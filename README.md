# 三角洲行动画面优化助手

[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0A1512)](#环境要求)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-0A1512)](#环境要求)
[![License](https://img.shields.io/badge/license-MIT-00E884)](LICENSE)
[![Unofficial](https://img.shields.io/badge/%E9%9D%9E%E5%AE%98%E6%96%B9%E4%B8%AA%E4%BA%BA%E9%A1%B9%E7%9B%AE-E5C46A)](NOTICE.md)

面向《三角洲行动》玩家的 Windows 画面与帧率优化工具，支持 AI Agent 调用 Skill，完成系统检测、优化执行与一键还原。

工具覆盖电源计划、进程与 IO 优先级、HAGS、后台录制、系统服务和显卡层设置。所有写入操作都会先保存原值，支持一键还原；不修改游戏目录内的文件，不注入游戏进程，也不与反作弊交互。

[下载](https://df.ltz88.cn/) · [快速开始](#安装与快速开始) · [Agent Skill](#agent-skill) · [命令行](#命令行) · [安全](#安全与风险提示) · [贡献](#贡献)

## 为什么选择这个工具？

- **集中管理** — 把散落在不同教程里的 Windows 优化项整理到同一个界面
- **自动检测** — 识别硬件、游戏路径和当前设置，只展示适用于当前电脑的内容
- **可控执行** — 提供主推全套、均衡推荐、保守模式，也支持逐项选择和自定义方案
- **完整回滚** — 每次修改前记录原值，包括原本不存在的注册表值
- **自动实测** — 「自动寻找最佳配置 Beta」在同一台电脑的固定场景里重复采样，只保留规则确认有收益的低风险组合
- **结果透明** — 分别报告成功、失败、跳过、体检异常和需要重启的项目
- **Agent 友好** — 内置通用 [SKILL.md](SKILL.md)，可由能执行 PowerShell 的 AI Agent 调用
- **边界明确** — 只调整 Windows 系统层设置，不修改游戏文件

## 功能

| 类别 | 能力 |
|---|---|
| ⚡ 电源与调度 | 卓越性能电源计划、隐藏电源项调优、前台调度、MMCSS 游戏任务 |
| 🎮 游戏优化 | Windows 游戏模式、关闭后台录制、禁用全屏优化、指定高性能 GPU |
| 🖥️ 显卡设置 | HAGS、MPO、NVIDIA App 自动优化体检、显卡型号伪装与驱动设置指引 |
| 🧠 内存与系统 | 内存压缩、页面文件、休眠、系统服务及视觉效果设置 |
| 🔍 硬件体检 | 只读检查 PCIe 链路、VC++ v14 运行库、内存 XMP / EXPO |
| 📈 性能记录 | 游戏启动后采样 120 秒平均帧率、1% 低帧率、GPU 占用率、温度与功耗汇总 |
| 🧪 自动调优 Beta | 三次基线加低风险候选组对比；按采样质量、性能、温度与功耗规则决定保留或定向回滚 |
| 🗂️ 方案管理 | 三套内置预设，自定义保存、载入和删除方案 |
| ↩️ 备份还原 | 写入前自动备份，默认合并全部尚未还原的备份回到第一次优化前，也可指定单份备份 |
| 📋 游戏内参考 | 按游戏菜单结构整理画质设置，供玩家手动调整 |
| 🔄 更新 | 检查新版本、下载进度、SHA256 与文件大小强制校验 |

不同 CPU、显卡、内存和系统状态的实际收益会有差异，本项目不承诺固定帧数提升。

## 安装与快速开始

### 环境要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1
- 启动软件时由自有 `EngineHost.exe` 请求一次管理员确认；主界面在本次会话保持管理员权限，执行优化、还原和自动调优不会重复确认

### 快速开始（图形界面）

1. 从 [下载页](https://df.ltz88.cn/) 获取 `DeltaForceBooster-Setup-vX.Y.exe`
2. 运行安装向导；程序文件默认安装到 `%ProgramFiles%\DeltaForceBooster`
3. 打开工具，等待硬件、游戏路径和系统设置检测完成
4. 选择预设方案或逐项勾选，点击「执行优化」
5. 需要恢复时点击「还原设置」

如需使用「自动寻找最佳配置 Beta」，请先定位真实的游戏主程序，再按照页面提示进入同一地图、画质、分辨率和固定路线完成每轮采样。第一版只测试三个内置、低风险、无需重启的候选组；结论由本地确定性规则计算，不会自动加入显卡型号伪装等高风险项。

自存方案和运行配置按原登录用户隔离保存在受保护的 `%ProgramData%\DeltaForceBooster\users\<Windows SID>`，还原备份保存在 `%ProgramData%\DeltaForceBooster\backup`，不会与程序文件混放。升级时会由启动前的普通权限进程只读导入旧版 `%LocalAppData%` 数据，源文件仍保留。

### 预设方案

| 方案 | 说明 |
|---|---|
| `main` | 主推全套，覆盖主要系统、调度与显卡层设置；仅 NVIDIA 主显卡包含「显卡型号伪装」，AMD / Intel 自动禁用，GUI 会单独二次确认，CLI 需显式加 `-Risky` |
| `balanced` | 均衡推荐，保留桌面效果、鼠标手感、系统服务和休眠 |
| `safe-only` | 保守模式，仅修改当前用户设置，通常不需要重启；受保护备份沿用启动时已确认的管理员会话 |

## Agent Skill

`delta-force-boost` 是一套面向 AI Agent 的《三角洲行动》画面优化 Skill，核心流程与操作边界定义在 [SKILL.md](SKILL.md) 中。

Agent 不会直接开始修改系统。它会先检测硬件和当前设置，解释准备执行的项目与副作用，获得用户明确同意后再调用脚本，最后逐项汇报执行结果、备份位置和重启要求。

### 快速开始（AI Agent）

> 需要一个能够在本机执行 PowerShell 命令的 AI Agent。

将下面的指令发送给 Agent：

```text
读取 https://raw.githubusercontent.com/Leonard8818/-Delta-Force-Graphics-Optimizer/main/SKILL.md
并按其中的流程帮我优化《三角洲行动》的帧率
```

### 工作流程

| 阶段 | Agent 行为 |
|---|---|
| 检测 | 读取硬件、游戏路径、管理员权限和当前优化状态 |
| 说明 | 展示推荐项目、实际作用、可能的副作用和重启要求 |
| 确认 | 获得用户明确同意，不代替用户接受免责声明 |
| 执行 | 调用项目脚本，所有改动沿用统一备份机制 |
| 汇报 | 区分成功、失败、跳过和体检异常，给出还原方法 |

Skill 不依赖某一家模型或专有工具。完整参数、预设说明和 Agent 操作红线见 [SKILL.md](SKILL.md)。

## 命令行

### 检测

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Detect
```

### 应用预设

```powershell
# 在管理员 PowerShell 中执行
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Apply -Preset main -Risky
```

### 还原

```powershell
# 在管理员 PowerShell 中执行
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Restore
```

执行 `-Apply` 或 `-Restore` 前，请先阅读 [DISCLAIMER.md](DISCLAIMER.md)。每次应用都会在 `%ProgramData%\DeltaForceBooster\backup` 生成带完整性校验的写前日志备份。

## 更新

工具启动时检查一次新版本，运行期间每 30 分钟静默复查。自动检查只负责提醒，不会自行下载或安装。

发布清单可声明最低支持版本。支持该字段的 v0.19.0 及以后客户端低于该值时，更新窗口不提供跳过或稍后选项，必须升级后才能继续使用；最低支持版本保持 v0.20.4，因此 v0.20.4 不会被强制升级到 v0.21.3。更早客户端仍会收到普通更新提示，官网同时保留最新版与多个历史版本安装包。

用户点击「立即更新」后，工具会在本次 `EngineHost` 管理员会话内下载、校验并封存更新包到受保护的暂存目录；安装器启动后还会再次校验，再完整解压、核对发布清单并事务切换版本。下载源限制为官方域名白名单，任一校验失败都不会安装。
更新安装前会等待发起更新的旧进程退出。旧版若仍装在下载文件夹等普通程序可写的位置，会自动迁移到默认受保护目录，同时保留自存方案、备份和运行配置；切换失败会回滚旧版本。全新安装默认使用 `%ProgramFiles%\DeltaForceBooster`，也可选择其他本地固定 NTFS 盘的卷根一级目录；该目录会成为永久受保护 anchor，实际程序位于其 `app` 子目录。
如果标准用户在 UAC 中输入了另一管理员账户，更新仍会完成，但不会用批准账户自动启动新版；界面会提示原登录用户安装后从桌面或开始菜单手动打开。

卸载时由自有 `UninstallHost.exe` 显示一次管理员确认，不会再以 “Windows PowerShell” 名称重复询问。卸载助手从安装根外执行删除，普通卸载始终保留受保护备份，重装后仍可继续还原。

## 故障排查

### PowerShell 脚本被拦截

优先使用根目录的 `启动优化工具.exe`。手动运行脚本时，请保留 `-ExecutionPolicy Bypass`，或者执行：

```powershell
Unblock-File -Path .\* -Recurse
```

### 优化没有生效

以管理员身份运行诊断脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\diagnose.ps1
```

诊断输出包含电源方案、隐藏电源项和全部优化项的真实状态。提交问题时请附上完整输出。

## 安全与风险提示

- 每一项可还原的系统设置改动都会先写入受保护备份，失败时保留系统原始错误；纯检测和明确标注不可还原的缓存清理不生成备份
- 不修改游戏安装目录内的文件，不注入进程，不与反作弊交互
- 经用户同意后发送匿名使用统计（随机安装标识、短期设备令牌、版本与硬件概况、启动/优化/还原汇总，以及游戏中最多 120 秒的平均帧率 / 1% 低帧率 / GPU 状态汇总和未使用/轻量/均衡/深度四档优化强度）。用户主动启动自动调优 Beta 后，还会发送实验编号、规则版本、固定候选组与项目 ID、每轮汇总指标、样本有效性及最终保留/回滚结果，用于评估规则效果；不上传自存方案、逐帧 CSV、用户名、机器名、SID、游戏路径、注册表内容或诊断日志，可在软件的统计设置中停用（状态保存在受保护的 per-SID 配置区）。汇总来自客户端自动采样，不是独立实验室测量；诊断报告保留 30 天、普通性能会话保留 90 天，匿名安装标识、按日使用明细和调优实验明细保留 180 天
- 诊断报告只有在用户主动点击、选择当前问题与已有改善，并确认上传数据清单后才会上传
- 程序文件默认位于 Program Files；低权限启动器先校验关键文件哈希，再只启动带 `requireAdministrator` 清单的自有 `EngineHost.exe`，该宿主在整个 GUI 生命周期保持提升并代理固定白名单的低权限用户动作
- 更新包仅允许从官方 HTTPS 域名下载，下载后与安装前分别校验 SHA256 和文件大小，并拒绝 reparse point 路径
- 效果有争议或副作用明显的项目默认不选中

SHA256 和启动器内置的发布文件哈希可以发现传输后或安装后的文件替换，但项目目前没有代码签名证书，无法提供商业签名证书的发布者身份保证，请在使用前了解这一限制。

首次运行需要由用户本人阅读并接受 [DISCLAIMER.md](DISCLAIMER.md)。AI Agent 不得代替用户确认，也不得绕过该步骤。

## 贡献

欢迎提交 [Issue](https://github.com/Leonard8818/-Delta-Force-Graphics-Optimizer/issues) 或 [Pull Request](https://github.com/Leonard8818/-Delta-Force-Graphics-Optimizer/pulls)。

新增优化项必须满足一个硬性条件：能够准确检测当前状态、在写入前完整备份，并可靠恢复到原始状态。提交代码前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [SECURITY.md](SECURITY.md)。

### 贡献者

- [@Leonard8818](https://github.com/Leonard8818) — 项目作者与维护者
- [@codex](https://github.com/codex) — OpenAI 编程协作助手

## 许可证

本项目基于 [MIT License](LICENSE) 开源。

这是一个非官方个人项目，与腾讯公司及《三角洲行动》官方没有关联。商标、免责声明及其他说明见 [NOTICE.md](NOTICE.md) 和 [DISCLAIMER.md](DISCLAIMER.md)。
