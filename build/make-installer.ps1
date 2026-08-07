<#
  DeltaForceBooster 安装包构建脚本 — v0.6
  只用系统自带组件（Compress-Archive + .NET Framework csc），零第三方依赖，只产出一个东西：
    build\DeltaForceBooster-Setup-vX.Y.exe —— 图形安装向导（WPF，三角洲官网视觉）：
      欢迎/自选安装位置/进度/完成四页，payload.zip 以 /resource: 内嵌，真正单文件

  v0.6：不再产出绿色免安装版（用户决定只发安装版）；payload 里加入 DISCLAIMER.md——
        免责声明门控要读它，不随包分发的话装完就只剩内嵌兜底文本了。
  v0.5：构建完成后自动生成 build\update-manifest.json 清单模板（sha256/size 现算）——
        内置更新强制校验哈希，手工算迟早算错一次。

  用法：powershell -NoProfile -ExecutionPolicy Bypass -File build\make-installer.ps1
        （必须用 Windows PowerShell 5.1：WPF 程序集定位和 Compress-Archive 行为按 5.1 处理）

  发布须知（写给分发者，别粉饰）：
    1) 没有代码签名证书，Windows SmartScreen 会对 Setup.exe 弹「未知发布者」拦截页，
       用户需点「更多信息 → 仍要运行」。安装向导欢迎页也如实写了这一条。
    2) 本工具改注册表、禁系统服务，杀毒软件误报是常态，可能直接被隔离。
       两条的详细说明见 build\README.md。
#>
#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root  = Split-Path -Parent $PSScriptRoot
$build = $PSScriptRoot

# 版本号以 GUI 文件头部徽标为准，构建产物文件名跟着走
$guiText = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'), [Text.Encoding]::UTF8)
if ($guiText -notmatch '\[ v([\d.]+) \]') { throw '无法从 GUI 文件解析版本号' }
$ver  = $Matches[1]
$ver4 = "$ver.0.0"

# 中间产物放 ASCII 路径的临时目录：仓库路径含「桌面」，非中文代码页（本机 ACP=1252）下
# 命令行工具处理中文路径容易翻车，成品最后再移回 build\
$work  = Join-Path $env:TEMP "dfb-build-$PID"
$stage = Join-Path $work 'stage'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

# ---------- 1. 收集要分发的文件 ----------
# exe 启动器是主入口，缺了先现场编译一份（只依赖系统自带 csc）
$launcher = Join-Path $root '启动优化工具.exe'
if (-not (Test-Path -LiteralPath $launcher)) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make-launcher.ps1')
  if (-not (Test-Path -LiteralPath $launcher)) { throw '启动器 exe 缺失且现场编译失败，先运行 build\make-launcher.ps1 排查' }
}
# backup\ 是本机改动记录、build\ 是构建目录、config\ 是运行期状态，都不进包；
# profiles\ 里的预设随包分发；.bat 保留为后备入口
# LICENSE 必须随包分发：MIT 要求保留版权声明，这不是可选项。
# DISCLAIMER.md 是免责声明门控的正文来源，NOTICE.md 是非官方声明与出处。
# SECURITY.md / CONTRIBUTING.md 是给仓库看的，不进安装包。
$parts = @('启动优化工具.exe', '启动优化工具.bat', 'README.md', 'SKILL.md',
           'DISCLAIMER.md', 'LICENSE', 'NOTICE.md',
           'scripts', 'gui', 'tools', 'profiles', 'data')
foreach ($p in $parts) {
  $src = Join-Path $root $p
  if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $stage -Recurse }
}

# 卸载脚本随包落到安装目录。
# 安装位置从 v0.3 起可自选，卸载目标以脚本自身所在目录为准，不再假定 %LOCALAPPDATA%。
# 全程不用 WScript.Shell：它按系统 ANSI 代码页转字符串，非中文代码页（如 1252）的系统上
# 中文全变 "?"。消息框走 .NET WinForms（原生 Unicode）。
$uninstallPs = @'
# DeltaForceBooster 卸载：删快捷方式（开始菜单/桌面，含提权安装写入的公共位置）+
# 安装目录；backup\ 是系统还原凭据，默认保留
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
# 安装位置可自选，以脚本自身所在目录为卸载目标
$dest = Split-Path -Parent $MyInvocation.MyCommand.Path
# 安装器行为：非提权装用户开始菜单，提权装公共开始菜单——卸载把两处都兜住；
# 桌面快捷方式同理（DFB_TEST_DESKTOP 是沙箱验证的重定向钩子，与安装器一致）
$menuDirs = @(
  (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\DeltaForceBooster'),
  (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\DeltaForceBooster'))
$deskDirs = @($env:DFB_TEST_DESKTOP,
  [Environment]::GetFolderPath('DesktopDirectory'),
  [Environment]::GetFolderPath('CommonDesktopDirectory')) | Where-Object { $_ }
# 脚本被单独拷到别处运行时绝不能误删所在目录：认准引擎文件才动手
if (-not (Test-Path (Join-Path $dest 'scripts\delta-booster.ps1'))) {
  [Windows.Forms.MessageBox]::Show('未在本目录找到优化工具，卸载已取消。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 1
}
# DFB_INSTALL_SILENT=1 供自动化验证：不弹框、按「保留备份」的安全默认走
$silent = ($env:DFB_INSTALL_SILENT -eq '1')
$keep = $true
if (-not $silent) {
  $r = [Windows.Forms.MessageBox]::Show(
    "是否保留优化备份（backup 目录）？`n`n还没「还原设置」过系统改动的话，请选「是」。",
    'DeltaForceBooster 卸载', 'YesNo', 'Question')
  $keep = ($r -ne 'No')
}
foreach ($m in $menuDirs) { if (Test-Path $m) { Remove-Item $m -Recurse -Force } }
foreach ($d in $deskDirs) {
  $lnk = Join-Path $d '三角洲行动优化助手.lnk'
  if (Test-Path $lnk) { Remove-Item $lnk -Force }
}
if (Test-Path $dest) {
  if ($keep) {
    Get-ChildItem $dest -Force | Where-Object { $_.Name -ne 'backup' } | Remove-Item -Recurse -Force
  } else {
    Remove-Item $dest -Recurse -Force
  }
}
if (-not $silent) { [Windows.Forms.MessageBox]::Show('卸载完成。', 'DeltaForceBooster', 'OK', 'Information') | Out-Null }
'@
$uninstallBat = @"
@echo off
rem cwd moves out first so the folder being deleted is not locked by this cmd
rem run + exit share ONE line: this bat deletes itself during uninstall, and cmd
rem re-reads the file between lines - a separate exit line would print an error
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" & exit
"@
$enc = New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText((Join-Path $stage 'uninstall.ps1'), $uninstallPs, $enc)
# bat 用 ANSI：cmd 不识别 UTF-8 BOM，中文注释改成 ASCII 保平安
[IO.File]::WriteAllText((Join-Path $stage '卸载.bat'), $uninstallBat, [Text.Encoding]::Default)

# ---------- 2. 压 payload ----------
$payload = Join-Path $work 'payload.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $payload -Force

# ---------- 3. 生成安装器图标（与 make-launcher.ps1 同一枚三角 Logo、同一套手写 ICO 逻辑） ----------
# 不用 Icon.FromHandle(...).Save()：句柄图标序列化在部分系统上产出损坏文件，手写格式最稳
Add-Type -AssemblyName System.Drawing
$side = 48
$bmp = New-Object Drawing.Bitmap $side, $side, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::FromArgb(255, 13, 20, 23))
$pts = @(
  (New-Object Drawing.PointF 24.0, 6.0), (New-Object Drawing.PointF 45.6, 42.0),
  (New-Object Drawing.PointF 31.2, 42.0), (New-Object Drawing.PointF 24.0, 27.6),
  (New-Object Drawing.PointF 16.8, 42.0), (New-Object Drawing.PointF 2.4, 42.0)
)
$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 0, 232, 132))
$g.FillPolygon($brush, $pts)
$g.Dispose()

$rect = New-Object Drawing.Rectangle 0, 0, $side, $side
$bd = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pixels = New-Object byte[] ($side * $side * 4)
[Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $pixels, 0, $pixels.Length)
$bmp.UnlockBits($bd)
$bmp.Dispose()

$xorSize = $side * $side * 4
$andRow  = [int]([math]::Ceiling($side / 32.0) * 4)
$andSize = $andRow * $side
$bmpSize = 40 + $xorSize + $andSize
$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
$bw.Write([byte]$side); $bw.Write([byte]$side); $bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$bmpSize); $bw.Write([uint32]22)
$bw.Write([uint32]40); $bw.Write([int]$side); $bw.Write([int]($side * 2))
$bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0); $bw.Write([uint32]($xorSize + $andSize))
$bw.Write([int]0); $bw.Write([int]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
for ($y = $side - 1; $y -ge 0; $y--) { $bw.Write($pixels, $y * $side * 4, $side * 4) }
$bw.Write((New-Object byte[] $andSize))
$bw.Flush()
$icoFile = Join-Path $work 'setup.ico'
[IO.File]::WriteAllBytes($icoFile, $ms.ToArray())
$bw.Close()

# ---------- 4. asInvoker 清单：默认装用户目录不需要管理员，选受保护目录时向导按需提权重启 ----------
$manifest = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
'@
$manifestFile = Join-Path $work 'setup.manifest'
[IO.File]::WriteAllText($manifestFile, $manifest, (New-Object Text.UTF8Encoding($false)))

# ---------- 5. 编译安装向导（源码在 build\setup-wizard.cs，版本号编译期注入） ----------
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw '本机没有 .NET Framework csc.exe，无法编译安装向导' }

$csSrc = [IO.File]::ReadAllText((Join-Path $build 'setup-wizard.cs'), [Text.Encoding]::UTF8)
$csSrc = $csSrc.Replace('__VER4__', $ver4).Replace('__VER__', $ver)
$csFile = Join-Path $work 'setup-wizard.cs'
# UTF-8 BOM + /codepage:65001 双保险：csc 默认按当前代码页读源文件（本机 ACP=1252），
# 缺了任何一个中文字符串都会在编译期被打碎
[IO.File]::WriteAllText($csFile, $csSrc, $enc)

# WPF/压缩程序集不在 Framework 目录里，只能从 GAC 按强名定位真实路径给 /r:
# （System.Windows.Forms 不在此列：csc 默认 csc.rsp 已引用，重复给会报 CS1703）
function Resolve-GacRef([string]$name) {
  $asm = [Reflection.Assembly]::LoadWithPartialName($name)
  if (-not $asm) { throw "无法在 GAC 定位程序集：$name" }
  $asm.Location
}
$refNames = @('PresentationFramework', 'PresentationCore', 'WindowsBase', 'System.Xaml',
              'System.IO.Compression', 'System.IO.Compression.FileSystem')
$refArgs = $refNames | ForEach-Object { "/r:$(Resolve-GacRef $_)" }

$setupTmp = Join-Path $work "DeltaForceBooster-Setup-v$ver.exe"
& $csc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 `
  /out:"$setupTmp" /win32icon:"$icoFile" /win32manifest:"$manifestFile" `
  /resource:"$payload,DFB.Payload" @refArgs "$csFile"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $setupTmp)) { throw "csc 编译安装向导失败（退出码 $LASTEXITCODE）" }

# ---------- 6. 成品落位 ----------
# payload.zip 只作为安装器的内嵌资源存在，不再单独输出成发布物
$setupOutTmp = Join-Path $build (Split-Path -Leaf $setupTmp)
if (Test-Path $setupOutTmp) { Remove-Item $setupOutTmp -Force }
Move-Item $setupTmp $setupOutTmp
Remove-Item $work -Recurse -Force

# ---------- 7. 更新清单模板（配合内置更新） ----------
# sha256/size 直接从刚构建的 Setup.exe 现算：客户端下载后强制校验这两个字段，
# 手工计算迟早抄错一次哈希，发布时只需把 notes 占位换成真实更新说明再上传。
# setupUrl 固定指向服务器上的无版本号文件名（发布即覆盖），域名必须保持在
# scripts\updater.ps1 的白名单内，否则老客户端会拒绝下载。
$setupOut = Join-Path $build "DeltaForceBooster-Setup-v$ver.exe"
$manifestOut = Join-Path $build 'update-manifest.json'
$manifestObj = [ordered]@{
  version  = "$ver.0"
  notes    = '（发布前把这里换成真实的更新说明，支持 \n 换行）'
  url      = 'https://df.ltz88.cn/'
  setupUrl = 'https://df.ltz88.cn/DeltaForceBooster-Setup.exe'
  sha256   = (Get-FileHash -LiteralPath $setupOut -Algorithm SHA256).Hash.ToLowerInvariant()
  size     = (Get-Item -LiteralPath $setupOut).Length
}
# 不带 BOM：服务器上的清单由 .NET/浏览器直接消费，带 BOM 的 JSON 部分解析器会噎住
[IO.File]::WriteAllText($manifestOut, ($manifestObj | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))

"构建完成（v$ver）："
Get-ChildItem $build -File -Filter '*.exe' |
  ForEach-Object { "  {0}  ({1:N0} KB)" -f $_.Name, ($_.Length / 1KB) }
"  update-manifest.json  已生成（sha256/size 取自本次 Setup.exe，notes 待填写）"
