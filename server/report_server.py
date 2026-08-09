#!/usr/bin/env python3
"""DeltaForceBooster report receiver and anonymous usage statistics API."""

import datetime as dt
import hashlib
import hmac
import http.server
import json
import os
import random
import re
import sqlite3
import string
import time
from collections import deque


REPORT_DIR = os.environ.get("DFB_REPORT_DIR", "/opt/df-booster-reports")
DATA_DIR = os.environ.get("DFB_DATA_DIR", "/opt/df-booster-data")
DB_PATH = os.path.join(DATA_DIR, "telemetry.db")
ADMIN_API_TOKEN = os.environ.get("DFB_ADMIN_API_TOKEN", "")
TELEMETRY_PEPPER = os.environ.get("DFB_TELEMETRY_PEPPER", "")
MAX_REPORT_BODY = 256 * 1024
MAX_TELEMETRY_BODY = 8 * 1024
PORT = int(os.environ.get("DFB_REPORT_PORT", "8899"))
RATE_WINDOW = 60
KEEP_DAYS = 30
CONFIG_TIERS = ("baseline", "light", "balanced", "full")
CONFIG_TIER_LABELS = {
    "baseline": "未使用本工具优化",
    "light": "轻量（1–9 项）",
    "balanced": "均衡（10–20 项）",
    "full": "深度（21+ 项）",
}

_hits = {}
_install_id_re = re.compile(r"^[0-9a-fA-F-]{32,64}$")


def _rate_ok(bucket, maximum):
    now = time.time()
    q = _hits.setdefault(bucket, deque())
    while q and now - q[0] > RATE_WINDOW:
        q.popleft()
    if len(q) >= maximum:
        return False
    q.append(now)
    return True


def _new_code():
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    while True:
        code = "".join(random.choice(alphabet) for _ in range(4))
        if not os.path.exists(os.path.join(REPORT_DIR, "DFB-%s.txt" % code)):
            return code


def _purge_old_reports():
    cutoff = time.time() - KEEP_DAYS * 86400
    try:
        for name in os.listdir(REPORT_DIR):
            if not re.match(r"^DFB-[A-Z2-9]{4}\.txt$", name):
                continue
            path = os.path.join(REPORT_DIR, name)
            if os.path.isfile(path) and os.path.getmtime(path) < cutoff:
                os.remove(path)
    except OSError:
        pass


def _connect():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=5)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def _init_db():
    conn = _connect()
    try:
        with conn:
            conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS clients (
                client_hash TEXT PRIMARY KEY,
                first_seen INTEGER NOT NULL,
                last_seen INTEGER NOT NULL,
                app_version TEXT NOT NULL DEFAULT '',
                os_name TEXT NOT NULL DEFAULT '',
                os_build TEXT NOT NULL DEFAULT '',
                cpu_model TEXT NOT NULL DEFAULT '',
                gpu_vendor TEXT NOT NULL DEFAULT '',
                gpu_model TEXT NOT NULL DEFAULT '',
                gpu_model_verified INTEGER NOT NULL DEFAULT 0,
                ram_gb REAL NOT NULL DEFAULT 0,
                device_type TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS daily_usage (
                day TEXT NOT NULL,
                client_hash TEXT NOT NULL,
                launches INTEGER NOT NULL DEFAULT 0,
                applies INTEGER NOT NULL DEFAULT 0,
                restores INTEGER NOT NULL DEFAULT 0,
                apply_ok INTEGER NOT NULL DEFAULT 0,
                apply_failed INTEGER NOT NULL DEFAULT 0,
                restore_failed INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (day, client_hash)
            );
            CREATE INDEX IF NOT EXISTS idx_clients_last_seen ON clients(last_seen);
            CREATE INDEX IF NOT EXISTS idx_clients_first_seen ON clients(first_seen);
            CREATE INDEX IF NOT EXISTS idx_daily_day ON daily_usage(day);
            CREATE TABLE IF NOT EXISTS performance_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_hash TEXT NOT NULL,
                recorded_at INTEGER NOT NULL,
                day TEXT NOT NULL,
                app_version TEXT NOT NULL DEFAULT '',
                gpu_model TEXT NOT NULL DEFAULT '',
                config_tier TEXT NOT NULL DEFAULT 'unknown',
                duration_sec INTEGER NOT NULL DEFAULT 0,
                avg_fps REAL NOT NULL DEFAULT 0,
                fps_1_low REAL NOT NULL DEFAULT 0,
                gpu_util_avg REAL NOT NULL DEFAULT 0,
                gpu_util_max REAL NOT NULL DEFAULT 0,
                gpu_temp_avg REAL NOT NULL DEFAULT 0,
                gpu_temp_max REAL NOT NULL DEFAULT 0,
                gpu_power_avg REAL NOT NULL DEFAULT 0,
                gpu_power_max REAL NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_performance_day ON performance_sessions(day);
            CREATE INDEX IF NOT EXISTS idx_performance_client ON performance_sessions(client_hash, recorded_at);
            """
            )
            # v0.19.0 以前的库没有“真实型号已验证”标记。旧的 GTX 1050 Ti/705 Ti
            # 可能是伪装值，只有新版客户端通过 NVML 验证后才进入显卡型号榜。
            columns = {row[1] for row in conn.execute("PRAGMA table_info(clients)")}
            if "gpu_model_verified" not in columns:
                conn.execute("ALTER TABLE clients ADD COLUMN gpu_model_verified INTEGER NOT NULL DEFAULT 0")
            performance_columns = {row[1] for row in conn.execute("PRAGMA table_info(performance_sessions)")}
            if "config_tier" not in performance_columns:
                conn.execute("ALTER TABLE performance_sessions ADD COLUMN config_tier TEXT NOT NULL DEFAULT 'unknown'")
    finally:
        conn.close()


def _text(value, maximum):
    if value is None:
        return ""
    return str(value).strip()[:maximum]


def _bounded_int(value, maximum=10000):
    try:
        return max(0, min(maximum, int(value)))
    except (TypeError, ValueError):
        return 0


def _bounded_float(value, maximum=2048):
    try:
        return max(0.0, min(float(maximum), round(float(value), 1)))
    except (TypeError, ValueError):
        return 0.0


def _normalize_telemetry(payload):
    if not isinstance(payload, dict):
        raise ValueError("payload must be an object")
    install_id = _text(payload.get("installId"), 64)
    event = _text(payload.get("event"), 16).lower()
    if not _install_id_re.fullmatch(install_id):
        raise ValueError("bad install id")
    if event not in ("launch", "apply", "restore", "performance"):
        raise ValueError("bad event")
    config_tier = _text(payload.get("configTier"), 16).lower()
    if config_tier not in CONFIG_TIERS:
        config_tier = "unknown"
    return {
        "install_id": install_id.lower(),
        "event": event,
        "app_version": _text(payload.get("version"), 24),
        "os_name": _text(payload.get("os"), 96),
        "os_build": _text(payload.get("build"), 24),
        "cpu_model": _text(payload.get("cpu"), 160),
        "gpu_vendor": _text(payload.get("gpuVendor"), 32),
        "gpu_model": _text(payload.get("gpuModel"), 160),
        "gpu_model_verified": 1 if payload.get("gpuModelVerified") is True else 0,
        "config_tier": config_tier,
        "ram_gb": _bounded_float(payload.get("ramGb")),
        "device_type": _text(payload.get("deviceType"), 24),
        "ok": _bounded_int(payload.get("ok")),
        "failed": _bounded_int(payload.get("failed")),
        "duration_sec": _bounded_int(payload.get("durationSec"), 600),
        "avg_fps": _bounded_float(payload.get("avgFps"), 2000),
        "fps_1_low": _bounded_float(payload.get("fps1Low"), 2000),
        "gpu_util_avg": _bounded_float(payload.get("gpuUtilAvg"), 100),
        "gpu_util_max": _bounded_float(payload.get("gpuUtilMax"), 100),
        "gpu_temp_avg": _bounded_float(payload.get("gpuTempAvg"), 150),
        "gpu_temp_max": _bounded_float(payload.get("gpuTempMax"), 150),
        "gpu_power_avg": _bounded_float(payload.get("gpuPowerAvg"), 2000),
        "gpu_power_max": _bounded_float(payload.get("gpuPowerMax"), 2000),
    }


def _client_hash(install_id):
    if not TELEMETRY_PEPPER:
        raise RuntimeError("DFB_TELEMETRY_PEPPER is not configured")
    return hashlib.sha256((TELEMETRY_PEPPER + install_id).encode("utf-8")).hexdigest()


def _record_telemetry(payload, now=None):
    item = _normalize_telemetry(payload)
    now = int(time.time() if now is None else now)
    day = time.strftime("%Y-%m-%d", time.gmtime(now))
    client_hash = _client_hash(item["install_id"])
    event = item["event"]
    counters = {
        "launches": 1 if event == "launch" else 0,
        "applies": 1 if event == "apply" else 0,
        "restores": 1 if event == "restore" else 0,
        "apply_ok": item["ok"] if event == "apply" else 0,
        "apply_failed": item["failed"] if event == "apply" else 0,
        "restore_failed": item["failed"] if event == "restore" else 0,
    }
    conn = _connect()
    try:
        with conn:
            conn.execute(
            """
            INSERT INTO clients (
                client_hash, first_seen, last_seen, app_version, os_name, os_build,
                cpu_model, gpu_vendor, gpu_model, gpu_model_verified, ram_gb, device_type
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(client_hash) DO UPDATE SET
                last_seen=excluded.last_seen,
                app_version=CASE WHEN excluded.app_version<>'' THEN excluded.app_version ELSE clients.app_version END,
                os_name=CASE WHEN excluded.os_name<>'' THEN excluded.os_name ELSE clients.os_name END,
                os_build=CASE WHEN excluded.os_build<>'' THEN excluded.os_build ELSE clients.os_build END,
                cpu_model=CASE WHEN excluded.cpu_model<>'' THEN excluded.cpu_model ELSE clients.cpu_model END,
                gpu_vendor=CASE WHEN excluded.gpu_vendor<>'' THEN excluded.gpu_vendor ELSE clients.gpu_vendor END,
                gpu_model=CASE
                    WHEN excluded.gpu_model<>'' AND (excluded.gpu_model_verified=1 OR clients.gpu_model_verified=0)
                    THEN excluded.gpu_model ELSE clients.gpu_model END,
                gpu_model_verified=CASE WHEN excluded.gpu_model_verified=1 THEN 1 ELSE clients.gpu_model_verified END,
                ram_gb=CASE WHEN excluded.ram_gb>0 THEN excluded.ram_gb ELSE clients.ram_gb END,
                device_type=CASE WHEN excluded.device_type<>'' THEN excluded.device_type ELSE clients.device_type END
            """,
            (
                client_hash, now, now, item["app_version"], item["os_name"], item["os_build"],
                item["cpu_model"], item["gpu_vendor"], item["gpu_model"],
                item["gpu_model_verified"], item["ram_gb"], item["device_type"],
            ),
        )
            if event == "performance" and item["gpu_model_verified"] == 1 and item["duration_sec"] > 0 and (
                item["avg_fps"] > 0 or item["gpu_util_avg"] > 0
            ):
                conn.execute(
                    """
                    INSERT INTO performance_sessions (
                        client_hash, recorded_at, day, app_version, gpu_model, config_tier, duration_sec,
                        avg_fps, fps_1_low, gpu_util_avg, gpu_util_max, gpu_temp_avg,
                        gpu_temp_max, gpu_power_avg, gpu_power_max
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        client_hash, now, day, item["app_version"], item["gpu_model"], item["config_tier"],
                        item["duration_sec"], item["avg_fps"], item["fps_1_low"],
                        item["gpu_util_avg"], item["gpu_util_max"], item["gpu_temp_avg"],
                        item["gpu_temp_max"], item["gpu_power_avg"], item["gpu_power_max"],
                    ),
                )
                # 只保留 90 天汇总；客户端逐帧 CSV 从不上传。
                conn.execute("DELETE FROM performance_sessions WHERE recorded_at<?", (now - 90 * 86400,))
            conn.execute(
            """
            INSERT INTO daily_usage (
                day, client_hash, launches, applies, restores, apply_ok, apply_failed, restore_failed
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(day, client_hash) DO UPDATE SET
                launches=daily_usage.launches+excluded.launches,
                applies=daily_usage.applies+excluded.applies,
                restores=daily_usage.restores+excluded.restores,
                apply_ok=daily_usage.apply_ok+excluded.apply_ok,
                apply_failed=daily_usage.apply_failed+excluded.apply_failed,
                restore_failed=daily_usage.restore_failed+excluded.restore_failed
            """,
            (
                day, client_hash, counters["launches"], counters["applies"], counters["restores"],
                counters["apply_ok"], counters["apply_failed"], counters["restore_failed"],
            ),
            )
    finally:
        conn.close()


def _rows(conn, sql, args=()):
    return [dict(row) for row in conn.execute(sql, args).fetchall()]


def _report_summary():
    count = 0
    last = 0
    try:
        for name in os.listdir(REPORT_DIR):
            if re.match(r"^DFB-[A-Z2-9]{4}\.txt$", name):
                count += 1
                last = max(last, int(os.path.getmtime(os.path.join(REPORT_DIR, name))))
    except OSError:
        pass
    return {"count": count, "lastUpload": last or None}


def _summarize_performance_pairs(rows):
    metric_keys = ("fpsDelta", "fps1LowDelta", "gpuUtilDelta", "gpuTempDelta", "gpuPowerDelta")
    result = {
        "comparisons": len(rows),
        "matchedClients": len({row["client_hash"] for row in rows}),
    }
    for key in metric_keys:
        values = [float(row[key]) for row in rows if row.get(key) is not None]
        result[key] = round(sum(values) / len(values), 1) if values else 0.0
    return result


def _build_stats(now=None, days=30):
    now = int(time.time() if now is None else now)
    today = dt.datetime.fromtimestamp(now, dt.timezone.utc).date()
    start_day = today - dt.timedelta(days=days - 1)
    midnight = int(dt.datetime.combine(today, dt.time.min, tzinfo=dt.timezone.utc).timestamp())
    conn = _connect()
    try:
        total_users = conn.execute("SELECT COUNT(*) FROM clients").fetchone()[0]
        active_15m = conn.execute("SELECT COUNT(*) FROM clients WHERE last_seen>=?", (now - 900,)).fetchone()[0]
        active_24h = conn.execute("SELECT COUNT(*) FROM clients WHERE last_seen>=?", (now - 86400,)).fetchone()[0]
        active_7d = conn.execute("SELECT COUNT(*) FROM clients WHERE last_seen>=?", (now - 7 * 86400,)).fetchone()[0]
        active_30d = conn.execute("SELECT COUNT(*) FROM clients WHERE last_seen>=?", (now - 30 * 86400,)).fetchone()[0]
        new_today = conn.execute("SELECT COUNT(*) FROM clients WHERE first_seen>=?", (midnight,)).fetchone()[0]
        sums = dict(conn.execute(
            """SELECT COALESCE(SUM(launches),0) launches, COALESCE(SUM(applies),0) applies,
                      COALESCE(SUM(restores),0) restores, COALESCE(SUM(apply_ok),0) apply_ok,
                      COALESCE(SUM(apply_failed),0) apply_failed,
                      COALESCE(SUM(restore_failed),0) restore_failed
                 FROM daily_usage WHERE day>=?""",
            (start_day.isoformat(),),
        ).fetchone())
        today_sums = dict(conn.execute(
            """SELECT COALESCE(SUM(launches),0) launches, COALESCE(SUM(applies),0) applies,
                      COALESCE(SUM(restores),0) restores FROM daily_usage WHERE day=?""",
            (today.isoformat(),),
        ).fetchone())
        daily_rows = {row["day"]: dict(row) for row in conn.execute(
            """SELECT day, COUNT(*) active, SUM(launches) launches, SUM(applies) applies,
                      SUM(restores) restores FROM daily_usage WHERE day>=? GROUP BY day""",
            (start_day.isoformat(),),
        )}
        new_rows = {row["day"]: row["new_users"] for row in conn.execute(
            """SELECT date(first_seen, 'unixepoch') day, COUNT(*) new_users
                 FROM clients WHERE first_seen>=? GROUP BY day""",
            (int(dt.datetime.combine(start_day, dt.time.min, tzinfo=dt.timezone.utc).timestamp()),),
        )}
        versions = _rows(conn, "SELECT app_version label, COUNT(*) value FROM clients WHERE app_version<>'' GROUP BY app_version ORDER BY value DESC, label DESC LIMIT 12")
        gpus = _rows(conn, "SELECT gpu_model label, COUNT(*) value FROM clients WHERE gpu_model<>'' AND gpu_model_verified=1 GROUP BY gpu_model ORDER BY value DESC, label LIMIT 12")
        vendors = _rows(conn, "SELECT gpu_vendor label, COUNT(*) value FROM clients WHERE gpu_vendor<>'' GROUP BY gpu_vendor ORDER BY value DESC, label LIMIT 8")
        systems = _rows(conn, "SELECT (os_name || CASE WHEN os_build<>'' THEN ' · ' || os_build ELSE '' END) label, COUNT(*) value FROM clients WHERE os_name<>'' GROUP BY label ORDER BY value DESC, label LIMIT 12")
        devices = _rows(conn, "SELECT device_type label, COUNT(*) value FROM clients WHERE device_type<>'' GROUP BY device_type ORDER BY value DESC, label")
        ram_values = [row[0] for row in conn.execute("SELECT ram_gb FROM clients WHERE ram_gb>0")]
        performance = dict(conn.execute(
            """SELECT COUNT(*) sessions,
                      AVG(NULLIF(avg_fps,0)) avg_fps, AVG(NULLIF(fps_1_low,0)) fps_1_low,
                      AVG(NULLIF(gpu_util_avg,0)) gpu_util_avg,
                      AVG(NULLIF(gpu_temp_avg,0)) gpu_temp_avg,
                      AVG(NULLIF(gpu_power_avg,0)) gpu_power_avg
                 FROM performance_sessions WHERE day>=?""",
            (start_day.isoformat(),),
        ).fetchone())
        performance_by_gpu = _rows(
            conn,
            """SELECT gpu_model label, COUNT(*) sessions,
                      ROUND(AVG(NULLIF(avg_fps,0)),1) avgFps,
                      ROUND(AVG(NULLIF(fps_1_low,0)),1) fps1Low,
                      ROUND(AVG(NULLIF(gpu_util_avg,0)),1) gpuUtil,
                      ROUND(AVG(NULLIF(gpu_temp_avg,0)),1) gpuTemp,
                      ROUND(AVG(NULLIF(gpu_power_avg,0)),1) gpuPower
                 FROM performance_sessions
                WHERE day>=? AND gpu_model<>''
                GROUP BY gpu_model ORDER BY sessions DESC, label LIMIT 12""",
            (start_day.isoformat(),),
        )
        performance_by_config = _rows(
            conn,
            """SELECT config_tier tier, COUNT(*) sessions, COUNT(DISTINCT client_hash) clients,
                      ROUND(AVG(NULLIF(avg_fps,0)),1) avgFps,
                      ROUND(AVG(NULLIF(fps_1_low,0)),1) fps1Low,
                      ROUND(AVG(NULLIF(gpu_util_avg,0)),1) gpuUtil,
                      ROUND(AVG(NULLIF(gpu_temp_avg,0)),1) gpuTemp,
                      ROUND(AVG(NULLIF(gpu_power_avg,0)),1) gpuPower
                 FROM performance_sessions
                WHERE day>=? AND config_tier IN ('baseline','light','balanced','full')
                GROUP BY config_tier
                ORDER BY CASE config_tier
                    WHEN 'baseline' THEN 0 WHEN 'light' THEN 1 WHEN 'balanced' THEN 2 ELSE 3 END""",
            (start_day.isoformat(),),
        )
        paired_rows = _rows(
            conn,
            """WITH client_tier AS (
                   SELECT client_hash, gpu_model, config_tier,
                          AVG(NULLIF(avg_fps,0)) avg_fps,
                          AVG(NULLIF(fps_1_low,0)) fps_1_low,
                          AVG(NULLIF(gpu_util_avg,0)) gpu_util,
                          AVG(NULLIF(gpu_temp_avg,0)) gpu_temp,
                          AVG(NULLIF(gpu_power_avg,0)) gpu_power
                     FROM performance_sessions
                    WHERE day>=? AND config_tier IN ('baseline','light','balanced','full')
                    GROUP BY client_hash, gpu_model, config_tier
               )
               SELECT opt.client_hash, opt.gpu_model, opt.config_tier tier,
                      opt.avg_fps-base.avg_fps fpsDelta,
                      opt.fps_1_low-base.fps_1_low fps1LowDelta,
                      opt.gpu_util-base.gpu_util gpuUtilDelta,
                      opt.gpu_temp-base.gpu_temp gpuTempDelta,
                      opt.gpu_power-base.gpu_power gpuPowerDelta
                 FROM client_tier opt
                 JOIN client_tier base
                   ON base.client_hash=opt.client_hash
                  AND base.gpu_model=opt.gpu_model
                  AND base.config_tier='baseline'
                WHERE opt.config_tier<>'baseline'""",
            (start_day.isoformat(),),
        )
    finally:
        conn.close()

    pair_summaries = {}
    for tier in CONFIG_TIERS[1:]:
        pair_summaries[tier] = _summarize_performance_pairs(
            [row for row in paired_rows if row["tier"] == tier]
        )
    empty_pair_summary = _summarize_performance_pairs([])
    config_rows = {row["tier"]: row for row in performance_by_config}
    performance_by_config = []
    for tier in CONFIG_TIERS:
        row = config_rows.get(tier, {
            "tier": tier, "sessions": 0, "clients": 0,
            "avgFps": 0, "fps1Low": 0, "gpuUtil": 0, "gpuTemp": 0, "gpuPower": 0,
        })
        row["label"] = CONFIG_TIER_LABELS[row["tier"]]
        row.update(pair_summaries.get(row["tier"], empty_pair_summary))
        performance_by_config.append(row)
    performance_improvement = _summarize_performance_pairs(paired_rows)

    ram_buckets = {"≤8 GB": 0, "9–16 GB": 0, "17–32 GB": 0, "33–64 GB": 0, ">64 GB": 0}
    for ram in ram_values:
        if ram <= 8:
            ram_buckets["≤8 GB"] += 1
        elif ram <= 16:
            ram_buckets["9–16 GB"] += 1
        elif ram <= 32:
            ram_buckets["17–32 GB"] += 1
        elif ram <= 64:
            ram_buckets["33–64 GB"] += 1
        else:
            ram_buckets[">64 GB"] += 1

    daily = []
    for offset in range(days):
        day = start_day + dt.timedelta(days=offset)
        row = daily_rows.get(day.isoformat(), {})
        daily.append({
            "day": day.isoformat(),
            "active": int(row.get("active") or 0),
            "newUsers": int(new_rows.get(day.isoformat(), 0)),
            "launches": int(row.get("launches") or 0),
            "applies": int(row.get("applies") or 0),
            "restores": int(row.get("restores") or 0),
        })
    return {
        "generatedAt": now,
        "periodDays": days,
        "totals": {
            "users": total_users,
            "active15m": active_15m,
            "active24h": active_24h,
            "active7d": active_7d,
            "active30d": active_30d,
            "newToday": new_today,
            "launchesToday": int(today_sums["launches"]),
            "appliesToday": int(today_sums["applies"]),
            "restoresToday": int(today_sums["restores"]),
        },
        "period": {key: int(value) for key, value in sums.items()},
        "daily": daily,
        "versions": versions,
        "gpus": gpus,
        "gpuVendors": vendors,
        "systems": systems,
        "devices": devices,
        "ram": [{"label": key, "value": value} for key, value in ram_buckets.items()],
        "performance": {
            "sessions": int(performance.get("sessions") or 0),
            "avgFps": round(float(performance.get("avg_fps") or 0), 1),
            "fps1Low": round(float(performance.get("fps_1_low") or 0), 1),
            "gpuUtil": round(float(performance.get("gpu_util_avg") or 0), 1),
            "gpuTemp": round(float(performance.get("gpu_temp_avg") or 0), 1),
            "gpuPower": round(float(performance.get("gpu_power_avg") or 0), 1),
        },
        "performanceByGpu": performance_by_gpu,
        "performanceByConfig": performance_by_config,
        "performanceImprovement": performance_improvement,
        "diagnosticReports": _report_summary(),
    }


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "dfb-report/2.0"

    def _reply_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self, maximum):
        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            raise ValueError("bad length")
        if length <= 0 or length > maximum:
            raise OverflowError("body size")
        return self.rfile.read(length)

    def do_POST(self):
        path = self.path.split("?", 1)[0].rstrip("/")
        ip = self.headers.get("X-Forwarded-For", self.client_address[0]).split(",")[0].strip()
        if path == "/report/upload":
            if not _rate_ok("report:" + ip, 5):
                return self._reply_json(429, {"error": "too many uploads, try later"})
            try:
                raw = self._read_body(MAX_REPORT_BODY)
            except ValueError:
                return self._reply_json(400, {"error": "bad length"})
            except OverflowError:
                return self._reply_json(413, {"error": "body too large"})
            text = raw.decode("utf-8", errors="replace")
            _purge_old_reports()
            code = _new_code()
            header = "# %s  from=%s  bytes=%d\n\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), ip, len(raw))
            with open(os.path.join(REPORT_DIR, "DFB-%s.txt" % code), "w", encoding="utf-8") as stream:
                stream.write(header + text)
            return self._reply_json(200, {"code": "DFB-" + code})

        if path == "/report/telemetry":
            if not _rate_ok("telemetry:" + ip, 120):
                return self._reply_json(429, {"error": "too many events, try later"})
            try:
                raw = self._read_body(MAX_TELEMETRY_BODY)
                payload = json.loads(raw.decode("utf-8"))
                _record_telemetry(payload)
            except OverflowError:
                return self._reply_json(413, {"error": "body too large"})
            except (UnicodeError, json.JSONDecodeError, ValueError):
                return self._reply_json(400, {"error": "bad telemetry"})
            except RuntimeError:
                return self._reply_json(503, {"error": "telemetry unavailable"})
            return self._reply_json(200, {"ok": True})

        self._reply_json(404, {"error": "not found"})

    def do_GET(self):
        path = self.path.split("?", 1)[0].rstrip("/")
        if path == "/report/health":
            return self._reply_json(200, {"ok": True, "telemetry": bool(TELEMETRY_PEPPER)})
        if path == "/api/stats":
            supplied = self.headers.get("X-DFB-Admin-Token", "")
            if not ADMIN_API_TOKEN or not hmac.compare_digest(supplied, ADMIN_API_TOKEN):
                return self._reply_json(403, {"error": "forbidden"})
            return self._reply_json(200, _build_stats())
        self._reply_json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    os.makedirs(REPORT_DIR, exist_ok=True)
    os.chmod(REPORT_DIR, 0o750)
    _init_db()
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
