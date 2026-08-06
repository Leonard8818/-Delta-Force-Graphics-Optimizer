<#
  DeltaForceBooster 安装包构建脚本 — v0.2
  只用系统自带组件（Compress-Archive + IExpress），零第三方依赖：
    build\DeltaForceBooster-Setup-vX.Y.exe   —— 双击安装：解包到 %LOCALAPPDATA%\DeltaForceBooster
                                                并创建开始菜单快捷方式（含卸载入口）
    build\DeltaForceBooster-Portable-vX.Y.zip —— 绿色版：解压即用，双击「启动优化工具.exe」
                                                （.bat 保留为后备入口）
  v0.2：主入口从 .bat 换成 make-launcher.ps1 编译的 .exe（不闪黑框、自带 UAC 清单、
        不受执行策略限制），快捷方式图标直接用 exe 自带图标。

  用法：powershell -NoProfile -ExecutionPolicy Bypass -File build\make-installer.ps1

  发布须知（写给分发者，别粉饰）：
    1) 没有代码签名证书，Windows SmartScreen 会对 Setup.exe 弹「未知发布者」拦截页，
       用户需点「更多信息 → 仍要运行」。
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
$ver = $Matches[1]

# 中间产物全放 ASCII 路径的临时目录：IExpress 的 SED 是 ANSI 格式，
# 路径里有「桌面」这类中文时不同代码页下会构建失败，最后再把成品移回 build\
$work  = Join-Path $env:TEMP "dfb-build-$PID"
$stage = Join-Path $work 'stage'
$pkg   = Join-Path $work 'pkg'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $stage, $pkg -Force | Out-Null

# ---------- 1. 收集要分发的文件 ----------
# exe 启动器是主入口，缺了先现场编译一份（只依赖系统自带 csc）
$launcher = Join-Path $root '启动优化工具.exe'
if (-not (Test-Path -LiteralPath $launcher)) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make-launcher.ps1')
  if (-not (Test-Path -LiteralPath $launcher)) { throw '启动器 exe 缺失且现场编译失败，先运行 build\make-launcher.ps1 排查' }
}
# backup\ 是本机改动记录、build\ 是构建目录、config\ 是运行期状态，都不进包；
# profiles\ 里的预设随包分发；.bat 保留为后备入口
$parts = @('启动优化工具.exe', '启动优化工具.bat', 'README.md', 'SKILL.md', 'scripts', 'gui', 'tools', 'profiles', 'data')
foreach ($p in $parts) {
  $src = Join-Path $root $p
  if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $stage -Recurse }
}

# 卸载脚本随包落到安装目录（绿色版用户也可直接删目录）。
# 全程不用 WScript.Shell：它按系统 ANSI 代码页转字符串，非中文代码页（如 1252）的系统上
# 中文全变 "?"，弹窗乱码、快捷方式直接保存失败。消息框走 .NET WinForms（原生 Unicode）。
$uninstallPs = @'
# DeltaForceBooster 卸载：删开始菜单快捷方式 + 安装目录；backup\ 是系统还原凭据，默认保留
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
$dest = Join-Path $env:LOCALAPPDATA 'DeltaForceBooster'
$menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\DeltaForceBooster'
# DFB_INSTALL_SILENT=1 供自动化验证：不弹框、按「保留备份」的安全默认走
$silent = ($env:DFB_INSTALL_SILENT -eq '1')
$keep = $true
if (-not $silent) {
  $r = [Windows.Forms.MessageBox]::Show(
    "是否保留优化备份（backup 目录）？`n`n还没「还原设置」过系统改动的话，请选「是」。",
    'DeltaForceBooster 卸载', 'YesNo', 'Question')
  $keep = ($r -ne 'No')
}
if (Test-Path $menu) { Remove-Item $menu -Recurse -Force }
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
cd /d "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
"@
$enc = New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText((Join-Path $stage 'uninstall.ps1'), $uninstallPs, $enc)
# bat 用 ANSI：cmd 不识别 UTF-8 BOM，中文注释改成 ASCII 保平安
[IO.File]::WriteAllText((Join-Path $stage '卸载.bat'), $uninstallBat, [Text.Encoding]::Default)

# ---------- 2. 压 payload + 生成安装脚本 ----------
$payload = Join-Path $pkg 'payload.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $payload -Force

$installPs = @'
<#
  DeltaForceBooster 安装脚本（由 Setup.exe 在解压临时目录里调起）
  装到 %LOCALAPPDATA%：写用户目录不需要管理员，装完程序自身运行时才提权。
  快捷方式不走 WScript.Shell：它按系统 ANSI 代码页转字符串，非中文代码页的系统
  （实测 ACP=1252 时）中文路径变 "?" 直接保存失败；改用 IShellLinkW（原生 Unicode）。
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
class CShellLink {}

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
interface IShellLinkW {
  void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cch, IntPtr pfd, int fFlags);
  void GetIDList(out IntPtr ppidl);
  void SetIDList(IntPtr pidl);
  void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cch);
  void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
  void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cch);
  void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
  void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cch);
  void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
  void GetHotkey(out short pwHotkey);
  void SetHotkey(short wHotkey);
  void GetShowCmd(out int piShowCmd);
  void SetShowCmd(int iShowCmd);
  void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cch, out int piIcon);
  void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
  void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, int dwReserved);
  void Resolve(IntPtr hwnd, int fFlags);
  void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
}

public static class DfbShortcut {
  public static void Create(string lnkPath, string target, string workDir, string iconPath, int iconIndex, string desc) {
    IShellLinkW link = (IShellLinkW)new CShellLink();
    link.SetPath(target);
    link.SetWorkingDirectory(workDir);
    link.SetDescription(desc);
    if (!string.IsNullOrEmpty(iconPath)) { link.SetIconLocation(iconPath, iconIndex); }
    ((IPersistFile)link).Save(lnkPath, true);
  }
}
"@

try {
  $dest = Join-Path $env:LOCALAPPDATA 'DeltaForceBooster'
  $menuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\DeltaForceBooster'
  $tmp = Join-Path $env:TEMP "dfb-install-$PID"
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  Expand-Archive -Path (Join-Path $PSScriptRoot 'payload.zip') -DestinationPath $tmp -Force

  if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
  foreach ($it in Get-ChildItem $tmp) {
    if ($it.Name -eq 'profiles') {
      # 覆盖安装时不动用户自存的方案：profiles 里只补充新文件，不覆盖同名旧文件
      $pd = Join-Path $dest 'profiles'
      if (-not (Test-Path $pd)) { New-Item -ItemType Directory -Path $pd | Out-Null }
      foreach ($f in Get-ChildItem $it.FullName -File) {
        if (-not (Test-Path (Join-Path $pd $f.Name))) { Copy-Item $f.FullName $pd }
      }
    } else {
      Copy-Item $it.FullName $dest -Recurse -Force
    }
  }
  Remove-Item $tmp -Recurse -Force

  # 开始菜单快捷方式：主入口 + 卸载。主入口优先指 exe（自带图标与 UAC 清单），
  # 老包里没有 exe 时退回 bat，保证覆盖安装不炸
  if (-not (Test-Path $menuDir)) { New-Item -ItemType Directory -Path $menuDir | Out-Null }
  $mainTarget = Join-Path $dest '启动优化工具.exe'
  if (Test-Path $mainTarget) {
    [DfbShortcut]::Create((Join-Path $menuDir '三角洲行动优化助手.lnk'),
      $mainTarget, $dest, $mainTarget, 0, '三角洲行动 画面/帧率优化助手')
  } else {
    [DfbShortcut]::Create((Join-Path $menuDir '三角洲行动优化助手.lnk'),
      (Join-Path $dest '启动优化工具.bat'), $dest,
      "$env:SystemRoot\System32\imageres.dll", 262, '三角洲行动 画面/帧率优化助手')
  }
  [DfbShortcut]::Create((Join-Path $menuDir '卸载优化助手.lnk'),
    (Join-Path $dest '卸载.bat'), $dest,
    "$env:SystemRoot\System32\imageres.dll", 271, '卸载 DeltaForceBooster')

  # DFB_INSTALL_SILENT=1 供自动化验证：跳过收尾弹窗
  if ($env:DFB_INSTALL_SILENT -ne '1') {
    [Windows.Forms.MessageBox]::Show(
      "安装完成！`n`n位置：$dest`n开始菜单已添加「三角洲行动优化助手」。`n首次运行会请求管理员权限（优化需要改系统设置）。",
      'DeltaForceBooster 安装', 'OK', 'Information') | Out-Null
  }
} catch {
  if ($env:DFB_INSTALL_SILENT -ne '1') {
    try {
      [Windows.Forms.MessageBox]::Show("安装失败：$($_.Exception.Message)", 'DeltaForceBooster 安装', 'OK', 'Error') | Out-Null
    } catch {}
  }
  exit 1
}
'@
[IO.File]::WriteAllText((Join-Path $pkg 'install.ps1'), $installPs, $enc)
# 安装全程写日志到 %TEMP%\dfb-install-log.txt：Setup.exe 没有控制台，出问题时这是唯一现场
[IO.File]::WriteAllText((Join-Path $pkg 'install.cmd'),
  "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0install.ps1`" > `"%TEMP%\dfb-install-log.txt`" 2>&1`r`n",
  [Text.Encoding]::ASCII)

# ---------- 3. IExpress 打自解压安装器 ----------
# 注意 AppLaunched 必须直指 install.cmd：写成 "cmd /c install.cmd" 时
# 本机 wextract 会静默跳过安装命令（实测复现），直指脚本文件才可靠
$setupTmp = Join-Path $work "DeltaForceBooster-Setup-v$ver.exe"
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$setupTmp
FriendlyName=DeltaForceBooster Setup
AppLaunched=install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
FILE0="payload.zip"
FILE1="install.cmd"
FILE2="install.ps1"
[SourceFiles]
SourceFiles0=$pkg\
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
"@
$sedFile = Join-Path $work 'setup.sed'
# SED 是 ANSI 世代的格式，写 ASCII 内容 + Default 编码最稳
[IO.File]::WriteAllText($sedFile, $sed, [Text.Encoding]::Default)
# 注意：不要给 SED 路径手动加引号——IExpress 收到带引号的路径会找不到文件、
# 静默退回向导界面把构建吊死；Start-Process 会自动处理含空格参数的引号
$ix = Start-Process -FilePath "$env:SystemRoot\System32\iexpress.exe" -ArgumentList '/N', $sedFile -Wait -PassThru
if ($ix.ExitCode -ne 0 -or -not (Test-Path $setupTmp)) {
  throw "IExpress 构建失败（退出码 $($ix.ExitCode)）：$sedFile"
}

# ---------- 4. 绿色版 zip + 成品落位 ----------
$portableTmp = Join-Path $work "DeltaForceBooster-Portable-v$ver.zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $portableTmp -Force

foreach ($f in @($setupTmp, $portableTmp)) {
  $out = Join-Path $build (Split-Path -Leaf $f)
  if (Test-Path $out) { Remove-Item $out -Force }
  Move-Item $f $out
}
Remove-Item $work -Recurse -Force

"构建完成（v$ver）："
Get-ChildItem $build -File | Where-Object { $_.Extension -in '.exe', '.zip' } |
  ForEach-Object { "  {0}  ({1:N0} KB)" -f $_.Name, ($_.Length / 1KB) }
