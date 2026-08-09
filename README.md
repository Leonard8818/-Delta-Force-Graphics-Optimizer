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
- **结果透明** — 分别报告成功、失败、跳过、体检异常和需要重启的项目
- **Agent 友好** — 内置通用 [SKILL.md](SKILL.md)，可由能执行 PowerShell 的 AI Agent 调用
- **边界明确** — 只调整 Windows 系统层设置，不修改游戏文件

## 功能

| 类别 | 能力 |
|---|---|
| ⚡ 电源与调度 | 卓越性能电源计划、隐藏电源项调优、前台调度、MMCSS 游戏任务 |
| 🎮 游戏优化 | Windows 游戏模式、关闭后台录制、禁用全屏优化、指定高性能 GPU |
| 🖥️ 显卡设置 | HAGS、MPO、NVIDIA App 自动优化开关、显卡型号伪装与驱动设置指引 |
| 🧠 内存与系统 | 内存压缩、页面文件、休眠、系统服务及视觉效果设置 |
| 🔍 硬件体检 | 只读检查 PCIe 链路、VC++ v14 运行库、内存 XMP / EXPO |
| 📈 性能记录 | 游戏启动后采样 120 秒平均 FPS、1% Low、GPU 占用率、温度与功耗汇总 |
| 🗂️ 方案管理 | 三套内置预设，自定义保存、载入和删除方案 |
| ↩️ 备份还原 | 写入前自动备份，按最近一次或指定备份逆序恢复 |
| 📋 游戏内参考 | 按游戏菜单结构整理画质设置，供玩家手动调整 |
| 🔄 更新 | 检查新版本、下载进度、SHA256 与文件大小强制校验 |

不同 CPU、显卡、内存和系统状态的实际收益会有差异，本项目不承诺固定帧数提升。

## 安装与快速开始

### 环境要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1
- 部分系统级设置需要管理员权限

### 快速开始（图形界面）

1. 从 [下载页](https://df.ltz88.cn/) 获取 `DeltaForceBooster-Setup-vX.Y.exe`
2. 运行安装向导并选择安装位置
3. 打开工具，等待硬件、游戏路径和系统设置检测完成
4. 选择预设方案或逐项勾选，点击「执行优化」
5. 需要恢复时点击「还原设置」

> 建议不要长期安装在「下载」文件夹。Windows「存储感知」可能清理该目录，并删除 `backup\` 中的还原备份。

### 预设方案

| 方案 | 说明 |
|---|---|
| `main` | 主推全套，覆盖主要系统、调度与显卡层设置 |
| `balanced` | 均衡推荐，保留桌面效果、鼠标手感、系统服务和休眠 |
| `safe-only` | 保守模式，仅修改当前用户设置，不需要重启 |

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
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Apply -Preset main
```

### 还原

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Restore
```

执行 `-Apply` 或 `-Restore` 前，请先阅读 [DISCLAIMER.md](DISCLAIMER.md)。每次应用都会在 `backup\` 目录生成备份文件。

## 更新

工具启动时检查一次新版本，运行期间每 30 分钟静默复查。自动检查只负责提醒，不会自行下载或安装。

用户点击「立即更新」后，工具会下载更新包、校验 SHA256 与文件大小、安装到当前目录并启动新版本。下载源限制为官方域名白名单，校验失败时不会执行安装包。
更新安装前会等待发起更新的旧进程退出，并处理重复打开的旧窗口；窗口图标会预先载入内存，避免 `gui\app.ico` 被主程序持续占用而导致覆盖失败。

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

- 所有写入操作都会先备份，失败时保留系统原始错误
- 不修改游戏安装目录内的文件，不注入进程，不与反作弊交互
- 经用户同意后发送匿名使用统计（随机安装标识、版本与硬件概况、启动/优化/还原汇总，以及游戏中最多 120 秒的 FPS / 1% Low / GPU 状态汇总和未使用/轻量/均衡/深度四档优化强度）；不上传具体勾选项、自存方案名称、逐帧 CSV、用户名、机器名、SID、游戏路径、注册表内容或诊断日志，可在 `config\telemetry.json` 中停用
- 诊断报告只有在用户主动点击并确认后才会上传
- 更新包仅允许从官方 HTTPS 域名下载，并校验 SHA256 与文件大小
- 效果有争议或副作用明显的项目默认不选中

SHA256 可以校验下载文件是否与版本清单一致，但无法防止官方服务器和清单同时被篡改。项目目前没有代码签名证书，请在使用前了解这一限制。

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
