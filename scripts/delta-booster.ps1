<#
  DeltaForceBooster 核心脚本 — v0.6
  三角洲行动 一键画面/帧率优化：硬件检测 + Windows 系统优化 + 显卡驱动指引。
  v0.6：移除「关闭引导虚拟化」（ACE 反作弊已开始检查虚拟化状态，关掉会导致游戏报错）；
        新增 MMCSS 游戏档位、关闭窗口化游戏优化（复合串只改目标子键）、VC++ 运行库体检、
        内存 XMP 体检；检测类项目改为按 Check 字段分发，新增检测项不再需要改分发逻辑。
  v0.5：Invoke-Apply 支持进度回调（不传则行为不变）；电源计划创建/激活逐步查退出码并
        带回 powercfg 原始错误；工具自建方案改用专属名「三角洲优化 · 卓越性能」并记录
        GUID 到 config\（防与用户自建方案混淆、防重复堆方案）；power-tuning 逐项容错。
  v0.4：新增 MPO/服务精简/休眠/MMCSS/显卡锁频/中断绑核/PCIe 体检/BCD/虚拟内存等 12 项，
        预设方案按「费利克斯Fx」调试路线重组（电源→优先级→中断→精简→驱动层）。

  用法（任意 AI 助手或用户均可直接调用）：
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Detect [-Json]
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Preview
    powershell -NoProfile -ExecutionPolicy Bypass -File delta-booster.ps1 -Apply [-Items id1,id2] [-GamePath "游戏exe路径"] [-Risky]
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

# 读当前活动方案下该项的交流电(AC)取值。直接读注册表而不用 powercfg /q：
# 隐藏项 /q 不输出，且中文系统输出无法用英文关键字解析。
# 方案未显式设值时回落到该项的默认值，这才是系统实际生效的值。
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

# 解除隐藏，返回原 Attributes 值供还原用；已可见则返回 $null
function Show-PowerSetting([string]$Sub, [string]$Setting) {
  if (-not (Test-PowerSettingHidden $Sub $Setting)) { return $null }
  $old = Get-RegValue "$script:PsRoot\$Sub\$Setting" 'Attributes'
  $ErrorActionPreference = 'SilentlyContinue'
  $out = & powercfg -attributes $Sub $Setting -ATTRIB_HIDE 2>&1
  if ($LASTEXITCODE -ne 0) { throw "解除电源项隐藏失败$(if ("$out") { "（powercfg 原话：$(("$out").Trim())）" } else { '（需要管理员权限）' })" }
  $old
}

function Set-PowerSettingAc([string]$Sub, [string]$Setting, [int]$Value) {
  $ErrorActionPreference = 'SilentlyContinue'
  # 把 powercfg 的原话带进异常：曾有 12 代机器报「尝试写入不受支持的设置」，
  # 只抛笼统的「写入失败」会让用户完全没法定位
  $out = & powercfg /setacvalueindex SCHEME_CURRENT $Sub $Setting $Value 2>&1
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

# 显卡中断绑核（微软文档：Interrupt Management\Affinity Policy，DevicePolicy=4 即
# IrqPolicySpecifiedProcessors，AssignmentSetOverride 为 KAFFINITY 掩码、REG_BINARY 小端）。
# 掩码取编号最大的 P 核（同构机型即最后一个物理核）的全部逻辑处理器：
# 避开默认承接大量系统中断的 CPU0，又保持 ISR/DPC 固定在同一物理核上缓存友好。
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

# PCIe 链路体检（纯读取）。只看"最大能力"：空闲时当前速率降到 x8 1.1 是正常省电，
# 上限本身只有 x8/x4 才说明插错槽/延长线劣质，这种问题白丢帧且没有软件能修
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

# VC++ 2015-2022(v14) 运行库错乱是 2026-07 游戏更新后的高发问题。只看 v14 系：
# 更早的 2010/2012/2013 是各自独立的运行库，多版本共存本来就正常，不该报警。
function Get-VcRedistStatus {
  $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $all = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -match 'Visual C\+\+' -and $_.DisplayVersion -match '^14\.' })
  if ($all.Count -eq 0) {
    return @{ Ok = $false; Text = '未检测到 VC++ 2015-2022(v14) 运行库 —— 游戏很可能无法启动，建议装一次' }
  }
  # 同一批运行库的 x64/x86 应当是同一个次版本；错开说明某次安装只覆盖了一半
  $minors = @($all | ForEach-Object { if ($_.DisplayVersion -match '^(14\.\d+)') { $Matches[1] } } |
              Select-Object -Unique | Sort-Object)
  $verList = ($minors -join ' / ')
  if ($minors.Count -gt 1) {
    return @{ Ok = $false
              Text = "检测到 v14 运行库版本不一致（$verList）—— 这正是掉帧/闪退的常见原因。建议到微软官网下载最新 VC++ 2015-2022 x64 与 x86 各装一遍覆盖修复" }
  }
  @{ Ok = $true; Text = "v14 运行库版本一致（$verList，共 $($all.Count) 个组件），正常" }
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
  # 双显卡（核显+独显）机器以独显为主，驱动指引按独显给
  $main = ($gpus | Where-Object { $_.Vendor -in 'NVIDIA','AMD' } | Select-Object -First 1)
  if (-not $main) { $main = $gpus | Select-Object -First 1 }

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
  # 三角洲行动国服走 WeGame，国际服(Delta Force)走 Steam；两边都找，找不到就让用户手动指
  $exeNames = 'DeltaForceClient-Win64-Shipping.exe', 'DeltaForce.exe'
  $roots = New-Object System.Collections.Generic.List[string]

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

  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
    foreach ($guess in 'WeGame', 'WeGameApps', 'Program Files\WeGame') {
      $p = Join-Path $d.Root $guess
      if (Test-Path -LiteralPath $p) { $roots.Add($p) }
    }
  }

  $found = @()
  foreach ($r in ($roots | Select-Object -Unique)) {
    foreach ($n in $exeNames) {
      $found += @(Get-ChildItem -Path $r -Recurse -Depth 6 -Filter $n -File -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)
    }
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

function Get-OptItems([string]$GamePath) {
  $items = @()
  $hw = $null
  try { $hw = Get-HardwareInfo } catch {}
  $exeName = $(if ($GamePath) { Split-Path -Leaf $GamePath } else { $null })

  # ===== safe 档：默认推荐，不降低系统安全性 =====

  $items += @{ Id = 'power-ultimate'; Tier = 'safe'; Name = '电源计划切换到「卓越性能」'; Admin = $true; Default = $true; Kind = 'power'
               Note = '解除系统对 CPU 频率的保守限制。台式机收益明显；笔记本电池续航会变差。' }

  # 电源计划隐藏项：控制面板里看不到，必须用 powercfg 直接写
  $items += @{ Id = 'power-tuning'; Tier = 'safe'; Name = '电源计划隐藏项深度调优（USB/调度/时间片）'; Admin = $true; Default = $true; Kind = 'multi'
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

  $items += @{ Id = 'hags'; Tier = 'safe'; Name = '开启硬件加速 GPU 计划（HAGS）'; Admin = $true; Default = $true; Kind = 'multi'
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

  $items += @{ Id = 'paging-exec'; Tier = 'safe'; Name = '内核代码常驻内存（DisablePagingExecutive）'; Admin = $true; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'DisablePagingExecutive'; Value = 1; Kind2 = 'DWord' })
               Note = '禁止内核代码被换出到硬盘，减少卡顿尖峰。内存 8G 以下不建议。' }

  $items += @{ Id = 'wer-off'; Tier = 'safe'; Name = '关闭 Windows 错误报告'; Admin = $false; Default = $true; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Value = 1; Kind2 = 'DWord' })
               Note = '游戏崩溃瞬间不再收集转储，避免二次卡死。' }

  # 内存压缩：16G 以下关掉反而更容易爆内存，默认只在 32G 及以上勾选
  $bigRam = ($hw -and $hw.RamGB -ge 32)
  $items += @{ Id = 'mem-compress-off'; Tier = 'safe'; Name = '关闭内存压缩与页面合并'; Admin = $true; Default = $bigRam; Kind = 'multi'
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

  # ===== v0.4 新增：费利克斯路线补齐 =====

  $items += @{ Id = 'mpo-off'; Tier = 'safe'; Name = '禁用 MPO 多平面叠加（治闪烁/卡顿）'; Admin = $true; Default = $true; Kind = 'multi'
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

  $items += @{ Id = 'sysmain-off'; Tier = 'safe'; Name = '禁用 SysMain 预取服务'; Admin = $true; Default = $false; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain'; Name = 'Start'; Value = 4; Kind2 = 'DWord'; Label = 'SysMain 启动类型（4=禁用）' })
               Note = 'SysMain（旧名 Superfetch）后台预读抢内存和磁盘带宽，SSD 上收益存疑。副作用：常用程序冷启动可能略变慢，默认不勾选。重启后彻底停止。' }

  $items += @{ Id = 'wsearch-off'; Tier = 'safe'; Name = '禁用 Windows Search 索引服务'; Admin = $true; Default = $false; Kind = 'multi'
               Ops  = @(@{ Kind = 'reg'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch'; Name = 'Start'; Value = 4; Kind2 = 'DWord'; Label = 'WSearch 启动类型（4=禁用）' })
               Note = '索引器后台扫盘占 IO。副作用明显：开始菜单和资源管理器搜索会变慢（现场逐盘找），只推荐给从不用系统搜索的人，默认不勾选。重启生效。' }

  $items += @{ Id = 'hibernate-off'; Tier = 'safe'; Name = '关闭休眠与快速启动'; Admin = $true
               Default = [bool]($hw -and -not $hw.IsLaptop); Kind = 'multi'
               Ops  = @(@{ Kind = 'hib'; Label = '休眠' })
               Note = '释放 C 盘数 GB 的 hiberfil.sys，并消除快速启动"假关机"导致的状态残留。副作用：休眠与快速启动都不可用，笔记本合盖只剩睡眠，故只在台式机默认勾选。' }

  $gpuClass = Get-GpuClassKeyPath $hw
  $items += @{ Id = 'gpu-pstate-lock'; Tier = 'safe'; Name = '禁止显卡动态降频（锁 P-State）'; Admin = $true; Default = $false; Kind = 'multi'
               Ops  = $(if ($gpuClass) { @(@{ Kind = 'reg'; Path = $gpuClass; Name = 'DisableDynamicPstate'; Value = 1; Kind2 = 'DWord' }) })
               Note = '阻止驱动随负载波动来回降频，减少频率抖动带来的帧率毛刺。副作用：待机功耗和发热明显上升、笔记本续航变差，默认不勾选。重启生效。' }

  $items += @{ Id = 'gpu-irq-affinity'; Tier = 'safe'; Name = '显卡中断绑核（费利克斯手法）'; Admin = $true; Default = $false; Kind = 'multi'
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

  $items += @{ Id = 'vcredist-check'; Tier = 'safe'; Name = 'VC++ 运行库冲突体检（纯检测，不改设置）'; Admin = $false; Default = $false; Kind = 'check'
               Check = 'Get-VcRedistStatus'
               Note = '2026 年 7 月底游戏更新后的高发问题：VC++ 2015-2022(v14) 运行库版本错乱会让帧数从 300 掉到 100 甚至闪退。本项只检测不修——卸载重装运行库会波及其他软件，须你自己判断后手动处理。' }

  $items += @{ Id = 'xmp-check'; Tier = 'safe'; Name = '内存 XMP/EXPO 体检（纯检测，不改设置）'; Admin = $false; Default = $false; Kind = 'check'
               Check = 'Get-MemoryXmpStatus'
               Note = '内存没开 XMP/EXPO 时会跑在 JEDEC 保守频率上，白白损失几十帧。BIOS 设置无法由软件修改，本项只负责把"你的内存在摸鱼"这件事告诉你。' }

  $items += @{ Id = 'dyntick-off'; Tier = 'safe'; Name = '禁用动态计时器（bcdedit）'; Admin = $true; Default = $false; Kind = 'multi'
               Ops  = @(@{ Kind = 'bcd'; Name = 'disabledynamictick'; Value = 'yes'; Label = '动态计时器' })
               Note = '恢复固定时钟中断，部分机器帧生成间隔更稳。副作用：空闲功耗略升、笔记本续航变差，默认不勾选。重启生效。' }

  # 费利克斯公式：初始=内存GB×1024×1.5、最大=×2；他本人也只在闪退/卡死时才建议改
  $ramInt = $(if ($hw) { [int][math]::Round($hw.RamGB) } else { 0 })
  $items += @{ Id = 'pagefile-custom'; Tier = 'safe'; Name = "虚拟内存固定为 $([int]($ramInt * 1.5))–$($ramInt * 2) GB"; Admin = $true; Default = $false; Kind = 'multi'
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
# 列表顺序即界面下拉顺序：费利克斯路线排第一位作为主推方案。
function Get-BuiltinPresets {
  @(
    [pscustomobject]@{
      # Items 顺序刻意按费利克斯的调试链路排列：
      # ①电源深度定制（一切的前置）→ ②进程/IO 优先级 → ③中断绑核 → ④系统精简 → ⑤显卡驱动层
      Id = 'felix'; Name = '费利克斯路线（主推全套）'; Builtin = $true
      Note = '按费利克斯Fx 的调试顺序全套执行：电源→优先级→中断绑核→系统精简→显卡层。代价：鼠标手感变直、休眠/快速启动没了、Windows 搜索变慢、待机功耗升高（笔记本更耗电）。不关引导虚拟化，WSL/模拟器不受影响。'
      Items = @('power-ultimate','power-tuning','powerplan-lock',
                'prio-separation','game-priority','sys-responsiveness','mmcss-games','net-throttling-off','game-mode',
                'gpu-irq-affinity',
                'dvr-off','wer-off','sysmain-off','wsearch-off','hibernate-off','mem-compress-off',
                'paging-exec','transparency-off','mpo-off','dyntick-off','mouse-accel-off',
                'hags','fso-off','gpu-pref','gpu-pstate-lock','nvidia-profile',
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
      if ($null -eq $v) { return @{ Ok = $false; Text = "$($Op.Label)=读取失败" } }
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

# ---------- 显卡驱动指引（无法安全脚本化的部分，给出精确手动步骤） ----------

function Get-GpuGuideText([string]$Vendor) {
  switch ($Vendor) {
    'NVIDIA' { @(
      '【N 卡驱动设置 — 手动 2 分钟】'
      '打开 NVIDIA 控制面板 → 管理 3D 设置 → 程序设置 → 添加「三角洲行动」，逐项设置：'
      '  1. 电源管理模式 = 最高性能优先'
      '  2. 低延迟模式 = 超高'
      '  3. 垂直同步 = 关（改用游戏内帧率上限，设为略低于显示器刷新率）'
      '  4. 着色器缓存大小 = 无限制'
      '  5. 线程优化 = 开'
      '  6. 最大预渲染帧数 = 1'
      '【重要】NVIDIA App → 设置 → 关闭「自动优化新添加的游戏及应用程序」'
      '        它开着会自动覆写你游戏内的画质设置，等于白调。此开关无法脚本化，只能手动关。'
      '游戏内：开启 NVIDIA Reflex（开+加速）；帧数不够时开 DLSS（画质/平衡档）。'
      '进阶：NVIDIA App → 图形 → 三角洲行动 → DLSS 模型预设 → 选 Preset K；'
      '      或下载 NVIDIA Profile Inspector 放入本工具 tools\ 目录后一键导入。'
    ) -join "`n" }
    'AMD' { @(
      '【A 卡驱动设置 — 手动 2 分钟】'
      '打开 AMD Software (Adrenalin) → 游戏 → 三角洲行动，逐项设置：'
      '  1. Radeon Anti-Lag = 开'
      '  2. Radeon Chill / Boost = 关'
      '  3. 等待垂直刷新 = 关闭，除非应用程序指定'
      '  4. 纹理过滤质量 = 性能'
      '  5. 表面格式优化 = 开'
      '游戏内：帧数不够时开启 FSR（质量/平衡档）。'
    ) -join "`n" }
    'Intel' { @(
      '【Intel 显卡】性能上限有限，建议：游戏内画质预设调最低 + 开启 XeSS/FSR 超分，'
      '并确认已安装最新 Intel Arc/核显驱动。'
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
    GpuGuide = Get-GpuGuideText $hw.MainGpuVendor
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
      Set-RegValue $Op.Path $Op.Name $newVal $Op.Kind2
      $BackupOps.Value += @{ Kind = 'reg'; Path = $Op.Path; Name = $Op.Name
                             Existed = ($null -ne $oldKind); OldValue = $oldVal; OldKind = "$oldKind" }
    }
    'pcfg' {
      if (-not (Test-PowerSetting $Op.Sub $Op.Setting)) {
        if ($Op.Optional) { return "跳过（本机 CPU 无此电源项）：$($Op.Label)" }
        throw "本机不支持该电源项：$($Op.Label)"
      }
      $old = Get-PowerSettingAc $Op.Sub $Op.Setting
      if ($null -eq $old) { throw "无法读取当前值：$($Op.Label)" }
      # 隐藏项必须先解除隐藏才能写入；原 Attributes 按普通注册表值备份，还原时自动改回
      $oldAttr = Show-PowerSetting $Op.Sub $Op.Setting
      if ($null -ne $oldAttr) {
        $BackupOps.Value += @{ Kind = 'reg'; Path = "$script:PsRoot\$($Op.Sub)\$($Op.Setting)"; Name = 'Attributes'
                               Existed = $true; OldValue = $oldAttr; OldKind = 'DWord' }
      }
      Set-PowerSettingAc $Op.Sub $Op.Setting $Op.Value
      $BackupOps.Value += @{ Kind = 'pcfg'; Sub = $Op.Sub; Setting = $Op.Setting; OldValue = $old }
    }
    'mmagent' {
      $old = Get-MMAgentState $Op.Feature
      if ($null -eq $old) { throw "无法读取 $($Op.Label) 当前状态" }
      Set-MMAgentState $Op.Feature $false
      $BackupOps.Value += @{ Kind = 'mmagent'; Feature = $Op.Feature; OldEnabled = $old }
    }
    'kvstr' {
      # 整串备份、只改目标子键：这个值里还住着 AutoHDREnable 等别人的设置，整串覆盖会误伤
      $oldKind = Get-RegValueKind $Op.Path $Op.Name
      $oldRaw  = $(if ($null -ne $oldKind) { Get-RegValue $Op.Path $Op.Name } else { $null })
      Set-RegValue $Op.Path $Op.Name (Set-KvStringItem $oldRaw $Op.Key $Op.Value) 'String'
      $BackupOps.Value += @{ Kind = 'reg'; Path = $Op.Path; Name = $Op.Name
                             Existed = ($null -ne $oldKind); OldValue = $oldRaw; OldKind = "$oldKind" }
    }
    'hib' {
      $old = Get-HibernateState
      Set-HibernateEnabled $false
      $BackupOps.Value += @{ Kind = 'hib'; OldEnabled = [bool]$old }
    }
    'bcd' {
      $old = Get-BcdValue $Op.Name
      if ($null -eq $old) { throw "无法读取引导配置（需要管理员权限）：$($Op.Label)" }
      Set-BcdEntryValue $Op.Name $Op.Value
      # OldValue='absent' 表示原本未设置，还原时删除该值而不是写回字符串
      $BackupOps.Value += @{ Kind = 'bcd'; Name = $Op.Name; OldValue = $old }
    }
    default { throw "未知操作类型：$($Op.Kind)" }
  }
  $null
}

# $Progress 为可选进度回调（不传时行为与旧版完全一致，CLI 与 SKILL.md 契约不受影响）：
# 每项开始时以 Stage='start' 调用一次（带 Index/Total/Name），完成时以 Stage='done'
# 再调一次（额外带该项的 Result），GUI 靠它做进度条与实时日志
function Invoke-Apply([string[]]$ItemIds, [string]$GamePath, [bool]$AllowRisky, [scriptblock]$Progress) {
  # powershell -File 不会把 "a,b" 解析成数组，整串会当成单个元素传进来，这里统一拆开
  $ItemIds = @($ItemIds | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if (-not $GamePath) { $GamePath = Find-GamePath }
  $items = Get-OptItems $GamePath
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
  $total = $sel.Count; $seq = 0
  foreach ($it in $sel) {
    $seq++
    if ($Progress) { & $Progress ([pscustomobject]@{ Stage = 'start'; Index = $seq; Total = $total; Name = $it.Name; Result = $null }) }
    try {
      if ($it.Kind -eq 'power') {
        $old = (Get-ActiveScheme).Guid
        $ps = Enable-UltimateScheme
        # ToolCreated 进备份：还原逻辑据此区分「原本就存在的方案」与「本工具新建的方案」
        $backupOps += @{ Kind = 'power'; Old = $old; ToolCreated = [bool]$ps.Created; NewGuid = $ps.Guid }
        $msg = $(if ($ps.Created) { "已创建「$script:ToolSchemeName」并激活（还原后该方案会保留，可手动删除）" }
                 else { '已切换到卓越性能方案' })
        if ($ps.Note) { $msg += "；$($ps.Note)" }
        $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = $true; Skipped = $false; Msg = $msg }
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
        # 纯检测项：把检测结论当作执行结果输出，绝不写任何东西
        $st = & $it.Check
        $results += [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Ok = ($st.Ok -ne $false); Skipped = $false; Msg = "纯检测：$($st.Text)" }
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
            try {
              $n = Invoke-ApplyOp $op $it.Id ([ref]$backupOps)
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
    if ($Progress) { & $Progress ([pscustomobject]@{ Stage = 'done'; Index = $seq; Total = $total; Name = $it.Name; Result = $results[-1] }) }
  }

  $bf = $null
  if ($backupOps.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $script:BackupDir)) { New-Item -ItemType Directory -Path $script:BackupDir | Out-Null }
    $bf = Join-Path $script:BackupDir ("backup-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))
    @{ Time = (Get-Date).ToString('s'); Ops = $backupOps } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $bf -Encoding UTF8
  }
  [pscustomobject]@{ Results = $results; Backup = $bf }
}

function Invoke-Restore([string]$File) {
  if (-not $File) {
    $File = Get-ChildItem $script:BackupDir -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $File) { throw '未找到任何备份文件，无法还原' }
  $b = Get-Content -LiteralPath $File -Raw -Encoding UTF8 | ConvertFrom-Json
  $ops = @($b.Ops); [array]::Reverse($ops)
  $restored = 0; $failed = @(); $restoreNotes = @()
  foreach ($op in $ops) {
    try {
      switch ($op.Kind) {
        'power'   {
          if ($op.Old) { powercfg /setactive $op.Old | Out-Null; $restored++ }
          # 工具自建的方案保留不删：用户可能已经在用它，静默删除是破坏性动作
          if ($op.ToolCreated) {
            $restoreNotes += "工具创建的电源计划「$script:ToolSchemeName」已保留，如不需要可在控制面板→电源选项里手动删除"
          }
        }
        'pcfg'    { Set-PowerSettingAc $op.Sub $op.Setting ([int]$op.OldValue); $restored++ }
        'mmagent' { Set-MMAgentState $op.Feature ([bool]$op.OldEnabled); $restored++ }
        'sched'   { & schtasks /Delete /TN $op.TaskName /F 2>&1 | Out-Null; $restored++ }
        'hib'     { Set-HibernateEnabled ([bool]$op.OldEnabled); $restored++ }
        'bcd'     {
          if ($op.OldValue -eq 'absent') { Remove-BcdEntryValue $op.Name } else { Set-BcdEntryValue $op.Name $op.OldValue }
          $restored++
        }
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
    } catch { $failed += "$($op.Kind) $($op.Name)$($op.Label)：$($_.Exception.Message)" }
  }
  [pscustomobject]@{ File = $File; RestoredOps = $restored; Failed = $failed; Notes = $restoreNotes }
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
  $r = Invoke-Apply $Items $GamePath ([bool]$Risky)
  if ($Json) { $r | ConvertTo-Json -Depth 5 }
  else {
    foreach ($x in $r.Results) { Write-Output "  $(if ($x.Ok) { '[成功]' } elseif ($x.Skipped) { '[跳过]' } else { '[失败]' }) $($x.Name) — $($x.Msg)" }
    $okN = @($r.Results | Where-Object Ok).Count
    $skipN = @($r.Results | Where-Object { -not $_.Ok -and $_.Skipped }).Count
    $failN = @($r.Results | Where-Object { -not $_.Ok -and -not $_.Skipped }).Count
    Write-Output "执行完成：共 $(@($r.Results).Count) 项 — $okN 成功、$failN 失败、$skipN 跳过。"
    if ($r.Backup) { Write-Output "备份已保存：$($r.Backup)（用 -Restore 可一键还原）" }
    Write-Output "提示：HAGS、电源计划等项重启后完全生效。"
  }
}
elseif ($Restore) {
  $r = Invoke-Restore $BackupFile
  if ($Json) { $r | ConvertTo-Json -Depth 4 }
  else {
    Write-Output "已按备份还原 $($r.RestoredOps) 项改动（备份：$($r.File)）"
    foreach ($f in $r.Failed) { Write-Output "  [还原失败] $f" }
    foreach ($n in $r.Notes) { Write-Output "  [提示] $n" }
  }
}
