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
- 调用脚本必须带 `-ExecutionPolicy Bypass`（下载解压的脚本带网络标记，部分机器默认
  策略会拒绝未签名 .ps1）。普通用户的图形入口是根目录 `启动优化工具.exe`（bat 为后备）。

## 流程

### 第 1 步：检测（只读，安全）

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -Detect -Json
```

返回 JSON：`Hardware`（CPU/内存/显卡/系统版本/是否管理员）、`GamePath`（自动找到的
游戏主程序，按可靠性多路查找：运行中的游戏进程 → 卸载注册表 → WeGame/Steam 平台目录 →
盘符常见位置兜底；仍找不到为空）、`Items`（每个优化项的 Id、当前状态 Optimized、说明）、
`GpuGuide`（按用户显卡厂商生成的驱动设置手动清单）。

### 第 2 步：向用户汇报并确认

用平实的语言告诉用户：检测到什么硬件、哪些项已优化、哪些项建议优化、每项干什么。
**必须先获得用户明确同意才能进入第 3 步**——这是改系统设置，不是普通操作。

注意事项（如实告知用户）：
- `visualfx-perf`（视觉效果最佳性能）会让桌面外观明显变朴素，默认不做；
- `mouse-accel-off` 会改变鼠标手感，只推荐给愿意重新适应的 FPS 玩家；
- `pagefile-custom`（固定虚拟内存）只在闪退/爆内存时才建议；
- `windowed-opt-off`（关窗口化游戏优化）微软说开着能降延迟、社区说关掉才不掉帧，
  两派都有实测支持，默认不勾选，建议让用户开关各测一次再定；
- `wsearch-off` 会让系统搜索变慢，`hibernate-off` 会顺带关掉快速启动；
- 笔记本用户切「卓越性能」电源计划会更耗电；
- 电源计划、HAGS、MPO、服务禁用、bcdedit、中断绑核等项需要重启后完全生效——Apply 结果里
  每项带 `Reboot` 字段（成功且确需重启才为 true），汇报时按它提醒用户重启，别自己猜；
- `pcie-check` / `vcredist-check` / `xmp-check` 是纯检测项，只读不写：分别报告 PCIe 链路
  异常（引导查插槽/延长线）、VC++ v14 运行库版本错乱（引导手动重装，**不要代劳卸载**）、
  内存未开 XMP/EXPO（引导进 BIOS，软件改不了）。检测项查出问题时结果标 `Attention`
  归入「体检发现问题」，不计入失败。vcredist 的提示文案已带微软官方永久下载链接
  （aka.ms/vs/17/release/vc_redist.x64.exe 与 .x86.exe），转述时直接给用户即可；
  转述教程要点：覆盖安装不需要先卸载、x64 与 x86 两个都要装、装完重启后再检测确认。
  XMP/EXPO 转述要点：开机按 Del/F2 进 BIOS，Intel 叫 XMP、AMD 叫 EXPO/DOCP，收益因
  硬件而异别承诺具体帧数，开完开不了机就进 BIOS 恢复默认设置即可。
- **不要建议关闭引导虚拟化**：ACE 反作弊已开始检查虚拟化状态，关掉会导致游戏报错进不去，
  该项已于 v0.6 移除。

### 第 3 步：应用（需用户同意；含系统级项时需管理员）

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -Apply -Json
```

- 默认应用所有推荐项；用 `-Items power-ultimate,dvr-off,...` 只应用用户选中的项。
- 也可以整套套用预设方案：`-Apply -Preset balanced`。先用 `-ListPresets` 看可选方案，
  把方案名和说明念给用户听、让他选，比逐项解释 32 个开关更省事。
  内置三套（顺序即界面下拉顺序，第一套为主推）：
  - `felix` 费利克斯路线（30 项主推全套）：按抖音博主费利克斯Fx 的调试链路排列——
    ①电源深度定制 → ②进程/IO 优先级 → ③中断绑核 → ④系统精简 → ⑤显卡驱动层。
    代价要如实告知：鼠标手感变直、休眠/快速启动没了、Windows 搜索变慢、待机功耗升高、
    笔记本更耗电；不含关引导虚拟化，WSL/模拟器不受影响。
  - `balanced` 均衡推荐（20 项，副作用小）：不改桌面外观和鼠标手感、不禁用服务、不动休眠。
  - `safe-only` 保守（7 项）：只改当前用户 HKCU、不需重启。
- 用户想保留自己的搭配：`-SavePreset "方案名" -Items id1,id2`（存到 `<root>\profiles\`），
  之后可 `-Apply -Preset 方案名`；`-DeletePreset 方案名` 删除（内置方案删不掉）。
- 若检测未找到游戏路径，追加 `-GamePath "游戏主程序完整路径"`（主程序通常是
  `DeltaForceClient-Win64-Shipping.exe`；找不到时向用户询问安装位置）。
- 权限不足时脚本会报错并列出需要管理员的项——此时用管理员身份重开终端再执行，
  或让用户以管理员运行。
- 每次 Apply 自动把旧值备份到 `<root>\backup\backup-时间戳.json`。
- 结果里每项带 `Ok`、`Skipped`、`Attention` 字段，末尾有「x 成功、y 失败、z 跳过
  （、n 项体检发现问题）」汇总。`Attention=true` 表示纯检测项查出了真实问题——这是
  检测项「立功」而不是工具失败，转述时务必与失败区分开，别让用户误以为工具坏了；
  失败消息内含 powercfg 等命令的原始报错，直接转述给用户即可。
- **电源计划命名行为**：系统没有可直接激活的卓越性能方案时（e9a42b02 在多数版本上只是
  不可激活的模板），脚本会实例化一份并命名为「三角洲优化 · 卓越性能」，GUID 记在
  `<root>\config\power-scheme.json`，重复执行只复用不堆积。`-Restore` 会切回原方案但
  **保留**该自建方案（输出的 Notes 字段里有说明，请一并念给用户）。
- 优化后某项仍「未达标」时，让用户以管理员运行只读诊断并回传输出：
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\diagnose.ps1"`。

### 第 4 步：显卡驱动部分（手动，念给用户听）

驱动内 3D 设置无法安全脚本化。把第 1 步返回的 `GpuGuide` 清单展示给用户，
指导其在 NVIDIA 控制面板 / AMD Adrenalin 中手动设置（约 2 分钟）。清单已按显卡厂商
标注了因型号而异的项（DLSS 仅 RTX 系、Preset K 还需 40/50 系、FSR 各家通用、XeSS 为
Intel 优化、低延迟 N 卡走 Reflex / A 卡走 Anti-Lag），转述时先说明检测到的显卡型号
（`Hardware.MainGpuName`，双显卡以独显为准），再给对应厂商的内容。

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
结果字段：`RestoredOps`（还原条数）、`Failed`（真失败，带人话项名）、`Skipped`
（跳过且无实际影响——「继承默认」的电源隐藏项删不掉注册表子键（ACL 只授权 SYSTEM）
且残留在已停用的工具自建方案里时归此类，转述时明确告诉用户这不影响任何生效设置）、
`Notes`（如工具自建电源方案保留的说明）。

## 优化项一览（Id 供 -Items 使用）

所有项分两档：`safe`（下表全部）与 `risky`。**不带 `-Items` 时只执行 safe 档默认项**；
risky 档必须同时用 `-Items` 点名并加 `-Risky` 才会执行（当前版本尚无 risky 项）。

| Id | 作用 | 默认 | 管理员 |
|---|---|---|---|
| power-ultimate | 电源计划切到卓越性能（无可激活方案时自建「三角洲优化 · 卓越性能」并激活，激活后回读校验） | 是 | 需要 |
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
| nv-autoopt-off | 关闭 NVIDIA App「自动优化游戏设置」（EnableAutomaticApplyOPS=0，防 OPS 覆写玩家手调画质；备份整个 config.xml，还原逐字节写回；没装 NVIDIA App 时自动不适用） | 是 | 否 |
| gpu-irq-affinity | 显卡中断绑核（DevicePolicy=4 + KAFFINITY 掩码，绑最后一个 P 核） | 否 | 需要 |
| pcie-check | PCIe 链路体检（纯检测，nvidia-smi 读上限） | 否 | 否 |
| dyntick-off | 禁用动态计时器（bcdedit disabledynamictick yes） | 否 | 需要 |
| mmcss-games | MMCSS 游戏任务档位拉满（GPU/IO 调度，收益微弱但零副作用） | 是 | 需要 |
| windowed-opt-off | 关闭「窗口化游戏优化」（复合串只改目标子键） | 否 | 否 |
| vcredist-check | VC++ v14 运行库冲突体检（纯检测） | 否 | 否 |
| xmp-check | 内存 XMP/EXPO 体检（纯检测） | 否 | 否 |
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
5. 不要代替用户下载或运行任何安装包。工具版本升级走图形界面自带的内置更新
   （官方域名白名单 + SHA256 强制校验，见 `scripts/updater.ps1`），agent 只需
   提示用户点标题栏的「有新版本」入口即可。
