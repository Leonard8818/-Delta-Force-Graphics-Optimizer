<#
  DeltaForceBooster 启动器构建脚本 — v0.6
  v0.6：收尾阶段不再对 GetProcessById 拿到的 EngineHost 直接读 ExitCode/WaitForExit——
        那会抛「进程不是由此对象启动的」，把 EngineHost 真正的失败原因盖成一句无关
        报错；改为可失败的安全读取，读不到就如实说明。会话建立后再出错也不再谎称
        「启动失败」。
  v0.5：asInvoker 启动器不再直接运行 PowerShell；它校验受保护安装目录、
        EngineHost 与全部可执行负载，再通过双向命名管道启动唯一的管理员会话。
  v0.4：启动器改为 asInvoker；启动 GUI 前校验关键脚本/PresentMon 的发布哈希，
        安装文件被替换或经重解析点跳转时拒绝启动并提示重新安装。
  v0.23.0.0：产品统一使用四段版本号，避免界面、更新清单与程序集元数据不一致。
  v0.2：ICO 除内嵌进 exe 外，另落一份 gui\app.ico 随包分发——WPF 窗口不设 Icon 时
        任务栏/Alt-Tab 显示宿主 powershell.exe 的图标（实机反馈），GUI 启动时读它。
  用系统自带的 .NET Framework csc.exe 编译出根目录「启动优化工具.exe」，零第三方依赖：
    - exe 内嵌 asInvoker 清单：完成低权限校验后，只对自有 EngineHost.exe 请求一次 UAC；
    - exe 不受 PowerShell 执行策略限制（实测有用户机器默认策略拦截未签名 .ps1，
      只有带 -ExecutionPolicy Bypass 的入口才跑得起来）；
    - 图标（官网同款三角 Logo）与版本信息由本脚本现场生成/内嵌。
  用法：powershell -NoProfile -ExecutionPolicy Bypass -File build\make-launcher.ps1
  「启动优化工具.bat」保留作为后备入口，不受本脚本影响。
#>
#requires -Version 5.1
param([switch]$TestBuild, [switch]$IconOnly)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "dfb-launcher-$PID"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null

# 文件版本跟随单调递增的内部发布序号；界面徽标允许使用更简洁的品牌版本。
$guiText = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'), [Text.Encoding]::UTF8)
if ($guiText -notmatch '\$script:GuiVersion\s*=\s*''([\d.]+)''') { throw '无法从 GUI 文件解析内部版本号' }
$ver = $Matches[1]
$verParts = @($ver -split '\.') + @('0', '0', '0', '0')
$ver4 = ($verParts[0..3]) -join '.'

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

if ($IconOnly) {
  Remove-Item $work -Recurse -Force
  return
}

# 关键运行文件的哈希直接编进启动器。图标必须先落成最终字节，再计算哈希；否则
# clean build 或图标重绘会让 EngineHost/launcher 在运行时互相拒绝完整 payload。
$hashFiles = @(
  'EngineHost.exe',
  'gui\DeltaForceBooster-GUI.ps1',
  'gui\app.ico',
  'scripts\delta-booster.ps1',
  'scripts\diagnose.ps1',
  'scripts\updater.ps1',
  'scripts\telemetry-client.ps1',
  'scripts\tuning-experiment.ps1',
  'scripts\user-context-worker.ps1',
  'scripts\hardware-sensors.ps1',
  'tools\PresentMon.exe',
  'tools\LibreHardwareMonitorLib.dll',
  'tools\HidSharp.dll',
  'tools\DiskInfoToolkit.dll',
  'tools\RAMSPDToolkit-NDD.dll',
  'tools\BlackSharp.Core.dll',
  'tools\System.Memory.dll',
  'tools\System.Runtime.CompilerServices.Unsafe.dll',
  'tools\System.Buffers.dll',
  'tools\System.Numerics.Vectors.dll'
)
$hashRows = foreach ($rel in $hashFiles) {
  $path = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "启动器哈希白名单文件缺失：$rel" }
  $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
  '        new string[] { @"' + $rel + '", "' + $hash + '" }'
}
$hashRowsText = $hashRows -join ",`r`n"

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
// DeltaForceBooster 启动器：低权限校验后只拉起自有 EngineHost，由它持有整段 GUI 管理员会话。
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("三角洲行动优化助手")]
[assembly: AssemblyDescription("DeltaForceBooster 安全启动器")]
[assembly: AssemblyProduct("DeltaForceBooster")]
[assembly: AssemblyCompany("DeltaForceBooster 开源项目")]
[assembly: AssemblyCopyright("DeltaForceBooster MIT 开源项目")]
[assembly: AssemblyVersion("$ver4")]
[assembly: AssemblyFileVersion("$ver4")]

static class Launcher {
    const string SessionMarkerName = @"Global\DeltaForceBooster.LaunchSession";
    const int MaxBrokerPayloadBytes = 24 * 1024 * 1024;
    static readonly string[][] RequiredFiles = new string[][] {
$hashRowsText
    };

    sealed class WorkerResult {
        public bool Ok;
        public string Payload;
    }

    static int ReadUacPolicy(string name, int defaultValue) {
        try {
            using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"))
                return key == null ? defaultValue : Convert.ToInt32(key.GetValue(name, defaultValue));
        } catch { return defaultValue; }
    }

    static bool IsRepairOnlyToken(DfbTokenFacts token, bool currentAdmin) {
        if (!currentAdmin || token == null || token.IsMedium || !token.Elevated || token.IntegrityRid < 0x3000)
            return false;
        // 用户经常习惯性右键“以管理员身份运行”。这时已经丢失 medium token，不能再
        // 提供原用户 worker，但仍可进入受限兼容会话；不要在入口直接把正版安装拦死。
        // EngineHost 会再次核验启动器确为同会话 high token，GUI 再关闭全部用户态 broker。
        return true;
    }

    static Dictionary<string,string> EnterTrustedElevationEnvironment() {
        var saved = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        foreach (DictionaryEntry entry in Environment.GetEnvironmentVariables(EnvironmentVariableTarget.Process))
            saved[(string)entry.Key] = Convert.ToString(entry.Value);
        // Known Folder 值必须在清空调用方环境前取得；随后 RunAs 只继承这份系统白名单，
        // COR_*/COMPlus_*/DOTNET_*/用户 PSModulePath 等注入变量不会跨过 UAC 边界。
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
        string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        foreach (string name in new List<string>(saved.Keys))
            Environment.SetEnvironmentVariable(name, null, EnvironmentVariableTarget.Process);
        Action<string,string> set = delegate(string name, string value) {
            if (!String.IsNullOrEmpty(value)) Environment.SetEnvironmentVariable(name, value, EnvironmentVariableTarget.Process);
        };
        set("SystemRoot", windows); set("WINDIR", windows); set("SystemDrive", Path.GetPathRoot(windows).TrimEnd('\\'));
        set("COMSPEC", Path.Combine(system, "cmd.exe"));
        set("PATH", system + Path.PathSeparator + windows + Path.PathSeparator + Path.Combine(system, "Wbem") +
            Path.PathSeparator + Path.Combine(system, "WindowsPowerShell", "v1.0"));
        set("PATHEXT", ".COM;.EXE;.BAT;.CMD"); set("TEMP", Path.Combine(windows, "Temp")); set("TMP", Path.Combine(windows, "Temp"));
        set("ProgramData", programData); set("ALLUSERSPROFILE", programData);
        set("ProgramFiles", programFiles); set("ProgramFiles(x86)", programFilesX86);
        return saved;
    }

    static void RestoreProcessEnvironment(Dictionary<string,string> saved) {
        var current = Environment.GetEnvironmentVariables(EnvironmentVariableTarget.Process);
        foreach (DictionaryEntry entry in current)
            Environment.SetEnvironmentVariable((string)entry.Key, null, EnvironmentVariableTarget.Process);
        foreach (var item in saved) Environment.SetEnvironmentVariable(item.Key, item.Value, EnvironmentVariableTarget.Process);
    }

    static string Sha256(string path) {
        using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
        using (var sha = SHA256.Create())
            return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetNamedPipeClientProcessId(Microsoft.Win32.SafeHandles.SafePipeHandle pipe, out uint processId);

    static bool PathHasReparsePoint(string path) {
        try {
            string full = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar);
            string root = Path.GetPathRoot(full);
            string current = root;
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) return true;
            foreach (string part in full.Substring(root.Length).Split(new char[] { '\\' }, StringSplitOptions.RemoveEmptyEntries)) {
                current = Path.Combine(current, part);
                if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) return true;
            }
            return false;
        } catch { return true; }
    }

    static bool RuleAllowsWrite(FileSystemAccessRule rule) {
        FileSystemRights mask = FileSystemRights.WriteData | FileSystemRights.AppendData |
            FileSystemRights.WriteExtendedAttributes | FileSystemRights.WriteAttributes |
            FileSystemRights.DeleteSubdirectoriesAndFiles | FileSystemRights.Delete |
            FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership;
        return (rule.FileSystemRights & mask) != 0;
    }

    static string ValidateProtectedRoot(string root) {
        try {
            string layoutError = DfbRuntimeRoot.Validate(root);
            if (layoutError != null) return "安装布局校验失败：" + layoutError;
            string full = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar);
            if (full.StartsWith(@"\\", StringComparison.Ordinal) ||
                new DriveInfo(Path.GetPathRoot(full)).DriveType != DriveType.Fixed)
                return "安装目录不在本地固定磁盘";
            if (PathHasReparsePoint(full)) return "安装路径包含目录联接/符号链接";
#if DFB_TESTING
            // 仅测试启动器允许跳过临时 fixture 的 ACL。生产产物不编入该分支；测试根固定在
            // %TEMP%\DeltaForceBooster-Tests，仍拒绝越界和重解析点，避免环境变量变成通用旁路。
            string testRoot = Path.GetFullPath(Path.Combine(Path.GetTempPath(), "DeltaForceBooster-Tests")).TrimEnd('\\') + "\\";
            if (Environment.GetEnvironmentVariable("DFB_TEST_SKIP_ACL") == "1" &&
                full.StartsWith(testRoot, StringComparison.OrdinalIgnoreCase)) return null;
#endif
            DirectorySecurity acl = Directory.GetAccessControl(full, AccessControlSections.Owner | AccessControlSections.Access);
            string owner = acl.GetOwner(typeof(SecurityIdentifier)).Value;
            if (owner != "S-1-5-18" && owner != "S-1-5-32-544" && !owner.StartsWith("S-1-5-80-", StringComparison.Ordinal))
                return "安装目录所有者不受信任";
            foreach (FileSystemAccessRule rule in acl.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
                string sid = rule.IdentityReference.Value;
                bool trusted = sid == "S-1-5-18" || sid == "S-1-5-32-544" || sid.StartsWith("S-1-5-80-", StringComparison.Ordinal);
                bool creatorInheritOnly = sid == "S-1-3-0" && (rule.PropagationFlags & PropagationFlags.InheritOnly) != 0;
                if (rule.AccessControlType == AccessControlType.Allow && !trusted && !creatorInheritOnly && RuleAllowsWrite(rule))
                    return "安装目录允许普通账户写入";
            }
            return null;
        } catch (Exception ex) { return "安装目录权限校验失败：" + ex.Message; }
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
        string engineHost = Path.Combine(root, "EngineHost.exe");
        if (!File.Exists(identity) || !File.Exists(launcher)) return "install.identity 缺失";
        if (HasReparsePoint(root, rel) || HasReparsePoint(root, "启动优化工具.exe") ||
            (File.Exists(engineHost) && HasReparsePoint(root, "EngineHost.exe"))) return "安装身份位于重解析点路径";
        try {
            if (new FileInfo(identity).Length <= 0 || new FileInfo(identity).Length > 512) return "安装身份大小无效";
            string text;
            using (var fs = new FileStream(identity, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var reader = new StreamReader(fs, new UTF8Encoding(false, true), false)) text = reader.ReadToEnd();
            string[] lines = text.Replace("\r\n", "\n").Split('\n');
            bool v1 = lines.Length == 4 && lines[3].Length == 0 && lines[0] == "SchemaVersion=1";
            bool v2 = lines.Length == 5 && lines[4].Length == 0 && lines[0] == "SchemaVersion=2";
            if ((!v1 && !v2) || lines[1] != "ProductId=DeltaForceBooster" ||
                !lines[2].StartsWith("LauncherSha256=", StringComparison.Ordinal))
                return "安装身份格式无效";
            string expected = lines[2].Substring("LauncherSha256=".Length);
            if (!IsSha256(expected) || !string.Equals(Sha256(launcher), expected, StringComparison.OrdinalIgnoreCase))
                return "启动器与安装身份不匹配";
            if (v2) {
                if (!lines[3].StartsWith("EngineHostSha256=", StringComparison.Ordinal) || !File.Exists(engineHost))
                    return "管理员助手安装身份缺失";
                string hostExpected = lines[3].Substring("EngineHostSha256=".Length);
                if (!IsSha256(hostExpected) || !string.Equals(Sha256(engineHost), hostExpected, StringComparison.OrdinalIgnoreCase))
                    return "管理员助手与安装身份不匹配";
            }
            return null;
        } catch (Exception ex) { return "安装身份校验失败：" + ex.Message; }
    }

    static string ValidateFiles(string root) {
        string rootError = ValidateProtectedRoot(root);
        if (rootError != null) return rootError;
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

    static string RandomHex() {
        byte[] bytes = new byte[16];
        using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(bytes);
        return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
    }

    static PipeSecurity CreateLaunchPipeSecurity() {
        SecurityIdentifier user = WindowsIdentity.GetCurrent().User;
        if (user == null || !user.IsAccountSid()) throw new InvalidOperationException("当前用户 SID 无效");
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var security = new PipeSecurity();
        security.SetAccessRuleProtection(true, false);
        security.AddAccessRule(new PipeAccessRule(user, PipeAccessRights.ReadWrite, AccessControlType.Allow));
        security.AddAccessRule(new PipeAccessRule(admins, PipeAccessRights.ReadWrite, AccessControlType.Allow));
        return security;
    }

    static Mutex CreateSessionMarker(out bool createdNew) {
        var users = new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null);
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var security = new MutexSecurity();
        security.SetAccessRuleProtection(true, false);
        security.AddAccessRule(new MutexAccessRule(users, MutexRights.Synchronize | MutexRights.Modify, AccessControlType.Allow));
        security.AddAccessRule(new MutexAccessRule(admins, MutexRights.FullControl, AccessControlType.Allow));
        return new Mutex(false, SessionMarkerName, out createdNew, security);
    }

    static string ReadBoundedUtf8(BinaryReader reader, int maxBytes) {
        int length = reader.ReadInt32();
        if (length < 0 || length > maxBytes) throw new InvalidOperationException("broker 回复大小无效");
        byte[] bytes = reader.ReadBytes(length);
        if (bytes.Length != length) throw new EndOfStreamException("broker 回复被截断");
        return new UTF8Encoding(false, true).GetString(bytes);
    }

    static void WriteBoundedUtf8(BinaryWriter writer, string value, int maxBytes) {
        byte[] bytes = new UTF8Encoding(false, true).GetBytes(value ?? "");
        if (bytes.Length > maxBytes) throw new InvalidOperationException("broker 回复超过大小上限");
        writer.Write(bytes.Length);
        writer.Write(bytes);
    }

    static WorkerResult RunUserWorker(string root, string action, string payload) {
        if (action != "MigrateLegacyData" && action != "ClearShaderCache" &&
            action != "GetNvidiaPanelApps" && action != "GetAmdPanelApps" &&
            action != "GetIntelPanelApps" && action != "GetNvAutoOptStatus")
            throw new InvalidOperationException("原用户 worker 动作不在白名单");
        if (!String.IsNullOrEmpty(payload))
            throw new InvalidOperationException("原用户 worker 动作不接受参数");
        string workerSession = RandomHex();
        string workerPipeName = "DeltaForceBooster.UserWorker." + RandomHex();
        using (var pipe = new NamedPipeServerStream(workerPipeName, PipeDirection.InOut, 1,
            PipeTransmissionMode.Byte, PipeOptions.Asynchronous, 4096, MaxBrokerPayloadBytes,
            CreateLaunchPipeSecurity())) {
            string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
            string powershell = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
            string worker = Path.Combine(root, "scripts", "user-context-worker.ps1");
            var psi = new ProcessStartInfo();
            psi.FileName = powershell;
            psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + worker + "\" -Action " + action +
                " -Payload \"" + payload + "\" -ReplyPipe " + workerPipeName + " -Session " + workerSession;
            psi.WorkingDirectory = system;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            psi.EnvironmentVariables.Clear();
            string machineModules = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "WindowsPowerShell", "Modules");
            string systemModules = Path.Combine(Path.GetDirectoryName(powershell), "Modules");
            psi.EnvironmentVariables["PSModulePath"] = systemModules + Path.PathSeparator + machineModules;
            psi.EnvironmentVariables["PATH"] = system + Path.PathSeparator + windows + Path.PathSeparator +
                Path.Combine(system, "Wbem") + Path.PathSeparator + Path.Combine(system, "WindowsPowerShell", "v1.0");
            psi.EnvironmentVariables["COMSPEC"] = Path.Combine(system, "cmd.exe");
            psi.EnvironmentVariables["PATHEXT"] = ".COM;.EXE;.BAT;.CMD";
            psi.EnvironmentVariables["SystemRoot"] = windows;
            psi.EnvironmentVariables["WINDIR"] = windows;
            // .NET Framework 4.x 的 CommonApplicationData 会按 %SystemDrive% 展开系统路径；
            // 清空 worker 环境后少这一项，GetFolderPath 会抛“需要绝对路径信息”。
            psi.EnvironmentVariables["SystemDrive"] = Path.GetPathRoot(windows).TrimEnd('\\');
            string commonAppData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            psi.EnvironmentVariables["ProgramData"] = commonAppData;
            psi.EnvironmentVariables["ALLUSERSPROFILE"] = commonAppData;
            psi.EnvironmentVariables["ProgramFiles"] = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            psi.EnvironmentVariables["ProgramFiles(x86)"] = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
            psi.EnvironmentVariables["USERPROFILE"] = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            psi.EnvironmentVariables["APPDATA"] = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            psi.EnvironmentVariables["LOCALAPPDATA"] = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            psi.EnvironmentVariables["TEMP"] = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Temp");
            psi.EnvironmentVariables["TMP"] = psi.EnvironmentVariables["TEMP"];
            using (Process workerProcess = Process.Start(psi)) {
                if (workerProcess == null) throw new InvalidOperationException("原用户 worker 未启动");
                IAsyncResult pending = pipe.BeginWaitForConnection(null, null);
                DateTime deadline = DateTime.UtcNow.AddMinutes(5);
                while (!pending.AsyncWaitHandle.WaitOne(200)) {
                    if (workerProcess.HasExited)
                        throw new InvalidOperationException("原用户 worker 未回传结果（退出码 " + workerProcess.ExitCode + "）");
                    if (DateTime.UtcNow >= deadline) throw new TimeoutException("原用户 worker 执行超时");
                }
                pipe.EndWaitForConnection(pending);
                uint workerPid;
                if (!GetNamedPipeClientProcessId(pipe.SafePipeHandle, out workerPid) || workerPid != (uint)workerProcess.Id)
                    throw new InvalidOperationException("原用户 worker 回复管道 PID 不匹配");
                var reader = new BinaryReader(pipe, new UTF8Encoding(false), true);
                if (reader.ReadString() != "DFB_USER_WORKER/1" || reader.ReadInt32() != workerProcess.Id || reader.ReadString() != workerSession)
                    throw new InvalidOperationException("原用户 worker 回复握手无效");
                var result = new WorkerResult();
                result.Ok = reader.ReadBoolean();
                result.Payload = ReadBoundedUtf8(reader, MaxBrokerPayloadBytes);
                if (!workerProcess.WaitForExit(30000)) throw new TimeoutException("原用户 worker 回复后未退出");
                return result;
            }
        }
    }

    static void OpenAllowedUrl(string raw) {
        Uri uri;
        if (!Uri.TryCreate(raw, UriKind.Absolute, out uri) || uri.Scheme != Uri.UriSchemeHttps ||
            !String.IsNullOrEmpty(uri.UserInfo) || !uri.IsDefaultPort)
            throw new InvalidOperationException("外部链接不是允许的 HTTPS 地址");
        string host = uri.IdnHost.ToLowerInvariant();
        string[] allowed = new string[] { "aka.ms", "df.ltz88.cn", "www.nvidia.cn", "www.amd.com", "www.intel.cn", "www.douyin.com" };
        if (Array.IndexOf(allowed, host) < 0) throw new InvalidOperationException("外部链接域名不在白名单");
        var psi = new ProcessStartInfo(uri.AbsoluteUri);
        psi.UseShellExecute = true;
        Process.Start(psi);
    }

    static void OpenGpuPanel(string key) {
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        string file = null;
        string arguments = null;
        if (key == "nv-cpl") {
            string legacy = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "NVIDIA Corporation", "Control Panel Client", "nvcplui.exe");
            if (File.Exists(legacy)) file = legacy;
            else { file = Path.Combine(windows, "explorer.exe"); arguments = @"shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel"; }
        } else if (key == "nv-app") {
            string p1 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "NVIDIA Corporation", "NVIDIA app", "CEF", "NVIDIA app.exe");
            string p2 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "NVIDIA Corporation", "NVIDIA App", "CEF", "NVIDIA app.exe");
            file = File.Exists(p1) ? p1 : p2;
        } else if (key == "amd-sw") {
            string p1 = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "AMD", "CNext", "CNext", "RadeonSoftware.exe");
            string p2 = Path.Combine(system, "amdow.exe");
            file = File.Exists(p1) ? p1 : p2;
        } else if (key == "intel-gcc") {
            file = Path.Combine(windows, "explorer.exe");
            arguments = @"shell:appsFolder\AppUp.IntelGraphicsExperience_8j3eq9eme6ctt!App";
        } else throw new InvalidOperationException("显卡控制面板动作不在白名单");
        if (String.IsNullOrEmpty(file) || !File.Exists(file)) throw new FileNotFoundException("显卡控制面板未安装");
        var psi = new ProcessStartInfo(file, arguments ?? "");
        psi.UseShellExecute = true;
        psi.WorkingDirectory = system;
        Process.Start(psi);
    }

    static WorkerResult HandleLowRequest(string root, string action, string payload) {
        if (action == "MigrateLegacyData" || action == "ClearShaderCache" ||
            action == "GetNvidiaPanelApps" || action == "GetAmdPanelApps" ||
            action == "GetIntelPanelApps" || action == "GetNvAutoOptStatus")
            return RunUserWorker(root, action, payload);
        if (action == "OpenUrl") { OpenAllowedUrl(payload); return new WorkerResult { Ok = true, Payload = "" }; }
        if (action == "OpenGpuPanel") { OpenGpuPanel(payload); return new WorkerResult { Ok = true, Payload = "" }; }
        throw new InvalidOperationException("低权限 broker 动作不在白名单");
    }

    static string QuotePowerShellLiteral(string value) {
        return "'" + (value ?? "").Replace("'", "''") + "'";
    }

    // 管理员会话是否已经建立：建立之后再出错就不是「启动失败」，而是运行/收尾阶段的问题。
    // 两者的用户动作完全不同（重装 vs 重开），文案不能混用
    static bool s_sessionStarted = false;

    // 下面三个都用于「不是本进程启动的」目标进程（GetProcessById 拿到的 EngineHost）。
    // .NET 对这类 Process 对象读退出状态可能抛 InvalidOperationException（没有句柄所有权）
    // 或 Win32Exception（medium 启动器打不开 high 完整性进程）。这些都属于「查不到」，
    // 不是致命错误：一旦让它们抛出去，真正的失败原因就会被掩盖成一句无关的报错。
    static bool ForeignHasExited(Process p) {
        try { return p.HasExited; }
        catch (InvalidOperationException) { }
        catch (System.ComponentModel.Win32Exception) { }
        // 查不到状态时按“仍在运行”处理：宁可多等一会儿，也不要误判成已退出而提前收尾
        return false;
    }

    static bool TryGetForeignExitCode(Process p, out int code) {
        code = 0;
        try {
            if (!p.HasExited) return false;
            code = p.ExitCode;
            return true;
        }
        catch (InvalidOperationException) { return false; }
        catch (System.ComponentModel.Win32Exception) { return false; }
    }

    // WaitForExit 需要 SYNCHRONIZE 权限，medium→high 会被拒；拿不到就退化成轮询
    static bool WaitForForeignExit(Process p, int timeoutMs) {
        try { return p.WaitForExit(timeoutMs); }
        catch (InvalidOperationException) { }
        catch (System.ComponentModel.Win32Exception) { }
        var sw = System.Diagnostics.Stopwatch.StartNew();
        while (sw.ElapsedMilliseconds < timeoutMs) {
            if (ForeignHasExited(p)) return true;
            System.Threading.Thread.Sleep(150);
        }
        return ForeignHasExited(p);
    }

    static Process StartEngineHostWithPolicyFallback(ProcessStartInfo direct, string hostPath,
        string pipeName, string session, out bool usedFallback) {
        usedFallback = false;
        try { return Process.Start(direct); }
        catch (System.ComponentModel.Win32Exception ex) {
            if (ex.NativeErrorCode != 8235) throw;
            usedFallback = true;
            // Some managed PCs enable "Only elevate executables that are signed and validated".
            // EngineHost has no commercial Authenticode certificate yet, so ShellExecute returns
            // ERROR_DS_REFERRAL (8235). The launcher has already verified the protected root and
            // exact EngineHost hash; use the Microsoft-signed system PowerShell only as a fixed,
            // argument-free compatibility boundary, then keep the same authenticated pipe session.
            MessageBox.Show(
                "当前电脑只允许直接提升已签名程序。软件将使用 Windows 自带的已签名 PowerShell 启动已校验的管理员助手。\n\n" +
                "本次 UAC 窗口会显示 Windows PowerShell；确认一次后，本次软件会话不会再次询问。",
                "三角洲行动优化助手", MessageBoxButtons.OK, MessageBoxIcon.Information);
            string command = "& " + QuotePowerShellLiteral(hostPath) +
                " --launch-pipe " + QuotePowerShellLiteral(pipeName) +
                " --launcher-pid " + Process.GetCurrentProcess().Id.ToString(System.Globalization.CultureInfo.InvariantCulture) +
                " --session " + QuotePowerShellLiteral(session) + "; exit $LASTEXITCODE";
            string encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(command));
            string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
            var fallback = new ProcessStartInfo();
            fallback.FileName = Path.Combine(windows, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
            fallback.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand " + encoded;
            fallback.WorkingDirectory = Environment.GetFolderPath(Environment.SpecialFolder.System);
            fallback.UseShellExecute = true;
            fallback.Verb = "runas";
            fallback.WindowStyle = ProcessWindowStyle.Hidden;
            return Process.Start(fallback);
        }
    }

    static void LaunchEngineHost(string root, bool repairOnly) {
        string nonce = RandomHex();
        string session = RandomHex();
        string pipeName = "DeltaForceBooster.Launch." + nonce;
        using (var pipe = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1,
            PipeTransmissionMode.Byte, PipeOptions.Asynchronous, 4096, 4096, CreateLaunchPipeSecurity())) {
            string hostPath = Path.Combine(root, "EngineHost.exe");
            var psi = new ProcessStartInfo();
            psi.FileName = hostPath;
            psi.Arguments = "--launch-pipe " + pipeName + " --launcher-pid " +
                Process.GetCurrentProcess().Id.ToString(System.Globalization.CultureInfo.InvariantCulture) + " --session " + session;
            psi.WorkingDirectory = Environment.GetFolderPath(Environment.SpecialFolder.System);
            psi.UseShellExecute = true;
            psi.Verb = "runas";
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            Process elevationProcess = null;
            bool usedPolicyFallback;
            Dictionary<string,string> savedEnvironment = EnterTrustedElevationEnvironment();
            try { elevationProcess = StartEngineHostWithPolicyFallback(psi, hostPath, pipeName, session, out usedPolicyFallback); }
            finally { RestoreProcessEnvironment(savedEnvironment); }
            using (Process elevation = elevationProcess) {
                if (elevation == null) throw new InvalidOperationException("EngineHost 进程未启动");

                IAsyncResult pending = pipe.BeginWaitForConnection(null, null);
                if (!pending.AsyncWaitHandle.WaitOne(TimeSpan.FromSeconds(60)))
                    throw new TimeoutException("管理员助手未在限定时间内建立安全会话");
                pipe.EndWaitForConnection(pending);
                uint clientPid;
                if (!GetNamedPipeClientProcessId(pipe.SafePipeHandle, out clientPid) || clientPid == 0)
                    throw new InvalidOperationException("无法确认 EngineHost 管道客户端");
                if (!usedPolicyFallback && clientPid != (uint)elevation.Id)
                    throw new InvalidOperationException("管道客户端不是刚启动的 EngineHost");
                var reader = new BinaryReader(pipe, new UTF8Encoding(false), true);
                var writer = new BinaryWriter(pipe, new UTF8Encoding(false), true);
                if (reader.ReadString() != "DFB_ENGINE_HOST/1" || reader.ReadInt32() != (int)clientPid || reader.ReadString() != session)
                    throw new InvalidOperationException("EngineHost 会话握手内容无效");
                using (Process host = Process.GetProcessById((int)clientPid)) {
                SecurityIdentifier userSid = WindowsIdentity.GetCurrent().User;
                string localAppData = Path.GetFullPath(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)).TrimEnd(Path.DirectorySeparatorChar);
                if (userSid == null || !userSid.IsAccountSid() || !Directory.Exists(localAppData) ||
                    PathHasReparsePoint(localAppData) || new DriveInfo(Path.GetPathRoot(localAppData)).DriveType != DriveType.Fixed)
                    throw new InvalidOperationException("原交互用户上下文不可验证");
                writer.Write("DFB_LAUNCHER_OK/2");
                writer.Write(Process.GetCurrentProcess().Id);
                writer.Write(userSid.Value);
                writer.Write(localAppData);
                writer.Write(repairOnly);
                writer.Flush();
                s_sessionStarted = true;

                // asInvoker 启动器在整个 GUI 生命周期内保留：它既在 UAC 前持有
                // 单实例 mutex，也作为唯一的 medium-token broker。EngineHost 只能
                // 通过已认证的这条管道请求固定动作，不能把任意命令交给低权限端。
                bool sessionCompleted = false;
                while (true) {
                    string message;
                    try { message = reader.ReadString(); }
                    catch (EndOfStreamException) { break; }
                    catch (IOException) { if (ForeignHasExited(host)) break; throw; }
                    if (message == "DFB_ENGINE_DONE/1") {
                        if (reader.ReadString() != session) throw new InvalidOperationException("管理员助手结束会话标记无效");
                        sessionCompleted = true;
                        break;
                    }
                    if (message != "DFB_LOW_REQUEST/1" || reader.ReadString() != session)
                        throw new InvalidOperationException("管理员助手 broker 请求协议无效");
                    string action = reader.ReadString();
                    string payload = reader.ReadString();
                    if (action.Length > 64 || payload.Length > 4096) throw new InvalidOperationException("管理员助手 broker 请求超过大小上限");
                    WorkerResult result;
                    try { result = HandleLowRequest(root, action, payload); }
                    catch (Exception ex) { result = new WorkerResult { Ok = false, Payload = ex.Message }; }
                    writer.Write("DFB_LOW_REPLY/1");
                    writer.Write(result.Ok);
                    WriteBoundedUtf8(writer, result.Payload, MaxBrokerPayloadBytes);
                    writer.Flush();
                }
                if (!WaitForForeignExit(host, 30000))
                    throw new TimeoutException("管理员助手结束会话后未在 30 秒内退出");
                // host 来自 GetProcessById，不是本对象启动的：直接读 ExitCode 会抛
                // “进程不是由此对象启动的，因此无法确定所请求的信息”，把 EngineHost
                // 真正的失败原因整个盖掉，用户只看到一句与病因无关的话。读不到退出码
                // 本身不是错误——报错路径绝不允许自己再抛一次异常
                int hostExitCode;
                if (TryGetForeignExitCode(host, out hostExitCode)) {
                    if (hostExitCode != 0)
                        throw new InvalidOperationException("管理员助手异常退出（退出码 " + hostExitCode + "）");
                } else if (!sessionCompleted) {
                    throw new InvalidOperationException("管理员助手在会话正常结束前退出，且无法读取其退出码");
                }
                }
                if (!elevation.HasExited && !elevation.WaitForExit(30000))
                    throw new TimeoutException("管理员启动边界未在 30 秒内退出");
            }
        }
    }

#if DFB_TESTING
    static bool WriteAlreadyRunningTestMarker() {
        string raw = Environment.GetEnvironmentVariable("DFB_TEST_ALREADY_RUNNING_LOG");
        if (String.IsNullOrEmpty(raw)) return false;
        string full = Path.GetFullPath(raw);
        string testRoot = Path.GetFullPath(Path.Combine(Path.GetTempPath(), "DeltaForceBooster-Tests")).TrimEnd('\\') + "\\";
        string parent = Path.GetDirectoryName(full);
        if (!full.StartsWith(testRoot, StringComparison.OrdinalIgnoreCase) || String.IsNullOrEmpty(parent) ||
            !Directory.Exists(parent) || PathHasReparsePoint(parent))
            throw new InvalidOperationException("单实例测试结果路径越界");
        using (var stream = new FileStream(full, FileMode.CreateNew, FileAccess.Write, FileShare.None))
        using (var writer = new StreamWriter(stream, new UTF8Encoding(false))) writer.Write("already-running");
        return true;
    }
#endif

    [STAThread]
    static void Main() {
        Mutex marker = null;
        try {
            DfbTokenFacts token = DfbTokenValidation.FromCurrentProcess();
            bool currentAdmin = new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
            bool repairOnly = IsRepairOnlyToken(token, currentAdmin);
            if (!token.IsMedium && !repairOnly)
                throw new InvalidOperationException("当前 Windows 会话令牌不是可用的普通或管理员交互令牌。");
            bool createdNew;
            try { marker = CreateSessionMarker(out createdNew); }
            catch (UnauthorizedAccessException) { createdNew = false; }
            if (!createdNew) {
#if DFB_TESTING
                if (WriteAlreadyRunningTestMarker()) return;
#endif
                MessageBox.Show("软件已经在运行，请使用已经打开的窗口。", "三角洲行动优化助手",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            string root = AppDomain.CurrentDomain.BaseDirectory;
            string validationError = ValidateFiles(root);
            if (validationError != null) {
                MessageBox.Show("程序文件不完整或已被修改：" + validationError +
                    "\n\n为避免运行异常文件，启动已停止。请从官网重新安装完整版本。",
                    "三角洲行动优化助手", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }
            LaunchEngineHost(root, repairOnly);
        } catch (Exception ex) {
            string reason;
            if (ex is System.ComponentModel.Win32Exception && ((System.ComponentModel.Win32Exception)ex).NativeErrorCode == 1223)
                reason = "已取消管理员授权，软件未启动。";
            else if (s_sessionStarted)
                // 会话已经建起来过，问题出在运行或收尾阶段：让用户重开而不是去重装
                reason = "运行过程中出现问题：" + ex.Message + "\n\n软件已退出，可以重新打开试试。";
            else
                reason = "启动失败：" + ex.Message;
            MessageBox.Show(reason, "三角洲行动优化助手", MessageBoxButtons.OK, MessageBoxIcon.Error);
        } finally {
            if (marker != null) marker.Dispose();
        }
    }
}
"@
$csFile = Join-Path $work 'launcher.cs'
[IO.File]::WriteAllText($csFile, $cs, (New-Object Text.UTF8Encoding($true)))

# ---------- 4. 编译到项目根目录 ----------
$exe = Join-Path $root '启动优化工具.exe'
$defineArgs = @($(if ($TestBuild) { '/define:DFB_TESTING' }))
$runtimeValidation = Join-Path $PSScriptRoot 'runtime-root-validation.cs'
$tokenValidation = Join-Path $PSScriptRoot 'token-validation.cs'
& $csc /nologo /target:winexe /platform:anycpu /optimize+ `
  /out:"$exe" /win32icon:"$icoFile" /win32manifest:"$manifestFile" `
  /r:System.Windows.Forms.dll @defineArgs "$runtimeValidation" "$tokenValidation" "$csFile"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { throw "csc 编译失败（退出码 $LASTEXITCODE）" }

Remove-Item $work -Recurse -Force
$fi = Get-Item -LiteralPath $exe
"构建完成：$($fi.FullName)"
"  大小 : {0:N0} KB" -f ($fi.Length / 1KB)
"  版本 : $($fi.VersionInfo.FileVersion)  描述 : $($fi.VersionInfo.FileDescription)"
