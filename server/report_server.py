#!/usr/bin/env python3
"""DeltaForceBooster report receiver and anonymous usage statistics API."""

import datetime as dt
import base64
import hashlib
import hmac
import http.server
import ipaddress
import json
import math
import os
import random
import re
import sqlite3
import statistics
import string
import sys
import threading
import time
import urllib.parse
from collections import deque, namedtuple


REPORT_DIR = os.environ.get("DFB_REPORT_DIR", "/opt/df-booster-reports")
DATA_DIR = os.environ.get("DFB_DATA_DIR", "/opt/df-booster-data")
DB_PATH = os.path.join(DATA_DIR, "telemetry.db")
ADMIN_API_TOKEN = os.environ.get("DFB_ADMIN_API_TOKEN", "")
TELEMETRY_PEPPER = os.environ.get("DFB_TELEMETRY_PEPPER", "")
MAX_REPORT_BODY = 256 * 1024
MAX_TELEMETRY_BODY = 8 * 1024
MAX_ADMIN_RESPONSE_BODY = 1024 * 1024
MAX_WEEKLY_SNAPSHOT_BODY = 768 * 1024
PORT = int(os.environ.get("DFB_REPORT_PORT", "8899"))
RATE_WINDOW = 60
KEEP_DAYS = 30
PERFORMANCE_KEEP_DAYS = 90
TELEMETRY_KEEP_DAYS = 180
REPLAY_KEEP_DAYS = 2
DEVICE_TOKEN_TTL_DAYS = 30
TELEMETRY_CLOCK_SKEW = 10 * 60
PERFORMANCE_MIN_DURATION = 60
PERFORMANCE_MAX_DURATION = 300
PERFORMANCE_DAILY_LIMIT = 8
TUNING_DAILY_LIMIT = 80
TUNING_GROUP_MIN_DEVICES = 20
PERFORMANCE_MIN_SAMPLES = 5
PERFORMANCE_MIN_COMPARISONS = 5
MAINTENANCE_INTERVAL = 6 * 60 * 60
REGISTRATION_DAILY_LIMIT = 200
MAX_RATE_BUCKETS = 20000
TOKEN_REQUIRED_VERSION = (0, 19, 4)
WEEKLY_SCHEMA_VERSION = 3
WEEKLY_FILTER_LIMITS = {"version": 24, "gpu": 160, "deviceType": 24}
CUSTOM_PERIOD_MAX_DAYS = 92
REPORTING_EPOCH_WEEK = dt.date(2026, 8, 3)
REPORT_TIMEZONE = dt.timezone(dt.timedelta(hours=8))
CONFIG_TIERS = ("baseline", "light", "balanced", "full")
CONFIG_TIER_LABELS = {
    "baseline": "未使用本工具优化",
    "light": "轻量（1–9 项）",
    "balanced": "均衡（10–20 项）",
    "full": "深度（21+ 项）",
}
TUNING_TYPES = ("experiment_started", "variant_applied", "run_completed", "experiment_completed")
TUNING_GOALS = ("smoothness", "average_fps", "stutter_reduction", "balanced", "laptop_efficiency")
TUNING_EXPERIMENT_STATUSES = (
    "created", "baseline_pending", "baseline_running", "baseline_complete",
    "variant_pending", "variant_applied", "reboot_required", "variant_running",
    "variant_complete", "comparing", "final_validation", "completed",
    "rolled_back", "cancelled", "failed",
)
TUNING_TERMINAL_STATUSES = ("completed", "rolled_back", "cancelled", "failed")
TUNING_RESULTS = ("found_better", "no_significant_gain", "rolled_back", "cancelled", "failed")
TUNING_STOP_REASONS = (
    "completed", "no_improvement", "constraints_exceeded", "baseline_unstable",
    "apply_failed", "user_cancelled", "environment_changed", "internal_error",
)
TUNING_VALIDITIES = ("valid", "invalid", "suspect")
TUNING_INVALID_REASONS = (
    "game_exited", "sample_too_short", "insufficient_frames", "scene_changed",
    "settings_changed", "driver_changed", "game_version_changed", "focus_lost",
    "thermal_anomaly", "capture_failed", "apply_failed", "user_cancelled",
)
TUNING_SOURCES = ("rules", "ai", "manual", "fallback")
TUNING_APPLY_RESULTS = ("succeeded", "partial", "failed")
TUNING_LIBRARY_GROUP_ITEMS = {
    1: {
        "G1": ("game-mode", "dvr-off"),
        "G2": ("prio-separation", "game-priority", "mmcss-games", "net-throttling-off"),
        "G3": ("fso-off", "gpu-pref", "windowed-opt-off"),
    },
}
TUNING_LIBRARY_VERSION = 1
TUNING_GROUP_ITEMS = TUNING_LIBRARY_GROUP_ITEMS[TUNING_LIBRARY_VERSION]
TUNING_GROUP_LABELS = {
    "G1": "后台与游戏模式组",
    "G2": "前台调度组",
    "G3": "显示与 GPU 选择组",
    "baseline": "实验基线",
    "final": "最终组合",
}
TUNING_ITEM_IDS = frozenset(
    item
    for groups in TUNING_LIBRARY_GROUP_ITEMS.values()
    for values in groups.values()
    for item in values
)

_hits = {}
_hits_lock = threading.Lock()
_hits_last_sweep = 0.0
_install_id_re = re.compile(r"^[0-9a-fA-F-]{32,64}$")
_event_id_re = re.compile(r"^[0-9a-fA-F-]{32,64}$")


class TelemetryAuthError(ValueError):
    pass


class TelemetryReplayError(ValueError):
    pass


class TelemetryDailyLimitError(ValueError):
    pass


class TelemetryPerformanceError(ValueError):
    pass


class TelemetryTuningError(ValueError):
    pass


class TelemetryOwnershipError(ValueError):
    pass


class TelemetryConflictError(ValueError):
    pass


class WeeklySnapshotError(RuntimeError):
    pass


CustomPeriod = namedtuple(
    "CustomPeriod", ("start", "end", "comparison_start", "comparison_end"),
    defaults=(None, None),
)


def _rate_ok(bucket, maximum, window=RATE_WINDOW):
    global _hits_last_sweep
    now = time.time()
    with _hits_lock:
        if now - _hits_last_sweep >= RATE_WINDOW:
            for key, entry in list(_hits.items()):
                queue = entry["queue"]
                entry_window = entry["window"]
                while queue and now - queue[0] > entry_window:
                    queue.popleft()
                if not queue:
                    _hits.pop(key, None)
            _hits_last_sweep = now
        entry = _hits.get(bucket)
        if entry is None:
            if len(_hits) >= MAX_RATE_BUCKETS:
                return False
            entry = {"queue": deque(), "window": window}
            _hits[bucket] = entry
        q = entry["queue"]
        effective_window = entry["window"]
        while q and now - q[0] > effective_window:
            q.popleft()
        if len(q) >= maximum:
            return False
        q.append(now)
        return True


def _client_ip(handler):
    """Return an address that a client cannot replace with the first XFF entry.

    Production Caddy connects over loopback.  Only that local proxy is allowed to
    supply X-Forwarded-For; direct connections are always keyed by their socket
    peer.  Walking the header from right to left also avoids trusting an
    attacker-prepended address when a proxy appends the real client address.
    """
    peer_text = str(handler.client_address[0]).strip()
    try:
        peer = ipaddress.ip_address(peer_text)
    except ValueError:
        return "unknown"
    if not peer.is_loopback:
        return peer.compressed
    forwarded = handler.headers.get("X-Forwarded-For", "")
    for value in reversed(forwarded.split(",")):
        try:
            candidate = ipaddress.ip_address(value.strip())
        except ValueError:
            continue
        if not candidate.is_loopback:
            return candidate.compressed
    return peer.compressed


def _new_code():
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    while True:
        code = "".join(random.choice(alphabet) for _ in range(4))
        if not os.path.exists(os.path.join(REPORT_DIR, "DFB-%s.txt" % code)):
            return code


def _purge_old_reports(now=None):
    cutoff = (time.time() if now is None else now) - KEEP_DAYS * 86400
    removed = 0
    try:
        for name in os.listdir(REPORT_DIR):
            if not re.match(r"^DFB-[A-Z2-9]{4}\.txt$", name):
                continue
            path = os.path.join(REPORT_DIR, name)
            if os.path.isfile(path) and os.path.getmtime(path) < cutoff:
                os.remove(path)
                removed += 1
    except OSError:
        pass
    return removed


def _connect():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=5)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def _run_maintenance(now=None):
    now = int(time.time() if now is None else now)
    removed_reports = _purge_old_reports(now)
    removed_sessions = 0
    removed_replays = 0
    removed_usage = 0
    removed_clients = 0
    conn = _connect()
    try:
        with conn:
            cursor = conn.execute(
                "DELETE FROM performance_sessions WHERE recorded_at<?",
                (now - PERFORMANCE_KEEP_DAYS * 86400,),
            )
            removed_sessions = max(0, cursor.rowcount)
            cursor = conn.execute(
                "DELETE FROM telemetry_replays WHERE seen_at<?",
                (now - REPLAY_KEEP_DAYS * 86400,),
            )
            removed_replays = max(0, cursor.rowcount)
            conn.execute(
                "DELETE FROM tuning_events WHERE seen_at<?",
                (now - REPLAY_KEEP_DAYS * 86400,),
            )
            conn.execute(
                "DELETE FROM tuning_experiments WHERE COALESCE(completed_at, created_at)<?",
                (now - TELEMETRY_KEEP_DAYS * 86400,),
            )
            usage_cutoff = dt.datetime.fromtimestamp(
                now - TELEMETRY_KEEP_DAYS * 86400, dt.timezone.utc
            ).date().isoformat()
            cursor = conn.execute("DELETE FROM daily_usage WHERE day<?", (usage_cutoff,))
            removed_usage = max(0, cursor.rowcount)
            cursor = conn.execute(
                "DELETE FROM clients WHERE last_seen<?",
                (now - TELEMETRY_KEEP_DAYS * 86400,),
            )
            removed_clients = max(0, cursor.rowcount)
    finally:
        conn.close()
    return {
        "reports": removed_reports,
        "performanceSessions": removed_sessions,
        "replayIds": removed_replays,
        "dailyUsage": removed_usage,
        "clients": removed_clients,
    }


def _maintenance_loop():
    while True:
        time.sleep(MAINTENANCE_INTERVAL)
        try:
            _run_maintenance()
        except Exception:
            # 维护失败不能中断接收服务；下一轮或独立维护命令会再次执行。
            pass


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
                device_type TEXT NOT NULL DEFAULT '',
                authenticated_last_seen INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS daily_usage (
                day TEXT NOT NULL,
                client_hash TEXT NOT NULL,
                launches INTEGER NOT NULL DEFAULT 0,
                applies INTEGER NOT NULL DEFAULT 0,
                restores INTEGER NOT NULL DEFAULT 0,
                apply_ok INTEGER NOT NULL DEFAULT 0,
                apply_failed INTEGER NOT NULL DEFAULT 0,
                restore_ok INTEGER NOT NULL DEFAULT 0,
                restore_failed INTEGER NOT NULL DEFAULT 0,
                trusted_launches INTEGER NOT NULL DEFAULT 0,
                trusted_applies INTEGER NOT NULL DEFAULT 0,
                trusted_restores INTEGER NOT NULL DEFAULT 0,
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
                gpu_power_max REAL NOT NULL DEFAULT 0,
                authenticated INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_performance_day ON performance_sessions(day);
            CREATE INDEX IF NOT EXISTS idx_performance_client ON performance_sessions(client_hash, recorded_at);
            CREATE TABLE IF NOT EXISTS telemetry_replays (
                client_hash TEXT NOT NULL,
                event_id TEXT NOT NULL,
                seen_at INTEGER NOT NULL,
                PRIMARY KEY (client_hash, event_id)
            );
            CREATE INDEX IF NOT EXISTS idx_replays_seen_at ON telemetry_replays(seen_at);
            CREATE TABLE IF NOT EXISTS weekly_snapshots (
                week_start TEXT PRIMARY KEY,
                generated_at INTEGER NOT NULL,
                schema_version INTEGER NOT NULL,
                report_json TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS tuning_experiments (
                experiment_id TEXT PRIMARY KEY,
                client_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                completed_at INTEGER,
                status TEXT NOT NULL,
                goal TEXT NOT NULL,
                risk_level TEXT NOT NULL,
                allow_reboot INTEGER NOT NULL DEFAULT 0,
                allow_higher_power INTEGER NOT NULL DEFAULT 0,
                max_temp_increase REAL,
                max_power_increase REAL,
                library_version INTEGER NOT NULL DEFAULT 1,
                app_version TEXT NOT NULL,
                game_version TEXT NOT NULL DEFAULT '',
                gpu_model TEXT NOT NULL,
                driver_version TEXT NOT NULL DEFAULT '',
                baseline_variant_id TEXT,
                winning_variant_id TEXT,
                result TEXT NOT NULL DEFAULT '',
                stop_reason TEXT NOT NULL DEFAULT '',
                auto_rollback INTEGER NOT NULL DEFAULT 0,
                start_payload_hash TEXT NOT NULL DEFAULT '',
                completion_payload_hash TEXT NOT NULL DEFAULT ''
            );
            CREATE INDEX IF NOT EXISTS idx_tuning_experiments_client ON tuning_experiments(client_hash, created_at);
            CREATE INDEX IF NOT EXISTS idx_tuning_experiments_completed ON tuning_experiments(completed_at);
            CREATE INDEX IF NOT EXISTS idx_tuning_experiments_status ON tuning_experiments(status, created_at);
            CREATE TABLE IF NOT EXISTS tuning_variants (
                variant_id TEXT PRIMARY KEY,
                experiment_id TEXT NOT NULL,
                sequence_no INTEGER NOT NULL,
                group_id TEXT NOT NULL,
                display_name TEXT NOT NULL,
                item_set_hash TEXT NOT NULL,
                item_ids_json TEXT NOT NULL,
                source TEXT NOT NULL,
                risk_level TEXT NOT NULL,
                requires_reboot INTEGER NOT NULL DEFAULT 0,
                ai_reason TEXT NOT NULL DEFAULT '',
                control_variant_id TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL,
                apply_result TEXT NOT NULL DEFAULT '',
                applied_count INTEGER NOT NULL DEFAULT 0,
                failed_count INTEGER NOT NULL DEFAULT 0,
                skipped_count INTEGER NOT NULL DEFAULT 0,
                applied_at INTEGER,
                restored_at INTEGER,
                payload_hash TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (experiment_id) REFERENCES tuning_experiments(experiment_id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_tuning_variants_experiment ON tuning_variants(experiment_id, group_id);
            CREATE TABLE IF NOT EXISTS tuning_runs (
                run_id TEXT PRIMARY KEY,
                experiment_id TEXT NOT NULL,
                variant_id TEXT NOT NULL,
                run_no INTEGER NOT NULL,
                sequence_no INTEGER NOT NULL,
                started_at INTEGER NOT NULL,
                completed_at INTEGER,
                validity TEXT NOT NULL,
                invalid_reason TEXT NOT NULL DEFAULT '',
                duration_sec INTEGER NOT NULL DEFAULT 0,
                avg_fps REAL,
                fps_1_low REAL,
                p99_frame_ms REAL,
                stutter_50ms INTEGER,
                stutter_100ms INTEGER,
                gpu_util_avg REAL,
                gpu_temp_avg REAL,
                gpu_power_avg REAL,
                settings_hash TEXT NOT NULL DEFAULT '',
                environment_hash TEXT NOT NULL DEFAULT '',
                order_controlled INTEGER NOT NULL DEFAULT 0,
                payload_hash TEXT NOT NULL DEFAULT '',
                FOREIGN KEY (experiment_id) REFERENCES tuning_experiments(experiment_id) ON DELETE CASCADE,
                FOREIGN KEY (variant_id) REFERENCES tuning_variants(variant_id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_tuning_runs_experiment ON tuning_runs(experiment_id, completed_at);
            CREATE INDEX IF NOT EXISTS idx_tuning_runs_variant ON tuning_runs(variant_id, completed_at);
            CREATE INDEX IF NOT EXISTS idx_tuning_runs_validity ON tuning_runs(validity, completed_at);
            CREATE TABLE IF NOT EXISTS ai_tuning_decisions (
                decision_id TEXT PRIMARY KEY,
                experiment_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                model TEXT NOT NULL,
                prompt_version TEXT NOT NULL,
                schema_version INTEGER NOT NULL,
                input_hash TEXT NOT NULL,
                decision TEXT NOT NULL,
                selected_group_id TEXT,
                selected_item_ids_json TEXT,
                reason_codes_json TEXT,
                explanation TEXT,
                confidence REAL,
                validation_result TEXT NOT NULL,
                fallback_used INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (experiment_id) REFERENCES tuning_experiments(experiment_id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_ai_tuning_experiment ON ai_tuning_decisions(experiment_id, created_at);
            CREATE TABLE IF NOT EXISTS tuning_events (
                client_hash TEXT NOT NULL,
                event_id TEXT NOT NULL,
                seen_at INTEGER NOT NULL,
                PRIMARY KEY (client_hash, event_id)
            );
            CREATE INDEX IF NOT EXISTS idx_tuning_events_seen ON tuning_events(client_hash, seen_at);
            """
            )
            # v0.19.0 以前的库没有“真实型号已验证”标记。旧的 GTX 1050 Ti/705 Ti
            # 可能是伪装值，只有新版客户端通过 NVML 验证后才进入显卡型号榜。
            columns = {row[1] for row in conn.execute("PRAGMA table_info(clients)")}
            if "gpu_model_verified" not in columns:
                conn.execute("ALTER TABLE clients ADD COLUMN gpu_model_verified INTEGER NOT NULL DEFAULT 0")
            if "authenticated_last_seen" not in columns:
                conn.execute("ALTER TABLE clients ADD COLUMN authenticated_last_seen INTEGER NOT NULL DEFAULT 0")
            daily_columns = {row[1] for row in conn.execute("PRAGMA table_info(daily_usage)")}
            if "restore_ok" not in daily_columns:
                conn.execute("ALTER TABLE daily_usage ADD COLUMN restore_ok INTEGER NOT NULL DEFAULT 0")
            for name in ("trusted_launches", "trusted_applies", "trusted_restores"):
                if name not in daily_columns:
                    conn.execute("ALTER TABLE daily_usage ADD COLUMN %s INTEGER NOT NULL DEFAULT 0" % name)
            performance_columns = {row[1] for row in conn.execute("PRAGMA table_info(performance_sessions)")}
            if "config_tier" not in performance_columns:
                conn.execute("ALTER TABLE performance_sessions ADD COLUMN config_tier TEXT NOT NULL DEFAULT 'unknown'")
            if "authenticated" not in performance_columns:
                conn.execute("ALTER TABLE performance_sessions ADD COLUMN authenticated INTEGER NOT NULL DEFAULT 0")
            experiment_columns = {row[1] for row in conn.execute("PRAGMA table_info(tuning_experiments)")}
            for name, definition in (
                ("allow_higher_power", "INTEGER NOT NULL DEFAULT 0"),
                ("auto_rollback", "INTEGER NOT NULL DEFAULT 0"),
                ("library_version", "INTEGER NOT NULL DEFAULT 1"),
                ("start_payload_hash", "TEXT NOT NULL DEFAULT ''"),
                ("completion_payload_hash", "TEXT NOT NULL DEFAULT ''"),
            ):
                if name not in experiment_columns:
                    conn.execute("ALTER TABLE tuning_experiments ADD COLUMN %s %s" % (name, definition))
            variant_columns = {row[1] for row in conn.execute("PRAGMA table_info(tuning_variants)")}
            for name, definition in (
                ("apply_result", "TEXT NOT NULL DEFAULT ''"),
                ("applied_count", "INTEGER NOT NULL DEFAULT 0"),
                ("failed_count", "INTEGER NOT NULL DEFAULT 0"),
                ("skipped_count", "INTEGER NOT NULL DEFAULT 0"),
                ("control_variant_id", "TEXT NOT NULL DEFAULT ''"),
                ("payload_hash", "TEXT NOT NULL DEFAULT ''"),
            ):
                if name not in variant_columns:
                    conn.execute("ALTER TABLE tuning_variants ADD COLUMN %s %s" % (name, definition))
            run_columns = {row[1] for row in conn.execute("PRAGMA table_info(tuning_runs)")}
            if "order_controlled" not in run_columns:
                conn.execute("ALTER TABLE tuning_runs ADD COLUMN order_controlled INTEGER NOT NULL DEFAULT 0")
            if "payload_hash" not in run_columns:
                conn.execute("ALTER TABLE tuning_runs ADD COLUMN payload_hash TEXT NOT NULL DEFAULT ''")
    finally:
        conn.close()


def _text(value, maximum):
    if value is None:
        return ""
    return str(value).strip()[:maximum]


def _version_tuple(value):
    parts = re.findall(r"\d+", str(value or ""))[:3]
    if not parts:
        return (0, 0, 0)
    return tuple([int(part) for part in parts] + [0] * (3 - len(parts)))


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


def _strict_nonnegative_int(value, maximum):
    try:
        number = int(value)
    except (TypeError, ValueError):
        raise TelemetryPerformanceError("bad performance number")
    if number < 0 or number > maximum:
        raise TelemetryPerformanceError("performance number out of range")
    return number


def _strict_nonnegative_float(value, maximum):
    if value is None or value == "":
        return 0.0
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise TelemetryPerformanceError("bad performance number")
    if not math.isfinite(number) or number < 0 or number > maximum:
        raise TelemetryPerformanceError("performance number out of range")
    return round(number, 1)


def _tuning_text(payload, key, maximum, required=True):
    if key not in payload:
        if required:
            raise TelemetryTuningError("missing %s" % key)
        return ""
    value = payload.get(key)
    if not isinstance(value, str):
        raise TelemetryTuningError("%s must be text" % key)
    value = value.strip()
    if (required and not value) or len(value) > maximum or any(ord(char) < 32 for char in value):
        raise TelemetryTuningError("invalid %s" % key)
    return value


def _tuning_identifier(payload, key, required=True):
    value = _tuning_text(payload, key, 96, required)
    if value and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:\-]{0,95}", value):
        raise TelemetryTuningError("invalid %s" % key)
    return value


def _tuning_hash(payload, key, required=True):
    value = _tuning_text(payload, key, 64, required).lower()
    if value and not re.fullmatch(r"[0-9a-f]{64}", value):
        raise TelemetryTuningError("invalid %s" % key)
    return value


def _tuning_enum(payload, key, allowed):
    value = _tuning_text(payload, key, 48).lower()
    if value not in allowed:
        raise TelemetryTuningError("unknown %s" % key)
    return value


def _tuning_bool(payload, key):
    value = payload.get(key)
    if not isinstance(value, bool):
        raise TelemetryTuningError("%s must be boolean" % key)
    return value


def _tuning_int(payload, key, minimum, maximum):
    value = payload.get(key)
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum or value > maximum:
        raise TelemetryTuningError("invalid %s" % key)
    return value


def _tuning_float(payload, key, minimum, maximum, required=True):
    if key not in payload or payload.get(key) is None:
        if required:
            raise TelemetryTuningError("missing %s" % key)
        return None
    value = payload.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise TelemetryTuningError("invalid %s" % key)
    value = float(value)
    if not math.isfinite(value) or value < minimum or value > maximum:
        raise TelemetryTuningError("invalid %s" % key)
    return round(value, 2)


def _tuning_item_set_hash(item_ids):
    canonical = ",".join(sorted(item_ids)).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def _normalize_tuning(payload):
    tuning_type = _tuning_enum(payload, "tuningType", TUNING_TYPES)
    experiment_id = _tuning_identifier(payload, "experimentId")
    common_fields = {
        "installId", "event", "version", "os", "build", "cpu", "gpuVendor",
        "gpuModel", "gpuModelVerified", "ramGb", "deviceType", "configTier",
        "ok", "failed", "deviceToken", "eventId", "sentAt", "tuningType",
        "experimentId",
    }
    type_fields = {
        "experiment_started": {
            "status", "goal", "riskLevel", "allowReboot", "allowHigherPower",
            "maxTempIncreaseC", "maxPowerIncreasePct", "gameVersion",
            "driverVersion", "baselineVariantId", "libraryVersion",
        },
        "variant_applied": {
            "status", "variantId", "controlVariantId", "sequenceNo", "groupId", "itemSetHash",
            "itemIds", "source", "riskLevel", "requiresReboot", "applyResult",
            "appliedCount", "failedCount", "skippedCount",
        },
        "run_completed": {
            "runId", "variantId", "runNo", "sequenceNo", "validity",
            "invalidReason", "durationSec", "avgFps", "fps1Low", "p99FrameMs",
            "stutter50Ms", "stutter100Ms", "gpuUtilAvg", "gpuTempAvg",
            "gpuPowerAvg", "settingsHash", "environmentHash", "orderControlled",
        },
        "experiment_completed": {
            "status", "result", "stopReason", "winningVariantId", "autoRollback",
        },
    }
    unknown = set(payload) - common_fields - type_fields[tuning_type]
    if unknown:
        raise TelemetryTuningError("unknown tuning field: %s" % sorted(unknown)[0])
    result = {"type": tuning_type, "experiment_id": experiment_id}
    if tuning_type == "experiment_started":
        library_version = _tuning_int(payload, "libraryVersion", 1, 2147483647)
        if library_version not in TUNING_LIBRARY_GROUP_ITEMS:
            raise TelemetryTuningError("unknown libraryVersion")
        status = _tuning_enum(payload, "status", TUNING_EXPERIMENT_STATUSES)
        if status not in ("created", "baseline_pending", "baseline_running"):
            raise TelemetryTuningError("invalid initial status")
        risk = _tuning_enum(payload, "riskLevel", ("low", "medium", "high"))
        allow_higher_power = _tuning_bool(payload, "allowHigherPower")
        max_power_increase = _tuning_float(payload, "maxPowerIncreasePct", 0, 100)
        if not allow_higher_power and max_power_increase != 0:
            raise TelemetryTuningError("maxPowerIncreasePct requires allowHigherPower")
        result.update({
            "status": status,
            "goal": _tuning_enum(payload, "goal", TUNING_GOALS),
            "risk_level": risk,
            "allow_reboot": _tuning_bool(payload, "allowReboot"),
            "allow_higher_power": allow_higher_power,
            "max_temp_increase": _tuning_float(payload, "maxTempIncreaseC", 0, 20),
            "max_power_increase": max_power_increase,
            "library_version": library_version,
            "game_version": _tuning_text(payload, "gameVersion", 64, False),
            "driver_version": _tuning_text(payload, "driverVersion", 64, False),
            "baseline_variant_id": _tuning_identifier(payload, "baselineVariantId"),
        })
    elif tuning_type == "variant_applied":
        variant_id = _tuning_identifier(payload, "variantId")
        group_id = _tuning_text(payload, "groupId", 16)
        if group_id not in tuple(TUNING_GROUP_ITEMS) + ("final",):
            raise TelemetryTuningError("unknown groupId")
        item_ids = payload.get("itemIds")
        if not isinstance(item_ids, list) or len(item_ids) > len(TUNING_ITEM_IDS):
            raise TelemetryTuningError("invalid itemIds")
        if any(not isinstance(item, str) or item not in TUNING_ITEM_IDS for item in item_ids):
            raise TelemetryTuningError("unknown itemId")
        if len(set(item_ids)) != len(item_ids):
            raise TelemetryTuningError("duplicate itemId")
        required_items = set(TUNING_GROUP_ITEMS[group_id]) if group_id in TUNING_GROUP_ITEMS else set()
        if not required_items.issubset(item_ids) or (group_id == "final" and not item_ids):
            raise TelemetryTuningError("itemIds do not match groupId")
        item_hash = _tuning_hash(payload, "itemSetHash")
        if item_hash != _tuning_item_set_hash(item_ids):
            raise TelemetryTuningError("itemSetHash mismatch")
        status = _tuning_enum(payload, "status", ("variant_applied", "apply_failed"))
        apply_result = _tuning_enum(payload, "applyResult", TUNING_APPLY_RESULTS)
        if (status == "apply_failed") != (apply_result == "failed"):
            raise TelemetryTuningError("status and applyResult disagree")
        applied_count = _tuning_int(payload, "appliedCount", 0, len(TUNING_ITEM_IDS))
        failed_count = _tuning_int(payload, "failedCount", 0, len(TUNING_ITEM_IDS))
        skipped_count = _tuning_int(payload, "skippedCount", 0, len(TUNING_ITEM_IDS))
        if applied_count + failed_count + skipped_count != len(item_ids):
            raise TelemetryTuningError("application counts do not match itemIds")
        if (
            (apply_result == "succeeded" and (
                applied_count != len(item_ids) or failed_count or skipped_count
            ))
            or (apply_result == "partial" and (not failed_count or not applied_count))
            or (apply_result == "failed" and not failed_count)
        ):
            raise TelemetryTuningError("invalid application counts")
        requires_reboot = _tuning_bool(payload, "requiresReboot")
        if requires_reboot:
            raise TelemetryTuningError("Beta groups must not require reboot")
        risk = _tuning_enum(payload, "riskLevel", ("low",))
        result.update({
            "variant_id": variant_id,
            "control_variant_id": _tuning_identifier(payload, "controlVariantId"),
            "sequence_no": _tuning_int(payload, "sequenceNo", 1, 64),
            "group_id": group_id,
            "item_set_hash": item_hash,
            "item_ids": sorted(item_ids),
            "source": _tuning_enum(payload, "source", TUNING_SOURCES),
            "risk_level": risk,
            "requires_reboot": requires_reboot,
            "status": status,
            "apply_result": apply_result,
            "applied_count": applied_count,
            "failed_count": failed_count,
            "skipped_count": skipped_count,
        })
    elif tuning_type == "run_completed":
        validity = _tuning_enum(payload, "validity", TUNING_VALIDITIES)
        invalid_reason = _tuning_text(payload, "invalidReason", 48, False).lower()
        if validity == "valid" and invalid_reason:
            raise TelemetryTuningError("valid run must not have invalidReason")
        if validity != "valid" and invalid_reason not in TUNING_INVALID_REASONS:
            raise TelemetryTuningError("unknown invalidReason")
        duration = _tuning_int(payload, "durationSec", 0, 600)
        if validity == "valid" and duration < 90:
            raise TelemetryTuningError("valid run is too short")
        avg_fps = _tuning_float(payload, "avgFps", 0, 1000, validity == "valid")
        fps_1_low = _tuning_float(payload, "fps1Low", 0, 1000, validity == "valid")
        p99_frame_ms = _tuning_float(payload, "p99FrameMs", 0, 1000, validity == "valid")
        if validity == "valid" and (
            not avg_fps or not fps_1_low or not p99_frame_ms or fps_1_low > avg_fps
        ):
            raise TelemetryTuningError("invalid frame metrics")
        result.update({
            "run_id": _tuning_identifier(payload, "runId"),
            "variant_id": _tuning_identifier(payload, "variantId"),
            "run_no": _tuning_int(payload, "runNo", 1, 16),
            "sequence_no": _tuning_int(payload, "sequenceNo", 1, 64),
            "validity": validity,
            "invalid_reason": invalid_reason,
            "duration_sec": duration,
            "avg_fps": avg_fps,
            "fps_1_low": fps_1_low,
            "p99_frame_ms": p99_frame_ms,
            "stutter_50ms": _tuning_int(payload, "stutter50Ms", 0, 10000000),
            "stutter_100ms": _tuning_int(payload, "stutter100Ms", 0, 10000000),
            "gpu_util_avg": _tuning_float(payload, "gpuUtilAvg", 0, 100, False),
            "gpu_temp_avg": _tuning_float(payload, "gpuTempAvg", 0, 120, False),
            "gpu_power_avg": _tuning_float(payload, "gpuPowerAvg", 0, 1500, False),
            "settings_hash": _tuning_hash(payload, "settingsHash"),
            "environment_hash": _tuning_hash(payload, "environmentHash"),
            "order_controlled": _tuning_bool(payload, "orderControlled"),
        })
    else:
        status = _tuning_enum(payload, "status", TUNING_TERMINAL_STATUSES)
        result_name = _tuning_enum(payload, "result", TUNING_RESULTS)
        expected_status = {
            "found_better": "completed", "no_significant_gain": "completed",
            "rolled_back": "rolled_back", "cancelled": "cancelled", "failed": "failed",
        }[result_name]
        if status != expected_status:
            raise TelemetryTuningError("status and result disagree")
        winning_variant_id = _tuning_identifier(payload, "winningVariantId", False)
        if result_name == "found_better" and not winning_variant_id:
            raise TelemetryTuningError("winningVariantId is required")
        if result_name != "found_better" and winning_variant_id:
            raise TelemetryTuningError("winningVariantId is not allowed")
        auto_rollback = _tuning_bool(payload, "autoRollback")
        if result_name == "found_better" and auto_rollback:
            raise TelemetryTuningError("winning experiment must not auto rollback")
        result.update({
            "status": status,
            "result": result_name,
            "stop_reason": _tuning_enum(payload, "stopReason", TUNING_STOP_REASONS),
            "winning_variant_id": winning_variant_id,
            "auto_rollback": auto_rollback,
        })
    return result


def _normalize_telemetry(payload):
    if not isinstance(payload, dict):
        raise ValueError("payload must be an object")
    install_id = _text(payload.get("installId"), 64)
    event = _text(payload.get("event"), 16).lower()
    if not _install_id_re.fullmatch(install_id):
        raise ValueError("bad install id")
    if event not in ("launch", "apply", "restore", "performance", "tuning"):
        raise ValueError("bad event")
    config_tier = _text(payload.get("configTier"), 16).lower()
    if config_tier not in CONFIG_TIERS:
        config_tier = "unknown"
    if event == "performance":
        duration_sec = _strict_nonnegative_int(payload.get("durationSec"), PERFORMANCE_MAX_DURATION)
        avg_fps = _strict_nonnegative_float(payload.get("avgFps"), 1000)
        fps_1_low = _strict_nonnegative_float(payload.get("fps1Low"), 1000)
        gpu_util_avg = _strict_nonnegative_float(payload.get("gpuUtilAvg"), 100)
        gpu_util_max = _strict_nonnegative_float(payload.get("gpuUtilMax"), 100)
        gpu_temp_avg = _strict_nonnegative_float(payload.get("gpuTempAvg"), 120)
        gpu_temp_max = _strict_nonnegative_float(payload.get("gpuTempMax"), 120)
        gpu_power_avg = _strict_nonnegative_float(payload.get("gpuPowerAvg"), 1500)
        gpu_power_max = _strict_nonnegative_float(payload.get("gpuPowerMax"), 1500)
    else:
        duration_sec = 0
        avg_fps = fps_1_low = 0.0
        gpu_util_avg = gpu_util_max = 0.0
        gpu_temp_avg = gpu_temp_max = 0.0
        gpu_power_avg = gpu_power_max = 0.0
    result = {
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
        "duration_sec": duration_sec,
        "avg_fps": avg_fps,
        "fps_1_low": fps_1_low,
        "gpu_util_avg": gpu_util_avg,
        "gpu_util_max": gpu_util_max,
        "gpu_temp_avg": gpu_temp_avg,
        "gpu_temp_max": gpu_temp_max,
        "gpu_power_avg": gpu_power_avg,
        "gpu_power_max": gpu_power_max,
        "device_token": _text(payload.get("deviceToken"), 256),
        "event_id": _text(payload.get("eventId"), 64).lower(),
        "sent_at": payload.get("sentAt"),
    }
    result["tuning"] = _normalize_tuning(payload) if event == "tuning" else None
    return result


def _client_hash(install_id):
    if not TELEMETRY_PEPPER:
        raise RuntimeError("DFB_TELEMETRY_PEPPER is not configured")
    return hashlib.sha256((TELEMETRY_PEPPER + install_id).encode("utf-8")).hexdigest()


def _token_mac(install_id, issued_at):
    message = "v1\n%s\n%d" % (install_id.lower(), issued_at)
    digest = hmac.new(TELEMETRY_PEPPER.encode("utf-8"), message.encode("utf-8"), hashlib.sha256).digest()
    return base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")


def _issue_device_token(install_id, now=None):
    if not TELEMETRY_PEPPER:
        raise RuntimeError("DFB_TELEMETRY_PEPPER is not configured")
    install_id = _text(install_id, 64).lower()
    if not _install_id_re.fullmatch(install_id):
        raise ValueError("bad install id")
    issued_at = int(time.time() if now is None else now)
    token = "v1.%d.%s" % (issued_at, _token_mac(install_id, issued_at))
    return {
        "deviceToken": token,
        "expiresAt": issued_at + DEVICE_TOKEN_TTL_DAYS * 86400,
    }


def _verify_device_token(install_id, token, now=None):
    if not TELEMETRY_PEPPER:
        raise RuntimeError("DFB_TELEMETRY_PEPPER is not configured")
    now = int(time.time() if now is None else now)
    parts = str(token or "").split(".")
    if len(parts) != 3 or parts[0] != "v1":
        raise TelemetryAuthError("bad device token")
    try:
        issued_at = int(parts[1])
    except ValueError:
        raise TelemetryAuthError("bad device token")
    expected = _token_mac(install_id, issued_at)
    if not hmac.compare_digest(parts[2], expected):
        raise TelemetryAuthError("bad device token")
    if issued_at > now + TELEMETRY_CLOCK_SKEW:
        raise TelemetryAuthError("device token issued in future")
    if now > issued_at + DEVICE_TOKEN_TTL_DAYS * 86400:
        raise TelemetryAuthError("device token expired")
    return issued_at


def _telemetry_auth(item, now):
    token = item["device_token"]
    if not token:
        return False
    _verify_device_token(item["install_id"], token, now)
    if not _event_id_re.fullmatch(item["event_id"]):
        raise TelemetryAuthError("bad event id")
    try:
        sent_at = int(item["sent_at"])
    except (TypeError, ValueError):
        raise TelemetryAuthError("bad sent timestamp")
    if abs(now - sent_at) > TELEMETRY_CLOCK_SKEW:
        raise TelemetryAuthError("event timestamp outside allowed window")
    return True


def _validate_performance(item, authenticated):
    if item["duration_sec"] < PERFORMANCE_MIN_DURATION:
        raise TelemetryPerformanceError("performance duration too short")
    if not item["gpu_model_verified"] or not item["gpu_model"]:
        raise TelemetryPerformanceError("unverified gpu model")
    if authenticated and item["config_tier"] not in CONFIG_TIERS:
        raise TelemetryPerformanceError("unknown config tier")
    if item["avg_fps"] <= 0 or item["fps_1_low"] <= 0:
        raise TelemetryPerformanceError("missing frame metrics")
    if item["fps_1_low"] > item["avg_fps"]:
        raise TelemetryPerformanceError("low frame rate exceeds average")
    for average_key, maximum_key in (
        ("gpu_util_avg", "gpu_util_max"),
        ("gpu_temp_avg", "gpu_temp_max"),
        ("gpu_power_avg", "gpu_power_max"),
    ):
        average = item[average_key]
        maximum = item[maximum_key]
        if average > 0 and maximum > 0 and maximum < average:
            raise TelemetryPerformanceError("maximum below average")


def _require_tuning_experiment(conn, experiment_id, client_hash):
    row = conn.execute(
        "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
    ).fetchone()
    if row is None:
        raise TelemetryTuningError("unknown experimentId")
    if row["client_hash"] != client_hash:
        raise TelemetryOwnershipError("experimentId belongs to another client")
    return row


def _require_tuning_variant(conn, variant_id, experiment_id):
    row = conn.execute(
        "SELECT * FROM tuning_variants WHERE variant_id=?", (variant_id,)
    ).fetchone()
    if row is None:
        raise TelemetryTuningError("unknown variantId")
    if row["experiment_id"] != experiment_id:
        raise TelemetryOwnershipError("variantId belongs to another experiment")
    return row


def _tuning_business_hash(item):
    value = {"tuning": item["tuning"]}
    if item["tuning"]["type"] == "experiment_started":
        value.update({"appVersion": item["app_version"], "gpuModel": item["gpu_model"]})
    encoded = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _tuning_variant_items(variant):
    try:
        values = json.loads(variant["item_ids_json"])
    except (TypeError, json.JSONDecodeError):
        return []
    return values if isinstance(values, list) and all(isinstance(value, str) for value in values) else []


def _tuning_variant_fully_applied(variant):
    items = _tuning_variant_items(variant)
    return bool(items) and (
        variant["apply_result"] == "succeeded"
        and int(variant["applied_count"]) == len(items)
        and int(variant["failed_count"]) == 0
        and int(variant["skipped_count"]) == 0
    )


def _tuning_cv(values):
    values = [float(value) for value in values if value is not None and float(value) > 0]
    if len(values) < 2 or statistics.mean(values) <= 0:
        return None
    return round(float(statistics.stdev(values) * 100.0 / statistics.mean(values)), 2)


def _evaluate_tuning_run_slice(
    experiment, baseline, control, candidate, baseline_runs, control_runs, candidate_runs,
):
    if len(baseline_runs) < 3 or len(candidate_runs) < 2:
        return None
    if len(control_runs) < 3:
        return None
    baseline_avg_cv = _tuning_cv([row["avg_fps"] for row in baseline_runs])
    baseline_low_cv = _tuning_cv([row["fps_1_low"] for row in baseline_runs])
    control_avg_cv = _tuning_cv([row["avg_fps"] for row in control_runs])
    control_low_cv = _tuning_cv([row["fps_1_low"] for row in control_runs])
    if baseline_avg_cv is None or baseline_avg_cv > 5 or baseline_low_cv is None or baseline_low_cv > 10:
        return None
    if control_avg_cv is None or control_avg_cv > 5 or control_low_cv is None or control_low_cv > 10:
        return None
    relevant = {}
    for variant, rows_for_variant in (
        (baseline, baseline_runs), (control, control_runs), (candidate, candidate_runs)
    ):
        bucket = relevant.setdefault(variant["variant_id"], [])
        existing_run_ids = {row["run_id"] for row in bucket}
        bucket.extend(row for row in rows_for_variant if row["run_id"] not in existing_run_ids)
    all_runs = [row for rows_for_variant in relevant.values() for row in rows_for_variant]
    if not all_runs or any(not bool(row["order_controlled"]) for row in all_runs):
        return None
    environment_hashes = {row["environment_hash"] for row in all_runs}
    if len(environment_hashes) != 1 or not next(iter(environment_hashes), ""):
        return None
    for rows_for_variant in relevant.values():
        settings_hashes = {row["settings_hash"] for row in rows_for_variant}
        if len(settings_hashes) != 1 or not next(iter(settings_hashes), ""):
            return None

    def median(rows_for_variant, key, positive=True):
        values = [
            float(row[key]) for row in rows_for_variant
            if row[key] is not None and (not positive or float(row[key]) > 0)
        ]
        return round(float(statistics.median(values)), 2) if values else None

    def delta_pct(candidate_value, control_value):
        if candidate_value is None or control_value is None or control_value == 0:
            return None
        return (candidate_value - control_value) * 100.0 / abs(control_value)

    def stutter_rate(row):
        duration = float(row["duration_sec"] or 0)
        return round(float(row["stutter_50ms"] or 0) * 60.0 / duration, 2) if duration > 0 else None

    control_fps = median(control_runs, "avg_fps")
    candidate_fps = median(candidate_runs, "avg_fps")
    control_low = median(control_runs, "fps_1_low")
    candidate_low = median(candidate_runs, "fps_1_low")
    control_p99 = median(control_runs, "p99_frame_ms")
    candidate_p99 = median(candidate_runs, "p99_frame_ms")
    control_temp = median(control_runs, "gpu_temp_avg", False)
    candidate_temp = median(candidate_runs, "gpu_temp_avg", False)
    control_power = median(control_runs, "gpu_power_avg", False)
    candidate_power = median(candidate_runs, "gpu_power_avg", False)
    control_stutters = [value for value in (stutter_rate(row) for row in control_runs) if value is not None]
    candidate_stutters = [value for value in (stutter_rate(row) for row in candidate_runs) if value is not None]
    control_stutter = round(float(statistics.median(control_stutters)), 2) if control_stutters else None
    candidate_stutter = round(float(statistics.median(candidate_stutters)), 2) if candidate_stutters else None
    if None in (
        control_fps, candidate_fps, control_low, candidate_low,
        control_p99, candidate_p99, control_temp, candidate_temp,
        control_stutter, candidate_stutter,
    ):
        return None
    avg_delta_pct = delta_pct(candidate_fps, control_fps)
    low_delta_pct = delta_pct(candidate_low, control_low)
    p99_delta_pct = delta_pct(candidate_p99, control_p99)
    stutter_delta_pct = delta_pct(candidate_stutter, control_stutter)
    power_delta_pct = delta_pct(candidate_power, control_power)
    temp_delta = candidate_temp - control_temp
    if avg_delta_pct is None or low_delta_pct is None or p99_delta_pct is None:
        return None
    threshold_pct = max(5.0, control_low_cv * 1.5)
    direction_wins = sum(1 for row in candidate_runs if float(row["fps_1_low"]) > control_low)
    required_direction_wins = int(math.ceil(len(candidate_runs) * 2.0 / 3.0))
    max_temp_increase = float(experiment["max_temp_increase"] or 0)
    max_power_increase = float(experiment["max_power_increase"] or 0)
    hard_rollback = bool(
        low_delta_pct < -5
        or avg_delta_pct < -4
        or temp_delta > max_temp_increase
        or (control_stutter == 0 and candidate_stutter > 0)
        or (stutter_delta_pct is not None and stutter_delta_pct > 20)
        or (power_delta_pct is not None and power_delta_pct > max_power_increase)
    )
    deterministic_win = bool(
        not hard_rollback
        and low_delta_pct >= threshold_pct
        and avg_delta_pct >= -2
        and candidate_stutter <= control_stutter
        and temp_delta <= max_temp_increase
        and (power_delta_pct is None or power_delta_pct <= max_power_increase)
        and direction_wins >= required_direction_wins
    )
    return {
        "experimentId": experiment["experiment_id"],
        "clientHash": experiment["client_hash"],
        "completedAt": experiment["completed_at"],
        "libraryVersion": int(experiment["library_version"]),
        "candidateVariantId": candidate["variant_id"],
        "controlVariantId": control["variant_id"],
        "groupId": candidate["group_id"],
        "thresholdPct": threshold_pct,
        "baselineNoisePct": control_low_cv,
        "avgFpsDeltaPct": avg_delta_pct,
        "fps1LowDeltaPct": low_delta_pct,
        "p99FrameMsDeltaPct": p99_delta_pct,
        "stutterDeltaPct": stutter_delta_pct,
        "gpuTempDeltaC": temp_delta,
        "gpuPowerDeltaPct": power_delta_pct,
        "directionWins": direction_wins,
        "requiredDirectionWins": required_direction_wins,
        "baselineRunIds": [row["run_id"] for row in baseline_runs],
        "controlRunIds": [row["run_id"] for row in control_runs],
        "candidateRunIds": [row["run_id"] for row in candidate_runs],
        "hardRollback": hard_rollback,
        "deterministicWin": deterministic_win,
    }


def _evaluate_tuning_comparison(experiment, variants, runs, candidate_id):
    candidate = variants.get(candidate_id)
    if not candidate or candidate["group_id"] == "baseline" or not _tuning_variant_fully_applied(candidate):
        return None
    baseline = variants.get(experiment["baseline_variant_id"])
    control = variants.get(candidate["control_variant_id"])
    if not baseline or not control or control["variant_id"] == candidate_id:
        return None
    if control["group_id"] != "baseline" and not _tuning_variant_fully_applied(control):
        return None

    def ordered(rows_for_variant):
        return sorted(
            rows_for_variant,
            key=lambda row: (int(row["sequence_no"]), int(row["completed_at"] or 0), row["run_id"]),
        )

    boundary = int(candidate["sequence_no"])
    later_boundaries = [
        int(row["sequence_no"]) for row in variants.values()
        if row["group_id"] != "baseline" and int(row["sequence_no"]) > boundary
    ]
    window_end = min(later_boundaries) if later_boundaries else None
    baseline_runs = ordered(runs.get(baseline["variant_id"], []))[:3]
    control_before_boundary = [
        row for row in ordered(runs.get(control["variant_id"], []))
        if int(row["sequence_no"]) < boundary
    ]
    if candidate["group_id"] == "G1" and len(control_before_boundary) < 4:
        return None
    control_seed = control_before_boundary[-3:]
    post_boundary = ordered(
        [
            row for variant_id in (control["variant_id"], candidate_id)
            for row in runs.get(variant_id, [])
            if int(row["sequence_no"]) >= boundary
            and (window_end is None or int(row["sequence_no"]) < window_end)
        ]
    )
    expected_initial = (candidate_id, control["variant_id"], candidate_id)
    if len(post_boundary) < 3 or tuple(row["variant_id"] for row in post_boundary[:3]) != expected_initial:
        return None
    control_runs = control_seed + [post_boundary[1]]
    candidate_runs = [post_boundary[0], post_boundary[2]]
    comparison = _evaluate_tuning_run_slice(
        experiment, baseline, control, candidate,
        baseline_runs, control_runs, candidate_runs,
    )
    if (
        comparison is not None
        and not comparison["hardRollback"]
        and not comparison["deterministicWin"]
    ):
        expected_extra = (control["variant_id"], candidate_id)
        if len(post_boundary) < 5:
            return None
        if tuple(row["variant_id"] for row in post_boundary[3:5]) != expected_extra:
            return None
        return _evaluate_tuning_run_slice(
            experiment, baseline, control, candidate,
            baseline_runs, control_runs + [post_boundary[3]],
            candidate_runs + [post_boundary[4]],
        )
    return comparison


def _evaluate_tuning_comparison_chain(experiment, variants, runs):
    current_variant_id = experiment["baseline_variant_id"]
    comparisons = {}
    candidates = sorted(
        (row for row in variants.values() if row["group_id"] != "baseline"),
        key=lambda row: (int(row["sequence_no"]), row["variant_id"]),
    )
    for candidate in candidates:
        if (
            candidate["control_variant_id"] != current_variant_id
            or not _tuning_variant_fully_applied(candidate)
        ):
            continue
        comparison = _evaluate_tuning_comparison(
            experiment, variants, runs, candidate["variant_id"]
        )
        if comparison is None:
            continue
        comparisons[candidate["variant_id"]] = comparison
        if comparison["deterministicWin"]:
            current_variant_id = candidate["variant_id"]
    return current_variant_id, comparisons


def _load_tuning_comparison(conn, experiment, candidate_id):
    variants = {
        row["variant_id"]: dict(row) for row in conn.execute(
            "SELECT * FROM tuning_variants WHERE experiment_id=?", (experiment["experiment_id"],)
        )
    }
    runs = {}
    for row in conn.execute(
        "SELECT * FROM tuning_runs WHERE experiment_id=? AND validity='valid'",
        (experiment["experiment_id"],),
    ):
        runs.setdefault(row["variant_id"], []).append(dict(row))
    return _evaluate_tuning_comparison(dict(experiment), variants, runs, candidate_id)


def _load_tuning_comparison_chain(conn, experiment):
    variants = {
        row["variant_id"]: dict(row) for row in conn.execute(
            "SELECT * FROM tuning_variants WHERE experiment_id=?", (experiment["experiment_id"],)
        )
    }
    runs = {}
    for row in conn.execute(
        "SELECT * FROM tuning_runs WHERE experiment_id=? AND validity='valid'",
        (experiment["experiment_id"],),
    ):
        runs.setdefault(row["variant_id"], []).append(dict(row))
    return _evaluate_tuning_comparison_chain(dict(experiment), variants, runs)


def _resolve_tuning_retained_variant(conn, experiment):
    return _load_tuning_comparison_chain(conn, experiment)[0]


def _record_tuning(conn, item, client_hash, now):
    tuning = item["tuning"]
    tuning_type = tuning["type"]
    experiment_id = tuning["experiment_id"]
    payload_hash = _tuning_business_hash(item)
    if tuning_type == "experiment_started":
        existing = conn.execute(
            "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
        ).fetchone()
        if existing is not None:
            if existing["client_hash"] != client_hash:
                raise TelemetryOwnershipError("experimentId belongs to another client")
            if existing["start_payload_hash"] != payload_hash:
                raise TelemetryConflictError("experimentId payload is immutable")
            return
        baseline_existing = conn.execute(
            "SELECT experiment_id FROM tuning_variants WHERE variant_id=?",
            (tuning["baseline_variant_id"],),
        ).fetchone()
        if baseline_existing is not None:
            raise TelemetryOwnershipError("baselineVariantId belongs to another experiment")
        conn.execute(
            """INSERT INTO tuning_experiments (
                   experiment_id, client_hash, created_at, status, goal, risk_level,
                   allow_reboot, allow_higher_power, max_temp_increase,
                   max_power_increase, library_version, app_version, game_version, gpu_model,
                   driver_version, baseline_variant_id, start_payload_hash
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                experiment_id, client_hash, now, tuning["status"], tuning["goal"],
                tuning["risk_level"], int(tuning["allow_reboot"]),
                int(tuning["allow_higher_power"]), tuning["max_temp_increase"],
                tuning["max_power_increase"], tuning["library_version"], item["app_version"], tuning["game_version"],
                item["gpu_model"], tuning["driver_version"], tuning["baseline_variant_id"],
                payload_hash,
            ),
        )
        conn.execute(
            """INSERT INTO tuning_variants (
                   variant_id, experiment_id, sequence_no, group_id, display_name,
                   item_set_hash, item_ids_json, source, risk_level, requires_reboot,
                   control_variant_id, status
               ) VALUES (?, ?, 0, 'baseline', ?, ?, '[]', 'manual', ?, 0, '', 'baseline')""",
            (
                tuning["baseline_variant_id"], experiment_id,
                TUNING_GROUP_LABELS["baseline"], _tuning_item_set_hash([]),
                tuning["risk_level"],
            ),
        )
        return

    experiment = _require_tuning_experiment(conn, experiment_id, client_hash)
    if tuning_type == "variant_applied":
        existing = conn.execute(
            "SELECT * FROM tuning_variants WHERE variant_id=?", (tuning["variant_id"],)
        ).fetchone()
        if existing is not None:
            if existing["experiment_id"] != experiment_id:
                raise TelemetryOwnershipError("variantId belongs to another experiment")
            if existing["payload_hash"] != payload_hash:
                raise TelemetryConflictError("variantId payload is immutable")
            return
        if experiment["completed_at"] is not None:
            raise TelemetryConflictError("experiment is terminal")
        duplicate_group = conn.execute(
            "SELECT variant_id FROM tuning_variants WHERE experiment_id=? AND group_id=?",
            (experiment_id, tuning["group_id"]),
        ).fetchone()
        if duplicate_group is not None:
            raise TelemetryConflictError("groupId was already applied in this experiment")
        if tuning["control_variant_id"] == tuning["variant_id"]:
            raise TelemetryTuningError("variant cannot control itself")
        previous_boundary = conn.execute(
            "SELECT MAX(sequence_no) FROM tuning_variants WHERE experiment_id=? AND group_id<>'baseline'",
            (experiment_id,),
        ).fetchone()[0]
        if previous_boundary is not None and tuning["sequence_no"] <= int(previous_boundary):
            raise TelemetryTuningError("variant sequence boundary must increase")
        control = _require_tuning_variant(conn, tuning["control_variant_id"], experiment_id)
        if tuning["group_id"] == "G1" and control["variant_id"] != experiment["baseline_variant_id"]:
            raise TelemetryTuningError("G1 must use baseline as control")
        if control["group_id"] != "baseline":
            if not _tuning_variant_fully_applied(control) or int(control["sequence_no"]) >= tuning["sequence_no"]:
                raise TelemetryTuningError("controlVariantId is not an earlier successful variant")
        library_groups = TUNING_LIBRARY_GROUP_ITEMS.get(int(experiment["library_version"]))
        if library_groups is None:
            raise TelemetryTuningError("unknown experiment libraryVersion")
        if tuning["group_id"] in library_groups:
            expected_items = set(_tuning_variant_items(control)) | set(library_groups[tuning["group_id"]])
            if set(tuning["item_ids"]) != expected_items:
                raise TelemetryTuningError("itemIds must equal control items plus the tested group")
        conn.execute(
            """INSERT INTO tuning_variants (
                   variant_id, experiment_id, sequence_no, group_id, display_name,
                   item_set_hash, item_ids_json, source, risk_level, requires_reboot,
                   control_variant_id, status, apply_result, applied_count, failed_count,
                   skipped_count, applied_at, payload_hash
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                tuning["variant_id"], experiment_id, tuning["sequence_no"],
                tuning["group_id"], TUNING_GROUP_LABELS[tuning["group_id"]],
                tuning["item_set_hash"],
                json.dumps(tuning["item_ids"], ensure_ascii=True, separators=(",", ":")),
                tuning["source"], tuning["risk_level"], int(tuning["requires_reboot"]),
                tuning["control_variant_id"], tuning["status"], tuning["apply_result"],
                tuning["applied_count"], tuning["failed_count"], tuning["skipped_count"],
                now, payload_hash,
            ),
        )
        conn.execute(
            "UPDATE tuning_experiments SET status=? WHERE experiment_id=?",
            ("failed" if tuning["apply_result"] == "failed" else "variant_applied", experiment_id),
        )
        return

    if tuning_type == "run_completed":
        variant = _require_tuning_variant(conn, tuning["variant_id"], experiment_id)
        existing = conn.execute(
            "SELECT * FROM tuning_runs WHERE run_id=?", (tuning["run_id"],)
        ).fetchone()
        if existing is not None:
            if existing["experiment_id"] != experiment_id or existing["variant_id"] != tuning["variant_id"]:
                raise TelemetryOwnershipError("runId belongs to another experiment or variant")
            if existing["payload_hash"] != payload_hash:
                raise TelemetryConflictError("runId payload is immutable")
            return
        if experiment["completed_at"] is not None:
            raise TelemetryConflictError("experiment is terminal")
        if variant["group_id"] != "baseline" and variant["apply_result"] not in ("succeeded", "partial"):
            raise TelemetryTuningError("variant was not applied")
        sequence_owner = conn.execute(
            "SELECT run_id FROM tuning_runs WHERE experiment_id=? AND sequence_no=?",
            (experiment_id, tuning["sequence_no"]),
        ).fetchone()
        if sequence_owner is not None:
            raise TelemetryConflictError("run sequenceNo is immutable within an experiment")
        conn.execute(
            """INSERT INTO tuning_runs (
                   run_id, experiment_id, variant_id, run_no, sequence_no, started_at,
                   completed_at, validity, invalid_reason, duration_sec, avg_fps,
                   fps_1_low, p99_frame_ms, stutter_50ms, stutter_100ms,
                   gpu_util_avg, gpu_temp_avg, gpu_power_avg, settings_hash,
                   environment_hash, order_controlled, payload_hash
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                tuning["run_id"], experiment_id, tuning["variant_id"], tuning["run_no"],
                tuning["sequence_no"], now - tuning["duration_sec"], now,
                tuning["validity"], tuning["invalid_reason"], tuning["duration_sec"],
                tuning["avg_fps"], tuning["fps_1_low"], tuning["p99_frame_ms"],
                tuning["stutter_50ms"], tuning["stutter_100ms"],
                tuning["gpu_util_avg"], tuning["gpu_temp_avg"], tuning["gpu_power_avg"],
                tuning["settings_hash"], tuning["environment_hash"],
                int(tuning["order_controlled"]), payload_hash,
            ),
        )
        next_status = "baseline_complete" if variant["group_id"] == "baseline" else "variant_complete"
        conn.execute(
            "UPDATE tuning_experiments SET status=? WHERE experiment_id=?",
            (next_status, experiment_id),
        )
        return

    if experiment["completed_at"] is not None:
        if experiment["completion_payload_hash"] == payload_hash:
            return
        raise TelemetryConflictError("terminal experiment is immutable")
    winning_variant_id = tuning["winning_variant_id"] or None
    if winning_variant_id:
        winner = _require_tuning_variant(conn, winning_variant_id, experiment_id)
        if not _tuning_variant_fully_applied(winner):
            raise TelemetryTuningError("winning variant was not fully applied")
        winner_comparison = _load_tuning_comparison(conn, experiment, winning_variant_id)
        if winner_comparison is None:
            raise TelemetryTuningError("winning variant lacks a qualified comparison")
        if not winner_comparison["deterministicWin"]:
            raise TelemetryTuningError("winning variant does not meet the deterministic win rule")
        if _resolve_tuning_retained_variant(conn, experiment) != winning_variant_id:
            raise TelemetryTuningError("winning variant is not the retained comparison-chain endpoint")
    elif tuning["result"] == "no_significant_gain":
        if _resolve_tuning_retained_variant(conn, experiment) != experiment["baseline_variant_id"]:
            raise TelemetryTuningError("no_significant_gain conflicts with a deterministic win")
    conn.execute(
        """UPDATE tuning_experiments SET completed_at=?, status=?, winning_variant_id=?,
                  result=?, stop_reason=?, auto_rollback=?, completion_payload_hash=?
            WHERE experiment_id=?""",
        (
            now, tuning["status"], winning_variant_id, tuning["result"],
            tuning["stop_reason"], int(tuning["auto_rollback"]), payload_hash, experiment_id,
        ),
    )
    if tuning["auto_rollback"]:
        conn.execute(
            """UPDATE tuning_variants SET restored_at=COALESCE(restored_at, ?)
                WHERE experiment_id=? AND group_id<>'baseline'""",
            (now, experiment_id),
        )


def _record_telemetry(payload, now=None):
    item = _normalize_telemetry(payload)
    now = int(time.time() if now is None else now)
    # 运营报表、自然日限额和客户端页面统一使用北京时间（UTC+8）。
    day = dt.datetime.fromtimestamp(now, REPORT_TIMEZONE).date().isoformat()
    client_hash = _client_hash(item["install_id"])
    event = item["event"]
    authenticated = _telemetry_auth(item, now)
    if event == "tuning" and not authenticated:
        raise TelemetryAuthError("device token required for tuning")
    if not authenticated and _version_tuple(item["app_version"]) >= TOKEN_REQUIRED_VERSION:
        raise TelemetryAuthError("device token required for this client version")
    if event == "performance":
        _validate_performance(item, authenticated)
    if event == "tuning" and (not item["gpu_model_verified"] or not item["gpu_model"]):
        raise TelemetryTuningError("verified gpu model is required")
    counters = {
        "launches": 1 if event == "launch" else 0,
        "applies": 1 if event == "apply" else 0,
        "restores": 1 if event == "restore" else 0,
        "apply_ok": item["ok"] if event == "apply" else 0,
        "apply_failed": item["failed"] if event == "apply" else 0,
        "restore_ok": item["ok"] if event == "restore" else 0,
        "restore_failed": item["failed"] if event == "restore" else 0,
        "trusted_launches": 1 if authenticated and event == "launch" else 0,
        "trusted_applies": 1 if authenticated and event == "apply" else 0,
        "trusted_restores": 1 if authenticated and event == "restore" else 0,
    }
    conn = _connect()
    try:
        with conn:
            if authenticated:
                try:
                    conn.execute(
                        "INSERT INTO telemetry_replays (client_hash, event_id, seen_at) VALUES (?, ?, ?)",
                        (client_hash, item["event_id"], now),
                    )
                except sqlite3.IntegrityError:
                    raise TelemetryReplayError("duplicate event")
            if event == "performance":
                count = conn.execute(
                    "SELECT COUNT(*) FROM performance_sessions WHERE client_hash=? AND day=?",
                    (client_hash, day),
                ).fetchone()[0]
                if count >= PERFORMANCE_DAILY_LIMIT:
                    raise TelemetryDailyLimitError("daily performance limit reached")
            if event == "tuning":
                day_start = now - (now % 86400)
                count = conn.execute(
                    "SELECT COUNT(*) FROM tuning_events WHERE client_hash=? AND seen_at>=?",
                    (client_hash, day_start),
                ).fetchone()[0]
                if count >= TUNING_DAILY_LIMIT:
                    raise TelemetryDailyLimitError("daily tuning limit reached")
                conn.execute(
                    "INSERT INTO tuning_events (client_hash, event_id, seen_at) VALUES (?, ?, ?)",
                    (client_hash, item["event_id"], now),
                )
            conn.execute(
            """
            INSERT INTO clients (
                client_hash, first_seen, last_seen, app_version, os_name, os_build,
                cpu_model, gpu_vendor, gpu_model, gpu_model_verified, ram_gb, device_type,
                authenticated_last_seen
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                device_type=CASE WHEN excluded.device_type<>'' THEN excluded.device_type ELSE clients.device_type END,
                authenticated_last_seen=MAX(clients.authenticated_last_seen, excluded.authenticated_last_seen)
            """,
            (
                client_hash, now, now, item["app_version"], item["os_name"], item["os_build"],
                item["cpu_model"], item["gpu_vendor"], item["gpu_model"],
                item["gpu_model_verified"], item["ram_gb"], item["device_type"],
                now if authenticated else 0,
            ),
        )
            if event == "performance":
                conn.execute(
                    """
                    INSERT INTO performance_sessions (
                        client_hash, recorded_at, day, app_version, gpu_model, config_tier, duration_sec,
                        avg_fps, fps_1_low, gpu_util_avg, gpu_util_max, gpu_temp_avg,
                        gpu_temp_max, gpu_power_avg, gpu_power_max, authenticated
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        client_hash, now, day, item["app_version"], item["gpu_model"], item["config_tier"],
                        item["duration_sec"], item["avg_fps"], item["fps_1_low"],
                        item["gpu_util_avg"], item["gpu_util_max"], item["gpu_temp_avg"],
                        item["gpu_temp_max"], item["gpu_power_avg"], item["gpu_power_max"],
                        1 if authenticated else 0,
                    ),
                )
            elif event == "tuning":
                _record_tuning(conn, item, client_hash, now)
            conn.execute(
            """
            INSERT INTO daily_usage (
                day, client_hash, launches, applies, restores, apply_ok, apply_failed, restore_failed,
                trusted_launches, trusted_applies, trusted_restores, restore_ok
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(day, client_hash) DO UPDATE SET
                launches=daily_usage.launches+excluded.launches,
                applies=daily_usage.applies+excluded.applies,
                restores=daily_usage.restores+excluded.restores,
                apply_ok=daily_usage.apply_ok+excluded.apply_ok,
                apply_failed=daily_usage.apply_failed+excluded.apply_failed,
                restore_ok=daily_usage.restore_ok+excluded.restore_ok,
                restore_failed=daily_usage.restore_failed+excluded.restore_failed,
                trusted_launches=daily_usage.trusted_launches+excluded.trusted_launches,
                trusted_applies=daily_usage.trusted_applies+excluded.trusted_applies,
                trusted_restores=daily_usage.trusted_restores+excluded.trusted_restores
            """,
            (
                day, client_hash, counters["launches"], counters["applies"], counters["restores"],
                counters["apply_ok"], counters["apply_failed"], counters["restore_failed"],
                counters["trusted_launches"], counters["trusted_applies"], counters["trusted_restores"],
                counters["restore_ok"],
            ),
            )
    finally:
        conn.close()
    return {
        "trusted": authenticated,
        "performanceAccepted": event == "performance",
        "tuningAccepted": event == "tuning",
        "tuningType": item["tuning"]["type"] if event == "tuning" else None,
    }


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


def _median_metric(rows, key, minimum):
    values = [float(row[key]) for row in rows if row.get(key) is not None and float(row[key]) > 0]
    return round(float(statistics.median(values)), 1) if len(values) >= minimum else None


def _aggregate_performance(rows, minimum=PERFORMANCE_MIN_SAMPLES):
    client_count = len({row["client_hash"] for row in rows})
    result = {
        "sessions": len(rows),
        "clients": client_count,
        # 同一设备一天可产生多段会话；门槛必须按独立匿名设备计算，否则单机重复
        # 采样就能让总体或某显卡分组达到公开条件。
        "published": len(rows) >= minimum and client_count >= minimum,
    }
    mapping = {
        "avgFps": "avg_fps",
        "fps1Low": "fps_1_low",
        "gpuUtil": "gpu_util_avg",
        "gpuTemp": "gpu_temp_avg",
        "gpuPower": "gpu_power_avg",
    }
    for output_key, row_key in mapping.items():
        result[output_key] = _median_metric(rows, row_key, minimum) if result["published"] else None
    return result


def _summarize_performance_pairs(rows):
    metric_keys = ("fpsDelta", "fps1LowDelta", "gpuUtilDelta", "gpuTempDelta", "gpuPowerDelta")
    client_count = len({row["client_hash"] for row in rows})
    result = {
        "comparisons": len(rows),
        "matchedClients": client_count,
        "published": len(rows) >= PERFORMANCE_MIN_COMPARISONS and client_count >= PERFORMANCE_MIN_COMPARISONS,
    }
    for key in metric_keys:
        values = [float(row[key]) for row in rows if row.get(key) is not None]
        observed_key = "observed" + key[0].upper() + key[1:]
        result[observed_key] = round(float(statistics.median(values)), 1) if values else None
        result[key] = (
            round(float(statistics.median(values)), 1)
            if result["published"] and len(values) >= PERFORMANCE_MIN_COMPARISONS
            else None
        )
    return result


def _performance_views(rows):
    overall = _aggregate_performance(rows)

    gpu_groups = {}
    tier_groups = {tier: [] for tier in CONFIG_TIERS}
    client_tiers = {}
    for row in rows:
        if row["gpu_model"]:
            gpu_groups.setdefault(row["gpu_model"], []).append(row)
        if row["config_tier"] in tier_groups:
            tier_groups[row["config_tier"]].append(row)
            key = (row["client_hash"], row["gpu_model"], row["config_tier"])
            client_tiers.setdefault(key, []).append(row)

    by_gpu = []
    for label, group in gpu_groups.items():
        aggregate = _aggregate_performance(group)
        if aggregate["published"]:
            aggregate["label"] = label
            by_gpu.append(aggregate)
    by_gpu.sort(key=lambda row: (-row["sessions"], row["label"]))
    by_gpu = by_gpu[:12]

    tier_medians = {key: _aggregate_performance(group, minimum=1) for key, group in client_tiers.items()}
    paired_rows = []
    for (client_hash, gpu_model, tier), optimized in tier_medians.items():
        if tier == "baseline":
            continue
        baseline = tier_medians.get((client_hash, gpu_model, "baseline"))
        if not baseline:
            continue
        paired_rows.append({
            "client_hash": client_hash,
            "gpu_model": gpu_model,
            "tier": tier,
            "fpsDelta": optimized["avgFps"] - baseline["avgFps"],
            "fps1LowDelta": optimized["fps1Low"] - baseline["fps1Low"],
            "gpuUtilDelta": _metric_delta(optimized, baseline, "gpuUtil"),
            "gpuTempDelta": _metric_delta(optimized, baseline, "gpuTemp"),
            "gpuPowerDelta": _metric_delta(optimized, baseline, "gpuPower"),
        })

    pair_summaries = {
        tier: _summarize_performance_pairs([row for row in paired_rows if row["tier"] == tier])
        for tier in CONFIG_TIERS[1:]
    }
    empty_pair_summary = _summarize_performance_pairs([])
    by_config = []
    for tier in CONFIG_TIERS:
        aggregate = _aggregate_performance(tier_groups[tier])
        aggregate["tier"] = tier
        aggregate["label"] = CONFIG_TIER_LABELS[tier]
        pair_summary = pair_summaries.get(tier, empty_pair_summary)
        aggregate.update({key: value for key, value in pair_summary.items() if key != "published"})
        aggregate["comparisonPublished"] = pair_summary["published"]
        by_config.append(aggregate)

    return overall, by_gpu, by_config, _summarize_performance_pairs(paired_rows)


def _performance_gpu_inventory(rows):
    """Private admin inventory: show collected rows without publishing weak conclusions."""
    groups = {}
    for row in rows:
        if row.get("gpu_model"):
            groups.setdefault(row["gpu_model"], []).append(row)
    result = []
    for label, group in groups.items():
        trusted = [row for row in group if int(row.get("authenticated") or 0) == 1]
        metric_rows = trusted if trusted else group
        display = _aggregate_performance(metric_rows, minimum=1)
        publish = _aggregate_performance(trusted)
        result.append({
            "label": label,
            "sessions": len(group),
            "clients": len({row["client_hash"] for row in group}),
            "trustedSessions": len(trusted),
            "trustedClients": len({row["client_hash"] for row in trusted}),
            "legacySessions": len(group) - len(trusted),
            "quality": "trusted" if trusted else "legacy",
            "published": publish["published"],
            "avgFps": display["avgFps"],
            "fps1Low": display["fps1Low"],
            "gpuUtil": display["gpuUtil"],
            "gpuTemp": display["gpuTemp"],
            "gpuPower": display["gpuPower"],
        })
    result.sort(key=lambda row: (-row["sessions"], row["label"]))
    return result[:30]


def _metric_delta(optimized, baseline, key):
    if optimized.get(key) is None or baseline.get(key) is None:
        return None
    return optimized[key] - baseline[key]


def _build_stats(now=None, days=30):
    now = int(time.time() if now is None else now)
    now_local = dt.datetime.fromtimestamp(now, REPORT_TIMEZONE)
    today = now_local.date()
    start_day = today - dt.timedelta(days=days - 1)
    midnight = int(dt.datetime.combine(today, dt.time.min, tzinfo=REPORT_TIMEZONE).timestamp())
    current_hour = now_local.replace(minute=0, second=0, microsecond=0)
    hourly_start = current_hour - dt.timedelta(hours=23)
    hourly_start_ts = int(hourly_start.timestamp())
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
        usage_rows = {row["day"]: dict(row) for row in conn.execute(
            """SELECT day, SUM(launches) launches, SUM(applies) applies,
                      SUM(restores) restores FROM daily_usage WHERE day>=? GROUP BY day""",
            (start_day.isoformat(),),
        )}
        daily_active_rows = {row["day"]: row["active"] for row in conn.execute(
            """SELECT date(seen_at, 'unixepoch', '+8 hours') day,
                      COUNT(DISTINCT client_hash) active
                 FROM telemetry_replays WHERE seen_at>=? GROUP BY day""",
            (int(dt.datetime.combine(start_day, dt.time.min, tzinfo=REPORT_TIMEZONE).timestamp()),),
        )}
        new_rows = {row["day"]: row["new_users"] for row in conn.execute(
            """SELECT date(first_seen, 'unixepoch', '+8 hours') day, COUNT(*) new_users
                 FROM clients WHERE first_seen>=? GROUP BY day""",
            (int(dt.datetime.combine(start_day, dt.time.min, tzinfo=REPORT_TIMEZONE).timestamp()),),
        )}
        hourly_active_rows = {row["hour"]: row["active"] for row in conn.execute(
            """SELECT strftime('%Y-%m-%dT%H:00+08:00', seen_at, 'unixepoch', '+8 hours') hour,
                      COUNT(DISTINCT client_hash) active
                 FROM telemetry_replays
                WHERE seen_at>=? AND seen_at<=? GROUP BY hour""",
            (hourly_start_ts, now),
        )}
        hourly_new_rows = {row["hour"]: row["new_users"] for row in conn.execute(
            """SELECT strftime('%Y-%m-%dT%H:00+08:00', first_seen, 'unixepoch', '+8 hours') hour,
                      COUNT(*) new_users
                 FROM clients
                WHERE first_seen>=? AND first_seen<=? GROUP BY hour""",
            (hourly_start_ts, now),
        )}
        versions = _rows(conn, "SELECT app_version label, COUNT(*) value FROM clients WHERE app_version<>'' GROUP BY app_version ORDER BY value DESC, label DESC LIMIT 12")
        gpus = _rows(conn, "SELECT gpu_model label, COUNT(*) value FROM clients WHERE gpu_model<>'' AND gpu_model_verified=1 GROUP BY gpu_model ORDER BY value DESC, label LIMIT 12")
        gpus_by_device = {
            "all": gpus,
            "desktop": _rows(conn, "SELECT gpu_model label, COUNT(*) value FROM clients WHERE gpu_model<>'' AND gpu_model_verified=1 AND device_type='desktop' GROUP BY gpu_model ORDER BY value DESC, label LIMIT 12"),
            "laptop": _rows(conn, "SELECT gpu_model label, COUNT(*) value FROM clients WHERE gpu_model<>'' AND gpu_model_verified=1 AND device_type='laptop' GROUP BY gpu_model ORDER BY value DESC, label LIMIT 12"),
        }
        vendors = _rows(conn, "SELECT gpu_vendor label, COUNT(*) value FROM clients WHERE gpu_vendor<>'' GROUP BY gpu_vendor ORDER BY value DESC, label LIMIT 8")
        systems = _rows(conn, "SELECT (os_name || CASE WHEN os_build<>'' THEN ' · ' || os_build ELSE '' END) label, COUNT(*) value FROM clients WHERE os_name<>'' GROUP BY label ORDER BY value DESC, label LIMIT 12")
        devices = _rows(conn, "SELECT device_type label, COUNT(*) value FROM clients WHERE device_type<>'' GROUP BY device_type ORDER BY value DESC, label")
        ram_values = [tuple(row) for row in conn.execute(
            "SELECT ram_gb, 1 weight FROM clients WHERE ram_gb>0"
        )]
        all_performance_rows = _rows(
            conn,
            """SELECT ps.client_hash, ps.gpu_model, ps.config_tier, ps.avg_fps, ps.fps_1_low,
                      ps.gpu_util_avg, ps.gpu_temp_avg, ps.gpu_power_avg, ps.authenticated,
                      COALESCE(c.device_type, '') device_type
                 FROM performance_sessions ps
                 LEFT JOIN clients c ON c.client_hash=ps.client_hash
                WHERE ps.day>=?""",
            (start_day.isoformat(),),
        )
        performance_rows = [row for row in all_performance_rows if int(row.get("authenticated") or 0) == 1]
        legacy_performance_sessions = len(all_performance_rows) - len(performance_rows)
        authenticated_clients = conn.execute(
            "SELECT COUNT(*) FROM clients WHERE authenticated_last_seen>0"
        ).fetchone()[0]
        trusted_usage = dict(conn.execute(
            """SELECT COALESCE(SUM(trusted_launches),0) launches,
                      COALESCE(SUM(trusted_applies),0) applies,
                      COALESCE(SUM(trusted_restores),0) restores
                 FROM daily_usage WHERE day>=?""",
            (start_day.isoformat(),),
        ).fetchone())
    finally:
        conn.close()

    performance, _, performance_by_config, performance_improvement = _performance_views(
        performance_rows
    )
    performance_by_gpu = _performance_gpu_inventory(all_performance_rows)
    performance_by_gpu_by_device = {
        "all": performance_by_gpu,
        "desktop": _performance_gpu_inventory([
            row for row in all_performance_rows if row.get("device_type") == "desktop"
        ]),
        "laptop": _performance_gpu_inventory([
            row for row in all_performance_rows if row.get("device_type") == "laptop"
        ]),
    }

    ram_buckets = {"≤8 GB": 0, "9–16 GB": 0, "17–32 GB": 0, "33–64 GB": 0, ">64 GB": 0}
    for ram, weight in ram_values:
        if ram <= 8:
            ram_buckets["≤8 GB"] += weight
        elif ram <= 16:
            ram_buckets["9–16 GB"] += weight
        elif ram <= 32:
            ram_buckets["17–32 GB"] += weight
        elif ram <= 64:
            ram_buckets["33–64 GB"] += weight
        else:
            ram_buckets[">64 GB"] += weight

    daily = []
    for offset in range(days):
        day = start_day + dt.timedelta(days=offset)
        row = usage_rows.get(day.isoformat(), {})
        daily.append({
            "day": day.isoformat(),
            "active": int(daily_active_rows.get(day.isoformat(), 0)),
            "newUsers": int(new_rows.get(day.isoformat(), 0)),
            "launches": int(row.get("launches") or 0),
            "applies": int(row.get("applies") or 0),
            "restores": int(row.get("restores") or 0),
        })
    hourly = []
    for offset in range(24):
        hour = hourly_start + dt.timedelta(hours=offset)
        hour_key = hour.strftime("%Y-%m-%dT%H:00+08:00")
        hourly.append({
            "hour": hour_key,
            "active": int(hourly_active_rows.get(hour_key, 0)),
            "newUsers": int(hourly_new_rows.get(hour_key, 0)),
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
        "hourly": hourly,
        "versions": versions,
        "gpus": gpus,
        "gpusByDevice": gpus_by_device,
        "gpuVendors": vendors,
        "systems": systems,
        "devices": devices,
        "ram": [{"label": key, "value": value} for key, value in ram_buckets.items()],
        "performance": performance,
        "performanceByGpu": performance_by_gpu,
        "performanceByGpuByDevice": performance_by_gpu_by_device,
        "performanceByConfig": performance_by_config,
        "performanceImprovement": performance_improvement,
        "dataQuality": {
            "source": "client_self_reported",
            "sourceLabel": "客户端自报，未经独立测量验证",
            "aggregation": "median",
            "minAggregateSamples": PERFORMANCE_MIN_SAMPLES,
            "minAggregateClients": PERFORMANCE_MIN_SAMPLES,
            "minComparisonSamples": PERFORMANCE_MIN_COMPARISONS,
            "authenticatedClients": int(authenticated_clients),
            "legacyClients": int(total_users - authenticated_clients),
            "weightedUsers": round(authenticated_clients + (total_users - authenticated_clients) * 0.25, 1),
            "trustedPerformanceSessions": int(performance["sessions"]),
            "legacyPerformanceSessionsExcluded": int(legacy_performance_sessions),
            "trustedLaunches": int(trusted_usage["launches"]),
            "weightedLaunches": round(
                trusted_usage["launches"] + (sums["launches"] - trusted_usage["launches"]) * 0.25,
                1,
            ),
            "telemetryRetentionDays": TELEMETRY_KEEP_DAYS,
            "hourlyActivitySource": "authenticated_event_receipts",
            "hourlyWindowHours": 24,
            "reportTimezone": "Asia/Shanghai",
            "reportUtcOffset": "+08:00",
        },
        "diagnosticReports": _report_summary(),
    }


def _build_public_stats(now=None):
    """Small aggregate-only payload for the public homepage."""
    now = int(time.time() if now is None else now)
    now_local = dt.datetime.fromtimestamp(now, REPORT_TIMEZONE)
    midnight = int(dt.datetime.combine(now_local.date(), dt.time.min, tzinfo=REPORT_TIMEZONE).timestamp())
    conn = _connect()
    try:
        totals = dict(conn.execute(
            """SELECT COALESCE(SUM(launches),0) launches,
                      COALESCE(SUM(applies),0) applies,
                      COALESCE(SUM(apply_ok),0) apply_ok
                 FROM daily_usage"""
        ).fetchone())
        return {
            "generatedAt": now,
            "users": int(conn.execute("SELECT COUNT(*) FROM clients").fetchone()[0]),
            "active7d": int(conn.execute(
                "SELECT COUNT(*) FROM clients WHERE last_seen>=?", (now - 7 * 86400,)
            ).fetchone()[0]),
            "active15m": int(conn.execute(
                "SELECT COUNT(*) FROM clients WHERE last_seen>=?", (now - 900,)
            ).fetchone()[0]),
            "launchesToday": int(conn.execute(
                "SELECT COALESCE(SUM(launches),0) FROM daily_usage WHERE day=?",
                (now_local.date().isoformat(),),
            ).fetchone()[0]),
            "totalLaunches": int(totals["launches"]),
            "totalApplies": int(totals["applies"]),
            "totalApplyOk": int(totals["apply_ok"]),
            "timezone": "Asia/Shanghai",
        }
    finally:
        conn.close()


def _latest_complete_week_start(now=None):
    now = int(time.time() if now is None else now)
    # Admin 周报按官网运营所在地（Asia/Taipei，UTC+8）的自然周展示。
    # 例如台北时间周一 00:00 后，应立即把刚结束的周一至周日作为“最近完整周”，
    # 不能再等到 UTC 周一，否则周一早上会错误地落后整整一周。
    today = dt.datetime.fromtimestamp(now, REPORT_TIMEZONE).date()
    return today - dt.timedelta(days=today.weekday() + 7)


def _taipei_today(now=None):
    now = int(time.time() if now is None else now)
    return dt.datetime.fromtimestamp(now, REPORT_TIMEZONE).date()


def _report_number(week_start):
    """Return the stable product-report number; the 2026-08-03 week is report 1."""
    if week_start < REPORTING_EPOCH_WEEK:
        return None
    return ((week_start - REPORTING_EPOCH_WEEK).days // 7) + 1


def _parse_week_start(value=None, now=None):
    if value in (None, ""):
        return _latest_complete_week_start(now)
    value = str(value)
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise ValueError("weekStart must be YYYY-MM-DD")
    try:
        result = dt.date.fromisoformat(value)
    except ValueError:
        raise ValueError("weekStart is not a valid date")
    if result.isoformat() != value or result.weekday() != 0:
        raise ValueError("weekStart must be a Monday")
    return result


def _parse_period_date(name, value):
    value = str(value)
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise ValueError("%s must be YYYY-MM-DD" % name)
    try:
        result = dt.date.fromisoformat(value)
    except ValueError:
        raise ValueError("%s is not a valid date" % name)
    if result.isoformat() != value:
        raise ValueError("%s must be YYYY-MM-DD" % name)
    return result


def _parse_custom_period(
    start_value, end_value, now=None,
    comparison_start_value=None, comparison_end_value=None,
):
    if start_value in (None, "") or end_value in (None, ""):
        raise ValueError("startDate and endDate must be provided together")
    start = _parse_period_date("startDate", start_value)
    end = _parse_period_date("endDate", end_value)
    days = (end - start).days + 1
    if days < 1:
        raise ValueError("startDate must not be after endDate")
    if days > CUSTOM_PERIOD_MAX_DAYS:
        raise ValueError("custom period must be between 1 and %d days" % CUSTOM_PERIOD_MAX_DAYS)
    if end > _taipei_today(now):
        raise ValueError("endDate must not be in the future")
    try:
        start - dt.timedelta(days=days * 7)
    except OverflowError:
        raise ValueError("startDate is too early")
    has_comparison = comparison_start_value not in (None, "") or comparison_end_value not in (None, "")
    comparison_start = None
    comparison_end = None
    if has_comparison:
        if comparison_start_value in (None, "") or comparison_end_value in (None, ""):
            raise ValueError("compareStartDate and compareEndDate must be provided together")
        comparison_start = _parse_period_date("compareStartDate", comparison_start_value)
        comparison_end = _parse_period_date("compareEndDate", comparison_end_value)
        comparison_days = (comparison_end - comparison_start).days + 1
        if comparison_days != days:
            raise ValueError("comparison period must have the same number of days")
        if comparison_end > _taipei_today(now):
            raise ValueError("compareEndDate must not be in the future")
    return CustomPeriod(start, end, comparison_start, comparison_end)


def _parse_weekly_query(raw_path, now=None):
    parsed = urllib.parse.urlsplit(raw_path)
    if len(parsed.query) > 512:
        raise ValueError("query too long")
    pairs = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    allowed = {
        "weekStart", "startDate", "endDate", "compareStartDate", "compareEndDate",
        "version", "gpu", "deviceType",
        "validOnly", "live",
    }
    values = {}
    for key, value in pairs:
        if key not in allowed or key in values:
            raise ValueError("invalid or duplicate query parameter")
        values[key] = value
    filters = {}
    for key, maximum in WEEKLY_FILTER_LIMITS.items():
        value = values.get(key, "").strip()
        if len(value) > maximum or any(ord(char) < 32 for char in value):
            raise ValueError("invalid %s filter" % key)
        if key == "version" and value and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+\-]{0,23}", value):
            raise ValueError("invalid version filter")
        filters[key] = value or None
    valid_text = values.get("validOnly", "0").lower()
    if valid_text not in ("0", "1", "false", "true"):
        raise ValueError("validOnly must be 0 or 1")
    filters["validOnly"] = valid_text in ("1", "true")
    live_text = values.get("live", "0")
    if live_text not in ("0", "1"):
        raise ValueError("live must be 0 or 1")
    has_custom_dates = "startDate" in values or "endDate" in values
    if has_custom_dates:
        if "weekStart" in values:
            raise ValueError("weekStart cannot be combined with startDate or endDate")
        period = _parse_custom_period(
            values.get("startDate"), values.get("endDate"), now,
            values.get("compareStartDate"), values.get("compareEndDate"),
        )
    else:
        if "compareStartDate" in values or "compareEndDate" in values:
            raise ValueError("comparison dates require startDate and endDate")
        period = _parse_week_start(values.get("weekStart"), now)
    return period, filters, live_text == "1"


def _default_weekly_filters():
    return {"version": None, "gpu": None, "deviceType": None, "validOnly": False}


def _filters_are_default(filters):
    return not filters.get("version") and not filters.get("gpu") and not filters.get("deviceType") and not filters.get("validOnly")


def _client_filter_sql(filters, alias="c"):
    clauses = []
    args = []
    mapping = (("version", "app_version"), ("gpu", "gpu_model"), ("deviceType", "device_type"))
    for filter_key, column in mapping:
        if filters.get(filter_key):
            clauses.append("%s.%s=?" % (alias, column))
            args.append(filters[filter_key])
    if filters.get("validOnly"):
        clauses.append("%s.authenticated_last_seen>0" % alias)
    return (" AND " + " AND ".join(clauses)) if clauses else "", args


def _date_timestamp(value):
    return int(dt.datetime.combine(value, dt.time.min, tzinfo=dt.timezone.utc).timestamp())


def _change_pct(current, previous):
    if current is None or previous is None or float(previous) == 0:
        return None
    return round((float(current) - float(previous)) * 100.0 / abs(float(previous)), 1)


def _metric_comparison(current, previous, **extra):
    result = {"current": current, "previous": previous, "changePct": _change_pct(current, previous)}
    result.update(extra)
    return result


def _period_usage(conn, start, end, filters):
    where, args = _client_filter_sql(filters)
    usage = dict(conn.execute(
        """SELECT COUNT(DISTINCT du.client_hash) active_users,
                  COUNT(DISTINCT CASE WHEN du.applies>0 THEN du.client_hash END) apply_devices,
                  COALESCE(SUM(du.launches),0) launches,
                  COALESCE(SUM(du.applies),0) applies,
                  COALESCE(SUM(du.restores),0) restores,
                  COALESCE(SUM(du.apply_ok),0) apply_ok,
                  COALESCE(SUM(du.apply_failed),0) apply_failed,
                  COALESCE(SUM(du.restore_ok),0) restore_ok,
                  COALESCE(SUM(du.restore_failed),0) restore_failed
             FROM daily_usage du JOIN clients c ON c.client_hash=du.client_hash
            WHERE du.day>=? AND du.day<?""" + where,
        [start.isoformat(), end.isoformat()] + args,
    ).fetchone())
    first_start = _date_timestamp(start)
    first_end = _date_timestamp(end)
    new_users = conn.execute(
        "SELECT COUNT(*) FROM clients c WHERE c.first_seen>=? AND c.first_seen<?" + where,
        [first_start, first_end] + args,
    ).fetchone()[0]
    return {
        "newUsers": int(new_users),
        "activeUsers": int(usage["active_users"] or 0),
        "launches": int(usage["launches"] or 0),
        "applyDevices": int(usage["apply_devices"] or 0),
        "applies": int(usage["applies"] or 0),
        "restores": int(usage["restores"] or 0),
        "applyOk": int(usage["apply_ok"] or 0),
        "applyFailures": int(usage["apply_failed"] or 0),
        "restoreOk": int(usage["restore_ok"] or 0),
        "restoreFailures": int(usage["restore_failed"] or 0),
    }


def _weekly_performance_rows(conn, start, end, filters):
    where, args = _client_filter_sql(filters)
    return _rows(
        conn,
        """SELECT ps.client_hash, ps.gpu_model, ps.config_tier, ps.avg_fps,
                  ps.fps_1_low, ps.gpu_util_avg, ps.gpu_temp_avg, ps.gpu_power_avg,
                  c.gpu_model profile_gpu_model, c.app_version profile_version,
                  c.device_type profile_device_type
             FROM performance_sessions ps JOIN clients c ON c.client_hash=ps.client_hash
            WHERE ps.day>=? AND ps.day<? AND ps.authenticated=1""" + where,
        [start.isoformat(), end.isoformat()] + args,
    )


def _weekly_performance_counts(conn, start, end, filters):
    """Expose collection, trust and device counts without mixing their meanings."""
    raw_filters = dict(filters)
    raw_filters["validOnly"] = False
    raw_where, raw_args = _client_filter_sql(raw_filters)
    raw_sessions = conn.execute(
        """SELECT COUNT(*)
             FROM performance_sessions ps JOIN clients c ON c.client_hash=ps.client_hash
            WHERE ps.day>=? AND ps.day<?""" + raw_where,
        [start.isoformat(), end.isoformat()] + raw_args,
    ).fetchone()[0]
    trusted_where, trusted_args = _client_filter_sql(filters)
    trusted = conn.execute(
        """SELECT COUNT(*) trusted_sessions,
                  COUNT(DISTINCT ps.client_hash) trusted_clients
             FROM performance_sessions ps JOIN clients c ON c.client_hash=ps.client_hash
            WHERE ps.day>=? AND ps.day<? AND ps.authenticated=1""" + trusted_where,
        [start.isoformat(), end.isoformat()] + trusted_args,
    ).fetchone()
    return {
        "rawSessions": int(raw_sessions or 0),
        "trustedSessions": int(trusted["trusted_sessions"] or 0),
        "trustedClients": int(trusted["trusted_clients"] or 0),
    }


def _median_positive(rows, key):
    values = [float(row[key]) for row in rows if row.get(key) is not None and float(row[key]) > 0]
    return float(statistics.median(values)) if values else None


def _weekly_performance_pairs(rows):
    groups = {}
    for row in rows:
        tier = row.get("config_tier")
        gpu_model = row.get("gpu_model") or ""
        if tier not in CONFIG_TIERS or not gpu_model:
            continue
        groups.setdefault((row["client_hash"], gpu_model, tier), []).append(row)
    medians = {}
    for key, group in groups.items():
        medians[key] = {
            "avgFps": _median_positive(group, "avg_fps"),
            "fps1Low": _median_positive(group, "fps_1_low"),
            "gpuUtil": _median_positive(group, "gpu_util_avg"),
            "gpuTemp": _median_positive(group, "gpu_temp_avg"),
            "gpuPower": _median_positive(group, "gpu_power_avg"),
            "profileGpu": group[-1].get("profile_gpu_model") or gpu_model,
        }
    pairs = []
    for (client_hash, gpu_model, tier), optimized in medians.items():
        if tier == "baseline":
            continue
        baseline = medians.get((client_hash, gpu_model, "baseline"))
        if not baseline or baseline["avgFps"] is None or optimized["avgFps"] is None:
            continue
        fps_delta = optimized["avgFps"] - baseline["avgFps"]
        fps_pct = fps_delta * 100.0 / baseline["avgFps"] if baseline["avgFps"] > 0 else None
        pairs.append({
            "clientHash": client_hash,
            "gpuModel": gpu_model,
            "profileGpu": optimized["profileGpu"],
            "tier": tier,
            "fpsDelta": fps_delta,
            "fpsDeltaPct": fps_pct,
            "fps1LowDelta": _optional_delta(optimized, baseline, "fps1Low"),
            "gpuUtilDelta": _optional_delta(optimized, baseline, "gpuUtil"),
            "gpuTempDelta": _optional_delta(optimized, baseline, "gpuTemp"),
            "gpuPowerDelta": _optional_delta(optimized, baseline, "gpuPower"),
        })
    return pairs


def _optional_delta(optimized, baseline, key):
    if optimized.get(key) is None or baseline.get(key) is None:
        return None
    return optimized[key] - baseline[key]


def _percentile(values, fraction):
    ordered = sorted(float(value) for value in values)
    if not ordered:
        return None
    position = (len(ordered) - 1) * fraction
    lower = int(math.floor(position))
    upper = int(math.ceil(position))
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def _delta_distribution(rows, key, published):
    values = [float(row[key]) for row in rows if row.get(key) is not None]
    if not published or len(values) < PERFORMANCE_MIN_COMPARISONS:
        return {"median": None, "mean": None, "p25": None, "p75": None}
    return {
        "median": round(float(statistics.median(values)), 1),
        "mean": round(float(statistics.mean(values)), 1),
        "p25": round(float(_percentile(values, 0.25)), 1),
        "p75": round(float(_percentile(values, 0.75)), 1),
    }


def _weekly_pair_summary(rows):
    clients = {row["clientHash"] for row in rows}
    published = len(rows) >= PERFORMANCE_MIN_COMPARISONS and len(clients) >= PERFORMANCE_MIN_COMPARISONS
    fps = _delta_distribution(rows, "fpsDelta", published)
    fps_low = _delta_distribution(rows, "fps1LowDelta", published)
    temperature = _delta_distribution(rows, "gpuTempDelta", published)
    power = _delta_distribution(rows, "gpuPowerDelta", published)
    result = {
        "pairs": len(rows),
        "matchedClients": len(clients),
        "published": published,
        "fpsDelta": fps,
        "fps1LowDelta": fps_low,
        "temperatureDelta": temperature,
        "powerDelta": power,
        "fpsDeltaMedian": fps["median"],
        "fps1LowDeltaMedian": fps_low["median"],
        "temperatureDeltaMedian": temperature["median"],
        "powerDeltaMedian": power["median"],
    }
    if not published:
        result.update({
            "winRate": None,
            "improved": None,
            "neutral": None,
            "worse": None,
            "fiveBands": None,
        })
        return result
    improved = sum(1 for row in rows if row["fpsDelta"] > 1.0)
    worse = sum(1 for row in rows if row["fpsDelta"] < -1.0)
    neutral = len(rows) - improved - worse
    bands = {"strongImprovement": 0, "improvement": 0, "neutral": 0, "decline": 0, "strongDecline": 0}
    for row in rows:
        value = row.get("fpsDeltaPct")
        if value is None:
            bands["neutral"] += 1
        elif value > 10:
            bands["strongImprovement"] += 1
        elif value > 2:
            bands["improvement"] += 1
        elif value >= -2:
            bands["neutral"] += 1
        elif value >= -10:
            bands["decline"] += 1
        else:
            bands["strongDecline"] += 1
    result.update({
        "winRate": round(improved * 100.0 / len(rows), 1),
        "improved": improved,
        "neutral": neutral,
        "worse": worse,
        "fiveBands": bands,
    })
    return result


def _weekly_trusted_aggregate(rows):
    client_groups = {}
    for row in rows:
        client_groups.setdefault(row["client_hash"], []).append(row)
    published = len(client_groups) >= PERFORMANCE_MIN_SAMPLES and len(rows) >= PERFORMANCE_MIN_SAMPLES
    result = {
        "sessions": len(rows),
        "clients": len(client_groups),
        "published": published,
        "aggregation": "clientMedian",
        "metricClients": {},
    }
    mapping = {
        "avgFps": "avg_fps",
        "fps1Low": "fps_1_low",
        "gpuUtil": "gpu_util_avg",
        "gpuTemp": "gpu_temp_avg",
        "gpuPower": "gpu_power_avg",
    }
    for output_key, row_key in mapping.items():
        client_values = []
        for group in client_groups.values():
            value = _median_positive(group, row_key)
            if value is not None:
                client_values.append(value)
        result["metricClients"][output_key] = len(client_values)
        result[output_key] = (
            round(float(statistics.median(client_values)), 1)
            if published and len(client_values) >= PERFORMANCE_MIN_SAMPLES else None
        )
    return result


def _weekly_performance_summary(rows, pairs):
    trusted = _weekly_trusted_aggregate(rows)
    tiers = {}
    for tier in CONFIG_TIERS[1:]:
        summary = _weekly_pair_summary([row for row in pairs if row["tier"] == tier])
        summary["tier"] = tier
        summary["label"] = CONFIG_TIER_LABELS[tier]
        tiers[tier] = summary
    return trusted, {"overall": _weekly_pair_summary(pairs), "configTiers": tiers}


def _period_bundle(conn, start, end, filters):
    rows = _weekly_performance_rows(conn, start, end, filters)
    counts = _weekly_performance_counts(conn, start, end, filters)
    pairs = _weekly_performance_pairs(rows)
    overall, comparisons = _weekly_performance_summary(rows, pairs)
    return {
        "start": start,
        "end": end,
        "usage": _period_usage(conn, start, end, filters),
        "performanceRows": rows,
        "performanceCounts": counts,
        "pairs": pairs,
        "performanceOverall": overall,
        "performanceComparison": comparisons,
    }


def _weekly_filter_options(conn):
    queries = {
        "versions": "SELECT app_version value, COUNT(*) count FROM clients WHERE app_version<>'' GROUP BY app_version ORDER BY count DESC, value LIMIT 100",
        "gpus": "SELECT gpu_model value, COUNT(*) count FROM clients WHERE gpu_model<>'' AND gpu_model_verified=1 GROUP BY gpu_model ORDER BY count DESC, value LIMIT 100",
        "deviceTypes": "SELECT device_type value, COUNT(*) count FROM clients WHERE device_type<>'' GROUP BY device_type ORDER BY count DESC, value LIMIT 100",
    }
    result = {}
    for key, sql in queries.items():
        result[key] = [
            {"value": row["value"], "label": row["value"], "count": int(row["count"])}
            for row in _rows(conn, sql)
        ]
    return result


def _active_distribution(conn, start, end, filters, column):
    allowed = {"app_version": "app_version", "device_type": "device_type"}
    if column not in allowed:
        raise ValueError("bad distribution column")
    where, args = _client_filter_sql(filters)
    rows = _rows(
        conn,
        """SELECT c.%s label, COUNT(DISTINCT du.client_hash) devices
             FROM daily_usage du JOIN clients c ON c.client_hash=du.client_hash
            WHERE du.day>=? AND du.day<? AND c.%s<>''%s
            GROUP BY c.%s ORDER BY devices DESC, label LIMIT 50"""
        % (allowed[column], allowed[column], where, allowed[column]),
        [start.isoformat(), end.isoformat()] + args,
    )
    total = sum(int(row["devices"]) for row in rows)
    return [{
        "label": row["label"],
        "devices": int(row["devices"]),
        "sharePct": round(int(row["devices"]) * 100.0 / total, 1) if total else 0.0,
    } for row in rows]


def _weekly_version_adoption(conn, start, end, filters):
    where, args = _client_filter_sql(filters)
    rows = _rows(
        conn,
        """SELECT c.app_version version, COUNT(DISTINCT du.client_hash) active_devices,
                  COALESCE(SUM(du.apply_ok),0) apply_ok,
                  COALESCE(SUM(du.apply_failed),0) apply_failed,
                  COALESCE(SUM(du.restore_ok),0) restore_ok,
                  COALESCE(SUM(du.restore_failed),0) restore_failed
             FROM daily_usage du JOIN clients c ON c.client_hash=du.client_hash
            WHERE du.day>=? AND du.day<? AND c.app_version<>''""" + where +
        " GROUP BY c.app_version ORDER BY active_devices DESC, version DESC LIMIT 50",
        [start.isoformat(), end.isoformat()] + args,
    )
    total = sum(int(row["active_devices"]) for row in rows)
    result = []
    for row in rows:
        apply_total = int(row["apply_ok"]) + int(row["apply_failed"])
        restore_total = int(row["restore_ok"]) + int(row["restore_failed"])
        result.append({
            "version": row["version"],
            "activeDevices": int(row["active_devices"]),
            "sharePct": round(int(row["active_devices"]) * 100.0 / total, 1) if total else 0.0,
            "applyFailureRate": round(int(row["apply_failed"]) * 100.0 / apply_total, 1) if apply_total else None,
            "restoreFailureRate": round(int(row["restore_failed"]) * 100.0 / restore_total, 1) if restore_total else None,
            "applyFailures": int(row["apply_failed"]),
            "restoreFailures": int(row["restore_failed"]),
        })
    return result


def _weekly_gpu_ranking(conn, bundle, filters):
    where, args = _client_filter_sql(filters)
    active = _rows(
        conn,
        """SELECT c.gpu_model gpu_model, COUNT(DISTINCT du.client_hash) active_devices
             FROM daily_usage du JOIN clients c ON c.client_hash=du.client_hash
            WHERE du.day>=? AND du.day<? AND c.gpu_model<>'' AND c.gpu_model_verified=1""" + where +
        " GROUP BY c.gpu_model",
        [bundle["start"].isoformat(), bundle["end"].isoformat()] + args,
    )
    active_map = {row["gpu_model"]: int(row["active_devices"]) for row in active}
    performance_groups = {}
    for row in bundle["performanceRows"]:
        gpu = row.get("profile_gpu_model") or row.get("gpu_model")
        if gpu:
            performance_groups.setdefault(gpu, []).append(row)
    pair_groups = {}
    for row in bundle["pairs"]:
        gpu = row.get("profileGpu") or row.get("gpuModel")
        if gpu:
            pair_groups.setdefault(gpu, []).append(row)
    labels = set(active_map) | set(performance_groups) | set(pair_groups)
    result = []
    for label in labels:
        devices = active_map.get(label, 0)
        aggregate = _weekly_trusted_aggregate(performance_groups.get(label, []))
        improvement = _weekly_pair_summary(pair_groups.get(label, []))
        conclusion = devices >= PERFORMANCE_MIN_SAMPLES and aggregate["published"]
        result.append({
            "gpu": label,
            "activeDevices": devices,
            "sessions": aggregate["sessions"],
            "performanceClients": aggregate["clients"],
            "avgFps": aggregate["avgFps"] if conclusion else None,
            "fps1Low": aggregate["fps1Low"] if conclusion else None,
            "pairs": improvement["pairs"],
            "fpsDelta": improvement["fpsDeltaMedian"] if conclusion and improvement["published"] else None,
            "fps1LowDelta": improvement["fps1LowDeltaMedian"] if conclusion and improvement["published"] else None,
            "winRate": improvement["winRate"] if conclusion and improvement["published"] else None,
            "conclusionPublished": bool(conclusion),
        })
    result.sort(key=lambda row: (-row["activeDevices"], -row["sessions"], row["gpu"]))
    return result[:30]


def _tuning_period_counts(conn, start, end, filters):
    where, filter_args = _client_filter_sql(filters)
    start_ts = _date_timestamp(start)
    end_ts = _date_timestamp(end)
    base = " FROM tuning_experiments e JOIN clients c ON c.client_hash=e.client_hash WHERE "

    def count(date_column, extra="", extra_args=()):
        return int(conn.execute(
            "SELECT COUNT(*)" + base + "%s>=? AND %s<?" % (date_column, date_column) + where + extra,
            [start_ts, end_ts] + filter_args + list(extra_args),
        ).fetchone()[0])

    result = {
        "started": count("e.created_at"),
        "completed": count("e.completed_at"),
        "valid": 0,
        "foundBetter": count("e.completed_at", " AND e.result=?", ("found_better",)),
        "noSignificantGain": count("e.completed_at", " AND e.result=?", ("no_significant_gain",)),
        "autoRollback": count("e.completed_at", " AND e.auto_rollback=1"),
    }
    result["valid"] = len({
        row["experimentId"] for row in _qualified_tuning_comparisons(conn, start, end, filters)
    })
    return result


def _tuning_funnel(conn, start, end, filters):
    where, args = _client_filter_sql(filters)
    rows = _rows(
        conn,
        """SELECT e.experiment_id, e.completed_at, e.result,
                  EXISTS (
                    SELECT 1 FROM tuning_runs rb JOIN tuning_variants vb ON vb.variant_id=rb.variant_id
                     WHERE rb.experiment_id=e.experiment_id AND rb.validity='valid' AND vb.group_id='baseline'
                  ) baseline_valid,
                  EXISTS (
                    SELECT 1 FROM tuning_variants va WHERE va.experiment_id=e.experiment_id
                     AND va.group_id IN ('G1','G2','G3') AND va.apply_result IN ('succeeded','partial')
                  ) variant_applied,
                  EXISTS (
                    SELECT 1 FROM tuning_runs rv JOIN tuning_variants vv ON vv.variant_id=rv.variant_id
                     WHERE rv.experiment_id=e.experiment_id AND rv.validity='valid'
                       AND vv.group_id IN ('G1','G2','G3')
                  ) variant_valid
             FROM tuning_experiments e JOIN clients c ON c.client_hash=e.client_hash
            WHERE e.created_at>=? AND e.created_at<?""" + where,
        [_date_timestamp(start), _date_timestamp(end)] + args,
    )
    started = len(rows)
    stages = (
        ("started", "开始实验", started),
        ("baselineValid", "有效基线", sum(int(row["baseline_valid"]) for row in rows)),
        ("variantApplied", "已应用候选", sum(int(row["variant_applied"]) for row in rows)),
        ("validVariantRun", "候选有效运行", sum(int(row["variant_valid"]) for row in rows)),
        ("completed", "完成实验", sum(1 for row in rows if row["completed_at"] is not None)),
        ("foundBetter", "找到更优配置", sum(1 for row in rows if row["result"] == "found_better")),
    )
    return [{
        "key": key,
        "label": label,
        "experiments": int(value),
        "rateFromStartedPct": round(value * 100.0 / started, 1) if started else None,
    } for key, label, value in stages]


def _tuning_run_distributions(conn, start, end, filters):
    where, args = _client_filter_sql(filters)
    base_args = [_date_timestamp(start), _date_timestamp(end)] + args
    validity = _rows(
        conn,
        """SELECT r.validity value, COUNT(*) count
             FROM tuning_runs r JOIN tuning_experiments e ON e.experiment_id=r.experiment_id
             JOIN clients c ON c.client_hash=e.client_hash
            WHERE r.completed_at>=? AND r.completed_at<?""" + where +
        " GROUP BY r.validity ORDER BY count DESC, value",
        base_args,
    )
    total = sum(int(row["count"]) for row in validity)
    validity_rows = [{
        "value": row["value"],
        "count": int(row["count"]),
        "sharePct": round(int(row["count"]) * 100.0 / total, 1) if total else 0.0,
    } for row in validity]
    invalid_reasons = _rows(
        conn,
        """SELECT r.invalid_reason value, COUNT(*) count
             FROM tuning_runs r JOIN tuning_experiments e ON e.experiment_id=r.experiment_id
             JOIN clients c ON c.client_hash=e.client_hash
            WHERE r.completed_at>=? AND r.completed_at<? AND r.invalid_reason<>''""" + where +
        " GROUP BY r.invalid_reason ORDER BY count DESC, value",
        base_args,
    )
    invalid_total = sum(int(row["count"]) for row in invalid_reasons)
    reason_rows = [{
        "value": row["value"],
        "count": int(row["count"]),
        "sharePct": round(int(row["count"]) * 100.0 / invalid_total, 1) if invalid_total else 0.0,
    } for row in invalid_reasons]
    return validity_rows, reason_rows


def _qualified_tuning_comparisons(conn, start, end, filters):
    where, args = _client_filter_sql(filters)
    time_args = [_date_timestamp(start), _date_timestamp(end)] + args
    experiments = _rows(
        conn,
        """SELECT e.* FROM tuning_experiments e
             JOIN clients c ON c.client_hash=e.client_hash
            WHERE e.completed_at>=? AND e.completed_at<?
              AND e.status NOT IN ('failed','cancelled')
              AND e.result NOT IN ('failed','cancelled')""" + where,
        time_args,
    )
    if not experiments:
        return []
    variants = _rows(
        conn,
        """SELECT v.* FROM tuning_variants v
             JOIN tuning_experiments e ON e.experiment_id=v.experiment_id
             JOIN clients c ON c.client_hash=e.client_hash
            WHERE e.completed_at>=? AND e.completed_at<?
              AND e.status NOT IN ('failed','cancelled')
              AND e.result NOT IN ('failed','cancelled')""" + where,
        time_args,
    )
    run_rows = _rows(
        conn,
        """SELECT r.* FROM tuning_runs r
             JOIN tuning_experiments e ON e.experiment_id=r.experiment_id
             JOIN clients c ON c.client_hash=e.client_hash
            WHERE e.completed_at>=? AND e.completed_at<? AND r.validity='valid'
              AND e.status NOT IN ('failed','cancelled')
              AND e.result NOT IN ('failed','cancelled')""" + where,
        time_args,
    )
    variants_by_experiment = {}
    for variant in variants:
        variants_by_experiment.setdefault(variant["experiment_id"], {})[variant["variant_id"]] = variant
    runs_by_experiment = {}
    for run in run_rows:
        runs_by_experiment.setdefault(run["experiment_id"], {}).setdefault(run["variant_id"], []).append(run)
    comparisons = []
    for experiment in experiments:
        experiment_variants = variants_by_experiment.get(experiment["experiment_id"], {})
        experiment_runs = runs_by_experiment.get(experiment["experiment_id"], {})
        winner = experiment_variants.get(experiment["winning_variant_id"])
        winner_items = set(_tuning_variant_items(winner)) if winner else set()
        library_groups = TUNING_LIBRARY_GROUP_ITEMS.get(int(experiment["library_version"]))
        if library_groups is None:
            continue
        _, chain_comparisons = _evaluate_tuning_comparison_chain(
            experiment, experiment_variants, experiment_runs
        )
        for candidate_id, comparison in chain_comparisons.items():
            candidate = experiment_variants[candidate_id]
            retained = set(library_groups[candidate["group_id"]]).issubset(winner_items)
            comparison.update({
                "retained": retained,
                "won": bool(
                    retained and experiment["result"] == "found_better"
                    and comparison["deterministicWin"]
                ),
                "rolledBack": not retained,
            })
            comparisons.append(comparison)
    return comparisons


def _tuning_group_ranking(conn, start, end, filters):
    all_comparisons = _qualified_tuning_comparisons(conn, start, end, filters)
    summaries = []
    for group_id in ("G1", "G2", "G3"):
        comparisons = [row for row in all_comparisons if row["groupId"] == group_id]
        by_client = {}
        for row in comparisons:
            by_client.setdefault(row["clientHash"], []).append(row)
        device_rows = []
        for client_hash, client_rows in by_client.items():
            client_rows.sort(key=lambda row: (row["completedAt"] or 0, row["experimentId"]))

            def device_median(key):
                values = [row[key] for row in client_rows if row.get(key) is not None]
                return float(statistics.median(values)) if values else None

            retained_count = sum(1 for row in client_rows if row["retained"])
            if retained_count * 2 == len(client_rows):
                retained = client_rows[-1]["retained"]
            else:
                retained = retained_count * 2 > len(client_rows)
            won_count = sum(1 for row in client_rows if row["won"])
            if won_count * 2 == len(client_rows):
                won = client_rows[-1]["won"]
            else:
                won = won_count * 2 > len(client_rows)
            device_rows.append({
                "clientHash": client_hash,
                "avgFpsDeltaPct": device_median("avgFpsDeltaPct"),
                "fps1LowDeltaPct": device_median("fps1LowDeltaPct"),
                "gpuTempDeltaC": device_median("gpuTempDeltaC"),
                "won": bool(retained and won),
                "rolledBack": not retained,
            })
        device_count = len(device_rows)
        published = device_count >= TUNING_GROUP_MIN_DEVICES

        def median_value(key):
            values = [row[key] for row in device_rows if row.get(key) is not None]
            return round(float(statistics.median(values)), 1) if published and len(values) >= TUNING_GROUP_MIN_DEVICES else None

        wins = sum(1 for row in device_rows if row["won"])
        rollbacks = sum(1 for row in device_rows if row["rolledBack"])
        summaries.append({
            "libraryVersion": TUNING_LIBRARY_VERSION,
            "groupId": group_id,
            "label": TUNING_GROUP_LABELS[group_id],
            "validIndependentExperiments": len(comparisons),
            "validIndependentDevices": device_count,
            "wins": wins,
            "rollbacks": rollbacks,
            "orderControlledExperiments": len(comparisons),
            "orderControlledSharePct": 100.0 if comparisons else None,
            "conclusionPublished": published,
            "winRate": round(wins * 100.0 / device_count, 1) if published else None,
            "fps1LowDeltaPct": median_value("fps1LowDeltaPct"),
            "avgFpsDeltaPct": median_value("avgFpsDeltaPct"),
            "gpuTempDeltaC": median_value("gpuTempDeltaC"),
            "rollbackRate": round(rollbacks * 100.0 / device_count, 1) if published else None,
            "rank": None,
        })
    publishable = sorted(
        [row for row in summaries if row["conclusionPublished"]],
        key=lambda row: (-row["fps1LowDeltaPct"], row["groupId"]),
    )
    for index, row in enumerate(publishable, 1):
        row["rank"] = index
    return summaries


def _weekly_tuning(conn, current_start, current_end, previous_start, previous_end, filters):
    current = _tuning_period_counts(conn, current_start, current_end, filters)
    previous = _tuning_period_counts(conn, previous_start, previous_end, filters)
    validity, invalid_reasons = _tuning_run_distributions(
        conn, current_start, current_end, filters
    )
    summary = {
        key: _metric_comparison(current[key], previous[key])
        for key in ("started", "completed", "valid", "foundBetter", "noSignificantGain", "autoRollback")
    }
    return {
        "libraryVersion": TUNING_LIBRARY_VERSION,
        "summary": summary,
        "funnel": _tuning_funnel(conn, current_start, current_end, filters),
        "groupRanking": _tuning_group_ranking(conn, current_start, current_end, filters),
        "validityDistribution": validity,
        "invalidReasonDistribution": invalid_reasons,
        "aiQuality": {
            "enabled": False,
            "status": "notEnabled",
            "decisions": 0,
            "accepted": 0,
            "rejected": 0,
            "fallbacks": 0,
            "validationFailures": 0,
            "reasonCodes": [],
        },
        "dataQuality": {
            "source": "authenticated_client_self_reported",
            "startedCohortIncludesAll": True,
            "groupConclusionMinIndependentDevices": TUNING_GROUP_MIN_DEVICES,
            "acceptedLibraryVersions": sorted(TUNING_LIBRARY_GROUP_ITEMS),
            "qualification": {
                "minimumValidBaselineRuns": 3,
                "minimumValidControlRuns": 3,
                "minimumValidCandidateRuns": 2,
                "baselineAvgFpsMaxCvPct": 5.0,
                "baselineFps1LowMaxCvPct": 10.0,
                "sameEnvironmentRequired": True,
                "stableSettingsPerVariantRequired": True,
                "orderControlledRequired": True,
                "fullyAppliedCandidateRequired": True,
                "deterministicWinRule": "v1",
                "comparisonMembership": "sequenceBoundaryV1",
            },
            "validityUsedForGroupConclusions": "valid",
            "filtersUseLatestClientProfile": True,
            "performanceSessionsMixedWithTuningRuns": False,
        },
    }


def _diagnostic_reports_in_period(start, end):
    lower = _date_timestamp(start)
    upper = _date_timestamp(end)
    count = 0
    try:
        for name in os.listdir(REPORT_DIR):
            if not re.fullmatch(r"DFB-[A-Z2-9]{4}\.txt", name):
                continue
            modified = os.path.getmtime(os.path.join(REPORT_DIR, name))
            if lower <= modified < upper:
                count += 1
    except OSError:
        pass
    return count


def _snapshot_metadata(used=False, available=False, generated_at=None):
    return {
        "used": bool(used),
        "available": bool(available),
        "generatedAt": generated_at,
        "schemaVersion": WEEKLY_SCHEMA_VERSION,
    }


def _mark_snapshot(report, used, available, generated_at=None):
    result = json.loads(json.dumps(report, ensure_ascii=False))
    result.setdefault("week", {})["snapshot"] = _snapshot_metadata(used, available, generated_at)
    return result


def _load_weekly_snapshot(week_start):
    conn = _connect()
    try:
        row = conn.execute(
            "SELECT generated_at, schema_version, report_json FROM weekly_snapshots WHERE week_start=?",
            (week_start.isoformat(),),
        ).fetchone()
    finally:
        conn.close()
    if row is None:
        return None
    if int(row["schema_version"]) != WEEKLY_SCHEMA_VERSION:
        return None
    if len(row["report_json"].encode("utf-8")) > MAX_WEEKLY_SNAPSHOT_BODY:
        raise WeeklySnapshotError("unsupported weekly snapshot")
    try:
        report = json.loads(row["report_json"])
    except (json.JSONDecodeError, TypeError):
        raise WeeklySnapshotError("invalid weekly snapshot")
    if not isinstance(report, dict) or report.get("schemaVersion") != WEEKLY_SCHEMA_VERSION:
        raise WeeklySnapshotError("invalid weekly snapshot")
    week = report.get("week")
    if not isinstance(week, dict) or week.get("weekStart") != week_start.isoformat():
        raise WeeklySnapshotError("weekly snapshot date mismatch")
    return _mark_snapshot(report, True, True, int(row["generated_at"]))


def _weekly_snapshot_exists(week_start):
    conn = _connect()
    try:
        return conn.execute(
            "SELECT 1 FROM weekly_snapshots WHERE week_start=?", (week_start.isoformat(),)
        ).fetchone() is not None
    finally:
        conn.close()


def _weekly_snapshot_generated_at(week_start):
    conn = _connect()
    try:
        row = conn.execute(
            "SELECT generated_at FROM weekly_snapshots WHERE week_start=? AND schema_version=?",
            (week_start.isoformat(), WEEKLY_SCHEMA_VERSION),
        ).fetchone()
        return int(row[0]) if row is not None else None
    finally:
        conn.close()


def _save_weekly_snapshot(week_start, report, overwrite=False):
    generated_at = int(report["generatedAt"])
    stored = _mark_snapshot(report, False, True, generated_at)
    text = json.dumps(stored, ensure_ascii=False, separators=(",", ":"))
    if len(text.encode("utf-8")) > MAX_WEEKLY_SNAPSHOT_BODY:
        raise OverflowError("weekly snapshot too large")
    conn = _connect()
    try:
        with conn:
            if overwrite:
                conn.execute(
                    """INSERT INTO weekly_snapshots (week_start, generated_at, schema_version, report_json)
                       VALUES (?, ?, ?, ?)
                       ON CONFLICT(week_start) DO UPDATE SET generated_at=excluded.generated_at,
                           schema_version=excluded.schema_version, report_json=excluded.report_json""",
                    (week_start.isoformat(), generated_at, WEEKLY_SCHEMA_VERSION, text),
                )
            else:
                conn.execute(
                    "INSERT INTO weekly_snapshots (week_start, generated_at, schema_version, report_json) VALUES (?, ?, ?, ?)",
                    (week_start.isoformat(), generated_at, WEEKLY_SCHEMA_VERSION, text),
                )
    finally:
        conn.close()
    return stored


def _weekly_summary(core, comparison, issues, period_mode="week"):
    active = core["activeUsers"]["current"]
    launches = core["launches"]["current"]
    pair_summary = comparison["overall"]
    current_label = "本周期" if period_mode == "custom" else "本周"
    previous_label = "上一等长周期" if period_mode == "custom" else "前一周"
    text = "%s %d 台活跃设备，共启动 %d 次。" % (current_label, active, launches)
    if pair_summary["published"]:
        text += " 可信配对样本的帧率中位变化为 %+.1f。" % pair_summary["fpsDeltaMedian"]
    else:
        text += " 可信配对样本尚未达到 5 台独立设备，暂不发布性能结论。"
    highlights = []
    concerns = []
    if core["activeUsers"]["changePct"] is not None and core["activeUsers"]["changePct"] > 0:
        highlights.append({
            "code": "activeUsersUp",
            "text": "活跃设备较%s增长 %.1f%%。" % (previous_label, core["activeUsers"]["changePct"]),
        })
    if pair_summary["published"] and pair_summary["fpsDeltaMedian"] > 0:
        highlights.append({"code": "frameRateUp", "text": "可信配对的帧率中位数提升 %.1f。" % pair_summary["fpsDeltaMedian"]})
    if issues["applyFailures"]["current"] > 0:
        concerns.append({"code": "applyFailures", "text": "%s记录到 %d 个应用失败项。" % (current_label, issues["applyFailures"]["current"])})
    if issues["restoreFailures"]["current"] > 0:
        concerns.append({"code": "restoreFailures", "text": "%s记录到 %d 个还原失败项。" % (current_label, issues["restoreFailures"]["current"])})
    if not pair_summary["published"]:
        concerns.append({"code": "insufficientPairs", "text": "性能配对少于 5 台独立设备，仅展示样本数。"})
    return {"text": text, "activeDevices": active, "launches": launches}, highlights, concerns


def _build_weekly_report(week_start=None, filters=None, now=None):
    now = int(time.time() if now is None else now)
    week_start = _parse_week_start(week_start, now)
    return _build_period_report(
        week_start, week_start + dt.timedelta(days=7), filters, now, "week"
    )


def _build_custom_period_report(
    start, end, filters=None, now=None,
    comparison_start=None, comparison_end=None,
):
    now = int(time.time() if now is None else now)
    period = _parse_custom_period(start, end, now, comparison_start, comparison_end)
    return _build_period_report(
        period.start, period.end + dt.timedelta(days=1), filters, now, "custom",
        comparison_start=period.comparison_start,
        comparison_end=(period.comparison_end + dt.timedelta(days=1)) if period.comparison_end else None,
    )


def _build_period_report(
    period_start, current_end, filters, now, period_mode,
    comparison_start=None, comparison_end=None,
):
    filters = dict(_default_weekly_filters() if filters is None else filters)
    period_days = (current_end - period_start).days
    if (comparison_start is None) != (comparison_end is None):
        raise ValueError("comparison period boundaries must be provided together")
    previous_start = comparison_start or (period_start - dt.timedelta(days=period_days))
    previous_end = comparison_end or period_start
    if (previous_end - previous_start).days != period_days:
        raise ValueError("comparison period must have the same number of days")
    conn = _connect()
    try:
        # Keep all database-derived sections on one WAL snapshot while uploads continue.
        conn.execute("BEGIN")
        current = _period_bundle(conn, period_start, current_end, filters)
        previous = _period_bundle(conn, previous_start, previous_end, filters)
        filter_options = _weekly_filter_options(conn)
        versions = _active_distribution(conn, period_start, current_end, filters, "app_version")
        devices = _active_distribution(conn, period_start, current_end, filters, "device_type")
        version_adoption = _weekly_version_adoption(conn, period_start, current_end, filters)
        gpu_ranking = _weekly_gpu_ranking(conn, current, filters)
        tuning = _weekly_tuning(
            conn, period_start, current_end, previous_start, previous_end, filters
        )
        trends = []
        for offset in range(7, -1, -1):
            start = period_start - dt.timedelta(days=offset * period_days)
            end = start + dt.timedelta(days=period_days)
            bundle = current if start == period_start else _period_bundle(conn, start, end, filters)
            usage = bundle["usage"]
            pair_summary = bundle["performanceComparison"]["overall"]
            trends.append({
                "weekStart": start.isoformat(),
                "weekEnd": (end - dt.timedelta(days=1)).isoformat(),
                "newUsers": usage["newUsers"],
                "activeUsers": usage["activeUsers"],
                "launches": usage["launches"],
                "applyDevices": usage["applyDevices"],
                "applies": usage["applyDevices"],
                "performanceSessions": bundle["performanceOverall"]["sessions"],
                "performanceClients": bundle["performanceOverall"]["clients"],
                "fps1LowDelta": pair_summary["fps1LowDeltaMedian"],
                "pairs": pair_summary["pairs"],
                "pairedClients": pair_summary["pairs"],
            })
        where, args = _client_filter_sql(filters)
        excluded_performance = conn.execute(
            """SELECT COUNT(*) FROM performance_sessions ps JOIN clients c ON c.client_hash=ps.client_hash
                WHERE ps.day>=? AND ps.day<? AND ps.authenticated=0""" + where,
            [period_start.isoformat(), current_end.isoformat()] + args,
        ).fetchone()[0]
    finally:
        conn.close()

    current_usage = current["usage"]
    previous_usage = previous["usage"]
    current_performance = current["performanceOverall"]
    previous_performance = previous["performanceOverall"]
    current_sampling = current["performanceCounts"]
    previous_sampling = previous["performanceCounts"]
    current_pairs = current["performanceComparison"]["overall"]
    previous_pairs = previous["performanceComparison"]["overall"]
    core = {
        "newUsers": _metric_comparison(current_usage["newUsers"], previous_usage["newUsers"]),
        "activeUsers": _metric_comparison(current_usage["activeUsers"], previous_usage["activeUsers"]),
        "launches": _metric_comparison(current_usage["launches"], previous_usage["launches"]),
        "applyDevices": _metric_comparison(current_usage["applyDevices"], previous_usage["applyDevices"]),
        "performanceSessions": _metric_comparison(
            current_performance["sessions"], previous_performance["sessions"],
            currentClients=current_performance["clients"],
            previousClients=previous_performance["clients"],
            clientsChangePct=_change_pct(current_performance["clients"], previous_performance["clients"]),
            clients=_metric_comparison(current_performance["clients"], previous_performance["clients"]),
        ),
        "rawPerformanceSessions": _metric_comparison(
            current_sampling["rawSessions"], previous_sampling["rawSessions"],
        ),
        "fps1LowDelta": _metric_comparison(
            current_pairs["fps1LowDeltaMedian"], previous_pairs["fps1LowDeltaMedian"],
            currentPairs=current_pairs["pairs"], previousPairs=previous_pairs["pairs"],
            pairsChangePct=_change_pct(current_pairs["pairs"], previous_pairs["pairs"]),
            pairs=_metric_comparison(current_pairs["pairs"], previous_pairs["pairs"]),
        ),
    }
    comparison_keys = (
        ("newUsers", "新增用户"), ("activeUsers", "活跃设备"),
        ("launches", "启动次数"), ("applyDevices", "应用优化设备"),
        ("applies", "应用次数"), ("restores", "还原次数"),
        ("applyFailures", "应用失败项"), ("restoreFailures", "还原失败项"),
    )
    usage_comparison = [{
        "key": key,
        "label": label,
        **_metric_comparison(current_usage[key], previous_usage[key]),
    } for key, label in comparison_keys]
    diagnostic_current = _diagnostic_reports_in_period(period_start, current_end)
    diagnostic_previous = _diagnostic_reports_in_period(previous_start, previous_end)
    issues = {
        "applyFailures": _metric_comparison(current_usage["applyFailures"], previous_usage["applyFailures"]),
        "restoreFailures": _metric_comparison(current_usage["restoreFailures"], previous_usage["restoreFailures"]),
        "diagnosticReports": _metric_comparison(diagnostic_current, diagnostic_previous),
        "samplingFailures": {
            "current": None, "previous": None, "changePct": None,
            "reason": "客户端协议尚未上报采样失败次数",
        },
    }
    summary, highlights, concerns = _weekly_summary(
        core, current["performanceComparison"], issues, period_mode
    )
    selected_filters = {
        "version": filters.get("version"), "gpu": filters.get("gpu"),
        "deviceType": filters.get("deviceType"), "validOnly": bool(filters.get("validOnly")),
    }
    performance_sampling = {
        "rawSessions": _metric_comparison(
            current_sampling["rawSessions"], previous_sampling["rawSessions"],
        ),
        "trustedSessions": _metric_comparison(
            current_sampling["trustedSessions"], previous_sampling["trustedSessions"],
        ),
        "trustedClients": _metric_comparison(
            current_sampling["trustedClients"], previous_sampling["trustedClients"],
        ),
        "validPairs": _metric_comparison(current_pairs["pairs"], previous_pairs["pairs"]),
        "conclusionPublished": bool(current_pairs["published"]),
        "minimumTrustedDevices": PERFORMANCE_MIN_SAMPLES,
        "minimumPairedDevices": PERFORMANCE_MIN_COMPARISONS,
    }
    return {
        "schemaVersion": WEEKLY_SCHEMA_VERSION,
        "generatedAt": now,
        "week": {
            "periodMode": period_mode,
            "comparisonMode": "selected" if comparison_start is not None else "adjacent",
            "reportNumber": _report_number(period_start) if period_mode == "week" else None,
            "weekStart": period_start.isoformat(),
            "current": {"start": period_start.isoformat(), "end": (current_end - dt.timedelta(days=1)).isoformat(), "endExclusive": current_end.isoformat()},
            "previous": {"start": previous_start.isoformat(), "end": (previous_end - dt.timedelta(days=1)).isoformat(), "endExclusive": previous_end.isoformat()},
            "snapshot": _snapshot_metadata(),
        },
        "filters": selected_filters,
        "filterOptions": filter_options,
        "core": core,
        "usageComparison": usage_comparison,
        "trends": trends,
        "summary": summary,
        "highlights": highlights,
        "concerns": concerns,
        "distributions": {"versions": versions, "devices": devices},
        "versions": versions,
        "devices": devices,
        "performanceOverall": current["performanceOverall"],
        "performanceSampling": performance_sampling,
        "performanceComparison": current["performanceComparison"],
        "gpuRanking": gpu_ranking,
        "versionAdoption": version_adoption,
        "tuning": tuning,
        "issues": issues,
        "dataQuality": {
            "source": "client_self_reported",
            "sourceLabel": "客户端自报，未经独立测量验证",
            "performanceAuthenticationRequired": True,
            "trustedPerformanceSessions": current_performance["sessions"],
            "trustedPerformanceClients": current_performance["clients"],
            "unauthenticatedPerformanceSessionsExcluded": int(excluded_performance),
            "minimumIndependentDevices": PERFORMANCE_MIN_SAMPLES,
            "minimumPairedDevices": PERFORMANCE_MIN_COMPARISONS,
            "performanceAggregation": "先按同一匿名设备、同一真实显卡和配置档取中位数，再做配对汇总",
            "pairNeutralThresholdFps": 1.0,
            "fiveBandThresholdsPct": {"strongImprovement": 10, "improvement": 2, "decline": -2, "strongDecline": -10},
            "filtersUseLatestClientProfile": True,
            "filtersNote": "版本、显卡和设备类型筛选均使用每个客户端最近一次档案；性能结论始终排除未认证会话。",
            "diagnosticReportsAreGlobal": True,
            "diagnosticRetentionDays": KEEP_DAYS,
            "samplingFailuresAvailable": False,
        },
    }


def _admin_authorized(handler):
    supplied = handler.headers.get("X-DFB-Admin-Token", "")
    return bool(ADMIN_API_TOKEN) and hmac.compare_digest(supplied, ADMIN_API_TOKEN)


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "dfb-report/3.0"

    def _reply_json(self, status, payload, cache_control="no-store"):
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        if len(body) > MAX_ADMIN_RESPONSE_BODY:
            status = 500
            body = b'{"error":"response too large"}'
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", cache_control)
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
        path = urllib.parse.urlsplit(self.path).path.rstrip("/")
        ip = _client_ip(self)
        if path == "/api/weekly/snapshot":
            if not _admin_authorized(self):
                return self._reply_json(403, {"error": "forbidden"})
            try:
                raw = self._read_body(MAX_TELEMETRY_BODY)
                payload = json.loads(raw.decode("utf-8"))
                if not isinstance(payload, dict) or set(payload) - {"weekStart", "overwrite"}:
                    raise ValueError("bad snapshot request")
                overwrite = payload.get("overwrite", False)
                if not isinstance(overwrite, bool):
                    raise ValueError("overwrite must be a boolean")
                week_start = _parse_week_start(payload.get("weekStart"))
            except OverflowError:
                return self._reply_json(413, {"error": "body too large"})
            except (UnicodeError, json.JSONDecodeError, ValueError) as error:
                return self._reply_json(400, {"error": str(error) or "bad snapshot request"})
            existed = _weekly_snapshot_exists(week_start)
            if not overwrite and existed:
                return self._reply_json(409, {"error": "snapshot already exists", "weekStart": week_start.isoformat()})
            report = _build_weekly_report(week_start, _default_weekly_filters())
            try:
                _save_weekly_snapshot(week_start, report, overwrite)
            except sqlite3.IntegrityError:
                return self._reply_json(409, {"error": "snapshot already exists", "weekStart": week_start.isoformat()})
            except OverflowError:
                return self._reply_json(500, {"error": "snapshot too large"})
            return self._reply_json(200 if existed else 201, {
                "ok": True,
                "weekStart": week_start.isoformat(),
                "overwritten": bool(existed),
                "generatedAt": report["generatedAt"],
                "schemaVersion": WEEKLY_SCHEMA_VERSION,
            })

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

        if path == "/report/telemetry/register":
            if (
                not _rate_ok("telemetry-register:" + ip, 30)
                or not _rate_ok(
                    "telemetry-register-day:" + ip,
                    REGISTRATION_DAILY_LIMIT,
                    86400,
                )
            ):
                return self._reply_json(429, {"error": "too many registrations, try later"})
            try:
                raw = self._read_body(MAX_TELEMETRY_BODY)
                payload = json.loads(raw.decode("utf-8"))
                if not isinstance(payload, dict):
                    raise ValueError("bad registration")
                issued = _issue_device_token(payload.get("installId"))
            except OverflowError:
                return self._reply_json(413, {"error": "body too large"})
            except (UnicodeError, json.JSONDecodeError, ValueError):
                return self._reply_json(400, {"error": "bad registration"})
            except RuntimeError:
                return self._reply_json(503, {"error": "telemetry unavailable"})
            return self._reply_json(200, {"ok": True, **issued})

        if path == "/report/telemetry":
            if not _rate_ok("telemetry:" + ip, 120):
                return self._reply_json(429, {"error": "too many events, try later"})
            try:
                raw = self._read_body(MAX_TELEMETRY_BODY)
                payload = json.loads(raw.decode("utf-8"))
                result = _record_telemetry(payload)
            except OverflowError:
                return self._reply_json(413, {"error": "body too large"})
            except TelemetryAuthError:
                return self._reply_json(401, {"error": "device authentication failed"})
            except TelemetryReplayError:
                return self._reply_json(409, {"error": "duplicate telemetry event"})
            except TelemetryDailyLimitError:
                return self._reply_json(429, {"error": "daily telemetry limit reached"})
            except TelemetryOwnershipError:
                return self._reply_json(409, {"error": "tuning identifier ownership conflict"})
            except TelemetryConflictError:
                return self._reply_json(409, {"error": "tuning business key conflict"})
            except TelemetryTuningError:
                return self._reply_json(422, {"error": "invalid tuning event"})
            except TelemetryPerformanceError:
                return self._reply_json(422, {"error": "invalid performance session"})
            except (UnicodeError, json.JSONDecodeError, ValueError):
                return self._reply_json(400, {"error": "bad telemetry"})
            except RuntimeError:
                return self._reply_json(503, {"error": "telemetry unavailable"})
            response = {"ok": True, **result}
            if not result["trusted"]:
                response.update(_issue_device_token(payload.get("installId")))
            return self._reply_json(200, response)

        self._reply_json(404, {"error": "not found"})

    def do_GET(self):
        path = urllib.parse.urlsplit(self.path).path.rstrip("/")
        if path == "/report/health":
            return self._reply_json(200, {"ok": True, "telemetry": bool(TELEMETRY_PEPPER)})
        if path == "/report/public-stats":
            return self._reply_json(200, _build_public_stats(), "public, max-age=15")
        if path == "/api/stats":
            if not _admin_authorized(self):
                return self._reply_json(403, {"error": "forbidden"})
            return self._reply_json(200, _build_stats())
        if path == "/api/weekly":
            if not _admin_authorized(self):
                return self._reply_json(403, {"error": "forbidden"})
            try:
                period, filters, live = _parse_weekly_query(self.path)
                if isinstance(period, CustomPeriod):
                    report = _build_custom_period_report(
                        period.start, period.end, filters,
                        comparison_start=period.comparison_start,
                        comparison_end=period.comparison_end,
                    )
                    return self._reply_json(200, _mark_snapshot(report, False, False))
                week_start = period
                if not live and _filters_are_default(filters):
                    snapshot = _load_weekly_snapshot(week_start)
                    if snapshot is not None:
                        return self._reply_json(200, snapshot)
                report = _build_weekly_report(week_start, filters)
                snapshot_generated_at = _weekly_snapshot_generated_at(week_start)
                return self._reply_json(200, _mark_snapshot(
                    report, False, snapshot_generated_at is not None, snapshot_generated_at
                ))
            except WeeklySnapshotError:
                return self._reply_json(500, {"error": "invalid weekly snapshot"})
            except ValueError as error:
                return self._reply_json(400, {"error": str(error) or "bad weekly query"})
        self._reply_json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    os.makedirs(REPORT_DIR, exist_ok=True)
    os.chmod(REPORT_DIR, 0o750)
    _init_db()
    if "--maintenance" in sys.argv[1:]:
        print(json.dumps(_run_maintenance(), ensure_ascii=False))
        raise SystemExit(0)
    _run_maintenance()
    threading.Thread(target=_maintenance_loop, name="dfb-maintenance", daemon=True).start()
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
