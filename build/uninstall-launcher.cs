using System;
using System.Collections;
using System.Collections.Generic;
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

static class UninstallLauncher {
    const string HostSha256 = "__HOST_SHA256__";
    const string ScriptSha256 = "__SCRIPT_SHA256__";
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetNamedPipeClientProcessId(Microsoft.Win32.SafeHandles.SafePipeHandle pipe, out uint pid);
    static string Sha256(string path) { using (var s = File.OpenRead(path)) using (var h = SHA256.Create()) return BitConverter.ToString(h.ComputeHash(s)).Replace("-", ""); }
    static string RandomHex() { byte[] bytes = new byte[16]; using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(bytes); return BitConverter.ToString(bytes).Replace("-", "").ToLowerInvariant(); }
    static int Policy(string name, int fallback) { try { using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System")) return key == null ? fallback : Convert.ToInt32(key.GetValue(name, fallback)); } catch { return fallback; } }
    static bool RepairToken(DfbTokenFacts token, bool admin) {
        if (!admin || token.IsMedium || !token.Elevated || token.IntegrityRid < 0x3000) return false;
        if (Policy("EnableLUA", 1) == 0) return true;
        return token.Sid != null && token.Sid.EndsWith("-500", StringComparison.Ordinal) && Policy("FilterAdministratorToken", 0) != 1;
    }
    static bool MainSessionExists() { try { using (Mutex marker = Mutex.OpenExisting(@"Global\DeltaForceBooster.LaunchSession", MutexRights.Synchronize)) return true; } catch (WaitHandleCannotBeOpenedException) { return false; } catch (UnauthorizedAccessException) { return true; } }
    static PipeSecurity PipeAcl(string sid) {
        var acl = new PipeSecurity(); acl.SetAccessRuleProtection(true, false);
        acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(sid), PipeAccessRights.FullControl, AccessControlType.Allow));
        acl.AddAccessRule(new PipeAccessRule(new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null), PipeAccessRights.FullControl, AccessControlType.Allow)); return acl;
    }
    static Dictionary<string,string> EnterTrustedElevationEnvironment() {
        var saved = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        foreach (DictionaryEntry entry in Environment.GetEnvironmentVariables(EnvironmentVariableTarget.Process)) saved[(string)entry.Key] = Convert.ToString(entry.Value);
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows), system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        string programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), pfx = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        foreach (string key in new List<string>(saved.Keys)) Environment.SetEnvironmentVariable(key, null, EnvironmentVariableTarget.Process);
        Action<string,string> set = delegate(string k, string v) { if (!String.IsNullOrEmpty(v)) Environment.SetEnvironmentVariable(k, v, EnvironmentVariableTarget.Process); };
        set("SystemRoot", windows); set("WINDIR", windows); set("SystemDrive", Path.GetPathRoot(windows).TrimEnd('\\')); set("COMSPEC", Path.Combine(system, "cmd.exe"));
        set("PATH", system + Path.PathSeparator + windows + Path.PathSeparator + Path.Combine(system, "Wbem") + Path.PathSeparator + Path.Combine(system, "WindowsPowerShell", "v1.0"));
        set("PATHEXT", ".COM;.EXE;.BAT;.CMD"); set("TEMP", Path.Combine(windows, "Temp")); set("TMP", Path.Combine(windows, "Temp")); set("ProgramData", programData); set("ALLUSERSPROFILE", programData); set("ProgramFiles", pf); set("ProgramFiles(x86)", pfx); return saved;
    }
    static void RestoreEnvironment(Dictionary<string,string> saved) { foreach (DictionaryEntry entry in Environment.GetEnvironmentVariables(EnvironmentVariableTarget.Process)) Environment.SetEnvironmentVariable((string)entry.Key, null, EnvironmentVariableTarget.Process); foreach (var item in saved) Environment.SetEnvironmentVariable(item.Key, item.Value, EnvironmentVariableTarget.Process); }
    static void DeleteShortcut(string path) { try { if (File.Exists(path) && (File.GetAttributes(path) & FileAttributes.ReparsePoint) == 0) File.Delete(path); } catch { } }
    static void CleanUserShortcuts(bool medium) {
        if (!medium) return;
        string menu = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "DeltaForceBooster");
        try {
            if (Directory.Exists(menu) && (File.GetAttributes(menu) & FileAttributes.ReparsePoint) == 0) {
                DeleteShortcut(Path.Combine(menu, "三角洲行动优化助手.lnk")); DeleteShortcut(Path.Combine(menu, "卸载优化助手.lnk"));
                if (Directory.GetFileSystemEntries(menu).Length == 0) Directory.Delete(menu, false);
            }
        } catch { }
        DeleteShortcut(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "三角洲行动优化助手.lnk"));
    }
    [STAThread] static int Main() {
        try {
            DfbTokenFacts token = DfbTokenValidation.FromCurrentProcess();
            bool admin = new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
            if (!token.IsMedium && !RepairToken(token, admin)) throw new InvalidOperationException("请普通双击卸载入口，不要右键选择“以管理员身份运行”");
            if (MainSessionExists()) throw new InvalidOperationException("软件仍在运行，请先关闭主界面并等待优化/还原完成后再卸载");
            string root = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory).TrimEnd('\\');
            string layout = DfbRuntimeRoot.Validate(root); if (layout != null) throw new InvalidOperationException("安装布局校验失败：" + layout);
            string hostPath = Path.Combine(root, "UninstallHost.exe"), scriptPath = Path.Combine(root, "uninstall.ps1");
            if (!String.Equals(Sha256(hostPath), HostSha256, StringComparison.OrdinalIgnoreCase) || !String.Equals(Sha256(scriptPath), ScriptSha256, StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("卸载组件哈希校验失败");
            string pipeName = "DeltaForceBooster.Uninstall." + RandomHex(), session = RandomHex();
            using (var pipe = new NamedPipeServerStream(pipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous, 4096, 4096, PipeAcl(token.Sid))) {
                var psi = new ProcessStartInfo(hostPath, "--pipe " + pipeName + " --launcher-pid " + Process.GetCurrentProcess().Id + " --session " + session);
                psi.WorkingDirectory = Environment.GetFolderPath(Environment.SpecialFolder.System); psi.UseShellExecute = true; psi.Verb = "runas"; psi.WindowStyle = ProcessWindowStyle.Hidden;
                Process started = null; Dictionary<string,string> saved = EnterTrustedElevationEnvironment();
                try { started = Process.Start(psi); } finally { RestoreEnvironment(saved); }
                using (Process host = started) {
                    if (host == null) throw new InvalidOperationException("UninstallHost 未启动");
                    IAsyncResult pending = pipe.BeginWaitForConnection(null, null); if (!pending.AsyncWaitHandle.WaitOne(60000)) throw new TimeoutException("UninstallHost 连接超时"); pipe.EndWaitForConnection(pending);
                    uint clientPid; if (!GetNamedPipeClientProcessId(pipe.SafePipeHandle, out clientPid) || clientPid != (uint)host.Id) throw new InvalidOperationException("UninstallHost 管道 PID 不匹配");
                    var reader = new BinaryReader(pipe, new UTF8Encoding(false), true); var writer = new BinaryWriter(pipe, new UTF8Encoding(false), true);
                    if (reader.ReadString() != "DFB_UNINSTALL_HOST/1" || reader.ReadInt32() != host.Id || reader.ReadString() != session) throw new InvalidOperationException("UninstallHost 握手无效");
                    writer.Write("DFB_UNINSTALL_LAUNCHER/1"); writer.Write(Process.GetCurrentProcess().Id); writer.Write(token.Sid); writer.Write(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)); writer.Flush();
                    if (reader.ReadString() != "DFB_UNINSTALL_CLEAN_SHORTCUTS/1") throw new InvalidOperationException("UninstallHost 协议无效");
                    CleanUserShortcuts(token.IsMedium); writer.Write("DFB_UNINSTALL_SHORTCUTS_DONE/1"); writer.Flush();
                    if (reader.ReadString() != "DFB_UNINSTALL_HANDOFF/1") throw new InvalidOperationException("UninstallHost 未完成安全交棒");
                    host.WaitForExit(30000);
                }
            }
            return 0;
        } catch (Exception ex) {
            string message = ex is System.ComponentModel.Win32Exception && ((System.ComponentModel.Win32Exception)ex).NativeErrorCode == 1223 ? "已取消管理员授权，卸载未开始。" : "卸载程序启动失败：" + ex.Message;
            MessageBox.Show(message, "三角洲行动优化助手 卸载", MessageBoxButtons.OK, MessageBoxIcon.Error); return 1;
        }
    }
}
