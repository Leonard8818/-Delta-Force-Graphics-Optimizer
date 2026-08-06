# DeltaForceBooster — 三角洲行动一键画面优化 v0.3

抖音教程里那些一步步改电脑设置的帧率优化，这个工具一键做完：
检测你的硬件 → 勾选优化项 → 一键应用（自动备份）→ 随时一键还原。

## 普通用户：图形界面

双击 **`启动优化工具.bat`**（会请求管理员权限，属正常——电源计划和 HAGS 是系统级设置）。
界面会显示你的 CPU/显卡/内存、自动找到的游戏路径、每个优化项的当前状态，
勾选后点「一键优化」即可；「还原上次优化」可完整回退。

## AI 助手：通用技能

把整个文件夹发给/指给任意 AI 助手（Claude Code、Codex、WorkBuddy、豆包电脑版等），
让它阅读 `SKILL.md` 按流程执行。Claude Code 用户可把本文件夹复制到
`~/.claude/skills/delta-force-boost/` 注册为正式技能。

命令行直接用：

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Detect
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Apply
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Restore
```

## 预设方案

不想逐项勾选就直接套方案（`-ListPresets` 可查看）：

| 方案 | 内容 | 适合 |
|---|---|---|
| `felix` 费利克斯路线（主推） | 25 项全套，按费利克斯Fx 的调试顺序：电源深度定制→进程/IO 优先级→中断绑核→系统精简→显卡驱动层。代价：鼠标手感变直、休眠/快速启动没了、系统搜索变慢、待机功耗升高 | 愿意按博主整套抄作业的人 |
| `balanced` 均衡推荐 | 15 项，收益明确、副作用小：不改桌面外观和鼠标手感、不禁用服务、不动休眠 | 绝大多数人 |
| `safe-only` 保守 | 6 项，只改当前用户设置、不碰系统全局、不需重启 | 公司电脑或不想动系统 |

也可以把自己的搭配存成方案：`-SavePreset "我的方案" -Items dvr-off,wer-off`，
存在 `profiles\` 目录里，之后 `-Apply -Preset 我的方案` 直接套用。

## 优化内容

Windows 层（可自动，共 28 项，按费利克斯Fx 的调试链路组织）：

- **① 电源**：卓越性能计划、隐藏项深度调优（USB3 链路省电关闭、处理器性能时间检查间隔
  拉到 5000ms、大小核调度强制走高性能核、关电源节流）、锁定电源计划防游戏篡改
- **② 调度/优先级**：Win32PrioritySeparation=40、游戏进程 CPU/IO 优先级提到「高」、
  MMCSS 系统响应度=0、解除多媒体网络限流、内核代码常驻内存
- **③ 中断绑核**：独显中断固定到最后一个 P 核（避开 CPU0，微软官方 Affinity Policy
  注册表机制，不依赖第三方工具；读不到核拓扑时自动不可用）
- **④ 系统精简**：关 Xbox 录制、关错误报告、关透明特效、关内存压缩（32G 以上才默认）、
  禁用 MPO 多平面叠加、禁用 SysMain/Windows Search 服务、关休眠与快速启动、
  禁用动态计时器（bcdedit）
- **⑤ 显卡层**：HAGS、为游戏禁用全屏优化、强制独显运行、禁止显卡动态降频（锁 P-State）
- **纯检测**：PCIe 通道体检——读出独显链路上限，插错槽/劣质延长线导致的 x8/x4 直接报警
- 可选不默认（副作用大，须明确知情）：视觉效果最佳性能、关闭鼠标指针精确度、
  关闭引导虚拟化（WSL/模拟器会失效）、虚拟内存固定为内存×1.5~×2（仅闪退时用）

显卡驱动层（半自动）：按你的显卡（N 卡/A 卡/Intel）生成精确的手动设置清单。
`tools\` 已附带按费利克斯参数生成的 `DeltaForce-Felix.nip`（最高性能/超低延迟超高/
垂直同步关/预渲染 1/着色器缓存无限制/线程优化开/DLSS Preset K）；再把 NVIDIA Profile
Inspector 放进 `tools\` 即可一键导入——导入前请先在 Inspector 里导出备份当前配置。

## 安全说明

- 每次优化前，所有被改动的注册表值和电源计划都会备份到 `backup\`，还原按备份逆序恢复。
- 只改 Windows 系统设置与游戏 exe 的兼容性标记，**不碰游戏安装目录内任何文件**，无反作弊风险。
- 不采集、不上传任何数据，全部本地运行。
