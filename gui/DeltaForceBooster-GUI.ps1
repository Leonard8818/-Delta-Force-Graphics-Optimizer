<#
  DeltaForceBooster 图形界面 — v0.21.2
  视觉基准：三角洲行动国服官网 df.qq.com 实测提炼：近黑微青顶栏 #0D1417 + 页面青绿细
  渐变 #0A1512→#10201C + 正绿 CTA #00E884（斜切角 + 等高线纹理）+ 金色分类标签 #E5C46A
  + 中英上下叠排分区标题 + 侧边刻度尺装饰 + 拉字距装饰分隔线。

  v0.21.2：修复了一些已知问题。
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
    [Parameter(Mandatory)][ValidateSet('MigrateLegacyData','ClearShaderCache','GetGpuPanelApps','GetNvAutoOptStatus','OpenUrl','OpenGpuPanel')][string]$Action,
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
if ([bool]$needsUacRepair -ne [bool]$script:RepairOnlySession) {
  Stop-UntrustedGuiStartup 'EngineHost 修复会话与当前 UAC 策略不匹配'
}
if ($needsUacRepair) {
    $repairPrompt = $(if ($isBuiltInAdministrator) {
      "检测到当前账户是 Windows 内置 Administrator（RID 500），并且 UAC 或此账户的「管理员审批模式」未开启。`n`n点击「是」：以网吧兼容模式继续，本次不修改安全策略，也不要求重启；核心优化与还原可用，用户缓存清理、显卡软件检测和外链入口会停用。`n点击「否」：开启 UAC 与管理员审批模式，保存后退出；设置在下次重启后生效。`n点击「取消」：不修改并退出。"
    } else {
      "检测到 Windows 的「用户账户控制（UAC）」已被关闭。`n`n点击「是」：以网吧兼容模式继续，本次不修改 UAC，也不要求重启；核心优化与还原可用，用户缓存清理、显卡软件检测和外链入口会停用。`n点击「否」：恢复 UAC，保存后退出；设置在下次重启后生效。`n点击「取消」：不修改并退出。"
    })
    $choice = [Windows.MessageBox]::Show(
      $repairPrompt,
      '三角洲行动 · 画面优化助手', [Windows.MessageBoxButton]::YesNoCancel, [Windows.MessageBoxImage]::Warning)
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

# 同一台电脑只保留一个主程序实例。用全局命名 Mutex 而不是枚举 powershell.exe：启动器、
# bat 和直接运行 ps1 最终都会经过这里，同时不会误伤用户开的其他 PowerShell 窗口。
$createdNew = $false
$script:InstanceMutex = [Threading.Mutex]::new($true, 'Global\DeltaForceBooster.GUI', [ref]$createdNew)
if (-not $createdNew) {
  Add-Type -AssemblyName PresentationFramework
  [Windows.MessageBox]::Show('软件已经在运行，请使用已经打开的窗口。', '三角洲行动 · 画面优化助手', 'OK', 'Information') | Out-Null
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

# 界面版本号：标题栏徽标 / 页脚 / 更新检查共用同一处定义，避免三处漂移
$script:GuiVersion = '0.21.2'
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
        Title="三角洲行动 · 画面优化助手" Width="780" Height="860"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="CanResize"
        BorderBrush="#FF1B2E28" BorderThickness="1"
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
    <SolidColorBrush x:Key="GreenLine" Color="#FF17603F"/>
    <SolidColorBrush x:Key="Gold"      Color="#FFE5C46A"/>
    <SolidColorBrush x:Key="GoldDark"  Color="#FF3A2C0C"/>
    <SolidColorBrush x:Key="Danger"    Color="#FFE5484D"/>

    <!-- 官网下载按钮同款：绿色实底之上叠一层略暗的等高线纹路（战术地图质感）。
         用 DrawingBrush 平铺而不是 Path 叠加：笔画粗细不随控件尺寸缩放（教训 #3） -->
    <DrawingBrush x:Key="CtaFill" TileMode="Tile" Viewport="0,0,64,40" ViewportUnits="Absolute"
                  Viewbox="0,0,64,40" ViewboxUnits="Absolute">
      <DrawingBrush.Drawing>
        <DrawingGroup>
          <GeometryDrawing Brush="#FF00E884">
            <GeometryDrawing.Geometry>
              <RectangleGeometry Rect="0,0,64,40"/>
            </GeometryDrawing.Geometry>
          </GeometryDrawing>
          <GeometryDrawing>
            <GeometryDrawing.Pen>
              <Pen Brush="#4C043C28" Thickness="1"/>
            </GeometryDrawing.Pen>
            <GeometryDrawing.Geometry>
              <PathGeometry Figures="M 0,7 C 12,3 22,12 34,8 C 46,4 56,11 64,7 M 0,20 C 10,25 24,15 36,21 C 48,26 58,18 64,20 M 0,33 C 14,29 28,37 42,32 C 52,28 60,35 64,33"/>
            </GeometryDrawing.Geometry>
          </GeometryDrawing>
        </DrawingGroup>
      </DrawingBrush.Drawing>
    </DrawingBrush>

    <Style x:Key="TacCheck" TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border Background="Transparent" Padding="0,3">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="Box" Width="13" Height="13" BorderBrush="#FF2C443B"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Center">
                  <Grid>
                    <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="#FF04241B"
                          StrokeThickness="2" Visibility="Collapsed"/>
                    <!-- 第三态（部分选中）：绿色小方块。只有全选框会进入此态，
                         普通项复选框永远只在勾/不勾之间切换 -->
                    <Border x:Name="PartMark" Width="7" Height="7" Background="#FF00E884"
                            HorizontalAlignment="Center" VerticalAlignment="Center"
                            Visibility="Collapsed"/>
                  </Grid>
                </Border>
                <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="#FF00E884"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="{x:Null}">
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="PartMark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网次级动作样式：绿色细描边 + 绿色文字 + 内容居中 -->
    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="#FF00E884"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网主 CTA：斜切角 + 等高线纹理 + 深色字；hover 用白色薄罩提亮而不是换色，
         保住纹理层不被覆盖 -->
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="#FF04241B"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Height" Value="38"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <!-- 几何用 0–1 归一化坐标：Path 的期望尺寸即为 1x1，不会把按钮撑大，Stretch 再拉满 -->
              <Path x:Name="Bg" Stretch="Fill" Fill="{StaticResource CtaFill}"
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
      <Setter Property="Foreground" Value="#FF9AA5A0"/>
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
                <Setter TargetName="B" Property="Background" Value="#FF14241F"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- 官网行首分类标签同款：金色实底 + 深色粗体字（官网用于「赛事」「公告」） -->
    <Style x:Key="Chip" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource Gold}"/>
      <Setter Property="Padding" Value="7,1"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="ChipText" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource GoldDark}"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>

    <!-- 中英上下叠排分区标题：中文白粗体在上、小号大写英文在下、绿色短下划线
         （官网标签页选中态：绿色文字 + 底部绿色下划线，这里移植为分区标识） -->
    <Style x:Key="HeadCn" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource TextPri}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontWeight" Value="Bold"/>
    </Style>
    <Style x:Key="HeadEn" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="8"/>
      <Setter Property="Foreground" Value="{StaticResource TextMut}"/>
      <Setter Property="Margin" Value="1,1,0,0"/>
    </Style>
    <Style x:Key="HeadBar" TargetType="Border">
      <Setter Property="Height" Value="2"/>
      <Setter Property="Width" Value="28"/>
      <Setter Property="Background" Value="{StaticResource Green}"/>
      <Setter Property="HorizontalAlignment" Value="Left"/>
      <Setter Property="Margin" Value="0,4,0,0"/>
    </Style>

    <Style x:Key="Mono" TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Foreground" Value="{StaticResource TextMut}"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <!-- 标签页按钮：官网标签页手法——选中项绿色文字 + 底部绿色下划线，未选中灰色。
         不用 WPF TabControl：其默认模板白底黑字，整套重模板不如自绘两个按钮可控 -->
    <Style x:Key="TabBtn" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Foreground" Value="{StaticResource TextSec}"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="16,9,16,11"/>
              <Border x:Name="UL" Height="2" Background="{StaticResource Green}" VerticalAlignment="Bottom"
                      Margin="12,0" Visibility="Collapsed"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="Tag" Value="on">
                <Setter TargetName="UL" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="{StaticResource Green}"/>
                <Setter Property="FontWeight" Value="Bold"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="{StaticResource Green}"/>
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
      <Setter Property="Foreground" Value="{StaticResource TextMut}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
    </Style>
    <Style x:Key="TickMajor" TargetType="Border">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{StaticResource LineHi}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,5"/>
    </Style>
    <Style x:Key="TickMinor" TargetType="Border">
      <Setter Property="Width" Value="4"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{StaticResource LineSoft}"/>
      <Setter Property="HorizontalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="0,5"/>
    </Style>
    <!-- 装饰分隔线的短横段：「— — — 中 文 — — —」 -->
    <Style x:Key="Dash" TargetType="Border">
      <Setter Property="Width" Value="14"/>
      <Setter Property="Height" Value="1"/>
      <Setter Property="Background" Value="{StaticResource LineHi}"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Margin" Value="4,0"/>
    </Style>

    <!-- 深色滚动条样式已移入 $script:ThemeResXaml 共享资源字典（v0.13）：
         对话框是独立 Window 不继承这里的资源，样式只放主窗口时对话框滚动条仍是
         系统白色（实机反馈）。主窗口在 Parse 后 MergedDictionaries 引同一份实例 -->

    <!-- 深色主题 ComboBox：默认白底模板在本主题下刺眼，整体重做。
         选中项文字用品牌绿——官网列表强调项就是整行绿色 -->
    <Style x:Key="TacComboItem" TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="#FF9AA5A0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="BD" Background="Transparent" Padding="10,5">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="BD" Property="Background" Value="#FF12291F"/>
                <Setter Property="Foreground" Value="#FF00E884"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="BD" Property="Background" Value="#FF0F2118"/>
                <Setter Property="Foreground" Value="#FF00E884"/>
                <Setter Property="FontWeight" Value="Bold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="TacCombo" TargetType="ComboBox">
      <Setter Property="Foreground" Value="#FF00E884"/>
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
                    <Border x:Name="BD" Background="#FF0B1712" BorderBrush="#FF2C443B" BorderThickness="1">
                      <Path Data="M 0,0 L 8,0 L 4,5 Z" Fill="#FF00E884"
                            HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,9,0"/>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="BD" Property="BorderBrush" Value="#FF00E884"/>
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
                <Border Background="#FF0E1B17" BorderBrush="#FF2C443B" BorderThickness="1"
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
    <Border x:Name="TitleBar" Grid.Row="0" Background="{StaticResource TopBar}"
            BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1">
      <Grid>
        <StackPanel Orientation="Horizontal" Margin="14,10">
          <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF00E884" VerticalAlignment="Center"/>
          <TextBlock Text="DELTA FORCE" Foreground="{StaticResource TextPri}" FontSize="13"
                     FontWeight="Bold" Margin="10,0,0,0" VerticalAlignment="Center">
            <TextBlock.LayoutTransform><ScaleTransform ScaleX="1.05"/></TextBlock.LayoutTransform>
          </TextBlock>
          <Border Width="1" Height="13" Background="#FF2C443B" Margin="11,0"/>
          <TextBlock Text="画面优化助手" Foreground="{StaticResource TextSec}" FontSize="12" VerticalAlignment="Center"/>
          <TextBlock Text="[ v0.21.2 ]" Style="{StaticResource Mono}" Foreground="{StaticResource Green}" Margin="9,0,0,0"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <!-- 手动检查更新：用户要求放在最上方。与右侧「有新版本」胶囊分工不同——
               胶囊只在已发现新版时出现，这个按钮任何时候都能主动查一次 -->
          <Button x:Name="CheckUpdBtn" Content="检查更新" Style="{StaticResource Ghost}"
                  Height="24" FontSize="11" VerticalAlignment="Center" Margin="0,0,10,0"/>
          <!-- Discord 式更新入口：检测到新版本才出现的小绿胶囊，点击弹更新详情。
               图标用固定坐标小 Path（不加 Stretch）：归一化坐标 + Stretch 会被撑大（教训 #3） -->
          <Button x:Name="UpdateBtn" Visibility="Collapsed" VerticalAlignment="Center" Margin="0,0,10,0"
                  Foreground="#FF04241B" Cursor="Hand">
            <Button.Template>
              <ControlTemplate TargetType="Button">
                <Border x:Name="B" Background="#FF00E884" CornerRadius="10" Padding="9,3">
                  <StackPanel Orientation="Horizontal">
                    <Path Data="M 3,0 L 6,0 L 6,4 L 9,4 L 4.5,9 L 0,4 L 3,4 Z M 0,11 L 9,11 L 9,12.5 L 0,12.5 Z"
                          Fill="#FF04241B" Width="9" Height="13" VerticalAlignment="Center"/>
                    <TextBlock Text="有新版本" FontSize="11" FontWeight="Bold" Foreground="#FF04241B"
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

    <!-- 标签页导航：优化 / 自动调优 / 游戏内设置参考 / 运行日志 -->
    <Border Grid.Row="1" Background="{StaticResource TopBar}" BorderBrush="{StaticResource Line}"
            BorderThickness="0,0,0,1">
      <StackPanel Orientation="Horizontal" Margin="15,0,0,0">
        <Button x:Name="TabOptBtn" Content="优化" Style="{StaticResource TabBtn}" Tag="on"/>
        <Button x:Name="TabTuneBtn" Content="自动调优 Beta" Style="{StaticResource TabBtn}" Tag=""/>
        <Button x:Name="TabRefBtn" Content="游戏内设置参考" Style="{StaticResource TabBtn}" Tag=""/>
        <Button x:Name="TabLogBtn" Style="{StaticResource TabBtn}" Tag="">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="运行日志" VerticalAlignment="Center"/>
            <!-- 角标：日志挪到独立页后，出了失败/体检问题得有个「这里有东西该看」的信号。
                 前景色写死，免得被标签页选中态的 Foreground 触发器染成绿色 -->
            <Border x:Name="LogBadge" Visibility="Collapsed" Background="{StaticResource Danger}"
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
      <Path Grid.Column="1" Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF00E884" Opacity="0.03"
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
            <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                    VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <TextBlock Grid.Column="2" x:Name="ScanState" Text="检测中…" Style="{StaticResource Mono}"
                       Foreground="{StaticResource Green}" VerticalAlignment="Bottom" Margin="0,0,0,2"/>
          </Grid>

          <UniformGrid x:Name="HwGrid" Columns="3" Margin="0,0,0,7"/>

          <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}"
                  BorderThickness="1" Padding="8,4" Margin="0,0,0,11">
            <StackPanel Orientation="Horizontal">
              <Border Style="{StaticResource Chip}">
                <TextBlock Text="目标程序" Style="{StaticResource ChipText}"/>
              </Border>
              <TextBlock x:Name="GameText" Text="定位中…" Style="{StaticResource Mono}"
                         Foreground="{StaticResource TextPri}" Margin="10,0,0,0"
                         TextTrimming="CharacterEllipsis" MaxWidth="470"/>
              <Button x:Name="BrowseBtn" Content="重新定位" Style="{StaticResource Ghost}"
                      Margin="12,0,0,0" FontSize="11" Height="24"/>
            </StackPanel>
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
            <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                    VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <TextBlock Grid.Column="2" x:Name="CountText" Text="" Style="{StaticResource Mono}"
                       Foreground="{StaticResource TextSec}" VerticalAlignment="Bottom" Margin="0,0,0,2"/>
          </Grid>

          <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}"
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

          <Border BorderBrush="{StaticResource Line}" BorderThickness="1" Background="{StaticResource PanelDeep}">
            <StackPanel>
              <!-- 全选行（实机诉求）：三态仅作展示——部分选中显示第三态，点击只在
                   全选/全不选之间切换；只圈「可执行」项，已就绪项重复执行只会撑大备份 -->
              <Border Background="#FF0C1915" BorderBrush="{StaticResource LineSoft}"
                      BorderThickness="0,0,0,1" Padding="10,3">
                <Grid>
                  <CheckBox x:Name="SelAllChk" Style="{StaticResource TacCheck}" VerticalAlignment="Center">
                    <TextBlock Text="全选" Foreground="#FFFFFFFF" FontSize="12" FontWeight="Bold"/>
                  </CheckBox>
                  <TextBlock Text="只圈可执行项 · 已就绪的不重复执行" FontFamily="Consolas" FontSize="10"
                             Foreground="{StaticResource TextMut}" HorizontalAlignment="Right"
                             VerticalAlignment="Center"/>
                </Grid>
              </Border>
              <StackPanel x:Name="ItemPanel"/>
            </StackPanel>
          </Border>

          <Expander x:Name="RiskyGroup" Margin="0,10,0,0" Visibility="Collapsed" IsExpanded="True" Foreground="{StaticResource TextPri}">
            <Expander.Header>
              <StackPanel Orientation="Horizontal">
                  <TextBlock Text="★ 显卡型号伪装" Foreground="{StaticResource TextPri}" FontSize="12"/>
                <TextBlock Text="按显卡代际推荐 · 可手动选择目标型号" Style="{StaticResource Mono}" Margin="10,0,0,0"/>
              </StackPanel>
            </Expander.Header>
            <Border BorderBrush="{StaticResource Line}" BorderThickness="1" Background="{StaticResource PanelDeep}" Margin="0,6,0,0">
              <StackPanel x:Name="RiskyPanel"/>
            </Border>
          </Expander>

          <!-- 官网招牌装饰分隔线：两侧短横段 + 中间拉开字距的中文 -->
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,14,0,4">
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <Border Style="{StaticResource Dash}"/>
            <TextBlock Text="系 统 优 化 · 改 前 备 份 · 一 键 还 原" Foreground="{StaticResource TextMut}"
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
            <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}" VerticalAlignment="Bottom" Margin="12,0,12,4"/>
            <Border Grid.Column="2" Background="{StaticResource GoldDark}" BorderBrush="{StaticResource Gold}" BorderThickness="1" Padding="7,2" VerticalAlignment="Bottom">
              <TextBlock Text="RULES / BETA" Foreground="{StaticResource Gold}" FontFamily="Consolas" FontSize="9" FontWeight="Bold"/>
            </Border>
          </Grid>

          <Border Background="#FF0E2A21" BorderBrush="{StaticResource GreenLine}" BorderThickness="1" Padding="11,8" Margin="0,0,0,9">
            <StackPanel>
              <TextBlock Text="固定目标：提高 1% 低帧率和流畅度" Foreground="{StaticResource Green}" FontSize="13" FontWeight="Bold"/>
              <TextBlock Text="这是确定性规则实验，不是 AI。候选仅来自内置低风险库，显卡型号伪装等 risky 项永不会自动加入。" Foreground="{StaticResource TextSec}" TextWrapping="Wrap" Margin="0,4,0,0"/>
              <TextBlock Text="个体内规则实验，不代表全局最优。" Foreground="{StaticResource Gold}" FontWeight="Bold" Margin="0,3,0,0"/>
            </StackPanel>
          </Border>

          <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="11,9" Margin="0,0,0,9">
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="108"/><ColumnDefinition Width="135"/><ColumnDefinition Width="112"/></Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0" Margin="0,0,10,0">
                <TextBlock Text="固定场景标识（2–80字）" Foreground="{StaticResource TextSec}" FontSize="10"/>
                <TextBox x:Name="TuneSceneBox" Height="27" Margin="0,4,0,0" Padding="7,4" MaxLength="80"
                         Background="{StaticResource PanelDeep}" BorderBrush="{StaticResource LineHi}" BorderThickness="1" Foreground="{StaticResource TextPri}"/>
              </StackPanel>
              <StackPanel Grid.Column="1" Margin="0,0,10,0">
                <TextBlock Text="最大温升（0–7°C）" Foreground="{StaticResource TextSec}" FontSize="10"/>
                <TextBox x:Name="TuneTempBox" Text="3" Height="27" Margin="0,4,0,0" Padding="7,4" MaxLength="3"
                         Background="{StaticResource PanelDeep}" BorderBrush="{StaticResource LineHi}" BorderThickness="1" Foreground="{StaticResource TextPri}"/>
              </StackPanel>
              <StackPanel Grid.Column="2" Margin="0,0,10,0">
                <TextBlock Text="功耗策略" Foreground="{StaticResource TextSec}" FontSize="10"/>
                <CheckBox x:Name="TunePowerChk" Style="{StaticResource TacCheck}" Margin="0,6,0,0">
                  <TextBlock Text="允许更高功耗" Foreground="{StaticResource TextPri}"/>
                </CheckBox>
              </StackPanel>
              <StackPanel Grid.Column="3">
                <TextBlock Text="最大增幅（0–20%）" Foreground="{StaticResource TextSec}" FontSize="10"/>
                <TextBox x:Name="TunePowerBox" Text="0" Height="27" Margin="0,4,0,0" Padding="7,4" MaxLength="4" IsEnabled="False"
                         Background="{StaticResource PanelDeep}" BorderBrush="{StaticResource LineHi}" BorderThickness="1" Foreground="{StaticResource TextPri}"/>
              </StackPanel>
            </Grid>
          </Border>

          <UniformGrid Columns="4" Margin="0,0,0,9">
            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="9,7" Margin="0,0,5,0"><StackPanel><TextBlock Text="实验状态" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneStatusText" Text="未创建" Foreground="{StaticResource Green}" FontWeight="Bold" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="9,7" Margin="0,0,5,0"><StackPanel><TextBlock Text="当前方案 / 轮次" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneRoundText" Text="-" Foreground="{StaticResource TextPri}" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="9,7" Margin="0,0,5,0"><StackPanel><TextBlock Text="基线稳定性" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneBaselineText" Text="待采样" Foreground="{StaticResource TextPri}" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
            <Border Background="{StaticResource Panel}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="9,7"><StackPanel><TextBlock Text="当前保留组合" Style="{StaticResource Mono}"/><TextBlock x:Name="TuneCurrentText" Text="基线" Foreground="{StaticResource TextPri}" Margin="0,3,0,0" TextWrapping="Wrap"/></StackPanel></Border>
          </UniformGrid>

          <Grid Margin="0,0,0,9">
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="{StaticResource PanelDeep}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="9,6" Margin="0,0,5,0"><TextBlock x:Name="TuneG1Text" Text="G1 后台与游戏模式：待实验" Foreground="{StaticResource TextSec}" TextWrapping="Wrap"/></Border>
            <Border Grid.Column="1" Background="{StaticResource PanelDeep}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="9,6" Margin="0,0,5,0"><TextBlock x:Name="TuneG2Text" Text="G2 前台调度：待实验" Foreground="{StaticResource TextSec}" TextWrapping="Wrap"/></Border>
            <Border Grid.Column="2" Background="{StaticResource PanelDeep}" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="9,6"><TextBlock x:Name="TuneG3Text" Text="G3 显示与 GPU 选择：待实验" Foreground="{StaticResource TextSec}" TextWrapping="Wrap"/></Border>
          </Grid>

          <Border Background="{StaticResource PanelDeep}" BorderBrush="{StaticResource Line}" BorderThickness="1" Margin="0,0,0,9">
            <StackPanel>
              <Grid Background="#FF0C1915" Margin="0" Height="25">
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

          <TextBlock x:Name="TuneHintText" Text="创建实验后，每次按「执行下一步」完成 120 秒同场景采样。实验可稍后继续。" Foreground="{StaticResource TextSec}" TextWrapping="Wrap" Margin="1,0,1,8"/>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="TuneCreateBtn" Content="创建 / 继续实验" Style="{StaticResource Primary}" Width="210"/>
            <Button x:Name="TuneNextBtn" Content="执行下一步" Style="{StaticResource Ghost}" Width="145" Margin="9,0,0,0"/>
            <Button x:Name="TuneStopBtn" Content="停止并回滚" Style="{StaticResource Ghost}" Width="135" Margin="9,0,0,0"/>
          </StackPanel>
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
        <Border Grid.Column="1" Height="1" Background="{StaticResource LineSoft}"
                VerticalAlignment="Bottom" Margin="12,0,12,4"/>
        <!-- 一键复制：反馈问题时直接整段拷走，不用在小窗里手动拖选。
             图标 Path 用固定坐标（不加 Stretch）：归一化坐标 + Stretch 会被撑大（教训 #3） -->
        <Button x:Name="CopyLogBtn" Grid.Column="2" Style="{StaticResource Ghost}" Height="24"
                FontSize="11" VerticalAlignment="Bottom" ToolTip="复制全部日志到剪贴板">
          <StackPanel Orientation="Horizontal">
            <Path Data="M 0,3 L 0,11 L 6,11 L 6,3 Z M 3,0 L 9,0 L 9,8 L 6,8" Stroke="#FF00E884"
                  StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center"/>
            <TextBlock x:Name="CopyLogTxt" Text="复制" Margin="5,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
      </Grid>
      <Border Grid.Row="1" Background="{StaticResource LogBg}" BorderBrush="{StaticResource Line}" BorderThickness="1">
        <TextBox x:Name="LogBox" IsReadOnly="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="Transparent"
                 Foreground="#FF9AA5A0" FontFamily="Consolas" FontSize="11" Padding="10,7"/>
      </Border>
      <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,9,0,0">
        <!-- 把诊断信息打包发给作者排查；上传前列清单请用户确认，不会静默发送 -->
        <Button x:Name="ReportBtn" Content="上传完整诊断" Style="{StaticResource Ghost}" Width="132"/>
        <TextBlock Text="上传前会列出内容并请你确认，路径中的用户名会脱敏" Style="{StaticResource Mono}"
                   Margin="12,0,0,0"/>
      </StackPanel>
    </Grid>

    <StackPanel Grid.Row="3" x:Name="ActionRow" Margin="29,6,29,8">
      <StackPanel Orientation="Horizontal">
        <!-- 主 CTA：绿色实底 + 深色字 + 左侧图标（官网下载按钮三要素） -->
        <Button x:Name="ApplyBtn" Style="{StaticResource Primary}" Width="230">
          <StackPanel Orientation="Horizontal">
            <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF04241B"
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
        <Border x:Name="ProgTrack" Height="6" Background="{StaticResource PanelDeep}"
                BorderBrush="{StaticResource Line}" BorderThickness="1">
          <Border x:Name="ProgFill" Background="{StaticResource Green}" HorizontalAlignment="Left" Width="0"/>
        </Border>
        <Grid Margin="0,5,0,0">
          <!-- 换行而不是截断：执行完成后这里要放下汇总 + 失败项名，截掉就等于没说 -->
          <TextBlock x:Name="ProgText" Style="{StaticResource Mono}" Foreground="{StaticResource TextSec}"
                     Text="" TextWrapping="Wrap" HorizontalAlignment="Left" Margin="0,0,120,0"/>
          <TextBlock x:Name="ProgCount" Style="{StaticResource Mono}" Foreground="{StaticResource Green}"
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
      <Border Grid.Column="1" Width="26" Height="2" Background="{StaticResource Gold}" VerticalAlignment="Center" Margin="9,0,0,0"/>
      <Border Grid.Column="2" Height="1" Background="{StaticResource LineSoft}" VerticalAlignment="Center" Margin="9,0"/>
      <Border Grid.Column="3" Width="5" Height="5" BorderBrush="{StaticResource Green}" BorderThickness="1" VerticalAlignment="Center" Margin="0,0,9,0"/>
      <StackPanel Grid.Column="4" Orientation="Horizontal">
        <TextBlock Text="[ V0.21.2 ] 改动前自动备份 · 可一键还原设置" Style="{StaticResource Mono}" FontSize="9"/>
        <!-- 随时可重看免责声明：首次启动的门控之外也得留个常驻入口 -->
        <Button x:Name="DisclaimerBtn" Style="{StaticResource Ghost}" Height="17" FontSize="9"
                Margin="10,0,0,0" Content="免责声明"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
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
                      <Border Background="#FF2C443B" CornerRadius="3"/>
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
                          <Border Background="#FF2C443B" CornerRadius="3"/>
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
    <Setter Property="Background" Value="#FF0E1B17"/>
    <Setter Property="BorderBrush" Value="#FF2C443B"/>
    <Setter Property="Foreground" Value="#FF9AA5A0"/>
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
    <Setter Property="Background" Value="#FF0E1B17"/>
    <Setter Property="BorderBrush" Value="#FF2C443B"/>
    <Setter Property="Foreground" Value="#FF9AA5A0"/>
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
    <Setter Property="Foreground" Value="#FF9AA5A0"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="MenuItem">
          <Border x:Name="BD" Background="Transparent" Padding="12,5">
            <ContentPresenter ContentSource="Header" RecognizesAccessKey="True"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsHighlighted" Value="True">
              <Setter TargetName="BD" Property="Background" Value="#FF12291F"/>
              <Setter Property="Foreground" Value="#FF00E884"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter Property="Foreground" Value="#FF4A554F"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="Separator">
    <Setter Property="Background" Value="#FF1B2E28"/>
    <Setter Property="Height" Value="1"/>
    <Setter Property="Margin" Value="4,2"/>
  </Style>
  <!-- 文本选中色：默认的系统蓝在青绿主题里最扎眼；焦点虚线框一并去掉 -->
  <Style TargetType="TextBox">
    <Setter Property="SelectionBrush" Value="#8000E884"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
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
foreach ($n in 'TitleBar','MinBtn','CloseBtn','UpdateBtn','ScanState','HwGrid','GameText','BrowseBtn','CountText',
               'SelAllChk',
               'ItemPanel','RiskyGroup','RiskyPanel','ApplyBtn','RestoreBtn','RefreshBtn','GuideBtn','CheckUpdBtn',
               'ReportBtn','DisclaimerBtn','LogBox',
               'PresetBox','SavePresetBtn','DelPresetBtn','PresetNote',
               'TabOptBtn','TabTuneBtn','TabRefBtn','TabLogBtn','LogBadge','LogBadgeTxt',
               'OptPage','TunePage','RefPage','LogPage','RefPanel','ActionRow',
               'TuneSceneBox','TuneTempBox','TunePowerChk','TunePowerBox',
               'TuneStatusText','TuneRoundText','TuneBaselineText','TuneCurrentText',
               'TuneG1Text','TuneG2Text','TuneG3Text','TuneRunPanel','TuneHintText',
               'TuneCreateBtn','TuneNextBtn','TuneStopBtn',
               'ProgressPanel','ProgTrack','ProgFill','ProgText','ProgCount','CopyLogBtn','CopyLogTxt') {
  $ui[$n] = $window.FindName($n)
}

# ---------- 主题化小部件构造（配色同 XAML：国服官网青绿渐变底 + 正绿 #00E884 + 金标签） ----------

$script:C = @{
  Panel = '#FF0E1B17'; Line = '#FF1B2E28'; LineSoft = '#FF16241F'
  TextPri = '#FFFFFFFF'; TextSec = '#FF9AA5A0'; TextMut = '#FF7A8580'
  Green = '#FF00E884'; GreenDark = '#FF04241B'; Gold = '#FFE5C46A'; GoldDark = '#FF3A2C0C'
  Gray = '#FF7A8580'
}
function New-Brush([string]$Hex) { (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex) }

function New-Text([string]$Content, [string]$Color, [int]$Size, [switch]$Mono) {
  $t = New-Object Windows.Controls.TextBlock
  $t.Text = $Content
  $t.Foreground = New-Brush $Color
  $t.FontSize = $Size
  $t.VerticalAlignment = 'Center'
  if ($Mono) { $t.FontFamily = New-Object Windows.Media.FontFamily 'Consolas' }
  $t
}

function New-HwCard([string]$Label, [string]$Value, [string]$Sub, [switch]$Ribbon) {
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
  $sp.Children.Add($head) | Out-Null
  $v = New-Text $Value $script:C.TextPri 12
  $v.TextTrimming = 'CharacterEllipsis'
  $sp.Children.Add($v) | Out-Null
  $sp.Children.Add((New-Text $Sub $script:C.TextSec 10 -Mono)) | Out-Null
  $b.Child = $sp
  # 官网小卡片右上角的金色三角角标：这里用来标记主力硬件（如主显卡）
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

function Update-Count {
  $rows = @($ui.ItemPanel.Children)
  $sel = @($rows | Where-Object { $_.Child.Children[0].IsChecked }).Count
  # 「可执行」= 未处于已就绪/正常态的项（行 Tag 存的是检测到的 Optimized 状态）
  $oper = @($rows | Where-Object { $_.Tag -ne $true })
  $ui.CountText.Text = "已选 $sel / $($rows.Count) · 可执行 $($oper.Count)"
  # 全选框三态回显：程序赋值不触发 Click，不会与点击处理器互相递归
  if ($ui.SelAllChk) {
    $operLeft = @($oper | Where-Object { -not $_.Child.Children[0].IsChecked }).Count
    $ui.SelAllChk.IsChecked = $(if ($sel -eq 0) { $false }
                                elseif ($oper.Count -gt 0 -and $operLeft -eq 0) { $true }
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

  $g = New-Object Windows.Controls.Grid
  foreach ($w in 'Auto', '*', 'Auto') {
    $c = New-Object Windows.Controls.ColumnDefinition
    $c.Width = [Windows.GridLength]::Auto
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
  $cb.Content = New-Text "$($Item.Name)$(if ($Item.Admin) { ' *' })" $nameColor 12
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

  $detail = New-Text $State.Current $script:C.TextMut 11 -Mono
  $detail.Margin = New-Object Windows.Thickness 12, 0, 12, 0
  $detail.TextTrimming = 'CharacterEllipsis'
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
    foreach ($model in @(Get-GpuSpoofModels)) { [void]$modelBox.Items.Add($model) }
    $selectedModel = $(if ($script:SelectedGpuSpoofModel -and $modelBox.Items.Contains($script:SelectedGpuSpoofModel)) {
                         $script:SelectedGpuSpoofModel
                       } else { $Item.SpoofModel })
    $modelBox.SelectedItem = $selectedModel
    $script:SelectedGpuSpoofModel = "$selectedModel"
    $modelBox.ToolTip = '选择要向系统和游戏上报的显卡型号'
    $modelBox.Add_SelectionChanged({
      if ($this.SelectedItem) { $script:SelectedGpuSpoofModel = "$($this.SelectedItem)" }
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
    Title = '内存 XMP/EXPO 未开启'
    Tutorial = @(
      'XMP（Intel 平台叫法）/ EXPO 或 DOCP（AMD 平台叫法）是内存条出厂标定的高频档位。不开启时内存跑在保守的 JEDEC 基准频率上，等于放着买好的频率不用；开启后帧数一般会有提升，幅度因 CPU/内存/游戏而异，无法承诺具体数字。'
      ''
      '开启步骤（BIOS 设置只能手动进，任何软件都改不了）：'
      '1. 重启电脑，开机自检画面出现时反复按 Del 或 F2 进入 BIOS（部分品牌是 F1/F10）；'
      '2. 找到内存/超频页面：Intel 主板找 XMP，AMD 主板找 EXPO 或 DOCP，选档位 1 开启；'
      '3. 按 F10 保存并退出；'
      '4. 万一开启后开不了机：多数主板会自动回退重启；不行就再进 BIOS 恢复默认设置（Load Optimized Defaults），恢复后与改动前完全一致，不会造成损坏。'
    ) -join "`n"
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
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="体检发现问题" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="HEALTH CHECK" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <TextBlock Text="以下问题本工具改不了，但按教程手动处理并不难：" Foreground="#FF9AA5A0"
               FontSize="12" Margin="14,12,14,0"/>
    <ScrollViewer MaxHeight="430" VerticalScrollBarVisibility="Auto" Margin="14,10,14,12">
      <StackPanel x:Name="ListPanel"/>
    </ScrollViewer>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" IsCancel="True"
              Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
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
    if ($help -and $help.Tutorial) {
      $tu = New-WrapText $help.Tutorial $script:C.TextMut 11
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
  $warn.Background = New-Brush '#FF2A2008'
  $warn.BorderBrush = New-Brush $script:C.Gold
  $warn.BorderThickness = New-Object Windows.Thickness 1
  $warn.Padding = New-Object Windows.Thickness 12, 8, 12, 8
  $wsp = New-Object Windows.Controls.StackPanel
  $wt = New-Text '仅供参考 · 本工具不会也无法修改游戏内设置' $script:C.Gold 12
  $wt.FontWeight = 'Bold'
  $wsp.Children.Add($wt) | Out-Null
  $wd = New-WrapText '下表是头部主播公开的游戏内画质设置记录，请进入游戏后在「设置 → 视频」页签里手动对照调整。主播设置随游戏版本和硬件不同而变化，不保证适合你的机器。' $script:C.TextSec 11
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

  $meta = New-Text "数据更新：$(if ($data.updated) { $data.updated } else { '未知' })$(if ($data.note) { "　·　$($data.note)" })" $script:C.TextMut 10 -Mono
  $meta.Margin = New-Object Windows.Thickness 2, 8, 0, 8
  $meta.TextWrapping = 'Wrap'
  $ui.RefPanel.Children.Add($meta) | Out-Null

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
      $nm = New-Text "$(if ($s.name) { $s.name } else { "主播$($j + 1)" })" $script:C.Green 12
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
    $nm2 = New-Text "$(if ($s.name) { $s.name } else { '未命名主播' })" $script:C.TextPri 12
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
    $hw2 = New-WrapText "硬件：$(if ($s.hardware) { $s.hardware } else { '未注明' })$(if ($s.captured) { "　·　记录于 $($s.captured)" })" $script:C.TextSec 11
    $hw2.Margin = New-Object Windows.Thickness 0, 4, 0, 0
    $csp.Children.Add($hw2) | Out-Null
    if ($s.notes) {
      $nt = New-WrapText "备注：$($s.notes)" $script:C.TextMut 10
      $nt.Margin = New-Object Windows.Thickness 0, 3, 0, 0
      $csp.Children.Add($nt) | Out-Null
    }
    $tail = New-Text '设置随版本/硬件而异，仅供参考' $script:C.Gold 10
    $tail.Margin = New-Object Windows.Thickness 0, 4, 0, 0
    $csp.Children.Add($tail) | Out-Null
    $card.Child = $csp
    $ui.RefPanel.Children.Add($card) | Out-Null
  }
}

# ---------- 免责声明门控 ----------

# 声明内容有实质修改时把这个数字 +1：配置里记的版本与此不符即重新弹一次，
# 老用户不会因为条款改了还停留在旧版本的「已同意」上
$script:DisclaimerVersion = '5'
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
    '- 没有代码签名证书，SmartScreen 与杀毒软件可能报警，这是必然结果。'
    '- 同意后会发送匿名使用统计：随机安装标识、版本、Windows / CPU / 真实 GPU / 内存 / 设备类型，以及启动、优化、还原和游戏中 120 秒性能采样的汇总结果（平均帧率、1% 低帧率、GPU 占用率、温度、功耗）；配置只上传未使用/轻量/均衡/深度四档，不发送具体勾选项、自存方案名称、用户名、机器名、SID、游戏路径、注册表内容或逐帧数据。统计来自客户端自动采样，会做令牌、重放和异常值过滤，但不是独立实验室测量。'
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
        Width="620" Height="640" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Border x:Name="DlgTitle" Grid.Row="0" Background="#FF0D1417" BorderBrush="#FF1B2E28"
            BorderThickness="0,0,0,1" Padding="14,11">
      <StackPanel Orientation="Horizontal">
        <Path Data="M 9,0 L 18,15 L 12,15 L 9,9 L 6,15 L 0,15 Z" Fill="#FF00E884" VerticalAlignment="Center"/>
        <TextBlock Text="使用前必读" Foreground="#FFFFFFFF" FontSize="15" FontWeight="Bold"
                   Margin="11,0,0,0" VerticalAlignment="Center"/>
        <TextBlock Text="DISCLAIMER" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="10,3,0,0"/>
      </StackPanel>
    </Border>
    <Border Grid.Row="1" Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,12,14,0">
      <ScrollViewer x:Name="Scroller" VerticalScrollBarVisibility="Auto" Padding="16,12,16,14">
        <StackPanel x:Name="Body"/>
      </ScrollViewer>
    </Border>
    <TextBlock x:Name="HintTxt" Grid.Row="2" Text="请滚动到底部阅读完整内容后再选择。"
               Foreground="#FFE5C46A" FontSize="11" Margin="16,8,16,0"/>
    <Grid Grid.Row="3" Margin="14,10,14,14">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <Button x:Name="AgreeBtn" Grid.Column="1" MinWidth="126" Height="34" IsEnabled="False"
              Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
                    Data="M 0.05,0 L 1,0 L 1,0.8 L 0.95,1 L 0,1 L 0,0.2 Z"/>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="14,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Fill" Value="#FF33F09E"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bg" Property="Fill" Value="#FF1E3A30"/>
                <Setter Property="Foreground" Value="#FF6B7A73"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="AgreeTxt" Text="同意并继续"/>
      </Button>
      <Button x:Name="DeclineBtn" Grid.Column="2" MinWidth="112" Height="34"
              Foreground="#FF00E884" Margin="10,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
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
    ConfigTier = 'baseline'; DeviceToken = ''; TokenExpiresAt = 0
  }
  if (Get-Command Write-DfbTelemetryConfigAtomic -ErrorAction SilentlyContinue) { Write-DfbTelemetryConfigAtomic $path $cfg }
  else { [IO.File]::WriteAllText($path, ($cfg | ConvertTo-Json), (New-Object Text.UTF8Encoding($true))) }
  $id
}

# 只记录粗粒度强度，不记录具体勾选项、自存方案名称或方案内容。
# 同一台匿名设备可据此把优化前后的性能会话配对，避免按每个人的独特配置拆分。
function Get-TelemetryConfigTier {
  try {
    $path = Join-Path $script:UserConfigDir 'telemetry.json'
    if (-not (Test-Path -LiteralPath $path)) { return 'baseline' }
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $tier = "$($cfg.ConfigTier)".ToLowerInvariant()
    if ($tier -in 'baseline','light','balanced','full') { return $tier }
  } catch {}
  'baseline'
}

function Set-TelemetryConfigTier([string]$Tier, [switch]$Force) {
  if ($Tier -notin 'baseline','light','balanced','full') { return }
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
    $current = 'baseline'
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
        $current = "$($cfg.ConfigTier)".ToLowerInvariant()
      }
    }
    $rank = @{ baseline = 0; light = 1; balanced = 2; full = 3 }
    if (-not $Force -and $rank[$current] -gt $rank[$Tier]) { $Tier = $current }
    $out = [ordered]@{
      Enabled = $enabled; InstallId = $installId; CreatedAt = $createdAt; ConfigTier = $Tier
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

function Send-AnonymousTelemetry([string]$Event, $Hw, [int]$Ok = 0, [int]$Failed = 0) {
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
      ramGb      = [double]$Hw.RamGB
      deviceType = $(if ($Hw.IsLaptop) { 'laptop' } else { 'desktop' })
      ok         = [math]::Max(0, $Ok)
      failed     = [math]::Max(0, $Failed)
    }
    if (-not (Get-Command Send-DfbTelemetryEvent -ErrorAction SilentlyContinue)) { return }
    $body = $payload | ConvertTo-Json -Compress
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

$script:PerformanceCaptureWorker = {
  param($GamePid, $PresentMon, $SessionFile, $TelemetryModule, $TelemetryConfigPath,
        $UploadUrl, $InstallId, $Version,
        $GpuVendor, $GpuModel, $GpuVerified, $GpuPciLocation, $NvidiaSmi,
        $ConfigTier, $WarmupSeconds, $SampleSeconds, $CaptureMode)
  $ErrorActionPreference = 'SilentlyContinue'

  function Get-Number([object]$Value) {
    $n = 0.0
    if ([double]::TryParse("$Value", [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
    $null
  }
  function Get-Average($Values) {
    $clean = @($Values | Where-Object { $null -ne $_ })
    if (-not $clean.Count) { return 0.0 }
    [math]::Round(($clean | Measure-Object -Average).Average, 1)
  }
  function Get-Maximum($Values) {
    $clean = @($Values | Where-Object { $null -ne $_ })
    if (-not $clean.Count) { return 0.0 }
    [math]::Round(($clean | Measure-Object -Maximum).Maximum, 1)
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
  function Expand-PerformanceSessions([object]$Value) {
    foreach ($entry in @($Value)) {
      if ($null -eq $entry) { continue }
      if ($entry.PSObject.Properties['recordedAt']) { Write-Output $entry; continue }
      $wrapped = $entry.PSObject.Properties['value']
      if ($wrapped) { Expand-PerformanceSessions $wrapped.Value }
    }
  }
  function New-FailedCapture([string]$Reason, [bool]$Exited) {
    [pscustomobject][ordered]@{
      recordedAt = [DateTime]::UtcNow.ToString('o'); startedAt = [DateTime]::UtcNow.ToString('o')
      completedAt = [DateTime]::UtcNow.ToString('o'); durationSec = 0; frameCount = 0
      gpuModel = "$GpuModel"; configTier = "$ConfigTier"; avgFps = 0.0; fps1Low = 0.0
      p99FrameMs = 0.0; frameTimeMadMs = 0.0; stutter50Ms = 0; stutter100Ms = 0
      stuttersPerMin = 0.0; focusLostSec = 0.0; gpuUtilAvg = 0.0; gpuUtilMax = 0.0
      gpuTempAvg = 0.0; gpuTempMax = 0.0; gpuPowerAvg = 0.0; gpuPowerMax = 0.0
      presentMonExitCode = -1; gameExitedEarly = [bool]$Exited; captureFailed = $true; captureError = $Reason
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
  $tmp = Join-Path ([IO.Path]::GetTempPath()) "dfb-presentmon-$GamePid-$([guid]::NewGuid().ToString('N')).csv"
  try {
    # PresentMon must not inherit the product root as CWD.  A capture can outlive an abrupt GUI
    # exit; inheriting that directory would keep it locked and make the transactional updater fail.
    $pm = Start-Process -FilePath $PresentMon -WorkingDirectory ([Environment]::SystemDirectory) -WindowStyle Hidden -PassThru -ArgumentList @(
      '--process_id', "$GamePid", '--output_file', "`"$tmp`"", '--timed', "$SampleSeconds",
      '--terminate_after_timed', '--terminate_on_proc_exit', '--no_console_stats',
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
  $gameExitedEarly = $false; $lastLoop = Get-Date
  while ($pm -and -not $pm.HasExited -and ((Get-Date) - $started).TotalSeconds -lt ($SampleSeconds + 15)) {
    $now = Get-Date; $elapsed = [math]::Max(0, ($now - $lastLoop).TotalSeconds); $lastLoop = $now
    if (-not (Get-Process -Id $GamePid -ErrorAction SilentlyContinue)) { $gameExitedEarly = $true; break }
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
          if ($null -ne $u) { $util += $u; $sampled = $true }
          if ($null -ne $t) { $temp += $t }
          if ($null -ne $w) { $power += $w }
        }
      }
    }
    if (-not $sampled) {
      $counters = @(Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples |
        Where-Object { $_.InstanceName -match "pid_$($GamePid)_" -and $_.InstanceName -match 'engtype_3D' }
      if ($counters.Count) { $util += [math]::Min(100.0, [double](($counters | Measure-Object CookedValue -Sum).Sum)) }
    }
    Start-Sleep -Seconds 2
    try { $pm.Refresh() } catch {}
  }
  if ($pm -and -not $pm.HasExited) { try { $pm.Kill() } catch {} }
  if ($pm) { try { $pm.WaitForExit(5000) | Out-Null } catch {} }
  $presentMonExitCode = $(if ($pm -and $pm.HasExited) { [int]$pm.ExitCode } else { -1 })

  $frameMs = New-Object 'System.Collections.Generic.List[double]'
  if (Test-Path -LiteralPath $tmp) {
    try {
      foreach ($row in @(Import-Csv -LiteralPath $tmp)) {
        $ms = Get-Number $row.MsBetweenPresents
        if ($null -ne $ms -and $ms -gt 0 -and $ms -le 1000) { $frameMs.Add([double]$ms) }
      }
    } catch {}
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
  $completedUtc = [DateTime]::UtcNow
  $durationSec = [math]::Min($SampleSeconds, [math]::Round(((Get-Date) - $started).TotalSeconds))
  if ($durationSec -lt ($SampleSeconds - 5) -and -not (Get-Process -Id $GamePid -ErrorAction SilentlyContinue)) { $gameExitedEarly = $true }
  $avgFps = 0.0; $fps1Low = 0.0; $p99 = 0.0; $mad = 0.0
  if ($frameMs.Count -ge 30) {
    $avgMs = ($frameMs | Measure-Object -Average).Average
    if ($avgMs -gt 0) { $avgFps = [math]::Round(1000.0 / $avgMs, 1) }
    # 1% 低帧率 = 最慢 1% 帧的平均帧时间所对应帧率。
    $slowCount = [math]::Max(1, [math]::Ceiling($frameMs.Count * 0.01))
    $avgSlowMs = (@($frameMs | Sort-Object -Descending | Select-Object -First $slowCount) | Measure-Object -Average).Average
    if ($avgSlowMs -gt 0) { $fps1Low = [math]::Round(1000.0 / $avgSlowMs, 1) }
    $p99 = [math]::Round((Get-Percentile $frameMs 0.99), 2)
    $median = Get-Median $frameMs
    $mad = [math]::Round((Get-Median @($frameMs | ForEach-Object { [math]::Abs([double]$_ - $median) })), 2)
  }
  $stutter50 = @($frameMs | Where-Object { $_ -gt 50 }).Count
  $stutter100 = @($frameMs | Where-Object { $_ -gt 100 }).Count
  $session = [pscustomobject][ordered]@{
    recordedAt = $completedUtc.ToString('o'); startedAt = $startedUtc.ToString('o'); completedAt = $completedUtc.ToString('o')
    durationSec = [int]$durationSec; frameCount = [int]$frameMs.Count
    gpuModel = "$GpuModel"; configTier = "$ConfigTier"; avgFps = $avgFps; fps1Low = $fps1Low
    p99FrameMs = $p99; frameTimeMadMs = $mad; stutter50Ms = [int]$stutter50; stutter100Ms = [int]$stutter100
    stuttersPerMin = $(if ($durationSec -gt 0) { [math]::Round($stutter50 * 60.0 / $durationSec, 2) } else { 0.0 })
    focusLostSec = [math]::Round($focusLostSec, 1)
    gpuUtilAvg = Get-Average $util; gpuUtilMax = Get-Maximum $util
    gpuTempAvg = Get-Average $temp; gpuTempMax = Get-Maximum $temp
    gpuPowerAvg = Get-Average $power; gpuPowerMax = Get-Maximum $power
    presentMonExitCode = $presentMonExitCode; gameExitedEarly = [bool]$gameExitedEarly
    captureFailed = [bool]($frameMs.Count -eq 0 -or $presentMonExitCode -ne 0)
    captureError = $(if ($frameMs.Count -eq 0) { 'PresentMon 未返回帧数据' } elseif ($presentMonExitCode -ne 0) { "PresentMon 退出码 $presentMonExitCode" } else { '' })
  }

  # Beta 返回显式结果，不写普通 performance_sessions，也不发 performance 事件。
  if ($CaptureMode -eq 'experiment') { Write-Output $session; return }
  if ($session.avgFps -le 0 -and $session.gpuUtilAvg -le 0) { return }

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

  if ($InstallId -and $GpuVerified) {
    try {
      $payload = [ordered]@{
        installId = $InstallId; event = 'performance'; version = $Version
        gpuVendor = $GpuVendor; gpuModel = $GpuModel; gpuModelVerified = [bool]$GpuVerified
        configTier = $ConfigTier; durationSec = $session.durationSec; avgFps = $session.avgFps; fps1Low = $session.fps1Low
        gpuUtilAvg = $session.gpuUtilAvg; gpuUtilMax = $session.gpuUtilMax
        gpuTempAvg = $session.gpuTempAvg; gpuTempMax = $session.gpuTempMax
        gpuPowerAvg = $session.gpuPowerAvg; gpuPowerMax = $session.gpuPowerMax
      }
      . $TelemetryModule
      Send-DfbTelemetryEvent -UploadUrl $UploadUrl -Payload ([pscustomobject]$payload) -ConfigPath $TelemetryConfigPath | Out-Null
    } catch {}
  }
  Write-Output $session
}

function Add-PerformanceWorkerArguments($PowerShell, [int]$GamePid, $Hw, [string]$Mode, [int]$WarmupSeconds) {
  $presentMon = Join-Path $script:RootDir 'tools\PresentMon.exe'
  $nvidiaSmi = $(if ($Hw.MainGpuVendor -eq 'NVIDIA') { Get-NvidiaSmiPath } else { $null })
  foreach ($arg in @($GamePid, $presentMon, (Join-Path $script:UserConfigDir 'performance-sessions.json'),
                      $script:TelemetryClientPath, (Join-Path $script:UserConfigDir 'telemetry.json'),
                      $script:TelemetryUploadUrl, (Get-TelemetryInstallId), $script:GuiVersion,
                      "$($Hw.MainGpuVendor)", "$($Hw.MainGpuName)", [bool]$Hw.MainGpuNameVerified,
                      "$($Hw.MainGpuPciLocation)", "$nvidiaSmi", (Get-TelemetryConfigTier),
                      $WarmupSeconds, $script:PerformanceSampleSeconds, $Mode)) {
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
        if([double]$pending.payload.$name -ne [double]$run.$name){throw "待提交运行遥测字段不一致：$name"}
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
  $payload = [ordered]@{
    installId=$InstallId;event='tuning';version="$script:GuiVersion";os="$($Hw.OS)";build="$($Hw.Build)";cpu="$($Hw.CPU)"
    gpuVendor="$($Hw.MainGpuVendor)";gpuModel="$($Hw.MainGpuName)";gpuModelVerified=[bool]$Hw.MainGpuNameVerified
    ramGb=[double]$Hw.RamGB;deviceType=$(if($Hw.IsLaptop){'laptop'}else{'desktop'})
    tuningType=$TuningType;experimentId="$($State.experimentId)"
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
      $payload.gpuUtilAvg=[double]$Run.gpuUtilAvg;$payload.gpuTempAvg=[double]$Run.gpuTempAvg;$payload.gpuPowerAvg=[double]$Run.gpuPowerAvg
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
      $t=New-Text "$($values[$i])" $(if($run.validity -eq 'valid'){$script:C.TextSec}else{'#FFE5C46A'}) 10 -Mono
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
  foreach($n in 'ApplyBtn','RestoreBtn','BrowseBtn','UpdateBtn','CheckUpdBtn') { if($ui[$n]){$ui[$n].IsEnabled=(-not $active -and -not $script:Busy)} }
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
    if ("$($pair[0])".Length -ge 2) { $t = $t -replace [regex]::Escape($pair[0]), $pair[1] }
  }
  $t
}

# 报告只放排查需要的：硬件 + 各优化项当前状态 + 运行日志 + 版本号 + 最近备份的项目名。
# 绝不带备份 JSON 原文——那里面是注册表原值，外传没有意义
function New-DiagnosticReport {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("DeltaForceBooster 诊断报告")
  $lines.Add("生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
  $lines.Add("界面版本：v$script:GuiVersion")
  $lines.Add('')

  $lines.Add('== 硬件与系统 ==')
  try {
    $hw = Get-HardwareInfo
    $lines.Add("系统：$($hw.OS)（Build $($hw.Build)）")
    $lines.Add("CPU：$($hw.CPU)（$($hw.Cores) 核 $($hw.Threads) 线程）")
    $lines.Add("内存：$($hw.RamGB) GB")
    foreach ($g in $hw.Gpus) {
      $lines.Add("显卡（真实）：$($g.Name)（$($g.Vendor)，驱动 $($g.Driver)）")
      if ($g.ReportedName -and $g.ReportedName -ne $g.Name) { $lines.Add("     系统当前伪装上报：$($g.ReportedName)") }
    }
    $lines.Add("机型：$(if ($hw.IsLaptop) { '笔记本' } else { '台式机' })")
  } catch { $lines.Add("读取失败：$($_.Exception.Message)") }
  $lines.Add('')

  $lines.Add('== 运行环境与显示 / 音频 ==')
  try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $boot = $os.LastBootUpTime
    $lines.Add("系统启动时间：$boot")
    $lines.Add("会话模式：$(if ($script:NetCafeCompatibilityMode) { '网吧兼容模式（UAC 策略未修改）' } else { '标准 EngineHost 管理员会话' })")
    $lines.Add("UAC：EnableLUA=$(Get-UacEnableLuaValue)；FilterAdministratorToken=$(Get-UacFilterAdministratorTokenValue)")
    foreach ($display in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
      $lines.Add("显示输出：$($display.Name)｜$($display.CurrentHorizontalResolution)x$($display.CurrentVerticalResolution) @$($display.CurrentRefreshRate)Hz｜驱动 $($display.DriverVersion)")
    }
    foreach ($audio in @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue)) {
      $lines.Add("音频设备：$($audio.Name)｜厂商 $($audio.Manufacturer)｜状态 $($audio.Status)")
    }
    foreach ($page in @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)) {
      $lines.Add("页面文件：$($page.Name)｜已分配 $($page.AllocatedBaseSize) MB｜当前 $($page.CurrentUsage) MB｜峰值 $($page.PeakUsage) MB")
    }
    $interesting = @('DeltaForceClient-Win64-Shipping','DeltaForce','PresentMon','RTSS','MSIAfterburner','obs64','Discord','GameBar','NVIDIA Share','WeGame')
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $interesting -contains $_.ProcessName } |
      Select-Object -ExpandProperty ProcessName -Unique | Sort-Object)
    $lines.Add("相关进程：$(if ($running.Count) { $running -join '、' } else { '未检测到' })")
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
        $lines.Add("$($s.recordedAt)｜$($s.gpuModel)｜$($s.durationSec)s｜平均帧率 $($s.avgFps) 帧/秒｜1% 低帧率 $($s.fps1Low) 帧/秒")
        $lines.Add("     GPU 占用 $($s.gpuUtilAvg)% / 峰值 $($s.gpuUtilMax)%｜温度 $($s.gpuTempAvg)°C / 峰值 $($s.gpuTempMax)°C｜功耗 $($s.gpuPowerAvg)W / 峰值 $($s.gpuPowerMax)W")
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

  $lines.Add('== 运行日志 ==')
  $lines.Add($(if ($ui.LogBox.Text) { $ui.LogBox.Text } else { '（空）' }))

  $txt = Protect-ReportText (($lines -join "`r`n"))
  # 上限按字节算：中文一个字三字节，按字符数截会超
  $bytes = [Text.Encoding]::UTF8.GetBytes($txt)
  if ($bytes.Length -gt $script:ReportMaxBytes) {
    $keep = [Text.Encoding]::UTF8.GetString($bytes, 0, $script:ReportMaxBytes - 200)
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

function Get-GuiGpuPanelApps([string]$Vendor) {
  if ($Vendor -notin 'NVIDIA','AMD','Intel') { return @() }
  try { @((Invoke-EngineHostUserAction -Action GetGpuPanelApps -Payload $Vendor) | ConvertFrom-Json) }
  catch { Write-Log "显卡软件检测失败：$($_.Exception.Message)"; @() }
}

function Build-GpuGuideDialog($Hw) {
  $gxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="520" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="显卡指引" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="GPU DRIVER GUIDE" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <Border Background="#FF0E2A21" BorderBrush="#FF17603F" BorderThickness="1" Margin="14,12,14,0" Padding="10,7">
      <TextBlock x:Name="BannerTxt" Text="" Foreground="#FF00E884" FontSize="12" FontWeight="Bold" TextWrapping="Wrap"/>
    </Border>
    <StackPanel x:Name="AppPanel" Margin="14,10,14,0"/>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,10,14,12">
      <ScrollViewer MaxHeight="300" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="MsgTxt" Text="" Foreground="#FF9AA5A0" FontSize="12" LineHeight="19"
                   TextWrapping="Wrap" Padding="12,9"/>
      </ScrollViewer>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" IsCancel="True"
              Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
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
  $dlg.FindName('MsgTxt').Text = Get-GpuGuideText $Hw.MainGpuVendor $Hw.MainGpuName $Hw.IsLaptop

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

# ---------- 标签页切换与执行态 ----------

$script:Busy = $false

function Select-Tab([string]$Which) {
  foreach ($t in @(@('opt', 'TabOptBtn', 'OptPage'), @('tune', 'TabTuneBtn', 'TunePage'), @('ref', 'TabRefBtn', 'RefPage'), @('log', 'TabLogBtn', 'LogPage'))) {
    $on = ($Which -eq $t[0])
    $ui[$t[1]].Tag = $(if ($on) { 'on' } else { '' })
    $ui[$t[2]].Visibility = $(if ($on) { 'Visible' } else { 'Collapsed' })
  }
  # 执行按钮只属于优化页，别让人以为参考设置或日志能「执行」
  $ui.ActionRow.Visibility = $(if ($Which -eq 'opt') { 'Visible' } else { 'Collapsed' })
  # 每次切入都重建：数据文件可能是界面启动之后才生成的
  if ($Which -eq 'ref') { Update-StreamerPage }
  if ($Which -eq 'tune') { Update-TuningUi }
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
                 'SavePresetBtn','DelPresetBtn','PresetBox','TabOptBtn','TabTuneBtn','TabRefBtn','UpdateBtn',
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

function ConvertTo-PsSingleQuotedLiteral([string]$Value) {
  "'" + $(if ($null -eq $Value) { '' } else { $Value.Replace("'", "''") }) + "'"
}

function Invoke-ElevatedEngineAction {
  param(
    [Parameter(Mandatory)][ValidateSet('Apply','Restore')][string]$Action,
    [string[]]$ItemIds,
    [string]$GamePath,
    [bool]$AllowRisky = $false,
    [string]$GpuSpoofModel,
    [string]$BackupFile,
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

  $resultId = $(if ($ResultId) { "$ResultId" } else { [guid]::NewGuid().ToString('D') })
  if ($resultId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
    throw '管理员执行结果 ID 无效'
  }
  $programData = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
  $userLocalAppData = $script:OriginalUserLocalAppData
  if (-not $programData -or -not $userLocalAppData) { throw '系统未提供用户数据目录' }
  $resultFile = Join-Path (Join-Path $programData 'DeltaForceBooster\ipc') ($resultId + '.json')
  $userSid = $script:OriginalUserSid
  $userLocalAppData = [IO.Path]::GetFullPath($userLocalAppData)
  $parts = New-Object System.Collections.Generic.List[string]
  $parts.Add('& ' + (ConvertTo-PsSingleQuotedLiteral $engine))
  $parts.Add('-' + $Action)
  $parts.Add('-ResultId ' + (ConvertTo-PsSingleQuotedLiteral $resultId))
  # 原交互用户上下文来自全生命周期 asInvoker 启动器的认证管道；引擎还会
  # 将 HKCU 映射到 HKEY_USERS\<SID> 并按 ProfileList 二次校验 LocalAppData。
  $parts.Add('-UserSid ' + (ConvertTo-PsSingleQuotedLiteral $userSid))
  $parts.Add('-UserLocalAppData ' + (ConvertTo-PsSingleQuotedLiteral $userLocalAppData))
  $parts.Add('-UserStateRoot ' + (ConvertTo-PsSingleQuotedLiteral $script:ProtectedUserStateRoot))
  if ($Action -eq 'Apply') {
    $itemLiterals = @($ItemIds | ForEach-Object { ConvertTo-PsSingleQuotedLiteral "$_" })
    $parts.Add('-Items @(' + ($itemLiterals -join ',') + ')')
    if ($GamePath) { $parts.Add('-GamePath ' + (ConvertTo-PsSingleQuotedLiteral $GamePath)) }
    if ($GpuSpoofModel) { $parts.Add('-GpuSpoofModel ' + (ConvertTo-PsSingleQuotedLiteral $GpuSpoofModel)) }
    if ($AllowRisky) { $parts.Add('-Risky') }
  } elseif ($BackupFile) {
    # Beta 回滚必须指向它自己刚刚生成的备份，绝不退化为“还原全部”。
    if (-not (Test-TuningBackupReference $BackupFile)) { throw '指定的实验备份路径无效' }
    $parts.Add('-BackupFile ' + (ConvertTo-PsSingleQuotedLiteral ([IO.Path]::GetFullPath($BackupFile))))
  }
  $command = ($parts -join ' ') + '; exit $LASTEXITCODE'
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  # 即使已在管理员会话，系统可执行文件仍只从 Known Folder 取得。
  $windowsDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
  if (-not $windowsDir) { throw '系统未提供 Windows 目录' }
  $powershellExe = Join-Path $windowsDir 'System32\WindowsPowerShell\v1.0\powershell.exe'

  try {
    # 继承 EngineHost 的 high token，不跨越新的 UAC 边界。
    $proc = Start-Process -FilePath $powershellExe -WindowStyle Hidden -PassThru `
      -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
  } catch {
    throw "引擎子进程启动失败：$($_.Exception.Message)"
  }
  while (-not $proc.HasExited) {
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Background)
    Start-Sleep -Milliseconds 80
    $proc.Refresh()
  }

  # 引擎会在退出前 Flush(true) 并原子发布结果；仍短暂重试以容忍杀毒软件扫描造成的共享延迟。
  $deadline = [DateTime]::UtcNow.AddSeconds(5)
  while (-not (Test-Path -LiteralPath $resultFile) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 80
  }
  if (-not (Test-Path -LiteralPath $resultFile)) {
    throw "管理员执行进程未返回可信结果（退出码 $($proc.ExitCode)）"
  }
  try { $reply = Get-Content -LiteralPath $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { throw "管理员执行结果读取失败：$($_.Exception.Message)" }
  if ([int]$reply.SchemaVersion -ne 1 -or "$($reply.ResultId)" -ne $resultId -or "$($reply.Action)" -ne $Action) {
    throw '管理员执行结果校验失败'
  }
  if ($null -eq $reply.Data) {
    throw $(if ("$($reply.Error)") { "$($reply.Error)" } else { "执行失败（退出码 $($reply.ExitCode)）" })
  }
  $reply.Data | Add-Member -NotePropertyName EngineExitCode -NotePropertyValue ([int]$reply.ExitCode) -Force
  $reply.Data
}

# 主题化确认/信息对话框：原生 MessageBox 白底系统样式与深色主题完全不搭（用户实测吐槽），
# 全站确认（执行/还原/删除）和长文本指引统一走这里。正文放 ScrollViewer：
# 执行清单可达 30 行、显卡指引更长，超高时内部滚动而不是把对话框撑出屏幕
function Show-ConfirmDialog([string]$ChipText, [string]$EnText, [string]$Message,
                            [string]$OkText = '确定', [switch]$InfoOnly, [string]$Banner) {
  $cxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="440" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock x:Name="ChipTxt" Text="" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock x:Name="EnTxt" Text="" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <!-- 醒目横幅（可选）：显卡指引用它标出「检测到你的显卡：xxx」，让用户一眼确认
         这份指引就是按自己的硬件生成的（实机反馈感知不到） -->
    <Border x:Name="BannerRow" Visibility="Collapsed" Background="#FF0E2A21" BorderBrush="#FF17603F"
            BorderThickness="1" Margin="14,12,14,0" Padding="10,7">
      <TextBlock x:Name="BannerTxt" Text="" Foreground="#FF00E884" FontSize="12" FontWeight="Bold"
                 TextWrapping="Wrap"/>
    </Border>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,12,14,12">
      <ScrollViewer MaxHeight="340" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="MsgTxt" Text="" Foreground="#FF9AA5A0" FontSize="12" LineHeight="19"
                   TextWrapping="Wrap" Padding="12,9"/>
      </ScrollViewer>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" MinWidth="104" Height="30" IsDefault="True" Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
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
      <Button x:Name="CancelBtn" Width="80" Height="30" IsCancel="True" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
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

# 重启调用单独包一层：验证脚本可整体替换成 mock 走完整个交互链路，
# 保证任何测试都不会真的把机器重启掉
function Invoke-SystemReboot {
  $windowsDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
  if (-not $windowsDir) { throw '系统未提供 Windows 目录' }
  $shutdownExe = Join-Path $windowsDir 'System32\shutdown.exe'
  # 主界面已经继承 EngineHost 的 high token，不再跨越第二次 UAC。
  Start-Process -FilePath $shutdownExe -WindowStyle Hidden -ArgumentList '/r', '/t', '5'
}

# 执行完成后的醒目重启提醒：此前只在日志末尾一行小字，用户根本注意不到（实机反馈）。
# 只在「本次成功项里确实有需重启的」才弹；纯检测/即时生效项不触发。
# 返回 $true 表示用户点了「立即重启」——调用方还要再走一道确认，重启是破坏性动作
function Show-RebootDialog([string[]]$ItemNames) {
  $rxaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="460" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False"
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,16">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="重启提醒" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="REBOOT REQUIRED" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <StackPanel Orientation="Horizontal" Margin="16,14,16,4">
      <!-- 电源符号图标：圆环开口 + 竖杠，全部固定尺寸拼装，不用归一化 Path（教训 #3） -->
      <Grid Width="34" Height="34" VerticalAlignment="Center">
        <Ellipse Stroke="#FF00E884" StrokeThickness="2.5" Margin="3,6,3,2"/>
        <Border Width="8" Height="14" Background="#FF0C1814" VerticalAlignment="Top" HorizontalAlignment="Center"/>
        <Border Width="3" Height="15" Background="#FF00E884" VerticalAlignment="Top" HorizontalAlignment="Center" Margin="0,1,0,0"/>
      </Grid>
      <StackPanel Margin="13,0,0,0" VerticalAlignment="Center">
        <TextBlock Text="需要重启电脑" Foreground="#FFFFFFFF" FontSize="16" FontWeight="Bold"/>
        <TextBlock Text="以下优化项已写入成功，但要等重启后才完全生效：" Foreground="#FF9AA5A0"
                   FontSize="11" Margin="0,3,0,0"/>
      </StackPanel>
    </StackPanel>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="16,8,16,12">
      <ScrollViewer MaxHeight="180" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="ItemsTxt" Text="" Foreground="#FF9AA5A0" FontSize="12" LineHeight="20"
                   TextWrapping="Wrap" Padding="12,8"/>
      </ScrollViewer>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="16,0,16,0">
      <Button x:Name="RebootBtn" MinWidth="110" Height="32" Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
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
        <TextBlock Text="立即重启"/>
      </Button>
      <Button x:Name="LaterBtn" MinWidth="110" Height="32" IsCancel="True" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
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
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="存为方案" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="SAVE PRESET" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <TextBlock Text="把当前勾选的优化项保存为方案，输入方案名：" Foreground="#FF9AA5A0" Margin="14,12,14,8"/>
    <Border Background="#FF0B1712" BorderBrush="#FF2C443B" BorderThickness="1" Margin="14,0,14,12">
      <TextBox x:Name="NameBox" BorderThickness="0" Background="Transparent" Foreground="#FFFFFFFF"
               CaretBrush="#FF00E884" Padding="9,6" FontSize="12" MaxLength="40"/>
    </Border>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="14,0,14,0">
      <Button x:Name="OkBtn" Width="96" Height="30" IsDefault="True" Foreground="#FF04241B"
              FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
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
      <Button x:Name="CancelBtn" Width="80" Height="30" IsCancel="True" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
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
        Background="#FF0C1814" BorderBrush="#FF2C443B" BorderThickness="1"
        FontFamily="Microsoft YaHei UI" FontSize="12">
  <StackPanel Margin="0,0,0,14">
    <Border x:Name="DlgTitle" Background="#FF0D1417" BorderBrush="#FF1B2E28" BorderThickness="0,0,0,1" Padding="12,9">
      <StackPanel Orientation="Horizontal">
        <Border Background="#FFE5C46A" Padding="7,1" VerticalAlignment="Center">
          <TextBlock Text="发现新版本" Foreground="#FF3A2C0C" FontSize="11" FontWeight="Bold"/>
        </Border>
        <TextBlock Text="UPDATE AVAILABLE" FontFamily="Consolas" FontSize="9" Foreground="#FF7A8580"
                   VerticalAlignment="Center" Margin="9,0,0,0"/>
      </StackPanel>
    </Border>
    <StackPanel Orientation="Horizontal" Margin="14,12,14,4">
      <TextBlock x:Name="VerText" Text="" Foreground="#FF00E884" FontSize="15" FontWeight="Bold"/>
      <TextBlock x:Name="CurText" Text="" Foreground="#FF7A8580" FontSize="11" Margin="9,0,0,0"
                 VerticalAlignment="Bottom"/>
    </StackPanel>
    <Border Background="#FF081310" BorderBrush="#FF1B2E28" BorderThickness="1" Margin="14,6,14,8">
      <ScrollViewer MaxHeight="140" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="NotesText" Text="" Foreground="#FF9AA5A0" FontSize="11"
                   TextWrapping="Wrap" Padding="10,8"/>
      </ScrollViewer>
    </Border>
    <!-- 内置更新说明：走安装器覆盖升级，覆盖安装保护会保住配置与备份 -->
    <TextBlock x:Name="InlineNote" Text="" Foreground="#FF7A8580" FontSize="10"
               TextWrapping="Wrap" Margin="14,0,14,8"/>
    <!-- 下载进度区：点「立即更新」后展开；进度由轮询定时器在 UI 线程刷新 -->
    <StackPanel x:Name="DlPanel" Visibility="Collapsed" Margin="14,0,14,10">
      <Grid>
        <TextBlock x:Name="DlPhaseText" Text="正在下载更新…" Foreground="#FF9AA5A0" FontSize="11"/>
        <TextBlock x:Name="DlSizeText" Text="" Foreground="#FF7A8580" FontFamily="Consolas"
                   FontSize="10" HorizontalAlignment="Right" VerticalAlignment="Center"/>
      </Grid>
      <Border x:Name="DlTrack" Height="8" Background="#FF081310" BorderBrush="#FF1B2E28"
              BorderThickness="1" Margin="0,6,0,0">
        <Border x:Name="DlFill" Background="#FF00E884" HorizontalAlignment="Left" Width="0"/>
      </Border>
    </StackPanel>
    <!-- 安装阶段：进度不可知（安装器在另一个进程里跑），只给转圈 + 一句话 -->
    <StackPanel x:Name="InstPanel" Visibility="Collapsed" Orientation="Horizontal" Margin="14,2,14,12">
      <Grid Width="20" Height="20" RenderTransformOrigin="0.5,0.5" VerticalAlignment="Center">
        <Grid.RenderTransform>
          <RotateTransform x:Name="SpinRot" Angle="0"/>
        </Grid.RenderTransform>
        <Ellipse Stroke="#FF1B2E28" StrokeThickness="2.5" Width="18" Height="18"/>
        <Path Stroke="#FF00E884" StrokeThickness="2.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
              Data="M 10,1 A 9,9 0 0 1 19,10"/>
      </Grid>
      <TextBlock x:Name="InstText" Text="正在安装，请稍候…" Foreground="#FF00E884" FontSize="12"
                 VerticalAlignment="Center" Margin="11,0,0,0"/>
    </StackPanel>
    <!-- 失败区：下载/校验失败的明确报错，旁边的「前往下载」变身降级入口 -->
    <Border x:Name="ErrPanel" Visibility="Collapsed" Background="#FF1A0E10" BorderBrush="#FF7A3034"
            BorderThickness="1" Margin="14,0,14,10">
      <TextBlock x:Name="ErrText" Text="" Foreground="#FFE5484D" FontSize="11"
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
                <Border x:Name="Box" Width="13" Height="13" BorderBrush="#FF2C443B"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Center">
                  <Path x:Name="Mark" Data="M 2,5.5 L 4.5,8.5 L 10,2" Stroke="#FF04241B"
                        StrokeThickness="2" Visibility="Collapsed"/>
                </Border>
                <TextBlock Text="不再提醒此版本" Foreground="#FF7A8580" FontSize="11"
                           Margin="7,0,0,0" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="#FF00E884"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="#FF00E884"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </CheckBox.Template>
      </CheckBox>
      <Button x:Name="UpdBtn" Grid.Column="1" MinWidth="96" Height="30" Foreground="#FF04241B" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Path x:Name="Bg" Stretch="Fill" Fill="#FF00E884"
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
      <Button x:Name="GoBtn" Grid.Column="2" MinWidth="96" Height="30" Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="GoTxt" Text="前往下载"/>
      </Button>
      <Button x:Name="CancelDlBtn" Grid.Column="3" Visibility="Collapsed" MinWidth="96" Height="30"
              Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="12,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="#FF7A8580"/>
                <Setter TargetName="B" Property="BorderBrush" Value="#FF1B2E28"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
        <TextBlock x:Name="CancelDlTxt" Text="取消下载"/>
      </Button>
      <Button x:Name="LaterBtn" Grid.Column="4" Width="86" Height="30" IsCancel="True"
              Foreground="#FF00E884" Margin="9,0,0,0">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" BorderBrush="#FF17603F" BorderThickness="1" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="BorderBrush" Value="#FF00E884"/>
                <Setter TargetName="B" Property="Background" Value="#FF0E2A21"/>
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
  $script:UpdUi.VerText.Text = "新版本 v$($UpdInfo.Version)"
  $script:UpdUi.CurText.Text = "当前 v$($UpdInfo.Current)"
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
    if ($script:UpdDlg.IsVisible -and $st.Phase -eq 'downloading') {
      $recv = [long]$st.Received; $totalB = [long]$st.Total
      $pct = $(if ($totalB -gt 0) { [Math]::Min(100, [Math]::Floor($recv * 100.0 / $totalB)) } else { 0 })
      $script:UpdUi.DlSizeText.Text = "{0:N1} MB / {1:N1} MB · {2}%" -f ($recv / 1MB), ($totalB / 1MB), $pct
      $trackW = $script:UpdUi.DlTrack.ActualWidth - 2
      if ($trackW -gt 0) { $script:UpdUi.DlFill.Width = $trackW * $pct / 100 }
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
      Received = 0L; Total = [long]$script:UpdDlgInfo.Size; Phase = 'downloading'
      Error = ''; File = ''; Cancel = $false; Done = $false
    })
    foreach ($n in 'SkipChk','UpdBtn','GoBtn','LaterBtn') { $script:UpdUi[$n].Visibility = 'Collapsed' }
    $script:UpdUi.ErrPanel.Visibility = 'Collapsed'
    $script:UpdUi.DlPanel.Visibility = 'Visible'
    $script:UpdUi.DlPhaseText.Text = '正在下载更新…'
    $script:UpdUi.DlSizeText.Text = ''
    $script:UpdUi.DlFill.Width = 0
    $script:UpdUi.CancelDlBtn.Visibility = 'Visible'
    $script:UpdUi.CancelDlBtn.IsEnabled = $true
    $script:UpdUi.CancelDlTxt.Text = '取消下载'
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
      $script:DlState.Cancel = $true
      $script:UpdUi.CancelDlBtn.IsEnabled = $false
      $script:UpdUi.CancelDlTxt.Text = '正在取消…'
      $script:UpdUi.DlPhaseText.Text = '正在取消下载…'
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
          $ui.UpdateBtn.ToolTip = "新版本 v$($found.Version) 可用（当前 v$($found.Current)），点击查看详情"
          $ui.UpdateBtn.Visibility = 'Visible'
          if ($isNew) {
            Write-Log "检测到新版本 v$($found.Version)（当前 v$($found.Current)），正在显示更新详情。"
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
      Write-Log "已是最新版本 v$($script:GuiVersion)。"
      Show-ConfirmDialog '检查更新' 'CHECK UPDATE' "已是最新版本 v$($script:GuiVersion)，无需更新。" '知道了' -InfoOnly | Out-Null
    } else {
      # 发现新版：与定时检查同一收口——点亮标题栏入口，并直接弹更新详情
      $script:UpdateInfo = $r.Info
      $ui.UpdateBtn.ToolTip = "新版本 v$($r.Info.Version) 可用（当前 v$($r.Info.Current)），点击查看详情"
      $ui.UpdateBtn.Visibility = 'Visible'
      Write-Log "检测到新版本 v$($r.Info.Version)（当前 v$($r.Info.Current)）。"
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

$window.Add_ContentRendered({
  try {
    $hw = Get-HardwareInfo
    $script:HardwareInfo = $hw
    $ui.HwGrid.Children.Clear()
    $gpu = ($hw.Gpus | Where-Object { $_.Name -eq $hw.MainGpuName } | Select-Object -First 1)
    if (-not $gpu) { $gpu = $hw.Gpus | Select-Object -First 1 }
    $cpuShort = ($hw.CPU -replace '^\d+th Gen ', '' -replace '\(R\)|\(TM\)', '' -replace '\s*@.*$', '').Trim()
    $ui.HwGrid.Children.Add((New-HwCard 'CPU' $cpuShort "$($hw.Cores)核 / $($hw.Threads)线程")) | Out-Null
    $ui.HwGrid.Children.Add((New-HwCard 'GPU' $gpu.Name "$($gpu.Vendor) · $(if (@($hw.Gpus).Count -gt 1) { '双显卡' } else { '单显卡' })" -Ribbon)) | Out-Null
    $ui.HwGrid.Children.Add((New-HwCard 'MEMORY' "$($hw.RamGB) GB" "$(if ($hw.IsLaptop) { '笔记本' } else { '台式机' }) / Build $($hw.Build)")) | Out-Null

    Write-Log '开始检测硬件与系统状态…'
    $script:TargetExe = Find-GamePath
    if ($script:TargetExe) {
      $ui.GameText.Text = $script:TargetExe
      Write-Log "目标程序已定位：$script:TargetExe"
    } else {
      $ui.GameText.Text = '未定位 — 点「重新定位」手动选择游戏主程序'
      Write-Log '未自动找到游戏，部分优化项需要手动指定路径'
    }
    # 硬件和默认游戏路径准备好后再恢复实验；状态中的固定路径优先且会严格复验。
    Load-ActiveTuningExperiment
    Update-ItemList
    Update-PresetList
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
    if ($script:PerformanceTimer) { $script:PerformanceTimer.Stop() }
    if ($script:TuningTelemetryTimer) { $script:TuningTelemetryTimer.Stop() }
  }
})
$ui.CloseBtn.Add_Click({
  if ($script:TuningSampling) { Write-Log '自动调优正在采样，请等本轮结束后再关闭。'; return }
  if ($script:Busy) { Write-Log '正在执行优化，请等本轮执行结束后再关闭。'; return }
  $window.Close()
})

$ui.TabOptBtn.Add_Click({ Select-Tab 'opt' })
$ui.TabTuneBtn.Add_Click({ Select-Tab 'tune' })
$ui.TabRefBtn.Add_Click({ Select-Tab 'ref' })
$ui.TabLogBtn.Add_Click({ Select-Tab 'log' })

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

# 全选/全不选（实机诉求）：勾选态只圈「可执行」的项——已就绪项重复执行只会撑大备份；
# 全不选则一视同仁清空。这等同手动改勾选，方案选中态一并清掉（勾选已不再等于该方案）
$ui.SelAllChk.Add_Click({
  $on = ($ui.SelAllChk.IsChecked -eq $true)
  foreach ($row in @($ui.ItemPanel.Children)) {
    $row.Child.Children[0].IsChecked = $(if ($on) { $row.Tag -ne $true } else { $false })
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

# 上传诊断报告：先组装（含脱敏）再让用户确认要发什么，确认后才上传。绝不静默发送
$ui.ReportBtn.Add_Click({
  try {
    Write-Log '正在收集诊断信息…'
    $report = New-DiagnosticReport
    $kb = [math]::Round([Text.Encoding]::UTF8.GetByteCount($report) / 1KB, 1)
    $msg = @(
      "将把以下内容上传到作者的服务器（$script:ReportUploadUrl），仅用于排查你反馈的问题："
      ''
      '· 硬件型号与系统版本（CPU / 显卡 / 内存 / Windows 版本）'
      '· 显示器分辨率/刷新率、音频设备、页面文件、系统启动时间与相关进程名'
      '· 排障所需的关键环境变量（路径会脱敏；敏感变量只记录名称，不上传值）'
      '· 已定位的游戏主程序路径（用户名和机器名会脱敏）'
      '· 各优化项的当前状态'
      '· 本次运行日志'
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
    if ($ids.Count -eq 0 -and $riskyIds.Count -eq 0) { Write-Log '未勾选任何优化项。'; return }
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
    # 档位按本轮真正成功且产生改动的项目数计算，不按预设名/勾选数夸大；检测、缓存、
    # Attention 与 Skipped 都不算。Set-TelemetryConfigTier 会保留历史上达到过的更高档位。
    $changedIds = @($r.Results | Where-Object { $_.Ok -and $_.Changed -eq $true -and -not $_.Attention } |
                    ForEach-Object { $_.Id })
    $changedCount = @($selectedItems | Where-Object { $changedIds -contains $_.Id -and $_.Kind -notin 'check','cache' }).Count
    if ($changedCount -gt 0) { $script:TuningConfigGeneration++ }
    if ($changedCount -gt 0) { Set-TelemetryConfigTier (Get-SelectedTelemetryConfigTier $changedCount) }
    Send-AnonymousTelemetry 'apply' $script:HardwareInfo $okN $failList.Count
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
        # 重启是破坏性动作：即便用户点了「立即重启」也必须再确认一次，双重确认不可省
        if (Show-ConfirmDialog '确认重启' 'CONFIRM REBOOT' '确定现在重启电脑？未保存的工作会丢失。确认后系统将在 5 秒内重启。' '确认重启') {
          Write-Log '已确认重启，系统将在 5 秒内重启…'
          Invoke-SystemReboot
        } else { Write-Log '已取消重启，稍后请自行重启电脑以让优化完全生效。' }
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
  try {
    if (Test-TuningExperimentActive) { throw '自动调优实验期间禁止普通全量还原；请使用「停止并回滚」只处理本实验备份' }
    if (-not (Show-ConfirmDialog '确认还原' 'CONFIRM RESTORE' '合并所有尚未还原的备份，把系统设置恢复到第一次优化前的原始状态？' '还原设置')) { return }
    Set-BusyState $true
    # 此前同步跑完才刷新，界面「卡一下」就结束，用户不知道还原有没有在干活（实测吐槽）；
    # 现在和执行优化共用进度面板，逐项推进 + 结束弹明确的完成提示
    $ui.ProgressPanel.Visibility = 'Visible'
    $ui.ProgFill.Width = 0
    $ui.ProgText.Text = '正在还原系统设置…'
    $ui.ProgCount.Text = ''
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $r = Invoke-ElevatedEngineAction -Action Restore
    $script:TuningConfigGeneration++
    $w = $ui.ProgTrack.ActualWidth - 2
    if ($w -gt 0) { $ui.ProgFill.Width = $w }
    $failN = @($r.Failed).Count
    $skipN = @($r.Skipped).Count
    if ($failN -eq 0) { Set-TelemetryConfigTier 'baseline' -Force }
    Send-AnonymousTelemetry 'restore' $script:HardwareInfo $r.RestoredOps $failN
    $bakName = Split-Path -Leaf $r.File
    $ui.ProgText.Text = "还原完成：$($r.RestoredOps) 项已还原 / $failN 项失败$(if ($skipN -gt 0) { " / $skipN 项跳过（无实际影响）" })"
    $ui.ProgCount.Text = "备份：$bakName"
    Write-Log "已还原 $($r.RestoredOps) 项改动（备份：$($r.File)）"
    foreach ($f in $r.Failed) { Write-Log "[还原失败] $f" }
    # 跳过与失败必须分开呈现：跳过是「删不掉但不影响任何生效设置」，混在失败里会吓到用户
    foreach ($s in $r.Skipped) { Write-Log "[还原跳过] $s" }
    foreach ($n in $r.Notes) { Write-Log "[提示] $n" }
    Update-ItemList
    # 成功与否都要有明确收尾：全成给定心丸，有失败的把数量点出来引导看日志。
    # 引擎已合并还原全部未消费备份，「回到优化前」只在零失败时才是事实，失败时必须如实说
    $sum = "已按$(if ($r.MergedCount -gt 1) { "合并的 $($r.MergedCount) 份备份" } else { "备份「$bakName」" })还原 $($r.RestoredOps) 项改动。" +
           $(if ($skipN -gt 0) { "`n`n$skipN 项跳过：工具自建电源方案里的残留设置，该方案已停用，无实际影响。" }) +
           $(if ($failN -gt 0) { "`n`n有 $failN 项还原失败，对应改动仍留在系统中（备份已保留，可排查后重试还原），明细见运行日志。" }
             elseif ($skipN -gt 0) { "`n`n其余全部还原成功，各项已回到优化前的状态。" }
             else { "`n`n全部还原成功，各项已回到优化前的状态。" })
    Show-ConfirmDialog '还原完成' 'RESTORE DONE' $sum '知道了' -InfoOnly | Out-Null
  } catch {
    $err = $_.Exception.Message
    Write-Log "还原失败：$err"
    Show-ConfirmDialog '还原未完成' 'RESTORE NOT COMPLETED' $err '知道了' -InfoOnly | Out-Null
  }
  finally { Set-BusyState $false }
})

# 免责声明门控放在主窗口之前：没同意就不该看到任何可点的优化按钮。
# 读取/写入配置失败一律按「没同意」处理——宁可多问一次，也不能因为磁盘异常就放行
if (-not (Test-DisclaimerAccepted)) {
  if (-not (Show-DisclaimerDialog)) { Invoke-AppExit }
}

$window.ShowDialog() | Out-Null
