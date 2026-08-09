# 统计服务与管理看板

## 组成

- `report_server.py`：保留原有 `/report/upload`，新增 `/report/telemetry` 与受内部令牌保护的 `/api/stats`。
- `dfb-report.service`：生产环境 systemd 单元。
- `../website/admin/index.html`：`https://df.ltz88.cn/admin/` 的静态页面。
- `Caddyfile.example`：Dashboard 的 Basic Auth、静态文件和统计 API 路由示例。

生产环境路径：

- 服务脚本：`/opt/df-booster-report-server.py`
- 匿名统计数据库：`/opt/df-booster-data/telemetry.db`
- 用户主动上传的诊断报告：`/opt/df-booster-reports/`
- Dashboard 静态文件：`/opt/df-booster-admin/index.html`
- 服务密钥：`/etc/dfb-report.env`（只在服务器保存，不提交仓库）

## 验证

```powershell
python -m unittest server\test_report_server.py -v
```

发布时先更新并验证统计服务和 `/admin`，最后再发布带遥测客户端的新安装包与更新清单，避免客户端事件先到达旧服务。Dashboard 密码和两个服务端随机密钥不得写进 Git。
