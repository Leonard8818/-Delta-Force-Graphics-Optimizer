# DeltaForceBooster 分发与更新说明

本目录负责两件事：**打 Windows 安装包**、**发布版本更新清单**（配合内置更新提醒）。
全部只用系统自带组件（PowerShell + IExpress），不需要安装任何第三方工具。
（macOS 不做：三角洲行动没有 macOS 版，本工具改的全是 Windows 注册表/电源计划/系统服务，Mac 上没有对应物。）

## 一、构建安装包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build\make-installer.ps1
```

产出两个文件（版本号自动取自 GUI 文件头徽标）：

| 产物 | 用途 |
|---|---|
| `DeltaForceBooster-Setup-vX.Y.exe` | 双击安装：解包到 `%LOCALAPPDATA%\DeltaForceBooster`，开始菜单创建「三角洲行动优化助手」「卸载优化助手」两个快捷方式 |
| `DeltaForceBooster-Portable-vX.Y.zip` | 绿色版：解压到任意目录，双击「启动优化工具.bat」即用 |

设计要点：

- **安装不需要管理员**（只写用户目录）；程序**运行时**自己弹 UAC 提权（优化要改 HKLM/电源计划）。
- 覆盖安装时 `profiles\` 里用户自存的方案**不会被覆盖**，`backup\`（系统还原凭据）完全不动。
- 卸载时默认**保留 backup 目录**——那是撤销系统改动的唯一凭据；用户明确选「否」才全删。
- 安装过程日志写在 `%TEMP%\dfb-install-log.txt`，装不上时先看它。
- 环境变量 `DFB_INSTALL_SILENT=1` 可让安装/卸载全程不弹框（自动化测试用）。

## 二、两个必须知道的现实问题（别指望能绕过）

1. **SmartScreen「未知发布者」警告。** Setup.exe 没有代码签名证书，用户首次运行时
   Windows SmartScreen 会弹蓝色拦截页，必须点「更多信息 → 仍要运行」才能继续。
   要消除它只有两条路：买代码签名证书（EV 证书立即生效，普通证书要积累信誉），
   或者引导用户用绿色版 zip（zip 内的 .bat/.ps1 不触发 SmartScreen 拦截页，但首次
   运行仍可能有「不常下载」提示）。分发时应在下载页明确写出这个警告长什么样，
   否则大量用户会以为是病毒直接关掉。

2. **杀毒软件误报是常态。** 本工具的行为模式——改注册表、禁用系统服务（SysMain/
   Windows Search）、动 bcdedit/powercfg、创建计划任务——和恶意软件高度重叠，
   Windows Defender / 火绒 / 360 都可能报毒甚至直接隔离。这是行为使然，换打包方式
   也躲不掉。能做的：让用户自行添加白名单/信任区；分发页放 VirusTotal 扫描链接
   自证；所有源码可读（.ps1 明文），有疑虑的用户可以自己审。**不要**为了压误报去
   混淆代码——只会更像病毒。

## 三、维护者备忘（踩过的坑）

- SED 里 `AppLaunched` 必须**直接写 `install.cmd`**。写成 `cmd /c install.cmd` 时
  wextract 会静默跳过安装命令（本机 Win11 26200 实测复现，构建正常、运行退出码 0、
  什么都没发生）。
- 调 `iexpress.exe /N <sed>` 时**不要给路径手动加引号**，收到带引号路径会静默退回
  向导界面把构建吊死。
- 安装脚本里**不能用 `WScript.Shell` 创建快捷方式或弹窗**：它按系统 ANSI 代码页转
  字符串，系统区域设置非中文（ACP=1252，本机就是）时中文全变 `?`，快捷方式直接
  保存失败。快捷方式走 `IShellLinkW` COM 接口（原生 Unicode），弹窗走 WinForms
  `MessageBox`。
- SED 文件与 install.cmd 保持 ASCII 内容；中间产物放 `%TEMP%` 的 ASCII 路径构建，
  成品再移回 build\（仓库路径含「桌面」，非中文代码页下 IExpress 处理不了）。

## 四、发布版本更新（配合内置更新提醒）

界面启动后会**异步**拉取一个 JSON 清单并和本地版本比对，发现新版本才弹提醒框。
提醒框只提供「前往下载」（浏览器打开下载页，且只放行 http/https 链接）和「稍后再说」
「不再提醒此版本」，**永远不会自动下载或自动执行任何东西**——自动更新就是供应链
攻击入口，这是刻意不做的功能，不要加。

清单格式（`update-manifest.json`，UTF-8）：

```json
{
  "version": "0.7.0",
  "notes": "1. 新增 XX 优化项\n2. 修复 YY 问题",
  "url": "https://github.com/Leonard8818/DeltaForceBooster/releases"
}
```

发布流程：

1. 改完代码，把 `gui\DeltaForceBooster-GUI.ps1` 的版本徽标升号，跑本目录构建脚本出包。
2. 写好 `update-manifest.json`（`version` 填新版本号，`url` 填下载页地址）。
3. 二选一：
   - **GitHub Releases**：建一个新 Release，把 Setup.exe / Portable.zip / update-manifest.json
     都作为 Release 资产上传。清单默认地址
     `https://github.com/Leonard8818/DeltaForceBooster/releases/latest/download/update-manifest.json`
     永远指向最新 Release 的清单，老版本客户端自动看得到新版本。
   - **自有服务器**：把清单放到固定 URL（如 `https://flowai.ltz88.cn/dfbooster/update-manifest.json`），
     并把 `scripts\updater.ps1` 顶部的 `$script:BoosterManifestUrl` 常量改成该地址后再出包。
4. 版本号比较是语义化的（`0.10.0` > `0.9.0`），清单里带不带 `v` 前缀都行。

更新检查的全部失败路径（断网、超时、清单格式坏）都静默吞掉，不会影响主程序；
「不再提醒此版本」记录在工具根目录 `config\updater.json`。
