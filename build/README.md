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
| `DeltaForceBooster-Setup-vX.Y.Z.exe` | 图形安装向导（单文件，payload 内嵌为程序集资源）：欢迎/安装位置/进度/完成四页；默认安装到 `%ProgramFiles%\DeltaForceBooster`，也支持其他本地固定 NTFS 盘，创建开始菜单与桌面入口并可立即运行 |
| `update-manifest.json` | 更新清单：`sha256`/`size` 由构建脚本从本次 Setup.exe 现算，`version` 取自 GUI 的 `$script:GuiVersion`（构建期与界面徽标交叉校验，不一致直接构建失败），`notes` 由构建脚本中的本版公开说明生成 |

**只发安装版**：绿色免安装 zip 已于 v0.15 停产（服务器上的下载入口也已移除）。
payload 随包分发 `LICENSE`（MIT 要求保留版权声明，非可选）、`NOTICE.md`、
`DISCLAIMER.md`（免责声明门控要读它）；`SECURITY.md`/`CONTRIBUTING.md` 只留在仓库。

设计要点：

- **安装位置**：默认 `%ProgramFiles%\DeltaForceBooster`，该布局不变。其他本地固定 NTFS 盘
  只允许选择卷根一级目录：界面中的 `D:\DeltaForceBooster` 是永不改名/删除的 permanent
  anchor，实际代码位于 `D:\DeltaForceBooster\app`。anchor 关闭 ACL 继承，权限恰好为
  Administrators/SYSTEM 完全控制、Users 只读执行，并设置可继承 High MIC NoWriteUp；
  `anchor.identity` 绑定该布局。安装器拒绝 UNC、可移动/网络盘、非 NTFS、卷根本身、任意
  中间父目录、reparse point、危险卷根 DeleteChild/WRITE_DAC/WRITE_OWNER 以及未通过 marker/
  ACL/MIC 复验的既有同名目录。
  静默更新遇到下载文件夹等旧版可写目录时，会把程序迁到默认受保护目录并登记旧根，
  旧入口停用，避免管理员进程加载普通进程可替换的脚本。
- 安装器和启动器清单是 `asInvoker`；自有 `EngineHost.exe` 使用 `requireAdministrator`。
  启动器在 UAC 前完成完整性校验和单实例拦截，只对 EngineHost 请求一次管理员确认；
  EngineHost 在整个 GUI 生命周期保持提升，优化、还原、Beta 和更新不再各自重复请求 UAC。
- 用户配置、自存方案和实验状态位于受保护的 `%ProgramData%\DeltaForceBooster\users\<SID>`；
  受保护备份位于 `%ProgramData%\DeltaForceBooster\backup`。UAC 使用另一管理员账户时，
  原用户 SID/LocalAppData 由全生命周期低权限启动器经认证管道提供；旧 LocalAppData 数据
  只由该低权限端按 JSON 白名单读取并导入，提权 GUI 不日常读写用户可控目录。
- 覆盖安装采用同卷 staging → 完整 payload 哈希核对 → 目录事务切换；Program Files 沿用
  同级事务目录，其他盘的 `.app.dfb-stage-*`/`.app.dfb-rollback-*` 全部位于 permanent
  anchor 内，anchor 自身绝不参与切换。中断或失败时恢复 rollback，未知的非空目标目录
  没有产品身份文件时原样拒绝，不会整目录替换。
- `卸载.exe` 保留原交互用户普通令牌，只对带 `requireAdministrator` 清单和产品版本资源的
  `UninstallHost.exe` 请求一次 UAC；Host 将哈希绑定的 `uninstall.ps1` 复制到受保护
  ProgramData，以 System32 为工作目录等待卸载入口/Host 退出后再删除安装根，因此 UAC
  显示软件卸载助手而非 Windows PowerShell，也不会由自身工作目录或映像锁住待删除目录。
  普通卸载**始终保留** `%ProgramData%\DeltaForceBooster\backup`——它可能同时包含多个
  Windows 用户撤销系统改动的唯一凭据。还原成功、失败或跳过还原均省略删除选项；
  重装后仍可点击「还原设置」继续读取。其他盘卸载会再次复验卷根、anchor marker、ACL、
  MIC 与 app 身份，只删除已验证的 app/完整事务项；永久 anchor、`anchor.identity` 和未知
  sibling 原样保留，之后可在同一受保护位置重装。
- 自动化验证参数（普通用户双击即图形向导，无需了解）：
  `/silent /dir=<路径> /log=<文件>` 静默安装（可加 `/waitpid=<EngineHost进程Id>` 与
  `/waitpid2=<启动器进程Id>`、`/waitpid3=<high GUI进程Id>` 依次等待整段旧会话退出、
  `/runafter` 切换文件后自启新版，并在出现可交互 WPF 窗口前保留旧版本；启动失败会原子恢复旧树；
  内置更新还会成对传 `/sha256=<64位哈希> /size=<字节数>`，
  安装器启动后与受保护 staging 的完整性 sidecar 交叉复验）；`/checkdir=<路径> /log=<文件>` 只跑权限
  预检（退出码 0 可安装 / 2 需管理员 / 3 无效）；`/render=<目录>` 离屏渲染各页为 PNG 并
  导出界面字符串。`DFB_TEST_*` 测试钩子只存在于显式 `-TestBuild` 产物，生产安装器会做
  静态扫描确认没有这些入口。卸载没有静默清理恢复数据的入口，普通卸载始终保留受保护备份。
- **快捷方式落点**（真机踩过「装完找不到入口」）：提权安装（右键管理员运行，或选
  Program Files 触发提权重启）时 `%APPDATA%` 指向提权账号，多账户机器上快捷方式会
  建进管理员的开始菜单——所以提权态一律写公共开始菜单/公共桌面（所有用户可见）；
  非提权态写当前用户。卸载时 per-user 快捷方式由原用户令牌入口清理，high 脚本只清公共落点，
  使用另一管理员凭据时不会误删批准账户的开始菜单或桌面。

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
  立即删除临时文件并报错。正常 GUI 已处于 EngineHost 管理员会话，下载直接落到仅
  Administrators/SYSTEM 可写的 `%ProgramData%\DeltaForceBooster-UpdateStaging`；兼容入口
  只允许继承现有 high token 的 helper 复验，不再通过 PowerShell 单独触发 UAC。安装器仍会按参数与 sidecar 复验，
  避免“校验后被同权限进程替换”的窗口。
- **如实告知局限（别粉饰）**：SHA256 校验防的是*传输途中*被篡改（中间人、镜像污染）。
  清单和安装包放在同一台服务器上，**服务器本身被攻破时攻击者可以同时替换两者并配好
  哈希，这套校验完全失效**。真正能防这种情况的是代码签名证书（私钥不在服务器上），
  本项目目前没有证书，所以服务器的安全就是更新链路的安全上限——SSH 键值登录、
  最小化暴露面，比在客户端加花样更有用。

清单格式（`update-manifest.json`，UTF-8 无 BOM，构建脚本自动生成）：

```json
{
  "version": "0.22.4",
  "minimumSupportedVersion": "0.22.3",
  "notes": "- 新增「通知中心」，支持新通知实时提醒、未读角标和历史消息查看。",
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
3. 在私有官网部署工作区更新「更新记录」并上传，确认官网显示的新版本号、更新内容和下载入口都正确。
4. 提交并推送 GitHub `main`，创建同版本 GitHub Release 并上传带版本号安装包；随后从公网复核官网、安装包、更新清单，并校验安装包大小与
   SHA256。任一目标未完成时必须明确记录阻塞原因，不能宣称发布完成。
5. 版本号比较是语义化的（`0.10.0` > `0.9.0`），清单里带不带 `v` 前缀都行。
   若换下载域名，必须同步改 `scripts\updater.ps1` 的白名单常量再出包，否则老客户端拒绝下载。

更新检查的全部失败路径（断网、超时、清单格式坏）都静默吞掉，不会影响主程序；
「不再提醒此版本」记录在受保护的 per-SID `config\updater.json`，定时复查同样跳过该版本；低于 `minimumSupportedVersion` 时不提供跳过或稍后入口。
**一键静默更新（v0.15）**：用户点「立即更新」即为授权，校验通过后主程序直接以
`/silent /dir=<当前物理 app 目录> /waitpid=<EngineHost PID> /waitpid2=<启动器 PID> /waitpid3=<high GUI PID> /runafter /log=<文件> /sha256=<哈希> /size=<字节数>` 拉起安装器
并自退——安装器等管理员宿主、全生命周期启动器和 GUI 都退出后才覆盖文件；只有 UAC 审批账户
与原登录用户相同时才传 `/runafter`，使用另一管理员凭据时会提示原用户安装后手动打开，避免新版
以批准管理员身份启动。
Program Files 继续原地事务更新；其他盘会把 `...\anchor\app` 规范化回既有 anchor，并仅在
anchor 内切换 app；旧版普通用户可写目录迁往默认受保护目录。
安装失败或新版未出现可交互窗口时，安装器先恢复尚未提交的旧版本，再弹框报错并指向下载页
（主程序此刻已退出，不弹就等于静默失败）。如果安装器在启动验证阶段被中断，下一次安装会先
识别 `.dfb-pending-*` 并恢复旧树，避免把未验证版本误当成已完成更新。
主窗口图标用 `BitmapCacheOption.OnLoad` 读入内存后立即释放 `gui\app.ico`；安装器同时会在
覆盖前礼貌关闭其他旧窗口，并对杀毒/索引器造成的短暂文件共享冲突重试约 3 秒。
沙箱验证钩子 `DFB_TEST_NOLAUNCH=1` 让 `/runafter` 只记日志、不真的拉起主程序；
`DFB_TEST_STARTUP_HEALTH_FAIL=1` 用于验证“文件已切换但新版未就绪”时的自动回滚。
