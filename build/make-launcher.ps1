<#
  DeltaForceBooster 启动器构建脚本 — v0.3
  v0.3：程序集版本号按位补齐到四段，三段 GUI 版本不再拼成五段导致 csc 编译失败。
  v0.2：ICO 除内嵌进 exe 外，另落一份 gui\app.ico 随包分发——WPF 窗口不设 Icon 时
        任务栏/Alt-Tab 显示宿主 powershell.exe 的图标（实机反馈），GUI 启动时读它。
  用系统自带的 .NET Framework csc.exe 编译出根目录「启动优化工具.exe」，零第三方依赖：
    - exe 内嵌 requireAdministrator 清单：双击即弹一次 UAC，GUI 脚本检测到已是管理员
      就不会二次提权，也没有 bat 方式先闪黑色控制台窗口的问题；
    - exe 不受 PowerShell 执行策略限制（实测有用户机器默认策略拦截未签名 .ps1，
      只有带 -ExecutionPolicy Bypass 的入口才跑得起来）；
    - 图标（官网同款三角 Logo）与版本信息由本脚本现场生成/内嵌。
  用法：powershell -NoProfile -ExecutionPolicy Bypass -File build\make-launcher.ps1
  「启动优化工具.bat」保留作为后备入口，不受本脚本影响。
#>
#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "dfb-launcher-$PID"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null

# 版本号跟随 GUI 徽标，exe 的文件版本与界面保持一致
$guiText = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'), [Text.Encoding]::UTF8)
if ($guiText -notmatch '\[ v([\d.]+) \]') { throw '无法从 GUI 文件解析版本号' }
$ver = $Matches[1]
$verParts = @($ver -split '\.') + @('0', '0', '0', '0')
$ver4 = ($verParts[0..3]) -join '.'

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw '本机没有 .NET Framework csc.exe，无法编译启动器（保留 .bat 入口即可）' }

# ---------- 1. 生成图标：官网同款三角 Logo，手写 ICO 格式 ----------
# 不用 Icon.FromHandle(...).Save()：句柄图标序列化在部分系统上产出损坏文件，手写格式最稳
Add-Type -AssemblyName System.Drawing
$side = 48
$bmp = New-Object Drawing.Bitmap $side, $side, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::FromArgb(255, 13, 20, 23))   # 官网顶栏近黑微青 #0D1417
$pts = @(                                              # GUI 里同一枚三角 Logo 的放大坐标
  (New-Object Drawing.PointF 24.0, 6.0), (New-Object Drawing.PointF 45.6, 42.0),
  (New-Object Drawing.PointF 31.2, 42.0), (New-Object Drawing.PointF 24.0, 27.6),
  (New-Object Drawing.PointF 16.8, 42.0), (New-Object Drawing.PointF 2.4, 42.0)
)
$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 0, 232, 132))  # 正绿 #00E884
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
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)          # ICONDIR
$bw.Write([byte]$side); $bw.Write([byte]$side); $bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$bmpSize); $bw.Write([uint32]22)
$bw.Write([uint32]40); $bw.Write([int]$side); $bw.Write([int]($side * 2)) # BITMAPINFOHEADER（高度含 AND 掩码故 ×2）
$bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0); $bw.Write([uint32]($xorSize + $andSize))
$bw.Write([int]0); $bw.Write([int]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
for ($y = $side - 1; $y -ge 0; $y--) { $bw.Write($pixels, $y * $side * 4, $side * 4) }  # DIB 自底向上
$bw.Write((New-Object byte[] $andSize))                                   # 32bpp 用 alpha，AND 掩码全 0
$bw.Flush()
$icoFile = Join-Path $work 'launcher.ico'
[IO.File]::WriteAllBytes($icoFile, $ms.ToArray())
# 同一枚图标另存 gui\app.ico 随包分发：GUI 的 WPF 窗口挂上它，任务栏/Alt-Tab
# 才不会显示宿主 powershell.exe 的图标（实机反馈过）
[IO.File]::WriteAllBytes((Join-Path $root 'gui\app.ico'), $ms.ToArray())
$bw.Close()

# ---------- 2. UAC 提权清单 ----------
$manifest = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
'@
$manifestFile = Join-Path $work 'launcher.manifest'
[IO.File]::WriteAllText($manifestFile, $manifest, (New-Object Text.UTF8Encoding($false)))

# ---------- 3. C# 启动器源码 ----------
$cs = @"
// DeltaForceBooster 启动器：唯一职责是以管理员权限拉起 gui\DeltaForceBooster-GUI.ps1。
// 用 exe 而不是 bat：不闪黑框、不受执行策略限制、UAC 弹窗带正规程序名。
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("三角洲行动优化助手")]
[assembly: AssemblyDescription("DeltaForceBooster 启动器（以管理员权限打开优化界面）")]
[assembly: AssemblyProduct("DeltaForceBooster")]
[assembly: AssemblyCompany("DeltaForceBooster 开源项目")]
[assembly: AssemblyCopyright("DeltaForceBooster MIT 开源项目")]
[assembly: AssemblyVersion("$ver4")]
[assembly: AssemblyFileVersion("$ver4")]

static class Launcher {
    [STAThread]
    static void Main() {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string gui = Path.Combine(root, "gui", "DeltaForceBooster-GUI.ps1");
        if (!File.Exists(gui)) {
            MessageBox.Show("未找到 gui\\DeltaForceBooster-GUI.ps1。\n请把本程序放在优化工具的根目录里运行。",
                "三角洲行动优化助手", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        var psi = new ProcessStartInfo();
        psi.FileName = "powershell.exe";
        // -ExecutionPolicy Bypass：实测有用户机器默认策略拒绝未签名脚本，入口必须自带豁免
        psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + gui + "\"";
        psi.WorkingDirectory = root;
        psi.UseShellExecute = true;
        // 本 exe 已带 requireAdministrator 清单，这里继承管理员权限；
        // 控制台宿主以隐藏方式启动，WPF 窗口由脚本自己弹出，全程无黑框
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        try { Process.Start(psi); }
        catch (Exception ex) {
            MessageBox.Show("启动失败：" + ex.Message, "三角洲行动优化助手",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
"@
$csFile = Join-Path $work 'launcher.cs'
[IO.File]::WriteAllText($csFile, $cs, (New-Object Text.UTF8Encoding($true)))

# ---------- 4. 编译到项目根目录 ----------
$exe = Join-Path $root '启动优化工具.exe'
& $csc /nologo /target:winexe /platform:anycpu /optimize+ `
  /out:"$exe" /win32icon:"$icoFile" /win32manifest:"$manifestFile" `
  /r:System.Windows.Forms.dll "$csFile"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { throw "csc 编译失败（退出码 $LASTEXITCODE）" }

Remove-Item $work -Recurse -Force
$fi = Get-Item -LiteralPath $exe
"构建完成：$($fi.FullName)"
"  大小 : {0:N0} KB" -f ($fi.Length / 1KB)
"  版本 : $($fi.VersionInfo.FileVersion)  描述 : $($fi.VersionInfo.FileDescription)"
