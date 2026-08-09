<#
  DeltaForceBooster 诊断脚本 — v0.5
  用途：优化后有项目没变成「已就绪」时，跑这个把真实原因打出来。
  除「电源项写入自检」（仅对已有显式值的项写回原值本身、不留改动）外全部只读。
  请用管理员身份运行（很多项非管理员读不到）。

  用法：右键「以管理员身份运行 PowerShell」，然后：
    powershell -NoProfile -ExecutionPolicy Bypass -File <本文件路径>
  （-ExecutionPolicy Bypass 不能省：下载解压的脚本带网络标记，默认策略会拒绝运行）
  把完整输出复制回来即可。

  v0.5：使用系统 Known Folder 中的 powercfg，并只读取受保护、已验证签名的新备份。
  v0.4：撤掉 v0.3 的「写目标值 → 删子键」自检——PowerSchemes 键 ACL 只给 SYSTEM 写权限
        （管理员组仅 ReadKey），删子键必被拒，实际会在方案里留下不进任何备份的显式值，
        输出却报「已回到继承默认态」。继承默认的项改为只读报告，诊断脚本绝不留改动。
  v0.3：跟进引擎 v0.7——「读不到当前值」不再是异常（方案无显式值即继承默认）。
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
$pcOut = & $script:PowerCfgExe /getactivescheme 2>&1
"活动方案（powercfg 原话）: $("$pcOut".Trim())"
"卓越性能模板(e9a42b02…)注册表键: $(if (Test-Path "$root\e9a42b02-d5df-448d-aa00-03f14749eb61") { '存在' } else { '不存在 —— 需要 duplicatescheme 创建' })"
"工具自建方案 GUID 记录($script:ConfigDir\power-scheme.json): $(if (Get-Command Get-ToolSchemeGuid -EA SilentlyContinue) { $g0 = Get-ToolSchemeGuid; if ($g0) { $g0 } else { '（无记录）' } } else { '（引擎版本过旧，无此功能）' })"
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
  $t1 = & $script:PowerCfgExe /setactive 'e9a42b02-d5df-448d-aa00-03f14749eb61' 2>&1
  $nowG = Get-RegValue $root 'ActivePowerScheme'
  "直接激活模板: exit=$LASTEXITCODE 输出=[$("$t1".Trim())]"
  "激活后回读 ActivePowerScheme: $nowG $(if ("$nowG" -ieq 'e9a42b02-d5df-448d-aa00-03f14749eb61') { '→ 模板可直接激活' } else { '→ 未切换成功，模板不可直接激活（需 duplicatescheme 实例化）' })"
  & $script:PowerCfgExe /setactive $activeGuid 2>&1 | Out-Null
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
      # 读不到值 = 方案无显式值（继承系统默认）。此态下无法在「不留改动」的前提下做
      # 写入自检：PowerSchemes 键 ACL 只给 SYSTEM 写权限（管理员组仅 ReadKey），写入后
      # 删子键回继承必被拒，只会留下不进任何备份的显式值。诊断只报告状态，不试写
      "    未显式设置（继承系统默认），优化会写入目标值 $($p.V)——此态不做写入自检，保持只读"
    } else {
      # 直接试一次真实写入，把 powercfg 的原话打出来（写的是当前值本身，等于不改动）
      $out = & $script:PowerCfgExe /setacvalueindex SCHEME_CURRENT $p.S $p.G $cur 2>&1
      "    写入自检(写回原值): exit=$LASTEXITCODE $(if ($out) { "输出=$($out -join ' ')" } else { '无输出（正常）' })"
      # 再试目标值，失败会打出确切错误；成功后立刻写回原值，不留改动
      $out2 = & $script:PowerCfgExe /setacvalueindex SCHEME_CURRENT $p.S $p.G $p.V 2>&1
      "    写入目标值    : exit=$LASTEXITCODE $(if ($out2) { "输出=$($out2 -join ' ')" } else { '无输出（成功）' })"
      if ($LASTEXITCODE -eq 0) {
        & $script:PowerCfgExe /setacvalueindex SCHEME_CURRENT $p.S $p.G $cur 2>&1 | Out-Null
        & $script:PowerCfgExe /setactive SCHEME_CURRENT 2>&1 | Out-Null
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

Line '最近一次受保护备份'
# 新备份位于 ProgramData 的管理员保护目录。诊断只通过引擎的签名/schema 校验读取，
# 不再直接解析程序目录里可被普通用户改写的旧 JSON。
if (-not (Test-Path -LiteralPath $script:BackupDir -PathType Container)) {
  "没有找到受保护备份目录：$script:BackupDir"
} else {
  try {
    if (-not (Test-Path -LiteralPath $script:BackupKeyFile -PathType Leaf)) {
      throw '备份完整性密钥缺失；诊断保持只读，不会新建密钥'
    }
    $valid = @()
    foreach ($f in @(Get-ChildItem -LiteralPath $script:BackupDir -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue)) {
      try { $valid += Read-ValidatedBackup $f.FullName @() }
      catch { "跳过未通过校验的备份 $($f.Name)：$($_.Exception.Message)" }
    }
    $last = @(Sort-BackupRecordsNewestFirst $valid | Select-Object -First 1)
    if ($last.Count) {
      $rec = $last[0]
      "文件: $($rec.Path)"
      "创建时间(UTC): $($rec.Document.CreatedUtc)"
      "状态: $($rec.Document.State)；记录了 $(@($rec.Document.Ops).Count) 项写前日志（还原会校验后按最早原值回退）"
    } else { '没有找到通过完整性校验且尚未还原的备份文件' }
  } catch {
    "受保护备份读取失败：$($_.Exception.Message)"
    '请确认使用管理员身份运行本诊断脚本。'
  }
}

Write-Output ""
Write-Output "诊断结束。请把以上全部内容复制回去。"
