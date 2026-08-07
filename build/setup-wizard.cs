// DeltaForceBooster 图形安装向导 — 源码由 build\make-installer.ps1 注入版本号后用系统自带 csc 编译。
//
// 为什么是 C# + WPF 而不是沿用 IExpress：IExpress 的界面不可定制、无法让用户选安装位置；
// make-launcher.ps1 已验证「系统 csc 编译 + 内嵌图标/清单」这条零第三方依赖路线可行，这里沿用。
// 为什么 payload 内嵌为程序集资源（/resource:）：真正单文件分发，运行时直接从自身程序集解流，
// 不经过 IExpress 那种落盘自解压临时目录。
// 为什么清单是 asInvoker 而非 requireAdministrator：默认装用户「下载」文件夹不需要管理员；
// 下载文件夹取自 Known Folder API（FOLDERID_Downloads，可被用户移到任意盘，SpecialFolder
// 枚举里没有它），取不到依次回退 %USERPROFILE%\Downloads → %LOCALAPPDATA%\DeltaForceBooster；
// 位置在下载文件夹内时就地金色提示存储感知/手动清空风险（只提示不阻止）；
// 沙箱重定向钩子 DFB_TEST_DOWNLOADS（Known Folder 不吃环境变量，与 DFB_TEST_DESKTOP 同类）。
// 只有用户主动选了受保护目录（写入预检失败）才引导按需提权重启（/dir= 回传已选路径），
// 避免对绝大多数用户弹无意义的 UAC。
// 为什么快捷方式走 IShellLinkW COM：本机实测 ACP=1252 时 WScript.Shell 会把中文转成 "?"
// 导致快捷方式保存失败，必须用原生 Unicode 接口。
// 快捷方式落点（真机踩过「装完找不到入口」）：提权态一律写公共开始菜单/公共桌面——
// 提权后 %APPDATA% 指向提权账号，多账户机器上会把快捷方式建进管理员的开始菜单；
// 完成页默认勾选「创建桌面快捷方式」与「创建开始菜单快捷方式」（后者原先无条件创建，
// 现同样交给勾选项控制），静默模式两者都创建。
// 更新场景防双开（实机反馈）：旧版主程序可能没退干净，完成页勾了「立即运行」时先按
// 主窗口标题精确匹配关掉旧实例再启动新的——绝不按进程名无差别杀 powershell。
//
// 命令行（全部供自动化验证，普通用户双击即图形向导）：
//   /dir=<路径>        预填安装位置（提权重启时回传用）
//   /silent /log=<文件> 静默安装（一键更新与沙箱验证共用，读 LOCALAPPDATA/APPDATA 环境变量以便重定向）
//   /waitpid=<进程Id>  静默安装前先等该进程退出（主程序占着自己的文件，不退就覆盖不了）
//   /runafter          静默安装完成后启动新版主程序；失败时弹框报错，绝不假装成功
//   /checkdir=<路径>   只跑写入权限预检，结果写 /log 文件
//   /render=<目录>     离屏渲染各页面为 PNG + 导出界面字符串（不弹窗，验证视觉与中文编码）
using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Threading;
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
[assembly: AssemblyCopyright("本地运行，不采集任何数据")]
[assembly: AssemblyVersion("__VER4__")]
[assembly: AssemblyFileVersion("__VER4__")]

namespace DfbSetup {

static class Program {
    public const string Version = "__VER__";

    [STAThread]
    static void Main(string[] args) {
        string dir = null, logFile = null, renderDir = null, checkDir = null;
        bool silent = false, runAfter = false;
        int waitPid = 0;
        foreach (string a in args) {
            if (a.Equals("/silent", StringComparison.OrdinalIgnoreCase)) silent = true;
            else if (a.Equals("/runafter", StringComparison.OrdinalIgnoreCase)) runAfter = true;
            else if (a.StartsWith("/dir=", StringComparison.OrdinalIgnoreCase)) dir = a.Substring(5).Trim('"');
            else if (a.StartsWith("/log=", StringComparison.OrdinalIgnoreCase)) logFile = a.Substring(5).Trim('"');
            else if (a.StartsWith("/waitpid=", StringComparison.OrdinalIgnoreCase)) int.TryParse(a.Substring(9).Trim('"'), out waitPid);
            else if (a.StartsWith("/render=", StringComparison.OrdinalIgnoreCase)) renderDir = a.Substring(8).Trim('"');
            else if (a.StartsWith("/checkdir=", StringComparison.OrdinalIgnoreCase)) checkDir = a.Substring(10).Trim('"');
        }
        if (checkDir != null) { Environment.Exit(RunCheck(checkDir, logFile)); return; }
        if (silent)           { Environment.Exit(RunSilent(dir, logFile, waitPid, runAfter)); return; }
        if (renderDir != null) { RunRender(renderDir); return; }
        var app = new Application();
        app.Run(new SetupWindow(dir));
    }

    static void Log(string file, string msg) {
        if (string.IsNullOrEmpty(file)) return;
        File.AppendAllText(file, DateTime.Now.ToString("HH:mm:ss") + " " + msg + "\r\n", new UTF8Encoding(true));
    }

    // 静默安装：一键更新与沙箱验证共用。日志落文件（winexe 没有控制台，这是唯一输出通道）。
    // /runafter 时属于用户点了「立即更新」的链路——主程序此刻已退出，失败必须弹框，
    // 否则用户看着窗口关掉、新版没起来，完全不知道发生了什么
    static int RunSilent(string dir, string logFile, int waitPid, bool runAfter) {
        string dest = null;
        try {
            dest = string.IsNullOrEmpty(dir) ? Installer.DefaultDir() : dir;
            Log(logFile, "安装目标: " + dest);
            if (waitPid > 0) Log(logFile, "等待旧进程退出(" + waitPid + "): " + WaitForPid(waitPid));
            string err = Installer.CheckWritable(dest);
            if (err != null) {
                Log(logFile, "预检失败: " + err);
                if (runAfter) FailBox(dest, err == Installer.NeedAdmin ? "目标目录没有写入权限。" : ("目标目录不可写：" + err));
                return 2;
            }
            Installer.Install(dest, delegate(int i, int n, string name) {
                if (i == 1 || i == n || i % 20 == 0) Log(logFile, string.Format("  {0}/{1} {2}", i, n, name));
            });
            // 静默模式与向导完成页的默认勾选保持一致：开始菜单与桌面快捷方式都建
            Log(logFile, "开始菜单快捷方式: " + Installer.CreateShortcuts(dest));
            Log(logFile, "桌面快捷方式: " + Installer.CreateDesktopShortcut(dest));
            Log(logFile, "安装完成: " + dest);
            if (runAfter) Log(logFile, "启动新版: " + LaunchInstalled(dest));
            return 0;
        } catch (Exception ex) {
            Log(logFile, "安装失败: " + ex);
            if (runAfter) FailBox(dest, ex.Message);
            return 1;
        }
    }

    // 主程序占着自己的文件，不等它退出就覆盖必失败。按 Id 精确等待，绝不按进程名杀 powershell；
    // 超时不强杀——宁可让下面的覆盖步骤报错，也不冒险打断用户正在跑的优化
    static string WaitForPid(int pid) {
        try {
            var p = Process.GetProcessById(pid);
            if (p.WaitForExit(30000)) return "已退出";
            return "等待超时（30 秒），仍继续尝试";
        } catch (ArgumentException) {
            return "进程已不存在";
        } catch (Exception ex) { return "等待异常: " + ex.Message; }
    }

    static string LaunchInstalled(string dest) {
        try {
            string exe = Path.Combine(dest, "启动优化工具.exe");
            if (!File.Exists(exe)) return "未找到 " + exe;
            // 沙箱验证钩子（与 DFB_TEST_DESKTOP / DFB_TEST_DOWNLOADS 同类）：验证要走完
            // 参数解析与时序，但绝不能真把主程序拉起来——它会自提权弹 UAC 打断验证
            if (Environment.GetEnvironmentVariable("DFB_TEST_NOLAUNCH") == "1")
                return "跳过启动（DFB_TEST_NOLAUNCH=1）: " + exe;
            // 主程序退不干净时的兜底（只按主窗口标题精确匹配），防止新旧窗口并存
            Installer.CloseRunningBooster();
            Process.Start(new ProcessStartInfo { FileName = exe, WorkingDirectory = dest, UseShellExecute = true });
            return "已启动";
        } catch (Exception ex) { return "启动失败: " + ex.Message; }
    }

    static void FailBox(string dest, string reason) {
        try {
            WinForms.MessageBox.Show(
                "更新安装失败：" + reason +
                "\r\n\r\n安装位置：" + (dest ?? "(未确定)") +
                "\r\n\r\n原来的版本没有被破坏，可以正常继续使用。请前往 https://df.ltz88.cn/ 下载安装包手动更新。",
                "三角洲行动优化助手 · 更新失败",
                WinForms.MessageBoxButtons.OK, WinForms.MessageBoxIcon.Error);
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
        string t = Environment.GetEnvironmentVariable("DFB_TEST_DOWNLOADS");
        if (!string.IsNullOrEmpty(t)) return t;
        string kf = KnownDownloads();
        if (kf != null) return kf;
        // 回退 ①：未重定向机器上的实际位置
        string up = Environment.GetEnvironmentVariable("USERPROFILE");
        if (!string.IsNullOrEmpty(up)) {
            string dl = Path.Combine(up, "Downloads");
            if (Directory.Exists(dl)) return dl;
        }
        return null;
    }

    // 默认装到「下载」文件夹（用户明确要求，找得到、无需管理员）；
    // 位置页会就地提示存储感知/手动清空的风险，但不阻止
    public static string DefaultDir() {
        string dl = DownloadsDir();
        if (!string.IsNullOrEmpty(dl)) return Path.Combine(dl, "DeltaForceBooster");
        // 回退 ②：沿用老默认值 %LOCALAPPDATA%，读环境变量优先以便沙箱重定向
        string la = Environment.GetEnvironmentVariable("LOCALAPPDATA");
        if (string.IsNullOrEmpty(la)) la = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(la, "DeltaForceBooster");
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

    // 解包后所需字节数（zip 各条目原始大小之和），位置页展示用
    public static long RequiredBytes() {
        if (_requiredBytes >= 0) return _requiredBytes;
        long sum = 0;
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("DFB.Payload"))
        using (var za = new ZipArchive(s, ZipArchiveMode.Read)) {
            foreach (var e in za.Entries) sum += e.Length;
        }
        _requiredBytes = sum;
        return sum;
    }

    // 写入权限预检：在最近的已存在祖先目录里真实写一个临时文件。
    // 只有实际写一把才可靠——按路径前缀猜「是否受保护」会漏掉网络盘、只读盘等各种情况
    public static string CheckWritable(string dest) {
        if (string.IsNullOrEmpty(dest) || dest.Trim().Length == 0) return "路径为空";
        string full;
        try {
            full = Path.GetFullPath(dest.Trim());
            if (!Path.IsPathRooted(full)) return "请输入带盘符的完整路径";
        } catch (Exception) { return "路径格式无效"; }
        string probe = full;
        while (!Directory.Exists(probe)) {
            string parent = null;
            try { parent = Path.GetDirectoryName(probe); } catch (Exception) { }
            if (string.IsNullOrEmpty(parent)) return "目标磁盘或根目录不存在";
            probe = parent;
        }
        try {
            string test = Path.Combine(probe, ".dfb-write-test-" + Process.GetCurrentProcess().Id);
            File.WriteAllText(test, "t");
            File.Delete(test);
            return null;
        } catch (UnauthorizedAccessException) { return NeedAdmin; }
        catch (Exception ex) { return ex.Message; }
    }

    // 解包 + 建快捷方式。覆盖安装保护：profiles\ backup\ config\ 下已存在的文件一律不动——
    // 那是用户的自存方案、系统还原凭据和运行状态，覆盖等于毁数据
    public static void Install(string dest, Action<int, int, string> onProgress) {
        string full = Path.GetFullPath(dest.Trim());
        Directory.CreateDirectory(full);
        string[] keep = { "profiles", "backup", "config" };
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("DFB.Payload"))
        using (var za = new ZipArchive(s, ZipArchiveMode.Read)) {
            int total = za.Entries.Count, i = 0;
            foreach (var e in za.Entries) {
                i++;
                // PowerShell 5.1 的 Compress-Archive 用反斜杠作分隔符，统一成 Windows 形式
                string rel = e.FullName.Replace('/', '\\').TrimStart('\\');
                string target = Path.GetFullPath(Path.Combine(full, rel));
                // zip 路径穿越防御：条目解析后必须仍在安装目录之内
                if (!target.StartsWith(full + "\\", StringComparison.OrdinalIgnoreCase)) continue;
                if (rel.EndsWith("\\")) { Directory.CreateDirectory(target); continue; }
                string top = rel.Split('\\')[0].ToLowerInvariant();
                if (Array.IndexOf(keep, top) >= 0 && File.Exists(target)) {
                    if (onProgress != null) onProgress(i, total, "保留 " + rel);
                    continue;
                }
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                e.ExtractToFile(target, true);
                if (onProgress != null) onProgress(i, total, rel);
            }
        }
        // 开始菜单快捷方式不再在这里无条件创建：完成页勾选项控制（默认勾选），
        // 静默模式由 RunSilent 显式创建，行为与默认勾选一致
    }

    public static string LastMenuDir;

    // 更新场景防双开（实机反馈「更新后新旧两个窗口并存」）：主程序在启动安装器后
    // 理应自退，但退不干净时这里兜底。只按主窗口标题精确匹配本程序的宿主进程——
    // 绝不按进程名杀 powershell（会误伤用户自己跑的其他脚本）。
    public static void CloseRunningBooster() {
        int self = Process.GetCurrentProcess().Id;
        try {
            foreach (var p in Process.GetProcesses()) {
                try {
                    if (p.Id == self) continue;
                    string t = p.MainWindowTitle;
                    if (string.IsNullOrEmpty(t) || t != "三角洲行动 · 画面优化助手") continue;
                    // 先礼后兵：WM_CLOSE 给它机会正常收尾，1.5 秒不退再强杀
                    p.CloseMainWindow();
                    if (!p.WaitForExit(1500)) p.Kill();
                } catch (Exception) { }
            }
        } catch (Exception) { }
    }

    // 开始菜单 Programs 目录的解析。教训（真机「装完找不到入口」）：安装器虽是 asInvoker，
    // 但用户会右键「以管理员身份运行」，或选 Program Files 触发提权重启——提权后
    // %APPDATA% 指向提权账号的目录，多账户机器上快捷方式会建进管理员的开始菜单，
    // 当前用户根本看不到，而 IPersistFile.Save 照样成功、安装显示成功。
    // 所以提权态一律写公共开始菜单（ProgramData，所有用户可见，也是常规安装器的
    // 标准做法）；非提权态仍按环境变量解析（沙箱验证靠重定向 APPDATA），缺失时
    // 回退 SHGetFolderPath（尊重 User Shell Folders 重定向）。
    static string ProgramsDir() {
        if (IsElevated()) {
            string common = Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms);
            if (!string.IsNullOrEmpty(common)) return common;
        }
        string appdata = Environment.GetEnvironmentVariable("APPDATA");
        if (string.IsNullOrEmpty(appdata)) return Environment.GetFolderPath(Environment.SpecialFolder.Programs);
        return Path.Combine(appdata, "Microsoft\\Windows\\Start Menu\\Programs");
    }

    // 桌面目录同理：提权态写公共桌面；DFB_TEST_DESKTOP 是沙箱验证的重定向钩子
    // （桌面没有对应的标准环境变量可用）
    static string DesktopDir() {
        string t = Environment.GetEnvironmentVariable("DFB_TEST_DESKTOP");
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
        string sysroot = Environment.GetEnvironmentVariable("SystemRoot");
        if (string.IsNullOrEmpty(sysroot)) sysroot = "C:\\Windows";
        string mainExe = Path.Combine(dest, "启动优化工具.exe");
        if (File.Exists(mainExe)) {
            Shortcut.Create(Path.Combine(menu, "三角洲行动优化助手.lnk"),
                mainExe, dest, mainExe, 0, "三角洲行动 画面/帧率优化助手");
        } else {
            // 老包或残缺包里没有 exe 时退回 bat 入口，保证覆盖安装不炸
            Shortcut.Create(Path.Combine(menu, "三角洲行动优化助手.lnk"),
                Path.Combine(dest, "启动优化工具.bat"), dest, sysroot + "\\System32\\imageres.dll", 262,
                "三角洲行动 画面/帧率优化助手");
        }
        Shortcut.Create(Path.Combine(menu, "卸载优化助手.lnk"),
            Path.Combine(dest, "卸载.bat"), dest, sysroot + "\\System32\\imageres.dll", 271,
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
                   "所有系统改动执行前都会自动备份到安装目录的 backup\\ 文件夹，随时可在界面里一键还原。",
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
            Text = "全部本地运行，不采集、不上传任何数据。",
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
            Text = "覆盖安装保护：目标目录里已存在的 profiles\\（自存方案）、backup\\（系统还原备份）、config\\（运行状态）不会被覆盖或删除。",
            Foreground = Theme.TextSub, TextWrapping = TextWrapping.Wrap, LineHeight = 19
        };
        sp.Children.Add(new Border {
            Child = keepBox, Background = Theme.BtnBg, BorderBrush = Theme.Line,
            BorderThickness = new Thickness(1), Padding = new Thickness(14, 10, 14, 10),
            Margin = new Thickness(0, 14, 0, 0)
        });
        sp.Children.Add(new TextBlock {
            Text = "默认装到「下载」文件夹，无需管理员权限；选择 Program Files 等受保护目录时，安装前会检测并引导提权。",
            Foreground = Theme.TextFaint, FontSize = 11, TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 10, 0, 0)
        });
        // 下载目录的具体隐患要如实讲，但只提示不阻止——默认值就是用户点名要的
        _dlWarnText = new TextBlock {
            Text = "当前位置在「下载」文件夹内：Windows「存储感知」可配置为自动删除下载文件夹里长期未打开的文件，也有人定期手动清空这里——程序连同安装目录内 backup\\ 里的系统还原备份会一起丢失。长期使用建议换个位置；继续安装也没问题。",
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
            Text = "首次运行会请求一次管理员权限（优化需要修改电源计划等系统级设置）。",
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
            case 1: _hintText.Text = "默认安装位置无需管理员权限"; break;
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
            // 不能默默失败：明确告知需要提权，让用户选提权重启还是换位置
            ShowWarn("该位置需要管理员权限。可以以管理员身份重新启动安装向导，或换一个位置（默认位置不需要提权）。", false);
            var r = MessageBox.Show(this,
                "目标位置需要管理员权限：\n" + dest +
                "\n\n是否以管理员身份重新启动安装向导？\n（选「否」则请更换安装位置）",
                "需要管理员权限", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (r == MessageBoxResult.Yes) RelaunchElevated(dest);
        } else {
            ShowWarn("该位置无法写入（" + err + "），请更换安装位置。", true);
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
            // 覆盖更新时旧版主程序可能还开着：先关掉旧实例再启动，避免新旧两个窗口并存
            // （只按主窗口标题精确匹配，不动用户其他 powershell 进程）
            Installer.CloseRunningBooster();
            string exe = Path.Combine(_installedDir, "启动优化工具.exe");
            try {
                Process.Start(new ProcessStartInfo {
                    FileName = exe, WorkingDirectory = _installedDir, UseShellExecute = true
                });
            } catch (Exception) {
                // 用户取消了主程序的 UAC：安装本身已完成，不拦着关窗口
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
                ShowWarn("该位置需要管理员权限。可以以管理员身份重新启动安装向导，或换一个位置（默认位置不需要提权）。", false);
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
