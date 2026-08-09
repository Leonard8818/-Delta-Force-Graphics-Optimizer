<#
  DeltaForceBooster 启动器构建脚本 — v0.4
  v0.4：启动器改为 asInvoker；启动 GUI 前校验关键脚本/PresentMon 的发布哈希，
        安装文件被替换或经重解析点跳转时拒绝启动并提示重新安装。
  v0.3：程序集版本号按位补齐到四段，三段 GUI 版本不再拼成五段导致 csc 编译失败。
  v0.2：ICO 除内嵌进 exe 外，另落一份 gui\app.ico 随包分发——WPF 窗口不设 Icon 时
        任务栏/Alt-Tab 显示宿主 powershell.exe 的图标（实机反馈），GUI 启动时读它。
  用系统自带的 .NET Framework csc.exe 编译出根目录「启动优化工具.exe」，零第三方依赖：
    - exe 内嵌 asInvoker 清单：GUI 默认以普通权限启动，需要系统权限的操作再单独提权；
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

# 关键运行文件的哈希直接编进启动器。安装目录 ACL 是主边界；这里再阻止离线篡改、
# 杀毒误删后被同名文件顶替等情况。make-installer 每次发布都会强制重建本启动器。
$hashFiles = @(
  'gui\DeltaForceBooster-GUI.ps1',
  'scripts\delta-booster.ps1',
  'scripts\updater.ps1',
  'scripts\telemetry-client.ps1',
  'scripts\tuning-experiment.ps1',
  'tools\PresentMon.exe'
)
$hashRows = foreach ($rel in $hashFiles) {
  $path = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "启动器哈希白名单文件缺失：$rel" }
  $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
  '        new string[] { @"' + $rel + '", "' + $hash + '" }'
}
$hashRowsText = $hashRows -join ",`r`n"

$windowsDir = Split-Path -Parent ([Environment]::SystemDirectory)
$csc = Join-Path $windowsDir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $windowsDir 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
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

# ---------- 2. asInvoker 清单 ----------
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
$manifestFile = Join-Path $work 'launcher.manifest'
[IO.File]::WriteAllText($manifestFile, $manifest, (New-Object Text.UTF8Encoding($false)))

# ---------- 3. C# 启动器源码 ----------
$cs = @"
// DeltaForceBooster 启动器：校验发布文件后，以当前用户权限拉起 GUI。
// 用 exe 而不是 bat：不闪黑框、不受执行策略限制，并固定从 System32 启动 PowerShell。
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("三角洲行动优化助手")]
[assembly: AssemblyDescription("DeltaForceBooster 安全启动器")]
[assembly: AssemblyProduct("DeltaForceBooster")]
[assembly: AssemblyCompany("DeltaForceBooster 开源项目")]
[assembly: AssemblyCopyright("DeltaForceBooster MIT 开源项目")]
[assembly: AssemblyVersion("$ver4")]
[assembly: AssemblyFileVersion("$ver4")]

static class Launcher {
    static readonly string[][] RequiredFiles = new string[][] {
$hashRowsText
    };

    static string Sha256(string path) {
        using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
        using (var sha = SHA256.Create())
            return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
    }

    static bool HasReparsePoint(string root, string relativePath) {
        string current = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar);
        try {
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) return true;
            foreach (string part in relativePath.Split(new char[] { '\\', '/' }, StringSplitOptions.RemoveEmptyEntries)) {
                current = Path.Combine(current, part);
                if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) return true;
            }
        } catch { return true; }
        return false;
    }

    static bool IsSha256(string value) {
        if (string.IsNullOrEmpty(value) || value.Length != 64) return false;
        foreach (char c in value)
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return false;
        return true;
    }

    static string ValidateIdentity(string root) {
        string rel = "install.identity";
        string identity = Path.Combine(root, rel);
        string launcher = Path.Combine(root, "启动优化工具.exe");
        if (!File.Exists(identity) || !File.Exists(launcher)) return "install.identity 缺失";
        if (HasReparsePoint(root, rel) || HasReparsePoint(root, "启动优化工具.exe")) return "安装身份位于重解析点路径";
        try {
            if (new FileInfo(identity).Length <= 0 || new FileInfo(identity).Length > 512) return "安装身份大小无效";
            string text;
            using (var fs = new FileStream(identity, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var reader = new StreamReader(fs, new UTF8Encoding(false, true), false)) text = reader.ReadToEnd();
            string[] lines = text.Replace("\r\n", "\n").Split('\n');
            if (lines.Length != 4 || lines[3].Length != 0 || lines[0] != "SchemaVersion=1" ||
                lines[1] != "ProductId=DeltaForceBooster" || !lines[2].StartsWith("LauncherSha256=", StringComparison.Ordinal))
                return "安装身份格式无效";
            string expected = lines[2].Substring("LauncherSha256=".Length);
            if (!IsSha256(expected) || !string.Equals(Sha256(launcher), expected, StringComparison.OrdinalIgnoreCase))
                return "启动器与安装身份不匹配";
            return null;
        } catch (Exception ex) { return "安装身份校验失败：" + ex.Message; }
    }

    static string ValidateFiles(string root) {
        string identityError = ValidateIdentity(root);
        if (identityError != null) return identityError;
        string prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        foreach (string[] item in RequiredFiles) {
            string path = Path.GetFullPath(Path.Combine(root, item[0]));
            if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || !File.Exists(path))
                return item[0] + " 缺失";
            if (HasReparsePoint(root, item[0])) return item[0] + " 位于重解析点路径";
            try {
                if (!string.Equals(Sha256(path), item[1], StringComparison.OrdinalIgnoreCase))
                    return item[0] + " 完整性校验失败";
            } catch (Exception ex) { return item[0] + " 校验失败：" + ex.Message; }
        }
        return null;
    }

    [STAThread]
    static void Main() {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string gui = Path.Combine(root, "gui", "DeltaForceBooster-GUI.ps1");
        string validationError = ValidateFiles(root);
        if (validationError != null) {
            MessageBox.Show("程序文件不完整或已被修改：" + validationError +
                "\n\n为避免运行异常文件，启动已停止。请从官网重新安装完整版本。",
                "三角洲行动优化助手", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }
        var psi = new ProcessStartInfo();
        string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        psi.FileName = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
        // -ExecutionPolicy Bypass：实测有用户机器默认策略拒绝未签名脚本，入口必须自带豁免
        psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + gui + "\"";
        psi.WorkingDirectory = root;
        psi.UseShellExecute = true;
        // asInvoker：控制台宿主继承当前用户权限；WPF 窗口由脚本自己弹出，全程无黑框。
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
