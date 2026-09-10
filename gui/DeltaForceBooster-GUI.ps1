<#
  DeltaForceBooster 图形界面 — v0.23.0.13
  视觉基准：三角洲行动国服官网 df.qq.com 实测提炼：近黑微青顶栏 #0D1417 + 页面青绿细
  渐变 #0A1512→#10201C + 正绿 CTA #00E884（斜切角）+ 深色金黄辅助标签
  + 中英上下叠排分区标题 + 侧边刻度尺装饰 + 拉字距装饰分隔线。

  v0.23.0.13：修复早期版本对 DeltaForceClient.exe 应用进程优先级后，新版读取
         历史备份误报“备份注册表目标不在白名单”、导致还原列表及还原操作失败的问题。
  v0.23.0.12：停止新应用会在系统盘创建超大页面文件的虚拟内存项；内存压缩项改为仅手动选择；
         历史虚拟内存与全部纯注册表优化支持按项目精确复原；停用无自动备份的 NPI 导入；
         修复其他登录会话导致首次启动误报“已运行”，重复点击会置前现有窗口；NVIDIA
         型号伪装改为笔记本推荐 GTX 1050 Ti、台式机推荐 GTX 750 Ti。
  v0.23.0.11：修复软件内立即重启在部分电脑上点击后没有反应的问题；运行日志改为跨会话保留，
         重新打开后可直接复制或随完整诊断上传，并补充 VBS/内存完整性状态。
  v0.23.0.10：修复已有 PawnIO 驱动或残留组件时安装可能报退出码 183 并中断的问题；
         扩展现有驱动识别，温度驱动未就绪时不再阻断软件主体安装。
  v0.23.0.9：修复下载服务器繁忙时内置更新直接失败并显示底层 HTTP 错误的问题；
         现在会按服务器等待时间自动重试，持续繁忙时显示清晰提示；增强旧版本更新兼容性。
  v0.23.0.8：电源计划优化新增统一风险确认，更新后首次启动会按用户提醒异常时的恢复方法；
         修复部分网吧、公共电脑或内置 Administrator 环境内置更新后启动验证失败的问题；
         本版本为强制更新。
  v0.23.0.7：全部还原可自动处理历史电源设置残留，并在受限时安全切换到 Windows「平衡」；
         优化电源方案隔离与重启提示；启动场景选择更直观；下载排队增加预计等待时间；
         本版本包含关键还原修复，旧版本需完成更新后继续使用。
  v0.23.0.6：下载并发调整为 3；排队显示前方人数与预计时间，并可取消后立即释放票据。
  v0.23.0.5：安装包下载增加服务器排队位置与自动开始提示；网络读取超时或连接中断时按已接收字节
         自动续传，失败提示不再暴露底层 Read 调用异常。
  v0.23.0.4：修复部分环境中安装器把所有 NTFS 磁盘误判为不可用的问题；内置 LibreHardwareMonitor
         与签名 PawnIO 驱动，直接读取可信 CPU/GPU 温度。
  v0.23.0.3：修复原电源方案被删除或失效时还原会反复失败的问题；现在会回退到 Windows「平衡」并记录提示；
         全量还原存在失败时明确显示「还原未完成」，成功回退会写入还原凭证，重复点击不再重复执行。
  v0.23.0.2：修正实时 FPS 的显示帧率与主交换链统计口径；CPU 温度缺少可信传感器源时说明原因；
         显卡型号伪装支持单独还原。
  v0.23.0.1：修复其他盘的既有安装因启动器缺失而阻止重新安装的问题；残缺目录会先保留，失败时恢复现场。
  v0.23.0.0：CPU/GPU 硬件与温度卡提前；FPS、CPU/GPU/内存卡直接显示记录变化并可查看历史；
         百分号与温度单位跟随数值字号和颜色；深色主题恢复金黄强调色，移除执行优化按钮内的
         等高线，并用绿色数字角标提醒未读消息。
  v0.22.10：CPU 占用改用 Windows Processor Utility 口径，避免混合架构处理器明显偏低；
         不再把主板 ACPI 温区冒充为 CPU 封装温度；主窗口默认增高并记住上次高度。
  v0.22.9：新增实时硬件状态与显示器信息，拉长主窗口以完整展示新增内容，
        并将软件通知正文上限提高至 10000 字。
  v0.22.8：修复未选择显卡伪装型号时管理员请求触发参数验证失败的问题。
  v0.22.7：修复管理员引擎通过 RequestFile 启动时被误判为混合参数的问题。
  v0.22.6：修复执行优化和读取还原目录时可选参数被误判的问题。
  v0.22.5：修复部分电脑执行优化或读取还原项目时管理员引擎异常退出的问题，并回传具体错误原因。
  v0.22.4：新增软件通知中心、未读提醒与历史消息，本地缓存支持断网查看。
  v0.22.3：修复一些已知问题。
  v0.22.2：修复一些已知问题。
  v0.22.1：①修复部分电脑无法正确检测 NVIDIA、AMD、Intel 显卡控制软件的问题；
        ②诊断反馈新增「游戏内部分区域黑屏 / 黑块」；③修复异常或不完整的性能采样
        被误判为有效记录的问题。
  v0.22.0：①「还原设置」支持按项目单选、多选和全选精确复原，并保护用户后续修改；
        ②新增「掉帧修复」页及可直接执行的缓存清理、高性能 GPU 和运行库体检入口；
        ③修复电源计划空操作崩溃、部分电脑首次启动受阻和显卡厂商识别失败；④内存频率
        体检不再把达到标称频率误报为未开档位，并区分 MSI AMD DDR4 与 ROG 魔霸笔记本。
  v0.21.6：①更新安装器在新版出现可交互窗口前保留旧版本；新版启动失败或安装器在验证
        阶段中断时自动恢复旧版本；②上传完整诊断前新增问题与改善效果多选页；③游戏内
        设置参考新增性能优先方案；④显卡型号伪装新增 RTX 2050/2060/RX560 并恢复 AMD
        支持；⑤AMD 驱动指引新增按本机配置推荐方案；⑥新增电脑品牌检测，XMP/EXPO 的
        BIOS 进入教程按品牌区分。
  v0.21.5：修复非中文区域设置（ACP≠936）的机器上软件完全无法启动：QueryFullProcessImageName
        的 P/Invoke 缺 CharSet.Unicode，绑到 ANSI 变体后「启动优化工具.exe」被转成 ??????.exe，
        .NET Framework 的 Path.GetFullPath 拒绝 ? 通配符，EngineHost 启动即死。卸载宿主同病同修。
  v0.21.4：启动器收尾不再对 EngineHost 直接读 ExitCode——那会抛「进程不是由此对象启动的」，
        把 EngineHost 真正的失败原因盖成一句无关报错；现在读不到就如实说明。会话建立后
        出错也不再谎称「启动失败」。
  v0.21.3：修复了一些已知问题。
  v0.21.1：修复了一些已知问题。
  v0.21.0：修复了一些已知问题。
  v0.20.4：修复了一些已知问题。
  v0.20.3：修复了一些已知问题。
  v0.20.2：修复了一些已知问题。
  v0.20.1：修复从 v0.19.x 等旧安装目录更新时，安装器错误要求旧版必须包含
        scripts\tuning-experiment.ps1，导致更新失败并被强制更新窗口锁住的问题。
  v0.20.0：①新增「自动寻找最佳配置 Beta」，以同一设备三次基线和 A/B 交替采样测试
        G1/G2/G3 三组低风险配置，按平均帧率、1% 低帧率、P99、卡顿、温度与功耗
        决定保留或定向回滚；②实验状态原子保存，异常退出后可继续或安全恢复，普通采样
        与实验采样隔离；③修复更新、安装、备份还原、权限边界、多显卡识别和性能记录等
        已知问题，旧版本必须升级后继续使用。
  v0.19.4：①主界面改为普通权限，程序默认进入 Program Files；系统修改由短生命周期
        管理员引擎执行，关键文件、更新暂存和事务安装均增加校验；②备份升级为受保护的
        HMAC 写前日志，失败退出码与还原结果不再误报；③混合/多 NVIDIA 主卡、IRQ 和性能
        采样按 PCI 位置对齐，1% 低帧率改按最慢 1% 帧的平均帧时间计算；④修复诊断报告
        多段记录拼行及旧版嵌套记录；⑤「解决掉帧」与「显卡型号伪装」项名前加 ★。
  v0.19.3：①增加全局单实例锁，软件已经运行时再次启动只给出提示，不再打开第二个主窗口；
        ②显卡型号伪装区域改为默认展开；③随引擎 v0.16.4 将着色器缓存项改名为
        「解决掉帧：清理着色器缓存」，方便用户按问题找到对应功能。
  v0.19.2：①体检项不再因「上次已通过」而在套用方案时被跳过（VC++ 体检等于只检测一次）；
        ②随引擎 v0.16.3 加入实验项「清理着色器缓存」，界面按普通项呈现，项名与
        说明里写明不保证生效、不产生备份。
  v0.19.1：性能汇总增加粗粒度优化强度（未使用/轻量/均衡/深度），不发送具体勾选项、
        自存方案名称或方案内容，用于同一匿名设备的优化前后配对比较。
  v0.19.0：显卡型号改从驱动/NVML 读取真实硬件，不再让伪装值污染界面和统计；游戏启动后
        自动采样 120 秒，记录平均帧率、1% 低帧率、GPU 占用率、温度和功耗汇总；加入最低
        支持版本策略，低于门槛的客户端不可跳过更新。
  v0.18.4：显卡软件缺失时明确指引点击官方下载按钮；自动检测到新版本时直接弹出
        更新详情，不再只显示标题栏入口。
  v0.18.3：主推全套加入显卡型号伪装，仍保留独立二次确认和手动目标型号选择。
  v0.18.2：修复双显卡笔记本误把 AMD/Intel 核显用于显卡指引，改为稳定选择独显；
        NVIDIA 笔记本补充 Game Ready 驱动选择说明。
  v0.18.1：修复显卡型号伪装参数与 GUI 状态变量同名，导致程序启动时直接退出。
  v0.17：①「危险区域」改为中性的「显卡型号伪装」，RTX 30 系默认 750 Ti、40/50 系默认
        1050 Ti，并可在界面手动切换；②修复内置更新覆盖 app.ico 时可能被旧窗口占用。
  v0.16.2：打包修正版——v0.16.1 的安装包误将构建者本机的自存方案（profiles\）打了进去，
        装完会凭空多出别人的方案。界面与引擎均无改动，仅版本号跟随。
  v0.16.1：随引擎 v0.15.1 发版——修复「电源计划隐藏项」还原被误报失败（残留值留在还原后
        不生效的方案里时不再当成失败）。界面无改动，仅版本号跟随。
  v0.16：①主窗口 Closing 忙碌守卫（WM_CLOSE/Alt+F4 不再能中断执行中的优化/还原）；
        ②配合引擎的实时备份：备份写盘失败时日志+弹窗双通道警告并给出手动还原线索；
        ③危险区域勾选真正生效——此前勾了也不执行、不提示；现在有独立的高风险二次
        确认（逐项列名称与风险说明），确认后才带 AllowRisky 执行，自存方案里的
        risky 项也因此在 GUI 里走得通。
  v0.15：①首次启动的免责声明门控（滚到底才能同意，同意状态与声明版本号存 config\，
        版本号 +1 即可让所有人重新确认）；②「上传诊断报告」：报告本地组装 + 脱敏后
        经用户确认才上传，返回取件码；③更新一键完成——校验通过直接静默安装并自启新版，
        安装阶段转圈禁操作，失败给降级入口；④「检查更新」移到标题栏；⑤显卡指引改为
        驱动层内容 + 控制面板一键入口（装了才给按钮）。
  v0.14：VC++ 体检指引改用 aka.ms/vs/18；主推预设 Id 改为 main。
  v0.13：「游戏内设置参考」页按实机菜单重排；启动默认选中主推方案；全局深色 Chrome
        资源字典（对话框是独立 Window，不挂就是系统白滚动条）。
  早期版本的变更见 git 历史；关键结论都已就地写在对应代码处的注释里。

  双击根目录「启动优化工具.exe」（或后备的 .bat）运行；本文件点源加载
  scripts\delta-booster.ps1 作为引擎，scripts\updater.ps1 作为更新模块。
#>
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

# 这两个 Get-CimInstance 运行在引擎点源之前。UAC 过程会继承原用户环境，
# 所以必须在第一次模块自动加载之前去掉用户可写 PSModulePath，防止高权限加载同名模块。
$trustedBootstrapModuleRoots = @(
  (Join-Path $PSHOME 'Modules'),
  (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'WindowsPowerShell\Modules')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
$env:PSModulePath = ($trustedBootstrapModuleRoots -join [IO.Path]::PathSeparator)
$bootstrapWindows = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$bootstrapSystem = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
$env:PATH = @(
  $bootstrapSystem, $bootstrapWindows, (Join-Path $bootstrapSystem 'Wbem'),
  (Join-Path $bootstrapSystem 'WindowsPowerShell\v1.0')
) -join [IO.Path]::PathSeparator
$env:COMSPEC = Join-Path $bootstrapSystem 'cmd.exe'
$env:PATHEXT = '.COM;.EXE;.BAT;.CMD'

# 主界面只接受自有 EngineHost.exe 在一次 UAC 后启动。EngineHost 会从 asInvoker
# 启动器通过认证管道提供原交互用户 SID/LocalAppData；这里再校验父进程、
# 全生命周期启动器和会话标记，
# 所以直接运行 ps1、用普通 PowerShell 打开或伪造环境变量都会关闭失败。
function Test-BootstrapPathHasReparsePoint([string]$Path) {
  try {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [IO.Path]::GetPathRoot($full)
    $current = $root
    if (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
    foreach ($part in @($full.Substring($root.Length) -split '\\' | Where-Object { $_ })) {
      $current = Join-Path $current $part
      if (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
    }
    $false
  } catch { $true }
}

function Stop-UntrustedGuiStartup([string]$Reason) {
  Add-Type -AssemblyName PresentationFramework
  [Windows.MessageBox]::Show(
    "软件已停止启动：$Reason`n`n请只通过「启动优化工具.exe」打开。如果仍然出现，请从官网重新安装完整版本。",
    '三角洲行动 · 画面优化助手', [Windows.MessageBoxButton]::OK,
    [Windows.MessageBoxImage]::Error) | Out-Null
  exit 1
}

$script:EngineHostSessionValidated = $false
$bootstrapRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
try {
  $hostPidText = "$env:DFB_ENGINE_HOST_PID"
  $launcherPidText = "$env:DFB_LAUNCHER_PID"
  $sessionText = "$env:DFB_ENGINE_HOST_SESSION"
  $originalSidText = "$env:DFB_ORIGINAL_USER_SID"
  $originalLocalText = "$env:DFB_ORIGINAL_LOCALAPPDATA"
  $repairOnlyText = "$env:DFB_REPAIR_ONLY"
  $hostPid = 0
  $launcherPid = 0
  if (-not [int]::TryParse($hostPidText, [ref]$hostPid) -or $hostPid -le 0 -or
      $sessionText -notmatch '^[0-9a-fA-F]{32}$') { throw 'EngineHost 会话标记缺失或无效' }
  if (-not [int]::TryParse($launcherPidText, [ref]$launcherPid) -or $launcherPid -le 0) {
    throw '启动器会话标记缺失或无效'
  }
  if ($repairOnlyText -notin '0','1') { throw 'EngineHost 修复会话标记无效' }
  try { $originalSid = New-Object Security.Principal.SecurityIdentifier($originalSidText) }
  catch { throw '原交互用户 SID 无效' }
  if (-not $originalSid.IsAccountSid()) { throw '原交互用户 SID 不是账户 SID' }
  if (-not [IO.Path]::IsPathRooted($originalLocalText)) { throw '原交互用户 LocalAppData 不是绝对路径' }
  $originalLocal = [IO.Path]::GetFullPath($originalLocalText).TrimEnd('\')
  if (-not (Test-Path -LiteralPath $originalLocal -PathType Container) -or
      (Test-BootstrapPathHasReparsePoint $originalLocal) -or
      (New-Object IO.DriveInfo([IO.Path]::GetPathRoot($originalLocal))).DriveType -ne [IO.DriveType]::Fixed) {
    throw '原交互用户 LocalAppData 不在可验证的本地固定磁盘路径'
  }
  $expectedTemp = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)) `
    "DeltaForceBooster\session-temp\$sessionText"
  $actualTemp = [IO.Path]::GetFullPath("$env:TEMP").TrimEnd('\')
  if ($actualTemp -ine [IO.Path]::GetFullPath($expectedTemp).TrimEnd('\') -or
      "$env:TMP" -ine $actualTemp -or -not (Test-Path -LiteralPath $actualTemp -PathType Container) -or
      (Test-BootstrapPathHasReparsePoint $actualTemp)) {
    throw 'EngineHost 会话临时目录无效'
  }

  $self = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop
  if (-not $self -or [int]$self.ParentProcessId -ne $hostPid) { throw '主界面父进程不是当前 EngineHost 会话' }
  # $Host 是 PowerShell 内置只读变量（变量名大小写不敏感），不能拿来保存进程对象。
  $engineHostProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$hostPid" -ErrorAction Stop
  $expectedHost = [IO.Path]::GetFullPath((Join-Path $bootstrapRoot 'EngineHost.exe'))
  if (-not $engineHostProcess -or -not $engineHostProcess.ExecutablePath -or
      [IO.Path]::GetFullPath("$($engineHostProcess.ExecutablePath)") -ine $expectedHost -or
      (Test-BootstrapPathHasReparsePoint $expectedHost)) { throw 'EngineHost 进程路径不匹配' }
  $launcher = Get-CimInstance Win32_Process -Filter "ProcessId=$launcherPid" -ErrorAction Stop
  $expectedLauncher = [IO.Path]::GetFullPath((Join-Path $bootstrapRoot '启动优化工具.exe'))
  if (-not $launcher -or -not $launcher.ExecutablePath -or
      [IO.Path]::GetFullPath("$($launcher.ExecutablePath)") -ine $expectedLauncher -or
      (Test-BootstrapPathHasReparsePoint $expectedLauncher)) { throw '全生命周期启动器进程路径不匹配' }

  $bootstrapIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  if (-not ([Security.Principal.WindowsPrincipal]$bootstrapIdentity).IsInRole(
      [Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '主界面未继承管理员令牌' }
  $script:OriginalUserSid = $originalSid.Value
  $script:OriginalUserLocalAppData = $originalLocal
  $script:EngineHostPid = $hostPid
  $script:LauncherPid = $launcherPid
  $script:RepairOnlySession = ($repairOnlyText -eq '1')
  $script:EngineHostSessionValidated = $true
} catch {
  Stop-UntrustedGuiStartup $_.Exception.Message
}

function Invoke-EngineHostUserAction {
  param(
    [Parameter(Mandatory)][ValidateSet('MigrateLegacyData','ClearShaderCache','GetNvidiaPanelApps','GetAmdPanelApps','GetIntelPanelApps','GetNvAutoOptStatus','OpenUrl','OpenGpuPanel')][string]$Action,
    [string]$Payload = ''
  )
  if ($script:RepairOnlySession) { throw 'UAC 修复会话不提供普通用户动作' }
  if (-not $script:EngineHostSessionValidated -or
      "$env:DFB_ENGINE_CONTROL_PIPE" -notmatch '^DeltaForceBooster\.Engine\.[0-9a-fA-F]{32}$' -or
      "$env:DFB_ENGINE_HOST_SESSION" -notmatch '^[0-9a-fA-F]{32}$') {
    throw '原用户 broker 会话不可用'
  }
  $pipe = New-Object IO.Pipes.NamedPipeClientStream('.', "$env:DFB_ENGINE_CONTROL_PIPE",
    [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::None)
  try {
    $pipe.Connect(30000)
    $encoding = New-Object Text.UTF8Encoding($false)
    $writer = New-Object IO.BinaryWriter($pipe, $encoding, $true)
    $reader = New-Object IO.BinaryReader($pipe, $encoding, $true)
    if ($Payload.Length -gt 4096) { throw '原用户 broker 参数超过大小上限' }
    $writer.Write('DFB_GUI_BROKER/1'); $writer.Write("$env:DFB_ENGINE_HOST_SESSION")
    $writer.Write($Action); $writer.Write($Payload); $writer.Flush()
    if ($reader.ReadString() -ne 'DFB_ENGINE_REPLY/1') { throw '原用户 broker 回复协议无效' }
    $ok = $reader.ReadBoolean(); $payloadLength = $reader.ReadInt32()
    if ($payloadLength -lt 0 -or $payloadLength -gt 24MB) { throw '原用户 broker 回复大小无效' }
    $payloadBytes = $reader.ReadBytes($payloadLength)
    if ($payloadBytes.Length -ne $payloadLength) { throw '原用户 broker 回复被截断' }
    $payload = (New-Object Text.UTF8Encoding($false, $true)).GetString($payloadBytes)
    if (-not $ok) { throw $(if ($payload) { $payload } else { '原用户 worker 执行失败' }) }
    $payload
  } finally { $pipe.Dispose() }
}

# UAC 被关闭时，即使 asInvoker 启动器也会拿到完整管理员令牌；内置 Administrator 还需
# 管理员审批模式。这里只恢复这两个必要策略；当前进程仍退出，长期 GUI 不跨越权限边界。
function Get-UacEnableLuaValue {
  try {
    $policy = Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
      -Name 'EnableLUA' -ErrorAction Stop
    if ($null -eq $policy.EnableLUA) { return $null }
    return [int]$policy.EnableLUA
  } catch {
    return $null
  }
}

function Get-UacFilterAdministratorTokenValue {
  try {
    $policy = Get-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
      -Name 'FilterAdministratorToken' -ErrorAction Stop
    if ($null -eq $policy.FilterAdministratorToken) { return $null }
    return [int]$policy.FilterAdministratorToken
  } catch {
    return $null
  }
}

function Test-IsBuiltInAdministratorSid([string]$SidValue) {
  if ([string]::IsNullOrWhiteSpace($SidValue)) { return $false }
  return $SidValue.EndsWith('-500', [StringComparison]::Ordinal)
}

function Enable-UacForNextRestart([switch]$EnableBuiltInAdministratorApprovalMode) {
  if ($EnableBuiltInAdministratorApprovalMode) {
    $null = New-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
      -Name 'FilterAdministratorToken' -Value 1 -PropertyType DWord -Force -ErrorAction Stop
    if ((Get-UacFilterAdministratorTokenValue) -ne 1) {
      throw 'Windows 没有保存内置 Administrator 的管理员审批模式，请检查系统策略后重试。'
    }
  }
  $null = New-ItemProperty -LiteralPath 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -Name 'EnableLUA' -Value 1 -PropertyType DWord -Force -ErrorAction Stop
  if ((Get-UacEnableLuaValue) -ne 1) {
    throw 'Windows 没有保存 UAC 设置，请检查系统策略后重试。'
  }
}

# 主界面已由 EngineHost 长期持有管理员令牌。这里仅保留“UAC 整体被关闭”或
# “内置 Administrator 未开启审批模式”的修复门控；正常的提权 GUI 继续运行。
$currentWindowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
# UAC 审批账户可能与原登录用户不同；RID-500 修复策略必须只看经 launcher token
# 认证的原交互用户，不能把 OTS 输入的管理员凭据误判成待修复用户。
$isBuiltInAdministrator = Test-IsBuiltInAdministratorSid $script:OriginalUserSid
$isAdminGui = ([Security.Principal.WindowsPrincipal]$currentWindowsIdentity
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdminGui) { Stop-UntrustedGuiStartup '主界面没有管理员令牌' }
Add-Type -AssemblyName PresentationFramework
$enableLUA = Get-UacEnableLuaValue
$filterAdministratorToken = $(if ($isBuiltInAdministrator) { Get-UacFilterAdministratorTokenValue } else { $null })
$needsUacRepair = $(if ($isBuiltInAdministrator) {
  $enableLUA -ne 1 -or $filterAdministratorToken -ne 1
} else {
  $enableLUA -eq 0
})
if ($needsUacRepair -and -not $script:RepairOnlySession) {
  Stop-UntrustedGuiStartup '当前 UAC 策略需要受限兼容会话'
}
if ($script:RepairOnlySession -and -not $needsUacRepair) {
  # 用户右键“以管理员身份运行”时 medium 原用户令牌已经丢失。核心优化/还原仍由
  # EngineHost 安全执行；缓存清理、显卡软件探测和外链等用户态 broker 本次关闭。
  $script:NetCafeCompatibilityMode = $true
  [Windows.MessageBox]::Show(
    "检测到本次是以管理员身份直接打开。软件会继续进入兼容模式，核心优化与还原可正常使用；清理用户缓存、显卡软件检测和软件内外链入口本次暂时停用。`n`n下次普通双击「启动优化工具.exe」即可使用全部功能。",
    '管理员启动 · 兼容模式', [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information) | Out-Null
}
if ($needsUacRepair) {
    $repairPrompt = "请根据这台电脑的使用场景选择：`n`n【网吧 / 公共电脑】点击「是」`n无需重启，直接进入软件；优化与还原功能正常使用，少数辅助功能暂时关闭。`n`n【个人电脑】点击「否」`n软件会完成必要设置并退出；重启电脑后重新打开，即可使用全部功能。`n`n【暂不处理】点击「取消」`n不做任何更改，直接退出软件。"
    $choice = [Windows.MessageBox]::Show(
      $repairPrompt,
      '请选择使用场景', [Windows.MessageBoxButton]::YesNoCancel, [Windows.MessageBoxImage]::Warning)
    if ($choice -eq [Windows.MessageBoxResult]::Yes) {
      $script:NetCafeCompatibilityMode = $true
    } elseif ($choice -eq [Windows.MessageBoxResult]::No) {
      try {
        Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode:$isBuiltInAdministrator
        $repairResult = $(if ($isBuiltInAdministrator) {
          'UAC 与内置 Administrator 的管理员审批模式均已开启。'
        } else {
          'UAC 已恢复为开启状态。'
        })
        [Windows.MessageBox]::Show(
          "$repairResult`n`n请先保存正在进行的工作，再由您选择合适的时间重启电脑。软件不会自动重启；重启后直接双击「启动优化工具.exe」即可。",
          '修复完成 · 等待重启', [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information) | Out-Null
      } catch {
        $manualRecovery = $(if ($isBuiltInAdministrator) {
          '请在本地安全策略中开启「用户账户控制：用于内置管理员账户的管理员审批模式」，并确认 UAC 已开启，然后自行重启电脑。'
        } else {
          '请在 Windows 的「更改用户账户控制设置」中把滑块调回默认位置，然后自行重启电脑。'
        })
        [Windows.MessageBox]::Show(
          "UAC 自动恢复失败：$($_.Exception.Message)`n`n$manualRecovery",
          'UAC 修复失败', [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Error) | Out-Null
      }
      exit
    } else { exit }
}

# 当前 Windows 登录会话只保留一个主程序实例。Local 命名空间避免其他用户/远程会话
# 正在运行时把本会话第一次启动误报成重复；全电脑范围的系统写入仍由引擎 mutex 串行化。
$createdNew = $false
$script:InstanceMutex = [Threading.Mutex]::new($true, 'Local\DeltaForceBooster.GUI', [ref]$createdNew)
if (-not $createdNew) {
  Add-Type -AssemblyName PresentationFramework
  [Windows.MessageBox]::Show('当前 Windows 会话已有主窗口，请使用任务栏中的现有窗口。', '三角洲行动 · 画面优化助手', 'OK', 'Information') | Out-Null
  $script:InstanceMutex.Dispose()
  exit
}

$script:RootDir = Split-Path -Parent $PSScriptRoot
. (Join-Path $script:RootDir 'scripts\delta-booster.ps1')
try {
  # 二次根据 ProfileList/HKEY_USERS 复验受信 launcher 传入的用户与 LocalAppData，
  # 并让提权引擎的 HKCU 显式指向 HKEY_USERS\<原用户 SID>。
  Set-TargetUserContext $script:OriginalUserSid $script:OriginalUserLocalAppData
} catch {
  Stop-UntrustedGuiStartup "原交互用户上下文复验失败：$($_.Exception.Message)"
}
# 主界面会在整个会话保持 high token，所以绝不把日常状态写回原用户可控制的
# LocalAppData。每个原交互用户使用独立的 ProgramData 受保护区；SID 只作为经过
# SecurityIdentifier 规范化后的目录名，且每一层都由 engine 的严格 ACL/reparse
# 校验创建，预占了不安全目录时直接停止启动。
function Initialize-ProtectedUserStateStore {
  $sid = New-Object Security.Principal.SecurityIdentifier($script:OriginalUserSid)
  if (-not $sid.IsAccountSid() -or $sid.Value -notmatch '^S-1-[0-9-]{3,184}$') {
    throw '原交互用户 SID 不能用作受保护状态分区'
  }
  $usersRoot = Join-Path $script:ProgramDataRoot 'users'
  $userRoot = Join-Path $usersRoot $sid.Value
  $configRoot = Join-Path $userRoot 'config'
  $profileRoot = Join-Path $userRoot 'profiles'
  foreach ($dir in $script:ProgramDataRoot,$usersRoot,$userRoot,$configRoot,$profileRoot) {
    New-ProtectedDirectory $dir $false
  }
  $script:ProtectedUserStateRoot = $userRoot
  $script:UserDataRoot = $userRoot
  $script:ConfigDir = $configRoot
  $script:ProfileDir = $profileRoot
  $script:UserConfigDir = $configRoot
  # updater.ps1 点源时优先使用这个受保护位置；不要依赖 elevated 账户的
  # Environment.SpecialFolder.LocalApplicationData。
  $script:BoosterUserConfigDir = $configRoot
}

try { Initialize-ProtectedUserStateStore }
catch { Stop-UntrustedGuiStartup "受保护用户状态初始化失败：$($_.Exception.Message)" }

# NVIDIA App 的配置位于原交互用户可写的 LocalAppData。high GUI 不直接读取该树；
# 保留引擎原有检查接口，但把实际只读解析交给 lifetime launcher 的 medium worker。
function Get-NvAutoOptStatus {
  try { (Invoke-EngineHostUserAction -Action GetNvAutoOptStatus) | ConvertFrom-Json -ErrorAction Stop }
  catch { @{ Ok = $null; Text = "NVIDIA App 自动优化检测失败：$($_.Exception.Message)" } }
}
$script:TelemetryClientPath = Join-Path $script:RootDir 'scripts\telemetry-client.ps1'
if (Test-Path -LiteralPath $script:TelemetryClientPath) { . $script:TelemetryClientPath }

# 旧状态只由原交互用户的 medium broker 读取。broker 返回严格白名单、定长、带
# SHA256 的 JSON 包；high GUI 复验后仅向上面的受保护区 CreateNew，绝不覆盖新版状态。
function Import-ProtectedLegacyState([string]$PackageJson) {
  if ([Text.Encoding]::UTF8.GetByteCount("$PackageJson") -gt 24MB) { throw '旧状态迁移包超过大小上限' }
  $package = "$PackageJson" | ConvertFrom-Json -ErrorAction Stop
  Assert-ExactProperties $package @('SchemaVersion','Files','Skipped') @() '旧状态迁移包'
  if ([int]$package.SchemaVersion -ne 1) { throw '不支持的旧状态迁移包版本' }
  $files = @($package.Files)
  if ($files.Count -gt 140) { throw '旧状态迁移包文件数超过上限' }
  $total = 0L; $imported = 0
  foreach ($entry in $files) {
    Assert-ExactProperties $entry @('RelativePath','Length','Sha256','ContentBase64') @() '旧状态迁移项'
    $relative = "$($entry.RelativePath)".Replace('/','\')
    $allowed = $relative -in @(
      'config\telemetry.json','config\disclaimer.json','config\updater.json',
      'config\performance-sessions.json','config\power-scheme.json',
      'config\tuning-telemetry-outbox.json'
    ) -or $relative -match '^config\\experiments\\(?:active-experiment|exp_[0-9a-f]{32})\.json$' -or
      $relative -match '^profiles\\[^\\/:*?"<>|]{1,80}\.json$'
    if (-not $allowed -or "$($entry.Sha256)" -notmatch '^[0-9a-fA-F]{64}$') {
      throw "旧状态迁移项路径或哈希无效：$relative"
    }
    $length = [long]$entry.Length
    if ($length -lt 2 -or $length -gt 4MB) { throw "旧状态迁移项大小无效：$relative" }
    try { $bytes = [Convert]::FromBase64String("$($entry.ContentBase64)") }
    catch { throw "旧状态迁移项 Base64 无效：$relative" }
    if ($bytes.Length -ne $length) { throw "旧状态迁移项长度不匹配：$relative" }
    $total += $bytes.Length
    if ($total -gt 12MB) { throw '旧状态迁移包解码后超过总大小上限' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actualHash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') }
    finally { $sha.Dispose() }
    if ($actualHash -ine "$($entry.Sha256)") { throw "旧状态迁移项哈希不匹配：$relative" }
    try {
      $strictUtf8 = New-Object Text.UTF8Encoding($false, $true)
      $offset = $(if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 3 } else { 0 })
      $jsonText = $strictUtf8.GetString($bytes, $offset, $bytes.Length - $offset)
      $null = $jsonText | ConvertFrom-Json -ErrorAction Stop
    } catch { throw "旧状态迁移项不是有效 UTF-8 JSON：$relative" }

    $destination = [IO.Path]::GetFullPath((Join-Path $script:ProtectedUserStateRoot $relative))
    $prefix = [IO.Path]::GetFullPath($script:ProtectedUserStateRoot).TrimEnd('\') + '\'
    if (-not $destination.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
      throw "旧状态迁移项目标越界：$relative"
    }
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-ProtectedDirectory $parent $false }
    if (-not (Test-ProtectedDirectoryAclExact $parent $false) -or (Test-PathHasReparsePoint $parent)) {
      throw "旧状态迁移项目标目录不安全：$relative"
    }
    if (Test-Path -LiteralPath $destination) { continue }
    $stream = $null
    try {
      $stream = New-Object IO.FileStream($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
        [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
      $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true)
      $stream.Dispose(); $stream = $null
      Set-ProtectedFileAcl $destination
      if (-not (Test-ProtectedFileAcl $destination)) { throw "旧状态迁移项 ACL 校验失败：$relative" }
      $imported++
    } finally { if ($stream) { $stream.Dispose() } }
  }
  [pscustomobject]@{ Imported = $imported; Skipped = @($package.Skipped).Count }
}

$script:LegacyMigrationNotice = $(if ($script:NetCafeCompatibilityMode) {
  '当前为网吧兼容模式：未修改 UAC，也无需重启；用户缓存清理、显卡软件检测和外链入口已停用。'
} else { '' })
try { $script:LegacyMigrationResult = Import-ProtectedLegacyState (Invoke-EngineHostUserAction MigrateLegacyData) }
catch {
  if (-not $script:NetCafeCompatibilityMode) {
    $script:LegacyMigrationNotice = "旧版用户数据迁移未完成：$($_.Exception.Message)"
  }
}

# 内置更新、安装身份、程序集元数据和界面统一使用同一个四段版本号。
$script:GuiVersion = '0.23.0.13'
$script:DisplayVersion = '0.23.0.13'
# 浅色主题实现保留给下个版本；当前版本隐藏入口并强制使用深色，避免半成品提前发布。
$script:LightThemeEnabled = $false
$script:UpdaterPath = Join-Path $script:RootDir 'scripts\updater.ps1'
# 更新模块独立可缺失：老用户手动拷贝升级时可能没有该文件，缺了也不能影响主功能
if (Test-Path -LiteralPath $script:UpdaterPath) { try { . $script:UpdaterPath } catch {} }
$script:TuningModulePath = Join-Path $script:RootDir 'scripts\tuning-experiment.ps1'
# 自动调优是可选 Beta：主功能在模块丢失时仍可启动，但 Beta 页会明确停用而不猜候选规则。
$script:TuningModuleLoaded = $false
if (Test-Path -LiteralPath $script:TuningModulePath -PathType Leaf) {
  try { . $script:TuningModulePath; $script:TuningModuleLoaded = $true } catch {}
}

Add-Type -AssemblyName PresentationFramework

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="三角洲行动 · 画面优化助手" Width="780" Height="1200" MinHeight="640"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="CanResize"
        BorderBrush="{DynamicResource Line}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <!-- 官网页面底色不是纯黑：带青绿调的细微垂直渐变 -->
  <Window.Background>
    <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#FF0A1512" Offset="0"/>
      <GradientStop Color="#FF10201C" Offset="1"/>
    </LinearGradientBrush>
  </Window.Background>
  <Window.Resources>
    <SolidColorBrush x:Key="TopBar"    Color="#FF0D1417"/>
    <SolidColorBrush x:Key="Panel"     Color="#FF0E1B17"/>
    <SolidColorBrush x:Key="PanelDeep" Color="#FF0B1713"/>
    <SolidColorBrush x:Key="LogBg"     Color="#FF081310"/>
    <SolidColorBrush x:Key="Line"      Color="#FF1B2E28"/>
    <SolidColorBrush x:Key="LineSoft"  Color="#FF16241F"/>
    <SolidColorBrush x:Key="LineHi"    Color="#FF2C443B"/>
    <SolidColorBrush x:Key="TextPri"   Color="#FFFFFFFF"/>
    <SolidColorBrush x:Key="TextSec"   Color="#FF9AA5A0"/>
    <SolidColorBrush x:Key="TextMut"   Color="#FF7A8580"/>
    <SolidColorBrush x:Key="Green"     Color="#FF00E884"/>
    <SolidColorBrush x:Key="GreenDark" Color="#FF04241B"/>
    <SolidColorBrush x:Key="GreenLine" Color="#FF00E884"/>
    <SolidColorBrush x:Key="Gold"      Color="#FFE5C46A"/>
    <SolidColorBrush x:Key="GoldDark"  Color="#FF3A2C0C"/>
    <SolidColorBrush x:Key="Danger"    Color="#FFE5484D"/>
    <SolidColorBrush x:Key="AccentPanel"   Color="#FF0E2A21"/>
    <SolidColorBrush x:Key="TableHeader"   Color="#FF0C1915"/>
    <SolidColorBrush x:Key="ComboSurface"  Color="#FF0B1712"/>
    <SolidColorBrush x:Key="HoverPanel"    Color="#FF12291F"/>
    <SolidColorBrush x:Key="SelectedPanel" Color="#FF0F2118"/>
    <SolidColorBrush x:Key="WindowHover"   Color="#FF14241F"/>
    <SolidColorBrush x:Key="DisabledText"  Color="#FF56615C"/>
    <SolidColorBrush x:Key="WarningPanel"  Color="#FF2A2008"/>
    <SolidColorBrush x:Key="DangerPanel"   Color="#FF1A0E10"/>
    <SolidColorBrush x:Key="InputSurface"  Color="#FF0C1814"/>

    <Style x:Key="TacCheck" TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border Background="Transparent" Padding="0,3">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="Box" Width="13" Height="13" BorderBrush="{DynamicResource LineHi}"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Center">
                  <Grid>
                    <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="{DynamicResource GreenDark}"
                          StrokeThickness="2" Visibility="Collapsed"/>
                    <!-- 第三态（部分选中）：绿色小方块。只有全选框会进入此态，
                         普通项复选框永远只在勾/不勾之间切换 -->
                    <Border x:Name="PartMark" Width="7" Height="7" Background="{DynamicResource Green}"
                            HorizontalAlignment="Center" VerticalAlignment="Center"
                            Visibility="Collapsed"/>
                  </Grid>
                </Border>
                <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="{DynamicResource Green}"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="{x:Null}">
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="PartMark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Green}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网次级动作样式：绿色细描边 + 绿色文字 + 内容居中 -->
    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource Green}"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网主 CTA：斜切角 + 纯绿色实底 + 深色字；hover 用白色薄罩提亮而不换色。 -->
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource GreenDark}"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Height" Value="38"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <!-- 几何用 0–1 归一化坐标：Path 的期望尺寸即为 1x1，不会把按钮撑大，Stretch 再拉满 -->
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.05,0 L 1,0 L 1,0.8 L 0.95,1 L 0,1 L 0,0.2 Z"/>
              <Path x:Name="Hover" Stretch="Fill" Fill="#FFFFFFFF" Opacity="0"
                    Data="M 0.05,0 L 1,0 L 1,0.8 L 0.95,1 L 0,1 L 0,0.2 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Hover" Property="Opacity" Value="0.16"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextSec}"/>
      <Setter Property="Width" Value="34"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="{DynamicResource WindowHover}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 行首分类标签：深色主题用亮黄，浅色主题用冷蓝，与绿色主操作形成清晰层级。 -->
    <Style x:Key="Chip" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource Gold}"/>
      <Setter Property="Padding" Value="7,1"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="ChipText" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource GoldDark}"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>

    <!-- 中英上下叠排分区标题：中文白粗体在上、小号大写英文在下、绿色短下划线
         （官网标签页选中态：绿色文字 + 底部绿色下划线，这里移植为分区标识） -->
    <Style x:Key="HeadCn" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{DynamicResource TextPri}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style x:Key="HeadEn" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="8"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMut}"/>
      <Setter Property="Margin" Value="1,1,0,0"/>
    </Style>
    <Style x:Key="HeadBar" TargetType="Border">
      <Setter Property="Height" Value="2"/>
      <Setter Property="Width" Value="28"/>
      <Setter Property="Background" Value="{DynamicResource Green}"/>
      <Setter Property="HorizontalAlignment" Value="Left"/>
      <Setter Property="Margin" Value="0,4,0,0"/>
    </Style>

    <Style x:Key="Mono" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMut}"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <!-- 标签页按钮：官网标签页手法——选中项绿色文字 + 底部绿色下划线，未选中灰色。
         不用 WPF TabControl：其默认模板白底黑字，整套重模板不如自绘两个按钮可控 -->
    <Style x:Key="TabBtn" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextSec}"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="16,9,16,11"/>
              <Border x:Name="UL" Height="2" Background="{DynamicResource Green}" VerticalAlignment="Bottom"
                      Margin="12,0" Visibility="Collapsed"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Tag" Value="on">
                <Setter TargetName="UL" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="{DynamicResource Green}"/>
                <Setter Property="FontWeight" Value="Bold"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="{DynamicResource Green}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="{DynamicResource DisabledText}"/>
                <Setter Property="Opacity" Value="0.62"/>
                <Setter Property="FontWeight" Value="Normal"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 侧边刻度尺装饰：官网页面两侧贯穿整屏的细刻度 + 等宽小数字 -->
    <Style x:Key="RulerNum" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="8"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMut}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="TickMajor" TargetType="Border">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{DynamicResource LineHi}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,5"/>
    </Style>
    <Style x:Key="TickMinor" TargetType="Border">
      <Setter Property="Width" Value="4"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{DynamicResource LineSoft}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,5"/>
    </Style>
    <!-- 装饰分隔线的短横段：「— — — 中 文 — — —」 -->
    <Style x:Key="Dash" TargetType="Border">
      <Setter Property="Width" Value="14"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{DynamicResource LineHi}"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="4,0"/>
    </Style>

    <!-- 深色滚动条样式已移入 $script:ThemeResXaml 共享资源字典（v0.13）：
         对话框是独立 Window 不继承这里的资源，样式只放主窗口时对话框滚动条仍是
         系统白色（实机反馈）。主窗口在 Parse 后 MergedDictionaries 引同一份实例 -->

    <!-- 深色主题 ComboBox：默认白底模板在本主题下刺眼，整体重做。
         选中项文字用品牌绿——官网列表强调项就是整行绿色 -->
    <Style x:Key="TacComboItem" TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="{DynamicResource TextSec}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="BD" Background="Transparent" Padding="10,5">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="BD" Property="Background" Value="{DynamicResource HoverPanel}"/>
                <Setter Property="Foreground" Value="{DynamicResource Green}"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="BD" Property="Background" Value="{DynamicResource SelectedPanel}"/>
                <Setter Property="Foreground" Value="{DynamicResource Green}"/>
                <Setter Property="FontWeight" Value="Bold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="TacCombo" TargetType="ComboBox">
      <Setter Property="Foreground" Value="{DynamicResource Green}"/>
      <Setter Property="Height" Value="26"/>
      <Setter Property="ItemContainerStyle" Value="{StaticResource TacComboItem}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                            Focusable="False" ClickMode="Press">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="BD" Background="{DynamicResource ComboSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1">
                      <Path Data="M 0,0 L 8,0 L 4,5 Z" Fill="{DynamicResource Green}"
                            HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,9,0"/>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="BD" Property="BorderBrush" Value="{DynamicResource Green}"/>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                Margin="10,0,26,0" VerticalAlignment="Center" IsHitTestVisible="False"
                                TextBlock.Foreground="{TemplateBinding Foreground}"/>
              <Popup IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom"
                     AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="220">
                  <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <ItemsPresenter/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- 顶栏：官网近黑微青 #0D1417 -->
    <Border x:Name="TitleBar" Grid.Row="0" Background="{DynamicResource TopBar}"
            BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1">
      <Grid>
        <StackPanel Orientation="Horizontal" Margin="14,10">
          <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="{DynamicResource Green}" VerticalAlignment="Center"/>
          <TextBlock Text="DELTA FORCE" Foreground="{DynamicResource TextPri}" FontSize="13"
                     FontWeight="Bold" Margin="10,0,0,0" VerticalAlignment="Center">
            <TextBlock.LayoutTransform><ScaleTransform ScaleX="1.05"/></TextBlock.LayoutTransform>
          </TextBlock>
          <Border Width="1" Height="13" Background="{DynamicResource LineHi}" Margin="11,0"/>
          <TextBlock Text="画面优化助手" Foreground="{DynamicResource TextSec}" FontSize="12" VerticalAlignment="Center"/>
          <TextBlock Text="[ v0.23.0.13 ]" Style="{StaticResource Mono}" Foreground="{DynamicResource Green}" Margin="9,0,0,0"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="NoticeBtn" Style="{StaticResource Ghost}"
                  Height="24" FontSize="11" VerticalAlignment="Center" Margin="0,0,8,0"
                  ToolTip="查看通知与历史消息">
            <StackPanel Orientation="Horizontal">
              <TextBlock x:Name="NoticeText" Text="通知" VerticalAlignment="Center"/>
              <Border x:Name="NoticeBadge" Visibility="Collapsed" Background="{DynamicResource Green}"
                      CornerRadius="7" MinWidth="15" Height="15" Margin="6,0,0,0" VerticalAlignment="Center">
                <TextBlock x:Name="NoticeBadgeTxt" Text="" Foreground="#FFFFFFFF" FontSize="9" FontWeight="Bold"
                           Margin="5,0,5,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
            </StackPanel>
          </Button>
          <Button x:Name="ThemeBtn" Content="☀ 浅色" Style="{StaticResource Ghost}" Visibility="Collapsed"
                  Height="24" MinWidth="66" FontSize="11" VerticalAlignment="Center" Margin="0,0,8,0"
                  ToolTip="切换浅色模式"/>
          <!-- 手动检查更新：用户要求放在最上方。与右侧「有新版本」胶囊分工不同——
               胶囊只在已发现新版时出现，这个按钮任何时候都能主动查一次 -->
          <Button x:Name="CheckUpdBtn" Content="检查更新" Style="{StaticResource Ghost}"
                  Height="24" FontSize="11" VerticalAlignment="Center" Margin="0,0,10,0"/>
          <!-- Discord 式更新入口：检测到新版本才出现的小绿胶囊，点击弹更新详情。
               图标用固定坐标小 Path（不加 Stretch）：归一化坐标 + Stretch 会被撑大（教训 #3） -->
          <Button x:Name="UpdateBtn" Visibility="Collapsed" VerticalAlignment="Center" Margin="0,0,10,0"
                  Foreground="{DynamicResource GreenDark}" Cursor="Hand">
            <Button.Template>
              <ControlTemplate TargetType="Button">
                <Border x:Name="B" Background="{DynamicResource Green}" CornerRadius="10" Padding="9,3">
                  <StackPanel Orientation="Horizontal">
                    <Path Data="M 3,0 L 6,0 L 6,4 L 9,4 L 4.5,9 L 0,4 L 3,4 Z M 0,11 L 9,11 L 9,12.5 L 0,12.5 Z"
                          Fill="{DynamicResource GreenDark}" Width="9" Height="13" VerticalAlignment="Center"/>
                    <TextBlock Text="有新版本" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource GreenDark}"
                               VerticalAlignment="Center" Margin="6,0,0,0"/>
                  </StackPanel>
                </Border>
                <ControlTemplate.Triggers>
                  <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="B" Property="Background" Value="#FF33F09E"/>
                  </Trigger>
                </ControlTemplate.Triggers>
              </ControlTemplate>
            </Button.Template>
          </Button>
          <Button x:Name="MinBtn" Content="—" Style="{StaticResource WinBtn}"/>
          <Button x:Name="CloseBtn" Content="✕" Style="{StaticResource WinBtn}"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- 标签页导航：优化 / 自动调优 / 掉帧修复 / 游戏内设置参考 / 运行日志 -->
    <Border Grid.Row="1" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}"
            BorderThickness="0,0,0,1">
      <StackPanel Orientation="Horizontal" Margin="15,0,0,0">
        <Button x:Name="TabOptBtn" Content="优化" Style="{StaticResource TabBtn}" Tag="on"/>
        <Button x:Name="TabTuneBtn" Style="{StaticResource TabBtn}" Tag="" IsEnabled="False" Opacity="1">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="AI定制优化" VerticalAlignment="Center"/>
            <TextBlock Text="（敬请期待）" Foreground="{DynamicResource Gold}" FontWeight="Bold" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
        <Button x:Name="TabFrameFixBtn" Content="掉帧修复" Style="{StaticResource TabBtn}" Tag=""/>
        <Button x:Name="TabRefBtn" Content="游戏内设置参考" Style="{StaticResource TabBtn}" Tag=""/>
        <Button x:Name="TabLogBtn" Style="{StaticResource TabBtn}" Tag="">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="运行日志" VerticalAlignment="Center"/>
            <!-- 角标：日志挪到独立页后，出了失败/体检问题得有个「这里有东西该看」的信号。
                 前景色写死，免得被标签页选中态的 Foreground 触发器染成绿色 -->
            <Border x:Name="LogBadge" Visibility="Collapsed" Background="{DynamicResource Danger}"
                    CornerRadius="7" MinWidth="15" Height="15" Margin="7,0,0,0" VerticalAlignment="Center">
              <TextBlock x:Name="LogBadgeTxt" Text="" Foreground="#FFFFFFFF" FontSize="9" FontWeight="Bold"
                         Margin="5,0,5,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </StackPanel>
        </Button>
      </StackPanel>
    </Border>

    <Grid Grid.Row="2" x:Name="OptPage">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <!-- 大号淡化 Logo 水印：官网 hero 区同手法 -->
      <Path Grid.Column="1" Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="{DynamicResource Green}" Opacity="0.03"
            Stretch="Uniform" Width="420" Height="350" HorizontalAlignment="Right"
            VerticalAlignment="Top" Margin="0,-60,-80,0"/>

      <!-- 左侧刻度尺 -->
      <Grid Grid.Column="0" Width="16" Margin="5,12,0,12">
        <StackPanel VerticalAlignment="Top">
          <TextBlock Text="82" Style="{StaticResource RulerNum}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Bottom">
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <TextBlock Text="42" Style="{StaticResource RulerNum}"/>
        </StackPanel>
      </Grid>

      <!-- 右侧刻度尺 -->
      <Grid Grid.Column="2" Width="16" Margin="0,12,5,12">
        <StackPanel VerticalAlignment="Top">
          <TextBlock Text="72" Style="{StaticResource RulerNum}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Bottom">
          <Border Style="{StaticResource TickMajor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMinor}"/>
          <Border Style="{StaticResource TickMajor}"/>
          <TextBlock Text="60" Style="{StaticResource RulerNum}"/>
        </StackPanel>
      </Grid>

      <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" Padding="8,6">
        <StackPanel>

          <!-- 分区标题：中英上下叠排 + 绿色短下划线 -->
          <Grid Margin="0,2,0,8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="系统信息" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="SYSTEM INFO" Style="{StaticResource HeadEn}"/>
              <Border Style="{StaticResource HeadBar}"/>
            </StackPanel>
            <Border Grid.Column="1" Height="1" Background="{DynamicResource LineSoft}"
                    VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <TextBlock Grid.Column="2" x:Name="ScanState" Text="检测中…" Style="{StaticResource Mono}"
                       Foreground="{DynamicResource Green}" VerticalAlignment="Bottom" Margin="0,0,0,2"/>
          </Grid>

          <!-- CPU/GPU 等硬件信息与温度先展示；FPS 和占用指标紧随其后。 -->
          <UniformGrid x:Name="HwGrid" Columns="4" Margin="0,0,0,8"/>

          <Grid x:Name="MetricsGrid" Margin="0,0,0,7"/>

          <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}"
                  BorderThickness="1" Padding="8,4" Margin="0,0,0,11">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Style="{StaticResource Chip}">
                <TextBlock Text="目标程序" Style="{StaticResource ChipText}"/>
              </Border>
              <TextBlock x:Name="GameText" Grid.Column="1" Text="定位中…" Style="{StaticResource Mono}"
                         Foreground="{DynamicResource TextPri}" Margin="10,0,12,0"
                         TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
              <Button x:Name="BrowseBtn" Grid.Column="2" Content="重新定位" Style="{StaticResource Ghost}"
                      FontSize="11" Height="24"/>
            </Grid>
          </Border>

          <Grid Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="优化项" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="OPTIMIZATION ITEMS" Style="{StaticResource HeadEn}"/>
              <Border Style="{StaticResource HeadBar}"/>
            </StackPanel>
            <Border Grid.Column="1" Height="1" Background="{DynamicResource LineSoft}"
                    VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <TextBlock Grid.Column="2" x:Name="CountText" Text="" Style="{StaticResource Mono}"
                       Foreground="{DynamicResource TextSec}" VerticalAlignment="Bottom" Margin="0,0,0,2"/>
          </Grid>

          <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}"
                  BorderThickness="1" Padding="8,4" Margin="0,0,0,4">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Style="{StaticResource Chip}">
                <TextBlock Text="预设方案" Style="{StaticResource ChipText}"/>
              </Border>
              <ComboBox x:Name="PresetBox" Grid.Column="1" Margin="10,0,10,0" Style="{StaticResource TacCombo}"/>
              <Button x:Name="SavePresetBtn" Grid.Column="2" Content="存为方案"
                      Style="{StaticResource Ghost}" FontSize="11" Height="24"/>
              <Button x:Name="DelPresetBtn" Grid.Column="3" Content="删除"
                      Style="{StaticResource Ghost}" FontSize="11" Height="24" Margin="7,0,0,0"/>
            </Grid>
          </Border>

          <TextBlock x:Name="PresetNote" Text="" Style="{StaticResource Mono}"
                     TextTrimming="CharacterEllipsis" Margin="2,0,0,4"/>

          <Border BorderBrush="{DynamicResource Line}" BorderThickness="1" Background="{DynamicResource PanelDeep}">
            <StackPanel>
              <!-- 全选行（实机诉求）：三态仅作展示——部分选中显示第三态，点击只在
                   全选/全不选之间切换；包含单独分组的显卡型号伪装，执行前仍保留二次确认 -->
              <Border Background="{DynamicResource TableHeader}" BorderBrush="{DynamicResource LineSoft}"
                      BorderThickness="0,0,0,1" Padding="10,3">
                <Grid>
                  <CheckBox x:Name="SelAllChk" Style="{StaticResource TacCheck}" VerticalAlignment="Center">
                    <TextBlock Text="全选" Foreground="{DynamicResource TextPri}" FontSize="12" FontWeight="Bold"/>
                  </CheckBox>
                  <TextBlock Text="包含 ★ 显卡型号伪装 · 执行前二次确认" FontFamily="Consolas" FontSize="10"
                             Foreground="{DynamicResource TextMut}" HorizontalAlignment="Right"
                             VerticalAlignment="Center"/>
                </Grid>
              </Border>
              <!-- 列含义表头：第一列与第二列之间可拖动调整列宽（数据行列0 固定宽度与之对齐，
                   拖动结果由 Sync-OptHeaderColumnWidth 同步到所有数据行） -->
              <Border Background="{DynamicResource TableHeader}" BorderBrush="{DynamicResource LineSoft}"
                      BorderThickness="0,0,0,1" Padding="10,3">
                <Grid x:Name="OptHeaderGrid">
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="220" MinWidth="80"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                  </Grid.ColumnDefinitions>
                  <TextBlock Grid.Column="0" Text="优化项" FontFamily="Consolas" FontSize="10"
                             Foreground="{DynamicResource TextMut}" VerticalAlignment="Center"/>
                  <GridSplitter x:Name="OptHeaderSplitter" Grid.Column="1" Width="6"
                                HorizontalAlignment="Stretch" VerticalAlignment="Stretch"
                                Background="{DynamicResource LineSoft}"/>
                  <TextBlock Grid.Column="2" Text="当前状态" FontFamily="Consolas" FontSize="10"
                             Foreground="{DynamicResource TextMut}" VerticalAlignment="Center"/>
                  <TextBlock Grid.Column="3" Text="优化状态/检测状态" FontFamily="Consolas" FontSize="10"
                             Foreground="{DynamicResource TextMut}" VerticalAlignment="Center"/>
                </Grid>
              </Border>
              <StackPanel x:Name="ItemPanel"/>
            </StackPanel>
          </Border>

          <Expander x:Name="RiskyGroup" Margin="0,10,0,0" Visibility="Collapsed" IsExpanded="True" Foreground="{DynamicResource TextPri}">
            <Expander.Header>
              <StackPanel Orientation="Horizontal">
                  <TextBlock Text="★ 显卡型号伪装" Foreground="{DynamicResource TextPri}" FontSize="12"/>
                <TextBlock Text="按显卡代际推荐 · 可手动选择目标型号" Style="{StaticResource Mono}" Margin="10,0,0,0"/>
              </StackPanel>
            </Expander.Header>
            <Border BorderBrush="{DynamicResource Line}" BorderThickness="1" Background="{DynamicResource PanelDeep}" Margin="0,6,0,0">
              <StackPanel x:Name="RiskyPanel"/>
            </Border>
          </Expander>

          <!-- 复原直接留在优化页内完成，不再打开第二层窗口。优化勾选与复原勾选分开，
               避免内置方案默认勾选的优化项被误当成要复原的项目。 -->
          <Border x:Name="InlineRestorePanel" Visibility="Collapsed" Margin="0,10,0,0"
                  Background="{DynamicResource Panel}" BorderBrush="{DynamicResource GreenLine}"
                  BorderThickness="1" Padding="12,10">
            <StackPanel>
              <Grid Margin="0,0,0,7">
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal">
                  <TextBlock Text="按项目复原" Foreground="{DynamicResource Green}" FontSize="15" FontWeight="Bold"/>
                  <TextBlock Text="RESTORE MANAGER" Style="{StaticResource Mono}" Margin="10,0,0,0" VerticalAlignment="Center"/>
                </StackPanel>
                <Button x:Name="InlineRestoreCloseBtn" Grid.Column="1" Content="收起" Style="{StaticResource Ghost}"
                        Width="70" Height="24" FontSize="10"/>
              </Grid>
              <TextBlock Text="直接勾选要复原的项目，可单选、多选或全选；其他项目保持不变。"
                         Foreground="{DynamicResource TextSec}" TextWrapping="Wrap" Margin="0,0,0,8"/>
              <Border x:Name="InlineRestoreLegacyNotice" Visibility="Collapsed" Background="{DynamicResource GoldDark}"
                      BorderBrush="{DynamicResource Gold}" BorderThickness="1" Padding="9,6" Margin="0,0,0,8">
                <TextBlock x:Name="InlineRestoreLegacyText" Foreground="{DynamicResource Gold}" TextWrapping="Wrap"/>
              </Border>
              <Border Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource Line}" BorderThickness="1">
                <StackPanel>
                  <DockPanel Margin="9,7">
                    <TextBlock x:Name="InlineRestoreSelectedText" DockPanel.Dock="Right" Text="已选择 0 项"
                               Foreground="{DynamicResource Gold}" VerticalAlignment="Center"/>
                    <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
                      <Button x:Name="InlineRestoreSelectAllBtn" Content="全选可复原项目" Style="{StaticResource Ghost}"
                              Height="25" FontSize="10"/>
                      <Button x:Name="InlineRestoreClearBtn" Content="清空" Style="{StaticResource Ghost}"
                              Width="64" Height="25" FontSize="10" Margin="7,0,0,0"/>
                    </StackPanel>
                  </DockPanel>
                  <Border BorderBrush="{DynamicResource LineSoft}" BorderThickness="0,1,0,0"/>
                  <ScrollViewer MaxHeight="230" VerticalScrollBarVisibility="Auto">
                    <StackPanel x:Name="InlineRestoreItemsPanel" Margin="9,3,9,7"/>
                  </ScrollViewer>
                  <TextBlock x:Name="InlineRestoreEmptyText" Visibility="Collapsed"
                             Text="当前没有支持按项目精确复原的记录。" Foreground="{DynamicResource TextMut}" Margin="11,9"/>
                </StackPanel>
              </Border>
              <Button x:Name="InlineRestoreSelectedBtn" Content="复原所选项目" Style="{StaticResource Primary}"
                      IsEnabled="False" Height="34" Margin="0,9,0,0"/>
              <Border BorderBrush="{DynamicResource Line}" BorderThickness="0,1,0,0" Margin="0,13,0,10"/>
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Margin="0,0,12,0">
                  <TextBlock Text="全部复原" Foreground="{DynamicResource Gold}" FontSize="13" FontWeight="Bold"/>
                  <TextBlock x:Name="InlineRestoreAllSummary" Foreground="{DynamicResource TextSec}"
                             TextWrapping="Wrap" Margin="0,3,0,0"/>
                </StackPanel>
                <Button x:Name="InlineRestoreAllBtn" Grid.Column="1" Content="确认全部复原"
                        Style="{StaticResource Ghost}" Width="138" VerticalAlignment="Center"/>
              </Grid>
              <TextBlock Text="检测到后续修改的项目不会被选择性覆盖。" Style="{StaticResource Mono}"
                         Margin="0,9,0,0" TextWrapping="Wrap"/>
            </StackPanel>
          </Border>

          <!-- 官网招牌装饰分隔线：两侧短横段 + 中间拉开字距的中文 -->
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,14,0,4">
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <TextBlock Text="系 统 优 化 · 改 前 备 份 · 一 键 还 原" Foreground="{DynamicResource TextMut}"
                       FontSize="10" Margin="10,0" VerticalAlignment="Center"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
          </StackPanel>

        </StackPanel>
      </ScrollViewer>
    </Grid>

    <!-- 规则版个体内自动调优：不从网络/AI 接受优化项，只运行本地签名发布的三组低风险规则。 -->
    <Grid Grid.Row="2" x:Name="TunePage" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="21,10">
        <StackPanel>
          <Grid Margin="0,0,0,9">
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="自动寻找最佳配置" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="DETERMINISTIC TUNING BETA" Style="{StaticResource HeadEn}"/>
              <Border Style="{StaticResource HeadBar}"/>
            </StackPanel>
            <Border Grid.Column="1" Height="1" Background="{DynamicResource LineSoft}" VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <Border Grid.Column="2" Background="{DynamicResource GoldDark}" BorderBrush="{DynamicResource Gold}" BorderThickness="1" Padding="7,2" VerticalAlignment="Bottom">
              <TextBlock Text="RULES / BETA" Foreground="{DynamicResource Gold}" FontFamily="Consolas" FontSize="9" FontWeight="Bold"/>
            </Border>
          </Grid>

          <Border Background="{DynamicResource AccentPanel}" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Padding="11,8" Margin="0,0,0,9">
            <StackPanel>
              <TextBlock Text="固定目标：提高 1% 低帧率和流畅度" Foreground="{DynamicResource Green}" FontSize="13" FontWeight="Bold"/>
              <TextBlock Text="这是确定性规则实验，不是 AI。候选仅来自内置低风险库，显卡型号伪装等 risky 项永不会自动加入。" Foreground="{DynamicResource TextSec}" TextWrapping="Wrap" Margin="0,4,0,0"/>
              <TextBlock Text="个体内规则实验，不代表全局最优。" Foreground="{DynamicResource Gold}" FontWeight="Bold" Margin="0,3,0,0"/>
            </StackPanel>
          </Border>

          <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="11,9" Margin="0,0,0,9">
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="108"/><ColumnDefinition Width="135"/><ColumnDefinition Width="112"/></Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0" Margin="0,0,10,0">
                <TextBlock Text="固定场景标识（2–80字）" Foreground="{DynamicResource TextSec}" FontSize="10"/>
                <TextBox x:Name="TuneSceneBox" Height="27" Margin="0,4,0,0" Padding="7,4" MaxLength="80"
                         Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1" Foreground="{DynamicResource TextPri}"/>
              </StackPanel>
              <StackPanel Grid.Column="1" Margin="0,0,10,0">
                <TextBlock Text="最大温升（0–7°C）" Foreground="{DynamicResource TextSec}" FontSize="10"/>
                <TextBox x:Name="TuneTempBox" Text="3" Height="27" Margin="0,4,0,0" Padding="7,4" MaxLength="3"
                         Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1" Foreground="{DynamicResource TextPri}"/>
              </StackPanel>
              <StackPanel Grid.Column="2" Margin="0,0,10,0">
                <TextBlock Text="功耗策略" Foreground="{DynamicResource TextSec}" FontSize="10"/>
                <CheckBox x:Name="TunePowerChk" Style="{StaticResource TacCheck}" Margin="0,6,0,0">
                  <TextBlock Text="允许更高功耗" Foreground="{DynamicResource TextPri}"/>
                </CheckBox>
              </StackPanel>
              <StackPanel Grid.Column="3">
                <TextBlock Text="最大增幅（0–20%）" Foreground="{DynamicResource TextSec}" FontSize="10"/>
                <TextBox x:Name="TunePowerBox" Text="0" Height="27" Margin="0,4,0,0" Padding="7,4" MaxLength="4" IsEnabled="False"
                         Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1" Foreground="{DynamicResource TextPri}"/>
              </StackPanel>
            </Grid>
          </Border>

          <UniformGrid Columns="4" Margin="0,0,0,9">
            <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="9,7" Margin="0,0,5,0"><StackPanel><TextBlock Text="实验状态" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneStatusText" Text="未创建" Foreground="{DynamicResource Green}" FontWeight="Bold" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
            <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="9,7" Margin="0,0,5,0"><StackPanel><TextBlock Text="当前方案 / 轮次" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneRoundText" Text="-" Foreground="{DynamicResource TextPri}" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
            <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="9,7" Margin="0,0,5,0"><StackPanel><TextBlock Text="基线稳定性" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneBaselineText" Text="待采样" Foreground="{DynamicResource TextPri}" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
            <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="9,7"><StackPanel><TextBlock Text="当前保留组合" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneCurrentText" Text="基线" Foreground="{DynamicResource TextPri}" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
          </UniformGrid>

          <Grid Margin="0,0,0,9">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="9,6" Margin="0,0,5,0"><TextBlock x:Name="TuneG1Text" Text="G1 后台与游戏模式：待实验" Foreground="{DynamicResource TextSec}" TextWrapping="Wrap"/></Border>
            <Border Grid.Column="1" Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="9,6" Margin="0,0,5,0"><TextBlock x:Name="TuneG2Text" Text="G2 前台调度：待实验" Foreground="{DynamicResource TextSec}" TextWrapping="Wrap"/></Border>
            <Border Grid.Column="2" Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="9,6"><TextBlock x:Name="TuneG3Text" Text="G3 显示与 GPU 选择：待实验" Foreground="{DynamicResource TextSec}" TextWrapping="Wrap"/></Border>
          </Grid>

          <Border Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="0,0,0,9">
            <StackPanel>
              <Grid Background="{DynamicResource TableHeader}" Margin="0" Height="25">
                <Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="100"/><ColumnDefinition Width="70"/><ColumnDefinition Width="70"/><ColumnDefinition Width="70"/><ColumnDefinition Width="70"/><ColumnDefinition Width="58"/><ColumnDefinition Width="58"/><ColumnDefinition Width="58"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="#" Style="{StaticResource Mono}" Margin="8,5"/><TextBlock Grid.Column="1" Text="方案" Style="{StaticResource Mono}" Margin="5"/>
                <TextBlock Grid.Column="2" Text="平均帧率" Style="{StaticResource Mono}" Margin="5"/><TextBlock Grid.Column="3" Text="1% 低" Style="{StaticResource Mono}" Margin="5"/>
                <TextBlock Grid.Column="4" Text="P99 ms" Style="{StaticResource Mono}" Margin="5"/><TextBlock Grid.Column="5" Text="卡顿/分" Style="{StaticResource Mono}" Margin="5"/>
                <TextBlock Grid.Column="6" Text="GPU%" Style="{StaticResource Mono}" Margin="5"/><TextBlock Grid.Column="7" Text="温度" Style="{StaticResource Mono}" Margin="5"/>
                <TextBlock Grid.Column="8" Text="功耗" Style="{StaticResource Mono}" Margin="5"/><TextBlock Grid.Column="9" Text="有效性 / 原因" Style="{StaticResource Mono}" Margin="5"/>
              </Grid>
              <StackPanel x:Name="TuneRunPanel"/>
            </StackPanel>
          </Border>

          <TextBlock x:Name="TuneHintText" Text="创建实验后，每次按「执行下一步」完成 120 秒同场景采样。实验可稍后继续。" Foreground="{DynamicResource TextSec}" TextWrapping="Wrap" Margin="1,0,1,8"/>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="TuneCreateBtn" Content="创建 / 继续实验" Style="{StaticResource Primary}" Width="210"/>
            <Button x:Name="TuneNextBtn" Content="执行下一步" Style="{StaticResource Ghost}" Width="145" Margin="9,0,0,0"/>
            <Button x:Name="TuneStopBtn" Content="停止并回滚" Style="{StaticResource Ghost}" Width="135" Margin="9,0,0,0"/>
          </StackPanel>
        </StackPanel>
      </ScrollViewer>
    </Grid>

    <!-- 近期版本掉帧排查：只按本机主力显卡给出可能有效的步骤。 -->
    <Grid Grid.Row="2" x:Name="FrameFixPage" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="21,10">
        <StackPanel>
          <Grid Margin="0,0,0,9">
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="掉帧修复" Style="{StaticResource HeadCn}"/>
              <TextBlock Text="FRAME DROP REPAIR" Style="{StaticResource HeadEn}"/>
              <Border Style="{StaticResource HeadBar}"/>
            </StackPanel>
            <Border Grid.Column="1" Height="1" Background="{DynamicResource LineSoft}" VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <Border Grid.Column="2" Background="{DynamicResource GoldDark}" BorderBrush="{DynamicResource Gold}" BorderThickness="1" Padding="7,2" VerticalAlignment="Bottom">
              <TextBlock Text="POSSIBLE FIXES" Foreground="{DynamicResource Gold}" FontFamily="Consolas" FontSize="9" FontWeight="Bold"/>
            </Border>
          </Grid>

          <Border Background="{DynamicResource AccentPanel}" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Padding="11,9" Margin="0,0,0,9">
            <StackPanel>
              <TextBlock x:Name="FrameFixGpuText" Text="正在识别主力显卡…" Foreground="{DynamicResource Green}" FontSize="14" FontWeight="Bold" TextWrapping="Wrap"/>
              <TextBlock x:Name="FrameFixSummaryText" Text="" Foreground="{DynamicResource TextSec}" TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>
          </Border>

          <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="12,9" Margin="0,0,0,9">
            <StackPanel>
              <TextBlock Text="先做这些 · 全显卡通用" Foreground="{DynamicResource TextPri}" FontSize="13" FontWeight="Bold"/>
              <TextBlock x:Name="FrameFixCommonText" Text="" Foreground="{DynamicResource TextSec}" FontSize="12" LineHeight="20" TextWrapping="Wrap" Margin="0,6,0,0"/>
            </StackPanel>
          </Border>

          <Border Background="{DynamicResource AccentPanel}" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Padding="12,9" Margin="0,0,0,9">
            <StackPanel>
              <TextBlock Text="工具可直接执行" Foreground="{DynamicResource Green}" FontSize="13" FontWeight="Bold"/>
              <TextBlock Text="下面三项会直接调用软件现有的受保护操作；涉及修改的项目仍会先写入可还原备份。"
                         Foreground="{DynamicResource TextSec}" FontSize="11" TextWrapping="Wrap" Margin="0,4,0,8"/>
              <WrapPanel>
                <Button x:Name="FrameFixCacheBtn" Content="清理着色器缓存" Style="{StaticResource Primary}" Width="170"/>
                <Button x:Name="FrameFixGpuPrefBtn" Content="设置高性能 GPU" Style="{StaticResource Ghost}" Width="160" Margin="9,0,0,0"/>
                <Button x:Name="FrameFixVcBtn" Content="检查 VC++ 运行库" Style="{StaticResource Ghost}" Width="160" Margin="9,0,0,0"/>
              </WrapPanel>
              <StackPanel x:Name="FrameFixProgressPanel" Visibility="Collapsed" Margin="0,8,0,0">
                <ProgressBar x:Name="FrameFixProgressBar" Height="6" Minimum="0" Maximum="100" Value="0"
                             Foreground="{DynamicResource Green}" Background="{DynamicResource PanelDeep}"
                             BorderBrush="{DynamicResource Line}" BorderThickness="1"/>
                <TextBlock x:Name="FrameFixProgressText" Text="" Style="{StaticResource Mono}"
                           Foreground="{DynamicResource TextSec}" TextWrapping="Wrap" Margin="0,5,0,0"/>
              </StackPanel>
              <TextBlock x:Name="FrameFixActionStatus" Text="请选择一项操作。" Foreground="{DynamicResource TextSec}"
                         FontSize="11" TextWrapping="Wrap" Margin="0,8,0,0"/>
            </StackPanel>
          </Border>

          <Border Background="{DynamicResource Panel}" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Padding="12,9" Margin="0,0,0,9">
            <StackPanel>
              <TextBlock x:Name="FrameFixVendorTitle" Text="显卡专项排查" Foreground="{DynamicResource Green}" FontSize="13" FontWeight="Bold"/>
              <TextBlock x:Name="FrameFixVendorText" Text="" Foreground="{DynamicResource TextSec}" FontSize="12" LineHeight="20" TextWrapping="Wrap" Margin="0,6,0,0"/>
            </StackPanel>
          </Border>

          <Border Background="{DynamicResource WarningPanel}" BorderBrush="{DynamicResource Gold}" BorderThickness="1" Padding="11,8" Margin="0,0,0,9">
            <StackPanel>
              <TextBlock Text="最后再尝试" Foreground="{DynamicResource Gold}" FontSize="12" FontWeight="Bold"/>
              <TextBlock x:Name="FrameFixCautionText" Text="" Foreground="{DynamicResource TextSec}" TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>
          </Border>

          <StackPanel Orientation="Horizontal">
            <Button x:Name="FrameFixOptBtn" Content="前往优化页" Style="{StaticResource Primary}" Width="180"/>
            <Button x:Name="FrameFixGuideBtn" Content="打开显卡指引" Style="{StaticResource Ghost}" Width="145" Margin="9,0,0,0"/>
          </StackPanel>
          <TextBlock Text="以上均为可能有效的排查步骤，不保证适合每台机器；请一次只改一项并在同一场景复测。"
                     Style="{StaticResource Mono}" TextWrapping="Wrap" Margin="1,9,0,0"/>
        </StackPanel>
      </ScrollViewer>
    </Grid>

    <!-- 游戏内设置参考页：纯展示（内容由代码按 data\streamer-settings.json 构建） -->
    <Grid Grid.Row="2" x:Name="RefPage" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="21,10">
        <StackPanel x:Name="RefPanel"/>
      </ScrollViewer>
    </Grid>

    <!-- 运行日志页：逐条文本记录。执行进度与结果汇总留在优化页，用户不必为看结果切页 -->
    <Grid Grid.Row="2" x:Name="LogPage" Visibility="Collapsed" Margin="21,10,21,10">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <Grid Grid.Row="0" Margin="0,0,0,7">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock Text="运行日志" Style="{StaticResource HeadCn}"/>
          <TextBlock Text="RUN LOG" Style="{StaticResource HeadEn}"/>
          <Border Style="{StaticResource HeadBar}"/>
        </StackPanel>
        <Border Grid.Column="1" Height="1" Background="{DynamicResource LineSoft}"
                VerticalAlignment="Bottom" Margin="12,0,12,4"/>
        <!-- 一键复制：反馈问题时直接整段拷走，不用在小窗里手动拖选。
             图标 Path 用固定坐标（不加 Stretch）：归一化坐标 + Stretch 会被撑大（教训 #3） -->
        <Button x:Name="CopyLogBtn" Grid.Column="2" Style="{StaticResource Ghost}" Height="24"
                FontSize="11" VerticalAlignment="Bottom" ToolTip="复制全部日志到剪贴板">
          <StackPanel Orientation="Horizontal">
            <Path Data="M 0,3 L 0,11 L 6,11 L 6,3 Z M 3,0 L 9,0 L 9,8 L 6,8" Stroke="{DynamicResource Green}"
                  StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center"/>
            <TextBlock x:Name="CopyLogTxt" Text="复制" Margin="5,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
      </Grid>
      <Border Grid.Row="1" Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1">
        <TextBox x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="Transparent"
                 Foreground="{DynamicResource TextSec}" FontFamily="Consolas" FontSize="11" Padding="10,7"/>
      </Border>
      <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,9,0,0">
        <!-- 把诊断信息打包发给作者排查；上传前列清单请用户确认，不会静默发送 -->
        <Button x:Name="ReportBtn" Content="上传完整诊断" Style="{StaticResource Ghost}" Width="132"/>
        <TextBlock Text="关闭软件后仍保留最近运行日志；重新打开可直接复制或上传" Style="{StaticResource Mono}"
                   Margin="12,0,0,0"/>
      </StackPanel>
    </Grid>

    <StackPanel Grid.Row="3" x:Name="ActionRow" Margin="29,6,29,8">
      <StackPanel Orientation="Horizontal">
        <!-- 主 CTA：绿色实底 + 深色字 + 左侧图标（官网下载按钮三要素） -->
        <Button x:Name="ApplyBtn" Style="{StaticResource Primary}" Width="230">
          <StackPanel Orientation="Horizontal">
            <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="{DynamicResource GreenDark}"
                  Width="18" Height="15" Stretch="Uniform" VerticalAlignment="Center" Margin="0,0,9,0"/>
            <TextBlock Text="执行优化" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
        <Button x:Name="RestoreBtn" Content="还原设置" Style="{StaticResource Ghost}" Width="118" Margin="9,0,0,0"/>
        <Button x:Name="RefreshBtn" Content="重新检测" Style="{StaticResource Ghost}" Width="104" Margin="9,0,0,0"/>
        <Button x:Name="GuideBtn" Content="显卡指引" Style="{StaticResource Ghost}" Width="104" Margin="9,0,0,0"/>
      </StackPanel>
      <!-- 执行进度留在优化页：日志挪走后，这里是执行期间唯一的实时反馈 -->
      <StackPanel x:Name="ProgressPanel" Visibility="Collapsed" Margin="0,9,0,0">
        <Border x:Name="ProgTrack" Height="6" Background="{DynamicResource PanelDeep}"
                BorderBrush="{DynamicResource Line}" BorderThickness="1">
          <Border x:Name="ProgFill" Background="{DynamicResource Green}" HorizontalAlignment="Left" Width="0"/>
        </Border>
        <Grid Margin="0,5,0,0">
          <!-- 换行而不是截断：执行完成后这里要放下汇总 + 失败项名，截掉就等于没说 -->
          <TextBlock x:Name="ProgText" Style="{StaticResource Mono}" Foreground="{DynamicResource TextSec}"
                     Text="" TextWrapping="Wrap" HorizontalAlignment="Left" Margin="0,0,120,0"/>
          <TextBlock x:Name="ProgCount" Style="{StaticResource Mono}" Foreground="{DynamicResource Green}"
                     Text="" HorizontalAlignment="Right"/>
        </Grid>
      </StackPanel>
    </StackPanel>

    <!-- 页脚 HUD 线：等宽小字 + 金色短段 + 空心小方块 -->
    <Grid Grid.Row="4" Margin="29,0,29,9" VerticalAlignment="Center">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <!-- 非官方声明常驻页脚：NOTICE.md 的核心一句，用户不会主动去翻文件 -->
      <TextBlock Grid.Column="0" Text="非官方工具 · 与腾讯及《三角洲行动》官方无关" Style="{StaticResource Mono}" FontSize="9"/>
      <Border Grid.Column="1" Width="26" Height="2" Background="{DynamicResource Gold}" VerticalAlignment="Center" Margin="9,0,0,0"/>
      <Border Grid.Column="2" Height="1" Background="{DynamicResource LineSoft}" VerticalAlignment="Center" Margin="9,0"/>
      <Border Grid.Column="3" Width="5" Height="5" BorderBrush="{DynamicResource Green}" BorderThickness="1" VerticalAlignment="Center" Margin="0,0,9,0"/>
      <StackPanel Grid.Column="4" Orientation="Horizontal">
        <TextBlock Text="[ V0.23.0.13 ] 改动前自动备份 · 可按项目精确复原" Style="{StaticResource Mono}" FontSize="9"/>
        <!-- 随时可重看免责声明：首次启动的门控之外也得留个常驻入口 -->
        <Button x:Name="DisclaimerBtn" Style="{StaticResource Ghost}" Height="17" FontSize="9"
                Margin="10,0,0,0" Content="免责声明"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
$script:DefaultAppWindowHeight = 1200.0
# 默认高度拉长到用户实机调整后的高度；小屏机器仍按工作区留出边缘。
$workAreaHeight = [double][Windows.SystemParameters]::WorkArea.Height
if ($workAreaHeight -gt 0) {
  $window.Height = [math]::Min($script:DefaultAppWindowHeight,[math]::Max(640.0,$workAreaHeight-32.0))
}
# 不设 Icon 时任务栏/Alt-Tab 显示宿主 powershell.exe 的图标（实机反馈）。
# app.ico 由 build\make-launcher.ps1 生成、随包分发；缺失（手动拷贝的残缺包）时
# 静默跳过——图标问题绝不能挡启动
try {
  $icoPath = Join-Path $PSScriptRoot 'app.ico'
  if (Test-Path -LiteralPath $icoPath) {
    # 直接用文件 Uri 会让 WPF 的解码器长期持有 app.ico，覆盖更新时安装器因此报“正由另
    # 一进程使用”。OnLoad 把图标完整读进内存并立即释放文件句柄，窗口生命周期不再锁文件。
    $icoStream = [IO.File]::Open($icoPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
      $ico = New-Object Windows.Media.Imaging.BitmapImage
      $ico.BeginInit()
      $ico.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
      $ico.StreamSource = $icoStream
      $ico.EndInit()
      $ico.Freeze()
      $window.Icon = $ico
    } finally { $icoStream.Dispose() }
  }
} catch {}
# ---------- 全局深色 Chrome 资源字典 ----------
# 对话框是 XamlReader 另行 Parse 的独立 Window，不继承主窗口 Window.Resources——样式只挂
# 主窗口时，对话框里的滚动条仍是系统白色（实机反馈）。这里把 WPF 默认浅色的零件
# （ScrollBar 纵横双向、ToolTip、右键菜单、文本选中色、焦点虚线框）一次做成深色，
# 主窗口与全部对话框引用同一份实例。
$script:ThemeResXaml = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <!-- 独立对话框不会继承主窗口资源；这里同时提供可切换的调色板。 -->
  <SolidColorBrush x:Key="TopBar"       Color="#FF0D1417"/>
  <SolidColorBrush x:Key="Panel"        Color="#FF0E1B17"/>
  <SolidColorBrush x:Key="PanelDeep"    Color="#FF0B1713"/>
  <SolidColorBrush x:Key="LogBg"        Color="#FF081310"/>
  <SolidColorBrush x:Key="Line"         Color="#FF1B2E28"/>
  <SolidColorBrush x:Key="LineSoft"     Color="#FF16241F"/>
  <SolidColorBrush x:Key="LineHi"       Color="#FF2C443B"/>
  <SolidColorBrush x:Key="TextPri"      Color="#FFFFFFFF"/>
  <SolidColorBrush x:Key="TextSec"      Color="#FF9AA5A0"/>
  <SolidColorBrush x:Key="TextMut"      Color="#FF7A8580"/>
  <SolidColorBrush x:Key="Green"        Color="#FF00E884"/>
  <SolidColorBrush x:Key="GreenDark"    Color="#FF04241B"/>
  <SolidColorBrush x:Key="GreenLine"    Color="#FF00E884"/>
  <SolidColorBrush x:Key="Gold"         Color="#FFE5C46A"/>
  <SolidColorBrush x:Key="GoldDark"     Color="#FF3A2C0C"/>
  <SolidColorBrush x:Key="Danger"       Color="#FFE5484D"/>
  <SolidColorBrush x:Key="AccentPanel"  Color="#FF0E2A21"/>
  <SolidColorBrush x:Key="TableHeader"  Color="#FF0C1915"/>
  <SolidColorBrush x:Key="ComboSurface" Color="#FF0B1712"/>
  <SolidColorBrush x:Key="HoverPanel"   Color="#FF12291F"/>
  <SolidColorBrush x:Key="SelectedPanel" Color="#FF0F2118"/>
  <SolidColorBrush x:Key="WindowHover"  Color="#FF14241F"/>
  <SolidColorBrush x:Key="DisabledText" Color="#FF56615C"/>
  <SolidColorBrush x:Key="WarningPanel" Color="#FF2A2008"/>
  <SolidColorBrush x:Key="DangerPanel"  Color="#FF1A0E10"/>
  <SolidColorBrush x:Key="InputSurface" Color="#FF0C1814"/>
  <Style TargetType="ScrollBar">
    <Setter Property="Width" Value="6"/>
    <!-- Min/Max 必须一起钉死：主题默认样式仍会给 ScrollBar 兜一个 MinWidth≈17，
         而 WPF 布局钳制里 Min 压过 Max 和 Width，不清零就永远是系统宽度（实测 17px） -->
    <Setter Property="MinWidth" Value="0"/>
    <Setter Property="MaxWidth" Value="6"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ScrollBar">
          <Grid Background="Transparent">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.DecreaseRepeatButton>
                <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
              </Track.DecreaseRepeatButton>
              <Track.IncreaseRepeatButton>
                <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
              </Track.IncreaseRepeatButton>
              <Track.Thumb>
                <Thumb>
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb">
                      <Border Background="{DynamicResource LineHi}" CornerRadius="3"/>
                    </ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
            </Track>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <!-- 横向滚动条（游戏内设置参考页的对照表会用到）：老样式只做了纵向模板，
           横向一旦出现会被 Width=6 挤成一条竖线 -->
      <Trigger Property="Orientation" Value="Horizontal">
        <Setter Property="Width" Value="Auto"/>
        <Setter Property="MaxWidth" Value="1000000"/>
        <Setter Property="Height" Value="6"/>
        <Setter Property="MinHeight" Value="0"/>
        <Setter Property="MaxHeight" Value="6"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="ScrollBar">
              <Grid Background="Transparent">
                <Track x:Name="PART_Track">
                  <Track.DecreaseRepeatButton>
                    <RepeatButton Command="ScrollBar.PageLeftCommand" Opacity="0" Focusable="False"/>
                  </Track.DecreaseRepeatButton>
                  <Track.IncreaseRepeatButton>
                    <RepeatButton Command="ScrollBar.PageRightCommand" Opacity="0" Focusable="False"/>
                  </Track.IncreaseRepeatButton>
                  <Track.Thumb>
                    <Thumb>
                      <Thumb.Template>
                        <ControlTemplate TargetType="Thumb">
                          <Border Background="{DynamicResource LineHi}" CornerRadius="3"/>
                        </ControlTemplate>
                      </Thumb.Template>
                    </Thumb>
                  </Track.Thumb>
                </Track>
              </Grid>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Trigger>
    </Style.Triggers>
  </Style>
  <!-- ToolTip：默认是白底系统气泡 -->
  <Style TargetType="ToolTip">
    <Setter Property="Background" Value="{DynamicResource Panel}"/>
    <Setter Property="BorderBrush" Value="{DynamicResource LineHi}"/>
    <Setter Property="Foreground" Value="{DynamicResource TextSec}"/>
    <Setter Property="Padding" Value="9,5"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToolTip">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="1" Padding="{TemplateBinding Padding}">
            <ContentPresenter/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <!-- TextBox 右键菜单（复制/粘贴）：默认白底。项目里没有子菜单，简化模板即可 -->
  <Style TargetType="ContextMenu">
    <Setter Property="Background" Value="{DynamicResource Panel}"/>
    <Setter Property="BorderBrush" Value="{DynamicResource LineHi}"/>
    <Setter Property="Foreground" Value="{DynamicResource TextSec}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ContextMenu">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="1" Padding="2">
            <ItemsPresenter/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="MenuItem">
    <Setter Property="Foreground" Value="{DynamicResource TextSec}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="MenuItem">
          <Border x:Name="BD" Background="Transparent" Padding="12,5">
            <ContentPresenter ContentSource="Header" RecognizesAccessKey="True"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsHighlighted" Value="True">
              <Setter TargetName="BD" Property="Background" Value="{DynamicResource HoverPanel}"/>
              <Setter Property="Foreground" Value="{DynamicResource Green}"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter Property="Foreground" Value="{DynamicResource DisabledText}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="Separator">
    <Setter Property="Background" Value="{DynamicResource Line}"/>
    <Setter Property="Height" Value="1"/>
    <Setter Property="Margin" Value="4,2"/>
  </Style>
  <!-- 文本选中色：默认的系统蓝在青绿主题里最扎眼；焦点虚线框一并去掉 -->
  <Style TargetType="TextBox">
    <Setter Property="SelectionBrush" Value="#8000E884"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  </Style>
  <Style x:Key="MetricHistoryButton" TargetType="Button">
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Foreground" Value="{DynamicResource Green}"/>
    <Setter Property="FontFamily" Value="Microsoft YaHei UI"/>
    <Setter Property="FontSize" Value="8"/>
    <Setter Property="Width" Value="32"/>
    <Setter Property="Height" Value="17"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
              <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <!-- 对话框里的按钮/勾选框都是行内模板、没挂命名样式，隐式样式只补焦点虚线框，
       不设 Template 不会覆盖行内模板 -->
  <Style TargetType="Button">
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  </Style>
  <Style TargetType="CheckBox">
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  </Style>
</ResourceDictionary>
'@
$script:ThemeRes = [Windows.Markup.XamlReader]::Parse($script:ThemeResXaml)
$window.Resources.MergedDictionaries.Add($script:ThemeRes)

$ui = @{}
foreach ($n in 'TitleBar','MinBtn','CloseBtn','UpdateBtn','NoticeBtn','NoticeText','NoticeBadge','NoticeBadgeTxt','ThemeBtn','ScanState','MetricsGrid','HwGrid','GameText','BrowseBtn','CountText',
               'SelAllChk',
               'ItemPanel','RiskyGroup','RiskyPanel','OptHeaderGrid','OptHeaderSplitter','ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','CheckUpdBtn',
               'InlineRestorePanel','InlineRestoreItemsPanel','InlineRestoreEmptyText',
               'InlineRestoreLegacyNotice','InlineRestoreLegacyText','InlineRestoreSelectedText','InlineRestoreAllSummary',
               'InlineRestoreSelectAllBtn','InlineRestoreClearBtn','InlineRestoreSelectedBtn','InlineRestoreAllBtn','InlineRestoreCloseBtn',
               'ReportBtn','DisclaimerBtn','LogBox',
               'PresetBox','SavePresetBtn','DelPresetBtn','PresetNote',
               'TabOptBtn','TabTuneBtn','TabFrameFixBtn','TabRefBtn','TabLogBtn','LogBadge','LogBadgeTxt',
               'OptPage','TunePage','FrameFixPage','RefPage','LogPage','RefPanel','ActionRow',
               'FrameFixGpuText','FrameFixSummaryText','FrameFixCommonText','FrameFixVendorTitle','FrameFixVendorText',
               'FrameFixCautionText','FrameFixCacheBtn','FrameFixGpuPrefBtn','FrameFixVcBtn','FrameFixActionStatus',
               'FrameFixProgressPanel','FrameFixProgressBar','FrameFixProgressText',
               'FrameFixOptBtn','FrameFixGuideBtn',
               'TuneSceneBox','TuneTempBox','TunePowerChk','TunePowerBox',
               'TuneStatusText','TuneRoundText','TuneBaselineText','TuneCurrentText',
               'TuneG1Text','TuneG2Text','TuneG3Text','TuneRunPanel','TuneHintText',
               'TuneCreateBtn','TuneNextBtn','TuneStopBtn',
               'ProgressPanel','ProgTrack','ProgFill','ProgText','ProgCount','CopyLogBtn','CopyLogTxt') {
  $ui[$n] = $window.FindName($n)
}

# ---------- 深浅主题 + 主题化小部件构造 ----------

$script:ThemePalettes = @{
  dark = [ordered]@{
    WindowTop='#FF0A1512';WindowBottom='#FF10201C';TopBar='#FF0D1417';Panel='#FF0E1B17'
    PanelDeep='#FF0B1713';LogBg='#FF081310';Line='#FF1B2E28';LineSoft='#FF16241F';LineHi='#FF2C443B'
    TextPri='#FFFFFFFF';TextSec='#FF9AA5A0';TextMut='#FF7A8580';Green='#FF00E884';GreenDark='#FF04241B'
    GreenLine='#FF00E884';Gold='#FFE5C46A';GoldDark='#FF3A2C0C';Danger='#FFE5484D';DangerText='#FFFF6B6B'
    AccentPanel='#FF0E2A21';TableHeader='#FF0C1915';ComboSurface='#FF0B1712';HoverPanel='#FF12291F'
    SelectedPanel='#FF0F2118';WindowHover='#FF14241F';DisabledText='#FF56615C';WarningPanel='#FF2A2008'
    DangerPanel='#FF1A0E10';InputSurface='#FF0C1814';SubtlePanel='#FF10201A'
  }
  light = [ordered]@{
    WindowTop='#FFF6F7F4';WindowBottom='#FFE8EFEB';TopBar='#FFF0F4F1';Panel='#FFFFFFFF'
    PanelDeep='#FFF4F6F3';LogBg='#FFEEF2EF';Line='#FFCBD4CE';LineSoft='#FFDCE3DE';LineHi='#FFAEBAB3'
    TextPri='#FF121815';TextSec='#FF45524C';TextMut='#FF68736E';Green='#FF00E884';GreenDark='#FF04241B'
    GreenLine='#FF00E884';Gold='#FF1677B8';GoldDark='#FFF4FBFF';Danger='#FFD83F47';DangerText='#FFD83F47'
    AccentPanel='#FFE4F5ED';TableHeader='#FFE9EFEB';ComboSurface='#FFFFFFFF';HoverPanel='#FFE3EEE8'
    SelectedPanel='#FFD5EADF';WindowHover='#FFDDE7E1';DisabledText='#FF96A19B';WarningPanel='#FFE8F5FB'
    DangerPanel='#FFFFECEE';InputSurface='#FFFAFCFB';SubtlePanel='#FFEAF0EC'
  }
}
$script:CurrentTheme = 'dark'
$script:C = @{}
$script:ThemeBrushCache = @{}
$script:ThemeColorAliases = @{
  '#FF0B1713'='PanelDeep';'#FF10201A'='SubtlePanel'
  '#FFE5484D'='Danger';'#FFFF6B6B'='DangerText';'#FF7A8580'='TextMut'
}

function Set-ThemeColorTable([string]$Theme) {
  $palette = $script:ThemePalettes[$Theme]
  foreach ($key in $palette.Keys) { $script:C[$key] = "$($palette[$key])" }
  $script:C.Gray = "$($palette.TextMut)"
  $script:C.Danger = "$($palette.DangerText)"
}
Set-ThemeColorTable 'dark'

function Resolve-ThemeColorKey([string]$Hex) {
  $value = "$Hex".ToUpperInvariant()
  foreach ($theme in 'dark','light') {
    foreach ($entry in $script:ThemePalettes[$theme].GetEnumerator()) {
      if ("$($entry.Value)".ToUpperInvariant() -eq $value) { return "$($entry.Key)" }
    }
  }
  if ($script:ThemeColorAliases.ContainsKey($value)) { return "$($script:ThemeColorAliases[$value])" }
  $null
}

function New-Brush([string]$Hex) {
  $key = Resolve-ThemeColorKey $Hex
  if ($key) {
    if (-not $script:ThemeBrushCache.ContainsKey($key)) {
      $script:ThemeBrushCache[$key] = (New-Object Windows.Media.BrushConverter).ConvertFromString(
        "$($script:ThemePalettes[$script:CurrentTheme][$key])")
    }
    return $script:ThemeBrushCache[$key]
  }
  (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex)
}

$script:UiPreferencesPath = Join-Path $script:UserConfigDir 'ui-preferences.json'
function Get-SavedUiPreferences {
  try {
    if (-not (Test-Path -LiteralPath $script:UiPreferencesPath -PathType Leaf)) { return $null }
    $file = Get-Item -LiteralPath $script:UiPreferencesPath -Force
    if ($file.Length -le 0 -or $file.Length -gt 4096) { return $null }
    $value = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json -ErrorAction Stop
    if ([int]$value.schemaVersion -eq 1) { return $value }
  } catch {}
  $null
}

function Get-SavedAppTheme {
  if (-not $script:LightThemeEnabled) { return 'dark' }
  $value = Get-SavedUiPreferences
  if ($value -and "$($value.theme)" -in 'dark','light') { return "$($value.theme)" }
  'dark'
}

function Get-SavedAppWindowHeight {
  $value = Get-SavedUiPreferences
  try {
    if ($value -and $value.PSObject.Properties['windowHeight']) {
      $height = [double]$value.windowHeight
      if (-not [double]::IsNaN($height) -and -not [double]::IsInfinity($height) -and $height -ge 640 -and $height -le 10000) {
        return $height
      }
    }
  } catch {}
  [double]$script:DefaultAppWindowHeight
}

function Get-PersistableAppWindowHeight {
  $height = $(if ($window.WindowState -eq [Windows.WindowState]::Normal) { [double]$window.Height } else { [double]$window.RestoreBounds.Height })
  if ([double]::IsNaN($height) -or [double]::IsInfinity($height) -or $height -lt 640) {
    $height = [double]$script:DefaultAppWindowHeight
  }
  [math]::Round($height,0)
}

function Set-SavedAppWindowHeight {
  $workHeight = [double][Windows.SystemParameters]::WorkArea.Height
  $maximum = $(if ($workHeight -gt 0) { [math]::Max(640.0,$workHeight-32.0) } else { [double]$script:DefaultAppWindowHeight })
  $window.Height = [math]::Min($maximum,[math]::Max(640.0,(Get-SavedAppWindowHeight)))
}

function Save-AppUiPreferences([string]$Theme, [double]$WindowHeight) {
  if (-not $script:LightThemeEnabled) { $Theme = 'dark' }
  if ($Theme -notin 'dark','light') { $Theme = 'dark' }
  if ([double]::IsNaN($WindowHeight) -or [double]::IsInfinity($WindowHeight) -or $WindowHeight -lt 640) {
    $WindowHeight = [double]$script:DefaultAppWindowHeight
  }
  $payload = [pscustomobject][ordered]@{
    schemaVersion=1
    theme=$Theme
    windowHeight=[math]::Round($WindowHeight,0)
  }
  $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($payload | ConvertTo-Json -Compress))
  Write-BytesAtomic $script:UiPreferencesPath $bytes
}

function Save-AppTheme([string]$Theme) {
  Save-AppUiPreferences $Theme (Get-PersistableAppWindowHeight)
}

function Set-AppTheme([ValidateSet('dark','light')][string]$Theme, [switch]$Persist) {
  if (-not $script:LightThemeEnabled) { $Theme = 'dark' }
  $script:CurrentTheme = $Theme
  $palette = $script:ThemePalettes[$Theme]
  foreach ($key in $palette.Keys) {
    if ($key -in 'WindowTop','WindowBottom','DangerText','SubtlePanel') { continue }
    foreach ($dictionary in @($window.Resources,$script:ThemeRes)) {
      if ($dictionary.Contains($key)) {
        $dictionary[$key] = (New-Object Windows.Media.BrushConverter).ConvertFromString("$($palette[$key])")
      }
    }
  }
  $gradient = New-Object Windows.Media.LinearGradientBrush
  $gradient.StartPoint = New-Object Windows.Point 0,0
  $gradient.EndPoint = New-Object Windows.Point 0,1
  $gradient.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList @(
    [Windows.Media.ColorConverter]::ConvertFromString("$($palette.WindowTop)"),0.0))) | Out-Null
  $gradient.GradientStops.Add((New-Object Windows.Media.GradientStop -ArgumentList @(
    [Windows.Media.ColorConverter]::ConvertFromString("$($palette.WindowBottom)"),1.0))) | Out-Null
  $window.Background = $gradient
  Set-ThemeColorTable $Theme
  foreach ($entry in @($script:ThemeBrushCache.GetEnumerator())) {
    $color = $(if ($palette.Contains($entry.Key)) { "$($palette[$entry.Key])" } else { "$($script:C[$entry.Key])" })
    if ($color -and $entry.Value -is [Windows.Media.SolidColorBrush]) {
      $entry.Value.Color = [Windows.Media.ColorConverter]::ConvertFromString($color)
    }
  }
  if ($ui.ThemeBtn) {
    $ui.ThemeBtn.Content = $(if ($Theme -eq 'dark') { '☀ 浅色' } else { '☾ 深色' })
    $ui.ThemeBtn.ToolTip = $(if ($Theme -eq 'dark') { '切换浅色模式' } else { '切换深色模式' })
  }
  if ($Persist) { Save-AppTheme $Theme }
}

function New-Text([string]$Content, [string]$Color, [int]$Size, [switch]$Mono) {
  $t = New-Object Windows.Controls.TextBlock
  $t.Text = $Content
  $t.Foreground = New-Brush $Color
  $t.FontSize = $Size
  $t.VerticalAlignment = 'Center'
  if ($Mono) { $t.FontFamily = New-Object Windows.Media.FontFamily 'Consolas' }
  $t
}

function New-HwCard([string]$Label, [string]$Value, [string]$Sub, [switch]$Ribbon, [string]$TemperatureKey = '') {
  $b = New-Object Windows.Controls.Border
  $b.Background = New-Brush $script:C.Panel
  $b.BorderBrush = New-Brush $script:C.Line
  $b.BorderThickness = New-Object Windows.Thickness 1
  $b.Padding = New-Object Windows.Thickness 10, 6, 10, 6
  $sp = New-Object Windows.Controls.StackPanel
  # 标签行：小空心方块 + 等宽标签（官网信息卡的方形项目符）
  $head = New-Object Windows.Controls.StackPanel
  $head.Orientation = 'Horizontal'
  $sq = New-Object Windows.Controls.Border
  $sq.Width = 5; $sq.Height = 5
  $sq.BorderBrush = New-Brush $script:C.Green
  $sq.BorderThickness = New-Object Windows.Thickness 1
  $sq.VerticalAlignment = 'Center'
  $sq.Margin = New-Object Windows.Thickness 0, 0, 6, 0
  $head.Children.Add($sq) | Out-Null
  $head.Children.Add((New-Text $Label $script:C.TextMut 10 -Mono)) | Out-Null
  if ($TemperatureKey) {
    $temperature = New-Object Windows.Controls.StackPanel
    $temperature.Orientation = 'Horizontal'
    $temperature.HorizontalAlignment = 'Right'
    $temperature.Margin = New-Object Windows.Thickness 8,0,0,0
    $temperatureValue = New-Text '--' $script:C.TextPri 15 -Mono
    $temperatureValue.FontWeight = 'Bold'
    $temperatureUnit = New-Text '°C' $script:C.TextPri 15 -Mono
    $temperatureUnit.FontWeight = 'Bold'
    $temperatureUnit.Margin = New-Object Windows.Thickness 1,0,0,0
    [void]$temperature.Children.Add($temperatureValue); [void]$temperature.Children.Add($temperatureUnit)
    $temperature.SetValue([Windows.Controls.DockPanel]::DockProperty,[Windows.Controls.Dock]::Right)
    $headerDock = New-Object Windows.Controls.DockPanel
    $headerDock.LastChildFill = $true
    [void]$headerDock.Children.Add($temperature)
    [void]$headerDock.Children.Add($head)
    $sp.Children.Add($headerDock) | Out-Null
    $script:HardwareTemperatureReadouts[$TemperatureKey] = [pscustomobject]@{
      ValueText=$temperatureValue;UnitText=$temperatureUnit;Container=$temperature
    }
  } else {
    $sp.Children.Add($head) | Out-Null
  }
  # 四张硬件卡统一完整显示：短名称保持单行，长名称自动换行。
  $v = New-Text $Value $script:C.TextPri 12
  $v.TextWrapping = 'Wrap'
  $v.TextTrimming = 'None'
  $v.ToolTip = $Value
  $sp.Children.Add($v) | Out-Null
  $sp.Children.Add((New-Text $Sub $script:C.TextSec 10 -Mono)) | Out-Null
  $b.Child = $sp
  # 小卡片右上角的主题强调色角标：这里用来标记主力硬件（如主显卡）
  $g = New-Object Windows.Controls.Grid
  $g.Margin = New-Object Windows.Thickness 0, 0, 8, 0
  $g.Children.Add($b) | Out-Null
  if ($Ribbon) {
    $tri = New-Object Windows.Shapes.Path
    $tri.Data = [Windows.Media.Geometry]::Parse('M 0,0 L 12,0 L 12,12 Z')
    $tri.Fill = New-Brush $script:C.Gold
    $tri.HorizontalAlignment = 'Right'
    $tri.VerticalAlignment = 'Top'
    $tri.Margin = New-Object Windows.Thickness 0, 1, 1, 0
    $tri.ToolTip = '游戏使用的主力硬件'
    $g.Children.Add($tri) | Out-Null
  }
  $g
}

function New-Pill([string]$Text, [string]$Fg, [string]$Bg, [string]$Bd) {
  # 官网分类标签手法：实底色块 + 深色粗体字
  $b = New-Object Windows.Controls.Border
  $b.Background = New-Brush $Bg
  $b.BorderBrush = New-Brush $Bd
  $b.BorderThickness = New-Object Windows.Thickness 1
  $b.Padding = New-Object Windows.Thickness 7, 0, 7, 0
  $b.VerticalAlignment = 'Center'
  $t = New-Text $Text $Fg 11
  $t.FontWeight = 'Bold'
  $b.Child = $t
  $b
}

$script:MetricGauges = @{}
$script:HardwareTemperatureReadouts = @{}

function New-MetricHistoryButton([string]$Key, [string]$Label) {
  $button = New-Object Windows.Controls.Button
  $button.Content = '记录'
  $button.Tag = $Key
  $button.Width = 32; $button.Height = 17; $button.FontSize = 8
  $button.HorizontalAlignment = 'Right'; $button.VerticalAlignment = 'Top'
  $button.ToolTip = "查看 $Label 历史记录"
  try {
    if ($script:ThemeRes -and $script:ThemeRes.Contains('MetricHistoryButton')) {
      $button.Style = $script:ThemeRes['MetricHistoryButton']
    }
  } catch {}
  $button.Add_Click({ Show-PerformanceMetricHistory "$($this.Tag)" })
  $button
}

function New-FpsMetricCard {
  $card = New-Object Windows.Controls.Border
  $card.Background = New-Brush $script:C.Panel
  $card.BorderBrush = New-Brush $script:C.Line
  $card.BorderThickness = New-Object Windows.Thickness 1
  $card.Padding = New-Object Windows.Thickness 12,7,12,7
  $card.Margin = New-Object Windows.Thickness 0,0,8,0
  $stack = New-Object Windows.Controls.StackPanel
  $stack.HorizontalAlignment = 'Stretch'
  $header = New-Object Windows.Controls.Grid
  $header.Height = 18
  $title = New-Text 'FPS' $script:C.TextMut 10 -Mono
  $title.FontWeight = 'Bold'
  $title.HorizontalAlignment = 'Center'
  $historyButton = New-MetricHistoryButton 'fps' 'FPS'
  [void]$header.Children.Add($title); [void]$header.Children.Add($historyButton)
  [void]$stack.Children.Add($header)
  $readout = New-Object Windows.Controls.StackPanel
  $readout.Orientation = 'Horizontal'; $readout.Margin = New-Object Windows.Thickness 0,1,0,0
  $readout.HorizontalAlignment = 'Center'
  $valueText = New-Text '--' $script:C.Green 25 -Mono
  $valueText.FontWeight = 'Bold'
  $unitText = New-Text '帧' $script:C.TextMut 9 -Mono
  $unitText.Margin = New-Object Windows.Thickness 5,0,0,3
  $unitText.VerticalAlignment = 'Bottom'
  [void]$readout.Children.Add($valueText); [void]$readout.Children.Add($unitText)
  [void]$stack.Children.Add($readout)
  $subText = New-Text '游戏未运行' $script:C.TextMut 8 -Mono
  $subText.HorizontalAlignment = 'Center'
  [void]$stack.Children.Add($subText)
  $compareText = New-Text '暂无可比记录' $script:C.TextMut 8 -Mono
  $compareText.HorizontalAlignment = 'Center'
  $compareText.Margin = New-Object Windows.Thickness 0,1,0,0
  [void]$stack.Children.Add($compareText)
  $card.Child = $stack
  $script:MetricGauges['fps'] = [pscustomobject]@{
    TitleText=$title;HistoryButton=$historyButton;ValueText=$valueText;SubText=$subText
    CompareText=$compareText;Maximum=240.0;Kind='number'
  }
  $card
}

function New-LiveMetricGauge([string]$Key, [string]$Label, [string]$Unit, [double]$Maximum) {
  $card = New-Object Windows.Controls.Border
  $card.Background = New-Brush $script:C.Panel
  $card.BorderBrush = New-Brush $script:C.Line
  $card.BorderThickness = New-Object Windows.Thickness 1
  $card.Padding = New-Object Windows.Thickness 5,6,5,5
  $card.Margin = New-Object Windows.Thickness 0,0,6,0

  $stack = New-Object Windows.Controls.StackPanel
  $header = New-Object Windows.Controls.Grid
  $header.Height = 18
  $title = New-Text $Label $script:C.TextPri 10
  $title.FontWeight = 'Bold'
  $title.HorizontalAlignment = 'Center'
  $historyButton = New-MetricHistoryButton $Key $Label
  [void]$header.Children.Add($title); [void]$header.Children.Add($historyButton)
  [void]$stack.Children.Add($header)

  $ring = New-Object Windows.Controls.Grid
  $ring.Width = 64; $ring.Height = 64
  $ring.Margin = New-Object Windows.Thickness 0,4,0,2
  $track = New-Object Windows.Shapes.Ellipse
  $track.Width = 56; $track.Height = 56
  $track.Stroke = New-Brush $script:C.LineHi
  $track.StrokeThickness = 5
  $track.HorizontalAlignment = 'Center'; $track.VerticalAlignment = 'Center'
  [void]$ring.Children.Add($track)

  $arc = New-Object Windows.Shapes.Path
  $arc.Width = 64; $arc.Height = 64
  $arc.Stroke = New-Brush $script:C.Green
  $arc.StrokeThickness = 5
  $arc.StrokeStartLineCap = 'Round'; $arc.StrokeEndLineCap = 'Round'
  $arc.HorizontalAlignment = 'Center'; $arc.VerticalAlignment = 'Center'
  [void]$ring.Children.Add($arc)

  $readout = New-Object Windows.Controls.StackPanel
  $readout.Orientation = 'Horizontal'
  $readout.HorizontalAlignment = 'Center'; $readout.VerticalAlignment = 'Center'
  $valueText = New-Text '--' $script:C.TextPri 14 -Mono
  $valueText.FontWeight = 'Bold'; $valueText.HorizontalAlignment = 'Center'
  $unitText = New-Text $Unit $script:C.TextPri 14 -Mono
  $unitText.FontWeight = 'Bold'
  $unitText.HorizontalAlignment = 'Center'; $unitText.Margin = New-Object Windows.Thickness 1,0,0,0
  [void]$readout.Children.Add($valueText); [void]$readout.Children.Add($unitText)
  [void]$ring.Children.Add($readout); [void]$stack.Children.Add($ring)

  $subText = New-Text '等待采样' $script:C.TextMut 8 -Mono
  $subText.HorizontalAlignment = 'Center'; $subText.TextTrimming = 'CharacterEllipsis'
  [void]$stack.Children.Add($subText)
  $compareText = New-Text '暂无可比记录' $script:C.TextMut 8 -Mono
  $compareText.HorizontalAlignment = 'Center'; $compareText.TextTrimming = 'CharacterEllipsis'
  $compareText.Margin = New-Object Windows.Thickness 0,1,0,0
  [void]$stack.Children.Add($compareText)
  $card.Child = $stack
  $script:MetricGauges[$Key] = [pscustomobject]@{
    TitleText=$title;HistoryButton=$historyButton;Arc=$arc;Track=$track;ValueText=$valueText;UnitText=$unitText
    SubText=$subText;CompareText=$compareText;Maximum=$Maximum;Kind='ring'
  }
  $card
}

function Set-LiveMetricGauge([string]$Key, $Value, [string]$SubText, [string]$ColorHex) {
  $gauge = $script:MetricGauges[$Key]
  if (-not $gauge) { return }
  $gauge.SubText.Text = $SubText
  if ($gauge.Kind -eq 'number') {
    $gauge.ValueText.Text = $(if ($null -eq $Value) { '--' } elseif ([math]::Abs([double]$Value-[math]::Round([double]$Value)) -lt 0.05) {
      "{0:N0}" -f [double]$Value
    } else { "{0:N1}" -f [double]$Value })
    return
  }
  if ($null -eq $Value) {
    $gauge.ValueText.Text = '--'
    $gauge.Arc.Visibility = 'Collapsed'
    return
  }
  $number = [math]::Max(0.0,[double]$Value)
  $gauge.ValueText.Text = $(if ([math]::Abs($number-[math]::Round($number)) -lt 0.05) {
    "{0:N0}" -f $number
  } else { "{0:N1}" -f $number })
  $gauge.Arc.Stroke = New-Brush $ColorHex
  $gauge.Arc.Visibility = 'Visible'
  $fraction = [math]::Min(0.99999,[math]::Max(0.002,$number/[math]::Max(1.0,[double]$gauge.Maximum)))
  $angle = 360.0*$fraction; $radians = $angle*[math]::PI/180.0
  $cx = 32.0; $cy = 32.0; $radius = 25.5
  $figure = New-Object Windows.Media.PathFigure
  $figure.StartPoint = New-Object Windows.Point $cx,($cy-$radius)
  $segment = New-Object Windows.Media.ArcSegment
  $segment.Point = New-Object Windows.Point ($cx+$radius*[math]::Sin($radians)),($cy-$radius*[math]::Cos($radians))
  $segment.Size = New-Object Windows.Size $radius,$radius
  $segment.IsLargeArc = ($angle -gt 180.0)
  $segment.SweepDirection = 'Clockwise'
  [void]$figure.Segments.Add($segment)
  $geometry = New-Object Windows.Media.PathGeometry
  [void]$geometry.Figures.Add($figure)
  $gauge.Arc.Data = $geometry
}

function Set-LiveMetricComparison {
  param(
    [string]$Key,
    $Before,
    $After,
    [ValidateSet('percent','points')][string]$Mode = 'points',
    [string]$Prefix = '变化',
    [string]$Tooltip = '',
    [string]$EmptyText = '暂无可比记录'
  )
  $gauge = $script:MetricGauges[$Key]
  if (-not $gauge -or -not $gauge.CompareText) { return }
  $gauge.CompareText.ToolTip = $Tooltip
  if ($null -eq $Before -or $null -eq $After) {
    $gauge.CompareText.Text = $EmptyText
    $gauge.CompareText.Foreground = New-Brush $script:C.TextMut
    return
  }
  $beforeNumber = [double]$Before; $afterNumber = [double]$After
  if ([double]::IsNaN($beforeNumber) -or [double]::IsInfinity($beforeNumber) -or
      [double]::IsNaN($afterNumber) -or [double]::IsInfinity($afterNumber) -or
      ($Mode -eq 'percent' -and $beforeNumber -le 0)) {
    $gauge.CompareText.Text = $EmptyText
    $gauge.CompareText.Foreground = New-Brush $script:C.TextMut
    return
  }
  $delta = $(if ($Mode -eq 'percent') { ($afterNumber-$beforeNumber)*100.0/$beforeNumber } else { $afterNumber-$beforeNumber })
  $sign = $(if ($delta -gt 0.05) { '+' } else { '' })
  $unit = $(if ($Mode -eq 'percent') { '%' } else { '点' })
  $gauge.CompareText.Text = "$Prefix $sign$('{0:N1}' -f $delta)$unit"
  $gauge.CompareText.Foreground = $(if ($Key -eq 'fps' -and $delta -gt 0.05) { New-Brush $script:C.Green }
    elseif ($Key -eq 'fps' -and $delta -lt -0.05) { New-Brush $script:C.Danger }
    else { New-Brush $script:C.Gold })
}

function Set-HardwareTemperature([string]$Key, $Value, [string]$Source = '', [string]$UnavailableReason = '') {
  $readout = $script:HardwareTemperatureReadouts[$Key]
  if (-not $readout) { return }
  if ($null -eq $Value) {
    $readout.ValueText.Text = 'N/A'
    $readout.UnitText.Text = ''
    $readout.ValueText.Foreground = New-Brush $script:C.TextMut
    $readout.UnitText.Foreground = New-Brush $script:C.TextMut
    $readout.Container.ToolTip = $(if ($UnavailableReason) { $UnavailableReason } else { '当前没有可用的温度数据' })
    $readout.Container.Cursor = [Windows.Input.Cursors]::Help
    return
  }
  $temperature = [double]$Value
  $readout.UnitText.Text = '°C'
  $readout.ValueText.Text = $(if ([math]::Abs($temperature-[math]::Round($temperature)) -lt 0.05) {
    "{0:N0}" -f $temperature
  } else { "{0:N1}" -f $temperature })
  $temperatureBrush = New-Brush (Get-TemperatureColor $temperature)
  $readout.ValueText.Foreground = $temperatureBrush
  $readout.UnitText.Foreground = $temperatureBrush
  $readout.Container.ToolTip = $(if ($Source) { "数据源：$Source" } else { '实时传感器温度' })
  $readout.Container.Cursor = [Windows.Input.Cursors]::Arrow
}

function Get-TemperatureColor([double]$Temperature) {
  if ($Temperature -le 55) { return $script:C.Green }
  if ($Temperature -le 75) {
    $p = ($Temperature-55.0)/20.0
    $r = [int][math]::Round(0+(229*$p)); $g = [int][math]::Round(200+(196-200)*$p); $b = [int][math]::Round(120+(106-120)*$p)
    return ('#FF{0:X2}{1:X2}{2:X2}' -f $r,$g,$b)
  }
  $p = [math]::Min(1.0,($Temperature-75.0)/20.0)
  $r = [int][math]::Round(229+(0*$p)); $g = [int][math]::Round(196+(72-196)*$p); $b = [int][math]::Round(106+(77-106)*$p)
  ('#FF{0:X2}{1:X2}{2:X2}' -f $r,$g,$b)
}

function Initialize-LiveMetricsDashboard {
  if (-not $ui.MetricsGrid -or $ui.MetricsGrid.Children.Count -gt 0) { return }
  $ui.MetricsGrid.ColumnDefinitions.Clear()
  $fpsColumn = New-Object Windows.Controls.ColumnDefinition
  $fpsColumn.Width = New-Object Windows.GridLength 126
  [void]$ui.MetricsGrid.ColumnDefinitions.Add($fpsColumn)
  foreach ($index in 0..2) {
    $column = New-Object Windows.Controls.ColumnDefinition
    $column.Width = [Windows.GridLength]::new(1.0,[Windows.GridUnitType]::Star)
    [void]$ui.MetricsGrid.ColumnDefinitions.Add($column)
  }
  $fpsCard = New-FpsMetricCard
  [Windows.Controls.Grid]::SetColumn($fpsCard,0)
  [void]$ui.MetricsGrid.Children.Add($fpsCard)
  $columnIndex = 1
  foreach ($definition in @(
    @('cpu','CPU 占用','%',100),@('gpu','GPU 占用','%',100),@('memory','内存占用','%',100)
  )) {
    $gauge = New-LiveMetricGauge $definition[0] $definition[1] $definition[2] ([double]$definition[3])
    [Windows.Controls.Grid]::SetColumn($gauge,$columnIndex++)
    [void]$ui.MetricsGrid.Children.Add($gauge)
  }
}

function Resolve-DisplayClassLabel([int]$Width, [int]$Height) {
  $long = [math]::Max($Width,$Height); $short = [math]::Min($Width,$Height)
  if ($long -eq 1920 -and $short -eq 1080) { return '1K' }
  if ($long -eq 2560 -and $short -eq 1440) { return '2K' }
  if ($long -eq 3840 -and $short -eq 2160) { return '4K' }
  if ($Width -gt 0 -and $Height -gt 0) { return "$Width × $Height" }
  '分辨率未知'
}

function Initialize-LiveMetricsTypes {
  if ('DfbLivePresentMonSampler' -as [type]) { return }
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;

public sealed class DfbLivePresentMonSampler : IDisposable {
  private sealed class FramePoint {
    public long Ticks;
    public string SwapChain;
    public double DisplayMilliseconds;
    public double PresentMilliseconds;
  }
  private sealed class FrameSummary {
    public int DisplayCount;
    public double DisplayTotalMilliseconds;
    public int PresentCount;
    public double PresentTotalMilliseconds;
  }
  private readonly object gate = new object();
  private readonly Queue<FramePoint> frames = new Queue<FramePoint>();
  private Process process;
  private int displayColumn = -1;
  private int presentColumn = -1;
  private int swapChainColumn = -1;
  private bool headerReady;
  private string metricLabel = "";

  private static string[] SplitCsv(string line) {
    var fields = new List<string>();
    var value = new System.Text.StringBuilder();
    bool quoted = false;
    for (int i = 0; i < line.Length; i++) {
      char c = line[i];
      if (c == '"') {
        if (quoted && i + 1 < line.Length && line[i + 1] == '"') { value.Append('"'); i++; }
        else { quoted = !quoted; }
      } else if (c == ',' && !quoted) { fields.Add(value.ToString()); value.Length = 0; }
      else { value.Append(c); }
    }
    fields.Add(value.ToString());
    return fields.ToArray();
  }

  private static int FindColumn(string[] fields, params string[] names) {
    for (int i = 0; i < fields.Length; i++) {
      foreach (string name in names) {
        if (String.Equals(fields[i].Trim(), name, StringComparison.OrdinalIgnoreCase)) return i;
      }
    }
    return -1;
  }

  public void AcceptCsvLine(string line) {
    if (String.IsNullOrWhiteSpace(line)) return;
    string[] fields = SplitCsv(line);
    lock (gate) {
      if (!headerReady) {
        // PresentMon 的 DisplayedTime 才是实际屏幕换帧间隔。FrameTime/
        // MsBetweenPresents 只是应用调用 Present 的速率，在 DLSS/AFMF 帧生成、
        // 丢帧或合成器介入时会和用户看到的 FPS 不一致。
        displayColumn = FindColumn(fields, "DisplayedTime");
        if (displayColumn < 0) displayColumn = FindColumn(fields, "MsBetweenDisplayChange");
        presentColumn = FindColumn(fields, "FrameTime", "MsBetweenPresents");
        swapChainColumn = FindColumn(fields, "SwapChainAddress");
        headerReady = displayColumn >= 0 || presentColumn >= 0;
        return;
      }
      double displayMilliseconds = Double.NaN;
      double presentMilliseconds = Double.NaN;
      if (displayColumn >= 0 && displayColumn < fields.Length) {
        double parsed;
        if (Double.TryParse(fields[displayColumn], NumberStyles.Float, CultureInfo.InvariantCulture, out parsed) &&
            parsed > 0.0 && parsed <= 1000.0) displayMilliseconds = parsed;
      }
      if (presentColumn >= 0 && presentColumn < fields.Length) {
        double parsed;
        if (Double.TryParse(fields[presentColumn], NumberStyles.Float, CultureInfo.InvariantCulture, out parsed) &&
            parsed > 0.0 && parsed <= 1000.0) presentMilliseconds = parsed;
      }
      if (Double.IsNaN(displayMilliseconds) && Double.IsNaN(presentMilliseconds)) return;
      string swapChain = swapChainColumn >= 0 && swapChainColumn < fields.Length ? fields[swapChainColumn].Trim() : "";
      if (String.IsNullOrEmpty(swapChain)) swapChain = "__default__";
      frames.Enqueue(new FramePoint {
        Ticks = DateTime.UtcNow.Ticks,
        SwapChain = swapChain,
        DisplayMilliseconds = displayMilliseconds,
        PresentMilliseconds = presentMilliseconds
      });
      Trim(DateTime.UtcNow.AddSeconds(-3).Ticks);
    }
  }

  private void OnOutput(object sender, DataReceivedEventArgs e) {
    // Stop/重启采样器时旧 PresentMon 仍可能补发最后几行；这些行不得混入
    // 新游戏进程或新交换链的滚动窗口。
    if (e != null && Object.ReferenceEquals(sender, process)) AcceptCsvLine(e.Data);
  }

  private void Trim(long cutoff) {
    while (frames.Count > 0 && frames.Peek().Ticks < cutoff) frames.Dequeue();
  }

  public bool Start(string executable, int processId, string sessionName) {
    Stop();
    try {
      var info = new ProcessStartInfo();
      info.FileName = executable;
      info.WorkingDirectory = Environment.SystemDirectory;
      info.Arguments = "--process_id " + processId.ToString(CultureInfo.InvariantCulture) +
        " --output_stdout --no_console_stats --v2_metrics --terminate_on_proc_exit --session_name " + sessionName;
      info.UseShellExecute = false;
      info.CreateNoWindow = true;
      info.RedirectStandardOutput = true;
      info.RedirectStandardError = true;
      process = new Process();
      process.StartInfo = info;
      process.OutputDataReceived += OnOutput;
      process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs args) { };
      if (!process.Start()) { Stop(); return false; }
      process.BeginOutputReadLine();
      process.BeginErrorReadLine();
      return true;
    } catch { Stop(); return false; }
  }

  public bool IsRunning {
    get {
      try { return process != null && !process.HasExited; }
      catch { return false; }
    }
  }

  public double ReadFps() {
    lock (gate) {
      Trim(DateTime.UtcNow.AddSeconds(-2.5).Ticks);
      if (frames.Count < 5) return Double.NaN;
      // 游戏、启动视频和 UI 可能各自拥有交换链。把它们混在一起平均会制造
      // 不存在的 FPS；以窗口内有效显示帧最多的交换链作为主游戏交换链。
      var summaries = new Dictionary<string, FrameSummary>(StringComparer.OrdinalIgnoreCase);
      foreach (FramePoint frame in frames) {
        FrameSummary summary;
        if (!summaries.TryGetValue(frame.SwapChain, out summary)) {
          summary = new FrameSummary();
          summaries.Add(frame.SwapChain, summary);
        }
        if (!Double.IsNaN(frame.DisplayMilliseconds)) {
          summary.DisplayCount++;
          summary.DisplayTotalMilliseconds += frame.DisplayMilliseconds;
        }
        if (!Double.IsNaN(frame.PresentMilliseconds)) {
          summary.PresentCount++;
          summary.PresentTotalMilliseconds += frame.PresentMilliseconds;
        }
      }
      FrameSummary primary = null;
      bool useDisplay = false;
      foreach (FrameSummary summary in summaries.Values) {
        if (summary.DisplayCount >= 5 && (primary == null || !useDisplay || summary.DisplayCount > primary.DisplayCount)) {
          primary = summary;
          useDisplay = true;
        }
      }
      if (!useDisplay) {
        primary = null;
        foreach (FrameSummary summary in summaries.Values) {
          if (summary.PresentCount >= 5 && (primary == null || summary.PresentCount > primary.PresentCount)) primary = summary;
        }
      }
      if (primary == null) return Double.NaN;
      metricLabel = useDisplay ? "显示帧率" : "呈现帧率";
      int count = useDisplay ? primary.DisplayCount : primary.PresentCount;
      double total = useDisplay ? primary.DisplayTotalMilliseconds : primary.PresentTotalMilliseconds;
      return count >= 5 && total > 0.0 ? Math.Round(1000.0 / (total / count), 1) : Double.NaN;
    }
  }

  public string MetricLabel {
    get { lock (gate) { return metricLabel; } }
  }

  public void Stop() {
    Process old = process;
    process = null;
    lock (gate) {
      frames.Clear();
      displayColumn = -1;
      presentColumn = -1;
      swapChainColumn = -1;
      headerReady = false;
      metricLabel = "";
    }
    if (old == null) return;
    try { if (!old.HasExited) old.Kill(); } catch { }
    try { old.WaitForExit(1500); } catch { }
    try { old.Dispose(); } catch { }
  }

  public void Dispose() { Stop(); }
}

public sealed class DfbProcessorUtilitySampler : IDisposable {
  private const uint PdhFmtDouble = 0x00000200;
  private IntPtr query;
  private IntPtr counter;
  private IntPtr valueBuffer;
  private bool primed;

  [DllImport("pdh.dll")] private static extern uint PdhOpenQuery(IntPtr dataSource, IntPtr userData, out IntPtr query);
  [DllImport("pdh.dll", CharSet=CharSet.Unicode, EntryPoint="PdhAddEnglishCounterW")]
  private static extern uint PdhAddEnglishCounter(IntPtr query, string path, IntPtr userData, out IntPtr counter);
  [DllImport("pdh.dll")] private static extern uint PdhCollectQueryData(IntPtr query);
  [DllImport("pdh.dll")] private static extern uint PdhGetFormattedCounterValue(IntPtr counter, uint format, out uint type, IntPtr value);
  [DllImport("pdh.dll")] private static extern uint PdhCloseQuery(IntPtr query);

  public DfbProcessorUtilitySampler() {
    try {
      if (PdhOpenQuery(IntPtr.Zero, IntPtr.Zero, out query) != 0 || query == IntPtr.Zero) return;
      if (PdhAddEnglishCounter(query, @"\Processor Information(_Total)\% Processor Utility", IntPtr.Zero, out counter) != 0 || counter == IntPtr.Zero) {
        Dispose();
        return;
      }
      valueBuffer = Marshal.AllocHGlobal(16);
      primed = PdhCollectQueryData(query) == 0;
    } catch { Dispose(); }
  }

  public double Read() {
    if (!primed || query == IntPtr.Zero || counter == IntPtr.Zero || valueBuffer == IntPtr.Zero) return Double.NaN;
    if (PdhCollectQueryData(query) != 0) return Double.NaN;
    uint type;
    if (PdhGetFormattedCounterValue(counter, PdhFmtDouble, out type, valueBuffer) != 0) return Double.NaN;
    uint status = unchecked((uint)Marshal.ReadInt32(valueBuffer));
    if (status != 0 && status != 1) return Double.NaN;
    byte[] bytes = new byte[8];
    Marshal.Copy(IntPtr.Add(valueBuffer, IntPtr.Size == 8 ? 8 : 4), bytes, 0, bytes.Length);
    double value = BitConverter.ToDouble(bytes, 0);
    if (Double.IsNaN(value) || Double.IsInfinity(value)) return Double.NaN;
    return Math.Round(Math.Max(0.0, Math.Min(100.0, value)), 1);
  }

  public void Dispose() {
    IntPtr oldBuffer = valueBuffer;
    IntPtr oldQuery = query;
    valueBuffer = IntPtr.Zero;
    query = IntPtr.Zero;
    counter = IntPtr.Zero;
    primed = false;
    if (oldBuffer != IntPtr.Zero) Marshal.FreeHGlobal(oldBuffer);
    if (oldQuery != IntPtr.Zero) PdhCloseQuery(oldQuery);
  }
}

public static class DfbLiveSystemMetrics {
  [StructLayout(LayoutKind.Sequential)] private struct FILETIME { public uint Low; public uint High; }
  [StructLayout(LayoutKind.Sequential)] private sealed class MEMORYSTATUSEX {
    public uint Length = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
    public uint MemoryLoad;
    public ulong TotalPhys, AvailPhys, TotalPageFile, AvailPageFile, TotalVirtual, AvailVirtual, AvailExtendedVirtual;
  }
  [DllImport("kernel32.dll", SetLastError=true)] private static extern bool GetSystemTimes(out FILETIME idle, out FILETIME kernel, out FILETIME user);
  [DllImport("kernel32.dll", SetLastError=true)] private static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX value);
  private static readonly object Gate = new object();
  private static ulong lastIdle, lastKernel, lastUser;
  private static bool initialized;
  private static ulong ToUInt64(FILETIME value) { return ((ulong)value.High << 32) | value.Low; }

  public static double ReadCpuUsage() {
    FILETIME idle, kernel, user;
    if (!GetSystemTimes(out idle, out kernel, out user)) return Double.NaN;
    ulong i = ToUInt64(idle), k = ToUInt64(kernel), u = ToUInt64(user);
    lock (Gate) {
      if (!initialized) { initialized = true; lastIdle = i; lastKernel = k; lastUser = u; return Double.NaN; }
      ulong idleDelta = i - lastIdle, kernelDelta = k - lastKernel, userDelta = u - lastUser;
      lastIdle = i; lastKernel = k; lastUser = u;
      ulong total = kernelDelta + userDelta;
      if (total == 0) return Double.NaN;
      double usage = (double)(total - Math.Min(total, idleDelta)) * 100.0 / total;
      return Math.Max(0.0, Math.Min(100.0, Math.Round(usage, 1)));
    }
  }

  public static double ReadMemoryUsage() {
    var value = new MEMORYSTATUSEX();
    return GlobalMemoryStatusEx(value) ? (double)value.MemoryLoad : Double.NaN;
  }
}
'@
}

$script:LiveMetricsWorker = {
  param($State,[string]$PresentMon,[string]$NvidiaSmi,[string]$GpuVendor,[string]$GpuPciLocation,
    [string]$HardwareSensorScript,[string]$HardwareSensorLibraryDir)
  $ErrorActionPreference = 'SilentlyContinue'

  function Get-OptionalSensorTemperatures {
    $cpu = $null; $gpu = $null; $cpuSource = ''; $gpuSource = ''; $providerSeen = $false; $bundledReadError = ''
    if ($sensorComputer) {
      $providerSeen = $true
      try {
        $bundled = Get-DfbHardwareTemperatures $sensorComputer
        if ($null -ne $bundled.Cpu) {
          $cpu = $bundled.Cpu
          $cpuSource = "内置硬件传感器（LibreHardwareMonitor / PawnIO · $($bundled.CpuSensor)）"
        }
        if ($null -ne $bundled.Gpu) {
          $gpu = $bundled.Gpu
          $gpuSource = "内置硬件传感器（LibreHardwareMonitor / PawnIO · $($bundled.GpuSensor)）"
        }
      } catch { $bundledReadError = $_.Exception.Message }
    }
    foreach ($namespace in 'root\LibreHardwareMonitor','root\OpenHardwareMonitor') {
      if ($null -ne $cpu -and $null -ne $gpu) { break }
      try {
        $sensors = @(Get-CimInstance -Namespace $namespace -ClassName Sensor -ErrorAction Stop |
          Where-Object { "$($_.SensorType)" -eq 'Temperature' -and $null -ne $_.Value })
        $providerSeen = $true
        $providerName = $(if ($namespace -match 'Libre') { 'LibreHardwareMonitor' } else { 'OpenHardwareMonitor' })
        $cpuValues = @($sensors | Where-Object { "$($_.Name)" -match '(?i)CPU Package|CPU Core|Core Max|Tctl|Tdie' } |
          ForEach-Object { [double]$_.Value } | Where-Object { $_ -ge 10 -and $_ -le 125 })
        $gpuValues = @($sensors | Where-Object { "$($_.Name)" -match '(?i)GPU Core|GPU Temperature' } |
          ForEach-Object { [double]$_.Value } | Where-Object { $_ -ge 10 -and $_ -le 125 })
        if ($null -eq $cpu -and $cpuValues.Count) {
          $cpu = [math]::Round(($cpuValues | Measure-Object -Maximum).Maximum,1); $cpuSource = $providerName
        }
        if ($null -eq $gpu -and $gpuValues.Count) {
          $gpu = [math]::Round(($gpuValues | Measure-Object -Maximum).Maximum,1); $gpuSource = $providerName
        }
        if ($null -ne $cpu -and $null -ne $gpu) { break }
      } catch {}
    }
    $cpuStatus = $(if ($null -ne $cpu) { '' } elseif ($bundledReadError) {
      "内置硬件传感器读取失败：$bundledReadError"
    } elseif ($sensorInitializationError) {
      "内置硬件传感器初始化失败：$sensorInitializationError"
    } elseif ($providerSeen) {
      '内置硬件传感器已启动，但没有上报可信的 CPU 封装温度；请确认 PawnIO 驱动正常并重启软件'
    } else {
      '未检测到可用的硬件温度源'
    })
    $gpuStatus = $(if ($null -ne $gpu) { '' } elseif ($bundledReadError) {
      "内置硬件传感器读取失败：$bundledReadError"
    } elseif ($sensorInitializationError) {
      "内置硬件传感器初始化失败：$sensorInitializationError"
    } else { '硬件传感器与显卡驱动均未上报可信的 GPU 温度' })
    [pscustomobject]@{Cpu=$cpu;Gpu=$gpu;CpuSource=$cpuSource;GpuSource=$gpuSource;CpuStatus=$cpuStatus;GpuStatus=$gpuStatus}
  }

  function Get-WindowsGpuUsage {
    try {
      $engines = @((Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop).CounterSamples |
        Where-Object { "$($_.InstanceName)" -match '(?i)engtype_3D' })
      $totals = @{}
      foreach ($sample in $engines) {
        $instance = "$($sample.InstanceName)"
        if ($instance -match '(?i)(luid_0x[0-9a-f]+_0x[0-9a-f]+).*?(eng_[0-9]+)_engtype_3D') {
          $key = "$($Matches[1])|$($Matches[2])"
          if (-not $totals.ContainsKey($key)) { $totals[$key] = 0.0 }
          $totals[$key] += [double]$sample.CookedValue
        }
      }
      if ($totals.Count) { return [math]::Round([math]::Min(100.0,($totals.Values | Measure-Object -Maximum).Maximum),1) }
    } catch {}
    $null
  }

  function Get-NvidiaSnapshot {
    if (-not $NvidiaSmi -or -not (Test-Path -LiteralPath $NvidiaSmi -PathType Leaf)) { return $null }
    try {
      $raw = @(& $NvidiaSmi '--query-gpu=pci.bus_id,utilization.gpu,temperature.gpu' '--format=csv,noheader,nounits' 2>$null)
      if ($LASTEXITCODE -ne 0 -or -not $raw.Count) { return $null }
      $row = $null
      foreach ($line in $raw) {
        $parts = @("$line" -split ',' | ForEach-Object { $_.Trim() })
        if ($parts.Count -lt 3 -or $parts[0] -notmatch '(?:[0-9A-Fa-f]{4,8}:)?([0-9A-Fa-f]{2}):([0-9A-Fa-f]{2})\.([0-7])$') { continue }
        $key = ('{0}:{1}:{2}' -f [Convert]::ToUInt32($Matches[1],16),[Convert]::ToUInt32($Matches[2],16),[Convert]::ToUInt32($Matches[3],16))
        if ($GpuPciLocation -and $key -eq $GpuPciLocation) { $row = $parts; break }
      }
      if (-not $row -and -not $GpuPciLocation -and $raw.Count -eq 1) { $row = @("$($raw[0])" -split ',' | ForEach-Object { $_.Trim() }) }
      if ($row -and $row.Count -ge 3) {
        $util = 0.0; $temp = 0.0
        $okUtil = [double]::TryParse("$($row[1])",[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$util)
        $okTemp = [double]::TryParse("$($row[2])",[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$temp)
        return [pscustomobject]@{Usage=$(if($okUtil){[math]::Min(100.0,[math]::Max(0.0,$util))}else{$null});Temperature=$(if($okTemp -and $temp -ge 10 -and $temp -le 125){$temp}else{$null})}
      }
    } catch {}
    $null
  }

  $sampler = $null; $cpuSampler = $null; $sensorComputer = $null; $sensorInitializationError = ''; $gamePid = 0
  $nextHardware = [DateTime]::MinValue; $nextProcess = [DateTime]::MinValue
  try {
    try {
      if (-not $HardwareSensorScript -or -not (Test-Path -LiteralPath $HardwareSensorScript -PathType Leaf)) {
        throw 'hardware-sensors.ps1 缺失'
      }
      . $HardwareSensorScript
      $sensorComputer = Open-DfbHardwareMonitor $HardwareSensorLibraryDir
    } catch { $sensorInitializationError = $_.Exception.Message }
    $sampler = New-Object DfbLivePresentMonSampler
    $cpuSampler = New-Object DfbProcessorUtilitySampler
    while (-not [bool]$State.Stop) {
      $now = [DateTime]::UtcNow
      if ($now -ge $nextHardware) {
        $nextHardware = $now.AddSeconds(2)
        $cpuUsage = $cpuSampler.Read()
        if ([double]::IsNaN($cpuUsage)) { $cpuUsage = [DfbLiveSystemMetrics]::ReadCpuUsage() }
        $memoryUsage = [DfbLiveSystemMetrics]::ReadMemoryUsage()
        $optional = Get-OptionalSensorTemperatures
        $cpuTemp = $optional.Cpu; $cpuSource = $optional.CpuSource
        $gpuUsage = $null; $gpuTemp = $optional.Gpu; $gpuSource = $optional.GpuSource; $gpuStatus = $optional.GpuStatus
        if ($GpuVendor -eq 'NVIDIA') {
          $nvidia = Get-NvidiaSnapshot
          if ($nvidia) {
            $gpuUsage = $nvidia.Usage
            if ($null -ne $nvidia.Temperature) { $gpuTemp = $nvidia.Temperature; $gpuSource = 'NVIDIA 驱动'; $gpuStatus = '' }
          }
        }
        if ($null -eq $gpuUsage) { $gpuUsage = Get-WindowsGpuUsage }
        $State.CpuUsage = $(if ([double]::IsNaN($cpuUsage)) { $null } else { [math]::Round($cpuUsage,1) })
        $State.MemoryUsage = $(if ([double]::IsNaN($memoryUsage)) { $null } else { [math]::Round($memoryUsage,1) })
        $State.CpuTemperature = $cpuTemp; $State.CpuTemperatureSource = $cpuSource; $State.CpuTemperatureStatus = $optional.CpuStatus
        $State.GpuUsage = $gpuUsage; $State.GpuTemperature = $gpuTemp; $State.GpuTemperatureSource = $gpuSource; $State.GpuTemperatureStatus = $gpuStatus
        $State.SampledAt = $now
      }

      if ($now -ge $nextProcess) {
        $nextProcess = $now.AddSeconds(1)
        $games = @()
        foreach ($name in 'DeltaForceClient-Win64-Shipping','DeltaForceClient','DeltaForce') {
          $games += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        }
        $game = @($games | Sort-Object Id -Descending | Select-Object -First 1)
        $newPid = $(if ($game.Count) { [int]$game[0].Id } else { 0 })
        if ($newPid -ne $gamePid) {
          $sampler.Stop(); $gamePid = $newPid; $State.Fps = $null
          if ($gamePid -gt 0 -and $PresentMon -and (Test-Path -LiteralPath $PresentMon -PathType Leaf)) {
            $session = "DFB-LIVE-$gamePid-$([guid]::NewGuid().ToString('N'))"
            $State.FpsStatus = $(if ($sampler.Start($PresentMon,$gamePid,$session)) { '采样中' } else { '采样不可用' })
          } else { $State.FpsStatus = $(if ($gamePid -gt 0) { '组件缺失' } else { '游戏未运行' }) }
        }
        $State.GameRunning = [bool]($gamePid -gt 0)
      }

      if ($gamePid -gt 0 -and $sampler.IsRunning) {
        $fps = $sampler.ReadFps()
        if (-not [double]::IsNaN($fps) -and $fps -gt 0) {
          $State.Fps = $fps
          $State.FpsStatus = $(if ($sampler.MetricLabel) { $sampler.MetricLabel } else { '实时帧率' })
        } else {
          # 交换链停止出帧（最小化、切换场景或退出渲染）后立即清掉旧值，
          # 避免把最后一次采样误当成仍在变化的实时 FPS。
          $State.Fps = $null
          $State.FpsStatus = '等待有效帧'
        }
      } elseif ($gamePid -gt 0) { $State.Fps = $null; $State.FpsStatus = '采样不可用' }
      Start-Sleep -Milliseconds 400
    }
  } finally {
    if ($sampler) { $sampler.Dispose() }
    if ($cpuSampler) { $cpuSampler.Dispose() }
    if ($sensorComputer -and (Get-Command Close-DfbHardwareMonitor -ErrorAction SilentlyContinue)) { Close-DfbHardwareMonitor $sensorComputer }
  }
}

function Update-LiveMetricsDashboard {
  if (-not $script:LiveMetricsState) { return }
  $state = $script:LiveMetricsState
  Set-LiveMetricGauge 'fps' $state.Fps "$($state.FpsStatus)" $script:C.Green
  Set-LiveMetricGauge 'cpu' $state.CpuUsage '处理器效用' $script:C.Green
  Set-HardwareTemperature 'cpu' $state.CpuTemperature "$($state.CpuTemperatureSource)" "$($state.CpuTemperatureStatus)"
  Set-LiveMetricGauge 'gpu' $state.GpuUsage '实时占用' $script:C.Green
  Set-HardwareTemperature 'gpu' $state.GpuTemperature "$($state.GpuTemperatureSource)" "$($state.GpuTemperatureStatus)"
  Set-LiveMetricGauge 'memory' $state.MemoryUsage '实时占用' $script:C.Gold
}

function Start-LiveMetricsMonitor($Hw) {
  Stop-LiveMetricsMonitor
  Initialize-LiveMetricsDashboard
  Initialize-LiveMetricsTypes
  if ($script:MetricGauges['fps'] -and [int]$Hw.DisplayRefreshHz -ge 60) {
    $script:MetricGauges['fps'].Maximum = [math]::Min(500,[math]::Max(120,[int]$Hw.DisplayRefreshHz))
  }
  $script:LiveMetricsState = [hashtable]::Synchronized(@{
    Stop=$false;Fps=$null;FpsStatus='游戏未运行';GameRunning=$false;CpuUsage=$null;CpuTemperature=$null
    CpuTemperatureSource='';CpuTemperatureStatus='正在启动内置硬件传感器';GpuUsage=$null;GpuTemperature=$null;GpuTemperatureSource='';GpuTemperatureStatus='正在启动内置硬件传感器';MemoryUsage=$null
  })
  $presentMon = Join-Path $script:RootDir 'tools\PresentMon.exe'
  $hardwareSensorScript = Join-Path $script:RootDir 'scripts\hardware-sensors.ps1'
  $hardwareSensorLibraryDir = Join-Path $script:RootDir 'tools'
  $nvidiaSmi = $(if (Get-Command Get-NvidiaSmiPath -ErrorAction SilentlyContinue) { Get-NvidiaSmiPath } else { $null })
  $script:LiveMetricsPowerShell = [PowerShell]::Create()
  [void]$script:LiveMetricsPowerShell.AddScript($script:LiveMetricsWorker)
  foreach ($argument in @($script:LiveMetricsState,$presentMon,$nvidiaSmi,"$($Hw.MainGpuVendor)","$($Hw.MainGpuPciLocation)",$hardwareSensorScript,$hardwareSensorLibraryDir)) {
    [void]$script:LiveMetricsPowerShell.AddArgument($argument)
  }
  $script:LiveMetricsAsync = $script:LiveMetricsPowerShell.BeginInvoke()
  $script:LiveMetricsUiTimer = New-Object Windows.Threading.DispatcherTimer
  $script:LiveMetricsUiTimer.Interval = [TimeSpan]::FromSeconds(1)
  $script:LiveMetricsUiTimer.Add_Tick({ Update-LiveMetricsDashboard })
  $script:LiveMetricsUiTimer.Start()
  Update-LiveMetricsDashboard
}

function Stop-LiveMetricsMonitor {
  if ($script:LiveMetricsUiTimer) { $script:LiveMetricsUiTimer.Stop(); $script:LiveMetricsUiTimer = $null }
  if ($script:LiveMetricsState) { $script:LiveMetricsState.Stop = $true }
  if ($script:LiveMetricsPowerShell) {
    try {
      if ($script:LiveMetricsAsync -and -not $script:LiveMetricsAsync.IsCompleted -and
          -not $script:LiveMetricsAsync.AsyncWaitHandle.WaitOne(1200)) { $script:LiveMetricsPowerShell.Stop() }
      if ($script:LiveMetricsAsync -and $script:LiveMetricsAsync.IsCompleted) {
        $script:LiveMetricsPowerShell.EndInvoke($script:LiveMetricsAsync) | Out-Null
      }
    } catch {} finally { try { $script:LiveMetricsPowerShell.Dispose() } catch {} }
  }
  $script:LiveMetricsPowerShell = $null; $script:LiveMetricsAsync = $null; $script:LiveMetricsState = $null
}

function Update-Count {
  $rows = @(@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children))
  $sel = @($rows | Where-Object { $_.Child.Children[0].IsChecked }).Count
  # 「可执行」= 未处于已就绪/正常态的项（行 Tag 存的是检测到的 Optimized 状态）
  $oper = @($rows | Where-Object { $_.Tag -ne $true })
  $ui.CountText.Text = "已选 $sel / $($rows.Count) · 可执行 $($oper.Count)"
  # 全选框只代表允许批量选择的项目；高磁盘/内存影响项仍可手动勾选，但不会被「全选」带上。
  # 程序赋值不触发 Click，不会与点击处理器互相递归。
  if ($ui.SelAllChk) {
    $bulkOper = @($oper | Where-Object { $_.DataContext -and $_.DataContext.BulkSelect })
    $bulkLeft = @($bulkOper | Where-Object { -not $_.Child.Children[0].IsChecked }).Count
    $manualSelected = @($rows | Where-Object {
      $_.DataContext -and -not $_.DataContext.BulkSelect -and $_.Child.Children[0].IsChecked
    }).Count
    $ui.SelAllChk.IsChecked = $(if ($sel -eq 0) { $false }
                                elseif ($bulkOper.Count -gt 0 -and $bulkLeft -eq 0 -and $manualSelected -eq 0) { $true }
                                else { $null })
  }
}

function New-ItemRow($Item, $State, [bool]$Last) {
  $row = New-Object Windows.Controls.Border
  if (-not $Last) {
    $row.BorderBrush = New-Brush $script:C.LineSoft
    $row.BorderThickness = New-Object Windows.Thickness 0, 0, 0, 1
  }
  $row.Padding = New-Object Windows.Thickness 10, 0, 10, 0
  # 行 Tag 存检测状态：全选框与方案据此只圈「可执行」的项（$true=已就绪，跳过）。
  # 体检项例外，一律记 $null：「已就绪就别重复执行」是给写入类项目省备份用的，而体检
  # 不写任何东西，上次通过不代表这次仍然正常（运行库可能被别的软件装崩）。此前 VC++
  # 体检一旦通过，套方案时就再也不会被勾上，等于永远只检测一次
  $row.Tag = $(if ($Item.Kind -eq 'check') { $null } else { $State.Optimized })
  $row.DataContext = [pscustomobject]@{
    BulkSelect = [bool](-not $Item.ContainsKey('BulkSelect') -or $Item.BulkSelect)
  }

  $g = New-Object Windows.Controls.Grid
  foreach ($w in '220', '*', 'Auto') {
    $c = New-Object Windows.Controls.ColumnDefinition
    $c.Width = [Windows.GridLength]::Auto
    if ($w -eq '220') { $c.Width = New-Object Windows.GridLength 220 }
    if ($w -eq '*') { $c.Width = New-Object Windows.GridLength 1, 'Star' }
    $g.ColumnDefinitions.Add($c) | Out-Null
  }

  $cb = New-Object Windows.Controls.CheckBox
  $cb.Style = $window.FindResource('TacCheck')
  $cb.Tag = $Item.Id
  $cb.ToolTip = $(if ($Item.Warn) { $Item.Warn } else { $Item.Note })
  # 已优化的项不再默认勾选，避免重复写入撑大备份
  $cb.IsChecked = ($Item.Default -and $State.Optimized -ne $true)
  $nameColor = $(if ($State.Optimized -eq $true) { $script:C.TextSec } else { $script:C.TextPri })
  if ($Item.Id -ne 'xmp-check') {
    $cb.Content = New-Text "$($Item.Name)$(if ($Item.Admin) { ' *' })" $nameColor 12
  }
  # 勾选变化时实时刷新计数；手动改动后清掉方案选中态（勾选已不再等于该方案）
  $cb.Add_Click({
    Update-Count
    if (-not $script:ApplyingPreset -and $ui.PresetBox -and $ui.PresetBox.SelectedIndex -ge 0) {
      $ui.PresetBox.SelectedIndex = -1
      $ui.PresetNote.Text = ''
    }
  })
  [Windows.Controls.Grid]::SetColumn($cb, 0)
  $g.Children.Add($cb) | Out-Null

  # 内存频率属于用户最常问、且需要品牌化 BIOS 教程的体检项：星标突出，并把名称做成
  # 独立点击入口。勾选框仍只负责是否随“执行优化”复查，点名称则直接复用同一个教程弹窗。
  if ($Item.Id -eq 'xmp-check') {
    $memoryLink = New-Object Windows.Controls.TextBlock
    # TacCheck 的勾选框 13px、内容左间距 8px；这里同样从 21px 开始，和普通项目
    # 的文字基线完全对齐。星标与名称也沿用普通项目的白色，只用下划线提示可点击。
    $memoryLink.Margin = New-Object Windows.Thickness 21, 0, 0, 0
    $memoryLink.VerticalAlignment = 'Center'
    $memoryLink.Cursor = 'Hand'
    $memoryLink.ToolTip = '点击查看内存频率检测结果与对应电脑的 BIOS 教程'
    $starRun = New-Object Windows.Documents.Run
    $starRun.Text = '★ '
    $starRun.Foreground = New-Brush $nameColor
    $starRun.FontWeight = 'Normal'
    $nameRun = New-Object Windows.Documents.Run
    $nameRun.Text = "$($Item.Name)"
    $nameRun.Foreground = New-Brush $nameColor
    $nameRun.FontWeight = 'Normal'
    $nameRun.TextDecorations = [Windows.TextDecorations]::Underline
    [void]$memoryLink.Inlines.Add($starRun)
    [void]$memoryLink.Inlines.Add($nameRun)
    $memoryLink.Tag = [pscustomobject]@{ Id = $Item.Id; Name = $Item.Name; Msg = $State.Current }
    $memoryLink.Add_MouseLeftButtonUp({
      $_.Handled = $true
      Show-HealthDialog @($this.Tag)
    })
    [Windows.Controls.Grid]::SetColumn($memoryLink, 0)
    $g.Children.Add($memoryLink) | Out-Null
  }

  $detail = New-Text $State.Current $script:C.TextMut 11 -Mono
  $detail.Margin = New-Object Windows.Thickness 12, 0, 12, 0
  $detail.TextTrimming = 'CharacterEllipsis'
  # 当前状态被省略号截断时，悬浮弹出完整文本（多底层设置以「；」连接）
  $detailTip = New-Object Windows.Controls.TextBlock
  $detailTip.Text = "$($State.Current)"
  $detailTip.MaxWidth = 320
  $detailTip.TextWrapping = 'Wrap'
  $detailTip.Foreground = New-Brush $script:C.TextPri
  $detail.ToolTip = $detailTip
  [Windows.Controls.Grid]::SetColumn($detail, 1)
  $g.Children.Add($detail) | Out-Null

  # 状态徽标（官网金色分类标签改造）：就绪=绿实底，待优化=金实底，待定=灰描边。
  # 检测类项目语义不同：发现问题不是「待优化」（工具改不了），用金色「需关注」示警
  $pill = if ($Item.Kind -eq 'check') {
            if ($State.Optimized -eq $true) { New-Pill '正常' $script:C.GreenDark $script:C.Green $script:C.Green }
            elseif ($State.Optimized -eq $false) { New-Pill '需关注' $script:C.GoldDark $script:C.Gold $script:C.Gold }
            else { New-Pill '待定' $script:C.Gray '#00000000' $script:C.Line }
          }
          elseif ($State.Optimized -eq $true) { New-Pill '已就绪' $script:C.GreenDark $script:C.Green $script:C.Green }
          elseif ($State.Optimized -eq $false) { New-Pill '待优化' $script:C.GoldDark $script:C.Gold $script:C.Gold }
          else { New-Pill '待定' $script:C.Gray '#00000000' $script:C.Line }
  $tail = New-Object Windows.Controls.StackPanel
  $tail.Orientation = 'Horizontal'
  if ($Item.Id -eq 'gpu-name-spoof') {
    $modelBox = New-Object Windows.Controls.ComboBox
    $modelBox.Style = $window.FindResource('TacCombo')
    $modelBox.Width = 220
    $modelBox.Margin = New-Object Windows.Thickness 0, 0, 8, 0
    $models = @(Get-GpuSpoofModels)
    $selectedModel = $(if ($script:SelectedGpuSpoofModel -and $models -contains $script:SelectedGpuSpoofModel) {
                         $script:SelectedGpuSpoofModel
                       } else { $Item.SpoofModel })
    $selectedOption = $null
    $isLaptop = [bool]$script:HardwareInfo.IsLaptop
    $gpuVendor = "$($script:HardwareInfo.MainGpuVendor)"
    $gpuName = "$($script:HardwareInfo.MainGpuName)"
    foreach ($model in $models) {
      $option = New-Object Windows.Controls.ComboBoxItem
      $recommended = Test-RecommendedGpuSpoofModel $model $isLaptop $gpuVendor $gpuName
      $option.Content = "$(if ($recommended) { '★ ' })$model"
      $option.Tag = $model
      [void]$modelBox.Items.Add($option)
      if ($model -eq $selectedModel) { $selectedOption = $option }
    }
    $modelBox.SelectedItem = $selectedOption
    $script:SelectedGpuSpoofModel = "$selectedModel"
    $modelBox.ToolTip = '选择要向系统和游戏上报的显卡型号；★ 为当前笔记本/台式机推荐项'
    $modelBox.Add_SelectionChanged({
      if ($this.SelectedItem -and $this.SelectedItem.Tag) {
        $script:SelectedGpuSpoofModel = "$($this.SelectedItem.Tag)"
      }
    })
    $tail.Children.Add($modelBox) | Out-Null
  }
  # 体检项查出问题时给行内直达入口：不执行优化也能看到教程和下载按钮，
  # 不用等日志（纯文本链接没人会手抄——实机反馈）
  if ($Item.Kind -eq 'check' -and $State.Optimized -eq $false -and $script:CheckHelp.ContainsKey($Item.Id)) {
    $fix = New-Object Windows.Controls.Button
    $fix.Style = $window.FindResource('Ghost')
    $fix.Content = '解决办法'
    $fix.FontSize = 10
    $fix.Height = 20
    $fix.Margin = New-Object Windows.Thickness 0, 0, 8, 0
    $fix.Tag = [pscustomobject]@{ Id = $Item.Id; Name = $Item.Name; Msg = $State.Current }
    # 循环里挂的处理器不能闭包引用循环变量，一律从 sender.Tag 取（与来源链接同一教训）
    $fix.Add_Click({ Show-HealthDialog @($this.Tag) })
    $tail.Children.Add($fix) | Out-Null
  }
  $tail.Children.Add($pill) | Out-Null
  [Windows.Controls.Grid]::SetColumn($tail, 2)
  $g.Children.Add($tail) | Out-Null

  $row.Child = $g
  $row
}

function Update-PresetList {
  # 下拉同时列内置与自存方案；显示名与方案对象按下标一一对应
  $script:PresetList = @(Get-Presets)
  $ui.PresetBox.Items.Clear()
  foreach ($p in $script:PresetList) {
    # 主推方案加星标突出（实机诉求）；星标只是显示层修饰，判定用内置 Id
    $star = $(if ($p.Id -eq 'main') { '★ ' } else { '' })
    $ui.PresetBox.Items.Add("$star$($p.Name)$(if (-not $p.Builtin) { '（自存）' })") | Out-Null
  }
}

$script:RunLogDir = Join-Path $script:UserConfigDir 'run-logs'
$script:CurrentRunLogPath = ''
$script:RunLogPersistenceError = ''
$script:RunLogMaxFileBytes = 1MB
$script:RunLogRetentionCount = 10
$script:RunLogHistoryCount = 5
$script:RunLogHistoryMaxBytes = 160KB

function Get-RunLogTail([string]$Path, [int]$MaxBytes) {
  if (-not $Path -or $MaxBytes -le 0 -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
  $file = Get-Item -LiteralPath $Path -Force
  if ($file.Length -le $MaxBytes) { return [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8) }
  $stream = New-Object IO.FileStream($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read,
    [IO.FileShare]::ReadWrite, 4096, [IO.FileOptions]::SequentialScan)
  try {
    [void]$stream.Seek(-$MaxBytes, [IO.SeekOrigin]::End)
    $bytes = New-Object byte[] $MaxBytes
    $read = $stream.Read($bytes, 0, $bytes.Length)
  } finally { $stream.Dispose() }
  $text = [Text.Encoding]::UTF8.GetString($bytes, 0, $read)
  $firstLineEnd = $text.IndexOf("`n")
  if ($firstLineEnd -ge 0) { $text = $text.Substring($firstLineEnd + 1) }
  "（较早内容已截断）`r`n$text"
}

function Get-RecentRunLogHistory([object[]]$Files) {
  $remaining = [int]$script:RunLogHistoryMaxBytes
  $blocks = New-Object System.Collections.Generic.List[string]
  foreach ($file in @($Files | Select-Object -First $script:RunLogHistoryCount)) {
    if ($remaining -le 0 -or -not (Test-ProtectedFileAcl $file.FullName)) { continue }
    $perFile = [math]::Min(48KB, $remaining)
    $text = Get-RunLogTail $file.FullName $perFile
    if (-not $text) { continue }
    [void]$blocks.Add("===== 历史会话：$($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) =====`r`n$text".TrimEnd())
    $remaining -= [Text.Encoding]::UTF8.GetByteCount($text)
  }
  $blocks.ToArray() -join "`r`n`r`n"
}

function Initialize-RunLogStore {
  try {
    New-ProtectedDirectory $script:RunLogDir $false
    $existing = @(Get-ChildItem -LiteralPath $script:RunLogDir -File -Filter 'run-*.log' -ErrorAction Stop |
      Sort-Object LastWriteTime -Descending)
    $history = Get-RecentRunLogHistory $existing

    $session = $(if ("$env:DFB_ENGINE_HOST_SESSION" -match '^[0-9a-fA-F]{32}$') {
      "$env:DFB_ENGINE_HOST_SESSION"
    } else { [guid]::NewGuid().ToString('N') })
    $name = 'run-{0}-{1}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $session.Substring(0, 8)
    $path = Join-Path $script:RunLogDir $name
    $header = "DeltaForceBooster v$script:DisplayVersion｜会话开始：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
    $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes($header)
    $stream = New-Object IO.FileStream($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
      [IO.FileShare]::Read, 4096, [IO.FileOptions]::WriteThrough)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    Set-ProtectedFileAcl $path
    if (-not (Test-ProtectedFileAcl $path)) { throw '运行日志文件权限校验失败' }
    $script:CurrentRunLogPath = $path
    foreach ($old in @(Get-ChildItem -LiteralPath $script:RunLogDir -File -Filter 'run-*.log' |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip $script:RunLogRetentionCount)) {
      Remove-Item -LiteralPath $old.FullName -Force -ErrorAction SilentlyContinue
    }

    if ($history) {
      $ui.LogBox.AppendText("$history`r`n`r`n===== 本次运行 =====`r`n")
      $ui.LogBox.ScrollToEnd()
    }
  } catch {
    $script:CurrentRunLogPath = ''
    $script:RunLogPersistenceError = $_.Exception.Message
    $ui.LogBox.AppendText("[提示] 最近运行日志保存暂未启用：$($script:RunLogPersistenceError)`r`n")
  }
}

function Add-PersistentRunLogLine([string]$Line) {
  if (-not $script:CurrentRunLogPath -or -not $Line) { return }
  try {
    $file = Get-Item -LiteralPath $script:CurrentRunLogPath -Force -ErrorAction Stop
    if ($file.Length -ge $script:RunLogMaxFileBytes) { return }
    $safeLine = $(if ($Line.Length -gt 32768) { $Line.Substring(0, 32768) + '…（本行已截断）' } else { $Line })
    [IO.File]::AppendAllText($script:CurrentRunLogPath, "$safeLine`r`n", (New-Object Text.UTF8Encoding($true)))
  } catch {
    # 日志落盘属于辅助能力，失败时保留界面日志；不能递归调用 Write-Log。
    $script:RunLogPersistenceError = $_.Exception.Message
    $script:CurrentRunLogPath = ''
  }
}

function Write-Log([string]$Msg) {
  # 先算好整行再传入：方法括号内的逗号会被当成第二个方法参数，-f 拿不到 $Msg 导致 {1} 越界
  $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $Msg
  # 追加前先判断用户是不是正贴着底部看：他手动上滚翻历史时不该被新日志拽回去。
  # 余量 2px 容忍取整误差；内容还没撑满视口时 ExtentHeight<=ViewportHeight，照样算「在底部」
  $box = $ui.LogBox
  $atEnd = ($box.ExtentHeight -le $box.ViewportHeight + 2) -or
           (($box.VerticalOffset + $box.ViewportHeight) -ge ($box.ExtentHeight - 2))
  $box.AppendText("$line`r`n")
  if ($atEnd) { $box.ScrollToEnd() }
  Add-PersistentRunLogLine $line
}

# ---------- 体检问题的解决办法（教程 + 可点击的官方下载入口） ----------

# 红线：下载链接只能来自这里的硬编码常量，绝不从检测输出/数据文件/网络取——
# 按钮只负责用浏览器打开微软官方地址，本工具自身绝不下载或执行任何安装包
$script:CheckHelp = @{
  'vcredist-check' = @{
    Title = 'VC++ v14 运行库缺失'
    Tutorial = @(
      'VC++ 运行库是游戏和很多软件依赖的微软组件。x64 与 x86 是两套相互独立的运行库，各自服务对应位数的程序：缺失才是真问题（依赖它的程序无法启动）；两套版本不同步很常见、多数机器上无害，本工具只做中性提示，不算问题。'
      ''
      '修复步骤：'
      '1. 点下方按钮下载 x64 与 x86 两个安装包（微软官方链接、当前最新的 vs/18 线，浏览器打开）；'
      '2. 依次双击安装——直接覆盖安装即可，不需要先卸载旧版本；'
      '3. 若双击后看到的是「修复 / 卸载」而不是「安装」，说明系统里已有同版本——选「修复」即可；'
      '4. 若报错 0x80070666「无法安装此产品，因为已安装更新的版本」——说明你系统里的版本比安装包更新，这是正常的，不用处理，也不要为此去卸载；'
      '5. 装完重启电脑，回到本工具点「重新检测」，确认此项变成「正常」；'
      '6. 想统一 x64/x86 版本时，给两个架构装同一条最新线（下方 vs/18 链接）的包，不要装旧线；'
      '7. 只有在缺失某架构、或确实反复闪退且已排除其他原因时，才考虑到「设置 → 应用 → 安装的应用」里只卸载对应架构的「Microsoft Visual C++ 2015-2022 Redistributable」然后重装。切勿把列表里其他年份的 VC++ 一并卸掉——2010/2012/2013 是各自独立的运行库，很多软件还依赖它们。'
    ) -join "`n"
    Links = @(
      @{ Text = '下载 x64 运行库'; Url = 'https://aka.ms/vs/18/release/vc_redist.x64.exe' }
      @{ Text = '下载 x86 运行库'; Url = 'https://aka.ms/vs/18/release/vc_redist.x86.exe' }
    )
  }
  'xmp-check' = @{
    Title = '内存频率 / 性能档位需要确认'
    Tutorial = $null # Build-HealthDialog 按检测到的品牌实时生成
    Links = @()
  }
}

# 打开外部链接的唯一出口：high GUI 不直接启动浏览器。URL 交给 UAC 前持续存活的
# medium launcher broker，并由其再次强制 HTTPS + 固定域名白名单。
function Open-HelpLink([string]$Url) {
  try { Invoke-EngineHostUserAction -Action OpenUrl -Payload $Url | Out-Null }
  catch { Write-Log "已拦截或无法打开外部链接：$($_.Exception.Message)" }
}

# 「体检发现问题」对话框：日志里的纯文本链接等于没给（实机反馈用户不会手抄网址），
# 这里逐条列问题 + 逐步教程 + 可点击的下载按钮。构建与弹出拆开便于离屏渲染验证
function Build-HealthDialog($AttResults) {
  $hxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="500" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="{DynamicResource Gold}" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="体检发现问题" Foreground="{DynamicResource GoldDark}" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="HEALTH CHECK" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <TextBlock Text="以下内容请进入BIOS按照教程手动操作。" Foreground="{DynamicResource TextSec}"
               FontSize="12" Margin="14,12,14,0"/>
    <ScrollViewer MaxHeight="430" VerticalScrollBarVisibility="Auto" Margin="14,10,14,12">
      <StackPanel x:Name="ListPanel"/>
    </ScrollViewer>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" IsCancel="True"
              Foreground="{DynamicResource GreenDark}" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="知道了"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  $dlg = [Windows.Markup.XamlReader]::Parse($hxaml)
  # 独立 Window 不继承主窗口资源：不挂共享字典，对话框滚动条就是系统白色（实机反馈）
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $panel = $dlg.FindName('ListPanel')
  foreach ($r in @($AttResults)) {
    $help = $script:CheckHelp["$($r.Id)"]
    $tutorial = $(if ("$($r.Id)" -eq 'xmp-check') { Get-XmpBiosTutorial $script:HardwareInfo }
                  elseif ($help) { $help.Tutorial } else { $null })
    $card = New-Object Windows.Controls.Border
    $card.Background = New-Brush $script:C.Panel
    $card.BorderBrush = New-Brush $script:C.Line
    $card.BorderThickness = New-Object Windows.Thickness 1
    $card.Padding = New-Object Windows.Thickness 12, 9, 12, 10
    $card.Margin = New-Object Windows.Thickness 0, 0, 0, 8
    $csp = New-Object Windows.Controls.StackPanel
    $tt = New-Text "$(if ($help -and $help.Title) { $help.Title } else { $r.Name })" $script:C.Gold 13
    $tt.FontWeight = 'Bold'
    $csp.Children.Add($tt) | Out-Null
    $ms = New-WrapText "检测结果：$($r.Msg)" $script:C.TextSec 11
    $ms.Margin = New-Object Windows.Thickness 0, 5, 0, 0
    $csp.Children.Add($ms) | Out-Null
    if ($tutorial) {
      $tu = New-WrapText $tutorial $script:C.TextMut 11
      $tu.LineHeight = 18
      $tu.Margin = New-Object Windows.Thickness 0, 7, 0, 0
      $csp.Children.Add($tu) | Out-Null
    }
    if ($help -and @($help.Links).Count -gt 0) {
      $lr = New-Object Windows.Controls.StackPanel
      $lr.Orientation = 'Horizontal'
      $lr.Margin = New-Object Windows.Thickness 0, 9, 0, 0
      foreach ($lk in @($help.Links)) {
        $lb = New-Object Windows.Controls.Button
        $lb.Style = $window.FindResource('Ghost')
        $lb.Content = "$($lk.Text)"
        $lb.FontSize = 11
        $lb.Height = 26
        $lb.Margin = New-Object Windows.Thickness 0, 0, 8, 0
        $lb.Tag = "$($lk.Url)"
        $lb.Add_Click({ Open-HelpLink "$($this.Tag)" })
        $lr.Children.Add($lb) | Out-Null
      }
      $csp.Children.Add($lr) | Out-Null
    }
    $card.Child = $csp
    $panel.Children.Add($card) | Out-Null
  }
  $dlg
}

function Show-HealthDialog($AttResults) {
  # 事件处理器在模态期间回调，与其他对话框同理：对象放 script 作用域最稳
  $script:HcDlg = Build-HealthDialog $AttResults
  $script:HcDlg.Owner = $window
  $script:HcDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:HcDlg.DragMove() })
  $script:HcDlg.FindName('OkBtn').Add_Click({ $script:HcDlg.DialogResult = $true })
  [void]$script:HcDlg.ShowDialog()
}

# ---------- 游戏内设置参考页（纯展示，数据来自 data\streamer-settings.json） ----------

$script:DataFile = Join-Path $script:RootDir 'data\streamer-settings.json'

function New-WrapText([string]$Content, [string]$Color, [int]$Size) {
  $t = New-Text $Content $Color $Size
  $t.TextWrapping = 'Wrap'
  $t
}

function New-RefCell([Windows.Controls.Grid]$Table, [int]$Row, [int]$Col, $Child, [bool]$Header) {
  $b = New-Object Windows.Controls.Border
  $b.BorderBrush = New-Brush $script:C.LineSoft
  $b.BorderThickness = New-Object Windows.Thickness 0, 0, 1, 1
  $b.Padding = New-Object Windows.Thickness 10, 5, 10, 5
  if ($Header) { $b.Background = New-Brush '#FF0B1713' }
  $b.Child = $Child
  [Windows.Controls.Grid]::SetRow($b, $Row)
  [Windows.Controls.Grid]::SetColumn($b, $Col)
  $Table.Children.Add($b) | Out-Null
}

function Add-RefNotice([string]$Title, [string]$Detail) {
  # 数据缺失/损坏时的降级提示：本页是参考内容，任何情况下都不该抛错打断界面
  $b = New-Object Windows.Controls.Border
  $b.Background = New-Brush $script:C.Panel
  $b.BorderBrush = New-Brush $script:C.Line
  $b.BorderThickness = New-Object Windows.Thickness 1
  $b.Padding = New-Object Windows.Thickness 16, 14, 16, 14
  $b.Margin = New-Object Windows.Thickness 0, 8, 0, 0
  $sp = New-Object Windows.Controls.StackPanel
  $t = New-Text $Title $script:C.TextPri 13
  $t.FontWeight = 'Bold'
  $sp.Children.Add($t) | Out-Null
  $d = New-WrapText $Detail $script:C.TextSec 11
  $d.Margin = New-Object Windows.Thickness 0, 6, 0, 0
  $sp.Children.Add($d) | Out-Null
  $b.Child = $sp
  $ui.RefPanel.Children.Add($b) | Out-Null
}

function Update-StreamerPage {
  $ui.RefPanel.Children.Clear()

  # 免责声明放最上面：必须让用户第一眼知道这页只是参考、工具改不了游戏内设置
  $warn = New-Object Windows.Controls.Border
  $warn.Background = New-Brush $script:C.WarningPanel
  $warn.BorderBrush = New-Brush $script:C.Gold
  $warn.BorderThickness = New-Object Windows.Thickness 1
  $warn.Padding = New-Object Windows.Thickness 12, 8, 12, 8
  $wsp = New-Object Windows.Controls.StackPanel
  $wt = New-Text '仅供参考 · 本工具不会也无法修改游戏内设置' $script:C.Gold 12
  $wt.FontWeight = 'Bold'
  $wsp.Children.Add($wt) | Out-Null
  $wd = New-WrapText '第一列是性能优先推荐方案，其余列是头部主播公开的游戏内画质设置记录。请进入游戏后在「设置 → 视频」页签里手动对照；分辨率、刷新率、显卡与超分辨率选项要按本机硬件调整。' $script:C.TextSec 11
  $wd.Margin = New-Object Windows.Thickness 0, 4, 0, 0
  $wsp.Children.Add($wd) | Out-Null
  $warn.Child = $wsp
  $ui.RefPanel.Children.Add($warn) | Out-Null

  if (-not (Test-Path -LiteralPath $script:DataFile)) {
    Add-RefNotice '数据尚未就绪' '游戏内设置参考数据（data\streamer-settings.json）还没有生成。数据到位后切回本页会自动加载。'
    return
  }
  $data = $null
  try { $data = Get-Content -LiteralPath $script:DataFile -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { Add-RefNotice '数据读取失败' "streamer-settings.json 暂时无法解析（可能正在生成中）：$($_.Exception.Message)"; return }

  $streamers = @($data.streamers | Where-Object { $_ })
  if ($streamers.Count -eq 0) { Add-RefNotice '数据尚未就绪' '数据文件里还没有主播条目。'; return }

  # 行头顺序优先用数据声明的 settings_schema。v0.12 起 schema 项支持 { name, group }
  # 对象——group 即游戏内「设置 → 视频」页签下的菜单分组（v0.13 按实机录像核对，
  # 一级页签是「视频」不是「画面」）；老格式的纯字符串仍能读，
  # 缺 group 的一律归入「其他」，数据文件与界面可以各自先后升级互不拖累
  $schema = @()
  foreach ($it in @($data.settings_schema | Where-Object { $_ })) {
    if ($it -is [string]) {
      if ("$it" -ne '') { $schema += [pscustomobject]@{ Name = "$it"; Group = '' } }
    } elseif ("$($it.name)" -ne '') {
      $schema += [pscustomobject]@{ Name = "$($it.name)"; Group = "$($it.group)" }
    }
  }
  if ($schema.Count -eq 0) {
    # 数据没声明行头：按各主播设置键的出现顺序取并集
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($s in $streamers) {
      if ($s.settings) {
        foreach ($p in $s.settings.PSObject.Properties) {
          if (-not $seen.Contains($p.Name)) { [void]$seen.Add($p.Name) }
        }
      }
    }
    $schema = @($seen | ForEach-Object { [pscustomobject]@{ Name = $_; Group = '' } })
  }

  # 分组顺序按 schema 首次出现的顺序；「其他」是兜底组不是游戏菜单，永远排最后
  $groupNames = New-Object System.Collections.Generic.List[string]
  foreach ($col in $schema) {
    $g = $(if ("$($col.Group)" -ne '') { "$($col.Group)" } else { '其他' })
    if (-not $groupNames.Contains($g)) { [void]$groupNames.Add($g) }
  }
  if ($groupNames.Contains('其他')) { [void]$groupNames.Remove('其他'); [void]$groupNames.Add('其他') }

  # 分组依据要如实交代：优先用数据文件里的 schema_note（v0.13 起写明依据实机录像
  # 逐帧核对 + 随版本可能变动），老数据没有分组信息时提示这是兜底展示
  $srcNote = $(if ($data.schema_note) { "$($data.schema_note)" }
               elseif (@($schema | Where-Object { "$($_.Group)" -ne '' }).Count -eq 0) {
                 '当前数据文件未带菜单分组信息，设置项暂归入「其他」统一展示。' })
  if ($srcNote) {
    $sn = New-WrapText $srcNote $script:C.TextMut 10
    $sn.Margin = New-Object Windows.Thickness 2, 0, 0, 8
    $ui.RefPanel.Children.Add($sn) | Out-Null
  }

  if ($schema.Count -gt 0) {
    # 对照表：行=设置项、列=主播，按游戏内菜单分组插入组标题行（实机反馈：扁平大表
    # 拿进游戏找不到每项在哪个菜单下）。单一 Grid 保证各组列宽对齐、横向滚动只有一条
    $tbl = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition
    $c0.Width = [Windows.GridLength]::Auto
    $tbl.ColumnDefinitions.Add($c0) | Out-Null
    foreach ($s in $streamers) {
      $c = New-Object Windows.Controls.ColumnDefinition
      $c.Width = [Windows.GridLength]::Auto
      $c.MinWidth = 110
      $tbl.ColumnDefinitions.Add($c) | Out-Null
    }
    $totalRows = 1 + $groupNames.Count + $schema.Count
    for ($r = 0; $r -lt $totalRows; $r++) {
      $rd = New-Object Windows.Controls.RowDefinition
      $rd.Height = [Windows.GridLength]::Auto
      $tbl.RowDefinitions.Add($rd) | Out-Null
    }
    New-RefCell $tbl 0 0 (New-Text '设置项' $script:C.TextMut 11 -Mono) $true
    for ($j = 0; $j -lt $streamers.Count; $j++) {
      $s = $streamers[$j]
      $hs = New-Object Windows.Controls.StackPanel
      $nm = New-Text "$(if ($s.featured -eq $true) { '★ 推荐设置' } elseif ($s.name) { $s.name } else { "主播$($j + 1)" })" $(if ($s.featured -eq $true) { $script:C.Gold } else { $script:C.Green }) 12
      $nm.FontWeight = 'Bold'
      $hs.Children.Add($nm) | Out-Null
      if ($s.platform) { $hs.Children.Add((New-Text "$($s.platform)" $script:C.TextMut 10 -Mono)) | Out-Null }
      New-RefCell $tbl 0 ($j + 1) $hs $true
    }
    $rowIdx = 1
    foreach ($gName in $groupNames) {
      $inGroup = @($schema | Where-Object { $(if ("$($_.Group)" -ne '') { "$($_.Group)" } else { '其他' }) -eq $gName })
      if ($inGroup.Count -eq 0) { continue }
      # 组标题行：金色分类标签横贯整行（官网 chip 手法），提示进游戏后翻哪个菜单
      $gb = New-Object Windows.Controls.Border
      $gb.Background = New-Brush '#FF10201A'
      $gb.BorderBrush = New-Brush $script:C.LineSoft
      $gb.BorderThickness = New-Object Windows.Thickness 0, 0, 1, 1
      $gb.Padding = New-Object Windows.Thickness 10, 5, 10, 5
      $gsp = New-Object Windows.Controls.StackPanel
      $gsp.Orientation = 'Horizontal'
      $gsp.Children.Add((New-Pill $gName $script:C.GoldDark $script:C.Gold $script:C.Gold)) | Out-Null
      # 路径按实机菜单给（v0.13）：一级页签是「视频」；「显示设置」是本表的归类名，
      # 游戏里顶部这组没有组名，路径只写到「设置 → 视频」为止，别让用户找一个不存在的三级菜单
      $gh = New-Text $(if ($gName -eq '其他') { '未归入游戏菜单的项' }
                       elseif ($gName -eq '显示设置') { '游戏内「设置 → 视频」顶部（游戏内未标组名）' }
                       else { "游戏内「设置 → 视频 → $gName」" }) $script:C.TextMut 10 -Mono
      $gh.Margin = New-Object Windows.Thickness 9, 0, 0, 0
      $gsp.Children.Add($gh) | Out-Null
      $gb.Child = $gsp
      [Windows.Controls.Grid]::SetRow($gb, $rowIdx)
      [Windows.Controls.Grid]::SetColumn($gb, 0)
      [Windows.Controls.Grid]::SetColumnSpan($gb, $streamers.Count + 1)
      $tbl.Children.Add($gb) | Out-Null
      $rowIdx++
      foreach ($col in $inGroup) {
        $key = "$($col.Name)"
        New-RefCell $tbl $rowIdx 0 (New-Text $key $script:C.TextSec 11) $false
        for ($j = 0; $j -lt $streamers.Count; $j++) {
          $s = $streamers[$j]
          $v = $null
          if ($s.settings) {
            $p = $s.settings.PSObject.Properties[$key]
            if ($p -and "$($p.Value)" -ne '') { $v = "$($p.Value)" }
          }
          $cell = New-Text $(if ($v) { $v } else { '—' }) $(if ($v) { $script:C.TextPri } else { $script:C.TextMut }) 11
          New-RefCell $tbl $rowIdx ($j + 1) $cell $false
        }
        $rowIdx++
      }
    }
    $tblWrap = New-Object Windows.Controls.Border
    $tblWrap.BorderBrush = New-Brush $script:C.Line
    $tblWrap.BorderThickness = New-Object Windows.Thickness 1, 1, 0, 0
    $tblWrap.HorizontalAlignment = 'Left'
    $tblWrap.Child = $tbl
    $hsv = New-Object Windows.Controls.ScrollViewer
    $hsv.HorizontalScrollBarVisibility = 'Auto'
    $hsv.VerticalScrollBarVisibility = 'Disabled'
    $hsv.Content = $tblWrap
    # 滚轮失灵的根因在这：ScrollViewer 的类处理器无条件把 MouseWheel 标记成已处理，
    # 哪怕纵向滚动被 Disabled 也不放行，事件到不了外层页面 ScrollViewer；对照表又占满
    # 首屏，于是整页滚轮像坏了一样。纵向滚轮对这个横向表没有任何用处，改成拦下原事件、
    # 以父容器为起点重新冒泡，让外层页面 ScrollViewer 接管
    $hsv.Add_PreviewMouseWheel({
      param($s, $e)
      if ($e.Handled) { return }
      $e.Handled = $true
      $fwd = New-Object Windows.Input.MouseWheelEventArgs($e.MouseDevice, $e.Timestamp, $e.Delta)
      $fwd.RoutedEvent = [Windows.UIElement]::MouseWheelEvent
      $fwd.Source = $s
      $parent = [Windows.Media.VisualTreeHelper]::GetParent($s)
      if ($parent) { $parent.RaiseEvent($fwd) }
    })
    $ui.RefPanel.Children.Add($hsv) | Out-Null
  }

  # 来源与硬件卡片：每位主播一张，来源链接只放行 http/https（与更新入口同一条红线）
  foreach ($s in $streamers) {
    $card = New-Object Windows.Controls.Border
    $card.Background = New-Brush $script:C.Panel
    $card.BorderBrush = New-Brush $script:C.Line
    $card.BorderThickness = New-Object Windows.Thickness 1
    $card.Padding = New-Object Windows.Thickness 12, 8, 12, 8
    $card.Margin = New-Object Windows.Thickness 0, 8, 0, 0
    $csp = New-Object Windows.Controls.StackPanel
    $head = New-Object Windows.Controls.StackPanel
    $head.Orientation = 'Horizontal'
    $nm2 = New-Text "$(if ($s.featured -eq $true) { '★ 推荐设置' } elseif ($s.name) { $s.name } else { '未命名主播' })" $(if ($s.featured -eq $true) { $script:C.Gold } else { $script:C.TextPri }) 12
    $nm2.FontWeight = 'Bold'
    $head.Children.Add($nm2) | Out-Null
    if ($s.platform) {
      $plat = New-Text "$($s.platform)" $script:C.TextMut 10 -Mono
      $plat.Margin = New-Object Windows.Thickness 8, 0, 0, 0
      $head.Children.Add($plat) | Out-Null
    }
    if ("$($s.url)" -match '^https?://') {
      $lnk = New-Object Windows.Controls.Button
      $lnk.Style = $window.FindResource('Ghost')
      $lnk.Content = '查看来源'
      $lnk.FontSize = 10
      $lnk.Height = 20
      $lnk.Margin = New-Object Windows.Thickness 10, 0, 0, 0
      $lnk.Tag = "$($s.url)"
      # 循环里挂的处理器不能直接引用 $s（点击时 $s 早已是最后一个元素），从 sender.Tag 取
      $lnk.Add_Click({ Open-HelpLink "$($this.Tag)" })
      $head.Children.Add($lnk) | Out-Null
    }
    $csp.Children.Add($head) | Out-Null
    # 推荐设置是持续维护的内置方案，不显示一次性采集日期；主播资料仍保留记录时间。
    $hw2 = New-WrapText "硬件：$(if ($s.hardware) { $s.hardware } else { '未注明' })$(if ($s.captured -and $s.featured -ne $true) { "　·　记录于 $($s.captured)" })" $script:C.TextSec 11
    $hw2.Margin = New-Object Windows.Thickness 0, 4, 0, 0
    $csp.Children.Add($hw2) | Out-Null
    $tail = New-Text $(if ($s.featured -eq $true) { '性能优先推荐 · 设备相关项请按本机调整' } else { '设置随版本/硬件而异，仅供参考' }) $script:C.Gold 10
    $tail.Margin = New-Object Windows.Thickness 0, 4, 0, 0
    $csp.Children.Add($tail) | Out-Null
    $card.Child = $csp
    $ui.RefPanel.Children.Add($card) | Out-Null
  }
}

# ---------- 免责声明门控 ----------

# 声明内容有实质修改时把这个数字 +1：配置里记的版本与此不符即重新弹一次，
# 老用户不会因为条款改了还停留在旧版本的「已同意」上
$script:DisclaimerVersion = '8'
$script:DisclaimerFile = Join-Path $script:RootDir 'DISCLAIMER.md'

# 同意状态与 updater 的配置同目录：profiles\ 下的 *.json 会被引擎当预设方案扫出来
function Get-DisclaimerConfigPath {
  $d = $script:UserConfigDir
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  Join-Path $d 'disclaimer.json'
}

function Test-DisclaimerAccepted {
  try {
    $f = Get-DisclaimerConfigPath
    if (-not (Test-Path -LiteralPath $f)) { return $false }
    $j = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
    return ("$($j.Version)" -eq $script:DisclaimerVersion)
  } catch { return $false }
}

function Set-DisclaimerAccepted {
  $o = @{ Version = $script:DisclaimerVersion; AcceptedAt = (Get-Date).ToString('s') }
  [IO.File]::WriteAllText((Get-DisclaimerConfigPath), ($o | ConvertTo-Json), (New-Object Text.UTF8Encoding($true)))
}

# 文件缺失（残缺包/被杀软删了）不能等于放行：退回内嵌短文本，门控照常拦
function Get-DisclaimerText {
  try {
    if (Test-Path -LiteralPath $script:DisclaimerFile) {
      $t = [IO.File]::ReadAllText($script:DisclaimerFile, [Text.Encoding]::UTF8)
      if ("$t".Trim()) { return $t }
    }
  } catch {}
  @(
    '# 使用前必读'
    ''
    '未能读取完整声明文件（DISCLAIMER.md 缺失），以下是核心要点：'
    ''
    '- 个人开发的免费工具，**与腾讯公司及《三角洲行动》官方无任何关系**。'
    '- 会修改注册表、电源计划、系统服务等系统级设置；可还原的设置改动会先写入受保护备份，可点「还原设置」回退；纯检测项和明确标注不可还原的操作不生成备份，还原也不保证 100% 成功。'
    '- 优化效果因机器而异，不做任何承诺；部分项有明确副作用，勾选前请读每项说明。'
    '- 极少数设备应用电源计划优化后可能出现卡顿、黑屏、驱动异常、游戏无法进入、温度功耗升高或睡眠/外设异常；执行前会再次确认，异常时请还原相关项目并重启。'
    '- 没有代码签名证书，SmartScreen 与杀毒软件可能报警，这是必然结果。'
    '- 同意后会发送匿名使用统计：随机安装标识、版本、Windows / CPU / 真实 GPU / 内存 / 设备与显示类型、驱动和电源/存储/系统功能状态、固定白名单软件是否正在运行、显卡控制软件检测和本工具备份还原状态，以及游戏中最多 120 秒的帧率、帧时间、延迟、帧生成、CPU / GPU / 内存 / 功耗汇总与采样覆盖率。性能汇总会附带当前由工具管理的公开优化项目 ID、匿名方案类别和归属完整度；自存方案只记为 custom，不发送方案名称或内容，也不发送用户名、机器名、SID、游戏路径、任意进程名、注册表路径/键值/原值或逐帧数据。统计来自客户端自动采样，会做令牌、重放、严格字段和异常值过滤，但不是独立实验室测量。'
    '- 服务端定时清理：诊断报告保留 30 天、性能会话保留 90 天、匿名安装标识与按日使用明细保留 180 天。'
    '- 作者不对使用本工具导致的任何损失负责，使用前请自行备份重要数据。'
    ''
    '完整声明见项目根目录的 DISCLAIMER.md。'
  ) -join "`n"
}

# 极简 Markdown 渲染：只处理标题/加粗/列表/分隔线四种，够用且不引第三方库
function Add-MdInlines([Windows.Controls.TextBlock]$Block, [string]$Text) {
  $parts = $Text -split '\*\*'
  for ($i = 0; $i -lt $parts.Count; $i++) {
    if (-not $parts[$i]) { continue }
    $run = New-Object Windows.Documents.Run $parts[$i]
    # 按 ** 切开后，奇数段就是被包起来的部分
    if ($i % 2 -eq 1) { $run.FontWeight = 'Bold'; $run.Foreground = New-Brush $script:C.TextPri }
    $Block.Inlines.Add($run)
  }
}

function Build-MdPanel([string]$Md) {
  $sp = New-Object Windows.Controls.StackPanel
  foreach ($raw in ($Md -split "`r?`n")) {
    $line = $raw.TrimEnd()
    if ($line -match '^#\s+(.*)$') { continue }   # 一级标题即窗口标题，不重复显示
    if ($line -match '^##\s+(.*)$') {
      $t = New-Text $Matches[1] $script:C.Green 14
      $t.FontWeight = 'Bold'
      $t.Margin = New-Object Windows.Thickness 0, 14, 0, 5
      $sp.Children.Add($t) | Out-Null
      continue
    }
    if ($line -match '^---+$') {
      $b = New-Object Windows.Controls.Border
      $b.Height = 1
      $b.Background = New-Brush $script:C.Line
      $b.Margin = New-Object Windows.Thickness 0, 12, 0, 10
      $sp.Children.Add($b) | Out-Null
      continue
    }
    if (-not $line.Trim()) { continue }
    $isLi = ($line -match '^[-*]\s+(.*)$')
    $body = $(if ($isLi) { $Matches[1] } else { $line })
    $t = New-WrapText '' $script:C.TextSec 12
    $t.LineHeight = 20
    if ($isLi) {
      $t.Margin = New-Object Windows.Thickness 14, 2, 0, 2
      $t.Inlines.Add((New-Object Windows.Documents.Run '· '))
    } else {
      $t.Margin = New-Object Windows.Thickness 0, 4, 0, 4
    }
    Add-MdInlines $t $body
    $sp.Children.Add($t) | Out-Null
  }
  $sp
}

# 退出调用单独包一层：验证脚本可替换成 mock 走完「不同意」的完整链路而不真的退掉测试进程
function Invoke-AppExit { [Environment]::Exit(0) }

# 构建与弹出拆开：离屏渲染只需要构建结果，不必真的走模态
function Build-DisclaimerDialog([bool]$ReadOnly) {
  $dxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="三角洲行动 · 画面优化助手" Width="620" Height="640" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Border x:Name="DlgTitle" Grid.Row="0" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}"
            BorderThickness="0,0,0,1" Padding="14,11">
      <StackPanel Orientation="Horizontal">
        <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="{DynamicResource Green}" VerticalAlignment="Center"/>
        <TextBlock Text="使用前必读" Foreground="{DynamicResource TextPri}" FontSize="15" FontWeight="Bold"
                   Margin="11,0,0,0" VerticalAlignment="Center"/>
        <TextBlock Text="DISCLAIMER" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                   VerticalAlignment="Center" Margin="10,3,0,0"/>
      </StackPanel>
    </Border>
    <Border Grid.Row="1" Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="14,12,14,0">
      <ScrollViewer x:Name="Scroller" VerticalScrollBarVisibility="Auto" Padding="16,12,16,14">
        <StackPanel x:Name="Body"/>
      </ScrollViewer>
    </Border>
    <TextBlock x:Name="HintTxt" Grid.Row="2" Text="请滚动到底部阅读完整内容后再选择。"
               Foreground="{DynamicResource Gold}" FontSize="11" Margin="16,8,16,0"/>
    <Grid Grid.Row="3" Margin="14,10,14,14">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <Button x:Name="AgreeBtn" Grid.Column="1" MinWidth="126" Height="34" IsEnabled="False"
              Foreground="{DynamicResource GreenDark}" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.05,0 L 1,0 L 1,0.8 L 0.95,1 L 0,1 L 0,0.2 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bg" Property="Fill" Value="{DynamicResource LineHi}"/>
                <Setter Property="Foreground" Value="{DynamicResource DisabledText}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="AgreeTxt" Text="同意并继续"/>
      </Button>
      <Button x:Name="DeclineBtn" Grid.Column="2" MinWidth="112" Height="34"
              Foreground="{DynamicResource Green}" Margin="10,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="DeclineTxt" Text="不同意，退出"/>
      </Button>
    </Grid>
  </Grid>
</Window>
'@
  $dlg = [Windows.Markup.XamlReader]::Parse($dxaml)
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $dlg.FindName('Body').Children.Add((Build-MdPanel (Get-DisclaimerText))) | Out-Null
  # 重看模式没有「再同意一次」的语义：只留一个关闭按钮，且不需要滚到底
  if ($ReadOnly) {
    $dlg.FindName('AgreeBtn').Visibility = 'Collapsed'
    $dlg.FindName('DeclineTxt').Text = '关闭'
    $dlg.FindName('HintTxt').Visibility = 'Collapsed'
  }
  $dlg
}

# 构建 + 挂事件（不弹）：拆出来供离屏验证走完整交互，弹窗是 ShowDialog 那一步的事
function Initialize-DisclaimerDialog([bool]$ReadOnly) {
  $script:DcDlg = Build-DisclaimerDialog $ReadOnly
  $script:DcUi = @{}
  foreach ($n in 'DlgTitle','Scroller','AgreeBtn','HintTxt','DeclineBtn') { $script:DcUi[$n] = $script:DcDlg.FindName($n) }
  $script:DcDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:DcDlg.DragMove() })
  if (-not $ReadOnly) {
    $script:DcUi.Scroller.Add_ScrollChanged({
      # 内容比视口还短时永远滚不到「底」，此时直接放行；余量 4px 容忍取整误差
      $sv = $script:DcUi.Scroller
      if ($sv.ScrollableHeight -le 0 -or ($sv.VerticalOffset + $sv.ViewportHeight) -ge ($sv.ExtentHeight - 4)) {
        $script:DcUi.AgreeBtn.IsEnabled = $true
        $script:DcUi.HintTxt.Text = '已读完，可以选择了。'
        $script:DcUi.HintTxt.Foreground = New-Brush $script:C.TextMut
      }
    })
    $script:DcUi.AgreeBtn.Add_Click({ $script:DcDlg.DialogResult = $true })
  }
  $script:DcUi.DeclineBtn.Add_Click({ $script:DcDlg.DialogResult = $false })
  $script:DcDlg
}

# 首次启动的门控：同意才返回 $true。滚到底才放开「同意」——目的是让人至少划一遍
function Show-DisclaimerDialog([switch]$ReadOnly) {
  $dlg = Initialize-DisclaimerDialog ([bool]$ReadOnly)
  $ok = [bool]$dlg.ShowDialog()
  if ($ReadOnly) { return $true }
  if ($ok) { Set-DisclaimerAccepted }
  $ok
}

# ---------- 匿名使用统计（同意声明后异步发送，不阻塞主界面） ----------

$script:TelemetryUploadUrl = 'https://df.ltz88.cn/report/telemetry'
$script:TelemetryJobs = New-Object System.Collections.ArrayList
$script:LatestRestoreCatalog = $null
$script:TelemetryGpuPanelCache = @{}
$script:TelemetryStorageCache = @{}
$script:TelemetryDeviceSecurityCache = $null

function Get-TelemetryInstallId {
  $dir = $script:UserConfigDir
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $path = Join-Path $dir 'telemetry.json'
  try {
    if (Test-Path -LiteralPath $path) {
      $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($cfg.Enabled -eq $false) { return $null }
      if ("$($cfg.InstallId)" -match '^[0-9a-fA-F-]{32,64}$') { return "$($cfg.InstallId)" }
    }
  } catch {}
  $id = [guid]::NewGuid().ToString()
  $cfg = [ordered]@{
    Enabled = $true; InstallId = $id; CreatedAt = (Get-Date).ToUniversalTime().ToString('o')
    ConfigTier = 'baseline'; OptimizationScheme = 'baseline'; OptimizationItemIds = @()
    OptimizationItemSetHash = ''; OptimizationItemsComplete = $true
    DeviceToken = ''; TokenExpiresAt = 0
  }
  if (Get-Command Write-DfbTelemetryConfigAtomic -ErrorAction SilentlyContinue) { Write-DfbTelemetryConfigAtomic $path $cfg }
  else { [IO.File]::WriteAllText($path, ($cfg | ConvertTo-Json), (New-Object Text.UTF8Encoding($true))) }
  $id
}

# 普通性能会话记录当前由工具管理的公开项目 ID 与匿名方案类别；自存方案只记为 custom，
# 不上传方案名称或内容。项目集合由受保护还原目录回推，历史备份缺少项目归属时会明确
# 标成不完整，避免把未知旧改动误当成基线或某个具体方案。
function ConvertTo-TelemetryOptimizationItemIds([object[]]$Values) {
  @($Values | ForEach-Object { "$_".Trim().ToLowerInvariant() } |
    Where-Object { $_ -match '^[a-z0-9][a-z0-9-]{0,63}$' } | Sort-Object -Unique)
}

function Get-TelemetryOptimizationItemSetHash([object[]]$Values) {
  $ids = @(ConvertTo-TelemetryOptimizationItemIds $Values)
  if ($ids.Count -eq 0) { return '' }
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes(($ids -join ','))
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-TelemetryOptimizationContext {
  $result = [ordered]@{
    ConfigTier = 'baseline'; Scheme = 'baseline'; ItemIds = @(); ItemSetHash = ''; ItemsComplete = $true
  }
  try {
    $path = Join-Path $script:UserConfigDir 'telemetry.json'
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]$result }
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $tier = "$($cfg.ConfigTier)".ToLowerInvariant()
    if ($tier -in 'baseline','light','balanced','full') { $result.ConfigTier = $tier }
    $hasIds = [bool]$cfg.PSObject.Properties['OptimizationItemIds']
    $ids = @(ConvertTo-TelemetryOptimizationItemIds @($cfg.OptimizationItemIds))
    $scheme = "$($cfg.OptimizationScheme)".ToLowerInvariant()
    if ($scheme -notin 'baseline','main','balanced','safe-only','custom','manual','frame-fix','auto-tuning','mixed','legacy-unknown','unknown') {
      $scheme = $(if ($result.ConfigTier -eq 'baseline') { 'baseline' } else { 'legacy-unknown' })
    }
    $complete = [bool]($cfg.PSObject.Properties['OptimizationItemsComplete'] -and
      $cfg.OptimizationItemsComplete -is [bool] -and [bool]$cfg.OptimizationItemsComplete)
    if (-not $hasIds) {
      $complete = ($result.ConfigTier -eq 'baseline')
      $scheme = $(if ($complete) { 'baseline' } else { 'legacy-unknown' })
    }
    if ($complete) {
      $result.ConfigTier = Get-SelectedTelemetryConfigTier $ids.Count
      if ($ids.Count -eq 0) { $scheme = 'baseline' }
    }
    $result.Scheme = $scheme
    $result.ItemIds = @($ids)
    $result.ItemSetHash = Get-TelemetryOptimizationItemSetHash $ids
    $result.ItemsComplete = [bool]$complete
  } catch {}
  [pscustomobject]$result
}

function Get-TelemetryConfigTier { (Get-TelemetryOptimizationContext).ConfigTier }

function Set-TelemetryOptimizationContext {
  param(
    [object[]]$ItemIds = @(),
    [ValidateSet('baseline','main','balanced','safe-only','custom','manual','frame-fix','auto-tuning','mixed','legacy-unknown','unknown')]
    [string]$Scheme = 'unknown',
    [bool]$ItemsComplete = $true,
    [string]$FallbackTier = ''
  )
  $mutex = $null; $locked = $false
  try {
    $mutex = New-Object Threading.Mutex($false, 'Local\DeltaForceBooster.Telemetry.Config')
    $locked = $mutex.WaitOne([TimeSpan]::FromSeconds(10))
    if (-not $locked) { return }
    $dir = $script:UserConfigDir
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $path = Join-Path $dir 'telemetry.json'
    $enabled = $true
    $installId = [guid]::NewGuid().ToString()
    $createdAt = (Get-Date).ToUniversalTime().ToString('o')
    $currentTier = 'baseline'
    $deviceToken = ''
    $tokenExpiresAt = 0L
    if (Test-Path -LiteralPath $path) {
      $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($cfg.Enabled -eq $false) { $enabled = $false }
      if ("$($cfg.InstallId)" -match '^[0-9a-fA-F-]{32,64}$') { $installId = "$($cfg.InstallId)" }
      if ("$($cfg.CreatedAt)") { $createdAt = "$($cfg.CreatedAt)" }
      if ("$($cfg.DeviceToken)" -match '^v1\.') { $deviceToken = "$($cfg.DeviceToken)" }
      try { $tokenExpiresAt = [long]$cfg.TokenExpiresAt } catch {}
      if ("$($cfg.ConfigTier)".ToLowerInvariant() -in 'baseline','light','balanced','full') {
        $currentTier = "$($cfg.ConfigTier)".ToLowerInvariant()
      }
    }
    $ids = @(ConvertTo-TelemetryOptimizationItemIds $ItemIds)
    $tier = Get-SelectedTelemetryConfigTier $ids.Count
    if (-not $ItemsComplete -and $ids.Count -eq 0) {
      $fallback = "$FallbackTier".ToLowerInvariant()
      $tier = $(if ($fallback -in 'baseline','light','balanced','full') { $fallback } else { $currentTier })
    }
    if ($ItemsComplete -and $ids.Count -eq 0) { $Scheme = 'baseline' }
    elseif (-not $ItemsComplete -and $ids.Count -eq 0 -and $Scheme -eq 'baseline') { $Scheme = 'legacy-unknown' }
    $out = [ordered]@{
      Enabled = $enabled; InstallId = $installId; CreatedAt = $createdAt; ConfigTier = $tier
      OptimizationScheme = $Scheme; OptimizationItemIds = @($ids)
      OptimizationItemSetHash = Get-TelemetryOptimizationItemSetHash $ids
      OptimizationItemsComplete = [bool]$ItemsComplete
      DeviceToken = $deviceToken; TokenExpiresAt = $tokenExpiresAt
    }
    if (Get-Command Write-DfbTelemetryConfigAtomic -ErrorAction SilentlyContinue) { Write-DfbTelemetryConfigAtomic $path $out }
    else { [IO.File]::WriteAllText($path, ($out | ConvertTo-Json), (New-Object Text.UTF8Encoding($true))) }
  } catch {} finally {
    if ($locked) { try { $mutex.ReleaseMutex() } catch {} }
    if ($mutex) { $mutex.Dispose() }
  }
}

function Get-SelectedTelemetryConfigTier([int]$SelectedCount) {
  if ($SelectedCount -ge 21) { return 'full' }
  if ($SelectedCount -ge 10) { return 'balanced' }
  if ($SelectedCount -ge 1) { return 'light' }
  'baseline'
}

function Clear-CompletedTelemetryJobs {
  foreach ($job in @($script:TelemetryJobs)) {
    if (-not $job.Async.IsCompleted) { continue }
    try { $job.PowerShell.EndInvoke($job.Async) | Out-Null } catch {}
    try { $job.PowerShell.Dispose() } catch {}
    $script:TelemetryJobs.Remove($job) | Out-Null
  }
}

function Get-TelemetryMainGpuDriver($Hw) {
  if (-not $Hw) { return '' }
  $gpu = @($Hw.Gpus | Where-Object { "$($_.Name)" -eq "$($Hw.MainGpuName)" } | Select-Object -First 1)
  if ($gpu.Count) { return "$($gpu[0].Driver)" }
  ''
}

function Get-TelemetryDisplayMode($Hw) {
  if (-not $Hw) { return '' }
  $width = [int]$Hw.DisplayWidth; $height = [int]$Hw.DisplayHeight; $refresh = [int]$Hw.DisplayRefreshHz
  if ($width -le 0 -or $height -le 0) { return '' }
  "${width}x${height}@$refresh"
}

function Get-TelemetryRegValue([string]$Path, [string]$Name) {
  try { Get-RegValue $Path $Name } catch { $null }
}

function Get-TelemetryActiveSoftwareKeys {
  # 只检查固定白名单并上传稳定 key；不采集任意进程名、命令行或路径。
  $map = [ordered]@{
    'DeltaForceClient-Win64-Shipping'='game-client'; 'DeltaForce'='game-launcher'
    'PresentMon'='presentmon'; 'RTSS'='rtss'; 'MSIAfterburner'='msi-afterburner'
    'obs64'='obs'; 'Discord'='discord'; 'GameBar'='game-bar'; 'NVIDIA Share'='nvidia-share'
    'RadeonSoftware'='amd-software'; 'WeGame'='wegame'; 'GamePP'='gamepp'
    'LosslessScaling'='lossless-scaling'; 'ProcessLasso'='process-lasso'; 'ProcessGovernor'='process-lasso'
    'ArmouryCrate.UserSessionHelper'='armoury-crate'; 'GHelper'='g-helper'
    'LenovoVantage'='lenovo-vantage'; 'LenovoVantageService'='lenovo-vantage'
    'MSI.CentralServer'='msi-center'; 'MSI_Center_Service'='msi-center'
    'OMEN Gaming Hub'='omen-gaming-hub'; 'OMENCommandCenter'='omen-gaming-hub'
    'AWCC.Background.Server'='alienware-command-center'; 'AWCCService'='alienware-command-center'
    'RazerCortex'='razer-cortex'
  }
  try {
    $running = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @(Get-Process -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique)) {
      [void]$running.Add("$name")
    }
    [string[]]@($map.Keys | Where-Object { $running.Contains("$_") } |
      ForEach-Object { "$($map[$_])" } | Sort-Object -Unique | Select-Object -First 32)
  } catch { [string[]]@() }
}

function Get-TelemetryGpuPanelSnapshot([string]$Vendor) {
  $key = "$Vendor".Trim().ToUpperInvariant()
  if (-not $script:TelemetryGpuPanelCache.ContainsKey($key)) {
    $inventory = $null
    try { $inventory = Get-GuiGpuPanelInventory $key } catch {}
    if (-not $inventory) { $inventory = [pscustomobject]@{ Status='not_checked';Apps=@() } }
    $allowed = @('nv-cpl','nv-app','amd-sw','intel-gcc')
    $script:TelemetryGpuPanelCache[$key] = [pscustomobject]@{
      Status = $(if ("$($inventory.Status)" -in 'ok','broker_failed','unsupported_vendor','unavailable_in_compatibility_mode','not_checked') {
        "$($inventory.Status)"
      } else { 'not_checked' })
      InstalledKeys = [string[]]@($inventory.Apps | Where-Object Installed | ForEach-Object { "$($_.Key)" } |
        Where-Object { $_ -in $allowed } | Sort-Object -Unique)
      MissingKeys = [string[]]@($inventory.Apps | Where-Object { -not $_.Installed } | ForEach-Object { "$($_.Key)" } |
        Where-Object { $_ -in $allowed } | Sort-Object -Unique)
    }
  }
  $script:TelemetryGpuPanelCache[$key]
}

function Get-TelemetryDeviceSecuritySnapshot {
  if ($script:TelemetryDeviceSecurityCache) { return $script:TelemetryDeviceSecurityCache }
  $vbs = 'unknown'; $memoryIntegrity = 'unknown'
  try {
    $guard = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop |
      Select-Object -First 1
    $vbs = $(switch ([int]$guard.VirtualizationBasedSecurityStatus) { 2 { 'running' }; 1 { 'configured' }; 0 { 'disabled' }; default { 'unknown' } })
    $running = @($guard.SecurityServicesRunning | ForEach-Object { [int]$_ })
    $configured = @($guard.SecurityServicesConfigured | ForEach-Object { [int]$_ })
    $memoryIntegrity = $(if ($running -contains 2) { 'enabled' } elseif ($configured -contains 2) { 'configured_not_running' } else { 'disabled' })
  } catch {}
  $script:TelemetryDeviceSecurityCache = [pscustomobject]@{ VbsState=$vbs;MemoryIntegrityState=$memoryIntegrity }
  $script:TelemetryDeviceSecurityCache
}

function Get-TelemetryWindowsChannel {
  try {
    $branch = "$(Get-TelemetryRegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'BuildBranch')"
    $selfHostPath = 'HKLM:\SOFTWARE\Microsoft\WindowsSelfHost\Applicability'
    if (-not (Test-Path -LiteralPath $selfHostPath)) {
      return $(if ($branch -match '(?i)prerelease|canary|dev|beta') { 'preview' } else { 'retail' })
    }
    $flight = Get-ItemProperty -LiteralPath $selfHostPath -ErrorAction Stop
    $value = "$($flight.BranchName) $($flight.Ring) $($flight.ContentType) $branch"
    if ($value -match '(?i)canary') { return 'canary' }
    if ($value -match '(?i)(?:^|\W)dev(?:\W|$)|rs_prerelease') { return 'dev' }
    if ($value -match '(?i)beta') { return 'beta' }
    if ($value -match '(?i)release[ _-]?preview') { return 'release_preview' }
    'preview'
  } catch { 'unknown' }
}

function Get-TelemetryStorageSnapshot([string]$Path) {
  $root = ''
  try { if ($Path) { $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path)) } } catch {}
  if (-not $root -or $root -notmatch '^[A-Za-z]:\\$') {
    return [pscustomobject]@{ MediaType='unknown';BusType='unknown';FreeGb=$null }
  }
  $cacheKey = $root.ToUpperInvariant()
  if ($script:TelemetryStorageCache.ContainsKey($cacheKey)) { return $script:TelemetryStorageCache[$cacheKey] }
  $media = 'unknown'; $bus = 'unknown'; $freeGb = $null
  try {
    $deviceId = $root.Substring(0,2)
    $logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$deviceId'" -ErrorAction Stop | Select-Object -First 1
    if ($logical -and $null -ne $logical.FreeSpace) { $freeGb = [math]::Round([double]$logical.FreeSpace / 1GB, 1) }
  } catch {}
  try {
    $partition = Get-Partition -DriveLetter $root.Substring(0,1) -ErrorAction Stop | Select-Object -First 1
    $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
    $busText = "$($disk.BusType)".Trim().ToLowerInvariant()
    $bus = $(if ($busText -in 'ata','sata','nvme','usb','raid','scsi','sas','mmc','sd','iscsi','virtual','file backed virtual','spaces') {
      $busText -replace ' ','_'
    } else { 'unknown' })
    $physical = Get-PhysicalDisk -ErrorAction SilentlyContinue |
      Where-Object { "$($_.DeviceId)" -eq "$($disk.Number)" } | Select-Object -First 1
    $mediaText = "$($physical.MediaType)".Trim().ToLowerInvariant()
    if ($mediaText -in 'hdd','ssd','scm') { $media = $mediaText }
  } catch {}
  $script:TelemetryStorageCache[$cacheKey] = [pscustomobject]@{ MediaType=$media;BusType=$bus;FreeGb=$freeGb }
  $script:TelemetryStorageCache[$cacheKey]
}

function Get-TelemetryAnalysisContext($Hw, [string]$GamePath = $script:TargetExe) {
  if (-not $Hw) { return $null }
  $gamePathValid = $false
  try { $gamePathValid = [bool]($GamePath -and (Test-AllowedGameExecutable $GamePath)) } catch {}
  $gameVersion = ''
  if ($gamePathValid) {
    try { $gameVersion = "$((Get-Item -LiteralPath $GamePath -Force).VersionInfo.FileVersion)".Trim() } catch {}
  }
  $osVersion = ''; $osUbr = 0
  try {
    $osReg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $osVersion = "$($osReg.DisplayVersion)".Trim()
    $osUbr = [math]::Max(0, [int]$osReg.UBR)
  } catch {}

  $hagsValue = Get-TelemetryRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
  $hagsState = $(if ($null -eq $hagsValue) { 'default' } elseif ([int]$hagsValue -eq 2) { 'enabled' }
    elseif ([int]$hagsValue -eq 1) { 'disabled' } else { 'custom' })
  $gameModeValue = Get-TelemetryRegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
  $gameModeState = $(if ($null -eq $gameModeValue) { 'default' } elseif ([int]$gameModeValue -eq 1) { 'enabled' }
    elseif ([int]$gameModeValue -eq 0) { 'disabled' } else { 'custom' })
  $dvrUser = Get-TelemetryRegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
  $dvrCapture = Get-TelemetryRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
  $gameDvrState = $(if ($null -eq $dvrUser -and $null -eq $dvrCapture) { 'default' }
    elseif (($null -eq $dvrUser -or [int]$dvrUser -eq 0) -and ($null -eq $dvrCapture -or [int]$dvrCapture -eq 0)) { 'disabled' }
    elseif (($null -eq $dvrUser -or [int]$dvrUser -eq 1) -and ($null -eq $dvrCapture -or [int]$dvrCapture -eq 1)) { 'enabled' }
    else { 'mixed' })
  $mpoValue = Get-TelemetryRegValue 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode'
  $mpoState = $(if ($null -eq $mpoValue) { 'default' } elseif ([int]$mpoValue -eq 5) { 'disabled' } else { 'custom' })
  $windowedRaw = "$(Get-TelemetryRegValue 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings')"
  $windowedState = $(if ($windowedRaw -match '(?:^|;)SwapEffectUpgradeEnable=0(?:;|$)') { 'disabled' }
    elseif ($windowedRaw -match '(?:^|;)SwapEffectUpgradeEnable=1(?:;|$)') { 'enabled' } else { 'default' })
  $autoHdrState = $(if ($windowedRaw -match '(?:^|;)AutoHDREnable=0(?:;|$)') { 'disabled' }
    elseif ($windowedRaw -match '(?:^|;)AutoHDREnable=1(?:;|$)') { 'enabled' } else { 'default' })
  $vrrState = $(if ($windowedRaw -match '(?:^|;)VRROptimizeEnable=0(?:;|$)') { 'disabled' }
    elseif ($windowedRaw -match '(?:^|;)VRROptimizeEnable=1(?:;|$)') { 'enabled' } else { 'default' })
  $fsoState = 'unknown'; $gpuPreferenceState = 'unknown'
  if ($gamePathValid) {
    $layer = "$(Get-TelemetryRegValue 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' $GamePath)"
    $fsoState = $(if ($layer -match '(?i)(?:^|\s)DISABLEDXMAXIMIZEDWINDOWEDMODE(?:\s|$)') { 'disabled' } else { 'default' })
    $gpuPreference = "$(Get-TelemetryRegValue 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $GamePath)"
    $gpuPreferenceState = $(if ($gpuPreference -match '(?i)(?:^|;)GpuPreference=2(?:;|$)') { 'high_performance' }
      elseif ($gpuPreference -match '(?i)(?:^|;)GpuPreference=1(?:;|$)') { 'power_saving' }
      elseif ([string]::IsNullOrWhiteSpace($gpuPreference)) { 'default' } else { 'custom' })
  }
  $activePowerPlanGuid = ''
  try { $activePowerPlanGuid = "$((Get-ActiveScheme).Guid)".Trim().ToLowerInvariant() } catch {}
  $rebootPending = $false
  try {
    $rebootPending = [bool](
      (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
      (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
      ($null -ne (Get-TelemetryRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations'))
    )
  } catch {}
  $power = $null
  try { $power = Get-SystemPowerSnapshot } catch {}
  if (-not $power) { $power = [pscustomobject]@{ Source="$($Hw.PowerSource)"; BatteryPercent=$Hw.BatteryPercent } }
  $vc = $null
  try { $vc = Get-VcRedistInventory } catch {}
  if (-not $vc) { $vc = [pscustomobject]@{ Status='unknown';X64Version='';X86Version='';ComponentCount=0 } }
  $memoryCompressionState = 'unknown'
  try { $memoryCompressionState = $(if ([bool](Get-MMAgent -ErrorAction Stop).MemoryCompression) { 'enabled' } else { 'disabled' }) } catch {}
  $security = Get-TelemetryDeviceSecuritySnapshot
  $optimization = Get-TelemetryOptimizationContext
  $panel = Get-TelemetryGpuPanelSnapshot "$($Hw.MainGpuVendor)"
  $systemStorage = Get-TelemetryStorageSnapshot "$env:SystemDrive\"
  $gameStorage = Get-TelemetryStorageSnapshot $(if ($gamePathValid) { $GamePath } else { '' })
  $catalog = $script:LatestRestoreCatalog
  $catalogStatus = $(if ($catalog) { 'ok' } else { 'unavailable' })
  $gpuAdapters = @($Hw.Gpus | Select-Object -First 8 | ForEach-Object {
    [pscustomobject][ordered]@{
      vendor = "$($_.Vendor)"; model = "$($_.Name)"; modelVerified = [bool]$_.NameVerified
      reportedModelDiffers = [bool]("$($_.ReportedName)" -ne "$($_.Name)")
      driverVersion = "$($_.Driver)"; driverDate = "$($_.DriverDate)"
      virtualDisplay = [bool]$_.IsVirtualDisplay; displayActive = [bool]$_.DisplayActive
      displayMode = $(if ([int]$_.DisplayWidth -gt 0 -and [int]$_.DisplayHeight -gt 0) {
        "$([int]$_.DisplayWidth)x$([int]$_.DisplayHeight)@$([int]$_.DisplayRefreshHz)"
      } else { '' })
      main = [bool]("$($_.Pnp)" -and "$($_.Pnp)" -ieq "$($Hw.MainGpuPnp)")
      displayConnected = [bool]("$($_.Pnp)" -and "$($_.Pnp)" -ieq "$($Hw.DisplayGpuPnp)" -and [bool]$_.DisplayActive)
    }
  })
  $presentMonPath = Join-Path $script:RootDir 'tools\PresentMon.exe'
  [pscustomobject][ordered]@{
    schemaVersion = 1
    formFactor = $(if ("$($Hw.FormFactor)" -in 'desktop','laptop','unknown') { "$($Hw.FormFactor)" } else { 'unknown' })
    formFactorConfidence = $(if ("$($Hw.FormFactorConfidence)" -in 'high','medium','low') { "$($Hw.FormFactorConfidence)" } else { 'low' })
    chassisTypes = [int[]]@($Hw.ChassisTypes | Select-Object -First 8)
    hasBattery = $(if ($null -eq $Hw.HasBattery) { $null } else { [bool]$Hw.HasBattery })
    hasInternalDisplay = $(if ($null -eq $Hw.HasInternalDisplay) { $null } else { [bool]$Hw.HasInternalDisplay })
    upsAmbiguous = [bool]$Hw.IsUpsAmbiguous
    manufacturer = "$($Hw.ComputerManufacturer)"
    modelFamily = "$($Hw.ComputerModelFamily)"
    cpuEfficiencyClasses = [int[]]@($Hw.CpuEfficiencyClasses | Sort-Object -Unique | Select-Object -First 16)
    hybridCpu = [bool]$Hw.HybridCpu
    hypervisorPresent = $(if ($null -eq $Hw.HypervisorPresent) { $null } else { [bool]$Hw.HypervisorPresent })
    gpuAdapters = [object[]]$gpuAdapters
    displayAdapterVendor = "$($Hw.DisplayGpuVendor)"
    displayAdapterModel = "$($Hw.DisplayGpuName)"
    displayAdapterModelVerified = [bool]$Hw.DisplayGpuNameVerified
    hybridGraphics = [bool]$Hw.HybridGraphics
    activeDisplayCount = [math]::Min(16,[math]::Max(0,[int]$Hw.ActiveDisplayCount))
    internalDisplayCount = [math]::Min(16,[math]::Max(0,[int]$Hw.InternalDisplayCount))
    externalDisplayCount = [math]::Min(16,[math]::Max(0,[int]$Hw.ExternalDisplayCount))
    displayConnectors = [string[]]@($Hw.DisplayConnectors | Select-Object -First 8)
    windowsDisplayVersion = $osVersion
    windowsBuildRevision = $osUbr
    windowsReleaseChannel = Get-TelemetryWindowsChannel
    vbsState = "$($security.VbsState)"; memoryIntegrityState = "$($security.MemoryIntegrityState)"
    hagsState = $hagsState; gameModeState = $gameModeState; gameDvrState = $gameDvrState
    mpoState = $mpoState; windowedOptimizationState = $windowedState
    autoHdrState = $autoHdrState; vrrState = $vrrState; memoryCompressionState = $memoryCompressionState
    fsoState = $fsoState; gpuPreferenceState = $gpuPreferenceState
    optimizationScheme = "$($optimization.Scheme)"; optimizationItemIds = [string[]]@($optimization.ItemIds)
    optimizationItemSetHash = "$($optimization.ItemSetHash)"; optimizationItemsComplete = [bool]$optimization.ItemsComplete
    gpuPanelStatus = "$($panel.Status)"; gpuPanelInstalledKeys = [string[]]@($panel.InstalledKeys)
    gpuPanelMissingKeys = [string[]]@($panel.MissingKeys); activeSoftwareKeys = [string[]]@(Get-TelemetryActiveSoftwareKeys)
    restoreCatalogStatus = $catalogStatus
    activeBackupCount = $(if ($catalog) { [math]::Max(0,[int]$catalog.ActiveBackupCount) } else { 0 })
    activeRestoreItemCount = $(if ($catalog) { [math]::Max(0,[int]$catalog.ActiveItemCount) } else { 0 })
    activeRestoreOpCount = $(if ($catalog) { [math]::Max(0,[int]$catalog.ActiveOpCount) } else { 0 })
    legacyBackupCount = $(if ($catalog) { [math]::Max(0,[int]$catalog.LegacyBackupCount) } else { 0 })
    pendingBackupCount = $(if ($catalog) { [math]::Max(0,[int]$catalog.PendingBackupCount) } else { 0 })
    restoreConflictItemCount = $(if ($catalog) { [math]::Max(0,[int]$catalog.ConflictItemCount) } else { 0 })
    systemDriveMediaType = "$($systemStorage.MediaType)"; systemDriveBusType = "$($systemStorage.BusType)"
    systemDriveFreeGb = $systemStorage.FreeGb; gameDriveMediaType = "$($gameStorage.MediaType)"
    gameDriveBusType = "$($gameStorage.BusType)"; gameDriveFreeGb = $gameStorage.FreeGb
    activePowerPlanGuid = $activePowerPlanGuid; rebootPending = [bool]$rebootPending
    gameExeVersion = $gameVersion
    powerSource = $(if ("$($power.Source)" -in 'ac','battery','unknown') { "$($power.Source)" } else { 'unknown' })
    batteryPercent = $(if ($null -ne $power.BatteryPercent -and [int]$power.BatteryPercent -ge 0 -and [int]$power.BatteryPercent -le 100) { [int]$power.BatteryPercent } else { $null })
    vcRuntimeStatus = "$($vc.Status)"; vcRuntimeX64Version = "$($vc.X64Version)"
    vcRuntimeX86Version = "$($vc.X86Version)"; vcRuntimeComponentCount = [math]::Min(128,[math]::Max(0,[int]$vc.ComponentCount))
    captureCompatibilityStatus = $(if (Test-Path -LiteralPath $presentMonPath -PathType Leaf) { 'available' } else { 'missing_presentmon' })
  }
}

function ConvertTo-OptimizationTelemetryIds([object[]]$Values, [switch]$OperationIds) {
  $pattern = $(if ($OperationIds) { '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' } else { '^[a-z0-9][a-z0-9-]{0,63}$' })
  @($Values | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ -match $pattern } | Sort-Object -Unique)
}

function New-OptimizationTelemetryOperation {
  param(
    [Parameter(Mandatory)][ValidateSet('apply','restore')][string]$Event,
    [Parameter(Mandatory)][ValidateSet('manual_selection','frame_fix','restore_manager')][string]$Source,
    [Parameter(Mandatory)]$Reply,
    [string[]]$ItemIds = @(),
    [ValidateSet('not_applicable','selected_items','all')][string]$RestoreMode = 'not_applicable'
  )
  $itemIds = @(ConvertTo-OptimizationTelemetryIds $ItemIds)
  $succeeded = @(); $failed = @(); $skipped = @(); $attention = @(); $changed = @(); $reboot = @()
  $succeededUnits = 0; $failedUnits = 0; $skippedUnits = 0
  $backupStatus = 'not_required'; $verificationStatus = 'not_applicable'; $residualCount = 0
  $related = @(ConvertTo-OptimizationTelemetryIds @($Reply.ApplyIds) -OperationIds)
  if ($Event -eq 'apply') {
    if ($Source -eq 'restore_manager' -or $RestoreMode -ne 'not_applicable') { throw '优化操作来源或还原模式无效' }
    foreach ($row in @($Reply.Results)) {
      $id = @(ConvertTo-OptimizationTelemetryIds @($row.Id)) | Select-Object -First 1
      if (-not $id) { continue }
      if ($itemIds -notcontains $id) { $itemIds += $id; $itemIds = @($itemIds | Sort-Object -Unique) }
      if ([bool]$row.Attention) { $attention += $id }
      elseif ([bool]$row.Skipped) { $skipped += $id }
      elseif (-not [bool]$row.Ok) { $failed += $id }
      else {
        $succeeded += $id
        if ([bool]$row.Changed) { $changed += $id }
      }
    }
    $succeeded = @($succeeded | Sort-Object -Unique); $failed = @($failed | Sort-Object -Unique)
    $skipped = @($skipped | Sort-Object -Unique); $attention = @($attention | Sort-Object -Unique)
    $changed = @($changed | Sort-Object -Unique)
    $succeededUnits = $succeeded.Count; $failedUnits = $failed.Count; $skippedUnits = $skipped.Count
    if ($changed.Count -gt 0) {
      if ($Reply.BackupError) { $backupStatus = $(if ($Reply.Backup) { 'partial' } else { 'failed' }) }
      elseif ($Reply.Backup) { $backupStatus = 'created' }
      else { $backupStatus = 'not_available' }
    }
  } else {
    if ($Source -ne 'restore_manager' -or $RestoreMode -eq 'not_applicable') { throw '还原操作来源或还原模式无效' }
    if ($RestoreMode -eq 'selected_items') {
      foreach ($row in @($Reply.ItemResults)) {
        $id = @(ConvertTo-OptimizationTelemetryIds @($row.Id)) | Select-Object -First 1
        if (-not $id) { continue }
        if ([bool]$row.Ok) { $succeeded += $id; $changed += $id } else { $failed += $id }
      }
    } elseif (@($Reply.Failed).Count -eq 0) {
      $succeeded = @(ConvertTo-OptimizationTelemetryIds @($Reply.RestoredItemIds))
      $changed = @($succeeded)
    }
    $reboot = @(ConvertTo-OptimizationTelemetryIds @($Reply.RebootItemIds))
    $succeeded = @($succeeded | Sort-Object -Unique); $changed = @($changed | Sort-Object -Unique)
    $failed = @($failed | Sort-Object -Unique)
    $succeededUnits = [math]::Max(0, [int]$Reply.RestoredOps)
    $failedUnits = @($Reply.Failed).Count; $skippedUnits = @($Reply.Skipped).Count
    $residualCount = $failedUnits + $skippedUnits
    $verificationStatus = $(if ($failedUnits -gt 0) { 'failed' } elseif ($residualCount -gt 0) { 'residuals_detected' } elseif ($reboot.Count -gt 0) { 'pending_restart' } else { 'immediate_verified' })
  }
  $result = $(if ($succeededUnits -gt 0 -and ($failedUnits -gt 0 -or $skippedUnits -gt 0 -or $backupStatus -in 'partial','failed')) { 'partial' }
    elseif ($succeededUnits -gt 0) { 'succeeded' }
    elseif ($failedUnits -gt 0 -or $backupStatus -eq 'failed') { 'failed' }
    else { 'noop' })
  $operationId = "$($Reply.ApplyId)".Trim().ToLowerInvariant()
  if ($Event -eq 'restore' -or $operationId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') {
    $operationId = [guid]::NewGuid().ToString('D').ToLowerInvariant()
  }
  [pscustomobject][ordered]@{
    schemaVersion=1;operationId=$operationId;source=$Source;result=$result;itemIds=@($itemIds)
    changedItemIds=@($changed);succeededItemIds=@($succeeded);failedItemIds=@($failed)
    skippedItemIds=@($skipped);attentionItemIds=@($attention);rebootItemIds=@($reboot)
    relatedOperationIds=@($related);succeededUnitCount=[int]$succeededUnits;failedUnitCount=[int]$failedUnits
    skippedUnitCount=[int]$skippedUnits;backupStatus=$backupStatus;restoreMode=$RestoreMode
    verificationStatus=$verificationStatus;residualCount=[int]$residualCount
  }
}

function Update-TelemetryOptimizationContextFromCatalog {
  param(
    [Parameter(Mandatory)]$Catalog,
    [string]$RequestedScheme = 'unknown',
    [object[]]$RequestedItemIds = @(),
    [object[]]$KnownChangedItemIds = @(),
    [switch]$MutationIncomplete
  )
  $script:LatestRestoreCatalog = $Catalog
  $before = Get-TelemetryOptimizationContext
  $ids = @(ConvertTo-TelemetryOptimizationItemIds @($Catalog.ActiveItemIds))
  $hasActive = [bool]$Catalog.HasActiveChanges
  $complete = (-not $MutationIncomplete -and [int]$Catalog.LegacyBackupCount -eq 0)
  $scheme = "$RequestedScheme".ToLowerInvariant()
  if ($scheme -notin 'main','balanced','safe-only','custom','manual','frame-fix','auto-tuning') { $scheme = 'unknown' }
  if ($MutationIncomplete) {
    # 备份写入中断时，目录只包含成功落盘的那部分操作。Reply.Results 中仍可确定
    # 哪些项目已经实际改变，把这些 ID 合并进来但保持 incomplete，避免误报为基线。
    $ids = @(ConvertTo-TelemetryOptimizationItemIds (@($ids) + @($KnownChangedItemIds)))
  }
  if (-not $hasActive) {
    if ($MutationIncomplete) {
      $scheme = $(if ($ids.Count -gt 0 -and $scheme -ne 'unknown') { $scheme } else { 'legacy-unknown' })
      $complete = $false
    } elseif (-not [bool]$before.ItemsComplete) {
      # 空目录只证明“没有可由当前目录精确还原的记录”，并不能证明旧版或备份失败
      # 留下的未知改动已经消失。保留不完整上下文，避免重启后把它洗成基线样本。
      $ids = @($before.ItemIds); $scheme = "$($before.Scheme)"; $complete = $false
    } else {
      $ids = @(); $scheme = 'baseline'; $complete = $true
    }
  } elseif ($ids.Count -eq 0) {
    $scheme = 'legacy-unknown'; $complete = $false
  } elseif (-not $complete) {
    $scheme = 'mixed'
  } elseif ($scheme -ne 'unknown') {
    $targets = @(ConvertTo-TelemetryOptimizationItemIds $RequestedItemIds)
    if ($targets.Count -eq 0 -or @($ids | Where-Object { $targets -notcontains $_ }).Count -gt 0) { $scheme = 'mixed' }
  } elseif ($before.ItemSetHash -eq (Get-TelemetryOptimizationItemSetHash $ids)) {
    $scheme = "$($before.Scheme)"
  } else { $scheme = 'mixed' }
  Set-TelemetryOptimizationContext -ItemIds $ids -Scheme $scheme -ItemsComplete $complete -FallbackTier "$($before.ConfigTier)"
}

function Send-AnonymousTelemetry([string]$Event, $Hw, [int]$Ok = 0, [int]$Failed = 0, $Operation = $null) {
  try {
    if (-not $Hw -or $Event -notin 'launch','apply','restore') { return }
    $installId = Get-TelemetryInstallId
    if (-not $installId) { return }
    Clear-CompletedTelemetryJobs
    $payload = [ordered]@{
      installId = $installId
      event      = $Event
      version    = $script:GuiVersion
      os         = "$($Hw.OS)"
      build      = "$($Hw.Build)"
      cpu        = "$($Hw.CPU)"
      gpuVendor  = "$($Hw.MainGpuVendor)"
      gpuModel   = "$($Hw.MainGpuName)"
      gpuModelVerified = [bool]$Hw.MainGpuNameVerified
      driverVersion = Get-TelemetryMainGpuDriver $Hw
      gpuCount   = [math]::Min(16, @($Hw.Gpus).Count)
      displayMode = Get-TelemetryDisplayMode $Hw
      ramGb      = [double]$Hw.RamGB
      deviceType = $(if ("$($Hw.FormFactor)" -in 'desktop','laptop','unknown') { "$($Hw.FormFactor)" }
        elseif ($Hw.IsLaptop) { 'laptop' } else { 'unknown' })
      cpuCores   = [math]::Max(0, [int]$Hw.Cores)
      cpuThreads = [math]::Max(0, [int]$Hw.Threads)
      cpuPackages = [math]::Max(0, [int]$Hw.CpuPackages)
      memoryType = "$($Hw.MemoryType)"
      memoryConfiguredMhz = [math]::Max(0, [int]$Hw.MemoryConfiguredMHz)
      memoryRatedMhz = [math]::Max(0, [int]$Hw.MemoryRatedMHz)
      memoryModuleCount = [math]::Max(0, [int]$Hw.MemoryModuleCount)
      virtualDisplayCount = [math]::Min(16, [math]::Max(0, [int]$Hw.VirtualDisplayCount))
      pagefileAutoManaged = [bool]$Hw.AutomaticManagedPagefile
      gpuReportedModelDiffers = [bool]("$($Hw.MainGpuReportedName)" -ne "$($Hw.MainGpuName)")
      ok         = [math]::Max(0, $Ok)
      failed     = [math]::Max(0, $Failed)
    }
    $analysisContext = Get-TelemetryAnalysisContext $Hw $script:TargetExe
    if ($analysisContext) { $payload.analysisContext = $analysisContext }
    if ($Operation) { $payload.operation = $Operation }
    if (-not (Get-Command Send-DfbTelemetryEvent -ErrorAction SilentlyContinue)) { return }
    $body = $payload | ConvertTo-Json -Compress -Depth 6
    $configPath = Join-Path $script:UserConfigDir 'telemetry.json'
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($ModulePath, $Url, $Body, $ConfigPath)
      try {
        . $ModulePath
        $payload = $Body | ConvertFrom-Json
        Send-DfbTelemetryEvent -UploadUrl $Url -Payload $payload -ConfigPath $ConfigPath | Out-Null
      } catch {}
    }).AddArgument($script:TelemetryClientPath).AddArgument($script:TelemetryUploadUrl).AddArgument($body).AddArgument($configPath)
    $async = $ps.BeginInvoke()
    [void]$script:TelemetryJobs.Add([pscustomobject]@{ PowerShell = $ps; Async = $async })
  } catch {}
}

# ---------- 游戏性能记录（一次会话只采样一段，不常驻逐帧记录） ----------

$script:PerformanceJobs = New-Object System.Collections.ArrayList
$script:MonitoredGamePids = @{}
$script:PerformanceSampleSeconds = 120
$script:PerformanceWarmupSeconds = 20

# Windows PowerShell 5.1 会把 ConvertFrom-Json 的顶层数组保留成单个管道对象。旧版连续
# 写入第三段记录后，数组可能被序列化成带 value/Count 的嵌套包装；递归展开可兼容修复
# 已经产生的本地文件，并让诊断报告始终拿到平坦的会话列表。
function Expand-PerformanceSessions([object]$Value) {
  foreach ($entry in @($Value)) {
    if ($null -eq $entry) { continue }
    if ($entry.PSObject.Properties['recordedAt']) { Write-Output $entry; continue }
    $wrapped = $entry.PSObject.Properties['value']
    if ($wrapped) { Expand-PerformanceSessions $wrapped.Value }
  }
}

function Get-PerformanceSessionTimestamp($Session) {
  try {
    [DateTimeOffset]::Parse("$($Session.recordedAt)",[Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind)
  } catch { [DateTimeOffset]::MinValue }
}

function Test-PerformanceSessionValid($Session) {
  if (-not $Session) { return $false }
  if ($Session.PSObject.Properties['validity']) { return "$($Session.validity)" -eq 'valid' }
  try {
    return (-not [bool]$Session.captureFailed -and -not [bool]$Session.gameExitedEarly -and
      [int]$Session.durationSec -ge 90 -and [int64]$Session.frameCount -ge 1000 -and
      [double]$Session.avgFps -gt 0 -and [double]$Session.fps1Low -gt 0)
  } catch { $false }
}

function Get-PerformanceSessionDisplayMode($Session) {
  try {
    $adapters = @($Session.analysisContext.gpuAdapters)
    $adapter = @($adapters | Where-Object { [bool]$_.main -and "$($_.displayMode)" } | Select-Object -First 1)
    if (-not $adapter.Count) { $adapter = @($adapters | Where-Object { "$($_.displayMode)" } | Select-Object -First 1) }
    if ($adapter.Count) { return "$($adapter[0].displayMode)".Trim().ToLowerInvariant() }
  } catch {}
  ''
}

function Get-PerformanceSessionToolState($Session) {
  if (-not $Session) { return 'unknown' }
  $tier = "$($Session.configTier)".Trim().ToLowerInvariant()
  $scheme = "$($Session.optimizationScheme)".Trim().ToLowerInvariant()
  $hash = "$($Session.optimizationItemSetHash)".Trim()
  if ($tier -eq 'baseline' -and $scheme -in '','baseline' -and -not $hash) { return 'baseline' }
  if ($hash -or $tier -in 'light','balanced','full' -or
      ($scheme -and $scheme -ne 'baseline')) { return 'managed' }
  'unknown'
}

function Get-PerformanceSessionToolStateLabel($Session) {
  switch (Get-PerformanceSessionToolState $Session) {
    'baseline' { '未使用工具' }
    'managed' { '已应用工具' }
    default { '状态未知' }
  }
}

function Get-PerformanceSessionComparisonConfidence($Before, $After) {
  if (-not $Before -or -not $After) { return 'incompatible' }
  $missing = $false
  $beforeGpu = "$($Before.gpuModel)".Trim(); $afterGpu = "$($After.gpuModel)".Trim()
  if ($beforeGpu -and $afterGpu) {
    if ($beforeGpu -ine $afterGpu) { return 'incompatible' }
  } else { $missing = $true }

  foreach ($values in @(
    @("$($Before.analysisContext.gameExeVersion)".Trim(),"$($After.analysisContext.gameExeVersion)".Trim()),
    @((Get-PerformanceSessionDisplayMode $Before),(Get-PerformanceSessionDisplayMode $After))
  )) {
    if ($values[0] -and $values[1]) {
      if ($values[0] -ine $values[1]) { return 'incompatible' }
    } else { $missing = $true }
  }
  $beforePower = "$($Before.analysisContext.powerSource)".Trim().ToLowerInvariant()
  $afterPower = "$($After.analysisContext.powerSource)".Trim().ToLowerInvariant()
  if ($beforePower -in 'ac','battery' -and $afterPower -in 'ac','battery') {
    if ($beforePower -ne $afterPower) { return 'incompatible' }
  } else { $missing = $true }
  $(if ($missing) { 'reference' } else { 'comparable' })
}

function Select-PerformanceComparisonPair([object[]]$Sessions, $OptimizationContext) {
  $valid = @($Sessions | Where-Object { Test-PerformanceSessionValid $_ } |
    Where-Object { (Get-PerformanceSessionTimestamp $_) -ne [DateTimeOffset]::MinValue })
  if (-not $valid.Count) {
    return [pscustomobject]@{Status='no_sessions';Before=$null;After=$null;Confidence='';PairKind=''}
  }
  $desiredHash = "$($OptimizationContext.ItemSetHash)".Trim().ToLowerInvariant()
  if ($desiredHash) {
    $currentCandidates = @($valid | Where-Object {
      "$($_.optimizationItemSetHash)".Trim().ToLowerInvariant() -eq $desiredHash
    })
  } else {
    # 当前没有由工具管理的改动时，只比较两次“未使用工具”记录。不要把旧优化记录
    # 冒充成当前状态，更不要在卡片上暗示用户已经执行过优化。
    $currentCandidates = @($valid | Where-Object { (Get-PerformanceSessionToolState $_) -eq 'baseline' })
  }
  if (-not $currentCandidates.Count) {
    return [pscustomobject]@{Status='waiting_current';Before=$null;After=$null;Confidence='';PairKind=''}
  }

  $hadEarlierCandidate = $false
  foreach ($after in @($currentCandidates | Sort-Object { Get-PerformanceSessionTimestamp $_ } -Descending)) {
    $afterTime = Get-PerformanceSessionTimestamp $after
    $beforeCandidates = @()
    if ($desiredHash) {
      # 优先用同环境的未使用工具记录作为参照；没有时再退回同一优化状态的上一条记录。
      $beforeCandidates += @($valid | Where-Object {
        (Get-PerformanceSessionToolState $_) -eq 'baseline' -and
        (Get-PerformanceSessionTimestamp $_) -lt $afterTime
      } | Sort-Object { Get-PerformanceSessionTimestamp $_ } -Descending)
    }
    $beforeCandidates += @($currentCandidates | Where-Object {
      (Get-PerformanceSessionTimestamp $_) -lt $afterTime
    } | Sort-Object { Get-PerformanceSessionTimestamp $_ } -Descending)
    foreach ($before in $beforeCandidates) {
      $hadEarlierCandidate = $true
      $confidence = Get-PerformanceSessionComparisonConfidence $before $after
      if ($confidence -ne 'incompatible') {
        $pairKind = $(if ((Get-PerformanceSessionToolState $before) -eq 'baseline' -and
            (Get-PerformanceSessionToolState $after) -eq 'managed') { 'tool_change' } else { 'history' })
        return [pscustomobject]@{
          Status='paired';Before=$before;After=$after;Confidence=$confidence;PairKind=$pairKind
        }
      }
    }
  }
  if ($hadEarlierCandidate) {
    return [pscustomobject]@{Status='environment_mismatch';Before=$null;After=$null;Confidence='';PairKind=''}
  }
  [pscustomobject]@{Status='waiting_next';Before=$null;After=$null;Confidence='';PairKind=''}
}

function Get-PerformanceComparisonMetricValue($Session, [string]$Key) {
  if (-not $Session) { return $null }
  $value = switch ($Key) {
    'fps' { $Session.avgFps }
    'cpu' { $Session.performanceContext.processCpuAvgPct }
    'gpu' { $Session.gpuUtilAvg }
    'memory' { $Session.performanceContext.systemMemoryUsedAvgPct }
    default { $null }
  }
  if ($null -eq $value -or "$value" -eq '') { return $null }
  try {
    $number = [double]$value
    if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0) { return $null }
    $number
  } catch { $null }
}

$script:PerformanceComparisonCacheKey = ''
function Refresh-PerformanceComparison([switch]$Force) {
  $path = Join-Path $script:UserConfigDir 'performance-sessions.json'
  $context = Get-TelemetryOptimizationContext
  $stamp = ''
  try {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $file = Get-Item -LiteralPath $path -Force
      $stamp = "$($file.LastWriteTimeUtc.Ticks):$($file.Length)"
    }
  } catch {}
  $cacheKey = "$stamp|$($context.ItemSetHash)"
  if (-not $Force -and $cacheKey -eq $script:PerformanceComparisonCacheKey) { return }
  $script:PerformanceComparisonCacheKey = $cacheKey

  $sessions = @()
  try {
    if ($stamp) {
      $file = Get-Item -LiteralPath $path -Force
      if ($file.Length -gt 0 -and $file.Length -le 4MB) {
        $sessions = @(Expand-PerformanceSessions (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json))
      }
    }
  } catch { $sessions = @() }
  $pair = Select-PerformanceComparisonPair $sessions $context
  if ($pair.Status -ne 'paired') {
    $emptyText = switch ($pair.Status) {
      'waiting_current' { '等待当前状态记录' }
      'waiting_next' { '等待下一次记录' }
      'environment_mismatch' { '暂无同环境记录' }
      default { '暂无历史记录' }
    }
    foreach ($key in 'fps','cpu','gpu','memory') {
      Set-LiveMetricComparison -Key $key -Before $null -After $null -EmptyText $emptyText `
        -Tooltip '取得两段同环境的有效游戏记录后，这里会显示记录变化；是否使用过工具不会改变文案。'
    }
    return
  }

  $beforeTime = (Get-PerformanceSessionTimestamp $pair.Before).ToLocalTime().ToString('MM-dd HH:mm')
  $afterTime = (Get-PerformanceSessionTimestamp $pair.After).ToLocalTime().ToString('MM-dd HH:mm')
  $confidenceText = $(if ($pair.Confidence -eq 'comparable') {
      '硬件、游戏版本、桌面显示模式和供电状态一致；游戏内设置与场景仍需保持一致'
    } else { '部分环境字段缺失，变化仅供参考' })
  $prefix = '变化'
  $beforeState = Get-PerformanceSessionToolStateLabel $pair.Before
  $afterState = Get-PerformanceSessionToolStateLabel $pair.After
  $definitions = @(
    @('fps','percent','平均 FPS'),
    @('cpu','points','游戏进程 CPU 平均占用'),
    @('gpu','points','GPU 平均占用'),
    @('memory','points','系统内存平均占用')
  )
  foreach ($definition in $definitions) {
    $key = $definition[0]
    $beforeValue = Get-PerformanceComparisonMetricValue $pair.Before $key
    $afterValue = Get-PerformanceComparisonMetricValue $pair.After $key
    $tooltip = "$($definition[2])：前一条 $beforeValue → 后一条 $afterValue。记录时间 $beforeTime / $afterTime；状态 $beforeState → $afterState；$confidenceText。"
    Set-LiveMetricComparison -Key $key -Before $beforeValue -After $afterValue -Mode $definition[1] `
      -Prefix $prefix -Tooltip $tooltip -EmptyText '该指标暂无记录'
  }
}

function Get-PerformanceMetricHistoryDefinition([string]$Key) {
  switch ($Key) {
    'fps' { [pscustomobject]@{Title='FPS 历史记录';Label='平均 FPS';Unit='帧'} }
    'cpu' { [pscustomobject]@{Title='CPU 占用历史记录';Label='游戏进程 CPU 平均占用';Unit='%'} }
    'gpu' { [pscustomobject]@{Title='GPU 占用历史记录';Label='GPU 平均占用';Unit='%'} }
    'memory' { [pscustomobject]@{Title='内存占用历史记录';Label='系统内存平均占用';Unit='%'} }
    default { $null }
  }
}

function Get-PerformanceMetricHistoryRows([object[]]$Sessions, [string]$Key) {
  $definition = Get-PerformanceMetricHistoryDefinition $Key
  if (-not $definition) { return @() }
  $rows = New-Object System.Collections.ArrayList
  foreach ($session in @($Sessions | Where-Object { Test-PerformanceSessionValid $_ } |
      Sort-Object { Get-PerformanceSessionTimestamp $_ } -Descending)) {
    $timestamp = Get-PerformanceSessionTimestamp $session
    $value = Get-PerformanceComparisonMetricValue $session $Key
    if ($timestamp -eq [DateTimeOffset]::MinValue -or $null -eq $value) { continue }
    $parts = New-Object System.Collections.Generic.List[string]
    $gpu = "$($session.gpuModel)".Trim()
    $displayMode = Get-PerformanceSessionDisplayMode $session
    $gameVersion = "$($session.analysisContext.gameExeVersion)".Trim()
    if ($gpu) { $parts.Add($gpu) }
    if ($displayMode) { $parts.Add($displayMode.ToUpperInvariant()) }
    if ($gameVersion) { $parts.Add("游戏 $gameVersion") }
    [void]$rows.Add([pscustomobject]@{
      TimeText=$timestamp.ToLocalTime().ToString('yyyy-MM-dd HH:mm')
      Value=[double]$value
      ValueText=("{0:N1} {1}" -f [double]$value,$definition.Unit)
      State=(Get-PerformanceSessionToolState $session)
      StateText=(Get-PerformanceSessionToolStateLabel $session)
      ContextText=($parts -join ' · ')
    })
    if ($rows.Count -ge 50) { break }
  }
  @($rows)
}

function Show-PerformanceMetricHistory([string]$Key) {
  $definition = Get-PerformanceMetricHistoryDefinition $Key
  if (-not $definition) { return }
  $sessions = @()
  $path = Join-Path $script:UserConfigDir 'performance-sessions.json'
  try {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $file = Get-Item -LiteralPath $path -Force
      if ($file.Length -gt 0 -and $file.Length -le 4MB) {
        $sessions = @(Expand-PerformanceSessions (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json))
      }
    }
  } catch { $sessions = @() }
  $rows = @(Get-PerformanceMetricHistoryRows $sessions $Key)

  $historyXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="560" Height="620" MinHeight="420" WindowStyle="None" ResizeMode="CanResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <Grid>
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Border x:Name="DragBar" Grid.Row="0" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="14,10">
      <DockPanel><TextBlock Text="性能历史" Foreground="{DynamicResource TextPri}" FontSize="14" FontWeight="Bold"/><TextBlock Text="  PERFORMANCE HISTORY" Foreground="{DynamicResource Green}" FontFamily="Consolas" FontSize="10" VerticalAlignment="Center"/></DockPanel>
    </Border>
    <StackPanel Grid.Row="1" Margin="16,14,16,9">
      <TextBlock x:Name="MetricTitle" Foreground="{DynamicResource Green}" FontSize="16" FontWeight="Bold"/>
      <TextBlock x:Name="StatusText" Foreground="{DynamicResource TextSec}" Margin="0,5,0,0" TextWrapping="Wrap"/>
    </StackPanel>
    <ScrollViewer Grid.Row="2" Margin="12,0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <StackPanel x:Name="ItemsPanel" Margin="4,2,4,8"/>
    </ScrollViewer>
    <Border Grid.Row="3" BorderBrush="{DynamicResource Line}" BorderThickness="0,1,0,0" Padding="14,11">
      <Button x:Name="CloseButton" Content="关闭" Width="92" Height="30" HorizontalAlignment="Right" Background="{DynamicResource Green}" Foreground="{DynamicResource GreenDark}" BorderThickness="0" FontWeight="Bold" Cursor="Hand"/>
    </Border>
  </Grid>
</Window>
'@
  $dialog = [Windows.Markup.XamlReader]::Parse($historyXaml)
  $dialog.Resources.MergedDictionaries.Add($script:ThemeRes)
  $dialog.Owner = $window
  $dialog.FindName('MetricTitle').Text = $definition.Title
  $dialog.FindName('StatusText').Text = "共 $($rows.Count) 条有效记录 · 按时间倒序 · 未使用工具的记录也会保留并明确标注"
  $panel = $dialog.FindName('ItemsPanel')
  if (-not $rows.Count) {
    $empty = New-Text '暂无有效历史记录。运行游戏并保持一段稳定对局后，这里会自动出现记录。' $script:C.TextSec 13
    $empty.TextWrapping = 'Wrap'; $empty.HorizontalAlignment = 'Center'; $empty.Margin = '18,70,18,0'
    [void]$panel.Children.Add($empty)
  } else {
    foreach ($row in $rows) {
      $card = New-Object Windows.Controls.Border
      $card.Background = New-Brush $script:C.Panel
      $card.BorderBrush = New-Brush $script:C.Line
      $card.BorderThickness = '1'; $card.Padding = '12,10'; $card.Margin = '0,0,0,8'
      $stack = New-Object Windows.Controls.StackPanel
      $meta = New-Object Windows.Controls.DockPanel
      $stateColor = switch ($row.State) { 'managed' { $script:C.Green } 'baseline' { $script:C.Gold } default { $script:C.TextMut } }
      $state = New-Text $row.StateText $stateColor 10 -Mono
      $state.SetValue([Windows.Controls.DockPanel]::DockProperty,[Windows.Controls.Dock]::Right)
      $time = New-Text $row.TimeText $script:C.TextMut 10 -Mono
      [void]$meta.Children.Add($state); [void]$meta.Children.Add($time); [void]$stack.Children.Add($meta)
      $valueText = New-Text ("$($definition.Label)  $($row.ValueText)") $script:C.TextPri 14 -Mono
      $valueText.FontWeight = 'Bold'; $valueText.Margin = '0,7,0,0'
      [void]$stack.Children.Add($valueText)
      if ($row.ContextText) {
        $contextText = New-Text $row.ContextText $script:C.TextSec 10 -Mono
        $contextText.TextWrapping = 'Wrap'; $contextText.Margin = '0,5,0,0'
        [void]$stack.Children.Add($contextText)
      }
      $card.Child = $stack; [void]$panel.Children.Add($card)
    }
  }
  $dialog.FindName('DragBar').Add_MouseLeftButtonDown({ $dialog.DragMove() })
  $dialog.FindName('CloseButton').Add_Click({ $dialog.Close() })
  [void]$dialog.ShowDialog()
}

$script:PerformanceCaptureWorker = {
  param($GamePid, $PresentMon, $SessionFile, $TelemetryModule, $TelemetryConfigPath,
        $UploadUrl, $InstallId, $Version,
        $GpuVendor, $GpuModel, $GpuVerified, $GpuPciLocation, $NvidiaSmi,
        $ConfigTier, $OptimizationScheme, $OptimizationItemSetHash, $OptimizationItemIdsCsv,
        $OptimizationItemsComplete, $WarmupSeconds, $SampleSeconds, $CaptureMode,
        $AnalysisContextJson, $PresentMonVersion)
  $ErrorActionPreference = 'SilentlyContinue'
  $OptimizationItemIds = @("$OptimizationItemIdsCsv" -split ',' | Where-Object { $_ })

  function Get-Number([object]$Value) {
    $n = 0.0
    if ([double]::TryParse("$Value", [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
    $null
  }
  function Get-Average($Values) {
    $clean = @($Values | Where-Object { $null -ne $_ })
    if (-not $clean.Count) { return $null }
    [math]::Round(($clean | Measure-Object -Average).Average, 1)
  }
  function Get-Maximum($Values) {
    $clean = @($Values | Where-Object { $null -ne $_ })
    if (-not $clean.Count) { return $null }
    [math]::Round(($clean | Measure-Object -Maximum).Maximum, 1)
  }
  function Get-Minimum($Values) {
    $clean = @($Values | Where-Object { $null -ne $_ })
    if (-not $clean.Count) { return $null }
    [math]::Round(($clean | Measure-Object -Minimum).Minimum, 1)
  }
  function Get-Median($Values) {
    $clean = @($Values | ForEach-Object { [double]$_ } | Sort-Object)
    if (-not $clean.Count) { return 0.0 }
    $mid = [math]::Floor($clean.Count / 2)
    if ($clean.Count % 2) { return [double]$clean[$mid] }
    ([double]$clean[$mid - 1] + [double]$clean[$mid]) / 2.0
  }
  function Get-Percentile($Values, [double]$Fraction) {
    $clean = @($Values | ForEach-Object { [double]$_ } | Sort-Object)
    if (-not $clean.Count) { return 0.0 }
    $index = [math]::Min($clean.Count - 1, [math]::Max(0, [math]::Ceiling($clean.Count * $Fraction) - 1))
    [double]$clean[$index]
  }
  function Get-FrameSummary($Values) {
    $clean = @($Values | ForEach-Object { [double]$_ } | Where-Object { $_ -gt 0 -and $_ -le 1000 })
    if ($clean.Count -lt 30) {
      return [pscustomobject]@{ Count=[int]$clean.Count;AvgFps=$null;Fps1Low=$null;P50FrameMs=$null
        P90FrameMs=$null;P95FrameMs=$null;P99FrameMs=$null;MadMs=$null;CvPct=$null }
    }
    $avgMs = ($clean | Measure-Object -Average).Average
    $slowCount = [math]::Max(1, [math]::Ceiling($clean.Count * 0.01))
    $avgSlowMs = (@($clean | Sort-Object -Descending | Select-Object -First $slowCount) | Measure-Object -Average).Average
    $median = Get-Median $clean
    $variance = (@($clean | ForEach-Object { [math]::Pow([double]$_ - $avgMs, 2) }) | Measure-Object -Average).Average
    [pscustomobject]@{
      Count = [int]$clean.Count
      AvgFps = $(if ($avgMs -gt 0) { [math]::Round(1000.0 / $avgMs,1) } else { $null })
      Fps1Low = $(if ($avgSlowMs -gt 0) { [math]::Round(1000.0 / $avgSlowMs,1) } else { $null })
      P50FrameMs = [math]::Round((Get-Percentile $clean 0.50),2)
      P90FrameMs = [math]::Round((Get-Percentile $clean 0.90),2)
      P95FrameMs = [math]::Round((Get-Percentile $clean 0.95),2)
      P99FrameMs = [math]::Round((Get-Percentile $clean 0.99),2)
      MadMs = [math]::Round((Get-Median @($clean | ForEach-Object { [math]::Abs([double]$_ - $median) })),2)
      CvPct = $(if ($avgMs -gt 0) { [math]::Round([math]::Sqrt([math]::Max(0,$variance))*100.0/$avgMs,2) } else { $null })
    }
  }
  function Get-RowNumber($Row, [string[]]$Names) {
    foreach ($name in $Names) {
      if ($Row.PSObject.Properties[$name]) {
        $number = Get-Number $Row.$name
        if ($null -ne $number) { return $number }
      }
    }
    $null
  }
  function ConvertTo-Distribution($Counter, [int]$Limit = 12) {
    $out = [ordered]@{}
    foreach ($entry in @($Counter.GetEnumerator() |
      Sort-Object @{Expression='Value';Descending=$true},@{Expression='Name';Descending=$false} |
      Select-Object -First $Limit)) {
      $name = ("$($entry.Name)" -replace '[\x00-\x1f\x7f]',' ').Trim()
      if ($name.Length -gt 48) { $name = $name.Substring(0,48) }
      if ($name) { $out[$name] = [int]$entry.Value }
    }
    [pscustomobject]$out
  }
  function Get-CapturePowerSnapshot {
    try {
      if (-not ('DfbCapturePowerStatus' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DfbCapturePowerStatus {
  [StructLayout(LayoutKind.Sequential)] public struct S {
    public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
    public uint BatteryLifeTime, BatteryFullLifeTime;
  }
  [DllImport("kernel32.dll")] static extern bool GetSystemPowerStatus(out S value);
  public static S Read() { S value; if (!GetSystemPowerStatus(out value)) throw new InvalidOperationException(); return value; }
}
'@
      }
      $value = [DfbCapturePowerStatus]::Read()
      [pscustomobject]@{
        Source=$(if($value.ACLineStatus -eq 1){'ac'}elseif($value.ACLineStatus -eq 0){'battery'}else{'unknown'})
        BatteryPercent=$(if($value.BatteryLifePercent -le 100){[int]$value.BatteryLifePercent}else{$null})
      }
    } catch { [pscustomobject]@{Source='unknown';BatteryPercent=$null} }
  }
  function Get-CaptureMemorySnapshot {
    try {
      if (-not ('DfbMemoryStatus' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DfbMemoryStatus {
  [StructLayout(LayoutKind.Sequential)] public class S {
    public uint Length = (uint)Marshal.SizeOf(typeof(S)); public uint MemoryLoad;
    public ulong TotalPhys, AvailPhys, TotalPageFile, AvailPageFile, TotalVirtual, AvailVirtual, AvailExtendedVirtual;
  }
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool GlobalMemoryStatusEx([In, Out] S value);
  public static S Read() { var value = new S(); if (!GlobalMemoryStatusEx(value)) throw new InvalidOperationException(); return value; }
}
'@
      }
      $value = [DfbMemoryStatus]::Read()
      [pscustomobject]@{
        UsedPct = [double]$value.MemoryLoad
        AvailableMb = [math]::Round([double]$value.AvailPhys / 1MB,1)
        CommitUsedPct = $(if ($value.TotalPageFile -gt 0) {
          [math]::Round(([double]($value.TotalPageFile-$value.AvailPageFile))*100.0/[double]$value.TotalPageFile,1)
        } else { $null })
      }
    } catch { $null }
  }
  function Expand-PerformanceSessions([object]$Value) {
    foreach ($entry in @($Value)) {
      if ($null -eq $entry) { continue }
      if ($entry.PSObject.Properties['recordedAt']) { Write-Output $entry; continue }
      $wrapped = $entry.PSObject.Properties['value']
      if ($wrapped) { Expand-PerformanceSessions $wrapped.Value }
    }
  }
  function New-FailedCapture([string]$Reason, [bool]$Exited) {
    $analysisContext = $null
    try { if ($AnalysisContextJson) { $analysisContext = $AnalysisContextJson | ConvertFrom-Json } } catch {}
    [pscustomobject][ordered]@{
      recordedAt = [DateTime]::UtcNow.ToString('o'); startedAt = [DateTime]::UtcNow.ToString('o')
      completedAt = [DateTime]::UtcNow.ToString('o'); durationSec = 0; frameCount = 0
      gpuModel = "$GpuModel"; configTier = "$ConfigTier"; optimizationScheme = "$OptimizationScheme"
      optimizationItemSetHash = "$OptimizationItemSetHash"; optimizationItemIds = @($OptimizationItemIds)
      optimizationItemsComplete = [bool]$OptimizationItemsComplete; avgFps = 0.0; fps1Low = 0.0
      p99FrameMs = 0.0; frameTimeMadMs = 0.0; stutter50Ms = 0; stutter100Ms = 0
      stuttersPerMin = 0.0; focusLostSec = 0.0; gpuUtilAvg = $null; gpuUtilMax = $null
      gpuTempAvg = $null; gpuTempMax = $null; gpuPowerAvg = $null; gpuPowerMax = $null
      presentMonExitCode = -1; gameExitedEarly = [bool]$Exited; captureFailed = $true; captureError = $Reason
      validity = 'invalid'; invalidReason = $(if ($Exited) { 'game_exited' } else { 'capture_failed' })
      analysisContext = $analysisContext; performanceContext = $null
    }
  }

  for ($i = 0; $i -lt $WarmupSeconds; $i++) {
    if (-not (Get-Process -Id $GamePid -ErrorAction SilentlyContinue)) {
      if ($CaptureMode -eq 'experiment') { New-FailedCapture '游戏在预热期退出' $true }
      return
    }
    Start-Sleep -Seconds 1
  }

  $startedUtc = [DateTime]::UtcNow
  $started = Get-Date
  $powerStart = Get-CapturePowerSnapshot
  $tmp = Join-Path ([IO.Path]::GetTempPath()) "dfb-presentmon-$GamePid-$([guid]::NewGuid().ToString('N')).csv"
  try {
    # PresentMon must not inherit the product root as CWD.  A capture can outlive an abrupt GUI
    # exit; inheriting that directory would keep it locked and make the transactional updater fail.
    $pm = Start-Process -FilePath $PresentMon -WorkingDirectory ([Environment]::SystemDirectory) -WindowStyle Hidden -PassThru -ArgumentList @(
      '--process_id', "$GamePid", '--output_file', "`"$tmp`"", '--timed', "$SampleSeconds",
      '--terminate_after_timed', '--terminate_on_proc_exit', '--no_console_stats',
      '--v2_metrics', '--track_frame_type', '--track_hybrid_present',
      '--session_name', "DFB-$GamePid-$([guid]::NewGuid().ToString('N'))")
  } catch {
    if ($CaptureMode -eq 'experiment') { New-FailedCapture "PresentMon 启动失败：$($_.Exception.Message)" $false }
    return
  }

  try {
    if (-not ('DfbForegroundWindow' -as [type])) {
      Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DfbForegroundWindow {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
'@
    }
  } catch {}

  $util = @(); $temp = @(); $power = @(); $focusLostSec = 0.0
  $processCpu = @(); $gameWorkingSetMb = @(); $gamePrivateMb = @()
  $systemMemoryUsed = @(); $systemMemoryAvailableMb = @(); $systemCommitUsed = @()
  $gpuDedicatedMb = @(); $gpuSharedMb = @(); $gpuMemorySource = 'unavailable'
  $utilSource = 'unavailable'; $tempSource = 'unavailable'; $powerSource = 'unavailable'
  $loopSamples = 0; $gameRenderAdapterLuid = ''; $gameRenderAdapterPhysicalIndex = $null
  $gameExitedEarly = $false; $lastLoop = Get-Date
  $lastGameCpuSeconds = $null; $lastGameCpuAt = $null
  $logicalProcessors = [math]::Max(1,[Environment]::ProcessorCount)
  while ($pm -and -not $pm.HasExited -and ((Get-Date) - $started).TotalSeconds -lt ($SampleSeconds + 15)) {
    $loopSamples++
    $now = Get-Date; $elapsed = [math]::Max(0, ($now - $lastLoop).TotalSeconds); $lastLoop = $now
    $gameProcess = Get-Process -Id $GamePid -ErrorAction SilentlyContinue
    if (-not $gameProcess) { $gameExitedEarly = $true; break }
    try {
      $cpuSeconds = [double]$gameProcess.TotalProcessorTime.TotalSeconds
      if ($null -ne $lastGameCpuSeconds -and $lastGameCpuAt) {
        $cpuElapsed = [math]::Max(0.001,($now-$lastGameCpuAt).TotalSeconds)
        $cpuPct = [math]::Min(100.0,[math]::Max(0.0,($cpuSeconds-$lastGameCpuSeconds)*100.0/$cpuElapsed/$logicalProcessors))
        $processCpu += $cpuPct
      }
      $lastGameCpuSeconds = $cpuSeconds; $lastGameCpuAt = $now
      $gameWorkingSetMb += [double]$gameProcess.WorkingSet64 / 1MB
      $gamePrivateMb += [double]$gameProcess.PrivateMemorySize64 / 1MB
    } catch {}
    $memorySnapshot = Get-CaptureMemorySnapshot
    if ($memorySnapshot) {
      $systemMemoryUsed += [double]$memorySnapshot.UsedPct
      $systemMemoryAvailableMb += [double]$memorySnapshot.AvailableMb
      if ($null -ne $memorySnapshot.CommitUsedPct) { $systemCommitUsed += [double]$memorySnapshot.CommitUsedPct }
    }
    try {
      [uint32]$foregroundPid = 0
      [void][DfbForegroundWindow]::GetWindowThreadProcessId([DfbForegroundWindow]::GetForegroundWindow(), [ref]$foregroundPid)
      if ([int]$foregroundPid -ne $GamePid) { $focusLostSec += $elapsed }
    } catch {}
    $sampled = $false
    if ($GpuVendor -eq 'NVIDIA' -and $NvidiaSmi -and (Test-Path -LiteralPath $NvidiaSmi -PathType Leaf)) {
      $raw = @(& $NvidiaSmi '--query-gpu=pci.bus_id,utilization.gpu,temperature.gpu,power.draw' '--format=csv,noheader,nounits' 2>$null)
      if ($LASTEXITCODE -eq 0 -and $raw.Count) {
        $parts = $null
        foreach ($line in $raw) {
          $candidate = @("$line" -split ',' | ForEach-Object { $_.Trim() })
          if ($candidate.Count -lt 4 -or $candidate[0] -notmatch '(?:[0-9A-Fa-f]{4,8}:)?([0-9A-Fa-f]{2}):([0-9A-Fa-f]{2})\.([0-7])$') { continue }
          $key = ('{0}:{1}:{2}' -f [Convert]::ToUInt32($Matches[1],16),
                  [Convert]::ToUInt32($Matches[2],16),[Convert]::ToUInt32($Matches[3],16))
          if ($GpuPciLocation -and $key -eq $GpuPciLocation) { $parts = $candidate; break }
        }
        if (-not $parts -and -not $GpuPciLocation -and $raw.Count -eq 1) {
          $parts = @("$($raw[0])" -split ',' | ForEach-Object { $_.Trim() })
        }
        if ($parts -and $parts.Count -ge 4) {
          $u = Get-Number $parts[1]; $t = Get-Number $parts[2]; $w = Get-Number $parts[3]
          if ($null -ne $u) { $util += $u; $sampled = $true; $utilSource = 'nvidia-smi' }
          if ($null -ne $t) { $temp += $t; $tempSource = 'nvidia-smi' }
          if ($null -ne $w) { $power += $w; $powerSource = 'nvidia-smi' }
        }
      }
    }
    if (-not $sampled -or -not $gameRenderAdapterLuid) {
      $counters = @(Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples |
        Where-Object { $_.InstanceName -match "pid_$($GamePid)_" -and $_.InstanceName -match 'engtype_3D' }
      if ($counters.Count) {
        $byAdapter = @{}; $physicalIndexByAdapter = @{}
        foreach ($counter in $counters) {
          $instance = "$($counter.InstanceName)"
          $adapterKey = 'unknown'
          if ($instance -match '(?i)luid_(0x[0-9a-f]+)_(0x[0-9a-f]+)') {
            $adapterKey = "$($Matches[1]):$($Matches[2])".ToLowerInvariant()
          }
          if (-not $byAdapter.ContainsKey($adapterKey)) { $byAdapter[$adapterKey] = 0.0 }
          $byAdapter[$adapterKey] += [double]$counter.CookedValue
          if ($adapterKey -ne 'unknown' -and -not $physicalIndexByAdapter.ContainsKey($adapterKey) -and
              $instance -match '(?i)_phys_(\d+)_') {
            $physicalIndexByAdapter[$adapterKey] = [int]$Matches[1]
          }
        }
        $primaryAdapter = @($byAdapter.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1)
        if ($primaryAdapter.Count -and "$($primaryAdapter[0].Key)" -ne 'unknown') {
          $gameRenderAdapterLuid = "$($primaryAdapter[0].Key)"
          if ($physicalIndexByAdapter.ContainsKey($gameRenderAdapterLuid)) {
            $gameRenderAdapterPhysicalIndex = [int]$physicalIndexByAdapter[$gameRenderAdapterLuid]
          }
        }
        if (-not $sampled) {
          $util += [math]::Min(100.0, [double](($counters | Measure-Object CookedValue -Sum).Sum))
          $utilSource = 'windows-gpu-engine'
        }
      }
    }
    try {
      $memoryCounters = @(Get-Counter @('\GPU Process Memory(*)\Dedicated Usage','\GPU Process Memory(*)\Shared Usage') -ErrorAction Stop).CounterSamples |
        Where-Object { $_.InstanceName -match "(?i)(?:^|_)pid_$($GamePid)(?:_|$)" }
      if ($memoryCounters.Count) {
        $dedicatedCounters = @($memoryCounters | Where-Object { "$($_.Path)" -match '(?i)Dedicated Usage$' })
        $sharedCounters = @($memoryCounters | Where-Object { "$($_.Path)" -match '(?i)Shared Usage$' })
        if ($dedicatedCounters.Count) {
          $dedicatedBytes = ($dedicatedCounters | Measure-Object CookedValue -Sum).Sum
          $gpuDedicatedMb += [math]::Max(0,[double]$dedicatedBytes/1MB)
        }
        if ($sharedCounters.Count) {
          $sharedBytes = ($sharedCounters | Measure-Object CookedValue -Sum).Sum
          $gpuSharedMb += [math]::Max(0,[double]$sharedBytes/1MB)
        }
        if ($dedicatedCounters.Count -or $sharedCounters.Count) { $gpuMemorySource = 'windows-gpu-process-memory' }
      }
    } catch {}
    Start-Sleep -Seconds 2
    try { $pm.Refresh() } catch {}
  }
  if ($pm -and -not $pm.HasExited) { try { $pm.Kill() } catch {} }
  if ($pm) { try { $pm.WaitForExit(5000) | Out-Null } catch {} }
  $presentMonExitCode = $(if ($pm -and $pm.HasExited) { [int]$pm.ExitCode } else { -1 })
  $powerEnd = Get-CapturePowerSnapshot

  $frameMs = New-Object 'System.Collections.Generic.List[double]'
  $displayFrameMs = New-Object 'System.Collections.Generic.List[double]'
  $appFrameMs = New-Object 'System.Collections.Generic.List[double]'
  $cpuBusyMs = New-Object 'System.Collections.Generic.List[double]'
  $gpuBusyMs = New-Object 'System.Collections.Generic.List[double]'
  $displayLatencyMs = New-Object 'System.Collections.Generic.List[double]'
  $frameTypes = @{}; $presentModes = @{}; $presentRuntimes = @{}; $syncIntervals = @{}; $swapChains = @{}
  $rowCount = 0; $displayTrackedRows = 0; $frameTypeRows = 0; $tearingRows = 0; $tearingCount = 0
  $generatedFrameCount = 0; $repeatedFrameCount = 0; $droppedFrameCount = 0
  $hybridPresentRows = 0; $hybridPresentCount = 0; $displayMetricSource = 'unavailable'; $headers = @()
  if (Test-Path -LiteralPath $tmp) {
    try {
      $rows = @(Import-Csv -LiteralPath $tmp)
      $headers = $(if ($rows.Count) { @($rows[0].PSObject.Properties.Name) } else { @() })
      $hasDisplayedTime = $headers -contains 'DisplayedTime'
      $hasDisplayDelta = $headers -contains 'MsBetweenDisplayChange'
      $displayMetricSource = $(if ($hasDisplayedTime) { 'displayed_time' } elseif ($hasDisplayDelta) { 'display_change' } else { 'unavailable' })
      $hybridHeader = @($headers | Where-Object { $_ -match '(?i)hybrid' } | Select-Object -First 1)
      foreach ($row in $rows) {
        $rowCount++
        $ms = Get-RowNumber $row @('MsBetweenPresents','FrameTime')
        if ($null -ne $ms -and $ms -gt 0 -and $ms -le 1000) { $frameMs.Add([double]$ms) }
        if ($hasDisplayedTime) {
          $displayValue = Get-Number $row.DisplayedTime
          if ($null -ne $displayValue -and $displayValue -gt 0 -and $displayValue -le 1000) {
            $displayFrameMs.Add([double]$displayValue); $displayTrackedRows++
          } elseif ("$($row.DisplayedTime)".Trim() -match '^(?i:NA|N/A)$') { $droppedFrameCount++ }
        } elseif ($hasDisplayDelta) {
          $displayValue = Get-Number $row.MsBetweenDisplayChange
          if ($null -ne $displayValue -and $displayValue -gt 0 -and $displayValue -le 1000) {
            $displayFrameMs.Add([double]$displayValue); $displayTrackedRows++
          }
        }
        $frameType = $(if ($row.PSObject.Properties['FrameType']) { "$($row.FrameType)".Trim() } else { '' })
        if ($frameType -and $frameType -notmatch '^(?i:NA|N/A|Unknown|NotSet)$') {
          $frameTypeRows++
          if (-not $frameTypes.ContainsKey($frameType)) { $frameTypes[$frameType] = 0 }; $frameTypes[$frameType]++
          if ($frameType -match '(?i)generated|frame\s*generation|interpolat|xess|afmf|dlss\s*fg') { $generatedFrameCount++ }
          elseif ($frameType -match '(?i)repeat') { $repeatedFrameCount++ }
          elseif ($frameType -match '(?i)^app(?:lication)?$|application') {
            $appMs = Get-RowNumber $row @('MsBetweenAppStart')
            if ($null -ne $appMs -and $appMs -gt 0 -and $appMs -le 1000) { $appFrameMs.Add([double]$appMs) }
          }
        }
        foreach ($field in @('PresentMode','PresentRuntime','SyncInterval')) {
          $counter = $(if ($field -eq 'PresentMode') { $presentModes } elseif ($field -eq 'PresentRuntime') { $presentRuntimes } else { $syncIntervals })
          if ($row.PSObject.Properties[$field]) {
            $value = "$($row.$field)".Trim()
            if ($value -and $value -notmatch '^(?i:NA|N/A)$') {
              if (-not $counter.ContainsKey($value)) { $counter[$value] = 0 }; $counter[$value]++
            }
          }
        }
        if ($row.PSObject.Properties['SwapChainAddress']) {
          $swap = "$($row.SwapChainAddress)".Trim(); if ($swap) { $swapChains[$swap] = $true }
        }
        if ($row.PSObject.Properties['AllowsTearing']) {
          $tearing = "$($row.AllowsTearing)".Trim()
          if ($tearing -match '^(?:0|1|true|false)$') { $tearingRows++; if ($tearing -match '^(?:1|true)$') { $tearingCount++ } }
        }
        if ($hybridHeader.Count) {
          $hybridValue = "$($row.($hybridHeader[0]))".Trim()
          if ($hybridValue -and $hybridValue -notmatch '^(?i:NA|N/A)$') {
            $hybridPresentRows++; if ($hybridValue -match '^(?i:1|true|yes|hybrid)$') { $hybridPresentCount++ }
          }
        }
        $cpuValue = Get-RowNumber $row @('MsCPUBusy','CPUBusy')
        if ($null -ne $cpuValue -and $cpuValue -ge 0 -and $cpuValue -le 1000) { $cpuBusyMs.Add([double]$cpuValue) }
        $gpuValue = Get-RowNumber $row @('MsGPUBusy','GPUBusy')
        if ($null -ne $gpuValue -and $gpuValue -ge 0 -and $gpuValue -le 1000) { $gpuBusyMs.Add([double]$gpuValue) }
        $latencyValue = Get-RowNumber $row @('DisplayLatency','MsUntilDisplayed')
        if ($null -ne $latencyValue -and $latencyValue -ge 0 -and $latencyValue -le 1000) { $displayLatencyMs.Add([double]$latencyValue) }
      }
    } catch {}
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
  $completedUtc = [DateTime]::UtcNow
  $durationSec = [math]::Min($SampleSeconds, [math]::Round(((Get-Date) - $started).TotalSeconds))
  if ($durationSec -lt ($SampleSeconds - 5) -and -not (Get-Process -Id $GamePid -ErrorAction SilentlyContinue)) { $gameExitedEarly = $true }
  $presented = Get-FrameSummary $frameMs
  $displayed = Get-FrameSummary $displayFrameMs
  $appFrames = Get-FrameSummary $appFrameMs
  $avgFps = $(if ($null -ne $presented.AvgFps) { [double]$presented.AvgFps } else { 0.0 })
  $fps1Low = $(if ($null -ne $presented.Fps1Low) { [double]$presented.Fps1Low } else { 0.0 })
  $p99 = $(if ($null -ne $presented.P99FrameMs) { [double]$presented.P99FrameMs } else { 0.0 })
  $mad = $(if ($null -ne $presented.MadMs) { [double]$presented.MadMs } else { 0.0 })
  $stutter50 = @($frameMs | Where-Object { $_ -gt 50 }).Count
  $stutter100 = @($frameMs | Where-Object { $_ -gt 100 }).Count
  $slow25 = @($frameMs | Where-Object { $_ -gt 25 }).Count
  $slow33 = @($frameMs | Where-Object { $_ -gt 33.333 }).Count
  $powerSourceChanged = $(if ($powerStart.Source -ne 'unknown' -and $powerEnd.Source -ne 'unknown') {
    [bool]($powerStart.Source -ne $powerEnd.Source)
  } else { $null })
  $batteryDischarging = $(if ($null -ne $powerStart.BatteryPercent -and $null -ne $powerEnd.BatteryPercent) {
    [bool]([int]$powerEnd.BatteryPercent -lt [int]$powerStart.BatteryPercent)
  } else { $null })
  $chargerInsufficiency = $(if ($null -ne $batteryDischarging -and $powerStart.Source -eq 'ac' -and $powerEnd.Source -eq 'ac') {
    [bool]$batteryDischarging
  } else { $null })
  $analysisContext = $null
  try { if ($AnalysisContextJson) { $analysisContext = $AnalysisContextJson | ConvertFrom-Json } } catch {}
  $performanceContext = [pscustomobject][ordered]@{
    schemaVersion=1;legacyFpsSource='presented';captureTool='presentmon';captureToolVersion="$PresentMonVersion"
    captureMode='etw_summary';overlayEnabled=$false;captureOverheadMeasured=$false
    presentedFrameCount=[int]$presented.Count;presentedFpsAvg=$presented.AvgFps;presentedFps1Low=$presented.Fps1Low
    presentedP50FrameMs=$presented.P50FrameMs;presentedP90FrameMs=$presented.P90FrameMs
    presentedP95FrameMs=$presented.P95FrameMs;presentedP99FrameMs=$presented.P99FrameMs
    presentedFrameTimeCvPct=$presented.CvPct
    slowFrame25Ms=[int]$slow25;slowFrame33Ms=[int]$slow33;slowFrame50Ms=[int]$stutter50;slowFrame100Ms=[int]$stutter100
    slowFrame33Pct=$(if($presented.Count -gt 0){[math]::Round($slow33*100.0/$presented.Count,1)}else{$null})
    displayedFrameCount=[int]$displayed.Count;displayedFpsAvg=$displayed.AvgFps;displayedFps1Low=$displayed.Fps1Low
    displayedP95FrameMs=$displayed.P95FrameMs;displayedP99FrameMs=$displayed.P99FrameMs;displayMetricSource=$displayMetricSource
    appFrameCount=[int]$appFrames.Count;appFpsAvg=$appFrames.AvgFps;appFps1Low=$appFrames.Fps1Low
    generatedFrameCount=$(if($frameTypeRows -gt 0){[int]$generatedFrameCount}else{$null})
    repeatedFrameCount=$(if($frameTypeRows -gt 0){[int]$repeatedFrameCount}else{$null})
    droppedFrameCount=$(if($headers -contains 'DisplayedTime'){[int]$droppedFrameCount}else{$null})
    frameGenerationDetected=$(if($frameTypeRows -gt 0){[bool]($generatedFrameCount -gt 0)}else{$null})
    displayTrackingCoveragePct=$(if($rowCount -gt 0){[math]::Round($displayTrackedRows*100.0/$rowCount,1)}else{$null})
    frameTypeCoveragePct=$(if($rowCount -gt 0){[math]::Round($frameTypeRows*100.0/$rowCount,1)}else{$null})
    frameTypeDistribution=ConvertTo-Distribution $frameTypes
    presentModeDistribution=ConvertTo-Distribution $presentModes
    presentRuntimeDistribution=ConvertTo-Distribution $presentRuntimes
    syncIntervalDistribution=ConvertTo-Distribution $syncIntervals
    swapChainCount=[int]$swapChains.Count
    tearingFramePct=$(if($tearingRows -gt 0){[math]::Round($tearingCount*100.0/$tearingRows,1)}else{$null})
    cpuBusyAvgMs=Get-Average $cpuBusyMs;cpuBusyP95Ms=$(if($cpuBusyMs.Count){[math]::Round((Get-Percentile $cpuBusyMs 0.95),2)}else{$null})
    gpuBusyAvgMs=Get-Average $gpuBusyMs;gpuBusyP95Ms=$(if($gpuBusyMs.Count){[math]::Round((Get-Percentile $gpuBusyMs 0.95),2)}else{$null})
    displayLatencyAvgMs=Get-Average $displayLatencyMs;displayLatencyP95Ms=$(if($displayLatencyMs.Count){[math]::Round((Get-Percentile $displayLatencyMs 0.95),2)}else{$null})
    captureCompatibilityStatus=$(if($frameMs.Count -gt 0){'ok'}else{'no_frame_data'})
    gpuUtilSource=$utilSource;gpuUtilSampleCount=[int]$util.Count;gpuUtilCoveragePct=$(if($loopSamples){[math]::Round($util.Count*100.0/$loopSamples,1)}else{$null})
    gpuTempSource=$tempSource;gpuTempSampleCount=[int]$temp.Count;gpuTempCoveragePct=$(if($loopSamples){[math]::Round($temp.Count*100.0/$loopSamples,1)}else{$null})
    gpuPowerSource=$powerSource;gpuPowerSampleCount=[int]$power.Count;gpuPowerCoveragePct=$(if($loopSamples){[math]::Round($power.Count*100.0/$loopSamples,1)}else{$null})
    processCpuAvgPct=Get-Average $processCpu;processCpuMaxPct=Get-Maximum $processCpu
    processCpuSampleCount=[int]$processCpu.Count;processCpuCoveragePct=$(if($loopSamples){[math]::Round($processCpu.Count*100.0/$loopSamples,1)}else{$null})
    gameWorkingSetAvgMb=Get-Average $gameWorkingSetMb;gameWorkingSetMaxMb=Get-Maximum $gameWorkingSetMb
    gamePrivateAvgMb=Get-Average $gamePrivateMb;gamePrivateMaxMb=Get-Maximum $gamePrivateMb
    processMemorySampleCount=[int][math]::Min($gameWorkingSetMb.Count,$gamePrivateMb.Count)
    systemMemoryUsedAvgPct=Get-Average $systemMemoryUsed;systemMemoryUsedMaxPct=Get-Maximum $systemMemoryUsed
    systemMemoryAvailableMinMb=Get-Minimum $systemMemoryAvailableMb;systemCommitUsedAvgPct=Get-Average $systemCommitUsed
    systemMemorySampleCount=[int]$systemMemoryUsed.Count
    gpuDedicatedMemoryAvgMb=Get-Average $gpuDedicatedMb;gpuDedicatedMemoryMaxMb=Get-Maximum $gpuDedicatedMb
    gpuSharedMemoryAvgMb=Get-Average $gpuSharedMb;gpuSharedMemoryMaxMb=Get-Maximum $gpuSharedMb
    # 部分 Windows/驱动只暴露 Dedicated 或 Shared 其中一类计数器。公共样本数表示
    # “至少有一类进程 GPU 内存读数”的轮次，取最小值会把真实样本误记成 0。
    gpuMemorySource=$gpuMemorySource;gpuMemorySampleCount=[int][math]::Max($gpuDedicatedMb.Count,$gpuSharedMb.Count)
    gpuMemoryCoveragePct=$(if($loopSamples){[math]::Round(([math]::Max($gpuDedicatedMb.Count,$gpuSharedMb.Count))*100.0/$loopSamples,1)}else{$null})
    gameRenderAdapterLuid=$gameRenderAdapterLuid;gameRenderAdapterPhysicalIndex=$gameRenderAdapterPhysicalIndex
    hybridPresentCount=$(if($hybridPresentRows){[int]$hybridPresentCount}else{$null})
    hybridPresentCoveragePct=$(if($rowCount -gt 0 -and $hybridPresentRows){[math]::Round($hybridPresentRows*100.0/$rowCount,1)}else{$null})
    powerSourceStart="$($powerStart.Source)";powerSourceEnd="$($powerEnd.Source)";powerSourceChanged=$powerSourceChanged
    batteryPercentStart=$powerStart.BatteryPercent;batteryPercentEnd=$powerEnd.BatteryPercent
    batteryDischargingUnderLoad=$batteryDischarging;chargerInsufficiencySuspected=$chargerInsufficiency
  }
  $session = [pscustomobject][ordered]@{
    recordedAt = $completedUtc.ToString('o'); startedAt = $startedUtc.ToString('o'); completedAt = $completedUtc.ToString('o')
    durationSec = [int]$durationSec; frameCount = [int]$frameMs.Count
    gpuModel = "$GpuModel"; configTier = "$ConfigTier"; optimizationScheme = "$OptimizationScheme"
    optimizationItemSetHash = "$OptimizationItemSetHash"; optimizationItemIds = @($OptimizationItemIds)
    optimizationItemsComplete = [bool]$OptimizationItemsComplete; avgFps = $avgFps; fps1Low = $fps1Low
    p99FrameMs = $p99; frameTimeMadMs = $mad; stutter50Ms = [int]$stutter50; stutter100Ms = [int]$stutter100
    stuttersPerMin = $(if ($durationSec -gt 0) { [math]::Round($stutter50 * 60.0 / $durationSec, 2) } else { 0.0 })
    focusLostSec = [math]::Round($focusLostSec, 1)
    gpuUtilAvg = Get-Average $util; gpuUtilMax = Get-Maximum $util
    gpuTempAvg = Get-Average $temp; gpuTempMax = Get-Maximum $temp
    gpuPowerAvg = Get-Average $power; gpuPowerMax = Get-Maximum $power
    presentMonExitCode = $presentMonExitCode; gameExitedEarly = [bool]$gameExitedEarly
    captureFailed = [bool]($frameMs.Count -eq 0 -or $presentMonExitCode -ne 0)
    captureError = $(if ($frameMs.Count -eq 0) { 'PresentMon 未返回帧数据' } elseif ($presentMonExitCode -ne 0) { "PresentMon 退出码 $presentMonExitCode" } else { '' })
    analysisContext = $analysisContext; performanceContext = $performanceContext
  }

  # 普通性能会话过去只在“帧率和 GPU 占用同时为 0”时丢弃，因此 0 FPS、低帧率 0
  # 但仍有 GPU 占用的失败捕获会被上传并污染建议样本。按 Beta 已验证的质量门槛标记，
  # 无效会话保留在本地诊断中解释失败原因，但只有 valid 会话进入服务器性能样本。
  $invalidReason = ''
  if ([bool]$session.captureFailed) { $invalidReason = 'capture_failed' }
  elseif ([bool]$session.gameExitedEarly) { $invalidReason = 'game_exited' }
  elseif ([int]$session.durationSec -lt 90) { $invalidReason = 'sample_too_short' }
  elseif ([int64]$session.frameCount -lt 1000 -or [double]$session.avgFps -le 0 -or [double]$session.fps1Low -le 0) {
    $invalidReason = 'insufficient_frames'
  }
  elseif ([double]$session.focusLostSec -gt 5) { $invalidReason = 'focus_lost' }
  $session | Add-Member -NotePropertyName validity -NotePropertyValue $(if ($invalidReason) { 'invalid' } else { 'valid' })
  $session | Add-Member -NotePropertyName invalidReason -NotePropertyValue $invalidReason

  # Beta 返回显式结果，不写普通 performance_sessions，也不发 performance 事件。
  if ($CaptureMode -eq 'experiment') { Write-Output $session; return }

  $sessionMutex = $null; $sessionLocked = $false; $sessionTemp = $null; $sessionBackup = $null
  try {
    $sessionMutex = New-Object Threading.Mutex($false, 'Local\DeltaForceBooster.PerformanceSessions')
    $sessionLocked = $sessionMutex.WaitOne([TimeSpan]::FromSeconds(10))
    if (-not $sessionLocked) { throw '性能记录文件正忙' }
    $dir = Split-Path -Parent $SessionFile
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $old = @()
    if (Test-Path -LiteralPath $SessionFile) {
      $decoded = Get-Content -LiteralPath $SessionFile -Raw -Encoding UTF8 | ConvertFrom-Json
      $old = @(Expand-PerformanceSessions $decoded)
    }
    $all = @($old) + $session
    if ($all.Count -gt 50) { $all = @($all | Select-Object -Last 50) }
    $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes((ConvertTo-Json -InputObject $all -Depth 5))
    $sessionTemp = Join-Path $dir ('.performance-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $stream = New-Object IO.FileStream($sessionTemp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
                                      [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    $sessionBackup = Join-Path $dir ('.performance-' + [guid]::NewGuid().ToString('N') + '.bak')
    if (Test-Path -LiteralPath $SessionFile) { [IO.File]::Replace($sessionTemp, $SessionFile, $sessionBackup, $true) }
    else { [IO.File]::Move($sessionTemp, $SessionFile) }
    $sessionTemp = $null
  } catch {} finally {
    if ($sessionTemp -and (Test-Path -LiteralPath $sessionTemp)) { Remove-Item -LiteralPath $sessionTemp -Force -ErrorAction SilentlyContinue }
    if ($sessionBackup -and (Test-Path -LiteralPath $sessionBackup)) { Remove-Item -LiteralPath $sessionBackup -Force -ErrorAction SilentlyContinue }
    if ($sessionLocked) { try { $sessionMutex.ReleaseMutex() } catch {} }
    if ($sessionMutex) { $sessionMutex.Dispose() }
  }

  if ($InstallId -and $GpuVerified -and $session.validity -eq 'valid') {
    try {
      $payload = [ordered]@{
        installId = $InstallId; event = 'performance'; version = $Version
        gpuVendor = $GpuVendor; gpuModel = $GpuModel; gpuModelVerified = [bool]$GpuVerified
        configTier = $ConfigTier; optimizationScheme = $OptimizationScheme
        optimizationItemSetHash = $OptimizationItemSetHash; optimizationItemIds = @($OptimizationItemIds)
        optimizationItemsComplete = [bool]$OptimizationItemsComplete
        durationSec = $session.durationSec; avgFps = $session.avgFps; fps1Low = $session.fps1Low
        frameCount = $session.frameCount; p99FrameMs = $session.p99FrameMs
        frameTimeMadMs = $session.frameTimeMadMs; stutter50Ms = $session.stutter50Ms
        stutter100Ms = $session.stutter100Ms; stuttersPerMin = $session.stuttersPerMin
        focusLostSec = $session.focusLostSec
        gpuUtilAvg = $session.gpuUtilAvg; gpuUtilMax = $session.gpuUtilMax
        gpuTempAvg = $session.gpuTempAvg; gpuTempMax = $session.gpuTempMax
        gpuPowerAvg = $session.gpuPowerAvg; gpuPowerMax = $session.gpuPowerMax
        performanceContext = $session.performanceContext
      }
      if ($session.analysisContext) { $payload.analysisContext = $session.analysisContext }
      . $TelemetryModule
      Send-DfbTelemetryEvent -UploadUrl $UploadUrl -Payload ([pscustomobject]$payload) -ConfigPath $TelemetryConfigPath | Out-Null
    } catch {}
  }
  Write-Output $session
}

function Add-PerformanceWorkerArguments($PowerShell, [int]$GamePid, $Hw, [string]$Mode, [int]$WarmupSeconds) {
  $presentMon = Join-Path $script:RootDir 'tools\PresentMon.exe'
  $nvidiaSmi = $(if ($Hw.MainGpuVendor -eq 'NVIDIA') { Get-NvidiaSmiPath } else { $null })
  $optimization = Get-TelemetryOptimizationContext
  $analysisContextJson = ''
  try { $analysisContextJson = (Get-TelemetryAnalysisContext $Hw $script:TargetExe) | ConvertTo-Json -Compress -Depth 6 } catch {}
  $presentMonVersion = ''
  try { $presentMonVersion = "$((Get-Item -LiteralPath $presentMon -Force).VersionInfo.FileVersion)".Trim() } catch {}
  foreach ($arg in @($GamePid, $presentMon, (Join-Path $script:UserConfigDir 'performance-sessions.json'),
                      $script:TelemetryClientPath, (Join-Path $script:UserConfigDir 'telemetry.json'),
                      $script:TelemetryUploadUrl, (Get-TelemetryInstallId), $script:GuiVersion,
                      "$($Hw.MainGpuVendor)", "$($Hw.MainGpuName)", [bool]$Hw.MainGpuNameVerified,
                      "$($Hw.MainGpuPciLocation)", "$nvidiaSmi", "$($optimization.ConfigTier)",
                      "$($optimization.Scheme)", "$($optimization.ItemSetHash)", (@($optimization.ItemIds) -join ','),
                      [bool]$optimization.ItemsComplete,
                      $WarmupSeconds, $script:PerformanceSampleSeconds, $Mode,
                      $analysisContextJson, $presentMonVersion)) {
    [void]$PowerShell.AddArgument($arg)
  }
}

function Start-GamePerformanceCapture([int]$GamePid, $Hw) {
  if ($GamePid -le 0 -or $script:MonitoredGamePids.ContainsKey($GamePid) -or (Test-TuningExperimentActive)) { return }
  $presentMon = Join-Path $script:RootDir 'tools\PresentMon.exe'
  if (-not (Test-Path -LiteralPath $presentMon -PathType Leaf)) {
    Write-Log '性能记录未启动：缺少 tools\PresentMon.exe。'; return
  }
  $script:MonitoredGamePids[$GamePid] = $true
  $ps = [PowerShell]::Create()
  [void]$ps.AddScript($script:PerformanceCaptureWorker)
  Add-PerformanceWorkerArguments $ps $GamePid $Hw 'ordinary' $script:PerformanceWarmupSeconds
  $async = $ps.BeginInvoke()
  [void]$script:PerformanceJobs.Add([pscustomobject]@{ PowerShell = $ps; Async = $async; Pid = $GamePid })
  Write-Log "检测到游戏进程 PID $GamePid：将在启动稳定后记录 120 秒帧率 / GPU 性能汇总。"
}

function Poll-GamePerformanceCapture {
  foreach ($job in @($script:PerformanceJobs)) {
    if (-not $job.Async.IsCompleted) { continue }
    try { $job.PowerShell.EndInvoke($job.Async) | Out-Null } catch {}
    try { $job.PowerShell.Dispose() } catch {}
    $script:PerformanceJobs.Remove($job) | Out-Null
    Write-Log "游戏性能记录已完成（PID $($job.Pid)），汇总已保存到本地并按隐私设置匿名上报。"
  }
  Refresh-PerformanceComparison
  # 实验期间同一 PID 要顺序采多轮，普通“每 PID 一次”的采样必须暂停，
  # 否则会抢 PresentMon 会话并把实验轮次写入普通 performance_sessions。
  if ((Test-TuningExperimentActive) -or $script:TuningSampling -or -not $script:TargetExe) { return }
  $name = [IO.Path]::GetFileNameWithoutExtension($script:TargetExe)
  foreach ($proc in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
    Start-GamePerformanceCapture $proc.Id $script:HardwareInfo
  }
}

# ---------- 自动寻找最佳配置 Beta（个体内确定性规则实验） ----------

$script:TuningExperimentDir = Join-Path $script:UserConfigDir 'experiments'
$script:TuningActivePointer = Join-Path $script:TuningExperimentDir 'active-experiment.json'
$script:ActiveTuningExperiment = $null
$script:ActiveTuningStatePath = $null
$script:TuningSampling = $false
$script:TuningConfigGeneration = 0

function Test-AllowedGameExecutable([string]$Path) {
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  [IO.Path]::GetFileName($Path) -in 'DeltaForceClient-Win64-Shipping.exe','DeltaForce.exe'
}

function Test-TuningBackupReference([string]$Path) {
  try {
    if (-not $Path) { return $false }
    $root = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)) 'DeltaForceBooster\backup'
    $full = [IO.Path]::GetFullPath($Path); $prefix = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
    $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and
      [IO.Path]::GetFileName($full) -match '^backup-[0-9a-fA-F-]{36}(?:\.pending)?\.json$'
  } catch { $false }
}

function Add-TuningStateProperty($Object, [string]$Name, $Value) {
  if (-not $Object.PSObject.Properties[$Name]) { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Initialize-TuningGuiStateFields($State) {
  Add-TuningStateProperty $State 'phase' 'baseline'
  Add-TuningStateProperty $State 'gamePath' ''
  Add-TuningStateProperty $State 'configGeneration' 0
  Add-TuningStateProperty $State 'pendingActionId' ''
  Add-TuningStateProperty $State 'pendingResumePhase' ''
  Add-TuningStateProperty $State 'pendingTuningCommit' $null
  Add-TuningStateProperty $State 'initialBaselineRunIds' @()
  Add-TuningStateProperty $State 'finalRunIds' @()
  Add-TuningStateProperty $State 'finalComparison' $null
  Add-TuningStateProperty $State 'groupRestartAfter' ''
  Add-TuningStateProperty $State 'lastMessage' ''
  foreach ($candidate in @($State.candidates)) {
    Add-TuningStateProperty $candidate 'controlRunIds' @()
    Add-TuningStateProperty $candidate 'candidateRunIds' @()
    Add-TuningStateProperty $candidate 'extraAttempted' $false
    Add-TuningStateProperty $candidate 'controlVariantId' ''
  }
  $State
}

function Assert-TuningGuiState($State) {
  [void](Assert-TuningExperimentState $State)
  [void](Initialize-TuningGuiStateFields $State)
  $allowedPhases = @('baseline','group_control_pre','group_apply_b1','group_capture_b1','group_rollback_a',
    'group_capture_a','group_apply_b2','group_capture_b2','group_rollback_extra_a','group_capture_extra_a',
    'group_apply_extra_b','group_capture_extra_b','final_capture','applying','rolling_back','completed','failed')
  if ("$($State.phase)" -notin $allowedPhases) { throw '实验阶段无效' }
  if (-not (Test-AllowedGameExecutable "$($State.gamePath)")) { throw '实验绑定的游戏路径无效' }
  if ([int64]$State.configGeneration -lt 0) { throw '实验配置代次无效' }
  if (-not [bool]$State.allowHigherPower -and [double]$State.maxPowerIncreasePct -ne 0) { throw '不允许更高功耗时，功耗增幅必须为 0' }
  if ($State.pendingActionId -and "$($State.pendingActionId)" -notmatch '^[0-9a-fA-F-]{36}$') { throw '实验动作 ID 无效' }
  if (@($State.runs).Count -gt 300) { throw '实验运行记录过多' }
  foreach ($candidate in @($State.candidates)) {
    $allowedControlVariants = @('') + @('baseline') + @($State.candidates | ForEach-Object { "$($_.variantId)" })
    if ("$($candidate.controlVariantId)" -notin $allowedControlVariants) { throw '候选组对照方案 ID 无效' }
    if ($candidate.activeBackup -and -not (Test-TuningBackupReference "$($candidate.activeBackup)")) { throw '候选组备份引用无效' }
    foreach ($backup in @($candidate.appliedBackups)) {
      if (-not (Test-TuningBackupReference "$backup")) { throw '候选组备份列表无效' }
    }
    foreach ($rid in @($candidate.controlRunIds) + @($candidate.candidateRunIds)) {
      if ("$rid" -notmatch '^run_[0-9a-f]{32}$' -or -not @($State.runs | Where-Object runId -eq "$rid").Count) {
        throw '候选组运行引用无效'
      }
    }
  }
  if($State.pendingTuningCommit -and $State.pendingTuningCommit.payload){
    if(-not (Get-Command Get-DfbTuningPayloadInfo -ErrorAction SilentlyContinue)){throw '缺少待提交遥测严格校验器'}
    $pending=$State.pendingTuningCommit;$info=Get-DfbTuningPayloadInfo $pending.payload
    if("$($info.ExperimentId)" -ne "$($State.experimentId)" -or "$($info.TuningType)" -ne "$($pending.telemetryType)"){
      throw '待提交遥测归属无效'
    }
    if("$($pending.kind)" -eq 'run'){
      $run=@($State.runs|Where-Object runId -eq "$($pending.entityId)")[0]
      if("$($pending.payload.runId)" -ne (ConvertTo-TuningWireRunId $State "$($pending.entityId)") -or
          "$($pending.payload.variantId)" -ne (ConvertTo-TuningWireVariantId $State "$($run.variantId)")){throw '待提交运行遥测业务 ID 无效'}
      foreach($name in 'runNo','sequenceNo','durationSec','stutter50Ms','stutter100Ms'){
        if([int64]$pending.payload.$name -ne [int64]$run.$name){throw "待提交运行遥测字段不一致：$name"}
      }
      foreach($name in 'avgFps','fps1Low','p99FrameMs','gpuUtilAvg','gpuTempAvg','gpuPowerAvg'){
        $pendingValue=$pending.payload.$name;$runValue=$run.$name
        if(($null -eq $pendingValue) -ne ($null -eq $runValue) -or
            ($null -ne $pendingValue -and [double]$pendingValue -ne [double]$runValue)){throw "待提交运行遥测字段不一致：$name"}
      }
      foreach($name in 'validity','invalidReason','settingsHash','environmentHash'){
        if("$($pending.payload.$name)" -cne "$($run.$name)"){throw "待提交运行遥测字段不一致：$name"}
      }
      if($pending.payload.orderControlled -isnot [bool] -or [bool]$pending.payload.orderControlled -ne [bool]$run.orderControlled){throw '待提交运行顺序控制标记不一致'}
    }else{
      $idx=[int]$pending.candidateIndex;$candidate=$State.candidates[$idx];$library=Get-TuningCandidate "$($candidate.groupId)"
      $groups=@($State.candidates|Select-Object -First $idx|Where-Object result -eq 'win'|ForEach-Object{"$($_.groupId)"})+@("$($candidate.groupId)")
      $ids=@($groups|ForEach-Object{@((Get-TuningCandidate "$_").ItemIds)}|ForEach-Object{"$_".ToLowerInvariant()}|Sort-Object -Unique)
      $expectedApply=$(if("$($pending.outcome)" -eq 'succeeded'){'succeeded'}else{'failed'})
      if("$($pending.payload.variantId)" -ne (ConvertTo-TuningWireVariantId $State "$($pending.entityId)") -or
          "$($pending.payload.controlVariantId)" -ne (ConvertTo-TuningWireVariantId $State "$($candidate.controlVariantId)") -or
          "$($pending.payload.groupId)" -ne "$($candidate.groupId)" -or [int]$pending.payload.sequenceNo -ne [int]$candidate.sequenceNo -or
          "$($pending.payload.applyResult)" -ne $expectedApply -or "$($pending.payload.status)" -ne $(if($expectedApply -eq 'succeeded'){'variant_applied'}else{'apply_failed'}) -or
          "$($pending.payload.itemSetHash)" -ne (Get-TuningItemSetHash $ids) -or (@($pending.payload.itemIds) -join ',') -cne ($ids -join ',') -or
          "$($pending.payload.source)" -ne "$($library.Source)" -or "$($pending.payload.riskLevel)" -ne "$($library.RiskLevel)" -or
          [bool]$pending.payload.requiresReboot -ne [bool]$library.RequiresReboot -or [int]$pending.payload.skippedCount -ne 0 -or
          [int]$pending.payload.appliedCount -ne $(if($expectedApply -eq 'succeeded'){$ids.Count}else{0}) -or
          [int]$pending.payload.failedCount -ne $(if($expectedApply -eq 'failed'){$ids.Count}else{0})){
        throw '待提交候选遥测与本地执行结果不一致'
      }
    }
  }
  $true
}

function Write-TuningPointerAtomic([string]$ExperimentId) {
  if ($ExperimentId -notmatch '^exp_[0-9a-f]{32}$') { throw '实验 ID 无效' }
  if (-not (Test-Path -LiteralPath $script:TuningExperimentDir)) {
    [void][IO.Directory]::CreateDirectory($script:TuningExperimentDir)
  }
  $tmp = Join-Path $script:TuningExperimentDir ('.active-' + [guid]::NewGuid().ToString('N') + '.tmp')
  $json = [pscustomobject][ordered]@{ schemaVersion = 1; experimentId = $ExperimentId } | ConvertTo-Json -Compress
  $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes($json)
  $stream = New-Object IO.FileStream($tmp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
  try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
  $backup = Join-Path $script:TuningExperimentDir ('.active-' + [guid]::NewGuid().ToString('N') + '.bak')
  try {
    if (Test-Path -LiteralPath $script:TuningActivePointer) { [IO.File]::Replace($tmp,$script:TuningActivePointer,$backup,$true) }
    else { [IO.File]::Move($tmp,$script:TuningActivePointer) }
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
  }
}

function Read-TuningPointerStrict {
  if (-not (Test-Path -LiteralPath $script:TuningActivePointer -PathType Leaf)) { return $null }
  $file = Get-Item -LiteralPath $script:TuningActivePointer -Force
  if ($file.Length -gt 1024 -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '活动实验指针无效' }
  $pointer = Get-Content -LiteralPath $script:TuningActivePointer -Raw -Encoding UTF8 | ConvertFrom-Json
  $names = @($pointer.PSObject.Properties.Name | Sort-Object)
  if ($names.Count -ne 2 -or ($names -join ',') -ne 'experimentId,schemaVersion' -or
      [int]$pointer.schemaVersion -ne 1 -or "$($pointer.experimentId)" -notmatch '^exp_[0-9a-f]{32}$') {
    throw '活动实验指针格式无效'
  }
  "$($pointer.experimentId)"
}

function Clear-TuningPointer {
  if (Test-Path -LiteralPath $script:TuningActivePointer -PathType Leaf) {
    Remove-Item -LiteralPath $script:TuningActivePointer -Force -ErrorAction SilentlyContinue
  }
}

function Test-TuningExperimentActive {
  $script:ActiveTuningExperiment -and "$($script:ActiveTuningExperiment.status)" -notin 'completed','rolled_back','cancelled','failed'
}

function Save-TuningExperiment([switch]$Terminal) {
  if (-not $script:ActiveTuningExperiment) { return }
  [void](Assert-TuningGuiState $script:ActiveTuningExperiment)
  if (-not $script:ActiveTuningStatePath) {
    $script:ActiveTuningStatePath = Join-Path $script:TuningExperimentDir ("$($script:ActiveTuningExperiment.experimentId).json")
  }
  Write-TuningStateAtomic $script:ActiveTuningStatePath $script:ActiveTuningExperiment | Out-Null
  if ($Terminal) { Clear-TuningPointer }
  else {
    $currentPointer=$null
    try{$currentPointer=Read-TuningPointerStrict}catch{}
    if("$currentPointer" -ne "$($script:ActiveTuningExperiment.experimentId)"){
      Write-TuningPointerAtomic "$($script:ActiveTuningExperiment.experimentId)"
    }
  }
}

function Get-TuningDisplayMode {
  $width = [int][Windows.SystemParameters]::PrimaryScreenWidth
  $height = [int][Windows.SystemParameters]::PrimaryScreenHeight
  $refresh = 0
  try {
    $vc = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object {
      $_.CurrentHorizontalResolution -eq $width -and $_.CurrentVerticalResolution -eq $height
    } | Select-Object -First 1)
    if ($vc) { $refresh = [int]$vc.CurrentRefreshRate }
  } catch {}
  "${width}x${height}@$refresh"
}

function Get-TuningEnvironmentSnapshot([string]$SceneId) {
  if (-not (Test-AllowedGameExecutable $script:TargetExe)) { throw '请先定位有效的三角洲行动主程序' }
  $gpu = @($script:HardwareInfo.Gpus | Where-Object Name -eq "$($script:HardwareInfo.MainGpuName)" | Select-Object -First 1)
  $driver = $(if ($gpu) { "$($gpu.Driver)" } else { '' })
  $gameVersion = ''
  try { $gameVersion = "$((Get-Item -LiteralPath $script:TargetExe -Force).VersionInfo.FileVersion)" } catch {}
  [pscustomobject][ordered]@{
    appVersion = "$script:GuiVersion"
    windowsBuild = "$($script:HardwareInfo.Build)"
    gpuModel = "$($script:HardwareInfo.MainGpuName)"
    driverVersion = $driver
    gameVersion = $gameVersion
    displayMode = Get-TuningDisplayMode
    sceneId = "$SceneId".Trim()
  }
}

function Get-TuningSettingsHash {
  $parts = New-Object System.Collections.Generic.List[string]
  [void]$parts.Add("game=$([IO.Path]::GetFullPath($script:TargetExe).ToLowerInvariant())")
  foreach ($candidate in @(Get-TuningCandidateLibrary)) {
    $actual = @(Get-OptItems $script:TargetExe | Where-Object { $candidate.ItemIds -contains $_.Id })
    foreach ($item in @($actual | Sort-Object Id)) {
      $state = Get-ItemState $item
      [void]$parts.Add("$($item.Id)=$([bool]$state.Ok):$($state.Text)")
    }
  }
  Get-TuningSha256 ($parts -join "`n")
}

function Find-TuningGameProcess {
  if (-not (Test-AllowedGameExecutable $script:TargetExe)) { return $null }
  $full = [IO.Path]::GetFullPath($script:TargetExe)
  $name = [IO.Path]::GetFileNameWithoutExtension($full)
  foreach ($proc in @(Get-Process -Name $name -ErrorAction SilentlyContinue | Sort-Object StartTime -Descending)) {
    try { if ([IO.Path]::GetFullPath($proc.Path) -ieq $full) { return $proc } } catch {}
  }
  $null
}

function ConvertTo-TuningWireVariantId($State,[string]$LocalVariantId) {
  if("$($State.experimentId)" -notmatch '^exp_[0-9a-f]{32}$' -or $LocalVariantId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$') {
    throw '实验或本地方案 ID 无效'
  }
  $suffix='baseline'
  if($LocalVariantId -ne 'baseline'){
    $candidateMatches=@($State.candidates|Where-Object{"$($_.variantId)" -eq $LocalVariantId -or "$($_.groupId)" -eq $LocalVariantId})
    if($candidateMatches.Count -ne 1 -or "$($candidateMatches[0].groupId)" -notmatch '^G[123]$'){throw '本地方案没有对应的受信候选组'}
    $suffix="$($candidateMatches[0].groupId)"
  }
  "$($State.experimentId).$suffix"
}

function ConvertTo-TuningWireRunId($State,[string]$LocalRunId) {
  if("$($State.experimentId)" -notmatch '^exp_[0-9a-f]{32}$' -or $LocalRunId -notmatch '^run_[0-9a-f]{32}$') {
    throw '实验或本地运行 ID 无效'
  }
  "$($State.experimentId).$LocalRunId"
}

function Get-TuningWireItemIds($State,$Candidate) {
  if(-not $Candidate -or "$($Candidate.groupId)" -notmatch '^G[123]$'){throw '候选组无效'}
  $expectedControl=$(if(@($State.currentBestGroups).Count){"$((Get-TuningCandidate "$(@($State.currentBestGroups)[-1])").VariantId)"}else{'baseline'})
  if("$($Candidate.controlVariantId)" -ne $expectedControl){throw '候选组的对照方案与当前保留组合不一致'}
  $groups=@($State.currentBestGroups)+@("$($Candidate.groupId)")
  if(@($groups|Select-Object -Unique).Count -ne $groups.Count){throw '候选组与已保留组重复'}
  @($groups|ForEach-Object{@((Get-TuningCandidate "$_").ItemIds)}|ForEach-Object{"$_".ToLowerInvariant()}|Sort-Object -Unique)
}

function New-TuningTelemetryPayload {
  param([Parameter(Mandatory)][ValidateSet('experiment_started','variant_applied','run_completed','experiment_completed')][string]$TuningType,
        [Parameter(Mandatory)]$State, $Candidate, $Run, $Result, [string]$InstallId = '00000000-0000-0000-0000-000000000000', $Hw = $script:HardwareInfo)
  $mainGpu=@($Hw.Gpus|Where-Object{"$($_.Name)" -eq "$($Hw.MainGpuName)"}|Select-Object -First 1)
  $driverVersion=$(if($mainGpu.Count){"$($mainGpu[0].Driver)"}else{''})
  $displayMode=$(if([int]$Hw.DisplayWidth -gt 0 -and [int]$Hw.DisplayHeight -gt 0){"$([int]$Hw.DisplayWidth)x$([int]$Hw.DisplayHeight)@$([int]$Hw.DisplayRefreshHz)"}else{''})
  $payload = [ordered]@{
    installId=$InstallId;event='tuning';version="$script:GuiVersion";os="$($Hw.OS)";build="$($Hw.Build)";cpu="$($Hw.CPU)"
    gpuVendor="$($Hw.MainGpuVendor)";gpuModel="$($Hw.MainGpuName)";gpuModelVerified=[bool]$Hw.MainGpuNameVerified
    driverVersion=$driverVersion;gpuCount=[math]::Min(16,@($Hw.Gpus).Count);displayMode=$displayMode
    ramGb=[double]$Hw.RamGB;deviceType=$(if("$($Hw.FormFactor)" -in 'desktop','laptop','unknown'){"$($Hw.FormFactor)"}elseif($Hw.IsLaptop){'laptop'}else{'unknown'})
    cpuCores=[math]::Max(0,[int]$Hw.Cores);cpuThreads=[math]::Max(0,[int]$Hw.Threads);cpuPackages=[math]::Max(0,[int]$Hw.CpuPackages)
    memoryType="$($Hw.MemoryType)";memoryConfiguredMhz=[math]::Max(0,[int]$Hw.MemoryConfiguredMHz)
    memoryRatedMhz=[math]::Max(0,[int]$Hw.MemoryRatedMHz);memoryModuleCount=[math]::Max(0,[int]$Hw.MemoryModuleCount)
    virtualDisplayCount=[math]::Min(16,[math]::Max(0,[int]$Hw.VirtualDisplayCount));pagefileAutoManaged=[bool]$Hw.AutomaticManagedPagefile
    gpuReportedModelDiffers=[bool]("$($Hw.MainGpuReportedName)" -ne "$($Hw.MainGpuName)")
    tuningType=$TuningType;experimentId="$($State.experimentId)"
  }
  if(Get-Command Get-TelemetryAnalysisContext -ErrorAction SilentlyContinue){
    $analysisContext=Get-TelemetryAnalysisContext $Hw $script:TargetExe
    if($analysisContext){$payload.analysisContext=$analysisContext}
  }
  switch($TuningType){
    'experiment_started'{
      # 初始事件采用固定状态，便于“状态先落盘、入队前崩溃”后从已推进的实验状态
      # 重建完全相同的 business payload，并复用 outbox 中的稳定 eventId。
      $payload.status='baseline_pending';$payload.goal="$($State.goal)";$payload.riskLevel="$($State.riskLevel)"
      $payload.allowReboot=[bool]$State.allowReboot;$payload.allowHigherPower=[bool]$State.allowHigherPower
      $payload.maxTempIncreaseC=[double]$State.maxTempIncreaseC;$payload.maxPowerIncreasePct=[double]$State.maxPowerIncreasePct
      $payload.gameVersion="$($State.environment.gameVersion)";$payload.driverVersion="$($State.environment.driverVersion)"
      $payload.libraryVersion=[int]$State.libraryVersion
      $payload.baselineVariantId=ConvertTo-TuningWireVariantId $State 'baseline'
    }
    'variant_applied'{
      if(-not $Candidate -or -not $Result -or -not $Result.runtime -or -not $Result.reply){throw 'variant_applied 缺少结构化执行结果'}
      $lib=$Result.runtime.Library;$ids=@(Get-TuningWireItemIds $State $Candidate)
      # wire variant 表示当前活动的完整累计组合，而不是本次引擎只执行的 delta 组。
      # 本地只有“全部成功”才进入测试；其他结果按整个 wire variant 失败上报，不产生 partial 候选。
      $applyResult=$(if([bool]$Result.succeeded){'succeeded'}else{'failed'})
      $applied=$(if($applyResult -eq 'succeeded'){$ids.Count}else{0})
      $failed=$(if($applyResult -eq 'failed'){$ids.Count}else{0});$skipped=0
      $payload.status=$(if($applyResult -eq 'failed'){'apply_failed'}else{'variant_applied'})
      $payload.variantId=ConvertTo-TuningWireVariantId $State "$($Candidate.variantId)"
      $payload.controlVariantId=ConvertTo-TuningWireVariantId $State "$($Candidate.controlVariantId)"
      if(-not $Candidate.PSObject.Properties['sequenceNo'] -or [int]$Candidate.sequenceNo -lt 1 -or [int]$Candidate.sequenceNo -gt 64){throw '候选组缺少持久化的 wire 边界序号'}
      $payload.sequenceNo=[int]$Candidate.sequenceNo;$payload.groupId="$($Candidate.groupId)"
      $payload.itemSetHash=Get-TuningItemSetHash $ids;$payload.itemIds=@($ids);$payload.source="$($lib.Source)"
      $payload.riskLevel="$($lib.RiskLevel)";$payload.requiresReboot=[bool]$lib.RequiresReboot
      $payload.applyResult=$applyResult;$payload.appliedCount=[int]$applied;$payload.failedCount=[int]$failed;$payload.skippedCount=[int]$skipped
    }
    'run_completed'{
      if(-not $Run){throw 'run_completed 缺少运行记录'}
      $payload.runId=ConvertTo-TuningWireRunId $State "$($Run.runId)";$payload.variantId=ConvertTo-TuningWireVariantId $State "$($Run.variantId)";$payload.runNo=[int]$Run.runNo;$payload.sequenceNo=[int]$Run.sequenceNo
      $payload.validity="$($Run.validity)";$payload.invalidReason="$($Run.invalidReason)";$payload.durationSec=[int]$Run.durationSec
      $payload.avgFps=[double]$Run.avgFps;$payload.fps1Low=[double]$Run.fps1Low;$payload.p99FrameMs=[double]$Run.p99FrameMs
      $payload.stutter50Ms=[int]$Run.stutter50Ms;$payload.stutter100Ms=[int]$Run.stutter100Ms
      $payload.gpuUtilAvg=$(if($null -ne $Run.gpuUtilAvg){[double]$Run.gpuUtilAvg}else{$null})
      $payload.gpuTempAvg=$(if($null -ne $Run.gpuTempAvg){[double]$Run.gpuTempAvg}else{$null})
      $payload.gpuPowerAvg=$(if($null -ne $Run.gpuPowerAvg){[double]$Run.gpuPowerAvg}else{$null})
      if($Run.PSObject.Properties['frameCount']){$payload.frameCount=[int]$Run.frameCount}
      if($Run.PSObject.Properties['frameTimeMadMs']){$payload.frameTimeMadMs=[double]$Run.frameTimeMadMs}
      if($Run.PSObject.Properties['stuttersPerMin']){$payload.stuttersPerMin=[double]$Run.stuttersPerMin}
      if($Run.PSObject.Properties['focusLostSec']){$payload.focusLostSec=[double]$Run.focusLostSec}
      if($Run.PSObject.Properties['gpuTempMax']){$payload.gpuTempMax=$(if($null -ne $Run.gpuTempMax){[double]$Run.gpuTempMax}else{$null})}
      if($Run.PSObject.Properties['gameExitedEarly']){$payload.gameExitedEarly=[bool]$Run.gameExitedEarly}
      if($Run.PSObject.Properties['captureFailed']){$payload.captureFailed=[bool]$Run.captureFailed}
      if($Run.PSObject.Properties['presentMonExitCode']){$payload.presentMonExitCode=[int]$Run.presentMonExitCode}
      if($Run.PSObject.Properties['performanceContext'] -and $Run.performanceContext){$payload.performanceContext=$Run.performanceContext}
      $payload.settingsHash="$($Run.settingsHash)";$payload.environmentHash="$($Run.environmentHash)";$payload.orderControlled=[bool]$Run.orderControlled
    }
    'experiment_completed'{
      $autoRollback=[bool]$(if($Result -and $Result.PSObject.Properties['autoRollback']){$Result.autoRollback}else{$false})
      $serverResult=$(if("$($State.status)" -eq 'completed' -and "$($State.result)" -eq 'found_better'){'found_better'}
        elseif("$($State.status)" -eq 'completed'){'no_significant_gain'}elseif("$($State.status)" -eq 'rolled_back'){'rolled_back'}
        elseif("$($State.status)" -eq 'cancelled'){'cancelled'}else{'failed'})
      $payload.status=$(if($serverResult -in 'found_better','no_significant_gain'){'completed'}else{$serverResult})
      $payload.result=$serverResult
      $payload.stopReason=$(switch -Regex ("$($State.stopReason)"){
        'baseline|unstable'{'baseline_unstable';break}'apply'{'apply_failed';break}'environment|settings|driver|game_version'{'environment_changed';break}
        'user|cancel'{'user_cancelled';break}'safety|constraint'{'constraints_exceeded';break}'completed'{$(if($serverResult -eq 'no_significant_gain'){'no_improvement'}else{'completed'});break}
        default{'internal_error'} })
      $payload.winningVariantId=$(if($serverResult -eq 'found_better'){ConvertTo-TuningWireVariantId $State "$($State.currentBestVariantId)"}else{''})
      $payload.autoRollback=$autoRollback
    }
  }
  [pscustomobject]$payload
}

function Start-TuningTelemetryOutboxFlush {
  try {
    if (-not (Get-Command Invoke-DfbTuningOutboxFlush -ErrorAction SilentlyContinue)) { return }
    $configPath = Join-Path $script:UserConfigDir 'telemetry.json'
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return }
    try {
      $cfg = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($cfg.Enabled -eq $false) { return }
    } catch { return }
    Clear-CompletedTelemetryJobs
    $running = @($script:TelemetryJobs | Where-Object {
      $_.PSObject.Properties['Kind'] -and $_.Kind -eq 'tuning-outbox' -and -not $_.Async.IsCompleted
    })
    if ($running.Count) { return }
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($ModulePath,$Url,$ConfigPath)
      try {
        . $ModulePath
        # 每次只在 outbox 锁内发送一个事件，随后释放锁；这样 UI 同步持久化下一条
        # completion 时不会被一长串网络请求饿死。成功后再小步续排，退避则立即结束。
        for ($i=0; $i -lt 16; $i++) {
          $result = Invoke-DfbTuningOutboxFlush -UploadUrl $Url -ConfigPath $ConfigPath -MaxEvents 1
          if (-not $result -or [int]$result.remaining -le 0 -or [int]$result.acknowledged -le 0) { break }
          Start-Sleep -Milliseconds 25
        }
      } catch {}
    }).AddArgument($script:TelemetryClientPath).AddArgument($script:TelemetryUploadUrl).AddArgument($configPath)
    $async = $ps.BeginInvoke()
    [void]$script:TelemetryJobs.Add([pscustomobject]@{ PowerShell=$ps; Async=$async; Kind='tuning-outbox' })
  } catch {}
}

function New-TuningTelemetryEventPayload {
  param([Parameter(Mandatory)][string]$TuningType, $State, $Candidate, $Run, $Result,
        [switch]$RequirePersistence)
  try {
    if (-not $script:HardwareInfo.MainGpuNameVerified) { return $null }
    $installId = Get-TelemetryInstallId
    if (-not $installId) { return $null }
    New-TuningTelemetryPayload -TuningType $TuningType -State $State -Candidate $Candidate -Run $Run -Result $Result -InstallId $installId
  } catch {
    if ($RequirePersistence) { throw "自动调优遥测载荷生成失败：$($_.Exception.Message)" }
    $null
  }
}

function Send-TuningTelemetryPayload {
  param($Payload, [switch]$DeferFlush, [switch]$RequirePersistence)
  if (-not $Payload) { return }
  try {
    if (-not (Get-Command Add-DfbTuningOutboxEvent -ErrorAction SilentlyContinue)) {
      throw '缺少自动调优遥测 outbox 组件'
    }
    $configPath = Join-Path $script:UserConfigDir 'telemetry.json'
    Add-DfbTuningOutboxEvent -Payload $Payload -ConfigPath $configPath | Out-Null
    if (-not $DeferFlush) { Start-TuningTelemetryOutboxFlush }
  } catch {
    if ($RequirePersistence) { throw "自动调优事件未能持久化：$($_.Exception.Message)" }
  }
}

function Send-TuningTelemetryEvent {
  param([Parameter(Mandatory)][string]$TuningType, $State, $Candidate, $Run, $Result,
        [switch]$DeferFlush, [switch]$RequirePersistence)
  $payload = New-TuningTelemetryEventPayload -TuningType $TuningType -State $State -Candidate $Candidate -Run $Run -Result $Result -RequirePersistence:$RequirePersistence
  Send-TuningTelemetryPayload -Payload $payload -DeferFlush:$DeferFlush -RequirePersistence:$RequirePersistence
}

function Complete-GuiTuningExperimentTerminal([bool]$AutoRollback) {
  $state = $script:ActiveTuningExperiment
  if (-not $state -or "$($state.status)" -notin 'completed','rolled_back','cancelled','failed') {
    throw '只有终态实验可以执行完成收口'
  }
  if (-not $state.completedAt) { $state.completedAt = ConvertTo-TuningUtcText }
  # 终态只会在待提交步骤已完成 durable enqueue 之后到达；清除 continuation，避免重启重放已完成步骤。
  $state.pendingTuningCommit=$null
  # 先把终态写入状态文件并保留活动指针；随后同步把 completion 原子写入 outbox。
  # 只有两份持久数据都落盘后才清指针并异步发送，崩溃重启可按同一 eventId 去重续传。
  Save-TuningExperiment
  Send-TuningTelemetryEvent -TuningType 'experiment_completed' -State $state `
    -Result ([pscustomobject]@{autoRollback=$AutoRollback}) -DeferFlush -RequirePersistence
  Save-TuningExperiment -Terminal
  Start-TuningTelemetryOutboxFlush
  # 实验结束后普通性能采样会重新开放；先按真实活动备份刷新当前项目集合，避免后续
  # 会话仍沿用实验前的档位。已有普通优化与实验胜出组并存时会明确记为 mixed。
  try {
    $tuningIds = @($state.currentBestGroups | ForEach-Object { @((Get-TuningCandidate "$_").ItemIds) })
    $catalog = Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems
    Update-TelemetryOptimizationContextFromCatalog -Catalog $catalog -RequestedScheme 'auto-tuning' -RequestedItemIds $tuningIds
  } catch {}
  Update-TuningUi
}

function Update-TuningRunTable {
  if (-not $ui.TuneRunPanel) { return }
  $ui.TuneRunPanel.Children.Clear()
  if (-not $script:ActiveTuningExperiment -or -not @($script:ActiveTuningExperiment.runs).Count) {
    $empty = New-Text '还没有采样记录' $script:C.TextMut 10 -Mono
    $empty.Margin = New-Object Windows.Thickness 9,7,9,7
    $ui.TuneRunPanel.Children.Add($empty) | Out-Null; return
  }
  $allRuns = @($script:ActiveTuningExperiment.runs)
  foreach ($run in @($allRuns | Select-Object -Last 30)) {
    $grid = New-Object Windows.Controls.Grid; $grid.Height = 25
    foreach ($w in 42,100,70,70,70,70,58,58,58) { $c=New-Object Windows.Controls.ColumnDefinition; $c.Width=$w; $grid.ColumnDefinitions.Add($c) }
    $c=New-Object Windows.Controls.ColumnDefinition; $c.Width='*'; $grid.ColumnDefinitions.Add($c)
    $index = [array]::IndexOf($allRuns,$run) + 1
    $variant = $(if ($run.groupId -eq 'baseline') { '基线' } else { "$($run.groupId.ToUpper())/$($run.variantId)" })
    $reason = $(if ($run.validity -eq 'valid') { '有效' } else { "$($run.validity) / $($run.invalidReason)" })
    $values = @("$index",$variant,("{0:N1}" -f [double]$run.avgFps),("{0:N1}" -f [double]$run.fps1Low),
      ("{0:N1}" -f [double]$run.p99FrameMs),("{0:N1}" -f [double]$run.stuttersPerMin),("{0:N1}" -f [double]$run.gpuUtilAvg),
      ("{0:N1}" -f [double]$run.gpuTempAvg),("{0:N1}" -f [double]$run.gpuPowerAvg),$reason)
    for($i=0;$i -lt $values.Count;$i++) {
      $t=New-Text "$($values[$i])" $(if($run.validity -eq 'valid'){$script:C.TextSec}else{$script:C.Gold}) 10 -Mono
      $t.Margin=New-Object Windows.Thickness 7,4,3,3; [Windows.Controls.Grid]::SetColumn($t,$i); $grid.Children.Add($t)|Out-Null
    }
    $ui.TuneRunPanel.Children.Add($grid) | Out-Null
  }
}

function Update-TuningUi {
  if (-not $ui.TuneStatusText) { return }
  $state = $script:ActiveTuningExperiment; $active = [bool](Test-TuningExperimentActive)
  $moduleReady = $script:TuningModuleLoaded -and (Get-Command Get-TuningCandidateLibrary -ErrorAction SilentlyContinue)
  if (-not $state) {
    $ui.TuneStatusText.Text = $(if ($moduleReady) { '未创建' } else { '规则模块缺失，请重新安装' })
    $ui.TuneRoundText.Text='-'; $ui.TuneBaselineText.Text='待采样'; $ui.TuneCurrentText.Text='基线'
    foreach($n in 'TuneG1Text','TuneG2Text','TuneG3Text'){ if($ui[$n]){$ui[$n].Foreground=New-Brush $script:C.TextSec} }
  } else {
    $statusMap = @{ baseline_pending='基线待采样'; baseline_running='基线采样中'; variant_pending='候选对照实验'; variant_running='候选采样中'; final_validation='最终组合验证'; completed='已完成'; rolled_back='已回滚'; cancelled='已取消'; failed='已停止（需处理）' }
    $ui.TuneStatusText.Text = $(if($statusMap["$($state.status)"]){$statusMap["$($state.status)"]}else{"$($state.status)"})
    $idx=[int]$state.candidateIndex; $phase="$($state.phase)"
    $nextRound=@($state.runs).Count+1
    $ui.TuneRoundText.Text = $(if($idx -lt @($state.candidates).Count){"$($state.candidates[$idx].displayName) / 第 $nextRound 轮 / $phase"}else{"最终复测 / 第 $nextRound 轮 / $phase"})
    $baseRuns=@($state.runs|Where-Object groupId -eq 'baseline'); $base=Get-TuningBaselineSummary $baseRuns
    $ui.TuneBaselineText.Text=$(if($base.validRuns -ge 3){"有效 $($base.validRuns) 次 · CV $($base.noisePercent)% · $(if($base.stable){'稳定'}else{'不稳定'})"}else{"有效 $($base.validRuns) / 3"})
    $ui.TuneCurrentText.Text=$(if(@($state.currentBestGroups).Count){@($state.currentBestGroups|ForEach-Object{$_.ToUpper()}) -join ' + '}else{'基线'})
    foreach($i in 0..2){
      $cand=$state.candidates[$i]; $n="TuneG$($i+1)Text"; $label="G$($i+1) $($cand.displayName)"
      $ui[$n].Text="$label：$(if($cand.result){$cand.result}elseif($cand.status){$cand.status}else{'待实验'})"
      $ui[$n].Foreground=New-Brush $(if($cand.result -eq 'win'){$script:C.Green}elseif($cand.result -match 'rollback|no_gain|failed'){'#FFE5484D'}else{$script:C.TextSec})
    }
    if ($state.lastMessage) { $ui.TuneHintText.Text="$($state.lastMessage)" }
  }
  foreach($n in 'TuneSceneBox','TuneTempBox','TunePowerChk','TunePowerBox'){ if($ui[$n]){$ui[$n].IsEnabled=-not $active -and -not $script:Busy} }
  $ui.TunePowerBox.IsEnabled=(-not $active -and -not $script:Busy -and [bool]$ui.TunePowerChk.IsChecked)
  $ui.TuneCreateBtn.IsEnabled=[bool]$moduleReady -and -not $script:Busy -and -not $script:TuningSampling
  $ui.TuneCreateBtn.Content=$(if($active){'继续当前实验'}else{'创建实验'})
  $ui.TuneNextBtn.IsEnabled=$active -and -not $script:Busy -and -not $script:TuningSampling
  $ui.TuneStopBtn.IsEnabled=$active -and -not $script:Busy -and -not $script:TuningSampling
  Update-TuningRunTable
  # 实验活动期间禁止普通系统写入、全量还原、路径变更和更新安装入口。
  foreach($n in 'ApplyBtn','RestoreBtn','BrowseBtn','UpdateBtn','CheckUpdBtn',
                 'InlineRestoreSelectAllBtn','InlineRestoreClearBtn','InlineRestoreSelectedBtn',
                 'InlineRestoreAllBtn','InlineRestoreCloseBtn') {
    if($ui[$n]){$ui[$n].IsEnabled=(-not $active -and -not $script:Busy)}
  }
  if ($ui.InlineRestorePanel -and $ui.InlineRestorePanel.Visibility -eq 'Visible') {
    Update-InlineRestoreSelection
  }
}

function Get-ValidatedTuningCandidateRuntime([string]$GroupId) {
  $library = Get-TuningCandidate $GroupId
  if ("$($library.Source)" -ne 'rules' -or "$($library.RiskLevel)" -ne 'low' -or [bool]$library.RequiresReboot) {
    throw '候选库包含超出 Beta 边界的项目'
  }
  $all = @(Get-OptItems $script:TargetExe)
  $resolved = New-Object System.Collections.Generic.List[object]
  foreach ($id in @($library.ItemIds)) {
    $matches = @($all | Where-Object Id -eq "$id")
    if ($matches.Count -ne 1) { throw "候选优化项不存在或重复：$id" }
    $item = $matches[0]
    if ("$($item.Tier)" -ne 'safe' -or [bool]$item.Reboot -or "$($item.Kind)" -in 'cache','check','npi','power','sched') {
      throw "候选项不符合低风险/无重启边界：$id"
    }
    if (-not @($item.Ops).Count) { throw "候选项没有可备份操作：$id" }
    foreach ($op in @($item.Ops)) {
      if ("$($op.Kind)" -notin 'reg','kvstr') { throw "候选项包含 Beta 不接受的操作：$id/$($op.Kind)" }
    }
    if ([bool]$item.RequiresGame -and -not (Test-AllowedGameExecutable $script:TargetExe)) { throw "候选项需要有效游戏路径：$id" }
    [void]$resolved.Add($item)
  }
  [pscustomobject]@{ Library=$library; Items=@($resolved.ToArray()) }
}

function Invoke-TuningRollbackBackup([string]$BackupFile, [string]$Reason) {
  if (-not (Test-TuningBackupReference $BackupFile)) { throw '只允许按当前实验的受保护备份回滚' }
  $reply = Invoke-ElevatedEngineAction -Action Restore -BackupFile $BackupFile
  if ([int]$reply.EngineExitCode -ne 0 -or @($reply.Failed).Count -gt 0) {
    throw "回滚失败（$Reason）：$(@($reply.Failed) -join '；')"
  }
  $script:TuningConfigGeneration++
  if ($script:ActiveTuningExperiment) { $script:ActiveTuningExperiment.configGeneration = $script:TuningConfigGeneration }
  Write-Log "自动调优已按指定备份回滚：$(Split-Path -Leaf $BackupFile)（$Reason）"
  $reply
}

function Set-PendingTuningCommit {
  param([Parameter(Mandatory)][ValidateSet('run','variant')][string]$Kind,
        [Parameter(Mandatory)][string]$SourcePhase,
        [Parameter(Mandatory)][int]$CandidateIndex,
        [Parameter(Mandatory)][string]$EntityId,
        $Payload,
        [string]$ResumePhase='',
        [string]$Outcome='',
        [bool]$UnsafeFailure=$false,
        [string]$Reason='')
  $state=$script:ActiveTuningExperiment
  if(-not $state){throw '没有活动实验可提交'}
  if($state.pendingTuningCommit){throw '已有待提交实验步骤，已拒绝覆盖'}
  $state.pendingTuningCommit=[pscustomobject][ordered]@{
    schemaVersion=1;kind=$Kind;telemetryType=$(if($Kind -eq 'run'){'run_completed'}else{'variant_applied'})
    sourcePhase=$SourcePhase;candidateIndex=$CandidateIndex;entityId=$EntityId;resumePhase=$ResumePhase
    outcome=$Outcome;unsafeFailure=$UnsafeFailure;reason=$Reason;payload=$Payload
  }
  try{Save-TuningExperiment}
  catch{
    # 状态 Replace 可能已成功、仅后续 pointer 写失败；此时绝不能回滚内存后再次采样。
    $persisted=$null
    try{$persisted=Read-TuningState $script:ActiveTuningStatePath}catch{}
    if($persisted -and $persisted.pendingTuningCommit -and "$($persisted.pendingTuningCommit.entityId)" -eq $EntityId){
      $script:ActiveTuningExperiment=Initialize-TuningGuiStateFields $persisted
      throw
    }
    $state.pendingTuningCommit=$null
    if($Kind -eq 'run'){$state.runs=@($state.runs|Where-Object runId -ne $EntityId)}
    throw
  }
  $state.pendingTuningCommit
}

function Complete-TuningVariantApplyDisposition {
  param([Parameter(Mandatory)]$Candidate,[Parameter(Mandatory)][bool]$Succeeded,
        [string]$Reason='',[bool]$UnsafeFailure=$false,[string]$ResumePhase='group_capture_b1')
  $state=$script:ActiveTuningExperiment
  if(-not $Succeeded){
    if($Candidate.activeBackup){
      $state.phase='rolling_back';Save-TuningExperiment
      try{Invoke-TuningRollbackBackup "$($Candidate.activeBackup)" '候选套用验证失败'|Out-Null;$Candidate.activeBackup=''}
      catch{$state.status='failed';$state.phase='failed';$state.stopReason='rollback_failed';$state.lastMessage=$_.Exception.Message;Complete-GuiTuningExperimentTerminal $true;throw}
    }elseif($UnsafeFailure){
      $state.status='failed';$state.phase='failed';$state.stopReason='apply_without_backup'
      $state.lastMessage='套用后没有可信的指定备份，已停止。请使用普通「还原设置」或上传诊断报告。'
      Complete-GuiTuningExperimentTerminal $false;throw $state.lastMessage
    }
    $state.pendingActionId='';$state.pendingResumePhase='';$state.lastMessage="已跳过 $($Candidate.displayName)：$Reason"
    Complete-TuningCandidate $Candidate ([pscustomobject]@{result='inconclusive';reason=$Reason}) $false
    return $false
  }
  $state.phase=$ResumePhase;$state.pendingActionId='';$state.pendingResumePhase=''
  $state.status='variant_applied';$state.lastMessage="$($Candidate.displayName) 已套用并保存受保护备份，下一步采样。"
  if("$($Candidate.groupId)" -eq 'G3'){$state.groupRestartAfter=[DateTime]::UtcNow.ToString('o')}
  Save-TuningExperiment
  $true
}

function Test-PendingTuningRunConsumed($State,$Pending,$Run){
  switch("$($Pending.sourcePhase)"){
    'baseline'{return @($State.initialBaselineRunIds) -contains "$($Run.runId)"}
    'final_capture'{return @($State.finalRunIds) -contains "$($Run.runId)"}
    'group_control_pre'{return @($State.candidates[[int]$Pending.candidateIndex].controlRunIds) -contains "$($Run.runId)"}
    'group_capture_b1'{return @($State.candidates[[int]$Pending.candidateIndex].candidateRunIds) -contains "$($Run.runId)"}
    'group_capture_a'{return @($State.candidates[[int]$Pending.candidateIndex].controlRunIds) -contains "$($Run.runId)"}
    'group_capture_b2'{return @($State.candidates[[int]$Pending.candidateIndex].candidateRunIds) -contains "$($Run.runId)"}
    'group_capture_extra_a'{return @($State.candidates[[int]$Pending.candidateIndex].controlRunIds) -contains "$($Run.runId)"}
    'group_capture_extra_b'{return @($State.candidates[[int]$Pending.candidateIndex].candidateRunIds) -contains "$($Run.runId)"}
  }
  $false
}

function Test-PendingTuningRunCompleted($State,$Pending,$Run){
  if(-not (Test-PendingTuningRunConsumed $State $Pending $Run)){return $false}
  $idx=[int]$Pending.candidateIndex
  switch("$($Pending.sourcePhase)"){
    'baseline'{return "$($State.phase)" -ne 'baseline'}
    'final_capture'{return "$($State.status)" -in 'completed','rolled_back','cancelled','failed'}
    'group_control_pre'{return "$($State.phase)" -ne 'group_control_pre'}
    'group_capture_b1'{return "$($State.phase)" -ne 'group_capture_b1'}
    'group_capture_a'{return "$($State.phase)" -ne 'group_capture_a'}
    'group_capture_b2'{return "$($State.candidates[$idx].status)" -eq 'complete' -or "$($State.phase)" -eq 'group_rollback_extra_a' -or [int]$State.candidateIndex -gt $idx}
    'group_capture_extra_a'{return "$($State.phase)" -ne 'group_capture_extra_a'}
    'group_capture_extra_b'{return "$($State.candidates[$idx].status)" -eq 'complete' -or [int]$State.candidateIndex -gt $idx}
  }
  $false
}

function Resume-PendingTuningCommit {
  $state=$script:ActiveTuningExperiment;$pending=$state.pendingTuningCommit
  if(-not $pending){return $false}
  # Exact payload was saved with the engine/capture result. Durable idempotent enqueue is the commit point.
  Send-TuningTelemetryPayload -Payload $pending.payload -DeferFlush -RequirePersistence
  if("$($pending.kind)" -eq 'run'){
    $runs=@($state.runs|Where-Object runId -eq "$($pending.entityId)")
    if($runs.Count -ne 1){throw '待提交运行记录不存在或重复'}
    $run=$runs[0]
    $completed=Test-PendingTuningRunCompleted $state $pending $run
    $resumableRollback=("$($state.phase)" -eq 'rolling_back' -and "$($pending.sourcePhase)" -in 'group_capture_b2','group_capture_extra_b','final_capture')
    if(-not $completed -and ("$($state.phase)" -eq "$($pending.sourcePhase)" -or $resumableRollback)){
      Advance-TuningAfterValidRun $run "$($pending.sourcePhase)" ([int]$pending.candidateIndex)
    }elseif(-not $completed){
      throw '待提交运行与当前实验阶段不一致，已拒绝重复采样'
    }
  }else{
    $candidate=$state.candidates[[int]$pending.candidateIndex]
    if("$($candidate.variantId)" -ne "$($pending.entityId)"){throw '待提交候选引用无效'}
    $alreadyProcessed=("$($pending.outcome)" -eq 'succeeded' -and "$($state.phase)" -eq "$($pending.resumePhase)" -and -not $state.pendingActionId) -or
      "$($candidate.status)" -eq 'complete' -or [int]$state.candidateIndex -gt [int]$pending.candidateIndex
    if(-not $alreadyProcessed){
      [void](Complete-TuningVariantApplyDisposition $candidate ("$($pending.outcome)" -eq 'succeeded') "$($pending.reason)" ([bool]$pending.unsafeFailure) "$($pending.resumePhase)")
    }
  }
  $state=$script:ActiveTuningExperiment
  if($state -and $state.pendingTuningCommit -and "$($state.pendingTuningCommit.entityId)" -eq "$($pending.entityId)"){
    $state.pendingTuningCommit=$null;Save-TuningExperiment
  }
  Start-TuningTelemetryOutboxFlush
  $true
}

function Invoke-TuningApplyCandidate($Candidate, [string]$ResumePhase) {
  $state = $script:ActiveTuningExperiment
  if($state.pendingTuningCommit){throw '上一个实验步骤尚未完成持久提交，请先继续恢复'}
  $runtime = Get-ValidatedTuningCandidateRuntime "$($Candidate.groupId)"
  $candidateIndex=[array]::IndexOf(@($state.candidates),$Candidate)
  if($candidateIndex -lt 0){throw '候选组不属于当前实验'}
  if($ResumePhase -eq 'group_capture_b1'){
    # 服务端用该边界确定性选取：对照取 seq < boundary 的最后 3 次，
    # 候选取 seq >= boundary 的前 2 次（需要时第 3 次）。必须在首次 B1 Apply 前持久化。
    $expectedBoundary=[int](@($state.runs).Count+1)
    if($Candidate.PSObject.Properties['sequenceNo']){
      if([int]$Candidate.sequenceNo -ne $expectedBoundary){throw '候选组遥测边界与首次 B1 不一致'}
    }else{Add-TuningStateProperty $Candidate 'sequenceNo' $expectedBoundary}
  }elseif(-not $Candidate.PSObject.Properties['sequenceNo'] -or [int]$Candidate.sequenceNo -lt 1 -or [int]$Candidate.sequenceNo -gt 64){
    throw '候选组缺少首次 B1 持久化的遥测边界'
  }
  $actionId = [guid]::NewGuid().ToString('D')
  $state.phase = 'applying'; $state.pendingActionId = $actionId; $state.pendingResumePhase = $ResumePhase
  $state.status = 'variant_running'; $state.lastMessage = "等待管理员授权，套用 $($Candidate.displayName)…"
  Save-TuningExperiment
  Update-TuningUi

  $reply = $null
  try {
    $reply = Invoke-ElevatedEngineAction -Action Apply -ItemIds @($runtime.Library.ItemIds) `
      -GamePath $script:TargetExe -ResultId $actionId
  } catch {
    $retryPhase=$(switch($ResumePhase){'group_capture_b1'{'group_apply_b1'}'group_capture_b2'{'group_apply_b2'}'group_capture_extra_b'{'group_apply_extra_b'}default{'group_apply_b1'}})
    $state.phase = $retryPhase; $state.pendingActionId=''; $state.pendingResumePhase=''
    $state.lastMessage = "候选套用未完成：$($_.Exception.Message)"
    Save-TuningExperiment
    throw
  }

  # 结果一返回就先持久化备份引用；验证和界面刷新都放在它之后，缩短 crash window。
  if ($reply.Backup -and (Test-TuningBackupReference "$($reply.Backup)")) {
    $Candidate.activeBackup = "$($reply.Backup)"
    $script:TuningConfigGeneration++; $state.configGeneration = $script:TuningConfigGeneration
    Save-TuningExperiment
  }

  $rows = @($reply.Results); $expected = @($runtime.Library.ItemIds)
  $seen = @($rows | ForEach-Object { "$($_.Id)" } | Sort-Object)
  $expectedSorted = @($expected | Sort-Object)
  $allOk = $rows.Count -eq $expected.Count -and ($seen -join ',') -eq ($expectedSorted -join ',') -and
           @($rows | Where-Object { -not $_.Ok -or $_.Skipped }).Count -eq 0
  $changed = @($rows | Where-Object { $_.Ok -and $_.Changed -eq $true }).Count
  $noReboot = @($rows | Where-Object { $_.Reboot -eq $true }).Count -eq 0
  $validBackup = $Candidate.activeBackup -and (Test-TuningBackupReference "$($Candidate.activeBackup)")
  $success = [int]$reply.EngineExitCode -eq 0 -and $allOk -and -not $reply.BackupError -and
             $changed -gt 0 -and $validBackup -and $noReboot

  $why=@()
  if(-not $allOk){$why+='关键项未全部成功'}
  if($reply.BackupError){$why+="备份错误：$($reply.BackupError)"}
  if($changed -le 0){$why+='没有产生实际改动'}
  if(-not $validBackup){$why+='未返回受保护备份'}
  if(-not $noReboot){$why+='候选结果要求重启'}
  $unsafeFailure=(-not $success -and -not $validBackup -and ($changed -gt 0 -or [bool]$reply.BackupError))
  if($ResumePhase -eq 'group_capture_b1'){
    $result=[pscustomobject]@{runtime=$runtime;reply=$reply;succeeded=$success;changed=$changed}
    $payload=New-TuningTelemetryEventPayload -TuningType 'variant_applied' -State $state -Candidate $Candidate -Result $result -RequirePersistence
    Set-PendingTuningCommit -Kind variant -SourcePhase applying -CandidateIndex $candidateIndex -EntityId "$($Candidate.variantId)" `
      -Payload $payload -ResumePhase $ResumePhase -Outcome $(if($success){'succeeded'}else{'failed'}) `
      -UnsafeFailure $unsafeFailure -Reason ($why -join '；')|Out-Null
    [void](Resume-PendingTuningCommit)
    return $success
  }
  if (-not $success) {
    $disposition=Complete-TuningVariantApplyDisposition $Candidate $false ($why -join '；') $unsafeFailure $ResumePhase
    return $disposition
  }
  Complete-TuningVariantApplyDisposition $Candidate $true '' $false $ResumePhase
}

function Test-TuningProcessReady($Process) {
  $state=$script:ActiveTuningExperiment
  if (-not $Process) { throw '未检测到已运行的目标游戏，请先启动游戏并进入固定场景' }
  if ($state.groupRestartAfter) {
    try {
      if ($Process.StartTime.ToUniversalTime() -lt [DateTime]::Parse("$($state.groupRestartAfter)").ToUniversalTime()) {
        throw '这一组改动后需要关闭并重新启动游戏，再执行采样'
      }
      $state.groupRestartAfter=''; Save-TuningExperiment
    } catch [FormatException] { throw '游戏重启时间记录无效，已停止继续' }
  }
  $true
}

function Invoke-TuningPerformanceCapture([string]$VariantId,[string]$GroupId,[bool]$OrderControlled=$true) {
  $state=$script:ActiveTuningExperiment
  if($state.pendingTuningCommit){throw '上一个实验步骤尚未完成持久提交，请先继续恢复'}
  $sourcePhase="$($state.phase)";$sourceCandidateIndex=$(if($GroupId -eq 'baseline'){-1}elseif($GroupId -eq 'final'){@($state.candidates).Count}else{[int]$state.candidateIndex})
  if (@($script:PerformanceJobs | Where-Object { -not $_.Async.IsCompleted }).Count) {
    throw '普通性能采样正在收尾，请等它完成后再开始实验轮次'
  }
  $proc=Find-TuningGameProcess; [void](Test-TuningProcessReady $proc)
  $confirm="请确认已进入固定场景「$($state.sceneId)」，且本轮不会改分辨率、画质、帧率上限或离开前台。`n`n确认后将连续采样 120 秒。"
  if (-not (Show-ConfirmDialog '开始采样' '120 SECOND CONTROLLED RUN' $confirm '我已就位')) { return $null }

  $beforeEnv=Get-TuningEnvironmentSnapshot "$($state.sceneId)"; $beforeHash=Get-TuningEnvironmentHash $beforeEnv
  $settingsBefore=Get-TuningSettingsHash; $generation=[int64]$script:TuningConfigGeneration
  $presentMon=Join-Path $script:RootDir 'tools\PresentMon.exe'
  if (-not (Test-Path -LiteralPath $presentMon -PathType Leaf)) { throw '缺少 tools\PresentMon.exe，请重新安装后再实验' }

  $script:TuningSampling=$true; Set-BusyState $true
  $state.status=$(if($GroupId -eq 'baseline'){'baseline_running'}else{'variant_running'})
  $state.lastMessage="正在采样 $VariantId：请保持游戏在前台，不要改设置…"; Save-TuningExperiment; Update-TuningUi
  $ps=[PowerShell]::Create(); [void]$ps.AddScript($script:PerformanceCaptureWorker)
  Add-PerformanceWorkerArguments $ps $proc.Id $script:HardwareInfo 'experiment' 0
  try {
    $async=$ps.BeginInvoke()
    while(-not $async.IsCompleted){
      $window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
      Start-Sleep -Milliseconds 100
    }
    $outputs=@($ps.EndInvoke($async)); $metrics=@($outputs|Where-Object{$_.PSObject.Properties['frameCount']}|Select-Object -Last 1)
    if(-not $metrics){ throw '性能采样线程没有返回结果' }
  } finally {
    try{$ps.Dispose()}catch{}; $script:TuningSampling=$false; Set-BusyState $false
  }

  $sceneMatches=Show-ConfirmDialog '场景复核' 'SCENE CHECK' "本轮 120 秒是否全程保持在「$($state.sceneId)」同一场景和操作路线？`n`n如果中途切换场景，请点取消，本轮会记为 scene_changed 且不参与胜负。" '场景一致'
  $manualSettingsMatch=Show-ConfirmDialog '设置复核' 'SETTINGS CHECK' '本轮是否没有修改游戏画质、渲染比例、帧率上限、分辨率或显示模式？`n`n如果改过，请点取消，本轮会记为 settings_changed 且不参与胜负。' '设置未变'
  $afterEnv=Get-TuningEnvironmentSnapshot "$($state.sceneId)"; $afterHash=Get-TuningEnvironmentHash $afterEnv
  $settingsAfter=Get-TuningSettingsHash
  $driverMatch=("$($state.environment.driverVersion)" -eq "$($beforeEnv.driverVersion)" -and "$($beforeEnv.driverVersion)" -eq "$($afterEnv.driverVersion)")
  $gameMatch=("$($state.environment.gameVersion)" -eq "$($beforeEnv.gameVersion)" -and "$($beforeEnv.gameVersion)" -eq "$($afterEnv.gameVersion)")
  $settingsMatch=([bool]$manualSettingsMatch -and $generation -eq [int64]$script:TuningConfigGeneration -and $settingsBefore -eq $settingsAfter -and $beforeHash -eq $afterHash)
  $validity=Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash "$($state.environmentHash)" `
    -ActualEnvironmentHash $afterHash -DriverMatches $driverMatch -GameVersionMatches $gameMatch -SettingsMatch $settingsMatch -SceneMatches ([bool]$sceneMatches)
  $runNo=@($state.runs|Where-Object variantId -eq $VariantId).Count+1;$sequenceNo=@($state.runs).Count+1
  if($runNo -gt 16 -or $sequenceNo -gt 64){throw '实验重试次数已达上限，请停止并回滚后重新创建'}
  $run=New-TuningRunRecord -ExperimentId "$($state.experimentId)" -VariantId $VariantId -GroupId $GroupId `
    -RunNo $runNo -SequenceNo $sequenceNo `
    -Metrics $metrics -Validity $validity -EnvironmentHash $afterHash -SettingsHash $settingsAfter -OrderControlled $OrderControlled
  $run | Add-Member -NotePropertyName presentMonExitCode -NotePropertyValue ([int]$metrics.presentMonExitCode)
  $run | Add-Member -NotePropertyName gameExitedEarly -NotePropertyValue ([bool]$metrics.gameExitedEarly)
  $run | Add-Member -NotePropertyName captureFailed -NotePropertyValue ([bool]$metrics.captureFailed)
  # 先生成精确 wire payload，再把 run 加进活动内存；载荷/telemetry 配置失败时不会留下
  # 一条没有 pending continuation 的幽灵 run，被下一轮误带进状态文件。
  $payload=$(if($GroupId -ne 'final'){New-TuningTelemetryEventPayload -TuningType 'run_completed' -State $state -Run $run -RequirePersistence}else{$null})
  $script:ActiveTuningExperiment=Add-TuningRun $state $run
  $state=$script:ActiveTuningExperiment
  $state.lastMessage=$(if($run.validity -eq 'valid'){"第 $($run.sequenceNo) 轮有效：平均帧率 $($run.avgFps)，1% 低帧率 $($run.fps1Low)。"}else{"本轮 $($run.validity)（$($run.invalidReason)），不参与胜负，请重试当前步骤。"})
  # final 是非交替的本地安全复核；不把它混入服务端候选组 A/B runs，否则会污染胜出证据。
  Set-PendingTuningCommit -Kind run -SourcePhase $sourcePhase -CandidateIndex $sourceCandidateIndex -EntityId "$($run.runId)" -Payload $payload|Out-Null
  Update-TuningUi
  $run
}

function Get-TuningRunsByIds($State,[object[]]$Ids) {
  $wanted=@($Ids|ForEach-Object{"$_"})
  @($State.runs|Where-Object{$wanted -contains "$($_.runId)"})
}

function Complete-TuningCandidate($Candidate,$Comparison,[bool]$AllowWin) {
  $state=$script:ActiveTuningExperiment
  $result="$($Comparison.result)"
  if($AllowWin -and $result -eq 'win'){
    if(-not (Test-TuningBackupReference "$($Candidate.activeBackup)")){throw '胜出候选缺少可供最终反向回滚的备份'}
    $Candidate.status='complete';$Candidate.result='win';$Candidate.comparison=$Comparison
    $Candidate.appliedBackups=@($Candidate.appliedBackups)+@("$($Candidate.activeBackup)")
    $state.activeBackups=@($state.activeBackups)+@("$($Candidate.activeBackup)");$Candidate.activeBackup=''
    $state.currentBestGroups=@($state.currentBestGroups)+@("$($Candidate.groupId)");$state.currentBestVariantId="$($Candidate.variantId)"
    $state.lastMessage="$($Candidate.displayName) 超过设备自身噪声并通过温度/功耗约束，已保留。"
  } else {
    if($Candidate.activeBackup){
      $state.phase='rolling_back';Save-TuningExperiment
      try{Invoke-TuningRollbackBackup "$($Candidate.activeBackup)" "候选结果 $result"|Out-Null;$Candidate.activeBackup=''}
      catch{$state.status='failed';$state.phase='failed';$state.stopReason='rollback_failed';$state.lastMessage=$_.Exception.Message;Complete-GuiTuningExperimentTerminal $true;throw}
    }
    $Candidate.status='complete';$Candidate.result=$(if($result -eq 'rollback'){'rollback'}else{'no_gain'});$Candidate.comparison=$Comparison
    $state.lastMessage="$($Candidate.displayName) 未达到保留规则，已只回滚它自己的备份。"
  }
  $state.candidateIndex=[int]$state.candidateIndex+1
  if([int]$state.candidateIndex -lt @($state.candidates).Count){$state.status='variant_pending';$state.phase='group_control_pre'}
  else{$state.status='final_validation';$state.phase='final_capture'}
  Save-TuningExperiment;Update-TuningUi
}

function Compare-CurrentTuningCandidate($Candidate,[bool]$FinalAttempt){
  $state=$script:ActiveTuningExperiment
  $controls=Get-TuningRunsByIds $state @($Candidate.controlRunIds)
  $variants=Get-TuningRunsByIds $state @($Candidate.candidateRunIds)
  $cmp=Compare-TuningVariant -ControlRuns $controls -CandidateRuns $variants `
    -MaxTempIncreaseC ([double]$state.maxTempIncreaseC) -MaxPowerIncreasePct ([double]$state.maxPowerIncreasePct) `
    -AllowHigherPower ([bool]$state.allowHigherPower)
  $Candidate.comparison=$cmp;Save-TuningExperiment
  if("$($cmp.result)" -eq 'inconclusive' -and -not $FinalAttempt){
    $Candidate.extraAttempted=$true;$state.phase='group_rollback_extra_a';$state.lastMessage='变化还在噪声范围内，追加一次 A/B 交替采样。';Save-TuningExperiment;Update-TuningUi;return
  }
  Complete-TuningCandidate $Candidate $cmp $true
}

function Remove-TuningBackupFromState($State,[string]$BackupFile) {
  $State.activeBackups=@($State.activeBackups|Where-Object{"$_" -ne $BackupFile})
  foreach($candidate in @($State.candidates)){
    if("$($candidate.activeBackup)" -eq $BackupFile){$candidate.activeBackup=''}
    $candidate.appliedBackups=@($candidate.appliedBackups|Where-Object{"$_" -ne $BackupFile})
    if("$($candidate.result)" -eq 'win' -and -not @($candidate.appliedBackups).Count){$candidate.result='rollback'}
  }
  $State.currentBestGroups=@($State.candidates|Where-Object result -eq 'win'|ForEach-Object{"$($_.groupId)"})
  $State.currentBestVariantId=$(if(@($State.currentBestGroups).Count){"$((Get-TuningCandidate "$(@($State.currentBestGroups)[-1])").VariantId)"}else{'baseline'})
}

function Invoke-TuningFinalRollback {
  $state=$script:ActiveTuningExperiment
  $remaining=New-Object System.Collections.Generic.List[string]
  foreach($b in @($state.activeBackups)){[void]$remaining.Add("$b")}
  $state.phase='rolling_back';$state.lastMessage='正在按相反顺序执行最终安全回滚…';Save-TuningExperiment
  for($i=$remaining.Count-1;$i -ge 0;$i--){
    $backup=$remaining[$i]
    try{
      Invoke-TuningRollbackBackup $backup '最终安全阈值触发'|Out-Null;$remaining.RemoveAt($i)
      Remove-TuningBackupFromState $state $backup
      $state.lastMessage="已回滚 $([IO.Path]::GetFileName($backup))；剩余 $($remaining.Count) 份指定备份。";Save-TuningExperiment
    }
    catch{$state.status='failed';$state.phase='failed';$state.stopReason='final_rollback_failed';$state.lastMessage=$_.Exception.Message;Complete-GuiTuningExperimentTerminal $true;throw}
  }
}

function Resolve-TuningFinalOutcome($State,$Comparison) {
  $hasRetained=@($State.currentBestGroups).Count -gt 0
  $comparisonResult="$($Comparison.result)"
  if(-not $hasRetained){
    return [pscustomobject]@{autoRollback=$false;status='completed';result='no_significant_gain'}
  }
  if($comparisonResult -in 'rollback','insufficient'){
    return [pscustomobject]@{autoRollback=$true;status='rolled_back';result='rolled_back'}
  }
  if($comparisonResult -ne 'inconclusive'){
    throw '最终安全复核返回了不应用于胜负的结果'
  }
  # found_better 的证据只来自前面各组 orderControlled=true 的交替 A/B；
  # final 的非交替三轮只能否决（安全回滚），不能独立创造胜出结论。
  [pscustomobject]@{autoRollback=$false;status='completed';result='found_better'}
}

function Advance-TuningAfterValidRun($Run,[string]$SourcePhase='',[int]$SourceCandidateIndex=-2){
  if(-not $Run -or $Run.validity -ne 'valid'){return}
  $state=$script:ActiveTuningExperiment;$phase=$(if($SourcePhase){$SourcePhase}else{"$($state.phase)"})
  if($phase -eq 'baseline'){
    $valid=@($state.runs|Where-Object{$_.groupId -eq 'baseline' -and $_.validity -eq 'valid'})
    if($valid.Count -lt 3){return}
    $summary=Get-TuningBaselineSummary $valid
    if(-not $summary.stable){$state.status='failed';$state.phase='failed';$state.stopReason='unstable_baseline';$state.lastMessage="基线波动过大（CV $($summary.noisePercent)%），本次实验停止；请固定场景后重新创建。";Complete-GuiTuningExperimentTerminal $false;return}
    $state.initialBaselineRunIds=@($valid|Select-Object -First 3|ForEach-Object{$_.runId});$state.status='variant_pending';$state.phase='group_control_pre';$state.lastMessage='基线已稳定，下一步对 G1 先做一次 A 对照复测。';Save-TuningExperiment;Update-TuningUi;return
  }
  if([int]$state.candidateIndex -ge @($state.candidates).Count){
    if($phase -ne 'final_capture'){return}
    if(@($state.finalRunIds) -notcontains "$($Run.runId)"){$state.finalRunIds=@($state.finalRunIds)+@("$($Run.runId)");Save-TuningExperiment}
    $finalRuns=Get-TuningRunsByIds $state $state.finalRunIds
    if(@($finalRuns|Where-Object validity -eq 'valid').Count -lt 3){return}
    $base=Get-TuningRunsByIds $state $state.initialBaselineRunIds
    $resumeSafetyRollback=("$($state.phase)" -eq 'rolling_back' -and $state.finalComparison -and "$($state.finalComparison.result)" -in 'rollback','insufficient')
    if($resumeSafetyRollback){
      # finalComparison/rollback intent 已在撤第一份备份前随 rolling_back 原子保存；即使所有
      # activeBackups 都撤完后崩溃，也必须沿用原安全结论，不能因 currentBest 已清空翻案。
      $cmp=$state.finalComparison
    }elseif(@($state.currentBestGroups).Count){
      $cmp=Compare-TuningVariant -ControlRuns $base -CandidateRuns $finalRuns -MaxTempIncreaseC ([double]$state.maxTempIncreaseC) `
        -MaxPowerIncreasePct ([double]$state.maxPowerIncreasePct) -AllowHigherPower ([bool]$state.allowHigherPower) -SafetyOnly
    } else {
      # 三组都未保留时当前组合就是初始基线；仍完成三次最终复测，
      # 但不把同一 variant 伪装成 A/B 输给比较器。
      $cmp=[pscustomobject]@{result='inconclusive';reason='没有候选超过基线噪声'}
    }
    $state.finalComparison=$cmp
    $outcome=$(if($resumeSafetyRollback){[pscustomobject]@{autoRollback=$true;status='rolled_back';result='rolled_back'}}else{Resolve-TuningFinalOutcome $state $cmp})
    $autoRollback=[bool]$outcome.autoRollback
    if($autoRollback){Invoke-TuningFinalRollback}
    $state.status="$($outcome.status)";$state.phase='completed';$state.completedAt=ConvertTo-TuningUtcText
    $state.result="$($outcome.result)"
    $state.stopReason=$(if($autoRollback){'safety_threshold'}else{'completed'})
    $state.lastMessage=$(if($autoRollback){'最终安全复核触发阈值或证据不完整，已按相反顺序回滚所有保留组。'}else{"实验完成：$($state.result)。胜出证据来自各组交替 A/B，最终三轮只作安全复核。个体内规则实验，不代表全局最优。"})
    Complete-GuiTuningExperimentTerminal $autoRollback;return
  }
  $candidateIndex=$(if($SourceCandidateIndex -ge 0){$SourceCandidateIndex}else{[int]$state.candidateIndex})
  $candidate=$state.candidates[$candidateIndex]
  switch($phase){
    'group_control_pre'{
      $candidate.controlVariantId="$($state.currentBestVariantId)"
      $seed=@($state.runs|Where-Object{$_.validity -eq 'valid' -and $_.variantId -eq $state.currentBestVariantId}|Select-Object -Last 3)
      $candidate.controlRunIds=@($seed|ForEach-Object{$_.runId});$state.phase='group_apply_b1';$state.lastMessage='对照 A 已完成，下一步套用候选并采 B1。';Save-TuningExperiment
    }
    'group_capture_b1'{if(@($candidate.candidateRunIds) -notcontains "$($Run.runId)"){$candidate.candidateRunIds=@($candidate.candidateRunIds)+@("$($Run.runId)")};$state.phase='group_rollback_a';$state.lastMessage='B1 完成，下一步只回滚本候选，重测 A。';Save-TuningExperiment}
    'group_capture_a'{if(@($candidate.controlRunIds) -notcontains "$($Run.runId)"){$candidate.controlRunIds=@($candidate.controlRunIds)+@("$($Run.runId)")};$state.phase='group_apply_b2';$state.lastMessage='A 复测完成，下一步再套用候选并采 B2。';Save-TuningExperiment}
    'group_capture_b2'{if(@($candidate.candidateRunIds) -notcontains "$($Run.runId)"){$candidate.candidateRunIds=@($candidate.candidateRunIds)+@("$($Run.runId)")};Save-TuningExperiment;Compare-CurrentTuningCandidate $candidate $false}
    'group_capture_extra_a'{if(@($candidate.controlRunIds) -notcontains "$($Run.runId)"){$candidate.controlRunIds=@($candidate.controlRunIds)+@("$($Run.runId)")};$state.phase='group_apply_extra_b';Save-TuningExperiment}
    'group_capture_extra_b'{if(@($candidate.candidateRunIds) -notcontains "$($Run.runId)"){$candidate.candidateRunIds=@($candidate.candidateRunIds)+@("$($Run.runId)")};Save-TuningExperiment;Compare-CurrentTuningCandidate $candidate $true}
  }
  Update-TuningUi
}

function Invoke-NextTuningStep {
  $state=$script:ActiveTuningExperiment
  if(-not (Test-TuningExperimentActive)){throw '没有可继续的活动实验'}
  if($state.pendingTuningCommit){[void](Resume-PendingTuningCommit);Update-TuningUi;return}
  if($state.phase -eq 'applying' -and -not @($state.candidates|Where-Object activeBackup).Count){throw '上次 Apply 在备份回传前中断，已拒绝继续写系统；请使用普通还原或诊断报告'}
  if($state.phase -eq 'baseline'){$run=Invoke-TuningPerformanceCapture 'baseline' 'baseline';if($run){[void](Resume-PendingTuningCommit)};return}
  if([int]$state.candidateIndex -ge @($state.candidates).Count){
    $run=Invoke-TuningPerformanceCapture "$($state.currentBestVariantId)" 'final' $false;if($run){[void](Resume-PendingTuningCommit)};return
  }
  $candidate=$state.candidates[[int]$state.candidateIndex]
  switch("$($state.phase)"){
    'group_control_pre'{
      if(-not $candidate.controlVariantId){$candidate.controlVariantId="$($state.currentBestVariantId)";Save-TuningExperiment}
      $run=Invoke-TuningPerformanceCapture "$($candidate.controlVariantId)" "$($candidate.groupId)";if($run){[void](Resume-PendingTuningCommit)}
    }
    'group_apply_b1'{[void](Invoke-TuningApplyCandidate $candidate 'group_capture_b1')}
    'group_capture_b1'{$run=Invoke-TuningPerformanceCapture "$($candidate.variantId)" "$($candidate.groupId)";if($run){[void](Resume-PendingTuningCommit)}}
    'group_rollback_a'{
      try{Invoke-TuningRollbackBackup "$($candidate.activeBackup)" 'A/B 交替回到 A'|Out-Null}
      catch{$state.status='failed';$state.phase='failed';$state.stopReason='rollback_failed';$state.lastMessage=$_.Exception.Message;Complete-GuiTuningExperimentTerminal $true;throw}
      $candidate.activeBackup='';$state.phase='group_capture_a';if("$($candidate.groupId)" -eq 'G3'){$state.groupRestartAfter=[DateTime]::UtcNow.ToString('o')};Save-TuningExperiment
    }
    'group_capture_a'{$run=Invoke-TuningPerformanceCapture "$($state.currentBestVariantId)" "$($candidate.groupId)";if($run){[void](Resume-PendingTuningCommit)}}
    'group_apply_b2'{[void](Invoke-TuningApplyCandidate $candidate 'group_capture_b2')}
    'group_capture_b2'{$run=Invoke-TuningPerformanceCapture "$($candidate.variantId)" "$($candidate.groupId)";if($run){[void](Resume-PendingTuningCommit)}}
    'group_rollback_extra_a'{
      try{Invoke-TuningRollbackBackup "$($candidate.activeBackup)" '追加 A/B 交替回到 A'|Out-Null}
      catch{$state.status='failed';$state.phase='failed';$state.stopReason='rollback_failed';$state.lastMessage=$_.Exception.Message;Complete-GuiTuningExperimentTerminal $true;throw}
      $candidate.activeBackup='';$state.phase='group_capture_extra_a';if("$($candidate.groupId)" -eq 'G3'){$state.groupRestartAfter=[DateTime]::UtcNow.ToString('o')};Save-TuningExperiment
    }
    'group_capture_extra_a'{$run=Invoke-TuningPerformanceCapture "$($state.currentBestVariantId)" "$($candidate.groupId)";if($run){[void](Resume-PendingTuningCommit)}}
    'group_apply_extra_b'{[void](Invoke-TuningApplyCandidate $candidate 'group_capture_extra_b')}
    'group_capture_extra_b'{$run=Invoke-TuningPerformanceCapture "$($candidate.variantId)" "$($candidate.groupId)";if($run){[void](Resume-PendingTuningCommit)}}
    default{throw "当前实验阶段不接受「下一步」：$($state.phase)"}
  }
  Update-TuningUi
}

function New-GuiTuningExperiment {
  if (-not $script:TuningModuleLoaded) { throw '自动调优规则模块缺失，请重新安装软件' }
  if (Test-TuningExperimentActive) {
    Send-TuningTelemetryEvent -TuningType 'experiment_started' -State $script:ActiveTuningExperiment -RequirePersistence
    return $script:ActiveTuningExperiment
  }
  if(@($script:PerformanceJobs|Where-Object{-not $_.Async.IsCompleted}).Count){throw '普通性能采样正在收尾，请等完成后再创建实验，避免普通会话混入 Beta 时段'}
  if (-not (Test-AllowedGameExecutable $script:TargetExe)) { throw '请先在「优化」页定位 DeltaForceClient-Win64-Shipping.exe 或 DeltaForce.exe' }
  $scene="$($ui.TuneSceneBox.Text)".Trim()
  if($scene.Length -lt 2 -or $scene.Length -gt 80 -or $scene -match '[\x00-\x1f]'){throw '固定场景标识需为 2–80 个可见字符'}
  $temp=0.0
  if(-not [double]::TryParse("$($ui.TuneTempBox.Text)",[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::CurrentCulture,[ref]$temp) -or $temp -lt 0 -or $temp -gt 7){throw '最大温升请填 0–7°C'}
  $allowPower=[bool]$ui.TunePowerChk.IsChecked;$power=0.0
  if($allowPower){
    if(-not [double]::TryParse("$($ui.TunePowerBox.Text)",[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::CurrentCulture,[ref]$power) -or $power -lt 0 -or $power -gt 20){throw '最大功耗增幅请填 0–20%'}
  } else {$ui.TunePowerBox.Text='0'}
  $env=Get-TuningEnvironmentSnapshot $scene
  $state=New-TuningExperimentState -SceneId $scene -Environment $env -Goal smoothness -MaxTempIncreaseC $temp `
    -AllowHigherPower $allowPower -MaxPowerIncreasePct $power
  $state=Initialize-TuningGuiStateFields $state;$state.phase='baseline';$state.gamePath=[IO.Path]::GetFullPath($script:TargetExe)
  $state.configGeneration=$script:TuningConfigGeneration;$state.candidates[0].controlVariantId='baseline'
  $state.lastMessage='实验已创建。先完成 3 次有效基线；每轮请使用同一场景和操作路线。'
  $script:ActiveTuningExperiment=$state;$script:ActiveTuningStatePath=Join-Path $script:TuningExperimentDir ("$($state.experimentId).json")
  Save-TuningExperiment;Send-TuningTelemetryEvent -TuningType 'experiment_started' -State $state -RequirePersistence;Update-TuningUi
  Write-Log "已创建自动调优实验 $($state.experimentId)，场景：$scene。"
  $state
}

function Stop-GuiTuningExperiment {
  $state=$script:ActiveTuningExperiment
  if(-not (Test-TuningExperimentActive)){return}
  if($state.pendingTuningCommit){[void](Resume-PendingTuningCommit);$state=$script:ActiveTuningExperiment;if(-not (Test-TuningExperimentActive)){return}}
  $refs=New-Object System.Collections.Generic.List[string]
  # activeBackups 是已保留组的旧→新链；当前候选 activeBackup 更新，必须排在最后，
  # 下面倒序恢复时才会先撤当前候选、再 G3→G2→G1。
  foreach($backup in @($state.activeBackups)){if(-not $refs.Contains("$backup")){[void]$refs.Add("$backup")}}
  foreach($candidate in @($state.candidates)){if($candidate.activeBackup -and -not $refs.Contains("$($candidate.activeBackup)")){[void]$refs.Add("$($candidate.activeBackup)")}}
  $state.phase='rolling_back';$state.lastMessage='正在按相反顺序停止实验并回滚指定备份…';Save-TuningExperiment
  for($i=$refs.Count-1;$i -ge 0;$i--){
    try{
      $restored="$($refs[$i])";Invoke-TuningRollbackBackup $restored '用户停止实验'|Out-Null;$refs.RemoveAt($i)
      Remove-TuningBackupFromState $state $restored
      $state.lastMessage="已回滚 $([IO.Path]::GetFileName($restored))；剩余 $($refs.Count) 份指定备份。";Save-TuningExperiment
    }
    catch{
      $state.status='failed';$state.phase='failed';$state.stopReason='internal_error';$state.lastMessage="停止时回滚失败，已保留未处理备份引用：$($_.Exception.Message)"
      Complete-GuiTuningExperimentTerminal $true;throw
    }
  }
  $state.activeBackups=@();$state.status='cancelled';$state.phase='completed';$state.result='cancelled';$state.stopReason='user_cancelled';$state.completedAt=ConvertTo-TuningUtcText
  $state.lastMessage='实验已停止，本实验保留的候选已按相反顺序用指定备份回滚。'
  Complete-GuiTuningExperimentTerminal $true
}

function Load-ActiveTuningExperiment {
  if(-not $script:TuningModuleLoaded){Update-TuningUi;return}
  try{
    $id=Read-TuningPointerStrict
    if(-not $id){Update-TuningUi;return}
    $path=Join-Path $script:TuningExperimentDir ("$id.json")
    $state=Read-TuningState $path
    if(-not $state){throw '活动实验状态文件缺失'}
    $state=Initialize-TuningGuiStateFields $state;[void](Assert-TuningGuiState $state)
    $script:ActiveTuningExperiment=$state;$script:ActiveTuningStatePath=$path;$script:TuningConfigGeneration=[int64]$state.configGeneration
    $script:TargetExe="$($state.gamePath)";$ui.GameText.Text=$script:TargetExe
    $ui.TuneSceneBox.Text="$($state.sceneId)";$ui.TuneTempBox.Text="$($state.maxTempIncreaseC)";$ui.TunePowerChk.IsChecked=[bool]$state.allowHigherPower;$ui.TunePowerBox.Text="$($state.maxPowerIncreasePct)"
    try { Send-TuningTelemetryEvent -TuningType 'experiment_started' -State $state -RequirePersistence }
    catch {
      # 状态文件本身有效，只是 start 事件尚未安全入队；保留指针，下一次启动/点击继续会重试。
      Write-Log "自动调优开始事件仍待持久化：$($_.Exception.Message)"
      Update-TuningUi
      return
    }
    if($state.pendingTuningCommit){
      try{[void](Resume-PendingTuningCommit);$state=$script:ActiveTuningExperiment}
      catch{Write-Log "自动调优待提交步骤仍未安全入队：$($_.Exception.Message)";Update-TuningUi;return}
    }
    if("$($state.status)" -in 'completed','rolled_back','cancelled','failed'){
      # 终态文件仍有活动指针，说明上次在“状态落盘 → completion 入 outbox → 清指针”之间退出。
      # 重新收口会复用稳定 eventId；若 outbox 本身暂时写不进，保留指针供下次启动继续。
      $autoRollback = "$($state.status)" -in 'rolled_back','cancelled' -or
        "$($state.stopReason)" -in 'safety_threshold','rollback_failed','final_rollback_failed','internal_error'
      try { Complete-GuiTuningExperimentTerminal ([bool]$autoRollback) }
      catch {
        Write-Log "自动调优完成事件仍待持久化：$($_.Exception.Message)"
        Update-TuningUi
        return
      }
      return
    } elseif("$($state.phase)" -eq 'applying'){
      $candidate=@($state.candidates|Where-Object activeBackup|Select-Object -First 1)
      if(-not $candidate){
        $state.status='failed';$state.phase='failed';$state.stopReason='apply_failed';$state.lastMessage='上次 Apply 在备份路径回传前中断。已拒绝继续写系统；请使用普通「还原设置」或上传诊断报告。'
        Complete-GuiTuningExperimentTerminal $false
        Show-ConfirmDialog '实验中断' 'CRASH WINDOW DETECTED' $state.lastMessage '知道了' -InfoOnly|Out-Null
      } else {
        $state.lastMessage='上次在 Apply 返回备份后中断。为避免猜测执行结果，请停止并回滚，或在普通还原后新建实验。';Save-TuningExperiment
        Show-ConfirmDialog '实验需要处理' 'APPLY INTERRUPTED' $state.lastMessage '知道了' -InfoOnly|Out-Null
      }
    } elseif(Test-TuningExperimentActive){
      if(Show-ConfirmDialog '发现未完成实验' 'RESUME TUNING' "场景：$($state.sceneId)`n当前：$($state.phase)`n`n是否回到「自动调优 Beta」继续？" '继续实验'){Select-Tab 'tune'}
    }
    Update-TuningUi
  }catch{
    Clear-TuningPointer;$script:ActiveTuningExperiment=$null;$script:ActiveTuningStatePath=$null;Update-TuningUi
    Write-Log "未能恢复自动调优实验：$($_.Exception.Message)"
    Show-ConfirmDialog '实验状态无效' 'TUNING STATE REJECTED' "已拒绝加载未通过严格校验的实验状态：`n$($_.Exception.Message)" '知道了' -InfoOnly|Out-Null
  }
}

# ---------- 诊断报告（本地组装 + 脱敏 + 用户确认后上传） ----------

$script:ReportUploadUrl = 'https://df.ltz88.cn/report/upload'
$script:ReportMaxBytes = 256KB

$script:DiagnosticIssueChoices = @(
  [pscustomobject]@{ Id = 'low_fps'; Label = '帧率偏低（平均 FPS 低）' }
  [pscustomobject]@{ Id = 'frame_drops'; Label = '掉帧 / 帧率波动' }
  [pscustomobject]@{ Id = 'stutter'; Label = '卡顿 / 微卡 / 突然停顿' }
  [pscustomobject]@{ Id = 'low_one_percent'; Label = '1% Low 偏低（画面不流畅）' }
  [pscustomobject]@{ Id = 'input_latency'; Label = '输入延迟高 / 操作粘滞' }
  [pscustomobject]@{ Id = 'slow_loading'; Label = '游戏加载慢 / 切换场景卡' }
  [pscustomobject]@{ Id = 'game_crash'; Label = '游戏闪退 / 无响应' }
  [pscustomobject]@{ Id = 'black_screen_audio'; Label = '游戏全屏黑屏，但仍有声音' }
  [pscustomobject]@{ Id = 'black_screen_no_audio'; Label = '游戏全屏黑屏，声音也中断' }
  [pscustomobject]@{ Id = 'partial_black_screen'; Label = '游戏内部分区域黑屏 / 黑块' }
  [pscustomobject]@{ Id = 'black_screen_alt_tab'; Label = 'Alt+Tab / 切换显示模式后黑屏' }
  [pscustomobject]@{ Id = 'black_screen_frame_generation'; Label = '开启帧生成后出现黑屏' }
  [pscustomobject]@{ Id = 'black_screen_external_display'; Label = '外接显示器 / 独显直连时黑屏' }
  [pscustomobject]@{ Id = 'system_lag'; Label = '电脑整体卡顿 / 响应慢' }
  [pscustomobject]@{ Id = 'cpu_heat'; Label = 'CPU 占用或温度过高' }
  [pscustomobject]@{ Id = 'gpu_heat'; Label = 'GPU 占用或温度过高' }
  [pscustomobject]@{ Id = 'noise_power'; Label = '风扇噪音大 / 功耗高' }
  [pscustomobject]@{ Id = 'app_update_failure'; Label = '优化工具打不开 / 更新失败' }
  [pscustomobject]@{ Id = 'apply_restore_failure'; Label = '优化或还原执行失败' }
)
$script:DiagnosticBenefitChoices = @(
  [pscustomobject]@{ Id = 'fps_gain'; Label = '平均帧率提升（涨帧）' }
  [pscustomobject]@{ Id = 'one_percent_gain'; Label = '1% Low 提升 / 掉帧减少' }
  [pscustomobject]@{ Id = 'less_stutter'; Label = '卡顿 / 微卡减少' }
  [pscustomobject]@{ Id = 'lower_latency'; Label = '输入延迟降低 / 操作更跟手' }
  [pscustomobject]@{ Id = 'faster_loading'; Label = '游戏加载 / 切换场景更快' }
  [pscustomobject]@{ Id = 'smoother_system'; Label = '电脑响应更流畅' }
  [pscustomobject]@{ Id = 'lower_cpu_heat'; Label = 'CPU 温度降低' }
  [pscustomobject]@{ Id = 'lower_gpu_heat'; Label = 'GPU 温度降低' }
  [pscustomobject]@{ Id = 'lower_noise_power'; Label = '风扇更安静 / 功耗降低' }
  [pscustomobject]@{ Id = 'better_stability'; Label = '游戏稳定性提高 / 闪退减少' }
)

# “上传完整诊断”的第一步：先让用户标记当前问题和已经感受到的改善。两组都支持多选；
# 至少选择一项才进入隐私确认页，避免收到没有反馈上下文的完整诊断。
function Show-DiagnosticFeedbackDialog {
  $fxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="700" Height="650" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <Window.Resources>
    <Style x:Key="FeedbackCheck" TargetType="CheckBox">
      <Setter Property="Foreground" Value="{DynamicResource TextPri}"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="Row" Background="{DynamicResource PanelDeep}" BorderBrush="{DynamicResource Line}"
                    BorderThickness="1" Padding="10,8" Margin="0,0,0,7">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="16"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                <Border x:Name="Box" Width="14" Height="14" BorderBrush="{DynamicResource LineHi}"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Top" Margin="0,1,0,0">
                  <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="{DynamicResource GreenDark}"
                        StrokeThickness="2" Visibility="Collapsed"/>
                </Border>
                <ContentPresenter Grid.Column="1" Margin="9,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="{DynamicResource Green}"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
                <Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource GreenLine}"/>
                <Setter TargetName="Row" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Row" Property="BorderBrush" Value="{DynamicResource Green}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Grid>
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Border x:Name="DlgTitle" Grid.Row="0" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}"
            BorderThickness="0,0,0,1" Padding="14,11">
      <Grid>
        <StackPanel Orientation="Horizontal">
          <Border Background="{DynamicResource Gold}" Padding="7,1" VerticalAlignment="Center">
            <TextBlock Text="反馈选择" Foreground="{DynamicResource GoldDark}" FontSize="11" FontWeight="Bold"/>
          </Border>
          <TextBlock Text="DIAGNOSTIC FEEDBACK" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                     VerticalAlignment="Center" Margin="9,0,0,0"/>
        </StackPanel>
        <TextBlock Text="1 / 2" HorizontalAlignment="Right" Foreground="{DynamicResource Green}"
                   FontFamily="Consolas" FontSize="10" VerticalAlignment="Center"/>
      </Grid>
    </Border>
    <Grid Grid.Row="1" Margin="14,12,14,8">
      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Margin="2,0,2,10">
        <TextBlock Text="这次主要遇到了什么？优化后有哪些改善？" Foreground="{DynamicResource TextPri}"
                   FontSize="17" FontWeight="Bold"/>
        <TextBlock Text="两组都可以多选。改善项还没有感受到时可留空；至少选择一项后再继续。"
                   Foreground="{DynamicResource TextSec}" FontSize="11" Margin="0,4,0,0"/>
      </StackPanel>
      <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
          <Border Grid.Column="0" Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="11">
            <StackPanel>
              <TextBlock Text="遇到的问题（可多选）" Foreground="{DynamicResource Gold}" FontSize="13" FontWeight="Bold"/>
              <TextBlock Text="CURRENT PROBLEMS" Foreground="{DynamicResource TextMut}" FontFamily="Consolas" FontSize="9" Margin="0,2,0,9"/>
              <StackPanel x:Name="IssuePanel"/>
            </StackPanel>
          </Border>
          <Border Grid.Column="2" Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Padding="11">
            <StackPanel>
              <TextBlock Text="优化后已有改善（可多选）" Foreground="{DynamicResource Green}" FontSize="13" FontWeight="Bold"/>
              <TextBlock Text="IMPROVEMENTS" Foreground="{DynamicResource TextMut}" FontFamily="Consolas" FontSize="9" Margin="0,2,0,9"/>
              <StackPanel x:Name="BenefitPanel"/>
            </StackPanel>
          </Border>
        </Grid>
      </ScrollViewer>
    </Grid>
    <Grid Grid.Row="2" Margin="14,4,14,14">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock x:Name="HintTxt" Grid.Column="0" Text="选择内容会写入诊断报告，上传前仍会显示完整数据清单。"
                 Foreground="{DynamicResource TextMut}" FontSize="10" VerticalAlignment="Center" TextWrapping="Wrap" Margin="2,0,10,0"/>
      <Button x:Name="CancelBtn" Grid.Column="1" Content="取消" Width="82" Height="34" IsCancel="True"/>
      <Button x:Name="NextBtn" Grid.Column="2" Content="下一步：确认上传" Width="158" Height="34"
              IsDefault="True" Margin="9,0,0,0"/>
    </Grid>
  </Grid>
</Window>
'@
  $script:FeedbackDlg = [Windows.Markup.XamlReader]::Parse($fxaml)
  $script:FeedbackDlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $script:FeedbackDlg.Owner = $window
  $script:FeedbackIssuePanel = $script:FeedbackDlg.FindName('IssuePanel')
  $script:FeedbackBenefitPanel = $script:FeedbackDlg.FindName('BenefitPanel')
  foreach ($group in @(
    [pscustomobject]@{ Panel = $script:FeedbackIssuePanel; Choices = $script:DiagnosticIssueChoices }
    [pscustomobject]@{ Panel = $script:FeedbackBenefitPanel; Choices = $script:DiagnosticBenefitChoices }
  )) {
    foreach ($choice in $group.Choices) {
      $cb = New-Object Windows.Controls.CheckBox
      $cb.Style = $script:FeedbackDlg.FindResource('FeedbackCheck')
      $cb.Tag = $choice
      $label = New-Object Windows.Controls.TextBlock
      $label.Text = $choice.Label
      $label.TextWrapping = 'Wrap'
      $label.Foreground = New-Brush $script:C.TextPri
      $label.FontSize = 11
      $cb.Content = $label
      $group.Panel.Children.Add($cb) | Out-Null
    }
  }
  $script:FeedbackDlg.FindName('CancelBtn').Style = $window.FindResource('Ghost')
  $script:FeedbackDlg.FindName('NextBtn').Style = $window.FindResource('Primary')
  $script:DiagnosticFeedbackResult = $null
  $script:FeedbackDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:FeedbackDlg.DragMove() })
  $script:FeedbackDlg.FindName('CancelBtn').Add_Click({ $script:FeedbackDlg.DialogResult = $false })
  $script:FeedbackDlg.FindName('NextBtn').Add_Click({
    $issueChoices = @($script:FeedbackIssuePanel.Children | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
    $benefitChoices = @($script:FeedbackBenefitPanel.Children | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
    if (($issueChoices.Count + $benefitChoices.Count) -eq 0) {
      $script:FeedbackDlg.FindName('HintTxt').Text = '请至少选择一项当前问题或改善效果。'
      $script:FeedbackDlg.FindName('HintTxt').Foreground = New-Brush '#FFFF6B6B'
      return
    }
    $script:DiagnosticFeedbackResult = [pscustomobject]@{
      IssueIds = [string[]]@($issueChoices | ForEach-Object { $_.Id })
      IssueLabels = [string[]]@($issueChoices | ForEach-Object { $_.Label })
      BenefitIds = [string[]]@($benefitChoices | ForEach-Object { $_.Id })
      BenefitLabels = [string[]]@($benefitChoices | ForEach-Object { $_.Label })
    }
    $script:FeedbackDlg.DialogResult = $true
  })
  if (-not [bool]$script:FeedbackDlg.ShowDialog()) { return $null }
  $script:DiagnosticFeedbackResult
}

# 脱敏：路径里的用户名、机器名、账户名一律替换。目录结构保留——排查问题要看得出
# 游戏装在哪层目录，但没必要知道机器主人叫什么
function Protect-ReportText([string]$Text) {
  if (-not $Text) { return $Text }
  $t = $Text -replace '(?i)([A-Za-z]:\\Users\\)[^\\\r\n"'']+', '${1}<user>'
  $t = $t -replace '(?i)(\\Users\\)[^\\\r\n"'']+', '${1}<user>'
  # 高权限 GUI 的环境经过 EngineHost 最小化，不能读取 UAC 审批账户的
  # USERNAME/USERDOMAIN。用户名只从已经认证、复验过的原用户 LocalAppData
  # 推导；机器名使用 .NET，避免重新引入高权限账户环境。
  $originalProfile = Split-Path -Parent (Split-Path -Parent $script:OriginalUserLocalAppData)
  $originalUserName = if ($originalProfile) { Split-Path -Leaf $originalProfile } else { '' }
  foreach ($pair in @(@($originalUserName, '<user>'), @([Environment]::MachineName, '<pc>'))) {
    # 只替换完整 token；原来的全局子串替换会把 Windows 注册表项
    # FilterAdministratorToken 错写成 Filter<user>Token（用户名恰为 Administrator）。
    if ("$($pair[0])".Length -ge 2) {
      $tokenPattern = '(?<![A-Za-z0-9_])' + [regex]::Escape("$($pair[0])") + '(?![A-Za-z0-9_])'
      $t = $t -replace $tokenPattern, $pair[1]
    }
  }
  $t
}

function ConvertTo-DiagnosticFieldValue([object]$Value) {
  $text = ("$Value" -replace '[\x00-\x1f\x7f]', ' ').Trim()
  if ($text.Length -gt 256) { $text = $text.Substring(0, 256) }
  $text
}

# 报告只放排查需要的：硬件 + 各优化项当前状态 + 本次/最近历史运行日志 + 版本号 + 最近备份的项目名。
# 绝不带备份 JSON 原文——那里面是注册表原值，外传没有意义
function New-DiagnosticReport($Feedback) {
  $lines = New-Object System.Collections.Generic.List[string]
  $hw = $null
  $gpuPanelInventory = [pscustomobject]@{ Status = 'not_checked'; Apps = [object[]]@() }
  $issueIds = @(); $benefitIds = @()
  # 只记录固定白名单进程的稳定 key，用于判断局部黑屏/卡顿是否与叠加层、录屏或
  # 监控软件同现；不采集任意进程名、命令行或路径。
  $diagnosticProcessMap = [ordered]@{
    'DeltaForceClient-Win64-Shipping'='game-client'; 'DeltaForce'='game-launcher'
    'PresentMon'='presentmon'; 'RTSS'='rtss'; 'MSIAfterburner'='msi-afterburner'
    'obs64'='obs'; 'Discord'='discord'; 'GameBar'='game-bar'
    'NVIDIA Share'='nvidia-share'; 'RadeonSoftware'='amd-software'; 'WeGame'='wegame'
    'GamePP'='gamepp'; 'LosslessScaling'='lossless-scaling'; 'ProcessLasso'='process-lasso'
    'ProcessGovernor'='process-lasso'; 'ArmouryCrate.UserSessionHelper'='armoury-crate'
    'GHelper'='g-helper'; 'LenovoVantage'='lenovo-vantage'; 'LenovoVantageService'='lenovo-vantage'
    'MSI.CentralServer'='msi-center'; 'MSI_Center_Service'='msi-center'
    'OMEN Gaming Hub'='omen-gaming-hub'; 'OMENCommandCenter'='omen-gaming-hub'
    'AWCC.Background.Server'='alienware-command-center'; 'AWCCService'='alienware-command-center'
    'RazerCortex'='razer-cortex'
  }
  $runningRelatedProcesses = @(); $runningRelatedProcessKeys = @()
  try {
    $runningNames = @(Get-Process -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique)
    foreach ($name in $diagnosticProcessMap.Keys) {
      if ($runningNames -contains "$name") {
        $runningRelatedProcesses += "$name"
        $runningRelatedProcessKeys += "$($diagnosticProcessMap[$name])"
      }
    }
  } catch {}
  $lines.Add("DeltaForceBooster 诊断报告")
  $lines.Add("生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
  $lines.Add("界面版本：v$script:DisplayVersion（构建 $script:GuiVersion）")
  $lines.Add('')

  $lines.Add('== 用户反馈选择 ==')
  if ($Feedback) {
    $issueLabels = @($Feedback.IssueLabels)
    $benefitLabels = @($Feedback.BenefitLabels)
    $issueIds = @($Feedback.IssueIds)
    $benefitIds = @($Feedback.BenefitIds)
    $lines.Add("遇到的问题：$(if ($issueLabels.Count) { $issueLabels -join '、' } else { '未选择' })")
    $lines.Add("问题标签：$(if ($issueIds.Count) { $issueIds -join ',' } else { 'none' })")
    $lines.Add("已有改善：$(if ($benefitLabels.Count) { $benefitLabels -join '、' } else { '未选择' })")
    $lines.Add("改善标签：$(if ($benefitIds.Count) { $benefitIds -join ',' } else { 'none' })")
  } else {
    $lines.Add('遇到的问题：未选择')
    $lines.Add('已有改善：未选择')
  }
  $lines.Add('')

  $lines.Add('== 硬件与系统 ==')
  try {
    $hw = Get-HardwareInfo
    $lines.Add("系统：$($hw.OS)（Build $($hw.Build)）")
    $lines.Add("电脑：$($hw.ComputerBrand) $($hw.ComputerModel)（主板 $($hw.BaseBoardManufacturer) $($hw.BaseBoardProduct)）")
    $lines.Add("CPU（Windows 当前可见）：$($hw.CPU)（$($hw.Cores) 核 $($hw.Threads) 线程，$($hw.CpuPackages) 路）")
    $lines.Add("内存：$($hw.RamGB) GB｜$($hw.MemoryType)｜$($hw.MemoryModuleCount) 条｜当前 $($hw.MemoryConfiguredMHz) MHz｜标称 $($hw.MemoryRatedMHz) MHz")
    foreach ($g in $hw.Gpus) {
      $lines.Add("显卡（真实）：$($g.Name)（$($g.Vendor)，驱动 $($g.Driver)，身份验证 $([bool]$g.NameVerified)，虚拟显示 $([bool]$g.IsVirtualDisplay)）")
      if ($g.ReportedName -and $g.ReportedName -ne $g.Name) { $lines.Add("     系统当前伪装上报：$($g.ReportedName)") }
    }
    $lines.Add("虚拟/远程显示适配器：$($hw.VirtualDisplayCount) 个")
    $gpuPanelInventory = Get-GuiGpuPanelInventory "$($hw.MainGpuVendor)"
    $panelApps = @($gpuPanelInventory.Apps)
    $lines.Add("显卡软件检测：$($gpuPanelInventory.Status)｜已安装 $(if (@($panelApps | Where-Object Installed).Count) { @($panelApps | Where-Object Installed | ForEach-Object Key) -join ',' } else { 'none' })｜未安装 $(if (@($panelApps | Where-Object { -not $_.Installed }).Count) { @($panelApps | Where-Object { -not $_.Installed } | ForEach-Object Key) -join ',' } else { 'none' })")
    $lines.Add("机型：$(switch ("$($hw.FormFactor)") { 'laptop' { '笔记本' }; 'desktop' { '台式机' }; default { '未知' } })")
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  # 机器可读、稳定命名的分析字段。诊断报告属于“遇到问题后主动提交”的有偏样本，
  # 服务端会与普通使用/性能遥测分开统计；字段本身不含账户、路径或硬件序列号。
  $lines.Add('== 分析字段（schema v3） ==')
  $lines.Add('diagnostic_schema=3')
  $lines.Add("app_version=$(ConvertTo-DiagnosticFieldValue $script:GuiVersion)")
  $lines.Add("feedback_issue_ids=$(ConvertTo-DiagnosticFieldValue ($issueIds -join ','))")
  $lines.Add("feedback_benefit_ids=$(ConvertTo-DiagnosticFieldValue ($benefitIds -join ','))")
  $optimizationContext = Get-TelemetryOptimizationContext
  $lines.Add("config_tier=$(ConvertTo-DiagnosticFieldValue $optimizationContext.ConfigTier)")
  $lines.Add("optimization_scheme=$(ConvertTo-DiagnosticFieldValue $optimizationContext.Scheme)")
  $lines.Add("optimization_item_ids=$(ConvertTo-DiagnosticFieldValue (@($optimizationContext.ItemIds) -join ','))")
  $lines.Add("optimization_item_set_hash=$(ConvertTo-DiagnosticFieldValue $optimizationContext.ItemSetHash)")
  $lines.Add("optimization_items_complete=$([bool]$optimizationContext.ItemsComplete)".ToLowerInvariant())
  $lines.Add("active_related_process_keys=$(ConvertTo-DiagnosticFieldValue ($runningRelatedProcessKeys -join ','))")
  if ($hw) {
    $installedPanelKeys = @($gpuPanelInventory.Apps | Where-Object Installed | ForEach-Object Key | Sort-Object -Unique)
    $missingPanelKeys = @($gpuPanelInventory.Apps | Where-Object { -not $_.Installed } | ForEach-Object Key | Sort-Object -Unique)
    $lines.Add("cpu_model=$(ConvertTo-DiagnosticFieldValue $hw.CPU)")
    $lines.Add("cpu_vendor=$(ConvertTo-DiagnosticFieldValue $hw.CpuVendor)")
    $lines.Add("cpu_visible_cores=$([int]$hw.Cores)")
    $lines.Add("cpu_visible_threads=$([int]$hw.Threads)")
    $lines.Add("cpu_packages=$([int]$hw.CpuPackages)")
    $lines.Add("ram_gb=$([double]$hw.RamGB)")
    $lines.Add("memory_type=$(ConvertTo-DiagnosticFieldValue $hw.MemoryType)")
    $lines.Add("memory_configured_mhz=$([int]$hw.MemoryConfiguredMHz)")
    $lines.Add("memory_rated_mhz=$([int]$hw.MemoryRatedMHz)")
    $lines.Add("memory_module_count=$([int]$hw.MemoryModuleCount)")
    $lines.Add("device_type=$(ConvertTo-DiagnosticFieldValue $hw.FormFactor)")
    $lines.Add("form_factor_confidence=$(ConvertTo-DiagnosticFieldValue $hw.FormFactorConfidence)")
    $lines.Add("chassis_types=$(ConvertTo-DiagnosticFieldValue (@($hw.ChassisTypes) -join ','))")
    $lines.Add("has_battery=$(if ($null -eq $hw.HasBattery) { 'unknown' } else { "$([bool]$hw.HasBattery)".ToLowerInvariant() })")
    $lines.Add("has_internal_display=$(if ($null -eq $hw.HasInternalDisplay) { 'unknown' } else { "$([bool]$hw.HasInternalDisplay)".ToLowerInvariant() })")
    $lines.Add("ups_ambiguous=$([bool]$hw.IsUpsAmbiguous)".ToLowerInvariant())
    $lines.Add("computer_manufacturer=$(ConvertTo-DiagnosticFieldValue $hw.ComputerManufacturer)")
    $lines.Add("computer_model_family=$(ConvertTo-DiagnosticFieldValue $hw.ComputerModelFamily)")
    $lines.Add("gpu_count=$(@($hw.Gpus).Count)")
    $lines.Add("main_gpu_vendor=$(ConvertTo-DiagnosticFieldValue $hw.MainGpuVendor)")
    $lines.Add("main_gpu_model=$(ConvertTo-DiagnosticFieldValue $hw.MainGpuName)")
    $lines.Add("main_gpu_reported_model=$(ConvertTo-DiagnosticFieldValue $hw.MainGpuReportedName)")
    $lines.Add("main_gpu_driver_version=$(ConvertTo-DiagnosticFieldValue (Get-TelemetryMainGpuDriver $hw))")
    $lines.Add("main_gpu_model_verified=$([bool]$hw.MainGpuNameVerified)".ToLowerInvariant())
    $pciMatchedField = $(if ("$($hw.MainGpuVendor)" -eq 'NVIDIA') {
      "$([bool]$hw.MainGpuPciMatched)".ToLowerInvariant()
    } else { 'unknown' })
    $lines.Add("main_gpu_pci_matched=$pciMatchedField")
    $lines.Add("main_gpu_reported_model_differs=$([bool]("$($hw.MainGpuReportedName)" -ne "$($hw.MainGpuName)"))".ToLowerInvariant())
    $lines.Add("virtual_display_count=$([int]$hw.VirtualDisplayCount)")
    $lines.Add("display_mode=$(ConvertTo-DiagnosticFieldValue (Get-TelemetryDisplayMode $hw))")
    $lines.Add("display_adapter_vendor=$(ConvertTo-DiagnosticFieldValue $hw.DisplayGpuVendor)")
    $lines.Add("display_adapter_model=$(ConvertTo-DiagnosticFieldValue $hw.DisplayGpuName)")
    $lines.Add("hybrid_graphics=$([bool]$hw.HybridGraphics)".ToLowerInvariant())
    $lines.Add("active_display_count=$([int]$hw.ActiveDisplayCount)")
    $lines.Add("internal_display_count=$([int]$hw.InternalDisplayCount)")
    $lines.Add("external_display_count=$([int]$hw.ExternalDisplayCount)")
    $lines.Add("display_connectors=$(ConvertTo-DiagnosticFieldValue (@($hw.DisplayConnectors) -join ','))")
    $lines.Add("pagefile_auto_managed=$([bool]$hw.AutomaticManagedPagefile)".ToLowerInvariant())
    $lines.Add("gpu_panel_status=$(ConvertTo-DiagnosticFieldValue $gpuPanelInventory.Status)")
    $lines.Add("gpu_panel_installed_keys=$(ConvertTo-DiagnosticFieldValue ($installedPanelKeys -join ','))")
    $lines.Add("gpu_panel_missing_keys=$(ConvertTo-DiagnosticFieldValue ($missingPanelKeys -join ','))")
    $analysis = Get-TelemetryAnalysisContext $hw $script:TargetExe
    foreach ($pair in ([ordered]@{
      windows_display_version=$analysis.windowsDisplayVersion;windows_build_revision=$analysis.windowsBuildRevision
      vbs_state=$analysis.vbsState;memory_integrity_state=$analysis.memoryIntegrityState
      hags_state=$analysis.hagsState;game_mode_state=$analysis.gameModeState;game_dvr_state=$analysis.gameDvrState
      mpo_state=$analysis.mpoState;windowed_optimization_state=$analysis.windowedOptimizationState
      fso_state=$analysis.fsoState;gpu_preference_state=$analysis.gpuPreferenceState
      active_power_plan_guid=$analysis.activePowerPlanGuid;reboot_pending=$analysis.rebootPending
      game_exe_version=$analysis.gameExeVersion;power_source=$analysis.powerSource;battery_percent=$analysis.batteryPercent
      vc_runtime_status=$analysis.vcRuntimeStatus;vc_runtime_x64_version=$analysis.vcRuntimeX64Version
      vc_runtime_x86_version=$analysis.vcRuntimeX86Version;capture_compatibility_status=$analysis.captureCompatibilityStatus
    }).GetEnumerator()) {
      $lines.Add("$($pair.Key)=$(ConvertTo-DiagnosticFieldValue $pair.Value)")
    }
  } else {
    $lines.Add('hardware_status=read_failed')
  }
  $lines.Add('')

  $lines.Add('== 运行环境与显示 / 音频 ==')
  try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $boot = $os.LastBootUpTime
    $lines.Add("系统启动时间：$boot")
    $lines.Add("会话模式：$(if ($script:NetCafeCompatibilityMode) { '网吧兼容模式（UAC 策略未修改）' } else { '标准 EngineHost 管理员会话' })")
    $lines.Add("UAC：EnableLUA=$(Get-UacEnableLuaValue)；FilterAdministratorToken=$(Get-UacFilterAdministratorTokenValue)")
    if ($hw) { $lines.Add("页面文件自动管理：$([bool]$hw.AutomaticManagedPagefile)") }
    foreach ($display in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
      $lines.Add("显示输出：$($display.Name)｜$($display.CurrentHorizontalResolution)x$($display.CurrentVerticalResolution) @$($display.CurrentRefreshRate)Hz｜驱动 $($display.DriverVersion)")
    }
    foreach ($audio in @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue)) {
      $lines.Add("音频设备：$($audio.Name)｜厂商 $($audio.Manufacturer)｜状态 $($audio.Status)")
    }
    foreach ($page in @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)) {
      $lines.Add("页面文件：$($page.Name)｜已分配 $($page.AllocatedBaseSize) MB｜当前 $($page.CurrentUsage) MB｜峰值 $($page.PeakUsage) MB")
    }
    $lines.Add("相关进程：$(if ($runningRelatedProcesses.Count) { $runningRelatedProcesses -join '、' } else { '未检测到' })")
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 关键环境变量（脱敏） ==')
  # 只收集排障相关白名单；令牌、密码、Cookie 等任意环境变量绝不进入报告。
  foreach ($name in @('SystemRoot','WINDIR','ProgramData','ProgramFiles','ProgramFiles(x86)','TEMP','TMP','PATH','PSModulePath','COMSPEC','PATHEXT','__COMPAT_LAYER')) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    $lines.Add("${name}=$(if ([string]::IsNullOrEmpty($value)) { '（未设置）' } else { $value })")
  }
  $injectionNames = @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object {
    "$_" -match '^(?i:COR_|COMPlus_|DOTNET_|PSExecutionPolicyPreference$)'
  } | ForEach-Object { "$_" } | Sort-Object)
  $lines.Add("运行时注入变量：$(if ($injectionNames.Count) { ($injectionNames -join '、') + '（仅记录名称，不上传值）' } else { '未检测到' })")
  try {
    $powercfg = Join-Path ([Environment]::SystemDirectory) 'powercfg.exe'
    $activePlan = (& $powercfg /getactivescheme 2>&1 | Out-String).Trim()
    $lines.Add("当前电源计划：$activePlan")
  } catch { $lines.Add("当前电源计划读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 游戏路径 ==')
  $lines.Add($(if ($script:TargetExe) { "$script:TargetExe" } else { '未定位' }))
  $lines.Add('')

  $lines.Add('== 最近游戏性能记录 ==')
  try {
    $perfFile = Join-Path $script:UserConfigDir 'performance-sessions.json'
    if (-not (Test-Path -LiteralPath $perfFile)) { $lines.Add('（暂无记录；v0.19.0 起在游戏启动稳定后自动采样）') }
    else {
      # Windows PowerShell 5.1 的 ConvertFrom-Json 会把顶层 JSON 数组作为一个管道对象输出；
      # 若直接接 Select-Object，foreach 会拿到整个数组并把每个属性展开成空格拼接的一行。
      # 先结束管道并显式数组化，确保每段性能记录都是独立对象。
      $decodedSessions = Get-Content -LiteralPath $perfFile -Raw -Encoding UTF8 | ConvertFrom-Json
      $sessions = @(Expand-PerformanceSessions $decodedSessions)
      if ($sessions.Count -gt 5) { $sessions = @($sessions | Select-Object -Last 5) }
      foreach ($s in $sessions) {
        $validity = $(if ($s.PSObject.Properties['validity']) { "$($s.validity)" }
          elseif ([double]$s.avgFps -gt 0 -and [double]$s.fps1Low -gt 0 -and [int]$s.durationSec -ge 90) { 'legacy_usable' }
          else { 'legacy_invalid' })
        $invalidReason = $(if ($s.PSObject.Properties['invalidReason']) { "$($s.invalidReason)" } else { '' })
        $lines.Add("$($s.recordedAt)｜$($s.gpuModel)｜$($s.durationSec)s｜平均帧率 $($s.avgFps) 帧/秒｜1% 低帧率 $($s.fps1Low) 帧/秒")
        $lines.Add("     GPU 占用 $($s.gpuUtilAvg)% / 峰值 $($s.gpuUtilMax)%｜温度 $($s.gpuTempAvg)°C / 峰值 $($s.gpuTempMax)°C｜功耗 $($s.gpuPowerAvg)W / 峰值 $($s.gpuPowerMax)W")
        $lines.Add("     有效性 $validity$(if ($invalidReason) { "｜原因 $invalidReason" })｜帧数 $($s.frameCount)｜P99 $($s.p99FrameMs)ms｜MAD $($s.frameTimeMadMs)ms｜焦点丢失 $($s.focusLostSec)s｜50ms+ 卡顿 $($s.stutter50Ms)")
      }
    }
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 优化项状态 ==')
  try {
    foreach ($it in @(Get-OptItems $script:TargetExe $script:SelectedGpuSpoofModel)) {
      $st = Get-ItemState $it
      $mark = $(if ($st.Optimized -eq $true) { '[√]' } elseif ($st.Optimized -eq $false) { '[×]' } else { '[?]' })
      $lines.Add("$mark $($it.Id) — $($it.Name)")
      $lines.Add("     当前：$($st.Current)")
    }
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 系统还原备份 ==')
  # v0.19.4 起备份含注册表/文件原值，存放在仅管理员可读的 ProgramData 目录并带 HMAC。
  # 普通权限 GUI 不为生成诊断报告而扩大权限或读取原值；执行/还原结果已记录在运行日志。
  $lines.Add("位置：$script:BackupDir（受保护；仅管理员引擎验证和读取）")
  $lines.Add('本次执行产生的备份文件名与结果见下方运行日志。')
  $lines.Add('')

  $lines.Add('== 本次与最近历史运行日志 ==')
  $lines.Add($(if ($ui.LogBox.Text) { $ui.LogBox.Text } else { '（空）' }))

  $txt = Protect-ReportText (($lines -join "`r`n"))
  # 上限按字节算：中文一个字三字节，按字符数截会超
  $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
  if ($bytes.Length -gt $script:ReportMaxBytes) {
    $strictUtf8 = New-Object Text.UTF8Encoding($false, $true)
    $byteCount = $script:ReportMaxBytes - 200
    while ($byteCount -gt 0) {
      try { $keep = $strictUtf8.GetString($bytes, 0, $byteCount); break }
      catch [Text.DecoderFallbackException] { $byteCount-- }
    }
    $txt = $keep + "`r`n`r`n【注意】报告超过 256KB 上限，以上内容已被截断。"
  }
  $txt
}

# 真正发请求的唯一出口：验证时整体替换成桩，绝不往服务器发测试数据
function Invoke-ReportUpload([string]$Body) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
  $r = Invoke-WebRequest -Uri $script:ReportUploadUrl -Method Post -Body $bytes `
        -ContentType 'text/plain; charset=utf-8' -TimeoutSec 30 -UseBasicParsing
  ($r.Content | ConvertFrom-Json).code
}

# ---------- 显卡指引对话框（驱动层设置 + 控制面板入口） ----------

# high GUI 不直接启动 explorer/Appx/供应商程序；launcher 只接受四个固定产品 Key，
# 并在 medium token 中自行解析受信 Known Folder 与固定目标。
function Open-GpuPanel($App) {
  if (-not $App -or "$($App.Key)" -notin 'nv-cpl','nv-app','amd-sw','intel-gcc') {
    throw '显卡控制面板动作不在白名单'
  }
  Invoke-EngineHostUserAction -Action OpenGpuPanel -Payload "$($App.Key)" | Out-Null
}

function Get-GuiGpuPanelInventory([string]$Vendor) {
  # 厂商值不再作为跨进程自由文本参数传递。固定动作从 GUI 到 launcher 再到 worker
  # 全程表达厂商身份，彻底消除空字符串、引号或大小写在任一边界被误判的问题。
  if ($script:RepairOnlySession) {
    return [pscustomobject]@{ Status = 'unavailable_in_compatibility_mode'; Apps = [object[]]@() }
  }
  $action = switch ("$Vendor".Trim().ToUpperInvariant()) {
    'NVIDIA' { 'GetNvidiaPanelApps' }
    'AMD'    { 'GetAmdPanelApps' }
    'INTEL'  { 'GetIntelPanelApps' }
    default  { $null }
  }
  if (-not $action) {
    return [pscustomobject]@{ Status = 'unsupported_vendor'; Apps = [object[]]@() }
  }
  try {
    # WinPS 5.1 会把 ConvertFrom-Json 的顶层数组作为一个管道对象返回；先赋值再
    # 数组化，避免 NVIDIA 的两个条目被包装成一个“Key=nv-cpl nv-app”对象。
    $decodedApps = (Invoke-EngineHostUserAction -Action $action) | ConvertFrom-Json
    $apps = @($decodedApps)
    $expectedKeys = @($(switch ($action) {
      'GetNvidiaPanelApps' { 'nv-cpl'; 'nv-app' }
      'GetAmdPanelApps' { 'amd-sw' }
      'GetIntelPanelApps' { 'intel-gcc' }
    }))
    $actualKeys = @($apps | ForEach-Object { "$($_.Key)" } | Sort-Object -Unique)
    if ($apps.Count -ne $expectedKeys.Count -or
        ($actualKeys -join ',') -cne (@($expectedKeys | Sort-Object) -join ',') -or
        @($apps | Where-Object { $_.Installed -isnot [bool] }).Count) {
      throw "显卡软件检测回复结构无效（期望 $($expectedKeys -join ',')；实际 $($actualKeys -join ',')；数量 $($apps.Count)）"
    }
    [pscustomobject]@{ Status = 'ok'; Apps = [object[]]$apps }
  } catch {
    Write-Log "显卡软件检测失败：$($_.Exception.Message)"
    [pscustomobject]@{ Status = 'broker_failed'; Apps = [object[]]@() }
  }
}

function Get-GuiGpuPanelApps([string]$Vendor) {
  $inventory = Get-GuiGpuPanelInventory $Vendor
  @($inventory.Apps)
}

function Build-GpuGuideDialog($Hw) {
  $gxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="520" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="{DynamicResource Gold}" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="显卡指引" Foreground="{DynamicResource GoldDark}" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="GPU DRIVER GUIDE" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <Border Background="{DynamicResource AccentPanel}" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Margin="14,12,14,0" Padding="10,7">
      <TextBlock x:Name="BannerTxt" Text="" Foreground="{DynamicResource Green}" FontSize="12" FontWeight="Bold" TextWrapping="Wrap"/>
    </Border>
    <StackPanel x:Name="AppPanel" Margin="14,10,14,0"/>
    <Border Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="14,10,14,12">
      <ScrollViewer MaxHeight="300" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="MsgTxt" Text="" Foreground="{DynamicResource TextSec}" FontSize="12" LineHeight="19"
                   TextWrapping="Wrap" Padding="12,9"/>
      </ScrollViewer>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" IsCancel="True"
              Foreground="{DynamicResource GreenDark}" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="知道了"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  $dlg = [Windows.Markup.XamlReader]::Parse($gxaml)
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $banner = "检测到你的显卡：$($Hw.MainGpuName)"
  if (@($Hw.Gpus).Count -gt 1) {
    $allGpuNames = @($Hw.Gpus | ForEach-Object { $_.Name }) -join ' + '
    $banner = "检测到双显卡：$allGpuNames`n以下按独显 $($Hw.MainGpuName) 给出"
  }
  $dlg.FindName('BannerTxt').Text = $banner
  $dlg.FindName('MsgTxt').Text = Get-GpuGuideText $Hw.MainGpuVendor $Hw.MainGpuName $Hw.IsLaptop $Hw

  $panel = $dlg.FindName('AppPanel')
  foreach ($app in @(Get-GuiGpuPanelApps $Hw.MainGpuVendor)) {
    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    $row.Margin = New-Object Windows.Thickness 0, 0, 0, 6
    if ($app.Installed) {
      $b = New-Object Windows.Controls.Button
      $b.Style = $window.FindResource('Ghost')
      $b.Content = "打开 $($app.Name)"
      $b.FontSize = 11
      $b.Height = 26
      $b.MinWidth = 168
      # 循环里挂的处理器不能闭包引用循环变量，一律从 sender.Tag 取
      $b.Tag = [pscustomobject]@{ Key = $app.Key; Kind = $app.Kind; Target = $app.Target; Name = $app.Name }
      $b.Add_Click({
        try { Open-GpuPanel $this.Tag; Write-Log "已打开 $($this.Tag.Name)。" }
        catch { Write-Log "打开 $($this.Tag.Name) 失败：$($_.Exception.Message)" }
      })
      $row.Children.Add($b) | Out-Null
    } else {
      # 缺失时明确告诉用户下一步点哪里；按钮直接打开对应厂商的官方下载页
      $t = New-WrapText "未检测到 $($app.Name)：$($app.Missing)。请点击右侧「下载 $($app.Name)」打开官网，安装完成后重新打开本工具。" $script:C.TextMut 11
      $t.MaxWidth = 300
      $t.Margin = New-Object Windows.Thickness 0, 0, 8, 0
      $row.Children.Add($t) | Out-Null
      $b = New-Object Windows.Controls.Button
      $b.Style = $window.FindResource('Ghost')
      $b.Content = "下载 $($app.Name)"
      $b.FontSize = 11
      $b.Height = 26
      $b.Tag = "$($app.Download)"
      $b.ToolTip = "$($app.Download)"
      $b.Add_Click({ Open-HelpLink "$($this.Tag)" })
      $row.Children.Add($b) | Out-Null
    }
    $panel.Children.Add($row) | Out-Null
  }
  $dlg
}

function Show-GpuGuideDialog($Hw) {
  $script:GgDlg = Build-GpuGuideDialog $Hw
  $script:GgDlg.Owner = $window
  $script:GgDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:GgDlg.DragMove() })
  $script:GgDlg.FindName('OkBtn').Add_Click({ $script:GgDlg.DialogResult = $true })
  [void]$script:GgDlg.ShowDialog()
}

# 近期版本掉帧页只给排查顺序，不自动改驱动、BIOS 或运行库。显卡厂商来自引擎已经完成的
# 主力 GPU 识别，双显卡机器仍以 MainGpuVendor/MainGpuName（通常为独显）生成推荐。
function Get-DropFrameRepairPlan($Hw) {
  $vendor = "$($Hw.MainGpuVendor)"
  $gpuName = $(if ($Hw.MainGpuName) { "$($Hw.MainGpuName)" } else { '未识别显卡' })
  $summary = "近期版本掉帧可能由着色器缓存、驱动配置、运行组件或游戏版本共同触发；以下按 $vendor 显卡生成排查顺序。"
  $common = @(
    '1. 【可执行】完全退出游戏和启动器，点击下方“清理着色器缓存”；重新进入后先等待着色器预热完成。'
    '2. 在启动器验证并修复游戏文件；确认游戏主程序已启用“禁用全屏优化”。'
    '3. 【可执行】点击下方“设置高性能 GPU”，把当前定位的三角洲主程序写入 Windows 高性能显卡首选项。'
    '4. 虚拟内存优先保持“系统管理大小”，并为系统盘和游戏盘保留足够空间。'
    '5. 【可检查】点击下方“检查 VC++ 运行库”；缺失时按软件给出的微软官方入口覆盖安装或“修复”，不要批量卸载旧年份组件。'
  ) -join "`n"
  $caution = 'DDU 重装驱动、回退驱动、关闭超线程/SMT、改 BIOS 或重装系统都放在最后。只有问题与某次驱动更新时间一致时才考虑驱动回退；关闭超线程/SMT必须做同场景前后对比，AMD 处理器不默认关闭 SMT。'

  switch ($vendor) {
    'NVIDIA' {
      $vendorTitle = 'NVIDIA 专项排查'
      $vendorText = @(
        '1. NVIDIA 控制面板 → 管理 3D 设置 → 程序设置：电源管理模式设为“最高性能优先”，着色器缓存大小设为“无限制”。'
        '2. NVIDIA App 的“自动优化”先关闭，避免它重新覆盖游戏画质；RTX 40/50 系的 DLSS 模型预设可保留当前稳定值。'
        '3. Windows“硬件加速 GPU 计划”分别开、关各测试一局，以 1% Low 和卡顿次数选择，不按平均帧率单独判断。'
        '4. 若掉帧恰好从显卡驱动更新后开始，优先干净安装当前 Game Ready WHQL；仍异常再回退到此前稳定版本。'
      ) -join "`n"
    }
    'AMD' {
      $vendorTitle = 'AMD Radeon 专项排查'
      $vendorText = @(
        '1. AMD Software → 游戏 → 三角洲行动：Radeon Anti-Lag 开；Radeon Chill、Boost、增强同步先关。'
        '2. AMD Software 的“重置着色器缓存”与工具清理二选一执行，随后首次进图耐心完成缓存重建。'
        '3. 纹理过滤质量设为“性能”，表面格式优化开启；不要同时叠加 Chill、帧率上限和游戏内限帧。'
        '4. 若问题紧跟驱动更新出现，优先安装 AMD 官方 WHQL/Recommended 版本；Optional 版异常时回退此前稳定版。'
      ) -join "`n"
    }
    'Intel' {
      $vendorTitle = 'Intel 显卡专项排查'
      $vendorText = @(
        '1. 更新到 Intel 官方稳定版显卡驱动；若是双显卡笔记本，确认游戏实际运行在独显而不是 Intel 核显。'
        '2. Intel Graphics Software 中为三角洲关闭垂直同步和额外限帧，只保留游戏内一处帧率上限。'
        '3. Intel Xe 低延迟只做开/关 A/B 测试；出现新的帧时间尖峰就恢复默认。'
        '4. Arc 独显确认主板已开启 Resizable BAR；核显机器优先降低纹理、阴影和分辨率比例，避免显存共享压力。'
      ) -join "`n"
    }
    default {
      $vendorTitle = '未识别厂商 · 通用排查'
      $vendorText = @(
        '1. 先完成上方通用步骤，每次只修改一项并在同一地图、相近场景复测。'
        '2. 从显卡厂商官网下载稳定版驱动，不使用第三方驱动包。'
        '3. 记录修改前后的平均帧率、1% Low、GPU 占用率和卡顿次数，再决定是否保留。'
      ) -join "`n"
    }
  }
  [pscustomobject]@{
    GpuName = $gpuName
    Summary = $summary
    Common = $common
    VendorTitle = $vendorTitle
    VendorText = $vendorText
    Caution = $caution
  }
}

# 掉帧页的三处直达能力用行内高亮标记；正文仍保持单个 TextBlock，避免为五行说明
# 搭出额外控件树，同时让“可执行 / 可检查”比普通手动步骤一眼更醒目。
function Set-DropFrameCommonText([string]$Content) {
  if (-not $ui.FrameFixCommonText) { return }
  $ui.FrameFixCommonText.Inlines.Clear()
  $lines = @("$Content" -split "`r?`n")
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^(.*?)(【可执行】|【可检查】)(.*)$') {
      foreach ($part in @(
        @{ Text = $Matches[1]; Highlight = $false },
        @{ Text = $Matches[2]; Highlight = $true },
        @{ Text = $Matches[3]; Highlight = $false }
      )) {
        if (-not "$($part.Text)") { continue }
        $run = New-Object Windows.Documents.Run
        $run.Text = "$($part.Text)"
        if ($part.Highlight) {
          $run.Foreground = New-Brush $script:C.Green
          $run.Background = New-Brush '#3313A66D'
          $run.FontWeight = 'Bold'
        }
        [void]$ui.FrameFixCommonText.Inlines.Add($run)
      }
    } else {
      $run = New-Object Windows.Documents.Run
      $run.Text = $line
      [void]$ui.FrameFixCommonText.Inlines.Add($run)
    }
    if ($i -lt $lines.Count - 1) {
      [void]$ui.FrameFixCommonText.Inlines.Add((New-Object Windows.Documents.LineBreak))
    }
  }
}

# NVIDIA 专项正文里的两个产品名本身就是入口：已安装时直接打开对应程序，未安装时
# 打开 NVIDIA 官方下载页。入口仍只携带 launcher 已允许的固定产品 Key/HTTPS 地址。
function Set-DropFrameVendorText([string]$Content, [string]$Vendor) {
  if (-not $ui.FrameFixVendorText) { return }
  $ui.FrameFixVendorText.Inlines.Clear()

  $vendorKey = "$Vendor".Trim().ToUpperInvariant()
  $appsByName = @{}
  if ($vendorKey -eq 'NVIDIA') {
    foreach ($app in @(Get-GuiGpuPanelApps 'NVIDIA')) {
      if ($app -and $app.Name) { $appsByName["$($app.Name)"] = $app }
    }
  }

  $lines = @("$Content" -split "`r?`n")
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($part in @([regex]::Split($lines[$i], '(NVIDIA 控制面板|NVIDIA App)'))) {
      if (-not $part) { continue }
      if ($vendorKey -eq 'NVIDIA' -and $part -in 'NVIDIA 控制面板','NVIDIA App') {
        $app = $appsByName[$part]
        if (-not $app) {
          # 检测暂时未返回结果时仍保留固定白名单入口；launcher 会再次验证本机安装状态。
          $app = [pscustomobject]@{
            Key = $(if ($part -eq 'NVIDIA 控制面板') { 'nv-cpl' } else { 'nv-app' })
            Name = $part
            Installed = $true
            Download = $(if ($part -eq 'NVIDIA 控制面板') {
              'https://www.nvidia.cn/geforce/drivers/'
            } else {
              'https://www.nvidia.cn/software/nvidia-app/'
            })
          }
        }

        $link = New-Object Windows.Documents.Hyperlink
        $link.Foreground = New-Brush $script:C.Green
        $link.Background = New-Brush '#3313A66D'
        $link.FontWeight = 'Bold'
        $link.TextDecorations = [Windows.TextDecorations]::Underline
        $run = New-Object Windows.Documents.Run
        $run.Text = $part
        [void]$link.Inlines.Add($run)
        if ($app.Installed) {
          $link.ToolTip = "点击打开 $($app.Name)"
          $link.Tag = [pscustomobject]@{
            Mode = 'open'
            Name = "$($app.Name)"
            App = [pscustomobject]@{ Key = "$($app.Key)"; Name = "$($app.Name)" }
          }
        } else {
          $link.ToolTip = "本机未检测到 $($app.Name)，点击打开 NVIDIA 官网"
          $link.Tag = [pscustomobject]@{
            Mode = 'download'
            Name = "$($app.Name)"
            Url = "$($app.Download)"
          }
        }
        $link.Add_Click({
          try {
            if ($this.Tag.Mode -eq 'open') {
              Open-GpuPanel $this.Tag.App
              Write-Log "已打开 $($this.Tag.Name)。"
            } else {
              Open-HelpLink "$($this.Tag.Url)"
              Write-Log "已打开 $($this.Tag.Name) 官方下载页。"
            }
          } catch {
            Write-Log "打开 $($this.Tag.Name) 失败：$($_.Exception.Message)"
          }
        })
        [void]$ui.FrameFixVendorText.Inlines.Add($link)
      } else {
        $run = New-Object Windows.Documents.Run
        $run.Text = $part
        [void]$ui.FrameFixVendorText.Inlines.Add($run)
      }
    }
    if ($i -lt $lines.Count - 1) {
      [void]$ui.FrameFixVendorText.Inlines.Add((New-Object Windows.Documents.LineBreak))
    }
  }
}

function Update-DropFrameRepairPage {
  if (-not $script:HardwareInfo) {
    $ui.FrameFixGpuText.Text = '正在识别主力显卡…'
    $ui.FrameFixSummaryText.Text = '硬件检测完成后会自动生成对应方案。'
    return
  }
  $plan = Get-DropFrameRepairPlan $script:HardwareInfo
  $ui.FrameFixGpuText.Text = "$($plan.GpuName) · 已生成显卡专项方案"
  $ui.FrameFixSummaryText.Text = "$($plan.Summary)"
  Set-DropFrameCommonText "$($plan.Common)"
  $ui.FrameFixVendorTitle.Text = "$($plan.VendorTitle)"
  Set-DropFrameVendorText "$($plan.VendorText)" "$($script:HardwareInfo.MainGpuVendor)"
  $ui.FrameFixCautionText.Text = "$($plan.Caution)"
  $ui.FrameFixCacheBtn.IsEnabled = (-not $script:Busy -and -not $script:NetCafeCompatibilityMode)
  $ui.FrameFixGpuPrefBtn.IsEnabled = (-not $script:Busy)
  $ui.FrameFixVcBtn.IsEnabled = (-not $script:Busy)
  if ($script:NetCafeCompatibilityMode -and $ui.FrameFixActionStatus.Text -eq '请选择一项操作。') {
    $ui.FrameFixActionStatus.Text = '当前为管理员兼容模式：用户着色器缓存清理停用；高性能 GPU 与 VC++ 检查仍可直接执行。'
  }
}

# ---------- 标签页切换与执行态 ----------

$script:Busy = $false

function Select-Tab([string]$Which) {
  foreach ($t in @(@('opt', 'TabOptBtn', 'OptPage'), @('tune', 'TabTuneBtn', 'TunePage'), @('framefix', 'TabFrameFixBtn', 'FrameFixPage'), @('ref', 'TabRefBtn', 'RefPage'), @('log', 'TabLogBtn', 'LogPage'))) {
    $on = ($Which -eq $t[0])
    $ui[$t[1]].Tag = $(if ($on) { 'on' } else { '' })
    $ui[$t[2]].Visibility = $(if ($on) { 'Visible' } else { 'Collapsed' })
  }
  # 执行按钮只属于优化页，别让人以为参考设置或日志能「执行」
  $ui.ActionRow.Visibility = $(if ($Which -eq 'opt') { 'Visible' } else { 'Collapsed' })
  # 每次切入都重建：数据文件可能是界面启动之后才生成的
  if ($Which -eq 'ref') { Update-StreamerPage }
  if ($Which -eq 'tune') { Update-TuningUi }
  if ($Which -eq 'framefix') { Update-DropFrameRepairPage }
  # 看过就不用再提示了
  if ($Which -eq 'log') { Set-LogBadge 0 }
}

# 日志页角标：日志不在眼前了，出了失败/体检问题得有个信号。0 即清除
function Set-LogBadge([int]$Count) {
  $ui.LogBadgeTxt.Text = $(if ($Count -gt 99) { '99+' } else { "$Count" })
  $ui.LogBadge.Visibility = $(if ($Count -gt 0) { 'Visible' } else { 'Collapsed' })
}

function Set-BusyState([bool]$On) {
  # 执行期间禁用一切入口防重复点击；窗口关闭由 CloseBtn 与主窗口 Closing 双重拦截
  $script:Busy = $On
  foreach ($n in 'ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','CheckUpdBtn','ReportBtn','BrowseBtn',
                 'SavePresetBtn','DelPresetBtn','PresetBox','TabOptBtn','TabFrameFixBtn','TabRefBtn','UpdateBtn',
                 'FrameFixCacheBtn','FrameFixGpuPrefBtn','FrameFixVcBtn','FrameFixOptBtn','FrameFixGuideBtn',
                 'InlineRestoreSelectAllBtn','InlineRestoreClearBtn','InlineRestoreSelectedBtn',
                 'InlineRestoreAllBtn','InlineRestoreCloseBtn',
                 'TuneCreateBtn','TuneNextBtn','TuneStopBtn') {
    if ($ui[$n]) { $ui[$n].IsEnabled = -not $On }
  }
  # 更新恰好在执行优化/还原时被检测到：先不打断系统修改，收尾后立即补弹详情
  if (-not $On -and $script:UpdateInfo -and
      "$script:UpdatePromptedVersion" -ne "$($script:UpdateInfo.Version)") {
    [void]$window.Dispatcher.BeginInvoke([action]{ Show-DetectedUpdateDialog })
  }
  Update-TuningUi
}

function Update-ApplyProgress($p) {
  # 引擎每处理一项回调两次：start 刷「正在处理」，done 落一条实时日志并推进进度条
  if ($p.Stage -eq 'start') {
    $ui.ProgText.Text = "正在处理：$($p.Name)"
    $ui.ProgCount.Text = "第 $($p.Index) / 共 $($p.Total) 项"
  } else {
    $r = $p.Result
    # 检测项发现问题挂 Attention：是「体检查出了东西」不是「工具失败了」，标签要分开
    $tag = $(if ($r.Attention) { '[提示]' } elseif ($r.Ok) { '[成功]' } elseif ($r.Skipped) { '[跳过]' } else { '[失败]' })
    Write-Log "$tag $($r.Name) — $($r.Msg)"
    $w = $ui.ProgTrack.ActualWidth - 2
    if ($w -gt 0 -and $p.Total -gt 0) { $ui.ProgFill.Width = [math]::Max(0, $w * $p.Index / $p.Total) }
  }
  # 单线程模型：手动泵一次渲染队列让进度立即上屏。用 Render 优先级不放行输入事件，
  # 执行期间的点击一律进不来（按钮禁用之外的第二道保险），界面也不会整体假死
  $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
}

function Update-RestoreProgress($p) {
  # 还原复用执行优化的进度面板；粒度是备份里的「值」而不是优化项，单条极快且可能有
  # 几十条，逐条落日志会刷爆日志框——只推进度条和当前项文案，失败明细由汇总统一给
  if ($p.Stage -eq 'start') {
    $ui.ProgText.Text = "正在还原：$($p.Name)"
    $ui.ProgCount.Text = "第 $($p.Index) / 共 $($p.Total) 项"
  } else {
    $w = $ui.ProgTrack.ActualWidth - 2
    if ($w -gt 0 -and $p.Total -gt 0) { $ui.ProgFill.Width = [math]::Max(0, $w * $p.Index / $p.Total) }
  }
  $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
}

# 纯检测和用户着色器缓存不需要、也不应获得管理员权限。尤其用户缓存目录可由同权限
# 进程调整目录结构；缓存删除始终由 medium worker 完成，即使发生竞态也不会扩大权限。
function Invoke-LocalNoBackupItems([object[]]$Items) {
  $results = New-Object System.Collections.Generic.List[object]
  foreach ($it in @($Items)) {
    try {
      if ($it.Kind -eq 'cache') {
        # 着色器缓存在原用户可写 LocalAppData 中；即使 GUI 已提权也不放宽
        # 引擎的安全拒绝，而是经 EngineHost 转发给全生命周期 medium launcher worker。
        $cache = (Invoke-EngineHostUserAction ClearShaderCache) | ConvertFrom-Json
        if (@($cache.Cleared).Count -eq 0 -and @($cache.Failed).Count -eq 0) {
          [void]$results.Add([pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $true
            Msg = '无缓存可清理（本机没有找到着色器缓存文件）' })
        } elseif (@($cache.Failed).Count -gt 0 -and @($cache.Cleared).Count -eq 0) {
          [void]$results.Add([pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $false; Skipped = $false
            Msg = "$(@($cache.Failed) -join '；')——请关闭游戏与显卡驱动面板后重试" })
        } else {
          $msg = "$(@($cache.Cleared) -join '；')；此项不产生备份，也无需还原（缓存会由驱动自动重建）"
          if (@($cache.Failed).Count -gt 0) { $msg += "；另有 $(@($cache.Failed) -join '；')" }
          [void]$results.Add([pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = $msg })
        }
      } elseif ($it.Kind -eq 'check') {
        $state = & $it.Check
        [void]$results.Add([pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = ($state.Ok -eq $true)
          Skipped = $false; Attention = ($state.Ok -ne $true); Msg = "纯检测：$($state.Text)" })
      } else {
        throw "本地收尾执行器不接受项目类型：$($it.Kind)"
      }
    } catch {
      [void]$results.Add([pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $false; Skipped = $false; Msg = $_.Exception.Message })
    }
  }
  @($results.ToArray())
}

function Set-FrameFixActionStatus {
  param(
    [string]$Message,
    [ValidateSet('normal','success','warning','error')][string]$Tone = 'normal'
  )
  if (-not $ui.FrameFixActionStatus) { return }
  $ui.FrameFixActionStatus.Text = $Message
  $ui.FrameFixActionStatus.Foreground = New-Brush $(switch ($Tone) {
    'success' { $script:C.Green }
    'warning' { $script:C.Gold }
    'error'   { '#FFFF6B6B' }
    default   { $script:C.TextSec }
  })
}

function Set-FrameFixProgress {
  param(
    [string]$Message,
    [ValidateSet('start','success','warning','error')][string]$Mode = 'start'
  )
  if (-not $ui.FrameFixProgressPanel -or -not $ui.FrameFixProgressBar -or -not $ui.FrameFixProgressText) { return }
  $ui.FrameFixProgressPanel.Visibility = 'Visible'
  $ui.FrameFixProgressText.Text = $Message
  if ($Mode -eq 'start') {
    $ui.FrameFixProgressBar.Foreground = New-Brush $script:C.Green
    $ui.FrameFixProgressText.Foreground = New-Brush $script:C.TextSec
    $ui.FrameFixProgressBar.Value = 0
    $ui.FrameFixProgressBar.IsIndeterminate = $true
  } else {
    $ui.FrameFixProgressBar.IsIndeterminate = $false
    $ui.FrameFixProgressBar.Value = 100
    $color = $(switch ($Mode) {
      'success' { $script:C.Green }
      'warning' { $script:C.Gold }
      'error'   { '#FFFF6B6B' }
    })
    $ui.FrameFixProgressBar.Foreground = New-Brush $color
    $ui.FrameFixProgressText.Foreground = New-Brush $color
  }
  # 直接操作同步等待受保护 broker 返回；先泵一次 Render，确保进度条在耗时工作前上屏。
  $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
}

function Get-FrameFixActionItem([string]$Id) {
  $matches = @(Get-OptItems $script:TargetExe $script:SelectedGpuSpoofModel | Where-Object { $_.Id -eq $Id })
  if ($matches.Count -ne 1) { throw "掉帧修复操作不存在或不可用：$Id" }
  $matches[0]
}

function Invoke-FrameFixCacheCleanup {
  if ($script:Busy) { return }
  $busySet = $false
  try {
    if (Test-TuningExperimentActive) { throw '自动调优实验期间不能清理缓存，请先停止并回滚实验' }
    if ($script:NetCafeCompatibilityMode) { throw '管理员兼容模式没有原用户缓存权限；请关闭软件后普通双击启动，再执行缓存清理' }
    $item = Get-FrameFixActionItem 'shader-cache-clean'
    $message = "将清理 Windows、DirectX 与显卡驱动的着色器缓存。`n`n请先完全退出游戏、启动器和显卡驱动面板。清理后首次进入游戏需要重新编译着色器，头一两局可能暂时更卡；缓存会自动重建，因此本项不产生还原备份。"
    if (-not (Show-ConfirmDialog '清理缓存' 'CLEAR SHADER CACHE' $message '确认清理')) {
      Set-FrameFixActionStatus '已取消着色器缓存清理。' 'normal'
      return
    }
    Set-BusyState $true; $busySet = $true
    Set-FrameFixActionStatus '正在清理着色器缓存，请稍候…' 'warning'
    Set-FrameFixProgress '正在清理 Windows、DirectX 与显卡驱动着色器缓存…' 'start'
    Write-Log '掉帧修复：开始清理着色器缓存…'
    $row = @(Invoke-LocalNoBackupItems @($item)) | Select-Object -First 1
    if (-not $row) { throw '缓存清理没有返回结果' }
    $tag = $(if ($row.Ok -and $row.Skipped) { '[跳过]' } elseif ($row.Ok) { '[成功]' } else { '[失败]' })
    Write-Log "$tag $($row.Name) — $($row.Msg)"
    if (-not $row.Ok) {
      Set-FrameFixActionStatus "缓存清理失败：$($row.Msg)" 'error'
      Set-FrameFixProgress '着色器缓存清理失败，请查看下方说明。' 'error'
      Set-LogBadge 1
      Show-ConfirmDialog '清理失败' 'CACHE CLEAN FAILED' "$($row.Msg)" '知道了' -InfoOnly | Out-Null
    } elseif ($row.Skipped) {
      Set-FrameFixActionStatus '本机当前没有可清理的着色器缓存，无需处理。' 'warning'
      Set-FrameFixProgress '检查完成：本机当前没有可清理的着色器缓存。' 'warning'
    } else {
      Set-FrameFixActionStatus '着色器缓存已清理。首次进入游戏请等待缓存重建完成后再判断效果。' 'success'
      Set-FrameFixProgress '着色器缓存清理完成。' 'success'
    }
  } catch {
    Set-FrameFixActionStatus "缓存清理未完成：$($_.Exception.Message)" 'error'
    Set-FrameFixProgress '着色器缓存清理未完成，请查看错误说明。' 'error'
    Write-Log "掉帧修复：缓存清理失败 — $($_.Exception.Message)"
    Set-LogBadge 1
    Show-ConfirmDialog '清理未完成' 'CACHE CLEAN NOT COMPLETED' $_.Exception.Message '知道了' -InfoOnly | Out-Null
  } finally {
    if ($busySet) { Set-BusyState $false }
    try { Update-ItemList } catch { Write-Log "缓存清理后刷新状态失败：$($_.Exception.Message)" }
    Update-DropFrameRepairPage
  }
  if ($ui.InlineRestorePanel -and $ui.InlineRestorePanel.Visibility -eq 'Visible') {
    Update-InlineRestoreSelection
  }
}

function Invoke-FrameFixGpuPreference {
  if ($script:Busy) { return }
  $busySet = $false
  try {
    if (Test-TuningExperimentActive) { throw '自动调优实验期间已锁定配置，请先停止并回滚实验' }
    if (-not $script:TargetExe -or -not (Test-AllowedGameExecutable $script:TargetExe)) {
      Set-FrameFixActionStatus '尚未定位有效的三角洲主程序，请先在优化页重新定位游戏。' 'warning'
      Show-ConfirmDialog '需要游戏路径' 'GAME PATH REQUIRED' '请先到「优化」页点击“重新定位”，选择 DeltaForceClient-Win64-Shipping.exe 或 DeltaForce.exe，然后再回来执行。' '知道了' -InfoOnly | Out-Null
      return
    }
    [void](Get-FrameFixActionItem 'gpu-pref')
    $message = "将把以下游戏主程序写入 Windows 高性能 GPU 首选项：`n`n$script:TargetExe`n`n修改前会写入受保护备份，可在「还原设置」中单独复原「强制游戏使用高性能 GPU」。"
    if (-not (Show-ConfirmDialog '设置高性能 GPU' 'HIGH PERFORMANCE GPU' $message '确认设置')) {
      Set-FrameFixActionStatus '已取消高性能 GPU 设置。' 'normal'
      return
    }
    Set-BusyState $true; $busySet = $true
    Set-FrameFixActionStatus '正在写入 Windows 高性能 GPU 首选项…' 'warning'
    Set-FrameFixProgress '正在设置 Windows 高性能 GPU 首选项并保存还原备份…' 'start'
    Write-Log '掉帧修复：正在为当前游戏设置高性能 GPU…'
    $reply = Invoke-ElevatedEngineAction -Action Apply -ItemIds @('gpu-pref') -GamePath $script:TargetExe `
      -GpuSpoofModel $script:SelectedGpuSpoofModel
    $rows = @($reply.Results | Where-Object { $_.Id -eq 'gpu-pref' })
    if ($rows.Count -ne 1) { throw '高性能 GPU 操作没有返回唯一结果' }
    $row = $rows[0]
    if ($reply.Backup) { Write-Log "备份已保存：$($reply.Backup)" }
    $changed = [bool]($row.PSObject.Properties['Changed'] -and $row.Changed -eq $true)
    if ($changed) {
      $script:TuningConfigGeneration++
    }
    if ($row.Ok) {
      try {
        $catalog = Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems
        Update-TelemetryOptimizationContextFromCatalog -Catalog $catalog -RequestedScheme 'frame-fix' `
          -RequestedItemIds @('gpu-pref') -KnownChangedItemIds $(if ($changed) { @('gpu-pref') } else { @() }) `
          -MutationIncomplete:([bool]$reply.BackupError)
      } catch { Write-Log "高性能 GPU 已设置，但当前优化状态同步失败：$($_.Exception.Message)" }
    }
    $tag = $(if ($row.Ok -and -not $changed) { '[跳过]' } elseif ($row.Ok) { '[成功]' } else { '[失败]' })
    Write-Log "$tag $($row.Name) — $($row.Msg)"
    if ($reply.BackupError) {
      $lost = @($reply.UnrecordedNames | Where-Object { $_ })
      $detail = "设置过程发生备份错误：$($reply.BackupError)" +
        $(if ($lost.Count -gt 0) { "`n`n以下改动可能已生效但没有完整备份：$($lost -join '、')" } else { '' })
      Set-FrameFixActionStatus $detail 'error'
      Set-FrameFixProgress '高性能 GPU 设置完成，但还原备份写入异常。' 'error'
      Write-Log "！！掉帧修复备份错误：$($reply.BackupError)"
      Set-LogBadge 1
      Show-ConfirmDialog '备份写入失败' 'BACKUP WRITE FAILED' $detail '我已知晓' -InfoOnly | Out-Null
    } elseif (-not $row.Ok) {
      Set-FrameFixActionStatus "高性能 GPU 设置失败：$($row.Msg)" 'error'
      Set-FrameFixProgress '高性能 GPU 设置失败，请查看下方说明。' 'error'
      Set-LogBadge 1
      Show-ConfirmDialog '设置失败' 'GPU PREFERENCE FAILED' "$($row.Msg)" '知道了' -InfoOnly | Out-Null
    } elseif ($changed) {
      Set-FrameFixActionStatus '已将当前三角洲主程序设为高性能 GPU，并保存可单独复原的备份。' 'success'
      Set-FrameFixProgress '高性能 GPU 首选项设置完成。' 'success'
    } else {
      Set-FrameFixActionStatus '当前游戏已经使用 Windows 高性能 GPU 首选项，无需重复写入。' 'success'
      Set-FrameFixProgress '检查完成：当前游戏已经使用高性能 GPU 首选项。' 'success'
    }
    try {
      $operation = New-OptimizationTelemetryOperation -Event apply -Source frame_fix -Reply $reply -ItemIds @('gpu-pref')
      Send-AnonymousTelemetry 'apply' $script:HardwareInfo $(if ($row.Ok) { 1 } else { 0 }) $(if ($row.Ok) { 0 } else { 1 }) $operation
    } catch {}
  } catch {
    Set-FrameFixActionStatus "高性能 GPU 设置未完成：$($_.Exception.Message)" 'error'
    Set-FrameFixProgress '高性能 GPU 设置未完成，请查看错误说明。' 'error'
    Write-Log "掉帧修复：高性能 GPU 设置失败 — $($_.Exception.Message)"
    Set-LogBadge 1
    Show-ConfirmDialog '设置未完成' 'GPU PREFERENCE NOT COMPLETED' $_.Exception.Message '知道了' -InfoOnly | Out-Null
  } finally {
    if ($busySet) { Set-BusyState $false }
    try { Update-ItemList } catch { Write-Log "高性能 GPU 设置后刷新状态失败：$($_.Exception.Message)" }
    Update-DropFrameRepairPage
  }
}

function Invoke-FrameFixVcredistCheck {
  if ($script:Busy) { return }
  $busySet = $false
  try {
    if (Test-TuningExperimentActive) { throw '自动调优实验期间请先完成当前步骤或停止实验' }
    $item = Get-FrameFixActionItem 'vcredist-check'
    Set-BusyState $true; $busySet = $true
    Set-FrameFixActionStatus '正在检查 VC++ 2015–2022 x64 / x86 运行库…' 'warning'
    Set-FrameFixProgress '正在检查 VC++ 2015–2022 x64 / x86 运行库…' 'start'
    Write-Log '掉帧修复：开始检查 VC++ 运行库…'
    $row = @(Invoke-LocalNoBackupItems @($item)) | Select-Object -First 1
    if (-not $row) { throw 'VC++ 运行库检查没有返回结果' }
    $tag = $(if ($row.Attention) { '[提示]' } elseif ($row.Ok) { '[正常]' } else { '[失败]' })
    Write-Log "$tag $($row.Name) — $($row.Msg)"
    if ($row.Attention) {
      Set-FrameFixActionStatus '检测到 VC++ 运行库缺失或异常，已打开修复教程与微软官方入口。' 'warning'
      Set-FrameFixProgress 'VC++ 运行库检查完成：检测到需要处理的项目。' 'warning'
      Set-LogBadge 1
      Show-HealthDialog @($row)
    } elseif ($row.Ok) {
      Set-FrameFixActionStatus 'VC++ 2015–2022 x64 / x86 运行库检查正常。' 'success'
      Set-FrameFixProgress 'VC++ 运行库检查完成，结果正常。' 'success'
    } else {
      Set-FrameFixActionStatus "VC++ 运行库检查失败：$($row.Msg)" 'error'
      Set-FrameFixProgress 'VC++ 运行库检查失败，请查看下方说明。' 'error'
      Set-LogBadge 1
      Show-ConfirmDialog '检查失败' 'VC++ CHECK FAILED' "$($row.Msg)" '知道了' -InfoOnly | Out-Null
    }
  } catch {
    Set-FrameFixActionStatus "VC++ 运行库检查未完成：$($_.Exception.Message)" 'error'
    Set-FrameFixProgress 'VC++ 运行库检查未完成，请查看错误说明。' 'error'
    Write-Log "掉帧修复：VC++ 运行库检查失败 — $($_.Exception.Message)"
    Set-LogBadge 1
    Show-ConfirmDialog '检查未完成' 'VC++ CHECK NOT COMPLETED' $_.Exception.Message '知道了' -InfoOnly | Out-Null
  } finally {
    if ($busySet) { Set-BusyState $false }
    try { Update-ItemList } catch { Write-Log "VC++ 检查后刷新状态失败：$($_.Exception.Message)" }
    Update-DropFrameRepairPage
  }
}

# 管理员引擎返回后，GUI 还要执行只读检测、medium worker 缓存清理、遥测和界面刷新。后半段即使
# 抛异常，系统批次也可能已经完成；把这个状态与会话前置失败分开，避免用户误以为本轮
# 完全没执行而立刻重复点击。异常类型和脚本堆栈只写运行日志，弹窗继续使用人话提示。
function Get-ApplyFailureContext($ErrorRecord, [bool]$AdminBatchReturned, $Reply) {
  $exception = $(if ($ErrorRecord -and $ErrorRecord.Exception) { $ErrorRecord.Exception } else { $null })
  $message = $(if ($exception -and $exception.Message) { "$($exception.Message)" }
               elseif ($ErrorRecord) { "$ErrorRecord" } else { '未知错误' })
  $exceptionType = $(if ($exception) { $exception.GetType().FullName } else { 'Unknown' })
  $stack = $(if ($ErrorRecord -and "$($ErrorRecord.ScriptStackTrace)".Trim()) {
               "$($ErrorRecord.ScriptStackTrace)".Trim()
             } else { '(无)' })
  $backupPath = $(if ($Reply -and $Reply.PSObject.Properties['Backup'] -and $Reply.Backup) {
                    "$($Reply.Backup)"
                  } else { $null })
  $userMessage = $message
  if ($AdminBatchReturned) {
    $userMessage = "系统批次可能已经执行，但界面收尾没有完成。请不要重复点击「执行优化」。" +
                   "`n`n请优先点击「还原设置」；如果提示没有可用备份，请点击「重新检测」确认当前状态。" +
                   "`n`n收尾错误：$message"
  }
  [pscustomobject]@{
    AdminBatchReturned = $AdminBatchReturned
    ErrorMessage = $message
    ExceptionType = $exceptionType
    ScriptStackTrace = $stack
    BackupPath = $backupPath
    UserMessage = $userMessage
  }
}

# GUI 由 EngineHost 在一次 UAC 后长期持有管理员令牌。Apply/Restore/Beta 仍使用
# 短生命周期 PowerShell 子进程与受保护 ProgramData IPC，用于隔离引擎退出码/结果；
# 子进程只继承已提权令牌，不再调用 RunAs，因此每次操作不再重复弹 UAC。
function Test-ProtectedProgramRoot {
  try {
    $root = [IO.Path]::GetFullPath($script:RootDir).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $false }
    if ($root.StartsWith('\\')) { return $false }
    if ((New-Object IO.DriveInfo([IO.Path]::GetPathRoot($root))).DriveType -ne [IO.DriveType]::Fixed -or
        (Test-BootstrapPathHasReparsePoint $root)) { return $false }
    $acl = [IO.Directory]::GetAccessControl($root,
      [Security.AccessControl.AccessControlSections]'Owner, Access')
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin @('S-1-5-18','S-1-5-32-544') -and $owner -notlike 'S-1-5-80-*') { return $false }
    $writeMask = [Security.AccessControl.FileSystemRights]'WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, DeleteSubdirectoriesAndFiles, Delete, ChangePermissions, TakeOwnership'
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $sid = $rule.IdentityReference.Value
      $trusted = $sid -in @('S-1-5-18','S-1-5-32-544') -or $sid -like 'S-1-5-80-*'
      $creatorInheritOnly = $sid -eq 'S-1-3-0' -and
        (($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0)
      if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
          -not $trusted -and -not $creatorInheritOnly -and (($rule.FileSystemRights -band $writeMask) -ne 0)) {
        return $false
      }
    }
    $true
  } catch { return $false }
}

function Get-ProtectedEngineExchangeRoot {
  $session = "$env:DFB_ENGINE_HOST_SESSION"
  if ($session -notmatch '^[0-9a-fA-F]{32}$') { throw '管理员引擎会话标记无效' }
  $programData = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
  if (-not $programData -or -not $env:TEMP) { throw '系统未提供管理员引擎会话目录' }
  $expected = [IO.Path]::GetFullPath((Join-Path $programData "DeltaForceBooster\session-temp\$session")).TrimEnd('\')
  $actual = [IO.Path]::GetFullPath("$env:TEMP").TrimEnd('\')
  if ($actual -ine $expected -or "$env:TMP" -ine $actual -or
      -not (Test-Path -LiteralPath $actual -PathType Container) -or
      (Test-PathHasReparsePoint $actual) -or -not (Test-ProtectedDirectoryAclExact $actual $false)) {
    throw '管理员引擎会话目录不可信'
  }
  $actual
}

function Remove-ProtectedEngineExchangeFile([string]$Path, [string]$ExchangeRoot) {
  $full = [IO.Path]::GetFullPath($Path)
  if ((Split-Path -Parent $full).TrimEnd('\') -ine [IO.Path]::GetFullPath($ExchangeRoot).TrimEnd('\')) {
    throw '管理员引擎交换文件越出会话目录'
  }
  if (-not (Test-Path -LiteralPath $full)) { return }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf) -or (Test-PathHasReparsePoint $full) -or
      -not (Test-ProtectedFileAcl $full)) { throw '管理员引擎交换文件类型或权限无效' }
  Remove-Item -LiteralPath $full -Force
}

function Write-ProtectedEngineRequest([string]$Path, $Request) {
  if (Test-Path -LiteralPath $Path) { throw '管理员引擎请求文件已存在' }
  $json = $Request | ConvertTo-Json -Depth 5 -Compress
  $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json)
  if ($bytes.Length -le 0 -or $bytes.Length -gt 65536) { throw '管理员引擎请求大小无效' }
  Write-BytesAtomic $Path $bytes
  Set-ProtectedFileAcl $Path
  if ((Test-PathHasReparsePoint $Path) -or -not (Test-ProtectedFileAcl $Path)) {
    throw '管理员引擎请求文件权限校验失败'
  }
}

function ConvertTo-NativeFileArgument([string]$Path) {
  if (-not $Path -or $Path -match '[\x00\r\n"]' -or $Path.EndsWith('\')) {
    throw '管理员引擎原生进程路径无法安全引用'
  }
  '"' + $Path + '"'
}

function ConvertTo-EngineDiagnosticSummary([string]$StandardError, [string]$StandardOutput) {
  $text = $(if ($StandardError -and $StandardError.Trim()) { $StandardError }
            elseif ($StandardOutput -and $StandardOutput.Trim()) { $StandardOutput } else { '' })
  if (-not $text) { return '' }
  if ($text.StartsWith('#< CLIXML', [StringComparison]::Ordinal)) {
    try {
      $xml = $text.Substring($text.IndexOf("`n") + 1)
      $text = ([Management.Automation.PSSerializer]::Deserialize($xml) | Out-String)
    } catch {}
  }
  $text = [regex]::Replace($text, '_x000D__x000A_|\s+', ' ').Trim()
  if ($text.Length -gt 1200) { $text = '…' + $text.Substring($text.Length - 1199) }
  $text
}

function Invoke-ElevatedEngineAction {
  param(
    [Parameter(Mandatory)][ValidateSet('Apply','Restore')][string]$Action,
    [string[]]$ItemIds,
    [string]$GamePath,
    [bool]$AllowRisky = $false,
    [string]$GpuSpoofModel,
    [string]$BackupFile,
    [switch]$ListRestoreItems,
    [string[]]$RestoreItemIds,
    [string]$ResultId
  )
  if (-not $script:EngineHostSessionValidated -or -not $isAdminGui) {
    throw '当前不在受信 EngineHost 管理员会话中，已拒绝执行'
  }
  if (-not (Test-ProtectedProgramRoot)) {
    throw '当前程序目录不是受保护的本地安装目录。请用最新安装器修复安装后重试。'
  }
  $engine = Join-Path $script:RootDir 'scripts\delta-booster.ps1'
  if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw '核心优化引擎缺失，请重新安装软件' }

  $resultIdText = $(if ($ResultId) { "$ResultId" } else { [guid]::NewGuid().ToString('D') })
  $parsedResultId = [guid]::Empty
  if (-not [guid]::TryParseExact($resultIdText, 'D', [ref]$parsedResultId)) {
    throw '管理员执行结果 ID 无效'
  }
  $resultId = $parsedResultId.ToString('D')
  $userLocalAppData = $script:OriginalUserLocalAppData
  if (-not $userLocalAppData) { throw '系统未提供用户数据目录' }
  $userSid = $script:OriginalUserSid
  $userLocalAppData = [IO.Path]::GetFullPath($userLocalAppData)
  # `$null | ForEach-Object { "$_" }` 会产出一个空字符串，不能用它归一化未绑定的
  # 可选数组参数，否则普通 Apply / 还原目录查询会被误判为混入了另一类参数。
  $itemIdsForRequest = [string[]]@($ItemIds | Where-Object { $null -ne $_ } | ForEach-Object { "$_" })
  $restoreIdsForRequest = [string[]]@($RestoreItemIds | Where-Object { $null -ne $_ } | ForEach-Object { "$_" })
  $normalizedGamePath = $(if ($GamePath) { [IO.Path]::GetFullPath($GamePath) } else { $null })
  $normalizedBackupFile = $null
  if ($Action -eq 'Apply') {
    if ($itemIdsForRequest.Count -eq 0) { throw '管理员执行请求没有优化项目' }
    if ($ListRestoreItems -or $restoreIdsForRequest.Count -gt 0 -or $BackupFile) { throw '优化请求包含还原参数' }
  } else {
    if ($ListRestoreItems -and ($restoreIdsForRequest.Count -gt 0 -or $BackupFile)) { throw '还原目录查询不能与复原项目或指定备份同时使用' }
    if ($restoreIdsForRequest.Count -gt 0 -and $BackupFile) { throw '按项目复原不能同时指定整份备份' }
    foreach ($id in $restoreIdsForRequest) { if ("$id" -notmatch '^[a-z0-9][a-z0-9-]{0,63}$') { throw "复原项目 ID 无效：$id" } }
    if ($BackupFile) {
      # Beta 回滚必须指向它自己刚刚生成的备份，绝不退化为“还原全部”。
      if (-not (Test-TuningBackupReference $BackupFile)) { throw '指定的实验备份路径无效' }
      $normalizedBackupFile = [IO.Path]::GetFullPath($BackupFile)
    }
  }

  $exchangeRoot = Get-ProtectedEngineExchangeRoot
  $requestFile = Join-Path $exchangeRoot ("engine-request-$resultId.json")
  $resultFile = Join-Path $exchangeRoot ("engine-result-$resultId.json")
  foreach ($path in @($requestFile, $resultFile)) { Remove-ProtectedEngineExchangeFile $path $exchangeRoot }
  $request = [ordered]@{
    SchemaVersion = 1; ResultId = $resultId; Action = $Action
    ItemIds = $itemIdsForRequest; GamePath = $normalizedGamePath; AllowRisky = [bool]$AllowRisky
    GpuSpoofModel = $(if ($GpuSpoofModel) { "$GpuSpoofModel" } else { $null })
    BackupFile = $normalizedBackupFile; ListRestoreItems = [bool]$ListRestoreItems
    RestoreItemIds = $restoreIdsForRequest; UserSid = $userSid
    UserLocalAppData = $userLocalAppData; UserStateRoot = [IO.Path]::GetFullPath($script:ProtectedUserStateRoot)
  }
  Write-ProtectedEngineRequest $requestFile $request

  # 即使已在管理员会话，系统可执行文件仍只从 Known Folder 取得。
  $windowsDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
  if (-not $windowsDir) { throw '系统未提供 Windows 目录' }
  $powershellExe = Join-Path $windowsDir 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $proc = $null; $stdoutTask = $null; $stderrTask = $null
  $standardOutput = ''; $standardError = ''; $exitCode = -1
  try {
    try {
      # 继承 EngineHost 的 high token，不跨越新的 UAC 边界。请求是数据文件，命令行只含固定开关与受保护路径。
      $startInfo = New-Object Diagnostics.ProcessStartInfo
      $startInfo.FileName = $powershellExe
      $startInfo.Arguments = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-OutputFormat','Text',
        '-File',(ConvertTo-NativeFileArgument $engine),'-RequestFile',(ConvertTo-NativeFileArgument $requestFile)) -join ' '
      $startInfo.WorkingDirectory = [Environment]::SystemDirectory
      $startInfo.UseShellExecute = $false
      $startInfo.CreateNoWindow = $true
      $startInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
      $startInfo.RedirectStandardOutput = $true
      $startInfo.RedirectStandardError = $true
      $proc = New-Object Diagnostics.Process
      $proc.StartInfo = $startInfo
      if (-not $proc.Start()) { throw '系统未创建管理员引擎进程' }
      $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
      $stderrTask = $proc.StandardError.ReadToEndAsync()
    } catch {
      throw "引擎子进程启动失败：$($_.Exception.Message)"
    }
    while (-not $proc.HasExited) {
      $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
      Start-Sleep -Milliseconds 80
      $proc.Refresh()
    }
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    if ($stdoutTask) { try { $standardOutput = $stdoutTask.GetAwaiter().GetResult() } catch {} }
    if ($stderrTask) { try { $standardError = $stderrTask.GetAwaiter().GetResult() } catch {} }

    # 引擎会在退出前 Flush(true) 并原子发布结果；仍短暂重试以容忍实时扫描造成的共享延迟。
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while (-not (Test-Path -LiteralPath $resultFile) -and [DateTime]::UtcNow -lt $deadline) {
      Start-Sleep -Milliseconds 80
    }
    if (-not (Test-Path -LiteralPath $resultFile)) {
      $detail = ConvertTo-EngineDiagnosticSummary $standardError $standardOutput
      $recoveryHint = $(if ($Action -eq 'Apply') {
          '本次系统设置可能已部分执行，请不要重复点击「执行优化」；请先「重新检测」，必要时使用「还原设置」。'
        } elseif ($ListRestoreItems) {
          '还原项目读取未完成，请稍后重新检测。'
        } else {
          '本次还原状态未知，请重新打开还原清单核对。'
        })
      if ($detail) { throw "管理员引擎在写回结果前异常退出（退出码 $exitCode）：$detail`n`n$recoveryHint" }
      throw "管理员引擎在写回结果前异常退出（退出码 $exitCode），系统未返回错误文本；请检查安全软件或 PowerShell 应用控制记录。`n`n$recoveryHint"
    }
    if ((Test-PathHasReparsePoint $resultFile) -or -not (Test-ProtectedFileAcl $resultFile)) {
      throw '管理员执行结果文件权限校验失败'
    }
    $resultInfo = Get-Item -LiteralPath $resultFile -Force
    if ($resultInfo.Length -le 0 -or $resultInfo.Length -gt 4MB) { throw '管理员执行结果文件大小无效' }
    try { $reply = Get-Content -LiteralPath $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "管理员执行结果读取失败：$($_.Exception.Message)" }
    if ([int]$reply.SchemaVersion -ne 1 -or "$($reply.ResultId)" -ne $resultId -or "$($reply.Action)" -ne $Action -or
        [int]$reply.ExitCode -ne $exitCode) {
      throw '管理员执行结果校验失败'
    }
    if ($null -eq $reply.Data) {
      throw $(if ("$($reply.Error)") { "$($reply.Error)" } else { "执行失败（退出码 $($reply.ExitCode)）" })
    }
    $reply.Data | Add-Member -NotePropertyName EngineExitCode -NotePropertyValue ([int]$reply.ExitCode) -Force
    $reply.Data
  } finally {
    if ($proc) { try { $proc.Dispose() } catch {} }
    foreach ($path in @($requestFile, $resultFile)) {
      try { Remove-ProtectedEngineExchangeFile $path $exchangeRoot }
      catch { try { Write-Log "管理员引擎会话文件清理失败：$($_.Exception.Message)" } catch {} }
    }
  }
}

# 主题化确认/信息对话框：原生 MessageBox 白底系统样式与深色主题完全不搭（用户实测吐槽），
# 全站确认（执行/还原/删除）和长文本指引统一走这里。正文放 ScrollViewer：
# 执行清单可达 30 行、显卡指引更长，超高时内部滚动而不是把对话框撑出屏幕
function Show-ConfirmDialog([string]$ChipText, [string]$EnText, [string]$Message,
                            [string]$OkText = '确定', [switch]$InfoOnly, [string]$Banner,
                            [switch]$DefaultCancel) {
  $cxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="440" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="{DynamicResource Gold}" Padding="7,1" VerticalAlignment="Center">
          <TextBlock x:Name="ChipTxt" Text="" Foreground="{DynamicResource GoldDark}" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock x:Name="EnTxt" Text="" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <!-- 醒目横幅（可选）：显卡指引用它标出「检测到你的显卡：xxx」，让用户一眼确认
         这份指引就是按自己的硬件生成的（实机反馈感知不到） -->
    <Border x:Name="BannerRow" Visibility="Collapsed" Background="{DynamicResource AccentPanel}" BorderBrush="{DynamicResource GreenLine}"
            BorderThickness="1" Margin="14,12,14,0" Padding="10,7">
      <TextBlock x:Name="BannerTxt" Text="" Foreground="{DynamicResource Green}" FontSize="12" FontWeight="Bold"
                 TextWrapping="Wrap"/>
    </Border>
    <Border Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="14,12,14,12">
      <ScrollViewer MaxHeight="340" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="MsgTxt" Text="" Foreground="{DynamicResource TextSec}" FontSize="12" LineHeight="19"
                   TextWrapping="Wrap" Padding="12,9"/>
      </ScrollViewer>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" Foreground="{DynamicResource GreenDark}" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="OkTxt" Text="确定"/>
      </Button>
      <Button x:Name="CancelBtn" Width="80" Height="30" IsCancel="True" Foreground="{DynamicResource Green}" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="取消"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  # 事件处理器在模态期间回调，与 Show-UpdateDialog 同理：要用的对象放 script 作用域最稳
  $script:CfmDlg = [Windows.Markup.XamlReader]::Parse($cxaml)
  # 深色滚动条等共享 Chrome：独立 Window 不继承主窗口资源，必须逐个挂（实机反馈）
  $script:CfmDlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $script:CfmDlg.Owner = $window
  $script:CfmDlg.FindName('ChipTxt').Text = $ChipText
  $script:CfmDlg.FindName('EnTxt').Text = $EnText
  $script:CfmDlg.FindName('MsgTxt').Text = $Message
  $script:CfmDlg.FindName('OkTxt').Text = $OkText
  # 信息模式（如显卡指引）没有「取消」的语义，只留一个确认按钮
  if ($InfoOnly) { $script:CfmDlg.FindName('CancelBtn').Visibility = 'Collapsed' }
  elseif ($DefaultCancel) {
    # 风险确认默认停在「取消」；误按回车不会直接执行系统级改动。
    $script:CfmDlg.FindName('OkBtn').IsDefault = $false
    $script:CfmDlg.FindName('CancelBtn').IsDefault = $true
    $script:CfmDlg.FindName('CancelBtn').Focus() | Out-Null
  }
  # 可选醒目横幅：显卡指引用它标出检测到的显卡型号
  if ($Banner) {
    $script:CfmDlg.FindName('BannerTxt').Text = $Banner
    $script:CfmDlg.FindName('BannerRow').Visibility = 'Visible'
  }
  $script:CfmDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:CfmDlg.DragMove() })
  $script:CfmDlg.FindName('OkBtn').Add_Click({ $script:CfmDlg.DialogResult = $true })
  $script:CfmDlg.FindName('CancelBtn').Add_Click({ $script:CfmDlg.DialogResult = $false })
  [bool]$script:CfmDlg.ShowDialog()
}

function Update-InlineRestoreSelection {
  if (-not $ui.InlineRestorePanel) { return }
  $checks = $(if ($script:InlineRestoreChecks) { @($script:InlineRestoreChecks.ToArray()) } else { @() })
  $selectedCount = @($checks | Where-Object IsChecked).Count
  $selectableCount = @($checks | Where-Object IsEnabled).Count
  $ready = (-not $script:Busy -and -not (Test-TuningExperimentActive))
  $ui.InlineRestoreSelectedText.Text = "已选择 $selectedCount 项"
  $ui.InlineRestoreSelectedBtn.IsEnabled = ($ready -and $selectedCount -gt 0)
  $ui.InlineRestoreAllBtn.IsEnabled = ($ready -and $script:InlineRestoreCatalog -and
    [bool]$script:InlineRestoreCatalog.HasActiveChanges)
  $ui.InlineRestoreSelectAllBtn.IsEnabled = ($ready -and $selectableCount -gt 0)
  $ui.InlineRestoreClearBtn.IsEnabled = ($ready -and $selectedCount -gt 0)
  $ui.InlineRestoreCloseBtn.IsEnabled = (-not $script:Busy)
}

function Hide-InlineRestorePanel {
  $ui.InlineRestorePanel.Visibility = 'Collapsed'
  $ui.RestoreBtn.Content = '还原设置'
  $script:InlineRestoreCatalog = $null
  $script:InlineRestoreChecks = $null
}

function Initialize-InlineRestorePanel($Catalog) {
  $script:InlineRestoreCatalog = $Catalog
  $script:InlineRestoreChecks = New-Object System.Collections.Generic.List[object]
  $ui.InlineRestoreItemsPanel.Children.Clear()
  $ui.InlineRestoreEmptyText.Visibility = 'Collapsed'
  $ui.InlineRestoreLegacyNotice.Visibility = 'Collapsed'
  $ui.InlineRestoreLegacyText.Text = ''

  foreach ($item in @($Catalog.Items | Sort-Object Name)) {
    $row = New-Object Windows.Controls.Border
    $row.BorderBrush = New-Brush $script:C.LineSoft
    $row.BorderThickness = New-Object Windows.Thickness 0,0,0,1
    $row.Padding = New-Object Windows.Thickness 3,7,3,7
    $cb = New-Object Windows.Controls.CheckBox
    $cb.Style = $window.FindResource('TacCheck')
    $cb.Tag = "$($item.Id)"
    $cb.IsEnabled = [bool]$item.CanRestore
    $content = New-Object Windows.Controls.StackPanel
    $title = New-Object Windows.Controls.TextBlock
    $title.Text = "$($item.Name)"
    $title.Foreground = New-Brush $(if ($item.CanRestore) { $script:C.TextPri } else { $script:C.TextMut })
    $title.FontWeight = 'SemiBold'
    [void]$content.Children.Add($title)
    $meta = New-Object Windows.Controls.TextBlock
    $reboot = $(if ($item.RebootRequired) { ' · 需要重启' } else { ' · 即时写回' })
    $meta.Text = "$($item.SettingCount) 个设置 · $($item.StatusText)$reboot"
    $meta.Foreground = New-Brush $(if ($item.CanRestore) { $script:C.Green } elseif ($item.Status -eq 'conflict') { $script:C.Danger } else { $script:C.Gold })
    $meta.FontSize = 10
    $meta.Margin = New-Object Windows.Thickness 0,3,0,0
    [void]$content.Children.Add($meta)
    if ($item.Reason) { $cb.ToolTip = "$($item.Reason)" }
    $cb.Content = $content
    $cb.Add_Checked({ Update-InlineRestoreSelection })
    $cb.Add_Unchecked({ Update-InlineRestoreSelection })
    $row.Child = $cb
    [void]$ui.InlineRestoreItemsPanel.Children.Add($row)
    [void]$script:InlineRestoreChecks.Add($cb)
  }
  if ($script:InlineRestoreChecks.Count -eq 0) {
    $ui.InlineRestoreEmptyText.Visibility = 'Visible'
  }

  $restoreNotices = @()
  if ([int]$Catalog.LegacyBackupCount -gt 0) {
    $restoreNotices += "检测到 $($Catalog.LegacyBackupCount) 份旧版本备份，缺少项目归属信息，仅支持下方「全部复原」。"
  }
  if ([int]$Catalog.UnsupportedV3ItemCount -gt 0) {
    $restoreNotices += "另有 $($Catalog.UnsupportedV3ItemCount) 个尚未开放按项目精确复原的项目，本阶段仅支持「全部复原」。"
  }
  if ($restoreNotices.Count -gt 0) {
    $ui.InlineRestoreLegacyText.Text = $restoreNotices -join "`n"
    $ui.InlineRestoreLegacyNotice.Visibility = 'Visible'
  }
  $ui.InlineRestoreAllSummary.Text = "恢复所有仍由工具管理的改动：$($Catalog.ActiveItemCount) 个新版本项目、$($Catalog.ActiveOpCount) 个底层设置、$($Catalog.ActiveBackupCount) 份活动备份。"
  $ui.InlineRestorePanel.Visibility = 'Visible'
  $ui.RestoreBtn.Content = '收起复原'
  Update-InlineRestoreSelection
  $ui.InlineRestorePanel.BringIntoView()
}

function Invoke-InlineRestoreAction([ValidateSet('selected_items','all')][string]$Mode) {
  if ($script:Busy) { return }
  $busySet = $false
  try {
    if (Test-TuningExperimentActive) { throw '自动调优实验期间禁止普通还原；请使用「停止并回滚」只处理本实验备份' }
    $catalog = $script:InlineRestoreCatalog
    if (-not $catalog -or -not $catalog.HasActiveChanges) {
      Hide-InlineRestorePanel
      Show-ConfirmDialog '无需还原' 'NO ACTIVE CHANGES' '当前没有仍由工具管理的可还原改动。' '知道了' -InfoOnly | Out-Null
      return
    }

    $itemIds = @()
    if ($Mode -eq 'selected_items') {
      $itemIds = @($script:InlineRestoreChecks.ToArray() | Where-Object IsChecked | ForEach-Object { "$($_.Tag)" })
      if ($itemIds.Count -eq 0) { return }
      $selectedNames = @($catalog.Items | Where-Object { $itemIds -contains "$($_.Id)" } | ForEach-Object Name)
      $confirmText = "将以下 $($selectedNames.Count) 个项目恢复到第一次被本工具修改前，其他项目保持不变：`n`n· " + ($selectedNames -join "`n· ")
      if (-not (Show-ConfirmDialog '确认按项目复原' 'CONFIRM SELECTED RESTORE' $confirmText '复原所选项目')) { return }
    } else {
      if (-not (Show-ConfirmDialog '确认全部复原' 'CONFIRM FULL RESTORE' '合并所有仍有效的备份，把全部工具管理的设置恢复到第一次优化前的原始状态？' '全部复原')) { return }
    }

    Set-BusyState $true; $busySet = $true
    $ui.ProgressPanel.Visibility = 'Visible'
    $ui.ProgFill.Width = 0
    $ui.ProgText.Text = $(if ($Mode -eq 'selected_items') { '正在复原所选项目…' } else { '正在全部复原系统设置…' })
    $ui.ProgCount.Text = ''
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $r = $(if ($Mode -eq 'selected_items') {
      Invoke-ElevatedEngineAction -Action Restore -RestoreItemIds $itemIds
    } else { Invoke-ElevatedEngineAction -Action Restore })
    $script:TuningConfigGeneration++
    $w = $ui.ProgTrack.ActualWidth - 2
    if ($w -gt 0) { $ui.ProgFill.Width = $w }
    $failN = @($r.Failed).Count
    $skipN = @($r.Skipped).Count
    try {
      $updatedCatalog = Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems
      Update-TelemetryOptimizationContextFromCatalog -Catalog $updatedCatalog
    } catch {
      # 列表刷新异常时只做确定性收口：全部复原成功可确认回到基线；其余保留旧上下文，
      # 避免把仍在生效的项目凭空删除。
      if ($Mode -eq 'all' -and $failN -eq 0) {
        Set-TelemetryOptimizationContext -ItemIds @() -Scheme baseline -ItemsComplete $true
      }
    }
    try {
      $restoreItemIds = $(if ($Mode -eq 'selected_items') { @($itemIds) } else { @($catalog.ActiveItemIds) })
      $operation = New-OptimizationTelemetryOperation -Event restore -Source restore_manager -Reply $r -ItemIds $restoreItemIds -RestoreMode $Mode
      Send-AnonymousTelemetry 'restore' $script:HardwareInfo $r.RestoredOps $failN $operation
    } catch {}
    $bakName = $(if ($r.File) { Split-Path -Leaf $r.File } else { '' })
    if ($Mode -eq 'selected_items') {
      $ui.ProgText.Text = "按项目复原完成：$($r.RestoredItems) 项成功 / $failN 项失败"
      $ui.ProgCount.Text = "$($r.RestoredOps) 个底层设置已写回"
      foreach ($itemResult in @($r.ItemResults)) {
        Write-Log "$(if ($itemResult.Ok) { '[复原成功]' } else { '[复原失败]' }) $($itemResult.Name) — $($itemResult.Message)"
      }
    } else {
      $ui.ProgText.Text = "$(if ($failN -gt 0) { '全部复原未完成' } else { '全部复原完成' })：$($r.RestoredOps) 项已还原 / $failN 项失败$(if ($skipN -gt 0) { " / $skipN 项带提示" })"
      $ui.ProgCount.Text = "备份：$bakName"
      Write-Log "本次已还原 $($r.RestoredOps) 项改动（备份：$($r.File)）"
    }
    foreach ($f in $r.Failed) { Write-Log "[还原失败] $f" }
    foreach ($s in $r.Skipped) { Write-Log "[还原跳过] $s" }
    foreach ($n in $r.Notes) { Write-Log "[提示] $n" }
    Update-ItemList
    Hide-InlineRestorePanel

    if ($Mode -eq 'selected_items') {
      $sum = "$($r.RestoredItems) 个项目、$($r.RestoredOps) 个底层设置已恢复到第一次被工具修改前。" +
             $(if ($failN -gt 0) { "`n`n$failN 个项目未复原；发生冲突或执行失败的项目保持原状，明细见运行日志。" } else { "`n`n其他未选项目保持不变。" })
    } else {
      $sum = "已按$(if ($r.MergedCount -gt 1) { "合并的 $($r.MergedCount) 份备份" } else { "备份「$bakName」" })还原 $($r.RestoredOps) 项改动。" +
             $(if ($skipN -gt 0) { "`n`n另有 $skipN 项未按原状写回或使用了安全回退，具体原因见运行日志。" }) +
             $(if ($failN -gt 0) { "`n`n有 $failN 项还原失败，对应改动仍留在系统中（备份已保留，可排查后重试还原），明细见运行日志。" }
               elseif ($skipN -gt 0) { "`n`n其余全部还原成功，各项已回到优化前的状态。" }
               else { "`n`n全部还原成功，各项已回到优化前的状态。" })
    }
    $restoreDialogTitle = $(if ($failN -gt 0) { '还原未完成' } else { '还原完成' })
    $restoreDialogCode = $(if ($failN -gt 0) { 'RESTORE INCOMPLETE' } else { 'RESTORE DONE' })
    Show-ConfirmDialog $restoreDialogTitle $restoreDialogCode $sum '知道了' -InfoOnly | Out-Null
    if (@($r.RebootItems).Count -gt 0 -and (Show-RebootDialog @($r.RebootItems))) {
      Start-ConfirmedSystemReboot
    }
  } catch {
    $err = $_.Exception.Message
    Write-Log "还原失败：$err"
    Show-ConfirmDialog '还原未完成' 'RESTORE NOT COMPLETED' $err '知道了' -InfoOnly | Out-Null
  } finally {
    if ($busySet -or $script:Busy) { Set-BusyState $false }
    Update-InlineRestoreSelection
  }
}

# 重启调用单独包一层：验证脚本可整体替换成 mock 走完整个交互链路，
# 保证任何测试都不会真的把机器重启掉
function Invoke-SystemReboot {
  $shutdownExe = Join-Path ([Environment]::SystemDirectory) 'shutdown.exe'
  if (-not (Test-Path -LiteralPath $shutdownExe -PathType Leaf)) { throw '系统重启程序不存在' }
  # 直接等待 shutdown.exe 返回并检查退出码。旧实现只负责启动子进程，命令被系统拒绝时
  # 界面仍会当作成功，用户看到的就是“点了立即重启但没有反应”。
  $output = @(& $shutdownExe /r /t 10 2>&1)
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    $detail = (($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) -join ' ').Trim()
    if ($detail.Length -gt 400) { $detail = $detail.Substring(0, 400) }
    throw "系统未接受重启请求（退出码 $exitCode$(if ($detail) { "：$detail" })）"
  }
  $true
}

function Start-ConfirmedSystemReboot {
  try {
    Write-Log '已确认立即重启，系统将在 10 秒内重启…'
    Invoke-SystemReboot | Out-Null
  } catch {
    $message = $_.Exception.Message
    Write-Log "[重启未启动] $message"
    Show-ConfirmDialog '重启未启动' 'REBOOT NOT STARTED' `
      "$message`n`n请先保存工作，再通过 Windows 开始菜单 → 电源 → 重启。刚才的优化或还原结果已经保存，不需要重复执行。" `
      '知道了' -InfoOnly | Out-Null
  }
}

# 执行完成后的醒目重启提醒：此前只在日志末尾一行小字，用户根本注意不到（实机反馈）。
# 只在「本次成功项里确实有需重启的」才弹；纯检测/即时生效项不触发。
# 对话框已经明确说明立即重启及未保存工作风险；返回 true 后直接执行，避免第二个模态窗
# 被前一个窗口遮住，让用户误以为按钮没有反应。
function Show-RebootDialog([string[]]$ItemNames) {
  $rxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="460" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,16">
    <Border x:Name="DlgTitle" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="{DynamicResource Gold}" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="重启提醒" Foreground="{DynamicResource GoldDark}" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="REBOOT REQUIRED" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <StackPanel Orientation="Horizontal" Margin="16,14,16,4">
      <!-- 电源符号图标：圆环开口 + 竖杠，全部固定尺寸拼装，不用归一化 Path（教训 #3） -->
      <Grid Width="34" Height="34" VerticalAlignment="Center">
        <Ellipse Stroke="{DynamicResource Green}" StrokeThickness="2.5" Margin="3,6,3,2"/>
        <Border Width="8" Height="14" Background="{DynamicResource InputSurface}" VerticalAlignment="Top" HorizontalAlignment="Center"/>
        <Border Width="3" Height="15" Background="{DynamicResource Green}" VerticalAlignment="Top" HorizontalAlignment="Center" Margin="0,1,0,0"/>
      </Grid>
      <StackPanel Margin="13,0,0,0" VerticalAlignment="Center">
        <TextBlock Text="需要重启电脑" Foreground="{DynamicResource TextPri}" FontSize="16" FontWeight="Bold"/>
        <TextBlock Text="以下项目已写入成功，但要等重启后才完全生效：" Foreground="{DynamicResource TextSec}"
                   FontSize="11" Margin="0,3,0,0"/>
      </StackPanel>
    </StackPanel>
    <Border Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="16,8,16,12">
      <ScrollViewer MaxHeight="180" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="ItemsTxt" Text="" Foreground="{DynamicResource TextSec}" FontSize="12" LineHeight="20"
                   TextWrapping="Wrap" Padding="12,8"/>
      </ScrollViewer>
    </Border>
    <TextBlock Text="请先保存正在进行的工作；点击立即重启后，系统将在 10 秒内重启。"
               Foreground="{DynamicResource Gold}" FontSize="11" TextWrapping="Wrap" Margin="16,0,16,10"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="16,0,16,0">
      <Button x:Name="RebootBtn" MinWidth="110" Height="32" Foreground="{DynamicResource GreenDark}" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="保存好了，立即重启"/>
      </Button>
      <Button x:Name="LaterBtn" MinWidth="110" Height="32" IsCancel="True" Foreground="{DynamicResource Green}" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="稍后自己重启"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  # 事件处理器在模态期间回调，与其他对话框同理：要用的对象放 script 作用域最稳
  $script:RbDlg = [Windows.Markup.XamlReader]::Parse($rxaml)
  $script:RbDlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $script:RbDlg.Owner = $window
  $script:RbDlg.FindName('ItemsTxt').Text = (@($ItemNames | ForEach-Object { "· $_" }) -join "`n")
  $script:RbDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:RbDlg.DragMove() })
  $script:RbDlg.FindName('RebootBtn').Add_Click({ $script:RbDlg.DialogResult = $true })
  $script:RbDlg.FindName('LaterBtn').Add_Click({ $script:RbDlg.DialogResult = $false })
  [bool]$script:RbDlg.ShowDialog()
}

# 贴合主题的输入对话框：项目禁用原生 InputBox 风格弹窗
function Show-NameDialog {
  $dxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="380" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="{DynamicResource Gold}" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="存为方案" Foreground="{DynamicResource GoldDark}" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="SAVE PRESET" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <TextBlock Text="把当前勾选的优化项保存为方案，输入方案名：" Foreground="{DynamicResource TextSec}" Margin="14,12,14,8"/>
    <Border Background="{DynamicResource ComboSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1" Margin="14,0,14,12">
      <TextBox x:Name="NameBox" BorderThickness="0" Background="Transparent" Foreground="{DynamicResource TextPri}"
               CaretBrush="{DynamicResource Green}" Padding="9,6" FontSize="12" MaxLength="40"/>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" Width="96" Height="30" IsDefault="True" Foreground="{DynamicResource GreenDark}"
              FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="确定"/>
      </Button>
      <Button x:Name="CancelBtn" Width="80" Height="30" IsCancel="True" Foreground="{DynamicResource Green}" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="取消"/>
      </Button>
    </StackPanel>
  </StackPanel>
</Window>
'@
  $dlg = [Windows.Markup.XamlReader]::Parse($dxaml)
  $dlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $dlg.Owner = $window
  $nameBox = $dlg.FindName('NameBox')
  $dlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $dlg.DragMove() })
  $dlg.FindName('OkBtn').Add_Click({ $dlg.DialogResult = $true })
  $dlg.FindName('CancelBtn').Add_Click({ $dlg.DialogResult = $false })
  $dlg.Add_ContentRendered({ $nameBox.Focus() | Out-Null })
  if ($dlg.ShowDialog()) {
    $txt = "$($nameBox.Text)".Trim()
    if ($txt) { return $txt }
  }
  $null
}

# 安装器日志：静默安装出问题时这是唯一的现场（主程序此刻已经退了）
$script:SetupLogPath = Join-Path $script:UserConfigDir 'update-setup.log'

# 真正启动安装器的唯一出口：验证时整体替换成桩，绝不真的覆盖自身。
# /waitpid、/waitpid2 与 /waitpid3 让安装器显式等待 EngineHost、lifetime launcher
# 和 GUI 三个进程退出后再切换版本；即使宿主异常先退，也不会遗漏仍锁目录的 GUI。
# SHA256 与大小同时传入，安装器在提权后重新从文件句柄校验，封闭下载后的替换窗口。
function Invoke-BoosterSetupRun([string]$SetupFile, [string]$TargetDir, [string]$LogFile,
                                [string]$Sha256, [long]$Size) {
  # Do not pass the product root as the setup process CWD: a process cannot rename its own CWD.
  # The installer also resets this itself so updates launched by older GUIs receive the same fix.
  $approvalIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $approvalSid = $(if ($approvalIdentity.User) { $approvalIdentity.User.Value } else { '' })
  # OTS（标准用户输入另一管理员凭据）时，提权安装器经 explorer 自启仍可能落到批准账户。
  # 此时明确不传 /runafter；更新照常完成，由原登录用户从现有快捷方式手动打开新版。
  $script:UpdateRunAfterAllowed = $approvalSid -ieq $script:OriginalUserSid
  $setupArgs = [Collections.Generic.List[string]]::new()
  foreach ($arg in @(
    '/silent', "/dir=`"$TargetDir`"", "/waitpid=$script:EngineHostPid", "/waitpid2=$script:LauncherPid", "/waitpid3=$PID",
    "/log=`"$LogFile`"", "/sha256=$Sha256", "/size=$Size")) { $setupArgs.Add($arg) }
  if ($script:UpdateRunAfterAllowed) { $setupArgs.Add('/runafter') }
  Start-Process -FilePath $SetupFile -WorkingDirectory ([Environment]::SystemDirectory) -PassThru -ArgumentList $setupArgs.ToArray()
}

# 安装阶段的不确定进度：安装在另一个进程里跑，拿不到百分比，只能转圈
function Start-UpdInstallSpinner {
  $script:UpdUi.InstPanel.Visibility = 'Visible'
  $anim = New-Object Windows.Media.Animation.DoubleAnimation 0, 360, ([TimeSpan]::FromSeconds(1.1))
  $anim.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
  $script:UpdUi.SpinRot.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $anim)
  # 安装期间不许再点任何东西，也不许关窗——关了也停不下已经起来的安装器，只会让人困惑
  foreach ($n in 'SkipChk','UpdBtn','GoBtn','LaterBtn','CancelDlBtn') { $script:UpdUi[$n].Visibility = 'Collapsed' }
  $script:UpdInstalling = $true
  Set-BusyState $true
}

function Stop-UpdInstallSpinner {
  $script:UpdInstalling = $false
  $script:UpdUi.SpinRot.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $null)
  $script:UpdUi.InstPanel.Visibility = 'Collapsed'
  Set-BusyState $false
}

# 更新对话框的按钮态复位：取消下载 / 下载失败后回到可再次操作的状态。
# 「立即更新」只在清单过了安检（CanInline）时出现，降级入口「前往下载」永远可用。
function Reset-UpdDialogButtons {
  $script:UpdUi.DlPanel.Visibility = 'Collapsed'
  $script:UpdUi.CancelDlBtn.Visibility = 'Collapsed'
  $script:UpdUi.SkipChk.Visibility = $(if ($script:UpdDlgInfo.Mandatory) { 'Collapsed' } else { 'Visible' })
  $script:UpdUi.UpdBtn.Visibility = $(if ($script:UpdDlgInfo.CanInline) { 'Visible' } else { 'Collapsed' })
  $script:UpdUi.GoBtn.Visibility = 'Visible'
  $script:UpdUi.LaterBtn.Visibility = $(if ($script:UpdDlgInfo.Mandatory) { 'Collapsed' } else { 'Visible' })
}

# 更新提醒对话框：v0.11 起支持内置更新——「立即更新」在应用内下载安装包（进度条 +
# 可取消），完成后强制 SHA256/大小校验，通过才提示关闭本程序并启动安装器；
# 下载源限白名单 https（见 scripts\updater.ps1），清单缺校验信息或任一环节失败都
# 退回「浏览器打开下载页」的旧行为。下载/安装永远由用户点击触发，检查只负责提醒。
function Show-UpdateDialog($UpdInfo) {
  if (Test-TuningExperimentActive) {
    Write-Log '自动调优实验活动期间不安装更新；可稍后继续实验，或先「停止并回滚」。'
    return $false
  }
  $uxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="470" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="{DynamicResource Gold}" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="发现新版本" Foreground="{DynamicResource GoldDark}" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="UPDATE AVAILABLE" FontFamily="Consolas" FontSize="9" Foreground="{DynamicResource TextMut}"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <StackPanel Orientation="Horizontal" Margin="14,12,14,4">
      <TextBlock x:Name="VerText" Text="" Foreground="{DynamicResource Green}" FontSize="15" FontWeight="Bold"/>
      <TextBlock x:Name="CurText" Text="" Foreground="{DynamicResource TextMut}" FontSize="11" Margin="9,0,0,0"
                 VerticalAlignment="Bottom"/>
    </StackPanel>
    <Border Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}" BorderThickness="1" Margin="14,6,14,8">
      <ScrollViewer MaxHeight="140" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="NotesText" Text="" Foreground="{DynamicResource TextSec}" FontSize="11"
                   TextWrapping="Wrap" Padding="10,8"/>
      </ScrollViewer>
    </Border>
    <!-- 内置更新说明：走安装器覆盖升级，覆盖安装保护会保住配置与备份 -->
    <TextBlock x:Name="InlineNote" Text="" Foreground="{DynamicResource TextMut}" FontSize="10"
               TextWrapping="Wrap" Margin="14,0,14,8"/>
    <!-- 下载进度区：点「立即更新」后展开；进度由轮询定时器在 UI 线程刷新 -->
    <StackPanel x:Name="DlPanel" Visibility="Collapsed" Margin="14,0,14,10">
      <Grid>
        <TextBlock x:Name="DlPhaseText" Text="正在下载更新…" Foreground="{DynamicResource TextSec}" FontSize="11"/>
        <TextBlock x:Name="DlSizeText" Text="" Foreground="{DynamicResource TextMut}" FontFamily="Consolas"
                   FontSize="10" HorizontalAlignment="Right" VerticalAlignment="Center"/>
      </Grid>
      <Border x:Name="DlTrack" Height="8" Background="{DynamicResource LogBg}" BorderBrush="{DynamicResource Line}"
              BorderThickness="1" Margin="0,6,0,0">
        <Border x:Name="DlFill" Background="{DynamicResource Green}" HorizontalAlignment="Left" Width="0"/>
      </Border>
    </StackPanel>
    <!-- 安装阶段：进度不可知（安装器在另一个进程里跑），只给转圈 + 一句话 -->
    <StackPanel x:Name="InstPanel" Visibility="Collapsed" Orientation="Horizontal" Margin="14,2,14,12">
      <Grid Width="20" Height="20" RenderTransformOrigin="0.5,0.5" VerticalAlignment="Center">
        <Grid.RenderTransform>
          <RotateTransform x:Name="SpinRot" Angle="0"/>
        </Grid.RenderTransform>
        <Ellipse Stroke="{DynamicResource Line}" StrokeThickness="2.5" Width="18" Height="18"/>
        <Path Stroke="{DynamicResource Green}" StrokeThickness="2.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
              Data="M 10,1 A 9,9 0 0 1 19,10"/>
      </Grid>
      <TextBlock x:Name="InstText" Text="正在安装，请稍候…" Foreground="{DynamicResource Green}" FontSize="12"
                 VerticalAlignment="Center" Margin="11,0,0,0"/>
    </StackPanel>
    <!-- 失败区：下载/校验失败的明确报错，旁边的「前往下载」变身降级入口 -->
    <Border x:Name="ErrPanel" Visibility="Collapsed" Background="{DynamicResource DangerPanel}" BorderBrush="#FF7A3034"
            BorderThickness="1" Margin="14,0,14,10">
      <TextBlock x:Name="ErrText" Text="" Foreground="{DynamicResource Danger}" FontSize="11"
                 TextWrapping="Wrap" Padding="10,7"/>
    </Border>
    <Grid Margin="14,0,14,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <CheckBox x:Name="SkipChk" Grid.Column="0" VerticalAlignment="Center">
        <CheckBox.Template>
          <ControlTemplate TargetType="CheckBox">
            <Border Background="Transparent" Padding="0,3">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="Box" Width="13" Height="13" BorderBrush="{DynamicResource LineHi}"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Center">
                  <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="{DynamicResource GreenDark}"
                        StrokeThickness="2" Visibility="Collapsed"/>
                </Border>
                <TextBlock Text="不再提醒此版本" Foreground="{DynamicResource TextMut}" FontSize="11"
                           Margin="7,0,0,0" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="{DynamicResource Green}"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Green}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </CheckBox.Template>
      </CheckBox>
      <Button x:Name="UpdBtn" Grid.Column="1" MinWidth="96" Height="30" Foreground="{DynamicResource GreenDark}" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"
                    Data="M 0.06,0 L 1,0 L 1,0.78 L 0.94,1 L 0,1 L 0,0.22 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="立即更新"/>
      </Button>
      <Button x:Name="GoBtn" Grid.Column="2" MinWidth="96" Height="30" Foreground="{DynamicResource Green}" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="GoTxt" Text="前往下载"/>
      </Button>
      <Button x:Name="CancelDlBtn" Grid.Column="3" Visibility="Collapsed" MinWidth="96" Height="30"
              Foreground="{DynamicResource Green}" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="{DynamicResource TextMut}"/>
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Line}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="CancelDlTxt" Text="取消下载"/>
      </Button>
      <Button x:Name="LaterBtn" Grid.Column="4" Width="86" Height="30" IsCancel="True"
              Foreground="{DynamicResource Green}" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="{DynamicResource GreenLine}" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Green}"/>
                <Setter TargetName="B" Property="Background" Value="{DynamicResource AccentPanel}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock Text="稍后再说"/>
      </Button>
    </Grid>
  </StackPanel>
</Window>
'@
  # 上一次对话框可能留有未收尾的下载：先请求取消并回收，避免两套轮询同时操作控件
  if ($script:DlPollTimer) { $script:DlPollTimer.Stop() }
  if ($script:DlState -and -not $script:DlState.Done) { $script:DlState.Cancel = $true }
  if ($script:DlJob) { try { $script:DlJob.Dispose() } catch {}; $script:DlJob = $null }
  $script:DlState = $null

  # 事件处理器在模态期间回调，跟 Show-NameDialog 一样把要用的对象放 script 作用域最稳
  $script:UpdDlg = [Windows.Markup.XamlReader]::Parse($uxaml)
  $script:UpdDlg.Resources.MergedDictionaries.Add($script:ThemeRes)
  $script:UpdDlgInfo = $UpdInfo
  $script:AllowMandatoryDialogClose = $false
  $script:UpdDlg.Owner = $window
  $script:UpdUi = @{}
  foreach ($n in 'DlgTitle','VerText','CurText','NotesText','InlineNote','DlPanel','DlPhaseText','DlSizeText',
                 'DlTrack','DlFill','InstPanel','InstText','SpinRot','ErrPanel','ErrText','SkipChk','UpdBtn','GoBtn','GoTxt',
                 'CancelDlBtn','CancelDlTxt','LaterBtn') {
    $script:UpdUi[$n] = $script:UpdDlg.FindName($n)
  }
  $script:UpdUi.VerText.Text = "新版本 v$($UpdInfo.DisplayVersion)"
  $script:UpdUi.CurText.Text = "当前 v$script:DisplayVersion"
  # 清单由发布脚本写成单行 JSON 时常用字面量 \n 表示换行；显示前统一还原，避免更新
  # 说明里直接露出“\n”字符。
  $notes = ("$($UpdInfo.Notes)" -replace '\\n', "`n").Trim()
  $script:UpdUi.NotesText.Text = $(if ($notes) { $notes } else { '（本次更新没有附带说明）' })
  if ($UpdInfo.Mandatory) {
    $script:UpdUi.SkipChk.Visibility = 'Collapsed'
    $script:UpdUi.LaterBtn.Visibility = 'Collapsed'
    $script:UpdUi.CurText.Text += " · 此版本已停止支持，需升级后继续使用"
  }
  if ($UpdInfo.CanInline) {
    $script:UpdUi.InlineNote.Visibility = 'Collapsed'
  } else {
    # 清单缺 sha256/size 或 setupUrl 过不了白名单安检：内置更新不可用，退回旧行为并留痕
    $script:UpdUi.UpdBtn.Visibility = 'Collapsed'
    $script:UpdUi.InlineNote.Text = '本次更新将打开浏览器前往下载页。'
    if ("$($UpdInfo.InlineDeny)") { Write-Log "内置更新不可用（$($UpdInfo.InlineDeny)），已退回浏览器下载。" }
  }
  $script:UpdDlg.FindName('DlgTitle').Add_MouseLeftButtonDown({ $script:UpdDlg.DragMove() })

  # 下载进度轮询：后台 runspace 只写 Synchronized 哈希表，UI 一律在这里（Dispatcher 线程）刷新。
  # 对话框中途被关也让它继续跑到 Done 再回收 runspace——取消清理必须有人等到底。
  $script:DlPollTimer = New-Object Windows.Threading.DispatcherTimer
  $script:DlPollTimer.Interval = [TimeSpan]::FromMilliseconds(250)
  $script:DlPollTimer.Add_Tick({
    $st = $script:DlState
    if (-not $st) { $script:DlPollTimer.Stop(); return }
    if ($script:UpdDlg.IsVisible -and $st.Phase -in @('queued','downloading')) {
      if ($st.Phase -eq 'queued') {
        $script:UpdUi.DlPhaseText.Text = $(if ($st.Cancel) { '正在取消排队…' } elseif ("$($st.Status)") { "$($st.Status)" } else { '正在进入服务器下载队列…' })
        $script:UpdUi.DlSizeText.Text = $(if ([int]$st.QueuePosition -gt 0) {
          $seconds = [Math]::Max(0, [int]$st.QueueEstimatedWaitSeconds)
          $estimate = $(if ($seconds -ge 60) {
            "预计约 {0} 分钟" -f ([Math]::Ceiling($seconds / 60.0))
          } elseif ($seconds -gt 0) { "预计约 {0} 秒" -f $seconds } else { '正在估算' })
          "前方 {0} 位 · {1}" -f ([int]$st.QueueAhead), $estimate
        } else { '正在获取排队位置' })
        if (-not $st.Cancel) { $script:UpdUi.CancelDlTxt.Text = '取消排队' }
        $script:UpdUi.DlFill.Width = 0
      } else {
        $recv = [long]$st.Received; $totalB = [long]$st.Total
        $pct = $(if ($totalB -gt 0) { [Math]::Min(100, [Math]::Floor($recv * 100.0 / $totalB)) } else { 0 })
        $script:UpdUi.DlPhaseText.Text = $(if ($st.Cancel) { '正在取消下载…' } elseif ("$($st.Status)") { "$($st.Status)" } else { '正在下载更新…' })
        if (-not $st.Cancel) { $script:UpdUi.CancelDlTxt.Text = '取消下载' }
        $script:UpdUi.DlSizeText.Text = "{0:N1} MB / {1:N1} MB · {2}%" -f ($recv / 1MB), ($totalB / 1MB), $pct
        $trackW = $script:UpdUi.DlTrack.ActualWidth - 2
        if ($trackW -gt 0) { $script:UpdUi.DlFill.Width = $trackW * $pct / 100 }
      }
    }
    if (-not $st.Done) { return }
    $script:DlPollTimer.Stop()
    try { if ($script:DlJob) { $script:DlJob.EndInvoke($script:DlAsync); $script:DlJob.Dispose() } } catch {}
    $script:DlJob = $null
    if (-not $script:UpdDlg.IsVisible) { return }   # 对话框已关：上面已把后台资源回收完
    if ($st.Phase -eq 'done') {
      $script:UpdUi.DlPhaseText.Text = '下载完成，SHA256 校验通过'
      $script:UpdUi.DlSizeText.Text = "{0:N1} MB · 100%" -f ([long]$st.Total / 1MB)
      $trackW = $script:UpdUi.DlTrack.ActualWidth - 2
      if ($trackW -gt 0) { $script:UpdUi.DlFill.Width = $trackW }
      $script:UpdUi.CancelDlBtn.Visibility = 'Collapsed'
      Write-Log "更新包已下载并通过校验：$($st.File)"
      # 用户点「立即更新」时就已经授权了整条链路，这里不再要求他确认第二次：
      # 直接转圈 + 静默安装 + 自启新版（安装只在校验通过后发生，见 updater.ps1 的授权边界）
      Start-UpdInstallSpinner
      $script:UpdUi.DlPanel.Visibility = 'Collapsed'
      try {
        if (Test-TuningExperimentActive) { throw '自动调优实验已激活，更新安装已拦截' }
        # 安装器要覆盖本程序的文件，必须等本进程退出——把 /waitpid 交给它，
        # 我们启动完立刻自退，等待逻辑放在安装器侧（这边退出后就没人能干活了）
        $proc = Invoke-BoosterSetupRun $st.File $script:RootDir $script:SetupLogPath `
                  "$($script:UpdDlgInfo.Sha256)" ([long]$script:UpdDlgInfo.Size)
        if (-not $proc) { throw '安装程序未能启动' }
        if ($script:UpdateRunAfterAllowed) {
          Write-Log "安装程序已启动（PID $($proc.Id)），本程序即将退出，安装完成后新版本会自动打开。"
        } else {
          Write-Log "安装程序已启动（PID $($proc.Id)）。本次使用了另一管理员账户授权，安装完成后请由原登录用户手动打开新版。"
          [Windows.MessageBox]::Show(
            '更新安装已经开始。由于本次管理员授权使用了另一账户，为避免用错账户，安装完成后不会自动启动。请稍后从桌面或开始菜单手动打开新版。',
            '三角洲行动 · 画面优化助手', [Windows.MessageBoxButton]::OK,
            [Windows.MessageBoxImage]::Information) | Out-Null
        }
        # 交棒完成，放行关窗：拦截关窗的守卫是拦用户的，别把自己也拦在里面。
        # 这里用 Close() 而不是设 DialogResult——非模态时后者会抛，且返回值此刻已无意义
        $script:UpdInstalling = $false
        $script:AllowMandatoryDialogClose = $true
        $script:UpdDlg.Close()
        $window.Close()
        # Close 之后进程未必真退（实机反馈旧窗口残留、与安装后的新实例并存）：
        # WPF 宿主里还挂着更新检查的后台 runspace 和嵌套的模态/调度帧，powershell
        # 不会因为窗口关了就结束。安装器已经拉起，这里强制退出兜底
        Invoke-AppExit
      } catch {
        Stop-UpdInstallSpinner
        $script:UpdUi.ErrText.Text = "启动安装程序失败：$($_.Exception.Message)"
        $script:UpdUi.ErrPanel.Visibility = 'Visible'
        $script:UpdUi.GoTxt.Text = '改为打开下载页'
        Reset-UpdDialogButtons
        Write-Log "启动安装程序失败：$($_.Exception.Message)"
      }
    } elseif ($st.Phase -eq 'cancelled') {
      Reset-UpdDialogButtons
      Write-Log '已取消更新下载，临时文件已清理。'
    } else {
      # 失败要说人话并给降级出路：改为浏览器打开下载页（旧行为）
      Reset-UpdDialogButtons
      $script:UpdUi.ErrText.Text = "$($st.Error)"
      $script:UpdUi.ErrPanel.Visibility = 'Visible'
      $script:UpdUi.GoTxt.Text = '改为打开下载页'
      Write-Log "内置更新失败：$($st.Error)"
    }
  })

  $script:UpdUi.UpdBtn.Add_Click({
    if ($script:DlState -and -not $script:DlState.Done) { return }
    if (Test-TuningExperimentActive) { Write-Log '自动调优实验期间已拦截更新安装。'; return }
    $script:DlState = [hashtable]::Synchronized(@{
      Received = 0L; Total = [long]$script:UpdDlgInfo.Size; Phase = 'queued'
      Status = '正在进入服务器下载队列…'; RetryCount = 0
      QueuePosition = 0; QueueAhead = 0; QueueActive = 0; QueueCapacity = 0
      QueueEstimatedWaitSeconds = 0; QueueTicket = ''
      Error = ''; File = ''; Cancel = $false; Done = $false
    })
    foreach ($n in 'SkipChk','UpdBtn','GoBtn','LaterBtn') { $script:UpdUi[$n].Visibility = 'Collapsed' }
    $script:UpdUi.ErrPanel.Visibility = 'Collapsed'
    $script:UpdUi.DlPanel.Visibility = 'Visible'
    $script:UpdUi.DlPhaseText.Text = '正在进入服务器下载队列…'
    $script:UpdUi.DlSizeText.Text = ''
    $script:UpdUi.DlFill.Width = 0
    $script:UpdUi.CancelDlBtn.Visibility = 'Visible'
    $script:UpdUi.CancelDlBtn.IsEnabled = $true
    $script:UpdUi.CancelDlTxt.Text = '取消排队'
    Write-Log "开始下载更新包：$($script:UpdDlgInfo.SetupUrl)"
    # 下载放后台 runspace：白名单安检、SHA256/大小校验都在 Invoke-BoosterSetupDownload 里强制执行
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($ModulePath, $Url, $Sha, $Bytes, $State)
      try { . $ModulePath; Invoke-BoosterSetupDownload -SetupUrl $Url -Sha256 $Sha -Size $Bytes -State $State }
      catch { $State.Phase = 'failed'; $State.Error = "下载线程异常：$($_.Exception.Message)"; $State.Done = $true }
    })
    foreach ($arg in @($script:UpdaterPath, "$($script:UpdDlgInfo.SetupUrl)",
                       "$($script:UpdDlgInfo.Sha256)", [long]$script:UpdDlgInfo.Size, $script:DlState)) {
      [void]$ps.AddArgument($arg)
    }
    $script:DlJob = $ps
    $script:DlAsync = $ps.BeginInvoke()
    $script:DlPollTimer.Start()
  })
  $script:UpdUi.CancelDlBtn.Add_Click({
    if ($script:DlState -and -not $script:DlState.Done) {
      $wasQueued = ($script:DlState.Phase -eq 'queued')
      $script:DlState.Cancel = $true
      $script:UpdUi.CancelDlBtn.IsEnabled = $false
      $script:UpdUi.CancelDlTxt.Text = '正在取消…'
      $script:UpdUi.DlPhaseText.Text = $(if ($wasQueued) { '正在取消排队…' } else { '正在取消下载…' })
    }
  })
  $script:UpdUi.GoBtn.Add_Click({
    # 只允许 http/https：清单被篡改成本地路径/其他协议时拒绝打开，防止借更新入口执行文件
    $u = "$($script:UpdDlgInfo.Url)"
    if ($u -match '^https://') {
      try { Invoke-EngineHostUserAction -Action OpenUrl -Payload $u | Out-Null }
      catch { Write-Log "更新网页打开失败：$($_.Exception.Message)"; return }
      if ($script:UpdDlgInfo.Mandatory) {
        $script:AllowMandatoryDialogClose = $true
        $script:UpdDlg.DialogResult = $true
        $window.Close()
        return
      }
    } else { Write-Log '更新清单里的下载地址不是网页链接，已拦截。'; return }
    $script:UpdDlg.DialogResult = $true
  })
  $script:UpdUi.LaterBtn.Add_Click({ $script:UpdDlg.DialogResult = $false })
  # 安装已经起来了就不许关窗：关了也停不下安装器，只会让用户以为取消了
  $script:UpdDlg.Add_Closing({
    if ($script:UpdInstalling -or ($script:UpdDlgInfo.Mandatory -and -not $script:AllowMandatoryDialogClose)) { $_.Cancel = $true }
  })
  # 下载中途直接关掉对话框：请求后台取消，轮询定时器会等它清理完临时文件再回收
  $script:UpdDlg.Add_Closed({
    if ($script:DlState -and -not $script:DlState.Done) { $script:DlState.Cancel = $true }
  })
  $script:UpdDlg.ShowDialog() | Out-Null
  if (-not $UpdInfo.Mandatory -and $script:UpdUi.SkipChk.IsChecked -and (Get-Command Set-BoosterSkipVersion -ErrorAction SilentlyContinue)) {
    # 返回值必须吞掉：现在函数输出会被调用方接住，落盘结果混进去会把 $skipped 变成数组
    Set-BoosterSkipVersion $UpdInfo.Version | Out-Null
    Write-Log "已设置不再提醒 v$($UpdInfo.Version)。"
    # 返回「用户选择了跳过」：调用方据此把标题栏的更新入口一并收起，语义保持一致
    return $true
  }
  $false
}

# 自动检查发现新版时的统一弹窗出口。同一版本每次程序运行只自动弹一次；用户选了
# 「稍后再说」仍可点标题栏入口重看，勾「不再提醒」则后续启动也不再自动提示。
function Show-DetectedUpdateDialog {
  if (-not $script:UpdateInfo -or $script:Busy -or $script:UpdateDialogOpen -or (Test-TuningExperimentActive)) { return }
  $ver = "$($script:UpdateInfo.Version)"
  if (-not $ver -or "$script:UpdatePromptedVersion" -eq $ver) { return }
  $script:UpdatePromptedVersion = $ver
  $script:UpdateDialogOpen = $true
  try {
    if (Show-UpdateDialog $script:UpdateInfo) { $ui.UpdateBtn.Visibility = 'Collapsed' }
  } finally {
    $script:UpdateDialogOpen = $false
  }
}

# 表头分割线拖动结束后，把第一列新宽度同步到所有数据行（含 RiskyPanel）
function Sync-OptHeaderColumnWidth([double]$w) {
  foreach ($row in (@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children))) {
    if ($row.Child -is [Windows.Controls.Grid]) {
      $row.Child.ColumnDefinitions[0].Width = New-Object Windows.GridLength $w
    }
  }
}
if ($ui.OptHeaderSplitter) { $ui.OptHeaderSplitter.Add_DragCompleted({ Sync-OptHeaderColumnWidth $ui.OptHeaderGrid.ColumnDefinitions[0].ActualWidth }) }

function Update-ItemList {
  $ui.ItemPanel.Children.Clear()
  $ui.RiskyPanel.Children.Clear()
  # 变量名不能用 $items：引擎被点源进同一作用域，其 [string[]]$Items 参数会把哈希表强制转成字符串
  $optItems = @(Get-OptItems $script:TargetExe $script:SelectedGpuSpoofModel)
  if ($script:NetCafeCompatibilityMode) {
    # repair-only 会话没有可认证的 medium broker；不要把用户目录缓存项交给 high GUI。
    $optItems = @($optItems | Where-Object { $_.Kind -ne 'cache' })
  }
  $safe  = @($optItems | Where-Object { $_.Tier -ne 'risky' })
  $risky = @($optItems | Where-Object { $_.Tier -eq 'risky' })

  for ($i = 0; $i -lt $safe.Count; $i++) {
    $st = Get-ItemState $safe[$i]
    $ui.ItemPanel.Children.Add((New-ItemRow $safe[$i] $st ($i -eq $safe.Count - 1))) | Out-Null
  }
  for ($i = 0; $i -lt $risky.Count; $i++) {
    $st = Get-ItemState $risky[$i]
    $ui.RiskyPanel.Children.Add((New-ItemRow $risky[$i] $st ($i -eq $risky.Count - 1))) | Out-Null
  }
  $ui.RiskyGroup.Visibility = $(if ($risky.Count -gt 0) { 'Visible' } else { 'Collapsed' })
  Update-Count
}

# ---------- 官方通知（60 秒轮询 + 本地历史缓存） ----------

$script:NotificationUrl = 'https://df.ltz88.cn/report/notifications'
$script:NotificationStatePath = Join-Path $script:UserConfigDir 'notifications.json'
$script:NotificationCheckIntervalSeconds = 60
$script:NotificationItems = @()
$script:NotificationLastSeenId = [int64]0
$script:NotificationAnnouncedLatestId = [int64]0
$script:NotificationLastFetchOk = $false
$script:NotificationCheckBusy = $false
$script:NotificationShowAfterFetch = $false

# v0.23.0.8 的一次性重要提醒。状态跟随受保护的用户配置目录，因此同一台电脑
# 不同 Windows 用户会各自弹出一次；关闭对话框而未点击「我知道了」时不写入确认状态。
$script:PowerRecoveryNoticeId = 'v0.23.0.8-power-plan-recovery'
$script:PowerRecoveryNoticeStatePath = Join-Path $script:UserConfigDir 'version-notice-v0.23.0.8.json'
$script:PowerRecoveryNoticePromptedThisRun = $false

function ConvertTo-NotificationList($Value) {
  $result = [Collections.Generic.List[object]]::new()
  $seen = @{}
  foreach ($item in @($Value) | Select-Object -First 50) {
    if (-not $item) { continue }
    [int64]$id = 0
    [int64]$publishedAt = 0
    if (-not [int64]::TryParse("$($item.id)", [ref]$id) -or $id -le 0 -or $seen.ContainsKey($id)) { continue }
    if (-not [int64]::TryParse("$($item.publishedAt)", [ref]$publishedAt) -or $publishedAt -le 0) { continue }
    $title = "$($item.title)".Trim()
    $content = "$($item.content)".Trim()
    $level = "$($item.level)".Trim().ToLowerInvariant()
    if (-not $title -or $title.Length -gt 80 -or -not $content -or $content.Length -gt 10000) { continue }
    if ($level -notin 'info','important','warning') { continue }
    $active = $true
    if ($item.PSObject.Properties['active']) { $active = [bool]$item.active }
    $seen[$id] = $true
    [void]$result.Add([pscustomobject]@{
      id = $id; title = $title; content = $content; level = $level
      publishedAt = $publishedAt; active = $active
    })
  }
  @($result.ToArray() | Sort-Object @{Expression='publishedAt';Descending=$true}, @{Expression='id';Descending=$true})
}

function Get-NotificationLatestId {
  [int64]$latest = 0
  foreach ($item in @($script:NotificationItems)) {
    if ($item.active -and [int64]$item.id -gt $latest) { $latest = [int64]$item.id }
  }
  $latest
}

function Save-NotificationState {
  try {
    $state = [ordered]@{
      SchemaVersion = 1
      LastSeenId = [int64]$script:NotificationLastSeenId
      Notifications = @($script:NotificationItems)
    }
    if (Get-Command Write-DfbTelemetryConfigAtomic -ErrorAction SilentlyContinue) {
      Write-DfbTelemetryConfigAtomic $script:NotificationStatePath $state
    } else {
      [IO.File]::WriteAllText($script:NotificationStatePath, ($state | ConvertTo-Json -Depth 5),
        (New-Object Text.UTF8Encoding($true)))
    }
  } catch {}
}

function Update-NotificationBadge {
  $unread = @($script:NotificationItems | Where-Object { $_.active -and [int64]$_.id -gt $script:NotificationLastSeenId }).Count
  if ($unread -gt 0) {
    $ui.NoticeBadgeTxt.Text = $(if ($unread -gt 99) { '99+' } else { "$unread" })
    $ui.NoticeBadge.Visibility = 'Visible'
    $ui.NoticeText.Text = '新通知'
    $ui.NoticeText.Foreground = New-Brush $script:C.Gold
    $ui.NoticeBtn.ToolTip = "有 $unread 条新通知，点击查看全部消息"
  } else {
    $ui.NoticeBadge.Visibility = 'Collapsed'
    $ui.NoticeBadgeTxt.Text = ''
    $ui.NoticeText.Text = '通知'
    $ui.NoticeText.Foreground = New-Brush $script:C.TextSec
    $ui.NoticeBtn.ToolTip = '查看通知与历史消息'
  }
}

function Initialize-NotificationState {
  try {
    if (Test-Path -LiteralPath $script:NotificationStatePath -PathType Leaf) {
      $state = Get-Content -LiteralPath $script:NotificationStatePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
      [int64]$lastSeen = 0
      if ([int64]::TryParse("$($state.LastSeenId)", [ref]$lastSeen) -and $lastSeen -ge 0) {
        $script:NotificationLastSeenId = $lastSeen
      }
      $script:NotificationItems = @(ConvertTo-NotificationList $state.Notifications)
    }
  } catch {
    $script:NotificationItems = @()
    $script:NotificationLastSeenId = [int64]0
  }
  $script:NotificationAnnouncedLatestId = $script:NotificationLastSeenId
  Update-NotificationBadge
}

function Set-NotificationPayload($Payload) {
  if (-not $Payload -or -not $Payload.PSObject.Properties['notifications']) { throw '通知响应格式无效' }
  $items = @(ConvertTo-NotificationList $Payload.notifications)
  $script:NotificationItems = $items
  $script:NotificationLastFetchOk = $true
  $latest = Get-NotificationLatestId
  if ($latest -gt $script:NotificationAnnouncedLatestId -and $latest -gt $script:NotificationLastSeenId) {
    $newCount = @($items | Where-Object { $_.active -and [int64]$_.id -gt $script:NotificationLastSeenId }).Count
    if ($newCount -gt 0) { Write-Log "收到 $newCount 条新通知，已在窗口右上角提示。" }
    $script:NotificationAnnouncedLatestId = $latest
  }
  Update-NotificationBadge
  Save-NotificationState
}

function Get-NotificationDisplayTime([int64]$UnixTime) {
  try { [DateTimeOffset]::FromUnixTimeSeconds($UnixTime).ToLocalTime().ToString('yyyy-MM-dd HH:mm') }
  catch { '' }
}

function ConvertTo-NotificationTextSegments([string]$Content) {
  $segments = [Collections.Generic.List[object]]::new()
  if ([string]::IsNullOrEmpty($Content)) { return @() }
  $cursor = 0
  $trimChars = [char[]]@('.', ',', ';', ':', '!', '?', ')', ']', '}', '>', '"', "'",
    '，', '。', '！', '？', '；', '：', '）', '》', '】')
  foreach ($match in [regex]::Matches($Content, '(?i)https?://[^\s<>"'']+')) {
    $urlText = $match.Value.TrimEnd($trimChars)
    if (-not $urlText) { continue }
    $uri = $null
    if (-not [Uri]::TryCreate($urlText, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin 'https','http') { continue }
    if ($match.Index -gt $cursor) {
      [void]$segments.Add([pscustomobject]@{ Text = $Content.Substring($cursor, $match.Index - $cursor); Url = '' })
    }
    [void]$segments.Add([pscustomobject]@{ Text = $urlText; Url = $uri.AbsoluteUri })
    # 末尾的中文句号、右括号等不属于链接，留给下一段普通文字。
    $cursor = $match.Index + $urlText.Length
  }
  if ($cursor -lt $Content.Length) {
    [void]$segments.Add([pscustomobject]@{ Text = $Content.Substring($cursor); Url = '' })
  }
  @($segments.ToArray())
}

function New-NotificationBodyTextBlock([string]$Content) {
  $body = New-Object Windows.Controls.TextBlock
  $body.Foreground = New-Brush $script:C.TextSec
  $body.FontSize = 12
  $body.LineHeight = 20
  $body.TextWrapping = 'Wrap'
  $body.Margin = '0,7,0,0'
  foreach ($segment in @(ConvertTo-NotificationTextSegments $Content)) {
    if (-not $segment.Url) {
      [void]$body.Inlines.Add((New-Object Windows.Documents.Run "$($segment.Text)"))
      continue
    }
    $link = New-Object Windows.Documents.Hyperlink
    $link.NavigateUri = New-Object Uri "$($segment.Url)"
    $link.Foreground = New-Brush $script:C.Green
    $link.TextDecorations = [Windows.TextDecorations]::Underline
    $link.Cursor = 'Hand'
    $link.ToolTip = '点击在默认浏览器中打开'
    [void]$link.Inlines.Add((New-Object Windows.Documents.Run "$($segment.Text)"))
    $link.Add_RequestNavigate({
      param($sender, $eventArgs)
      try {
        $target = $eventArgs.Uri
        if ($target -and $target.IsAbsoluteUri -and $target.Scheme -in 'https','http') {
          Start-Process -FilePath $target.AbsoluteUri
        }
      } catch {}
      $eventArgs.Handled = $true
    })
    [void]$body.Inlines.Add($link)
  }
  $body
}

function Show-NotificationHistory {
  $unreadBefore = [int64]$script:NotificationLastSeenId
  $latest = Get-NotificationLatestId
  if ($latest -gt $script:NotificationLastSeenId) { $script:NotificationLastSeenId = $latest }
  Update-NotificationBadge
  Save-NotificationState

  $nxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="520" Height="610" MinHeight="420" WindowStyle="None" ResizeMode="CanResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="{DynamicResource InputSurface}" BorderBrush="{DynamicResource LineHi}" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <Grid>
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Border x:Name="DragBar" Grid.Row="0" Background="{DynamicResource TopBar}" BorderBrush="{DynamicResource Line}" BorderThickness="0,0,0,1" Padding="14,10">
      <DockPanel><TextBlock Text="通知中心" Foreground="{DynamicResource TextPri}" FontSize="14" FontWeight="Bold"/><TextBlock Text="  NOTIFICATIONS" Foreground="{DynamicResource Green}" FontFamily="Consolas" FontSize="10" VerticalAlignment="Center"/></DockPanel>
    </Border>
    <StackPanel Grid.Row="1" Margin="16,14,16,8">
      <TextBlock Text="官方通知与历史消息" Foreground="{DynamicResource Green}" FontSize="16" FontWeight="Bold"/>
      <TextBlock x:Name="StatusText" Foreground="{DynamicResource TextSec}" Margin="0,5,0,0" TextWrapping="Wrap"/>
    </StackPanel>
    <ScrollViewer Grid.Row="2" Margin="12,0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <StackPanel x:Name="ItemsPanel" Margin="4,2,4,8"/>
    </ScrollViewer>
    <Border Grid.Row="3" BorderBrush="{DynamicResource Line}" BorderThickness="0,1,0,0" Padding="14,11">
      <Button x:Name="CloseButton" Content="关闭" Width="92" Height="30" HorizontalAlignment="Right" Background="{DynamicResource Green}" Foreground="{DynamicResource GreenDark}" BorderThickness="0" FontWeight="Bold" Cursor="Hand"/>
    </Border>
  </Grid>
</Window>
'@
  $dialog = [Windows.Markup.XamlReader]::Parse($nxaml)
  $dialog.Resources.MergedDictionaries.Add($script:ThemeRes)
  $dialog.Owner = $window
  $panel = $dialog.FindName('ItemsPanel')
  $count = @($script:NotificationItems).Count
  $status = $(if ($script:NotificationLastFetchOk) { "共 $count 条消息 · 已与服务器同步" } else { "共 $count 条消息 · 当前显示本机缓存" })
  $dialog.FindName('StatusText').Text = $status

  if ($count -eq 0) {
    $empty = New-Object Windows.Controls.TextBlock
    $empty.Text = '暂时没有通知。'
    $empty.Foreground = New-Brush $script:C.TextSec
    $empty.FontSize = 14
    $empty.HorizontalAlignment = 'Center'
    $empty.Margin = '0,70,0,0'
    [void]$panel.Children.Add($empty)
  } else {
    foreach ($notice in @($script:NotificationItems)) {
      $isUnread = [int64]$notice.id -gt $unreadBefore
      $accent = switch ($notice.level) { 'warning' { $script:C.Danger } 'important' { $script:C.Gold } default { $script:C.Green } }
      $levelText = switch ($notice.level) { 'warning' { '重要提醒' } 'important' { '重点通知' } default { '官方通知' } }
      $card = New-Object Windows.Controls.Border
      $card.Background = New-Brush $script:C.Panel
      $card.BorderBrush = New-Brush $accent
      $card.BorderThickness = '2,0,0,0'
      $card.Padding = '14,12'
      $card.Margin = '0,0,0,10'
      $stack = New-Object Windows.Controls.StackPanel
      $meta = New-Object Windows.Controls.StackPanel
      $meta.Orientation = 'Horizontal'
      $chip = New-Text $levelText $accent 10 -Mono
      [void]$meta.Children.Add($chip)
      if ($isUnread) {
        $new = New-Text '  NEW' $script:C.Danger 10 -Mono
        $new.FontWeight = 'Bold'
        [void]$meta.Children.Add($new)
      }
      $time = New-Text ("  " + (Get-NotificationDisplayTime ([int64]$notice.publishedAt))) $script:C.TextMut 10 -Mono
      [void]$meta.Children.Add($time)
      [void]$stack.Children.Add($meta)
      $title = New-Object Windows.Controls.TextBlock
      $title.Text = "$($notice.title)"
      $title.Foreground = New-Brush $script:C.TextPri
      $title.FontSize = 14
      $title.FontWeight = 'Bold'
      $title.TextWrapping = 'Wrap'
      $title.Margin = '0,7,0,0'
      [void]$stack.Children.Add($title)
      $body = New-NotificationBodyTextBlock "$($notice.content)"
      [void]$stack.Children.Add($body)
      $card.Child = $stack
      [void]$panel.Children.Add($card)
    }
  }
  $dialog.FindName('DragBar').Add_MouseLeftButtonDown({ $dialog.DragMove() })
  $dialog.FindName('CloseButton').Add_Click({ $dialog.Close() })
  [void]$dialog.ShowDialog()
}

function Start-NotificationCheck([switch]$ShowHistory) {
  if ($ShowHistory) { $script:NotificationShowAfterFetch = $true }
  if ($script:NotificationCheckBusy) { return }
  $script:NotificationCheckBusy = $true
  try {
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($Url)
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 8 -UseBasicParsing -Headers @{ Accept='application/json' }
        [pscustomobject]@{ Ok=$true; Content="$($response.Content)" }
      } catch { [pscustomobject]@{ Ok=$false; Content='' } }
    }).AddArgument($script:NotificationUrl)
    $script:NotificationJob = $ps
    $script:NotificationAsync = $ps.BeginInvoke()
    $script:NotificationPollTimer = New-Object Windows.Threading.DispatcherTimer
    $script:NotificationPollTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:NotificationPollTimer.Add_Tick({
      if (-not $script:NotificationAsync.IsCompleted) { return }
      $script:NotificationPollTimer.Stop()
      try {
        $reply = @($script:NotificationJob.EndInvoke($script:NotificationAsync)) | Where-Object { $_ -and $_.PSObject.Properties['Ok'] } | Select-Object -Last 1
        if ($reply -and $reply.Ok -and $reply.Content) {
          $payload = "$($reply.Content)" | ConvertFrom-Json -ErrorAction Stop
          Set-NotificationPayload $payload
        } else { $script:NotificationLastFetchOk = $false }
      } catch { $script:NotificationLastFetchOk = $false }
      finally {
        try { $script:NotificationJob.Dispose() } catch {}
        $script:NotificationCheckBusy = $false
      }
      if ($script:NotificationShowAfterFetch) {
        $script:NotificationShowAfterFetch = $false
        Show-NotificationHistory
      }
    })
    $script:NotificationPollTimer.Start()
  } catch {
    $script:NotificationCheckBusy = $false
    $script:NotificationLastFetchOk = $false
    if ($script:NotificationShowAfterFetch) {
      $script:NotificationShowAfterFetch = $false
      Show-NotificationHistory
    }
  }
}

function Test-PowerRecoveryNoticeAcknowledged {
  try {
    if (-not (Test-Path -LiteralPath $script:PowerRecoveryNoticeStatePath -PathType Leaf)) { return $false }
    $state = Get-Content -LiteralPath $script:PowerRecoveryNoticeStatePath -Raw -Encoding UTF8 |
             ConvertFrom-Json -ErrorAction Stop
    return ([int]$state.SchemaVersion -eq 1 -and "$($state.NoticeId)" -eq $script:PowerRecoveryNoticeId)
  } catch { return $false }
}

function Set-PowerRecoveryNoticeAcknowledged {
  $state = [ordered]@{
    SchemaVersion = 1
    NoticeId = $script:PowerRecoveryNoticeId
    AcknowledgedAt = (Get-Date).ToString('s')
  }
  if (Get-Command Write-DfbTelemetryConfigAtomic -ErrorAction SilentlyContinue) {
    Write-DfbTelemetryConfigAtomic $script:PowerRecoveryNoticeStatePath $state
  } else {
    [IO.File]::WriteAllText($script:PowerRecoveryNoticeStatePath, ($state | ConvertTo-Json),
      (New-Object Text.UTF8Encoding($true)))
  }
}

function Show-PowerRecoveryVersionNotice {
  if ($script:PowerRecoveryNoticePromptedThisRun -or (Test-PowerRecoveryNoticeAcknowledged)) { return }
  $script:PowerRecoveryNoticePromptedThisRun = $true
  $message = @(
    '如果你在执行优化后出现游戏或电脑卡顿、异常掉帧、黑屏、闪屏、无法进入游戏或游戏异常退出，请先恢复电源相关选项。'
    '使用过「主推全套」也不必全部还原，可以只恢复下面的电源项。'
    ''
    '操作方法：'
    '1. 进入「优化」页，点击「还原设置」。'
    '2. 勾选你执行过的电源项：'
    '   · 电源计划切换到「卓越性能」'
    '   · 电源计划隐藏项深度调优'
    '   · 锁定电源计划'
    '3. 点击「复原所选项目」，完成后重启电脑。'
    ''
    '只执行过其中一项就只恢复对应项；也可同时多选恢复。'
  ) -join "`n"
  if (Show-ConfirmDialog '重要提醒' 'POWER RECOVERY NOTICE' $message '我知道了' -InfoOnly `
      -Banner '优化后出现异常：先恢复电源选项并重启电脑') {
    try { Set-PowerRecoveryNoticeAcknowledged }
    catch { Write-Log "重要提醒确认状态保存失败，下次启动将再次提醒：$($_.Exception.Message)" }
  }
}

# 更新检查间隔（分钟）：做成常量便于调整；验证定时机制时可临时改小
$script:UpdateCheckIntervalMinutes = 30

# 异步检查更新：网络请求放后台运行空间，界面渲染不等它；任何失败静默吞掉。
# 启动时查一次，此后由定时器每 $script:UpdateCheckIntervalMinutes 分钟复查——
# 检测到新版会直接弹详情，同时保留标题栏常驻入口供稍后重看。
function Start-UpdateCheck {
  if (-not (Get-Command Test-BoosterUpdate -ErrorAction SilentlyContinue)) { return }
  # 上一轮检查还没回来就跳过本轮：慢网络下 30 分钟间隔也可能追尾
  if ($script:UpdateCheckBusy) { return }
  $script:UpdateCheckBusy = $true
  try {
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript({
      param($ModulePath, $Cur)
      try { . $ModulePath; Test-BoosterUpdate -CurrentVersion $Cur } catch { $null }
    }).AddArgument($script:UpdaterPath).AddArgument($script:GuiVersion)
    $script:UpdateJob = $ps
    $script:UpdateAsync = $ps.BeginInvoke()
    $script:UpdateTimer = New-Object Windows.Threading.DispatcherTimer
    $script:UpdateTimer.Interval = [TimeSpan]::FromMilliseconds(700)
    $script:UpdateTimer.Add_Tick({
      if (-not $script:UpdateAsync.IsCompleted) { return }
      $script:UpdateTimer.Stop()
      try {
        $r = @($script:UpdateJob.EndInvoke($script:UpdateAsync))
        $found = $r | Where-Object { $_ } | Select-Object -First 1
        if ($found) {
          # 新版本第一次出现就直接弹详情；同一版本本次运行只自动弹一次，标题栏入口常驻
          $isNew = ("$($found.Version)" -ne "$(if ($script:UpdateInfo) { $script:UpdateInfo.Version })")
          $script:UpdateInfo = $found
          $ui.UpdateBtn.ToolTip = "新版本 v$($found.DisplayVersion) 可用（当前 v$script:DisplayVersion），点击查看详情"
          $ui.UpdateBtn.Visibility = 'Visible'
          if ($isNew) {
            Write-Log "检测到新版本 v$($found.DisplayVersion)（当前 v$script:DisplayVersion），正在显示更新详情。"
            Show-DetectedUpdateDialog
          }
        }
      } catch {} finally { $script:UpdateJob.Dispose(); $script:UpdateCheckBusy = $false }
    })
    $script:UpdateTimer.Start()
  } catch { $script:UpdateCheckBusy = $false }
}

# 手动检查更新（v0.13，实机诉求）：定时检查是静默的，手动点击必须给出明确结果——
# 已最新 / 发现新版弹详情 / 网络失败提示。只看 Test-BoosterUpdate 的 $null 分不出
# 「已最新」和「拿不到清单」，所以先取清单分辨状态；手动检查带 -IncludeSkipped：
# 用户主动点按钮就是想看结果，「不再提醒此版本」的记录不该拦住他
function Start-ManualUpdateCheck {
  if ($script:ManualCheckBusy) { return }
  if (-not (Get-Command Test-BoosterUpdate -ErrorAction SilentlyContinue)) {
    Show-ConfirmDialog '检查更新' 'CHECK UPDATE' '更新模块（scripts\updater.ps1）缺失，无法检查更新。请重新安装完整版本。' '知道了' -InfoOnly | Out-Null
    return
  }
  $script:ManualCheckBusy = $true
  $ui.CheckUpdBtn.IsEnabled = $false
  $ui.CheckUpdBtn.Content = '检查中…'
  Write-Log '正在检查更新…'
  $ps = [PowerShell]::Create()
  [void]$ps.AddScript({
    param($ModulePath, $Cur, $ManifestUrl)
    try {
      . $ModulePath
      $m = Get-BoosterManifest $ManifestUrl
      if (-not $m) { return [pscustomobject]@{ Status = 'error' } }
      if ((Compare-BoosterVersion "$($m.version)" $Cur) -le 0) { return [pscustomobject]@{ Status = 'latest' } }
      $found = Test-BoosterUpdate -CurrentVersion $Cur -ManifestUrl $ManifestUrl -IncludeSkipped
      if ($found) { return [pscustomobject]@{ Status = 'found'; Info = $found } }
      [pscustomobject]@{ Status = 'latest' }
    } catch { [pscustomobject]@{ Status = 'error' } }
  })
  foreach ($arg in @($script:UpdaterPath, $script:GuiVersion, $script:BoosterManifestUrl)) { [void]$ps.AddArgument($arg) }
  $script:ManualCheckJob = $ps
  $script:ManualCheckAsync = $ps.BeginInvoke()
  $script:ManualCheckTimer = New-Object Windows.Threading.DispatcherTimer
  $script:ManualCheckTimer.Interval = [TimeSpan]::FromMilliseconds(300)
  $script:ManualCheckTimer.Add_Tick({
    if (-not $script:ManualCheckAsync.IsCompleted) { return }
    $script:ManualCheckTimer.Stop()
    $r = $null
    try { $r = @($script:ManualCheckJob.EndInvoke($script:ManualCheckAsync)) | Where-Object { $_ } | Select-Object -First 1 } catch {}
    try { $script:ManualCheckJob.Dispose() } catch {}
    $script:ManualCheckBusy = $false
    $ui.CheckUpdBtn.Content = '检查更新'
    # 恢复可用要看全局忙碌态：万一结果回来时正在执行优化，不能把按钮提前放开
    if (-not $script:Busy) { $ui.CheckUpdBtn.IsEnabled = $true }
    if (-not $r -or $r.Status -eq 'error') {
      Write-Log '检查更新失败：网络不可达或服务器暂时无响应。'
      Show-ConfirmDialog '检查更新' 'CHECK UPDATE' '检查更新失败：网络不可达或服务器暂时无响应，请稍后再试。' '知道了' -InfoOnly | Out-Null
    } elseif ($r.Status -eq 'latest') {
      Write-Log "已是最新版本 v$($script:DisplayVersion)。"
      Show-ConfirmDialog '检查更新' 'CHECK UPDATE' "已是最新版本 v$($script:DisplayVersion)，无需更新。" '知道了' -InfoOnly | Out-Null
    } else {
      # 发现新版：与定时检查同一收口——点亮标题栏入口，并直接弹更新详情
      $script:UpdateInfo = $r.Info
      $ui.UpdateBtn.ToolTip = "新版本 v$($r.Info.DisplayVersion) 可用（当前 v$script:DisplayVersion），点击查看详情"
      $ui.UpdateBtn.Visibility = 'Visible'
      Write-Log "检测到新版本 v$($r.Info.DisplayVersion)（当前 v$script:DisplayVersion）。"
      if (Show-UpdateDialog $script:UpdateInfo) { $ui.UpdateBtn.Visibility = 'Collapsed' }
    }
  })
  $script:ManualCheckTimer.Start()
}

$script:TargetExe = $null
$script:PresetList = @()
$script:ApplyingPreset = $false
$script:SelectedGpuSpoofModel = $null
$script:UpdateInfo = $null
$script:UpdatePromptedVersion = $null
$script:UpdateDialogOpen = $false
$script:HardwareInfo = $null
Initialize-RunLogStore
Initialize-NotificationState

$window.Add_ContentRendered({
  Show-PowerRecoveryVersionNotice
  Initialize-LiveMetricsDashboard
  Refresh-PerformanceComparison -Force
  Start-NotificationCheck
  $script:NotificationPeriodicTimer = New-Object Windows.Threading.DispatcherTimer
  $script:NotificationPeriodicTimer.Interval = [TimeSpan]::FromSeconds($script:NotificationCheckIntervalSeconds)
  $script:NotificationPeriodicTimer.Add_Tick({ Start-NotificationCheck })
  $script:NotificationPeriodicTimer.Start()
  try {
    $hw = Get-HardwareInfo
    $script:HardwareInfo = $hw
    $ui.HwGrid.Children.Clear()
    $gpu = ($hw.Gpus | Where-Object { $_.Name -eq $hw.MainGpuName } | Select-Object -First 1)
    if (-not $gpu) { $gpu = $hw.Gpus | Select-Object -First 1 }
    $cpuShort = ($hw.CPU -replace '^\d+th Gen ', '' -replace '\(R\)|\(TM\)', '' -replace '\s*@.*$', '').Trim()
    $script:HardwareTemperatureReadouts.Clear()
    $ui.HwGrid.Children.Add((New-HwCard 'CPU' $cpuShort "$($hw.Cores)核 / $($hw.Threads)线程" -TemperatureKey 'cpu')) | Out-Null
    $ui.HwGrid.Children.Add((New-HwCard 'GPU' $gpu.Name "$($gpu.Vendor) · $(if (@($hw.Gpus).Count -gt 1) { '双显卡' } else { '单显卡' })" -Ribbon -TemperatureKey 'gpu')) | Out-Null
    $systemName = "$($hw.ComputerBrand) $($hw.ComputerModel)".Trim()
    $ui.HwGrid.Children.Add((New-HwCard 'SYSTEM' $systemName "$($hw.RamGB) GB · $(if ($hw.IsLaptop) { '笔记本' } else { '台式机' }) · Build $($hw.Build)")) | Out-Null
    $displayClass = Resolve-DisplayClassLabel ([int]$hw.DisplayWidth) ([int]$hw.DisplayHeight)
    $displayName = $(if ("$($hw.DisplayName)".Trim()) { "$($hw.DisplayName)".Trim() } else { '显示器' })
    $displayValue = $(if ($displayClass -in '1K','2K','4K') { "$displayClass · $displayName" } else { $displayClass })
    $displaySub = $(if ([int]$hw.DisplayWidth -gt 0 -and [int]$hw.DisplayHeight -gt 0) {
      "$($hw.DisplayWidth) × $($hw.DisplayHeight)$(if ([int]$hw.DisplayRefreshHz -gt 0) { " · $($hw.DisplayRefreshHz) Hz" })"
    } else { '未获取当前分辨率' })
    $ui.HwGrid.Children.Add((New-HwCard 'DISPLAY' $displayValue $displaySub)) | Out-Null
    try { Start-LiveMetricsMonitor $hw } catch { Write-Log "实时硬件状态启动失败：$($_.Exception.Message)" }
    Update-DropFrameRepairPage

    Write-Log '开始检测硬件与系统状态…'
    $script:TargetExe = Find-GamePath
    if ($script:TargetExe) {
      $ui.GameText.Text = $script:TargetExe
      Write-Log "目标程序已定位：$script:TargetExe"
    } else {
      $ui.GameText.Text = '未定位 — 点「重新定位」手动选择游戏主程序'
      Write-Log '未自动找到游戏，部分优化项需要手动指定路径'
    }
    Update-DropFrameRepairPage
    # 硬件和默认游戏路径准备好后再恢复实验；状态中的固定路径优先且会严格复验。
    Load-ActiveTuningExperiment
    Update-ItemList
    Update-PresetList
    try {
      $startupCatalog = Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems
      Update-TelemetryOptimizationContextFromCatalog -Catalog $startupCatalog
    } catch { Write-Log "当前优化项目归属暂未同步：$($_.Exception.Message)" }
    # 启动即默认选中主推方案（实机诉求「进去之后默认直接选择主推全套」）：
    # SelectionChanged 处理器会完成勾选，其中已就绪的项自动跳过不重复勾
    for ($fi = 0; $fi -lt $script:PresetList.Count; $fi++) {
      if ($script:PresetList[$fi].Id -eq 'main') { $ui.PresetBox.SelectedIndex = $fi; break }
    }
    $ui.ScanState.Text = '检测完成'
    Write-Log '检测完成。已默认选中「主推全套」方案，可改选其他方案或手动勾选后点「执行优化」。本次软件会话已在启动时完成管理员确认，执行优化、还原和自动调优不会再次弹出权限确认。'
    Send-AnonymousTelemetry 'launch' $hw
    # tuning 事件使用独立的持久 outbox。启动先恢复历史队列，运行中定时唤醒到期重试；
    # 普通 launch/apply/restore 遥测仍保持原来的即时异步发送路径。
    Start-TuningTelemetryOutboxFlush
    $script:TuningTelemetryTimer = New-Object Windows.Threading.DispatcherTimer
    $script:TuningTelemetryTimer.Interval = [TimeSpan]::FromSeconds(30)
    $script:TuningTelemetryTimer.Add_Tick({ Start-TuningTelemetryOutboxFlush })
    $script:TuningTelemetryTimer.Start()
    Start-UpdateCheck
    # 运行期间定时复查：DispatcherTimer 在 UI 线程触发，真正的网络请求仍在后台 runspace，
    # 静默失败的约定不变——断网/超时都不会打扰主界面
    $script:UpdatePeriodicTimer = New-Object Windows.Threading.DispatcherTimer
    $script:UpdatePeriodicTimer.Interval = [TimeSpan]::FromMinutes($script:UpdateCheckIntervalMinutes)
    $script:UpdatePeriodicTimer.Add_Tick({ Start-UpdateCheck })
    $script:UpdatePeriodicTimer.Start()
    # 软件保持打开时观察游戏进程；每个 PID 只采一次 120 秒汇总，不做永久逐帧录制。
    $script:PerformanceTimer = New-Object Windows.Threading.DispatcherTimer
    $script:PerformanceTimer.Interval = [TimeSpan]::FromSeconds(5)
    $script:PerformanceTimer.Add_Tick({ Poll-GamePerformanceCapture })
    $script:PerformanceTimer.Start()
    Poll-GamePerformanceCapture
  } catch {
    $ui.ScanState.Text = '检测失败'
    Write-Log "初始化失败：$($_.Exception.Message)"
  }
})

$ui.TitleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$ui.MinBtn.Add_Click({ $window.WindowState = 'Minimized' })
if ($script:LightThemeEnabled) {
  $ui.ThemeBtn.Add_Click({ Set-AppTheme $(if ($script:CurrentTheme -eq 'dark') { 'light' } else { 'dark' }) -Persist })
}
$ui.NoticeBtn.Add_Click({
  if (@($script:NotificationItems).Count -gt 0) {
    Show-NotificationHistory
    Start-NotificationCheck
  } else {
    Start-NotificationCheck -ShowHistory
  }
})
$ui.UpdateBtn.Add_Click({
  if (-not $script:UpdateInfo) { return }
  if (Test-TuningExperimentActive) { Write-Log '自动调优实验期间不安装更新，请先停止并回滚。'; return }
  # 用户在详情框里勾了「不再提醒此版本」就把入口收起，和跳过语义保持一致
  if (Show-UpdateDialog $script:UpdateInfo) { $ui.UpdateBtn.Visibility = 'Collapsed' }
})
# 忙碌关窗守卫（真正的防线在 Closing 上）：CloseBtn 只拦自绘按钮，外部程序发的
# WM_CLOSE（如安装器 CloseMainWindow）和 Alt+F4 都不经过它——执行/还原中途被关会
# 留下写了一半的系统改动，必须在 Closing 事件里统一拦截
$window.Add_Closing({
  if ($script:TuningSampling) {
    $_.Cancel = $true
    Write-Log '自动调优正在采样，请等本轮结束后再关闭；非采样阶段可直接关闭稍后继续。'
  } elseif ($script:Busy) {
    $_.Cancel = $true
    Write-Log '正在执行优化/还原，请等本轮结束后再关闭。'
  } else {
    try { Save-AppUiPreferences $script:CurrentTheme (Get-PersistableAppWindowHeight) } catch {}
    Stop-LiveMetricsMonitor
    if ($script:PerformanceTimer) { $script:PerformanceTimer.Stop() }
    if ($script:TuningTelemetryTimer) { $script:TuningTelemetryTimer.Stop() }
    if ($script:NotificationPeriodicTimer) { $script:NotificationPeriodicTimer.Stop() }
  }
})
$ui.CloseBtn.Add_Click({
  if ($script:TuningSampling) { Write-Log '自动调优正在采样，请等本轮结束后再关闭。'; return }
  if ($script:Busy) { Write-Log '正在执行优化，请等本轮执行结束后再关闭。'; return }
  $window.Close()
})

$ui.TabOptBtn.Add_Click({ Select-Tab 'opt' })
$ui.TabFrameFixBtn.Add_Click({ Select-Tab 'framefix' })
$ui.TabRefBtn.Add_Click({ Select-Tab 'ref' })
$ui.TabLogBtn.Add_Click({ Select-Tab 'log' })
$ui.FrameFixOptBtn.Add_Click({ Select-Tab 'opt' })
$ui.FrameFixCacheBtn.Add_Click({ Invoke-FrameFixCacheCleanup })
$ui.FrameFixGpuPrefBtn.Add_Click({ Invoke-FrameFixGpuPreference })
$ui.FrameFixVcBtn.Add_Click({ Invoke-FrameFixVcredistCheck })
$ui.FrameFixGuideBtn.Add_Click({
  try { Show-GpuGuideDialog $(if ($script:HardwareInfo) { $script:HardwareInfo } else { Get-HardwareInfo }) }
  catch { Write-Log "显卡指引打开失败：$($_.Exception.Message)" }
})

$ui.BrowseBtn.Add_Click({
  if (Test-TuningExperimentActive) { Write-Log '自动调优实验期间已锁定游戏路径。'; return }
  $dlg = New-Object Microsoft.Win32.OpenFileDialog
  $dlg.Filter = '三角洲行动主程序|DeltaForceClient-Win64-Shipping.exe;DeltaForce.exe|EXE 文件 (*.exe)|*.exe'
  $dlg.Title = '选择三角洲行动主程序（如 DeltaForceClient-Win64-Shipping.exe）'
  if ($dlg.ShowDialog()) {
    if (-not (Test-AllowedGameExecutable $dlg.FileName)) {
      Show-ConfirmDialog '选择错误' 'INVALID GAME EXECUTABLE' '只能选择已存在的 DeltaForceClient-Win64-Shipping.exe 或 DeltaForce.exe。请不要选择启动器、捷径或其他 EXE。' '知道了' -InfoOnly | Out-Null
      return
    }
    $script:TargetExe = $dlg.FileName
    $script:TuningConfigGeneration++
    $ui.GameText.Text = $script:TargetExe
    Update-ItemList
    Update-DropFrameRepairPage
    Write-Log "目标程序已更新：$script:TargetExe"
  }
})

$ui.TunePowerChk.Add_Click({
  if(-not $ui.TunePowerChk.IsChecked){$ui.TunePowerBox.Text='0'}
  $ui.TunePowerBox.IsEnabled=[bool]$ui.TunePowerChk.IsChecked -and -not (Test-TuningExperimentActive) -and -not $script:Busy
})
$ui.TuneCreateBtn.Add_Click({
  try{
    if(Test-TuningExperimentActive){Select-Tab 'tune';$script:ActiveTuningExperiment.lastMessage='已继续当前实验，点「执行下一步」按状态机前进。';Save-TuningExperiment;Update-TuningUi;return}
    [void](New-GuiTuningExperiment)
  }catch{Write-Log "创建自动调优实验失败：$($_.Exception.Message)";Show-ConfirmDialog '创建失败' 'TUNING NOT STARTED' $_.Exception.Message '知道了' -InfoOnly|Out-Null}
})
$ui.TuneNextBtn.Add_Click({
  try{Set-BusyState $true;Invoke-NextTuningStep}
  catch{Write-Log "自动调优下一步未完成：$($_.Exception.Message)";Show-ConfirmDialog '步骤未完成' 'TUNING STEP STOPPED' $_.Exception.Message '知道了' -InfoOnly|Out-Null}
  finally{Set-BusyState $false;Update-TuningUi}
})
$ui.TuneStopBtn.Add_Click({
  if(-not (Show-ConfirmDialog '停止并回滚' 'STOP TUNING' '停止当前实验，并按相反顺序只回滚它保留的指定备份？' '停止并回滚')){return}
  try{Set-BusyState $true;Stop-GuiTuningExperiment;Write-Log '自动调优实验已停止并回滚。'}
  catch{Write-Log "自动调优停止/回滚失败：$($_.Exception.Message)";Show-ConfirmDialog '回滚未完成' 'ROLLBACK STOPPED' $_.Exception.Message '知道了' -InfoOnly|Out-Null}
  finally{Set-BusyState $false;Update-TuningUi}
})

$ui.RefreshBtn.Add_Click({ Update-ItemList; Write-Log '状态已刷新。' })

$ui.CheckUpdBtn.Add_Click({
  if(Test-TuningExperimentActive){Write-Log '自动调优实验期间已暂停主动更新入口。';return}
  Start-ManualUpdateCheck
})

# 全选/全不选：只批量勾选 BulkSelect 项，避免把会显著增加页面文件 IO 的专家项顺手带上；
# 已就绪项不重复圈选。全不选仍一视同仁清空。
$ui.SelAllChk.Add_Click({
  $on = ($ui.SelAllChk.IsChecked -eq $true)
  foreach ($row in (@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children))) {
    $bulkSelect = [bool]($row.DataContext -and $row.DataContext.BulkSelect)
    $row.Child.Children[0].IsChecked = $(if ($on) { $bulkSelect -and $row.Tag -ne $true } else { $false })
  }
  Update-Count
  if ($ui.PresetBox -and $ui.PresetBox.SelectedIndex -ge 0) {
    $ui.PresetBox.SelectedIndex = -1
    $ui.PresetNote.Text = ''
  }
})

# 复制成功后按钮短暂变「已复制」再复原：给出即时反馈但不打断视线
$script:CopyRevertTimer = New-Object Windows.Threading.DispatcherTimer
$script:CopyRevertTimer.Interval = [TimeSpan]::FromSeconds(1.5)
$script:CopyRevertTimer.Add_Tick({ $script:CopyRevertTimer.Stop(); $ui.CopyLogTxt.Text = '复制' })
$ui.CopyLogBtn.Add_Click({
  $txt = $ui.LogBox.Text
  if (-not $txt) { Write-Log '日志还是空的，没有可复制的内容。'; return }
  # GUI 线程本就是 STA；但 SetText 的冲刷（flush）步骤会被短暂占用剪贴板的进程搅黄而抛
  # CLIPBRD_E_CANT_OPEN——本机实测这种情况下数据其实已经写进去了，所以抛错后先回读确认，
  # 确认不了再用不冲刷的 SetDataObject 兜底（代价只是应用退出后剪贴板内容失效）
  $copied = $false
  try { [Windows.Clipboard]::SetText($txt); $copied = $true }
  catch {
    # 回读确认也可能撞上同一把短锁，稍候重试几次再下结论
    foreach ($attempt in 1..3) {
      try { $copied = ([Windows.Clipboard]::GetText() -eq $txt); break } catch { Start-Sleep -Milliseconds 80 }
    }
    if (-not $copied) {
      try { [Windows.Clipboard]::SetDataObject($txt, $false); $copied = $true } catch {}
    }
  }
  if ($copied) {
    $ui.CopyLogTxt.Text = '已复制'
    $script:CopyRevertTimer.Stop()
    $script:CopyRevertTimer.Start()
  } else {
    Write-Log '复制到剪贴板失败（剪贴板被其他程序占用），请手动选中日志文本按 Ctrl+C 复制。'
  }
})

$ui.GuideBtn.Add_Click({ Show-GpuGuideDialog (Get-HardwareInfo) })

$ui.DisclaimerBtn.Add_Click({ Show-DisclaimerDialog -ReadOnly | Out-Null })

# 上传诊断报告：先选择问题/改善，再组装脱敏报告并确认数据清单，最后才上传。绝不静默发送
$ui.ReportBtn.Add_Click({
  try {
    $feedback = Show-DiagnosticFeedbackDialog
    if (-not $feedback) {
      Write-Log '已取消上传诊断报告。'
      return
    }
    Write-Log '正在收集诊断信息…'
    $report = New-DiagnosticReport -Feedback $feedback
    $kb = [math]::Round([Text.Encoding]::UTF8.GetByteCount($report) / 1KB, 1)
    $selectedIssues = $(if (@($feedback.IssueLabels).Count) { @($feedback.IssueLabels) -join '、' } else { '未选择' })
    $selectedBenefits = $(if (@($feedback.BenefitLabels).Count) { @($feedback.BenefitLabels) -join '、' } else { '未选择' })
    $msg = @(
      "将把以下内容上传到作者的服务器（$script:ReportUploadUrl），仅用于排查你反馈的问题："
      ''
      "· 你选择的当前问题：$selectedIssues"
      "· 你选择的已有改善：$selectedBenefits"
      '· 硬件型号与系统版本（CPU / 显卡 / 内存 / Windows 版本）'
      '· 显示器分辨率/刷新率、音频设备、页面文件、系统启动时间与相关进程名'
      '· 排障所需的关键环境变量（路径会脱敏；敏感变量只记录名称，不上传值）'
      '· 已定位的游戏主程序路径（用户名和机器名会脱敏）'
      '· 各优化项的当前状态'
      '· 本次运行日志与软件关闭前保留的最近历史日志'
      '· 受保护备份的位置，以及本次日志中的备份文件名与执行结果（不会读取注册表原值）'
      '· 本工具的版本号'
      ''
      "路径中的用户名、机器名已替换为 <user> / <pc>。报告大小约 $kb KB。"
      '上传成功后会给你一个取件码，发给开发者即可。'
    ) -join "`n"
    if (-not (Show-ConfirmDialog '上传诊断报告' 'UPLOAD REPORT' $msg '确认上传')) {
      Write-Log '已取消上传诊断报告。'
      return
    }
    Set-BusyState $true
    Write-Log '正在上传诊断报告…'
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $code = Invoke-ReportUpload $report
    if (-not $code) { throw '服务器没有返回取件码' }
    Write-Log "诊断报告上传成功，取件码：$code"
    Show-ConfirmDialog '上传成功' 'UPLOAD OK' "取件码：$code`n`n把这个码发给开发者，他就能取到你这份报告。`n（取件码也已写进上面的运行日志，可用「复制」按钮一并带走）" '知道了' -InfoOnly | Out-Null
  } catch {
    # 失败绝不含糊：说清原因并引导走「复制日志」手工发送
    Write-Log "诊断报告上传失败：$($_.Exception.Message)"
    Show-ConfirmDialog '上传失败' 'UPLOAD FAILED' "上传失败：$($_.Exception.Message)`n`n可能是网络不通、服务暂时不可用，或短时间内上传次数过多。`n`n改用手工方式：点运行日志右侧的「复制」按钮，把日志粘贴发给开发者即可。" '知道了' -InfoOnly | Out-Null
  } finally { Set-BusyState $false }
})

# ---------- 预设方案 ----------

$ui.PresetBox.Add_SelectionChanged({
  $idx = $ui.PresetBox.SelectedIndex
  if ($idx -lt 0 -or $idx -ge $script:PresetList.Count) { return }
  try {
    $p = $script:PresetList[$idx]
    $ids = @(Resolve-PresetItems $p.Id $script:TargetExe)
    $script:ApplyingPreset = $true
    try {
      foreach ($row in (@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children))) {
        $cb = $row.Child.Children[0]
        # 已就绪的项不勾（与全选框同一语义，v0.13）：方案表达的是「要达到的状态」，
        # 已达标的再执行一遍只会撑大备份
        $cb.IsChecked = (($ids -contains $cb.Tag) -and ($row.Tag -ne $true))
      }
    } finally { $script:ApplyingPreset = $false }
    $ui.PresetNote.Text = $p.Note
    Update-Count
    $selN = @((@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children)) |
              Where-Object { $_.Child.Children[0].IsChecked }).Count
    Write-Log "已套用方案「$($p.Name)」（勾选 $selN / $($ids.Count) 项，已就绪的不重复执行）"
  } catch { Write-Log "套用方案失败：$($_.Exception.Message)" }
})

$ui.SavePresetBtn.Add_Click({
  try {
    $ids = @((@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children)) |
             Where-Object { $_.Child.Children[0].IsChecked } | ForEach-Object { $_.Child.Children[0].Tag })
    if ($ids.Count -eq 0) { Write-Log '未勾选任何优化项，无法存为方案。'; return }
    $newName = Show-NameDialog
    if (-not $newName) { return }
    Save-UserPreset $newName $ids | Out-Null
    Update-PresetList
    for ($i = 0; $i -lt $script:PresetList.Count; $i++) {
      if (-not $script:PresetList[$i].Builtin -and $script:PresetList[$i].Name -eq $newName) {
        $ui.PresetBox.SelectedIndex = $i; break
      }
    }
    Write-Log "方案「$newName」已保存（$($ids.Count) 项）。"
  } catch { Write-Log "保存方案失败：$($_.Exception.Message)" }
})

$ui.DelPresetBtn.Add_Click({
  try {
    $idx = $ui.PresetBox.SelectedIndex
    if ($idx -lt 0) { Write-Log '请先在下拉里选中要删除的方案。'; return }
    $p = $script:PresetList[$idx]
    if ($p.Builtin) { Write-Log "「$($p.Name)」是内置方案，不能删除。"; return }
    if (-not (Show-ConfirmDialog '确认删除' 'CONFIRM DELETE' "删除自存方案「$($p.Name)」？删除后不可恢复。" '删除')) { return }
    Remove-UserPreset $p.Id | Out-Null
    Update-PresetList
    $ui.PresetNote.Text = ''
    Write-Log "方案「$($p.Name)」已删除。"
  } catch { Write-Log "删除方案失败：$($_.Exception.Message)" }
})

$ui.ApplyBtn.Add_Click({
  $adminBatchReturned = $false
  $adminBatchBackupLogged = $false
  $r = $null
  try {
    if (Test-TuningExperimentActive) { throw '自动调优实验期间已锁定配置，请使用实验「下一步」，或先停止并回滚' }
    $ids = @($ui.ItemPanel.Children | Where-Object { $_.Child.Children[0].IsChecked } |
             ForEach-Object { $_.Child.Children[0].Tag })
    # 危险区域的勾选此前被整个忽略（勾了也不执行、不提示）：单独收集，走独立的
    # 高风险二次确认，确认后才带 AllowRisky 交给引擎
    $riskyIds = @($ui.RiskyPanel.Children | Where-Object { $_.Child.Children[0].IsChecked } |
                  ForEach-Object { $_.Child.Children[0].Tag })
    if ($ids.Count -eq 0 -and $riskyIds.Count -eq 0) {
      Write-Log '未勾选任何优化项。'
      Show-ConfirmDialog '未选择优化项' 'NO ITEMS SELECTED' '请先勾选至少一个优化项目，再点击「执行优化」。' '知道了' -InfoOnly | Out-Null
      return
    }
    $presetIndex = $(if ($ui.PresetBox) { [int]$ui.PresetBox.SelectedIndex } else { -1 })
    $optAll = @(Get-OptItems $script:TargetExe $script:SelectedGpuSpoofModel)
    if ($riskyIds.Count -gt 0) {
      $riskySel = @($optAll | Where-Object { $riskyIds -contains $_.Id })
      $rmsg = "将执行以下显卡型号伪装设置：`n`n" +
              (@($riskySel | ForEach-Object { "· $($_.Name)`n  $(if ($_.Warn) { $_.Warn } else { $_.Note })" }) -join "`n`n") +
              "`n`n目标型号：$script:SelectedGpuSpoofModel`n`n确认后将与其余勾选项一起执行（改动前自动备份，可一键还原）。"
      if (Show-ConfirmDialog '显卡型号伪装' 'GPU MODEL SPOOF' $rmsg '确认执行') {
        $ids = @($ids + $riskyIds)
      } else {
        Write-Log "已取消 $($riskyIds.Count) 个高风险项，本次不执行它们。"
        $riskyIds = @()
        if ($ids.Count -eq 0) { Write-Log '取消高风险项后没有剩余可执行项。'; return }
      }
    }
    $powerRiskIds = @('power-ultimate','power-tuning','powerplan-lock')
    $selectedPowerIds = @($ids | Where-Object { $powerRiskIds -contains $_ })
    if ($selectedPowerIds.Count -gt 0) {
      $selectedPowerNames = @($optAll | Where-Object { $selectedPowerIds -contains $_.Id } |
                              ForEach-Object { "· $($_.Name)" })
      $powerMessage = "你选择了以下电源相关优化：`n`n" +
                      ($selectedPowerNames -join "`n") +
                      "`n`n绝大多数电脑可以正常使用，但由于不同设备的电源管理存在差异，极少数用户修改后可能出现：`n`n" +
                      "· 游戏或系统卡顿、异常掉帧`n" +
                      "· 黑屏、闪屏或显卡驱动异常`n" +
                      "· 游戏无法启动、无法进入或启动后崩溃`n" +
                      "· 温度、功耗或风扇噪声升高`n" +
                      "· 睡眠、唤醒、USB、键鼠等外设异常`n`n" +
                      "执行前请保存工作并关闭游戏。可还原的设置会自动备份；如出现异常，请进入「还原设置」恢复本次电源相关项目，并重启电脑。`n`n" +
                      "是否了解以上风险并继续执行？"
      if (-not (Show-ConfirmDialog '电源计划优化风险确认' 'POWER PLAN RISK' $powerMessage '我已了解，继续执行' -DefaultCancel)) {
        Write-Log "已取消电源计划风险确认，本次 $($ids.Count) 项优化均未执行。"
        return
      }
    }
    $names = @($optAll | Where-Object { $ids -contains $_.Id } | ForEach-Object { $_.Name })
    $msg = "将执行以下 $($ids.Count) 项优化（可还原的设置会先写入受保护备份）：`n`n" +
           (@($names | ForEach-Object { "· $_" }) -join "`n")
    if (-not (Show-ConfirmDialog '确认执行' 'CONFIRM APPLY' $msg '执行优化')) { return }
    Set-BusyState $true
    $ui.ProgressPanel.Visibility = 'Visible'
    $ui.ProgFill.Width = 0
    $ui.ProgText.Text = '准备执行…'
    $ui.ProgCount.Text = ''
    Write-Log "开始执行 $($ids.Count) 项优化…"
    $selectedItems = @($optAll | Where-Object { $ids -contains $_.Id })
    $telemetryScheme = 'manual'
    $telemetrySchemeItemIds = @($selectedItems | Where-Object { $_.Kind -notin 'check','cache' } | ForEach-Object Id)
    if ($presetIndex -ge 0 -and $presetIndex -lt $script:PresetList.Count) {
      $selectedPreset = $script:PresetList[$presetIndex]
      $telemetryScheme = $(if ($selectedPreset.Builtin -and "$($selectedPreset.Id)" -in 'main','balanced','safe-only') {
          "$($selectedPreset.Id)"
        } else { 'custom' })
      # 只上报本次实际选择并准备执行的系统修改项；方案声明中已达标、不可用、
      # 纯检测或被用户取消的项目不得混入归因集合。
      $telemetrySchemeItemIds = @($selectedItems | Where-Object { $_.Kind -notin 'check','cache' } | ForEach-Object Id)
    }
    $localItems = @($selectedItems | Where-Object { $_.Kind -in 'cache','check' })
    $elevatedIds = @($selectedItems | Where-Object { $_.Kind -notin 'cache','check' } | ForEach-Object { $_.Id })
    $localResults = @()
    if ($elevatedIds.Count -gt 0) {
      # 先完成受保护系统批次，再做不可回滚的本地缓存清理，避免留下
      # “系统项没改、缓存却已经清了”的半执行状态。当前会话已完成唯一一次 UAC。
      # AllowRisky 只在用户刚通过高风险二次确认时才为真，绝不默认放行。
      $ui.ProgText.Text = '正在执行系统优化…'
      $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
      $r = Invoke-ElevatedEngineAction -Action Apply -ItemIds $elevatedIds -GamePath $script:TargetExe `
           -AllowRisky ($riskyIds.Count -gt 0) -GpuSpoofModel $script:SelectedGpuSpoofModel
      $adminBatchReturned = $true
      # 系统批次与受保护备份已经完成，先记日志再进入本地收尾。后续检测、缓存、
      # 遥测或界面刷新即使异常，用户仍能从日志和诊断报告里找到本轮备份。
      if ($r.Backup) {
        Write-Log "备份已保存：$($r.Backup)"
        $adminBatchBackupLogged = $true
      }
    } else {
      $r = [pscustomobject]@{ Results = @(); Backup = $null; BackupError = $null
                              UnrecordedNames = @(); EngineExitCode = 0 }
    }
    if ($localItems.Count -gt 0) {
      $ui.ProgText.Text = '正在执行检测 / 缓存清理…'
      $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
      $localResults = @(Invoke-LocalNoBackupItems $localItems)
      $r.Results = @($r.Results) + @($localResults)
    }
    $resultRows = @($r.Results)
    for ($ri = 0; $ri -lt $resultRows.Count; $ri++) {
      Update-ApplyProgress ([pscustomobject]@{ Stage = 'done'; Index = ($ri + 1); Total = $resultRows.Count; Result = $resultRows[$ri] })
    }
    $okN = @($r.Results | Where-Object Ok).Count
    $attList = @($r.Results | Where-Object Attention)
    $skipList = @($r.Results | Where-Object { -not $_.Ok -and $_.Skipped })
    $failList = @($r.Results | Where-Object { -not $_.Ok -and -not $_.Skipped -and -not $_.Attention })
    $total = @($r.Results).Count
    # 当前档位与项目集合按受保护还原目录里的“仍在生效”记录重算，不再沿用历史最高档位；
    # 检测、缓存、Attention 与 Skipped 都不会进入活动优化集合。
    $changedIds = @($r.Results | Where-Object { $_.Ok -and $_.Changed -eq $true -and -not $_.Attention } |
                    ForEach-Object { $_.Id })
    $changedCount = @($selectedItems | Where-Object { $changedIds -contains $_.Id -and $_.Kind -notin 'check','cache' }).Count
    if ($changedCount -gt 0) { $script:TuningConfigGeneration++ }
    if ($elevatedIds.Count -gt 0) {
      try {
        $activeCatalog = Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems
        Update-TelemetryOptimizationContextFromCatalog -Catalog $activeCatalog -RequestedScheme $telemetryScheme `
          -RequestedItemIds $telemetrySchemeItemIds -KnownChangedItemIds $changedIds `
          -MutationIncomplete:([bool]$r.BackupError)
      } catch {
        # Apply 已返回后状态同步失败时，把可确认的项目并入旧集合但标记为不完整，
        # 后续启动会再次从受保护目录校正；遥测收尾不影响已经完成的优化结果。
        $beforeContext = Get-TelemetryOptimizationContext
        $fallbackIds = @($beforeContext.ItemIds) + @($changedIds)
        $fallbackScheme = $(if ($beforeContext.ConfigTier -eq 'baseline') { $telemetryScheme } else { 'mixed' })
        Set-TelemetryOptimizationContext -ItemIds $fallbackIds -Scheme $fallbackScheme -ItemsComplete $false `
          -FallbackTier "$($beforeContext.ConfigTier)"
      }
    }
    try {
      $operation = New-OptimizationTelemetryOperation -Event apply -Source manual_selection -Reply $r -ItemIds @($selectedItems | ForEach-Object Id)
      Send-AnonymousTelemetry 'apply' $script:HardwareInfo $okN $failList.Count $operation
    } catch {}
    # 明确的完成度结论：进度条区和日志各给一份，失败项单独列出让用户一眼看到；
    # 体检发现的问题单列——那是检测项立功了，混进「失败」会让用户误以为工具坏了
    $att = $(if ($attList.Count -gt 0) { " / $($attList.Count) 项体检发现问题" })
    $ui.ProgText.Text = "执行完成：$okN 成功 / $($failList.Count) 失败 / $($skipList.Count) 跳过$att"
    $ui.ProgCount.Text = "共 $total 项"
    if ($r.Backup -and -not $adminBatchBackupLogged) { Write-Log "备份已保存：$($r.Backup)" }
    # 备份写盘失败 = 「系统改了、凭据没记全」，比任何一项优化失败都严重：
    # 日志 + 弹窗双通道警告，并把已生效项名和抢救出的部分备份当场给到用户
    if ($r.BackupError) {
      $lost = @($r.UnrecordedNames)
      Write-Log "！！严重：备份文件写入失败（$($r.BackupError)），剩余优化项已中止执行。"
      if ($lost.Count -gt 0) { Write-Log "！！以下已生效的改动可能没有完整的备份记录：$($lost -join '、')" }
      $warn = "备份文件写入失败，本轮执行已中止。`n`n以下改动已经生效、但可能没有完整的备份记录：`n" +
              $(if ($lost.Count -gt 0) { @($lost | ForEach-Object { "· $_" }) -join "`n" } else { '（无）' }) +
              "`n`n失败原因：$($r.BackupError)" +
              $(if ($r.Backup) { "`n`n已抢救出部分备份：$(Split-Path -Leaf $r.Backup)，「还原设置」可还原其中已记录的部分。" }) +
              "`n`n其余项如需回退，请按上面的项名手动处理，或点「上传诊断报告」联系开发者。"
      Show-ConfirmDialog '备份写入失败' 'BACKUP WRITE FAILED' $warn '我已知晓' -InfoOnly | Out-Null
    }
    Write-Log "执行完成：共 $total 项 — $okN 成功、$($failList.Count) 失败、$($skipList.Count) 跳过$(if ($attList.Count -gt 0) { "、$($attList.Count) 项体检发现问题" })。"
    # 日志在另一页了：有失败/体检问题就给标签打角标，提示那边有内容值得看
    Set-LogBadge ($failList.Count + $attList.Count)
    if ($failList.Count -gt 0) {
      # 失败明细也在优化页当场列出，用户不必为了看结果切页
      $ui.ProgText.Text = "执行完成：$okN 成功 / $($failList.Count) 失败 / $($skipList.Count) 跳过$att —— 失败：$(@($failList | ForEach-Object { $_.Name }) -join '、')"
      Write-Log "以下 $($failList.Count) 项失败，请把日志原文反馈或运行 scripts\diagnose.ps1 排查："
      foreach ($x in $failList) { Write-Log "  [失败] $($x.Name) — $($x.Msg)" }
    }
    if ($attList.Count -gt 0) {
      Write-Log "体检发现以下问题（工具改不了，需按提示手动处理）："
      foreach ($x in $attList) { Write-Log "  [提示] $($x.Name) — $($x.Msg)" }
      # 日志里的纯文本链接没人会手抄（实机反馈）：弹对话框给逐步教程和可点击的下载按钮
      Show-HealthDialog $attList
    }
    Update-ItemList
    # 醒目的重启提醒取代此前日志末尾的一行小字（实机反馈根本注意不到）：
    # 引擎已在每条结果上标好 Reboot（成功且确需重启才为 true），全失败/全即时项不弹
    $rebootList = @($r.Results | Where-Object { $_.Reboot })
    if ($rebootList.Count -gt 0) {
      $rebootNames = @($rebootList | ForEach-Object { $_.Name })
      Write-Log "以下 $($rebootList.Count) 个成功项需重启电脑后完全生效：$($rebootNames -join '、')。"
      if (Show-RebootDialog $rebootNames) {
        Start-ConfirmedSystemReboot
      } else { Write-Log '你选择了稍后重启，优化项将在下次重启后完全生效。' }
    }
  } catch {
    $failure = Get-ApplyFailureContext $_ $adminBatchReturned $r
    if ($failure.AdminBatchReturned) {
      Write-Log "执行收尾失败：$($failure.ErrorMessage)"
      if ($failure.BackupPath -and -not $adminBatchBackupLogged) {
        Write-Log "备份已保存：$($failure.BackupPath)"
      }
      Write-Log '！！系统批次可能已执行，请不要重复点击「执行优化」；请优先点击「还原设置」，若没有可用备份则点击「重新检测」确认当前状态。'
    } else {
      # 会话异常、路径无效、参数校验等前置失败仍把原始错误原文直接给用户。
      Write-Log "执行失败：$($failure.ErrorMessage)"
    }
    Write-Log "异常类型：$($failure.ExceptionType)"
    Write-Log "ScriptStackTrace：$($failure.ScriptStackTrace)"
    if ($failure.AdminBatchReturned) {
      Show-ConfirmDialog '执行收尾未完成' 'APPLY FINALIZATION FAILED' $failure.UserMessage '知道了' -InfoOnly | Out-Null
    } else {
      Show-ConfirmDialog '执行未完成' 'APPLY NOT COMPLETED' $failure.UserMessage '知道了' -InfoOnly | Out-Null
    }
  }
  finally { Set-BusyState $false }
})

$ui.RestoreBtn.Add_Click({
  if ($script:Busy) { return }
  if ($ui.InlineRestorePanel.Visibility -eq 'Visible') {
    Hide-InlineRestorePanel
    return
  }
  $busySet = $false
  try {
    if (Test-TuningExperimentActive) { throw '自动调优实验期间禁止普通还原；请使用「停止并回滚」只处理本实验备份' }
    Set-BusyState $true; $busySet = $true
    $catalog = Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems
    Set-BusyState $false; $busySet = $false
    Initialize-InlineRestorePanel $catalog
  } catch {
    $err = $_.Exception.Message
    Write-Log "复原项目读取失败：$err"
    Show-ConfirmDialog '还原记录读取失败' 'RESTORE LIST NOT AVAILABLE' $err '知道了' -InfoOnly | Out-Null
  } finally {
    if ($busySet -or $script:Busy) { Set-BusyState $false }
    Update-InlineRestoreSelection
  }
})

$ui.InlineRestoreCloseBtn.Add_Click({ Hide-InlineRestorePanel })
$ui.InlineRestoreSelectAllBtn.Add_Click({
  foreach ($box in @($script:InlineRestoreChecks.ToArray())) {
    if ($box.IsEnabled) { $box.IsChecked = $true }
  }
  Update-InlineRestoreSelection
})
$ui.InlineRestoreClearBtn.Add_Click({
  foreach ($box in @($script:InlineRestoreChecks.ToArray())) { $box.IsChecked = $false }
  Update-InlineRestoreSelection
})
$ui.InlineRestoreSelectedBtn.Add_Click({ Invoke-InlineRestoreAction 'selected_items' })
$ui.InlineRestoreAllBtn.Add_Click({ Invoke-InlineRestoreAction 'all' })
# 在任何窗口出现前恢复用户上次的主题与窗口高度；旧版偏好没有高度时默认使用 1200。
Set-AppTheme (Get-SavedAppTheme)
Set-SavedAppWindowHeight
# 免责声明门控放在主窗口之前：没同意就不该看到任何可点的优化按钮。
# 读取/写入配置失败一律按「没同意」处理——宁可多问一次，也不能因为磁盘异常就放行
if (-not (Test-DisclaimerAccepted)) {
  if (-not (Show-DisclaimerDialog)) { Invoke-AppExit }
}

$window.ShowDialog() | Out-Null
# 主窗口关闭就是本次会话的终点。通知/更新检查等后台 PowerShell runspace 即使窗口已
# 消失，仍可能让 powershell.exe、EngineHost 和启动器继续存活并占住全局单实例锁；
# Closing 已完成偏好保存、忙碌保护与实时监控清理，这里用进程级退出收尾。
Invoke-AppExit
