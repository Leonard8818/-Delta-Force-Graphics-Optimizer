---
name: delta-force-boost
description: 三角洲行动（Delta Force）一键画面/帧率优化。检测用户电脑硬件与当前系统设置，经用户确认后批量应用 Windows 层帧率优化（电源计划、HAGS、游戏模式、关闭后台录制、禁用全屏优化、强制独显等），并给出对应显卡厂商的驱动设置清单。所有改动自动备份、支持一键还原。当用户提到"三角洲行动卡顿/掉帧/帧数低/画面优化/帧率优化"时使用。
---

# 三角洲行动 · 一键画面优化（通用 Agent 技能）

本技能与具体 AI 工具无关：Claude Code、Codex、WorkBuddy、豆包等任何能在用户 Windows
电脑上执行 PowerShell 的助手，按下面的流程操作即可。核心逻辑全部在
`scripts/delta-booster.ps1` 里，你只负责：**检测 → 向用户解释 → 征得确认 → 执行 → 汇报**。

## 前置条件

- Windows 10/11；脚本兼容自带的 Windows PowerShell 5.1，无需安装任何东西。
- 部分优化项（电源计划、HAGS）需要**管理员权限**的 PowerShell。
- **工具本体必须已装在用户机器上**。你可能是通过链接远程读到这份说明的——那样只有说明、
  没有脚本。先确认 `<root>` 是否存在（正式安装默认位置：
  `%ProgramFiles%\DeltaForceBooster`；旧版可能仍留有下载文件夹中的副本）；找不到就让用户去
  https://df.ltz88.cn/ 安装后再继续，
  **不要代替用户下载或运行安装包**。
- 所有命令都在本技能所在目录执行（下文用 `<root>` 表示工具的安装目录）。
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
- `mouse-accel-off` 会改变鼠标手感，只推荐给愿意重新适应的射击游戏玩家；
- 固定虚拟内存功能已停止新应用；旧版 `pagefile-custom` 备份仍可在「还原设置」中单独复原；
- `windowed-opt-off`（关窗口化游戏优化）微软说开着能降延迟、社区说关掉才不掉帧，
  两派都有实测支持，默认不勾选，建议让用户开关各测一次再定；
- `wsearch-off` 会让系统搜索变慢，`hibernate-off` 会顺带关掉快速启动；
- 笔记本用户切「卓越性能」电源计划会更耗电；
- 电源计划、HAGS、MPO、服务禁用、bcdedit、中断绑核等项需要重启后完全生效——Apply 结果里
  每项带 `Reboot` 字段（成功且确需重启才为 true），汇报时按它提醒用户重启，别自己猜；
- `pcie-check` / `vcredist-check` / `xmp-check` 是纯检测项，只读不写：分别报告 PCIe 链路
  异常（引导查插槽/延长线）、VC++ v14 运行库缺失（引导手动安装，**不要代劳卸载**）、
  内存当前频率与 SMBIOS 标称频率的差异（只能提示确认，不能证明某个性能档位一定存在）。检测项查出问题时结果标 `Attention`
  归入「体检发现问题」，不计入失败。
  vcredist 判定口径（引擎 v0.12 起）：**只有缺失某个/全部架构才算问题**。x64 与 x86
  是两套相互独立的运行库、各自服务对应位数的程序，两者版本不同步很常见且通常无害——
  检测只做中性陈述、不报问题；转述时**不要**把版本不同步说成掉帧/闪退的原因（社区有
  「重装后恢复」的个案报告，但没有严格证据证明因果）。
  缺失时的提示文案已带微软官方下载链接（aka.ms/vs/18/release/vc_redist.x64.exe 与
  .x86.exe——vs/18 是当前最新线；旧的 vs/17 线停在 14.44，在已装更新版本的机器上会
  被安装器判定降级而拒装），转述时直接给用户即可。转述教程要点：覆盖安装不需要先
  卸载、x64 与 x86 两个都装同一条线（vs/18）的包、装完重启后再检测确认；若安装包
  只显示「修复/卸载」，说明系统已有同版本——选「修复」即可；若报错 0x80070666
  「无法安装此产品，因为已安装更新的版本」，说明系统里的版本比安装包更新——这是
  正常的，不用处理，也不要为此去卸载；只有缺失某架构、或确实反复闪退且已排除其他
  原因时，才考虑在「应用和功能」里只卸载该架构的 VC++ 2015-2022 后重装，
  **绝不建议卸载其他年份的 VC++**（2010/2012/2013 是独立运行库，其他软件依赖）。
  内存档位转述要点：菜单名取决于主板品牌、CPU 平台与 DDR 代际，不可只按 Intel/AMD
  二分。MSI AMD DDR4 通常叫 A-XMP，华硕 AMD DDR4 常见 DOCP，AMD DDR5 才优先找 EXPO，
  Intel 通常找 XMP；ROG 魔霸等品牌笔记本可能完全不开放相关菜单。达到 SMBIOS 标称频率
  时不要再引导用户进 BIOS；菜单不存在时按厂商未开放或内存没有该档位处理，不刷非官方
  BIOS。收益因硬件而异，不承诺具体帧数；实际修改后启动异常再恢复 BIOS 默认设置。
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
  - `main` 主推全套（界面显示为「★ 主推全套」且启动默认选中）：按依赖顺序排列——
    ①电源深度定制 → ②进程/IO 优先级 → ③中断绑核 → ④系统精简 → ⑤显卡驱动层。
    代价要如实告知：鼠标手感变直、休眠/快速启动没了、Windows 搜索变慢、待机功耗升高、
    笔记本更耗电；其中唯一的 risky 项是「显卡型号伪装」，对 NVIDIA / AMD 主显卡显示，Intel
    主显卡自动禁用。GUI 会单独二次确认，CLI 套用 `main` 必须显式加 `-Risky`；不含关引导虚拟化，
    WSL/模拟器不受影响。
  - `balanced` 均衡推荐（20 项，副作用小）：不改桌面外观和鼠标手感、不禁用服务、不动休眠。
  - `safe-only` 保守：只改当前用户设置、通常不需重启；图形界面沿用软件启动时已确认的管理员
    会话，CLI 仍应在管理员 PowerShell 中执行。
- 用户想保留自己的搭配：`-SavePreset "方案名" -Items id1,id2`。图形界面保存在受保护的
  `%ProgramData%\DeltaForceBooster\users\<SID>\profiles\`；直接使用 CLI 时保存在当前用户的
  `%LocalAppData%\DeltaForceBooster\profiles\`。
之后可 `-Apply -Preset 方案名`；`-DeletePreset 方案名` 删除（内置方案删不掉）。
- 若检测未找到游戏路径，追加 `-GamePath "游戏主程序完整路径"`（主程序通常是
  `DeltaForceClient-Win64-Shipping.exe`；找不到时向用户询问安装位置）。
- 权限不足时脚本会报错并列出需要管理员的项——此时用管理员身份重开终端再执行，
  或让用户以管理员运行。
- 每次 Apply 会先把可还原设置的旧值写入
  `%ProgramData%\DeltaForceBooster\backup\backup-<GUID>.pending.json`：备份使用严格 schema、
  HMAC 完整性校验和原子写前日志，普通用户进程没有写权限；schema v3 同时记录 `ApplyId`、
  项目归属、实际写入值和项目内操作顺序，全部完成后才发布为正式备份。
- 结果里每项带 `Ok`、`Changed`、`Skipped`、`Attention` 字段，末尾有「x 成功、y 失败、z 跳过
  （、n 项体检发现问题）」汇总。`Attention=true` 表示纯检测项查出了真实问题——这是
  检测项「立功」而不是工具失败，转述时务必与失败区分开，别让用户误以为工具坏了；
  失败消息内含 powercfg 等命令的原始报错，直接转述给用户即可。
- **电源计划命名行为**：系统没有可直接激活的卓越性能方案时（e9a42b02 在多数版本上只是
  不可激活的模板），脚本会实例化一份并命名为「三角洲优化 · 卓越性能」，GUID 记在
  图形界面的受保护 per-SID `config\power-scheme.json`（CLI 使用当前用户 `%LocalAppData%`），重复执行只复用不堆积。`-Restore` 会切回原方案但
  **保留**该自建方案（输出的 Notes 字段里有说明，请一并念给用户）。
- 优化后某项仍「未达标」时，让用户以管理员运行只读诊断并回传输出：
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\diagnose.ps1"`。

### 自动寻找最佳配置 Beta（只在图形界面操作）

GUI 提供同一设备内的规则版 A/B 测试：先采集三次稳定基线，再依次测试三个内置、低风险、无需重启且可完整回滚的候选组。它会按平均帧率、1% 低帧率、P99 帧时间、卡顿次数、温度和功耗决定保留或只还原当前候选；样本不足、游戏退出、失去前台、环境变化或基线不稳定时不形成结论。

Agent 只负责向用户解释需要保持同一地图、画质、分辨率和路线，并提示在 GUI 中逐轮确认采样。不要用 CLI 手工模拟实验状态、不要替实验规则挑项目，也不要把 `gpu-name-spoof` 或任何 risky / 需重启项目加入候选。

### 第 4 步：显卡驱动部分（手动，念给用户听）

驱动内 3D 设置无法安全脚本化。把第 1 步返回的 `GpuGuide` 清单展示给用户，
指导其在 NVIDIA 控制面板 / AMD Adrenalin 中手动设置（约 2 分钟）。清单已按显卡厂商
标注了因型号而异的项（DLSS 仅 RTX 系、Preset K 还需 40/50 系、FSR 各家通用、XeSS 为
Intel 优化、低延迟 N 卡走 Reflex / A 卡走 Anti-Lag），转述时先说明检测到的显卡型号
（`Hardware.MainGpuName`，双显卡以独显为准），再给对应厂商的内容。

NVIDIA Profile Inspector 配置导入不再由本工具执行：该操作无法生成可验证的自动还原
备份。需要调整驱动配置时，只展示 `GpuGuide`，由用户在显卡控制面板中手动设置。

### 还原（用户后悔时）

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -ListRestoreItems
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -Restore -RestoreItems dvr-off,hags
powershell -NoProfile -ExecutionPolicy Bypass -File "<root>\scripts\delta-booster.ps1" -Restore
```

`-ListRestoreItems` 返回当前可精确复原项目及冲突状态；`-RestoreItems` 支持单选和多选，
统一恢复到各项目第一次被工具修改前。执行前会确认当前值仍是工具当时写入的值；检测到
用户或其他程序的后续修改时保留当前状态。每个项目内部原子执行，任一子设置失败会写回
本次复原前状态。成功操作通过签名 `restore-receipt-<GUID>.json` 消费，原始 v3 备份不改名。
第一阶段只开放八个无需重启且没有复杂依赖的项目：`game-mode`、`dvr-off`、
`prio-separation`、`net-throttling-off`、`sys-responsiveness`、`mmcss-games`、`fso-off`、
`gpu-pref`；其余项目继续使用全部复原。

不带 `-RestoreItems` 时仍是全部复原：合并所有尚未消费的受保护备份，按签名文档里的创建
时间从新到旧处理，同一目标恢复到最早一次优化前的原值；`-BackupFile` 可指定某个具体备份。
旧版 v2 备份没有可靠项目归属，只支持全部复原，成功后整份标为 `.restored`。
结果字段：`RestoredOps`（还原条数）、`Failed`（真失败，带人话项名）、`Skipped`
（跳过且无实际影响——「继承默认」的电源隐藏项删不掉注册表子键（ACL 只授权 SYSTEM）
且残留在已停用的工具自建方案里时归此类，转述时明确告诉用户这不影响任何生效设置）、
`Notes`（如工具自建电源方案保留的说明）。

## 优化项一览（Id 供 -Items 使用）

所有项分两档：`safe`（下表全部）与 `risky`。**不带 `-Items` 且不指定预设时只执行 safe
档默认项**；risky 档必须显式加 `-Risky` 才会执行。「显卡型号伪装」是唯一由内置
`main` 预设明确包含的 risky 项；直接用 `-Items` 调它时同样必须加 `-Risky`。

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
| mem-compress-off | 关闭内存压缩与页面合并（仅供手动对比，不进入默认、全选或内置方案） | 否 | 需要 |
| transparency-off | 关闭窗口透明特效 | 是 | 否 |
| fso-off | 为游戏禁用全屏优化 | 是 | 否 |
| gpu-pref | 强制游戏用高性能 GPU | 是 | 否 |
| game-priority | 游戏进程 CPU/IO 优先级提到高（IFEO） | 是 | 需要 |
| visualfx-perf | 视觉效果最佳性能 | 否 | 否 |
| mouse-accel-off | 关闭鼠标指针精确度 | 否 | 否 |
| mpo-off | 禁用 MPO 多平面叠加（OverlayTestMode=5，治闪烁） | 是 | 需要 |
| net-throttling-off | 解除多媒体网络限流（NetworkThrottlingIndex=0xffffffff） | 是 | 需要 |
| sys-responsiveness | MMCSS 后台 CPU 保留设为文档允许的最低值 10（SystemResponsiveness） | 是 | 需要 |
| sysmain-off | 禁用 SysMain 预取服务（Start=4） | 否 | 需要 |
| wsearch-off | 禁用 Windows Search 索引（Start=4，搜索会变慢） | 否 | 需要 |
| hibernate-off | 关闭休眠与快速启动（powercfg -h off） | 台式机默认 | 需要 |
| gpu-pstate-lock | 禁止显卡动态降频（DisableDynamicPstate=1，待机功耗升） | 否 | 需要 |
| nv-autoopt-off | NVIDIA App「自动优化游戏设置」只读体检；发现开启时指引用户在 App 内手动关闭，不写用户配置文件 | 否 | 否 |
| gpu-irq-affinity | 显卡中断绑核（DevicePolicy=4 + KAFFINITY 掩码，绑最后一个 P 核） | 否 | 需要 |
| pcie-check | PCIe 链路体检（纯检测，nvidia-smi 读上限） | 否 | 否 |
| dyntick-off | 禁用动态计时器（bcdedit disabledynamictick yes） | 否 | 需要 |
| mmcss-games | MMCSS 游戏任务档位拉满（GPU/IO 调度，收益微弱但零副作用） | 是 | 需要 |
| windowed-opt-off | 关闭「窗口化游戏优化」（复合串只改目标子键） | 否 | 否 |
| vcredist-check | VC++ v14 运行库体检（纯检测，缺失才报问题） | 否 | 否 |
| xmp-check | 内存频率 / XMP·A-XMP·EXPO·DOCP 体检（纯检测） | 否 | 否 |

risky 档（默认不勾；`main` 会选中但仍要求独立确认 / `-Risky`）：

| Id | 作用 | 风险 |
|---|---|---|
| gpu-name-spoof | 显卡型号伪装（`Enum\PCI\VEN_10DE/1002&...\DeviceDesc`）：NVIDIA 笔记本默认并标 ★ GTX 1050 Ti，台式机默认并标 ★ GTX 750 Ti，AMD 默认并标 ★ RX560；GUI 仍可手动选择 GTX 750 Ti、GTX 1050 Ti、RTX 2050、RTX 2060、RX560 | 有实测反例：有人改完帧数不升反降；重装/更新显卡驱动后失效；系统上报型号与真实硬件不一致，反作弊如何对待未知。支持 NVIDIA / AMD，原值完整备份、还原逐字节写回 |

`power-tuning` 涉及的电源项默认被 Windows 隐藏，脚本会先用 `powercfg -attributes`
解除隐藏再写入，原隐藏状态一并进备份；CPU 不支持的项（如非大小核 CPU 的调度策略）
自动跳过而不报错。

## 红线（任何 agent 都必须遵守）

1. **agent 驱动 CLI 不代表用户同意任何声明。** 图形界面首次运行会弹免责声明门控
   （`DISCLAIMER.md`，需滚动到底后确认），这类涉及免责条款的确认**必须由用户本人在
   图形界面完成**，agent 不得代为点击、也不得代写 `config\disclaimer.json` 绕过。
   命令行使用时请先把 `DISCLAIMER.md` 的要点念给用户听。
2. 未经用户明确同意，不得执行 `-Apply` / `-Restore`。
3. 不要绕过脚本自行改注册表——脚本的备份机制是唯一的还原保障。
4. 不修改游戏安装目录内的任何文件（反作弊敏感区，本技能设计上就不碰）。
5. 执行后如实汇报每项成功/失败，并告知备份文件位置与还原方法。
6. 不要代替用户下载或运行任何安装包。工具版本升级走图形界面自带的内置更新
   （官方域名白名单 + SHA256 强制校验，见 `scripts/updater.ps1`），agent 只需
   提示用户点标题栏的「有新版本」入口即可。
