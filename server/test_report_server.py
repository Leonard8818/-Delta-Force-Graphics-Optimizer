import importlib.util
import datetime as dt
import json
import os
import sqlite3
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
import uuid


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
        SERVER.ADMIN_API_TOKEN = ""
        SERVER._hits.clear()
        SERVER._hits_last_sweep = 0.0
        os.makedirs(SERVER.REPORT_DIR)
        SERVER._init_db()

    def tearDown(self):
        self.temp.cleanup()

    def payload(self, install_id, event="launch", version="0.19.4"):
        return {
            "installId": install_id,
            "event": event,
            "version": version,
            "os": "Windows 11 Pro",
            "build": "26100",
            "cpu": "Example CPU",
            "gpuVendor": "NVIDIA",
            "gpuModel": "NVIDIA GeForce RTX 4070 SUPER",
            "gpuModelVerified": True,
            "driverVersion": "600.00",
            "gpuCount": 1,
            "displayMode": "2560x1440@165",
            "ramGb": 31.8,
            "deviceType": "desktop",
            "ok": 5,
            "failed": 1,
        }

    def analysis_fields(self):
        return {
            "cpuCores": 8,
            "cpuThreads": 16,
            "cpuPackages": 1,
            "memoryType": "DDR5",
            "memoryConfiguredMhz": 6000,
            "memoryRatedMhz": 6400,
            "memoryModuleCount": 2,
            "virtualDisplayCount": 1,
            "pagefileAutoManaged": False,
            "gpuReportedModelDiffers": True,
        }

    def performance_payload(self, install_id, tier="baseline", avg_fps=100, fps_1_low=70):
        data = self.payload(install_id, "performance")
        data.update({
            "configTier": tier,
            "durationSec": 120,
            "avgFps": avg_fps,
            "fps1Low": fps_1_low,
            "gpuUtilAvg": 80,
            "gpuUtilMax": 90,
            "gpuTempAvg": 70,
            "gpuTempMax": 75,
            "gpuPowerAvg": 150,
            "gpuPowerMax": 170,
        })
        return data

    def performance_context_payload(
        self, install_id, item_ids=None, scheme="baseline", avg_fps=100, fps_1_low=70,
        complete=True,
    ):
        item_ids = sorted(list(item_ids or []))
        data = self.performance_payload(
            install_id, SERVER._performance_config_tier(len(item_ids)), avg_fps, fps_1_low,
        )
        data.update({
            "version": "0.22.1",
            "optimizationScheme": scheme,
            "optimizationItemSetHash": SERVER._tuning_item_set_hash(item_ids) if item_ids else "",
            "optimizationItemIds": item_ids,
            "optimizationItemsComplete": complete,
        })
        return data

    def operation_payload(
        self, install_id, event="apply", operation_id=None, result="succeeded",
        item_ids=None, succeeded_ids=None, failed_ids=None, skipped_ids=None,
        changed_ids=None, reboot_ids=None, failed_units=0, skipped_units=0,
        residual_count=0, backup_status=None, verification_status=None,
        restore_mode=None, related_operation_ids=None,
    ):
        item_ids = ["gpu-pref"] if item_ids is None else list(item_ids)
        succeeded_ids = list(item_ids) if succeeded_ids is None else list(succeeded_ids)
        failed_ids = [] if failed_ids is None else list(failed_ids)
        skipped_ids = [] if skipped_ids is None else list(skipped_ids)
        changed_ids = list(succeeded_ids) if changed_ids is None else list(changed_ids)
        data = self.payload(install_id, event, "0.22.0")
        data["operation"] = {
            "schemaVersion": 1,
            "operationId": operation_id or str(uuid.uuid4()),
            "source": "restore_manager" if event == "restore" else "manual_selection",
            "result": result,
            "itemIds": item_ids,
            "changedItemIds": changed_ids,
            "succeededItemIds": succeeded_ids,
            "failedItemIds": failed_ids,
            "skippedItemIds": skipped_ids,
            "attentionItemIds": [],
            "rebootItemIds": [] if reboot_ids is None else list(reboot_ids),
            "relatedOperationIds": [] if related_operation_ids is None else list(related_operation_ids),
            "succeededUnitCount": len(succeeded_ids),
            "failedUnitCount": failed_units,
            "skippedUnitCount": skipped_units,
            "backupStatus": backup_status or ("not_required" if event == "restore" else "created"),
            "restoreMode": restore_mode or ("selected_items" if event == "restore" else "not_applicable"),
            "verificationStatus": verification_status or ("immediate_verified" if event == "restore" else "not_applicable"),
            "residualCount": residual_count,
        }
        return data

    def authenticate(self, payload, now, token=None, event_id=None):
        token = token or SERVER._issue_device_token(payload["installId"], now)["deviceToken"]
        payload.update({
            "deviceToken": token,
            "eventId": event_id or str(uuid.uuid4()),
            "sentAt": now,
        })
        return payload

    def seed_weekly_client(
        self, client_hash, first_day, active_day, version="1.0.0",
        gpu="NVIDIA Test GPU", device_type="desktop", authenticated=True,
        launches=1, applies=0, restores=0, apply_ok=0, apply_failed=0,
        restore_ok=0, restore_failed=0,
    ):
        first_seen = int(dt.datetime.combine(first_day, dt.time.min, tzinfo=dt.timezone.utc).timestamp())
        conn = SERVER._connect()
        try:
            with conn:
                conn.execute(
                    """INSERT INTO clients (
                           client_hash, first_seen, last_seen, app_version, gpu_model,
                           gpu_model_verified, device_type, authenticated_last_seen
                       ) VALUES (?, ?, ?, ?, ?, 1, ?, ?)""",
                    (client_hash, first_seen, first_seen, version, gpu, device_type, first_seen if authenticated else 0),
                )
                conn.execute(
                    """INSERT INTO daily_usage (
                           day, client_hash, launches, applies, restores, apply_ok,
                           apply_failed, restore_ok, restore_failed
                       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (active_day.isoformat(), client_hash, launches, applies, restores,
                     apply_ok, apply_failed, restore_ok, restore_failed),
                )
        finally:
            conn.close()

    def seed_weekly_performance(
        self, client_hash, day, tier, avg_fps, fps_1_low,
        gpu="NVIDIA Test GPU", authenticated=True, temperature=70, power=150,
    ):
        recorded_at = int(dt.datetime.combine(day, dt.time(hour=12), tzinfo=dt.timezone.utc).timestamp())
        conn = SERVER._connect()
        try:
            with conn:
                conn.execute(
                    """INSERT INTO performance_sessions (
                           client_hash, recorded_at, day, app_version, gpu_model,
                           config_tier, duration_sec, avg_fps, fps_1_low,
                           gpu_temp_avg, gpu_power_avg, authenticated
                       ) VALUES (?, ?, ?, '1.0.0', ?, ?, 120, ?, ?, ?, ?, ?)""",
                    (client_hash, recorded_at, day.isoformat(), gpu, tier, avg_fps,
                     fps_1_low, temperature, power, 1 if authenticated else 0),
                )
        finally:
            conn.close()

    def tuning_start_payload(self, install_id, experiment_id):
        data = self.payload(install_id, "tuning", "0.20.0")
        data.update({
            "tuningType": "experiment_started",
            "experimentId": experiment_id,
            "status": "baseline_pending",
            "goal": "smoothness",
            "riskLevel": "low",
            "allowReboot": False,
            "allowHigherPower": False,
            "maxTempIncreaseC": 3,
            "maxPowerIncreasePct": 0,
            "libraryVersion": 1,
            "gameVersion": "1.0",
            "driverVersion": "600.00",
            "baselineVariantId": experiment_id + ".baseline",
        })
        return data

    def tuning_variant_payload(
        self, install_id, experiment_id, group_id="G1", variant_id=None,
        control_variant_id=None, sequence_no=5, item_ids=None,
    ):
        item_ids = list(SERVER.TUNING_GROUP_ITEMS[group_id]) if item_ids is None else list(item_ids)
        data = self.payload(install_id, "tuning", "0.20.0")
        data.update({
            "tuningType": "variant_applied",
            "experimentId": experiment_id,
            "status": "variant_applied",
            "variantId": variant_id or experiment_id + "." + group_id,
            "controlVariantId": control_variant_id or experiment_id + ".baseline",
            "sequenceNo": sequence_no,
            "groupId": group_id,
            "itemSetHash": SERVER._tuning_item_set_hash(item_ids),
            "itemIds": item_ids,
            "source": "rules",
            "riskLevel": "low",
            "requiresReboot": False,
            "applyResult": "succeeded",
            "appliedCount": len(item_ids),
            "failedCount": 0,
            "skippedCount": 0,
        })
        return data

    def tuning_run_payload(
        self, install_id, experiment_id, variant_id, run_id,
        validity="valid", invalid_reason="", avg_fps=110, fps_1_low=70,
        temperature=70, power=150, p99_frame_ms=18, stutter_50ms=2,
        stutter_100ms=0, order_controlled=True, run_no=1, sequence_no=1,
        settings_hash=None, environment_hash=None,
    ):
        data = self.payload(install_id, "tuning", "0.20.0")
        data.update({
            "tuningType": "run_completed",
            "experimentId": experiment_id,
            "runId": run_id,
            "variantId": variant_id,
            "runNo": run_no,
            "sequenceNo": sequence_no,
            "validity": validity,
            "invalidReason": invalid_reason,
            "durationSec": 120 if validity == "valid" else 30,
            "avgFps": avg_fps,
            "fps1Low": fps_1_low,
            "p99FrameMs": p99_frame_ms,
            "stutter50Ms": stutter_50ms,
            "stutter100Ms": stutter_100ms,
            "gpuUtilAvg": 85,
            "gpuTempAvg": temperature,
            "gpuPowerAvg": power,
            "settingsHash": settings_hash or "a" * 64,
            "environmentHash": environment_hash or "b" * 64,
            "orderControlled": order_controlled,
        })
        return data

    def tuning_complete_payload(
        self, install_id, experiment_id, result="found_better", winning_variant_id=None,
        auto_rollback=False,
    ):
        status = {
            "found_better": "completed",
            "no_significant_gain": "completed",
            "rolled_back": "rolled_back",
            "cancelled": "cancelled",
            "failed": "failed",
        }[result]
        data = self.payload(install_id, "tuning", "0.20.0")
        data.update({
            "tuningType": "experiment_completed",
            "experimentId": experiment_id,
            "status": status,
            "result": result,
            "stopReason": "completed" if result in ("found_better", "no_significant_gain") else "no_improvement",
            "winningVariantId": winning_variant_id or "",
            "autoRollback": auto_rollback,
        })
        return data

    def seed_qualified_tuning_experiment(
        self, client_hash, experiment_id, timestamp, group_id="G1", retained=True,
    ):
        baseline = experiment_id + ".baseline"
        variant = experiment_id + "." + group_id
        items = list(SERVER.TUNING_GROUP_ITEMS[group_id])
        conn = SERVER._connect()
        try:
            with conn:
                conn.execute(
                    """INSERT OR IGNORE INTO clients (
                           client_hash, first_seen, last_seen, app_version, gpu_model,
                           gpu_model_verified, device_type, authenticated_last_seen
                       ) VALUES (?, ?, ?, '0.20.0', 'NVIDIA Test GPU', 1, 'desktop', ?)""",
                    (client_hash, timestamp, timestamp, timestamp),
                )
                conn.execute(
                    """INSERT INTO tuning_experiments (
                           experiment_id, client_hash, created_at, completed_at, status,
                           goal, risk_level, max_temp_increase, max_power_increase,
                           library_version, app_version, gpu_model, baseline_variant_id,
                           winning_variant_id, result
                        ) VALUES (?, ?, ?, ?, 'completed', 'smoothness', 'low', 3, 0, 1,
                                  '0.20.0', 'NVIDIA Test GPU', ?, ?, ?)""",
                    (
                        experiment_id, client_hash, timestamp, timestamp + 100, baseline,
                        variant if retained else None,
                        "found_better" if retained else "no_significant_gain",
                    ),
                )
                conn.execute(
                    """INSERT INTO tuning_variants (
                           variant_id, experiment_id, sequence_no, group_id, display_name,
                           item_set_hash, item_ids_json, source, risk_level, status
                       ) VALUES (?, ?, 0, 'baseline', 'baseline', ?, '[]', 'manual', 'low', 'baseline')""",
                    (baseline, experiment_id, SERVER._tuning_item_set_hash([])),
                )
                conn.execute(
                    """INSERT INTO tuning_variants (
                           variant_id, experiment_id, sequence_no, group_id, display_name,
                           item_set_hash, item_ids_json, source, risk_level, status,
                           control_variant_id, apply_result, applied_count
                        ) VALUES (?, ?, 5, ?, ?, ?, ?, 'rules', 'low',
                                 'variant_applied', ?, 'succeeded', ?)""",
                    (
                        variant, experiment_id, group_id, group_id,
                        SERVER._tuning_item_set_hash(items), json.dumps(items), baseline,
                        len(items),
                    ),
                )
                run_specs = [
                    (baseline, 1, 100, 60, 70, "a" * 64),
                    (baseline, 2, 101, 61, 70, "a" * 64),
                    (baseline, 3, 99, 59, 70, "a" * 64),
                    (baseline, 4, 100, 60, 70, "a" * 64),
                    (variant, 1, 110, 72, 71, "c" * 64),
                    (baseline, 5, 100, 60, 70, "a" * 64),
                    (variant, 2, 111, 73, 71, "c" * 64),
                ]
                for sequence, (variant_id, run_no, avg, low, temp, settings_hash) in enumerate(run_specs, 1):
                    conn.execute(
                        """INSERT INTO tuning_runs (
                               run_id, experiment_id, variant_id, run_no, sequence_no,
                               started_at, completed_at, validity, duration_sec, avg_fps,
                               fps_1_low, p99_frame_ms, stutter_50ms, stutter_100ms,
                               gpu_temp_avg, settings_hash, environment_hash, order_controlled
                           ) VALUES (?, ?, ?, ?, ?, ?, ?, 'valid', 120, ?, ?, 18, 1, 0,
                                     ?, ?, ?, 1)""",
                        (
                            experiment_id + ".run-" + str(sequence), experiment_id,
                            variant_id, run_no, sequence, timestamp, timestamp + 100,
                            avg, low, temp, settings_hash, "b" * 64,
                        ),
                    )
        finally:
            conn.close()

    def test_legacy_usage_is_accepted_and_distributions_are_integer_counts(self):
        now = 1786248000
        first = "11111111-1111-4111-8111-111111111111"
        second = "22222222-2222-4222-8222-222222222222"
        SERVER._record_telemetry(self.payload(first, version="0.19.3"), now)
        SERVER._record_telemetry(self.payload(first, version="0.19.3"), now + 60)
        SERVER._record_telemetry(self.payload(first, "apply", "0.19.3"), now + 120)
        SERVER._record_telemetry(self.payload(second, version="0.19.3"), now + 180)
        stats = SERVER._build_stats(now + 180)
        self.assertEqual(2, stats["totals"]["users"])
        self.assertEqual(3, stats["totals"]["launchesToday"])
        self.assertEqual(1, stats["totals"]["appliesToday"])
        self.assertEqual(0, stats["dataQuality"]["authenticatedClients"])
        self.assertEqual(0.5, stats["dataQuality"]["weightedUsers"])
        self.assertEqual(0.8, stats["dataQuality"]["weightedLaunches"])
        self.assertEqual(2, stats["versions"][0]["value"])
        public = SERVER._build_public_stats(now + 180)
        self.assertEqual(2, public["users"])
        self.assertEqual(3, public["totalLaunches"])
        self.assertEqual(1, public["totalApplies"])
        self.assertEqual(5, public["totalApplyOk"])
        self.assertEqual("Asia/Shanghai", public["timezone"])
        self.assertEqual(
            {"users", "active7d", "active15m", "active60m", "launchesToday",
             "totalLaunches", "totalApplies", "totalApplyOk"},
            set(public["trends"]),
        )
        for key, values in public["trends"].items():
            self.assertEqual(8 if key in {"active15m", "active60m"} else 7, len(values))
            self.assertTrue(all(isinstance(value, int) and value >= 0 for value in values))
        self.assertEqual(public["users"], public["trends"]["users"][-1])
        self.assertEqual(public["active7d"], public["trends"]["active7d"][-1])
        self.assertEqual(public["active15m"], public["trends"]["active15m"][-1])
        self.assertEqual(public["active60m"], public["trends"]["active60m"][-1])
        self.assertEqual(public["launchesToday"], public["trends"]["launchesToday"][-1])
        self.assertEqual(public["totalLaunches"], public["trends"]["totalLaunches"][-1])
        self.assertEqual(public["totalApplies"], public["trends"]["totalApplies"][-1])
        self.assertEqual(public["totalApplyOk"], public["trends"]["totalApplyOk"][-1])

    def test_structured_optimization_operations_are_persisted_and_aggregated(self):
        now = 1786248000
        install_id = "12121212-1212-4121-8121-121212121212"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        apply_id = str(uuid.uuid4())
        apply = self.authenticate(
            self.operation_payload(
                install_id, operation_id=apply_id,
                item_ids=["gpu-pref", "timer-resolution"],
                succeeded_ids=["gpu-pref", "timer-resolution"],
            ),
            now, token,
        )
        result = SERVER._record_telemetry(apply, now)
        self.assertTrue(result["operationAccepted"])

        restore = self.authenticate(
            self.operation_payload(
                install_id, event="restore", result="partial",
                item_ids=["gpu-pref", "timer-resolution"],
                succeeded_ids=["gpu-pref"], failed_ids=["timer-resolution"],
                failed_units=1, residual_count=1, verification_status="failed",
                related_operation_ids=[apply_id],
            ),
            now + 1, token,
        )
        SERVER._record_telemetry(restore, now + 1)

        conn = SERVER._connect()
        try:
            rows = [dict(row) for row in conn.execute(
                "SELECT * FROM optimization_operations ORDER BY recorded_at"
            )]
            client = dict(conn.execute(
                "SELECT * FROM clients WHERE client_hash=?",
                (SERVER._client_hash(install_id),),
            ).fetchone())
        finally:
            conn.close()
        self.assertEqual(2, len(rows))
        self.assertEqual(apply_id, rows[0]["operation_id"])
        self.assertEqual(SERVER._tuning_item_set_hash(["gpu-pref", "timer-resolution"]), rows[0]["item_set_hash"])
        self.assertEqual(["gpu-pref", "timer-resolution"], json.loads(rows[0]["item_ids_json"]))
        self.assertEqual("failed", rows[1]["verification_status"])
        self.assertEqual([apply_id], json.loads(rows[1]["related_operation_ids_json"]))
        self.assertEqual("600.00", client["driver_version"])
        self.assertEqual(1, client["gpu_count"])
        self.assertEqual("2560x1440@165", client["display_mode"])

        experiments = SERVER._build_stats(now + 1)["experiments"]
        self.assertEqual(2, experiments["dataReadiness"]["operations"])
        self.assertEqual(1, experiments["dataReadiness"]["operationDevices"])
        self.assertEqual(2, experiments["dataReadiness"]["exactItemOperations"])
        self.assertEqual(1, experiments["operationSummary"]["applies"])
        self.assertEqual(1, experiments["operationSummary"]["restores"])
        self.assertEqual(1, experiments["operationSummary"]["partial"])
        self.assertEqual(1, experiments["operationSummary"]["restoreFailed"])
        self.assertEqual(1, experiments["operationSummary"]["residualUnits"])
        self.assertEqual(2, experiments["items"][0]["operations"])
        self.assertNotIn(SERVER._client_hash(install_id), json.dumps(experiments))

    def test_analysis_fields_are_persisted_without_breaking_historical_payloads(self):
        now = 1786248000
        install_id = "23232323-2323-4232-8232-232323232323"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        operation = self.operation_payload(install_id)
        operation.update(self.analysis_fields())
        SERVER._record_telemetry(self.authenticate(operation, now, token), now)

        experiment_id = "exp_analysis_fields"
        tuning = self.tuning_start_payload(install_id, experiment_id)
        tuning.update(self.analysis_fields())
        SERVER._record_telemetry(self.authenticate(tuning, now + 1, token), now + 1)
        # A later old client payload has no analysis fields and must not erase known values.
        SERVER._record_telemetry(self.payload(install_id, version="0.19.3"), now + 2)

        conn = SERVER._connect()
        try:
            client = dict(conn.execute(
                "SELECT * FROM clients WHERE client_hash=?", (SERVER._client_hash(install_id),)
            ).fetchone())
            recorded_operation = dict(conn.execute(
                "SELECT * FROM optimization_operations"
            ).fetchone())
            recorded_experiment = dict(conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone())
        finally:
            conn.close()
        expected = {
            "cpu_cores": 8, "cpu_threads": 16, "cpu_packages": 1,
            "memory_type": "DDR5", "memory_configured_mhz": 6000,
            "memory_rated_mhz": 6400, "memory_module_count": 2,
            "virtual_display_count": 1, "pagefile_auto_managed": 0,
            "gpu_reported_model_differs": 1,
        }
        for key, value in expected.items():
            self.assertEqual(value, client[key], key)
            self.assertEqual(value, recorded_operation[key], key)
            self.assertEqual(value, recorded_experiment[key], key)

        experiments = SERVER._build_stats(now + 2)["experiments"]
        configuration = experiments["configurations"][0]
        self.assertEqual(8, configuration["cpuCores"])
        self.assertEqual(1, configuration["cpuPackages"])
        self.assertEqual(6400, configuration["memoryRatedMhz"])
        self.assertEqual(2, configuration["memoryModuleCount"])
        self.assertEqual(1, configuration["gpuCount"])
        self.assertEqual(1, configuration["virtualDisplayCount"])
        self.assertEqual(0, configuration["pagefileAutoManaged"])
        self.assertEqual(1, configuration["gpuReportedModelDiffers"])

    def test_diagnostic_analysis_uses_crlf_history_and_keeps_problem_sample_bias_explicit(self):
        now = 1786248000
        historical = "\r\n".join((
            "DeltaForceBooster 诊断报告",
            "界面版本：v0.20.1",
            "问题标签：low_fps",
            "改善标签：none",
            "== 硬件与系统 ==",
            "CPU：Example Old CPU（8 核 16 线程）",
            "内存：32 GB",
            "显卡（真实）：NVIDIA GeForce RTX 4070（NVIDIA，驱动 599.00）",
            "机型：台式机",
            "显示输出：ToDesk Virtual Display｜1920x1080 @60Hz｜驱动 1.0",
            "== 最近游戏性能记录 ==",
            "2026-08-01T00:00:00Z｜NVIDIA GeForce RTX 4070｜120s｜平均 100 FPS｜1% Low 60 FPS",
            "相关进程：RTSS、Discord",
            "== 运行日志 ==",
            "执行失败：参数类型不匹配",
        ))
        structured = "\r\n".join((
            "DeltaForceBooster 诊断报告",
            "界面版本：v0.23.0",
            "问题标签：partial_black_screen,stutter",
            "改善标签：none",
            "== 分析字段（schema v2） ==",
            "diagnostic_schema=2",
            "app_version=0.23.0",
            "feedback_issue_ids=partial_black_screen,stutter",
            "feedback_benefit_ids=",
            "config_tier=balanced",
            "optimization_scheme=balanced",
            "optimization_item_ids=dvr-off,game-mode,gpu-pref,prio-separation,fso-off,wer-off,mpo-off,transparency-off,paging-exec,game-priority",
            "optimization_item_set_hash=" + SERVER._tuning_item_set_hash([
                "dvr-off", "game-mode", "gpu-pref", "prio-separation", "fso-off",
                "wer-off", "mpo-off", "transparency-off", "paging-exec", "game-priority",
            ]),
            "optimization_items_complete=true",
            "active_related_process_keys=obs,nvidia-share",
            "cpu_model=Example New CPU",
            "cpu_vendor=Intel",
            "cpu_visible_cores=12",
            "cpu_visible_threads=24",
            "cpu_packages=1",
            "ram_gb=31.8",
            "memory_type=DDR5",
            "memory_configured_mhz=6000",
            "memory_rated_mhz=6400",
            "memory_module_count=2",
            "main_gpu_vendor=NVIDIA",
            "main_gpu_model=NVIDIA GeForce RTX 4070 SUPER",
            "main_gpu_reported_model=NVIDIA GeForce RTX 4070 SUPER",
            "main_gpu_driver_version=32.0.15.9900",
            "main_gpu_model_verified=true",
            "main_gpu_pci_matched=true",
            "main_gpu_reported_model_differs=false",
            "gpu_count=2",
            "device_type=desktop",
            "virtual_display_count=1",
            "display_mode=2560x1440@165",
            "pagefile_auto_managed=true",
            "gpu_panel_status=broker_failed",
            "gpu_panel_installed_keys=nv-cpl",
            "gpu_panel_missing_keys=nv-app",
            "== 最近游戏性能记录 ==",
            "2026-08-02T00:00:00Z｜NVIDIA GeForce RTX 4070 SUPER｜120s｜平均帧率 120 帧/秒｜1% 低帧率 80 帧/秒",
            "     有效性 valid｜帧数 12000｜P99 18ms",
            "== 运行日志 ==",
            "显卡软件检测失败：模拟 broker 失败",
        ))
        for name, contents, modified in (
            ("DFB-ABCD.txt", historical, now - 2),
            ("DFB-EFGH.txt", structured, now - 1),
        ):
            path = os.path.join(SERVER.REPORT_DIR, name)
            with open(path, "w", encoding="utf-8", newline="") as stream:
                stream.write(contents)
            os.utime(path, (modified, modified))

        analysis = SERVER._build_diagnostic_analysis(now - 100, now)
        self.assertEqual(2, analysis["reports"])
        self.assertEqual(1, analysis["schemaV2Reports"])
        self.assertEqual(1, analysis["historicalReports"])
        self.assertEqual(2, analysis["feedbackReports"])
        self.assertEqual(2, analysis["hardwareReports"])
        self.assertEqual(2, analysis["virtualDisplayReports"])
        self.assertEqual(1, analysis["gpuPanelFailures"])
        self.assertEqual(2, analysis["performanceSessions"])
        self.assertEqual(1, analysis["qualityMarkedPerformanceSessions"])
        self.assertEqual(1, analysis["usableHistoricalPerformanceSessions"])
        self.assertEqual(
            {"low_fps": 1, "partial_black_screen": 1, "stutter": 1},
            {row["id"]: row["reports"] for row in analysis["issues"]},
        )
        self.assertEqual(
            {"parameter_type_mismatch": 1, "gpu_panel_detection_failed": 1},
            {row["id"]: row["reports"] for row in analysis["errorSignals"]},
        )
        self.assertEqual({"nv-cpl": 1}, {
            row["key"]: row["reports"] for row in analysis["gpuPanelInstalled"]
        })
        self.assertEqual({"nv-app": 1}, {
            row["key"]: row["reports"] for row in analysis["gpuPanelMissing"]
        })
        self.assertEqual({"rtss": 1, "discord": 1, "obs": 1, "nvidia-share": 1}, {
            row["processId"]: row["reports"] for row in analysis["relatedProcesses"]
        })
        self.assertIn(
            ("partial_black_screen", "obs", 1),
            {(row["issueId"], row["processId"], row["reports"])
             for row in analysis["issueRelatedProcesses"]},
        )
        self.assertEqual({"0.20.1": 1, "0.23.0": 1}, {
            row["version"]: row["reports"] for row in analysis["versions"]
        })
        new_config = next(row for row in analysis["configurations"] if row["cpuModel"] == "Example New CPU")
        self.assertEqual(6400, new_config["memoryRatedMhz"])
        self.assertEqual(2, new_config["gpuCount"])
        self.assertTrue(new_config["pagefileAutoManaged"])
        self.assertEqual("balanced", new_config["configTier"])
        self.assertEqual("balanced", new_config["optimizationScheme"])
        self.assertTrue(new_config["optimizationItemsComplete"])
        self.assertEqual("Intel", new_config["cpuVendor"])
        self.assertEqual("NVIDIA GeForce RTX 4070 SUPER", new_config["gpuReportedModel"])
        self.assertEqual("32.0.15.9900", new_config["gpuDriverVersion"])
        self.assertEqual("2560x1440@165", new_config["displayMode"])
        self.assertTrue(new_config["gpuModelVerified"])
        self.assertTrue(new_config["gpuPciMatched"])
        partial_environment = next(
            row for row in analysis["issueEnvironments"]
            if row["issueId"] == "partial_black_screen"
        )
        self.assertEqual("balanced", partial_environment["configTier"])
        self.assertEqual("32.0.15.9900", partial_environment["gpuDriverVersion"])
        self.assertEqual("2560x1440@165", partial_environment["displayMode"])
        self.assertFalse(analysis["dataQuality"]["rawReportTextExposed"])
        self.assertEqual(
            "descriptive_only_not_causal_training",
            analysis["dataQuality"]["historicalPerformanceUse"],
        )
        self.assertNotIn("模拟 broker 失败", json.dumps(analysis, ensure_ascii=False))
        no_gpu = SERVER._parse_diagnostic_report("\n".join((
            "== 分析字段（schema v2） ==", "diagnostic_schema=2",
            "cpu_model=Example CPU", "main_gpu_model=未检测到",
            "main_gpu_reported_model=未检测到",
        )))
        self.assertEqual("", no_gpu["gpu_model"])
        self.assertEqual("", no_gpu["gpu_reported_model"])

    def test_structured_optimization_operation_requires_auth_and_strict_schema(self):
        now = 1786248000
        install_id = "13131313-1313-4131-8131-131313131313"
        with self.assertRaises(SERVER.TelemetryAuthError):
            SERVER._record_telemetry(self.operation_payload(install_id), now)

        malformed = self.operation_payload(install_id)
        malformed["operation"]["extra"] = True
        with self.assertRaises(SERVER.TelemetryOperationError):
            SERVER._record_telemetry(malformed, now)

        overlap = self.operation_payload(install_id)
        overlap["operation"]["failedItemIds"] = ["gpu-pref"]
        overlap["operation"]["failedUnitCount"] = 1
        overlap["operation"]["result"] = "partial"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        with self.assertRaises(SERVER.TelemetryOperationError):
            SERVER._record_telemetry(self.authenticate(overlap, now, token), now)

        operation_id = str(uuid.uuid4())
        first = self.authenticate(self.operation_payload(install_id, operation_id=operation_id), now, token)
        SERVER._record_telemetry(first, now)
        changed = self.operation_payload(
            install_id, operation_id=operation_id, item_ids=["timer-resolution"],
            succeeded_ids=["timer-resolution"],
        )
        with self.assertRaises(SERVER.TelemetryConflictError):
            SERVER._record_telemetry(self.authenticate(changed, now + 1, token), now + 1)

    def test_structured_optimization_operations_follow_telemetry_retention(self):
        now = 1786248000
        old = now - (SERVER.TELEMETRY_KEEP_DAYS + 1) * 86400
        for install_id, timestamp in (
            ("15151515-1515-4151-8151-151515151515", old),
            ("16161616-1616-4161-8161-161616161616", now),
        ):
            token = SERVER._issue_device_token(install_id, timestamp)["deviceToken"]
            event = self.authenticate(self.operation_payload(install_id), timestamp, token)
            SERVER._record_telemetry(event, timestamp)
        removed = SERVER._run_maintenance(now)
        self.assertEqual(1, removed["optimizationOperations"])
        conn = SERVER._connect()
        try:
            self.assertEqual(1, conn.execute("SELECT COUNT(*) FROM optimization_operations").fetchone()[0])
        finally:
            conn.close()

    def test_token_binding_timestamp_and_replay_protection(self):
        now = 1786248000
        first = "33333333-3333-4333-8333-333333333333"
        second = "44444444-4444-4444-8444-444444444444"
        token_info = SERVER._issue_device_token(first, now)
        with self.assertRaises(SERVER.TelemetryAuthError):
            SERVER._record_telemetry(self.payload(first), now)
        data = self.authenticate(self.payload(first), now, token_info["deviceToken"])
        result = SERVER._record_telemetry(data, now)
        self.assertTrue(result["trusted"])
        with self.assertRaises(SERVER.TelemetryReplayError):
            SERVER._record_telemetry(data, now + 1)

        wrong_device = self.authenticate(self.payload(second), now, token_info["deviceToken"])
        with self.assertRaises(SERVER.TelemetryAuthError):
            SERVER._record_telemetry(wrong_device, now)

        stale = self.authenticate(self.payload(first), now, token_info["deviceToken"])
        stale["sentAt"] = now - SERVER.TELEMETRY_CLOCK_SKEW - 1
        with self.assertRaises(SERVER.TelemetryAuthError):
            SERVER._record_telemetry(stale, now)

    def test_performance_filters_and_daily_limit(self):
        now = 1786248000
        install_id = "55555555-5555-4555-8555-555555555555"
        short = self.authenticate(self.performance_payload(install_id), now)
        short["durationSec"] = SERVER.PERFORMANCE_MIN_DURATION - 1
        with self.assertRaises(SERVER.TelemetryPerformanceError):
            SERVER._record_telemetry(short, now)

        impossible = self.authenticate(self.performance_payload(install_id, avg_fps=60, fps_1_low=90), now)
        with self.assertRaises(SERVER.TelemetryPerformanceError):
            SERVER._record_telemetry(impossible, now)

        out_of_range = self.authenticate(self.performance_payload(install_id), now)
        out_of_range["gpuTempAvg"] = 999
        with self.assertRaises(SERVER.TelemetryPerformanceError):
            SERVER._record_telemetry(out_of_range, now)

        boolean_metric = self.authenticate(self.performance_payload(install_id), now)
        boolean_metric["avgFps"] = True
        with self.assertRaises(SERVER.TelemetryPerformanceError):
            SERVER._record_telemetry(boolean_metric, now)

        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        for offset in range(SERVER.PERFORMANCE_DAILY_LIMIT):
            data = self.authenticate(self.performance_payload(install_id), now + offset, token)
            SERVER._record_telemetry(data, now + offset)
        over_limit = self.authenticate(self.performance_payload(install_id), now + 30, token)
        with self.assertRaises(SERVER.TelemetryDailyLimitError):
            SERVER._record_telemetry(over_limit, now + 30)

    def test_performance_context_is_required_and_cross_validated_from_v0221(self):
        now = 1786248000
        install_id = "56565656-5656-4656-8656-565656565656"
        missing = self.performance_payload(install_id)
        missing["version"] = "0.22.1"
        with self.assertRaisesRegex(SERVER.TelemetryPerformanceError, "missing performance optimization context"):
            SERVER._normalize_telemetry(missing)

        wrong_hash = self.performance_context_payload(
            install_id, ["gpu-pref"], "frame-fix",
        )
        wrong_hash["optimizationItemSetHash"] = "0" * 64
        with self.assertRaisesRegex(SERVER.TelemetryPerformanceError, "hash mismatch"):
            SERVER._normalize_telemetry(wrong_hash)

        wrong_tier = self.performance_context_payload(
            install_id, ["gpu-pref"], "frame-fix",
        )
        wrong_tier["configTier"] = "full"
        with self.assertRaisesRegex(SERVER.TelemetryPerformanceError, "item count and config tier disagree"):
            SERVER._normalize_telemetry(wrong_tier)

        valid = SERVER._normalize_telemetry(self.performance_context_payload(
            install_id, ["gpu-pref"], "frame-fix",
        ))
        self.assertEqual(["gpu-pref"], valid["item_ids"])
        self.assertEqual("frame-fix", valid["optimization_scheme"])
        self.assertEqual(1, valid["item_ids_complete"])

    def test_performance_uses_trusted_median_and_minimum_sample(self):
        now = 1786248000
        values = [100, 101, 102, 103, 900]
        for index, value in enumerate(values):
            install_id = "%08d-0000-4000-8000-%012d" % (index + 1, index + 1)
            data = self.performance_payload(install_id, avg_fps=value, fps_1_low=min(value, 70 + index))
            if index:
                data["gpuTempAvg"] = 0
                data["gpuTempMax"] = 0
            SERVER._record_telemetry(self.authenticate(data, now + index), now + index)

        legacy_id = "66666666-6666-4666-8666-666666666666"
        legacy = self.performance_payload(legacy_id, avg_fps=500, fps_1_low=400)
        legacy["version"] = "0.19.3"
        SERVER._record_telemetry(legacy, now + 10)
        # Preserve the row as historical evidence, but do not let an old failed
        # capture satisfy sample thresholds or enter recommendation metrics.
        conn = SERVER._connect()
        try:
            with conn:
                conn.execute(
                    """INSERT INTO performance_sessions (
                           client_hash, recorded_at, day, app_version, gpu_model, config_tier,
                           duration_sec, avg_fps, fps_1_low, authenticated
                       ) VALUES (?, ?, ?, '0.22.0', 'NVIDIA GeForce RTX 4070 SUPER',
                                 'baseline', 120, 0, 0, 1)""",
                    (
                        SERVER._client_hash("00000001-0000-4000-8000-000000000001"),
                        now + 9,
                        dt.datetime.fromtimestamp(now + 9, SERVER.REPORT_TIMEZONE).date().isoformat(),
                    ),
                )
        finally:
            conn.close()
        stats = SERVER._build_stats(now + 10)
        self.assertEqual(5, stats["performance"]["sessions"])
        self.assertTrue(stats["performance"]["published"])
        self.assertEqual(102.0, stats["performance"]["avgFps"])
        self.assertEqual(72.0, stats["performance"]["fps1Low"])
        self.assertIsNone(stats["performance"]["gpuTemp"])
        self.assertEqual(1, stats["dataQuality"]["legacyPerformanceSessionsExcluded"])
        self.assertEqual(1, stats["dataQuality"]["invalidHistoricalPerformanceSessionsExcluded"])
        self.assertEqual(6, stats["performanceByGpu"][0]["sessions"])
        self.assertEqual(5, stats["performanceByGpu"][0]["trustedSessions"])
        self.assertEqual(1, stats["performanceByGpu"][0]["legacySessions"])
        self.assertTrue(stats["performanceByGpu"][0]["published"])
        self.assertEqual(6, stats["performanceByGpuByDevice"]["desktop"][0]["sessions"])
        self.assertEqual([], stats["performanceByGpuByDevice"]["laptop"])
        self.assertEqual(stats["gpus"], stats["gpusByDevice"]["all"])
        self.assertGreater(stats["gpusByDevice"]["desktop"][0]["value"], 0)
        self.assertEqual("median", stats["dataQuality"]["aggregation"])

        other_temp = tempfile.TemporaryDirectory()
        try:
            SERVER.DB_PATH = os.path.join(other_temp.name, "small.db")
            SERVER._init_db()
            one_id = "77777777-7777-4777-8777-777777777777"
            one = self.authenticate(self.performance_payload(one_id), now)
            SERVER._record_telemetry(one, now)
            small = SERVER._build_stats(now)
            self.assertEqual(1, small["performance"]["sessions"])
            self.assertFalse(small["performance"]["published"])
            self.assertIsNone(small["performance"]["avgFps"])
            self.assertEqual(1, len(small["performanceByGpu"]))
            self.assertEqual(1, small["performanceByGpu"][0]["trustedSessions"])
            self.assertFalse(small["performanceByGpu"][0]["published"])
            self.assertEqual(100.0, small["performanceByGpu"][0]["avgFps"])
        finally:
            SERVER.DB_PATH = os.path.join(self.temp.name, "telemetry.db")
            other_temp.cleanup()

    def test_repeated_sessions_from_one_device_do_not_publish_aggregate(self):
        now = 1786248000
        install_id = "77777777-7777-4777-8777-777777777777"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        for index in range(SERVER.PERFORMANCE_MIN_SAMPLES):
            payload = self.authenticate(
                self.performance_payload(install_id, avg_fps=100 + index),
                now + index,
                token,
            )
            SERVER._record_telemetry(payload, now + index)
        stats = SERVER._build_stats(now + SERVER.PERFORMANCE_MIN_SAMPLES)
        self.assertEqual(SERVER.PERFORMANCE_MIN_SAMPLES, stats["performance"]["sessions"])
        self.assertEqual(1, stats["performance"]["clients"])
        self.assertFalse(stats["performance"]["published"])
        self.assertIsNone(stats["performance"]["avgFps"])

    def test_performance_aggregate_equal_weights_each_independent_device(self):
        rows = []
        for index in range(20):
            rows.append({"client_hash": "frequent", "avg_fps": 500, "fps_1_low": 400,
                         "gpu_util_avg": 90, "gpu_temp_avg": 80, "gpu_power_avg": 300})
        for index, value in enumerate((100, 101, 102, 103), 1):
            rows.append({"client_hash": "device-%d" % index, "avg_fps": value,
                         "fps_1_low": value - 30, "gpu_util_avg": 70,
                         "gpu_temp_avg": 65, "gpu_power_avg": 150})
        aggregate = SERVER._aggregate_performance(rows)
        self.assertTrue(aggregate["published"])
        self.assertEqual("clientMedian", aggregate["aggregation"])
        self.assertEqual(102.0, aggregate["avgFps"])

    def test_performance_aggregate_ignores_non_finite_historical_metrics(self):
        rows = []
        for index, value in enumerate((100, 101, 102, 103, 104)):
            rows.append({"client_hash": "device-%d" % index, "avg_fps": value,
                         "fps_1_low": value - 30, "gpu_util_avg": 70,
                         "gpu_temp_avg": 65, "gpu_power_avg": 150})
        rows.extend([
            {"client_hash": "device-0", "avg_fps": float("inf"), "fps_1_low": "bad",
             "gpu_util_avg": None, "gpu_temp_avg": float("nan"), "gpu_power_avg": 150},
            {"client_hash": "device-0", "avg_fps": "bad", "fps_1_low": float("inf"),
             "gpu_util_avg": 70, "gpu_temp_avg": 65, "gpu_power_avg": 150},
        ])
        aggregate = SERVER._aggregate_performance(rows)
        self.assertTrue(aggregate["published"])
        self.assertEqual(102.0, aggregate["avgFps"])
        self.assertEqual(72.0, aggregate["fps1Low"])

    def test_exact_item_set_performance_is_persisted_and_descriptive_only(self):
        now = 1786248000
        item_ids = ["gpu-pref"]
        for index in range(SERVER.PERFORMANCE_MIN_COMPARISONS):
            install_id = "%08d-2222-4222-8222-%012d" % (index + 20, index + 20)
            token = SERVER._issue_device_token(install_id, now)["deviceToken"]
            baseline = self.authenticate(
                self.performance_context_payload(install_id, [], "baseline", 100, 60), now, token,
            )
            optimized = self.authenticate(
                self.performance_context_payload(install_id, item_ids, "frame-fix", 112, 68),
                now + 60, token,
            )
            SERVER._record_telemetry(baseline, now)
            SERVER._record_telemetry(optimized, now + 60)

        stats = SERVER._build_stats(now + 60)
        view = stats["performanceOptimization"]
        self.assertTrue(view["associationOnly"])
        self.assertEqual("descriptive_association_not_causal", view["interpretation"])
        self.assertEqual(10, view["completeSessions"])
        optimized = next(row for row in view["rows"] if row["itemIds"] == item_ids)
        self.assertEqual("frame-fix", optimized["scheme"])
        self.assertTrue(optimized["comparisonPublished"])
        self.assertEqual(12.0, optimized["fpsDelta"])
        self.assertEqual(8.0, optimized["fps1LowDelta"])
        conn = SERVER._connect()
        try:
            stored = conn.execute(
                "SELECT optimization_scheme, item_set_hash, item_ids_json, item_ids_complete "
                "FROM performance_sessions WHERE item_ids_complete=1 AND item_ids_json<>'[]'"
            ).fetchone()
        finally:
            conn.close()
        self.assertEqual("frame-fix", stored["optimization_scheme"])
        self.assertEqual(SERVER._tuning_item_set_hash(item_ids), stored["item_set_hash"])
        self.assertEqual(item_ids, json.loads(stored["item_ids_json"]))

    def test_paired_improvement_uses_median_and_minimum_comparisons(self):
        now = 1786248000
        deltas = [10, 20, 20, 30, 400]
        for index, delta in enumerate(deltas):
            install_id = "%08d-1111-4111-8111-%012d" % (index + 10, index + 10)
            token = SERVER._issue_device_token(install_id, now)["deviceToken"]
            baseline = self.authenticate(self.performance_payload(install_id, "baseline", 100, 60), now, token)
            optimized = self.authenticate(
                self.performance_payload(install_id, "full", 100 + delta, 70), now + 60, token
            )
            SERVER._record_telemetry(baseline, now)
            SERVER._record_telemetry(optimized, now + 60)

        stats = SERVER._build_stats(now + 60)
        improvement = stats["performanceImprovement"]
        self.assertEqual(5, improvement["comparisons"])
        self.assertTrue(improvement["published"])
        self.assertEqual(20.0, improvement["fpsDelta"])
        by_tier = {row["tier"]: row for row in stats["performanceByConfig"]}
        self.assertTrue(by_tier["full"]["published"])
        self.assertEqual(5, by_tier["full"]["comparisons"])
        self.assertEqual("深度（21+ 项）", by_tier["full"]["label"])

    def test_single_pair_exposes_observed_value_without_publishing_conclusion(self):
        now = 1786248000
        install_id = "12121212-1212-4212-8212-121212121212"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        SERVER._record_telemetry(
            self.authenticate(self.performance_payload(install_id, "baseline", 100, 60), now, token),
            now,
        )
        SERVER._record_telemetry(
            self.authenticate(self.performance_payload(install_id, "full", 112, 68), now + 60, token),
            now + 60,
        )
        improvement = SERVER._build_stats(now + 60)["performanceImprovement"]
        self.assertEqual(1, improvement["comparisons"])
        self.assertFalse(improvement["published"])
        self.assertIsNone(improvement["fpsDelta"])
        self.assertEqual(12.0, improvement["observedFpsDelta"])
        self.assertEqual(8.0, improvement["observedFps1LowDelta"])

    def test_maintenance_removes_expired_data_without_new_upload(self):
        now = 1786248000
        old_report = os.path.join(SERVER.REPORT_DIR, "DFB-ABCD.txt")
        fresh_report = os.path.join(SERVER.REPORT_DIR, "DFB-EFGH.txt")
        for path in (old_report, fresh_report):
            with open(path, "w", encoding="utf-8") as stream:
                stream.write("diagnostic")
        os.utime(old_report, (now - (SERVER.KEEP_DAYS + 1) * 86400,) * 2)
        os.utime(fresh_report, (now,) * 2)

        conn = SERVER._connect()
        try:
            with conn:
                conn.execute(
                    "INSERT INTO performance_sessions (client_hash, recorded_at, day) VALUES ('old', ?, '2000-01-01')",
                    (now - (SERVER.PERFORMANCE_KEEP_DAYS + 1) * 86400,),
                )
                conn.execute(
                    "INSERT INTO performance_sessions (client_hash, recorded_at, day) VALUES ('fresh', ?, '2099-01-01')",
                    (now,),
                )
                conn.execute(
                    "INSERT INTO telemetry_replays VALUES ('old', 'event-old', ?)",
                    (now - (SERVER.REPLAY_KEEP_DAYS + 1) * 86400,),
                )
                conn.execute("INSERT INTO telemetry_replays VALUES ('fresh', 'event-fresh', ?)", (now,))
                old_seen = now - (SERVER.TELEMETRY_KEEP_DAYS + 1) * 86400
                conn.execute(
                    "INSERT INTO clients (client_hash, first_seen, last_seen) VALUES ('expired-client', ?, ?)",
                    (old_seen, old_seen),
                )
                conn.execute(
                    "INSERT INTO clients (client_hash, first_seen, last_seen) VALUES ('fresh-client', ?, ?)",
                    (now, now),
                )
                old_day = time.strftime("%Y-%m-%d", time.gmtime(old_seen))
                fresh_day = time.strftime("%Y-%m-%d", time.gmtime(now))
                conn.execute(
                    "INSERT INTO daily_usage (day, client_hash, launches) VALUES (?, 'expired-client', 1)",
                    (old_day,),
                )
                conn.execute(
                    "INSERT INTO daily_usage (day, client_hash, launches) VALUES (?, 'fresh-client', 1)",
                    (fresh_day,),
                )
                conn.execute(
                    "INSERT INTO website_visits (seen_at, visitor_hash) VALUES (?, 'expired-visitor')",
                    (now - (SERVER.WEBSITE_VISIT_KEEP_DAYS + 1) * 86400,),
                )
                conn.execute(
                    "INSERT INTO website_visits (seen_at, visitor_hash) VALUES (?, 'fresh-visitor')",
                    (now,),
                )
        finally:
            conn.close()

        result = SERVER._run_maintenance(now)
        self.assertEqual(
            {
                "reports": 1,
                "performanceSessions": 1,
                "replayIds": 1,
                "dailyUsage": 1,
                "clients": 1,
                "websiteVisits": 1,
                "optimizationOperations": 0,
            },
            result,
        )
        self.assertFalse(os.path.exists(old_report))
        self.assertTrue(os.path.exists(fresh_report))
        conn = SERVER._connect()
        try:
            self.assertEqual(["fresh"], [row[0] for row in conn.execute("SELECT client_hash FROM performance_sessions")])
            self.assertEqual(["event-fresh"], [row[0] for row in conn.execute("SELECT event_id FROM telemetry_replays")])
            self.assertEqual(["fresh-client"], [row[0] for row in conn.execute("SELECT client_hash FROM clients")])
            self.assertEqual(["fresh-client"], [row[0] for row in conn.execute("SELECT client_hash FROM daily_usage")])
            self.assertEqual(["fresh-visitor"], [row[0] for row in conn.execute("SELECT visitor_hash FROM website_visits")])
        finally:
            conn.close()

    def test_sixty_minute_online_and_website_visits_are_clear_and_separate(self):
        now = int(dt.datetime(2026, 8, 11, 4, 30, tzinfo=dt.timezone.utc).timestamp())
        conn = SERVER._connect()
        try:
            with conn:
                conn.executemany(
                    "INSERT INTO clients (client_hash, first_seen, last_seen) VALUES (?, ?, ?)",
                    [
                        ("online-15m", now - 100, now - 100),
                        ("online-60m", now - 1800, now - 1800),
                        ("offline-60m", now - 3700, now - 3700),
                    ],
                )
        finally:
            conn.close()

        visitor_a = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        visitor_b = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        visitor_c = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
        SERVER._record_website_visit(visitor_a, now - 1200)
        SERVER._record_website_visit(visitor_a, now - 1100)
        SERVER._record_website_visit(visitor_b, now - 3500)
        SERVER._record_website_visit(visitor_c, now - 4000)

        stats = SERVER._build_stats(now)
        self.assertEqual(1, stats["totals"]["active15m"])
        self.assertEqual(2, stats["totals"]["active60m"])
        website = stats["website"]
        self.assertEqual({"views": 3, "visitors": 2}, website["last60m"])
        self.assertEqual({"views": 4, "visitors": 3}, website["today"])
        self.assertEqual(24, len(website["hourly"]))
        self.assertEqual("12:00", website["hourly"][-1]["label"])
        self.assertEqual({"views": 2, "visitors": 1}, {
            key: website["hourly"][-1][key] for key in ("views", "visitors")
        })
        self.assertEqual({"views": 2, "visitors": 2}, {
            key: website["hourly"][-2][key] for key in ("views", "visitors")
        })

        conn = SERVER._connect()
        try:
            stored = [row[0] for row in conn.execute("SELECT DISTINCT visitor_hash FROM website_visits")]
        finally:
            conn.close()
        self.assertEqual(3, len(stored))
        self.assertTrue(all(len(value) == 64 and value not in {visitor_a, visitor_b, visitor_c} for value in stored))
        self.assertNotEqual(SERVER._client_hash(visitor_a), SERVER._website_visitor_hash(visitor_a))

    def test_client_ip_only_trusts_loopback_proxy_and_uses_last_valid_hop(self):
        class FakeHandler:
            def __init__(self, peer, forwarded):
                self.client_address = (peer, 12345)
                self.headers = {"X-Forwarded-For": forwarded}

        proxied = FakeHandler("127.0.0.1", "198.51.100.9, 203.0.113.7")
        self.assertEqual("203.0.113.7", SERVER._client_ip(proxied))
        direct = FakeHandler("192.0.2.10", "198.51.100.9")
        self.assertEqual("192.0.2.10", SERVER._client_ip(direct))
        malformed = FakeHandler("127.0.0.1", "not-an-ip")
        self.assertEqual("127.0.0.1", SERVER._client_ip(malformed))

    def test_http_registration_telemetry_statuses_and_protected_stats(self):
        SERVER.ADMIN_API_TOKEN = "test-admin-token"
        httpd = SERVER.http.server.ThreadingHTTPServer(("127.0.0.1", 0), SERVER.Handler)
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        base = "http://127.0.0.1:%d" % httpd.server_address[1]

        def post(path, payload):
            request = urllib.request.Request(
                base + path,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(request, timeout=3) as response:
                return response.status, json.load(response)

        try:
            install_id = "88888888-8888-4888-8888-888888888888"
            status, registration = post("/report/telemetry/register", {"installId": install_id})
            self.assertEqual(200, status)
            self.assertTrue(registration["deviceToken"].startswith("v1."))

            now = int(time.time())
            event_id = str(uuid.uuid4())
            data = self.authenticate(self.payload(install_id), now, registration["deviceToken"], event_id)
            status, result = post("/report/telemetry", data)
            self.assertEqual(200, status)
            self.assertTrue(result["trusted"])
            with self.assertRaises(urllib.error.HTTPError) as replay:
                post("/report/telemetry", data)
            self.assertEqual(409, replay.exception.code)

            legacy_id = "99999999-9999-4999-8999-999999999999"
            status, legacy = post("/report/telemetry", self.payload(legacy_id, version="0.19.3"))
            self.assertEqual(200, status)
            self.assertFalse(legacy["trusted"])
            self.assertIn("deviceToken", legacy)

            visitor_id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
            status, visit = post("/report/website-visit", {"visitorId": visitor_id})
            self.assertEqual(200, status)
            self.assertTrue(visit["ok"])
            with self.assertRaises(urllib.error.HTTPError) as bad_visit:
                post("/report/website-visit", {"visitorId": "not-a-visitor-id"})
            self.assertEqual(400, bad_visit.exception.code)

            request = urllib.request.Request(base + "/api/stats", headers={"X-DFB-Admin-Token": "test-admin-token"})
            with urllib.request.urlopen(request, timeout=3) as response:
                stats = json.load(response)
            self.assertEqual(2, stats["totals"]["users"])
            self.assertEqual(1, stats["website"]["today"]["views"])
            self.assertEqual(1, stats["website"]["today"]["visitors"])
            self.assertEqual("client_self_reported", stats["dataQuality"]["source"])
            with self.assertRaises(urllib.error.HTTPError) as denied:
                urllib.request.urlopen(base + "/api/stats", timeout=3)
            self.assertEqual(403, denied.exception.code)

            with urllib.request.urlopen(base + "/report/public-stats", timeout=3) as response:
                public_stats = json.load(response)
                self.assertEqual("public, max-age=15", response.headers["Cache-Control"])
            self.assertEqual(2, public_stats["users"])
            self.assertEqual(2, public_stats["totalLaunches"])
            self.assertEqual(7, len(public_stats["trends"]["totalLaunches"]))
            self.assertEqual(8, len(public_stats["trends"]["active15m"]))
            self.assertEqual(8, len(public_stats["trends"]["active60m"]))
            self.assertEqual("Asia/Shanghai", public_stats["timezone"])
        finally:
            httpd.shutdown()
            httpd.server_close()
            thread.join(timeout=3)

    def test_stats_exposes_daily_and_last_24_beijing_hours_in_one_user_analysis(self):
        now = int(dt.datetime(2026, 8, 10, 13, 42, tzinfo=dt.timezone.utc).timestamp())
        hour_12 = int(dt.datetime(2026, 8, 10, 12, 10, tzinfo=dt.timezone.utc).timestamp())
        hour_13 = int(dt.datetime(2026, 8, 10, 13, 5, tzinfo=dt.timezone.utc).timestamp())
        conn = SERVER._connect()
        try:
            with conn:
                conn.executemany(
                    """INSERT INTO clients (client_hash, first_seen, last_seen)
                       VALUES (?, ?, ?)""",
                    [
                        ("hour-a", hour_12, hour_13),
                        ("hour-b", hour_13, hour_13),
                        ("too-old", now - 25 * 3600, now - 25 * 3600),
                    ],
                )
                conn.executemany(
                    """INSERT INTO telemetry_replays (client_hash, event_id, seen_at)
                       VALUES (?, ?, ?)""",
                    [
                        ("hour-a", "a-12", hour_12),
                        ("hour-a", "a-13-1", hour_13),
                        ("hour-a", "a-13-2", hour_13 + 60),
                        ("hour-b", "b-13", hour_13),
                        ("too-old", "old", now - 25 * 3600),
                    ],
                )
        finally:
            conn.close()

        stats = SERVER._build_stats(now=now)
        self.assertEqual(30, len(stats["daily"]))
        self.assertEqual(24, len(stats["hourly"]))
        self.assertEqual("2026-08-09T22:00+08:00", stats["hourly"][0]["hour"])
        self.assertEqual("2026-08-10T21:00+08:00", stats["hourly"][-1]["hour"])
        self.assertEqual({"active": 1, "newUsers": 1}, {
            key: stats["hourly"][-2][key] for key in ("active", "newUsers")
        })
        self.assertEqual({"active": 2, "newUsers": 1}, {
            key: stats["hourly"][-1][key] for key in ("active", "newUsers")
        })
        self.assertEqual("authenticated_event_receipts", stats["dataQuality"]["hourlyActivitySource"])
        self.assertEqual("Asia/Shanghai", stats["dataQuality"]["reportTimezone"])
        self.assertEqual("+08:00", stats["dataQuality"]["reportUtcOffset"])

    def test_rejects_identifying_or_oversized_fields(self):
        with self.assertRaises(ValueError):
            SERVER._record_telemetry(self.payload("not-a-guid"), 1786248000)

        non_finite = self.payload("20202020-2020-4020-8020-202020202020")
        non_finite["ramGb"] = float("nan")
        non_finite["cpuCores"] = True
        normalized = SERVER._normalize_telemetry(non_finite)
        self.assertEqual(0.0, normalized["ram_gb"])
        self.assertEqual(0, normalized["cpu_cores"])
        good = self.payload("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", version="0.19.3")
        good["gpuModel"] = "x" * 1000
        SERVER._record_telemetry(good, 1786248000)
        conn = SERVER._connect()
        try:
            value = conn.execute("SELECT gpu_model FROM clients").fetchone()[0]
        finally:
            conn.close()
        self.assertEqual(160, len(value))

    def test_weekly_date_and_filter_validation(self):
        self.assertEqual(dt.date(2026, 7, 27), SERVER._parse_week_start("2026-07-27"))
        known_now = int(dt.datetime(2026, 8, 10, 12, tzinfo=dt.timezone.utc).timestamp())
        self.assertEqual(dt.date(2026, 8, 3), SERVER._parse_week_start(None, known_now))
        self.assertEqual(1, SERVER._report_number(dt.date(2026, 8, 3)))
        self.assertEqual(2, SERVER._report_number(dt.date(2026, 8, 10)))
        self.assertIsNone(SERVER._report_number(dt.date(2026, 7, 27)))
        # 2026-08-09 23:53 UTC 已是台北 2026-08-10 周一早上；默认周报应切到 8/3–8/9。
        taipei_monday = int(dt.datetime(2026, 8, 9, 23, 53, tzinfo=dt.timezone.utc).timestamp())
        self.assertEqual(dt.date(2026, 8, 3), SERVER._parse_week_start(None, taipei_monday))
        # 台北周日仍属于尚未结束的本周，最近完整周保持 7/27–8/2。
        taipei_sunday = int(dt.datetime(2026, 8, 9, 15, 59, tzinfo=dt.timezone.utc).timestamp())
        self.assertEqual(dt.date(2026, 7, 27), SERVER._parse_week_start(None, taipei_sunday))
        with self.assertRaises(ValueError):
            SERVER._parse_week_start("2026-07-28")
        with self.assertRaises(ValueError):
            SERVER._parse_week_start("2026-7-27")
        with self.assertRaises(ValueError):
            SERVER._parse_weekly_query("/api/weekly?weekStart=2026-07-27&weekStart=2026-07-20")
        with self.assertRaises(ValueError):
            SERVER._parse_weekly_query("/api/weekly?gpu=" + "x" * 161)
        week, filters, live = SERVER._parse_weekly_query(
            "/api/weekly?weekStart=2026-07-27&version=1.0.0&validOnly=1&live=1"
        )
        self.assertEqual(dt.date(2026, 7, 27), week)
        self.assertEqual("1.0.0", filters["version"])
        self.assertTrue(filters["validOnly"])
        self.assertTrue(live)

        period, filters, live = SERVER._parse_weekly_query(
            "/api/weekly?startDate=2026-05-11&endDate=2026-08-10&gpu=NVIDIA+Test+GPU",
            known_now,
        )
        self.assertEqual(SERVER.CustomPeriod(dt.date(2026, 5, 11), dt.date(2026, 8, 10)), period)
        self.assertEqual("NVIDIA Test GPU", filters["gpu"])
        self.assertFalse(live)
        single_day, _, _ = SERVER._parse_weekly_query(
            "/api/weekly?startDate=2026-08-10&endDate=2026-08-10", known_now
        )
        self.assertEqual(SERVER.CustomPeriod(dt.date(2026, 8, 10), dt.date(2026, 8, 10)), single_day)
        selected_days, _, _ = SERVER._parse_weekly_query(
            "/api/weekly?startDate=2026-08-10&endDate=2026-08-10"
            "&compareStartDate=2026-08-01&compareEndDate=2026-08-01",
            known_now,
        )
        self.assertEqual(
            SERVER.CustomPeriod(
                dt.date(2026, 8, 10), dt.date(2026, 8, 10),
                dt.date(2026, 8, 1), dt.date(2026, 8, 1),
            ),
            selected_days,
        )
        invalid_custom_queries = (
            "/api/weekly?startDate=2026-08-01",
            "/api/weekly?endDate=2026-08-01",
            "/api/weekly?weekStart=2026-08-03&startDate=2026-08-03&endDate=2026-08-09",
            "/api/weekly?startDate=2026-08-03&endDate=2026-08-02",
            "/api/weekly?startDate=2026-05-10&endDate=2026-08-10",
            "/api/weekly?startDate=2026-08-03&endDate=2026-08-11",
            "/api/weekly?startDate=2026-8-03&endDate=2026-08-09",
            "/api/weekly?startDate=2026-02-30&endDate=2026-03-01",
            "/api/weekly?startDate=0001-01-01&endDate=0001-01-01",
            "/api/weekly?startDate=2026-08-03&startDate=2026-08-04&endDate=2026-08-09",
            "/api/weekly?compareStartDate=2026-08-01&compareEndDate=2026-08-01",
            "/api/weekly?startDate=2026-08-10&endDate=2026-08-10&compareStartDate=2026-08-01",
            "/api/weekly?startDate=2026-08-09&endDate=2026-08-10&compareStartDate=2026-08-01&compareEndDate=2026-08-01",
        )
        for query in invalid_custom_queries:
            with self.subTest(query=query), self.assertRaises(ValueError):
                SERVER._parse_weekly_query(query, known_now)

    def test_weekly_week_over_week_and_trusted_pairing(self):
        previous = dt.date(2026, 7, 20)
        current = dt.date(2026, 7, 27)
        for index in range(5):
            previous_client = "previous-%d" % index
            current_client = "current-%d" % index
            self.seed_weekly_client(previous_client, previous, previous, launches=1)
            self.seed_weekly_performance(previous_client, previous, "baseline", 100, 60)
            self.seed_weekly_performance(previous_client, previous, "full", 110, 65)
            self.seed_weekly_client(current_client, current, current, launches=2, applies=1, apply_ok=1)
            self.seed_weekly_performance(current_client, current, "baseline", 100, 60)
            self.seed_weekly_performance(current_client, current, "full", 120, 75, temperature=68, power=145)

        self.seed_weekly_client("legacy-outlier", current, current, authenticated=False, launches=0)
        self.seed_weekly_performance(
            "legacy-outlier", current, "baseline", 10, 5, authenticated=False
        )
        self.seed_weekly_performance(
            "legacy-outlier", current, "full", 900, 800, authenticated=False
        )

        report = SERVER._build_weekly_report(current, now=1785700000)
        self.assertEqual(10, report["core"]["launches"]["current"])
        self.assertEqual(5, report["core"]["launches"]["previous"])
        self.assertEqual(100.0, report["core"]["launches"]["changePct"])
        self.assertEqual(10, report["core"]["performanceSessions"]["current"])
        comparison = report["performanceComparison"]["overall"]
        self.assertTrue(comparison["published"])
        self.assertEqual(5, comparison["pairs"])
        self.assertEqual(20.0, comparison["fpsDelta"]["median"])
        self.assertEqual(15.0, comparison["fps1LowDelta"]["median"])
        self.assertEqual(2, report["dataQuality"]["unauthenticatedPerformanceSessionsExcluded"])
        self.assertEqual(8, len(report["trends"]))
        self.assertEqual(
            ["newUsers", "activeUsers"],
            [row["key"] for row in report["usageComparison"][:2]],
        )
        self.assertEqual(report["trends"][-1]["applyDevices"], report["trends"][-1]["applies"])
        self.assertEqual(report["trends"][-1]["pairs"], report["trends"][-1]["pairedClients"])

    def test_weekly_performance_requires_five_independent_devices(self):
        week = dt.date(2026, 7, 27)
        for index in range(4):
            client = "repeat-%d" % index
            self.seed_weekly_client(client, week, week)
            for _ in range(3):
                self.seed_weekly_performance(client, week, "baseline", 100, 60)
            self.seed_weekly_performance(client, week, "balanced", 120, 75)
        report = SERVER._build_weekly_report(week)
        self.assertEqual(16, report["performanceOverall"]["sessions"])
        self.assertEqual(4, report["performanceOverall"]["clients"])
        self.assertFalse(report["performanceOverall"]["published"])
        self.assertIsNone(report["performanceOverall"]["avgFps"])
        self.assertEqual(4, report["performanceComparison"]["overall"]["pairs"])
        self.assertFalse(report["performanceComparison"]["overall"]["published"])
        self.assertIsNone(report["performanceComparison"]["overall"]["fpsDelta"]["median"])
        self.assertFalse(report["gpuRanking"][0]["conclusionPublished"])

    def test_weekly_filters_use_latest_client_profile(self):
        week = dt.date(2026, 7, 27)
        self.seed_weekly_client(
            "desktop-v1", week, week, version="1.0.0", device_type="desktop", launches=2
        )
        self.seed_weekly_client(
            "laptop-v2", week, week, version="2.0.0", gpu="NVIDIA Laptop GPU",
            device_type="laptop", launches=7, applies=1, apply_ok=3,
            apply_failed=1, restores=1, restore_ok=3, restore_failed=1,
        )
        filtered = SERVER._build_weekly_report(
            week,
            {"version": "2.0.0", "gpu": "NVIDIA Laptop GPU", "deviceType": "laptop", "validOnly": True},
        )
        self.assertEqual(1, filtered["core"]["activeUsers"]["current"])
        self.assertEqual(7, filtered["core"]["launches"]["current"])
        self.assertEqual("2.0.0", filtered["filters"]["version"])
        self.assertEqual(25.0, filtered["versionAdoption"][0]["applyFailureRate"])
        self.assertEqual(25.0, filtered["versionAdoption"][0]["restoreFailureRate"])
        self.assertEqual({"1.0.0", "2.0.0"}, {
            row["value"] for row in filtered["filterOptions"]["versions"]
        })

    def test_custom_period_uses_inclusive_range_adjacent_comparison_and_equal_trends(self):
        previous_start = dt.date(2026, 7, 7)
        previous_day = dt.date(2026, 7, 9)
        current_start = dt.date(2026, 7, 10)
        current_end = dt.date(2026, 7, 12)
        after = dt.date(2026, 7, 13)
        before = dt.date(2026, 7, 6)
        profile = {
            "version": "2.0.0", "gpu": "NVIDIA Custom GPU",
            "device_type": "laptop", "authenticated": True,
        }
        self.seed_weekly_client(
            "custom-previous", previous_start, previous_day, launches=2,
            applies=1, apply_ok=1, apply_failed=1, **profile
        )
        self.seed_weekly_client(
            "custom-current", current_start, current_end, launches=5,
            applies=2, apply_ok=2, apply_failed=3, restores=1,
            restore_failed=1, **profile
        )
        self.seed_weekly_client(
            "custom-unmatched", current_start, current_start, version="1.0.0",
            gpu="AMD Other GPU", device_type="desktop", launches=50,
        )
        self.seed_weekly_client("custom-before", before, before, launches=99, **profile)
        self.seed_weekly_client("custom-after", after, after, launches=99, **profile)
        self.seed_weekly_performance(
            "custom-previous", previous_day, "baseline", 90, 55,
            gpu="NVIDIA Custom GPU",
        )
        self.seed_weekly_performance(
            "custom-current", current_end, "baseline", 100, 60,
            gpu="NVIDIA Custom GPU",
        )
        self.seed_weekly_performance(
            "custom-current", current_end, "full", 120, 75,
            gpu="NVIDIA Custom GPU",
        )
        self.seed_weekly_performance(
            "custom-after", after, "full", 999, 999,
            gpu="NVIDIA Custom GPU",
        )

        def noon(day):
            return int(dt.datetime.combine(day, dt.time(hour=12), tzinfo=dt.timezone.utc).timestamp())

        conn = SERVER._connect()
        try:
            with conn:
                conn.executemany(
                    """INSERT INTO tuning_experiments (
                           experiment_id, client_hash, created_at, completed_at, status,
                           goal, risk_level, app_version, gpu_model, result
                       ) VALUES (?, ?, ?, ?, 'completed', 'balanced', 'low', '2.0.0',
                                 'NVIDIA Custom GPU', ?)""",
                    (
                        ("custom-exp-previous", "custom-previous", noon(previous_day), noon(previous_day), "no_significant_gain"),
                        ("custom-exp-current", "custom-current", noon(current_end), noon(current_end), "found_better"),
                        ("custom-exp-after", "custom-after", noon(after), noon(after), "found_better"),
                    ),
                )
        finally:
            conn.close()

        for name, day in (
            ("DFB-ABCD.txt", previous_day),
            ("DFB-EFGH.txt", current_end),
            ("DFB-IJKL.txt", after),
        ):
            path = os.path.join(SERVER.REPORT_DIR, name)
            with open(path, "w", encoding="utf-8") as handle:
                handle.write("diagnostic")
            os.utime(path, (noon(day), noon(day)))

        filters = {
            "version": "2.0.0", "gpu": "NVIDIA Custom GPU",
            "deviceType": "laptop", "validOnly": True,
        }
        report = SERVER._build_custom_period_report(
            current_start, current_end, filters,
            now=noon(dt.date(2026, 8, 10)),
        )
        self.assertEqual("custom", report["week"]["periodMode"])
        self.assertEqual(
            {"start": "2026-07-10", "end": "2026-07-12", "endExclusive": "2026-07-13"},
            report["week"]["current"],
        )
        self.assertEqual(
            {"start": "2026-07-07", "end": "2026-07-09", "endExclusive": "2026-07-10"},
            report["week"]["previous"],
        )
        self.assertEqual(5, report["core"]["launches"]["current"])
        self.assertEqual(2, report["core"]["launches"]["previous"])
        self.assertEqual(2, report["core"]["performanceSessions"]["current"])
        self.assertEqual(1, report["core"]["performanceSessions"]["previous"])
        usage = {row["key"]: row for row in report["usageComparison"]}
        self.assertEqual(2, usage["applies"]["current"])
        self.assertEqual(1, usage["applies"]["previous"])
        self.assertEqual(1, usage["restores"]["current"])
        self.assertEqual(0, usage["restores"]["previous"])
        self.assertEqual(3, report["issues"]["applyFailures"]["current"])
        self.assertEqual(1, report["issues"]["applyFailures"]["previous"])
        self.assertEqual(1, report["issues"]["diagnosticReports"]["current"])
        self.assertEqual(1, report["issues"]["diagnosticReports"]["previous"])
        self.assertEqual(1, report["tuning"]["summary"]["started"]["current"])
        self.assertEqual(1, report["tuning"]["summary"]["started"]["previous"])
        self.assertEqual(1, report["tuning"]["summary"]["foundBetter"]["current"])
        self.assertEqual(["2.0.0"], [row["label"] for row in report["versions"]])
        self.assertEqual(["laptop"], [row["label"] for row in report["devices"]])
        self.assertEqual("NVIDIA Custom GPU", report["gpuRanking"][0]["gpu"])
        self.assertEqual(1, report["versionAdoption"][0]["activeDevices"])
        self.assertEqual("2026-07-10", report["trends"][-1]["weekStart"])
        self.assertEqual("2026-07-12", report["trends"][-1]["weekEnd"])
        self.assertEqual("2026-07-07", report["trends"][-2]["weekStart"])
        self.assertEqual("2026-07-09", report["trends"][-2]["weekEnd"])
        self.assertTrue(report["summary"]["text"].startswith("本周期"))

    def test_selected_day_comparison_and_sampling_funnel_are_explicit(self):
        selected = dt.date(2026, 8, 10)
        comparison = dt.date(2026, 8, 1)
        self.seed_weekly_client("selected", selected, selected, launches=3)
        self.seed_weekly_client("comparison", comparison, comparison, launches=7)
        self.seed_weekly_client(
            "selected-legacy", selected, selected, authenticated=False, launches=1,
        )
        self.seed_weekly_performance("selected", selected, "baseline", 100, 60)
        self.seed_weekly_performance(
            "selected", selected, "full", 120, 75, authenticated=False,
        )
        self.seed_weekly_performance(
            "selected-legacy", selected, "full", 130, 80, authenticated=False,
        )
        self.seed_weekly_performance("comparison", comparison, "baseline", 90, 50)
        self.seed_weekly_performance("comparison", comparison, "full", 95, 55)

        now = int(dt.datetime(2026, 8, 10, 12, tzinfo=dt.timezone.utc).timestamp())
        report = SERVER._build_custom_period_report(
            selected, selected, filters={"validOnly": True}, now=now,
            comparison_start=comparison, comparison_end=comparison,
        )

        self.assertEqual("selected", report["week"]["comparisonMode"])
        self.assertEqual("2026-08-01", report["week"]["previous"]["start"])
        self.assertEqual("2026-08-01", report["week"]["previous"]["end"])
        self.assertEqual(3, report["core"]["launches"]["current"])
        self.assertEqual(7, report["core"]["launches"]["previous"])
        sampling = report["performanceSampling"]
        self.assertEqual(3, sampling["rawSessions"]["current"])
        self.assertEqual(2, sampling["rawSessions"]["previous"])
        self.assertEqual(1, sampling["trustedSessions"]["current"])
        self.assertEqual(2, sampling["trustedSessions"]["previous"])
        self.assertEqual(0, sampling["validPairs"]["current"])
        self.assertEqual(1, sampling["validPairs"]["previous"])
        self.assertFalse(sampling["conclusionPublished"])

    def test_standard_report_number_starts_at_product_epoch(self):
        week = dt.date(2026, 8, 3)
        report = SERVER._build_weekly_report(week, now=1786305600)
        self.assertEqual(1, report["week"]["reportNumber"])
        self.assertEqual("adjacent", report["week"]["comparisonMode"])

    def test_schema_two_weekly_snapshot_is_preserved_but_not_returned(self):
        week = dt.date(2026, 8, 3)
        legacy = json.dumps({
            "schemaVersion": 2,
            "week": {"weekStart": week.isoformat()},
        })
        conn = SERVER._connect()
        try:
            with conn:
                conn.execute(
                    """INSERT INTO weekly_snapshots (
                           week_start, generated_at, schema_version, report_json
                       ) VALUES (?, ?, 2, ?)""",
                    (week.isoformat(), 1786305600, legacy),
                )
        finally:
            conn.close()

        self.assertIsNone(SERVER._load_weekly_snapshot(week))
        self.assertTrue(SERVER._weekly_snapshot_exists(week))

    def test_weekly_snapshot_auth_conflict_overwrite_and_stable_read(self):
        week = dt.date(2026, 7, 27)
        self.seed_weekly_client("snapshot-client", week, week, launches=1)
        SERVER.ADMIN_API_TOKEN = "weekly-admin"
        httpd = SERVER.http.server.ThreadingHTTPServer(("127.0.0.1", 0), SERVER.Handler)
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        base = "http://127.0.0.1:%d" % httpd.server_address[1]

        def get(path, authorized=True):
            headers = {"X-DFB-Admin-Token": "weekly-admin"} if authorized else {}
            request = urllib.request.Request(base + path, headers=headers)
            with urllib.request.urlopen(request, timeout=3) as response:
                return response.status, json.load(response)

        def post(payload, authorized=True):
            headers = {"Content-Type": "application/json"}
            if authorized:
                headers["X-DFB-Admin-Token"] = "weekly-admin"
            request = urllib.request.Request(
                base + "/api/weekly/snapshot",
                data=json.dumps(payload).encode("utf-8"),
                headers=headers,
            )
            with urllib.request.urlopen(request, timeout=3) as response:
                return response.status, json.load(response)

        try:
            with self.assertRaises(urllib.error.HTTPError) as denied_get:
                get("/api/weekly?weekStart=2026-07-27", authorized=False)
            self.assertEqual(403, denied_get.exception.code)
            with self.assertRaises(urllib.error.HTTPError) as denied_custom_get:
                get("/api/weekly?startDate=2026-07-27&endDate=2026-08-02", authorized=False)
            self.assertEqual(403, denied_custom_get.exception.code)
            with self.assertRaises(urllib.error.HTTPError) as bad_custom_range:
                get("/api/weekly?startDate=2026-05-10&endDate=2026-08-10")
            self.assertEqual(400, bad_custom_range.exception.code)
            with self.assertRaises(urllib.error.HTTPError) as denied_post:
                post({"weekStart": "2026-07-27"}, authorized=False)
            self.assertEqual(403, denied_post.exception.code)
            with self.assertRaises(urllib.error.HTTPError) as custom_snapshot:
                post({"startDate": "2026-07-27", "endDate": "2026-08-02"})
            self.assertEqual(400, custom_snapshot.exception.code)

            status, created = post({"weekStart": "2026-07-27", "overwrite": False})
            self.assertEqual(201, status)
            self.assertFalse(created["overwritten"])
            _, snapshot = get("/api/weekly?weekStart=2026-07-27")
            self.assertTrue(snapshot["week"]["snapshot"]["used"])
            self.assertEqual("week", snapshot["week"]["periodMode"])
            self.assertEqual(1, snapshot["core"]["launches"]["current"])

            conn = SERVER._connect()
            try:
                with conn:
                    conn.execute(
                        "UPDATE daily_usage SET launches=9 WHERE client_hash='snapshot-client'"
                    )
            finally:
                conn.close()
            _, still_snapshot = get("/api/weekly?weekStart=2026-07-27")
            self.assertEqual(1, still_snapshot["core"]["launches"]["current"])
            _, live = get("/api/weekly?weekStart=2026-07-27&live=1")
            self.assertEqual(9, live["core"]["launches"]["current"])
            self.assertFalse(live["week"]["snapshot"]["used"])
            _, custom = get("/api/weekly?startDate=2026-07-27&endDate=2026-08-02")
            self.assertEqual("custom", custom["week"]["periodMode"])
            self.assertEqual(9, custom["core"]["launches"]["current"])
            self.assertFalse(custom["week"]["snapshot"]["used"])
            self.assertFalse(custom["week"]["snapshot"]["available"])

            with self.assertRaises(urllib.error.HTTPError) as conflict:
                post({"weekStart": "2026-07-27", "overwrite": False})
            self.assertEqual(409, conflict.exception.code)
            status, replaced = post({"weekStart": "2026-07-27", "overwrite": True})
            self.assertEqual(200, status)
            self.assertTrue(replaced["overwritten"])
            _, refreshed = get("/api/weekly?weekStart=2026-07-27")
            self.assertEqual(9, refreshed["core"]["launches"]["current"])
        finally:
            httpd.shutdown()
            httpd.server_close()
            thread.join(timeout=3)

    def test_tuning_item_set_hash_matches_windows_client_golden_vector(self):
        self.assertEqual(
            "298650b980078d6a0b9d61f874b485db8588523c079e0efadc7a51406074961f",
            SERVER._tuning_item_set_hash(["dvr-off", "game-mode"]),
        )

    def test_tuning_library_version_v1_is_persisted_and_unknown_is_rejected(self):
        now = 1786248000
        install_id = "07070707-0707-4707-8707-070707070707"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-library-v1"
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(install_id, experiment_id), now, token), now
        )
        unknown = self.tuning_start_payload(install_id, "exp-library-unknown")
        unknown["libraryVersion"] = 2
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(
                self.authenticate(unknown, now + 1, token), now + 1
            )
        conn = SERVER._connect()
        try:
            self.assertEqual(1, conn.execute(
                "SELECT library_version FROM tuning_experiments WHERE experiment_id=?",
                (experiment_id,),
            ).fetchone()[0])
        finally:
            conn.close()
        week = dt.datetime.fromtimestamp(now, dt.timezone.utc).date()
        week -= dt.timedelta(days=week.weekday())
        tuning = SERVER._build_weekly_report(week, now=now + 2)["tuning"]
        self.assertEqual(1, tuning["libraryVersion"])
        self.assertEqual([1], tuning["dataQuality"]["acceptedLibraryVersions"])

    def test_tuning_cv_and_dynamic_threshold_match_client_rule(self):
        self.assertAlmostEqual(10.0, SERVER._tuning_cv([90, 100, 110]), places=8)
        now = 1786248000
        install_id = "08080808-0808-4808-8808-080808080808"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-dynamic-threshold"
        baseline = experiment_id + ".baseline"
        variant = experiment_id + ".G1"
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=150, fps_1_low=94, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=150, fps_1_low=98, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=150, fps_1_low=102, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=150, fps_1_low=106, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-1", avg_fps=150, fps_1_low=107.5, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-a1", avg_fps=150, fps_1_low=94, run_no=5, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-2", avg_fps=150, fps_1_low=107.5, run_no=2, sequence_no=7),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-a2", avg_fps=150, fps_1_low=102, run_no=6, sequence_no=8),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-3", avg_fps=150, fps_1_low=107.5, run_no=3, sequence_no=9),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )
        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            comparison = SERVER._load_tuning_comparison(conn, experiment, variant)
            self.assertEqual(4.54, comparison["baselineNoisePct"])
            self.assertAlmostEqual(6.81, comparison["thresholdPct"], places=8)
            self.assertAlmostEqual(5.392156862745098, comparison["fps1LowDeltaPct"], places=8)
            self.assertEqual(
                [experiment_id + ".candidate-1", experiment_id + ".candidate-2", experiment_id + ".candidate-3"],
                comparison["candidateRunIds"],
            )
            self.assertFalse(comparison["deterministicWin"])
        finally:
            conn.close()
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_complete_payload(
                        install_id, experiment_id, "found_better", variant
                    ),
                    now + len(events), token,
                ),
                now + len(events),
            )

    def test_tuning_rounding_matches_powershell_boundary_rules(self):
        self.assertEqual(10.0, SERVER._tuning_cv([30, 30.5, 36.5, 30]))
        now = 1786248000
        install_id = "13131313-1313-4313-8313-131313131313"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-rounding-boundaries"
        baseline = experiment_id + ".baseline"
        variant = experiment_id + ".G1"
        candidate_one = self.tuning_run_payload(
            install_id, experiment_id, variant, experiment_id + ".candidate-1",
            avg_fps=110, fps_1_low=40, stutter_50ms=1, run_no=1, sequence_no=5,
        )
        candidate_one["durationSec"] = 119
        candidate_two = self.tuning_run_payload(
            install_id, experiment_id, variant, experiment_id + ".candidate-2",
            avg_fps=110, fps_1_low=40, stutter_50ms=1, run_no=2, sequence_no=7,
        )
        candidate_two["durationSec"] = 119
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=30, stutter_50ms=1, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=100, fps_1_low=30.5, stutter_50ms=1, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=100, fps_1_low=30, stutter_50ms=1, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=100, fps_1_low=36.5, stutter_50ms=1, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
            candidate_one,
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-a1", avg_fps=100, fps_1_low=30, stutter_50ms=1, run_no=5, sequence_no=6),
            candidate_two,
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )
        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            comparison = SERVER._load_tuning_comparison(conn, experiment, variant)
            self.assertEqual(10.0, comparison["baselineNoisePct"])
            self.assertEqual(0.0, comparison["stutterDeltaPct"])
            self.assertTrue(comparison["deterministicWin"])
        finally:
            conn.close()
        completed_at = now + len(events)
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_complete_payload(
                    install_id, experiment_id, "found_better", variant
                ),
                completed_at, token,
            ),
            completed_at,
        )

    def test_tuning_g1_checks_initial_baseline_environment_and_settings(self):
        now = 1786248000
        install_id = "14141414-1414-4414-8414-141414141414"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        for case_index, mismatch_field in enumerate(("environmentHash", "settingsHash")):
            experiment_id = "exp-g1-mismatch-" + mismatch_field.lower()
            baseline = experiment_id + ".baseline"
            variant = experiment_id + ".G1"
            first = self.tuning_run_payload(
                install_id, experiment_id, baseline, experiment_id + ".base-1",
                avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1,
            )
            first[mismatch_field] = "c" * 64
            events = [
                self.tuning_start_payload(install_id, experiment_id),
                first,
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=100, fps_1_low=60, run_no=2, sequence_no=2),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=100, fps_1_low=60, run_no=3, sequence_no=3),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
                self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
                self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-1", avg_fps=110, fps_1_low=70, run_no=1, sequence_no=5),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6),
                self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-2", avg_fps=110, fps_1_low=70, run_no=2, sequence_no=7),
            ]
            for offset, payload in enumerate(events):
                timestamp = now + case_index * 20 + offset
                SERVER._record_telemetry(
                    self.authenticate(payload, timestamp, token), timestamp
                )
            conn = SERVER._connect()
            try:
                experiment = conn.execute(
                    "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
                ).fetchone()
                self.assertIsNone(
                    SERVER._load_tuning_comparison(conn, experiment, variant), mismatch_field
                )
            finally:
                conn.close()

    def test_tuning_requires_auth_and_rejects_unknown_or_invalid_fields(self):
        now = 1786248000
        install_id = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
        experiment_id = "exp-auth-validation"
        with self.assertRaises(SERVER.TelemetryAuthError):
            SERVER._record_telemetry(self.tuning_start_payload(install_id, experiment_id), now)

        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        bad_path = self.authenticate(self.tuning_start_payload(install_id, experiment_id), now, token)
        bad_path["gamePath"] = "C:/private/game.exe"
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(bad_path, now)

        valid_start = self.authenticate(
            self.tuning_start_payload(install_id, experiment_id), now + 1, token
        )
        result = SERVER._record_telemetry(valid_start, now + 1)
        self.assertTrue(result["tuningAccepted"])
        self.assertEqual("experiment_started", result["tuningType"])

        bad_items = self.tuning_variant_payload(install_id, experiment_id)
        bad_items["itemIds"].append("unknown-item")
        bad_items = self.authenticate(bad_items, now + 2, token)
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(bad_items, now + 2)

        invalid_reason = self.tuning_run_payload(
            install_id, experiment_id, experiment_id + ".baseline", "run-invalid-reason",
            validity="invalid", invalid_reason="made_up_reason",
        )
        invalid_reason = self.authenticate(invalid_reason, now + 3, token)
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(invalid_reason, now + 3)

        conn = SERVER._connect()
        try:
            self.assertEqual(0, conn.execute("SELECT COUNT(*) FROM performance_sessions").fetchone()[0])
        finally:
            conn.close()

    def test_http_tuning_auth_and_validation_statuses(self):
        now = int(time.time())
        install_id = "abababab-abab-4aba-8aba-abababababab"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        httpd = SERVER.http.server.ThreadingHTTPServer(("127.0.0.1", 0), SERVER.Handler)
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        base = "http://127.0.0.1:%d" % httpd.server_address[1]

        def post(payload):
            request = urllib.request.Request(
                base + "/report/telemetry",
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            return urllib.request.urlopen(request, timeout=3)

        try:
            with self.assertRaises(urllib.error.HTTPError) as unauthenticated:
                post(self.tuning_start_payload(install_id, "exp-http-unauth"))
            self.assertEqual(401, unauthenticated.exception.code)

            invalid = self.tuning_variant_payload(install_id, "exp-http-invalid")
            invalid["itemIds"] = ["unknown-item"]
            invalid["itemSetHash"] = "0" * 64
            invalid = self.authenticate(invalid, now, token)
            with self.assertRaises(urllib.error.HTTPError) as rejected:
                post(invalid)
            self.assertEqual(422, rejected.exception.code)

            experiment_id = "exp-http-conflict"
            with post(self.authenticate(
                self.tuning_start_payload(install_id, experiment_id), now + 1, token
            )) as accepted:
                self.assertEqual(200, accepted.status)
            changed = self.tuning_start_payload(install_id, experiment_id)
            changed["goal"] = "average_fps"
            changed = self.authenticate(changed, now + 2, token)
            with self.assertRaises(urllib.error.HTTPError) as conflict:
                post(changed)
            self.assertEqual(409, conflict.exception.code)
        finally:
            httpd.shutdown()
            httpd.server_close()
            thread.join(timeout=3)

    def test_tuning_persists_environment_and_enriched_run_quality_metrics(self):
        now = 1786248000
        install_id = "14141414-1414-4141-8141-141414141414"
        experiment_id = "exp_enriched_metrics"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        start = self.authenticate(self.tuning_start_payload(install_id, experiment_id), now, token)
        SERVER._record_telemetry(start, now)
        run = self.tuning_run_payload(
            install_id, experiment_id, experiment_id + ".baseline", "run_enriched_metrics"
        )
        run.update({
            "frameCount": 12000,
            "frameTimeMadMs": 1.75,
            "stuttersPerMin": 1.0,
            "focusLostSec": 0.5,
            "gpuTempMax": 76.0,
            "gameExitedEarly": False,
            "captureFailed": False,
            "presentMonExitCode": 0,
        })
        SERVER._record_telemetry(self.authenticate(run, now + 1, token), now + 1)
        invalid_run = self.tuning_run_payload(
            install_id, experiment_id, experiment_id + ".baseline", "run_failed_capture",
            validity="invalid", invalid_reason="capture_failed", avg_fps=0, fps_1_low=0,
            p99_frame_ms=0, stutter_50ms=0, run_no=2, sequence_no=2,
        )
        invalid_run.update({
            "frameCount": 0,
            "frameTimeMadMs": 0,
            "stuttersPerMin": 0,
            "focusLostSec": 0,
            "gpuTempMax": 70,
            "gameExitedEarly": False,
            "captureFailed": True,
            "presentMonExitCode": -1,
        })
        SERVER._record_telemetry(self.authenticate(invalid_run, now + 2, token), now + 2)
        conn = SERVER._connect()
        try:
            experiment = dict(conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone())
            recorded_run = dict(conn.execute(
                "SELECT * FROM tuning_runs WHERE run_id='run_enriched_metrics'"
            ).fetchone())
        finally:
            conn.close()
        self.assertEqual("Windows 11 Pro", experiment["os_name"])
        self.assertEqual("26100", experiment["os_build"])
        self.assertEqual("600.00", experiment["driver_version"])
        self.assertEqual(1, experiment["gpu_count"])
        self.assertEqual("2560x1440@165", experiment["display_mode"])
        self.assertEqual(12000, recorded_run["frame_count"])
        self.assertEqual(1.75, recorded_run["frame_time_mad_ms"])
        self.assertEqual(0, recorded_run["capture_failed"])
        self.assertEqual(0, recorded_run["presentmon_exit_code"])
        tuning = SERVER._build_stats(now + 2)["experiments"]["tuning"]
        self.assertEqual(1, tuning["experiments"])
        self.assertEqual(2, tuning["runs"])
        self.assertEqual(2, tuning["enrichedRuns"])
        self.assertEqual(1, tuning["validEnrichedRuns"])
        self.assertEqual(1, tuning["captureFailures"])
        self.assertEqual(1.75, tuning["medianFrameTimeMadMs"])
        self.assertEqual(1.0, tuning["medianStuttersPerMin"])

    def test_tuning_primary_keys_are_idempotent_and_cannot_be_taken_over(self):
        now = 1786248000
        first_id = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        second_id = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
        first_token = SERVER._issue_device_token(first_id, now)["deviceToken"]
        second_token = SERVER._issue_device_token(second_id, now)["deviceToken"]
        experiment_id = "exp-owner-001"
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(first_id, experiment_id), now, first_token), now
        )
        takeover = self.authenticate(
            self.tuning_start_payload(second_id, experiment_id), now + 1, second_token
        )
        with self.assertRaises(SERVER.TelemetryOwnershipError):
            SERVER._record_telemetry(takeover, now + 1)

        variant_id = experiment_id + ".G1"
        for offset in (2, 3):
            event = self.authenticate(
                self.tuning_variant_payload(first_id, experiment_id, variant_id=variant_id),
                now + offset, first_token,
            )
            SERVER._record_telemetry(event, now + offset)
        run_id = "run-owner-001"
        first_run = self.authenticate(
            self.tuning_run_payload(first_id, experiment_id, variant_id, run_id, avg_fps=110),
            now + 4, first_token,
        )
        SERVER._record_telemetry(first_run, now + 4)
        repeated_run = self.authenticate(
            self.tuning_run_payload(first_id, experiment_id, variant_id, run_id, avg_fps=110),
            now + 5, first_token,
        )
        SERVER._record_telemetry(repeated_run, now + 5)
        changed_run = self.authenticate(
            self.tuning_run_payload(first_id, experiment_id, variant_id, run_id, avg_fps=115),
            now + 6, first_token,
        )
        with self.assertRaises(SERVER.TelemetryConflictError):
            SERVER._record_telemetry(changed_run, now + 6)

        second_experiment = "exp-owner-002"
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(first_id, second_experiment), now + 7, first_token),
            now + 7,
        )
        stolen_variant = self.authenticate(
            self.tuning_variant_payload(first_id, second_experiment, variant_id=variant_id),
            now + 8, first_token,
        )
        with self.assertRaises(SERVER.TelemetryOwnershipError):
            SERVER._record_telemetry(stolen_variant, now + 8)

        conn = SERVER._connect()
        try:
            self.assertEqual(1, conn.execute(
                "SELECT COUNT(*) FROM tuning_variants WHERE variant_id=?", (variant_id,)
            ).fetchone()[0])
            row = conn.execute(
                "SELECT avg_fps, completed_at FROM tuning_runs WHERE run_id=?", (run_id,)
            ).fetchone()
            self.assertEqual(110, row[0])
            self.assertEqual(now + 4, row[1])
            self.assertEqual(now + 2, conn.execute(
                "SELECT applied_at FROM tuning_variants WHERE variant_id=?", (variant_id,)
            ).fetchone()[0])
            owner = conn.execute(
                "SELECT client_hash FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()[0]
            self.assertEqual(SERVER._client_hash(first_id), owner)
        finally:
            conn.close()

    def test_tuning_namespaced_variant_ids_allow_multiple_complete_experiments(self):
        now = 1786248000
        installs = (
            "01010101-0101-4101-8101-010101010101",
            "02020202-0202-4202-8202-020202020202",
        )
        experiment_ids = []
        for device_index, install_id in enumerate(installs):
            token = SERVER._issue_device_token(install_id, now)["deviceToken"]
            experiment_id = "exp_" + ("%032x" % (device_index + 1))
            baseline_id = experiment_id + ".baseline"
            variant_id = experiment_id + ".background_low_risk"
            self.assertLessEqual(len(variant_id), 96)
            experiment_ids.append(experiment_id)
            events = [
                self.tuning_start_payload(install_id, experiment_id),
                self.tuning_run_payload(
                    install_id, experiment_id, baseline_id, experiment_id + ".base-1",
                    avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1,
                ),
                self.tuning_run_payload(
                    install_id, experiment_id, baseline_id, experiment_id + ".base-2",
                    avg_fps=101, fps_1_low=61, run_no=2, sequence_no=2,
                ),
                self.tuning_run_payload(
                    install_id, experiment_id, baseline_id, experiment_id + ".base-3",
                    avg_fps=99, fps_1_low=59, run_no=3, sequence_no=3,
                ),
                self.tuning_run_payload(
                    install_id, experiment_id, baseline_id, experiment_id + ".control-pre",
                    avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4,
                ),
                self.tuning_variant_payload(
                    install_id, experiment_id, variant_id=variant_id, sequence_no=5,
                ),
                self.tuning_run_payload(
                    install_id, experiment_id, variant_id, experiment_id + ".candidate-1",
                    avg_fps=110, fps_1_low=70, run_no=1, sequence_no=5,
                ),
                self.tuning_run_payload(
                    install_id, experiment_id, baseline_id, experiment_id + ".control-a1",
                    avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6,
                ),
                self.tuning_run_payload(
                    install_id, experiment_id, variant_id, experiment_id + ".candidate-2",
                    avg_fps=111, fps_1_low=71, run_no=2, sequence_no=7,
                ),
                self.tuning_complete_payload(
                    install_id, experiment_id, "found_better", variant_id,
                ),
            ]
            for offset, payload in enumerate(events):
                timestamp = now + device_index * 20 + offset
                SERVER._record_telemetry(
                    self.authenticate(payload, timestamp, token), timestamp
                )

        conn = SERVER._connect()
        try:
            self.assertEqual(2, conn.execute(
                "SELECT COUNT(*) FROM tuning_experiments WHERE result='found_better'"
            ).fetchone()[0])
            self.assertEqual(4, conn.execute(
                "SELECT COUNT(*) FROM tuning_variants"
            ).fetchone()[0])
            for experiment_id in experiment_ids:
                rows = conn.execute(
                    "SELECT variant_id FROM tuning_variants WHERE experiment_id=? ORDER BY sequence_no",
                    (experiment_id,),
                ).fetchall()
                self.assertEqual(2, len(rows))
                self.assertTrue(all(row[0].startswith(experiment_id + ".") for row in rows))
        finally:
            conn.close()

    def test_tuning_terminal_state_and_business_payloads_are_immutable(self):
        now = 1786248000
        install_id = "03030303-0303-4303-8303-030303030303"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-terminal-immutable"
        start = self.tuning_start_payload(install_id, experiment_id)
        SERVER._record_telemetry(self.authenticate(start, now, token), now)
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(install_id, experiment_id), now + 1, token),
            now + 1,
        )

        completion = self.tuning_complete_payload(
            install_id, experiment_id, "no_significant_gain", auto_rollback=False
        )
        SERVER._record_telemetry(self.authenticate(completion, now + 2, token), now + 2)
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_complete_payload(
                    install_id, experiment_id, "no_significant_gain", auto_rollback=False
                ),
                now + 3, token,
            ),
            now + 3,
        )

        changed_completion = self.tuning_complete_payload(
            install_id, experiment_id, "rolled_back", auto_rollback=True
        )
        with self.assertRaises(SERVER.TelemetryConflictError):
            SERVER._record_telemetry(
                self.authenticate(changed_completion, now + 4, token), now + 4
            )
        changed_start = self.tuning_start_payload(install_id, experiment_id)
        changed_start["goal"] = "average_fps"
        with self.assertRaises(SERVER.TelemetryConflictError):
            SERVER._record_telemetry(
                self.authenticate(changed_start, now + 5, token), now + 5
            )
        with self.assertRaises(SERVER.TelemetryConflictError):
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_variant_payload(install_id, experiment_id), now + 6, token
                ),
                now + 6,
            )
        with self.assertRaises(SERVER.TelemetryConflictError):
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_run_payload(
                        install_id, experiment_id, experiment_id + ".baseline",
                        "run-after-terminal", avg_fps=100, fps_1_low=60,
                    ),
                    now + 7, token,
                ),
                now + 7,
            )

        conn = SERVER._connect()
        try:
            row = conn.execute(
                "SELECT created_at, completed_at, result FROM tuning_experiments WHERE experiment_id=?",
                (experiment_id,),
            ).fetchone()
            self.assertEqual((now, now + 2, "no_significant_gain"), tuple(row))
            self.assertEqual(1, conn.execute(
                "SELECT COUNT(*) FROM tuning_variants WHERE experiment_id=?", (experiment_id,)
            ).fetchone()[0])
            self.assertEqual(0, conn.execute(
                "SELECT COUNT(*) FROM tuning_runs WHERE experiment_id=?", (experiment_id,)
            ).fetchone()[0])
        finally:
            conn.close()

    def test_tuning_success_counts_and_found_better_require_qualified_runs(self):
        now = 1786248000
        install_id = "04040404-0404-4404-8404-040404040404"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]

        incomplete_id = "exp-zero-applied"
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(install_id, incomplete_id), now, token), now
        )
        invalid_success = self.tuning_variant_payload(install_id, incomplete_id)
        invalid_success["appliedCount"] = 0
        invalid_success["skippedCount"] = len(invalid_success["itemIds"])
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(
                self.authenticate(invalid_success, now + 1, token), now + 1
            )

        no_runs_id = "exp-no-qualified-runs"
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(install_id, no_runs_id), now + 2, token), now + 2
        )
        no_runs_variant = no_runs_id + ".G1"
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_variant_payload(install_id, no_runs_id, variant_id=no_runs_variant),
                now + 3, token,
            ),
            now + 3,
        )
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_complete_payload(
                        install_id, no_runs_id, "found_better", no_runs_variant
                    ),
                    now + 4, token,
                ),
                now + 4,
            )

        partial_id = "exp-partial-not-winner"
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(install_id, partial_id), now + 5, token), now + 5
        )
        partial_variant = partial_id + ".G1"
        partial = self.tuning_variant_payload(
            install_id, partial_id, variant_id=partial_variant
        )
        partial["applyResult"] = "partial"
        partial["appliedCount"] = 1
        partial["failedCount"] = 1
        SERVER._record_telemetry(self.authenticate(partial, now + 6, token), now + 6)
        with self.assertRaises(SERVER.TelemetryTuningError):
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_complete_payload(
                        install_id, partial_id, "found_better", partial_variant
                    ),
                    now + 7, token,
                ),
                now + 7,
            )

    def test_no_gain_rejects_a_win_and_cancelled_is_not_effectiveness_data(self):
        now = 1786248000
        install_id = "18181818-1818-4818-8818-181818181818"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-no-gain-false-negative"
        baseline = experiment_id + ".baseline"
        variant = experiment_id + ".G1"
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=100, fps_1_low=60, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=100, fps_1_low=60, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".b1", avg_fps=110, fps_1_low=70, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".b2", avg_fps=110, fps_1_low=70, run_no=2, sequence_no=7),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )
        with self.assertRaises(SERVER.TelemetryTuningError):
            completed_at = now + len(events)
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_complete_payload(
                        install_id, experiment_id, "no_significant_gain"
                    ),
                    completed_at, token,
                ),
                completed_at,
            )
        cancelled_at = now + len(events) + 1
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_complete_payload(install_id, experiment_id, "cancelled"),
                cancelled_at, token,
            ),
            cancelled_at,
        )
        conn = SERVER._connect()
        try:
            day = dt.datetime.fromtimestamp(now, dt.timezone.utc).date()
            comparisons = SERVER._qualified_tuning_comparisons(
                conn, day, day + dt.timedelta(days=1), SERVER._default_weekly_filters()
            )
            self.assertEqual([], comparisons)
            row = conn.execute(
                "SELECT status, result FROM tuning_experiments WHERE experiment_id=?",
                (experiment_id,),
            ).fetchone()
            self.assertEqual(("cancelled", "cancelled"), tuple(row))
        finally:
            conn.close()

    def test_winner_must_be_the_endpoint_of_a_valid_control_chain(self):
        now = 1786248000
        install_id = "19191919-1919-4919-8919-191919191919"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-invalid-winner-chain"
        baseline = experiment_id + ".baseline"
        g1_variant = experiment_id + ".G1"
        g2_variant = experiment_id + ".G2"
        g2_items = sorted(
            set(SERVER.TUNING_GROUP_ITEMS["G1"]) | set(SERVER.TUNING_GROUP_ITEMS["G2"])
        )
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=100, fps_1_low=60, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=100, fps_1_low=60, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g1-control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=g1_variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g1-b1", avg_fps=90, fps_1_low=50, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g1-a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g1-b2", avg_fps=90, fps_1_low=50, run_no=2, sequence_no=7),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g2-control-pre", avg_fps=90, fps_1_low=50, run_no=3, sequence_no=8),
            self.tuning_variant_payload(install_id, experiment_id, group_id="G2", variant_id=g2_variant, control_variant_id=g1_variant, sequence_no=9, item_ids=g2_items),
            self.tuning_run_payload(install_id, experiment_id, g2_variant, experiment_id + ".g2-b1", avg_fps=99, fps_1_low=55, run_no=1, sequence_no=9),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g2-a1", avg_fps=90, fps_1_low=50, run_no=4, sequence_no=10),
            self.tuning_run_payload(install_id, experiment_id, g2_variant, experiment_id + ".g2-b2", avg_fps=99, fps_1_low=55, run_no=2, sequence_no=11),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )
        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            self.assertTrue(
                SERVER._load_tuning_comparison(conn, experiment, g1_variant)["hardRollback"]
            )
            self.assertTrue(
                SERVER._load_tuning_comparison(conn, experiment, g2_variant)["deterministicWin"]
            )
            self.assertEqual(
                baseline, SERVER._resolve_tuning_retained_variant(conn, experiment)
            )
        finally:
            conn.close()
        with self.assertRaises(SERVER.TelemetryTuningError):
            completed_at = now + len(events)
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_complete_payload(
                        install_id, experiment_id, "found_better", g2_variant
                    ),
                    completed_at, token,
                ),
                completed_at,
            )
        no_gain_at = now + len(events) + 1
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_complete_payload(
                    install_id, experiment_id, "no_significant_gain"
                ),
                no_gain_at, token,
            ),
            no_gain_at,
        )
        conn = SERVER._connect()
        try:
            day = dt.datetime.fromtimestamp(now, dt.timezone.utc).date()
            comparisons = SERVER._qualified_tuning_comparisons(
                conn, day, day + dt.timedelta(days=1), SERVER._default_weekly_filters()
            )
            self.assertEqual(["G1"], [row["groupId"] for row in comparisons])
            self.assertTrue(comparisons[0]["hardRollback"])
        finally:
            conn.close()

    def test_found_better_recomputes_decline_constraints_stutter_and_direction(self):
        now = 1786248000
        install_id = "09090909-0909-4909-8909-090909090909"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]

        def rejected_case(name, first_metrics, second_metrics, baseline_stutter=2):
            experiment_id = "exp-server-win-" + name
            baseline = experiment_id + ".baseline"
            variant = experiment_id + ".G1"
            offset_base = {
                "decline": 0, "temperature": 10, "power": 20,
                "stutter-zero": 30, "direction": 40,
            }[name]
            events = [
                self.tuning_start_payload(install_id, experiment_id),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=60, stutter_50ms=baseline_stutter, run_no=1, sequence_no=1),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=101, fps_1_low=61, stutter_50ms=baseline_stutter, run_no=2, sequence_no=2),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=99, fps_1_low=59, stutter_50ms=baseline_stutter, run_no=3, sequence_no=3),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=100, fps_1_low=60, stutter_50ms=baseline_stutter, run_no=4, sequence_no=4),
                self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
                self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-1", run_no=1, sequence_no=5, **first_metrics),
                self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-a1", avg_fps=100, fps_1_low=60, stutter_50ms=baseline_stutter, run_no=5, sequence_no=6),
                self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-2", run_no=2, sequence_no=7, **second_metrics),
            ]
            for offset, payload in enumerate(events):
                timestamp = now + offset_base + offset
                SERVER._record_telemetry(
                    self.authenticate(payload, timestamp, token), timestamp
                )
            conn = SERVER._connect()
            try:
                experiment = conn.execute(
                    "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
                ).fetchone()
                comparison = SERVER._load_tuning_comparison(conn, experiment, variant)
            finally:
                conn.close()
            with self.assertRaises(SERVER.TelemetryTuningError):
                timestamp = now + offset_base + len(events)
                SERVER._record_telemetry(
                    self.authenticate(
                        self.tuning_complete_payload(
                            install_id, experiment_id, "found_better", variant
                        ),
                        timestamp, token,
                    ),
                    timestamp,
                )
            return comparison

        decline = rejected_case(
            "decline",
            {"avg_fps": 90, "fps_1_low": 50},
            {"avg_fps": 92, "fps_1_low": 52},
        )
        self.assertTrue(decline["hardRollback"])
        self.assertLess(decline["fps1LowDeltaPct"], -5)

        temperature = rejected_case(
            "temperature",
            {"avg_fps": 110, "fps_1_low": 70, "temperature": 74},
            {"avg_fps": 111, "fps_1_low": 71, "temperature": 74},
        )
        self.assertTrue(temperature["hardRollback"])
        self.assertGreater(temperature["gpuTempDeltaC"], 3)

        power = rejected_case(
            "power",
            {"avg_fps": 110, "fps_1_low": 70, "power": 160},
            {"avg_fps": 111, "fps_1_low": 71, "power": 160},
        )
        self.assertTrue(power["hardRollback"])
        self.assertGreater(power["gpuPowerDeltaPct"], 0)

        stutter = rejected_case(
            "stutter-zero",
            {"avg_fps": 110, "fps_1_low": 70, "stutter_50ms": 1},
            {"avg_fps": 111, "fps_1_low": 71, "stutter_50ms": 1},
            baseline_stutter=0,
        )
        self.assertTrue(stutter["hardRollback"])
        self.assertFalse(stutter["deterministicWin"])

        direction = rejected_case(
            "direction",
            {"avg_fps": 110, "fps_1_low": 50},
            {"avg_fps": 110, "fps_1_low": 80},
        )
        self.assertIsNone(direction)

    def test_tuning_control_chain_compares_candidate_to_current_best(self):
        now = 1786248000
        install_id = "05050505-0505-4505-8505-050505050505"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-control-chain"
        baseline = experiment_id + ".baseline"
        g1_variant = experiment_id + ".G1"
        g2_variant = experiment_id + ".G2"
        g1_items = list(SERVER.TUNING_GROUP_ITEMS["G1"])
        g2_items = sorted(set(g1_items) | set(SERVER.TUNING_GROUP_ITEMS["G2"]))
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(
                install_id, experiment_id, baseline, experiment_id + ".base-1",
                avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, baseline, experiment_id + ".base-2",
                avg_fps=101, fps_1_low=61, run_no=2, sequence_no=2,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, baseline, experiment_id + ".base-3",
                avg_fps=99, fps_1_low=59, run_no=3, sequence_no=3,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, baseline, experiment_id + ".g1-control-pre",
                avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4,
            ),
            self.tuning_variant_payload(
                install_id, experiment_id, variant_id=g1_variant,
                control_variant_id=baseline, sequence_no=5,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, g1_variant, experiment_id + ".g1-1",
                avg_fps=110, fps_1_low=70, run_no=1, sequence_no=5,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, baseline, experiment_id + ".g1-control-a1",
                avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, g1_variant, experiment_id + ".g1-2",
                avg_fps=110, fps_1_low=70, run_no=2, sequence_no=7,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, g1_variant, experiment_id + ".g2-control-pre",
                avg_fps=110, fps_1_low=70, run_no=3, sequence_no=8,
            ),
            self.tuning_variant_payload(
                install_id, experiment_id, group_id="G2", variant_id=g2_variant,
                control_variant_id=g1_variant, sequence_no=9, item_ids=g2_items,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, g2_variant, experiment_id + ".g2-1",
                avg_fps=119, fps_1_low=78, run_no=1, sequence_no=9,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, g1_variant, experiment_id + ".g2-control-a1",
                avg_fps=110, fps_1_low=70, run_no=4, sequence_no=10,
            ),
            self.tuning_run_payload(
                install_id, experiment_id, g2_variant, experiment_id + ".g2-2",
                avg_fps=121, fps_1_low=80, run_no=2, sequence_no=11,
            ),
            self.tuning_complete_payload(
                install_id, experiment_id, "found_better", g2_variant,
            ),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )

        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            comparison = SERVER._load_tuning_comparison(conn, experiment, g2_variant)
            self.assertEqual(g1_variant, comparison["controlVariantId"])
            self.assertAlmostEqual(9.09, comparison["avgFpsDeltaPct"], places=2)
            self.assertAlmostEqual(12.86, comparison["fps1LowDeltaPct"], places=2)
            day = dt.datetime.fromtimestamp(now, dt.timezone.utc).date()
            comparisons = SERVER._qualified_tuning_comparisons(
                conn, day, day + dt.timedelta(days=1), SERVER._default_weekly_filters()
            )
            by_group = {row["groupId"]: row for row in comparisons}
            self.assertTrue(by_group["G1"]["retained"])
            self.assertTrue(by_group["G2"]["retained"])
            self.assertFalse(by_group["G1"]["rolledBack"])
            self.assertFalse(by_group["G2"]["rolledBack"])
        finally:
            conn.close()

    def test_tuning_membership_is_frozen_by_candidate_boundaries(self):
        now = 1786248000
        install_id = "15151515-1515-4515-8515-151515151515"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-membership-boundaries"
        baseline = experiment_id + ".baseline"
        g1_variant = experiment_id + ".G1"
        g2_variant = experiment_id + ".G2"
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=55, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=100, fps_1_low=60, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=100, fps_1_low=60, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g1-control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=g1_variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g1-b1", avg_fps=90, fps_1_low=50, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g1-a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g1-b2", avg_fps=92, fps_1_low=52, run_no=2, sequence_no=7),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g2-control-pre", avg_fps=100, fps_1_low=60, run_no=6, sequence_no=8),
            self.tuning_variant_payload(install_id, experiment_id, group_id="G2", variant_id=g2_variant, control_variant_id=baseline, sequence_no=9),
            self.tuning_run_payload(install_id, experiment_id, g2_variant, experiment_id + ".g2-b1", avg_fps=105.5, fps_1_low=63.2, run_no=1, sequence_no=9),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g2-a1", avg_fps=100, fps_1_low=60, run_no=7, sequence_no=10),
            self.tuning_run_payload(install_id, experiment_id, g2_variant, experiment_id + ".g2-b2", avg_fps=105.5, fps_1_low=63.2, run_no=2, sequence_no=11),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )

        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            g1_before = SERVER._load_tuning_comparison(conn, experiment, g1_variant)
            g2 = SERVER._load_tuning_comparison(conn, experiment, g2_variant)
            self.assertTrue(g1_before["hardRollback"])
            self.assertEqual(
                [experiment_id + ".base-2", experiment_id + ".base-3", experiment_id + ".g1-control-pre", experiment_id + ".g1-a1"],
                g1_before["controlRunIds"],
            )
            self.assertEqual(
                [experiment_id + ".g1-b1", experiment_id + ".g1-b2"],
                g1_before["candidateRunIds"],
            )
            self.assertTrue(g2["deterministicWin"])
            self.assertEqual(
                [experiment_id + ".g1-control-pre", experiment_id + ".g1-a1", experiment_id + ".g2-control-pre", experiment_id + ".g2-a1"],
                g2["controlRunIds"],
            )
        finally:
            conn.close()

        late_run = self.tuning_run_payload(
            install_id, experiment_id, g1_variant, experiment_id + ".g1-late",
            avg_fps=300, fps_1_low=300, run_no=3, sequence_no=12,
        )
        SERVER._record_telemetry(
            self.authenticate(late_run, now + len(events), token), now + len(events)
        )
        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            g1_after = SERVER._load_tuning_comparison(conn, experiment, g1_variant)
            for key in (
                "controlRunIds", "candidateRunIds", "fps1LowDeltaPct",
                "avgFpsDeltaPct", "hardRollback", "deterministicWin",
            ):
                self.assertEqual(g1_before[key], g1_after[key], key)
            self.assertNotIn(experiment_id + ".g1-late", g1_after["candidateRunIds"])
        finally:
            conn.close()
        completed_at = now + len(events) + 1
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_complete_payload(
                    install_id, experiment_id, "found_better", g2_variant
                ),
                completed_at, token,
            ),
            completed_at,
        )

    def test_tuning_inconclusive_membership_uses_alternating_a2_b3(self):
        now = 1786248000
        install_id = "16161616-1616-4616-8616-161616161616"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-membership-extra"
        baseline = experiment_id + ".baseline"
        variant = experiment_id + ".G1"
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=100, fps_1_low=60, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=100, fps_1_low=60, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".b1", avg_fps=110, fps_1_low=63, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".a1", avg_fps=100, fps_1_low=54, run_no=5, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".b2", avg_fps=110, fps_1_low=66, run_no=2, sequence_no=7),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".a2", avg_fps=100, fps_1_low=60, run_no=6, sequence_no=8),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".b3", avg_fps=110, fps_1_low=70, run_no=3, sequence_no=9),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )
        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            comparison = SERVER._load_tuning_comparison(conn, experiment, variant)
            self.assertEqual(
                [experiment_id + ".base-2", experiment_id + ".base-3", experiment_id + ".control-pre", experiment_id + ".a1", experiment_id + ".a2"],
                comparison["controlRunIds"],
            )
            self.assertEqual(
                [experiment_id + ".b1", experiment_id + ".b2", experiment_id + ".b3"],
                comparison["candidateRunIds"],
            )
            self.assertEqual(4.56, comparison["baselineNoisePct"])
            self.assertTrue(comparison["deterministicWin"])
        finally:
            conn.close()
        completed_at = now + len(events)
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_complete_payload(
                    install_id, experiment_id, "found_better", variant
                ),
                completed_at, token,
            ),
            completed_at,
        )

    def test_tuning_rejects_non_alternating_run_membership(self):
        now = 1786248000
        install_id = "17171717-1717-4717-8717-171717171717"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-membership-order"
        baseline = experiment_id + ".baseline"
        variant = experiment_id + ".G1"
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=100, fps_1_low=60, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=100, fps_1_low=60, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".b1", avg_fps=110, fps_1_low=70, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".b2", avg_fps=110, fps_1_low=70, run_no=2, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=7),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )
        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            self.assertIsNone(SERVER._load_tuning_comparison(conn, experiment, variant))
        finally:
            conn.close()
        with self.assertRaises(SERVER.TelemetryTuningError):
            completed_at = now + len(events)
            SERVER._record_telemetry(
                self.authenticate(
                    self.tuning_complete_payload(
                        install_id, experiment_id, "found_better", variant
                    ),
                    completed_at, token,
                ),
                completed_at,
            )

    def test_tuning_group_rollbacks_follow_final_winner_items(self):
        now = 1786248000
        install_id = "06060606-0606-4606-8606-060606060606"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-winner-items"
        baseline = experiment_id + ".baseline"
        g1_variant = experiment_id + ".G1"
        g2_variant = experiment_id + ".G2"
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=101, fps_1_low=61, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=99, fps_1_low=59, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g1-control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=g1_variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g1-1", avg_fps=90, fps_1_low=50, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g1-control-a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, g1_variant, experiment_id + ".g1-2", avg_fps=92, fps_1_low=52, run_no=2, sequence_no=7),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g2-control-pre", avg_fps=100, fps_1_low=60, run_no=6, sequence_no=8),
            self.tuning_variant_payload(
                install_id, experiment_id, group_id="G2", variant_id=g2_variant,
                control_variant_id=baseline, sequence_no=9,
            ),
            self.tuning_run_payload(install_id, experiment_id, g2_variant, experiment_id + ".g2-1", avg_fps=110, fps_1_low=70, run_no=1, sequence_no=9),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".g2-control-a1", avg_fps=100, fps_1_low=60, run_no=7, sequence_no=10),
            self.tuning_run_payload(install_id, experiment_id, g2_variant, experiment_id + ".g2-2", avg_fps=111, fps_1_low=71, run_no=2, sequence_no=11),
            self.tuning_complete_payload(install_id, experiment_id, "found_better", g2_variant),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )

        conn = SERVER._connect()
        try:
            day = dt.datetime.fromtimestamp(now, dt.timezone.utc).date()
            comparisons = SERVER._qualified_tuning_comparisons(
                conn, day, day + dt.timedelta(days=1), SERVER._default_weekly_filters()
            )
            by_group = {row["groupId"]: row for row in comparisons}
            self.assertTrue(by_group["G1"]["rolledBack"])
            self.assertFalse(by_group["G1"]["retained"])
            self.assertFalse(by_group["G2"]["rolledBack"])
            self.assertTrue(by_group["G2"]["retained"])
            self.assertEqual(0, conn.execute(
                "SELECT auto_rollback FROM tuning_experiments WHERE experiment_id=?",
                (experiment_id,),
            ).fetchone()[0])
        finally:
            conn.close()

    def test_weekly_group_ranking_excludes_failed_experiments(self):
        now = int(dt.datetime(2026, 7, 28, 12, tzinfo=dt.timezone.utc).timestamp())
        install_id = "10101010-1010-4010-8010-101010101010"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        experiment_id = "exp-failed-exclusion"
        baseline = experiment_id + ".baseline"
        variant = experiment_id + ".G1"
        events = [
            self.tuning_start_payload(install_id, experiment_id),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-1", avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-2", avg_fps=101, fps_1_low=61, run_no=2, sequence_no=2),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".base-3", avg_fps=99, fps_1_low=59, run_no=3, sequence_no=3),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(install_id, experiment_id, variant_id=variant, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-1", avg_fps=110, fps_1_low=70, run_no=1, sequence_no=5),
            self.tuning_run_payload(install_id, experiment_id, baseline, experiment_id + ".control-a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6),
            self.tuning_run_payload(install_id, experiment_id, variant, experiment_id + ".candidate-2", avg_fps=111, fps_1_low=71, run_no=2, sequence_no=7),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, token), now + offset
            )
        conn = SERVER._connect()
        try:
            experiment = conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,)
            ).fetchone()
            self.assertTrue(SERVER._load_tuning_comparison(
                conn, experiment, variant
            )["deterministicWin"])
        finally:
            conn.close()
        SERVER._record_telemetry(
            self.authenticate(
                self.tuning_complete_payload(
                    install_id, experiment_id, "failed", auto_rollback=False
                ),
                now + len(events), token,
            ),
            now + len(events),
        )
        week = dt.date(2026, 7, 27)
        tuning = SERVER._build_weekly_report(week, now=now + 20)["tuning"]
        self.assertEqual(1, tuning["summary"]["completed"]["current"])
        self.assertEqual(0, tuning["summary"]["valid"]["current"])
        self.assertEqual(0, tuning["groupRanking"][0]["validIndependentExperiments"])
        self.assertFalse(tuning["groupRanking"][0]["conclusionPublished"])

    def test_tuning_conclusion_requires_twenty_distinct_devices(self):
        week = dt.date(2026, 7, 27)
        timestamp = int(dt.datetime(2026, 7, 28, 12, tzinfo=dt.timezone.utc).timestamp())
        for index in range(20):
            self.seed_qualified_tuning_experiment(
                "single-device", "exp-same-device-%02d" % index, timestamp + index
            )
        group = SERVER._build_weekly_report(week, now=timestamp + 1000)["tuning"]["groupRanking"][0]
        self.assertEqual(20, group["validIndependentExperiments"])
        self.assertEqual(1, group["validIndependentDevices"])
        self.assertFalse(group["conclusionPublished"])
        self.assertIsNone(group["winRate"])
        self.assertEqual(20, SERVER._build_weekly_report(
            week, now=timestamp + 1000
        )["tuning"]["dataQuality"]["groupConclusionMinIndependentDevices"])

    def test_tuning_qualification_rejects_short_unstable_or_mismatched_arms(self):
        week = dt.date(2026, 7, 27)
        timestamp = int(dt.datetime(2026, 7, 28, 12, tzinfo=dt.timezone.utc).timestamp())
        cases = ("baseline-short", "candidate-short", "unstable", "environment", "settings", "order")
        for index, name in enumerate(cases):
            self.seed_qualified_tuning_experiment(
                "qualification-client-%s" % name,
                "exp-qualification-%s" % name,
                timestamp + index,
            )
        conn = SERVER._connect()
        try:
            with conn:
                conn.execute("DELETE FROM tuning_runs WHERE run_id='exp-qualification-baseline-short.run-3'")
                conn.execute("DELETE FROM tuning_runs WHERE run_id='exp-qualification-candidate-short.run-7'")
                conn.execute(
                    "UPDATE tuning_runs SET avg_fps=180 WHERE run_id='exp-qualification-unstable.run-1'"
                )
                conn.execute(
                    "UPDATE tuning_runs SET environment_hash=? WHERE run_id='exp-qualification-environment.run-7'",
                    ("d" * 64,),
                )
                conn.execute(
                    "UPDATE tuning_runs SET settings_hash=? WHERE run_id='exp-qualification-settings.run-7'",
                    ("e" * 64,),
                )
                conn.execute(
                    "UPDATE tuning_runs SET order_controlled=0 WHERE run_id='exp-qualification-order.run-5'"
                )
            comparisons = SERVER._qualified_tuning_comparisons(
                conn, week, week + dt.timedelta(days=7), SERVER._default_weekly_filters()
            )
            self.assertEqual([], comparisons)
        finally:
            conn.close()
        ranking = SERVER._build_weekly_report(
            week, now=timestamp + 1000
        )["tuning"]["groupRanking"][0]
        self.assertEqual(0, ranking["validIndependentExperiments"])
        self.assertFalse(ranking["conclusionPublished"])

    def test_weekly_tuning_funnel_ranking_threshold_and_invalid_reasons(self):
        week = dt.date(2026, 7, 27)
        now = int(dt.datetime(2026, 7, 28, 12, tzinfo=dt.timezone.utc).timestamp())

        first_id = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
        first_token = SERVER._issue_device_token(first_id, now)["deviceToken"]
        first_exp = "exp-weekly-good"
        first_variant = first_exp + ".G1"
        events = [
            self.tuning_start_payload(first_id, first_exp),
            self.tuning_run_payload(first_id, first_exp, first_exp + ".baseline", "run-good-base-1", avg_fps=100, fps_1_low=60, run_no=1, sequence_no=1),
            self.tuning_run_payload(first_id, first_exp, first_exp + ".baseline", "run-good-base-2", avg_fps=101, fps_1_low=61, run_no=2, sequence_no=2),
            self.tuning_run_payload(first_id, first_exp, first_exp + ".baseline", "run-good-base-3", avg_fps=99, fps_1_low=59, run_no=3, sequence_no=3),
            self.tuning_run_payload(first_id, first_exp, first_exp + ".baseline", "run-good-control-pre", avg_fps=100, fps_1_low=60, run_no=4, sequence_no=4),
            self.tuning_variant_payload(first_id, first_exp, variant_id=first_variant, sequence_no=5),
            self.tuning_run_payload(first_id, first_exp, first_variant, "run-good-G1-1", avg_fps=110, fps_1_low=70, run_no=1, sequence_no=5),
            self.tuning_run_payload(first_id, first_exp, first_exp + ".baseline", "run-good-control-a1", avg_fps=100, fps_1_low=60, run_no=5, sequence_no=6),
            self.tuning_run_payload(first_id, first_exp, first_variant, "run-good-G1-2", avg_fps=111, fps_1_low=71, run_no=2, sequence_no=7),
            self.tuning_complete_payload(first_id, first_exp, "found_better", first_variant),
        ]
        for offset, payload in enumerate(events):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, first_token), now + offset
            )

        pending_id = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
        pending_token = SERVER._issue_device_token(pending_id, now)["deviceToken"]
        SERVER._record_telemetry(
            self.authenticate(self.tuning_start_payload(pending_id, "exp-weekly-pending"), now + 10, pending_token),
            now + 10,
        )

        invalid_id = "ffffffff-ffff-4fff-8fff-ffffffffffff"
        invalid_token = SERVER._issue_device_token(invalid_id, now)["deviceToken"]
        invalid_exp = "exp-weekly-invalid"
        invalid_variant = invalid_exp + ".G1"
        invalid_events = [
            self.tuning_start_payload(invalid_id, invalid_exp),
            self.tuning_variant_payload(invalid_id, invalid_exp, variant_id=invalid_variant),
            self.tuning_run_payload(
                invalid_id, invalid_exp, invalid_variant, "run-focus-lost",
                validity="invalid", invalid_reason="focus_lost", avg_fps=0, fps_1_low=0,
            ),
            self.tuning_complete_payload(
                invalid_id, invalid_exp, "no_significant_gain", auto_rollback=True
            ),
        ]
        for offset, payload in enumerate(invalid_events, 20):
            SERVER._record_telemetry(
                self.authenticate(payload, now + offset, invalid_token), now + offset
            )

        report = SERVER._build_weekly_report(week, now=now + 60)
        tuning = report["tuning"]
        self.assertEqual(3, tuning["summary"]["started"]["current"])
        self.assertEqual(2, tuning["summary"]["completed"]["current"])
        self.assertEqual(1, tuning["summary"]["valid"]["current"])
        self.assertEqual(1, tuning["summary"]["foundBetter"]["current"])
        self.assertEqual(1, tuning["summary"]["noSignificantGain"]["current"])
        self.assertEqual(1, tuning["summary"]["autoRollback"]["current"])
        self.assertEqual(3, tuning["funnel"][0]["experiments"])
        self.assertFalse(tuning["groupRanking"][0]["conclusionPublished"])
        self.assertEqual("focus_lost", tuning["invalidReasonDistribution"][0]["value"])
        self.assertFalse(tuning["aiQuality"]["enabled"])

        for index in range(19):
            self.seed_qualified_tuning_experiment(
                "rank-client-%02d" % index, "exp-rank-%02d" % index, now
            )
        published = SERVER._build_weekly_report(week, now=now + 200)["tuning"]["groupRanking"][0]
        self.assertEqual(20, published["validIndependentExperiments"])
        self.assertEqual(20, published["validIndependentDevices"])
        self.assertTrue(published["conclusionPublished"])
        self.assertEqual(100.0, published["winRate"])
        self.assertEqual(1, published["rank"])

    def test_tuning_daily_limit_and_retention_cascade(self):
        now = 1786248000
        install_id = "12121212-3434-4567-8abc-121212121212"
        token = SERVER._issue_device_token(install_id, now)["deviceToken"]
        client_hash = SERVER._client_hash(install_id)
        day_start = now - (now % 86400)
        old = now - (SERVER.TELEMETRY_KEEP_DAYS + 1) * 86400
        conn = SERVER._connect()
        try:
            with conn:
                for index in range(SERVER.TUNING_DAILY_LIMIT):
                    conn.execute(
                        "INSERT INTO tuning_events VALUES (?, ?, ?)",
                        (client_hash, "limit-%03d" % index, day_start + index),
                    )
                for prefix, timestamp in (("old", old), ("fresh", now)):
                    experiment = prefix + "-experiment"
                    variant = prefix + "-variant"
                    conn.execute(
                        """INSERT INTO tuning_experiments (
                               experiment_id, client_hash, created_at, completed_at, status,
                               goal, risk_level, app_version, gpu_model, baseline_variant_id
                           ) VALUES (?, ?, ?, ?, 'completed', 'smoothness', 'low',
                                     '0.20.0', 'GPU', ?)""",
                        (experiment, prefix, timestamp, timestamp, variant),
                    )
                    conn.execute(
                        """INSERT INTO tuning_variants (
                               variant_id, experiment_id, sequence_no, group_id, display_name,
                               item_set_hash, item_ids_json, source, risk_level, status
                           ) VALUES (?, ?, 0, 'baseline', 'baseline', ?, '[]', 'manual', 'low', 'baseline')""",
                        (variant, experiment, SERVER._tuning_item_set_hash([])),
                    )
                    conn.execute(
                        """INSERT INTO tuning_runs (
                               run_id, experiment_id, variant_id, run_no, sequence_no,
                               started_at, completed_at, validity, settings_hash, environment_hash
                           ) VALUES (?, ?, ?, 1, 1, ?, ?, 'valid', ?, ?)""",
                        (prefix + "-run", experiment, variant, timestamp, timestamp, "a" * 64, "b" * 64),
                    )
                    conn.execute(
                        """INSERT INTO ai_tuning_decisions (
                               decision_id, experiment_id, created_at, model, prompt_version,
                               schema_version, input_hash, decision, validation_result
                           ) VALUES (?, ?, ?, 'future', 'v1', 1, ?, 'test_variant', 'valid')""",
                        (prefix + "-decision", experiment, timestamp, "c" * 64),
                    )
        finally:
            conn.close()

        limited = self.authenticate(
            self.tuning_start_payload(install_id, "exp-daily-limited"), now, token
        )
        with self.assertRaises(SERVER.TelemetryDailyLimitError):
            SERVER._record_telemetry(limited, now)

        SERVER._run_maintenance(now)
        conn = SERVER._connect()
        try:
            for table in ("tuning_experiments", "tuning_variants", "tuning_runs", "ai_tuning_decisions"):
                self.assertEqual(0, conn.execute(
                    "SELECT COUNT(*) FROM %s WHERE %s LIKE 'old%%'" % (
                        table, "experiment_id" if table != "tuning_runs" and table != "ai_tuning_decisions" else
                        ("run_id" if table == "tuning_runs" else "decision_id")
                    )
                ).fetchone()[0])
            self.assertEqual(1, conn.execute(
                "SELECT COUNT(*) FROM tuning_experiments WHERE experiment_id='fresh-experiment'"
            ).fetchone()[0])
        finally:
            conn.close()

    def test_migrates_existing_tuning_database_to_library_version_one(self):
        conn = SERVER._connect()
        try:
            with conn:
                conn.executescript("""
                    DROP TABLE ai_tuning_decisions;
                    DROP TABLE tuning_runs;
                    DROP TABLE tuning_variants;
                    DROP TABLE tuning_experiments;
                    CREATE TABLE tuning_experiments (
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
                """)
                conn.execute(
                    """INSERT INTO tuning_experiments (
                           experiment_id, client_hash, created_at, status, goal,
                           risk_level, app_version, gpu_model
                       ) VALUES ('legacy-tuning', 'legacy-client', 1, 'created',
                                 'smoothness', 'low', '0.20.0', 'GPU')"""
                )
        finally:
            conn.close()
        SERVER._init_db()
        conn = SERVER._connect()
        try:
            columns = {row[1] for row in conn.execute("PRAGMA table_info(tuning_experiments)")}
            run_columns = {row[1] for row in conn.execute("PRAGMA table_info(tuning_runs)")}
            self.assertIn("library_version", columns)
            for name in (
                "os_name", "os_build", "cpu_model", "gpu_vendor", "ram_gb",
                "device_type", "gpu_count", "display_mode", "cpu_cores", "cpu_threads",
                "cpu_packages", "memory_type", "memory_configured_mhz",
                "memory_rated_mhz", "memory_module_count", "virtual_display_count",
                "pagefile_auto_managed", "gpu_reported_model_differs",
            ):
                self.assertIn(name, columns)
            for name in ("frame_count", "frame_time_mad_ms", "stutters_per_min", "focus_lost_sec", "gpu_temp_max", "game_exited_early", "capture_failed", "presentmon_exit_code"):
                self.assertIn(name, run_columns)
            self.assertEqual(1, conn.execute(
                "SELECT library_version FROM tuning_experiments WHERE experiment_id='legacy-tuning'"
            ).fetchone()[0])
            for table in ("tuning_variants", "tuning_runs", "ai_tuning_decisions"):
                self.assertIsNotNone(conn.execute(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table,)
                ).fetchone())
        finally:
            conn.close()

    def test_migrates_pre_019_tables(self):
        os.remove(SERVER.DB_PATH)
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
            conn.execute(
                "INSERT INTO clients (client_hash, first_seen, last_seen) VALUES ('preserved-client', 1, 2)"
            )
            conn.commit()
        finally:
            conn.close()
        SERVER._init_db()
        conn = SERVER._connect()
        try:
            client_columns = {row[1] for row in conn.execute("PRAGMA table_info(clients)")}
            performance_columns = {row[1] for row in conn.execute("PRAGMA table_info(performance_sessions)")}
            daily_columns = {row[1] for row in conn.execute("PRAGMA table_info(daily_usage)")}
            weekly_columns = {row[1] for row in conn.execute("PRAGMA table_info(weekly_snapshots)")}
            tables = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            preserved = conn.execute(
                "SELECT COUNT(*) FROM clients WHERE client_hash='preserved-client'"
            ).fetchone()[0]
        finally:
            conn.close()
        self.assertIn("gpu_model_verified", client_columns)
        self.assertIn("authenticated_last_seen", client_columns)
        self.assertIn("driver_version", client_columns)
        self.assertIn("gpu_count", client_columns)
        self.assertIn("display_mode", client_columns)
        for name in (
            "cpu_cores", "cpu_threads", "cpu_packages", "memory_type",
            "memory_configured_mhz", "memory_rated_mhz", "memory_module_count",
            "virtual_display_count", "pagefile_auto_managed", "gpu_reported_model_differs",
        ):
            self.assertIn(name, client_columns)
        self.assertIn("config_tier", performance_columns)
        self.assertIn("authenticated", performance_columns)
        for name in ("optimization_scheme", "item_set_hash", "item_ids_json", "item_ids_complete"):
            self.assertIn(name, performance_columns)
        self.assertIn("trusted_launches", daily_columns)
        self.assertIn("restore_ok", daily_columns)
        self.assertIn("telemetry_replays", tables)
        self.assertIn("optimization_operations", tables)
        self.assertIn("weekly_snapshots", tables)
        for table in (
            "tuning_experiments", "tuning_variants", "tuning_runs",
            "ai_tuning_decisions", "tuning_events",
        ):
            self.assertIn(table, tables)
        self.assertEqual(
            {"week_start", "generated_at", "schema_version", "report_json"}, weekly_columns
        )
        self.assertEqual(1, preserved)


if __name__ == "__main__":
    unittest.main()
