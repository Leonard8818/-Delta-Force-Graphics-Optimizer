<#
  DeltaForceBooster 核心脚本 — v0.16.1
  三角洲行动 一键画面/帧率优化：硬件检测 + Windows 系统优化 + 显卡驱动指引。

  v0.16.1：双显卡按独显性能优先级选择主显卡，不再因 WMI 返回顺序误把 AMD/Intel
        核显用于显卡指引；NVIDIA 笔记本指引补充 Game Ready 驱动选择说明。
  v0.16：显卡型号伪装按代际给默认值（RTX 30 系 → GTX 705 Ti，RTX 40/50 系 →
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
  v0.13：新增 risky 项 gpu-name-spoof（改独显上报型号，默认不勾、不进任何预设）；
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
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Restore [-BackupFile 备份文件]
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -ListItems
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -ListPresets
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Apply -Preset balanced
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -SavePreset "我的方案" -Items id1,id2

  安全设计：
    - Apply 前把每个被改动的注册表值/电源设置/系统开关完整备份到 backup\backup-*.json
    - Restore 按备份逆序恢复，原本不存在的值会被删除而不是写 0
    - 优化项分两档：safe（默认推荐）与 risky（有副作用或降低系统安全性，必须显式选中
      并加 -Risky 才会执行）。risky 档永远不会被"一键默认"带上。
#>
#requires -Version 5.1
[CmdletBinding()]
param(
  [switch]$Detect,
  [switch]$Preview,
  [switch]$Apply,
  [switch]$Restore,
  [switch]$ListItems,
  [switch]$ListPresets,
  [string]$Preset,
  [string]$SavePreset,
  [string]$DeletePreset,
  [string[]]$Items,
  [string]$GamePath,
  [string]$BackupFile,
  [ValidateSet('NVIDIA GeForce GTX 705 Ti', 'NVIDIA GeForce GTX 1050 Ti')]
  [string]$GpuSpoofModel,
  [switch]$Risky,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$script:Root      = Split-Path -Parent $PSScriptRoot
$script:BackupDir = Join-Path $script:Root 'backup'
$script:ToolsDir  = Join-Path $script:Root 'tools'
$script:LockTask  = 'DeltaForceBooster-PowerPlanLock'

# ---------- 基础工具 ----------

function Test-Admin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 用 .NET Registry API 而不是 PowerShell Provider：值名是完整 exe 路径时含反斜杠，
# Provider 的 -Name 会做通配符解析，.NET API 没有这个坑。
function Split-RegPath([string]$Path) {
  # 输出两个对象（根键、子路径），调用侧用 $base,$sub = ... 解包；不要再包一层数组
  if     ($Path -match '^HKLM:\\?(.*)$') { [Microsoft.Win32.Registry]::LocalMachine; $Matches[1] }
  elseif ($Path -match '^HKCU:\\?(.*)$') { [Microsoft.Win32.Registry]::CurrentUser;  $Matches[1] }
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

$script:UltimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'

# 工具自建方案的专属名：用户可能自建过任意名字的方案（实测有人的方案就叫「4060」），
# 新建的方案必须一眼能认出来自本工具，避免与用户自己维护的方案混淆
$script:ToolSchemeName = '三角洲优化 · 卓越性能'
$script:ConfigDir = Join-Path $script:Root 'config'

# 自建方案 GUID 记在 config\ 而不是 profiles\：profiles 下的 *.json 会被扫描成用户预设方案
function Get-ToolSchemeGuid {
  $f = Join-Path $script:ConfigDir 'power-scheme.json'
  if (-not (Test-Path -LiteralPath $f)) { return $null }
  try { (Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json).Guid } catch { $null }
}

function Save-ToolSchemeGuid([string]$SchemeGuid) {
  if (-not (Test-Path -LiteralPath $script:ConfigDir)) { New-Item -ItemType Directory -Path $script:ConfigDir | Out-Null }
  @{ Guid = $SchemeGuid; Name = $script:ToolSchemeName; Created = (Get-Date).ToString('s') } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:ConfigDir 'power-scheme.json') -Encoding UTF8
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
  $out = & powercfg /setactive $SchemeGuid 2>&1
  $script:LastActivateOut = ("$out").Trim()
  if ($LASTEXITCODE -ne 0) { return $false }
  $now = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActivePowerScheme'
  ("$now" -ieq $SchemeGuid)
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
  $out = & powercfg -duplicatescheme $script:UltimateGuid 2>&1
  if ($LASTEXITCODE -ne 0 -or "$out" -notmatch "($script:GuidRx)") {
    throw "无法创建卓越性能电源计划（powercfg 原话：$(("$out").Trim())）"
  }
  $newGuid = $Matches[1]
  $ren = & powercfg -changename $newGuid $script:ToolSchemeName '由 DeltaForceBooster 创建，还原优化后如不需要可手动删除' 2>&1
  if ($LASTEXITCODE -ne 0) { Write-Warning "电源计划已创建但命名失败：$(("$ren").Trim())" }
  Save-ToolSchemeGuid $newGuid
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
  & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
}

# 解除隐藏，返回原 Attributes 值供还原用；已可见则返回 $null
function Show-PowerSetting([string]$Sub, [string]$Setting) {
  if (-not (Test-PowerSettingHidden $Sub $Setting)) { return $null }
  $old = Get-RegValue "$script:PsRoot\$Sub\$Setting" 'Attributes'
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & powercfg -attributes $Sub $Setting -ATTRIB_HIDE 2>&1
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
  $out = & powercfg /setacvalueindex $target $Sub $Setting $Value 2>&1
  if ($LASTEXITCODE -ne 0) { throw "写入电源项失败$(if ("$out") { "（powercfg 原话：$(("$out").Trim())）" } else { '' })" }
  & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
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
  # schtasks 找不到任务时往 stderr 写字，Stop 模式下会被当成终止错误，这里局部降级
  $ErrorActionPreference = 'SilentlyContinue'
  & schtasks /Query /TN $script:LockTask 2>&1 | Out-Null
  $LASTEXITCODE -eq 0
}

# ---------- 休眠 / 引导配置 / 显卡专项 ----------

function Get-HibernateState {
  # HibernateEnabled 在部分机器上不存在（本机实测缺失），退而看休眠文件是否在，
  # 两个信号都拿不到才算读取失败——备份必须基于真实旧状态
  $v = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
  if ($null -ne $v) { return ([int]$v -ne 0) }
  [bool](Test-Path -LiteralPath (Join-Path $env:SystemDrive 'hiberfil.sys'))
}

function Set-HibernateEnabled([bool]$On) {
  # powercfg 失败信息走 stderr，Stop 模式下会变终止错误，这里局部降级后查退出码
  $ErrorActionPreference = 'SilentlyContinue'
  & powercfg -h $(if ($On) { 'on' } else { 'off' }) 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw '设置休眠状态失败（需要管理员权限）' }
}

# 读 {current} 引导项里某个值。bcdedit 连读取都要管理员，非管理员返回 $null；
# 值名（disabledynamictick 等）和取值（Yes/Off 等）不随系统语言变化，可安全解析
function Get-BcdValue([string]$Name) {
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & bcdedit /enum "{current}" 2>&1
  if ($LASTEXITCODE -ne 0) { return $null }
  foreach ($line in @($out)) {
    if ("$line" -match ('^\s*' + [regex]::Escape($Name) + '\s+(\S+)\s*$')) { return $Matches[1] }
  }
  # 能读到引导项但没有该值：多数值默认就不写入，这是合法状态，与"读取失败"区分开
  'absent'
}

function Set-BcdEntryValue([string]$Name, [string]$Value) {
  $ErrorActionPreference = 'SilentlyContinue'
  & bcdedit /set "{current}" $Name $Value 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "写入引导配置失败：$Name（需要管理员权限）" }
}

function Remove-BcdEntryValue([string]$Name) {
  $ErrorActionPreference = 'SilentlyContinue'
  # 原本就没设过该值时 deletevalue 报"找不到元素"，这正是还原目标状态，不算失败
  & bcdedit /deletevalue "{current}" $Name 2>&1 | Out-Null
}

# 独显在 Enum\PCI 下的实例路径。同一个 VEN_10DE 下还挂着 HD Audio 控制器等非显卡设备，
# 必须按驱动服务名 nvlddmkm 认显卡，不能只看厂商 ID。
# 实测（RTX 3070 Laptop / Win11 26200）：该键 Owner=BUILTIN\Administrators 且管理员组
# FullControl，管理员可直接读写，无需 takeown/改 ACL——与电源方案键（只有 SYSTEM 可写）不同。
function Get-NvidiaGpuEnumPath {
  $root = 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI'
  $base, $sub = Split-RegPath $root
  $k = $base.OpenSubKey($sub)
  if (-not $k) { return $null }
  try {
    foreach ($ven in ($k.GetSubKeyNames() | Where-Object { $_ -match 'VEN_10DE' })) {
      $vk = $base.OpenSubKey("$sub\$ven")
      if (-not $vk) { continue }
      try {
        foreach ($inst in $vk.GetSubKeyNames()) {
          if ((Get-RegValue "$root\$ven\$inst" 'Service') -match 'nvlddmkm') { return "$root\$ven\$inst" }
        }
      } finally { $vk.Close() }
    }
  } finally { $k.Close() }
  $null
}

# 显卡控制面板入口检测。装了才给按钮，没装只给下载页——按钮点了没反应比没有按钮更糟。
# 查找方式与 Find-GamePath 同思路：应用包 → 传统安装路径 → 卸载注册表。
# 下载页地址是本文件里的硬编码 https 常量，绝不从检测结果或网络取。
function Get-GpuPanelApps([string]$Vendor) {
  $apps = @()
  # appx 类走 shell:appsFolder（Store 版控制面板没有可直接执行的 exe 路径）
  $findAppx = {
    param($Name)
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
              "$env:SystemRoot\System32\amdow.exe") |
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
  $base, $sub = Split-RegPath $root
  $k = $base.OpenSubKey($sub)
  if (-not $k) { return $null }
  try {
    foreach ($n in ($k.GetSubKeyNames() | Where-Object { $_ -match '^\d{4}$' })) {
      if ((Get-RegValue "$root\$n" 'DriverDesc') -eq $Hw.MainGpuName) { return "$root\$n" }
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
  $gpu = @($Hw.Gpus | Where-Object { $_.Vendor -in 'NVIDIA', 'AMD' -and $_.Pnp }) | Select-Object -First 1
  if (-not $gpu) { return $null }
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
function Get-VcRedistStatus {
  $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $all = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -match 'Visual C\+\+' -and $_.DisplayVersion -match '^14\.' })
  # 文案直接带微软官方永久链接：用户不用再自己搜安装包，配合日志一键复制即可拿到
  $dl = 'https://aka.ms/vs/18/release/vc_redist.x64.exe 和 https://aka.ms/vs/18/release/vc_redist.x86.exe'
  if ($all.Count -eq 0) {
    return @{ Ok = $false; Text = "未检测到 VC++ 2015-2022(v14) 运行库 —— 游戏很可能无法启动。请下载 x64 与 x86 两个都装（双击覆盖安装即可）：$dl，装完重启后再跑一次检测确认" }
  }
  # 按架构分组（DisplayName 里带 x64/x86 字样；arm64 不含字母 x 不会误匹配）
  $vc64 = @($all | Where-Object { $_.DisplayName -match '(?i)x64' })
  $vc86 = @($all | Where-Object { $_.DisplayName -match '(?i)x86' })
  if ($vc64.Count -eq 0 -or $vc86.Count -eq 0) {
    $missArch = $(if ($vc64.Count -eq 0) { 'x64' } else { 'x86' })
    return @{ Ok = $false; Text = "缺少 $missArch 架构的 v14 运行库 —— 依赖它的程序（含游戏组件）可能无法启动。请下载 x64 与 x86 两个都装（双击覆盖安装即可）：$dl，装完重启后再跑一次检测确认" }
  }
  # 每个架构取已装的最高版本作代表（同架构的 Minimum/Additional Runtime 组件版本一致）
  $ver64 = @($vc64 | ForEach-Object { [version]$_.DisplayVersion } | Sort-Object -Descending)[0]
  $ver86 = @($vc86 | ForEach-Object { [version]$_.DisplayVersion } | Sort-Object -Descending)[0]
  if ($ver64.Minor -ne $ver86.Minor) {
    # 中性陈述而非报警：没有严格证据表明版本不同步必然导致掉帧/闪退（社区只有
    # 「重装后恢复」的个案报告），把它计入「体检发现问题」会制造误报和无谓折腾
    return @{ Ok = $true; Text = "x64 $ver64 / x86 $ver86，版本不同步——两套运行库相互独立，这在多数机器上无害，不算问题；只有确实遇到闪退或异常掉帧且排除了其他原因时，才值得给两个架构都装同一条最新线的包来统一：$dl。若安装器报 0x80070666「已安装更新的版本」，说明系统里的比安装包还新——正常现象，不用处理，也不要为此卸载" }
  }
  @{ Ok = $true; Text = "v14 运行库 x64/x86 版本一致（x64 $ver64 / x86 $ver86，共 $($all.Count) 个组件），正常" }
}

# 内存没开 XMP/EXPO 会跑在 JEDEC 保守频率上。SPD 里的 XMP 档位 WMI 读不到，
# 所以只能保守判断：跑不满标称=明确没开；等于 JEDEC 基准频率=可疑，提示用户自己去 BIOS 确认。
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
    return @{ Ok = $false; Text = "$ddr 实际 $cur MHz 低于标称 $rated MHz —— XMP/EXPO 多半没开，去 BIOS 开启可白捡性能" }
  }
  if ($cur -le $jedecMax) {
    return @{ Ok = $null; Text = "$ddr 运行在 $cur MHz（正好是 JEDEC 基准上限）—— 如果你的内存条标称更高，说明 XMP/EXPO 没开，值得去 BIOS 确认" }
  }
  @{ Ok = $true; Text = "$ddr 运行在 $cur MHz，已超过 JEDEC 基准，XMP/EXPO 已生效" }
}

function Get-PcieLinkStatus {
  if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
    return @{ Ok = $null; Text = '无法检测（无 nvidia-smi；A 卡/核显可用 GPU-Z 查看总线接口）' }
  }
  $ErrorActionPreference = 'SilentlyContinue'
  # 参数必须整体加引号：PowerShell 会把裸逗号解析成数组，拆散 nvidia-smi 的查询串
  $out = & nvidia-smi '--query-gpu=pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max' '--format=csv,noheader' 2>&1
  if ($LASTEXITCODE -ne 0 -or -not "$out") { return @{ Ok = $null; Text = '无法检测（nvidia-smi 查询失败）' } }
  $p = @("$(@($out)[0])" -split ',' | ForEach-Object { $_.Trim() })
  if ($p.Count -lt 4 -or $p[3] -notmatch '^\d+$') { return @{ Ok = $null; Text = "无法检测（输出异常：$out）" } }
  $ok = ([int]$p[3] -ge 8)
  @{ Ok = $ok
     Text = "链路上限 PCIe $($p[1]).0 x$($p[3])$(if ($ok) { '，正常' } else { '，异常偏低，检查显卡是否插在直连 CPU 的主插槽' })（当前 $($p[0]).0 x$($p[2])，空闲降速属正常）" }
}

# ---------- 硬件与游戏检测 ----------

function Get-GpuVendor([string]$Pnp, [string]$Name) {
  if     ($Pnp -match 'VEN_10DE' -or $Name -match 'NVIDIA|GeForce|RTX|GTX') { 'NVIDIA' }
  elseif ($Pnp -match 'VEN_1002' -or $Name -match 'AMD|Radeon')             { 'AMD' }
  elseif ($Pnp -match 'VEN_8086' -or $Name -match 'Intel|Arc|UHD|Iris')     { 'Intel' }
  else   { 'Unknown' }
}

# Win32_VideoController 的返回顺序没有「独显优先」保证，AMD 核显经常排在 NVIDIA
# 独显前面。用型号特征做稳定排序：NVIDIA GeForce、AMD RX/Pro、Intel Arc 视为独显，
# 其余 Radeon Graphics / Intel UHD / Iris 作为核显兜底。
function Get-GpuPreferenceScore($Gpu) {
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

function Get-HardwareInfo {
  $os   = Get-CimInstance Win32_OperatingSystem
  $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
  $cs   = Get-CimInstance Win32_ComputerSystem
  $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object {
    [pscustomobject]@{
      Name   = $_.Name
      Vendor = Get-GpuVendor $_.PNPDeviceID $_.Name
      Driver = $_.DriverVersion
      Pnp    = $_.PNPDeviceID   # 中断绑核要按设备实例路径落到 Enum 键下
    }
  })
  # 双显卡（核显+独显）机器以独显为主，不能依赖 WMI 的未定义返回顺序
  $main = Select-MainGpu $gpus

  # 笔记本判定：有电池即笔记本。部分优化项（电源计划 DC 档、显卡型号）取值按机型区分
  $isLaptop = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)

  [pscustomobject]@{
    OS            = $os.Caption
    Build         = [int]$os.BuildNumber
    CPU           = $cpu.Name.Trim()
    Cores         = $cpu.NumberOfCores
    Threads       = $cpu.NumberOfLogicalProcessors
    RamGB         = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    Gpus          = $gpus
    MainGpuVendor = $(if ($main) { $main.Vendor } else { 'Unknown' })
    MainGpuName   = $(if ($main) { $main.Name } else { '未检测到' })
    IsLaptop      = $isLaptop
    IsAdmin       = Test-Admin
  }
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
  $unKeys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
  foreach ($e in @(Get-ItemProperty $unKeys -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -match '三角洲|Delta\s*Force|DeltaForce' })) {
    # InstallLocation 常为空，此时从卸载程序/图标路径倒推安装目录
    foreach ($cand in @($e.InstallLocation,
                        $(if ($e.UninstallString) { Split-Path -Parent ($e.UninstallString -replace '^"|"$') }),
                        $(if ($e.DisplayIcon)     { Split-Path -Parent ($e.DisplayIcon -replace '^"|"$' -replace ',\d+$') }))) {
      if ($cand -and (Test-Path -LiteralPath $cand -ErrorAction SilentlyContinue)) { $roots.Add($cand) }
    }
  }

  foreach ($rk in 'HKLM:\SOFTWARE\WOW6432Node\Tencent\WeGame', 'HKCU:\Software\Tencent\WeGame') {
    $ip = Get-RegValue $rk 'InstallPath'
    if ($ip -and (Test-Path -LiteralPath $ip)) { $roots.Add($ip) }
  }

  $steam = Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'
  if ($steam) {
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
      foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
        $lib = $m.Groups[1].Value -replace '\\\\', '\'
        $g = Join-Path $lib 'steamapps\common\Delta Force'
        if (Test-Path -LiteralPath $g) { $roots.Add($g) }
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
      $p = Join-Path $d.Root $guess
      if (Test-Path -LiteralPath $p) { $uniq += $p }
    }
  }

  $found = @()
  foreach ($r in ($uniq | Select-Object -Unique)) {
    foreach ($n in $exeNames) {
      $found += @(Get-ChildItem -Path $r -Recurse -Depth 6 -Filter $n -File -ErrorAction SilentlyContinue |
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

# ---------- 优化项定义 ----------

# 电源子组 GUID（微软公开文档值）
$script:SubUsb  = '2a737441-1930-4402-8d77-b2bebba308a3'
$script:SubProc = '54533251-82be-4824-96c1-47b60b740d00'

function Get-GpuSpoofModels {
  @('NVIDIA GeForce GTX 705 Ti', 'NVIDIA GeForce GTX 1050 Ti')
}

function Get-DefaultGpuSpoofModel([string]$GpuName, [bool]$IsLaptop) {
  # 按用户实机经验做代际映射：RTX 30 系默认伪装为 705 Ti，40/50 系默认 1050 Ti。
  # 其他型号保留原先的机型兜底逻辑，界面仍允许用户手动切换两种目标型号。
  if ("$GpuName" -match '(?i)RTX\s*30\d{2}') { return 'NVIDIA GeForce GTX 705 Ti' }
  if ("$GpuName" -match '(?i)RTX\s*(?:40|50)\d{2}') { return 'NVIDIA GeForce GTX 1050 Ti' }
  if ($IsLaptop) { return 'NVIDIA GeForce GTX 1050 Ti' }
  'NVIDIA GeForce GTX 705 Ti'
}

function Get-OptItems([string]$GamePath, [string]$GpuSpoofModel) {
  $items = @()
  $hw = $null
  try { $hw = Get-HardwareInfo } catch {}
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
               Note = '与帧率无关但影响压枪手感，FPS 玩家普遍关闭。会改变鼠标移动习惯，默认不勾选。' }

  # ===== v0.4 新增：全套调试路线补齐 =====

  $items += @{ Id = 'mpo-off'; Tier = 'safe'; Name = '禁用 MPO 多平面叠加（治闪烁/卡顿）'; Admin = $true; Default = $true; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'; Name = 'OverlayTestMode'; Value = 5; Kind2 = 'DWord' })
               Note = 'MPO 与部分驱动组合会造成画面闪烁和掉帧，NVIDIA 官方曾专门发布禁用工具。副作用：视频播放时 DWM 功耗略升。重启生效。' }

  $mmcss = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
  # DWord 0xffffffff 在 .NET 有符号 int 里就是 -1，写 4294967295 会转换溢出
  $items += @{ Id = 'net-throttling-off'; Tier = 'safe'; Name = '解除多媒体网络限流'; Admin = $true; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = $mmcss; Name = 'NetworkThrottlingIndex'; Value = -1; Kind2 = 'DWord'; Label = '网络限流指数（-1 即 0xffffffff 不限流）' })
               Note = '系统默认每毫秒只放行 10 个网络包给非多媒体流量，网游高发包率下引入延迟抖动；0xffffffff 表示彻底不限流。' }

  $items += @{ Id = 'sys-responsiveness'; Tier = 'safe'; Name = '提高系统响应度（MMCSS 后台保留=0）'; Admin = $true; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = $mmcss; Name = 'SystemResponsiveness'; Value = 0; Kind2 = 'DWord'; Label = '后台 CPU 保留比例' })
               Note = '默认给后台任务保留 20% CPU；写 0 让前台游戏拿满（内核实际按 10% 下限钳制，0 是游戏圈通行写法）。' }

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
  $nvAppCfg = Join-Path $env:LOCALAPPDATA 'NVIDIA Corporation\NVIDIA app\NvBackend\config.xml'
  $items += @{ Id = 'nv-autoopt-off'; Tier = 'safe'; Name = '关闭 NVIDIA App 自动优化游戏设置'; Admin = $false; Default = $true; Kind = 'multi'
               Ops  = $(if (Test-Path -LiteralPath $nvAppCfg) { @(@{ Kind = 'file'; Path = $nvAppCfg
                          Match   = '(<Setting name=[''"]EnableAutomaticApplyOPS[''"] value=[''"])1([''"][^>]*/>)'
                          Replace = '${1}0$2'
                          Verify  = '<Setting name=[''"]EnableAutomaticApplyOPS[''"] value=[''"]0[''"]'
                          Label   = 'NVIDIA 自动优化(OPS)' }) })
               Note = '这个开关开着时，NVIDIA 会自动把它认为「最佳」的画质设置写进游戏、覆盖你自己调好的参数（俗称"白调"）。关掉只是不再自动改游戏设置，不影响驱动本身。与「锁定电源计划」同源：都是防外部程序偷改你的配置。' }

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

  $items += @{ Id = 'vcredist-check'; Tier = 'safe'; Name = 'VC++ 运行库体检（纯检测，不改设置）'; Admin = $false; Default = $false; Kind = 'check'
               Check = 'Get-VcRedistStatus'
               Note = '检测 VC++ 2015-2022(v14) 运行库是否缺失——缺了游戏很可能无法启动。x64 与 x86 两套相互独立，版本不同步很常见且通常无害，只做中性提示不报问题。本项只检测不修——卸载重装运行库会波及其他软件，须你自己判断后手动处理。' }

  $items += @{ Id = 'xmp-check'; Tier = 'safe'; Name = '内存 XMP/EXPO 体检（纯检测，不改设置）'; Admin = $false; Default = $false; Kind = 'check'
               Check = 'Get-MemoryXmpStatus'
               Note = '内存没开 XMP/EXPO 时会跑在 JEDEC 保守频率上，白白损失几十帧。BIOS 设置无法由软件修改，本项只负责把"你的内存在摸鱼"这件事告诉你。' }

  $items += @{ Id = 'dyntick-off'; Tier = 'safe'; Name = '禁用动态计时器（bcdedit）'; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = @(@{ Kind = 'bcd'; Name = 'disabledynamictick'; Value = 'yes'; Label = '动态计时器' })
               Note = '恢复固定时钟中断，部分机器帧生成间隔更稳。副作用：空闲功耗略升、笔记本续航变差，默认不勾选。重启生效。' }

  # 经验公式：初始=内存GB×1024×1.5、最大=×2。固定大小是为防页面文件动态收缩引发卡顿；
  # 收益只在闪退/爆内存场景成立，平时不值得占这份磁盘，所以默认不勾选
  $ramInt = $(if ($hw) { [int][math]::Round($hw.RamGB) } else { 0 })
  $items += @{ Id = 'pagefile-custom'; Tier = 'safe'; Name = "虚拟内存固定为 $([int]($ramInt * 1.5))–$($ramInt * 2) GB"; Admin = $true; Default = $false; Kind = 'multi'; Reboot = $true
               Ops  = $(if ($ramInt -gt 0) { @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
                                                  Name = 'PagingFiles'; Kind2 = 'MultiString'; Label = '页面文件'
                                                  Value = [string[]]@("$env:SystemDrive\pagefile.sys $($ramInt * 1536) $($ramInt * 2048)") }) })
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

  # ===== risky 档：必须显式勾选 + -Risky 才执行，不进任何预设方案 =====

  # 改独显上报的型号名。实测结论（RTX 3070 Laptop / Win11 26200）：该键管理员组有
  # FullControl，直接写即可，无需 takeown 或改 ACL；写入即时生效（WMI 立刻改口径），
  # 写回原字符串后逐字节一致、WMI 同步复原——所以备份/还原走通用 reg 通路就够。
  $nvEnum = Get-NvidiaGpuEnumPath
  $spoofModels = @(Get-GpuSpoofModels)
  $fakeGpu = $(if ($GpuSpoofModel -and $spoofModels -contains $GpuSpoofModel) { $GpuSpoofModel }
               else { Get-DefaultGpuSpoofModel $(if ($hw) { $hw.MainGpuName } else { '' }) $(if ($hw) { $hw.IsLaptop } else { $false }) })
  $items += @{ Id = 'gpu-name-spoof'; Tier = 'risky'; Name = '显卡型号伪装'; SpoofModel = $fakeGpu; Admin = $true; Default = $false; Kind = 'multi'
               Ops = $(if ($nvEnum) { @(@{ Kind = 'reg'; Path = $nvEnum; Name = 'DeviceDesc'; Value = $fakeGpu
                                           Kind2 = 'String'; Label = '显卡型号' }) })
               Note = '让游戏以为你是低端卡从而走低配渲染路径。已有实测反例：有人改完帧数不升反降。重装或更新显卡驱动后失效（DeviceDesc 被驱动写回）。系统上报的型号与真实硬件不一致，反作弊如何对待这种状态没有公开说明。仅 N 卡可用，备份原值可完整还原。' }

  # N 卡进阶：用户自行下载 NVIDIA Profile Inspector 放进 tools\ 后才出现此项
  $npi = Join-Path $script:ToolsDir 'nvidiaProfileInspector.exe'
  $nip = Get-ChildItem $script:ToolsDir -Filter '*.nip' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ((Test-Path -LiteralPath $npi) -and $nip) {
    $items += @{ Id = 'nvidia-profile'; Tier = 'safe'; Name = "导入 N 卡驱动配置档（$($nip.Name)）"; Admin = $true; Default = $false; Kind = 'npi'
                 Npi = $npi; Nip = $nip.FullName
                 Note = '调用 NVIDIA Profile Inspector 静默导入 3D 设置（低延迟/预渲染帧/DLSS 预设）。此项无自动备份，请先在 Inspector 里手动导出当前配置。' }
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
      Note = '按电源→优先级→中断绑核→系统精简→显卡层的顺序全套执行。代价：鼠标手感变直、休眠/快速启动没了、Windows 搜索变慢、待机功耗升高（笔记本更耗电）。不关引导虚拟化，WSL/模拟器不受影响。'
      Items = @('power-ultimate','power-tuning','powerplan-lock',
                'prio-separation','game-priority','sys-responsiveness','mmcss-games','net-throttling-off','game-mode',
                'gpu-irq-affinity',
                'dvr-off','wer-off','sysmain-off','wsearch-off','hibernate-off','mem-compress-off',
                'paging-exec','transparency-off','mpo-off','dyntick-off','mouse-accel-off',
                'hags','fso-off','gpu-pref','gpu-pstate-lock','nv-autoopt-off','nvidia-profile',
                'pcie-check','vcredist-check','xmp-check')
    }
    [pscustomobject]@{
      Id = 'balanced'; Name = '均衡推荐'; Builtin = $true
      Note = '收益明确、副作用小的一组，适合绝大多数人。不改桌面外观和鼠标手感，不禁用任何服务，不动休眠。顺带做三项硬件体检。'
      Items = @('power-ultimate','power-tuning','hags','game-mode','dvr-off','prio-separation',
                'paging-exec','wer-off','transparency-off','mpo-off','net-throttling-off',
                'sys-responsiveness','mmcss-games','fso-off','gpu-pref','game-priority',
                'nv-autoopt-off','pcie-check','vcredist-check','xmp-check')
    }
    [pscustomobject]@{
      Id = 'safe-only'; Name = '保守（只改当前用户）'; Builtin = $true
      Note = '只动 HKCU 用户级设置，不碰系统全局、不需要重启。适合公司电脑或不想动系统的人。'
      Items = @('game-mode','dvr-off','wer-off','transparency-off','fso-off','gpu-pref','windowed-opt-off')
    }
  )
}

function Get-ProfileDir {
  $d = Join-Path $script:Root 'profiles'
  if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
  $d
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
  $f = Join-Path (Get-ProfileDir) "$safe.json"
  @{ Name = $Name; Saved = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Items = $ids } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $f -Encoding UTF8
  $f
}

function Remove-UserPreset([string]$Id) {
  $p = @(Get-UserPresets | Where-Object { $_.Id -eq $Id }) | Select-Object -First 1
  if (-not $p) { throw "未找到自存方案：$Id" }
  Remove-Item -LiteralPath $p.File -Force
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
function Get-GpuGuideText([string]$Vendor, [string]$GpuName, [bool]$IsLaptop) {
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
      '「自动优化」会覆写你调好的画质，用本工具的「关闭 NVIDIA App 自动优化游戏设置」项关掉即可。'
      '进阶：NVIDIA Profile Inspector 放进本工具 tools\ 目录后可一键导入驱动配置档。'
    ) -join "`n" }
    'AMD' { @(
      'AMD Software (Adrenalin) → 游戏 → 三角洲行动：'
      '  1. Radeon Anti-Lag = 开'
      '  2. Radeon Chill / Boost = 关'
      '  3. 等待垂直刷新 = 关闭，除非应用程序指定'
      '  4. 纹理过滤质量 = 性能'
      '  5. 表面格式优化 = 开'
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
    GpuGuide = Get-GpuGuideText $hw.MainGpuVendor $hw.MainGpuName $hw.IsLaptop
  }
}

function Invoke-ApplyOp($Op, $ItemId, [ref]$BackupOps) {
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
      Set-RegValue $Op.Path $Op.Name $newVal $Op.Kind2
      $BackupOps.Value += @{ Kind = 'reg'; Path = $Op.Path; Name = $Op.Name
                             Existed = ($null -ne $oldKind); OldValue = $oldVal; OldKind = "$oldKind" }
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
      $oldAttr = Show-PowerSetting $Op.Sub $Op.Setting
      if ($null -ne $oldAttr) {
        $BackupOps.Value += @{ Kind = 'reg'; Path = "$script:PsRoot\$($Op.Sub)\$($Op.Setting)"; Name = 'Attributes'
                               Existed = $true; OldValue = $oldAttr; OldKind = 'DWord' }
      }
      Set-PowerSettingAc $Op.Sub $Op.Setting $Op.Value
      # Label 一并进备份：还原失败/跳过时日志要能报出人话项名，纯 GUID 用户根本对不上号
      $BackupOps.Value += @{ Kind = 'pcfg'; Sub = $Op.Sub; Setting = $Op.Setting; Label = $Op.Label
                             Existed = ($null -ne $old); OldValue = $old; SchemeGuid = $act.Guid }
    }
    'mmagent' {
      $old = Get-MMAgentState $Op.Feature
      if ($null -eq $old) { throw "无法读取 $($Op.Label) 当前状态" }
      # 已是关闭态就跳过：再备份会把「已被上一轮关掉」记成原状态，还原时开不回去
      if (-not $old) { return "无需修改：$($Op.Label) 已是目标状态" }
      Set-MMAgentState $Op.Feature $false
      $BackupOps.Value += @{ Kind = 'mmagent'; Feature = $Op.Feature; OldEnabled = $old }
    }
    'kvstr' {
      # 整串备份、只改目标子键：这个值里还住着 AutoHDREnable 等别人的设置，整串覆盖会误伤
      $oldKind = Get-RegValueKind $Op.Path $Op.Name
      $oldRaw  = $(if ($null -ne $oldKind) { Get-RegValue $Op.Path $Op.Name } else { $null })
      # 只比目标子键：整串里其余键值是别人的设置，不影响本项是否已达标
      if ("$(Get-KvStringItem $oldRaw $Op.Key)" -eq "$($Op.Value)") { return "无需修改：$($Op.Label) 已是目标状态" }
      Set-RegValue $Op.Path $Op.Name (Set-KvStringItem $oldRaw $Op.Key $Op.Value) 'String'
      $BackupOps.Value += @{ Kind = 'reg'; Path = $Op.Path; Name = $Op.Name
                             Existed = ($null -ne $oldKind); OldValue = $oldRaw; OldKind = "$oldKind" }
    }
    'hib' {
      $old = Get-HibernateState
      # 已关闭就跳过：再备份会把 OldEnabled 记成 $false，还原时休眠开不回去
      if (-not $old) { return "无需修改：$($Op.Label) 已是目标状态" }
      Set-HibernateEnabled $false
      $BackupOps.Value += @{ Kind = 'hib'; OldEnabled = [bool]$old }
    }
    'bcd' {
      $old = Get-BcdValue $Op.Name
      if ($null -eq $old) { throw "无法读取引导配置（需要管理员权限）：$($Op.Label)" }
      # 已达标就跳过（bcdedit 取值大小写不敏感）：避免把目标值当原值备份
      if ("$old" -ieq "$($Op.Value)") { return "无需修改：$($Op.Label) 已是目标状态" }
      Set-BcdEntryValue $Op.Name $Op.Value
      # OldValue='absent' 表示原本未设置，还原时删除该值而不是写回字符串
      $BackupOps.Value += @{ Kind = 'bcd'; Name = $Op.Name; OldValue = $old }
    }
    'file' {
      # 外部程序的配置文件是别人家的私产：用正则只替换目标那一小段而不是 XML DOM 重排
      # （.Save() 会把单引号改双引号、动缩进，没必要冒对方解析异常的风险）；
      # 备份直接存整文件原始字节，还原时逐字节写回，比值级还原可靠
      if (-not (Test-Path -LiteralPath $Op.Path)) { throw "文件不存在：$($Op.Path)" }
      $rawBytes = [IO.File]::ReadAllBytes($Op.Path)
      $txt = [IO.File]::ReadAllText($Op.Path)
      if ($txt -match $Op.Verify) { return "无需修改：$($Op.Label) 已是目标状态" }
      if ($txt -notmatch $Op.Match) { throw "未在 $(Split-Path -Leaf $Op.Path) 中找到目标设置（配置结构可能已变化），请手动处理：$($Op.Label)" }
      $new = [regex]::Replace($txt, $Op.Match, $Op.Replace)
      # 写回保持原文件的编码与 BOM 状态，除目标片段外逐字节不变
      $enc = if ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) { New-Object Text.UTF8Encoding($true) }
             elseif ($rawBytes.Length -ge 2 -and $rawBytes[0] -eq 0xFF -and $rawBytes[1] -eq 0xFE) { [Text.Encoding]::Unicode }
             elseif ($rawBytes.Length -ge 2 -and $rawBytes[0] -eq 0xFE -and $rawBytes[1] -eq 0xFF) { [Text.Encoding]::BigEndianUnicode }
             else { New-Object Text.UTF8Encoding($false) }
      [IO.File]::WriteAllText($Op.Path, $new, $enc)
      # 回读校验：拥有该文件的程序（NVIDIA App 常驻进程）可能随时把配置写回去，
      # 写完必须确认真的落住了，落不住就如实报失败引导手动关
      if ([IO.File]::ReadAllText($Op.Path) -notmatch $Op.Verify) { throw "写入后回读校验未通过（文件可能被其所属程序改回），请在对应程序里手动设置：$($Op.Label)" }
      $BackupOps.Value += @{ Kind = 'file'; Path = $Op.Path; OrigB64 = [Convert]::ToBase64String($rawBytes) }
    }
    default { throw "未知操作类型：$($Op.Kind)" }
  }
  $null
}

# $Progress 为可选进度回调（不传时行为与旧版完全一致，CLI 与 SKILL.md 契约不受影响）：
# 每项开始时以 Stage='start' 调用一次（带 Index/Total/Name），完成时以 Stage='done'
# 再调一次（额外带该项的 Result），GUI 靠它做进度条与实时日志
function Invoke-Apply([string[]]$ItemIds, [string]$GamePath, [bool]$AllowRisky, [scriptblock]$Progress,
                      [string]$GpuSpoofModel) {
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

  $backupOps = @(); $results = @()

  # 备份边执行边落盘：先写 *.pending.json、全部完成后原子改名为正式备份，中途断电/被杀
  # 也能留下可还原的备份文件。开工前必须先试写一次——备份目录写不进去（OneDrive 同步锁、
  # 只读、磁盘满）就直接中止，绝不能在「存不下备份」的状态下改系统
  $applyTime = Get-Date
  $pendingFile = Join-Path $script:BackupDir ("backup-{0:yyyyMMdd-HHmmss}.pending.json" -f $applyTime)
  try {
    if (-not (Test-Path -LiteralPath $script:BackupDir)) { New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null }
    @{ Time = $applyTime.ToString('s'); Ops = @() } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $pendingFile -Encoding UTF8
  } catch {
    throw "备份目录不可写（$script:BackupDir），已中止执行，未做任何修改。请先解除目录占用（OneDrive 同步、只读属性、磁盘空间）再重试。原因：$($_.Exception.Message)"
  }
  # 每记录一条备份就整文件重写 pending（备份体量小，重写代价可忽略）；写失败只记录不抛出，
  # 由主循环立即止步——继续执行只会积累更多「改了但没记下」的项。用 . 号调用在当前作用域执行
  $persisted = 0; $persistErr = $null
  $persistBackup = {
    if (-not $persistErr -and $backupOps.Count -gt $persisted) {
      try {
        @{ Time = $applyTime.ToString('s'); Ops = $backupOps } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $pendingFile -Encoding UTF8
        $persisted = $backupOps.Count
      } catch { $persistErr = $_.Exception.Message }
    }
  }

  $total = $sel.Count; $seq = 0
  foreach ($it in $sel) {
    # 备份落不了盘就立即停手：后续改动将无法回滚
    if ($persistErr) { break }
    $seq++
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
          $old = $act.Guid
          $ps = Enable-UltimateScheme
          # ToolCreated 进备份：还原逻辑据此区分「原本就存在的方案」与「本工具新建的方案」
          $backupOps += @{ Kind = 'power'; Old = $old; ToolCreated = [bool]$ps.Created; NewGuid = $ps.Guid }
          $msg = $(if ($ps.Created) { "已创建「$script:ToolSchemeName」并激活（还原后该方案会保留，可手动删除）" }
                   else { '已切换到卓越性能方案' })
          if ($ps.Note) { $msg += "；$($ps.Note)" }
          $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = $msg }
        }
      }
      elseif ($it.Kind -eq 'sched') {
        $guid = (Get-ActiveScheme).Guid
        & schtasks /Create /TN $script:LockTask /TR "powercfg.exe /setactive $guid" /SC MINUTE /MO 1 /RU SYSTEM /RL HIGHEST /F 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw '计划任务创建失败' }
        $backupOps += @{ Kind = 'sched'; TaskName = $script:LockTask }
        $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = '已锁定到当前电源计划（每分钟重设一次）' }
      }
      elseif ($it.Kind -eq 'npi') {
        & $it.Npi -silentImport $it.Nip
        $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = '已导入驱动配置档（此项不在自动备份内）' }
      }
      elseif ($it.Kind -eq 'check') {
        # 纯检测项：把检测结论当作执行结果输出，绝不写任何东西。
        # 发现问题恰恰说明检测「运行成功」，绝不能计成失败——用独立的 Attention 状态
        # 承载「体检发现问题/无法判定」，汇总时单列，避免用户误以为工具坏了
        $st = & $it.Check
        $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = ($st.Ok -eq $true)
                                       Skipped = $false; Attention = ($st.Ok -ne $true); Msg = "纯检测：$($st.Text)" }
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
            if ($persistErr) { break }
            try {
              $n = Invoke-ApplyOp $op $it.Id ([ref]$backupOps)
              if ($n) { $notes += $n }
            } catch {
              $opLabel = $(if ($op.Label) { $op.Label } elseif ($op.Name) { $op.Name } else { $op.Kind })
              $errs += "$opLabel：$($_.Exception.Message)"
            }
            # 每条子操作产生的备份立即落盘：断电/被杀最多丢最后一条记录
            . $persistBackup
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
    # 兜底落盘：power/sched 等直接往 $backupOps 里加记录的分支也在每项结束时持久化
    . $persistBackup
    if ($Progress) { try { & $Progress ([pscustomobject]@{ Stage = 'done'; Index = $seq; Total = $total; Name = $it.Name; Result = $results[-1] }) } catch {} }
  }

  # 结构化标注「哪些成功项要等重启」：GUI 的重启提醒弹窗、CLI 的收尾文案都以此为准。
  # 跳过/失败/纯检测项一律 $false——没写进系统的东西谈不上重启生效
  $rebootIds = @($sel | Where-Object { $_.Reboot } | ForEach-Object { $_.Id })
  foreach ($x in $results) {
    $x | Add-Member -NotePropertyName Reboot -NotePropertyValue ([bool]($x.Ok -and -not $x.Skipped -and -not $x.Attention -and ($rebootIds -contains $x.Id)))
  }

  # 收尾三分支：正常完成→pending 原子改名为正式备份；中途写盘失败→保住已持久化的部分并
  # 如实上报；全程没有产生备份（纯检测/全部跳过）→清掉预写的空壳文件
  $bf = $null
  if ($persistErr) {
    if ($persisted -gt 0) { $bf = $pendingFile }
    else { Remove-Item -LiteralPath $pendingFile -Force -ErrorAction SilentlyContinue }
  } elseif ($backupOps.Count -gt 0) {
    $bf = $pendingFile -replace '\.pending\.json$', '.json'
    # 改名失败不丢数据：还原逻辑同样识别 pending 文件，退回用它即可
    try { [IO.File]::Move($pendingFile, $bf) } catch { $bf = $pendingFile }
  } else {
    Remove-Item -LiteralPath $pendingFile -Force -ErrorAction SilentlyContinue
  }
  # 备份写盘失败时列出「已生效但备份可能没记全」的项名（排除跳过/纯检测项）：
  # 这是用户手动还原的唯一线索，调用方（GUI/CLI）必须用最醒目的方式呈现
  $unrecorded = @()
  if ($persistErr) {
    $unrecorded = @($results | Where-Object {
      -not $_.Skipped -and -not $_.Attention -and $_.Msg -notlike '纯检测：*' -and
      ($_.Ok -or $_.Msg -like '部分子项写入失败*')
    } | ForEach-Object { $_.Name })
  }
  [pscustomobject]@{ Results = $results; Backup = $bf; BackupError = $persistErr; UnrecordedNames = $unrecorded }
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

function Invoke-Restore([string]$File, [scriptblock]$Progress) {
  # 默认合并所有尚未消费过的备份：分多次执行优化会产生多份备份，只回退最新一份会把
  # 更早那次的改动原封留在系统里，而界面却宣布「已回到优化前」。显式传 -BackupFile
  # 仍只还原那一份（专家操作，CLI 契约不变）。全部成功后给备份文件打 .restored 后缀，
  # 下次还原不再消费，避免把早已还原过的旧值再写回系统、覆盖用户此后的手动调整
  $files = @()
  if ($File) { $files = @($File) }
  else {
    $files = @(Get-ChildItem $script:BackupDir -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -ExpandProperty FullName)
  }
  if ($files.Count -eq 0) { throw '未找到任何备份文件，无法还原' }
  $restoreNotes = @()
  # 按「新→旧」展开成一张操作表（每份内部仍逆序执行）
  $flat = New-Object System.Collections.Generic.List[object]
  foreach ($f in $files) {
    $b = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
    $cur = @($b.Ops); [array]::Reverse($cur)
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
  # 先算出「还原全部完成后最终生效的方案」：pcfg 残留有没有实际影响只取决于它，而不是
  # 方案是否为工具自建。还原是逆序执行的——pcfg 项执行时活动方案还没切回去（卓越性能
  # 仍是活动方案），所以绝不能在循环里用「当前是否活动」判断。合并去重后 power 项至多
  # 一条且取自最早备份，其 Old 就是优化前的真原方案；没有 power 项则维持当前活动方案
  $finalSchemeGuid = $null
  foreach ($o in $ops) { if ($o.Kind -eq 'power' -and $o.Old) { $finalSchemeGuid = "$($o.Old)"; break } }
  if (-not $finalSchemeGuid) { $a = Get-ActiveScheme; if ($a) { $finalSchemeGuid = $a.Guid } }
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
          # 复用 Apply 方向的 Invoke-SchemeActivate：powercfg /setactive 失败只写 stderr
          # 不抛终止错误（实机踩过被静默当成成功），必须回读确认，失败如实计入 Failed
          if ($op.Old) {
            if (-not (Invoke-SchemeActivate "$($op.Old)")) {
              throw "切回原电源方案失败$(if ($script:LastActivateOut) { "（powercfg 原话：$script:LastActivateOut）" } else { '' })"
            }
            $restored++
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
                # 默认表里只有三个内置方案 GUID，duplicatescheme 出来的方案（含工具自建、
                # 也含用户/别的工具复制出来的卓越性能）都读不到默认值。残留显式值有没有
                # 实际影响只看它是否留在最终生效方案里——实机踩过「按名字匹配激活的卓越
                # 方案」被原先的工具自建判定漏掉、误报还原失败；最终方案判定天然覆盖工具
                # 自建方案。真留在生效方案里才如实报错，且必须给人话（OpenSubKey 的原始
                # 异常「不允许所请求的注册表访问权」用户完全无法定位）
                if ($finalSchemeGuid -and ($guid -ine $finalSchemeGuid)) {
                  $skippedOps += "$(Get-RestoreOpLabel $op)：跳过（残留设置在还原后不生效的方案里，对当前无影响；若以后手动切回该方案会重新用上这些值，不需要可在控制面板→电源选项里删除该方案）"
                } else {
                  throw "无法清除该方案里的残留显式值（此注册表键仅系统账户可写，且该方案查不到默认值），该值仍留在还原后生效的方案（$guid）中"
                }
              }
            }
          } else {
            Set-PowerSettingAc $op.Sub $op.Setting ([int]$op.OldValue) "$($op.SchemeGuid)"
            $restored++
          }
        }
        'mmagent' { Set-MMAgentState $op.Feature ([bool]$op.OldEnabled); $restored++ }
        'sched'   { & schtasks /Delete /TN $op.TaskName /F 2>&1 | Out-Null; $restored++ }
        'hib'     { Set-HibernateEnabled ([bool]$op.OldEnabled); $restored++ }
        'bcd'     {
          if ($op.OldValue -eq 'absent') { Remove-BcdEntryValue $op.Name } else { Set-BcdEntryValue $op.Name $op.OldValue }
          $restored++
        }
        # 备份里存的是应用前的整文件原始字节，逐字节写回即完全复原（含编码/BOM/格式）
        'file'    { [IO.File]::WriteAllBytes($op.Path, [Convert]::FromBase64String($op.OrigB64)); $restored++ }
        'reg'     {
          if ($op.Path -like 'HKLM:*' -and -not (Test-Admin)) { throw '需要管理员权限' }
          if ($op.Existed) {
            # JSON 往返后二进制/多字符串会变成普通数组，必须转回强类型才能写回注册表
            $val = $op.OldValue
            if ($op.OldKind -eq 'Binary') { $val = [byte[]]@($val) }
            elseif ($op.OldKind -eq 'MultiString') { $val = [string[]]@($val) }
            Set-RegValue $op.Path $op.Name $val $op.OldKind
          } else { Remove-RegValue $op.Path $op.Name }
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
  # 全部成功才给消费过的备份打 .restored 后缀（不再匹配 backup-*.json）；有失败保留原名，
  # 修复权限后可整体重试（重写旧值幂等无害）。改名失败不算还原失败，但必须提示：
  # 不标记的话下次还原会把这些旧值再写回系统
  if (@($failed).Count -eq 0) {
    foreach ($f in $files) {
      try { Rename-Item -LiteralPath $f -NewName ((Split-Path -Leaf $f) + '.restored') -ErrorAction Stop }
      catch { $restoreNotes += "备份「$(Split-Path -Leaf $f)」已还原但标记失败（$($_.Exception.Message)），下次还原前请手动将其移出 backup 目录" }
    }
  }
  [pscustomobject]@{ File = $files[0]; Files = $files; MergedCount = @($files).Count
                     RestoredOps = $restored; Failed = $failed; Skipped = $skippedOps; Notes = $restoreNotes }
}

# ---------- 输出 ----------

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
  $r = Invoke-Restore $BackupFile
  if ($Json) { $r | ConvertTo-Json -Depth 4 }
  else {
    if ($r.MergedCount -gt 1) { Write-Output "已合并 $($r.MergedCount) 份备份，共还原 $($r.RestoredOps) 项改动（同一设置以最早备份的原值为准）" }
    else { Write-Output "已按备份还原 $($r.RestoredOps) 项改动（备份：$($r.File)）" }
    foreach ($f in $r.Failed) { Write-Output "  [还原失败] $f" }
    foreach ($s in $r.Skipped) { Write-Output "  [还原跳过] $s" }
    foreach ($n in $r.Notes) { Write-Output "  [提示] $n" }
  }
}
