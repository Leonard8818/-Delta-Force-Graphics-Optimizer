---
name: delta-force-boost
description: 三角洲行动（Delta Force）一键画面/帧率优化。检测用户电脑硬件与当前系统设置，经用户确认后批量应用 Windows 层帧率优化（电源计划、HAGS、游戏模式、关闭后台录制、禁用全屏优化、强制独显等），并给出对应显卡厂商的驱动设置清单。所有改动自动备份、支持一键还原。当用户提到"三角洲行动卡顿/掉帧/帧数低/画面优化/FPS 优化"时使用。
---

# 三角洲行动 · 一键画面优化（通用 Agent 技能）

本技能与具体 AI 工具无关：Claude Code、Codex、WorkBuddy、豆包等任何能在用户 Windows
电脑上执行 PowerShell 的助手，按下面的流程操作即可。核心逻辑全部在
`scripts/delta-booster.ps1` 里，你只负责：**检测 → 向用户解释 → 征得确认 → 执行 → 汇报**。

## 前置条件

- Windows 10/11；脚本兼容自带的 Windows PowerShell 5.1，无需安装任何东西。
- 部分优化项（电源计划、HAGS）需要**管理员权限**的 PowerShell。
- 所有命令都在本技能所在目录执行（下文用 `<root>` 表示本文件所在文件夹）。

## 流程

### 第 1 步：检测（只读，安全）

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -Detect -Json
```

返回 JSON：`Hardware`（CPU/内存/显卡/系统版本/是否管理员）、`GamePath`（自动找到的
游戏主程序，找不到为空）、`Items`（每个优化项的 Id、当前状态 Optimized、说明）、
`GpuGuide`（按用户显卡厂商生成的驱动设置手动清单）。

### 第 2 步：向用户汇报并确认

用平实的语言告诉用户：检测到什么硬件、哪些项已优化、哪些项建议优化、每项干什么。
**必须先获得用户明确同意才能进入第 3 步**——这是改系统设置，不是普通操作。

注意事项（如实告知用户）：
- `visualfx-perf`（视觉效果最佳性能）会让桌面外观明显变朴素，默认不做；
- `mouse-accel-off` 会改变鼠标手感，只推荐给愿意重新适应的 FPS 玩家；
- `hypervisor-off`（关引导虚拟化）会让 WSL2/Hyper-V/安卓模拟器/内核隔离全部失效，
  必须用户明确知情才可选；`pagefile-custom`（固定虚拟内存）只在闪退/爆内存时才建议；
- `wsearch-off` 会让系统搜索变慢，`hibernate-off` 会顺带关掉快速启动；
- 笔记本用户切「卓越性能」电源计划会更耗电；
- HAGS、MPO、服务禁用、bcdedit、中断绑核等项需要重启后完全生效；
- `pcie-check` 是纯检测项，只读不写，报告链路异常时应引导用户检查插槽/延长线。

### 第 3 步：应用（需用户同意；含系统级项时需管理员）

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -Apply -Json
```

- 默认应用所有推荐项；用 `-Items power-ultimate,dvr-off,...` 只应用用户选中的项。
- 也可以整套套用预设方案：`-Apply -Preset balanced`。先用 `-ListPresets` 看可选方案，
  把方案名和说明念给用户听、让他选，比逐项解释 28 个开关更省事。
  内置三套（顺序即界面下拉顺序，第一套为主推）：
  - `felix` 费利克斯路线（25 项主推全套）：按抖音博主费利克斯Fx 的调试链路排列——
    ①电源深度定制 → ②进程/IO 优先级 → ③中断绑核 → ④系统精简 → ⑤显卡驱动层。
    代价要如实告知：鼠标手感变直、休眠/快速启动没了、Windows 搜索变慢、待机功耗升高、
    笔记本更耗电；不含关引导虚拟化，WSL/模拟器不受影响。
  - `balanced` 均衡推荐（15 项，副作用小）：不改桌面外观和鼠标手感、不禁用服务、不动休眠。
  - `safe-only` 保守（6 项）：只改当前用户 HKCU、不需重启。
- 用户想保留自己的搭配：`-SavePreset "方案名" -Items id1,id2`（存到 `<root>\profiles\`），
  之后可 `-Apply -Preset 方案名`；`-DeletePreset 方案名` 删除（内置方案删不掉）。
- 若检测未找到游戏路径，追加 `-GamePath "游戏主程序完整路径"`（主程序通常是
  `DeltaForceClient-Win64-Shipping.exe`；找不到时向用户询问安装位置）。
- 权限不足时脚本会报错并列出需要管理员的项——此时用管理员身份重开终端再执行，
  或让用户以管理员运行。
- 每次 Apply 自动把旧值备份到 `<root>\backup\backup-时间戳.json`。

### 第 4 步：显卡驱动部分（手动，念给用户听）

驱动内 3D 设置无法安全脚本化。把第 1 步返回的 `GpuGuide` 清单展示给用户，
指导其在 NVIDIA 控制面板 / AMD Adrenalin 中手动设置（约 2 分钟）。

进阶（可选）：`<root>\tools\` 已附带按费利克斯参数生成的 `DeltaForce-Felix.nip`
（电源最高性能/超低延迟超高/垂直同步强制关/预渲染 1/着色器缓存无限制/线程优化开/
DLSS 强制 Preset K）。用户再自行下载 NVIDIA Profile Inspector（nvidiaProfileInspector.exe）
放入同目录后，检测结果会多出 `nvidia-profile` 项，可用 `-Items nvidia-profile` 一键导入。
该 .nip 未经实机导入验证，且此项无自动备份——导入前必须提醒用户先在 Inspector 中
Export Profiles 手动备份当前配置。

### 还原（用户后悔时）

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -Restore
```

按最近一次备份逆序恢复；`-BackupFile` 可指定某个具体备份。

## 优化项一览（Id 供 -Items 使用）

所有项分两档：`safe`（下表全部）与 `risky`。**不带 `-Items` 时只执行 safe 档默认项**；
risky 档必须同时用 `-Items` 点名并加 `-Risky` 才会执行（当前版本尚无 risky 项）。

| Id | 作用 | 默认 | 管理员 |
|---|---|---|---|
| power-ultimate | 电源计划切到卓越性能 | 是 | 需要 |
| power-tuning | 电源计划隐藏项调优：USB3 链路省电关闭、性能时间检查间隔 5000ms、大小核调度强制高性能核、关电源节流 | 是 | 需要 |
| powerplan-lock | 建计划任务锁定电源计划，防游戏篡改 | 否 | 需要 |
| hags | 开启硬件加速 GPU 计划 | 是 | 需要 |
| game-mode | 开启 Windows 游戏模式 | 是 | 否 |
| dvr-off | 关闭 Xbox 后台录制 | 是 | 否 |
| prio-separation | Win32PrioritySeparation=40，前台调度权重 | 是 | 需要 |
| paging-exec | 内核代码常驻内存 | 是 | 需要 |
| wer-off | 关闭 Windows 错误报告 | 是 | 否 |
| mem-compress-off | 关闭内存压缩与页面合并 | 内存≥32G 才默认 | 需要 |
| transparency-off | 关闭窗口透明特效 | 是 | 否 |
| fso-off | 为游戏禁用全屏优化 | 是 | 否 |
| gpu-pref | 强制游戏用高性能 GPU | 是 | 否 |
| game-priority | 游戏进程 CPU/IO 优先级提到高（IFEO） | 是 | 需要 |
| visualfx-perf | 视觉效果最佳性能 | 否 | 否 |
| mouse-accel-off | 关闭鼠标指针精确度 | 否 | 否 |
| mpo-off | 禁用 MPO 多平面叠加（OverlayTestMode=5，治闪烁） | 是 | 需要 |
| net-throttling-off | 解除多媒体网络限流（NetworkThrottlingIndex=0xffffffff） | 是 | 需要 |
| sys-responsiveness | MMCSS 后台 CPU 保留降为 0（SystemResponsiveness） | 是 | 需要 |
| sysmain-off | 禁用 SysMain 预取服务（Start=4） | 否 | 需要 |
| wsearch-off | 禁用 Windows Search 索引（Start=4，搜索会变慢） | 否 | 需要 |
| hibernate-off | 关闭休眠与快速启动（powercfg -h off） | 台式机默认 | 需要 |
| gpu-pstate-lock | 禁止显卡动态降频（DisableDynamicPstate=1，待机功耗升） | 否 | 需要 |
| gpu-irq-affinity | 显卡中断绑核（DevicePolicy=4 + KAFFINITY 掩码，绑最后一个 P 核） | 否 | 需要 |
| pcie-check | PCIe 链路体检（纯检测，nvidia-smi 读上限） | 否 | 否 |
| dyntick-off | 禁用动态计时器（bcdedit disabledynamictick yes） | 否 | 需要 |
| hypervisor-off | 关闭引导虚拟化（bcdedit，WSL/模拟器会失效！） | 否 | 需要 |
| pagefile-custom | 虚拟内存固定（初始=内存×1.5、最大=×2，仅闪退时用） | 否 | 需要 |
| nvidia-profile | 导入 N 卡配置档（需 tools\ 就位） | 否 | 需要 |

`power-tuning` 涉及的电源项默认被 Windows 隐藏，脚本会先用 `powercfg -attributes`
解除隐藏再写入，原隐藏状态一并进备份；CPU 不支持的项（如非大小核 CPU 的调度策略）
自动跳过而不报错。

## 红线（任何 agent 都必须遵守）

1. 未经用户明确同意，不得执行 `-Apply` / `-Restore`。
2. 不要绕过脚本自行改注册表——脚本的备份机制是唯一的还原保障。
3. 不修改游戏安装目录内的任何文件（反作弊敏感区，本技能设计上就不碰）。
4. 执行后如实汇报每项成功/失败，并告知备份文件位置与还原方法。
