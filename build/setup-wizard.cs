// DeltaForceBooster 图形安装向导 — 源码由 build\make-installer.ps1 注入版本号后用系统自带 csc 编译。
//
// 为什么是 C# + WPF 而不是沿用 IExpress：IExpress 的界面不可定制、无法让用户选安装位置；
// make-launcher.ps1 已验证「系统 csc 编译 + 内嵌图标/清单」这条零第三方依赖路线可行，这里沿用。
// 为什么 payload 内嵌为程序集资源（/resource:）：真正单文件分发，运行时直接从自身程序集解流，
// 不经过 IExpress 那种落盘自解压临时目录。
// 为什么清单是 asInvoker 而非 requireAdministrator：默认装 %LOCALAPPDATA% 不需要管理员；
// 只有用户主动选了受保护目录（写入预检失败）才引导按需提权重启（/dir= 回传已选路径），
// 避免对绝大多数用户弹无意义的 UAC。
// 为什么快捷方式走 IShellLinkW COM：本机实测 ACP=1252 时 WScript.Shell 会把中文转成 "?"
// 导致快捷方式保存失败，必须用原生 Unicode 接口。
//
// 命令行（全部供自动化验证，普通用户双击即图形向导）：
//   /dir=<路径>        预填安装位置（提权重启时回传用）
//   /silent /log=<文件> 静默安装（沙箱验证用，读 LOCALAPPDATA/APPDATA 环境变量以便重定向）
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
        bool silent = false;
        foreach (string a in args) {
            if (a.Equals("/silent", StringComparison.OrdinalIgnoreCase)) silent = true;
            else if (a.StartsWith("/dir=", StringComparison.OrdinalIgnoreCase)) dir = a.Substring(5).Trim('"');
            else if (a.StartsWith("/log=", StringComparison.OrdinalIgnoreCase)) logFile = a.Substring(5).Trim('"');
            else if (a.StartsWith("/render=", StringComparison.OrdinalIgnoreCase)) renderDir = a.Substring(8).Trim('"');
            else if (a.StartsWith("/checkdir=", StringComparison.OrdinalIgnoreCase)) checkDir = a.Substring(10).Trim('"');
        }
        if (checkDir != null) { Environment.Exit(RunCheck(checkDir, logFile)); return; }
        if (silent)           { Environment.Exit(RunSilent(dir, logFile)); return; }
        if (renderDir != null) { RunRender(renderDir); return; }
        var app = new Application();
        app.Run(new SetupWindow(dir));
    }

    static void Log(string file, string msg) {
        if (string.IsNullOrEmpty(file)) return;
        File.AppendAllText(file, DateTime.Now.ToString("HH:mm:ss") + " " + msg + "\r\n", new UTF8Encoding(true));
    }

    // 静默安装：沙箱验证的入口。日志落文件（winexe 没有控制台，这是唯一输出通道）
    static int RunSilent(string dir, string logFile) {
        try {
            string dest = string.IsNullOrEmpty(dir) ? Installer.DefaultDir() : dir;
            Log(logFile, "安装目标: " + dest);
            string err = Installer.CheckWritable(dest);
            if (err != null) { Log(logFile, "预检失败: " + err); return 2; }
            Installer.Install(dest, delegate(int i, int n, string name) {
                if (i == 1 || i == n || i % 20 == 0) Log(logFile, string.Format("  {0}/{1} {2}", i, n, name));
            });
            Log(logFile, "安装完成: " + dest);
            return 0;
        } catch (Exception ex) {
            Log(logFile, "安装失败: " + ex);
            return 1;
        }
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

    // 读环境变量而不是 GetFolderPath：后者绕过环境变量，沙箱验证没法重定向
    public static string DefaultDir() {
        string la = Environment.GetEnvironmentVariable("LOCALAPPDATA");
        if (string.IsNullOrEmpty(la)) la = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        return Path.Combine(la, "DeltaForceBooster");
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
        CreateShortcuts(full);
    }

    public static string CreateShortcuts(string dest) {
        string appdata = Environment.GetEnvironmentVariable("APPDATA");
        if (string.IsNullOrEmpty(appdata)) appdata = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        string menu = Path.Combine(appdata, "Microsoft\\Windows\\Start Menu\\Programs\\DeltaForceBooster");
        Directory.CreateDirectory(menu);
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
    TextBlock _spaceText, _warnText, _pctText, _cntText, _fileText, _destText, _hintText;
    Border _barFill, _closeBtn;
    Grid _btnNext, _btnBack, _btnInstall, _btnFinish, _btnCancel;
    TextBlock _checkMark;
    bool _runChecked = true;
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
            Text = "默认位置在用户目录，无需管理员权限；选择 Program Files 等受保护目录时，安装前会检测并引导提权。",
            Foreground = Theme.TextFaint, FontSize = 11, TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 10, 0, 0)
        });
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
            Text = "正在解包程序文件并创建开始菜单快捷方式，请勿关闭窗口。",
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
        sp.Children.Add(new TextBlock {
            Text = "开始菜单已创建「三角洲行动优化助手」与「卸载优化助手」快捷方式。",
            Foreground = Theme.TextSub, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 8, 0, 0)
        });

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
        var runRow = new StackPanel {
            Orientation = Orientation.Horizontal, Margin = new Thickness(0, 20, 0, 0), Cursor = Cursors.Hand
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
            case 1: _hintText.Text = "安装到用户目录无需管理员权限"; break;
            case 2: _hintText.Text = "正在安装，请稍候…"; break;
            default: _hintText.Text = "遇到问题可随时通过开始菜单卸载"; break;
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
            ShowWarn("该位置需要管理员权限。可以以管理员身份重新启动安装向导，或换一个位置（默认的用户目录不需要提权）。", false);
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
        if (_runChecked && _installedDir != null) {
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
                ShowWarn("该位置需要管理员权限。可以以管理员身份重新启动安装向导，或换一个位置（默认的用户目录不需要提权）。", false);
                break;
        }
    }

    public string DumpStrings() {
        var sb = new StringBuilder();
        sb.AppendLine("窗口标题=" + Title);
        sb.AppendLine("步骤=" + string.Join("/", StepNames));
        sb.AppendLine("欢迎标题=欢迎安装 三角洲行动优化助手");
        sb.AppendLine("按钮=上一步/取消/下一步/开始安装/完成/浏览…");
        sb.AppendLine("完成页勾选=立即运行 三角洲行动优化助手");
        sb.AppendLine("默认路径=" + Installer.DefaultDir());
        sb.AppendLine("所需空间行=" + _spaceText.Text);
        sb.AppendLine("权限警告=" + _warnText.Text);
        return sb.ToString();
    }
}
}
