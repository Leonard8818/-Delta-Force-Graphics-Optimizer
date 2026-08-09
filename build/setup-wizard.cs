// DeltaForceBooster 图形安装向导 — 源码由 build\make-installer.ps1 注入版本号后用系统自带 csc 编译。
//
// 为什么是 C# + WPF 而不是沿用 IExpress：IExpress 的界面不可定制、无法让用户选安装位置；
// make-launcher.ps1 已验证「系统 csc 编译 + 内嵌图标/清单」这条零第三方依赖路线可行，这里沿用。
// 为什么 payload 内嵌为程序集资源（/resource:）：真正单文件分发，运行时直接从自身程序集解流，
// 不经过 IExpress 那种落盘自解压临时目录。
// 清单保持 asInvoker：向导先显示，真正写入默认 %ProgramFiles%\DeltaForceBooster 时才按需
// 提权重启（/dir= 回传已选路径）。主程序启动器同样是 asInvoker，不让整个 GUI 常驻管理员。
// 为什么快捷方式走 IShellLinkW COM：本机实测 ACP=1252 时 WScript.Shell 会把中文转成 "?"
// 导致快捷方式保存失败，必须用原生 Unicode 接口。
// 快捷方式落点（真机踩过「装完找不到入口」）：提权态一律写公共开始菜单/公共桌面——
// 提权后 %APPDATA% 指向提权账号，多账户机器上会把快捷方式建进管理员的开始菜单；
// 完成页默认勾选「创建桌面快捷方式」与「创建开始菜单快捷方式」（后者原先无条件创建，
// 现同样交给勾选项控制），静默模式两者都创建。
// 更新场景防双开（实机反馈）：旧版主程序可能没退干净，完成页勾了「立即运行」时先按
// 主窗口标题精确匹配礼貌请求旧实例关闭（WM_CLOSE）——绝不 Kill：旧实例可能正在执行
// 优化/还原，强杀等于把系统改到一半且备份写不完整。拒绝退出就放弃自动启动并明示用户。
// 静默更新覆盖前也检查其余旧窗口，并对杀毒/索引器造成的短暂文件共享冲突有限重试。
//
// 命令行（全部供自动化验证，普通用户双击即图形向导）：
//   /dir=<路径>        预填安装位置（提权重启时回传用）
//   /silent /log=<文件> 静默安装；非提权阶段可写调用者日志，提权阶段忽略任意日志路径
//   /waitpid=<进程Id>  静默安装前先等该进程退出（主程序占着自己的文件；等待超时视为
//                      「可能正在执行优化」，直接取消本次更新，绝不带伤覆盖）
//   /runafter          静默安装完成后启动新版主程序；失败时弹框报错，绝不假装成功
//   /sha256=<64 hex> /size=<字节>  内置更新传入的安装器预期完整性；启动第一时间复验自身
//   /checkdir=<路径>   仅 DFB_TESTING 构建：跑写入权限预检，结果写测试临时根
//   /render=<目录>     仅 DFB_TESTING 构建：离屏渲染页面并导出界面字符串
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using WShapes = System.Windows.Shapes;
using WinForms = System.Windows.Forms;

[assembly: AssemblyTitle("三角洲行动优化助手 安装向导")]
[assembly: AssemblyDescription("DeltaForceBooster 安装向导（可自选安装位置）")]
[assembly: AssemblyProduct("DeltaForceBooster")]
[assembly: AssemblyCompany("DeltaForceBooster 开源项目")]
[assembly: AssemblyCopyright("DeltaForceBooster MIT 开源项目")]
[assembly: AssemblyVersion("__VER4__")]
[assembly: AssemblyFileVersion("__VER4__")]

namespace DfbSetup {

static class Program {
    public const string Version = "__VER__";

    [STAThread]
    static void Main(string[] args) {
        string dir = null, logFile = null, renderDir = null, checkDir = null;
        bool silent = false, runAfter = false;
        bool migrationPrepared = false;
        string expectedSha256 = null;
        long expectedSize = -1;
        int waitPid = 0;
        foreach (string a in args) {
            if (a.Equals("/silent", StringComparison.OrdinalIgnoreCase)) silent = true;
            else if (a.Equals("/runafter", StringComparison.OrdinalIgnoreCase)) runAfter = true;
            else if (a.Equals("/migrationprepared", StringComparison.OrdinalIgnoreCase)) migrationPrepared = true;
            else if (a.StartsWith("/dir=", StringComparison.OrdinalIgnoreCase)) dir = a.Substring(5).Trim('"');
            else if (a.StartsWith("/log=", StringComparison.OrdinalIgnoreCase)) logFile = a.Substring(5).Trim('"');
            else if (a.StartsWith("/waitpid=", StringComparison.OrdinalIgnoreCase)) int.TryParse(a.Substring(9).Trim('"'), out waitPid);
            else if (a.StartsWith("/render=", StringComparison.OrdinalIgnoreCase)) renderDir = a.Substring(8).Trim('"');
            else if (a.StartsWith("/checkdir=", StringComparison.OrdinalIgnoreCase)) checkDir = a.Substring(10).Trim('"');
            else if (a.StartsWith("/sha256=", StringComparison.OrdinalIgnoreCase)) expectedSha256 = a.Substring(8).Trim('"');
            else if (a.StartsWith("/size=", StringComparison.OrdinalIgnoreCase)) long.TryParse(a.Substring(6).Trim('"'), out expectedSize);
        }
        // /log、/render、/checkdir 都能造成文件写入。提权进程绝不使用调用者传入的
        // 任意路径；自动化入口只存在于单独的 DFB_TESTING 构建且被限制在测试临时根。
        if (Installer.IsElevated()) logFile = null;
        if (checkDir != null && !Installer.TestAutomationPath(checkDir)) { Environment.Exit(6); return; }
        if (renderDir != null && !Installer.TestAutomationPath(renderDir)) { Environment.Exit(6); return; }
        string selfError = VerifySelfIntegrity(expectedSha256, expectedSize);
        if (selfError != null) {
            Log(logFile, "安装器启动复验失败: " + selfError);
            if (runAfter) WarnBox("更新安装包在启动前复验失败，已停止安装。\r\n\r\n" + selfError + "\r\n\r\n请重新检查更新或从官网下载。 ");
            Environment.Exit(5); return;
        }
        if (checkDir != null) { Environment.Exit(RunCheck(checkDir, logFile)); return; }
        if (silent)           { Environment.Exit(RunSilent(dir, logFile, waitPid, runAfter, migrationPrepared, args)); return; }
        if (renderDir != null) { RunRender(renderDir); return; }
        var app = new Application();
        app.Run(new SetupWindow(dir));
    }

    // 更新器把同名 .integrity 放在已封闭 ACL 的 staging 目录中。这样旧 GUI 即使还没有传
    // /sha256 与 /size，安装器也会在启动第一时间复验；新 GUI 两种来源必须一致。
    static string VerifySelfIntegrity(string expectedSha256, long expectedSize) {
        try {
            string self = Assembly.GetExecutingAssembly().Location;
            string sidecar = self + ".integrity";
            if (File.Exists(sidecar)) {
                string[] lines = File.ReadAllLines(sidecar, Encoding.ASCII);
                if (lines.Length != 2) return "完整性元数据格式错误";
                long sideSize;
                if (!long.TryParse(lines[1].Trim(), out sideSize)) return "完整性元数据大小无效";
                string sideSha = lines[0].Trim();
                if (expectedSha256 != null && !string.Equals(expectedSha256, sideSha, StringComparison.OrdinalIgnoreCase))
                    return "命令行哈希与受保护元数据不一致";
                if (expectedSize >= 0 && expectedSize != sideSize) return "命令行大小与受保护元数据不一致";
                expectedSha256 = sideSha;
                expectedSize = sideSize;
            }
            bool hasSha = !string.IsNullOrEmpty(expectedSha256);
            bool hasSize = expectedSize >= 0;
            if (hasSha != hasSize) return "安装器完整性参数不完整";
            if (!hasSha) return null; // 官网手动下载的独立安装包没有 sidecar，维持兼容。
            if (!Installer.IsSha256(expectedSha256) || expectedSize <= 0) return "安装器完整性参数无效";
            var fi = new FileInfo(self);
            if (fi.Length != expectedSize) return "安装器大小与清单不一致";
            string actual;
            using (var fs = new FileStream(self, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var sha = SHA256.Create()) actual = BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "");
            if (!string.Equals(actual, expectedSha256, StringComparison.OrdinalIgnoreCase)) return "安装器 SHA256 与清单不一致";
            return null;
        } catch (Exception ex) { return "安装器复验异常：" + ex.Message; }
    }

    static void Log(string file, string msg) {
        if (string.IsNullOrEmpty(file)) return;
        File.AppendAllText(file, DateTime.Now.ToString("HH:mm:ss") + " " + msg + "\r\n", new UTF8Encoding(true));
    }

    // 静默安装：一键更新与沙箱验证共用。日志落文件（winexe 没有控制台，这是唯一输出通道）。
    // /runafter 时属于用户点了「立即更新」的链路——主程序此刻已退出，失败必须弹框，
    // 否则用户看着窗口关掉、新版没起来，完全不知道发生了什么
    static int RunSilent(string dir, string logFile, int waitPid, bool runAfter, bool migrationPrepared, string[] rawArgs) {
        string dest = null;
        string migrationSource = null;
        bool installStarted = false;
        try {
            if (migrationPrepared && !Installer.IsElevated()) migrationPrepared = false;
            dest = string.IsNullOrEmpty(dir) ? Installer.DefaultDir() : dir;
            Log(logFile, "安装目标: " + dest);
            if (waitPid > 0) {
                string waitDetail;
                bool exited = WaitForPid(waitPid, out waitDetail);
                Log(logFile, "等待旧进程退出(" + waitPid + "): " + waitDetail);
                // 超时 = 旧版可能正在执行优化：此时覆盖文件等于打断一次系统级改动，
                // 宁可取消本次更新——原版本一个字节都没动，用户随时可以重来
                if (!exited) {
                    Log(logFile, "更新已取消：旧版主程序未退出（可能正在执行优化）");
                    if (runAfter) WarnBox("检测到旧版程序仍在运行（可能正在执行优化或还原）。\r\n\r\n本次更新已取消，原来的版本没有被改动。请等待优化完成并关闭程序后，再重新检查更新。");
                    return 3;
                }
            }
            // 用户可能重复打开了多个旧版窗口。/waitpid 只覆盖发起更新的那个进程；其余
            // 实例同样可能占用 app.ico。安装前统一礼貌请求关闭，忙碌实例拒绝时取消更新。
            if (!Installer.CloseRunningBooster()) {
                Log(logFile, "更新已取消：仍有旧版主程序拒绝退出");
                if (runAfter) WarnBox("检测到另一个旧版窗口仍在执行优化或还原。\r\n\r\n本次更新已取消，原来的版本没有被改动。请等待所有旧版窗口完成并关闭后，再重新检查更新。");
                return 3;
            }
            // 兼容旧客户端：它会把当前 Downloads 安装位置通过 /dir 传回来。继续原地更新会
            // 保留可写代码目录，所以把该路径当迁移源，实际安装到 Program Files。
            string insecure = Installer.CheckSecureInstallLocation(dest);
            if (insecure != null && !string.IsNullOrEmpty(dir)) {
                migrationSource = Path.GetFullPath(dest);
                // 只有通过旧版产品身份校验的目录才可进入迁移；未知用户目录不会被提权
                // 进程改名/隔离。JSON 在切换前按严格白名单迁到当前用户 LocalAppData。
                if (!migrationPrepared) {
                    string migrationResult = Installer.MigrateLegacyUserData(migrationSource);
                    Log(logFile, migrationResult);
                    migrationPrepared = true;
                } else {
                    Installer.ValidateLegacyMigrationSource(migrationSource);
                    Log(logFile, "旧版用户 JSON 已由提权前调用者迁移；本进程只复验旧根身份");
                }
                dest = Installer.DefaultDir();
                Log(logFile, "检测到旧版可写安装目录，迁移到: " + dest + "；原因: " + insecure);
                insecure = Installer.CheckSecureInstallLocation(dest);
            }
            if (insecure != null) {
                Log(logFile, "安装目录安全检查失败: " + insecure);
                if (runAfter) FailBox(dest, insecure, false);
                return 2;
            }
            string err = Installer.CheckWritable(dest);
            if (err != null) {
                if (err == Installer.NeedAdmin && !Installer.IsElevated()) {
                    Log(logFile, "目标目录需要管理员权限，正在按需提权重启安装器");
                    if (RelaunchElevated(rawArgs, migrationPrepared)) return 0;
                    Log(logFile, "用户取消或提权重启失败");
                    return 2;
                }
                Log(logFile, "预检失败: " + err);
                if (runAfter) FailBox(dest, err == Installer.NeedAdmin ? "目标目录没有写入权限。" : ("目标目录不可写：" + err), false);
                return 2;
            }
            installStarted = true;
            Installer.Install(dest, delegate(int i, int n, string name) {
                if (i == 1 || i == n || i % 20 == 0) Log(logFile, string.Format("  {0}/{1} {2}", i, n, name));
            }, migrationSource);
            // 静默模式与向导完成页的默认勾选保持一致：开始菜单与桌面快捷方式都建
            Log(logFile, "开始菜单快捷方式: " + Installer.CreateShortcuts(dest));
            Log(logFile, "桌面快捷方式: " + Installer.CreateDesktopShortcut(dest));
            Log(logFile, "安装完成: " + dest);
            if (!string.IsNullOrEmpty(Installer.LastMigrationNote)) Log(logFile, Installer.LastMigrationNote);
            if (runAfter) Log(logFile, "启动新版: " + LaunchInstalled(dest));
            return 0;
        } catch (Exception ex) {
            Log(logFile, "安装失败: " + ex);
            if (runAfter) FailBox(dest, ex.Message, installStarted);
            return 1;
        }
    }

    static bool RelaunchElevated(string[] args, bool migrationPrepared) {
        try {
            var forwarded = new List<string>(args);
            if (migrationPrepared && !forwarded.Exists(delegate(string a) { return a.Equals("/migrationprepared", StringComparison.OrdinalIgnoreCase); }))
                forwarded.Add("/migrationprepared");
            var quoted = new string[forwarded.Count];
            for (int i = 0; i < forwarded.Count; i++) quoted[i] = QuoteArgument(forwarded[i]);
            Process.Start(new ProcessStartInfo {
                FileName = Assembly.GetExecutingAssembly().Location,
                Arguments = string.Join(" ", quoted),
                UseShellExecute = true,
                Verb = "runas"
            });
            return true;
        } catch (Exception) { return false; }
    }

    // Windows CreateProcess 命令行引号规则，保留结尾反斜杠与内嵌引号。
    static string QuoteArgument(string value) {
        if (value == null) return "\"\"";
        if (value.Length > 0 && value.IndexOfAny(new char[] { ' ', '\t', '\n', '\v', '"' }) < 0) return value;
        var b = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value) {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') { b.Append('\\', slashes * 2 + 1); b.Append('"'); slashes = 0; continue; }
            b.Append('\\', slashes); slashes = 0; b.Append(c);
        }
        b.Append('\\', slashes * 2); b.Append('"');
        return b.ToString();
    }

    // 主程序占着自己的文件，不等它退出就覆盖必失败。按 Id 精确等待，绝不按进程名杀 powershell；
    // 超时不强杀也不硬闯：返回 false 让调用方取消本次更新（解包是顺序覆盖，中途报错会
    // 留下新旧混杂的半套文件，比“更新失败”严重得多）
    static bool WaitForPid(int pid, out string detail) {
        try {
            var p = Process.GetProcessById(pid);
            if (p.WaitForExit(30000)) { detail = "已退出"; return true; }
            detail = "等待超时（30 秒）";
            return false;
        } catch (ArgumentException) {
            detail = "进程已不存在";
            return true;
        } catch (Exception ex) { detail = "等待异常: " + ex.Message; return true; }
    }

    static string LaunchInstalled(string dest) {
        try {
            string exe = Path.Combine(dest, "启动优化工具.exe");
            if (!File.Exists(exe)) return "未找到 " + exe;
            // 沙箱验证钩子（与 DFB_TEST_DESKTOP / DFB_TEST_DOWNLOADS 同类）：验证要走完
            // 参数解析与时序，但绝不能真把主程序拉起来——它会自提权弹 UAC 打断验证
            if (Installer.TestNoLaunch(dest))
                return "测试模式跳过启动: " + exe;
            // 主程序退不干净时的兜底（只按主窗口标题精确匹配请求关闭）：旧实例拒绝退出
            // 多半是正在执行优化——绝不强杀，放弃自动启动并明确告诉用户怎么办
            if (!Installer.CloseRunningBooster()) {
                WarnBox("新版本已安装完成，但检测到旧版程序仍在运行（可能正在执行优化或还原）。\r\n\r\n已跳过自动启动。请等待旧版完成并关闭后，再手动打开新版本。");
                return "旧版程序仍在运行（可能正在执行优化），已跳过自动启动";
            }
            return Installer.StartInstalledApplication(dest);
        } catch (Exception ex) { return "启动失败: " + ex.Message; }
    }

    // 安装采用完整暂存、校验、目录切换和失败回滚，不再逐文件覆盖旧版本。
    static void FailBox(string dest, string reason, bool partialInstall) {
        string state = partialInstall
            ? "新版本没有通过完整安装，暂存内容已清理；已有版本不会与新文件混在一起"
            : "原来的版本没有被破坏，可以正常继续使用";
        try {
            WinForms.MessageBox.Show(
                "更新安装失败：" + reason +
                "\r\n\r\n安装位置：" + (dest ?? "(未确定)") +
                "\r\n\r\n" + state + "。如需帮助请前往 https://df.ltz88.cn/ 下载安装包手动更新。",
                "三角洲行动优化助手 · 更新失败",
                WinForms.MessageBoxButtons.OK, WinForms.MessageBoxIcon.Error);
        } catch (Exception) { }
    }

    // 与 FailBox 区分：更新被主动取消/部分收尾未完成，不是“失败”，用警告级弹框
    static void WarnBox(string msg) {
        try {
            WinForms.MessageBox.Show(msg, "三角洲行动优化助手 · 更新未完成",
                WinForms.MessageBoxButtons.OK, WinForms.MessageBoxIcon.Warning);
        } catch (Exception) { }
    }

    static int RunCheck(string dir, string logFile) {
        string err = Installer.CheckWritable(dir);
        if (err == null)                 { Log(logFile, "WRITABLE: " + dir); return 0; }
        if (err == Installer.NeedAdmin)  { Log(logFile, "NEED_ADMIN: " + dir); return 2; }
        Log(logFile, "INVALID: " + dir + " => " + err);
        return 3;
    }

    // 离屏渲染：窗口挪到屏幕外完成布局后用 RenderTargetBitmap 截视觉树。
    // 根 Grid 自带渐变背景（而不是靠 Window.Background），导出的 PNG 才不会透明。
    static void RunRender(string outDir) {
        Directory.CreateDirectory(outDir);
        var win = new SetupWindow(null);
        win.WindowStartupLocation = WindowStartupLocation.Manual;
        win.Left = -4000; win.Top = -4000; win.ShowActivated = false;
        win.Show();
        string[] names = { "1-welcome", "2-location", "3-progress", "4-finish", "2b-location-needadmin" };
        for (int s = 0; s < names.Length; s++) {
            win.PrepareRenderState(s);
            win.UpdateLayout();
            Dispatcher.CurrentDispatcher.Invoke(new Action(delegate { }), DispatcherPriority.ContextIdle);
            var root = (FrameworkElement)win.Content;
            var rtb = new RenderTargetBitmap((int)root.ActualWidth, (int)root.ActualHeight, 96, 96, PixelFormats.Pbgra32);
            rtb.Render(root);
            var enc = new PngBitmapEncoder();
            enc.Frames.Add(BitmapFrame.Create(rtb));
            using (var fs = File.Create(Path.Combine(outDir, "page" + names[s] + ".png"))) enc.Save(fs);
        }
        // 中文编码自检：把编译产物里真实的界面字符串导出成 UTF-8 文件供核对
        File.WriteAllText(Path.Combine(outDir, "strings.txt"), win.DumpStrings(), new UTF8Encoding(true));
        win.Close();
    }
}

// ---------------- 安装引擎（图形/静默两个入口共用） ----------------
static class Installer {
    public const string NeedAdmin = "NEED_ADMIN";
    static long _requiredBytes = -1;
    sealed class PayloadFile {
        public string RelativePath;
        public string Sha256;
        public long Size;
    }
    static readonly string[] UserDataDirectories = { "profiles", "backup", "config", "logs" };
    static readonly string[] LegacyConfigFiles = {
        "telemetry.json", "disclaimer.json", "updater.json", "performance-sessions.json", "power-scheme.json"
    };
    const string InstallIdentityName = "install.identity";
    const string InstallProductId = "DeltaForceBooster";
    public static string LastMigrationNote;

    static string TestRoot() {
#if DFB_TESTING
        if (IsElevated()) return null;
        return Path.GetFullPath(Path.Combine(Path.GetTempPath(), "DeltaForceBooster-Tests"));
#else
        return null;
#endif
    }

    static bool IsInside(string root, string path) {
        if (string.IsNullOrEmpty(root) || string.IsNullOrEmpty(path)) return false;
        string prefix = Path.GetFullPath(root).TrimEnd('\\') + "\\";
        string full = Path.GetFullPath(path).TrimEnd('\\') + "\\";
        return full.StartsWith(prefix, StringComparison.OrdinalIgnoreCase);
    }

    static string TestPathValue(string name) {
        string root = TestRoot();
        if (root == null) return null;
        string value = Environment.GetEnvironmentVariable(name);
        if (string.IsNullOrEmpty(value)) return null;
        try { return IsInside(root, value) ? Path.GetFullPath(value) : null; }
        catch { return null; }
    }

    static bool TestFlagEnabled(string name, string scope) {
        string root = TestRoot();
        if (root == null || Environment.GetEnvironmentVariable(name) != "1") return false;
        try { return string.IsNullOrEmpty(scope) || IsInside(root, scope); }
        catch { return false; }
    }

    public static bool TestAutomationPath(string path) {
        string root = TestRoot();
        try { return root != null && IsInside(root, path); }
        catch { return false; }
    }

    public static bool TestNoLaunch(string scope) {
#if DFB_TESTING
        return TestFlagEnabled("DFB_TEST_NOLAUNCH", scope);
#else
        return false;
#endif
    }
    static string TestDownloadsPath() {
#if DFB_TESTING
        return TestPathValue("DFB_TEST_DOWNLOADS");
#else
        return null;
#endif
    }
    static string TestProgramFilesPath() {
#if DFB_TESTING
        return TestPathValue("DFB_TEST_PROGRAMFILES");
#else
        return null;
#endif
    }
    static string TestInsecurePrefix() {
#if DFB_TESTING
        return TestPathValue("DFB_TEST_INSECURE_PREFIX");
#else
        return null;
#endif
    }
    static bool TestAllowWritable(string scope) {
#if DFB_TESTING
        return TestFlagEnabled("DFB_TEST_ALLOW_WRITABLE_INSTALL", scope);
#else
        return false;
#endif
    }
    static bool TestSkipAcl(string scope) {
#if DFB_TESTING
        return TestFlagEnabled("DFB_TEST_SKIP_ACL", scope);
#else
        return false;
#endif
    }
    static string TestProgramDataPath() {
#if DFB_TESTING
        return TestPathValue("DFB_TEST_PROGRAMDATA");
#else
        return null;
#endif
    }
    static string TestInstallFailureAt(string scope) {
#if DFB_TESTING
        string root = TestRoot();
        if (root != null && IsInside(root, scope)) return Environment.GetEnvironmentVariable("DFB_TEST_INSTALL_FAIL_AT");
#endif
        return null;
    }
    static string TestDesktopPath() {
#if DFB_TESTING
        return TestPathValue("DFB_TEST_DESKTOP");
#else
        return null;
#endif
    }
    static string TestProgramsPath() {
#if DFB_TESTING
        return TestPathValue("DFB_TEST_PROGRAMS");
#else
        return null;
#endif
    }
    static string TestLocalAppDataPath() {
#if DFB_TESTING
        return TestPathValue("DFB_TEST_LOCALAPPDATA");
#else
        return null;
#endif
    }

    public static bool IsSha256(string value) {
        if (string.IsNullOrEmpty(value) || value.Length != 64) return false;
        foreach (char c in value) {
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return false;
        }
        return true;
    }

    static string NormalizeRelative(string relative) {
        if (string.IsNullOrEmpty(relative)) throw new InvalidDataException("payload 含空路径");
        string rel = relative.Replace('/', '\\').TrimStart('\\');
        if (Path.IsPathRooted(relative) || relative.StartsWith("\\", StringComparison.Ordinal) || relative.Contains(":"))
            throw new InvalidDataException("payload 含绝对路径：" + relative);
        string[] parts = rel.Split(new char[] { '\\' }, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) throw new InvalidDataException("payload 路径为空：" + relative);
        foreach (string p in parts) {
            if (p == "." || p == "..") throw new InvalidDataException("payload 含路径穿越：" + relative);
        }
        return string.Join("\\", parts);
    }

    static Dictionary<string, PayloadFile> ReadPayloadManifest() {
        var files = new Dictionary<string, PayloadFile>(StringComparer.OrdinalIgnoreCase);
        using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("DFB.PayloadManifest")) {
            if (stream == null) throw new InvalidDataException("安装包缺少 payload 哈希清单");
            using (var reader = new StreamReader(stream, Encoding.UTF8, true)) {
                string line;
                while ((line = reader.ReadLine()) != null) {
                    if (line.Length == 0) continue;
                    string[] fields = line.Split('|');
                    long size;
                    if (fields.Length != 3 || !IsSha256(fields[0]) || !long.TryParse(fields[1], out size) || size < 0)
                        throw new InvalidDataException("payload 哈希清单格式错误");
                    string rel;
                    try { rel = NormalizeRelative(Encoding.UTF8.GetString(Convert.FromBase64String(fields[2]))); }
                    catch (Exception ex) { throw new InvalidDataException("payload 哈希清单路径无效", ex); }
                    if (files.ContainsKey(rel)) throw new InvalidDataException("payload 哈希清单含重复路径：" + rel);
                    files.Add(rel, new PayloadFile { RelativePath = rel, Sha256 = fields[0], Size = size });
                }
            }
        }
        if (files.Count == 0 || files.Count > 256) throw new InvalidDataException("payload 哈希清单文件数异常");
        return files;
    }

    // 下载文件夹可被用户移动到任意盘，SpecialFolder 枚举里也没有 Downloads——
    // 唯一可靠取法是 Known Folder API（FOLDERID_Downloads）
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    static extern int SHGetKnownFolderPath(ref Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr ppszPath);

    static string KnownDownloads() {
        try {
            var rfid = new Guid("374DE290-123F-4565-9164-39C4925E467B");
            IntPtr p = IntPtr.Zero;
            try {
                if (SHGetKnownFolderPath(ref rfid, 0, IntPtr.Zero, out p) == 0 && p != IntPtr.Zero) {
                    string s = Marshal.PtrToStringUni(p);
                    if (!string.IsNullOrEmpty(s) && Directory.Exists(s)) return s;
                }
            } finally { if (p != IntPtr.Zero) Marshal.FreeCoTaskMem(p); }
        } catch (Exception) { }
        return null;
    }

    // 取不到时返回 null，由 DefaultDir 兜底——默认路径任何情况下都不能是空串
    public static string DownloadsDir() {
        // Known Folder API 不吃环境变量重定向，沙箱验证需要专用钩子（与 DFB_TEST_DESKTOP 同类）
        string t = TestDownloadsPath();
        if (!string.IsNullOrEmpty(t)) return t;
        string kf = KnownDownloads();
        if (kf != null) return kf;
        // 回退 ①：未重定向机器上的实际位置
        string up = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (!string.IsNullOrEmpty(up)) {
            string dl = Path.Combine(up, "Downloads");
            if (Directory.Exists(dl)) return dl;
        }
        return null;
    }

    // 程序代码默认进入 Program Files，避免普通权限进程替换同目录脚本后等待用户下次运行。
    // DFB_TEST_PROGRAMFILES 只用于安装回归测试重定向，不影响正式用户路径。
    public static string DefaultDir() {
        string pf = TestProgramFilesPath();
        if (string.IsNullOrEmpty(pf)) pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        if (string.IsNullOrEmpty(pf)) throw new InvalidOperationException("系统未提供 Program Files 路径");
        return Path.Combine(pf, "DeltaForceBooster");
    }

    // 位置页的风险提示据此判断：当前输入路径是否位于下载文件夹之内
    public static bool IsUnderDownloads(string path) {
        try {
            string dl = DownloadsDir();
            if (string.IsNullOrEmpty(dl)) return false;
            string full = Path.GetFullPath(path.Trim()).TrimEnd('\\') + "\\";
            string root = Path.GetFullPath(dl).TrimEnd('\\') + "\\";
            return full.StartsWith(root, StringComparison.OrdinalIgnoreCase);
        } catch (Exception) { return false; }
    }

    public static bool IsElevated() {
        var id = System.Security.Principal.WindowsIdentity.GetCurrent();
        var p = new System.Security.Principal.WindowsPrincipal(id);
        return p.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
    }

    // 解包后所需字节数由嵌入的发布清单求和，避免未知 ZIP 条目影响显示或被误安装。
    public static long RequiredBytes() {
        if (_requiredBytes >= 0) return _requiredBytes;
        long sum = 0;
        foreach (PayloadFile f in ReadPayloadManifest().Values) checked { sum += f.Size; }
        _requiredBytes = sum;
        return sum;
    }

    // 安装器写 Program Files 时处于 elevated token；asInvoker 启动器若直接继承该 token，
    // 非提权 GUI 会按安全策略拒绝启动。交给当前桌面的 explorer shell 可回到交互用户 token。
    public static string StartInstalledApplication(string dest) {
        string exe = Path.Combine(dest, "启动优化工具.exe");
        if (!File.Exists(exe)) return "未找到 " + exe;
        if (TestNoLaunch(dest))
            return "测试模式跳过启动: " + exe;
        if (IsElevated()) {
            string system = Environment.SystemDirectory;
            if (string.IsNullOrEmpty(system)) throw new InvalidOperationException("系统未提供受信 System32 路径");
            string explorer = Path.Combine(Directory.GetParent(system).FullName, "explorer.exe");
            Process.Start(new ProcessStartInfo {
                FileName = explorer,
                Arguments = "\"" + exe + "\"",
                UseShellExecute = true
            });
            return "已交给普通用户桌面启动";
        }
        Process.Start(new ProcessStartInfo { FileName = exe, WorkingDirectory = dest, UseShellExecute = true });
        return "已启动";
    }

    static bool HasWriteRights(FileSystemRights rights) {
        // Modify/FullControl are composite constants that also include read/execute bits. OR-ing
        // them into a detection mask makes a normal Users RX ACE look writable and rejects the
        // real Program Files ACL. Match only the write/delete/DACL/owner bits themselves.
        const FileSystemRights write = FileSystemRights.WriteData | FileSystemRights.AppendData |
            FileSystemRights.WriteExtendedAttributes | FileSystemRights.WriteAttributes |
            FileSystemRights.DeleteSubdirectoriesAndFiles | FileSystemRights.Delete |
            FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership;
        long raw = (long)rights;
        return (rights & write) != 0 || (raw & 0x10000000L) != 0 || (raw & 0x40000000L) != 0;
    }

    static bool IsTrustedProgramFilesWriter(SecurityIdentifier sid) {
        if (sid == null) return false;
        return IsTrustedInstallWriter(sid) || sid.Value == "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464";
    }

    static string ProgramFilesBoundary(string full) {
        foreach (Environment.SpecialFolder folder in new Environment.SpecialFolder[] {
            Environment.SpecialFolder.ProgramFiles, Environment.SpecialFolder.ProgramFilesX86 }) {
            string root = Environment.GetFolderPath(folder);
            if (string.IsNullOrEmpty(root)) continue;
            string prefix = Path.GetFullPath(root).TrimEnd('\\') + "\\";
            if ((full.TrimEnd('\\') + "\\").StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return prefix.TrimEnd('\\');
        }
        return null;
    }

    static void EnsureTrustedProgramFilesChain(string boundary, string full) {
        string current = Path.GetFullPath(boundary).TrimEnd('\\');
        string target = Path.GetFullPath(full).TrimEnd('\\');
        while (true) {
            if (!Directory.Exists(current)) break;
            var security = Directory.GetAccessControl(current, AccessControlSections.Owner | AccessControlSections.Access);
            var owner = security.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier;
            if (!IsTrustedProgramFilesWriter(owner)) throw new UnauthorizedAccessException("Program Files 路径 owner 不可信：" + current);
            foreach (FileSystemAccessRule rule in security.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
                var sid = rule.IdentityReference as SecurityIdentifier;
                bool creatorInheritOnly = sid != null && sid.Value == "S-1-3-0" &&
                    (rule.PropagationFlags & PropagationFlags.InheritOnly) != 0;
                if (rule.AccessControlType == AccessControlType.Allow && HasWriteRights(rule.FileSystemRights) &&
                    !IsTrustedProgramFilesWriter(sid) && !creatorInheritOnly)
                    throw new UnauthorizedAccessException("Program Files 路径允许非受信账户写入/DeleteChild：" + current);
            }
            if (string.Equals(current, target, StringComparison.OrdinalIgnoreCase)) break;
            string remainder = target.Substring(current.Length).TrimStart('\\');
            if (remainder.Length == 0) break;
            string next = remainder.Split('\\')[0];
            current = Path.Combine(current, next);
        }
    }

    static string NearestExistingDirectory(string full) {
        string probe = full;
        while (!Directory.Exists(probe)) {
            string parent = Path.GetDirectoryName(probe);
            if (string.IsNullOrEmpty(parent)) return null;
            probe = parent;
        }
        return probe;
    }

    // 正式安装只允许 System Known Folder 返回的 Program Files / Program Files (x86)。
    // 对从边界到目标的每个既有目录，拒绝除 Admin/SYSTEM/TrustedInstaller 之外的任意
    // 写/DeleteChild ACE；不能只检查“当前用户”，否则另一个本地用户仍可替换程序根。
    public static string CheckSecureInstallLocation(string dest) {
        try {
            string full = Path.GetFullPath(dest.Trim());
            string forced = TestInsecurePrefix();
            if (!string.IsNullOrEmpty(forced)) {
                string prefix = Path.GetFullPath(forced).TrimEnd('\\') + "\\";
                if ((full.TrimEnd('\\') + "\\").StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                    return "测试模式标记为旧版可写目录";
            }
            EnsureNoReparseExistingPath(full);
            if (TestAllowWritable(full)) return null;
            string boundary = ProgramFilesBoundary(full);
            if (boundary == null) return "程序文件只允许安装到系统 Program Files 目录";
            EnsureTrustedProgramFilesChain(boundary, full);
            return null;
        } catch (Exception ex) { return "目标目录安全检查失败：" + ex.Message; }
    }

    // 写入权限预检：先拒绝重解析点与普通用户可写位置，再以 CreateNew 在最近祖先真实探测。
    public static string CheckWritable(string dest) {
        if (string.IsNullOrEmpty(dest) || dest.Trim().Length == 0) return "路径为空";
        string full;
        try {
            full = Path.GetFullPath(dest.Trim());
            if (!Path.IsPathRooted(full)) return "请输入带盘符的完整路径";
        } catch (Exception) { return "路径格式无效"; }
        string secure = CheckSecureInstallLocation(full);
        if (secure != null) return secure;
        try { ValidateExistingInstallTarget(full); }
        catch (Exception ex) { return ex.Message; }
        string probe = NearestExistingDirectory(full);
        if (probe == null) return "目标磁盘或根目录不存在";
        try {
            string test = Path.Combine(probe, ".dfb-write-test-" + Guid.NewGuid().ToString("N"));
            using (var fs = new FileStream(test, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
                fs.WriteByte(0x44); fs.Flush(true);
            }
            File.Delete(test);
            return null;
        } catch (UnauthorizedAccessException) { return NeedAdmin; }
        catch (Exception ex) { return ex.Message; }
    }

    static void EnsureNoReparseExistingPath(string path) {
        string full = Path.GetFullPath(path);
        string root = Path.GetPathRoot(full);
        if (string.IsNullOrEmpty(root)) throw new IOException("路径没有有效根目录：" + path);
        string current = root.TrimEnd('\\');
        string rest = full.Substring(root.Length);
        foreach (string part in rest.Split(new char[] { '\\' }, StringSplitOptions.RemoveEmptyEntries)) {
            current = current.Length == 2 && current[1] == ':' ? current + "\\" + part : Path.Combine(current, part);
            if (!Directory.Exists(current) && !File.Exists(current)) break;
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("路径包含 junction/symlink/reparse point：" + current);
        }
    }

    static string ChildPath(string root, string relative) {
        string prefix = Path.GetFullPath(root).TrimEnd('\\') + "\\";
        string target = Path.GetFullPath(Path.Combine(root, relative));
        if (!target.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("payload 路径越界：" + relative);
        return target;
    }

    static string FileSha256(string path) {
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
        using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "");
    }

    static bool IsTrustedInstallWriter(SecurityIdentifier sid) {
        if (sid == null) return false;
        string value = sid.Value;
        return value == new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null).Value ||
               value == new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null).Value;
    }

    static void EnsureProtectedEntry(string path, bool directory) {
        FileSystemSecurity security = directory
            ? (FileSystemSecurity)Directory.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access)
            : (FileSystemSecurity)File.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access);
        var owner = security.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier;
        if (!IsTrustedInstallWriter(owner)) throw new UnauthorizedAccessException("现有安装项 owner 不可信：" + path);
        var rules = security.GetAccessRules(true, true, typeof(SecurityIdentifier));
        foreach (FileSystemAccessRule rule in rules) {
            if (rule.AccessControlType != AccessControlType.Allow || !HasWriteRights(rule.FileSystemRights)) continue;
            if (!IsTrustedInstallWriter(rule.IdentityReference as SecurityIdentifier))
                throw new UnauthorizedAccessException("现有安装项允许非管理员写入：" + path);
        }
    }

    static void EnsureExactAdminSystemEntry(string path, bool directory) {
        FileSystemSecurity security = directory
            ? (FileSystemSecurity)Directory.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access)
            : (FileSystemSecurity)File.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access);
        var owner = security.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier;
        if (!IsTrustedInstallWriter(owner) || !security.AreAccessRulesProtected)
            throw new UnauthorizedAccessException("受保护存储 owner/DACL 继承状态不可信：" + path);
        bool adminFull = false, systemFull = false;
        string adminSid = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null).Value;
        string systemSid = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null).Value;
        var rules = security.GetAccessRules(true, true, typeof(SecurityIdentifier));
        foreach (FileSystemAccessRule rule in rules) {
            var sid = rule.IdentityReference as SecurityIdentifier;
            if (!IsTrustedInstallWriter(sid)) throw new UnauthorizedAccessException("受保护存储含非 Admin/SYSTEM ACL：" + path);
            if (rule.AccessControlType == AccessControlType.Allow &&
                (rule.FileSystemRights & FileSystemRights.FullControl) == FileSystemRights.FullControl) {
                if (sid.Value == adminSid) adminFull = true;
                if (sid.Value == systemSid) systemFull = true;
            }
        }
        if (!adminFull || !systemFull) throw new UnauthorizedAccessException("受保护存储缺少 Admin/SYSTEM FullControl：" + path);
    }

    static void EnsureProtectedInstallTree(string root) {
        EnsureTreeHasNoReparsePoints(root);
        if (TestSkipAcl(root)) return;
        EnsureProtectedEntry(root, true);
        foreach (string directory in Directory.GetDirectories(root, "*", SearchOption.AllDirectories))
            EnsureProtectedEntry(directory, true);
        foreach (string file in Directory.GetFiles(root, "*", SearchOption.AllDirectories))
            EnsureProtectedEntry(file, false);
    }

    static bool TryReadInstallIdentity(string root, out string launcherSha256, out string reason) {
        launcherSha256 = null; reason = null;
        try {
            string identity = Path.Combine(root, InstallIdentityName);
            string launcher = Path.Combine(root, "启动优化工具.exe");
            string gui = Path.Combine(root, "gui", "DeltaForceBooster-GUI.ps1");
            string engine = Path.Combine(root, "scripts", "delta-booster.ps1");
            string tuning = Path.Combine(root, "scripts", "tuning-experiment.ps1");
            foreach (string required in new string[] { identity, launcher, gui, engine, tuning }) {
                EnsureNoReparseExistingPath(required);
                if (!File.Exists(required)) { reason = "缺少产品身份文件：" + required; return false; }
            }
            var info = new FileInfo(identity);
            if (info.Length <= 0 || info.Length > 512) { reason = "产品身份文件大小无效"; return false; }
            string text;
            using (var fs = new FileStream(identity, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var reader = new StreamReader(fs, new UTF8Encoding(false, true), false)) text = reader.ReadToEnd();
            string[] lines = text.Replace("\r\n", "\n").Split('\n');
            if (lines.Length != 4 || lines[3].Length != 0 || lines[0] != "SchemaVersion=1" ||
                lines[1] != "ProductId=" + InstallProductId || !lines[2].StartsWith("LauncherSha256=", StringComparison.Ordinal)) {
                reason = "产品身份文件格式无效"; return false;
            }
            launcherSha256 = lines[2].Substring("LauncherSha256=".Length);
            if (!IsSha256(launcherSha256) || !string.Equals(FileSha256(launcher), launcherSha256, StringComparison.OrdinalIgnoreCase)) {
                reason = "启动器与产品身份文件不匹配"; return false;
            }
            return true;
        } catch (Exception ex) { reason = "产品身份校验失败：" + ex.Message; return false; }
    }

    // 已存在目录只接受空目录或由本安装器生成、且整棵仍由 Admin/SYSTEM 独占写权限的
    // DeltaForceBooster。未知非空目录绝不移动到 rollback，更不会递归删除。
    static void ValidateExistingInstallTarget(string root) {
        if (!Directory.Exists(root)) return;
        EnsureNoReparseExistingPath(root);
        if (Directory.GetFileSystemEntries(root).Length == 0) return;
        string launcherHash, reason;
        if (!TryReadInstallIdentity(root, out launcherHash, out reason))
            throw new IOException("目标目录非空且不是可验证的 DeltaForceBooster 安装：" + reason);
        EnsureProtectedInstallTree(root);
    }

    static bool IsManifestDirectory(Dictionary<string, PayloadFile> files, string directory) {
        string prefix = directory.TrimEnd('\\') + "\\";
        foreach (string rel in files.Keys) if (rel.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }

    static void ExtractAndVerifyPayload(string stage, Action<int, int, string> onProgress) {
        Dictionary<string, PayloadFile> manifest = ReadPayloadManifest();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("DFB.Payload"))
        using (var za = new ZipArchive(s, ZipArchiveMode.Read)) {
            foreach (ZipArchiveEntry entry in za.Entries) {
                string rel = NormalizeRelative(entry.FullName);
                bool isDirectory = string.IsNullOrEmpty(entry.Name) || entry.FullName.EndsWith("/", StringComparison.Ordinal) || entry.FullName.EndsWith("\\", StringComparison.Ordinal);
                string target = ChildPath(stage, rel);
                if (isDirectory) {
                    if (!IsManifestDirectory(manifest, rel)) throw new InvalidDataException("payload 含白名单外目录：" + rel);
                    EnsureNoReparseExistingPath(target);
                    Directory.CreateDirectory(target);
                    EnsureNoReparseExistingPath(target);
                    continue;
                }
                PayloadFile expected;
                if (!manifest.TryGetValue(rel, out expected)) throw new InvalidDataException("payload 含白名单外文件：" + rel);
                if (!seen.Add(rel)) throw new InvalidDataException("payload 含重复文件：" + rel);
                if (entry.Length != expected.Size) throw new InvalidDataException("payload 文件大小与清单不符：" + rel);
                string parent = Path.GetDirectoryName(target);
                EnsureNoReparseExistingPath(parent);
                Directory.CreateDirectory(parent);
                EnsureNoReparseExistingPath(parent);
                string actualHash;
                long written = 0;
                using (Stream input = entry.Open())
                using (var output = new FileStream(target, FileMode.CreateNew, FileAccess.ReadWrite, FileShare.None)) {
                    byte[] buffer = new byte[65536];
                    int n;
                    while ((n = input.Read(buffer, 0, buffer.Length)) > 0) {
                        output.Write(buffer, 0, n); written += n;
                        if (written > expected.Size) throw new InvalidDataException("payload 解压大小超限：" + rel);
                    }
                    output.Flush(true);
                    output.Position = 0;
                    using (var sha = SHA256.Create()) actualHash = BitConverter.ToString(sha.ComputeHash(output)).Replace("-", "");
                }
                if (written != expected.Size || !string.Equals(actualHash, expected.Sha256, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("payload 文件完整性校验失败：" + rel);
                if (onProgress != null) onProgress(seen.Count, manifest.Count, rel);
            }
        }
        if (seen.Count != manifest.Count) throw new InvalidDataException("payload 文件不完整");
        foreach (PayloadFile expected in manifest.Values) {
            string path = ChildPath(stage, expected.RelativePath);
            EnsureNoReparseExistingPath(path);
            var info = new FileInfo(path);
            if (!info.Exists || info.Length != expected.Size || !string.Equals(FileSha256(path), expected.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("切换前完整性复验失败：" + expected.RelativePath);
        }
    }

    static void EnsureTreeHasNoReparsePoints(string root) {
        EnsureNoReparseExistingPath(root);
        if (!Directory.Exists(root)) return;
        foreach (string entry in Directory.GetFileSystemEntries(root)) {
            FileAttributes attributes = File.GetAttributes(entry);
            if ((attributes & FileAttributes.ReparsePoint) != 0) throw new IOException("目录树包含 junction/symlink/reparse point：" + entry);
            if ((attributes & FileAttributes.Directory) != 0) EnsureTreeHasNoReparsePoints(entry);
        }
    }

    static void CopyDirectoryNoReparse(string source, string target) {
        EnsureTreeHasNoReparsePoints(source);
        Directory.CreateDirectory(target);
        EnsureNoReparseExistingPath(target);
        foreach (string file in Directory.GetFiles(source)) {
            string dest = Path.Combine(target, Path.GetFileName(file));
            if (!File.Exists(dest)) File.Copy(file, dest, false);
        }
        foreach (string directory in Directory.GetDirectories(source))
            CopyDirectoryNoReparse(directory, Path.Combine(target, Path.GetFileName(directory)));
    }

    static void CopyUserData(string sourceRoot, string stage) {
        if (string.IsNullOrEmpty(sourceRoot) || !Directory.Exists(sourceRoot)) return;
        EnsureTreeHasNoReparsePoints(sourceRoot);
        foreach (string name in UserDataDirectories) {
            string source = Path.Combine(sourceRoot, name);
            if (Directory.Exists(source)) CopyDirectoryNoReparse(source, Path.Combine(stage, name));
        }
    }

    static string ReadSmallUtf8(string path, int maxBytes) {
        EnsureNoReparseExistingPath(path);
        var info = new FileInfo(path);
        if (!info.Exists || info.Length < 2 || info.Length > maxBytes) throw new InvalidDataException("JSON 文件大小无效");
        string text;
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read)) {
            if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) throw new IOException("JSON 文件是重解析点");
            using (var reader = new StreamReader(fs, new UTF8Encoding(false, true), true)) text = reader.ReadToEnd();
            // 文件句柄仍在持有时再复验整条路径；路径被换成 junction/symlink 时本项作废。
            EnsureNoReparseExistingPath(path);
        }
        var serializer = new JavaScriptSerializer { MaxJsonLength = maxBytes, RecursionLimit = 64 };
        serializer.DeserializeObject(text);
        return text;
    }

    static bool LooksLikeLegacyProductRoot(string root, out string reason) {
        reason = null;
        try {
            string full = Path.GetFullPath(root).TrimEnd('\\');
            string drive = Path.GetPathRoot(full);
            if (string.IsNullOrEmpty(drive) || new DriveInfo(drive).DriveType != DriveType.Fixed) {
                reason = "旧安装必须位于本地固定磁盘"; return false;
            }
            EnsureNoReparseExistingPath(full);
            string launcher = Path.Combine(full, "启动优化工具.exe");
            string gui = Path.Combine(full, "gui", "DeltaForceBooster-GUI.ps1");
            string engine = Path.Combine(full, "scripts", "delta-booster.ps1");
            string tuning = Path.Combine(full, "scripts", "tuning-experiment.ps1");
            foreach (string required in new string[] { launcher, gui, engine, tuning }) {
                EnsureNoReparseExistingPath(required);
                if (!File.Exists(required)) { reason = "缺少旧版产品文件：" + required; return false; }
            }
            FileVersionInfo vi = FileVersionInfo.GetVersionInfo(launcher);
            if (!string.Equals(vi.ProductName, InstallProductId, StringComparison.Ordinal) ||
                !string.Equals(vi.CompanyName, "DeltaForceBooster 开源项目", StringComparison.Ordinal)) {
                reason = "旧版启动器产品身份不匹配"; return false;
            }
            string guiHead = ReadTextPrefix(gui, 65536);
            string engineHead = ReadTextPrefix(engine, 16384);
            if (!guiHead.Contains("DeltaForceBooster 图形界面") || !guiHead.Contains("$script:GuiVersion") ||
                !engineHead.Contains("DeltaForceBooster 核心脚本")) {
                reason = "旧版脚本产品身份不匹配"; return false;
            }
            return true;
        } catch (Exception ex) { reason = ex.Message; return false; }
    }

    public static void ValidateLegacyMigrationSource(string root) {
        string reason;
        if (!LooksLikeLegacyProductRoot(root, out reason))
            throw new IOException("传入目录不是可识别的旧版 DeltaForceBooster：" + reason);
    }

    static string ReadTextPrefix(string path, int maxBytes) {
        EnsureNoReparseExistingPath(path);
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read)) {
            if (fs.Length <= 0 || fs.Length > 4 * 1024 * 1024) throw new InvalidDataException("产品脚本大小异常");
            byte[] buffer = new byte[Math.Min(maxBytes, (int)fs.Length)];
            int total = 0, n;
            while (total < buffer.Length && (n = fs.Read(buffer, total, buffer.Length - total)) > 0) total += n;
            EnsureNoReparseExistingPath(path);
            return new UTF8Encoding(false, true).GetString(buffer, 0, total);
        }
    }

    static bool CopyLegacyJsonIfMissing(string sourceRoot, string relative, string destination, int maxBytes) {
        string source = ChildPath(sourceRoot, relative);
        if (!File.Exists(source) || File.Exists(destination)) return false;
        string text = ReadSmallUtf8(source, maxBytes);
        string parent = Path.GetDirectoryName(destination);
        EnsureNoReparseExistingPath(parent);
        Directory.CreateDirectory(parent);
        EnsureNoReparseExistingPath(parent);
        byte[] bytes = new UTF8Encoding(true).GetBytes(text);
        using (var fs = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough)) {
            fs.Write(bytes, 0, bytes.Length); fs.Flush(true);
        }
        return true;
    }

    // 在首次调用者（通常是普通 GUI 用户）上下文里先迁移明确 JSON 白名单；提权安装阶段
    // 只负责代码切换和登记旧备份，绝不递归读取用户可写 legacy 树。
    public static string MigrateLegacyUserData(string legacyRoot) {
        ValidateLegacyMigrationSource(legacyRoot);
        string local = TestLocalAppDataPath();
        if (string.IsNullOrEmpty(local)) local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (string.IsNullOrEmpty(local)) throw new IOException("系统未提供用户 LocalAppData 路径");
        string userRoot = Path.Combine(local, "DeltaForceBooster");
        EnsureNoReparseExistingPath(local);
        int copied = 0, skipped = 0;
        foreach (string name in LegacyConfigFiles) {
            try {
                if (CopyLegacyJsonIfMissing(legacyRoot, Path.Combine("config", name),
                    Path.Combine(userRoot, "config", name), 1024 * 1024)) copied++; else skipped++;
            } catch { skipped++; }
        }
        string profileSource = Path.Combine(legacyRoot, "profiles");
        if (Directory.Exists(profileSource)) {
            try {
                EnsureNoReparseExistingPath(profileSource);
                int count = 0;
                foreach (string file in Directory.GetFiles(profileSource, "*.json", SearchOption.TopDirectoryOnly)) {
                    if (count++ >= 100) { skipped++; break; }
                    string name = Path.GetFileName(file);
                    if (name.Length < 6 || name.Length > 85 || name.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0) { skipped++; continue; }
                    try {
                        if (CopyLegacyJsonIfMissing(legacyRoot, Path.Combine("profiles", name),
                            Path.Combine(userRoot, "profiles", name), 256 * 1024)) copied++; else skipped++;
                    } catch { skipped++; }
                }
            } catch { skipped++; }
        }
        return "旧版用户 JSON 已按白名单迁移：新增 " + copied + "，保留/跳过 " + skipped;
    }

    // 发布代码目录 owner 固定为 Administrators，普通 Users 只有 RX；避免 elevated token 创建
    // 文件时把“当前管理员用户”留成 owner，之后 medium token 以 owner 身份重写 DACL。
    static void HardenInstalledTree(string root) {
        if (TestSkipAcl(root)) return;
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        var users = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null);
        var inherit = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
        foreach (string file in Directory.GetFiles(root, "*", SearchOption.AllDirectories)) {
            if ((File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) throw new IOException("安装树包含重解析点：" + file);
            var fileAcl = new FileSecurity();
            fileAcl.SetAccessRuleProtection(true, false); fileAcl.SetOwner(admins);
            fileAcl.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, AccessControlType.Allow));
            fileAcl.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, AccessControlType.Allow));
            fileAcl.AddAccessRule(new FileSystemAccessRule(users, FileSystemRights.ReadAndExecute, AccessControlType.Allow));
            File.SetAccessControl(file, fileAcl);
        }
        var directories = new List<string>(Directory.GetDirectories(root, "*", SearchOption.AllDirectories));
        directories.Sort(delegate(string a, string b) { return b.Length.CompareTo(a.Length); });
        directories.Add(root);
        foreach (string directory in directories) {
            if ((File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0) throw new IOException("安装树包含重解析点：" + directory);
            var dirAcl = new DirectorySecurity();
            dirAcl.SetAccessRuleProtection(true, false); dirAcl.SetOwner(admins);
            dirAcl.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
            dirAcl.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
            dirAcl.AddAccessRule(new FileSystemAccessRule(users, FileSystemRights.ReadAndExecute, inherit, PropagationFlags.None, AccessControlType.Allow));
            Directory.SetAccessControl(directory, dirAcl);
        }
    }

    static void MoveDirectoryWithRetry(string source, string destination) {
        const int attempts = 12;
        for (int n = 1; ; n++) {
            try { Directory.Move(source, destination); return; }
            catch (IOException) { if (n >= attempts) throw; Thread.Sleep(250); }
            catch (UnauthorizedAccessException) { if (n >= attempts) throw; Thread.Sleep(250); }
        }
    }

    // 清理时遇到重解析点只删除链接本身，永不递归进入其目标。
    static void SafeDeleteTree(string root) {
        if (!Directory.Exists(root)) return;
        FileAttributes rootAttr = File.GetAttributes(root);
        if ((rootAttr & FileAttributes.ReparsePoint) != 0) { Directory.Delete(root, false); return; }
        foreach (string entry in Directory.GetFileSystemEntries(root)) {
            FileAttributes attr = File.GetAttributes(entry);
            if ((attr & FileAttributes.ReparsePoint) != 0) {
                if ((attr & FileAttributes.Directory) != 0) Directory.Delete(entry, false); else File.Delete(entry);
            } else if ((attr & FileAttributes.Directory) != 0) SafeDeleteTree(entry);
            else File.Delete(entry);
        }
        Directory.Delete(root, false);
    }

    static string JsonEscape(string value) {
        var b = new StringBuilder();
        foreach (char c in value) {
            switch (c) {
                case '\\': b.Append("\\\\"); break;
                case '"': b.Append("\\\""); break;
                case '\r': b.Append("\\r"); break;
                case '\n': b.Append("\\n"); break;
                case '\t': b.Append("\\t"); break;
                default:
                    if (c < 0x20) b.Append("\\u" + ((int)c).ToString("x4")); else b.Append(c);
                    break;
            }
        }
        return b.ToString();
    }

    // legacy roots 清单是管理员还原入口，只写入 Admin/SYSTEM-owned ProgramData，普通用户
    // 无写权限。engine 读取后还会对绝对本地盘、规范路径和 reparse point 再做严格验证。
    static void PersistLegacyRoot(string legacyRoot) {
        string full = Path.GetFullPath(legacyRoot).TrimEnd('\\');
        string driveRoot = Path.GetPathRoot(full);
        if (string.IsNullOrEmpty(driveRoot) || new DriveInfo(driveRoot).DriveType != DriveType.Fixed)
            throw new IOException("legacy root 必须位于本地固定磁盘");
        EnsureNoReparseExistingPath(full);
        string programData = TestProgramDataPath();
        if (string.IsNullOrEmpty(programData)) programData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
        if (string.IsNullOrEmpty(programData)) throw new IOException("系统未提供 ProgramData 路径");
        string root = Path.Combine(programData, "DeltaForceBooster");
        EnsureNoReparseExistingPath(root);

        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        var inherit = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
        var acl = new DirectorySecurity();
        acl.SetAccessRuleProtection(true, false); acl.SetOwner(admins);
        acl.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        acl.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        bool testAclBypass = TestSkipAcl(root);
        if (!Directory.Exists(root)) {
            if (testAclBypass) Directory.CreateDirectory(root); else Directory.CreateDirectory(root, acl);
        } else if (!testAclBypass) {
            // 已存在根绝不“先接管再相信”：普通用户可预建目录并保留写句柄。只有它本来就
            // 是 Admin/SYSTEM exact protected store 才继续。
            EnsureExactAdminSystemEntry(root, true);
        }
        EnsureNoReparseExistingPath(root);
        if (!testAclBypass) EnsureExactAdminSystemEntry(root, true);

        string destination = Path.Combine(root, "legacy-roots.json");
        EnsureNoReparseExistingPath(destination);
        var roots = new List<string>();
        if (File.Exists(destination)) {
            if (!testAclBypass) EnsureExactAdminSystemEntry(destination, false);
            var existingInfo = new FileInfo(destination);
            if (existingInfo.Length <= 0 || existingInfo.Length > 16384) throw new InvalidDataException("legacy roots 清单大小无效");
            string existing;
            using (var fs = new FileStream(destination, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var reader = new StreamReader(fs, new UTF8Encoding(false, true), true)) existing = reader.ReadToEnd();
            var serializer = new JavaScriptSerializer { MaxJsonLength = 16384, RecursionLimit = 8 };
            var doc = serializer.DeserializeObject(existing) as Dictionary<string, object>;
            if (doc == null || doc.Count != 2 || !doc.ContainsKey("SchemaVersion") || !doc.ContainsKey("Roots") ||
                Convert.ToInt32(doc["SchemaVersion"]) != 1) throw new InvalidDataException("legacy roots 清单 schema 无效");
            var values = doc["Roots"] as object[];
            if (values == null || values.Length > 16) throw new InvalidDataException("legacy roots 清单 Roots 无效");
            foreach (object value in values) {
                string prior = value as string;
                if (string.IsNullOrEmpty(prior)) throw new InvalidDataException("legacy roots 清单含非字符串路径");
                string normalized = Path.GetFullPath(prior).TrimEnd('\\');
                string leaf = Path.GetFileName(normalized);
                if (!System.Text.RegularExpressions.Regex.IsMatch(leaf, @"^\.DeltaForceBooster\.migrated-[0-9a-fA-F]{32}$"))
                    throw new InvalidDataException("legacy roots 清单路径 leaf 无效");
                string priorDrive = Path.GetPathRoot(normalized);
                if (string.IsNullOrEmpty(priorDrive) || new DriveInfo(priorDrive).DriveType != DriveType.Fixed)
                    throw new InvalidDataException("legacy roots 清单含非本地固定盘路径");
                EnsureNoReparseExistingPath(normalized);
                if (!roots.Exists(delegate(string p) { return string.Equals(p, normalized, StringComparison.OrdinalIgnoreCase); }))
                    roots.Add(normalized);
            }
        }
        if (!roots.Exists(delegate(string p) { return string.Equals(p, full, StringComparison.OrdinalIgnoreCase); })) {
            if (roots.Count >= 16) throw new InvalidDataException("legacy roots 清单已达到 16 项上限");
            roots.Add(full);
        }
        string temp = Path.Combine(root, ".legacy-roots-" + Guid.NewGuid().ToString("N") + ".tmp");
        var rootJson = new List<string>();
        foreach (string item in roots) rootJson.Add("\"" + JsonEscape(item) + "\"");
        string json = "{\"SchemaVersion\":1,\"Roots\":[" + string.Join(",", rootJson.ToArray()) + "]}";
        byte[] bytes = new UTF8Encoding(false).GetBytes(json);
        using (var fs = new FileStream(temp, FileMode.CreateNew, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough)) {
            fs.Write(bytes, 0, bytes.Length); fs.Flush(true);
        }
        if (!testAclBypass) {
            var fileAcl = new FileSecurity();
            fileAcl.SetAccessRuleProtection(true, false); fileAcl.SetOwner(admins);
            fileAcl.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, AccessControlType.Allow));
            fileAcl.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, AccessControlType.Allow));
            File.SetAccessControl(temp, fileAcl);
            EnsureExactAdminSystemEntry(temp, false);
        }
        if (File.Exists(destination)) File.Replace(temp, destination, null, true); else File.Move(temp, destination);
        EnsureNoReparseExistingPath(destination);
        if (!testAclBypass) EnsureExactAdminSystemEntry(destination, false);
    }

    // legacy 目录属于普通用户可写边界；切换成功后不以管理员身份递归读取或删除它。
    // 只做同父目录原子改名，旧入口离开原路径，备份/配置原样保留供用户人工核对。
    static void QuarantineLegacyInstall(string source) {
        try {
            if (!Directory.Exists(source)) return;
            string identityReason;
            if (!LooksLikeLegacyProductRoot(source, out identityReason)) {
                LastMigrationNote = "新版本已迁入 Program Files；旧目录身份复验失败，已原样保留：" + identityReason;
                return;
            }
            string parent = Path.GetDirectoryName(source.TrimEnd('\\'));
            // engine 只接受该固定 leaf schema，避免任意 ProgramData inventory 路径被当备份根。
            string quarantine = Path.Combine(parent, ".DeltaForceBooster.migrated-" + Guid.NewGuid().ToString("N"));
            MoveDirectoryWithRetry(source, quarantine);
            try {
                PersistLegacyRoot(quarantine);
                LastMigrationNote = "旧版可写目录已停用并保留在：" + quarantine + "；备份位置已登记到受保护清单";
            } catch (Exception ex) {
                LastMigrationNote = "旧版目录已停用并保留在：" + quarantine + "；备份位置登记失败，请保留安装日志。原因：" + ex.Message;
            }
        } catch (Exception ex) {
            LastMigrationNote = "新版本已迁入 Program Files；旧目录未自动清理，请勿继续从旧目录启动。原因：" + ex.Message;
        }
    }

    static void AssertTransactionPath(string path, string parent, string leaf, string id, string kind) {
        string expected = Path.GetFullPath(Path.Combine(parent, "." + leaf + ".dfb-" + kind + "-" + id));
        if (!string.Equals(Path.GetFullPath(path), expected, StringComparison.OrdinalIgnoreCase))
            throw new IOException("事务目录路径身份不匹配：" + path);
    }

    static void ValidateRollbackBeforeUse(string rollback, string parent, string leaf, string id) {
        AssertTransactionPath(rollback, parent, leaf, id, "rollback");
        if (!Directory.Exists(rollback)) throw new IOException("事务 rollback 目录不存在");
        EnsureNoReparseExistingPath(rollback);
        if (Directory.GetFileSystemEntries(rollback).Length == 0) return;
        string launcherHash, reason;
        if (!TryReadInstallIdentity(rollback, out launcherHash, out reason))
            throw new IOException("事务 rollback 产品身份无效：" + reason);
        EnsureProtectedInstallTree(rollback);
    }

    static void CreateProtectedTransactionStage(string stage) {
        if (TestSkipAcl(stage)) { Directory.CreateDirectory(stage); return; }
        if (!IsElevated()) throw new UnauthorizedAccessException("创建受保护安装 staging 需要管理员权限");
        var admins = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null);
        var system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null);
        var inherit = InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit;
        var acl = new DirectorySecurity();
        acl.SetAccessRuleProtection(true, false); acl.SetOwner(admins);
        acl.AddAccessRule(new FileSystemAccessRule(system, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        acl.AddAccessRule(new FileSystemAccessRule(admins, FileSystemRights.FullControl, inherit, PropagationFlags.None, AccessControlType.Allow));
        Directory.CreateDirectory(stage, acl);
        EnsureNoReparseExistingPath(stage);
        EnsureExactAdminSystemEntry(stage, true);
        // 子文件在逐个 Harden 前可能由当前管理员 SID 成为 owner；High IL 的继承标签阻止
        // 同账号 medium token 在解压窗口内利用 owner 身份改 DACL/抢建 junction。
        string icacls = Path.Combine(Environment.SystemDirectory, "icacls.exe");
        using (var process = Process.Start(new ProcessStartInfo {
            FileName = icacls,
            Arguments = "\"" + stage + "\" /setintegritylevel (OI)(CI)H",
            UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden
        })) {
            if (process == null || !process.WaitForExit(15000) || process.ExitCode != 0)
                throw new IOException("无法给安装 staging 设置高完整性标签");
        }
        EnsureNoReparseExistingPath(stage);
        EnsureExactAdminSystemEntry(stage, true);
    }

    static void RecoverInterruptedRollback(string full, string parent, string leaf) {
        string prefix = "." + leaf + ".dfb-rollback-";
        var valid = new List<string[]>();
        foreach (string candidate in Directory.GetDirectories(parent, prefix + "*", SearchOption.TopDirectoryOnly)) {
            string name = Path.GetFileName(candidate);
            if (!name.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
            string id = name.Substring(prefix.Length);
            if (id.Length != 32 || !System.Text.RegularExpressions.Regex.IsMatch(id, "^[0-9a-fA-F]{32}$"))
                throw new IOException("发现命名异常的 rollback，已停止自动恢复：" + candidate);
            ValidateRollbackBeforeUse(candidate, parent, leaf, id);
            valid.Add(new string[] { candidate, id });
        }
        if (Directory.Exists(full)) {
            // 断电可能发生在 stage 已切成正式目录、旧 rollback 尚未来得及删除之后。
            // 只有正式目录和 rollback 都通过产品身份、ACL 与 reparse 复验时才回收旧副本。
            ValidateExistingInstallTarget(full);
            foreach (string[] item in valid) {
                try { ValidateRollbackBeforeUse(item[0], parent, leaf, item[1]); SafeDeleteTree(item[0]); }
                catch (Exception ex) {
                    LastMigrationNote = "检测到上次中断留下的 rollback，安全复验/清理失败，已原样保留：" +
                        item[0] + "；原因：" + ex.Message;
                }
            }
            return;
        }
        if (valid.Count > 1) throw new IOException("发现多份有效 rollback，已停止自动选择，请保留现场");
        if (valid.Count == 1) {
            MoveDirectoryWithRetry(valid[0][0], full);
            ValidateExistingInstallTarget(full);
            LastMigrationNote = "检测到上次断电/中断留下的 rollback，已先恢复旧版本再继续安装";
        }
    }

    static void CleanupCompletedStaging(string parent, string leaf) {
        string prefix = "." + leaf + ".dfb-stage-";
        foreach (string candidate in Directory.GetDirectories(parent, prefix + "*", SearchOption.TopDirectoryOnly)) {
            string name = Path.GetFileName(candidate);
            if (!name.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
            string id = name.Substring(prefix.Length);
            if (id.Length != 32 || !System.Text.RegularExpressions.Regex.IsMatch(id, "^[0-9a-fA-F]{32}$"))
                throw new IOException("发现命名异常的 staging，已停止自动清理：" + candidate);
            AssertTransactionPath(candidate, parent, leaf, id, "stage");
            try {
                // 仅回收已经完整解压、写入身份标记并完成 Harden 的 staging。若断电发生在
                // Harden 之前，子项 owner 可能仍是某个管理员账户；此时宁可保留现场，也不
                // 以高权限递归处理一棵尚未达到最终安全状态的目录树。
                string launcherHash, reason;
                if (!TryReadInstallIdentity(candidate, out launcherHash, out reason)) continue;
                EnsureProtectedInstallTree(candidate);
                SafeDeleteTree(candidate);
            } catch (Exception ex) {
                LastMigrationNote = "检测到上次中断留下的 staging，安全复验/清理失败，已原样保留：" +
                    candidate + "；原因：" + ex.Message;
            }
        }
    }

    // 全量解压到同卷兄弟 staging，逐文件按嵌入清单复验，再目录切换；失败时把旧目录移回。
    public static void Install(string dest, Action<int, int, string> onProgress) {
        Install(dest, onProgress, null);
    }

    public static void Install(string dest, Action<int, int, string> onProgress, string migrationSource) {
        string full = Path.GetFullPath(dest.Trim());
        string secure = CheckSecureInstallLocation(full);
        if (secure != null) throw new UnauthorizedAccessException(secure);
        if (File.Exists(full)) throw new IOException("安装目标已被同名文件占用：" + full);
        EnsureNoReparseExistingPath(full);
        ValidateExistingInstallTarget(full);
        string parent = Path.GetDirectoryName(full.TrimEnd('\\'));
        if (string.IsNullOrEmpty(parent)) throw new IOException("安装目标不能是磁盘根目录");
        EnsureNoReparseExistingPath(parent);
        Directory.CreateDirectory(parent);
        EnsureNoReparseExistingPath(parent);
        string leaf = Path.GetFileName(full.TrimEnd('\\'));
        RecoverInterruptedRollback(full, parent, leaf);
        ValidateExistingInstallTarget(full);
        CleanupCompletedStaging(parent, leaf);
        string id = Guid.NewGuid().ToString("N");
        string stage = Path.Combine(parent, "." + leaf + ".dfb-stage-" + id);
        string rollback = Path.Combine(parent, "." + leaf + ".dfb-rollback-" + id);
        AssertTransactionPath(stage, parent, leaf, id, "stage");
        AssertTransactionPath(rollback, parent, leaf, id, "rollback");
        if (Directory.Exists(stage) || File.Exists(stage) || Directory.Exists(rollback) || File.Exists(rollback))
            throw new IOException("随机事务目录已存在，安装已停止");
        bool oldMoved = false;
        bool newMoved = false;
        try {
            CreateProtectedTransactionStage(stage);
            EnsureNoReparseExistingPath(stage);
            ExtractAndVerifyPayload(stage, onProgress);

            if (Directory.Exists(full)) {
                EnsureTreeHasNoReparsePoints(full);
                CopyUserData(full, stage);
            }
            string migrationFull = null;
            if (!string.IsNullOrEmpty(migrationSource)) {
                migrationFull = Path.GetFullPath(migrationSource.Trim());
                // legacy 源对普通用户可写，管理员安装器不从中递归复制；原用户上下文负责将
                // 明确白名单数据迁到 LocalAppData，旧目录随后仅原子改名保留。
            }
            HardenInstalledTree(stage);

            string injectedFailure = TestInstallFailureAt(full);
            if (injectedFailure == "after-extract") throw new IOException("测试注入：after-extract");

            if (Directory.Exists(full)) {
                ValidateExistingInstallTarget(full);
                MoveDirectoryWithRetry(full, rollback);
                oldMoved = true;
                ValidateRollbackBeforeUse(rollback, parent, leaf, id);
            }
            if (injectedFailure == "after-old-move") throw new IOException("测试注入：after-old-move");
            MoveDirectoryWithRetry(stage, full);
            newMoved = true;

            if (oldMoved) {
                try { ValidateRollbackBeforeUse(rollback, parent, leaf, id); SafeDeleteTree(rollback); }
                catch (Exception ex) { LastMigrationNote = "旧版本 rollback 已安全保留，未递归清理：" + rollback + "；原因：" + ex.Message; }
            }
            if (!string.IsNullOrEmpty(migrationFull) && Directory.Exists(migrationFull) &&
                !string.Equals(migrationFull.TrimEnd('\\'), full.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) {
                QuarantineLegacyInstall(migrationFull);
            }
        } catch {
            if (oldMoved && !newMoved && !Directory.Exists(full) && Directory.Exists(rollback)) {
                ValidateRollbackBeforeUse(rollback, parent, leaf, id);
                MoveDirectoryWithRetry(rollback, full);
            }
            if (Directory.Exists(stage)) {
                try { AssertTransactionPath(stage, parent, leaf, id, "stage"); SafeDeleteTree(stage); } catch (Exception) { }
            }
            throw;
        }
    }

    public static string LastMenuDir;

    // 更新场景防双开（实机反馈「更新后新旧两个窗口并存」）：主程序在启动安装器后
    // 理应自退，但退不干净时这里兜底。只按主窗口标题精确匹配本程序的宿主进程——
    // 绝不按进程名杀 powershell（会误伤用户自己跑的其他脚本）。
    // 只发 WM_CLOSE 礼貌请求，绝不 Kill：旧实例可能正在执行优化/还原（其主窗口在忙碌时
    // 会拒绝 Closing），强杀等于把系统改到一半且备份写不完整。
    // 返回 false = 有实例拒绝退出，调用方必须放弃自动启动并明确告知用户。
    public static bool CloseRunningBooster() {
        int self = Process.GetCurrentProcess().Id;
        bool allClosed = true;
        try {
            foreach (var p in Process.GetProcesses()) {
                try {
                    if (p.Id == self) continue;
                    string t = p.MainWindowTitle;
                    if (string.IsNullOrEmpty(t) || t != "三角洲行动 · 画面优化助手") continue;
                    p.CloseMainWindow();
                    if (!p.WaitForExit(3000)) allClosed = false;
                } catch (Exception) { }
            }
        } catch (Exception) { }
        return allClosed;
    }

    // 开始菜单 Programs 目录的解析。教训（真机「装完找不到入口」）：安装器虽是 asInvoker，
    // 但用户会右键「以管理员身份运行」，或选 Program Files 触发提权重启——提权后
    // %APPDATA% 指向提权账号的目录，多账户机器上快捷方式会建进管理员的开始菜单，
    // 当前用户根本看不到，而 IPersistFile.Save 照样成功、安装显示成功。
    // 所以提权态一律写公共开始菜单（ProgramData，所有用户可见，也是常规安装器的
    // 标准做法）；非提权态同样只走 Known Folder（尊重 User Shell Folders 重定向，
    // 不信任调用进程可覆盖的 APPDATA 环境变量）。
    static string ProgramsDir() {
        string test = TestProgramsPath();
        if (!string.IsNullOrEmpty(test)) return test;
        if (IsElevated()) {
            string common = Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms);
            if (!string.IsNullOrEmpty(common)) return common;
        }
        return Environment.GetFolderPath(Environment.SpecialFolder.Programs);
    }

    // 桌面目录同理：提权态写公共桌面；DFB_TEST_DESKTOP 是沙箱验证的重定向钩子
    // （桌面没有对应的标准环境变量可用）
    static string DesktopDir() {
        string t = TestDesktopPath();
        if (!string.IsNullOrEmpty(t)) return t;
        if (IsElevated()) {
            string common = Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory);
            if (!string.IsNullOrEmpty(common)) return common;
        }
        return Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
    }

    // 桌面快捷方式：装完找不到入口的直接解药。完成页默认勾选，用户可取消
    public static string CreateDesktopShortcut(string dest) {
        string full = Path.GetFullPath(dest.Trim());
        string mainExe = Path.Combine(full, "启动优化工具.exe");
        string target = File.Exists(mainExe) ? mainExe : Path.Combine(full, "启动优化工具.bat");
        string lnk = Path.Combine(DesktopDir(), "三角洲行动优化助手.lnk");
        Shortcut.Create(lnk, target, full, File.Exists(mainExe) ? mainExe : null, 0,
            "三角洲行动 画面/帧率优化助手");
        return lnk;
    }

    public static string CreateShortcuts(string dest) {
        string menu = Path.Combine(ProgramsDir(), "DeltaForceBooster");
        Directory.CreateDirectory(menu);
        LastMenuDir = menu;
        string systemDir = Environment.SystemDirectory;
        if (string.IsNullOrEmpty(systemDir)) throw new InvalidOperationException("系统未提供受信 System32 路径");
        string mainExe = Path.Combine(dest, "启动优化工具.exe");
        if (File.Exists(mainExe)) {
            Shortcut.Create(Path.Combine(menu, "三角洲行动优化助手.lnk"),
                mainExe, dest, mainExe, 0, "三角洲行动 画面/帧率优化助手");
        } else {
            // 老包或残缺包里没有 exe 时退回 bat 入口，保证覆盖安装不炸
            Shortcut.Create(Path.Combine(menu, "三角洲行动优化助手.lnk"),
                Path.Combine(dest, "启动优化工具.bat"), dest, Path.Combine(systemDir, "imageres.dll"), 262,
                "三角洲行动 画面/帧率优化助手");
        }
        string uninstallExe = Path.Combine(dest, "卸载.exe");
        Shortcut.Create(Path.Combine(menu, "卸载优化助手.lnk"),
            File.Exists(uninstallExe) ? uninstallExe : Path.Combine(dest, "卸载.bat"), dest,
            File.Exists(uninstallExe) ? uninstallExe : Path.Combine(systemDir, "imageres.dll"),
            File.Exists(uninstallExe) ? 0 : 271,
            "卸载 DeltaForceBooster");
        return menu;
    }
}

// IShellLinkW COM：原生 Unicode 的快捷方式接口（ACP=1252 机器上 WScript.Shell 写中文必坏）
[ComImport, Guid("00021401-0000-0000-C000-000000000046")]
class CShellLink { }

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

static class Shortcut {
    public static void Create(string lnkPath, string target, string workDir, string iconPath, int iconIndex, string desc) {
        IShellLinkW link = (IShellLinkW)new CShellLink();
        link.SetPath(target);
        link.SetWorkingDirectory(workDir);
        link.SetDescription(desc);
        if (!string.IsNullOrEmpty(iconPath)) link.SetIconLocation(iconPath, iconIndex);
        ((IPersistFile)link).Save(lnkPath, true);
    }
}

// ---------------- 主题（取自主程序 GUI 的官网视觉基准） ----------------
static class Theme {
    public static SolidColorBrush B(string hex) {
        var b = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
        b.Freeze();
        return b;
    }
    public static readonly SolidColorBrush Green      = B("#FF00E884");
    public static readonly SolidColorBrush GreenHover = B("#FF3BF2A4");
    public static readonly SolidColorBrush Gold       = B("#FFE5C46A");
    public static readonly SolidColorBrush TextMain   = B("#FFE6F0EA");
    public static readonly SolidColorBrush TextSub    = B("#FF8FA69E");
    public static readonly SolidColorBrush TextFaint  = B("#FF5A6E66");
    public static readonly SolidColorBrush Line       = B("#FF1B2E28");
    public static readonly SolidColorBrush Line2      = B("#FF2A4A40");
    public static readonly SolidColorBrush InputBg    = B("#FF0A1613");
    public static readonly SolidColorBrush BtnBg      = B("#FF0F201B");
    public static readonly SolidColorBrush TitleBg    = B("#FF0D1417");
    public static readonly SolidColorBrush DarkOnGreen = B("#FF06120D");
    public static readonly SolidColorBrush Red        = B("#FFFF6B5E");
    public static readonly SolidColorBrush WarnBoxBg  = B("#FF171307");
    public static readonly SolidColorBrush WarnBoxLine = B("#66E5C46A");
    public static readonly FontFamily Mono = new FontFamily("Consolas");
}

// ---------------- 安装向导窗口（界面全部代码构建，不依赖 XAML 编译） ----------------
class SetupWindow : Window {
    const double BarWidth = 500;                 // 进度条轨道宽度（像素），填充按比例算
    static readonly string[] StepNames = { "欢迎", "安装位置", "安装", "完成" };

    Grid[] _pages;
    TextBlock[] _stepNums, _stepLabels;
    TextBox _pathBox;
    TextBlock _spaceText, _warnText, _dlWarnText, _pctText, _cntText, _fileText, _destText, _hintText;
    Border _barFill, _closeBtn;
    Grid _btnNext, _btnBack, _btnInstall, _btnFinish, _btnCancel;
    TextBlock _checkMark, _deskMark, _menuMark;
    bool _runChecked = true;
    bool _deskChecked = true;   // 桌面快捷方式默认勾选：真机反馈「装完找不到入口」的直接解药
    bool _menuChecked = true;   // 开始菜单快捷方式默认勾选（原先无条件创建，现交给用户）
    bool _installing;
    string _installedDir;
    int _curStep;

    public SetupWindow(string presetDir) {
        Title = "三角洲行动优化助手 · 安装向导";
        Width = 700; Height = 600;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        BorderBrush = Theme.Line; BorderThickness = new Thickness(1);
        FontFamily = new FontFamily("Microsoft YaHei UI");
        FontSize = 12;
        Foreground = Theme.TextMain;
        Content = BuildRoot();
        ShowStep(0);
        _pathBox.Text = Installer.DefaultDir();
        // 提权重启回传路径时直接落到位置页，别让用户从头再点一遍
        if (!string.IsNullOrEmpty(presetDir)) { _pathBox.Text = presetDir; ShowStep(1); }
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e) {
        // 解包中途关窗口会留下半套文件，禁止
        if (_installing) e.Cancel = true;
        base.OnClosing(e);
    }

    // ---------- 结构 ----------
    UIElement BuildRoot() {
        var root = new Grid();
        // 官网页面底色不是纯黑：带青绿调的细微垂直渐变。背景挂在根 Grid 上
        // 而不是 Window 上，离屏渲染视觉树时 PNG 才不会透明
        var bg = new LinearGradientBrush();
        bg.StartPoint = new Point(0, 0); bg.EndPoint = new Point(0, 1);
        bg.GradientStops.Add(new GradientStop((Color)ColorConverter.ConvertFromString("#FF0A1512"), 0));
        bg.GradientStops.Add(new GradientStop((Color)ColorConverter.ConvertFromString("#FF10201C"), 1));
        bg.Freeze();
        root.Background = bg;
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(46) });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(44) });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(62) });

        var title = BuildTitleBar(); Grid.SetRow(title, 0); root.Children.Add(title);
        var steps = BuildStepStrip(); Grid.SetRow(steps, 1); root.Children.Add(steps);

        var content = new Grid { Margin = new Thickness(38, 6, 38, 0) };
        _pages = new Grid[4];
        _pages[0] = BuildWelcomePage();
        _pages[1] = BuildLocationPage();
        _pages[2] = BuildProgressPage();
        _pages[3] = BuildFinishPage();
        foreach (var p in _pages) content.Children.Add(p);
        Grid.SetRow(content, 2); root.Children.Add(content);

        var bottom = BuildBottomBar(); Grid.SetRow(bottom, 3); root.Children.Add(bottom);
        return root;
    }

    UIElement BuildTitleBar() {
        var g = new Grid { Background = Theme.TitleBg };
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        // 与启动器 exe 图标同一枚三角 Logo
        var logo = new WShapes.Polygon {
            Points = new PointCollection {
                new Point(10, 2.5), new Point(19, 17.5), new Point(13, 17.5),
                new Point(10, 11.5), new Point(7, 17.5), new Point(1, 17.5)
            },
            Fill = Theme.Green, Width = 20, Height = 20,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(14, 0, 10, 0)
        };
        Grid.SetColumn(logo, 0); g.Children.Add(logo);

        var t = new TextBlock {
            Text = "三角洲行动优化助手 · 安装向导",
            Foreground = Theme.TextMain, FontWeight = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(t, 1); g.Children.Add(t);

        var ver = new TextBlock {
            Text = "SETUP v" + Program.Version,
            Foreground = Theme.Gold, FontFamily = Theme.Mono, FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 12, 0)
        };
        Grid.SetColumn(ver, 3); g.Children.Add(ver);

        var closeText = new TextBlock {
            Text = "\u2715", Foreground = Theme.TextSub, FontSize = 13,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center
        };
        _closeBtn = new Border { Width = 44, Background = Brushes.Transparent, Child = closeText, Cursor = Cursors.Hand };
        _closeBtn.MouseEnter += delegate { _closeBtn.Background = Theme.B("#FF3A2020"); closeText.Foreground = Brushes.White; };
        _closeBtn.MouseLeave += delegate { _closeBtn.Background = Brushes.Transparent; closeText.Foreground = Theme.TextSub; };
        _closeBtn.MouseLeftButtonUp += delegate { if (!_installing) Close(); };
        Grid.SetColumn(_closeBtn, 4); g.Children.Add(_closeBtn);

        var wrap = new Border { Child = g, BorderBrush = Theme.Line, BorderThickness = new Thickness(0, 0, 0, 1) };
        wrap.MouseLeftButtonDown += delegate(object s, MouseButtonEventArgs e) {
            if (e.OriginalSource != closeText) { try { DragMove(); } catch (Exception) { } }
        };
        return wrap;
    }

    UIElement BuildStepStrip() {
        var sp = new StackPanel {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        _stepNums = new TextBlock[4]; _stepLabels = new TextBlock[4];
        for (int i = 0; i < 4; i++) {
            _stepNums[i] = new TextBlock {
                Text = "0" + (i + 1), FontFamily = Theme.Mono, FontSize = 11,
                VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 5, 0)
            };
            _stepLabels[i] = new TextBlock { VerticalAlignment = VerticalAlignment.Center, Text = StepNames[i] };
            sp.Children.Add(_stepNums[i]);
            sp.Children.Add(_stepLabels[i]);
            if (i < 3) sp.Children.Add(new TextBlock {
                Text = "\u2014\u2014", Foreground = Theme.TextFaint,
                Margin = new Thickness(14, 0, 14, 0), VerticalAlignment = VerticalAlignment.Center
            });
        }
        return sp;
    }

    UIElement BuildBottomBar() {
        var g = new Grid();
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        _hintText = new TextBlock {
            Foreground = Theme.TextFaint, FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(38, 0, 0, 0)
        };
        Grid.SetColumn(_hintText, 0); g.Children.Add(_hintText);

        var sp = new StackPanel {
            Orientation = Orientation.Horizontal,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 30, 0)
        };
        _btnBack    = MakeButton("上一步", false, delegate { ShowStep(0); });
        _btnCancel  = MakeButton("取消", false, delegate { Close(); });
        _btnNext    = MakeButton("下一步", true, delegate { ShowStep(1); });
        _btnInstall = MakeButton("开始安装", true, OnInstallClick);
        _btnFinish  = MakeButton("完成", true, OnFinishClick);
        sp.Children.Add(_btnBack); sp.Children.Add(_btnCancel);
        sp.Children.Add(_btnNext); sp.Children.Add(_btnInstall); sp.Children.Add(_btnFinish);
        Grid.SetColumn(sp, 1); g.Children.Add(sp);

        return new Border { Child = g, BorderBrush = Theme.Line, BorderThickness = new Thickness(0, 1, 0, 0) };
    }

    // 官网 CTA 的斜切角按钮：Polygon 画形 + 文本叠放。不用原生 Button——
    // 重写它的 ControlTemplate 在纯代码里要 FrameworkElementFactory，可读性太差
    Grid MakeButton(string text, bool primary, Action onClick) {
        double w = 116, h = 36, cut = 9;
        var poly = new WShapes.Polygon {
            Points = new PointCollection {
                new Point(cut, 0), new Point(w, 0), new Point(w, h - cut),
                new Point(w - cut, h), new Point(0, h), new Point(0, cut)
            },
            Fill = primary ? (Brush)Theme.Green : Theme.BtnBg,
            Stroke = primary ? null : Theme.Line2,
            StrokeThickness = primary ? 0 : 1
        };
        var tb = new TextBlock {
            Text = text,
            Foreground = primary ? (Brush)Theme.DarkOnGreen : Theme.B("#FFC8D8D2"),
            FontWeight = primary ? FontWeights.Bold : FontWeights.Normal,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        var g = new Grid { Width = w, Height = h, Cursor = Cursors.Hand, Margin = new Thickness(10, 0, 0, 0) };
        g.Children.Add(poly); g.Children.Add(tb);
        g.MouseEnter += delegate {
            if (primary) poly.Fill = Theme.GreenHover;
            else { poly.Stroke = Theme.Green; tb.Foreground = Theme.TextMain; }
        };
        g.MouseLeave += delegate {
            if (primary) poly.Fill = Theme.Green;
            else { poly.Stroke = Theme.Line2; tb.Foreground = Theme.B("#FFC8D8D2"); }
        };
        g.MouseLeftButtonUp += delegate { if (g.IsEnabled) onClick(); };
        return g;
    }

    static TextBlock SectionLabel(string en, string zh) {
        return new TextBlock {
            Text = en + "  /  " + zh,
            Foreground = Theme.Gold, FontFamily = Theme.Mono, FontSize = 11,
            Margin = new Thickness(0, 6, 0, 10)
        };
    }

    // ---------- 页面 1：欢迎 ----------
    Grid BuildWelcomePage() {
        var page = new Grid();
        var sp = new StackPanel();
        sp.Children.Add(SectionLabel("SETUP WIZARD", "安装向导"));
        sp.Children.Add(new TextBlock {
            Text = "欢迎安装 三角洲行动优化助手",
            FontSize = 22, FontWeight = FontWeights.SemiBold, Foreground = Theme.TextMain
        });
        sp.Children.Add(new TextBlock {
            Text = "DELTA FORCE BOOSTER · 画面 / 帧率一键优化",
            Foreground = Theme.TextSub, FontFamily = Theme.Mono, FontSize = 11,
            Margin = new Thickness(0, 4, 0, 14)
        });
        sp.Children.Add(new TextBlock {
            Text = "本工具把主播教程里零散的系统级帧率优化一键做完：侦察硬件与系统状态 → 勾选优化项 → 一键执行。" +
                   "所有系统改动执行前都会自动备份到 ProgramData 的受保护备份区，随时可在界面里一键还原。",
            Foreground = Theme.TextSub, TextWrapping = TextWrapping.Wrap, LineHeight = 20
        });
        var warnBox = new StackPanel();
        warnBox.Children.Add(new TextBlock {
            Text = "安装前请知悉", Foreground = Theme.Gold, FontWeight = FontWeights.Bold,
            Margin = new Thickness(0, 0, 0, 6)
        });
        warnBox.Children.Add(new TextBlock {
            Text = "· 本安装包没有代码签名：首次运行时 Windows SmartScreen 可能显示「未知发布者」拦截页，需点「更多信息 → 仍要运行」。",
            Foreground = Theme.TextSub, TextWrapping = TextWrapping.Wrap, LineHeight = 19
        });
        warnBox.Children.Add(new TextBlock {
            Text = "· 优化会修改注册表、电源计划，并可禁用部分系统服务：杀毒软件存在误报甚至隔离的可能。所有脚本均为明文，可自行审阅后再用。",
            Foreground = Theme.TextSub, TextWrapping = TextWrapping.Wrap, LineHeight = 19,
            Margin = new Thickness(0, 4, 0, 0)
        });
        sp.Children.Add(new Border {
            Child = warnBox, Background = Theme.WarnBoxBg, BorderBrush = Theme.WarnBoxLine,
            BorderThickness = new Thickness(1), Padding = new Thickness(14, 10, 14, 12),
            Margin = new Thickness(0, 16, 0, 0)
        });
        sp.Children.Add(new TextBlock {
            Text = "系统优化在本地执行；联网功能包括检查更新、匿名使用统计和用户主动上传诊断报告。",
            Foreground = Theme.TextFaint, Margin = new Thickness(0, 12, 0, 0)
        });
        page.Children.Add(sp);
        return page;
    }

    // ---------- 页面 2：安装位置 ----------
    Grid BuildLocationPage() {
        var page = new Grid();
        var sp = new StackPanel();
        sp.Children.Add(SectionLabel("INSTALL LOCATION", "选择安装位置"));

        var row = new Grid();
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        _pathBox = new TextBox {
            Height = 34, VerticalContentAlignment = VerticalAlignment.Center,
            Background = Theme.InputBg, Foreground = Theme.TextMain,
            BorderBrush = Theme.Line2, BorderThickness = new Thickness(1),
            CaretBrush = Theme.Green, Padding = new Thickness(8, 0, 8, 0),
            FontFamily = Theme.Mono, FontSize = 12
        };
        _pathBox.TextChanged += delegate { UpdateSpaceInfo(); };
        Grid.SetColumn(_pathBox, 0); row.Children.Add(_pathBox);
        var browse = MakeButton("浏览…", false, OnBrowseClick);
        browse.Height = 34;
        Grid.SetColumn(browse, 1); row.Children.Add(browse);
        sp.Children.Add(row);

        sp.Children.Add(new TextBlock {
            Text = "路径可直接编辑；通过「浏览…」选择目录时会自动附加 DeltaForceBooster 子目录。",
            Foreground = Theme.TextFaint, FontSize = 11, Margin = new Thickness(0, 6, 0, 0)
        });
        _spaceText = new TextBlock {
            Foreground = Theme.TextSub, FontFamily = Theme.Mono, FontSize = 12,
            Margin = new Thickness(0, 12, 0, 0)
        };
        sp.Children.Add(_spaceText);

        var keepBox = new TextBlock {
            Text = "覆盖安装保护：先完整暂存并校验，再原子切换，失败自动回滚。配置与自存方案保存在 LocalAppData，系统还原备份保存在 ProgramData，不会混进程序目录。",
            Foreground = Theme.TextSub, TextWrapping = TextWrapping.Wrap, LineHeight = 19
        };
        sp.Children.Add(new Border {
            Child = keepBox, Background = Theme.BtnBg, BorderBrush = Theme.Line,
            BorderThickness = new Thickness(1), Padding = new Thickness(14, 10, 14, 10),
            Margin = new Thickness(0, 14, 0, 0)
        });
        sp.Children.Add(new TextBlock {
            Text = "默认安装到 Program Files，真正写入时才按需请求管理员权限；程序文件不会留在普通进程可修改的目录。",
            Foreground = Theme.TextFaint, FontSize = 11, TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 10, 0, 0)
        });
        // 下载目录对普通用户可写，不能再作为程序代码安装位置。
        _dlWarnText = new TextBlock {
            Text = "当前位置在「下载」文件夹内，普通进程可以替换程序脚本。为保护系统操作，本安装器会拒绝该位置；请使用默认的 Program Files。",
            Foreground = Theme.Gold, TextWrapping = TextWrapping.Wrap, LineHeight = 19,
            Margin = new Thickness(0, 12, 0, 0), Visibility = Visibility.Collapsed
        };
        sp.Children.Add(_dlWarnText);
        _warnText = new TextBlock {
            Foreground = Theme.Gold, TextWrapping = TextWrapping.Wrap, LineHeight = 19,
            Margin = new Thickness(0, 12, 0, 0), Visibility = Visibility.Collapsed
        };
        sp.Children.Add(_warnText);
        page.Children.Add(sp);
        return page;
    }

    // ---------- 页面 3：安装进度 ----------
    Grid BuildProgressPage() {
        var page = new Grid();
        var sp = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 0, 40) };
        sp.Children.Add(SectionLabel("INSTALLING", "正在安装"));

        var track = new Border {
            Width = BarWidth, Height = 10, HorizontalAlignment = HorizontalAlignment.Left,
            Background = Theme.B("#FF12241E"), BorderBrush = Theme.Line2, BorderThickness = new Thickness(1),
            Margin = new Thickness(0, 10, 0, 0)
        };
        _barFill = new Border { Background = Theme.Green, HorizontalAlignment = HorizontalAlignment.Left, Width = 0 };
        track.Child = _barFill;
        sp.Children.Add(track);

        var info = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 10, 0, 0) };
        _pctText = new TextBlock {
            Text = "0%", Foreground = Theme.Gold, FontFamily = Theme.Mono, FontSize = 16,
            VerticalAlignment = VerticalAlignment.Center
        };
        _cntText = new TextBlock {
            Text = "", Foreground = Theme.TextSub, FontFamily = Theme.Mono, FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(14, 0, 0, 0)
        };
        info.Children.Add(_pctText); info.Children.Add(_cntText);
        sp.Children.Add(info);

        _fileText = new TextBlock {
            Text = "", Foreground = Theme.TextSub, FontFamily = Theme.Mono, FontSize = 11,
            TextTrimming = TextTrimming.CharacterEllipsis, Margin = new Thickness(0, 8, 0, 0)
        };
        sp.Children.Add(_fileText);
        sp.Children.Add(new TextBlock {
            Text = "正在解包程序文件，请勿关闭窗口。",
            Foreground = Theme.TextFaint, FontSize = 11, Margin = new Thickness(0, 16, 0, 0)
        });
        page.Children.Add(sp);
        return page;
    }

    // ---------- 页面 4：完成 ----------
    Grid BuildFinishPage() {
        var page = new Grid();
        var sp = new StackPanel();
        sp.Children.Add(SectionLabel("COMPLETE", "安装完成"));
        var head = new StackPanel { Orientation = Orientation.Horizontal };
        head.Children.Add(new TextBlock {
            Text = "\u2713", Foreground = Theme.Green, FontSize = 22, FontWeight = FontWeights.Bold,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 10, 0)
        });
        head.Children.Add(new TextBlock {
            Text = "安装完成", FontSize = 22, FontWeight = FontWeights.SemiBold,
            Foreground = Theme.TextMain, VerticalAlignment = VerticalAlignment.Center
        });
        sp.Children.Add(head);
        _destText = new TextBlock {
            Foreground = Theme.TextSub, FontFamily = Theme.Mono, FontSize = 12,
            TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 12, 0, 0)
        };
        sp.Children.Add(_destText);

        var box = new Border {
            Width = 16, Height = 16, Background = Theme.InputBg,
            BorderBrush = Theme.Line2, BorderThickness = new Thickness(1),
            VerticalAlignment = VerticalAlignment.Center
        };
        _checkMark = new TextBlock {
            Text = "\u2713", Foreground = Theme.Green, FontWeight = FontWeights.Bold, FontSize = 12,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, -2, 0, 0)
        };
        box.Child = _checkMark;
        // 勾选行顺序：开始菜单（含卸载入口）→ 桌面（「装完找不到入口」的直接解药）→ 立即运行
        _menuMark = MakeCheckMark();
        var menuRow = MakeCheckRow(_menuMark, "创建开始菜单快捷方式（含「卸载优化助手」入口）", new Thickness(0, 20, 0, 0));
        menuRow.MouseLeftButtonUp += delegate {
            _menuChecked = !_menuChecked;
            _menuMark.Visibility = _menuChecked ? Visibility.Visible : Visibility.Collapsed;
        };
        sp.Children.Add(menuRow);
        _deskMark = MakeCheckMark();
        var deskRow = MakeCheckRow(_deskMark, "创建桌面快捷方式（三角洲行动优化助手）", new Thickness(0, 10, 0, 0));
        deskRow.MouseLeftButtonUp += delegate {
            _deskChecked = !_deskChecked;
            _deskMark.Visibility = _deskChecked ? Visibility.Visible : Visibility.Collapsed;
        };
        sp.Children.Add(deskRow);
        var runRow = new StackPanel {
            Orientation = Orientation.Horizontal, Margin = new Thickness(0, 10, 0, 0), Cursor = Cursors.Hand
        };
        runRow.Children.Add(box);
        runRow.Children.Add(new TextBlock {
            Text = "立即运行 三角洲行动优化助手", Foreground = Theme.TextMain,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(8, 0, 0, 0)
        });
        runRow.MouseLeftButtonUp += delegate {
            _runChecked = !_runChecked;
            _checkMark.Visibility = _runChecked ? Visibility.Visible : Visibility.Collapsed;
        };
        sp.Children.Add(runRow);
        sp.Children.Add(new TextBlock {
            Text = "主界面始终以普通权限运行；只有执行或还原需要修改系统的项目时，才会单独弹出 UAC 确认。",
            Foreground = Theme.TextFaint, FontSize = 11, Margin = new Thickness(0, 8, 0, 0)
        });
        page.Children.Add(sp);
        return page;
    }

    static TextBlock MakeCheckMark() {
        return new TextBlock {
            Text = "✓", Foreground = Theme.Green, FontWeight = FontWeights.Bold, FontSize = 12,
            HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, -2, 0, 0)
        };
    }

    static StackPanel MakeCheckRow(TextBlock mark, string label, Thickness margin) {
        var box = new Border {
            Width = 16, Height = 16, Background = Theme.InputBg,
            BorderBrush = Theme.Line2, BorderThickness = new Thickness(1),
            VerticalAlignment = VerticalAlignment.Center, Child = mark
        };
        var row = new StackPanel { Orientation = Orientation.Horizontal, Margin = margin, Cursor = Cursors.Hand };
        row.Children.Add(box);
        row.Children.Add(new TextBlock {
            Text = label, Foreground = Theme.TextMain,
            VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(8, 0, 0, 0)
        });
        return row;
    }

    // ---------- 行为 ----------
    void ShowStep(int s) {
        _curStep = s;
        for (int i = 0; i < 4; i++) {
            _pages[i].Visibility = (i == s) ? Visibility.Visible : Visibility.Collapsed;
            bool cur = (i == s), done = (i < s);
            _stepNums[i].Foreground = cur ? Theme.Gold : (done ? (Brush)Theme.Green : Theme.TextFaint);
            _stepLabels[i].Foreground = cur ? (Brush)Theme.Green : (done ? (Brush)Theme.TextSub : Theme.TextFaint);
            _stepLabels[i].FontWeight = cur ? FontWeights.Bold : FontWeights.Normal;
        }
        _btnNext.Visibility    = (s == 0) ? Visibility.Visible : Visibility.Collapsed;
        _btnBack.Visibility    = (s == 1) ? Visibility.Visible : Visibility.Collapsed;
        _btnInstall.Visibility = (s == 1) ? Visibility.Visible : Visibility.Collapsed;
        _btnCancel.Visibility  = (s <= 1) ? Visibility.Visible : Visibility.Collapsed;
        _btnFinish.Visibility  = (s == 3) ? Visibility.Visible : Visibility.Collapsed;
        _closeBtn.Visibility   = (s == 2) ? Visibility.Hidden : Visibility.Visible;
        switch (s) {
            case 0: _hintText.Text = "安装过程只复制文件，不修改任何系统设置"; break;
            case 1: _hintText.Text = "默认安装到 Program Files，写入时按需提权"; break;
            case 2: _hintText.Text = "正在安装，请稍候…"; break;
            default: _hintText.Text = "遇到问题可通过开始菜单或安装目录里的「卸载.bat」卸载"; break;
        }
    }

    void UpdateSpaceInfo() {
        try {
            string full = Path.GetFullPath(_pathBox.Text.Trim());
            string driveRoot = Path.GetPathRoot(full);
            var di = new DriveInfo(driveRoot);
            _spaceText.Text = string.Format("所需空间 {0:F1} MB    可用空间 {1:F1} GB（{2}）",
                Installer.RequiredBytes() / 1048576.0,
                di.AvailableFreeSpace / 1073741824.0,
                driveRoot.TrimEnd('\\'));
            _spaceText.Foreground = Theme.TextSub;
        } catch (Exception) {
            _spaceText.Text = "无法识别目标磁盘，请检查路径。";
            _spaceText.Foreground = Theme.Red;
        }
        if (_warnText != null) _warnText.Visibility = Visibility.Collapsed;
        // 路径每次变化都重新判定是否在下载文件夹内，提示随之显隐
        if (_dlWarnText != null)
            _dlWarnText.Visibility = Installer.IsUnderDownloads(_pathBox.Text)
                ? Visibility.Visible : Visibility.Collapsed;
    }

    void OnBrowseClick() {
        var dlg = new WinForms.FolderBrowserDialog();
        dlg.Description = "选择安装位置（将自动创建 DeltaForceBooster 子目录）";
        try { if (Directory.Exists(_pathBox.Text.Trim())) dlg.SelectedPath = _pathBox.Text.Trim(); } catch (Exception) { }
        if (dlg.ShowDialog() == WinForms.DialogResult.OK) {
            string p = dlg.SelectedPath;
            string leaf = Path.GetFileName(p.TrimEnd('\\'));
            if (!string.Equals(leaf, "DeltaForceBooster", StringComparison.OrdinalIgnoreCase))
                p = Path.Combine(p, "DeltaForceBooster");
            _pathBox.Text = p;
        }
    }

    void ShowWarn(string msg, bool isError) {
        _warnText.Text = msg;
        _warnText.Foreground = isError ? (Brush)Theme.Red : Theme.Gold;
        _warnText.Visibility = Visibility.Visible;
    }

    void OnInstallClick() {
        string dest = _pathBox.Text.Trim();
        string err = Installer.CheckWritable(dest);
        if (err == null) {
            ShowStep(2);
            StartInstall(dest);
            return;
        }
        if (err == Installer.NeedAdmin && !Installer.IsElevated()) {
            // 默认 Program Files 需要一次 UAC；安装器本身仍是 asInvoker，显示向导时不提权。
            ShowWarn("默认 Program Files 需要管理员权限。确认后将以管理员身份重新启动安装向导。", false);
            var r = MessageBox.Show(this,
                "目标位置需要管理员权限：\n" + dest +
                "\n\n是否以管理员身份重新启动安装向导？",
                "需要管理员权限", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (r == MessageBoxResult.Yes) RelaunchElevated(dest);
        } else {
            ShowWarn("该位置不符合安全安装要求（" + err + "），请使用默认的 Program Files。", true);
        }
    }

    void RelaunchElevated(string dest) {
        var psi = new ProcessStartInfo {
            FileName = Assembly.GetExecutingAssembly().Location,
            Arguments = "/dir=\"" + dest + "\"",
            UseShellExecute = true,
            Verb = "runas"
        };
        try {
            Process.Start(psi);
            Application.Current.Shutdown();
        } catch (Exception) {
            // 用户在 UAC 上点了取消：留在位置页，什么都不做
        }
    }

    void StartInstall(string dest) {
        _installing = true;
        var th = new Thread(delegate() {
            try {
                Installer.Install(dest, delegate(int i, int n, string name) {
                    Dispatcher.BeginInvoke(new Action(delegate { SetProgress(i, n, name); }));
                });
                Dispatcher.Invoke(new Action(delegate {
                    _installing = false;
                    _installedDir = Path.GetFullPath(dest);
                    _destText.Text = "安装位置：" + _installedDir;
                    ShowStep(3);
                }));
            } catch (Exception ex) {
                Dispatcher.Invoke(new Action(delegate {
                    _installing = false;
                    MessageBox.Show(this, "安装失败：" + ex.Message + "\n\n可换一个位置重试。",
                        "安装向导", MessageBoxButton.OK, MessageBoxImage.Error);
                    ShowStep(1);
                }));
            }
        });
        th.IsBackground = true;
        th.Start();
    }

    void SetProgress(int i, int n, string name) {
        double pct = (n == 0) ? 0 : (double)i / n;
        _barFill.Width = Math.Max(0, (BarWidth - 2) * pct);
        _pctText.Text = ((int)(pct * 100)) + "%";
        _cntText.Text = i + " / " + n;
        _fileText.Text = name;
    }

    void OnFinishClick() {
        if (_menuChecked && _installedDir != null) {
            // 快捷方式建不上不该拦着完成流程：极端失败静默放过，安装本身已完成
            try { Installer.CreateShortcuts(_installedDir); } catch (Exception) { }
        }
        if (_deskChecked && _installedDir != null) {
            try { Installer.CreateDesktopShortcut(_installedDir); } catch (Exception) { }
        }
        if (_runChecked && _installedDir != null) {
            // 覆盖更新时旧版主程序可能还开着：礼貌请求旧实例关闭再启动，避免新旧窗口并存
            // （只按主窗口标题精确匹配，不动用户其他 powershell 进程）。拒绝退出多半是
            // 正在执行优化——绝不强杀，跳过自动启动并明示用户，安装本身已完成
            if (!Installer.CloseRunningBooster()) {
                MessageBox.Show(this,
                    "检测到旧版程序仍在运行（可能正在执行优化或还原），已跳过自动启动。\n\n请等待旧版完成并关闭后，再打开新版本。",
                    "安装向导", MessageBoxButton.OK, MessageBoxImage.Warning);
            } else {
                try {
                    Installer.StartInstalledApplication(_installedDir);
                } catch (Exception) {
                    // 自动启动失败不影响安装；开始菜单/桌面快捷方式仍可用普通用户 token 打开
                }
            }
        }
        Close();
    }

    // ---------- 离屏渲染支撑（/render 验证模式专用） ----------
    public void PrepareRenderState(int state) {
        switch (state) {
            case 0: ShowStep(0); break;
            case 1:
                _pathBox.Text = Installer.DefaultDir();
                UpdateSpaceInfo();
                ShowStep(1);
                break;
            case 2:
                ShowStep(2);
                SetProgress(14, 31, "scripts\\delta-booster.ps1");
                break;
            case 3:
                _destText.Text = "安装位置：" + Installer.DefaultDir();
                ShowStep(3);
                break;
            default:
                ShowStep(1);
                _pathBox.Text = "C:\\Program Files\\DeltaForceBooster";
                UpdateSpaceInfo();
                ShowWarn("默认 Program Files 需要管理员权限，开始安装时会按需提权。", false);
                break;
        }
    }

    public string DumpStrings() {
        var sb = new StringBuilder();
        sb.AppendLine("窗口标题=" + Title);
        sb.AppendLine("步骤=" + string.Join("/", StepNames));
        sb.AppendLine("欢迎标题=欢迎安装 三角洲行动优化助手");
        sb.AppendLine("按钮=上一步/取消/下一步/开始安装/完成/浏览…");
        sb.AppendLine("完成页勾选=创建开始菜单快捷方式（含「卸载优化助手」入口）/创建桌面快捷方式（三角洲行动优化助手）/立即运行 三角洲行动优化助手");
        sb.AppendLine("默认路径=" + Installer.DefaultDir());
        sb.AppendLine("所需空间行=" + _spaceText.Text);
        sb.AppendLine("权限警告=" + _warnText.Text);
        sb.AppendLine("下载目录提醒可见=" + (_dlWarnText.Visibility == Visibility.Visible));
        sb.AppendLine("下载目录提醒=" + _dlWarnText.Text);
        return sb.ToString();
    }
}
}
