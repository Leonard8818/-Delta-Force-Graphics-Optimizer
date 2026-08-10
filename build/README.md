# DeltaForceBooster 分发与更新说明

本目录负责两件事：**打 Windows 安装包**、**发布版本更新清单**（配合 v0.11 起的内置更新）。
全部只用系统自带组件（PowerShell + .NET Framework csc），不需要安装任何第三方工具。
v0.3 起弃用 IExpress：它的解压界面不可定制、安装位置只能硬编码，改为 csc 现场编译
`setup-wizard.cs`（WPF 图形安装向导，官网同款三角洲视觉）。
（macOS 不做：三角洲行动没有 macOS 版，本工具改的全是 Windows 注册表/电源计划/系统服务，Mac 上没有对应物。）

## 一、构建安装包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build\make-installer.ps1
```

产出（版本号自动取自 GUI 文件头徽标）：

| 产物 | 用途 |
|---|---|
| `DeltaForceBooster-Setup-vX.Y.Z.exe` | 图形安装向导（单文件，payload 内嵌为程序集资源）：欢迎/安装位置/进度/完成四页；默认安装到 `%ProgramFiles%\DeltaForceBooster`，创建开始菜单与桌面入口并可立即运行 |
| `update-manifest.json` | 更新清单：`sha256`/`size` 由构建脚本从本次 Setup.exe 现算，`version` 取自 GUI 的 `$script:GuiVersion`（构建期与界面徽标交叉校验，不一致直接构建失败），`notes` 由构建脚本中的本版公开说明生成 |

**只发安装版**：绿色免安装 zip 已于 v0.15 停产（服务器上的下载入口也已移除）。
payload 随包分发 `LICENSE`（MIT 要求保留版权声明，非可选）、`NOTICE.md`、
`DISCLAIMER.md`（免责声明门控要读它）；`SECURITY.md`/`CONTRIBUTING.md` 只留在仓库。

设计要点：

- **安装位置**：默认 `%ProgramFiles%\DeltaForceBooster`。交互安装拒绝普通用户可写的程序目录；
  静默更新遇到下载文件夹等旧版可写目录时，会把程序迁到 Program Files 并登记旧根，
  旧入口停用，避免管理员进程加载普通进程可替换的脚本。
- 安装器和启动器清单都是 `asInvoker`。主界面保持普通权限，只有具体系统操作、还原和
  更新安装才启动短生命周期 UAC helper；启动器还会校验 GUI、引擎、更新器、遥测模块、
  自动调优规则模块和 PresentMon 的构建时 SHA256。
- 用户配置、自存方案和实验状态位于 `%LocalAppData%\DeltaForceBooster`；受保护备份位于
  `%ProgramData%\DeltaForceBooster\backup`，不再和程序文件混放。
- 覆盖安装采用同卷 staging → 完整 payload 哈希核对 → 目录事务切换；中断或失败时恢复
  rollback，未知的非空目标目录没有产品身份文件时原样拒绝，不会整目录替换。
- 卸载目标以 `uninstall.ps1` 自身所在目录为准（位置可自选后不能再假定 LOCALAPPDATA）；
  默认**保留 backup 目录**——那是撤销系统改动的唯一凭据；用户明确选「否」才全删。
- 自动化验证参数（普通用户双击即图形向导，无需了解）：
  `/silent /dir=<路径> /log=<文件>` 静默安装（可加 `/waitpid=<进程Id>` 先等旧进程退出、
  `/runafter` 装完自启新版；内置更新还会成对传 `/sha256=<64位哈希> /size=<字节数>`，
  安装器启动后与受保护 staging 的完整性 sidecar 交叉复验）；`/checkdir=<路径> /log=<文件>` 只跑权限
  预检（退出码 0 可安装 / 2 需管理员 / 3 无效）；`/render=<目录>` 离屏渲染各页为 PNG 并
  导出界面字符串。`DFB_TEST_*` 测试钩子只存在于显式 `-TestBuild` 产物，生产安装器会做
  静态扫描确认没有这些入口。卸载脚本仍认 `DFB_INSTALL_SILENT=1`（不弹框、保留备份）。
- **快捷方式落点**（真机踩过「装完找不到入口」）：提权安装（右键管理员运行，或选
  Program Files 触发提权重启）时 `%APPDATA%` 指向提权账号，多账户机器上快捷方式会
  建进管理员的开始菜单——所以提权态一律写公共开始菜单/公共桌面（所有用户可见）；
  非提权态写当前用户。卸载脚本把用户/公共两处落点都清理。

## 二、两个必须知道的现实问题（别指望能绕过）

1. **SmartScreen「未知发布者」警告。** Setup.exe 没有代码签名证书，用户首次运行时
   Windows SmartScreen 会弹蓝色拦截页，必须点「更多信息 → 仍要运行」才能继续。
   要消除它只有一条路：买代码签名证书（EV 证书立即生效，普通证书要积累信誉）。
   分发时应在下载页明确写出这个警告长什么样，否则大量用户会以为是病毒直接关掉。

2. **杀毒软件误报是常态。** 本工具的行为模式——改注册表、禁用系统服务（SysMain/
   Windows Search）、动 bcdedit/powercfg、创建计划任务——和恶意软件高度重叠，
   Windows Defender / 火绒 / 360 都可能报毒甚至直接隔离。这是行为使然，换打包方式
   也躲不掉。能做的：让用户自行添加白名单/信任区；分发页放 VirusTotal 扫描链接
   自证；所有源码可读（.ps1 明文），有疑虑的用户可以自己审。**不要**为了压误报去
   混淆代码——只会更像病毒。

## 三、维护者备忘（踩过的坑）

- **不能用 `WScript.Shell` 创建快捷方式或弹窗**：它按系统 ANSI 代码页转字符串，
  系统区域设置非中文（ACP=1252，本机就是）时中文全变 `?`，快捷方式直接保存失败。
  快捷方式走 `IShellLinkW` COM 接口（原生 Unicode），弹窗走 WPF/WinForms `MessageBox`。
- `setup-wizard.cs` 必须 **UTF-8 带 BOM** 保存，构建脚本编译时再加 `/codepage:65001`
  双保险——csc 默认按当前代码页（1252）读源文件，中文字符串会在编译期被打碎。
  编译产物的中文是否完好，用 `/render=` 导出的 `strings.txt` 与页面 PNG 实测核对。
- csc 的默认应答文件（csc.rsp）已引用 `System.Windows.Forms.dll`，`/r:` 再给一遍
  GAC 路径会报 CS1703 重复引用；WPF（PresentationFramework 等）与 System.IO.Compression
  不在 Framework 目录里，要用 `LoadWithPartialName` 从 GAC 解析真实路径后传 `/r:`。
- `卸载.bat` 里「运行 + exit」必须写在**同一行**：卸载会删掉 bat 自身，而 cmd 逐行
  回读批处理文件，分行写会在删除后打出「找不到批处理文件」并返回退出码 1。
- 构建脚本必须用 **Windows PowerShell 5.1** 跑（不能用 pwsh 7）：pwsh 7 解析出的
  压缩程序集是 .NET Core 版路径，喂给 Framework csc 会炸；Compress-Archive 的
  反斜杠条目分隔符行为也按 5.1 处理（安装器解包时两种分隔符都认）。
- 中间产物放 `%TEMP%` 的 ASCII 路径构建，成品再移回 build\（仓库路径含「桌面」，
  非中文代码页下命令行工具处理中文路径容易翻车）。

## 四、发布版本更新（配合内置更新）

界面启动时**异步**拉取 JSON 清单并和本地版本比对，此后运行期间每 30 分钟静默复查一次
（GUI 常量 `$script:UpdateCheckIntervalMinutes`）；发现新版本点亮标题栏「有新版本」入口。
v0.11 起更新详情框支持「立即更新」：应用内下载安装包（进度条、可取消）→ 强制校验
SHA256 与文件大小 → 提权 helper 复验并复制到受保护 staging → 关闭程序并启动安装器再次复验。
**下载与安装必须由用户点击触发**，
自动检查只负责提醒，永不静默安装。

内置下载的硬约束（实现于 `scripts\updater.ps1`，一条都不能省）：

- **域名白名单硬编码**在 `$script:BoosterDownloadHosts`（当前只有 `df.ltz88.cn`）：
  `setupUrl` 必须是 https 且主机在白名单内，否则拒绝下载并落日志。清单文件本身可能
  被篡改，**绝不信任清单里的任意 URL**——没有这道闸，攻击者改一行 JSON 就能把用户
  导去恶意地址。
- 清单缺 `sha256` 或 `size`（或值不合法）时视为不可信，界面自动退化为
  「仅提示 + 浏览器打开下载页」的旧行为；下载完成后哈希或大小任一不符，
  立即删除临时文件并报错。普通权限下载使用 LocalAppData 下随机 `CreateNew` 文件并保持
  句柄约束，管理员 helper 再从句柄复验并复制到仅 Administrators/SYSTEM 可写的
  `%ProgramData%\DeltaForceBooster-UpdateStaging`；安装器启动后仍会按参数与 sidecar 复验，
  避免“校验后被同权限进程替换”的窗口。
- **如实告知局限（别粉饰）**：SHA256 校验防的是*传输途中*被篡改（中间人、镜像污染）。
  清单和安装包放在同一台服务器上，**服务器本身被攻破时攻击者可以同时替换两者并配好
  哈希，这套校验完全失效**。真正能防这种情况的是代码签名证书（私钥不在服务器上），
  本项目目前没有证书，所以服务器的安全就是更新链路的安全上限——SSH 键值登录、
  最小化暴露面，比在客户端加花样更有用。

清单格式（`update-manifest.json`，UTF-8 无 BOM，构建脚本自动生成）：

```json
{
  "version": "0.20.1",
  "minimumSupportedVersion": "0.20.1",
  "notes": "修复旧安装目录更新时误判缺少新版本文件的问题。\n旧版配置、方案与备份继续保留迁移。",
  "url": "https://df.ltz88.cn/",
  "setupUrl": "https://df.ltz88.cn/DeltaForceBooster-Setup.exe",
  "sha256": "（安装包的 SHA256，小写十六进制，构建脚本自动填）",
  "size": 137728
}
```

发布流程（GitHub、更新服务器、官网三处同步，缺一不算发布完成）：

1. 改完代码，把 `gui\DeltaForceBooster-GUI.ps1` 的版本徽标升号，跑本目录构建脚本出包。
   构建结束会自动生成 `build\update-manifest.json`，`sha256`/`size` 已按本次 Setup.exe
   算好——**不要手工改这两个字段**，改了客户端必然校验失败。
2. 上传到发布服务器（Caddy 站点 `df.ltz88.cn`，托管目录 `/opt/df-booster`）：
   Setup.exe 覆盖为 `DeltaForceBooster-Setup.exe`（无版本号固定名，`setupUrl` 才能不变），
   清单覆盖 `update-manifest.json`。**先传安装包、后传清单**——反过来会有一段时间窗口，
   老客户端按新清单校验旧安装包，全部失败。
3. 在 `website/index.html` 的「更新记录」中新增本版内容并上传，确认官网显示的新版本号、
   更新内容和下载入口都正确。
4. 提交并推送 GitHub `main`，创建同版本 GitHub Release 并上传带版本号安装包；随后从公网复核官网、安装包、更新清单，并校验安装包大小与
   SHA256。任一目标未完成时必须明确记录阻塞原因，不能宣称发布完成。
5. 版本号比较是语义化的（`0.10.0` > `0.9.0`），清单里带不带 `v` 前缀都行。
   若换下载域名，必须同步改 `scripts\updater.ps1` 的白名单常量再出包，否则老客户端拒绝下载。

更新检查的全部失败路径（断网、超时、清单格式坏）都静默吞掉，不会影响主程序；
「不再提醒此版本」记录在 `%LocalAppData%\DeltaForceBooster\config\updater.json`，定时复查同样跳过该版本；低于 `minimumSupportedVersion` 时不提供跳过或稍后入口。
**一键静默更新（v0.15）**：用户点「立即更新」即为授权，校验通过后主程序直接以
`/silent /dir=<当前程序目录> /waitpid=<主程序PID> /runafter /log=<文件> /sha256=<哈希> /size=<字节数>` 拉起安装器
并自退——安装器等旧进程退出后覆盖文件、装完自启新版，用户不必再走一遍向导。
安全的 Program Files 安装执行原地事务更新；旧版普通用户可写目录会迁往默认 Program Files。
安装失败时安装器弹框报错并指向下载页（主程序此刻已退出，不弹就等于静默失败）。
主窗口图标用 `BitmapCacheOption.OnLoad` 读入内存后立即释放 `gui\app.ico`；安装器同时会在
覆盖前礼貌关闭其他旧窗口，并对杀毒/索引器造成的短暂文件共享冲突重试约 3 秒。
沙箱验证钩子 `DFB_TEST_NOLAUNCH=1` 让 `/runafter` 只记日志、不真的拉起主程序。
