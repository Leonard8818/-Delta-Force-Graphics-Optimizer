<#
  DeltaForceBooster 诊断脚本 — v0.3
  用途：优化后有项目没变成「已就绪」时，跑这个把真实原因打出来。
  除「电源项写入自检」（写回原值、不留改动）外全部只读。请用管理员身份运行
  （很多项非管理员读不到）。

  用法：右键「以管理员身份运行 PowerShell」，然后：
    powershell -NoProfile -ExecutionPolicy Bypass -File <本文件路径>
  （-ExecutionPolicy Bypass 不能省：下载解压的脚本带网络标记，默认策略会拒绝运行）
  把完整输出复制回来即可。

  v0.3：跟进引擎 v0.7——「读不到当前值」不再是异常（方案无显式值即继承默认），
        该情形下改用「写目标值 → 删设置子键回继承」做真实写入自检，同样不留改动。
  v0.2：当前值读不到时跳过目标值试写（避免试写成功后无值可还原，在用户机上留下改动）；
        新增激活方案交叉核对（注册表 vs powercfg）、模板激活自检、显示名解析自检。
#>
#requires -Version 5.1
. (Join-Path $PSScriptRoot 'delta-booster.ps1')
# 必须放在点源之后：引擎自己会把 $ErrorActionPreference 设成 Stop，先设会被覆盖，
# 诊断脚本里任何 powercfg 的 stderr 都会直接终止整个诊断（实测踩过）
$ErrorActionPreference = 'Continue'

function Line([string]$t) { Write-Output ""; Write-Output "===== $t =====" }

Line '基本信息'
$hw = Get-HardwareInfo
"系统   : $($hw.OS) Build $($hw.Build)"
"CPU    : $($hw.CPU)（$($hw.Cores) 核 $($hw.Threads) 线程）"
"机型   : $(if ($hw.IsLaptop) { '笔记本' } else { '台式机' })"
"管理员 : $(if ($hw.IsAdmin) { '是' } else { '否 —— 请以管理员重跑，否则下面很多项读不到' })"

Line '电源方案（power-ultimate 失败时看这里）'
$root = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
$activeGuid = Get-RegValue $root 'ActivePowerScheme'
"活动方案 GUID（注册表）: $activeGuid"
# 交叉核对：powercfg 视角的活动方案。两边不一致说明注册表读取路径有问题
$pcOut = & powercfg /getactivescheme 2>&1
"活动方案（powercfg 原话）: $("$pcOut".Trim())"
"卓越性能模板(e9a42b02…)注册表键: $(if (Test-Path "$root\e9a42b02-d5df-448d-aa00-03f14749eb61") { '存在' } else { '不存在 —— 需要 duplicatescheme 创建' })"
"工具自建方案 GUID 记录(config\power-scheme.json): $(if (Get-Command Get-ToolSchemeGuid -EA SilentlyContinue) { $g0 = Get-ToolSchemeGuid; if ($g0) { $g0 } else { '（无记录）' } } else { '（引擎版本过旧，无此功能）' })"
Write-Output "--- 全部方案（原始 FriendlyName / 解析后显示名）---"
$base, $sub = Split-RegPath $root
$k = $base.OpenSubKey($sub)
try {
  foreach ($g in $k.GetSubKeyNames()) {
    if ($g -notmatch "^$script:GuidRx$") { continue }
    $fn = Get-RegValue "$root\$g" 'FriendlyName'
    "  $g$(if ($g -ieq "$activeGuid") { '   ← 当前活动' })"
    "      原始 : [$fn]"
    "      显示 : [$(Get-SchemeDisplayName $fn)]"
  }
} finally { $k.Close() }

Line '模板激活自检（判定 e9a42b02 是否为「不可直接激活的模板」）'
# 关键疑点：多数非工作站版 Windows 上卓越性能只是模板，注册表可见但 setactive 会失败。
# 先试激活模板本身，把 powercfg 原话打出来，再立刻切回原方案，不留改动
if ($activeGuid -and (Test-Path "$root\e9a42b02-d5df-448d-aa00-03f14749eb61")) {
  $t1 = & powercfg /setactive 'e9a42b02-d5df-448d-aa00-03f14749eb61' 2>&1
  $nowG = Get-RegValue $root 'ActivePowerScheme'
  "直接激活模板: exit=$LASTEXITCODE 输出=[$("$t1".Trim())]"
  "激活后回读 ActivePowerScheme: $nowG $(if ("$nowG" -ieq 'e9a42b02-d5df-448d-aa00-03f14749eb61') { '→ 模板可直接激活' } else { '→ 未切换成功，模板不可直接激活（需 duplicatescheme 实例化）' })"
  & powercfg /setactive $activeGuid 2>&1 | Out-Null
  "已切回原方案 $activeGuid（回读: $(Get-RegValue $root 'ActivePowerScheme')）"
} else { '（模板不存在或读不到当前方案，跳过此项自检）' }

Line '显示名解析自检（FriendlyName 各形态）'
foreach ($case in @(
  '@%SystemRoot%\system32\powrprof.dll,-19,Ultimate Performance',
  '@%SystemRoot%\system32\powrprof.dll,-19,卓越性能',
  '@%SystemRoot%\system32\umpo.dll,-4060',
  '我的游戏方案', '4060'
)) { "  [$case] → [$(Get-SchemeDisplayName $case)]" }

Line '电源隐藏项（power-tuning 失败时看这里）'
$probe = @(
  @{ N = 'USB3 链路电源管理';   S = $script:SubUsb;  G = 'd4e98f31-5ffe-4ce1-be31-1b38b384c009'; V = 0 }
  @{ N = '处理器性能时间检查'; S = $script:SubProc; G = '4d2b0152-7d5c-498b-88e2-34345392a2c5'; V = 5000 }
  @{ N = '大小核调度策略';     S = $script:SubProc; G = '93b8b6dc-0698-4d1c-9ee4-0644e900c85d'; V = 1 }
  @{ N = '短任务大小核调度';   S = $script:SubProc; G = 'bae08b81-2d5e-4688-ad6a-13243356654b'; V = 1 }
)
foreach ($p in $probe) {
  $exists = Test-PowerSetting $p.S $p.G
  $hidden = if ($exists) { Test-PowerSettingHidden $p.S $p.G } else { $null }
  $cur    = if ($exists) { Get-PowerSettingAc $p.S $p.G } else { $null }
  "[$($p.N)]"
  "    本机是否存在: $exists    当前隐藏: $hidden    当前值: $cur    目标值: $($p.V)"
  if ($exists) {
    if ($null -eq $cur) {
      # 读不到值 = 方案无显式值且默认表没有该方案（duplicatescheme 出来的方案都这样），
      # 引擎 v0.7 起这是合法的「继承默认」态：写目标值试一次，再删设置子键回到继承，不留改动
      "    未显式设置（继承系统默认）——按引擎 v0.7 语义做写入+删键自检"
      $out2 = & powercfg /setacvalueindex SCHEME_CURRENT $p.S $p.G $p.V 2>&1
      "    写入目标值    : exit=$LASTEXITCODE $(if ($out2) { "输出=$($out2 -join ' ')" } else { '无输出（成功）' })"
      if ($LASTEXITCODE -eq 0) {
        $g1 = Get-RegValue $root 'ActivePowerScheme'
        if ((Get-Command Remove-PowerSettingAcOverride -EA SilentlyContinue) -and $g1) {
          Remove-PowerSettingAcOverride "$g1" $p.S $p.G
          "    已删除显式值子键，回到继承默认态（回读: $(Get-PowerSettingAc $p.S $p.G)，null 即已继承）"
        } else { "    警告：引擎过旧，无法删键还原，方案里留下了显式值 $($p.V)" }
      }
    } else {
      # 直接试一次真实写入，把 powercfg 的原话打出来（写的是当前值本身，等于不改动）
      $out = & powercfg /setacvalueindex SCHEME_CURRENT $p.S $p.G $cur 2>&1
      "    写入自检(写回原值): exit=$LASTEXITCODE $(if ($out) { "输出=$($out -join ' ')" } else { '无输出（正常）' })"
      # 再试目标值，失败会打出确切错误；成功后立刻写回原值，不留改动
      $out2 = & powercfg /setacvalueindex SCHEME_CURRENT $p.S $p.G $p.V 2>&1
      "    写入目标值    : exit=$LASTEXITCODE $(if ($out2) { "输出=$($out2 -join ' ')" } else { '无输出（成功）' })"
      if ($LASTEXITCODE -eq 0) {
        & powercfg /setacvalueindex SCHEME_CURRENT $p.S $p.G $cur 2>&1 | Out-Null
        & powercfg /setactive SCHEME_CURRENT 2>&1 | Out-Null
        "    已还原为原值 $cur"
      }
    }
  }
}

Line '所有优化项当前判定'
foreach ($it in (Get-OptItems (Find-GamePath))) {
  $st = Get-ItemState $it
  $mark = if ($st.Optimized -eq $true) { '已就绪' } elseif ($st.Optimized -eq $false) { '未达标' } else { '待定  ' }
  "[$mark] $($it.Id)"
  "         $($st.Current)"
}

Line '最近一次备份'
$bd = Join-Path (Split-Path -Parent $PSScriptRoot) 'backup'
$last = Get-ChildItem $bd -Filter 'backup-*.json' -File -EA SilentlyContinue | Sort-Object Name -Desc | Select-Object -First 1
if ($last) {
  "文件: $($last.FullName)"
  $b = Get-Content -LiteralPath $last.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  "记录了 $(@($b.Ops).Count) 项改动（还原时会逆序回退这些）"
} else { '没有找到备份文件' }

Write-Output ""
Write-Output "诊断结束。请把以上全部内容复制回去。"
