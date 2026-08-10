<#
  DeltaForceBooster 管理员会话宿主构建脚本。

  EngineHost.exe 是唯一的 UAC 边界：它带 requireAdministrator 清单，复验安装身份、
  受保护目录和发布哈希后，在整个 GUI 生命周期内保持管理员令牌。原交互用户的
  SID/LocalAppData 由通过 PID/路径/双向管道认证、且全生命周期存活的 asInvoker
  启动器提供，不信任 UAC 后的管理员账户环境变量；所有低权限动作也只经该管道转发。

  用法：powershell -NoProfile -ExecutionPolicy Bypass -File build\make-engine-host.ps1
#>
#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "dfb-engine-host-$PID"
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {
  # Clean build 先生成最终 app.ico；EngineHost 固化其哈希后，make-installer 再构建
  # launcher。IconOnly 不读取 EngineHost，因此不会形成构建环。
  $trustedPowerShell = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
  & $trustedPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make-launcher.ps1') -IconOnly
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $root 'gui\app.ico') -PathType Leaf)) {
    throw "生成最终 app.ico 失败（退出码 $LASTEXITCODE）"
  }
  $guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'
  $guiText = [IO.File]::ReadAllText($guiPath, [Text.Encoding]::UTF8)
  if ($guiText -notmatch '\$script:GuiVersion\s*=\s*''([\d.]+)''') { throw '无法从 GUI 文件解析版本号' }
  $ver = $Matches[1]
  $verParts = @($ver -split '\.') + @('0', '0', '0', '0')
  $ver4 = ($verParts[0..3]) -join '.'

  # 这些文件会在提权后被 GUI 点源加载或直接执行，必须全部在宿主内固化哈希。
  $hashFiles = @(
    'gui\DeltaForceBooster-GUI.ps1', 'gui\app.ico',
    'scripts\delta-booster.ps1', 'scripts\diagnose.ps1', 'scripts\updater.ps1',
    'scripts\telemetry-client.ps1', 'scripts\tuning-experiment.ps1', 'scripts\user-context-worker.ps1',
    'tools\PresentMon.exe'
  )
  $hashRows = foreach ($rel in $hashFiles) {
    $path = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "EngineHost 哈希白名单文件缺失：$rel" }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToUpperInvariant()
    '        new string[] { @"' + $rel + '", "' + $hash + '" }'
  }
  $hashRowsText = $hashRows -join ",`r`n"

  $windowsDir = Split-Path -Parent ([Environment]::SystemDirectory)
  $csc = Join-Path $windowsDir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  if (-not (Test-Path -LiteralPath $csc -PathType Leaf)) {
    $csc = Join-Path $windowsDir 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
  }
  if (-not (Test-Path -LiteralPath $csc -PathType Leaf)) { throw '本机没有 .NET Framework csc.exe，无法编译 EngineHost' }

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
  $manifestFile = Join-Path $work 'EngineHost.manifest'
  [IO.File]::WriteAllText($manifestFile, $manifest, (New-Object Text.UTF8Encoding($false)))

  $cs = @"
using System;
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

[assembly: AssemblyTitle("三角洲行动优化助手 管理员助手")]
[assembly: AssemblyDescription("三角洲行动优化助手 管理员助手")]
[assembly: AssemblyProduct("DeltaForceBooster")]
[assembly: AssemblyCompany("DeltaForceBooster 开源项目")]
[assembly: AssemblyCopyright("DeltaForceBooster MIT 开源项目")]
[assembly: AssemblyVersion("$ver4")]
[assembly: AssemblyFileVersion("$ver4")]

static class EngineHost {
    const string SessionMarkerName = @"Global\DeltaForceBooster.LaunchSession";
    const int MaxBrokerPayloadBytes = 24 * 1024 * 1024;
    const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    static readonly string[][] RequiredFiles = new string[][] {
$hashRowsText
    };

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(uint access, bool inheritHandle, uint processId);
    // 必须显式 Unicode：DllImport 默认 CharSet.Ansi 会绑到 ...NameA，按系统 ANSI 代码页转字符串。
    // 启动器叫「启动优化工具.exe」，在非中文区域设置（本机 ACP=1252）上中文全变成 ?，随后
    // .NET Framework 的 Path.GetFullPath 把 ? 当通配符拒绝，抛「路径中具有非法字符」——
    // EngineHost 启动即死，而弹出的报错与真因毫无关系
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool QueryFullProcessImageName(IntPtr process, int flags, StringBuilder path, ref int size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetNamedPipeServerProcessId(Microsoft.Win32.SafeHandles.SafePipeHandle pipe, out uint processId);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetNamedPipeClientProcessId(Microsoft.Win32.SafeHandles.SafePipeHandle pipe, out uint processId);

    sealed class WorkerResult {
        public bool Ok; public string Payload;
    }

    sealed class LauncherSession : IDisposable {
        public readonly NamedPipeClientStream Pipe;
        public readonly BinaryReader Reader;
        public readonly BinaryWriter Writer;
        public readonly string Session;
        public string OriginalSid;
        public string OriginalLocalAppData;
        public bool RepairOnly;

        public LauncherSession(NamedPipeClientStream pipe, string session) {
            Pipe = pipe;
            Session = session;
            Reader = new BinaryReader(pipe, new UTF8Encoding(false), true);
            Writer = new BinaryWriter(pipe, new UTF8Encoding(false), true);
        }

        public WorkerResult Request(string action, string payload) {
            Writer.Write("DFB_LOW_REQUEST/1");
            Writer.Write(Session);
            Writer.Write(action);
            Writer.Write(payload ?? "");
            Writer.Flush();
            if (Reader.ReadString() != "DFB_LOW_REPLY/1") throw new InvalidOperationException("低权限 broker 回复协议无效");
            var result = new WorkerResult();
            result.Ok = Reader.ReadBoolean();
            result.Payload = ReadBoundedUtf8(Reader, MaxBrokerPayloadBytes);
            return result;
        }

        public void Complete() {
            Writer.Write("DFB_ENGINE_DONE/1");
            Writer.Write(Session);
            Writer.Flush();
        }

        public void Dispose() { Reader.Dispose(); Writer.Dispose(); Pipe.Dispose(); }
    }

    static string Sha256(string path) {
        using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
        using (var sha = SHA256.Create())
            return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
    }

    static bool IsSha256(string value) {
        if (String.IsNullOrEmpty(value) || value.Length != 64) return false;
        foreach (char c in value)
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return false;
        return true;
    }

    static bool IsHex32(string value) {
        if (String.IsNullOrEmpty(value) || value.Length != 32) return false;
        foreach (char c in value)
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return false;
        return true;
    }

    static string RandomHex() {
        byte[] bytes = new byte[16];
        using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(bytes);
        return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant();
    }

    static bool PathHasReparsePoint(string path) {
        try {
            string full = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar);
            string root = Path.GetPathRoot(full);
            string current = root;
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0) return true;
            string rest = full.Substring(root.Length);
            foreach (string part in rest.Split(new char[] { '\\' }, StringSplitOptions.RemoveEmptyEntries)) {
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

    static string ValidateIdentity(string root) {
        string identity = Path.Combine(root, "install.identity");
        string launcher = Path.Combine(root, "启动优化工具.exe");
        string engineHost = Path.Combine(root, "EngineHost.exe");
        if (!File.Exists(identity) || !File.Exists(launcher)) return "install.identity 缺失";
        if (PathHasReparsePoint(identity) || PathHasReparsePoint(launcher) ||
            (File.Exists(engineHost) && PathHasReparsePoint(engineHost))) return "安装身份位于重解析点路径";
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
            if (!IsSha256(expected) || !String.Equals(Sha256(launcher), expected, StringComparison.OrdinalIgnoreCase))
                return "启动器与安装身份不匹配";
            if (v2) {
                if (!lines[3].StartsWith("EngineHostSha256=", StringComparison.Ordinal) || !File.Exists(engineHost))
                    return "管理员助手安装身份缺失";
                string hostExpected = lines[3].Substring("EngineHostSha256=".Length);
                if (!IsSha256(hostExpected) || !String.Equals(Sha256(engineHost), hostExpected, StringComparison.OrdinalIgnoreCase))
                    return "管理员助手与安装身份不匹配";
            }
            return null;
        } catch (Exception ex) { return "安装身份校验失败：" + ex.Message; }
    }

    static string ValidateFiles(string root) {
        string error = ValidateProtectedRoot(root);
        if (error != null) return error;
        error = ValidateIdentity(root);
        if (error != null) return error;
        string prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        foreach (string[] item in RequiredFiles) {
            string path = Path.GetFullPath(Path.Combine(root, item[0]));
            if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || !File.Exists(path)) return item[0] + " 缺失";
            if (PathHasReparsePoint(path)) return item[0] + " 位于重解析点路径";
            try {
                if (!String.Equals(Sha256(path), item[1], StringComparison.OrdinalIgnoreCase)) return item[0] + " 完整性校验失败";
            } catch (Exception ex) { return item[0] + " 校验失败：" + ex.Message; }
        }
        return null;
    }

    static string QueryProcessPath(IntPtr process) {
        var path = new StringBuilder(32768);
        int size = path.Capacity;
        if (!QueryFullProcessImageName(process, 0, path, ref size))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "无法读取启动器路径");
        return Path.GetFullPath(path.ToString());
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

    static DfbTokenFacts ValidateLauncherProcess(uint launcherPid, string root) {
        IntPtr process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, launcherPid);
        if (process == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "无法打开原启动器进程");
        try {
            string expected = Path.GetFullPath(Path.Combine(root, "启动优化工具.exe"));
            if (!String.Equals(QueryProcessPath(process), expected, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("原启动器进程路径不匹配");
            return DfbTokenValidation.FromProcessHandle(process);
        } finally { CloseHandle(process); }
    }

    static int ReadUacPolicy(string name, int defaultValue) {
        try {
            using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"))
                return key == null ? defaultValue : Convert.ToInt32(key.GetValue(name, defaultValue));
        } catch { return defaultValue; }
    }

    static bool IsRepairOnlyToken(DfbTokenFacts token) {
        if (token == null || token.IsMedium || !token.Elevated || token.IntegrityRid < 0x3000) return false;
        if (ReadUacPolicy("EnableLUA", 1) == 0) return true;
        return token.Sid != null && token.Sid.EndsWith("-500", StringComparison.Ordinal) &&
            ReadUacPolicy("FilterAdministratorToken", 0) != 1;
    }

    static string ReplaceIgnoreCase(string value, string token, string replacement) {
        int offset = 0;
        while (true) {
            int found = value.IndexOf(token, offset, StringComparison.OrdinalIgnoreCase);
            if (found < 0) return value;
            value = value.Substring(0, found) + replacement + value.Substring(found + token.Length);
            offset = found + replacement.Length;
        }
    }

    static string ExpandProfilePath(string raw, string profile, bool allowUserProfile) {
        if (String.IsNullOrWhiteSpace(raw)) throw new InvalidOperationException("原交互用户配置路径为空");
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string value = ReplaceIgnoreCase(raw.Trim(), "%SystemDrive%", Path.GetPathRoot(windows).TrimEnd('\\'));
        if (allowUserProfile) value = ReplaceIgnoreCase(value, "%USERPROFILE%", profile);
        if (value.IndexOf('%') >= 0) throw new InvalidOperationException("原交互用户配置路径含未允许的环境变量");
        return Path.GetFullPath(value).TrimEnd('\\');
    }

    static string ResolveOriginalLocalAppData(string sid) {
        string profileRaw;
        using (RegistryKey machine = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64))
        using (RegistryKey key = machine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" + sid)) {
            if (key == null) throw new InvalidOperationException("原交互用户没有 ProfileList 配置");
            profileRaw = Convert.ToString(key.GetValue("ProfileImagePath", null, RegistryValueOptions.DoNotExpandEnvironmentNames));
        }
        string profile = ExpandProfilePath(profileRaw, "", false);
        string shellRaw;
        using (RegistryKey users = RegistryKey.OpenBaseKey(RegistryHive.Users, RegistryView.Default))
        using (RegistryKey key = users.OpenSubKey(sid + @"\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders")) {
            if (key == null) throw new InvalidOperationException("原交互用户注册表配置未加载");
            shellRaw = Convert.ToString(key.GetValue("Local AppData", null, RegistryValueOptions.DoNotExpandEnvironmentNames));
        }
        string shell = ExpandProfilePath(shellRaw, profile, true);
        string expected = Path.GetFullPath(Path.Combine(profile, "AppData", "Local")).TrimEnd('\\');
        if (!String.Equals(shell, expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("原交互用户 LocalAppData 与 ProfileList/User Shell Folders 不一致");
        if (!Directory.Exists(shell) || PathHasReparsePoint(shell) ||
            new DriveInfo(Path.GetPathRoot(shell)).DriveType != DriveType.Fixed)
            throw new InvalidOperationException("原交互用户 LocalAppData 不可验证");
        return shell;
    }

    static LauncherSession AuthenticateLauncher(string pipeName, string session, uint launcherPid, string root) {
        DfbTokenFacts launcherToken = ValidateLauncherProcess(launcherPid, root);
        var pipe = new NamedPipeClientStream(".", pipeName, PipeDirection.InOut, PipeOptions.None);
        try {
            pipe.Connect(30000);
            uint serverPid;
            if (!GetNamedPipeServerProcessId(pipe.SafePipeHandle, out serverPid) || serverPid != launcherPid)
                throw new InvalidOperationException("启动管道所有者不是已验证的启动器");
            var channel = new LauncherSession(pipe, session);
            channel.Writer.Write("DFB_ENGINE_HOST/1");
            channel.Writer.Write(Process.GetCurrentProcess().Id);
            channel.Writer.Write(session);
            channel.Writer.Flush();
            if (channel.Reader.ReadString() != "DFB_LAUNCHER_OK/2" || channel.Reader.ReadInt32() != (int)launcherPid)
                throw new InvalidOperationException("启动管道握手失败");
            string sidText = channel.Reader.ReadString();
            string localText = channel.Reader.ReadString();
            bool repairOnly = channel.Reader.ReadBoolean();
            SecurityIdentifier sid;
            try { sid = new SecurityIdentifier(sidText); }
            catch { throw new InvalidOperationException("原交互用户 SID 无效"); }
            string local = Path.GetFullPath(localText).TrimEnd(Path.DirectorySeparatorChar);
            if (!sid.IsAccountSid() || !String.Equals(sid.Value, launcherToken.Sid, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("管道自报 SID 与启动器真实进程令牌不匹配");
            if (launcherToken.SessionId != Process.GetCurrentProcess().SessionId)
                throw new InvalidOperationException("启动器不在当前交互会话");
            if (repairOnly) {
                if (!IsRepairOnlyToken(launcherToken))
                    throw new InvalidOperationException("UAC 修复会话的启动器令牌无效");
            } else if (!launcherToken.IsMedium) {
                throw new InvalidOperationException("启动器必须使用原交互用户的 Medium 非提升令牌");
            }
            string derivedLocal = ResolveOriginalLocalAppData(sid.Value);
            if (!String.Equals(local, derivedLocal, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("管道自报 LocalAppData 与系统用户配置不匹配");
            channel.OriginalSid = sid.Value;
            channel.OriginalLocalAppData = derivedLocal;
            channel.RepairOnly = repairOnly;
            return channel;
        } catch { pipe.Dispose(); throw; }
    }

    static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }

    static PipeSecurity CreateBrokerPipeSecurity(string originalSid, bool includeOriginalUser) {
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var security = new PipeSecurity();
        security.SetAccessRuleProtection(true, false);
        security.AddAccessRule(new PipeAccessRule(admins, PipeAccessRights.FullControl, AccessControlType.Allow));
        if (includeOriginalUser) {
            var user = new SecurityIdentifier(originalSid);
            security.AddAccessRule(new PipeAccessRule(user, PipeAccessRights.ReadWrite, AccessControlType.Allow));
        }
        return security;
    }

    static DirectorySecurity CreateAdminSystemDirectorySecurity() {
        var security = new DirectorySecurity();
        security.SetAccessRuleProtection(true, false);
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        security.SetOwner(admins);
        InheritanceFlags inherit = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
        security.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        security.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        return security;
    }

    static bool IsExactAdminSystemDirectory(string path) {
        try {
            if (!Directory.Exists(path) || PathHasReparsePoint(path)) return false;
            DirectorySecurity acl = Directory.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access);
            string owner = acl.GetOwner(typeof(SecurityIdentifier)).Value;
            if (owner != "S-1-5-18" && owner != "S-1-5-32-544" || !acl.AreAccessRulesProtected) return false;
            bool admins = false, system = false;
            foreach (FileSystemAccessRule rule in acl.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
                string sid = rule.IdentityReference.Value;
                if (rule.AccessControlType != AccessControlType.Allow || (sid != "S-1-5-18" && sid != "S-1-5-32-544") ||
                    (rule.FileSystemRights & FileSystemRights.FullControl) != FileSystemRights.FullControl) return false;
                if (sid == "S-1-5-18") system = true;
                if (sid == "S-1-5-32-544") admins = true;
            }
            return admins && system;
        } catch { return false; }
    }

    static void EnsureAdminSystemDirectory(string path) {
        var security = CreateAdminSystemDirectorySecurity();
        if (Directory.Exists(path)) {
            if (!IsExactAdminSystemDirectory(path)) throw new InvalidOperationException("受保护会话目录已被不安全地预占：" + path);
        } else {
            string parent = Path.GetDirectoryName(path);
            if (String.IsNullOrEmpty(parent) || PathHasReparsePoint(parent))
                throw new InvalidOperationException("受保护会话目录父路径不安全：" + path);
            Directory.CreateDirectory(path, security);
        }
        Directory.SetAccessControl(path, security);
        if (!IsExactAdminSystemDirectory(path)) throw new InvalidOperationException("受保护会话目录 ACL 校验失败：" + path);
    }

    static string CreateSessionTemp(string session) {
        string common = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
        string product = Path.Combine(common, "DeltaForceBooster");
        string tempRoot = Path.Combine(product, "session-temp");
        string sessionRoot = Path.Combine(tempRoot, session);
        EnsureAdminSystemDirectory(product);
        EnsureAdminSystemDirectory(tempRoot);
        EnsureAdminSystemDirectory(sessionRoot);
        return sessionRoot;
    }

    static void RemoveSessionTemp(string path) {
        try {
            if (!IsExactAdminSystemDirectory(path)) return;
            foreach (string entry in Directory.GetFileSystemEntries(path, "*", SearchOption.AllDirectories))
                if ((File.GetAttributes(entry) & FileAttributes.ReparsePoint) != 0) return;
            Directory.Delete(path, true);
        } catch { /* 安全目录留待后续会话清理，绝不放宽 ACL 或追随 reparse */ }
    }

    static Process StartGui(string root, string sid, string localAppData, string session, string controlPipe,
        string sessionTemp, uint launcherPid, bool repairOnly) {
        string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        string powershell = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
        string gui = Path.Combine(root, "gui", "DeltaForceBooster-GUI.ps1");
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
        string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        string machineModules = Path.Combine(programFiles, "WindowsPowerShell", "Modules");
        string systemModules = Path.Combine(Path.GetDirectoryName(powershell), "Modules");
        var psi = new ProcessStartInfo();
        psi.FileName = powershell;
        psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(gui);
        psi.WorkingDirectory = system;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        // EngineHost 是 high-IL 边界。子 GUI 不得继承批准账户或调用方的用户环境，
        // 尤其是 CLR profiler、COMPlus、PATH 和 PowerShell 模块注入变量。
        psi.EnvironmentVariables.Clear();
        psi.EnvironmentVariables["SystemRoot"] = windows;
        psi.EnvironmentVariables["WINDIR"] = windows;
        psi.EnvironmentVariables["SystemDrive"] = Path.GetPathRoot(windows).TrimEnd('\\');
        psi.EnvironmentVariables["COMSPEC"] = Path.Combine(system, "cmd.exe");
        psi.EnvironmentVariables["PATH"] = system + Path.PathSeparator + windows + Path.PathSeparator +
            Path.Combine(system, "Wbem") + Path.PathSeparator + Path.Combine(system, "WindowsPowerShell", "v1.0");
        psi.EnvironmentVariables["PATHEXT"] = ".COM;.EXE;.BAT;.CMD";
        psi.EnvironmentVariables["ProgramData"] = programData;
        psi.EnvironmentVariables["ALLUSERSPROFILE"] = programData;
        psi.EnvironmentVariables["ProgramFiles"] = programFiles;
        if (!String.IsNullOrEmpty(programFilesX86)) psi.EnvironmentVariables["ProgramFiles(x86)"] = programFilesX86;
        psi.EnvironmentVariables["PSModulePath"] = systemModules + Path.PathSeparator + machineModules;
        psi.EnvironmentVariables["TEMP"] = sessionTemp;
        psi.EnvironmentVariables["TMP"] = sessionTemp;
        psi.EnvironmentVariables["DFB_ENGINE_HOST_PID"] = Process.GetCurrentProcess().Id.ToString(System.Globalization.CultureInfo.InvariantCulture);
        psi.EnvironmentVariables["DFB_LAUNCHER_PID"] = launcherPid.ToString(System.Globalization.CultureInfo.InvariantCulture);
        psi.EnvironmentVariables["DFB_ENGINE_HOST_SESSION"] = session;
        psi.EnvironmentVariables["DFB_ORIGINAL_USER_SID"] = sid;
        psi.EnvironmentVariables["DFB_ORIGINAL_LOCALAPPDATA"] = localAppData;
        psi.EnvironmentVariables["DFB_ENGINE_CONTROL_PIPE"] = controlPipe;
        psi.EnvironmentVariables["DFB_REPAIR_ONLY"] = repairOnly ? "1" : "0";
        Process guiProcess = Process.Start(psi);
        if (guiProcess == null) throw new InvalidOperationException("管理员主界面进程未启动");
        return guiProcess;
    }

    static int RunGuiAndServe(string root, string sid, string localAppData, string session, uint launcherPid, LauncherSession launcher) {
        string controlPipeName = "DeltaForceBooster.Engine." + RandomHex();
        string sessionTemp = CreateSessionTemp(session);
        using (Process guiProcess = StartGui(root, sid, localAppData, session, controlPipeName, sessionTemp, launcherPid, launcher.RepairOnly)) {
            try {
                while (!guiProcess.HasExited) {
                    using (var pipe = new NamedPipeServerStream(controlPipeName, PipeDirection.InOut, 1,
                        PipeTransmissionMode.Byte, PipeOptions.Asynchronous, 4096, MaxBrokerPayloadBytes,
                        CreateBrokerPipeSecurity(sid, false))) {
                        IAsyncResult pending = pipe.BeginWaitForConnection(null, null);
                        while (!pending.AsyncWaitHandle.WaitOne(200)) {
                            if (guiProcess.HasExited) return guiProcess.ExitCode;
                        }
                        pipe.EndWaitForConnection(pending);
                        uint clientPid;
                        if (!GetNamedPipeClientProcessId(pipe.SafePipeHandle, out clientPid) || clientPid != (uint)guiProcess.Id)
                            continue;
                        var reader = new BinaryReader(pipe, new UTF8Encoding(false), true);
                        var writer = new BinaryWriter(pipe, new UTF8Encoding(false), true);
                        try {
                            if (reader.ReadString() != "DFB_GUI_BROKER/1" || reader.ReadString() != session)
                                throw new InvalidOperationException("GUI broker 会话校验失败");
                            if (launcher.RepairOnly) throw new InvalidOperationException("UAC 修复会话不提供用户 broker 动作");
                            string action = reader.ReadString();
                            string payload = reader.ReadString();
                            if ((action != "MigrateLegacyData" && action != "ClearShaderCache" &&
                                 action != "GetGpuPanelApps" && action != "GetNvAutoOptStatus" &&
                                 action != "OpenUrl" && action != "OpenGpuPanel") || payload.Length > 4096)
                                throw new InvalidOperationException("GUI broker 动作或参数不在白名单");
                            WorkerResult result = launcher.Request(action, payload);
                            writer.Write("DFB_ENGINE_REPLY/1"); writer.Write(result.Ok);
                            WriteBoundedUtf8(writer, result.Payload, MaxBrokerPayloadBytes); writer.Flush();
                        } catch (Exception ex) {
                            writer.Write("DFB_ENGINE_REPLY/1"); writer.Write(false);
                            WriteBoundedUtf8(writer, ex.Message, MaxBrokerPayloadBytes); writer.Flush();
                        }
                    }
                }
                return guiProcess.ExitCode;
            } finally {
                launcher.Complete();
                RemoveSessionTemp(sessionTemp);
            }
        }
    }

    static void ShowError(string message) {
        MessageBox.Show("管理员助手已停止启动：" + message +
            "\n\n请只通过“启动优化工具.exe”打开；如果持续出现，请从官网重新安装完整版本。",
            "三角洲行动优化助手 管理员助手", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }

    [STAThread]
    static int Main(string[] args) {
        try {
            if (args.Length != 6 || args[0] != "--launch-pipe" || args[2] != "--launcher-pid" || args[4] != "--session")
                throw new InvalidOperationException("未收到有效的启动器会话");
            string pipeName = args[1];
            uint launcherPid;
            string session = args[5];
            if (!pipeName.StartsWith("DeltaForceBooster.Launch.", StringComparison.Ordinal) ||
                !IsHex32(pipeName.Substring("DeltaForceBooster.Launch.".Length)) ||
                !UInt32.TryParse(args[3], out launcherPid) || launcherPid == 0 || !IsHex32(session))
                throw new InvalidOperationException("启动器会话参数无效");

            using (WindowsIdentity current = WindowsIdentity.GetCurrent()) {
                if (!(new WindowsPrincipal(current)).IsInRole(WindowsBuiltInRole.Administrator))
                    throw new InvalidOperationException("未获得管理员令牌");
            }
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string validationError = ValidateFiles(root);
            if (validationError != null) throw new InvalidOperationException("程序文件不完整或已被修改：" + validationError);

            using (LauncherSession launcher = AuthenticateLauncher(pipeName, session, launcherPid, root)) {
                // asInvoker launcher 持有全生命周期 mutex；EngineHost 只打开同步句柄
                // 复验标记存在，不接管也不缩短低权限 broker 生命周期。
                using (Mutex marker = Mutex.OpenExisting(SessionMarkerName, MutexRights.Synchronize)) {
                    return RunGuiAndServe(root, launcher.OriginalSid, launcher.OriginalLocalAppData, session, launcherPid, launcher);
                }
            }
        } catch (Exception ex) {
            ShowError(ex.Message);
            return 1;
        }
    }
}
"@
  $source = Join-Path $work 'EngineHost.cs'
  [IO.File]::WriteAllText($source, $cs, (New-Object Text.UTF8Encoding($true)))

  $icon = Join-Path $root 'gui\app.ico'
  $exe = Join-Path $root 'EngineHost.exe'
  $runtimeValidation = Join-Path $PSScriptRoot 'runtime-root-validation.cs'
  $tokenValidation = Join-Path $PSScriptRoot 'token-validation.cs'
  & $csc /nologo /target:winexe /platform:anycpu /optimize+ `
    /out:"$exe" /win32icon:"$icon" /win32manifest:"$manifestFile" `
    /r:System.Windows.Forms.dll /r:System.Core.dll "$runtimeValidation" "$tokenValidation" "$source"
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "EngineHost csc 编译失败（退出码 $LASTEXITCODE）"
  }
  $fi = Get-Item -LiteralPath $exe
  "EngineHost 构建完成：$($fi.FullName)"
  "  大小 : {0:N0} KB" -f ($fi.Length / 1KB)
  "  版本 : $($fi.VersionInfo.FileVersion)  描述 : $($fi.VersionInfo.FileDescription)"
} finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
