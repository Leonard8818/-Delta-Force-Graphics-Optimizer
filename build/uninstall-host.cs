using System;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

static class UninstallHost {
    const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    const string ScriptSha256 = "__SCRIPT_SHA256__";
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool QueryFullProcessImageName(IntPtr process, int flags, StringBuilder path, ref int size);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetNamedPipeServerProcessId(Microsoft.Win32.SafeHandles.SafePipeHandle pipe, out uint pid);

    static string Sha256(string path) {
        using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
        using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
    }
    static bool Hex32(string value) {
        if (value == null || value.Length != 32) return false;
        foreach (char c in value) if (!Uri.IsHexDigit(c)) return false;
        return true;
    }
    static string ProcessPath(IntPtr process) {
        var text = new StringBuilder(32768); int length = text.Capacity;
        if (!QueryFullProcessImageName(process, 0, text, ref length)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        return Path.GetFullPath(text.ToString());
    }
    static DfbTokenFacts ValidateLauncher(uint pid, string root) {
        IntPtr process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (process == IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(), "无法打开卸载入口进程");
        try {
            if (!String.Equals(ProcessPath(process), Path.GetFullPath(Path.Combine(root, "卸载.exe")), StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("卸载入口进程路径不匹配");
            return DfbTokenValidation.FromProcessHandle(process);
        } finally { CloseHandle(process); }
    }
    static int Policy(string name, int fallback) {
        try { using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"))
            return key == null ? fallback : Convert.ToInt32(key.GetValue(name, fallback)); }
        catch { return fallback; }
    }
    static bool RepairToken(DfbTokenFacts token) {
        if (token == null || token.IsMedium || !token.Elevated || token.IntegrityRid < 0x3000) return false;
        if (Policy("EnableLUA", 1) == 0) return true;
        return token.Sid != null && token.Sid.EndsWith("-500", StringComparison.Ordinal) && Policy("FilterAdministratorToken", 0) != 1;
    }
    static string Replace(string value, string token, string replacement) {
        int offset = 0;
        while (true) { int found = value.IndexOf(token, offset, StringComparison.OrdinalIgnoreCase); if (found < 0) return value;
            value = value.Substring(0, found) + replacement + value.Substring(found + token.Length); offset = found + replacement.Length; }
    }
    static string Expand(string raw, string profile, bool userProfile) {
        if (String.IsNullOrWhiteSpace(raw)) throw new InvalidOperationException("原用户配置路径为空");
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string value = Replace(raw.Trim(), "%SystemDrive%", Path.GetPathRoot(windows).TrimEnd('\\'));
        if (userProfile) value = Replace(value, "%USERPROFILE%", profile);
        if (value.IndexOf('%') >= 0) throw new InvalidOperationException("原用户配置路径含未允许的环境变量");
        return Path.GetFullPath(value).TrimEnd('\\');
    }
    static string ResolveLocalAppData(string sid) {
        string profileRaw, localRaw;
        using (RegistryKey lm = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64))
        using (RegistryKey key = lm.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" + sid)) {
            if (key == null) throw new InvalidOperationException("原用户 ProfileList 不存在");
            profileRaw = Convert.ToString(key.GetValue("ProfileImagePath", null, RegistryValueOptions.DoNotExpandEnvironmentNames));
        }
        string profile = Expand(profileRaw, "", false);
        using (RegistryKey users = RegistryKey.OpenBaseKey(RegistryHive.Users, RegistryView.Default))
        using (RegistryKey key = users.OpenSubKey(sid + @"\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders")) {
            if (key == null) throw new InvalidOperationException("原用户注册表配置单元未加载");
            localRaw = Convert.ToString(key.GetValue("Local AppData", null, RegistryValueOptions.DoNotExpandEnvironmentNames));
        }
        string local = Expand(localRaw, profile, true);
        if (!String.Equals(local, Path.Combine(profile, "AppData", "Local"), StringComparison.OrdinalIgnoreCase) || !Directory.Exists(local))
            throw new InvalidOperationException("原用户 LocalAppData 与系统配置不匹配");
        return local;
    }
    static bool ValidateIdentity(string root) {
        try {
            string[] lines = File.ReadAllLines(Path.Combine(root, "install.identity"), new UTF8Encoding(false, true));
            bool v1 = lines.Length == 3 && lines[0] == "SchemaVersion=1";
            bool v2 = lines.Length == 4 && lines[0] == "SchemaVersion=2";
            if ((!v1 && !v2) || lines[1] != "ProductId=DeltaForceBooster" || !lines[2].StartsWith("LauncherSha256=")) return false;
            string launcherHash = lines[2].Substring("LauncherSha256=".Length);
            if (launcherHash.Length != 64 || !String.Equals(Sha256(Path.Combine(root, "启动优化工具.exe")), launcherHash, StringComparison.OrdinalIgnoreCase)) return false;
            if (v2) {
                if (!lines[3].StartsWith("EngineHostSha256=")) return false;
                string hostHash = lines[3].Substring("EngineHostSha256=".Length);
                if (hostHash.Length != 64 || !String.Equals(Sha256(Path.Combine(root, "EngineHost.exe")), hostHash, StringComparison.OrdinalIgnoreCase)) return false;
            }
            return true;
        } catch { return false; }
    }
    static DirectorySecurity AdminSystemDirectorySecurity() {
        var acl = new DirectorySecurity(); acl.SetAccessRuleProtection(true, false);
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null); acl.SetOwner(admins);
        var inherit = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
        acl.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        acl.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        return acl;
    }
    static bool ExactAdminSystemDirectory(string path) {
        try {
            if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) return false;
            var acl = Directory.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access);
            string owner = acl.GetOwner(typeof(SecurityIdentifier)).Value;
            if (owner != "S-1-5-32-544" && owner != "S-1-5-18" || !acl.AreAccessRulesProtected) return false;
            int count = 0; bool admins = false, system = false;
            foreach (FileSystemAccessRule rule in acl.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
                count++; string sid = rule.IdentityReference.Value;
                if (rule.IsInherited || rule.AccessControlType != AccessControlType.Allow || rule.FileSystemRights != FileSystemRights.FullControl ||
                    rule.InheritanceFlags != (InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit) || rule.PropagationFlags != PropagationFlags.None) return false;
                if (sid == "S-1-5-32-544") admins = true; else if (sid == "S-1-5-18") system = true; else return false;
            }
            return count == 2 && admins && system;
        } catch { return false; }
    }
    static void EnsureDirectory(string path) {
        if (Directory.Exists(path)) { if (!ExactAdminSystemDirectory(path)) throw new UnauthorizedAccessException("卸载暂存目录权限异常：" + path); return; }
        Directory.CreateDirectory(path, AdminSystemDirectorySecurity());
        if (!ExactAdminSystemDirectory(path)) throw new UnauthorizedAccessException("卸载暂存目录创建后复验失败：" + path);
    }
    static void SetAdminSystemFile(string path) {
        var acl = new FileSecurity(); acl.SetAccessRuleProtection(true, false);
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null); acl.SetOwner(admins);
        acl.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, AccessControlType.Allow));
        acl.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, AccessControlType.Allow));
        File.SetAccessControl(path, acl);
    }
    static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }
    static Process StartScript(string stagedScript, string stage, string root, string sid, string local, uint launcherPid) {
        string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        string ps = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
        var psi = new ProcessStartInfo(ps, "-NoProfile -ExecutionPolicy Bypass -File " + Quote(stagedScript) +
            " -InstallRoot " + Quote(root) + " -UserSid " + Quote(sid) + " -UserLocalAppData " + Quote(local) +
            " -WaitPid " + Process.GetCurrentProcess().Id + " -WaitPid2 " + launcherPid + " -StageRoot " + Quote(stage));
        psi.WorkingDirectory = system; psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.WindowStyle = ProcessWindowStyle.Hidden;
        string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
        string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        string temp = Path.Combine(stage, "temp"); EnsureDirectory(temp);
        psi.EnvironmentVariables.Clear();
        psi.EnvironmentVariables["SystemRoot"] = windows; psi.EnvironmentVariables["WINDIR"] = windows;
        psi.EnvironmentVariables["SystemDrive"] = Path.GetPathRoot(windows).TrimEnd('\\'); psi.EnvironmentVariables["COMSPEC"] = Path.Combine(system, "cmd.exe");
        psi.EnvironmentVariables["PATH"] = system + Path.PathSeparator + windows + Path.PathSeparator + Path.Combine(system, "Wbem") + Path.PathSeparator + Path.Combine(system, "WindowsPowerShell", "v1.0");
        psi.EnvironmentVariables["PATHEXT"] = ".COM;.EXE;.BAT;.CMD"; psi.EnvironmentVariables["ProgramData"] = programData;
        psi.EnvironmentVariables["ALLUSERSPROFILE"] = programData; psi.EnvironmentVariables["ProgramFiles"] = programFiles;
        if (!String.IsNullOrEmpty(programFilesX86)) psi.EnvironmentVariables["ProgramFiles(x86)"] = programFilesX86;
        psi.EnvironmentVariables["PSModulePath"] = Path.Combine(Path.GetDirectoryName(ps), "Modules") + Path.PathSeparator + Path.Combine(programFiles, "WindowsPowerShell", "Modules");
        psi.EnvironmentVariables["TEMP"] = temp; psi.EnvironmentVariables["TMP"] = temp;
        Process result = Process.Start(psi); if (result == null) throw new InvalidOperationException("卸载脚本进程未启动"); return result;
    }
    static bool MainSessionExists() {
        try { using (Mutex marker = Mutex.OpenExisting(@"Global\DeltaForceBooster.LaunchSession", MutexRights.Synchronize)) return true; }
        catch (WaitHandleCannotBeOpenedException) { return false; }
        catch (UnauthorizedAccessException) { return true; }
    }
    [STAThread] static int Main(string[] args) {
        try {
            if (args.Length != 6 || args[0] != "--pipe" || args[2] != "--launcher-pid" || args[4] != "--session" || !Hex32(args[5]))
                throw new InvalidOperationException("卸载入口会话参数无效");
            uint launcherPid; if (!UInt32.TryParse(args[3], out launcherPid) || launcherPid == 0 ||
                !args[1].StartsWith("DeltaForceBooster.Uninstall.", StringComparison.Ordinal) || !Hex32(args[1].Substring("DeltaForceBooster.Uninstall.".Length)))
                throw new InvalidOperationException("卸载入口会话参数无效");
            DfbTokenFacts self = DfbTokenValidation.FromCurrentProcess();
            if (!self.Elevated || self.IntegrityRid < 0x3000) throw new InvalidOperationException("UninstallHost 未获得管理员令牌");
            string root = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory).TrimEnd('\\');
            string layout = DfbRuntimeRoot.Validate(root); if (layout != null) throw new InvalidOperationException("安装布局校验失败：" + layout);
            if (!ValidateIdentity(root) || !String.Equals(Sha256(Path.Combine(root, "uninstall.ps1")), ScriptSha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("卸载组件产品身份或哈希校验失败");
            if (MainSessionExists()) throw new InvalidOperationException("软件仍在运行，请先关闭主界面并等待优化/还原完成后再卸载");
            DfbTokenFacts launcherToken = ValidateLauncher(launcherPid, root);
            using (var pipe = new NamedPipeClientStream(".", args[1], PipeDirection.InOut, PipeOptions.None)) {
                pipe.Connect(30000); uint serverPid;
                if (!GetNamedPipeServerProcessId(pipe.SafePipeHandle, out serverPid) || serverPid != launcherPid) throw new InvalidOperationException("卸载管道所有者不匹配");
                var reader = new BinaryReader(pipe, new UTF8Encoding(false), true); var writer = new BinaryWriter(pipe, new UTF8Encoding(false), true);
                writer.Write("DFB_UNINSTALL_HOST/1"); writer.Write(Process.GetCurrentProcess().Id); writer.Write(args[5]); writer.Flush();
                if (reader.ReadString() != "DFB_UNINSTALL_LAUNCHER/1" || reader.ReadInt32() != (int)launcherPid) throw new InvalidOperationException("卸载入口握手失败");
                string sid = reader.ReadString(), claimedLocal = reader.ReadString();
                if (!String.Equals(sid, launcherToken.Sid, StringComparison.OrdinalIgnoreCase) || launcherToken.SessionId != Process.GetCurrentProcess().SessionId ||
                    (!launcherToken.IsMedium && !RepairToken(launcherToken))) throw new InvalidOperationException("卸载入口真实令牌与原用户上下文不匹配");
                string local = ResolveLocalAppData(sid);
                if (!String.Equals(Path.GetFullPath(claimedLocal).TrimEnd('\\'), local, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("卸载入口 LocalAppData 自报值不匹配");
                writer.Write("DFB_UNINSTALL_CLEAN_SHORTCUTS/1"); writer.Flush();
                if (reader.ReadString() != "DFB_UNINSTALL_SHORTCUTS_DONE/1") throw new InvalidOperationException("原用户快捷方式清理未完成");
                string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
                string product = Path.Combine(programData, "DeltaForceBooster"), stages = Path.Combine(product, "uninstall-stage");
                EnsureDirectory(product); EnsureDirectory(stages); string stage = Path.Combine(stages, Guid.NewGuid().ToString("N")); EnsureDirectory(stage);
                string stagedScript = Path.Combine(stage, "uninstall.ps1");
                using (var input = new FileStream(Path.Combine(root, "uninstall.ps1"), FileMode.Open, FileAccess.Read, FileShare.Read))
                using (var output = new FileStream(stagedScript, FileMode.CreateNew, FileAccess.Write, FileShare.None)) { input.CopyTo(output); output.Flush(true); }
                SetAdminSystemFile(stagedScript);
                if (!String.Equals(Sha256(stagedScript), ScriptSha256, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("受保护卸载脚本暂存后哈希不匹配");
                using (Process script = StartScript(stagedScript, stage, root, sid, local, launcherPid)) { }
                writer.Write("DFB_UNINSTALL_HANDOFF/1"); writer.Flush();
            }
            return 0;
        } catch (Exception ex) {
            MessageBox.Show("卸载助手已停止：" + ex.Message, "三角洲行动优化助手 卸载助手", MessageBoxButtons.OK, MessageBoxIcon.Error); return 1;
        }
    }
}
