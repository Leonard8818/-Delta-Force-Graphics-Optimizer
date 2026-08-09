import importlib.util
import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request


MODULE_PATH = os.path.join(os.path.dirname(__file__), "report_server.py")
SPEC = importlib.util.spec_from_file_location("dfb_report_server", MODULE_PATH)
SERVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERVER)


class TelemetryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        SERVER.DATA_DIR = self.temp.name
        SERVER.DB_PATH = os.path.join(self.temp.name, "telemetry.db")
        SERVER.REPORT_DIR = os.path.join(self.temp.name, "reports")
        SERVER.TELEMETRY_PEPPER = "test-pepper"
        os.makedirs(SERVER.REPORT_DIR)
        SERVER._init_db()

    def tearDown(self):
        self.temp.cleanup()

    def payload(self, install_id, event="launch"):
        return {
            "installId": install_id,
            "event": event,
            "version": "0.18.0",
            "os": "Windows 11 Pro",
            "build": "26100",
            "cpu": "Example CPU",
            "gpuVendor": "NVIDIA",
            "gpuModel": "NVIDIA GeForce RTX 4070 SUPER",
            "gpuModelVerified": True,
            "ramGb": 31.8,
            "deviceType": "desktop",
            "ok": 5,
            "failed": 1,
        }

    def test_unique_users_and_daily_events(self):
        now = 1786248000
        first = "11111111-1111-4111-8111-111111111111"
        second = "22222222-2222-4222-8222-222222222222"
        SERVER._record_telemetry(self.payload(first), now)
        SERVER._record_telemetry(self.payload(first), now + 60)
        SERVER._record_telemetry(self.payload(first, "apply"), now + 120)
        SERVER._record_telemetry(self.payload(second), now + 180)
        stats = SERVER._build_stats(now + 180)
        self.assertEqual(2, stats["totals"]["users"])
        self.assertEqual(2, stats["totals"]["active15m"])
        self.assertEqual(3, stats["totals"]["launchesToday"])
        self.assertEqual(1, stats["totals"]["appliesToday"])
        self.assertEqual(5, stats["period"]["apply_ok"])
        self.assertEqual(1, stats["period"]["apply_failed"])
        self.assertEqual("0.18.0", stats["versions"][0]["label"])
        self.assertEqual(2, stats["versions"][0]["value"])
        self.assertEqual("NVIDIA GeForce RTX 4070 SUPER", stats["gpus"][0]["label"])

    def test_performance_session_aggregates(self):
        now = 1786248000
        data = self.payload("55555555-5555-4555-8555-555555555555", "performance")
        data.update({
            "durationSec": 120,
            "avgFps": 144.2,
            "fps1Low": 93.5,
            "gpuUtilAvg": 97.1,
            "gpuUtilMax": 100,
            "gpuTempAvg": 72.4,
            "gpuTempMax": 76,
            "gpuPowerAvg": 151.7,
            "gpuPowerMax": 180.2,
        })
        SERVER._record_telemetry(data, now)
        unverified = dict(data)
        unverified.update({"installId": "66666666-6666-4666-8666-666666666666", "gpuModel": "NVIDIA GeForce GTX 1050 Ti", "gpuModelVerified": False})
        SERVER._record_telemetry(unverified, now + 1)
        stats = SERVER._build_stats(now)
        self.assertEqual(1, stats["performance"]["sessions"])
        self.assertEqual(144.2, stats["performance"]["avgFps"])
        self.assertEqual(93.5, stats["performance"]["fps1Low"])
        self.assertEqual(97.1, stats["performance"]["gpuUtil"])
        self.assertEqual(1, stats["performanceByGpu"][0]["sessions"])

    def test_performance_improvement_uses_coarse_tiers_and_paired_clients(self):
        now = 1786248000
        install_id = "77777777-7777-4777-8777-777777777777"
        baseline = self.payload(install_id, "performance")
        baseline.update({
            "configTier": "baseline", "durationSec": 120,
            "avgFps": 100, "fps1Low": 70, "gpuUtilAvg": 80,
            "gpuTempAvg": 75, "gpuPowerAvg": 150,
        })
        optimized = dict(baseline)
        optimized.update({
            "configTier": "full", "avgFps": 120, "fps1Low": 85,
            "gpuUtilAvg": 90, "gpuTempAvg": 72, "gpuPowerAvg": 145,
        })
        SERVER._record_telemetry(baseline, now)
        SERVER._record_telemetry(optimized, now + 60)

        # 没有同一匿名设备的基线时只进入配置绝对值，不进入“提升”配对。
        unpaired = dict(optimized)
        unpaired.update({"installId": "88888888-8888-4888-8888-888888888888", "avgFps": 180})
        SERVER._record_telemetry(unpaired, now + 120)

        stats = SERVER._build_stats(now + 120)
        improvement = stats["performanceImprovement"]
        self.assertEqual(1, improvement["comparisons"])
        self.assertEqual(1, improvement["matchedClients"])
        self.assertEqual(20.0, improvement["fpsDelta"])
        self.assertEqual(15.0, improvement["fps1LowDelta"])
        self.assertEqual(10.0, improvement["gpuUtilDelta"])
        self.assertEqual(-3.0, improvement["gpuTempDelta"])
        self.assertEqual(-5.0, improvement["gpuPowerDelta"])

        by_tier = {row["tier"]: row for row in stats["performanceByConfig"]}
        self.assertEqual({"baseline", "light", "balanced", "full"}, set(by_tier))
        self.assertEqual(2, by_tier["full"]["sessions"])
        self.assertEqual(1, by_tier["full"]["comparisons"])
        self.assertEqual("深度（21+ 项）", by_tier["full"]["label"])

    def test_rejects_identifying_or_oversized_fields(self):
        bad = self.payload("not-a-guid")
        with self.assertRaises(ValueError):
            SERVER._record_telemetry(bad, 1786248000)
        good = self.payload("33333333-3333-4333-8333-333333333333")
        good["gpuModel"] = "x" * 1000
        SERVER._record_telemetry(good, 1786248000)
        conn = SERVER._connect()
        try:
            value = conn.execute("SELECT gpu_model FROM clients").fetchone()[0]
        finally:
            conn.close()
        self.assertEqual(160, len(value))

    def test_http_telemetry_and_protected_stats(self):
        SERVER.ADMIN_API_TOKEN = "test-admin-token"
        httpd = SERVER.http.server.ThreadingHTTPServer(("127.0.0.1", 0), SERVER.Handler)
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        base = "http://127.0.0.1:%d" % httpd.server_address[1]
        try:
            raw = json.dumps(self.payload("44444444-4444-4444-8444-444444444444")).encode("utf-8")
            request = urllib.request.Request(base + "/report/telemetry", data=raw, headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(request, timeout=3) as response:
                self.assertEqual(200, response.status)
            request = urllib.request.Request(
                base + "/report/upload",
                data="synthetic diagnostic".encode("utf-8"),
                headers={"Content-Type": "text/plain; charset=utf-8"},
            )
            with urllib.request.urlopen(request, timeout=3) as response:
                report_result = json.load(response)
            self.assertRegex(report_result["code"], r"^DFB-[A-Z2-9]{4}$")
            request = urllib.request.Request(base + "/api/stats", headers={"X-DFB-Admin-Token": "test-admin-token"})
            with urllib.request.urlopen(request, timeout=3) as response:
                stats = json.load(response)
            self.assertEqual(1, stats["totals"]["users"])
            self.assertEqual(1, stats["diagnosticReports"]["count"])
            with self.assertRaises(urllib.error.HTTPError) as denied:
                urllib.request.urlopen(base + "/api/stats", timeout=3)
            self.assertEqual(403, denied.exception.code)
        finally:
            httpd.shutdown()
            httpd.server_close()
            thread.join(timeout=3)

    def test_migrates_pre_019_tables(self):
        os.remove(SERVER.DB_PATH)
        import sqlite3
        conn = sqlite3.connect(SERVER.DB_PATH)
        try:
            conn.execute("""CREATE TABLE clients (
                client_hash TEXT PRIMARY KEY, first_seen INTEGER NOT NULL, last_seen INTEGER NOT NULL,
                app_version TEXT NOT NULL DEFAULT '', os_name TEXT NOT NULL DEFAULT '',
                os_build TEXT NOT NULL DEFAULT '', cpu_model TEXT NOT NULL DEFAULT '',
                gpu_vendor TEXT NOT NULL DEFAULT '', gpu_model TEXT NOT NULL DEFAULT '',
                ram_gb REAL NOT NULL DEFAULT 0, device_type TEXT NOT NULL DEFAULT '')""")
            conn.execute("""CREATE TABLE performance_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT, client_hash TEXT NOT NULL,
                recorded_at INTEGER NOT NULL, day TEXT NOT NULL,
                app_version TEXT NOT NULL DEFAULT '', gpu_model TEXT NOT NULL DEFAULT '',
                duration_sec INTEGER NOT NULL DEFAULT 0, avg_fps REAL NOT NULL DEFAULT 0,
                fps_1_low REAL NOT NULL DEFAULT 0, gpu_util_avg REAL NOT NULL DEFAULT 0,
                gpu_util_max REAL NOT NULL DEFAULT 0, gpu_temp_avg REAL NOT NULL DEFAULT 0,
                gpu_temp_max REAL NOT NULL DEFAULT 0, gpu_power_avg REAL NOT NULL DEFAULT 0,
                gpu_power_max REAL NOT NULL DEFAULT 0)""")
            conn.commit()
        finally:
            conn.close()
        SERVER._init_db()
        conn = SERVER._connect()
        try:
            columns = {row[1] for row in conn.execute("PRAGMA table_info(clients)")}
            performance_columns = {row[1] for row in conn.execute("PRAGMA table_info(performance_sessions)")}
        finally:
            conn.close()
        self.assertIn("gpu_model_verified", columns)
        self.assertIn("config_tier", performance_columns)


if __name__ == "__main__":
    unittest.main()
