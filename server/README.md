# 统计服务与私有周报 API

## 组成

- `report_server.py`：诊断上传、匿名遥测、设备令牌与受内部令牌保护的统计 API。
- `dfb-report.service`：生产环境 systemd 单元。
- 私有周报页面作为 `.gitignore` 排除的部署物维护，源码不进入 GitHub；生产环境仍由 Caddy Basic Auth 保护。
- `Caddyfile.example`：私有页面的 Basic Auth、静态文件和统计 API 路由示例。

生产环境路径：

- 服务脚本：`/opt/df-booster-report-server.py`
- 匿名统计数据库：`/opt/df-booster-data/telemetry.db`
- 用户主动上传的诊断报告：`/opt/df-booster-reports/`
- 私有周报静态文件：`/opt/df-booster-admin/index.html`
- 服务密钥：`/etc/dfb-report.env`（只在服务器保存，不提交仓库）

## 验证

```powershell
python -m unittest server\test_report_server.py -v
```

## 遥测协议

首次注册：

```http
POST /report/telemetry/register
Content-Type: application/json

{"installId":"匿名安装 GUID"}
```

成功返回 `deviceToken` 与 Unix 秒格式的 `expiresAt`。客户端把它们保存在现有的
`telemetry.json`，不要写入日志。随后每个 `/report/telemetry` 请求除原有字段外还要发送：

- `deviceToken`：服务端签发、与 `installId` 绑定的令牌；
- `eventId`：每个事件新建且永不复用的 GUID；
- `sentAt`：发送时的 UTC Unix 秒，服务端允许前后 10 分钟时钟偏差。

从 v0.19.4 起缺少令牌的事件返回 `401`。令牌失效时客户端应重新注册后最多重试一次；重复 `eventId` 返回 `409`；
同一匿名设备每天最多接收 8 个性能会话，超限返回 `429`；时长不足或指标异常返回
`422`。没有令牌的旧客户端基础事件在迁移期继续接收，响应也会附带新令牌；管理页的版本与
硬件分布按匿名安装标识的原始整数设备数展示，同时在数据质量字段保留可信/旧版权重口径供内部审计。
旧客户端性能会话不进入可信性能汇总或优化前后结论。

性能会话至少持续 60 秒，并校验帧率、占用率、温度、功耗及平均值/最大值关系。服务端
只对已认证会话使用中位数汇总：单个汇总组至少覆盖 5 台独立匿名设备，优化前后变化至少 5 个同设备、
同真实显卡配对后才返回可展示数值。所有这些数据仍属于客户端自报，未经独立测量验证。

`event="tuning"` 只接收已认证客户端，分为 `experiment_started`、`variant_applied`、
`run_completed` 和 `experiment_completed` 四类事件。字段采用严格白名单；实验、候选和运行 ID
必须包含实验命名空间，候选 G1/G2/G3 的累计项目集合及哈希必须等于“当前对照方案 + 本组固定项”。
候选业务记录和终态一经写入即不可改写；未知字段、非法枚举、跨匿名设备接管实验、不匹配的
项目集合或异常指标返回 `409` / `422`。同一匿名设备每天最多 80 个调优事件。
实验运行独立写入 `tuning_*` 表，不混入普通 `performance_sessions`。

私有周报 API 为 `GET /api/weekly`，默认完整周按 `Asia/Taipei (UTC+8)` 的周一至周日计算，
也可用 `startDate=YYYY-MM-DD&endDate=YYYY-MM-DD` 查询包含首尾的自定义周期。自定义周期为
1–92 天，结束日期不晚于台北当天；默认对比紧邻当前周期且天数相同的上一周期。传入同长度的
`compareStartDate=YYYY-MM-DD&compareEndDate=YYYY-MM-DD` 可指定任意对比区间，生产工作台用两个
单日区间提供日与日对比。趋势图仍使用最近 8 个等长周期。两种模式都可按版本、真实显卡和
设备类型筛选。标准周的 `reportNumber` 从 2026-08-03 至 2026-08-09 稳定编号为第 1 周，
不使用 ISO 周序号。`performanceSampling` 分别返回原始采样会话、认证可信会话、可信独立设备、
有效优化前后配对及是否达到发布门槛，旧性能记录不会被删除。自定义周期始终实时计算，
不会读取或生成周快照；`POST /api/weekly/snapshot` 只固化以周一为起点的标准历史周报。两者都要求
`X-DFB-Admin-Token`。自动调优结论要求
每个实验至少 3 次稳定基线、3 次当前对照、2 次候选有效运行，环境和设置摘要一致、顺序受控且
候选全量成功；每组至少覆盖 20 台独立匿名设备才发布胜出率、性能变化与回滚率，同一设备每组
只贡献一份汇总，样本不足时只返回数量。

旧版运营页使用的 `GET /api/stats` 同时返回 `daily`（最近 30 个北京时间自然日）与
`hourly`（截至当前北京时间小时的最近 24 小时，ISO 值带 `+08:00`）两组用户趋势。小时活跃数按已认证事件回执中的
匿名设备去重，小时新增数按匿名设备首次出现时间统计；前端在同一张“用户分析”图中切换日/小时维度。
`performanceByGpu` 会保留原始、认证和旧版未认证会话数量；指标优先取认证会话，认证样本不足时只展示数据并明确标记，
不会把小样本或旧版会话写成可信结论。`performanceByGpuByDevice` 与 `gpusByDevice` 提供全部、
笔记本、台式机三组视图；分布数量均为整数。

官网只读取无需管理令牌的 `GET /report/public-stats`。该接口仅返回累计用户、近 7 日活跃、
近 15 分钟在线、今日启动次数、累计启动次数、累计执行优化和累计优化成功项七个整型汇总，
以及每张卡对应的 7 个日点或 8 个 15 分钟点迷你趋势；不返回设备明细、诊断报告、性能样本
或匿名标识，响应允许缓存 15 秒。

## 数据保留与维护

- 诊断报告保留 30 天；
- 性能会话保留 90 天；
- 防重放事件 ID 保留 2 天；
- 匿名安装标识与按日使用明细保留 180 天；
- 自动调优实验、候选、运行与决策明细保留 180 天；
- 服务启动时立即清理，此后运行中的维护线程每 6 小时清理一次；
- 也可独立执行 `python3 /opt/df-booster-report-server.py --maintenance`，不依赖新上传。

## 部署顺序

先备份数据库，然后部署并重启统计服务，确认 `/report/health` 正常以及旧客户端事件仍可
接收；再部署私有周报页面；最后发布带新遥测协议的客户端、安装包与更新清单。数据库迁移由
服务启动时的 `_init_db()` 原地增加列和防重放表，不删除旧记录。管理页密码、
`DFB_ADMIN_API_TOKEN` 和 `DFB_TELEMETRY_PEPPER` 只保存在服务器，不得写进 Git。
