<#
  DeltaForceBooster 核心脚本 — v0.17.1
  三角洲行动 一键画面/帧率优化：硬件检测 + Windows 系统优化 + 显卡驱动指引。

  v0.17.1：显卡型号伪装新增 RTX 2050/2060/RX560，并恢复 AMD 主显卡支持；AMD
        驱动指引新增按本机配置推荐方案；新增电脑品牌检测，XMP/EXPO 的 BIOS 进入步骤
        按品牌区分。
  v0.17：备份升级为受保护目录中的严格 schema + HMAC 写前日志，新增核心互斥与可靠退出码；
        修复混合/多显卡匹配、计划任务覆盖、无效 MMCSS 值、缓存重解析点和外部工具信任问题。
  v0.16.4：着色器缓存项改名为「解决掉帧：清理着色器缓存」——用户搜的问的都是
        「解决掉帧」，只写手段名，真正需要它的人在列表里认不出来。
  v0.16.3：①VC++ 运行库体检改为默认勾选（社区排查掉帧最常命中的一条，纯检测零代价）；
        ②新增实验项「清理着色器缓存」（Kind=cache）：只清系统与驱动的着色器缓存目录，
        不碰游戏目录；缓存可再生，故不产生备份也无需还原，这一点在项名、Note 与执行
        结果三处都写明，不让用户误以为它能一键退回。
  v0.16.2：主推全套加入显卡型号伪装；GUI 仍会单独列出并要求二次确认，CLI 仍需 -Risky。
  v0.16.1：双显卡按独显性能优先级选择主显卡，不再因 WMI 返回顺序误把 AMD/Intel
        核显用于显卡指引；NVIDIA 笔记本指引补充 Game Ready 驱动选择说明。
  v0.16：显卡型号伪装按代际给默认值（RTX 30 系 → GTX 750 Ti，RTX 40/50 系 →
        GTX 1050 Ti），并新增 -GpuSpoofModel 供 GUI/CLI 明确选择目标型号。
  v0.15.1：pcfg 还原兜底改按「残留是否在还原后最终生效的方案里」判定（原先只认工具
        自建方案，名字匹配来的卓越性能方案会误报还原失败）；真失败时给人话错误并带项名。
  v0.15：修复备份污染与还原语义：所有写入类操作（reg/pcfg/mmagent/kvstr/hib/bcd/power）
        已达标就跳过、不写不备份（重复 Apply 不再把上一轮写入的目标值记成「原值」）；
        -Restore 默认合并全部尚未消费的备份（新→旧，同一设置取最早原值），全部成功后
        给备份打 .restored 后缀防重复消费，显式 -BackupFile 仍只还原一份；还原电源计划
        改走 Invoke-SchemeActivate 回读校验，失败如实计入 Failed；pcfg/mmagent/hib/bcd
        还原前统一查管理员；Save-UserPreset 拒绝 Windows 保留设备名。
  v0.14：备份改为边执行边落盘：开工前先试写 backup-*.pending.json（写不进直接中止、
        不做任何修改），每记录一条备份立即重写，全部完成后原子改名为正式备份；
        中途断电/被杀留下的 pending 备份可被 -Restore 正常识别并还原（还原时明确提示来源）。
  v0.13：新增 risky 项 gpu-name-spoof（改独显上报型号，默认不勾；后续版本已纳入需二次确认的主推全套）；
        新增 Get-GpuPanelApps（显卡控制面板安装检测，供界面决定是否显示入口按钮）；
        显卡指引只保留驱动层内容（游戏内那部分已有独立页）。
  v0.12：VC++ 体检只在「缺失某架构」时报问题，x64/x86 版本不同步改为中性陈述；
        下载链接改用 aka.ms/vs/18（vs/17 是 14.44 线，在更新的机器上必报 0x80070666）。
        主推预设 Id 改为 main。
  早期版本的变更见 git 历史；关键结论都已就地写在对应代码处的注释里。

  用法（任意 AI 助手或用户均可直接调用）：
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Detect [-Json]
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Preview
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Apply [-Items id1,id2] [-GamePath "游戏exe路径"] [-GpuSpoofModel "NVIDIA GeForce GTX 1050 Ti"] [-Risky]
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -ListRestoreItems [-Json]
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Restore [-RestoreItems id1,id2] [-BackupFile 备份文件]
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -ListItems
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -ListPresets
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Apply -Preset balanced
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Apply -Preset main -Risky
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -SavePreset "我的方案" -Items id1,id2

  安全设计：
    - Apply 在每次系统写入前，先将严格 schema + HMAC 写前日志落到 %ProgramData%\DeltaForceBooster\backup
    - Restore 按备份逆序恢复，原本不存在的值会被删除而不是写 0
    - 优化项分两档：safe（默认推荐）与 risky（有副作用，GUI 必须通过独立二次确认，
      CLI 必须显式加 -Risky 才会执行）。
#>
#requires -Version 5.1
[CmdletBinding()]
param(
  [switch]$Detect,
  [switch]$Preview,
  [switch]$Apply,
  [switch]$Restore,
  [switch]$ListRestoreItems,
  [switch]$ListItems,
  [switch]$ListPresets,
  [string]$Preset,
  [string]$SavePreset,
  [string]$DeletePreset,
  [string[]]$Items,
  [string]$GamePath,
  [string]$BackupFile,
  [string[]]$RestoreItems,
  [string]$ResultId,
  [string]$UserSid,
  [string]$UserLocalAppData,
  [string]$UserStateRoot,
  [ValidateSet('NVIDIA GeForce GTX 750 Ti', 'NVIDIA GeForce GTX 1050 Ti',
               'NVIDIA GeForce RTX 2050', 'NVIDIA GeForce RTX 2060', 'AMD Radeon RX560')]
  [string]$GpuSpoofModel,
  [switch]$Risky,
  [switch]$Json,
  [string]$RequestFile
)

$ErrorActionPreference = 'Stop'
$script:Root      = Split-Path -Parent $PSScriptRoot
$script:ToolsDir  = Join-Path $script:Root 'tools'
$script:WindowsDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$script:System32 = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
$script:SystemDrive = [IO.Path]::GetPathRoot($script:WindowsDir).TrimEnd('\')
$script:ProgramFiles = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
$script:CommonAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
$script:CurrentLocalAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
# 提权进程继承的 PSModulePath 可由发起用户控制。仅保留 Windows 与机器级模块目录，防止
# Get-CimInstance / MMAgent / Appx 等命令自动加载用户伪造的同名模块。
$script:TrustedModuleRoots = @(
  (Join-Path $PSHOME 'Modules'),
  (Join-Path $script:ProgramFiles 'WindowsPowerShell\Modules')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
$env:PSModulePath = ($script:TrustedModuleRoots -join [IO.Path]::PathSeparator)
$script:LegacyBackupDir = Join-Path $script:Root 'backup'
$script:LegacyConfigDir = Join-Path $script:Root 'config'
$script:LegacyProfileDir = Join-Path $script:Root 'profiles'
$script:TargetUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$script:TargetLocalAppData = [IO.Path]::GetFullPath($script:CurrentLocalAppData)
$script:UseExplicitUserHive = $false
$script:UserDataRoot = Join-Path $script:TargetLocalAppData 'DeltaForceBooster'
$script:ProgramDataRoot = Join-Path $script:CommonAppData 'DeltaForceBooster'
$script:ConfigDir = Join-Path $script:UserDataRoot 'config'
$script:ProfileDir = Join-Path $script:UserDataRoot 'profiles'
$script:BackupDir = Join-Path $script:ProgramDataRoot 'backup'
$script:IpcDir = Join-Path $script:ProgramDataRoot 'ipc'
$script:BackupKeyFile = Join-Path $script:ProgramDataRoot 'backup.key'
$script:LegacyRootsFile = Join-Path $script:ProgramDataRoot 'legacy-roots.json'
$script:BackupSchemaVersion = 3
$script:LegacySignedBackupSchemaVersion = 2
$script:BackupCatalogVersion = 3
$script:RestoreReceiptSchemaVersion = 1
$script:EngineResultFile = $null
$script:AppVersion = '0.0.0'
$guiVersionFile = Join-Path $script:Root 'gui\DeltaForceBooster-GUI.ps1'
if (Test-Path -LiteralPath $guiVersionFile -PathType Leaf) {
  $guiVersionText = [IO.File]::ReadAllText($guiVersionFile, [Text.Encoding]::UTF8)
  if ($guiVersionText -match '(?m)^\$script:GuiVersion\s*=\s*''(\d+\.\d+\.\d+)''\s*$') { $script:AppVersion = $Matches[1] }
}
$script:LockTaskPrefix = 'DeltaForceBooster-PowerPlanLock'
# 每个安装目录使用独立任务名：不再用 /F 覆盖系统里可能已经存在的同名任务。
$rootHash = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes(([IO.Path]::GetFullPath($script:Root)).ToUpperInvariant()))
$script:LockTask = '{0}-{1}' -f $script:LockTaskPrefix, (([BitConverter]::ToString($rootHash) -replace '-', '').Substring(0, 12))
$script:EngineMutexName = 'Global\DeltaForceBooster.Engine'
$script:PowerCfgExe = Join-Path $script:System32 'powercfg.exe'
$script:BcdEditExe = Join-Path $script:System32 'bcdedit.exe'
$script:SchTasksExe = Join-Path $script:System32 'schtasks.exe'

# ---------- 基础工具 ----------

function Test-Admin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Expand-TrustedProfilePath([string]$RawPath, [string]$ProfilePath) {
  if (-not $RawPath) { return $null }
  $value = "$RawPath"
  $map = [ordered]@{
    '%SystemDrive%' = $script:SystemDrive
    '%SystemRoot%' = $script:WindowsDir
  }
  if ($ProfilePath) {
    $map['%USERPROFILE%'] = $ProfilePath
    $map['%USERNAME%'] = Split-Path -Leaf $ProfilePath
    $map['%HOMEDRIVE%'] = [IO.Path]::GetPathRoot($ProfilePath).TrimEnd('\')
    $map['%HOMEPATH%'] = $ProfilePath.Substring([IO.Path]::GetPathRoot($ProfilePath).Length - 1)
  }
  foreach ($name in $map.Keys) {
    $replacement = ([string]$map[$name]).Replace('$', '$$')
    $value = [regex]::Replace($value, [regex]::Escape($name), $replacement, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  }
  if ($value -match '%[^%]+%') { throw "用户路径包含未允许的环境变量：$value" }
  $value
}

function Get-ProtectedUserStateRoot([string]$SidText) {
  try { $sid = New-Object Security.Principal.SecurityIdentifier($SidText) }
  catch { throw '受保护状态的 UserSid 格式无效' }
  if (-not $sid.IsAccountSid() -or $sid.Value -notmatch '^S-1-[0-9-]{3,184}$') {
    throw '受保护状态的 UserSid 不是账户 SID'
  }
  Join-Path (Join-Path $script:ProgramDataRoot 'users') $sid.Value
}

function Set-TargetUserContext([string]$SidText, [string]$LocalAppDataPath) {
  if ([bool]$SidText -ne [bool]$LocalAppDataPath) { throw 'UserSid 与 UserLocalAppData 必须同时提供' }
  if (-not $SidText) {
    $script:UseExplicitUserHive = $false
    $script:TargetUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $script:TargetLocalAppData = [IO.Path]::GetFullPath([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData))
  } else {
    try { $sid = New-Object Security.Principal.SecurityIdentifier($SidText) } catch { throw 'UserSid 格式无效' }
    $SidText = $sid.Value
    $lm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
    try {
      $pk = $lm.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SidText")
      if (-not $pk) { throw 'UserSid 没有对应的 Windows 用户配置文件' }
      try { $profileRaw = $pk.GetValue('ProfileImagePath', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
      finally { $pk.Close() }
    } finally { $lm.Close() }
    if (-not $profileRaw) { throw 'UserSid 没有对应的 Windows 用户配置文件' }
    $profileFull = [IO.Path]::GetFullPath((Expand-TrustedProfilePath "$profileRaw" $null)).TrimEnd('\')
    $hive = [Microsoft.Win32.Registry]::Users.OpenSubKey($SidText)
    if (-not $hive) { throw '目标用户注册表配置单元未加载，无法安全写入该用户的 HKCU' }
    try {
      $usk = $hive.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders')
      if ($usk) {
        try { $localRaw = $usk.GetValue('Local AppData', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
        finally { $usk.Close() }
      }
    } finally { $hive.Close() }
    if ($localRaw) { $expected = [IO.Path]::GetFullPath((Expand-TrustedProfilePath "$localRaw" $profileFull)).TrimEnd('\') }
    else { $expected = [IO.Path]::GetFullPath((Join-Path $profileFull 'AppData\Local')).TrimEnd('\') }
    $actual = [IO.Path]::GetFullPath($LocalAppDataPath).TrimEnd('\')
    if ($actual -ine $expected) { throw "UserLocalAppData 与 UserSid 的系统配置文件不匹配（期望 $expected）" }
    $drive = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($actual))
    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'UserLocalAppData 必须位于本地固定磁盘' }
    if (-not (Test-Path -LiteralPath $actual -PathType Container) -or (Test-PathHasReparsePoint $actual)) {
      throw 'UserLocalAppData 不存在或路径包含目录联接/符号链接'
    }
    $script:TargetUserSid = $SidText
    $script:TargetLocalAppData = $actual
    $script:UseExplicitUserHive = $true
  }
  # high token 绝不日常读写原用户可控 LocalAppData。管理员 GUI/CLI 的状态统一
  # 落到 ProgramData 的 per-SID 受保护分区；medium worker 仍保留 LocalAppData
  # 语义，仅用于原用户缓存清理与旧状态只读导出。
  $script:UserDataRoot = $(if (Test-Admin) {
    Get-ProtectedUserStateRoot $script:TargetUserSid
  } else {
    Join-Path $script:TargetLocalAppData 'DeltaForceBooster'
  })
  $script:ConfigDir = Join-Path $script:UserDataRoot 'config'
  $script:ProfileDir = Join-Path $script:UserDataRoot 'profiles'
}

function Test-AclRuleAllowsWrite($Rule) {
  # FullControl/Modify 这类复合枚举也包含“读”位，不能直接当 write-mask，否则 Users 只读 ACE 也会误判为可写。
  $writeMask = [Security.AccessControl.FileSystemRights]'WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, DeleteSubdirectoriesAndFiles, Delete, ChangePermissions, TakeOwnership'
  $rights = [int64]$Rule.FileSystemRights
  (($Rule.FileSystemRights -band $writeMask) -ne 0) -or (($rights -band 0x10000000) -ne 0) -or (($rights -band 0x40000000) -ne 0)
}

function Test-DirectoryAclSafe([string]$Path, [string[]]$TrustedSids, [string[]]$AllowedOwnerSids) {
  try {
    if (-not (Test-Path -LiteralPath $Path -PathType Container) -or (Test-PathHasReparsePoint $Path)) { return $false }
    $acl = [IO.Directory]::GetAccessControl($Path, [Security.AccessControl.AccessControlSections]'Owner, Access')
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin $AllowedOwnerSids) { return $false }
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
          $rule.IdentityReference.Value -notin $TrustedSids) {
        # CREATOR OWNER 的 InheritOnly ACE 不授予当前目录权限；当前目录没有任何非受信写 ACE 时，普通用户也无法创建子项来获得该权限。
        $creatorInheritOnly = ($rule.IdentityReference.Value -eq 'S-1-3-0' -and
          (($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0))
        if (-not $creatorInheritOnly -and (Test-AclRuleAllowsWrite $rule)) { return $false }
      }
    }
    $true
  } catch { $false }
}

function Test-ProtectedDirectoryAclExact([string]$Path, [bool]$UsersRead) {
  try {
    $trusted = @('S-1-5-18','S-1-5-32-544')
    if (-not (Test-DirectoryAclSafe $Path $trusted $trusted)) { return $false }
    $acl = [IO.Directory]::GetAccessControl($Path, [Security.AccessControl.AccessControlSections]'Owner, Access')
    if (-not $acl.AreAccessRulesProtected) { return $false }
    $full = [Security.AccessControl.FileSystemRights]::FullControl
    $seen = @{}
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $sid = $rule.IdentityReference.Value
      if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) { return $false }
      if ($sid -in $trusted) {
        if (($rule.FileSystemRights -band $full) -ne $full) { return $false }
        $seen[$sid] = $true
      } elseif ($UsersRead -and $sid -eq 'S-1-5-32-545') {
        if (Test-AclRuleAllowsWrite $rule) { return $false }
      } else { return $false }
    }
    [bool]($seen['S-1-5-18'] -and $seen['S-1-5-32-544'])
  } catch { $false }
}

function New-ProtectedDirectory([string]$Path, [bool]$UsersRead) {
  if (-not (Test-Admin)) { throw "初始化受保护目录需要管理员权限：$Path" }
  $acl = New-Object Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true, $false)
  $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
  $none = [Security.AccessControl.PropagationFlags]::None
  $allow = [Security.AccessControl.AccessControlType]::Allow
  $adminSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
  $acl.SetOwner($adminSid)
  foreach ($sidText in 'S-1-5-18','S-1-5-32-544') {
    $sid = New-Object Security.Principal.SecurityIdentifier($sidText)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, [Security.AccessControl.FileSystemRights]::FullControl, $inherit, $none, $allow)
    [void]$acl.AddAccessRule($rule)
  }
  if ($UsersRead) {
    $users = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-545')
    $readRule = New-Object Security.AccessControl.FileSystemAccessRule($users, [Security.AccessControl.FileSystemRights]'ReadAndExecute, Synchronize', $inherit, $none, $allow)
    [void]$acl.AddAccessRule($readRule)
  }
  if (Test-Path -LiteralPath $Path) {
    # 已有目录若曾由普通用户创建，对方可能仍持有可写句柄。此时不能“接管后继续”，必须关闭失败。
    if (-not (Test-DirectoryAclSafe $Path @('S-1-5-18','S-1-5-32-544') @('S-1-5-18','S-1-5-32-544'))) {
      throw "已有受保护目录的所有者或权限不安全，已拒绝接管：$Path"
    }
  } else {
    $parent = Split-Path -Parent $Path
    if ($parent -and (Test-Path -LiteralPath $parent) -and (Test-PathHasReparsePoint $parent)) {
      throw "受保护目录父路径包含目录联接或符号链接：$parent"
    }
    # .NET Framework 的安全描述符重载让“创建目录”和“设置 ACL”成为一步；如果同名目录被竞态预建，下面的再校验会关闭失败。
    [void][IO.Directory]::CreateDirectory($Path, $acl)
    if (-not (Test-DirectoryAclSafe $Path @('S-1-5-18','S-1-5-32-544') @('S-1-5-18','S-1-5-32-544'))) {
      throw "受保护目录创建后所有者或权限校验失败：$Path"
    }
  }
  [IO.Directory]::SetAccessControl($Path, $acl)
  if (-not (Test-ProtectedDirectoryAclExact $Path $UsersRead)) { throw "受保护目录 ACL 最终校验失败：$Path" }
}

function Set-ProtectedFileAcl([string]$Path) {
  $acl = New-Object Security.AccessControl.FileSecurity
  $acl.SetAccessRuleProtection($true, $false)
  $adminSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
  $acl.SetOwner($adminSid)
  foreach ($sidText in 'S-1-5-18','S-1-5-32-544') {
    $sid = New-Object Security.Principal.SecurityIdentifier($sidText)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, [Security.AccessControl.FileSystemRights]::FullControl,
      [Security.AccessControl.AccessControlType]::Allow)
    [void]$acl.AddAccessRule($rule)
  }
  [IO.File]::SetAccessControl($Path, $acl)
}

function Test-ProtectedFileAcl([string]$Path) {
  try {
    $acl = [IO.File]::GetAccessControl($Path, [Security.AccessControl.AccessControlSections]'Owner, Access')
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin @('S-1-5-18','S-1-5-32-544')) { return $false }
    if (-not $acl.AreAccessRulesProtected) { return $false }
    $full = [Security.AccessControl.FileSystemRights]::FullControl
    $seen = @{}
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $sid = $rule.IdentityReference.Value
      if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or $sid -notin @('S-1-5-18','S-1-5-32-544') -or
          (($rule.FileSystemRights -band $full) -ne $full)) { return $false }
      $seen[$sid] = $true
    }
    [bool]($seen['S-1-5-18'] -and $seen['S-1-5-32-544'])
  } catch { $false }
}

function Get-LegacyRoots {
  $script:LegacyRootWarnings = @()
  if (-not (Test-Path -LiteralPath $script:LegacyRootsFile -PathType Leaf)) { return @() }
  if (-not (Test-Admin)) { return @() }
  if (Test-PathHasReparsePoint $script:LegacyRootsFile -or -not (Test-ProtectedFileAcl $script:LegacyRootsFile)) {
    throw 'legacy-roots.json 类型或权限异常，已拒绝读取旧备份位置'
  }
  $f = Get-Item -LiteralPath $script:LegacyRootsFile -Force
  if ($f.Length -gt 64KB) { throw 'legacy-roots.json 超过 64KB 上限' }
  try { $doc = [IO.File]::ReadAllText($script:LegacyRootsFile, [Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop }
  catch { throw "legacy-roots.json 格式损坏：$($_.Exception.Message)" }
  Assert-ExactProperties $doc @('SchemaVersion','Roots') @() 'legacy-roots.json'
  if ([int]$doc.SchemaVersion -ne 1) { throw "不支持的 legacy-roots.json 版本：$($doc.SchemaVersion)" }
  $roots = @($doc.Roots)
  if ($roots.Count -gt 16) { throw 'legacy-roots.json 的 Roots 超过 16 项上限' }
  $valid = @()
  foreach ($raw in $roots) {
    if ("$raw" -notmatch '^[A-Za-z]:\\' -or (Split-Path -Leaf "$raw") -notmatch '^\.DeltaForceBooster\.migrated-[0-9A-Fa-f]{32}$') {
      throw "旧安装根路径格式无效：$raw"
    }
    $root = [IO.Path]::GetFullPath("$raw").TrimEnd('\')
    $drive = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($root))
    if ($drive.DriveType -ne [IO.DriveType]::Fixed) { throw "旧安装根不在本地固定磁盘：$root" }
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
      $script:LegacyRootWarnings += "已登记的旧安装根已不存在，已跳过：$root"
      continue
    }
    if (Test-PathHasReparsePoint $root) {
      $script:LegacyRootWarnings += "已登记的旧安装根含重解析点，已跳过：$root"
      continue
    }
    $valid += $root
  }
  @($valid | Select-Object -Unique)
}

function Test-TrustedProgramBackupDir([string]$Dir) {
  try {
    $rootFull = [IO.Path]::GetFullPath($script:Root).TrimEnd('\')
    $dirFull = [IO.Path]::GetFullPath($Dir).TrimEnd('\')
    $programRoots = @(
      [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles),
      [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
    ) | Where-Object { $_ } | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\') } | Select-Object -Unique
    if (-not @($programRoots | Where-Object {
      $rootFull.StartsWith(($_ + '\'), [StringComparison]::OrdinalIgnoreCase)
    }).Count) { return $false }
    if (-not $dirFull.StartsWith(($rootFull + '\'), [StringComparison]::OrdinalIgnoreCase)) { return $false }
    $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
    $trusted = @('S-1-5-18','S-1-5-32-544',$trustedInstaller)
    (Test-DirectoryAclSafe $rootFull $trusted $trusted) -and (Test-DirectoryAclSafe $dirFull $trusted $trusted)
  } catch { $false }
}

function Get-LegacyBackupDirs {
  $script:LegacyBackupWarnings = @()
  $dirs = @()
  if (Test-Path -LiteralPath $script:LegacyBackupDir -PathType Container) {
    if (Test-TrustedProgramBackupDir $script:LegacyBackupDir) { $dirs += [IO.Path]::GetFullPath($script:LegacyBackupDir).TrimEnd('\') }
    else { $script:LegacyBackupWarnings += "程序目录中的旧备份目录不是受信的只读 Program Files 路径，已跳过：$script:LegacyBackupDir" }
  }
  $roots = @(Get-LegacyRoots)
  $script:LegacyBackupWarnings += @($script:LegacyRootWarnings)
  $dirs += @(($roots) | ForEach-Object {
    $d = [IO.Path]::GetFullPath((Join-Path $_ 'backup'))
    if (-not (Test-Path -LiteralPath $d -PathType Container)) {
      $script:LegacyBackupWarnings += "旧安装根中没有备份目录，已跳过：$d"
    } elseif (Test-PathHasReparsePoint $d) {
      $script:LegacyBackupWarnings += "旧备份目录含重解析点，已跳过：$d"
    } else { $d }
  })
  @($dirs | Select-Object -Unique)
}

function Initialize-UserDataStore {
  if (Test-Admin) {
    $expected = [IO.Path]::GetFullPath((Get-ProtectedUserStateRoot $script:TargetUserSid)).TrimEnd('\')
    if ([IO.Path]::GetFullPath($script:UserDataRoot).TrimEnd('\') -ine $expected) {
      throw '管理员进程的用户状态路径不在受保护 per-SID 分区'
    }
    $usersRoot = Join-Path $script:ProgramDataRoot 'users'
    foreach ($d in $script:ProgramDataRoot,$usersRoot,$script:UserDataRoot,$script:ConfigDir,$script:ProfileDir) {
      New-ProtectedDirectory $d $false
    }
    return
  }
  # medium worker 只初始化自己的用户目录；它不会写 ProgramData。
  $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $currentLocal = [IO.Path]::GetFullPath([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)).TrimEnd('\')
  if ($currentSid -ine $script:TargetUserSid -or $currentLocal -ine $script:TargetLocalAppData.TrimEnd('\')) {
    throw '用户数据只能由目标用户的普通权限进程初始化'
  }
  foreach ($d in $script:ConfigDir,$script:ProfileDir) {
    if (-not (Test-Path -LiteralPath $d)) { [void][IO.Directory]::CreateDirectory($d) }
  }
  # 旧版把可写数据放在程序目录。只迁移明确的 JSON 文件，目标已存在时绝不覆盖用户新数据。
  $legacyPower = Join-Path $script:LegacyConfigDir 'power-scheme.json'
  $newPower = Join-Path $script:ConfigDir 'power-scheme.json'
  if ((Test-Path -LiteralPath $legacyPower) -and -not (Test-Path -LiteralPath $newPower)) {
    Copy-Item -LiteralPath $legacyPower -Destination $newPower
  }
  if (Test-Path -LiteralPath $script:LegacyProfileDir) {
    foreach ($f in @(Get-ChildItem -LiteralPath $script:LegacyProfileDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
      $dest = Join-Path $script:ProfileDir $f.Name
      if (-not (Test-Path -LiteralPath $dest)) { Copy-Item -LiteralPath $f.FullName -Destination $dest }
    }
  }
}

function Initialize-ProtectedStore {
  New-ProtectedDirectory $script:ProgramDataRoot $false
  New-ProtectedDirectory $script:BackupDir $false
  if (Test-Path -LiteralPath $script:BackupKeyFile) {
    $keyItem = Get-Item -LiteralPath $script:BackupKeyFile -Force
    if ($keyItem.PSIsContainer -or (Test-PathHasReparsePoint $script:BackupKeyFile) -or -not (Test-ProtectedFileAcl $script:BackupKeyFile)) {
      throw '备份完整性密钥类型或权限异常，已拒绝继续；请修复 ProgramData 文件后重试'
    }
  }
  if (-not (Test-Path -LiteralPath $script:BackupKeyFile)) {
    $key = New-Object byte[] 32
    $rng = New-Object Security.Cryptography.RNGCryptoServiceProvider
    try { $rng.GetBytes($key) } finally { $rng.Dispose() }
    $fs = New-Object IO.FileStream($script:BackupKeyFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
                                  [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
    try { $fs.Write($key, 0, $key.Length); $fs.Flush($true) } finally { $fs.Dispose() }
    Set-ProtectedFileAcl $script:BackupKeyFile
  }
}

function Get-BackupHmacKey {
  Initialize-ProtectedStore
  $key = [IO.File]::ReadAllBytes($script:BackupKeyFile)
  if ($key.Length -ne 32) { throw '备份完整性密钥损坏（长度不正确）' }
  $key
}

function Initialize-IpcStore {
  New-ProtectedDirectory $script:ProgramDataRoot $false
  New-ProtectedDirectory $script:IpcDir $true
  # 结果只用于一次提权调用回传；清理 24 小时前且名称严格为 GUID 的旧文件，避免长期堆积。
  $cutoff = (Get-Date).AddHours(-24)
  foreach ($f in @(Get-ChildItem -LiteralPath $script:IpcDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.BaseName -match '^[0-9a-fA-F-]{36}$' -and $_.LastWriteTime -lt $cutoff })) {
    Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
  }
}

function Write-BytesAtomic([string]$Path, [byte[]]$Bytes) {
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { throw "目标目录不存在：$dir" }
  $tmp = Join-Path $dir ('.{0}.{1}.tmp' -f (Split-Path -Leaf $Path), [guid]::NewGuid().ToString('N'))
  $backup = Join-Path $dir ('.{0}.{1}.bak' -f (Split-Path -Leaf $Path), [guid]::NewGuid().ToString('N'))
  try {
    $fs = New-Object IO.FileStream($tmp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
                                   [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
    try { $fs.Write($Bytes, 0, $Bytes.Length); $fs.Flush($true) } finally { $fs.Dispose() }
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, $backup, $true) }
    else { [IO.File]::Move($tmp, $Path) }
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
  }
}

function Write-IpcResult([string]$Id, [string]$Action, $Data, [int]$ExitCode, [string]$ErrorMessage) {
  if (-not $Id) { return }
  $parsed = [guid]::Empty
  if (-not [guid]::TryParseExact($Id, 'D', [ref]$parsed)) { throw 'ResultId 必须是标准 D 格式 GUID' }
  $outputPath = $null
  if ($script:EngineResultFile) {
    $sessionRoot = Get-ValidatedEngineSessionRoot
    $expectedPath = Join-Path $sessionRoot ("engine-result-{0}.json" -f $parsed.ToString('D'))
    $outputPath = [IO.Path]::GetFullPath($script:EngineResultFile)
    if ($outputPath -ine [IO.Path]::GetFullPath($expectedPath) -or
        (Test-Path -LiteralPath $outputPath) -and (Test-PathHasReparsePoint $outputPath)) {
      throw '管理员引擎结果文件不在当前受保护会话目录'
    }
  } else {
    Initialize-IpcStore
    $outputPath = Join-Path $script:IpcDir ($parsed.ToString('D') + '.json')
  }
  $body = [ordered]@{
    SchemaVersion = 1; ResultId = $parsed.ToString('D'); Action = $Action
    CreatedUtc = [DateTime]::UtcNow.ToString('o'); ExitCode = $ExitCode
    Ok = ($ExitCode -eq 0); Data = $Data; Error = $ErrorMessage
  }
  $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($body | ConvertTo-Json -Depth 10))
  Write-BytesAtomic $outputPath $bytes
  if ($script:EngineResultFile) {
    Set-ProtectedFileAcl $outputPath
    if ((Test-PathHasReparsePoint $outputPath) -or -not (Test-ProtectedFileAcl $outputPath)) {
      throw '管理员引擎结果文件权限校验失败'
    }
  }
}

function Enter-EngineMutex {
  $created = $false
  $m = New-Object Threading.Mutex($false, $script:EngineMutexName, [ref]$created)
  try {
    if (-not $m.WaitOne(0)) { throw '另一个优化或还原任务正在运行，请等待它完成后重试' }
  } catch [Threading.AbandonedMutexException] {
    # 上一进程异常退出时系统把互斥锁交给当前进程，继续接管并依赖 pending 日志恢复。
  } catch {
    $m.Dispose(); throw
  }
  $m
}

function Exit-EngineMutex($Mutex) {
  if (-not $Mutex) { return }
  try { $Mutex.ReleaseMutex() } catch {}
  $Mutex.Dispose()
}

# 用 .NET Registry API 而不是 PowerShell Provider：值名是完整 exe 路径时含反斜杠，
# Provider 的 -Name 会做通配符解析，.NET API 没有这个坑。
function Split-RegPath([string]$Path) {
  # 输出两个对象（根键、子路径），调用侧用 $base,$sub = ... 解包；不要再包一层数组
  if     ($Path -match '^HKLM:\\?(.*)$') { [Microsoft.Win32.Registry]::LocalMachine; $Matches[1] }
  elseif ($Path -match '^HKCU:\\?(.*)$') {
    if ($script:UseExplicitUserHive) { [Microsoft.Win32.Registry]::Users; "$script:TargetUserSid\$($Matches[1])" }
    else { [Microsoft.Win32.Registry]::CurrentUser; $Matches[1] }
  }
  else   { throw "不支持的注册表根：$Path" }
}

function Get-RegValue([string]$Path, [string]$Name) {
  $base, $sub = Split-RegPath $Path
  $k = $base.OpenSubKey($sub)
  if (-not $k) { return $null }
  try { $k.GetValue($Name, $null) } finally { $k.Close() }
}

function Get-RegValueKind([string]$Path, [string]$Name) {
  $base, $sub = Split-RegPath $Path
  $k = $base.OpenSubKey($sub)
  if (-not $k) { return $null }
  try { try { $k.GetValueKind($Name) } catch { $null } } finally { $k.Close() }
}

function Set-RegValue([string]$Path, [string]$Name, $Value, [string]$Kind) {
  $base, $sub = Split-RegPath $Path
  $k = $base.CreateSubKey($sub)
  try { $k.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]$Kind) } finally { $k.Close() }
}

function Remove-RegValue([string]$Path, [string]$Name) {
  $base, $sub = Split-RegPath $Path
  $k = $base.OpenSubKey($sub, $true)
  if ($k) { try { $k.DeleteValue($Name, $false) } finally { $k.Close() } }
}

# ---------- 电源计划 ----------

$script:GuidRx = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

$script:BalancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
$script:UltimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'

# 工具自建方案的专属名：用户可能自建过任意名字的方案（实测有人的方案就叫「4060」），
# 新建的方案必须一眼能认出来自本工具，避免与用户自己维护的方案混淆
$script:ToolSchemeName = '三角洲优化 · 卓越性能'
# 电源计划是系统全局对象；直接从受保护的系统配置按专属名称定位，不再从
# 目标用户可写的 LocalAppData 读写 GUID，避免提权进程与用户目录产生 TOCTOU。
function Get-ToolSchemeGuid {
  @(Get-PowerSchemes | Where-Object { $_.Name -eq $script:ToolSchemeName } | Select-Object -First 1).Guid
}

# 方案名在注册表里是资源引用串 "@...powrprof.dll,-19,Ultimate Performance"，
# 末段英文名与系统显示语言无关，取它比解析 powercfg 文本可靠
function Get-SchemeDisplayName([string]$FriendlyName) {
  if ($FriendlyName -match '^@.*,-?\d+,(.+)$') { return $Matches[1] }
  $FriendlyName
}

# 直接读注册表而不解析 powercfg /list：powercfg 按 OEM 代码页输出，
# 输出被重定向时中文方案名会变成 ??，导致匹配不到"卓越性能"而重复创建方案
function Get-PowerSchemes {
  $root = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
  $active = Get-RegValue $root 'ActivePowerScheme'
  $base, $sub = Split-RegPath $root
  $k = $base.OpenSubKey($sub)
  if (-not $k) { return @() }
  $schemes = @()
  try {
    foreach ($g in $k.GetSubKeyNames()) {
      if ($g -notmatch "^$script:GuidRx$") { continue }
      $schemes += [pscustomobject]@{
        Guid   = $g
        Name   = Get-SchemeDisplayName (Get-RegValue "$root\$g" 'FriendlyName')
        Active = ($g -eq $active)
      }
    }
  } finally { $k.Close() }
  $schemes
}

function Get-ActiveScheme { Get-PowerSchemes | Where-Object Active | Select-Object -First 1 }

# setactive 后必须回读 ActivePowerScheme 确认真切过去了：实机踩过「激活失败但被静默
# 当成成功」的坑（模板方案不可激活），powercfg 的输出留在 $script:LastActivateOut 供报错用
function Invoke-SchemeActivate([string]$SchemeGuid) {
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & $script:PowerCfgExe /setactive $SchemeGuid 2>&1
  $script:LastActivateOut = ("$out").Trim()
  if ($LASTEXITCODE -ne 0) { return $false }
  $now = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActivePowerScheme'
  ("$now" -ieq $SchemeGuid)
}

# 原方案可能被 Armoury Crate、整机控制中心或用户在优化后删除。此时反复写回其他设置
# 也不可能让那个 GUID 重新出现；继续把工具的卓越性能方案留在活动状态反而会让还原
# 看似完成、实际仍带着激进电源参数。精确回切失败时优先退到 Windows 内置“平衡”，
# 并把“非精确还原”作为结构化提示返回；平衡方案也不可用时仍按失败关闭。
function Invoke-RestorePowerScheme([string]$OriginalGuid) {
  $schemes = @(Get-PowerSchemes)
  $originalExists = @($schemes | Where-Object { $_.Guid -ieq $OriginalGuid }).Count -gt 0
  if (Invoke-SchemeActivate $OriginalGuid) {
    return [pscustomobject]@{ Guid=$OriginalGuid; Exact=$true; Message=$null }
  }

  $originalOut = "$script:LastActivateOut"
  $originalReason = $(if (-not $originalExists) {
    "原电源方案 $OriginalGuid 已不存在"
  } elseif ($originalOut) {
    "原电源方案激活失败（powercfg 原话：$originalOut）"
  } else { '原电源方案激活后回读未生效' })

  $balanced = @($schemes | Where-Object { $_.Guid -ieq $script:BalancedGuid } | Select-Object -First 1)
  if ($OriginalGuid -ine $script:BalancedGuid -and $balanced.Count -gt 0 -and
      (Invoke-SchemeActivate $script:BalancedGuid)) {
    return [pscustomobject]@{
      Guid=$script:BalancedGuid; Exact=$false
      Message="$originalReason；已切换到 Windows「平衡」作为安全回退，未精确恢复原方案"
    }
  }

  $fallbackOut = "$script:LastActivateOut"
  $fallbackReason = $(if ($balanced.Count -eq 0) { 'Windows「平衡」方案也不存在' }
    elseif ($fallbackOut) { "Windows「平衡」方案激活失败（powercfg 原话：$fallbackOut）" }
    else { 'Windows「平衡」方案激活后回读未生效' })
  throw "$originalReason；$fallbackReason"
}

function Enable-UltimateScheme {
  # 实机结论（i5-12600KF / Win11 22631）：卓越性能 GUID e9a42b02 在多数非工作站版上只是
  # 注册表里可见的「模板」，直接 setactive 会失败，必须 duplicatescheme 实例化后才能激活。
  # 因此候选按「工具自建实例 → 名字匹配的其他实例 → 模板本身」排序逐个试激活（每次都
  # 回读校验），全部失败才实例化新方案——保证反复执行复用现成方案、不堆积
  $schemes = @(Get-PowerSchemes)
  $cands = New-Object System.Collections.Generic.List[object]
  $toolGuid = Get-ToolSchemeGuid
  if ($toolGuid) {
    $t = $schemes | Where-Object { $_.Guid -ieq $toolGuid } | Select-Object -First 1
    if ($t) { [void]$cands.Add($t) }
  }
  foreach ($s in $schemes) {
    if ($s.Guid -ne $script:UltimateGuid -and $s.Name -match '卓越|Ultimate' -and
        -not ($cands | Where-Object { $_.Guid -ieq $s.Guid })) { [void]$cands.Add($s) }
  }
  $tpl = $schemes | Where-Object { $_.Guid -eq $script:UltimateGuid } | Select-Object -First 1
  if ($tpl) { [void]$cands.Add($tpl) }

  # 同类方案堆了多个时提示用户可手动清理；绝不自动删除（可能正被用户使用）
  $note = $null
  $dup = @($schemes | Where-Object { $_.Guid -ne $script:UltimateGuid -and $_.Name -match '卓越|Ultimate' })
  if ($dup.Count -gt 1) {
    $note = "检测到 $($dup.Count) 个卓越性能类方案，多余的可在控制面板→电源选项里手动删除（本工具不会自动删）"
  }

  foreach ($c in $cands) {
    if (Invoke-SchemeActivate $c.Guid) {
      return [pscustomobject]@{ Guid = $c.Guid; Created = $false; Note = $note }
    }
  }

  # 没有可直接激活的现成方案：从模板实例化，挂工具专属名（防与用户自建方案混淆），再激活
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & $script:PowerCfgExe -duplicatescheme $script:UltimateGuid 2>&1
  if ($LASTEXITCODE -ne 0 -or "$out" -notmatch "($script:GuidRx)") {
    throw "无法创建卓越性能电源计划（powercfg 原话：$(("$out").Trim())）"
  }
  $newGuid = $Matches[1]
  $ren = & $script:PowerCfgExe -changename $newGuid $script:ToolSchemeName '由 DeltaForceBooster 创建，还原优化后如不需要可手动删除' 2>&1
  if ($LASTEXITCODE -ne 0) { Write-Warning "电源计划已创建但命名失败：$(("$ren").Trim())" }
  if (-not (Invoke-SchemeActivate $newGuid)) {
    throw "新方案已创建但激活失败（powercfg 原话：$script:LastActivateOut）"
  }
  [pscustomobject]@{ Guid = $newGuid; Created = $true; Note = $note }
}

$script:PsRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings'
$script:PuRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'

# 本机是否支持该电源项（不支持的 CPU 上注册表里根本没有这个键）
function Test-PowerSetting([string]$Sub, [string]$Setting) {
  $base, $subPath = Split-RegPath "$script:PsRoot\$Sub\$Setting"
  $k = $base.OpenSubKey($subPath)
  if ($k) { $k.Close(); return $true }
  $false
}

# 该项是否被隐藏（Attributes 的第 0 位为 1 即隐藏）。隐藏项 powercfg /q 不会输出。
function Test-PowerSettingHidden([string]$Sub, [string]$Setting) {
  $a = Get-RegValue "$script:PsRoot\$Sub\$Setting" 'Attributes'
  ($null -ne $a) -and (([int]$a -band 1) -eq 1)
}

# 读活动方案下该项的 AC 取值。直接读注册表而不用 powercfg /q：隐藏项 /q 不输出，
# 且中文系统输出没法用英文关键字解析。方案没显式设值就回落默认表。
# DefaultPowerSchemeValues 里只有三个内置方案 GUID，duplicatescheme 出来的方案两级都
# 读不到、返回 $null——这是「继承默认」的合法状态，调用方绝不能当成错误。
function Get-PowerSettingAc([string]$Sub, [string]$Setting) {
  if (-not (Test-PowerSetting $Sub $Setting)) { return $null }
  $act = Get-ActiveScheme
  if (-not $act) { return $null }
  $v = Get-RegValue "$script:PuRoot\$($act.Guid)\$Sub\$Setting" 'ACSettingIndex'
  if ($null -ne $v) { return [int]$v }
  $v = Get-RegValue "$script:PsRoot\$Sub\$Setting\DefaultPowerSchemeValues\$($act.Guid)" 'ACSettingIndex'
  if ($null -ne $v) { return [int]$v }
  $null
}

# 只读方案下的显式值（不回落默认表）：备份要的是「写入前方案里到底有没有值」，
# 回落值写进备份会在还原时把「继承」固化成显式设置，语义就变了
function Get-PowerSettingAcExplicit([string]$SchemeGuid, [string]$Sub, [string]$Setting) {
  $v = Get-RegValue "$script:PuRoot\$SchemeGuid\$Sub\$Setting" 'ACSettingIndex'
  if ($null -ne $v) { return [int]$v }
  $null
}

# 还原「原本无显式值」的电源项：删除方案下的设置子键，回到继承默认态。
# 写一个猜出来的数字会把继承关系永久改成显式覆盖，所以必须删键而不是写值。
function Remove-PowerSettingAcOverride([string]$SchemeGuid, [string]$Sub, [string]$Setting) {
  if (-not $SchemeGuid) {
    $act = Get-ActiveScheme
    if (-not $act) { throw '无法确定要还原的电源方案' }
    $SchemeGuid = $act.Guid
  }
  $base, $parent = Split-RegPath "$script:PuRoot\$SchemeGuid\$Sub"
  $k = $base.OpenSubKey($parent, $true)
  if ($k) { try { $k.DeleteSubKeyTree($Setting, $false) } finally { $k.Close() } }
  # 改的是活动方案时要重新 setactive 才即时生效；非活动方案执行这句无害
  $ErrorActionPreference = 'SilentlyContinue'
  & $script:PowerCfgExe /setactive SCHEME_CURRENT 2>&1 | Out-Null
}

# 解除隐藏，返回原 Attributes 值供还原用；已可见则返回 $null
function Show-PowerSetting([string]$Sub, [string]$Setting) {
  if (-not (Test-PowerSettingHidden $Sub $Setting)) { return $null }
  $old = Get-RegValue "$script:PsRoot\$Sub\$Setting" 'Attributes'
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & $script:PowerCfgExe -attributes $Sub $Setting -ATTRIB_HIDE 2>&1
  if ($LASTEXITCODE -ne 0) { throw "解除电源项隐藏失败$(if ("$out") { "（powercfg 原话：$(("$out").Trim())）" } else { '（需要管理员权限）' })" }
  $old
}

# $SchemeGuid 可选：还原时按备份里记录的方案精确写回（用户可能已手动切走活动方案），
# 不传则写当前活动方案（Apply 路径的既有行为）
function Set-PowerSettingAc([string]$Sub, [string]$Setting, [int]$Value, [string]$SchemeGuid) {
  $target = $(if ($SchemeGuid) { $SchemeGuid } else { 'SCHEME_CURRENT' })
  $ErrorActionPreference = 'SilentlyContinue'
  # 把 powercfg 的原话带进异常：曾有 12 代机器报「尝试写入不受支持的设置」，
  # 只抛笼统的「写入失败」会让用户完全没法定位
  $out = & $script:PowerCfgExe /setacvalueindex $target $Sub $Setting $Value 2>&1
  if ($LASTEXITCODE -ne 0) { throw "写入电源项失败$(if ("$out") { "（powercfg 原话：$(("$out").Trim())）" } else { '' })" }
  $refresh = & $script:PowerCfgExe /setactive SCHEME_CURRENT 2>&1
  if ($LASTEXITCODE -ne 0) { throw "刷新电源方案失败（powercfg 原话：$(("$refresh").Trim())）" }
  $actual = $(if ($SchemeGuid) { Get-PowerSettingAcExplicit $SchemeGuid $Sub $Setting } else { Get-PowerSettingAc $Sub $Setting })
  if ($null -eq $actual -or [int]$actual -ne $Value) { throw "电源项写入后验证失败（期望 $Value，实际 $actual）" }
}

# ---------- 内存压缩 / 计划任务 ----------

function Get-MMAgentState([string]$Feature) {
  try {
    # 非管理员下会"拒绝访问"，这里静默失败交由调用方显示"读取失败"，不把红字抛给用户
    $a = Get-MMAgent -ErrorAction SilentlyContinue
    if (-not $a) { return $null }
    if ($Feature -eq 'mc') { return [bool]$a.MemoryCompression } else { return [bool]$a.PageCombining }
  } catch { return $null }
}

function Set-MMAgentState([string]$Feature, [bool]$Enabled) {
  if ($Feature -eq 'mc') {
    if ($Enabled) { Enable-MMAgent -mc } else { Disable-MMAgent -mc }
  } else {
    if ($Enabled) { Enable-MMAgent -pc } else { Disable-MMAgent -pc }
  }
}

function Test-LockTaskExists {
  [bool](Test-BoosterLockTask $script:LockTask)
}

# ---------- 休眠 / 引导配置 / 显卡专项 ----------

function Get-HibernateState {
  # HibernateEnabled 在部分机器上不存在（本机实测缺失），退而看休眠文件是否在，
  # 两个信号都拿不到才算读取失败——备份必须基于真实旧状态
  $v = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
  if ($null -ne $v) { return ([int]$v -ne 0) }
  [bool](Test-Path -LiteralPath (Join-Path $script:SystemDrive 'hiberfil.sys'))
}

function Set-HibernateEnabled([bool]$On) {
  # powercfg 失败信息走 stderr，Stop 模式下会变终止错误，这里局部降级后查退出码
  $ErrorActionPreference = 'SilentlyContinue'
  & $script:PowerCfgExe -h $(if ($On) { 'on' } else { 'off' }) 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw '设置休眠状态失败（需要管理员权限）' }
  if ((Get-HibernateState) -ne $On) { throw '设置休眠状态后回读验证失败' }
}

# 读 {current} 引导项里某个值。bcdedit 连读取都要管理员，非管理员返回 $null；
# 值名（disabledynamictick 等）和取值（Yes/Off 等）不随系统语言变化，可安全解析
function Get-BcdValue([string]$Name) {
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & $script:BcdEditExe /enum "{current}" 2>&1
  if ($LASTEXITCODE -ne 0) { return $null }
  foreach ($line in @($out)) {
    if ("$line" -match ('^\s*' + [regex]::Escape($Name) + '\s+(\S+)\s*$')) { return $Matches[1] }
  }
  # 能读到引导项但没有该值：多数值默认就不写入，这是合法状态，与"读取失败"区分开
  'absent'
}

function Set-BcdEntryValue([string]$Name, [string]$Value) {
  $ErrorActionPreference = 'SilentlyContinue'
  & $script:BcdEditExe /set "{current}" $Name $Value 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "写入引导配置失败：$Name（需要管理员权限）" }
  $actual = Get-BcdValue $Name
  if ($null -eq $actual -or "$actual" -ine "$Value") { throw "写入引导配置后验证失败：$Name（期望 $Value，实际 $actual）" }
}

function Get-TaskXml([string]$TaskName) {
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & $script:SchTasksExe /Query /TN $TaskName /XML 2>&1
  if ($LASTEXITCODE -ne 0) { return $null }
  try { [xml](@($out) -join "`r`n") } catch { $null }
}

function Test-BoosterLockTask([string]$TaskName) {
  $xml = Get-TaskXml $TaskName
  if (-not $xml) { return $false }
  $cmd = $xml.SelectSingleNode("//*[local-name()='Exec']/*[local-name()='Command']")
  $arg = $xml.SelectSingleNode("//*[local-name()='Exec']/*[local-name()='Arguments']")
  if (-not $cmd -or -not $arg) { return $false }
  try { $commandPath = [IO.Path]::GetFullPath("$($cmd.InnerText)".Trim().Trim('"')) } catch { return $false }
  [bool]($commandPath -ieq [IO.Path]::GetFullPath($script:PowerCfgExe) -and
         "$($arg.InnerText)".Trim() -match ('(?i)^/setactive\s+' + $script:GuidRx + '$'))
}

function Remove-BcdEntryValue([string]$Name) {
  $ErrorActionPreference = 'SilentlyContinue'
  # 原本就没设过该值时 deletevalue 会返回非零；最终回读为 absent 才算达到还原目标。
  $out = & $script:BcdEditExe /deletevalue "{current}" $Name 2>&1
  $code = $LASTEXITCODE
  $actual = Get-BcdValue $Name
  if ($null -eq $actual) { throw "删除引导配置后无法回读验证：$Name" }
  if ($actual -ne 'absent') { throw "删除引导配置失败：$Name（退出码 $code，实际仍为 $actual；bcdedit 原话：$(("$out").Trim())）" }
}

# 独显在 Enum\PCI 下的实例路径。同一厂商 ID 下还挂着音频等非显卡设备，不能只看 VEN。
# MainGpuPnp 来自 Win32_VideoController 的精确设备实例，再复验厂商 ID 与显示适配器 ClassGUID；
# NVIDIA 多卡还必须已由 PCI BDF 与 NVML 对齐，避免真实型号恢复后选错同厂商设备。
# 实测（RTX 3070 Laptop / Win11 26200）：该键 Owner=BUILTIN\Administrators 且管理员组
# FullControl，管理员可直接读写，无需 takeown/改 ACL——与电源方案键（只有 SYSTEM 可写）不同。
function Get-GpuNameEnumPath($Hw) {
  if (-not $Hw -or "$($Hw.MainGpuVendor)" -notin @('NVIDIA','AMD') -or -not $Hw.MainGpuPnp) { return $null }
  if ($Hw.MainGpuVendor -eq 'NVIDIA') {
    $sameVendorCount = @($Hw.Gpus | Where-Object Vendor -eq 'NVIDIA').Count
    if ($sameVendorCount -gt 1 -and -not $Hw.MainGpuPciMatched) { return $null }
  }
  $vendorId = $(if ($Hw.MainGpuVendor -eq 'NVIDIA') { '10DE' } else { '1002' })
  if ("$($Hw.MainGpuPnp)" -notmatch "^PCI\\VEN_$vendorId&") { return $null }
  $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($Hw.MainGpuPnp)"
  if ("$(Get-RegValue $path 'ClassGUID')" -ine '{4d36e968-e325-11ce-bfc1-08002be10318}') { return $null }
  $path
}

# 保留旧函数名供既有调用方使用；新逻辑统一由厂商感知的实现完成。
function Get-NvidiaGpuEnumPath($Hw) {
  if (-not $Hw -or "$($Hw.MainGpuVendor)" -ne 'NVIDIA') { return $null }
  Get-GpuNameEnumPath $Hw
}

# 显卡控制面板入口检测。装了才给按钮，没装只给下载页——按钮点了没反应比没有按钮更糟。
# 查找方式与 Find-GamePath 同思路：应用包 → 传统安装路径 → 卸载注册表。
# 下载页地址是本文件里的硬编码 https 常量，绝不从检测结果或网络取。
function Get-GpuPanelApps([string]$Vendor) {
  $apps = @()
  # appx 类走 shell:appsFolder（Store 版控制面板没有可直接执行的 exe 路径）
  $findAppx = {
    param($Name)
    # high token 可能属于批准 UAC 的另一管理员账户，不能把该账户的 AppX 当成
    # 原交互用户结果。GUI 通过 medium launcher worker 检测；此函数高权限时
    # 只返回机器级 exe 结果。
    if (Test-Admin) { return $null }
    try { @(Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue)[0] } catch { $null }
  }
  switch ($Vendor) {
    'NVIDIA' {
      $pkg = & $findAppx 'NVIDIACorp.NVIDIAControlPanel'
      $legacy = 'C:\Program Files\NVIDIA Corporation\Control Panel Client\nvcplui.exe'
      $cpl = $(if ($pkg) { @{ Kind = 'appx'; Target = "$($pkg.PackageFamilyName)!NVIDIACorp.NVIDIAControlPanel" } }
               elseif (Test-Path -LiteralPath $legacy) { @{ Kind = 'exe'; Target = $legacy } })
      $apps += @{ Key = 'nv-cpl'; Name = 'NVIDIA 控制面板'; Installed = [bool]$cpl
                  Kind = $cpl.Kind; Target = $cpl.Target
                  Download = 'https://www.nvidia.cn/geforce/drivers/'
                  Missing = '随显卡驱动一起安装，没有说明驱动装得不完整，重装驱动即可' }

      $nvApp = @('C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe',
                 'C:\Program Files\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA app.exe') |
               Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
      $apps += @{ Key = 'nv-app'; Name = 'NVIDIA App'; Installed = [bool]$nvApp
                  Kind = 'exe'; Target = $nvApp
                  Download = 'https://www.nvidia.cn/software/nvidia-app/'
                  Missing = 'DLSS 预设、驱动更新等新功能在这里，建议装' }
    }
    'AMD' {
      $rs = @('C:\Program Files\AMD\CNext\CNext\RadeonSoftware.exe',
               (Join-Path $script:System32 'amdow.exe')) |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
      $apps += @{ Key = 'amd-sw'; Name = 'AMD Software (Adrenalin)'; Installed = [bool]$rs
                  Kind = 'exe'; Target = $rs
                  Download = 'https://www.amd.com/zh-cn/support/download/drivers.html'
                  Missing = '随 Adrenalin 驱动一起安装，没有就去官网装完整版驱动' }
    }
    'Intel' {
      $pkg = & $findAppx 'AppUp.IntelGraphicsExperience'
      $apps += @{ Key = 'intel-gcc'; Name = 'Intel 显卡控制中心'; Installed = [bool]$pkg
                  Kind = 'appx'; Target = $(if ($pkg) { "$($pkg.PackageFamilyName)!App" })
                  Download = 'https://www.intel.cn/content/www/cn/zh/download-center/home.html'
                  Missing = '随 Intel 显卡驱动一起安装，也可在微软商店搜「Intel Graphics Command Center」' }
    }
  }
  $apps
}

# 独显在显示适配器 Class 键下的子键序号因机器而异（本机独显在 0002），
# 必须按 DriverDesc 匹配主显卡名，绝不能硬编码 0000
function Get-GpuClassKeyPath($Hw) {
  if (-not $Hw -or $Hw.MainGpuVendor -notin 'NVIDIA', 'AMD') { return $null }
  $root = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
  # Enum 设备键的 Driver 值直接指向 Class\{GUID}\000x，优先走这条一一对应关系。
  # 仅按 VEN/DEV 在两张同型号显卡上仍会命中第一张，不能算可靠匹配。
  if ($Hw.MainGpuPnp) {
    $driver = "$(Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Enum\$($Hw.MainGpuPnp)" 'Driver')"
    if ($driver -match '^\{4d36e968-e325-11ce-bfc1-08002be10318\}\\(\d{4})$') {
      $exact = "$root\$($Matches[1])"
      $baseExact, $subExact = Split-RegPath $exact
      $kExact = $baseExact.OpenSubKey($subExact)
      if ($kExact) { $kExact.Close(); return $exact }
    }
  }
  $sameVendorCount = @($Hw.Gpus | Where-Object { $_.Vendor -eq $Hw.MainGpuVendor }).Count
  if ($sameVendorCount -gt 1) { return $null }
  $base, $sub = Split-RegPath $root
  $k = $base.OpenSubKey($sub)
  if (-not $k) { return $null }
  try {
    foreach ($n in ($k.GetSubKeyNames() | Where-Object { $_ -match '^\d{4}$' })) {
      $path = "$root\$n"
      # DeviceDesc 可被“显卡型号伪装”改写，不能再把显示名当作唯一身份。
      # 优先用不会随伪装变化的 PCI VEN/DEV 匹配 Class 键，旧数据再按名称兜底。
      $pnpModel = $(if ($Hw.MainGpuPnp -match '^PCI\\([^\\]+)') { $Matches[1] } else { '' })
      $matching = "$(Get-RegValue $path 'MatchingDeviceId')"
      if ($pnpModel -and $matching -match [regex]::Escape($pnpModel)) { return $path }
      $driverDesc = "$(Get-RegValue $path 'DriverDesc')"
      if ($driverDesc -in @("$($Hw.MainGpuName)", "$($Hw.MainGpuReportedName)")) { return $path }
    }
  } finally { $k.Close() }
  $null
}

# 读物理核拓扑。WMI 分不清大小核（异构电源项在 11 代同构 CPU 上也存在，实测不可作判据），
# 只有 GetLogicalProcessorInformationEx 的 EfficiencyClass 是官方可靠信号
function Get-CpuCoreTopology {
  try {
    if (-not ('DfbCpuTopo' -as [type])) {
      Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DfbCpuTopo {
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetLogicalProcessorInformationEx(int type, IntPtr buffer, ref uint length);
    // 每个物理核返回 "效率等级:十六进制掩码"。手工按偏移解析变长结构：
    // 头部 Relationship(4)+Size(4)，PROCESSOR_RELATIONSHIP 的 EfficiencyClass 在偏移 9，
    // GROUP_AFFINITY 数组 8 字节对齐后落在偏移 32，前 8 字节即 KAFFINITY 掩码
    public static string[] GetCores() {
        uint len = 0;
        GetLogicalProcessorInformationEx(0, IntPtr.Zero, ref len);
        if (len == 0) return null;
        IntPtr buf = Marshal.AllocHGlobal((int)len);
        try {
            if (!GetLogicalProcessorInformationEx(0, buf, ref len)) return null;
            var list = new List<string>();
            long pos = 0;
            while (pos < len) {
                IntPtr p = (IntPtr)((long)buf + pos);
                int size = Marshal.ReadInt32(p, 4);
                if (size <= 0) return null;
                if (Marshal.ReadInt32(p, 0) == 0) {  // RelationProcessorCore
                    byte cls = Marshal.ReadByte(p, 9);
                    ushort grp = (ushort)Marshal.ReadInt16(p, 40);
                    ulong mask = (ulong)Marshal.ReadInt64(p, 32);
                    if (grp == 0) list.Add(cls + ":" + mask.ToString("X"));
                }
                pos += size;
            }
            return list.ToArray();
        } finally { Marshal.FreeHGlobal(buf); }
    }
}
'@
    }
    $raw = [DfbCpuTopo]::GetCores()
    if (-not $raw) { return $null }
    @($raw | ForEach-Object {
      $c, $m = $_ -split ':'
      [pscustomobject]@{ Class = [int]$c; Mask = [Convert]::ToUInt64($m, 16) }
    })
  } catch { $null }
}

# 显卡中断绑核（微软 Interrupt Management\Affinity Policy：DevicePolicy=4 即
# IrqPolicySpecifiedProcessors，AssignmentSetOverride 是 KAFFINITY 掩码、REG_BINARY 小端）。
# 掩码取编号最大的 P 核：既避开承接大量系统中断的 CPU0，又让 ISR/DPC 留在同一物理核上。
function Get-GpuIrqOps($Hw) {
  # KAFFINITY 只覆盖一个处理器组（64 逻辑核），超出的机器不做
  if (-not $Hw -or $Hw.Threads -lt 4 -or $Hw.Threads -gt 64) { return $null }
  # 必须按硬件评分阶段选出的 MainGpuPnp 精确落键。WMI 的原始数组顺序未定义，
  # “第一个 NVIDIA/AMD”在 AMD 核显 + NVIDIA 独显笔记本上会绑错设备。
  $gpu = @($Hw.Gpus | Where-Object { $_.Pnp -and $_.Pnp -ieq $Hw.MainGpuPnp }) | Select-Object -First 1
  if (-not $gpu) { return $null }
  $nvGpuCount = @($Hw.Gpus | Where-Object Vendor -eq 'NVIDIA').Count
  if ($gpu.Vendor -eq 'NVIDIA' -and $nvGpuCount -gt 1 -and -not $Hw.MainGpuPciMatched) {
    return $null
  }
  $cores = Get-CpuCoreTopology
  if (-not $cores -or @($cores).Count -lt 2) { return $null }
  $top = ($cores | Measure-Object -Property Class -Maximum).Maximum
  $cand = @($cores | Where-Object { $_.Class -eq $top })
  # 只剩一个高性能核就没有"避让 CPU0"的余地；掩码含 CPU0 说明拓扑异常——都放弃不做
  if ($cand.Count -lt 2) { return $null }
  $mask = [uint64](($cand | Sort-Object Mask | Select-Object -Last 1).Mask)
  if ($mask -band 1) { return $null }
  $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpu.Pnp)\Device Parameters\Interrupt Management\Affinity Policy"
  @(
    @{ Kind = 'reg'; Path = $path; Name = 'DevicePolicy'; Value = 4; Kind2 = 'DWord'; Label = '中断策略=指定处理器' }
    @{ Kind = 'reg'; Path = $path; Name = 'AssignmentSetOverride'
       Value = [BitConverter]::GetBytes($mask); Kind2 = 'Binary'; Label = ('绑定掩码=0x{0:X}' -f $mask) }
  )
}

# DirectXUserGlobalSettings 这类值是 "键=值;键=值;" 的复合串，多个功能共用一个注册表值。
# 必须逐项解析、只替换目标键，整串覆盖会把别人的设置一起抹掉。
function Get-KvStringItem([string]$Raw, [string]$Key) {
  if (-not $Raw) { return $null }
  foreach ($pair in ($Raw -split ';')) {
    if ($pair -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*?)\s*$") { return $Matches[1] }
  }
  $null
}

function Set-KvStringItem([string]$Raw, [string]$Key, [string]$Value) {
  $parts = @()
  $found = $false
  foreach ($pair in (@($Raw -split ';') | Where-Object { $_.Trim() })) {
    if ($pair -match "^\s*$([regex]::Escape($Key))\s*=") {
      $parts += "$Key=$Value"; $found = $true
    } else { $parts += $pair.Trim() }
  }
  if (-not $found) { $parts += "$Key=$Value" }
  # 原值本来就以分号收尾，保持同样形态，免得其他读取方解析出空项
  ($parts -join ';') + ';'
}

# VC++ 2015-2022(v14) 运行库体检。只看 v14 系：2010/2012/2013 是各自独立的运行库，
# 多版本共存本来就正常。判定口径（用户实测坐实）：只有缺失某个架构才算问题——x64 与
# x86 相互独立，版本不同步很常见且通常无害，一律报警是误报。
# 下载链接必须用 vs/18：vs/17 是 14.44 线，在已装更新版本的机器上必撞 0x80070666。
function Get-VcRedistInventory {
  $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $all = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -match 'Visual C\+\+' -and $_.DisplayVersion -match '^14\.' })
  $vc64 = @($all | Where-Object { $_.DisplayName -match '(?i)x64' })
  $vc86 = @($all | Where-Object { $_.DisplayName -match '(?i)x86' })
  $ver64 = @($vc64 | ForEach-Object { try { [version]$_.DisplayVersion } catch {} } | Sort-Object -Descending | Select-Object -First 1)
  $ver86 = @($vc86 | ForEach-Object { try { [version]$_.DisplayVersion } catch {} } | Sort-Object -Descending | Select-Object -First 1)
  [pscustomobject]@{
    Status = $(if ($all.Count -eq 0) { 'missing_both' } elseif ($vc64.Count -eq 0) { 'missing_x64' }
      elseif ($vc86.Count -eq 0) { 'missing_x86' } else { 'complete' })
    X64Version = $(if ($ver64.Count) { "$($ver64[0])" } else { '' })
    X86Version = $(if ($ver86.Count) { "$($ver86[0])" } else { '' })
    ComponentCount = [int]$all.Count
  }
}

function Get-VcRedistStatus {
  $inventory = Get-VcRedistInventory
  # 文案直接带微软官方永久链接：用户不用再自己搜安装包，配合日志一键复制即可拿到
  $dl = 'https://aka.ms/vs/18/release/vc_redist.x64.exe 和 https://aka.ms/vs/18/release/vc_redist.x86.exe'
  if ($inventory.Status -eq 'missing_both') {
    return @{ Ok = $false; Text = "未检测到 VC++ 2015-2022(v14) 运行库 —— 游戏很可能无法启动。请下载 x64 与 x86 两个都装（双击覆盖安装即可）：$dl，装完重启后再跑一次检测确认" }
  }
  if ($inventory.Status -in 'missing_x64','missing_x86') {
    $missArch = $(if ($inventory.Status -eq 'missing_x64') { 'x64' } else { 'x86' })
    return @{ Ok = $false; Text = "缺少 $missArch 架构的 v14 运行库 —— 依赖它的程序（含游戏组件）可能无法启动。请下载 x64 与 x86 两个都装（双击覆盖安装即可）：$dl，装完重启后再跑一次检测确认" }
  }
  $ver64 = [version]$inventory.X64Version
  $ver86 = [version]$inventory.X86Version
  if ($ver64.Minor -ne $ver86.Minor) {
    # 中性陈述而非报警：没有严格证据表明版本不同步必然导致掉帧/闪退（社区只有
    # 「重装后恢复」的个案报告），把它计入「体检发现问题」会制造误报和无谓折腾
    return @{ Ok = $true; Text = "x64 $ver64 / x86 $ver86，版本不同步——两套运行库相互独立，这在多数机器上无害，不算问题；只有确实遇到闪退或异常掉帧且排除了其他原因时，才值得给两个架构都装同一条最新线的包来统一：$dl。若安装器报 0x80070666「已安装更新的版本」，说明系统里的比安装包还新——正常现象，不用处理，也不要为此卸载" }
  }
  @{ Ok = $true; Text = "v14 运行库 x64/x86 版本一致（x64 $ver64 / x86 $ver86，共 $($inventory.ComponentCount) 个组件），正常" }
}

# WMI 读不到 SPD 中是否真的存在 XMP/A-XMP/EXPO/DOCP 档位，只能比较当前频率与
# SMBIOS 标称频率。达到标称频率时没有降频证据；低于标称时也要同时提示平台限频、
# 混插降频及品牌 BIOS 不开放菜单等可能，不能断言某个档位一定存在或一定未开启。
function Get-MemoryXmpStatus {
  $mem = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
  if ($mem.Count -eq 0) { return @{ Ok = $null; Text = '无法读取内存信息' } }
  $cur = ($mem | ForEach-Object { [int]$_.ConfiguredClockSpeed } | Measure-Object -Minimum).Minimum
  $rated = ($mem | ForEach-Object { [int]$_.Speed } | Measure-Object -Minimum).Minimum
  # SMBIOSMemoryType: 26=DDR4, 34=DDR5；JEDEC 基准最高频率据此区分
  $type = ($mem | Select-Object -First 1).SMBIOSMemoryType
  $ddr  = $(if ($type -eq 34) { 'DDR5' } elseif ($type -eq 26) { 'DDR4' } else { '内存' })
  $jedecMax = $(if ($type -eq 34) { 5600 } else { 3200 })

  if ($cur -le 0) { return @{ Ok = $null; Text = '无法读取内存运行频率' } }
  if ($rated -gt 0 -and $cur -lt $rated) {
    return @{ Ok = $false; Text = "$ddr 实际 $cur MHz 低于 SMBIOS 标称 $rated MHz。可能是内存档位未启用、CPU/主板限频或混插降频；BIOS 菜单名称可能是 XMP、A-XMP、EXPO 或 DOCP，也可能被品牌机/笔记本厂商隐藏" }
  }
  if ($rated -gt 0 -and $cur -ge $rated) {
    if ($cur -le $jedecMax) {
      return @{ Ok = $true; Text = "$ddr 运行在 $cur MHz，已达到 SMBIOS 标称 $rated MHz；没有证据表明内存被降频。该内存或整机可能本来就没有 XMP/EXPO 档位，BIOS 找不到相关菜单属于正常情况" }
    }
    return @{ Ok = $true; Text = "$ddr 运行在 $cur MHz，已达到 SMBIOS 标称 $rated MHz；高频档位或手动内存设置已生效" }
  }
  if ($cur -le $jedecMax) {
    return @{ Ok = $null; Text = "$ddr 运行在 $cur MHz，但系统没有提供可靠的标称频率，无法判断是否存在或启用了内存性能档位；BIOS 没有 XMP/A-XMP/EXPO/DOCP 菜单时不要强行寻找或刷非官方 BIOS" }
  }
  @{ Ok = $true; Text = "$ddr 运行在 $cur MHz，已超过常见 JEDEC 基准；高频档位或手动内存设置已生效" }
}

function Get-NvidiaSmiPath {
  @((Join-Path $script:System32 'nvidia-smi.exe'),
    (Join-Path $script:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe')) |
    Where-Object { (Test-Path -LiteralPath $_ -PathType Leaf) -and -not (Test-PathHasReparsePoint $_) } |
    Select-Object -First 1
}

function Get-PcieLinkStatus {
  $smi = Get-NvidiaSmiPath
  if (-not $smi) {
    return @{ Ok = $null; Text = '无法检测（无 nvidia-smi；A 卡/核显可用 GPU-Z 查看总线接口）' }
  }
  $ErrorActionPreference = 'SilentlyContinue'
  $hw = Get-HardwareInfo
  if ($hw.MainGpuVendor -ne 'NVIDIA' -or -not $hw.MainGpuPciLocation) { return @{ Ok = $null; Text = '无法可靠匹配主 NVIDIA 显卡的 PCI 位置' } }
  # 带 pci.bus_id 查询并按 SetupAPI 得到的主卡 BDF 精确选行，多卡时不再固定取第一行。
  $out = & $smi '--query-gpu=pci.bus_id,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max' '--format=csv,noheader' 2>&1
  if ($LASTEXITCODE -ne 0 -or -not "$out") { return @{ Ok = $null; Text = '无法检测（nvidia-smi 查询失败）' } }
  $row = $null
  foreach ($line in @($out)) {
    $p = @("$line" -split ',' | ForEach-Object { $_.Trim() })
    if ($p.Count -lt 5 -or $p[0] -notmatch '(?:[0-9A-Fa-f]{4,8}:)?([0-9A-Fa-f]{2}):([0-9A-Fa-f]{2})\.([0-7])$') { continue }
    $key = ('{0}:{1}:{2}' -f [Convert]::ToUInt32($Matches[1],16),[Convert]::ToUInt32($Matches[2],16),[Convert]::ToUInt32($Matches[3],16))
    if ($key -eq $hw.MainGpuPciLocation) { $row = $p; break }
  }
  if (-not $row -or $row[4] -notmatch '^\d+$') { return @{ Ok = $null; Text = '无法检测（nvidia-smi 没有返回主显卡对应的 PCI 行）' } }
  $ok = ([int]$row[4] -ge 8)
  @{ Ok = $ok
     Text = "链路上限 PCIe $($row[2]).0 x$($row[4])$(if ($ok) { '，正常' } else { '，异常偏低，检查显卡是否插在直连 CPU 的主插槽' })（当前 $($row[1]).0 x$($row[3])，空闲降速属正常）" }
}

function Get-NvAutoOptStatus {
  $path = Join-Path $script:TargetLocalAppData 'NVIDIA Corporation\NVIDIA app\NvBackend\config.xml'
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ Ok = $null; Text = '未找到 NVIDIA App 配置；如已安装，请在 App 内确认“自动优化游戏设置”' } }
  if (Test-PathHasReparsePoint $path) { return @{ Ok = $null; Text = 'NVIDIA App 配置路径含目录联接/符号链接，已拒绝读取' } }
  $f = Get-Item -LiteralPath $path
  if ($f.Length -gt 4MB) { return @{ Ok = $null; Text = 'NVIDIA App 配置文件异常过大，已拒绝读取' } }
  try { $txt = [IO.File]::ReadAllText($path) } catch { return @{ Ok = $null; Text = "读取 NVIDIA App 配置失败：$($_.Exception.Message)" } }
  if ($txt -match '<Setting name=[''"]EnableAutomaticApplyOPS[''"] value=[''"]0[''"]') { return @{ Ok = $true; Text = 'NVIDIA App 自动优化已关闭' } }
  if ($txt -match '<Setting name=[''"]EnableAutomaticApplyOPS[''"] value=[''"]1[''"]') { return @{ Ok = $false; Text = 'NVIDIA App 自动优化仍开启，请在 NVIDIA App 内手动关闭' } }
  @{ Ok = $null; Text = '未找到 NVIDIA App 自动优化设置，请在 App 内手动确认' }
}

# ---------- 硬件与游戏检测 ----------

function Get-GpuVendor([string]$Pnp, [string]$Name) {
  # 型号伪装会改变 Name，PCI 厂商 ID 必须优先，否则 A 卡伪装成 GeForce 后会被误认成 N 卡。
  if     ($Pnp -match 'VEN_10DE') { 'NVIDIA' }
  elseif ($Pnp -match 'VEN_1002') { 'AMD' }
  elseif ($Pnp -match 'VEN_8086') { 'Intel' }
  elseif ($Name -match 'NVIDIA|GeForce|RTX|GTX') { 'NVIDIA' }
  elseif ($Name -match 'AMD|Radeon')             { 'AMD' }
  elseif ($Name -match 'Intel|Arc|UHD|Iris')     { 'Intel' }
  else   { 'Unknown' }
}

# 远控/串流软件常安装间接显示驱动。它们不是主力 GPU，但会改变桌面输出、刷新率、
# 捕获路径和游戏所选适配器；把这个信号单独记录，避免把问题误归因到实体显卡。
function Test-VirtualDisplayAdapter([string]$Pnp, [string]$Name) {
  $identity = "$Name $Pnp"
  [bool]($identity -match '(?i)(?:ToDesk\s+Virtual\s+Display|OrayIddDriver|AskLink\s+Display\s+Adapter|GameViewer\s+Virtual\s+Display|MuMu\s+Virtual\s+Display|Parsec\s+Virtual\s+Display|Sunshine\s+Virtual\s+Display|Indirect\s+Display\s+Driver|IddSampleDriver)')
}

# Enum 设备键的 Driver 值一一指向显示适配器 Class 键；这里读取不会被 DeviceDesc
# 伪装覆盖的 DriverDesc，为 AMD 恢复真实型号显示与后续主卡选择。
function Get-GpuDriverDescription([string]$PnpDeviceId, [string]$Vendor) {
  if (-not $PnpDeviceId -or $Vendor -notin @('NVIDIA','AMD')) { return $null }
  $enumPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$PnpDeviceId"
  $driver = "$(Get-RegValue $enumPath 'Driver')"
  if ($driver -notmatch '^\{4d36e968-e325-11ce-bfc1-08002be10318\}\\\d{4}$') { return $null }
  $name = "$(Get-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$driver" 'DriverDesc')".Trim()
  if (-not $name -or (Get-GpuVendor $PnpDeviceId $name) -ne $Vendor) { return $null }
  $name
}

function Resolve-ComputerBrand([string]$Manufacturer, [string]$Model, [string]$BaseBoardManufacturer) {
  $text = "$Manufacturer $Model $BaseBoardManufacturer"
  if ($text -match '(?i)Surface')                         { return [pscustomobject]@{ Key='surface'; Name='Microsoft Surface' } }
  if ($text -match '(?i)Alienware')                       { return [pscustomobject]@{ Key='alienware'; Name='Alienware' } }
  if ($text -match '(?i)ThinkPad')                        { return [pscustomobject]@{ Key='thinkpad'; Name='联想 ThinkPad' } }
  if ($text -match '(?i)ROG|Republic of Gamers')          { return [pscustomobject]@{ Key='asus'; Name='华硕 ROG' } }
  if ($text -match '(?i)Hewlett[- ]Packard|(^|\W)HP(\W|$)|OMEN') { return [pscustomobject]@{ Key='hp'; Name='惠普' } }
  if ($text -match '(?i)Dell')                            { return [pscustomobject]@{ Key='dell'; Name='戴尔' } }
  if ($text -match '(?i)Lenovo|Legion|IdeaPad|ThinkCentre') { return [pscustomobject]@{ Key='lenovo'; Name='联想' } }
  if ($text -match '(?i)ASUSTeK|(^|\W)ASUS(\W|$)')       { return [pscustomobject]@{ Key='asus'; Name='华硕' } }
  if ($text -match '(?i)Acer')                            { return [pscustomobject]@{ Key='acer'; Name='宏碁' } }
  if ($text -match '(?i)Micro-Star|(^|\W)MSI(\W|$)')     { return [pscustomobject]@{ Key='msi'; Name='微星' } }
  if ($text -match '(?i)Gigabyte|AORUS')                  { return [pscustomobject]@{ Key='gigabyte'; Name='技嘉 / AORUS' } }
  if ($text -match '(?i)ASRock')                          { return [pscustomobject]@{ Key='asrock'; Name='华擎' } }
  if ($text -match '(?i)Colorful|七彩虹')                  { return [pscustomobject]@{ Key='colorful'; Name='七彩虹' } }
  if ($text -match '(?i)Hasee|神舟')                      { return [pscustomobject]@{ Key='hasee'; Name='神舟' } }
  if ($text -match '(?i)MECHREVO|机械革命')               { return [pscustomobject]@{ Key='mechrevo'; Name='机械革命' } }
  if ($text -match '(?i)Huawei|华为')                     { return [pscustomobject]@{ Key='huawei'; Name='华为' } }
  if ($text -match '(?i)Honor|荣耀')                      { return [pscustomobject]@{ Key='honor'; Name='荣耀' } }
  if ($text -match '(?i)Xiaomi|Redmi|小米')               { return [pscustomobject]@{ Key='xiaomi'; Name='小米 / Redmi' } }
  if ($text -match '(?i)Samsung')                         { return [pscustomobject]@{ Key='samsung'; Name='三星' } }
  if ($text -match '(?i)(^|\W)LG(\W|$)')                 { return [pscustomobject]@{ Key='lg'; Name='LG' } }
  if ($text -match '(?i)Dynabook|Toshiba')                { return [pscustomobject]@{ Key='dynabook'; Name='Dynabook / 东芝' } }
  if ($text -match '(?i)CLEVO|TONGFANG')                  { return [pscustomobject]@{ Key='clevo'; Name='蓝天 / 同方模具' } }

  $generic = '(?i)^\s*$|To Be Filled By O\.E\.M\.|System manufacturer|Default string|OEM'
  $fallback = $(if ("$Manufacturer" -notmatch $generic) { "$Manufacturer".Trim() }
                elseif ("$BaseBoardManufacturer" -notmatch $generic) { "$BaseBoardManufacturer".Trim() }
                else { '未知品牌' })
  [pscustomobject]@{ Key='generic'; Name=$fallback }
}

function Get-BiosEntryInstruction([string]$BrandKey, [bool]$IsLaptop) {
  switch ($BrandKey) {
    'surface'    { '完全关机后按住音量加键，再短按电源键；看到 Surface 标志后松开音量加键，进入 UEFI' }
    'hp'         { '开机出现惠普标志时连续按 Esc，进入启动菜单后按 F10' }
    'thinkpad'   { '开机出现 ThinkPad 标志时连续按 F1；功能键模式开启时用 Fn+F1' }
    'lenovo'     { '开机出现联想标志时连续按 F2；功能键模式开启时用 Fn+F2，有 NOVO 小孔的机型也可关机后按 NOVO' }
    'dell'       { '开机出现 Dell 标志时连续按 F2' }
    'alienware'  { '开机出现 Alienware 标志时连续按 F2' }
    'acer'       { '开机出现 Acer 标志时连续按 F2' }
    'asus'       { $(if ($IsLaptop) { '开机出现 ASUS/ROG 标志时连续按 F2' } else { '开机自检时连续按 Del（也可尝试 F2）' }) }
    'msi'        { '开机出现 MSI 标志时连续按 Del' }
    'gigabyte'   { $(if ($IsLaptop) { '开机出现 GIGABYTE/AORUS 标志时连续按 F2' } else { '开机自检时连续按 Del' }) }
    'asrock'     { '开机自检时连续按 F2 或 Del' }
    'colorful'   { '开机自检时连续按 Del' }
    'hasee'      { '开机出现神舟标志时连续按 F2' }
    'mechrevo'   { '开机出现机械革命标志时连续按 F2' }
    'huawei'     { '开机出现华为标志时连续按 F2' }
    'honor'      { '开机出现荣耀标志时连续按 F2' }
    'xiaomi'     { '开机出现小米/Redmi 标志时连续按 F2' }
    'samsung'    { '开机出现 Samsung 标志时连续按 F2' }
    'lg'         { '开机出现 LG 标志时连续按 F2' }
    'dynabook'   { '开机出现 Dynabook/东芝标志时连续按 F2' }
    'clevo'      { '开机出现品牌标志时连续按 F2' }
    default      { '开机自检画面出现时连续按 Del 或 F2；若无效，再按屏幕提示尝试 F1/F10' }
  }
}

function Get-XmpBiosTutorial($Hw) {
  $brand = $(if ($Hw -and $Hw.ComputerBrand) { "$($Hw.ComputerBrand)" } else { '未知品牌' })
  $model = $(if ($Hw -and $Hw.ComputerModel) { "$($Hw.ComputerModel)" } else { '型号未识别' })
  $key = $(if ($Hw) { "$($Hw.ComputerBrandKey)" } else { 'generic' })
  $laptop = [bool]($Hw -and $Hw.IsLaptop)
  $ddr = $(if ($Hw -and "$($Hw.MemoryType)" -in @('DDR4','DDR5')) { "$($Hw.MemoryType)" } else { '内存代际未识别' })
  $cpuVendor = $(if ($Hw -and "$($Hw.CpuVendor)" -in @('AMD','Intel')) { "$($Hw.CpuVendor)" }
                 elseif ($Hw -and "$($Hw.CPU)" -match '(?i)AMD|Ryzen') { 'AMD' }
                 elseif ($Hw -and "$($Hw.CPU)" -match '(?i)Intel|Core') { 'Intel' }
                 else { '平台未识别' })
  $entry = Get-BiosEntryInstruction $key $laptop
  $menu = $(switch ($key) {
    'msi' {
      if ($cpuVendor -eq 'AMD' -and $ddr -eq 'DDR4') {
        'MSI Click BIOS 5 按 F7 进入高级模式 → OC → A-XMP → Profile 1；部分版本在 EZ Mode 顶部直接显示 A-XMP。MSI 的 AMD DDR4 通常叫 A-XMP，不叫 EXPO 或 DOCP。'
      } elseif ($cpuVendor -eq 'AMD' -and $ddr -eq 'DDR5') {
        'MSI Click BIOS 5 按 F7 → OC → EXPO → Profile 1；AM5/DDR5 才优先找 EXPO。'
      } else {
        'MSI Click BIOS 5 按 F7 → OC → XMP/A-XMP → Profile 1；也可先看 EZ Mode 顶部是否有 XMP/A-XMP 开关。'
      }
    }
    'asus' {
      if ($laptop) {
        '华硕/ROG 笔记本（包括魔霸系列）很多型号不开放内存超频档位。按 F7 进入 Advanced Mode 后，若没有 Ai Tweaker / Extreme Tweaker / Memory Profile 页面，就表示该机型 BIOS 未提供此功能，不需要继续找；Armoury Crate 里也不会补出该开关。'
      } elseif ($cpuVendor -eq 'AMD' -and $ddr -eq 'DDR4') {
        '华硕台式机/主板按 F7 → Ai Tweaker → Ai Overclock Tuner → D.O.C.P. → Profile 1；华硕 AMD DDR4 才常见 DOCP。'
      } elseif ($cpuVendor -eq 'AMD' -and $ddr -eq 'DDR5') {
        '华硕台式机/主板按 F7 → Ai Tweaker → Ai Overclock Tuner → EXPO I；AM5/DDR5 优先找 EXPO。'
      } else {
        '华硕台式机/主板按 F7 → Ai Tweaker → Ai Overclock Tuner → XMP I。'
      }
    }
    'gigabyte' { '进入 Tweaker → Extreme Memory Profile (X.M.P.)；AMD DDR5 平台则找 EXPO，选择 Profile 1。' }
    'asrock'    { '进入 OC Tweaker → DRAM Profile / Load XMP Setting；AMD DDR5 平台则找 EXPO，选择 Profile 1。' }
    default {
      if ($laptop) {
        '品牌笔记本通常不开放内存超频页面。进入 Advanced/Performance/Overclocking 页面检查一次；若没有 Memory Profile、XMP、A-XMP、EXPO 或 DOCP，就表示厂商未提供该功能。'
      } elseif ($cpuVendor -eq 'AMD' -and $ddr -eq 'DDR4') {
        'AMD DDR4 平台按主板品牌寻找 A-XMP、XMP 或 DOCP（DOCP 主要见于华硕），选择 Profile 1。'
      } elseif ($cpuVendor -eq 'AMD' -and $ddr -eq 'DDR5') {
        'AMD DDR5/AM5 平台寻找 EXPO，选择 Profile 1。'
      } else {
        'Intel 平台通常寻找 XMP；不同主板也可能写作 Extreme Memory Profile，选择 Profile 1。'
      }
    }
  })
  @(
    'XMP、A-XMP、EXPO、DOCP 都是可选的内存性能档位名称，不是每根内存、每台品牌机或每款笔记本都有。软件只能比较系统报告的运行/标称频率，不能证明 BIOS 一定存在某个开关。'
    ''
    "检测到电脑：$brand · $model；平台：$cpuVendor；内存：$ddr"
    '确认步骤（BIOS 设置只能手动进入）：'
    "1. $entry；"
    "2. $menu"
    '3. 如果上述页面或开关不存在，就以“此机型未开放/内存没有该档位”处理，不要反复寻找，也不要刷非官方 BIOS 强开；'
    '4. 只有实际修改了档位才按 F10 保存并退出；没有找到开关时直接退出且不保存；'
    '5. 若修改后不能正常启动，先等待主板完成内存训练并自动回退；仍未恢复时重新进入 BIOS，选择 Load Optimized Defaults/恢复默认设置。'
  ) -join "`n"
}

# Win32_VideoController 的返回顺序没有「独显优先」保证，AMD 核显经常排在 NVIDIA
# 独显前面。用型号特征做稳定排序：NVIDIA GeForce、AMD RX/Pro、Intel Arc 视为独显，
# 其余 Radeon Graphics / Intel UHD / Iris 作为核显兜底。
function Get-GpuPreferenceScore($Gpu) {
  # 已知虚拟/远程显示适配器只描述显示环境，不参与主力 GPU 选择。
  if ([bool]$Gpu.IsVirtualDisplay) { return -1000 }
  $name = "$($Gpu.Name)"
  switch ("$($Gpu.Vendor)") {
    'NVIDIA' { return 400 }
    'AMD' {
      if ($name -match '(?i)\bRadeon\s+(?:RX|Pro)\b|\bFirePro\b') { return 300 }
      return 150
    }
    'Intel' {
      if ($name -match '(?i)\bArc\b') { return 280 }
      return 100
    }
    default { return 0 }
  }
}

function Select-MainGpu($Gpus) {
  @($Gpus | Where-Object { $_ } |
    Sort-Object @{ Expression = { Get-GpuPreferenceScore $_ }; Descending = $true },
                @{ Expression = { "$($_.Name)" }; Descending = $false } |
    Select-Object -First 1)[0]
}

# DeviceDesc 伪装后 Win32_VideoController.Name 也会跟着变。NVIDIA 的 NVML/nvidia-smi
# 直接从驱动查询物理适配器型号，不受 DeviceDesc 影响，用它恢复真实型号用于界面、
# 显卡指引、诊断报告和匿名统计。查询失败时保留 WMI 值，并明确标记为未验证。
function Get-PciBusLocation([string]$PnpDeviceId) {
  try {
    if (-not ('DfbPciLocation' -as [type])) {
      Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DfbPciLocation {
  const uint SPDRP_BUSNUMBER = 0x15, SPDRP_ADDRESS = 0x1C;
  [StructLayout(LayoutKind.Sequential)]
  struct SP_DEVINFO_DATA { public uint cbSize; public Guid ClassGuid; public uint DevInst; public UIntPtr Reserved; }
  [DllImport("setupapi.dll", SetLastError=true)] static extern IntPtr SetupDiCreateDeviceInfoList(IntPtr cls, IntPtr hwnd);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  static extern bool SetupDiOpenDeviceInfo(IntPtr set, string id, IntPtr hwnd, uint flags, ref SP_DEVINFO_DATA data);
  [DllImport("setupapi.dll", SetLastError=true)]
  static extern bool SetupDiGetDeviceRegistryProperty(IntPtr set, ref SP_DEVINFO_DATA data, uint prop,
    out uint regType, byte[] buffer, uint size, out uint needed);
  [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
  static uint GetDword(IntPtr set, ref SP_DEVINFO_DATA data, uint prop) {
    byte[] b = new byte[4]; uint type, needed;
    if (!SetupDiGetDeviceRegistryProperty(set, ref data, prop, out type, b, 4, out needed))
      throw new InvalidOperationException("SetupAPI property unavailable");
    return BitConverter.ToUInt32(b, 0);
  }
  public static string Get(string id) {
    IntPtr set = SetupDiCreateDeviceInfoList(IntPtr.Zero, IntPtr.Zero);
    if (set == new IntPtr(-1)) return null;
    try {
      SP_DEVINFO_DATA data = new SP_DEVINFO_DATA(); data.cbSize = (uint)Marshal.SizeOf(data);
      if (!SetupDiOpenDeviceInfo(set, id, IntPtr.Zero, 0, ref data)) return null;
      uint bus = GetDword(set, ref data, SPDRP_BUSNUMBER);
      uint address = GetDword(set, ref data, SPDRP_ADDRESS);
      uint device = (address >> 16) & 0xffff, function = address & 0xffff;
      return bus + ":" + device + ":" + function;
    } catch { return null; }
    finally { SetupDiDestroyDeviceInfoList(set); }
  }
}
'@
    }
    [DfbPciLocation]::Get($PnpDeviceId)
  } catch { $null }
}

function Get-NvidiaGpuIdentities {
  try {
    # 只执行驱动安装到受保护系统目录的 nvidia-smi，绝不从用户可写 PATH 解析同名 EXE。
    $smi = Get-NvidiaSmiPath
    if (-not $smi) { return @() }
    $out = @(& $smi '--query-gpu=name,pci.bus_id' '--format=csv,noheader' 2>$null)
    if ($LASTEXITCODE -ne 0) { return @() }
    @($out | ForEach-Object {
      $line = "$($_)".Trim()
      if ($line -match '^(.*?),\s*(?:[0-9A-Fa-f]{4,8}:)?([0-9A-Fa-f]{2}):([0-9A-Fa-f]{2})\.([0-7])$') {
        [pscustomobject]@{
          Name = $Matches[1].Trim(); Bus = [Convert]::ToUInt32($Matches[2],16)
          Device = [Convert]::ToUInt32($Matches[3],16); Function = [Convert]::ToUInt32($Matches[4],16)
          Key = ('{0}:{1}:{2}' -f [Convert]::ToUInt32($Matches[2],16),[Convert]::ToUInt32($Matches[3],16),[Convert]::ToUInt32($Matches[4],16))
        }
      }
    } | Where-Object { $_ })
  } catch { @() }
}

function Get-SystemPowerSnapshot {
  try {
    if (-not ('DfbSystemPowerStatus' -as [type])) {
      Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DfbSystemPowerStatus {
  [StructLayout(LayoutKind.Sequential)]
  public struct SYSTEM_POWER_STATUS {
    public byte ACLineStatus;
    public byte BatteryFlag;
    public byte BatteryLifePercent;
    public byte SystemStatusFlag;
    public uint BatteryLifeTime;
    public uint BatteryFullLifeTime;
  }
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS status);
  public static SYSTEM_POWER_STATUS Read() {
    SYSTEM_POWER_STATUS status;
    if (!GetSystemPowerStatus(out status)) throw new InvalidOperationException("GetSystemPowerStatus failed");
    return status;
  }
}
'@
    }
    $status = [DfbSystemPowerStatus]::Read()
    [pscustomobject]@{
      Source = $(if ($status.ACLineStatus -eq 1) { 'ac' } elseif ($status.ACLineStatus -eq 0) { 'battery' } else { 'unknown' })
      BatteryPercent = $(if ($status.BatteryLifePercent -le 100) { [int]$status.BatteryLifePercent } else { $null })
    }
  } catch {
    [pscustomobject]@{ Source = 'unknown'; BatteryPercent = $null }
  }
}

function Get-DisplayTopologyInfo {
  $queried = $false
  $connections = @()
  try {
    $connections = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams -ErrorAction Stop |
      Where-Object { $_.Active -ne $false })
    $queried = $true
  } catch {}
  $displayNames = @()
  try {
    $displayNames = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop |
      Where-Object { $_.Active -ne $false } | ForEach-Object {
        $chars = @($_.UserFriendlyName | Where-Object { [int]$_ -gt 0 -and [int]$_ -le 0xFFFF } |
          ForEach-Object { [char][int]$_ })
        ("$($chars -join '')" -replace '[\x00-\x1f\x7f]',' ').Trim()
      } | Where-Object { $_ } | Select-Object -Unique)
  } catch {}
  $connectors = @()
  $internal = 0; $external = 0
  foreach ($connection in $connections) {
    $technology = [int64]$connection.VideoOutputTechnology
    if ($technology -lt 0) { $technology += 4294967296L }
    $connector = switch ($technology) {
      0 { 'vga' }
      4 { 'dvi' }
      5 { 'hdmi' }
      6 { 'lvds' }
      10 { 'displayport' }
      11 { 'embedded-displayport' }
      13 { 'embedded-udi' }
      2147483648 { 'internal' }
      default { 'other' }
    }
    $connectors += $connector
    if ($technology -in 6,11,13,2147483648) { $internal++ } else { $external++ }
  }
  [pscustomobject]@{
    QueryAvailable = [bool]$queried
    ActiveDisplayCount = [int]$connections.Count
    InternalDisplayCount = [int]$internal
    ExternalDisplayCount = [int]$external
    HasInternalDisplay = $(if ($queried -and $connections.Count -gt 0) { [bool]($internal -gt 0) } else { $null })
    Connectors = [string[]]@($connectors | Sort-Object -Unique)
    DisplayNames = [string[]]$displayNames
    PrimaryDisplayName = $(if ($displayNames.Count) { "$($displayNames[0])" } else { '' })
  }
}

function Resolve-FormFactor([object[]]$ChassisTypes, $HasBattery, $HasInternalDisplay) {
  $types = @($ChassisTypes | ForEach-Object { try { [int]$_ } catch {} } |
    Where-Object { $_ -ge 1 -and $_ -le 36 } | Sort-Object -Unique)
  # SMBIOS chassis types: portable/notebook/tablet/convertible/detachable are portable;
  # tower/AIO/rack/mini-PC/stick-PC are stationary.  A battery alone is not proof of a
  # notebook because desktop UPS devices can expose Win32_Battery.
  $portableTypes = @(8,9,10,11,14,30,31,32)
  $stationaryTypes = @(3,4,5,6,7,13,15,16,17,23,24,34,35,36)
  $portable = @($types | Where-Object { $portableTypes -contains $_ }).Count -gt 0
  $stationary = @($types | Where-Object { $stationaryTypes -contains $_ }).Count -gt 0
  $batteryKnown = $null -ne $HasBattery
  $internalKnown = $null -ne $HasInternalDisplay
  $battery = $batteryKnown -and [bool]$HasBattery
  $internal = $internalKnown -and [bool]$HasInternalDisplay
  $formFactor = 'unknown'; $confidence = 'low'
  if ($portable -and -not $stationary) { $formFactor = 'laptop'; $confidence = 'high' }
  elseif ($stationary -and -not $portable) { $formFactor = 'desktop'; $confidence = 'high' }
  elseif (-not $portable -and -not $stationary -and $battery -and $internal) {
    $formFactor = 'laptop'; $confidence = 'medium'
  }
  [pscustomobject]@{
    FormFactor = $formFactor
    Confidence = $confidence
    ChassisTypes = [int[]]$types
    IsUpsAmbiguous = [bool]($battery -and (($stationary -and -not $portable) -or ($internalKnown -and -not $internal)))
  }
}

function Get-HardwareInfo {
  $os   = Get-CimInstance Win32_OperatingSystem
  $processors = @(Get-CimInstance Win32_Processor)
  $cpu  = $processors | Select-Object -First 1
  $cs   = Get-CimInstance Win32_ComputerSystem
  $enclosures = @(Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue)
  $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
  $memory = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
  $memoryFirst = $memory | Select-Object -First 1
  $memoryType = $(if ($memoryFirst.SMBIOSMemoryType -eq 34) { 'DDR5' }
                  elseif ($memoryFirst.SMBIOSMemoryType -eq 26) { 'DDR4' } else { '未知' })
  $configuredSpeeds = @($memory | ForEach-Object { [int]$_.ConfiguredClockSpeed } | Where-Object { $_ -gt 0 })
  $ratedSpeeds = @($memory | ForEach-Object { [int]$_.Speed } | Where-Object { $_ -gt 0 })
  $memoryConfiguredMHz = $(if ($configuredSpeeds.Count) {
    [int](($configuredSpeeds | Measure-Object -Minimum).Minimum)
  } else { 0 })
  $memoryRatedMHz = $(if ($ratedSpeeds.Count) {
    [int](($ratedSpeeds | Measure-Object -Minimum).Minimum)
  } else { 0 })
  # WMI 每个 Win32_Processor 对象代表一个处理器封装。旧实现只取第一个对象，会把
  # 多路机器少算；这里汇总 Windows 当前可见拓扑，并在报告中明确它不是型号标称值。
  $visibleCores = [int](($processors | ForEach-Object { [int]$_.NumberOfCores } |
    Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum)
  $visibleThreads = [int](($processors | ForEach-Object { [int]$_.NumberOfLogicalProcessors } |
    Where-Object { $_ -gt 0 } | Measure-Object -Sum).Sum)
  $cpuVendor = $(if ("$($cpu.Manufacturer) $($cpu.Name)" -match '(?i)AuthenticAMD|AMD|Ryzen') { 'AMD' }
                 elseif ("$($cpu.Manufacturer) $($cpu.Name)" -match '(?i)GenuineIntel|Intel|Core') { 'Intel' }
                 else { 'Unknown' })
  $nvidiaIds = @(Get-NvidiaGpuIdentities)
  $video = @(Get-CimInstance Win32_VideoController)
  $nvidiaWmiCount = @($video | Where-Object { (Get-GpuVendor $_.PNPDeviceID "$($_.Name)") -eq 'NVIDIA' }).Count
  $gpus = @($video | ForEach-Object {
    $reportedName = "$($_.Name)".Trim()
    $vendor = Get-GpuVendor $_.PNPDeviceID $reportedName
    $realName = $reportedName
    # Intel 的 WMI 名称可直接作为当前实现的可信来源；NVIDIA / AMD 需要下面的
    # 二次身份解析。Unknown（常见于虚拟显示驱动）不能被误标成已验证实体显卡。
    $verified = ($vendor -eq 'Intel')
    $pciLocation = $(if ($vendor -eq 'NVIDIA') { Get-PciBusLocation "$($_.PNPDeviceID)" } else { $null })
    $pciMatched = $false
    if ($vendor -eq 'NVIDIA') {
      $match = @($nvidiaIds | Where-Object { $_.Key -eq $pciLocation }) | Select-Object -First 1
      # 单卡机器不存在错配歧义，SetupAPI 属性缺失时仍可安全一一对应；多卡必须按 PCI BDF 命中。
      if (-not $match -and $nvidiaWmiCount -eq 1 -and $nvidiaIds.Count -eq 1) { $match = $nvidiaIds[0] }
      if ($match) { $realName = "$($match.Name)".Trim(); $verified = [bool]$realName; $pciMatched = $true }
    } elseif ($vendor -eq 'AMD') {
      $driverName = Get-GpuDriverDescription "$($_.PNPDeviceID)" $vendor
      if ($driverName) { $realName = $driverName; $verified = $true }
    }
    [pscustomobject]@{
      Name         = $realName
      ReportedName = $reportedName
      NameVerified = $verified
      Vendor       = $vendor
      Driver       = $_.DriverVersion
      DriverDate   = $(try {
        if ($_.DriverDate -is [DateTime]) { ([DateTime]$_.DriverDate).ToString('yyyy-MM-dd') }
        else { ([Management.ManagementDateTimeConverter]::ToDateTime("$($_.DriverDate)")).ToString('yyyy-MM-dd') }
      } catch { '' })
      DisplayWidth = $(if ([int64]$_.CurrentHorizontalResolution -ge 640 -and [int64]$_.CurrentHorizontalResolution -le 16384) { [int]$_.CurrentHorizontalResolution } else { 0 })
      DisplayHeight = $(if ([int64]$_.CurrentVerticalResolution -ge 480 -and [int64]$_.CurrentVerticalResolution -le 8640) { [int]$_.CurrentVerticalResolution } else { 0 })
      DisplayRefreshHz = $(if ([int64]$_.CurrentRefreshRate -ge 24 -and [int64]$_.CurrentRefreshRate -le 1000) { [int]$_.CurrentRefreshRate } else { 0 })
      DisplayActive = [bool]([int64]$_.CurrentHorizontalResolution -gt 0 -and [int64]$_.CurrentVerticalResolution -gt 0)
      Pnp          = $_.PNPDeviceID   # 中断绑核要按设备实例路径落到 Enum 键下
      PciLocation  = $pciLocation
      PciMatched   = $pciMatched
      IsVirtualDisplay = Test-VirtualDisplayAdapter "$($_.PNPDeviceID)" "$reportedName $realName"
    }
  })
  # 双显卡（核显+独显）机器以独显为主，不能依赖 WMI 的未定义返回顺序
  $main = Select-MainGpu $gpus
  # 双显卡笔记本的显示输出常挂在核显上，独显分辨率字段为空；此时从所有活动显示适配器
  # 中选择像素数最高的一项作为当前桌面口径，仅用于生成文字建议，不参与显卡身份判断。
  $display = @($gpus | Where-Object { $_.DisplayWidth -gt 0 -and $_.DisplayHeight -gt 0 } |
               Sort-Object @{Expression={ [int64]$_.DisplayWidth * [int64]$_.DisplayHeight };Descending=$true},
                           @{Expression='DisplayRefreshHz';Descending=$true} | Select-Object -First 1)
  if ($display.Count -gt 0) { $display = $display[0] } else { $display = $null }

  $batteryKnown = $false; $batteries = @()
  try { $batteries = @(Get-CimInstance Win32_Battery -ErrorAction Stop); $batteryKnown = $true } catch {}
  $hasBattery = $(if ($batteryKnown) { [bool]($batteries.Count -gt 0) } else { $null })
  $chassisTypes = @($enclosures | ForEach-Object { @($_.ChassisTypes) } | ForEach-Object { $_ })
  $displayTopology = Get-DisplayTopologyInfo
  $formFactor = Resolve-FormFactor $chassisTypes $hasBattery $displayTopology.HasInternalDisplay
  $isLaptop = $formFactor.FormFactor -eq 'laptop'
  $powerStatus = Get-SystemPowerSnapshot
  $brand = Resolve-ComputerBrand "$($cs.Manufacturer)" "$($cs.Model)" "$($board.Manufacturer)"
  $virtualDisplayCount = @($gpus | Where-Object IsVirtualDisplay).Count
  $physicalGpus = @($gpus | Where-Object { -not $_.IsVirtualDisplay })
  $hybridGraphics = [bool]($physicalGpus.Count -gt 1 -and @($physicalGpus.Vendor | Sort-Object -Unique).Count -gt 1)
  $cpuTopology = @(Get-CpuCoreTopology)
  $cpuEfficiencyClasses = @($cpuTopology | ForEach-Object { [int]$_.Class } | Sort-Object -Unique)

  [pscustomobject]@{
    OS            = $os.Caption
    Build         = [int]$os.BuildNumber
    CPU           = $cpu.Name.Trim()
    CpuVendor     = $cpuVendor
    Cores         = $visibleCores
    Threads       = $visibleThreads
    CpuPackages   = $processors.Count
    CpuEfficiencyClasses = [int[]]$cpuEfficiencyClasses
    HybridCpu     = [bool]($cpuEfficiencyClasses.Count -gt 1)
    HypervisorPresent = $(if ($null -eq $cs.HypervisorPresent) { $null } else { [bool]$cs.HypervisorPresent })
    RamGB         = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    MemoryType    = $memoryType
    MemoryConfiguredMHz = $memoryConfiguredMHz
    MemoryRatedMHz = $memoryRatedMHz
    MemoryModuleCount = $memory.Count
    AutomaticManagedPagefile = [bool]$cs.AutomaticManagedPagefile
    ComputerBrandKey = $brand.Key
    ComputerBrand = $brand.Name
    ComputerManufacturer = "$($cs.Manufacturer)".Trim()
    ComputerModel = "$($cs.Model)".Trim()
    ComputerModelFamily = $(if ("$($cs.SystemFamily)".Trim()) { "$($cs.SystemFamily)".Trim() } else { "$($cs.Model)".Trim() })
    BaseBoardManufacturer = "$($board.Manufacturer)".Trim()
    BaseBoardProduct = "$($board.Product)".Trim()
    BiosEntryHint = Get-BiosEntryInstruction $brand.Key $isLaptop
    Gpus          = $gpus
    MainGpuVendor = $(if ($main) { $main.Vendor } else { 'Unknown' })
    MainGpuName   = $(if ($main) { $main.Name } else { '未检测到' })
    MainGpuReportedName = $(if ($main) { $main.ReportedName } else { '未检测到' })
    MainGpuNameVerified = $(if ($main) { [bool]$main.NameVerified } else { $false })
    MainGpuPnp    = $(if ($main) { $main.Pnp } else { $null })
    MainGpuPciLocation = $(if ($main) { $main.PciLocation } else { $null })
    MainGpuPciMatched = $(if ($main) { [bool]$main.PciMatched } else { $false })
    DisplayWidth   = $(if ($display) { [int]$display.DisplayWidth } else { 0 })
    DisplayHeight  = $(if ($display) { [int]$display.DisplayHeight } else { 0 })
    DisplayRefreshHz = $(if ($display) { [int]$display.DisplayRefreshHz } else { 0 })
    DisplayName    = "$($displayTopology.PrimaryDisplayName)"
    DisplayNames   = [string[]]@($displayTopology.DisplayNames)
    DisplayGpuVendor = $(if ($display) { "$($display.Vendor)" } else { 'Unknown' })
    DisplayGpuName = $(if ($display) { "$($display.Name)" } else { '' })
    DisplayGpuPnp = $(if ($display) { "$($display.Pnp)" } else { '' })
    DisplayGpuNameVerified = $(if ($display) { [bool]$display.NameVerified } else { $false })
    HybridGraphics = $hybridGraphics
    VirtualDisplayCount = $virtualDisplayCount
    HasVirtualDisplay = [bool]($virtualDisplayCount -gt 0)
    FormFactor = "$($formFactor.FormFactor)"
    FormFactorConfidence = "$($formFactor.Confidence)"
    ChassisTypes = [int[]]@($formFactor.ChassisTypes)
    HasBattery = $hasBattery
    HasInternalDisplay = $displayTopology.HasInternalDisplay
    IsUpsAmbiguous = [bool]$formFactor.IsUpsAmbiguous
    ActiveDisplayCount = [int]$displayTopology.ActiveDisplayCount
    InternalDisplayCount = [int]$displayTopology.InternalDisplayCount
    ExternalDisplayCount = [int]$displayTopology.ExternalDisplayCount
    DisplayConnectors = [string[]]@($displayTopology.Connectors)
    PowerSource = "$($powerStatus.Source)"
    BatteryPercent = $powerStatus.BatteryPercent
    IsLaptop      = $isLaptop
    IsAdmin       = Test-Admin
  }
}

function Resolve-ValidatedGamePath([string]$Path) {
  if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) {
    throw '游戏主程序路径必须是完整的绝对路径'
  }
  $full = [IO.Path]::GetFullPath($Path)
  $leaf = [IO.Path]::GetFileName($full)
  if ($leaf -notin @('DeltaForceClient-Win64-Shipping.exe','DeltaForce.exe')) {
    throw '请选择三角洲行动主程序：DeltaForceClient-Win64-Shipping.exe 或 DeltaForce.exe'
  }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw '所选游戏主程序不存在，请重新定位' }
  $file = Get-Item -LiteralPath $full -Force
  if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw '所选游戏主程序是符号链接或重解析文件，请选择真实 exe 文件'
  }
  $full
}

# 平台/卸载信息来自第三方注册表。少数安装器会把 REG_SZ 写成带尾随 NUL 的字符串；
# Windows PowerShell 5.1 在 Test-Path 这类值时会直接抛“路径中具有非法字符”，使整个
# 启动检测中断。自动定位是尽力而为：清掉无意义的尾随 NUL，规范化确实存在的目录；
# 其余损坏、带参数或已离线的单个候选只跳过，不能拖垮硬件检测和系统优化。
function Resolve-ExistingGameSearchRoot([string]$Candidate) {
  if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
  try {
    $value = "$Candidate".Trim().TrimEnd([char[]]@([char]0)).Trim()
    if ($value.Length -ge 2 -and $value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') {
      $value = $value.Substring(1, $value.Length - 2).Trim()
    }
    if (-not $value -or $value.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0 -or
        -not [IO.Path]::IsPathRooted($value)) { return $null }
    $full = [IO.Path]::GetFullPath($value)
    # 损坏的卸载项若误指到 C:\ / 共享根，后面的 Depth 6 会退化成整盘/整共享扫描。
    # 自动定位不接受文件系统根；平台根下的正常子目录仍照常使用。
    if ($full.TrimEnd('\') -ieq ([IO.Path]::GetPathRoot($full)).TrimEnd('\')) { return $null }
    if (Test-Path -LiteralPath $full -PathType Container -ErrorAction SilentlyContinue) { return $full }
  } catch {}
  $null
}

# UninstallString 是命令行，DisplayIcon 是“文件路径[,资源索引]”；二者都不能直接当目录。
# 引号形式只取第一段引号内容，未加引号的卸载命令只取开头到首个完整 .exe，随后再把
# 解析出的文件父目录交给同一条路径校验。这样参数里的 /S、引号、逗号都不会混进搜索根。
function Resolve-RegistryFileParent([string]$RawValue, [bool]$DisplayIcon = $false) {
  if ([string]::IsNullOrWhiteSpace($RawValue)) { return $null }
  try {
    $text = "$RawValue".Trim().TrimEnd([char[]]@([char]0)).Trim()
    $filePath = $null
    if ($text -match '^"([^"]+)"(?:\s.*|,\s*-?\d+\s*)?$') {
      $filePath = $Matches[1]
    } elseif ($DisplayIcon) {
      # 未加引号的图标值没有命令行参数，只允许末尾的资源索引。
      $filePath = ($text -replace ',\s*-?\d+\s*$', '').Trim()
    } elseif ($text -match '^(.+?\.exe)(?:\s+(?:/|-).*)?$') {
      $filePath = $Matches[1]
    }
    if (-not $filePath -or $filePath.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0 -or
        -not [IO.Path]::IsPathRooted($filePath)) { return $null }
    $full = [IO.Path]::GetFullPath($filePath)
    $parent = [IO.Path]::GetDirectoryName($full)
    if ($parent) { return Resolve-ExistingGameSearchRoot $parent }
  } catch {}
  $null
}

function Find-GamePath {
  # 三角洲行动国服走 WeGame，国际服(Delta Force)走 Steam。但玩家常把游戏装到
  # 平台目录之外（实测有人装在 E:\Delta Force\Delta Force），所以按可靠性排序多路查找：
  # ①运行中的进程 ②卸载注册表 ③平台安装目录 ④盘符猜测兜底。
  $exeNames = 'DeltaForceClient-Win64-Shipping.exe', 'DeltaForce.exe'
  $roots = New-Object System.Collections.Generic.List[string]

  # ① 游戏正开着时最省事：直接拿进程的可执行文件路径，零搜索、零歧义
  foreach ($pn in 'DeltaForceClient-Win64-Shipping', 'DeltaForceClient', 'DeltaForce') {
    foreach ($proc in @(Get-Process -Name $pn -ErrorAction SilentlyContinue)) {
      try { if ($proc.Path -and $proc.Path -match 'Shipping') { return $proc.Path } } catch {}
    }
  }

  # ② 卸载注册表：不管装在哪个盘、哪个目录都登记在册，比猜路径可靠得多
  # GUI 可能由另一名管理员账户批准 UAC；这里不得让 PowerShell Provider 的 HKCU
  # 悄悄落到批准账户，显式枚举 EngineHost 已复验的原交互用户 HKEY_USERS hive。
  $targetUserUninstall = "Registry::HKEY_USERS\$script:TargetUserSid\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
  $unKeys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            $targetUserUninstall
  foreach ($e in @(Get-ItemProperty $unKeys -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -match '三角洲|Delta\s*Force|DeltaForce' })) {
    # InstallLocation 常为空，此时从卸载程序/图标路径倒推安装目录
    $candidates = @($e.InstallLocation,
                    (Resolve-RegistryFileParent "$($e.UninstallString)" $false),
                    (Resolve-RegistryFileParent "$($e.DisplayIcon)" $true))
    foreach ($cand in $candidates) {
      $resolved = Resolve-ExistingGameSearchRoot "$cand"
      if ($resolved) { $roots.Add($resolved) }
    }
  }

  foreach ($rk in 'HKLM:\SOFTWARE\WOW6432Node\Tencent\WeGame', 'HKCU:\Software\Tencent\WeGame') {
    $ip = Resolve-ExistingGameSearchRoot "$(Get-RegValue $rk 'InstallPath')"
    if ($ip) { $roots.Add($ip) }
  }

  $steam = Resolve-ExistingGameSearchRoot "$(Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath')"
  if ($steam) {
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
      foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
        $lib = Resolve-ExistingGameSearchRoot ($m.Groups[1].Value -replace '\\\\', '\')
        if ($lib) {
          $g = Resolve-ExistingGameSearchRoot (Join-Path $lib 'steamapps\common\Delta Force')
          if ($g) { $roots.Add($g) }
        }
      }
    }
  }

  $uniq = @($roots | Where-Object { $_ } | Select-Object -Unique)

  # 先按虚幻引擎的固定布局直接命中，省掉递归扫描；同时兼容"根目录已经是游戏子目录"的情形
  foreach ($r in $uniq) {
    foreach ($rel in 'DeltaForce\Binaries\Win64\DeltaForceClient-Win64-Shipping.exe',
                     'Delta Force\DeltaForce\Binaries\Win64\DeltaForceClient-Win64-Shipping.exe',
                     'Binaries\Win64\DeltaForceClient-Win64-Shipping.exe') {
      $p = Join-Path $r $rel
      if (Test-Path -LiteralPath $p) { return $p }
    }
  }

  # 兜底：平台目录下按盘符猜测（放最后，因为这里最可能扫到无关的大目录）
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
    foreach ($guess in 'Delta Force', 'WeGame', 'WeGameApps', 'Program Files\WeGame') {
      $p = Resolve-ExistingGameSearchRoot (Join-Path $d.Root $guess)
      if ($p) { $uniq += $p }
    }
  }

  $found = @()
  foreach ($r in ($uniq | Select-Object -Unique)) {
    foreach ($n in $exeNames) {
      $found += @(Get-ChildItem -LiteralPath $r -Recurse -Depth 6 -Filter $n -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)
    }
    # 找到就停，别为了凑齐所有结果把每个候选目录都递归扫一遍
    if ($found.Count -gt 0) { break }
  }
  # 全屏优化/GPU 首选项要落在真正渲染的进程上，优先 Shipping 主程序
  $ship = $found | Where-Object { $_ -match 'Shipping' } | Select-Object -First 1
  if ($ship) { return $ship }
  $found | Select-Object -First 1
}

# ---------- 着色器缓存 ----------

# 驱动与 DirectX 把编译好的着色器缓存在这些目录。缓存损坏或与新版本错位时，典型症状是
# 「进游戏后每隔十几秒卡 2~3 秒」。只列系统与驱动的缓存目录——游戏安装目录是本工具的红线。
# 本机没装对应品牌显卡时目录根本不存在，那不是错误，跳过即可
function Get-ShaderCacheDirs {
  @(
    @{ Label = 'DirectX 着色器缓存'; Path = (Join-Path $script:TargetLocalAppData 'D3DSCache'); Scope = 'user' }
    @{ Label = 'NVIDIA DX 缓存';     Path = (Join-Path $script:TargetLocalAppData 'NVIDIA\DXCache'); Scope = 'user' }
    @{ Label = 'NVIDIA GL 缓存';     Path = (Join-Path $script:TargetLocalAppData 'NVIDIA\GLCache'); Scope = 'user' }
    @{ Label = 'NVIDIA 全局缓存';    Path = (Join-Path $script:CommonAppData 'NVIDIA Corporation\NV_Cache'); Scope = 'system' }
    @{ Label = 'AMD DX 缓存';        Path = (Join-Path $script:TargetLocalAppData 'AMD\DxCache'); Scope = 'user' }
    @{ Label = 'AMD DXC 缓存';       Path = (Join-Path $script:TargetLocalAppData 'AMD\DxcCache'); Scope = 'user' }
    @{ Label = 'Intel 着色器缓存';   Path = (Join-Path $script:TargetLocalAppData 'Intel\ShaderCache'); Scope = 'user' }
  )
}

function Test-PathHasReparsePoint([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  $root = [IO.Path]::GetPathRoot($full)
  $cur = $root
  $rest = $full.Substring($root.Length).TrimEnd('\')
  foreach ($part in @($rest -split '\\' | Where-Object { $_ })) {
    $cur = Join-Path $cur $part
    if (-not (Test-Path -LiteralPath $cur)) { break }
    $attrs = [IO.File]::GetAttributes($cur)
    if (($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
  }
  $false
}

function Get-SafeFilesUnderRoot([string]$Root) {
  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
  if (Test-PathHasReparsePoint $rootFull) {
    return [pscustomobject]@{ Files = @(); Rejected = @($rootFull) }
  }
  $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
  $stack = New-Object 'System.Collections.Generic.Stack[string]'
  $stack.Push($rootFull)
  $files = New-Object System.Collections.Generic.List[object]
  $rejected = New-Object System.Collections.Generic.List[string]
  while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    foreach ($entry in @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
      try {
        $full = [IO.Path]::GetFullPath($entry.FullName)
        if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
          [void]$rejected.Add($full); continue
        }
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
          [void]$rejected.Add($full); continue
        }
        if ($entry.PSIsContainer) { $stack.Push($full) }
        else { [void]$files.Add($entry) }
      } catch { [void]$rejected.Add("$($entry.FullName)") }
    }
  }
  [pscustomobject]@{ Files = @($files | ForEach-Object { $_ }); Rejected = @($rejected | ForEach-Object { $_ }) }
}

# 当前占用总量，供界面显示「值不值得清」。目录不存在或读不到都按 0 计
function Get-ShaderCacheSize {
  $sum = 0
  foreach ($d in Get-ShaderCacheDirs) {
    if (-not (Test-Path -LiteralPath $d.Path)) { continue }
    $f = @((Get-SafeFilesUnderRoot $d.Path).Files)
    if ($f.Count -gt 0) { $sum += ($f | Measure-Object Length -Sum).Sum }
  }
  $sum
}

# 逐文件删而不是删整个目录：目录本身被驱动持有，删掉可能要重启才重建。
# 游戏或驱动面板开着时部分文件必然被占用——那是常态，如实报数，不算失败
function Clear-ShaderCache {
  $cleared = @(); $failed = @()
  foreach ($d in Get-ShaderCacheDirs) {
    if (-not (Test-Path -LiteralPath $d.Path)) { continue }
    if ($d.Scope -eq 'system') {
      # ProgramData 缓存需要 handle/no-follow 遍历才能完全消除检查→删除 TOCTOU；当前版本
      # 宁可跳过，也不在管理员权限下用字符串路径递归删除。
      $failed += "$($d.Label) 属于系统级缓存，当前安全模式暂不自动删除"
      continue
    }
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $currentLocal = [IO.Path]::GetFullPath([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)).TrimEnd('\')
    if ((Test-Admin) -or $currentSid -ine $script:TargetUserSid -or $currentLocal -ine $script:TargetLocalAppData.TrimEnd('\')) {
      $failed += "$($d.Label) 必须由目标用户的普通权限进程清理，已拒绝在提权进程中删除"
      continue
    }
    $scan = Get-SafeFilesUnderRoot $d.Path
    if (@($scan.Rejected).Count -gt 0) {
      $failed += "$($d.Label) 含目录联接/符号链接或越界项，已拒绝整目录清理"
      continue
    }
    $rootFull = [IO.Path]::GetFullPath($d.Path).TrimEnd('\')
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    $files = @($scan.Files)
    if ($files.Count -eq 0) { continue }
    $bytes = ($files | Measure-Object Length -Sum).Sum
    $err = 0
    foreach ($f in $files) {
      try {
        $candidate = [IO.Path]::GetFullPath($f.FullName)
        if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
            (Test-PathHasReparsePoint $candidate)) { throw '候选文件越界或路径中出现重解析点' }
        Remove-Item -LiteralPath $candidate -Force -ErrorAction Stop
      } catch { $err++ }
    }
    if ($err -eq 0) {
      $cleared += "$($d.Label) 已清空（$([math]::Round($bytes / 1MB, 1))MB）"
    } elseif ($err -lt $files.Count) {
      $cleared += "$($d.Label) 清理 $($files.Count - $err)/$($files.Count) 个文件（$err 个被占用）"
    } else {
      $failed += "$($d.Label) 全部文件被占用，未清理"
    }
  }
  @{ Cleared = $cleared; Failed = $failed }
}

# ---------- 优化项定义 ----------

# 电源子组 GUID（微软公开文档值）
$script:SubUsb  = '2a737441-1930-4402-8d77-b2bebba308a3'
$script:SubProc = '54533251-82be-4824-96c1-47b60b740d00'

function Get-GpuSpoofModels {
  @('NVIDIA GeForce GTX 750 Ti', 'NVIDIA GeForce GTX 1050 Ti',
    'NVIDIA GeForce RTX 2050', 'NVIDIA GeForce RTX 2060', 'AMD Radeon RX560')
}

function Test-RecommendedGpuSpoofModel([string]$Model) {
  $Model -in @('NVIDIA GeForce GTX 750 Ti', 'NVIDIA GeForce GTX 1050 Ti', 'AMD Radeon RX560')
}

function Test-GpuNameSpoofSupported($Hw) {
  [bool]($Hw -and "$($Hw.MainGpuVendor)" -in @('NVIDIA','AMD'))
}

function Get-DefaultGpuSpoofModel([string]$GpuName, [bool]$IsLaptop, [string]$GpuVendor = '') {
  if ($GpuVendor -eq 'AMD' -or (-not $GpuVendor -and "$GpuName" -match '(?i)AMD|Radeon')) {
    return 'AMD Radeon RX560'
  }
  # 按用户实机经验做代际映射：RTX 30 系默认伪装为 750 Ti，40/50 系默认 1050 Ti。
  # 其他 N 卡保留原先的机型兜底逻辑，界面可手动切换全部五种目标型号。
  if ("$GpuName" -match '(?i)RTX\s*30\d{2}') { return 'NVIDIA GeForce GTX 750 Ti' }
  if ("$GpuName" -match '(?i)RTX\s*(?:40|50)\d{2}') { return 'NVIDIA GeForce GTX 1050 Ti' }
  if ($IsLaptop) { return 'NVIDIA GeForce GTX 1050 Ti' }
  'NVIDIA GeForce GTX 750 Ti'
}

function Test-TrustedNvidiaProfileInspector([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  if ((Split-Path -Leaf $Path) -ine 'nvidiaProfileInspector.exe') { return $false }
  if (Test-PathHasReparsePoint $Path) { return $false }
  try {
    $sig = Get-AuthenticodeSignature -LiteralPath $Path
    [bool]($sig.Status -eq 'Valid' -and $sig.SignerCertificate -and
           $sig.SignerCertificate.Subject -match '(?i)(^|,\s*)CN=(NVIDIA Corporation|Orbmu2k)(,|$)')
  } catch { $false }
}

function Get-OptItems([string]$GamePath, [string]$GpuSpoofModel) {
  $items = @()
  $hw = $null
  try { $hw = Get-HardwareInfo } catch {}
  # 游戏路径会同时用于 AppCompat、GPU 首选项和 IFEO。入口先严格限定真实游戏主程序，
  # 避免用户在文件选择器里误点任意 exe 后得到一串难懂的备份白名单失败。
  if ($GamePath) { $GamePath = Resolve-ValidatedGamePath $GamePath }
  $exeName = $(if ($GamePath) { Split-Path -Leaf $GamePath } else { $null })

  # ===== safe 档：默认推荐，不降低系统安全性 =====

  # Reboot 标记：该项写入成功后仍需重启才完全生效。GUI 重启提醒和 CLI 汇总都读这个
  # 字段而不是解析 Note 文本——文案会改，结构化标记不会漂
  $items += @{ Id = 'power-ultimate'; Tier = 'safe'; Name = '电源计划切换到「卓越性能」'; Admin = $true; Default = $true; Kind = 'power'; Reboot = $true
               Note = '解除系统对 CPU 频率的保守限制。台式机收益明显；笔记本电池续航会变差。重启后完全生效。' }

  # 电源计划隐藏项：控制面板里看不到，必须用 powercfg 直接写
  $items += @{ Id = 'power-tuning'; Tier = 'safe'; Name = '电源计划隐藏项深度调优（USB/调度/时间片）'; Admin = $true; Default = $true; Kind = 'multi'; Reboot = $true
               Ops  = @(
                 @{ Kind = 'pcfg'; Sub = $script:SubUsb;  Setting = 'd4e98f31-5ffe-4ce1-be31-1b38b384c009'; Value = 0;    Label = 'USB3 链路电源管理=关闭' }
                 @{ Kind = 'pcfg'; Sub = $script:SubProc; Setting = '4d2b0152-7d5c-498b-88e2-34345392a2c5'; Value = 5000; Label = '处理器性能时间检查间隔=5000ms' }
                 @{ Kind = 'pcfg'; Sub = $script:SubProc; Setting = '93b8b6dc-0698-4d1c-9ee4-0644e900c85d'; Value = 1;    Label = '大小核调度策略=高性能核心'; Optional = $true }
                 @{ Kind = 'pcfg'; Sub = $script:SubProc; Setting = 'bae08b81-2d5e-4688-ad6a-13243356654b'; Value = 1;    Label = '短任务大小核调度=高性能核心'; Optional = $true }
                 @{ Kind = 'reg';  Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'; Name = 'PowerThrottlingOff'; Value = 1; Kind2 = 'DWord'; Label = '关闭电源节流' }
               )
               Note = 'USB 链路省电会让键鼠有粘滞感；时间片拉长可减少频率抖动；大小核调度项只在 12 代+ Intel 等混合架构上存在，不存在会自动跳过。' }

  $items += @{ Id = 'powerplan-lock'; Tier = 'safe'; Name = '锁定电源计划（防游戏偷改回去）'; Admin = $true; Default = $false; Kind = 'sched'
               Note = '建立每分钟运行一次的计划任务，把电源计划重新设回当前方案。三角洲已知会在启动时篡改电源计划。这是持久化配置，还原时会自动删除该任务。' }

  $items += @{ Id = 'hags'; Tier = 'safe'; Name = '开启硬件加速 GPU 计划（HAGS）'; Admin = $true; Default = $true; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name = 'HwSchMode'; Value = 2; Kind2 = 'DWord' })
               Note = '降低显卡调度延迟。需要 Win10 2004+ 与较新驱动，重启后生效。' }

  $items += @{ Id = 'game-mode'; Tier = 'safe'; Name = '开启 Windows 游戏模式'; Admin = $false; Default = $true; Kind = 'multi'
               Ops  = @(
                 @{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AutoGameModeEnabled'; Value = 1; Kind2 = 'DWord' }
                 @{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AllowAutoGameMode';   Value = 1; Kind2 = 'DWord' }
               )
               Note = '游戏运行时系统自动降低后台活动优先级。' }

  $items += @{ Id = 'dvr-off'; Tier = 'safe'; Name = '关闭 Xbox 后台录制（Game DVR）'; Admin = $false; Default = $true; Kind = 'multi'
               Ops  = @(
                 @{ Kind = 'reg'; Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; Kind2 = 'DWord' }
                 @{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0; Kind2 = 'DWord' }
               )
               Note = '后台录制持续占用显卡编码器和内存带宽，是最常见的隐形掉帧源。' }

  $items += @{ Id = 'prio-separation'; Tier = 'safe'; Name = '前台程序调度权重（Win32PrioritySeparation=40）'; Admin = $true; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'; Name = 'Win32PrioritySeparation'; Value = 40; Kind2 = 'DWord' })
               Note = '短时间片 + 固定长度，牺牲一点后台响应换取前台游戏帧生成更稳定。' }

  $items += @{ Id = 'paging-exec'; Tier = 'safe'; Name = '内核代码常驻内存（DisablePagingExecutive）'; Admin = $true; Default = $true; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'DisablePagingExecutive'; Value = 1; Kind2 = 'DWord' })
               Note = '禁止内核代码被换出到硬盘，减少卡顿尖峰。内存 8G 以下不建议。' }

  $items += @{ Id = 'wer-off'; Tier = 'safe'; Name = '关闭 Windows 错误报告'; Admin = $false; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1; Kind2 = 'DWord' })
               Note = '游戏崩溃瞬间不再收集转储，避免二次卡死。' }

  # 内存压缩：16G 以下关掉反而更容易爆内存，默认只在 32G 及以上勾选
  $bigRam = ($hw -and $hw.RamGB -ge 32)
  $items += @{ Id = 'mem-compress-off'; Tier = 'safe'; Name = '关闭内存压缩与页面合并'; Admin = $true; Default = $bigRam; Kind = 'multi'; Reboot = $true
               Ops  = @(
                 @{ Kind = 'mmagent'; Feature = 'mc'; Label = '内存压缩' }
                 @{ Kind = 'mmagent'; Feature = 'pc'; Label = '页面合并' }
               )
               Note = '省下压缩/解压的 CPU 开销，代价是内存吃紧时更早开始动用硬盘。内存 32G 以上默认勾选，16G 及以下不建议。' }

  $items += @{ Id = 'transparency-off'; Tier = 'safe'; Name = '关闭窗口透明特效'; Admin = $false; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Kind2 = 'DWord' })
               Note = '减少桌面合成开销，对低配机有小幅收益。' }

  $items += @{ Id = 'visualfx-perf'; Tier = 'safe'; Name = '视觉效果调整为最佳性能（改变系统外观）'; Admin = $false; Default = $false; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Value = 2; Kind2 = 'DWord' })
               Note = '关闭全部窗口动画和阴影，桌面观感会明显变朴素，默认不勾选。' }

  $items += @{ Id = 'mouse-accel-off'; Tier = 'safe'; Name = '关闭鼠标「提高指针精确度」（电竞常规操作）'; Admin = $false; Default = $false; Kind = 'multi'
               Ops  = @(
                 @{ Kind = 'reg'; Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseSpeed';      Value = '0'; Kind2 = 'String' }
                 @{ Kind = 'reg'; Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold1'; Value = '0'; Kind2 = 'String' }
                 @{ Kind = 'reg'; Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold2'; Value = '0'; Kind2 = 'String' }
               )
               Note = '与帧率无关但影响压枪手感，射击游戏玩家普遍关闭。会改变鼠标移动习惯，默认不勾选。' }

  # ===== v0.4 新增：全套调试路线补齐 =====

  $items += @{ Id = 'mpo-off'; Tier = 'safe'; Name = '禁用 MPO 多平面叠加（治闪烁/卡顿）'; Admin = $true; Default = $true; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'; Name = 'OverlayTestMode'; Value = 5; Kind2 = 'DWord' })
               Note = 'MPO 与部分驱动组合会造成画面闪烁和掉帧，NVIDIA 官方曾专门发布禁用工具。副作用：视频播放时 DWM 功耗略升。重启生效。' }

  $mmcss = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
  # DWord 0xffffffff 在 .NET 有符号 int 里就是 -1，写 4294967295 会转换溢出
  $items += @{ Id = 'net-throttling-off'; Tier = 'safe'; Name = '解除多媒体网络限流'; Admin = $true; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = $mmcss; Name = 'NetworkThrottlingIndex'; Value = -1; Kind2 = 'DWord'; Label = '网络限流指数（-1 即 0xffffffff 不限流）' })
               Note = '系统默认每毫秒只放行 10 个网络包给非多媒体流量，网游高发包率下引入延迟抖动；0xffffffff 表示彻底不限流。' }

  $items += @{ Id = 'sys-responsiveness'; Tier = 'safe'; Name = '提高系统响应度（MMCSS 后台保留=10%）'; Admin = $true; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = $mmcss; Name = 'SystemResponsiveness'; Value = 10; Kind2 = 'DWord'; Label = '后台 CPU 保留比例' })
               Note = '把系统为后台多媒体任务保留的 CPU 比例设为 Windows 支持的最低有效值 10%。低于 10 的值会被系统钳制为 20，因此不再写无效的 0。' }

  $items += @{ Id = 'sysmain-off'; Tier = 'safe'; Name = '禁用 SysMain 预取服务'; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain'; Name = 'Start'; Value = 4; Kind2 = 'DWord'; Label = 'SysMain 启动类型（4=禁用）' })
               Note = 'SysMain（旧名 Superfetch）后台预读抢内存和磁盘带宽，SSD 上收益存疑。副作用：常用程序冷启动可能略变慢，默认不勾选。重启后彻底停止。' }

  $items += @{ Id = 'wsearch-off'; Tier = 'safe'; Name = '禁用 Windows Search 索引服务'; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch'; Name = 'Start'; Value = 4; Kind2 = 'DWord'; Label = 'WSearch 启动类型（4=禁用）' })
               Note = '索引器后台扫盘占 IO。副作用明显：开始菜单和资源管理器搜索会变慢（现场逐盘找），只推荐给从不用系统搜索的人，默认不勾选。重启生效。' }

  $items += @{ Id = 'hibernate-off'; Tier = 'safe'; Name = '关闭休眠与快速启动'; Admin = $true
               Default = [bool]($hw -and -not $hw.IsLaptop); Kind = 'multi'
               Ops  = @(@{ Kind = 'hib'; Label = '休眠' })
               Note = '释放 C 盘数 GB 的 hiberfil.sys，并消除快速启动"假关机"导致的状态残留。副作用：休眠与快速启动都不可用，笔记本合盖只剩睡眠，故只在台式机默认勾选。' }

  $gpuClass = Get-GpuClassKeyPath $hw
  $items += @{ Id = 'gpu-pstate-lock'; Tier = 'safe'; Name = '禁止显卡动态降频（锁 P-State）'; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = $(if ($gpuClass) { @(@{ Kind = 'reg'; Path = $gpuClass; Name = 'DisableDynamicPstate'; Value = 1; Kind2 = 'DWord' }) })
               Note = '阻止驱动随负载波动来回降频，减少频率抖动带来的帧率毛刺。副作用：待机功耗和发热明显上升、笔记本续航变差，默认不勾选。重启生效。' }

  # NVIDIA App 的「自动优化」开关落在 NvBackend\config.xml 的 EnableAutomaticApplyOPS
  # （OPS=Optimal Playable Settings，本机 A/B 实测坐实：界面开关与该值即时联动、App 常驻
  # 时也直接写盘）。没装 NVIDIA App（A 卡/核显）时文件不存在，Ops 置空走「本机不适用」降级
  $items += @{ Id = 'nv-autoopt-off'; Tier = 'safe'; Name = 'NVIDIA App 自动优化体检（手动关闭）'; Admin = $false; Default = $false; Kind = 'check'
               Check = 'Get-NvAutoOptStatus'
               Note = '只检测 NVIDIA App 是否仍在自动覆盖游戏设置，不再由工具写入用户配置文件；发现开启时请在 NVIDIA App 内手动关闭。' }

  $items += @{ Id = 'gpu-irq-affinity'; Tier = 'safe'; Name = '显卡中断绑核（固定到高性能核）'; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = (Get-GpuIrqOps $hw)
               Note = '把独显中断固定到编号最大的物理核（大小核机型按 EfficiencyClass 选最后一个 P 核），避开挤满系统中断的 CPU0，压低 DPC 延迟。读不到核拓扑时本项自动不可用（宁可不做不能做错）。重启生效，还原即删除策略。' }

  # 与 sys-responsiveness 同属 MMCSS，是同一父键下的兄弟项：那个调后台保留比例，这个调游戏任务本身的档位
  $mmTasks = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
  $items += @{ Id = 'mmcss-games'; Tier = 'safe'; Name = 'MMCSS 游戏任务档位拉满'; Admin = $true; Default = $true; Kind = 'multi'
               Ops  = @(
                 @{ Kind = 'reg'; Path = $mmTasks; Name = 'GPU Priority';        Value = 8;      Kind2 = 'DWord';  Label = 'GPU 优先级' }
                 @{ Kind = 'reg'; Path = $mmTasks; Name = 'Priority';            Value = 6;      Kind2 = 'DWord';  Label = '任务优先级' }
                 @{ Kind = 'reg'; Path = $mmTasks; Name = 'Scheduling Category'; Value = 'High'; Kind2 = 'String'; Label = '调度类别' }
                 @{ Kind = 'reg'; Path = $mmTasks; Name = 'SFIO Priority';       Value = 'High'; Kind2 = 'String'; Label = '文件IO优先级' }
               )
               Note = '把系统给"游戏"这类多媒体任务的 GPU/IO 调度档位调到最高。收益微弱（不是博主说的立竿见影），但零副作用且可完整还原，属于体系补齐。' }

  # DirectXUserGlobalSettings 是分号分隔的复合串（还含 AutoHDREnable 等），必须只改目标子键
  $items += @{ Id = 'windowed-opt-off'; Tier = 'safe'; Name = '关闭「窗口化游戏优化」'; Admin = $false; Default = $false; Kind = 'multi'
               Ops  = @(@{ Kind = 'kvstr'; Path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
                           Name = 'DirectXUserGlobalSettings'; Key = 'SwapEffectUpgradeEnable'; Value = '0'
                           Label = '窗口化游戏优化' })
               Note = '对应「设置→系统→显示→图形→默认图形设置」里的开关。微软说开启能降低窗口模式延迟，但社区普遍反馈它与叠加层/反作弊冲突时反而掉帧——两种说法都有人实测支持，所以默认不勾选，建议自己开关各测一次再定。' }

  # 检测类项目：Check 字段指明检测函数，只读不写。新增检测项只要加一行 + 写个返回 @{Ok;Text} 的函数
  $items += @{ Id = 'pcie-check'; Tier = 'safe'; Name = 'PCIe 通道体检（纯检测，不改设置）'; Admin = $false; Default = $false; Kind = 'check'
               Check = 'Get-PcieLinkStatus'
               Note = '读取独显 PCIe 链路的最大能力。上限只有 x8/x4 多半是插错插槽或用了劣质延长线，这种硬件问题白丢帧、软件修不了。空闲时当前速率自动降档属正常省电。' }

  # 默认勾选：v14 运行库异常是社区排查掉帧时最常命中的一条（教程里常被叫作「V14」），
  # 纯检测不写任何东西，代价为零，没有理由让用户自己想起来勾
  $items += @{ Id = 'vcredist-check'; Tier = 'safe'; Name = 'VC++ 运行库体检（纯检测，不改设置）'; Admin = $false; Default = $true; Kind = 'check'
               Check = 'Get-VcRedistStatus'
               Note = '检测 VC++ 2015-2022(v14) 运行库是否缺失——缺了游戏很可能无法启动。x64 与 x86 两套相互独立，版本不同步很常见且通常无害，只做中性提示不报问题。本项只检测不修——卸载重装运行库会波及其他软件，须你自己判断后手动处理。' }

  $items += @{ Id = 'xmp-check'; Tier = 'safe'; Name = '内存频率 / XMP·A-XMP·EXPO·DOCP 体检（纯检测）'; Admin = $false; Default = $false; Kind = 'check'
               Check = 'Get-MemoryXmpStatus'
               Note = '比较内存当前频率与 SMBIOS 标称频率，并按电脑品牌、平台与 DDR 代际给出可能的 BIOS 菜单名。不是每台电脑都有性能档位；达到标称频率时不会再误报“未开启”。' }

  # 实验项：默认不勾、不进任何内置方案。社区大面积反馈的「进游戏后每隔十几秒卡 2~3 秒」
  # 多方指向着色器缓存异常，但这是经验疗法而非确证的因果，名字里必须写明不保证生效。
  # 缓存是可再生的派生数据，删掉由驱动自动重建——所以本项不产生备份，也没有还原的必要，
  # 这是它与其余所有优化项的根本区别，Note 里对用户讲清楚
  # 项名以「解决掉帧」开头：用户搜的、问的都是这四个字，「清理着色器缓存」是手段不是诉求，
  # 只写手段的话真正需要它的人在列表里根本认不出来
  $items += @{ Id = 'shader-cache-clean'; Tier = 'safe'; Name = '★ 解决掉帧：清理着色器缓存（实验功能，不保证生效）'; Admin = $false; Default = $false; Kind = 'cache'
               Note = '针对「进游戏后每隔十几秒卡顿 2~3 秒」这类症状——社区普遍指向显卡/DirectX 着色器缓存异常，游戏大版本更新后尤其高发。只清理系统与显卡驱动的缓存目录，不碰游戏安装目录内任何文件。执行前请先知道三件事：①清理后首次进游戏要重新编译着色器，头一两局可能比现在更卡，之后才恢复；②如果你的掉帧不是从游戏更新之后才开始的，这项大概率无效；③缓存由驱动自动重建，因此本项不进备份、也无需还原——点「还原设置」不会把它恢复回来（也不需要）。游戏和显卡驱动面板开着时部分文件会被占用，关掉再执行效果最好。' }

  $items += @{ Id = 'dyntick-off'; Tier = 'safe'; Name = '禁用动态计时器（bcdedit）'; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'bcd'; Name = 'disabledynamictick'; Value = 'yes'; Label = '动态计时器' })
               Note = '恢复固定时钟中断，部分机器帧生成间隔更稳。副作用：空闲功耗略升、笔记本续航变差，默认不勾选。重启生效。' }

  # 经验公式：初始=内存GB×1024×1.5、最大=×2。固定大小是为防页面文件动态收缩引发卡顿；
  # 收益只在闪退/爆内存场景成立，平时不值得占这份磁盘，所以默认不勾选
  $ramInt = $(if ($hw) { [int][math]::Round($hw.RamGB) } else { 0 })
  $items += @{ Id = 'pagefile-custom'; Tier = 'safe'; Name = "虚拟内存固定为 $([int]($ramInt * 1.5))–$($ramInt * 2) GB"; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = $(if ($ramInt -gt 0) { @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
                                                  Name = 'PagingFiles'; Kind2 = 'MultiString'; Label = '页面文件'
                                                   Value = [string[]]@("$script:SystemDrive\pagefile.sys $($ramInt * 1536) $($ramInt * 2048)") }) })
               Note = '取消系统自动管理，按公式固定页面文件（初始=内存×1.5、最大=×2），防止动态收缩引发卡顿。只建议在游戏闪退/爆内存时启用：会立即占用系统盘约 ' + [int]($ramInt * 1.5) + ' GB，默认不勾选。重启生效。' }

  # 以下几项按 exe 路径/文件名落地，没有游戏路径时 Ops 为空，Apply 时跳过并提示
  $fsoOps = $null; $gpuOps = $null; $prioOps = $null
  if ($GamePath) {
    $fsoOps  = @(@{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'; Name = $GamePath; Value = '~ DISABLEDXMAXIMIZEDWINDOWEDMODE'; Kind2 = 'String' })
    $gpuOps  = @(@{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'; Name = $GamePath; Value = 'GpuPreference=2;'; Kind2 = 'String' })
    $ifeo    = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName\PerfOptions"
    $prioOps = @(
      @{ Kind = 'reg'; Path = $ifeo; Name = 'CpuPriorityClass'; Value = 3; Kind2 = 'DWord' }
      @{ Kind = 'reg'; Path = $ifeo; Name = 'IoPriority';       Value = 3; Kind2 = 'DWord' }
    )
  }
  $items += @{ Id = 'fso-off'; Tier = 'safe'; Name = '为游戏禁用全屏优化'; Admin = $false; Default = $true; Kind = 'multi'
               Ops = $fsoOps; RequiresGame = $true
               Note = '让游戏拿到真独占全屏，帧率更稳、延迟更低。需要游戏 exe 路径。' }
  $items += @{ Id = 'gpu-pref'; Tier = 'safe'; Name = '强制游戏使用高性能 GPU'; Admin = $false; Default = $true; Kind = 'multi'
               Ops = $gpuOps; RequiresGame = $true
               Note = '双显卡（核显+独显）笔记本必开，防止游戏跑在核显上。需要游戏 exe 路径。' }
  $items += @{ Id = 'game-priority'; Tier = 'safe'; Name = '游戏进程 CPU/IO 优先级提到「高」'; Admin = $true; Default = $true; Kind = 'multi'
               Ops = $prioOps; RequiresGame = $true
               Note = '通过 IFEO 让游戏进程一启动就是高优先级，抢占后台扫描/更新占用的资源。需要游戏 exe 路径。' }

  # ===== risky 档：必须显式勾选 + -Risky 才执行；仅主推全套包含，界面必须单独二次确认 =====

  # 改独显上报的型号名。实测结论（RTX 3070 Laptop / Win11 26200）：该键管理员组有
  # FullControl，直接写即可，无需 takeown 或改 ACL；写入即时生效（WMI 立刻改口径），
  # 写回原字符串后逐字节一致、WMI 同步复原——所以备份/还原走通用 reg 通路就够。
  if (Test-GpuNameSpoofSupported $hw) {
    $gpuEnum = Get-GpuNameEnumPath $hw
    $spoofModels = @(Get-GpuSpoofModels)
    $fakeGpu = $(if ($GpuSpoofModel -and $spoofModels -contains $GpuSpoofModel) { $GpuSpoofModel }
                 else { Get-DefaultGpuSpoofModel $hw.MainGpuName $hw.IsLaptop $hw.MainGpuVendor })
    $items += @{ Id = 'gpu-name-spoof'; Tier = 'risky'; Name = '★ 显卡型号伪装'; SpoofModel = $fakeGpu; Admin = $true; Default = $false; Kind = 'multi'
                 Ops = $(if ($gpuEnum) { @(@{ Kind = 'reg'; Path = $gpuEnum; Name = 'DeviceDesc'; Value = $fakeGpu
                                             Kind2 = 'String'; Label = '显卡型号' }) })
                 Note = '让游戏以为你是另一款显卡从而选择不同渲染路径。已有实测反例：有人改完帧数不升反降。重装或更新显卡驱动后失效（DeviceDesc 被驱动写回）。系统上报的型号与真实硬件不一致，反作弊如何对待这种状态没有公开说明。支持 NVIDIA 与 AMD 主显卡，备份原值可完整还原。' }
  }

  # N 卡进阶：用户自行下载 NVIDIA Profile Inspector 放进 tools\ 后才出现此项
  $npi = Join-Path $script:ToolsDir 'nvidiaProfileInspector.exe'
  $nip = Get-Item -LiteralPath (Join-Path $script:ToolsDir 'DeltaForce-Recommended.nip') -ErrorAction SilentlyContinue
  if ((Test-TrustedNvidiaProfileInspector $npi) -and $nip -and -not (Test-PathHasReparsePoint $nip.FullName)) {
    $items += @{ Id = 'nvidia-profile'; Tier = 'safe'; Name = "导入 N 卡驱动配置档（$($nip.Name)）"; Admin = $true; Default = $false; Kind = 'npi'
                 Npi = $npi; Nip = $nip.FullName
                 Note = '仅在 NVIDIA Profile Inspector 带有效且受信发布者签名时调用，并检查导入进程退出码。此项无自动备份，请先在 Inspector 里手动导出当前配置。' }
  }

  $items
}

# ---------- 优化方案（内置推荐 + 用户自存） ----------

# 内置方案只列"要勾选的项"，不存在的项（如本机没装 Profile Inspector）自动忽略。
# 列表顺序即界面下拉顺序：「主推全套」排第一位。
function Get-BuiltinPresets {
  @(
    [pscustomobject]@{
      # Items 顺序刻意按依赖关系排列：
      # ①电源深度定制（一切的前置）→ ②进程/IO 优先级 → ③中断绑核 → ④系统精简 → ⑤显卡驱动层
      Id = 'main'; Name = '主推全套'; Builtin = $true
      Note = '按电源→优先级→中断绑核→系统精简→显卡层的顺序全套执行；NVIDIA / AMD 主显卡显示并包含显卡型号伪装（执行前单独二次确认），Intel 显卡自动禁用该项。代价：鼠标手感变直、休眠/快速启动没了、Windows 搜索变慢、待机功耗升高（笔记本更耗电）。不关引导虚拟化，WSL/模拟器不受影响。'
      Items = @('power-ultimate','power-tuning','powerplan-lock',
                'prio-separation','game-priority','sys-responsiveness','mmcss-games','net-throttling-off','game-mode',
                'gpu-irq-affinity',
                'dvr-off','wer-off','sysmain-off','wsearch-off','hibernate-off','mem-compress-off',
                'paging-exec','transparency-off','mpo-off','dyntick-off','mouse-accel-off',
                'hags','fso-off','gpu-pref','gpu-pstate-lock','gpu-name-spoof',
                'pcie-check','vcredist-check','xmp-check')
    }
    [pscustomobject]@{
      Id = 'balanced'; Name = '均衡推荐'; Builtin = $true
      Note = '收益明确、副作用小的一组，适合绝大多数人。不改桌面外观和鼠标手感，不禁用任何服务，不动休眠。顺带做三项硬件体检。'
      Items = @('power-ultimate','power-tuning','hags','game-mode','dvr-off','prio-separation',
                'paging-exec','wer-off','transparency-off','mpo-off','net-throttling-off',
                'sys-responsiveness','mmcss-games','fso-off','gpu-pref','game-priority',
                'pcie-check','vcredist-check','xmp-check')
    }
    [pscustomobject]@{
      Id = 'safe-only'; Name = '保守（只改当前用户）'; Builtin = $true
      Note = '只改当前用户设置，不碰系统全局，通常无需重启；受保护备份沿用软件启动时已确认的管理员会话，不会再次弹窗。适合不想改系统全局设置的人。'
      Items = @('game-mode','dvr-off','wer-off','transparency-off','fso-off','gpu-pref','windowed-opt-off')
    }
  )
}

function Get-ProfileDir {
  Initialize-UserDataStore
  $script:ProfileDir
}

function Get-UserPresets {
  $d = Get-ProfileDir
  @(Get-ChildItem $d -Filter '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $j = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
      [pscustomobject]@{
        Id = $_.BaseName; Name = $j.Name; Builtin = $false
        Note = "自存方案，$($j.Items.Count) 项，保存于 $($j.Saved)"
        Items = @($j.Items); File = $_.FullName
      }
    } catch { $null }
  } | Where-Object { $_ })
}

function Get-Presets { @(Get-BuiltinPresets) + @(Get-UserPresets) }

function Assert-UserPresetWriteContext {
  $dir = Get-ProfileDir
  if (Test-Admin) {
    $expectedRoot = [IO.Path]::GetFullPath((Get-ProtectedUserStateRoot $script:TargetUserSid)).TrimEnd('\')
    $expected = [IO.Path]::GetFullPath((Join-Path $expectedRoot 'profiles')).TrimEnd('\')
    if ([IO.Path]::GetFullPath($dir).TrimEnd('\') -ine $expected -or
        (Test-PathHasReparsePoint $dir) -or -not (Test-ProtectedDirectoryAclExact $dir $false)) {
      throw '管理员进程只能在受保护 per-SID 方案目录中操作自存方案'
    }
  } else {
    $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $currentLocal = [IO.Path]::GetFullPath([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)).TrimEnd('\')
    if ($currentSid -ine $script:TargetUserSid -or $currentLocal -ine $script:TargetLocalAppData.TrimEnd('\')) {
      throw '普通权限进程只能操作当前用户自己的自存方案'
    }
  }
  $dir
}

# 文件名要能安全落盘，方案显示名另存字段，不受文件名清洗影响
function Save-UserPreset([string]$Name, [string[]]$ItemIds) {
  if (-not $Name) { throw '方案名不能为空' }
  $safe = ($Name -replace '[\\/:*?"<>|]', '_').Trim()
  if (-not $safe) { throw '方案名无效' }
  # Windows 保留设备名（含带扩展名形态）做文件名时写入「成功」但永远读不出也删不掉，
  # 必须在落盘前拒绝
  if ($safe -match '^(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') { throw "方案名不能使用 Windows 保留名（CON/PRN/AUX/NUL/COM1-9/LPT1-9）：$Name" }
  if (@(Get-BuiltinPresets | Where-Object { $_.Id -eq $safe -or $_.Name -eq $Name }).Count -gt 0) {
    throw "「$Name」与内置方案同名，请换一个名字"
  }
  $ids = @($ItemIds | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($ids.Count -eq 0) { throw '方案里至少要有一项' }
  $f = Join-Path (Assert-UserPresetWriteContext) "$safe.json"
  $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((@{ Name = $Name; Saved = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Items = $ids } | ConvertTo-Json -Depth 4))
  Write-BytesAtomic $f $bytes
  if (Test-Admin) {
    Set-ProtectedFileAcl $f
    if (-not (Test-ProtectedFileAcl $f)) { throw '自存方案文件 ACL 校验失败' }
  }
  $f
}

function Remove-UserPreset([string]$Id) {
  $profileDir = Assert-UserPresetWriteContext
  $p = @(Get-UserPresets | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
  if (-not $p) { throw "未找到自存方案：$Id" }
  $full = [IO.Path]::GetFullPath("$($p.File)")
  $prefix = [IO.Path]::GetFullPath($profileDir).TrimEnd('\') + '\'
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or (Test-PathHasReparsePoint $full)) {
    throw '自存方案路径越界或包含重解析点'
  }
  if ((Test-Admin) -and -not (Test-ProtectedFileAcl $full)) { throw '自存方案文件 ACL 不安全' }
  Remove-Item -LiteralPath $full -Force
  $p.Name
}

# 方案里的项 id 与本机实际可用项取交集，避免引用到不存在的项
function Resolve-PresetItems([string]$PresetId, [string]$GamePath) {
  $p = @(Get-Presets | Where-Object { $_.Id -eq $PresetId }) | Select-Object -First 1
  if (-not $p) { throw "未找到方案：$PresetId（用 -ListPresets 查看）" }
  $avail = @(Get-OptItems $GamePath | ForEach-Object { $_.Id })
  @($p.Items | Where-Object { $avail -contains $_ })
}

# ---------- 状态读取 ----------

function Get-OpState($Op, $ItemId) {
  switch ($Op.Kind) {
    'reg' {
      $v = Get-RegValue $Op.Path $Op.Name
      $label = $(if ($Op.Label) { $Op.Label } else { $Op.Name })
      $ok = $false
      if ($ItemId -eq 'fso-off') {
        # 兼容性标志可能已带有其他 flag（如 RUNASADMIN），只看目标 flag 是否在
        $ok = ($v -is [string] -and $v -match 'DISABLEDXMAXIMIZEDWINDOWEDMODE')
      } else { $ok = ("$v" -eq "$($Op.Value)") }
      # 二进制值（如中断掩码）按十六进制显示，直接拼字节数组没法读
      $vText = $(if ($null -eq $v) { '(未设置)' }
                 elseif ($v -is [byte[]]) { '0x' + ((@($v)[($v.Length - 1)..0] | ForEach-Object { $_.ToString('X2') }) -join '') }
                 else { "$v" })
      return @{ Ok = $ok; Text = "$label=$vText" }
    }
    'hib' {
      $on = Get-HibernateState
      return @{ Ok = (-not $on); Text = "$($Op.Label)=$(if ($on) { '开启' } else { '已关闭' })" }
    }
    'bcd' {
      $cur = Get-BcdValue $Op.Name
      if ($null -eq $cur) { return @{ Ok = $false; Text = "$($Op.Label)=读取失败（需管理员）" } }
      return @{ Ok = ($cur -ieq $Op.Value)
                Text = "$($Op.Label)=$(if ($cur -eq 'absent') { '未设置(系统默认)' } else { $cur })" }
    }
    'pcfg' {
      if (-not (Test-PowerSetting $Op.Sub $Op.Setting)) {
        # 该电源项在本机 CPU 上不存在：可选项算通过，必需项算未优化
        return @{ Ok = [bool]$Op.Optional; Text = "$($Op.Label)=本机不支持此项" }
      }
      $v = Get-PowerSettingAc $Op.Sub $Op.Setting
      # 读不到值 ≠ 读取失败：方案没写显式值、默认表里又没有该方案 GUID 时就是这样，
      # 语义上是「继承默认」，照实说，别吓唬用户
      if ($null -eq $v) { return @{ Ok = $false; Text = "$($Op.Label)=未显式设置（继承系统默认）" } }
      return @{ Ok = ($v -eq $Op.Value); Text = "$($Op.Label)（当前 $v）" }
    }
    'mmagent' {
      $on = Get-MMAgentState $Op.Feature
      if ($null -eq $on) { return @{ Ok = $false; Text = "$($Op.Label)=读取失败" } }
      return @{ Ok = (-not $on); Text = "$($Op.Label)=$(if ($on) { '开启' } else { '已关闭' })" }
    }
    'kvstr' {
      $cur = Get-KvStringItem (Get-RegValue $Op.Path $Op.Name) $Op.Key
      $shown = $(if ($null -eq $cur) { '(未设置)' } else { $cur })
      return @{ Ok = ("$cur" -eq "$($Op.Value)"); Text = "$($Op.Label)=$shown" }
    }
    'file' {
      # 外部程序的配置文件（如 NVIDIA App）：Verify 命中即已优化，Match 命中即待优化，
      # 两者都不命中说明文件结构变了——如实报「未找到」，绝不瞎猜默认值
      if (-not (Test-Path -LiteralPath $Op.Path)) { return @{ Ok = $false; Text = "$($Op.Label)=文件不存在" } }
      $txt = [IO.File]::ReadAllText($Op.Path)
      if ($txt -match $Op.Verify) { return @{ Ok = $true; Text = "$($Op.Label)=已关闭" } }
      if ($txt -match $Op.Match)  { return @{ Ok = $false; Text = "$($Op.Label)=开启中" } }
      return @{ Ok = $false; Text = "$($Op.Label)=未找到该设置（配置结构可能已变化）" }
    }
    default { return @{ Ok = $false; Text = '未知操作' } }
  }
}

function Get-ItemState($Item) {
  if ($Item.Kind -eq 'power') {
    $act = Get-ActiveScheme
    # 判定不能只靠显示名：工具自建的方案挂的是专属名，按 GUID（原生卓越/工具自建）优先，
    # 名字匹配只作兜底——否则改名后会「明明成功了却永远显示待优化」
    $toolGuid = Get-ToolSchemeGuid
    return @{ Optimized = [bool]($act -and ($act.Guid -eq $script:UltimateGuid -or
                                            ($toolGuid -and $act.Guid -eq $toolGuid) -or
                                            $act.Name -match '卓越|Ultimate'))
              Current   = $(if ($act) { $act.Name } else { '未知' }) }
  }
  if ($Item.Kind -eq 'sched') {
    $ex = Test-LockTaskExists
    return @{ Optimized = $ex; Current = $(if ($ex) { '锁定任务已建立' } else { '未锁定' }) }
  }
  if ($Item.Kind -eq 'npi') { return @{ Optimized = $null; Current = '无法读取驱动内状态' } }
  if ($Item.Kind -eq 'check') {
    $st = & $Item.Check
    return @{ Optimized = $st.Ok; Current = $st.Text }
  }
  # 清理类项目没有「已优化/待优化」之分：缓存清完就会重新长回来，Optimized 恒为未知。
  # 给出当前占用量，让用户自己判断这一项现在值不值得跑
  if ($Item.Kind -eq 'cache') {
    $mb = [math]::Round((Get-ShaderCacheSize) / 1MB, 1)
    return @{ Optimized = $null
              Current = $(if ($mb -le 0) { '当前无缓存可清理' } else { "当前着色器缓存约 ${mb}MB，每次执行都会重新清理" }) }
  }
  if (-not $Item.Ops) {
    return @{ Optimized = $null
              Current = $(if ($Item.RequiresGame) { '需先提供游戏路径' } else { '本机不适用（见说明）' }) }
  }

  $all = $true; $cur = @()
  foreach ($op in $Item.Ops) {
    $st = Get-OpState $op $Item.Id
    $cur += $st.Text
    if (-not $st.Ok) { $all = $false }
  }
  @{ Optimized = $all; Current = ($cur -join '；') }
}

# ---------- 显卡驱动指引 ----------

# 只讲驱动层设置：游戏内那部分已有独立的「游戏内设置参考」页，重复写只会让人两头对不上
function Get-AmdGpuPerformanceClass([string]$GpuName) {
  if ("$GpuName" -notmatch '(?i)Radeon\s+RX\s*\d{4}') { return 'integrated-or-legacy' }
  if ("$GpuName" -match '(?i)RX\s*(?:68|69|78|79)\d{2}|RX\s*90[78]\d') { return 'high' }
  if ("$GpuName" -match '(?i)RX\s*(?:56|57|66|67|76|77)\d{2}|RX\s*90[56]\d') { return 'mid' }
  'entry'
}

function Get-AmdConfiguredGuideText($Hw, [string]$GpuName, [bool]$IsLaptop) {
  $class = Get-AmdGpuPerformanceClass $GpuName
  $width = $(if ($Hw -and $Hw.PSObject.Properties['DisplayWidth'] -and $Hw.DisplayWidth) { [int]$Hw.DisplayWidth } else { 0 })
  $height = $(if ($Hw -and $Hw.PSObject.Properties['DisplayHeight'] -and $Hw.DisplayHeight) { [int]$Hw.DisplayHeight } else { 0 })
  $refresh = $(if ($Hw -and $Hw.PSObject.Properties['DisplayRefreshHz'] -and $Hw.DisplayRefreshHz) { [int]$Hw.DisplayRefreshHz } else { 0 })
  $ram = $(if ($Hw -and $Hw.PSObject.Properties['RamGB'] -and $Hw.RamGB) { [double]$Hw.RamGB } else { 0 })
  $displayText = $(if ($width -gt 0 -and $height -gt 0) {
      "$width×$height$(if ($refresh -gt 0) { " @ ${refresh}Hz" } else { '' })"
    } else { '分辨率未检测到' })
  $deviceText = $(if ($IsLaptop) { '笔记本' } else { '台式机' })
  $ramText = $(if ($ram -gt 0) { "，内存 $ram GB" } else { '' })
  $lines = New-Object Collections.Generic.List[string]
  $lines.Add("检测依据：$GpuName · $deviceText · $displayText$ramText")
  $lines.Add('AMD Software → 游戏 → 三角洲行动：Anti-Lag = 开；Chill / Boost = 关；等待垂直刷新 = 关闭，除非应用程序指定；表面格式优化 = 开。')
  $lines.Add('三角洲已有游戏内超分辨率，优先用游戏内 AMD FSR 2「质量优先」；使用 FSR 时关闭 RSR，避免重复放大。')

  switch ($class) {
    'high' {
      if ($height -eq 0) {
        $lines.Add('定位：高性能 A 卡；当前未检测到屏幕分辨率，先保持原生分辨率。确认是 1080P 且有性能余量后，才把 VSR 2560×1440 作为可选清晰度方案。')
        $lines.Add('纹理过滤质量 = 标准；Radeon Image Sharpening = 20–40；RSR = 关；VSR = 默认关。')
      } elseif ($height -le 1080) {
        $lines.Add('定位：显卡性能余量较大、屏幕偏向 1080P；以原生分辨率为基准。想提高远处清晰度时，可单独试 VSR 2560×1440，帧率或 1% Low 明显下降就关闭。')
        $lines.Add('纹理过滤质量 = 标准；Radeon Image Sharpening = 30–40 起步；RSR = 关；VSR = 可选。')
      } else {
        $lines.Add('定位：中高分辨率高性能显卡；优先原生分辨率，不叠加 RSR/VSR。帧率不足时只开启游戏内 FSR 2「质量优先」。')
        $lines.Add('纹理过滤质量 = 标准；Radeon Image Sharpening = 关或 10–30；RSR / VSR = 关。')
      }
      $lines.Add('AFMF 2.1 = 竞技默认关；只在更看重观感流畅、基础帧率稳定时作为可选项测试。')
    }
    'mid' {
      $lines.Add('定位：主流 A 卡；优先稳定帧和清晰度平衡。原生帧率够用就保持原生，不够再开游戏内 FSR 2「质量优先」。')
      $lines.Add('纹理过滤质量 = 标准；Radeon Image Sharpening = 30–40；RSR / VSR = 关。')
      $lines.Add('RX 6000 系及更新型号可试 AFMF 2.1，但竞技模式仍默认关闭；启用时按 AMD 要求同时关闭驱动和游戏内垂直同步。')
    }
    default {
      $lines.Add('定位：入门、核显或较早型号；优先降低 GPU 压力，不建议用 VSR 提高渲染分辨率。')
      $lines.Add('纹理过滤质量 = 性能；Radeon Image Sharpening = 20–40；RSR / VSR / AFMF = 关。帧率不足时使用游戏内 FSR 2「质量优先」，仍不足再试「均衡」。')
    }
  }

  if ($IsLaptop) {
    $lines.Add('笔记本补充：插电并使用厂商性能模式；温度或功耗受限时先关闭 VSR/AFMF，不建议靠提高功耗上限硬撑。')
  }
  if ($refresh -ge 120) {
    $lines.Add("显示器补充：若屏幕支持 FreeSync 则开启，并把游戏帧率上限设为约 $([math]::Max(30, $refresh - 3)) FPS，避免长期顶到刷新率上限。")
  } elseif ($refresh -gt 0) {
    $lines.Add('显示器补充：若屏幕支持 FreeSync 则开启；不要为了显示更高的生成帧数而默认开启 AFMF。')
  }
  if ($ram -gt 0 -and $ram -lt 16) {
    $lines.Add('内存补充：当前内存少于 16 GB，卡顿可能来自内存压力；显卡面板设置对此帮助有限。')
  }
  $lines -join "`n"
}

function Get-GpuGuideText([string]$Vendor, [string]$GpuName, [bool]$IsLaptop, $Hw = $null) {
  switch ($Vendor) {
    'NVIDIA' { @(
      $(if ($IsLaptop) {
        "驱动选择：$GpuName 使用 NVIDIA GeForce Game Ready Driver（Notebook / DCH / WHQL）。玩游戏优先 Game Ready，不要下载同名桌面显卡驱动；可直接通过 NVIDIA App 更新。"
      } else {
        '驱动选择：玩游戏优先安装最新 NVIDIA GeForce Game Ready Driver（DCH / WHQL），可直接通过 NVIDIA App 更新。'
      })
      ''
      'NVIDIA 控制面板 → 管理 3D 设置 → 程序设置 → 添加「三角洲行动」：'
      '  1. 电源管理模式 = 最高性能优先'
      '  2. 低延迟模式 = 超高'
      '  3. 垂直同步 = 关（帧率上限改在游戏里设，略低于显示器刷新率）'
      '  4. 着色器缓存大小 = 无限制'
      '  5. 线程优化 = 开'
      '  6. 最大预渲染帧数 = 1'
      ''
      'NVIDIA App → 图形 → 三角洲行动：RTX 40/50 系可把 DLSS 模型预设选到 Preset K，'
      '其余型号保持默认。'
      ''
      '「自动优化」会覆写你调好的画质，请在 NVIDIA App 内手动关闭；本工具只做状态体检，不写它的配置文件。'
      '进阶：NVIDIA Profile Inspector 放进本工具 tools\ 目录后可一键导入驱动配置档。'
    ) -join "`n" }
    'AMD' { @(
      '【方案一：原推荐方案】'
      'AMD Software (Adrenalin) → 游戏 → 三角洲行动：'
      '  1. Radeon Anti-Lag = 开'
      '  2. Radeon Chill / Boost = 关'
      '  3. 等待垂直刷新 = 关闭，除非应用程序指定'
      '  4. 纹理过滤质量 = 性能'
      '  5. 表面格式优化 = 开'
      ''
      '【方案二：按本机配置推荐】'
      (Get-AmdConfiguredGuideText $Hw $GpuName $IsLaptop)
    ) -join "`n" }
    'Intel' { @(
      'Intel 显卡控制中心 → 游戏 → 三角洲行动：'
      '  1. 电源性能模式 = 最高性能'
      '  2. 垂直同步 = 关'
      '  3. 异常检测 = 关'
      ''
      '核显性能上限有限，先确认装的是最新 Intel 显卡驱动。'
    ) -join "`n" }
    default { '未识别到独立显卡，驱动层指引略过。' }
  }
}

# ---------- 动作 ----------

function Get-ObjectPropertyNames($Object) {
  if ($Object -is [Collections.IDictionary]) { @($Object.Keys | ForEach-Object { "$_" }) }
  else { @($Object.PSObject.Properties.Name) }
}

function Assert-ExactProperties($Object, [string[]]$Required, [string[]]$Optional, [string]$Label) {
  if ($null -eq $Object) { throw "$Label 不能为空" }
  $actual = @(Get-ObjectPropertyNames $Object)
  foreach ($n in $Required) { if ($actual -notcontains $n) { throw "$Label 缺少字段：$n" } }
  $allowed = @($Required) + @($Optional)
  $unknown = @($actual | Where-Object { $allowed -notcontains $_ })
  if ($unknown.Count -gt 0) { throw "$Label 包含未知字段：$($unknown -join '、')" }
}

# EngineHost 为每次 GUI 会话创建只允许 Administrators/SYSTEM 访问的临时目录。
# GUI 与短生命周期管理员引擎只通过该目录交换严格 JSON，避免把动态 PowerShell 代码
# 放进 -EncodedCommand，也不再依赖普通 Users 可读的全局 IPC 目录。
function Get-ValidatedEngineSessionRoot {
  $session = "$env:DFB_ENGINE_HOST_SESSION"
  if ($session -notmatch '^[0-9a-fA-F]{32}$') { throw '管理员引擎缺少有效的 EngineHost 会话标记' }
  if (-not $script:CommonAppData) { throw '系统未提供 ProgramData 目录' }
  $expected = [IO.Path]::GetFullPath((Join-Path $script:CommonAppData "DeltaForceBooster\session-temp\$session")).TrimEnd('\')
  $actual = $(if ($env:TEMP) { [IO.Path]::GetFullPath("$env:TEMP").TrimEnd('\') } else { '' })
  if (-not $actual -or $actual -ine $expected -or "$env:TMP" -ine $actual -or
      -not (Test-Path -LiteralPath $actual -PathType Container) -or
      (Test-PathHasReparsePoint $actual) -or -not (Test-ProtectedDirectoryAclExact $actual $false)) {
    throw '管理员引擎会话目录校验失败'
  }
  $actual
}

function Get-EngineRequestOptionalString($Value, [string]$Name, [int]$MaxLength = 32767) {
  if ($null -eq $Value) { return $null }
  if ($Value -isnot [string] -or $Value.Length -gt $MaxLength) { throw "管理员引擎请求字段无效：$Name" }
  "$Value"
}

function Get-EngineRequestItemIds($Value, [string]$Name) {
  if ($null -eq $Value -or $Value -isnot [Array]) { throw "管理员引擎请求字段必须是数组：$Name" }
  if ($Value.Count -gt 128) { throw "管理员引擎请求项目过多：$Name" }
  $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  foreach ($id in @($Value)) {
    if ($id -isnot [string] -or "$id" -notmatch '^[a-z0-9][a-z0-9-]{0,63}$') {
      throw "管理员引擎请求项目 ID 无效：$Name"
    }
    if (-not $seen.Add("$id")) { throw "管理员引擎请求包含重复项目：$id" }
    "$id"
  }
}

function Import-EngineActionRequest([string]$Path, [string]$ExpectedSessionRoot) {
  if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) { throw '管理员引擎请求文件不是绝对路径' }
  $sessionRoot = $(if ($ExpectedSessionRoot) {
      [IO.Path]::GetFullPath($ExpectedSessionRoot).TrimEnd('\')
    } else { Get-ValidatedEngineSessionRoot })
  if (-not (Test-Path -LiteralPath $sessionRoot -PathType Container) -or
      (Test-PathHasReparsePoint $sessionRoot) -or -not (Test-ProtectedDirectoryAclExact $sessionRoot $false)) {
    throw '管理员引擎请求目录不可信'
  }
  $full = [IO.Path]::GetFullPath($Path)
  if ((Split-Path -Parent $full).TrimEnd('\') -ine $sessionRoot -or
      (Split-Path -Leaf $full) -notmatch '^engine-request-([0-9a-fA-F-]{36})\.json$') {
    throw '管理员引擎请求文件不在当前会话目录'
  }
  $fileResultId = $Matches[1]
  $parsedFileResultId = [guid]::Empty
  if (-not [guid]::TryParseExact($fileResultId, 'D', [ref]$parsedFileResultId) -or
      -not (Test-Path -LiteralPath $full -PathType Leaf) -or (Test-PathHasReparsePoint $full) -or
      -not (Test-ProtectedFileAcl $full)) {
    throw '管理员引擎请求文件类型、名称或权限无效'
  }
  $fileInfo = Get-Item -LiteralPath $full -Force
  if ($fileInfo.Length -le 0 -or $fileInfo.Length -gt 65536) { throw '管理员引擎请求文件大小无效' }
  try { $document = Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { throw "管理员引擎请求 JSON 无效：$($_.Exception.Message)" }
  Assert-ExactProperties $document @(
    'SchemaVersion','ResultId','Action','ItemIds','GamePath','AllowRisky','GpuSpoofModel',
    'BackupFile','ListRestoreItems','RestoreItemIds','UserSid','UserLocalAppData','UserStateRoot'
  ) @() '管理员引擎请求'
  if (($document.SchemaVersion -isnot [int] -and $document.SchemaVersion -isnot [long]) -or
      [int]$document.SchemaVersion -ne 1) { throw '管理员引擎请求版本不受支持' }
  if ($document.ResultId -isnot [string]) { throw '管理员引擎请求 ResultId 无效' }
  $parsedResultId = [guid]::Empty
  if (-not [guid]::TryParseExact("$($document.ResultId)", 'D', [ref]$parsedResultId) -or
      $parsedResultId -ne $parsedFileResultId) { throw '管理员引擎请求 ResultId 与文件名不匹配' }
  $resultId = $parsedResultId.ToString('D')
  if ($document.Action -isnot [string] -or "$($document.Action)" -notin @('Apply','Restore')) {
    throw '管理员引擎请求动作无效'
  }
  if ($document.AllowRisky -isnot [bool] -or $document.ListRestoreItems -isnot [bool]) {
    throw '管理员引擎请求布尔字段无效'
  }
  $itemIds = @(Get-EngineRequestItemIds $document.ItemIds 'ItemIds')
  $restoreItemIds = @(Get-EngineRequestItemIds $document.RestoreItemIds 'RestoreItemIds')
  $gamePath = Get-EngineRequestOptionalString $document.GamePath 'GamePath'
  $gpuSpoofModel = Get-EngineRequestOptionalString $document.GpuSpoofModel 'GpuSpoofModel' 128
  $backupFile = Get-EngineRequestOptionalString $document.BackupFile 'BackupFile'
  $userSid = Get-EngineRequestOptionalString $document.UserSid 'UserSid' 184
  $userLocalAppData = Get-EngineRequestOptionalString $document.UserLocalAppData 'UserLocalAppData'
  $userStateRoot = Get-EngineRequestOptionalString $document.UserStateRoot 'UserStateRoot'
  if (-not $userSid -or -not $userLocalAppData -or -not $userStateRoot) {
    throw '管理员引擎请求缺少目标用户上下文'
  }
  try { $sid = New-Object Security.Principal.SecurityIdentifier($userSid) }
  catch { throw '管理员引擎请求用户 SID 无效' }
  if (-not $sid.IsAccountSid() -or -not [IO.Path]::IsPathRooted($userLocalAppData) -or
      -not [IO.Path]::IsPathRooted($userStateRoot)) { throw '管理员引擎请求用户上下文无效' }
  $supportedSpoofModels = @('NVIDIA GeForce GTX 750 Ti','NVIDIA GeForce GTX 1050 Ti',
    'NVIDIA GeForce RTX 2050','NVIDIA GeForce RTX 2060','AMD Radeon RX560')
  if ($gpuSpoofModel -and $gpuSpoofModel -notin $supportedSpoofModels) { throw '管理员引擎请求显卡伪装型号无效' }

  if ("$($document.Action)" -eq 'Apply') {
    if ($itemIds.Count -eq 0 -or $document.ListRestoreItems -or $restoreItemIds.Count -gt 0 -or $backupFile) {
      throw '管理员引擎 Apply 请求参数组合无效'
    }
  } else {
    if ($itemIds.Count -gt 0 -or $gamePath -or $document.AllowRisky -or $gpuSpoofModel) {
      throw '管理员引擎 Restore 请求包含 Apply 参数'
    }
    $restoreModeCount = [int][bool]$document.ListRestoreItems + [int][bool]($restoreItemIds.Count -gt 0) + [int][bool]$backupFile
    if ($restoreModeCount -gt 1) { throw '管理员引擎 Restore 请求参数组合无效' }
  }
  [pscustomobject]@{
    ResultId = $resultId; Action = "$($document.Action)"; ItemIds = [string[]]$itemIds
    GamePath = $gamePath; AllowRisky = [bool]$document.AllowRisky; GpuSpoofModel = $gpuSpoofModel
    BackupFile = $backupFile; ListRestoreItems = [bool]$document.ListRestoreItems
    RestoreItemIds = [string[]]$restoreItemIds; UserSid = $userSid
    UserLocalAppData = [IO.Path]::GetFullPath($userLocalAppData)
    UserStateRoot = [IO.Path]::GetFullPath($userStateRoot); SessionRoot = $sessionRoot
    ResultFile = Join-Path $sessionRoot ("engine-result-$resultId.json")
  }
}

function Get-BackupOpFields([string]$Kind, [int]$SchemaVersion) {
  $base = @(switch ($SchemaVersion) {
    3 { 'Id','Status','ApplyId','ItemId','RestoreGroupId','OpIndex','Kind' }
    2 { 'Id','Status','Kind' }
    default { 'Kind' }
  })
  switch ($Kind) {
    'reg'     { $base + @('Path','Name','Existed','OldValue','OldKind') + $(if ($SchemaVersion -eq 3) { @('AppliedValue','AppliedKind') } else { @() }) }
    'pcfg'    { $base + @('Sub','Setting','Label','Existed','OldValue','SchemeGuid') }
    'mmagent' { $base + @('Feature','OldEnabled') }
    'sched'   { $base + @('TaskName') }
    'hib'     { $base + @('OldEnabled') }
    'bcd'     { $base + @('Name','OldValue') }
    'file'    { $base + @('Path','OrigB64') }
    'power'   { $base + @('Old','ToolCreated','NewGuid') }
    default   { throw "未知备份类型：$Kind" }
  }
}

function Test-AllowedGameExe([string]$Path) {
  if (-not [IO.Path]::IsPathRooted($Path)) { return $false }
  try { $leaf = [IO.Path]::GetFileName([IO.Path]::GetFullPath($Path)) } catch { return $false }
  $leaf -iin @('DeltaForceClient-Win64-Shipping.exe','DeltaForce.exe')
}

function Test-AllowedBackupRegTarget($Op) {
  $path = "$($Op.Path)"; $name = "$($Op.Name)"
  # 游戏路径是注册表“值名”，仅允许本项目识别的两个真实游戏进程名。
  if ($path -ieq 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' -or
      $path -ieq 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences') {
    if (Test-AllowedGameExe $name) { return $true }
  }
  if ($path -match '^HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\(DeltaForceClient-Win64-Shipping|DeltaForce)\.exe\\PerfOptions$' -and
      $name -iin @('CpuPriorityClass','IoPriority')) { return $true }
  if ($path -match '^HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Class\\\{4d36e968-e325-11ce-bfc1-08002be10318\}\\\d{4}$' -and
      $name -ieq 'DisableDynamicPstate') { return $true }
  if ($path -match '^HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\PCI\\VEN_(10DE|1002)&[^\\]+\\[^\\]+\\Device Parameters\\Interrupt Management\\Affinity Policy$' -and
      $name -iin @('DevicePolicy','AssignmentSetOverride')) { return $true }
  if ($path -match '^HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\PCI\\VEN_(10DE|1002)&[^\\]+\\[^\\]+$' -and $name -ieq 'DeviceDesc') { return $true }
  if ($name -ieq 'Attributes') {
    $allowedPowerPaths = @(
      "$script:PsRoot\$script:SubUsb\d4e98f31-5ffe-4ce1-be31-1b38b384c009",
      "$script:PsRoot\$script:SubProc\4d2b0152-7d5c-498b-88e2-34345392a2c5",
      "$script:PsRoot\$script:SubProc\93b8b6dc-0698-4d1c-9ee4-0644e900c85d",
      "$script:PsRoot\$script:SubProc\bae08b81-2d5e-4688-ad6a-13243356654b"
    )
    if ($allowedPowerPaths -icontains $path) { return $true }
  }

  $fixed = @(
    'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling|PowerThrottlingOff',
    'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers|HwSchMode',
    'HKCU:\Software\Microsoft\GameBar|AutoGameModeEnabled','HKCU:\Software\Microsoft\GameBar|AllowAutoGameMode',
    'HKCU:\System\GameConfigStore|GameDVR_Enabled','HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR|AppCaptureEnabled',
    'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl|Win32PrioritySeparation',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management|DisablePagingExecutive',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management|PagingFiles',
    'HKCU:\Software\Microsoft\Windows\Windows Error Reporting|Disabled',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize|EnableTransparency',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects|VisualFXSetting',
    'HKCU:\Control Panel\Mouse|MouseSpeed','HKCU:\Control Panel\Mouse|MouseThreshold1','HKCU:\Control Panel\Mouse|MouseThreshold2',
    'HKLM:\SOFTWARE\Microsoft\Windows\Dwm|OverlayTestMode',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile|NetworkThrottlingIndex',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile|SystemResponsiveness',
    'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain|Start','HKLM:\SYSTEM\CurrentControlSet\Services\WSearch|Start',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games|GPU Priority',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games|Priority',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games|Scheduling Category',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games|SFIO Priority',
    'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences|DirectXUserGlobalSettings'
  )
  $fixed -icontains ($path + '|' + $name)
}

function Test-JsonInteger($Value, [long]$Min, [decimal]$Max) {
  if ($Value -isnot [sbyte] -and $Value -isnot [byte] -and $Value -isnot [int16] -and $Value -isnot [uint16] -and
      $Value -isnot [int32] -and $Value -isnot [uint32] -and $Value -isnot [int64] -and $Value -isnot [uint64]) { return $false }
  try { ([decimal]$Value -ge [decimal]$Min) -and ([decimal]$Value -le $Max) } catch { $false }
}

function Assert-BackupRegValue($Op) {
  if ($Op.Existed -isnot [bool]) { throw '备份注册表 Existed 必须是布尔值' }
  if (-not $Op.Existed) {
    if ($null -ne $Op.OldValue -or "$($Op.OldKind)") { throw '原本不存在的注册表值不得携带旧内容' }
    return
  }
  $kind = "$($Op.OldKind)"
  switch ($kind) {
    'String'       { if ($Op.OldValue -isnot [string] -or $Op.OldValue.Length -gt 4096) { throw '备份注册表字符串值无效' } }
    'ExpandString' { if ($Op.OldValue -isnot [string] -or $Op.OldValue.Length -gt 4096) { throw '备份注册表可展开字符串值无效' } }
    'DWord'        { if (-not (Test-JsonInteger $Op.OldValue ([int32]::MinValue) ([uint32]::MaxValue))) { throw '备份注册表 DWord 值无效' } }
    'QWord'        { if (-not (Test-JsonInteger $Op.OldValue ([int64]::MinValue) ([decimal][uint64]::MaxValue))) { throw '备份注册表 QWord 值无效' } }
    'Binary' {
      $values = @($Op.OldValue)
      if ($values.Count -gt 64 -or @($values | Where-Object { -not (Test-JsonInteger $_ 0 255) }).Count -gt 0) { throw '备份注册表二进制值无效' }
    }
    'MultiString' {
      $values = @($Op.OldValue)
      if ($values.Count -gt 32 -or @($values | Where-Object { $_ -isnot [string] -or $_.Length -gt 4096 }).Count -gt 0) { throw '备份注册表多字符串值无效' }
    }
    default { throw "注册表值类型无效：$kind" }
  }

  $path = "$($Op.Path)"; $name = "$($Op.Name)"
  if ($name -ieq 'PagingFiles') {
    foreach ($entry in @($Op.OldValue)) {
      if ($entry -notmatch '^(?:[A-Za-z]|\?):\\pagefile\.sys\s+\d+\s+\d+$') { throw '备份页面文件值不在安全格式白名单' }
    }
  }
  if ($name -ieq 'AssignmentSetOverride' -and @($Op.OldValue).Count -gt 32) { throw '备份中断亲和性掩码过长' }
  if ($name -ieq 'DevicePolicy' -and ([decimal]$Op.OldValue -lt 0 -or [decimal]$Op.OldValue -gt 5)) { throw '备份中断策略值超出白名单' }
  if ($name -ieq 'DeviceDesc' -and $Op.OldValue.Length -gt 512) { throw '备份显卡描述过长' }
  if ($name -ieq 'Start' -and ([decimal]$Op.OldValue -lt 0 -or [decimal]$Op.OldValue -gt 4)) { throw '备份服务启动类型超出白名单' }
  if ($path -like '*\Multimedia\SystemProfile\Tasks\Games') {
    if ($name -ieq 'GPU Priority' -and ([decimal]$Op.OldValue -lt 0 -or [decimal]$Op.OldValue -gt 31)) { throw '备份 GPU Priority 超出白名单' }
    if ($name -ieq 'Priority' -and ([decimal]$Op.OldValue -lt 1 -or [decimal]$Op.OldValue -gt 8)) { throw '备份 MMCSS Priority 超出白名单' }
    if ($name -ieq 'Scheduling Category' -and "$($Op.OldValue)" -notin @('High','Medium','Low')) { throw '备份 Scheduling Category 超出白名单' }
    if ($name -ieq 'SFIO Priority' -and "$($Op.OldValue)" -notin @('High','Normal','Low')) { throw '备份 SFIO Priority 超出白名单' }
  }
}

function Assert-BackupOperation($Op, [int]$SchemaVersion, [string]$AllowedLocalAppData) {
  if (-not $AllowedLocalAppData) { $AllowedLocalAppData = $script:TargetLocalAppData }
  $kind = "$($Op.Kind)"
  $fields = @(Get-BackupOpFields $kind $SchemaVersion)
  Assert-ExactProperties $Op $fields @() "备份操作($kind)"
  if ($kind -eq 'file') {
    # 旧版曾备份 NVIDIA App 的用户配置文件。提权还原任何用户可写路径都存在
    # 目录换成 junction 的竞态窗口；该优化项已改为纯检测，因此新旧 schema 都关闭拒绝文件操作。
    throw '备份中的用户配置文件操作已停用，请在 NVIDIA App 内手动确认该设置'
  }
  if ($SchemaVersion -ge 2) {
    $id = [guid]::Empty
    if (-not [guid]::TryParseExact("$($Op.Id)", 'D', [ref]$id)) { throw "备份操作 Id 无效：$($Op.Id)" }
    if ("$($Op.Status)" -notin @('prepared','applied')) { throw "备份操作状态无效：$($Op.Status)" }
  }
  if ($SchemaVersion -eq 3) {
    $applyId = [guid]::Empty
    if (-not [guid]::TryParseExact("$($Op.ApplyId)", 'D', [ref]$applyId)) { throw "备份操作 ApplyId 无效：$($Op.ApplyId)" }
    foreach ($field in 'ItemId','RestoreGroupId') {
      if ("$($Op.$field)" -notmatch '^[a-z0-9][a-z0-9-]{0,63}$') { throw "备份操作 $field 无效：$($Op.$field)" }
    }
    if (-not (Test-JsonInteger $Op.OpIndex 0 255)) { throw "备份操作 OpIndex 无效：$($Op.OpIndex)" }
  }
  switch ($kind) {
    'reg' {
      if (-not (Test-AllowedBackupRegTarget $Op)) { throw "备份注册表目标不在白名单：$($Op.Path)|$($Op.Name)" }
      if ("$($Op.OldKind)" -notin @('','String','ExpandString','Binary','DWord','MultiString','QWord')) { throw "注册表值类型无效：$($Op.OldKind)" }
      Assert-BackupRegValue $Op
      if ($SchemaVersion -eq 3) {
        if ("$($Op.AppliedKind)" -notin @('String','ExpandString','Binary','DWord','MultiString','QWord')) { throw "注册表应用值类型无效：$($Op.AppliedKind)" }
        $applied = [pscustomobject]@{
          Path = "$($Op.Path)"; Name = "$($Op.Name)"; Existed = $true
          OldValue = $Op.AppliedValue; OldKind = "$($Op.AppliedKind)"
        }
        Assert-BackupRegValue $applied
      }
    }
    'pcfg' {
      $valid = (($Op.Sub -ieq $script:SubUsb -and $Op.Setting -ieq 'd4e98f31-5ffe-4ce1-be31-1b38b384c009') -or
                ($Op.Sub -ieq $script:SubProc -and $Op.Setting -iin @('4d2b0152-7d5c-498b-88e2-34345392a2c5','93b8b6dc-0698-4d1c-9ee4-0644e900c85d','bae08b81-2d5e-4688-ad6a-13243356654b')))
      $g = [guid]::Empty
      if (-not $valid -or -not [guid]::TryParse("$($Op.SchemeGuid)", [ref]$g)) { throw '备份电源项目标不在白名单' }
      $badOld = $(if ($Op.Existed -is [bool] -and $Op.Existed) { -not (Test-JsonInteger $Op.OldValue ([int32]::MinValue) ([uint32]::MaxValue)) } else { $null -ne $Op.OldValue })
      if ($Op.Existed -isnot [bool] -or $badOld -or ("$($Op.Label)").Length -gt 256) { throw '备份电源项旧值无效' }
    }
    'mmagent' { if ("$($Op.Feature)" -notin @('mc','pc') -or $Op.OldEnabled -isnot [bool]) { throw '备份内存管理目标或旧值不在白名单' } }
    'sched' {
      if ("$($Op.TaskName)" -ne $script:LockTaskPrefix -and "$($Op.TaskName)" -notmatch ('^' + [regex]::Escape($script:LockTaskPrefix) + '-[0-9A-Fa-f]{12}$')) {
        throw '备份计划任务目标不在白名单'
      }
    }
    'hib' { if ($Op.OldEnabled -isnot [bool]) { throw '备份休眠状态无效' } }
    'bcd' {
      if ("$($Op.Name)" -ne 'disabledynamictick' -or "$($Op.OldValue)" -notin @('absent','Yes','No','yes','no')) { throw '备份 BCD 目标或旧值不在白名单' }
    }
    'power' {
      $a = [guid]::Empty; $b = [guid]::Empty
      if ($Op.Old -and -not [guid]::TryParse("$($Op.Old)", [ref]$a)) { throw '原电源计划 GUID 无效' }
      if ($Op.NewGuid -and -not [guid]::TryParse("$($Op.NewGuid)", [ref]$b)) { throw '新电源计划 GUID 无效' }
      if ($Op.ToolCreated -isnot [bool]) { throw '备份电源计划 ToolCreated 必须是布尔值' }
    }
  }
}

function ConvertTo-CanonicalBackupOp($Op, [int]$SchemaVersion) {
  $ordered = [ordered]@{}
  foreach ($n in @(Get-BackupOpFields "$($Op.Kind)" $SchemaVersion)) { $ordered[$n] = $Op.$n }
  [pscustomobject]$ordered
}

function ConvertTo-CanonicalBackupItem($Item) {
  [pscustomobject][ordered]@{
    ItemId = "$($Item.ItemId)"
    RestoreGroupId = "$($Item.RestoreGroupId)"
    DisplayName = "$($Item.DisplayName)"
    DefinitionHash = "$($Item.DefinitionHash)"
    RebootRequired = [bool]$Item.RebootRequired
    OpIds = @($Item.OpIds | ForEach-Object { "$_" })
  }
}

function Get-BackupCanonicalPayload($Document) {
  $schema = [int]$Document.SchemaVersion
  # PowerShell 7 的 ConvertFrom-Json 会把 ISO-8601 时间自动转成 DateTime；若直接插值，
  # HMAC 复验会受当前区域格式影响。统一还原成 UTC round-trip 格式，兼容 5.1/7。
  $createdUtc = $(if ($Document.CreatedUtc -is [DateTime]) {
    $Document.CreatedUtc.ToUniversalTime().ToString('o')
  } else { "$($Document.CreatedUtc)" })
  if ($schema -eq 3) {
    $payload = [ordered]@{
      SchemaVersion = $schema
      BackupId = "$($Document.BackupId)"
      ApplyId = "$($Document.ApplyId)"
      AppVersion = "$($Document.AppVersion)"
      CatalogVersion = [int]$Document.CatalogVersion
      CreatedUtc = $createdUtc
      UserSid = "$($Document.UserSid)"
      UserLocalAppData = "$($Document.UserLocalAppData)"
      State = "$($Document.State)"
      Items = @($Document.Items | ForEach-Object { ConvertTo-CanonicalBackupItem $_ })
      Ops = @($Document.Ops | ForEach-Object { ConvertTo-CanonicalBackupOp $_ 3 })
    }
  } else {
    $payload = [ordered]@{
      SchemaVersion = $schema
      BackupId = "$($Document.BackupId)"
      CreatedUtc = $createdUtc
      UserSid = "$($Document.UserSid)"
      UserLocalAppData = "$($Document.UserLocalAppData)"
      State = "$($Document.State)"
      Ops = @($Document.Ops | ForEach-Object { ConvertTo-CanonicalBackupOp $_ 2 })
    }
  }
  $payload | ConvertTo-Json -Depth 10 -Compress
}

function Get-HmacHex([string]$Text, [byte[]]$Key) {
  $h = New-Object Security.Cryptography.HMACSHA256(,$Key)
  try { ([BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))) -replace '-', '').ToLowerInvariant() }
  finally { $h.Dispose() }
}

function Test-FixedTimeEqual([byte[]]$A, [byte[]]$B) {
  if ($A.Length -ne $B.Length) { return $false }
  $diff = 0
  for ($i = 0; $i -lt $A.Length; $i++) { $diff = $diff -bor ($A[$i] -bxor $B[$i]) }
  $diff -eq 0
}

function Set-BackupIntegrity($Document) {
  $value = Get-HmacHex (Get-BackupCanonicalPayload $Document) (Get-BackupHmacKey)
  $Document.Integrity = [pscustomobject][ordered]@{ Algorithm = 'HMAC-SHA256'; Value = $value }
}

function Write-BackupDocumentAtomic([string]$Path, $Document) {
  Set-BackupIntegrity $Document
  $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($Document | ConvertTo-Json -Depth 10))
  Write-BytesAtomic $Path $bytes
}

function Assert-BackupItem($Item) {
  Assert-ExactProperties $Item @('ItemId','RestoreGroupId','DisplayName','DefinitionHash','RebootRequired','OpIds') @() '备份项目'
  foreach ($field in 'ItemId','RestoreGroupId') {
    if ("$($Item.$field)" -notmatch '^[a-z0-9][a-z0-9-]{0,63}$') { throw "备份项目 $field 无效：$($Item.$field)" }
  }
  if (-not "$($Item.DisplayName)" -or "$($Item.DisplayName)".Length -gt 256) { throw '备份项目显示名称无效' }
  if ("$($Item.DefinitionHash)" -notmatch '^[0-9a-f]{64}$') { throw '备份项目定义哈希无效' }
  if ($Item.RebootRequired -isnot [bool]) { throw '备份项目 RebootRequired 必须是布尔值' }
  $opIds = @($Item.OpIds)
  if ($opIds.Count -eq 0 -or $opIds.Count -gt 256 -or @($opIds | Select-Object -Unique).Count -ne $opIds.Count) {
    throw '备份项目 OpIds 为空、重复或超过上限'
  }
  foreach ($opId in $opIds) {
    $parsed = [guid]::Empty
    if (-not [guid]::TryParseExact("$opId", 'D', [ref]$parsed)) { throw "备份项目操作 ID 无效：$opId" }
  }
}

function Assert-BackupDocument($Document, [bool]$RequireIntegrity) {
  if ($RequireIntegrity) {
    $schema = [int]$Document.SchemaVersion
    if ($schema -eq 3) {
      Assert-ExactProperties $Document @('SchemaVersion','BackupId','ApplyId','AppVersion','CatalogVersion','CreatedUtc','UserSid','UserLocalAppData','State','Items','Ops','Integrity') @() '备份文档'
    } elseif ($schema -eq 2) {
      Assert-ExactProperties $Document @('SchemaVersion','BackupId','CreatedUtc','UserSid','UserLocalAppData','State','Ops','Integrity') @() '备份文档'
    } else { throw "不支持的备份版本：$($Document.SchemaVersion)" }
    $id = [guid]::Empty; $when = [DateTime]::MinValue
    if (-not [guid]::TryParseExact("$($Document.BackupId)", 'D', [ref]$id)) { throw '备份 ID 无效' }
    if ($schema -eq 3) {
      $applyId = [guid]::Empty
      if (-not [guid]::TryParseExact("$($Document.ApplyId)", 'D', [ref]$applyId)) { throw '备份 ApplyId 无效' }
      if ("$($Document.AppVersion)" -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { throw '备份软件版本无效' }
      if (-not (Test-JsonInteger $Document.CatalogVersion 1 1000)) { throw '备份目录版本无效' }
    }
    if (-not [DateTime]::TryParse("$($Document.CreatedUtc)", [ref]$when)) { throw '备份时间无效' }
    try { [void](New-Object Security.Principal.SecurityIdentifier("$($Document.UserSid)")) } catch { throw '备份用户 SID 无效' }
    if (-not [IO.Path]::IsPathRooted("$($Document.UserLocalAppData)")) { throw '备份用户 LocalAppData 路径无效' }
    if ("$($Document.State)" -notin @('pending','complete')) { throw '备份状态无效' }
    Assert-ExactProperties $Document.Integrity @('Algorithm','Value') @() '备份完整性字段'
    if ($Document.Integrity.Algorithm -ne 'HMAC-SHA256' -or "$($Document.Integrity.Value)" -notmatch '^[0-9a-f]{64}$') { throw '备份完整性字段无效' }
  } else {
    Assert-ExactProperties $Document @('Time','Ops') @() '旧版备份文档'
    $legacyWhen = [DateTime]::MinValue
    if (-not [DateTime]::TryParse("$($Document.Time)", [ref]$legacyWhen)) { throw '旧版备份时间无效' }
  }
  $ops = @($Document.Ops)
  if ($ops.Count -gt 256) { throw '备份操作超过 256 项上限' }
  $schemaForOps = $(if ($RequireIntegrity) { [int]$Document.SchemaVersion } else { 1 })
  $allowedLocal = $(if ($RequireIntegrity) { "$($Document.UserLocalAppData)" } else { $script:TargetLocalAppData })
  foreach ($op in $ops) { Assert-BackupOperation $op $schemaForOps $allowedLocal }
  if ($RequireIntegrity -and $schemaForOps -eq 3) {
    $items = @($Document.Items)
    if ($items.Count -gt 64) { throw '备份项目超过 64 项上限' }
    foreach ($item in $items) { Assert-BackupItem $item }
    if (@($items | ForEach-Object ItemId | Select-Object -Unique).Count -ne $items.Count) { throw '备份项目 ItemId 重复' }
    $allOpIds = @($ops | ForEach-Object { "$($_.Id)" })
    if (@($allOpIds | Select-Object -Unique).Count -ne $allOpIds.Count) { throw '备份操作 Id 重复' }
    $mapped = @($items | ForEach-Object { @($_.OpIds) })
    if (@($mapped | Select-Object -Unique).Count -ne $mapped.Count -or $mapped.Count -ne $allOpIds.Count) { throw '备份项目与操作映射不完整或重复' }
    foreach ($op in $ops) {
      if ("$($op.ApplyId)" -ne "$($Document.ApplyId)") { throw '备份操作 ApplyId 与文档不一致' }
      $owner = @($items | Where-Object { "$($_.ItemId)" -eq "$($op.ItemId)" -and "$($_.RestoreGroupId)" -eq "$($op.RestoreGroupId)" -and @($_.OpIds) -contains "$($op.Id)" })
      if ($owner.Count -ne 1) { throw "备份操作缺少唯一项目归属：$($op.Id)" }
    }
  }
  if ($RequireIntegrity) {
    $expected = Get-HmacHex (Get-BackupCanonicalPayload $Document) (Get-BackupHmacKey)
    $actualBytes = [Text.Encoding]::ASCII.GetBytes("$($Document.Integrity.Value)")
    $expectBytes = [Text.Encoding]::ASCII.GetBytes($expected)
    if (-not (Test-FixedTimeEqual $actualBytes $expectBytes)) { throw '备份完整性校验失败，文件可能已被修改' }
  }
}

function Test-PathUnder([string]$Path, [string]$Root) {
  try {
    $full = [IO.Path]::GetFullPath($Path)
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $full.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)
  } catch { $false }
}

function Get-LegacyMigrationId([string]$Path, [string]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(([IO.Path]::GetFullPath($Path).ToUpperInvariant() + "`0" + $Raw))) }
  finally { $sha.Dispose() }
  $hex = ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
  '{0}-{1}-{2}-{3}-{4}' -f $hex.Substring(0,8),$hex.Substring(8,4),$hex.Substring(12,4),$hex.Substring(16,4),$hex.Substring(20,12)
}

function Read-ValidatedBackup([string]$Path, [string[]]$LegacyDirs) {
  $full = [IO.Path]::GetFullPath($Path)
  $isProtected = Test-PathUnder $full $script:BackupDir
  if ($null -eq $LegacyDirs) { $LegacyDirs = @(Get-LegacyBackupDirs) }
  $isLegacy = [bool](@($LegacyDirs | Where-Object { Test-PathUnder $full $_ }).Count -gt 0)
  if (-not $isProtected -and -not $isLegacy) { throw "备份文件不在受支持的备份目录：$full" }
  if (Test-PathHasReparsePoint $full) { throw "备份路径包含目录联接或符号链接：$full" }
  $fi = Get-Item -LiteralPath $full -ErrorAction Stop
  if ($fi.Length -gt 32MB) { throw '备份文件超过 32MB 上限' }
  $raw = [IO.File]::ReadAllText($full, [Text.Encoding]::UTF8)
  try { $doc = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw "备份 JSON 损坏：$($_.Exception.Message)" }
  $signed = [bool]$doc.PSObject.Properties['SchemaVersion']
  if ($signed) {
    if (-not $isProtected) { throw '带完整性签名的新备份必须位于受保护备份目录' }
    Assert-BackupDocument $doc $true
    return [pscustomobject]@{ Path = $full; Document = $doc; LegacySource = $null }
  }

  # 旧备份没有完整性签名：先做严格 schema/目标白名单校验，再复制为受保护且签名的新格式，
  # 后续只从内存中的已验证数据和受保护副本执行，不再信任可写的旧文件。
  Assert-BackupDocument $doc $false
  Initialize-ProtectedStore
  # 迁移文件名由“规范源路径 + 原始内容”确定：中断后重试不会重复制造备份。
  # 旧根由目标用户可写，提权进程绝不对其 Rename/Write（否则存在 junction 竞态）；
  # 已还原状态只由受保护目录内的 .restored 标记表示。
  $id = Get-LegacyMigrationId $full $raw
  $ops = @($doc.Ops | ForEach-Object {
    $h = [ordered]@{ Id = [guid]::NewGuid().ToString('D'); Status = 'applied'; Kind = "$($_.Kind)" }
    foreach ($n in @(Get-BackupOpFields "$($_.Kind)" 1 | Select-Object -Skip 1)) { $h[$n] = $_.$n }
    [pscustomobject]$h
  })
  $legacyWhen = [DateTime]::Parse("$($doc.Time)")
  $migrated = [pscustomobject][ordered]@{
    SchemaVersion = $script:LegacySignedBackupSchemaVersion; BackupId = $id
    CreatedUtc = $legacyWhen.ToUniversalTime().ToString('o')
    UserSid = $script:TargetUserSid; UserLocalAppData = $script:TargetLocalAppData
    State = $(if ($full -like '*.pending.json') { 'pending' } else { 'complete' })
    Ops = $ops; Integrity = $null
  }
  $dest = Join-Path $script:BackupDir ("backup-migrated-$id$(if ($migrated.State -eq 'pending') { '.pending' }).json")
  $restoredDest = $dest + '.restored'
  if (Test-Path -LiteralPath $restoredDest -PathType Leaf) {
    $consumed = Read-ValidatedBackup $restoredDest @()
    return [pscustomobject]@{ Path = $consumed.Path; Document = $consumed.Document; LegacySource = $full; Consumed = $true }
  }
  if (Test-Path -LiteralPath $dest -PathType Leaf) {
    $existing = Read-ValidatedBackup $dest @()
    return [pscustomobject]@{ Path = $existing.Path; Document = $existing.Document; LegacySource = $full; Consumed = $false }
  }
  Write-BackupDocumentAtomic $dest $migrated
  [pscustomobject]@{ Path = $dest; Document = $migrated; LegacySource = $full; Consumed = $false }
}

function New-BackupDocument([DateTime]$When, [string]$ApplyId) {
  if (-not $ApplyId) { $ApplyId = [guid]::NewGuid().ToString('D') }
  [pscustomobject][ordered]@{
    SchemaVersion = $script:BackupSchemaVersion
    BackupId = [guid]::NewGuid().ToString('D')
    ApplyId = $ApplyId
    AppVersion = $script:AppVersion
    CatalogVersion = $script:BackupCatalogVersion
    CreatedUtc = $When.ToUniversalTime().ToString('o')
    UserSid = $script:TargetUserSid
    UserLocalAppData = $script:TargetLocalAppData
    State = 'pending'; Items = @(); Ops = @(); Integrity = $null
  }
}

function Get-ItemDefinitionHash($Item) {
  $ops = @()
  foreach ($op in @($Item.Ops)) {
    # PowerShell 5.1 的 @($null) 会产生一个含 null 的单元素数组。power/sched 等项目
    # 没有 Ops 字段；若直接调用 $op.ContainsKey()，真实 Apply 会在写入第一条备份时抛
    # “不能对 Null 值表达式调用方法”，系统操作尚未执行但该项目会被误报为失败。
    if ($null -eq $op) { continue }
    if ($op -isnot [Collections.IDictionary]) { throw "优化项 $($Item.Id) 的操作定义格式无效" }
    $entry = [ordered]@{}
    foreach ($field in 'Kind','Path','Name','Sub','Setting','Feature','TaskName','Key','Value','Kind2') {
      if ($op.ContainsKey($field)) { $entry[$field] = $op[$field] }
    }
    $ops += [pscustomobject]$entry
  }
  $definition = [pscustomobject][ordered]@{
    ItemId = "$($Item.Id)"; Kind = "$($Item.Kind)"; RebootRequired = [bool]$Item.Reboot; Ops = $ops
  }
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($definition | ConvertTo-Json -Depth 8 -Compress)))
    ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function New-BackupItemRecord($Item) {
  [pscustomobject][ordered]@{
    ItemId = "$($Item.Id)"
    RestoreGroupId = "$($Item.Id)"
    DisplayName = "$($Item.Name)"
    DefinitionHash = Get-ItemDefinitionHash $Item
    RebootRequired = [bool]$Item.Reboot
    OpIds = @()
  }
}

function Get-SelectiveRestoreItemIds {
  # 只开放没有复杂依赖且底层目标可独立验证的项目。显卡型号伪装只有一个
  # 已完整记录原值的 DeviceDesc 注册表操作，也可安全地单独冲突检测与还原。
  @('game-mode','dvr-off','prio-separation','net-throttling-off','sys-responsiveness','mmcss-games','fso-off','gpu-pref','gpu-name-spoof')
}

function Sort-BackupRecordsNewestFirst($Records) {
  @($Records | Sort-Object @{ Expression = { [DateTime]::Parse($_.Document.CreatedUtc).ToUniversalTime() }; Descending = $true })
}

function Invoke-DetectReport([string]$GamePath) {
  $hw = Get-HardwareInfo
  if (-not $GamePath) { $GamePath = Find-GamePath }
  $items = Get-OptItems $GamePath
  $states = foreach ($it in $items) {
    $st = Get-ItemState $it
    [pscustomobject]@{
      Id = $it.Id; Name = $it.Name; Tier = $it.Tier; Admin = $it.Admin; Default = $it.Default
      Optimized = $st.Optimized; Current = $st.Current
      Note = $(if ($it.Warn) { $it.Warn } else { $it.Note })
    }
  }
  [pscustomobject]@{
    Hardware = $hw
    GamePath = $GamePath
    Items    = $states
    GpuGuide = Get-GpuGuideText $hw.MainGpuVendor $hw.MainGpuName $hw.IsLaptop $hw
  }
}

function Test-ValueEqual($A, $B) {
  if ($A -is [byte[]] -or $B -is [byte[]]) {
    $aa = [byte[]]@($A); $bb = [byte[]]@($B)
    return (Test-FixedTimeEqual $aa $bb)
  }
  if ($A -is [array] -or $B -is [array]) { return ((@($A) -join "`0") -ceq (@($B) -join "`0")) }
  "$A" -ceq "$B"
}

function Invoke-ApplyOp($Op, $ItemId, [scriptblock]$PrepareBackup, [scriptblock]$MarkApplied) {
  switch ($Op.Kind) {
    'reg' {
      $oldKind = Get-RegValueKind $Op.Path $Op.Name
      $oldVal  = $(if ($null -ne $oldKind) { Get-RegValue $Op.Path $Op.Name } else { $null })
      $newVal  = $Op.Value
      # 全屏优化标志采用合并写入，保留用户已有的其他兼容性 flag
      if ($ItemId -eq 'fso-off' -and $oldVal -is [string] -and $oldVal) {
        $newVal = $oldVal
        if ($newVal -notmatch 'DISABLEDXMAXIMIZEDWINDOWEDMODE') { $newVal = "$newVal DISABLEDXMAXIMIZEDWINDOWEDMODE" }
      }
      # 已达标就不写不备份：重复 Apply 时照旧备份会把上一轮写入的目标值记成「原值」，
      # 还原就回不到真正的优化前状态。值与类型都要相等（byte[]/string[] 经 "$()" 展开
      # 后两侧同构可直接比对）；fso-off 合并写入后 flag 已在则 newVal 与 oldVal 相同，天然覆盖
      if ($null -ne $oldKind -and "$oldKind" -eq "$($Op.Kind2)" -and "$oldVal" -eq "$newVal") {
        return "无需修改：$(if ($Op.Label) { $Op.Label } else { $Op.Name }) 已是目标状态"
      }
      $token = & $PrepareBackup @{ Kind = 'reg'; Path = $Op.Path; Name = $Op.Name
                                   Existed = ($null -ne $oldKind); OldValue = $oldVal; OldKind = "$oldKind"
                                   AppliedValue = $newVal; AppliedKind = "$($Op.Kind2)" }
      Set-RegValue $Op.Path $Op.Name $newVal $Op.Kind2
      $actualKind = Get-RegValueKind $Op.Path $Op.Name
      $actualValue = Get-RegValue $Op.Path $Op.Name
      if ("$actualKind" -ne "$($Op.Kind2)" -or -not (Test-ValueEqual $actualValue $newVal)) { throw '注册表写入后回读验证失败' }
      & $MarkApplied $token
    }
    'pcfg' {
      if (-not (Test-PowerSetting $Op.Sub $Op.Setting)) {
        if ($Op.Optional) { return "跳过（本机 CPU 无此电源项）：$($Op.Label)" }
        throw "本机不支持该电源项：$($Op.Label)"
      }
      $act = Get-ActiveScheme
      if (-not $act) { throw "无法确定当前活动电源方案：$($Op.Label)" }
      # 只看方案下的显式值：读不到不是错误，就是「继承默认」（duplicatescheme 出来的
      # 方案不在 DefaultPowerSchemeValues 表里，连回落值都没有）。当前值只服务于备份，
      # 备份记 Existed=$false 即可，绝不能因为读不到就拒绝写入
      $old = Get-PowerSettingAcExplicit $act.Guid $Op.Sub $Op.Setting
      # 已达标（显式值或继承的默认值已等于目标）就整段跳过——不解隐藏、不写入、不备份。
      # 否则重复 Apply 会把上一轮写入的目标值备份成「原值」；且游戏切走活动方案后本项
      # 会重新显示「待优化」，用户再点执行时也靠这道判断挡住污染
      $eff = Get-PowerSettingAc $Op.Sub $Op.Setting
      if ($null -ne $eff -and [int]$eff -eq [int]$Op.Value) { return "无需修改：$($Op.Label) 已是目标状态" }
      # 隐藏项必须先解除隐藏才能写入；原 Attributes 按普通注册表值备份，还原时自动改回
      $oldAttr = $(if (Test-PowerSettingHidden $Op.Sub $Op.Setting) { Get-RegValue "$script:PsRoot\$($Op.Sub)\$($Op.Setting)" 'Attributes' } else { $null })
      if ($null -ne $oldAttr) {
        $newAttr = ([int]$oldAttr -band (-bnot 1))
        $attrToken = & $PrepareBackup @{ Kind = 'reg'; Path = "$script:PsRoot\$($Op.Sub)\$($Op.Setting)"; Name = 'Attributes'
                                          Existed = $true; OldValue = $oldAttr; OldKind = 'DWord'
                                          AppliedValue = $newAttr; AppliedKind = 'DWord' }
        [void](Show-PowerSetting $Op.Sub $Op.Setting)
        & $MarkApplied $attrToken
      }
      $token = & $PrepareBackup @{ Kind = 'pcfg'; Sub = $Op.Sub; Setting = $Op.Setting; Label = $Op.Label
                                   Existed = ($null -ne $old); OldValue = $old; SchemeGuid = $act.Guid }
      Set-PowerSettingAc $Op.Sub $Op.Setting $Op.Value
      & $MarkApplied $token
    }
    'mmagent' {
      $old = Get-MMAgentState $Op.Feature
      if ($null -eq $old) { throw "无法读取 $($Op.Label) 当前状态" }
      # 已是关闭态就跳过：再备份会把「已被上一轮关掉」记成原状态，还原时开不回去
      if (-not $old) { return "无需修改：$($Op.Label) 已是目标状态" }
      $token = & $PrepareBackup @{ Kind = 'mmagent'; Feature = $Op.Feature; OldEnabled = $old }
      Set-MMAgentState $Op.Feature $false
      if ((Get-MMAgentState $Op.Feature) -ne $false) { throw '内存管理状态写入后回读验证失败' }
      & $MarkApplied $token
    }
    'kvstr' {
      # 整串备份、只改目标子键：这个值里还住着 AutoHDREnable 等别人的设置，整串覆盖会误伤
      $oldKind = Get-RegValueKind $Op.Path $Op.Name
      $oldRaw  = $(if ($null -ne $oldKind) { Get-RegValue $Op.Path $Op.Name } else { $null })
      # 只比目标子键：整串里其余键值是别人的设置，不影响本项是否已达标
      if ("$(Get-KvStringItem $oldRaw $Op.Key)" -eq "$($Op.Value)") { return "无需修改：$($Op.Label) 已是目标状态" }
      $newRaw = Set-KvStringItem $oldRaw $Op.Key $Op.Value
      $token = & $PrepareBackup @{ Kind = 'reg'; Path = $Op.Path; Name = $Op.Name
                                   Existed = ($null -ne $oldKind); OldValue = $oldRaw; OldKind = "$oldKind"
                                   AppliedValue = $newRaw; AppliedKind = 'String' }
      Set-RegValue $Op.Path $Op.Name $newRaw 'String'
      if ("$(Get-KvStringItem (Get-RegValue $Op.Path $Op.Name) $Op.Key)" -ne "$($Op.Value)") { throw '复合注册表值写入后回读验证失败' }
      & $MarkApplied $token
    }
    'hib' {
      $old = Get-HibernateState
      # 已关闭就跳过：再备份会把 OldEnabled 记成 $false，还原时休眠开不回去
      if (-not $old) { return "无需修改：$($Op.Label) 已是目标状态" }
      $token = & $PrepareBackup @{ Kind = 'hib'; OldEnabled = [bool]$old }
      Set-HibernateEnabled $false
      & $MarkApplied $token
    }
    'bcd' {
      $old = Get-BcdValue $Op.Name
      if ($null -eq $old) { throw "无法读取引导配置（需要管理员权限）：$($Op.Label)" }
      # 已达标就跳过（bcdedit 取值大小写不敏感）：避免把目标值当原值备份
      if ("$old" -ieq "$($Op.Value)") { return "无需修改：$($Op.Label) 已是目标状态" }
      # OldValue='absent' 表示原本未设置，还原时删除该值而不是写回字符串
      $token = & $PrepareBackup @{ Kind = 'bcd'; Name = $Op.Name; OldValue = $old }
      Set-BcdEntryValue $Op.Name $Op.Value
      & $MarkApplied $token
    }
    'file' {
      throw '用户配置文件自动写入已停用，请在对应程序内手动设置'
    }
    default { throw "未知操作类型：$($Op.Kind)" }
  }
  $null
}

function Set-ApplyResultChangeState($Result, [bool]$Changed) {
  $Result | Add-Member -NotePropertyName Changed -NotePropertyValue $Changed -Force
  if (-not $Changed -and $Result.Ok -and -not $Result.Attention) {
    $Result.Skipped = $true
    if ($Result.Msg -like '已写入*') { $Result.Msg = '无需修改：所有设置已是目标状态' }
  }
  $Result
}

# $Progress 为可选进度回调（不传时行为与旧版完全一致，CLI 与 SKILL.md 契约不受影响）：
# 每项开始时以 Stage='start' 调用一次（带 Index/Total/Name），完成时以 Stage='done'
# 再调一次（额外带该项的 Result），GUI 靠它做进度条与实时日志
function Invoke-Apply([string[]]$ItemIds, [string]$GamePath, [bool]$AllowRisky, [scriptblock]$Progress,
                      [string]$GpuSpoofModel) {
  $engineMutex = Enter-EngineMutex
  try {
  # powershell -File 不会把 "a,b" 解析成数组，整串会当成单个元素传进来，这里统一拆开
  $ItemIds = @($ItemIds | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if (-not $GamePath) { $GamePath = Find-GamePath }
  $items = Get-OptItems $GamePath $GpuSpoofModel
  # 不传 -Items 时只取 safe 档默认项：risky 永远不会被"一键默认"带上
  if (-not $ItemIds -or $ItemIds.Count -eq 0) {
    $ItemIds = @($items | Where-Object { $_.Default -and $_.Tier -eq 'safe' } | ForEach-Object { $_.Id })
  }
  $sel = @($items | Where-Object { $ItemIds -contains $_.Id })
  if ($sel.Count -eq 0) { throw "没有匹配的优化项，请用 -ListItems 查看可用 Id" }

  $riskySel = @($sel | Where-Object { $_.Tier -eq 'risky' })
  if ($riskySel.Count -gt 0 -and -not $AllowRisky) {
    throw "选中了高风险项，需要显式加 -Risky 确认：$(@($riskySel | ForEach-Object { $_.Name }) -join '、')"
  }

  $needAdmin = @($sel | Where-Object { $_.Admin })
  if ($needAdmin.Count -gt 0 -and -not (Test-Admin)) {
    throw "以下优化项需要管理员权限，请以管理员身份重新运行：$(@($needAdmin | ForEach-Object { $_.Name }) -join '、')"
  }
  $needsJournal = @($sel | Where-Object { $_.Kind -notin @('check','cache','npi') }).Count -gt 0
  if ($needsJournal -and -not (Test-Admin)) { throw '可还原修改需要一次 UAC，用于写入受保护的系统备份' }

  $results = @()

  # 严格写前日志：每条撤销记录先以 prepared 状态做 temp→Flush(true)→原子替换，
  # 系统写入并回读成功后再标 applied。GUID 文件名避免并发/同秒冲突，核心 mutex 负责串行化。
  $applyTime = Get-Date
  $applyId = [guid]::NewGuid().ToString('D')
  $journal = [pscustomobject]@{ Document = $null; Path = $null; Error = $null; CurrentItem = $null; CurrentOpIndex = 0 }
  if ($needsJournal) {
    try {
      Initialize-ProtectedStore
      $journal.Document = New-BackupDocument $applyTime $applyId
      $journal.Path = Join-Path $script:BackupDir ("backup-$($journal.Document.BackupId).pending.json")
      Write-BackupDocumentAtomic $journal.Path $journal.Document
    } catch {
      throw "备份目录不可写（$script:BackupDir），已中止执行，未做任何修改。请先解除目录占用（OneDrive 同步、只读属性、磁盘空间）再重试。原因：$($_.Exception.Message)"
    }
  } else {
    $journal.Document = [pscustomobject]@{ Ops = @() }
  }
  $prepareBackup = {
    param($Data)
    if ($journal.Error) { throw "备份写入已失败：$($journal.Error)" }
    if (-not $journal.CurrentItem) { throw '备份项目上下文缺失' }
    $opId = [guid]::NewGuid().ToString('D')
    $entry = [ordered]@{
      Id = $opId; Status = 'prepared'; ApplyId = "$($journal.Document.ApplyId)"
      ItemId = "$($journal.CurrentItem.Id)"; RestoreGroupId = "$($journal.CurrentItem.Id)"
      OpIndex = [int]$journal.CurrentOpIndex; Kind = "$($Data.Kind)"
    }
    foreach ($n in @(Get-BackupOpFields "$($Data.Kind)" 3)) {
      if (-not $entry.Contains($n)) { $entry[$n] = $Data[$n] }
    }
    $op = [pscustomobject]$entry
    Assert-BackupOperation $op 3
    $itemRecord = @($journal.Document.Items | Where-Object { "$($_.ItemId)" -eq "$($journal.CurrentItem.Id)" }) | Select-Object -First 1
    if (-not $itemRecord) {
      $itemRecord = New-BackupItemRecord $journal.CurrentItem
      $journal.Document.Items = @($journal.Document.Items) + @($itemRecord)
    }
    $itemRecord.OpIds = @($itemRecord.OpIds) + @($opId)
    $journal.Document.Ops = @($journal.Document.Ops) + @($op)
    $journal.CurrentOpIndex++
    try { Write-BackupDocumentAtomic $journal.Path $journal.Document }
    catch { $journal.Error = $_.Exception.Message; throw "备份 prepared 状态持久化失败：$($journal.Error)" }
    $op.Id
  }
  $markApplied = {
    param([string]$Id, $Updates)
    $op = @($journal.Document.Ops | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
    if (-not $op) { throw "找不到备份操作：$Id" }
    if ($Updates) { foreach ($k in $Updates.Keys) { $op.$k = $Updates[$k] } }
    $op.Status = 'applied'
    try { Write-BackupDocumentAtomic $journal.Path $journal.Document }
    catch { $journal.Error = $_.Exception.Message; throw "备份 applied 状态持久化失败：$($journal.Error)" }
  }

  $total = $sel.Count; $seq = 0
  foreach ($it in $sel) {
    # 备份落不了盘就立即停手：后续改动将无法回滚
    if ($journal.Error) { break }
    $seq++
    $journal.CurrentItem = $it
    $journal.CurrentOpIndex = 0
    $appliedBefore = @($journal.Document.Ops | Where-Object Status -eq 'applied').Count
    $changeOverride = $null
    # 进度回调来自调用方（GUI），必须包进保护：回调抛异常不能把整轮执行拖死在半路
    if ($Progress) { try { & $Progress ([pscustomobject]@{ Stage = 'start'; Index = $seq; Total = $total; Name = $it.Name; Result = $null }) } catch {} }
    try {
      if ($it.Kind -eq 'power') {
        # 已是卓越性能类方案就不再切换也不备份（判定口径与 Get-ItemState 一致）：
        # 否则重复执行会把「卓越性能」当原方案记进备份，还原时切不回真正的原方案
        $act = Get-ActiveScheme
        $toolGuid = Get-ToolSchemeGuid
        if ($act -and ($act.Guid -eq $script:UltimateGuid -or ($toolGuid -and $act.Guid -eq $toolGuid) -or $act.Name -match '卓越|Ultimate')) {
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = "当前已是「$($act.Name)」，无需切换" }
        } else {
          if (-not $act) { throw '无法确定当前活动电源计划' }
          $old = $act.Guid
          $token = & $prepareBackup @{ Kind = 'power'; Old = $old; ToolCreated = $false; NewGuid = $null }
          $ps = Enable-UltimateScheme
          # ToolCreated 进备份：还原逻辑据此区分「原本就存在的方案」与「本工具新建的方案」
          & $markApplied $token @{ ToolCreated = [bool]$ps.Created; NewGuid = $ps.Guid }
          $msg = $(if ($ps.Created) { "已创建「$script:ToolSchemeName」并激活（还原后该方案会保留，可手动删除）" }
                   else { '已切换到卓越性能方案' })
          if ($ps.Note) { $msg += "；$($ps.Note)" }
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = $msg }
        }
      }
      elseif ($it.Kind -eq 'sched') {
        if (Test-LockTaskExists) {
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = '锁定任务已存在，无需覆盖' }
        } else {
          $active = Get-ActiveScheme
          if (-not $active) { throw '无法确定当前活动电源计划' }
          $token = & $prepareBackup @{ Kind = 'sched'; TaskName = $script:LockTask }
          $taskAction = ('"{0}" /setactive {1}' -f $script:PowerCfgExe, $active.Guid)
          $taskOut = & $script:SchTasksExe /Create /TN $script:LockTask /TR $taskAction /SC MINUTE /MO 1 /RU SYSTEM /RL HIGHEST 2>&1
          if ($LASTEXITCODE -ne 0) { throw "计划任务创建失败：$(("$taskOut").Trim())" }
          if (-not (Test-BoosterLockTask $script:LockTask)) { throw '计划任务创建后回读验证失败' }
          & $markApplied $token
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = '已锁定到当前电源计划（每分钟重设一次）' }
        }
      }
      elseif ($it.Kind -eq 'npi') {
        if (-not (Test-TrustedNvidiaProfileInspector $it.Npi)) { throw 'NVIDIA Profile Inspector 文件签名或发布者校验未通过' }
        if (Test-PathHasReparsePoint $it.Nip) { throw 'NVIDIA 配置档路径包含目录联接或符号链接' }
        $npiOut = & $it.Npi -silentImport $it.Nip 2>&1
        if ($LASTEXITCODE -ne 0) { throw "NVIDIA Profile Inspector 导入失败（退出码 $LASTEXITCODE）：$("$npiOut".Trim())" }
        $changeOverride = $true
        $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = '已导入驱动配置档（此项不在自动备份内）' }
      }
      elseif ($it.Kind -eq 'cache') {
        # 缓存是可再生数据，不写备份（备份几百 MB 再原样写回毫无意义）。
        # 但「没有备份」必须在结果里说出来，不能让用户以为这项也能一键还原
        $r = Clear-ShaderCache
        $changeOverride = [bool]($r.Cleared.Count -gt 0)
        if ($r.Cleared.Count -eq 0 -and $r.Failed.Count -eq 0) {
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $true
                                         Msg = '无缓存可清理（本机没有找到着色器缓存文件）' }
        } elseif ($r.Failed.Count -gt 0 -and $r.Cleared.Count -eq 0) {
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $false; Skipped = $false
                                         Msg = "$($r.Failed -join '；')——请关闭游戏与显卡驱动面板后重试" }
        } else {
          $msg = "$($r.Cleared -join '；')；此项不产生备份，也无需还原（缓存会由驱动自动重建）"
          if ($r.Failed.Count -gt 0) { $msg += "；另有 $($r.Failed -join '；')" }
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = $msg }
        }
      }
      elseif ($it.Kind -eq 'check') {
        # 纯检测项：把检测结论当作执行结果输出，绝不写任何东西。
        # 发现问题恰恰说明检测「运行成功」，绝不能计成失败——用独立的 Attention 状态
        # 承载「体检发现问题/无法判定」，汇总时单列，避免用户误以为工具坏了
        $st = & $it.Check
        $changeOverride = $false
        $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = ($st.Ok -eq $true)
                                       Skipped = $true; Attention = ($st.Ok -ne $true); Msg = "纯检测：$($st.Text)" }
      }
      else {
        if (-not $it.Ops) {
          $why = $(if ($it.RequiresGame) { '未找到游戏路径，已跳过；请用 -GamePath 指定游戏 exe' } else { '本机不满足此项前提，已跳过' })
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $false; Skipped = $true; Msg = $why }
        }
        else {
          # 逐操作容错：某个子操作写入失败（如 12 代大小核机器上个别电源项不受支持）
          # 不再拖垮整项，其余子操作照常执行，失败的逐条记录进结果
          $notes = @(); $errs = @()
          foreach ($op in $it.Ops) {
            if ($journal.Error) { break }
            try {
              $n = Invoke-ApplyOp $op $it.Id $prepareBackup $markApplied
              if ($n) { $notes += $n }
            } catch {
              $opLabel = $(if ($op.Label) { $op.Label } elseif ($op.Name) { $op.Name } else { $op.Kind })
              $errs += "$opLabel：$($_.Exception.Message)"
            }
          }
          if ($errs.Count -eq 0) {
            $msg = $(if ($notes.Count -gt 0) { "已写入（$($notes -join '；')）" } else { '已写入' })
            $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = $msg }
          } elseif ($errs.Count -lt @($it.Ops).Count) {
            $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $false; Skipped = $false
                                           Msg = "部分子项写入失败（其余已写入）：$($errs -join '；')" }
          } else {
            $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $false; Skipped = $false
                                           Msg = "失败：$($errs -join '；')" }
          }
        }
      }
    } catch {
      $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $false; Skipped = $false; Msg = "失败：$($_.Exception.Message)" }
    }
    $walChanged = (@($journal.Document.Ops | Where-Object Status -eq 'applied').Count -gt $appliedBefore)
    $actualChanged = $(if ($null -ne $changeOverride) { [bool]($changeOverride -or $walChanged) } else { $walChanged })
    [void](Set-ApplyResultChangeState $results[-1] $actualChanged)
    if ($Progress) { try { & $Progress ([pscustomobject]@{ Stage = 'done'; Index = $seq; Total = $total; Name = $it.Name; Result = $results[-1] }) } catch {} }
  }

  # 结构化标注「哪些成功项要等重启」：GUI 的重启提醒弹窗、CLI 的收尾文案都以此为准。
  # 跳过/失败/纯检测项一律 $false——没写进系统的东西谈不上重启生效
  $rebootIds = @($sel | Where-Object { $_.Reboot } | ForEach-Object { $_.Id })
  foreach ($x in $results) {
    $x | Add-Member -NotePropertyName Reboot -NotePropertyValue ([bool]($x.Ok -and $x.Changed -and -not $x.Attention -and ($rebootIds -contains $x.Id)))
  }

  # 正常完成时先把 complete 状态原子持久化，再把 GUID pending 文件原子改名。
  $bf = $null
  if (-not $journal.Path) {
    $bf = $null
  } elseif ($journal.Error) {
    if (@($journal.Document.Ops).Count -gt 0) { $bf = $journal.Path }
    else { Remove-Item -LiteralPath $journal.Path -Force -ErrorAction SilentlyContinue }
  } elseif (@($journal.Document.Ops).Count -gt 0) {
    try {
      $journal.Document.State = 'complete'
      Write-BackupDocumentAtomic $journal.Path $journal.Document
      $bf = $journal.Path -replace '\.pending\.json$', '.json'
      [IO.File]::Move($journal.Path, $bf)
    } catch {
      $journal.Error = $_.Exception.Message
      $journal.Document.State = 'pending'
      $bf = $journal.Path
    }
  } else {
    Remove-Item -LiteralPath $journal.Path -Force -ErrorAction SilentlyContinue
  }
  # 备份写盘失败时列出「已生效但备份可能没记全」的项名（排除跳过/纯检测项）：
  # 这是用户手动还原的唯一线索，调用方（GUI/CLI）必须用最醒目的方式呈现
  $unrecorded = @()
  if ($journal.Error) {
    $unrecorded = @($results | Where-Object {
      $_.Changed -and -not $_.Attention -and $_.Msg -notlike '纯检测：*'
    } | ForEach-Object { $_.Name })
  }
  [pscustomobject]@{ ApplyId = $applyId; Results = $results; Backup = $bf; BackupError = $journal.Error; UnrecordedNames = $unrecorded }
  } finally { Exit-EngineMutex $engineMutex }
}

# $Progress 为可选进度回调（与 Invoke-Apply 同一约定：不传时行为与旧版完全一致，
# CLI 与 SKILL.md 契约不受影响）。备份操作是「值」粒度没有人话名字，这里按 Kind
# 拼出用户看得懂的描述，界面还原进度不至于满屏 GUID
function Get-RestoreOpLabel($op) {
  switch ($op.Kind) {
    'power'   { '电源计划（切回原方案）' }
    # v0.9 起备份带 Label；旧备份没有该字段时带上 Sub\Setting GUID——实机出过 4 条
    # 失败全显示泛称「电源计划隐藏项」，用户完全分不清是哪几项
    'pcfg'    { if ($op.PSObject.Properties['Label'] -and $op.Label) { "电源隐藏项「$($op.Label)」" } else { "电源计划隐藏项（$($op.Sub)\$($op.Setting)）" } }
    'mmagent' { "内存管理（$(if ($op.Feature -eq 'mc') { '内存压缩' } else { '页面合并' })）" }
    'sched'   { "计划任务 $($op.TaskName)" }
    'hib'     { '休眠状态' }
    'bcd'     { "启动配置 $($op.Name)" }
    'reg'     { "注册表 $($op.Name)" }
    'file'    { "文件 $(Split-Path -Leaf $op.Path)" }
    default   { "$($op.Kind)" }
  }
}

# 备份操作的去重键：同一目标在多份备份里都出现时，只有最早那份的 OldValue 是真正的
# 优化前原值（后来那些可能记到的是已被本工具改过的值），合并还原据此只保留最早一条
function Get-RestoreOpKey($op) {
  switch ($op.Kind) {
    'reg'     { "reg|$($op.Path)|$($op.Name)" }
    'pcfg'    { "pcfg|$($op.SchemeGuid)|$($op.Sub)|$($op.Setting)" }
    'mmagent' { "mmagent|$($op.Feature)" }
    'bcd'     { "bcd|$($op.Name)" }
    'hib'     { 'hib' }
    'power'   { 'power' }
    'sched'   { "sched|$($op.TaskName)" }
    'file'    { "file|$($op.Path)" }
    default   { $null }   # 未知类型不去重，逐条走还原并如实报错
  }
}

# 计划任务会每分钟把活动方案切回优化方案，因此先删锁定任务；随后先恢复/回退活动
# 电源方案，后续 pcfg 才能根据“实际正在生效的方案”判断残留是否真的无影响。
function Get-RestoreExecutionOps($Ops) {
  $ordered = New-Object System.Collections.Generic.List[object]
  foreach ($kind in @('sched','power')) {
    foreach ($op in @($Ops | Where-Object { "$($_.Kind)" -eq $kind })) { [void]$ordered.Add($op) }
  }
  foreach ($op in @($Ops | Where-Object { "$($_.Kind)" -notin @('sched','power') })) { [void]$ordered.Add($op) }
  @($ordered.ToArray())
}

function Get-RestoreReceiptCanonicalPayload($Receipt) {
  # PowerShell 7 会把 ConvertFrom-Json 读到的 ISO-8601 时间转成 DateTime；
  # 与备份文档使用相同的 UTC round-trip 表示，保证 5.1/7 复验一致。
  $createdUtc = $(if ($Receipt.CreatedUtc -is [DateTime]) {
    $Receipt.CreatedUtc.ToUniversalTime().ToString('o')
  } else { "$($Receipt.CreatedUtc)" })
  $payload = [pscustomobject][ordered]@{
    SchemaVersion = [int]$Receipt.SchemaVersion
    RestoreActionId = "$($Receipt.RestoreActionId)"
    Mode = "$($Receipt.Mode)"
    UserSid = "$($Receipt.UserSid)"
    RestoredItemIds = @($Receipt.RestoredItemIds | ForEach-Object { "$_" })
    ConsumedOps = @($Receipt.ConsumedOps | ForEach-Object {
      [pscustomobject][ordered]@{ BackupId = "$($_.BackupId)"; OpId = "$($_.OpId)" }
    })
    CreatedUtc = $createdUtc
    Verification = "$($Receipt.Verification)"
  }
  $payload | ConvertTo-Json -Depth 8 -Compress
}

function Set-RestoreReceiptIntegrity($Receipt) {
  $value = Get-HmacHex (Get-RestoreReceiptCanonicalPayload $Receipt) (Get-BackupHmacKey)
  $Receipt.Integrity = [pscustomobject][ordered]@{ Algorithm = 'HMAC-SHA256'; Value = $value }
}

function Assert-RestoreReceipt($Receipt) {
  Assert-ExactProperties $Receipt @('SchemaVersion','RestoreActionId','Mode','UserSid','RestoredItemIds','ConsumedOps','CreatedUtc','Verification','Integrity') @() '还原消费凭证'
  if ([int]$Receipt.SchemaVersion -ne $script:RestoreReceiptSchemaVersion) { throw "不支持的还原消费凭证版本：$($Receipt.SchemaVersion)" }
  $actionId = [guid]::Empty; $when = [DateTime]::MinValue
  if (-not [guid]::TryParseExact("$($Receipt.RestoreActionId)", 'D', [ref]$actionId)) { throw '还原消费凭证 ID 无效' }
  if ("$($Receipt.Mode)" -notin @('selected_items','all')) { throw '还原消费凭证模式无效' }
  try { [void](New-Object Security.Principal.SecurityIdentifier("$($Receipt.UserSid)")) } catch { throw '还原消费凭证用户 SID 无效' }
  if (-not [DateTime]::TryParse("$($Receipt.CreatedUtc)", [ref]$when)) { throw '还原消费凭证时间无效' }
  if ("$($Receipt.Verification)" -ne 'verified') { throw '还原消费凭证尚未验证' }
  $itemIds = @($Receipt.RestoredItemIds)
  if ($itemIds.Count -gt 64 -or @($itemIds | Select-Object -Unique).Count -ne $itemIds.Count) { throw '还原消费凭证项目列表重复或超过上限' }
  foreach ($itemId in $itemIds) { if ("$itemId" -notmatch '^[a-z0-9][a-z0-9-]{0,63}$') { throw "还原消费凭证项目 ID 无效：$itemId" } }
  $ops = @($Receipt.ConsumedOps)
  if ($ops.Count -eq 0 -or $ops.Count -gt 4096) { throw '还原消费凭证操作为空或超过上限' }
  $pairs = @()
  foreach ($op in $ops) {
    Assert-ExactProperties $op @('BackupId','OpId') @() '还原消费操作'
    foreach ($field in 'BackupId','OpId') {
      $parsed = [guid]::Empty
      if (-not [guid]::TryParseExact("$($op.$field)", 'D', [ref]$parsed)) { throw "还原消费操作 $field 无效：$($op.$field)" }
    }
    $pairs += ("$($op.BackupId)|$($op.OpId)".ToLowerInvariant())
  }
  if (@($pairs | Select-Object -Unique).Count -ne $pairs.Count) { throw '还原消费凭证包含重复操作' }
  Assert-ExactProperties $Receipt.Integrity @('Algorithm','Value') @() '还原消费凭证完整性字段'
  if ($Receipt.Integrity.Algorithm -ne 'HMAC-SHA256' -or "$($Receipt.Integrity.Value)" -notmatch '^[0-9a-f]{64}$') { throw '还原消费凭证完整性字段无效' }
  $expected = Get-HmacHex (Get-RestoreReceiptCanonicalPayload $Receipt) (Get-BackupHmacKey)
  if (-not (Test-FixedTimeEqual ([Text.Encoding]::ASCII.GetBytes("$($Receipt.Integrity.Value)")) ([Text.Encoding]::ASCII.GetBytes($expected)))) {
    throw '还原消费凭证完整性校验失败，文件可能已被修改'
  }
}

function Write-RestoreReceipt($Receipt) {
  Initialize-ProtectedStore
  Set-RestoreReceiptIntegrity $Receipt
  Assert-RestoreReceipt $Receipt
  $path = Join-Path $script:BackupDir ("restore-receipt-$($Receipt.RestoreActionId).json")
  if (Test-Path -LiteralPath $path) { throw '还原消费凭证文件已存在' }
  $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($Receipt | ConvertTo-Json -Depth 10))
  Write-BytesAtomic $path $bytes
  Set-ProtectedFileAcl $path
  $path
}

function Read-ValidatedRestoreReceipt([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  if (-not (Test-PathUnder $full $script:BackupDir) -or (Test-PathHasReparsePoint $full)) { throw '还原消费凭证路径无效' }
  $fi = Get-Item -LiteralPath $full -ErrorAction Stop
  if ($fi.Length -gt 8MB) { throw '还原消费凭证超过 8MB 上限' }
  try { $receipt = [IO.File]::ReadAllText($full, [Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop }
  catch { throw "还原消费凭证 JSON 损坏：$($_.Exception.Message)" }
  Assert-RestoreReceipt $receipt
  $receipt
}

function Get-ConsumedRestoreOpSet {
  $set = @{}
  if (-not (Test-Path -LiteralPath $script:BackupDir -PathType Container)) { return $set }
  foreach ($path in @(Get-ChildItem -LiteralPath $script:BackupDir -Filter 'restore-receipt-*.json' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)) {
    $receipt = Read-ValidatedRestoreReceipt $path
    if ("$($receipt.UserSid)" -ine $script:TargetUserSid) { continue }
    foreach ($op in @($receipt.ConsumedOps)) { $set[("$($op.BackupId)|$($op.OpId)".ToLowerInvariant())] = $true }
  }
  $set
}

function Get-ValidatedRestoreRecords([string]$File, [bool]$AllowEmpty) {
  Initialize-ProtectedStore
  $notes = @(); $legacyDirs = @(); $sourceFiles = @(); $alreadyConsumed = $false
  if ($File) {
    $candidate = [IO.Path]::GetFullPath($File)
    $restoredCandidate = $candidate + '.restored'
    if ((Test-PathUnder $candidate $script:BackupDir) -and
        -not (Test-Path -LiteralPath $candidate -PathType Leaf) -and
        (Test-Path -LiteralPath $restoredCandidate -PathType Leaf)) {
      $consumed = Read-ValidatedBackup $restoredCandidate @()
      if ($consumed.Document.UserSid -ine $script:TargetUserSid -or
          ([IO.Path]::GetFullPath("$($consumed.Document.UserLocalAppData)").TrimEnd('\') -ine $script:TargetLocalAppData.TrimEnd('\'))) {
        throw '指定备份属于另一个 Windows 用户，已拒绝跨用户还原'
      }
      return [pscustomobject]@{ Records = @(); Notes = @('指定备份此前已完成还原，本次无需重复执行'); AlreadyConsumed = $true }
    }
    if (-not (Test-PathUnder $candidate $script:BackupDir)) {
      $legacyDirs = @(Get-LegacyBackupDirs); $notes += @($script:LegacyBackupWarnings)
    }
    $sourceFiles = @($candidate)
  } else {
    $legacyDirs = @(Get-LegacyBackupDirs); $notes += @($script:LegacyBackupWarnings)
    $sourceFiles = @(
      foreach ($d in (@($script:BackupDir) + @($legacyDirs) | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $d) {
          Get-ChildItem -LiteralPath $d -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        }
      }
    ) | Select-Object -Unique
  }
  if ($sourceFiles.Count -eq 0) {
    if ($AllowEmpty) { return [pscustomobject]@{ Records = @(); Notes = $notes; AlreadyConsumed = $false } }
    $detail = $(if ($notes.Count -gt 0) { "（$($notes -join '；')）" } else { '' })
    throw "未找到任何备份文件，无法还原$detail"
  }
  $readRecords = @($sourceFiles | ForEach-Object { Read-ValidatedBackup $_ $legacyDirs })
  $consumed = @($readRecords | Where-Object Consumed)
  if ($consumed.Count -gt 0) { $notes += "已跳过 $($consumed.Count) 份早已迁移并还原的旧备份" }
  $records = @(Sort-BackupRecordsNewestFirst @($readRecords | Where-Object { -not $_.Consumed } | Group-Object Path | ForEach-Object { $_.Group[0] }))
  $mismatch = @($records | Where-Object {
    $_.Document.UserSid -ine $script:TargetUserSid -or
    ([IO.Path]::GetFullPath("$($_.Document.UserLocalAppData)").TrimEnd('\') -ine $script:TargetLocalAppData.TrimEnd('\'))
  })
  if ($File -and $mismatch.Count -gt 0) { throw '指定备份属于另一个 Windows 用户，已拒绝跨用户还原' }
  if ($mismatch.Count -gt 0) { $notes += "已跳过 $($mismatch.Count) 份属于其他 Windows 用户的备份" }
  $records = @($records | Where-Object { $mismatch -notcontains $_ })
  if ($records.Count -eq 0 -and -not $AllowEmpty) { throw '未找到属于当前目标用户的备份文件，无法还原' }
  [pscustomobject]@{ Records = $records; Notes = $notes; AlreadyConsumed = $alreadyConsumed }
}

function Get-ActiveV3RestoreOps($Records, $ConsumedSet) {
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($record in @($Records | Where-Object { [int]$_.Document.SchemaVersion -eq 3 })) {
    $items = @{}; foreach ($item in @($record.Document.Items)) { $items["$($item.ItemId)"] = $item }
    foreach ($op in @($record.Document.Ops)) {
      $key = ("$($record.Document.BackupId)|$($op.Id)".ToLowerInvariant())
      if ($ConsumedSet.ContainsKey($key)) { continue }
      [void]$list.Add([pscustomobject]@{
        BackupId = "$($record.Document.BackupId)"; BackupPath = "$($record.Path)"
        CreatedUtc = [DateTime]::Parse("$($record.Document.CreatedUtc)").ToUniversalTime()
        Item = $items["$($op.ItemId)"]; Op = $op; ConsumeKey = $key
      })
    }
  }
  @($list.ToArray())
}

function Get-SelectiveRestoreUnits($Wrappers) {
  $units = New-Object System.Collections.Generic.List[object]
  foreach ($group in @($Wrappers | Group-Object { Get-RestoreOpKey $_.Op })) {
    if (-not $group.Name) { continue }
    $ordered = @($group.Group | Sort-Object @{Expression='CreatedUtc';Descending=$false}, @{Expression={ [int]$_.Op.OpIndex };Descending=$false})
    [void]$units.Add([pscustomobject]@{
      TargetKey = $group.Name; Restore = $ordered[0].Op; Latest = $ordered[-1].Op; Wrappers = @($ordered)
    })
  }
  @($units.ToArray())
}

function Test-RegOperationMatchesApplied($Op) {
  $kind = Get-RegValueKind $Op.Path $Op.Name
  $value = $(if ($null -ne $kind) { Get-RegValue $Op.Path $Op.Name } else { $null })
  $matches = ($null -ne $kind) -and "$kind" -eq "$($Op.AppliedKind)" -and (Test-ValueEqual $value $Op.AppliedValue)
  [pscustomobject]@{ Matches = [bool]$matches; CurrentKind = "$kind"; CurrentValue = $value }
}

function Get-RestoreItemCatalog {
  if (-not (Test-Admin)) { throw '读取受保护还原目录需要管理员权限' }
  $state = Get-ValidatedRestoreRecords $null $true
  $consumedSet = Get-ConsumedRestoreOpSet
  $active = @(Get-ActiveV3RestoreOps $state.Records $consumedSet)
  $supported = @(Get-SelectiveRestoreItemIds)
  $shared = @{}
  foreach ($target in @($active | Group-Object { Get-RestoreOpKey $_.Op })) {
    $owners = @($target.Group | ForEach-Object { "$($_.Op.ItemId)" } | Select-Object -Unique)
    if ($target.Name -and $owners.Count -gt 1) { foreach ($owner in $owners) { $shared[$owner] = $true } }
  }
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($itemGroup in @($active | Where-Object { $supported -contains "$($_.Op.ItemId)" } | Group-Object { "$($_.Op.ItemId)" })) {
    $wrappers = @($itemGroup.Group)
    $meta = @($wrappers | Sort-Object CreatedUtc -Descending | ForEach-Object Item | Where-Object { $_ } | Select-Object -First 1)
    if ($meta.Count -eq 0) { continue }
    $units = @(Get-SelectiveRestoreUnits $wrappers)
    $status = 'available'; $reason = ''; $canRestore = $true
    if (@($wrappers | Where-Object { $_.Op.Kind -ne 'reg' }).Count -gt 0) {
      $status = 'unsupported'; $reason = '该项目包含当前版本尚未开放的底层设置，仅支持全部复原'; $canRestore = $false
    } elseif ($shared.ContainsKey($itemGroup.Name)) {
      $status = 'shared_target'; $reason = '该项目与其他项目共享底层设置，请使用全部复原'; $canRestore = $false
    } else {
      foreach ($unit in $units) {
        $check = Test-RegOperationMatchesApplied $unit.Latest
        if (-not $check.Matches) { $status = 'conflict'; $reason = '检测到优化后又被用户或其他程序修改，本次不会覆盖'; $canRestore = $false; break }
      }
    }
    [void]$items.Add([pscustomobject][ordered]@{
      Id = $itemGroup.Name; Name = "$($meta[0].DisplayName)"; RestoreGroupId = "$($meta[0].RestoreGroupId)"
      SettingCount = $units.Count; HistoryOpCount = $wrappers.Count; RebootRequired = [bool]$meta[0].RebootRequired
      Status = $status; StatusText = $(switch ($status) { 'available' { '可精确复原' }; 'conflict' { '发生后续修改' }; 'shared_target' { '存在共享设置' }; default { '仅支持全部复原' } })
      Reason = $reason; CanRestore = $canRestore
    })
  }
  $legacyRecords = @($state.Records | Where-Object { [int]$_.Document.SchemaVersion -eq 2 -and @($_.Document.Ops).Count -gt 0 })
  $pendingRecords = @($state.Records | Where-Object { "$($_.Path)" -like '*.pending.json' })
  $unsupportedIds = @($active | Where-Object { $supported -notcontains "$($_.Op.ItemId)" } | ForEach-Object { "$($_.Op.ItemId)" } | Select-Object -Unique)
  $activeV3BackupCount = @($active | ForEach-Object BackupId | Select-Object -Unique).Count
  [pscustomobject][ordered]@{
    SchemaVersion = 1; Items = @($items.ToArray()); LegacyBackupCount = $legacyRecords.Count
    UnsupportedV3ItemCount = $unsupportedIds.Count; ActiveBackupCount = $activeV3BackupCount + $legacyRecords.Count
    ActiveItemIds = @($active | ForEach-Object { "$($_.Op.ItemId)" } | Select-Object -Unique)
    ActiveItemCount = @($active | ForEach-Object { "$($_.Op.ItemId)" } | Select-Object -Unique).Count
    ActiveOpCount = $active.Count + @($legacyRecords | ForEach-Object { @($_.Document.Ops) }).Count
    PendingBackupCount = $pendingRecords.Count
    ConflictItemCount = @($items.ToArray() | Where-Object { $_.Status -in 'conflict','shared_target','unsupported' }).Count
    HasActiveChanges = [bool]($active.Count -gt 0 -or $legacyRecords.Count -gt 0); Notes = @($state.Notes)
  }
}

function Get-RegRestoreSnapshot($Op) {
  $kind = Get-RegValueKind $Op.Path $Op.Name
  [pscustomobject]@{
    Path = "$($Op.Path)"; Name = "$($Op.Name)"; Existed = ($null -ne $kind)
    Value = $(if ($null -ne $kind) { Get-RegValue $Op.Path $Op.Name } else { $null }); Kind = "$kind"
  }
}

function Set-RegRestoreSnapshot($Snapshot) {
  if ($Snapshot.Existed) {
    $value = $Snapshot.Value
    if ($Snapshot.Kind -eq 'Binary') { $value = [byte[]]@($value) }
    elseif ($Snapshot.Kind -eq 'MultiString') { $value = [string[]]@($value) }
    Set-RegValue $Snapshot.Path $Snapshot.Name $value $Snapshot.Kind
    if ("$(Get-RegValueKind $Snapshot.Path $Snapshot.Name)" -ne "$($Snapshot.Kind)" -or -not (Test-ValueEqual (Get-RegValue $Snapshot.Path $Snapshot.Name) $value)) { throw '注册表状态回滚后验证失败' }
  } else {
    Remove-RegValue $Snapshot.Path $Snapshot.Name
    if ($null -ne (Get-RegValueKind $Snapshot.Path $Snapshot.Name)) { throw '注册表状态回滚删除后验证失败' }
  }
}

function Invoke-RestoreRegOperation($Op) {
  if ($Op.Existed) {
    $value = $Op.OldValue
    if ($Op.OldKind -eq 'Binary') { $value = [byte[]]@($value) }
    elseif ($Op.OldKind -eq 'MultiString') { $value = [string[]]@($value) }
    Set-RegValue $Op.Path $Op.Name $value $Op.OldKind
    if ("$(Get-RegValueKind $Op.Path $Op.Name)" -ne "$($Op.OldKind)" -or -not (Test-ValueEqual (Get-RegValue $Op.Path $Op.Name) $value)) { throw '注册表还原后回读验证失败' }
  } else {
    Remove-RegValue $Op.Path $Op.Name
    if ($null -ne (Get-RegValueKind $Op.Path $Op.Name)) { throw '注册表删除后回读验证失败' }
  }
}

function New-RestoreReceipt([string]$Mode, [string[]]$ItemIds, $Wrappers) {
  [pscustomobject][ordered]@{
    SchemaVersion = $script:RestoreReceiptSchemaVersion
    RestoreActionId = [guid]::NewGuid().ToString('D')
    Mode = $Mode; UserSid = $script:TargetUserSid; RestoredItemIds = @($ItemIds | Select-Object -Unique)
    ConsumedOps = @($Wrappers | ForEach-Object { [pscustomobject][ordered]@{ BackupId = "$($_.BackupId)"; OpId = "$($_.Op.Id)" } })
    CreatedUtc = [DateTime]::UtcNow.ToString('o'); Verification = 'verified'; Integrity = $null
  }
}

function Invoke-RestoreSelected([string[]]$ItemIds, [scriptblock]$Progress) {
  $engineMutex = Enter-EngineMutex
  try {
    if (-not (Test-Admin)) { throw '按项目复原受保护备份需要管理员权限' }
    $ItemIds = @($ItemIds | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    if ($ItemIds.Count -eq 0) { throw '请至少选择一个要复原的项目' }
    $unsupported = @($ItemIds | Where-Object { (Get-SelectiveRestoreItemIds) -notcontains $_ })
    if ($unsupported.Count -gt 0) { throw "以下项目暂不支持按项目复原：$($unsupported -join '、')" }
    $state = Get-ValidatedRestoreRecords $null $false
    $active = @(Get-ActiveV3RestoreOps $state.Records (Get-ConsumedRestoreOpSet))
    $itemResults = New-Object System.Collections.Generic.List[object]
    $successes = New-Object System.Collections.Generic.List[object]
    $failed = New-Object System.Collections.Generic.List[string]
    $index = 0
    foreach ($itemId in $ItemIds) {
      $index++
      $wrappers = @($active | Where-Object { "$($_.Op.ItemId)" -eq $itemId })
      $meta = @($wrappers | ForEach-Object Item | Where-Object { $_ } | Select-Object -First 1)
      $name = $(if ($meta.Count) { "$($meta[0].DisplayName)" } else { $itemId })
      if ($Progress) { & $Progress ([pscustomobject]@{ Stage='start';Index=$index;Total=$ItemIds.Count;Name=$name;Ok=$null }) }
      $ok = $false; $message = ''
      if ($wrappers.Count -eq 0) { $message = '没有仍生效且可精确复原的记录' }
      elseif (@($wrappers | Where-Object { $_.Op.Kind -ne 'reg' }).Count -gt 0) { $message = '该项目包含当前版本尚未开放的底层设置，请使用全部复原' }
      else {
        $units = @(Get-SelectiveRestoreUnits $wrappers)
        $conflict = $false
        foreach ($unit in $units) { if (-not (Test-RegOperationMatchesApplied $unit.Latest).Matches) { $conflict = $true; break } }
        if ($conflict) { $message = '检测到优化后又被用户或其他程序修改，已保留当前状态' }
        else {
          $snapshots = [ordered]@{}; $touched = New-Object System.Collections.Generic.List[string]
          try {
            foreach ($unit in $units) { $snapshots[$unit.TargetKey] = Get-RegRestoreSnapshot $unit.Latest }
            foreach ($unit in $units) {
              [void]$touched.Add($unit.TargetKey)
              Invoke-RestoreRegOperation $unit.Restore
            }
            $ok = $true; $message = "已复原 $($units.Count) 个底层设置"
            [void]$successes.Add([pscustomobject]@{ Id=$itemId;Name=$name;Wrappers=$wrappers;Snapshots=$snapshots;Units=$units;RebootRequired=[bool]$meta[0].RebootRequired })
          } catch {
            $restoreError = $_.Exception.Message; $rollbackErrors = @()
            $rollbackKeys = @($touched.ToArray()); if ($rollbackKeys.Count -gt 1) { [array]::Reverse($rollbackKeys) }
            foreach ($key in $rollbackKeys) {
              try { Set-RegRestoreSnapshot $snapshots[$key] } catch { $rollbackErrors += $_.Exception.Message }
            }
            $message = "$restoreError；本项目已自动撤销本次复原$(if ($rollbackErrors.Count) { "（回滚异常：$($rollbackErrors -join '；')）" })"
          }
        }
      }
      if (-not $ok) { [void]$failed.Add("$name：$message") }
      [void]$itemResults.Add([pscustomobject]@{ Id=$itemId;Name=$name;Ok=$ok;Message=$message })
      if ($Progress) { & $Progress ([pscustomobject]@{ Stage='done';Index=$index;Total=$ItemIds.Count;Name=$name;Ok=$ok }) }
    }
    $receiptPath = $null
    if ($successes.Count -gt 0) {
      $receiptWrappers = @($successes.ToArray() | ForEach-Object { @($_.Wrappers) })
      try { $receiptPath = Write-RestoreReceipt (New-RestoreReceipt 'selected_items' @($successes.ToArray() | ForEach-Object Id) $receiptWrappers) }
      catch {
        $receiptError = $_.Exception.Message
        $rollbackSuccesses = @($successes.ToArray()); if ($rollbackSuccesses.Count -gt 1) { [array]::Reverse($rollbackSuccesses) }
        foreach ($success in $rollbackSuccesses) {
          $rollbackErrors = @()
          $rollbackKeys = @($success.Snapshots.Keys); if ($rollbackKeys.Count -gt 1) { [array]::Reverse($rollbackKeys) }
          foreach ($key in $rollbackKeys) {
            try { Set-RegRestoreSnapshot $success.Snapshots[$key] } catch { $rollbackErrors += $_.Exception.Message }
          }
          $msg = "消费凭证写入失败，已撤销本次复原：$receiptError$(if ($rollbackErrors.Count) { "；回滚异常：$($rollbackErrors -join '；')" })"
          $row = @($itemResults.ToArray() | Where-Object Id -eq $success.Id | Select-Object -First 1)
          if ($row.Count) { $row[0].Ok = $false; $row[0].Message = $msg }
          [void]$failed.Add("$($success.Name)：$msg")
        }
        $successes.Clear()
      }
    }
    $successArray = @($successes.ToArray())
    $files = @($successArray | ForEach-Object { @($_.Wrappers | ForEach-Object BackupPath) } | Select-Object -Unique)
    [pscustomobject][ordered]@{
      Mode='selected_items'; File=$(if($files.Count){$files[0]}else{$null}); Files=$files; MergedCount=$files.Count
      RestoredOps=@($successArray | ForEach-Object { @($_.Units).Count } | Measure-Object -Sum).Sum
      RestoredItems=$successArray.Count; Failed=@($failed.ToArray()); Skipped=@(); Notes=@($state.Notes)
      ItemResults=@($itemResults.ToArray()); RebootItems=@($successArray | Where-Object RebootRequired | ForEach-Object Name)
      RestoredItemIds=@($successArray | ForEach-Object Id)
      RebootItemIds=@($successArray | Where-Object RebootRequired | ForEach-Object Id)
      ApplyIds=@($successArray | ForEach-Object { @($_.Wrappers | ForEach-Object { "$($_.Op.ApplyId)" }) } | Select-Object -Unique)
      Receipt=$receiptPath
    }
  } finally { Exit-EngineMutex $engineMutex }
}

function Invoke-Restore([string]$File, [scriptblock]$Progress) {
  $engineMutex = Enter-EngineMutex
  try {
  if (-not (Test-Admin)) { throw '还原受保护备份需要管理员权限' }
  # 默认合并所有尚未消费过的备份：分多次执行优化会产生多份备份，只回退最新一份会把
  # 更早那次的改动原封留在系统里，而界面却宣布「已回到优化前」。显式传 -BackupFile
  # 仍只还原那一份（专家操作，CLI 契约不变）。全部成功后给备份文件打 .restored 后缀，
  # 下次还原不再消费，避免把早已还原过的旧值再写回系统、覆盖用户此后的手动调整
  $state = Get-ValidatedRestoreRecords $File $false
  if ($state.AlreadyConsumed) {
    return [pscustomobject]@{ Mode='all'; File=$File; Files=@($File); MergedCount=1; RestoredOps=0
      Failed=@(); Skipped=@(); Notes=@($state.Notes); Receipt=$null }
  }
  $restoreNotes = @($state.Notes)
  $consumedSet = Get-ConsumedRestoreOpSet
  $activeV3 = @(Get-ActiveV3RestoreOps $state.Records $consumedSet)
  $activeV3Backups = @($activeV3 | ForEach-Object BackupId | Select-Object -Unique)
  $records = @($state.Records | Where-Object {
    [int]$_.Document.SchemaVersion -eq 2 -or $activeV3Backups -contains "$($_.Document.BackupId)"
  })
  if ($records.Count -eq 0) {
    if ($File) {
      return [pscustomobject]@{ Mode='all'; File=$File; Files=@($File); MergedCount=1; RestoredOps=0
        Failed=@(); Skipped=@(); Notes=@('指定备份此前已完成还原，本次无需重复执行'); Receipt=$null }
    }
    throw "未找到尚未还原的备份$(if ($restoreNotes.Count -gt 0) { "（$($restoreNotes -join '；')）" })"
  }
  $files = @($records | ForEach-Object { $_.Path })
  # 按「新→旧」展开成一张操作表（每份内部仍逆序执行）
  $flat = New-Object System.Collections.Generic.List[object]
  foreach ($record in $records) {
    $f = $record.Path; $b = $record.Document
    if ([int]$b.SchemaVersion -eq 3) {
      $cur = @($activeV3 | Where-Object { $_.BackupId -eq "$($b.BackupId)" } | ForEach-Object Op)
    } else { $cur = @($b.Ops) }
    if ($cur.Count -gt 1) { [array]::Reverse($cur) }
    foreach ($o in $cur) { [void]$flat.Add($o) }
    # *.pending.json = 某次执行中途异常退出（断电/被杀/备份目录中途写失败）实时保留的备份：
    # 内容有效、正常还原，但必须让用户知道它的来源——那次执行没有跑完
    if ($f -like '*.pending.json') {
      $restoreNotes += "备份「$(Split-Path -Leaf $f)」来自一次未完成的执行（中途异常退出时自动保留），已按其中已记录的改动还原"
    }
  }
  # 同一目标只保留最后出现的那条：列表按新→旧排列，最后出现的正是最早备份里的记录
  $lastIdx = @{}
  for ($i = 0; $i -lt $flat.Count; $i++) {
    $k = Get-RestoreOpKey $flat[$i]
    if ($k) { $lastIdx[$k] = $i }
  }
  $ops = @()
  for ($i = 0; $i -lt $flat.Count; $i++) {
    $k = Get-RestoreOpKey $flat[$i]
    if (-not $k -or $lastIdx[$k] -eq $i) { $ops += $flat[$i] }
  }
  $ops = @(Get-RestoreExecutionOps $ops)
  $restored = 0; $failed = @(); $skippedOps = @(); $seq = 0; $total = $ops.Count
  foreach ($op in $ops) {
    $seq++
    if ($Progress) { & $Progress ([pscustomobject]@{ Stage = 'start'; Index = $seq; Total = $total; Name = (Get-RestoreOpLabel $op); Ok = $null }) }
    $opOk = $true
    try {
      # 这些系统级项非管理员必失败：统一先给人话错误，而不是让底层命令各报各的
      if (@('pcfg', 'mmagent', 'hib', 'bcd') -contains $op.Kind -and -not (Test-Admin)) { throw '需要管理员权限' }
      switch ($op.Kind) {
        'power'   {
          if ($op.Old) {
            $powerRestore = Invoke-RestorePowerScheme "$($op.Old)"
            if ($powerRestore.Exact) { $restored++ }
            else { $skippedOps += "电源计划：$($powerRestore.Message)" }
          }
          # 工具自建的方案保留不删：用户可能已经在用它，静默删除是破坏性动作
          if ($op.ToolCreated) {
            $restoreNotes += "工具创建的电源计划「$script:ToolSchemeName」已保留，如不需要可在控制面板→电源选项里手动删除"
          }
        }
        'pcfg'    {
          # Existed=$false：写入前方案里没有显式值（继承默认），删设置子键回到继承态。
          # 旧版备份没有 Existed 字段（当年读不到值就不会写入），一律按显式值写回
          $hasExisted = [bool]$op.PSObject.Properties['Existed']
          if ($hasExisted -and -not $op.Existed) {
            try {
              Remove-PowerSettingAcOverride "$($op.SchemeGuid)" $op.Sub $op.Setting
              $restored++
            } catch {
              # 实机（i5-12600KF）踩实：PowerSchemes 键的 ACL 只给 SYSTEM 写权限，管理员组
              # 只有 ReadKey，直删子键必被「不允许所请求的注册表访问权」拒掉。powercfg 写入
              # 能成是因为它经电源服务（SYSTEM）代写。删不掉就退而求其次——
              # 用 powercfg 把该项写回方案默认值：生效值与继承态完全一致，只是形式上从
              # 「继承」变成了「显式等于默认」，对用户零影响
              $guid = $(if ($op.SchemeGuid) { "$($op.SchemeGuid)" } else { (Get-ActiveScheme).Guid })
              $def = Get-RegValue "$script:PsRoot\$($op.Sub)\$($op.Setting)\DefaultPowerSchemeValues\$guid" 'ACSettingIndex'
              if ($null -ne $def) {
                Set-PowerSettingAc $op.Sub $op.Setting ([int]$def) $guid
                $restored++
              } else {
                # power/sched 已提前还原，此处必须读取“实际”活动方案，而不是根据备份猜
                # 最终方案。实机出现过原方案失效，旧逻辑仍按预期 GUID 判定无影响，导致
                # 工具方案实际保持活动却被写成“复原完成”。
                $activeAfterPowerRestore = Get-ActiveScheme
                $activeGuid = $(if ($activeAfterPowerRestore) { "$($activeAfterPowerRestore.Guid)" } else { '' })
                if ($activeGuid -and ($guid -ine $activeGuid)) {
                  $skippedOps += "$(Get-RestoreOpLabel $op)：跳过（残留设置当前位于非活动方案，对正在使用的电源方案无影响；若以后手动切回该方案会重新用上这些值）"
                } else {
                  throw "无法清除该方案里的残留显式值（此注册表键仅系统账户可写，且该方案查不到默认值），该值仍留在当前活动方案（$guid）中"
                }
              }
            }
          } else {
            Set-PowerSettingAc $op.Sub $op.Setting ([int]$op.OldValue) "$($op.SchemeGuid)"
            $restored++
          }
        }
        'mmagent' {
          Set-MMAgentState $op.Feature ([bool]$op.OldEnabled)
          if ((Get-MMAgentState $op.Feature) -ne [bool]$op.OldEnabled) { throw '内存管理状态还原后回读验证失败' }
          $restored++
        }
        'sched'   {
          $xml = Get-TaskXml "$($op.TaskName)"
          if ($xml) {
            if (-not (Test-BoosterLockTask "$($op.TaskName)")) { throw '同名计划任务不是本工具创建，已拒绝删除' }
            $taskOut = & $script:SchTasksExe /Delete /TN "$($op.TaskName)" /F 2>&1
            $code = $LASTEXITCODE
            if ((Get-TaskXml "$($op.TaskName)") -or $code -ne 0) { throw "计划任务删除失败（退出码 $code）：$(("$taskOut").Trim())" }
          }
          $restored++
        }
        'hib'     { Set-HibernateEnabled ([bool]$op.OldEnabled); $restored++ }
        'bcd'     {
          if ($op.OldValue -eq 'absent') { Remove-BcdEntryValue $op.Name } else { Set-BcdEntryValue $op.Name $op.OldValue }
          $restored++
        }
        # 备份里存的是应用前的整文件原始字节，逐字节写回即完全复原（含编码/BOM/格式）
        'file'    {
          throw '用户配置文件备份需要由原用户普通权限进程还原，已拒绝在管理员进程中写入'
        }
        'reg'     {
          if ($op.Path -like 'HKLM:*' -and -not (Test-Admin)) { throw '需要管理员权限' }
          if ($op.Existed) {
            # JSON 往返后二进制/多字符串会变成普通数组，必须转回强类型才能写回注册表
            $val = $op.OldValue
            if ($op.OldKind -eq 'Binary') { $val = [byte[]]@($val) }
            elseif ($op.OldKind -eq 'MultiString') { $val = [string[]]@($val) }
            Set-RegValue $op.Path $op.Name $val $op.OldKind
            if ("$(Get-RegValueKind $op.Path $op.Name)" -ne "$($op.OldKind)" -or -not (Test-ValueEqual (Get-RegValue $op.Path $op.Name) $val)) { throw '注册表还原后回读验证失败' }
          } else {
            Remove-RegValue $op.Path $op.Name
            if ($null -ne (Get-RegValueKind $op.Path $op.Name)) { throw '注册表删除后回读验证失败' }
          }
          $restored++
        }
        default   { throw "未知备份类型：$($op.Kind)" }
      }
    } catch {
      # 失败行必须带人话项名：pcfg 备份没有 Name 字段，旧写法拼出来只剩「pcfg ：」，
      # 用户完全不知道哪项失败了——统一走 Get-RestoreOpLabel
      $opOk = $false; $failed += "$(Get-RestoreOpLabel $op)：$($_.Exception.Message)"
    }
    if ($Progress) { & $Progress ([pscustomobject]@{ Stage = 'done'; Index = $seq; Total = $total; Name = (Get-RestoreOpLabel $op); Ok = $opOk }) }
  }
  # v3 原始备份保持不可变，通过签名消费凭证记录已还原操作；v2 缺少项目归属，继续用
  # .restored 整份归档兼容旧版。任何还原失败都不消费记录，修复后可重试。
  $receiptPath = $null
  if (@($failed).Count -eq 0) {
    if ($activeV3.Count -gt 0) {
      try {
        $receipt = New-RestoreReceipt 'all' @($activeV3 | ForEach-Object { "$($_.Op.ItemId)" } | Select-Object -Unique) $activeV3
        $receiptPath = Write-RestoreReceipt $receipt
      } catch { $failed += "v3 备份已还原但消费凭证写入失败：$($_.Exception.Message)" }
    }
    if (@($failed).Count -eq 0) {
      foreach ($record in @($records | Where-Object { [int]$_.Document.SchemaVersion -eq 2 })) {
        $f = $record.Path
        try { Rename-Item -LiteralPath $f -NewName ((Split-Path -Leaf $f) + '.restored') -ErrorAction Stop }
        catch { $failed += "备份「$(Split-Path -Leaf $f)」已还原但完成标记失败：$($_.Exception.Message)" }
      }
    }
  }
  $allSucceeded = @($failed).Count -eq 0
  [pscustomobject]@{ Mode='all'; File = $files[0]; Files = $files; MergedCount = @($files).Count
                     RestoredOps = $restored; Failed = $failed; Skipped = $skippedOps; Notes = $restoreNotes
                     RestoredItemIds = $(if ($allSucceeded) { @($activeV3 | ForEach-Object { "$($_.Op.ItemId)" } | Select-Object -Unique) } else { @() })
                     RebootItemIds = $(if ($allSucceeded) { @($activeV3 | Where-Object { $_.Item -and $_.Item.RebootRequired } | ForEach-Object { "$($_.Op.ItemId)" } | Select-Object -Unique) } else { @() })
                     ApplyIds = @($activeV3 | ForEach-Object { "$($_.Op.ApplyId)" } | Select-Object -Unique)
                     Receipt=$receiptPath }
  } finally { Exit-EngineMutex $engineMutex }
}

# ---------- 输出 ----------

function Get-ApplyExitCode($Result) {
  if ($Result.BackupError) { return 3 }
  if (@($Result.Results | Where-Object { -not $_.Ok -and -not $_.Skipped -and -not $_.Attention }).Count -gt 0) { return 2 }
  0
}

function Get-RestoreExitCode($Result) {
  if (@($Result.Failed).Count -gt 0) { return 4 }
  0
}

function Write-DetectText($r) {
  Write-Output "== 硬件 =="
  Write-Output "  系统   ：$($r.Hardware.OS)（Build $($r.Hardware.Build)）"
  Write-Output "  CPU    ：$($r.Hardware.CPU)（$($r.Hardware.Cores) 核 $($r.Hardware.Threads) 线程）"
  Write-Output "  内存   ：$($r.Hardware.RamGB) GB"
  foreach ($g in $r.Hardware.Gpus) { Write-Output "  显卡   ：$($g.Name)（$($g.Vendor)，驱动 $($g.Driver)）" }
  Write-Output "  机型   ：$(if ($r.Hardware.IsLaptop) { '笔记本' } else { '台式机' })"
  Write-Output "  管理员 ：$(if ($r.Hardware.IsAdmin) { '是' } else { '否（部分优化项需要管理员）' })"
  Write-Output ""
  Write-Output "== 游戏 =="
  Write-Output "  $(if ($r.GamePath) { $r.GamePath } else { '未自动找到游戏，请用 -GamePath 指定游戏主程序 exe' })"
  Write-Output ""
  Write-Output "== 推荐优化项（safe） =="
  foreach ($s in ($r.Items | Where-Object { $_.Tier -eq 'safe' })) {
    $mark = if ($s.Optimized -eq $true) { '[√]' } elseif ($s.Optimized -eq $false) { '[×]' } else { '[?]' }
    Write-Output "  $mark $($s.Id) — $($s.Name)$(if ($s.Admin) { '（需管理员）' })"
    Write-Output "      当前：$($s.Current)"
  }
  $risky = @($r.Items | Where-Object { $_.Tier -eq 'risky' })
  if ($risky.Count -gt 0) {
    Write-Output ""
    Write-Output "== 高风险项（risky，需 -Items 显式指定 + -Risky 才执行） =="
    foreach ($s in $risky) {
      $mark = if ($s.Optimized -eq $true) { '[√]' } elseif ($s.Optimized -eq $false) { '[×]' } else { '[?]' }
      Write-Output "  $mark $($s.Id) — $($s.Name)"
      Write-Output "      当前：$($s.Current)"
      Write-Output "      风险：$($s.Note)"
    }
  }
  Write-Output ""
  Write-Output $r.GpuGuide
}

# ---------- 入口分发（被 GUI 点源加载时所有开关为 false，不执行任何动作） ----------

if ($Json) { try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {} }

if ($RequestFile) {
  # Windows PowerShell 5.1 的脚本参数绑定会让未绑定的 [string[]] 参数在
  # @($Items).Count 中表现为 1。直接检查实际绑定键，避免把空 Items/RestoreItems
  # 误判成与 -RequestFile 同时传入的业务参数。
  if ($PSBoundParameters.Count -ne 1 -or -not $PSBoundParameters.ContainsKey('RequestFile')) {
    throw '-RequestFile 不能与其他动作或业务参数同时使用'
  }
  $engineRequest = Import-EngineActionRequest $RequestFile
  $script:EngineResultFile = $engineRequest.ResultFile
  $ResultId = $engineRequest.ResultId
  $UserSid = $engineRequest.UserSid
  $UserLocalAppData = $engineRequest.UserLocalAppData
  $UserStateRoot = $engineRequest.UserStateRoot
  $Apply = $engineRequest.Action -eq 'Apply'
  $ListRestoreItems = $engineRequest.Action -eq 'Restore' -and $engineRequest.ListRestoreItems
  $Restore = $engineRequest.Action -eq 'Restore' -and -not $engineRequest.ListRestoreItems
  $Items = [string[]]@($engineRequest.ItemIds)
  $GamePath = $engineRequest.GamePath
  $Risky = [bool]$engineRequest.AllowRisky
  # GpuSpoofModel 是带 ValidateSet 的脚本参数。Windows PowerShell 5.1 会在把
  # $null/空串重新赋给该变量时再次执行验证并抛出 ValidateSetFailure；请求未指定
  # 型号时保持参数原有的 $null，只在确有已校验型号时回填。
  if ($engineRequest.GpuSpoofModel) { $GpuSpoofModel = $engineRequest.GpuSpoofModel }
  $BackupFile = $engineRequest.BackupFile
  $RestoreItems = [string[]]@($engineRequest.RestoreItemIds)
}

$didDispatch = [bool]($ListItems -or $Detect -or $Preview -or $ListPresets -or $SavePreset -or $DeletePreset -or $Apply -or $Restore -or $ListRestoreItems)
if ($didDispatch) {
$dispatchAction = $(if ($Apply) { 'Apply' } elseif ($Restore -or $ListRestoreItems) { 'Restore' } elseif ($Detect -or $Preview) { 'Detect' } else { 'Other' })
$dispatchData = $null; $dispatchError = $null; $cliExitCode = 0
try {
  Set-TargetUserContext $UserSid $UserLocalAppData
  if ($UserStateRoot) {
    if (-not (Test-Admin) -or -not $UserSid) { throw 'UserStateRoot 仅支持管理员显式用户上下文' }
    $expectedStateRoot = [IO.Path]::GetFullPath((Get-ProtectedUserStateRoot $script:TargetUserSid)).TrimEnd('\')
    if ([IO.Path]::GetFullPath($UserStateRoot).TrimEnd('\') -ine $expectedStateRoot -or
        [IO.Path]::GetFullPath($script:UserDataRoot).TrimEnd('\') -ine $expectedStateRoot) {
      throw 'UserStateRoot 与受保护 per-SID 状态分区不匹配'
    }
    Initialize-UserDataStore
  }
  if ($ResultId) {
    $rid = [guid]::Empty
    if (-not [guid]::TryParseExact($ResultId, 'D', [ref]$rid)) { throw 'ResultId 必须是标准 D 格式 GUID' }
    if ($dispatchAction -eq 'Other') { throw 'ResultId 仅支持 Detect、Apply 或 Restore' }
  }
if ($ListItems) {
  $r = Get-OptItems $GamePath
  if ($Json) { $r | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Tier = $_.Tier; Name = $_.Name; Admin = $_.Admin; Default = $_.Default; Note = $(if ($_.Warn) { $_.Warn } else { $_.Note }) } } | ConvertTo-Json -Depth 4 }
  else {
    foreach ($it in $r) {
      $tag = $(if ($it.Tier -eq 'risky') { '[高风险] ' } else { '' })
      Write-Output ("{0,-20} {1}{2}{3}" -f $it.Id, $tag, $it.Name, $(if ($it.Admin) { '（需管理员）' } else { '' }))
      Write-Output ("                     {0}" -f $(if ($it.Warn) { $it.Warn } else { $it.Note }))
    }
  }
}
elseif ($Detect -or $Preview) {
  $r = Invoke-DetectReport $GamePath
  if ($Json) { $r | ConvertTo-Json -Depth 6 } else { Write-DetectText $r }
  if ($Preview) {
    Write-Output ""
    Write-Output "== 预览：-Apply 将执行（仅 safe 档默认项） =="
    foreach ($s in ($r.Items | Where-Object { $_.Default -and $_.Tier -eq 'safe' -and $_.Optimized -ne $true })) { Write-Output "  将优化：$($s.Name)" }
    Write-Output "（仅预览，未做任何修改）"
  }
}
elseif ($ListPresets) {
  $r = Get-Presets
  if ($Json) { $r | ConvertTo-Json -Depth 4 }
  else {
    foreach ($p in $r) {
      Write-Output ("{0,-12} {1}{2}  （{3} 项）" -f $p.Id, $p.Name, $(if ($p.Builtin) { '' } else { ' [自存]' }), @($p.Items).Count)
      Write-Output ("             {0}" -f $p.Note)
    }
  }
}
elseif ($SavePreset) {
  $f = Save-UserPreset $SavePreset $Items
  if ($Json) { @{ Saved = $f } | ConvertTo-Json } else { Write-Output "方案「$SavePreset」已保存：$f" }
}
elseif ($DeletePreset) {
  $n = Remove-UserPreset $DeletePreset
  if ($Json) { @{ Deleted = $n } | ConvertTo-Json } else { Write-Output "方案「$n」已删除" }
}
elseif ($ListRestoreItems) {
  $r = Get-RestoreItemCatalog
  if ($Json) { $r | ConvertTo-Json -Depth 6 }
  else {
    foreach ($item in @($r.Items)) { Write-Output "  $(if ($item.CanRestore) { '[可复原]' } else { '[不可选]' }) $($item.Id) — $($item.Name)（$($item.StatusText)）" }
    if ($r.LegacyBackupCount -gt 0) { Write-Output "旧版本备份：$($r.LegacyBackupCount) 份，仅支持全部还原" }
  }
}
elseif ($Apply) {
  # -Preset 与 -Items 二选一；同时给出时以 -Preset 为准
  if ($Preset) { $Items = Resolve-PresetItems $Preset $GamePath }
  $r = Invoke-Apply $Items $GamePath ([bool]$Risky) $null $GpuSpoofModel
  if ($Json) { $r | ConvertTo-Json -Depth 5 }
  else {
    foreach ($x in $r.Results) { Write-Output "  $(if ($x.Attention) { '[提示]' } elseif ($x.Ok) { '[成功]' } elseif ($x.Skipped) { '[跳过]' } else { '[失败]' }) $($x.Name) — $($x.Msg)" }
    $okN = @($r.Results | Where-Object Ok).Count
    $attN = @($r.Results | Where-Object Attention).Count
    $skipN = @($r.Results | Where-Object { -not $_.Ok -and $_.Skipped }).Count
    $failN = @($r.Results | Where-Object { -not $_.Ok -and -not $_.Skipped -and -not $_.Attention }).Count
    Write-Output "执行完成：共 $(@($r.Results).Count) 项 — $okN 成功、$failN 失败、$skipN 跳过$(if ($attN -gt 0) { "、$attN 项体检发现问题" })。"
    if ($r.Backup) { Write-Output "备份已保存：$($r.Backup)（用 -Restore 可一键还原）" }
    # 备份写盘失败是最高级别的告警：系统已经改了、备份却没记全，必须当场把线索给全
    if ($r.BackupError) {
      Write-Output "！！严重警告：备份文件写入失败（$($r.BackupError)），剩余优化项已中止执行。"
      if (@($r.UnrecordedNames).Count -gt 0) {
        Write-Output "！！以下已生效的改动可能没有完整的备份记录，如需回退请按项名手动处理：$(@($r.UnrecordedNames) -join '、')"
      }
      if ($r.Backup) { Write-Output "！！已抢救出的部分备份：$($r.Backup)（-Restore 可还原其中已记录的部分）" }
    }
    $rebootList = @($r.Results | Where-Object { $_.Reboot })
    if ($rebootList.Count -gt 0) {
      Write-Output "提示：以下 $($rebootList.Count) 个成功项需重启电脑后完全生效——$(@($rebootList | ForEach-Object { $_.Name }) -join '、')。"
    }
  }
}
elseif ($Restore) {
  if ($BackupFile -and @($RestoreItems).Count -gt 0) { throw '-BackupFile 与 -RestoreItems 不能同时使用' }
  $r = $(if (@($RestoreItems).Count -gt 0) { Invoke-RestoreSelected $RestoreItems } else { Invoke-Restore $BackupFile })
  if ($Json) { $r | ConvertTo-Json -Depth 4 }
  else {
    if ($r.Mode -eq 'selected_items') {
      foreach ($item in @($r.ItemResults)) { Write-Output "  $(if ($item.Ok) { '[复原成功]' } else { '[复原失败]' }) $($item.Name) — $($item.Message)" }
      Write-Output "按项目复原完成：$($r.RestoredItems) 项成功，共写回 $($r.RestoredOps) 个底层设置"
    } elseif ($r.MergedCount -gt 1) { Write-Output "已合并 $($r.MergedCount) 份备份，共还原 $($r.RestoredOps) 项改动（同一设置以最早备份的原值为准）" }
    else { Write-Output "已按备份还原 $($r.RestoredOps) 项改动（备份：$($r.File)）" }
    foreach ($f in $r.Failed) { Write-Output "  [还原失败] $f" }
    foreach ($s in $r.Skipped) { Write-Output "  [还原跳过] $s" }
    foreach ($n in $r.Notes) { Write-Output "  [提示] $n" }
  }
}
  $dispatchData = $r
  if ($Apply) {
    $cliExitCode = Get-ApplyExitCode $r
  } elseif ($Restore) { $cliExitCode = Get-RestoreExitCode $r }
} catch {
  $dispatchError = $_.Exception.Message
  $cliExitCode = $(if ($Apply -and $dispatchError -match '备份.*(不可写|持久化|完整性密钥)') { 3 } else { 1 })
  [Console]::Error.WriteLine("[错误] $dispatchError")
} finally {
  if ($ResultId -and $ResultId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
    try { Write-IpcResult $ResultId $dispatchAction $dispatchData $cliExitCode $dispatchError }
    catch {
      [Console]::Error.WriteLine("[错误] 写入提权结果失败：$($_.Exception.Message)")
      if ($cliExitCode -eq 0) { $cliExitCode = 1 }
    }
  }
}
exit $cliExitCode
}
