<p align="center">
  <img alt="Delta Force Graphics Optimizer" src="gui/app.ico" width="72">
</p>

<h3 align="center">三角洲行动 · 画面优化助手</h3>

<p align="center">
  把网上那些一步步改设置的帧率教程，做成一次点完、随时能还原
</p>

<p align="center">
  <a href="https://df.ltz88.cn/">下载</a> &bull;
  <a href="DISCLAIMER.md">免责声明</a> &bull;
  <a href="SKILL.md">给 AI 助手用</a> &bull;
  <a href="CONTRIBUTING.md">参与贡献</a> &bull;
  <a href="SECURITY.md">安全</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0A1512" alt="platform">
  <img src="https://img.shields.io/badge/PowerShell-5.1-0A1512" alt="powershell">
  <img src="https://img.shields.io/badge/license-MIT-00E884" alt="license">
  <img src="https://img.shields.io/badge/%E9%9D%9E%E5%AE%98%E6%96%B9%E4%B8%AA%E4%BA%BA%E9%A1%B9%E7%9B%AE-E5C46A" alt="unofficial">
</p>

---

网上那些"手动改 Windows 设置提帧率"的教程，几十个步骤散在各处，改错了还不知道怎么改回去。这个工具把它们整理成可批量执行、**改动前自动备份、随时一键还原**的形式。

工具围绕三件事设计：

- **改得了，也退得回。** 每一项在写入前把原值完整记录下来，包括"这个值原本不存在"这种状态——还原时会删除它而不是写个默认值。哪项没成功会明确报错并带上系统原始错误，不会假装成功。
- **只碰 Windows，不碰游戏。** 改的全是系统层设置（注册表、电源计划、系统服务、启动配置），不进游戏目录、不注入进程、不与反作弊交互。
- **该说的话不藏着。** 每一项都标注了它实际改什么、有什么副作用；效果有争议的项默认不勾选；查出来的硬件问题只提示不代劳。

## 快速开始

到 [下载页](https://df.ltz88.cn/) 拿安装包，双击装好后打开：

1. 工具自动检测硬件、定位游戏、列出每一项的当前状态
2. 默认选中「★ 主推全套」方案，也可以换方案或自己逐项勾
3. 点「执行优化」，改动前自动备份
4. 后悔了点「还原设置」

需要管理员权限——电源计划、HAGS 这些是系统级设置。

## 它做什么

**30 多项系统优化**，按调试链路组织：电源计划深度定制（含 Windows 隐藏项）、进程与 IO 优先级、显卡中断绑核、系统精简、显卡层设置。三套预设方案，也可以存成自己的方案。

**三项硬件体检**，只读不写：PCIe 链路带宽是否跑满、VC++ 运行库版本是否错乱、内存 XMP/EXPO 有没有开。这三样都实打实丢帧，而且软件改不了，只能告诉你去哪儿修。

**游戏内设置参考**：头部主播的画质设置，按游戏里的菜单结构分组，照着能逐项找到。这一页纯参考——工具不会也无法修改游戏内设置。

**驱动层指引**：认出你的显卡型号，只给这张卡用得上的设置，可以直接打开 NVIDIA 控制面板 / NVIDIA App。

## 给 AI 助手用

不想自己点界面，可以让 AI 助手代劳。**把下面这句直接发给你的 agent**：

```
读取 https://raw.githubusercontent.com/Leonard8818/-Delta-Force-Graphics-Optimizer/main/SKILL.md
并按其中的流程帮我优化《三角洲行动》的帧率
```

它会自己完成检测 → 解释每一项在改什么 → **征得你同意** → 执行 → 汇报结果。
[SKILL.md](SKILL.md) 里写明了红线：未经你明确同意不得执行任何改动，也不得代你同意免责声明。

### 已验证可用

| Agent | 说明 |
|---|---|
| [Claude Code](https://claude.com/claude-code) | 也可把仓库放进 `~/.claude/skills/` 注册为常驻技能 |
| [Codex CLI](https://openai.com/codex) | OpenAI 官方命令行 agent |
| [Cursor](https://cursor.com) | 在 Agent 模式下贴上面那句即可 |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Google 官方命令行 agent |
| [OpenCode](https://github.com/sst/opencode) | 开源，可接任意模型 |

国内的豆包电脑版、通义灵码等只要**能在 Windows 上执行 PowerShell**，同样适用——SKILL.md 不依赖任何特定工具的能力。

不带 agent 直接用命令行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Detect
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Apply -Preset main
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\delta-booster.ps1 -Restore
```

## 安装

双击 `DeltaForceBooster-Setup-vX.Y.exe`，图形向导四步走完。安装位置可自选，默认在
「下载」文件夹（无需管理员权限）；选 Program Files 等受保护目录会自动检测并引导提权。

- **装在下载文件夹的提醒**：Windows「存储感知」可能自动清理这里，会连同 `backup\`
  里的系统还原备份一起删掉。长期使用建议在位置页换个目录（向导会提示但不阻止）。
- **覆盖安装保护**：`profiles\`（自存方案）、`backup\`（还原备份）、`config\`（运行状态）
  不会被覆盖。
- 完成页可勾选创建开始菜单/桌面快捷方式与立即运行，卸载时快捷方式一并清理。

## 更新

检测到新版本时标题栏亮起「有新版本」入口（启动查一次，运行期间每 30 分钟静默复查）；
标题栏的「检查更新」可随时手动查一次，立刻给出结果，且无视「不再提醒此版本」的记录。

点「立即更新」后**全程自动**：下载（进度条、可取消）→ 强制校验 SHA256 与文件大小 →
原地安装到当前目录 → 自动打开新版本，中途不需要再操作。下载源锁定官方域名白名单，
任何一步失败都退回「浏览器打开下载页」并明确报错。自动检查只负责提醒，绝不自行下载或安装。

## 下载后脚本被拦怎么办

从网上下载的文件带「来自 Internet」标记，部分机器会拒绝运行未签名 .ps1。三选一：

1. **用 `启动优化工具.exe` 启动**（推荐，不受执行策略限制）；
2. 管理员 PowerShell 里 `Unblock-File -Path .\* -Recurse`；
3. 手动运行时带豁免参数：`powershell -NoProfile -ExecutionPolicy Bypass -File <脚本>`。

## 优化没生效？跑诊断脚本

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\diagnose.ps1
```

打出全部电源方案的原始名与解析名、模板激活自检、隐藏电源项的真实写入自检（写完立即
还原）、所有优化项的当前判定。把完整输出反馈即可定位问题。

## 关于电源计划的命名

系统里没有可直接激活的「卓越性能」方案时，工具用 `powercfg -duplicatescheme` 实例化
一份并命名为**「三角洲优化 · 卓越性能」**（GUID 记在 `config\`，重复执行只复用不堆积）。
「还原设置」会把活动方案切回原来的，但**保留**这份方案（你可能已在用）；不需要就在
控制面板→电源选项里手动删。

## 安全说明

- 改动前所有被修改的注册表值、电源设置和配置文件都备份到 `backup\`，还原按逆序恢复。
- 只改 Windows 系统设置、游戏 exe 的兼容性标记与 NVIDIA App 的自动优化开关，
  **不碰游戏安装目录内任何文件**。
- 不采集、不上传任何数据。两项网络行为：检查更新请求版本清单；「上传诊断报告」需你
  主动点击并确认。
- 内置更新只允许从官方域名（df.ltz88.cn）经 https 下载，下载后强制校验 SHA256 与文件
  大小，任一不符立即删除、绝不执行。局限如实说明：这防的是传输途中被篡改，防不住
  官方服务器本身被攻破（详见 `build/README.md`）。

## 许可与声明

- 本项目以 [MIT 许可证](LICENSE) 开源。
- 非官方个人项目，与腾讯公司及《三角洲行动》官方无任何关联——详见 [NOTICE.md](NOTICE.md)。
- 首次运行需阅读并同意 [DISCLAIMER.md](DISCLAIMER.md)。
- 安全问题请按 [SECURITY.md](SECURITY.md) 的方式报告；参与贡献见 [CONTRIBUTING.md](CONTRIBUTING.md)。
