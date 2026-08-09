<#
  DeltaForceBooster 自动寻找最佳配置 Beta — 确定性实验与统计规则。

  本模块只负责候选白名单、实验状态、样本有效性和胜负计算；它不执行 PowerShell
  命令、不直接写注册表，也不接受 AI 返回的 itemIds。GUI 只能按 GroupId 查询这里的
  版本化候选库，再调用现有带备份/HMAC/WAL 的优化引擎。
#>
#requires -Version 5.1

$script:TuningSchemaVersion = 1
$script:TuningCandidateLibraryVersion = 1
$script:TuningAllowedStatuses = @(
  'created','baseline_pending','baseline_running','baseline_complete',
  'variant_pending','variant_applied','variant_running','variant_complete',
  'comparing','final_validation','completed','rolled_back','cancelled','failed'
)
$script:TuningAllowedValidity = @('valid','suspect','invalid')
$script:TuningInvalidReasons = @(
  'game_exited','sample_too_short','insufficient_frames','scene_changed',
  'settings_changed','driver_changed','game_version_changed','focus_lost',
  'thermal_anomaly','capture_failed','apply_failed','user_cancelled'
)

function Get-TuningCandidateLibrary {
  # 第一版只有低风险、无需重启、可检测且可由现有备份完整还原的三组。
  # 显卡型号伪装和其他 risky/高级项永远不在这里。
  @(
    [pscustomobject][ordered]@{
      LibraryVersion = $script:TuningCandidateLibraryVersion
      GroupId = 'G1'; VariantId = 'background_low_risk'; DisplayName = '后台与游戏模式'
      ItemIds = @('game-mode','dvr-off'); RiskLevel = 'low'; RequiresReboot = $false; Source = 'rules'
      Purpose = '减少后台录制与系统干扰，优先观察 1% 低帧率和卡顿。'
    }
    [pscustomobject][ordered]@{
      LibraryVersion = $script:TuningCandidateLibraryVersion
      GroupId = 'G2'; VariantId = 'foreground_scheduler'; DisplayName = '前台调度'
      ItemIds = @('prio-separation','game-priority','mmcss-games','net-throttling-off')
      RiskLevel = 'low'; RequiresReboot = $false; Source = 'rules'
      Purpose = '提高游戏 CPU、IO 与多媒体调度优先级，主要观察流畅度。'
    }
    [pscustomobject][ordered]@{
      LibraryVersion = $script:TuningCandidateLibraryVersion
      GroupId = 'G3'; VariantId = 'display_path'; DisplayName = '显示与 GPU 选择'
      ItemIds = @('fso-off','gpu-pref','windowed-opt-off'); RiskLevel = 'low'; RequiresReboot = $false; Source = 'rules'
      Purpose = '校正混合显卡选择与呈现路径，需要关闭并重新启动游戏后测试。'
    }
  )
}

function Get-TuningCandidate([Parameter(Mandatory)][string]$GroupId) {
  $candidate = @(Get-TuningCandidateLibrary | Where-Object GroupId -eq $GroupId) | Select-Object -First 1
  if (-not $candidate) { throw "未知自动调优候选组：$GroupId" }
  $candidate
}

function Get-TuningSha256([string]$Text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$Text"))) -replace '-','').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-TuningItemSetHash([string[]]$ItemIds) {
  $clean = @($ItemIds | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ } | Sort-Object -Unique)
  if (-not $clean.Count) { return Get-TuningSha256 '' }
  # 与服务端协议一致：排序、去重、小写后使用英文逗号连接。
  Get-TuningSha256 ($clean -join ',')
}

function Get-TuningEnvironmentHash($Environment) {
  if (-not $Environment) { return Get-TuningSha256 '' }
  $ordered = [ordered]@{}
  foreach ($name in 'appVersion','windowsBuild','gpuModel','driverVersion','gameVersion','displayMode','sceneId') {
    $value = $Environment.PSObject.Properties[$name]
    $ordered[$name] = $(if ($value) { "$($value.Value)" } else { '' })
  }
  Get-TuningSha256 ($ordered | ConvertTo-Json -Compress)
}

function ConvertTo-TuningUtcText([DateTime]$Value = [DateTime]::UtcNow) {
  $Value.ToUniversalTime().ToString('o')
}

function New-TuningExperimentState {
  param(
    [Parameter(Mandatory)][string]$SceneId,
    [Parameter(Mandatory)]$Environment,
    [ValidateSet('smoothness')][string]$Goal = 'smoothness',
    [ValidateRange(0,7)][double]$MaxTempIncreaseC = 3,
    [ValidateRange(0,20)][double]$MaxPowerIncreasePct = 0,
    [bool]$AllowHigherPower = $false
  )
  $scene = "$SceneId".Trim()
  if ($scene.Length -lt 2 -or $scene.Length -gt 80 -or $scene -match '[\x00-\x1f]') {
    throw '测试场景标识需为 2–80 个可见字符'
  }
  if (-not $AllowHigherPower -and $MaxPowerIncreasePct -ne 0) {
    throw '不允许增加功耗时，功耗增幅上限必须为 0'
  }
  $id = 'exp_' + [guid]::NewGuid().ToString('N')
  $candidates = @(Get-TuningCandidateLibrary | ForEach-Object {
    [pscustomobject][ordered]@{
      groupId = $_.GroupId; variantId = $_.VariantId; displayName = $_.DisplayName
      itemSetHash = Get-TuningItemSetHash $_.ItemIds
      status = 'pending'; result = ''; runs = 0; activeBackup = ''; appliedBackups = @()
      comparison = $null
    }
  })
  [pscustomobject][ordered]@{
    schemaVersion = $script:TuningSchemaVersion
    libraryVersion = $script:TuningCandidateLibraryVersion
    experimentId = $id
    status = 'baseline_pending'
    goal = $Goal
    riskLevel = 'low'
    allowReboot = $false
    allowHigherPower = [bool]$AllowHigherPower
    maxTempIncreaseC = [double]$MaxTempIncreaseC
    maxPowerIncreasePct = [double]$MaxPowerIncreasePct
    sceneId = $scene
    environment = $Environment
    environmentHash = Get-TuningEnvironmentHash $Environment
    createdAt = ConvertTo-TuningUtcText
    updatedAt = ConvertTo-TuningUtcText
    completedAt = ''
    currentBestVariantId = 'baseline'
    currentBestGroups = @()
    candidateIndex = 0
    candidates = $candidates
    runs = @()
    activeBackups = @()
    result = ''
    stopReason = ''
    orderControlled = $true
  }
}

function Assert-TuningScalarText($Value, [string]$Label, [int]$MaxLength, [switch]$AllowEmpty) {
  if ($Value -isnot [string]) { throw "$Label 类型无效" }
  if (-not $AllowEmpty -and -not $Value) { throw "$Label 不能为空" }
  if ($Value.Length -gt $MaxLength -or $Value -match '[\x00-\x1f]') { throw "$Label 内容无效" }
}

function Test-TuningFiniteNumber($Value, [double]$Minimum, [double]$Maximum, [switch]$MinimumExclusive) {
  if ($null -eq $Value -or $Value -is [bool] -or $Value -is [string] -or $Value -isnot [ValueType]) { return $false }
  try { $number = [double]$Value } catch { return $false }
  if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -gt $Maximum) { return $false }
  $(if ($MinimumExclusive) { $number -gt $Minimum } else { $number -ge $Minimum })
}

function Test-PathUnderProtectedTuningBackup([string]$Path) {
  try {
    if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) { return $false }
    $root = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)) 'DeltaForceBooster\backup'
    $full = [IO.Path]::GetFullPath($Path)
    $prefix = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
    $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and
      [IO.Path]::GetFileName($full) -match '^backup-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}(?:\.pending)?\.json$'
  } catch { $false }
}

function Assert-TuningExactProperties($Object, [string[]]$Required, [string[]]$Optional, [string]$Label) {
  if ($null -eq $Object) { throw "$Label 不能为空" }
  $actual = @($Object.PSObject.Properties.Name)
  foreach ($name in $Required) { if ($actual -notcontains $name) { throw "$Label 缺少字段：$name" } }
  $allowed = @($Required) + @($Optional)
  $unknown = @($actual | Where-Object { $allowed -notcontains $_ })
  if ($unknown.Count) { throw "$Label 包含未知字段：$($unknown -join '、')" }
}

function Test-TuningRunMetrics($Run, [bool]$RequireValidCapture) {
  $ranges = [ordered]@{
    durationSec=@(0,600,$false); frameCount=@(0,10000000,$false)
    avgFps=@(0,1000,$RequireValidCapture); fps1Low=@(0,1000,$RequireValidCapture); p99FrameMs=@(0,1000,$RequireValidCapture)
    frameTimeMadMs=@(0,1000,$false); stutter50Ms=@(0,10000000,$false); stutter100Ms=@(0,10000000,$false)
    stuttersPerMin=@(0,100000,$false); focusLostSec=@(0,600,$false); gpuUtilAvg=@(0,100,$false)
    gpuTempAvg=@(0,120,$false); gpuTempMax=@(0,120,$false); gpuPowerAvg=@(0,1500,$false)
  }
  foreach ($entry in $ranges.GetEnumerator()) {
    $v = $Run.PSObject.Properties[$entry.Key]
    if (-not $v -or -not (Test-TuningFiniteNumber $v.Value $entry.Value[0] $entry.Value[1] -MinimumExclusive:([bool]$entry.Value[2]))) { return $false }
  }
  if ([double]$Run.fps1Low -gt [double]$Run.avgFps -or [double]$Run.gpuTempAvg -gt [double]$Run.gpuTempMax -or
      [double]$Run.focusLostSec -gt [double]$Run.durationSec -or [int64]$Run.stutter100Ms -gt [int64]$Run.stutter50Ms) { return $false }
  if ([double]$Run.frameCount -ne [math]::Truncate([double]$Run.frameCount) -or
      [double]$Run.stutter50Ms -ne [math]::Truncate([double]$Run.stutter50Ms) -or
      [double]$Run.stutter100Ms -ne [math]::Truncate([double]$Run.stutter100Ms)) { return $false }
  if ($RequireValidCapture -and ([double]$Run.durationSec -lt 90 -or [int64]$Run.frameCount -lt 1000)) { return $false }
  $true
}

function Assert-TuningExperimentState($State) {
  $requiredState = @('schemaVersion','libraryVersion','experimentId','status','goal','riskLevel','allowReboot',
    'allowHigherPower','maxTempIncreaseC','maxPowerIncreasePct','sceneId','environment','environmentHash',
    'createdAt','updatedAt','completedAt','currentBestVariantId','currentBestGroups','candidateIndex','candidates',
    'runs','activeBackups','result','stopReason','orderControlled')
  $optionalState = @('phase','gamePath','configGeneration','pendingActionId','pendingResumePhase',
    'pendingTuningCommit','initialBaselineRunIds','finalRunIds','groupRestartAfter','lastMessage','finalComparison')
  Assert-TuningExactProperties $State $requiredState $optionalState '实验状态'
  if (-not $State -or [int]$State.schemaVersion -ne $script:TuningSchemaVersion) { throw '实验状态版本无效' }
  if ([int]$State.libraryVersion -ne $script:TuningCandidateLibraryVersion) { throw '实验候选库版本已变化，请重新开始实验' }
  if ("$($State.experimentId)" -notmatch '^exp_[0-9a-f]{32}$') { throw '实验 ID 无效' }
  if ("$($State.status)" -notin $script:TuningAllowedStatuses) { throw '实验状态无效' }
  if ("$($State.goal)" -ne 'smoothness' -or "$($State.riskLevel)" -ne 'low' -or $State.allowReboot -isnot [bool] -or
      [bool]$State.allowReboot -or $State.allowHigherPower -isnot [bool] -or $State.orderControlled -isnot [bool] -or
      -not [bool]$State.orderControlled) {
    throw '第一版只接受低风险、无需重启的流畅度实验'
  }
  Assert-TuningScalarText $State.sceneId '测试场景' 80
  if (-not (Test-TuningFiniteNumber $State.maxTempIncreaseC 0 7)) { throw '温度约束无效' }
  if (-not (Test-TuningFiniteNumber $State.maxPowerIncreasePct 0 20) -or
      (-not [bool]$State.allowHigherPower -and [double]$State.maxPowerIncreasePct -ne 0)) { throw '功耗约束无效' }
  $environmentFields = @('appVersion','windowsBuild','gpuModel','driverVersion','gameVersion','displayMode','sceneId')
  Assert-TuningExactProperties $State.environment $environmentFields @() '实验环境'
  foreach ($name in $environmentFields) { Assert-TuningScalarText $State.environment.$name "实验环境.$name" 256 -AllowEmpty }
  if ("$($State.environmentHash)" -notmatch '^[0-9a-f]{64}$' -or
      "$($State.environmentHash)" -ne (Get-TuningEnvironmentHash $State.environment)) { throw '实验环境摘要不一致' }
  foreach ($name in 'createdAt','updatedAt') {
    $when = [DateTime]::MinValue
    if (-not [DateTime]::TryParse("$($State.$name)",[ref]$when)) { throw "实验时间无效：$name" }
  }
  if ($State.completedAt) { $when = [DateTime]::MinValue; if (-not [DateTime]::TryParse("$($State.completedAt)",[ref]$when)) { throw '实验完成时间无效' } }
  if ("$($State.result)" -notin @('','found_better','no_significant_gain','rolled_back','cancelled') -or
      "$($State.stopReason)" -notin @('','completed','safety_threshold','unstable_baseline','rollback_failed',
        'final_rollback_failed','apply_without_backup','apply_failed','internal_error','user_cancelled')) { throw '实验结论或停止原因无效' }
  if ("$($State.status)" -eq 'completed' -and "$($State.result)" -notin @('found_better','no_significant_gain')) { throw '完成状态与实验结论不一致' }
  if ("$($State.status)" -eq 'rolled_back' -and "$($State.result)" -ne 'rolled_back') { throw '回滚状态与实验结论不一致' }
  if ("$($State.status)" -eq 'cancelled' -and "$($State.result)" -ne 'cancelled') { throw '取消状态与实验结论不一致' }

  $library = @(Get-TuningCandidateLibrary)
  $stateCandidates = @($State.candidates)
  if ($stateCandidates.Count -ne $library.Count) { throw '实验候选数量无效' }
  $knownVariants = @('baseline') + @($library.VariantId)
  for ($i = 0; $i -lt $library.Count; $i++) {
    $expected = $library[$i]; $actual = $stateCandidates[$i]
    $candidateRequired = @('groupId','variantId','displayName','itemSetHash','status','result','runs','activeBackup',
      'appliedBackups','comparison')
    $candidateOptional = @('controlRunIds','candidateRunIds','extraAttempted','controlVariantId','sequenceNo')
    Assert-TuningExactProperties $actual $candidateRequired $candidateOptional "实验候选[$i]"
    if ("$($actual.groupId)" -ne $expected.GroupId -or "$($actual.variantId)" -ne $expected.VariantId -or
        "$($actual.itemSetHash)" -ne (Get-TuningItemSetHash $expected.ItemIds)) { throw '实验候选被修改，已停止继续执行' }
    if ("$($actual.displayName)" -ne "$($expected.DisplayName)" -or "$($actual.status)" -notin @('pending','complete') -or
        "$($actual.result)" -notin @('','win','rollback','no_gain') -or -not (Test-TuningFiniteNumber $actual.runs 0 100)) {
      throw '实验候选状态无效'
    }
    if ($actual.comparison) {
      $comparisonRequired = @('result','reason')
      $comparisonOptional = @('controlRuns','candidateRuns','thresholdPct','baselineNoisePct','avgFpsDeltaPct',
        'fps1LowDeltaPct','p99FrameMsDeltaPct','stutterDeltaPct','gpuTempDeltaC','gpuPowerDeltaPct',
        'directionWins','requiredDirectionWins','score')
      Assert-TuningExactProperties $actual.comparison $comparisonRequired $comparisonOptional '实验候选比较结果'
      if ("$($actual.comparison.result)" -notin @('insufficient','inconclusive','win','rollback')) { throw '实验候选比较结果无效' }
      Assert-TuningScalarText $actual.comparison.reason '实验候选比较原因' 160
      foreach ($name in $comparisonOptional) {
        $property = $actual.comparison.PSObject.Properties[$name]
        if ($property -and $null -ne $property.Value -and -not (Test-TuningFiniteNumber $property.Value -10000000 10000000)) {
          throw "实验候选比较指标无效：$name"
        }
      }
    }
    if ($actual.activeBackup -and -not (Test-PathUnderProtectedTuningBackup "$($actual.activeBackup)")) { throw '候选活动备份引用无效' }
    foreach ($backup in @($actual.appliedBackups)) {
      if (-not (Test-PathUnderProtectedTuningBackup "$backup")) { throw '候选已保留备份引用无效' }
    }
    if (@($actual.appliedBackups | Select-Object -Unique).Count -ne @($actual.appliedBackups).Count) { throw '候选已保留备份引用重复' }
  }
  if (-not (Test-TuningFiniteNumber $State.candidateIndex 0 $library.Count) -or
      [double]$State.candidateIndex -ne [math]::Truncate([double]$State.candidateIndex)) { throw '候选进度无效' }
  $bestGroups = @($State.currentBestGroups)
  if (@($bestGroups | Select-Object -Unique).Count -ne $bestGroups.Count) { throw '当前保留组重复' }
  $lastIndex = -1
  foreach ($group in $bestGroups) {
    $candidate = Get-TuningCandidate "$group"; $index = [array]::IndexOf($library.GroupId,$candidate.GroupId)
    if ($index -le $lastIndex -or "$($stateCandidates[$index].result)" -ne 'win') { throw '当前保留组与候选结果不一致' }
    $lastIndex = $index
  }
  if ("$($State.currentBestVariantId)" -notin $knownVariants -or
      ($bestGroups.Count -eq 0 -and "$($State.currentBestVariantId)" -ne 'baseline') -or
      ($bestGroups.Count -gt 0 -and "$($State.currentBestVariantId)" -ne "$((Get-TuningCandidate $bestGroups[-1]).VariantId)")) {
    throw '当前最佳方案标识无效'
  }
  foreach ($backup in @($State.activeBackups)) {
    if (-not (Test-PathUnderProtectedTuningBackup "$backup")) { throw '实验备份引用超出受保护备份目录' }
  }
  if (@($State.activeBackups | Select-Object -Unique).Count -ne @($State.activeBackups).Count) { throw '实验活动备份引用重复' }
  $runIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  $sequences = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($run in @($State.runs)) {
    $runFields = @('runId','experimentId','variantId','groupId','runNo','sequenceNo','startedAt','completedAt','validity',
      'invalidReason','durationSec','frameCount','avgFps','fps1Low','p99FrameMs','frameTimeMadMs','stutter50Ms',
      'stutter100Ms','stuttersPerMin','focusLostSec','gpuUtilAvg','gpuTempAvg','gpuTempMax','gpuPowerAvg',
      'settingsHash','environmentHash','orderControlled')
    Assert-TuningExactProperties $run $runFields @('presentMonExitCode','gameExitedEarly','captureFailed') '运行记录'
    if ("$($run.runId)" -notmatch '^run_[0-9a-f]{32}$') { throw '运行记录 ID 无效' }
    if (-not $runIds.Add("$($run.runId)")) { throw '运行记录 ID 重复' }
    if ("$($run.experimentId)" -ne "$($State.experimentId)" -or "$($run.variantId)" -notin $knownVariants) { throw '运行记录归属无效' }
    if ("$($run.groupId)" -notin (@('baseline','final') + @($library.GroupId)) -or
        ("$($run.groupId)" -eq 'baseline' -and "$($run.variantId)" -ne 'baseline')) { throw '运行记录分组无效' }
    if ("$($run.groupId)" -in $library.GroupId) {
      $groupIndex = [array]::IndexOf($library.GroupId,"$($run.groupId)")
      $variantIndex = [array]::IndexOf($library.VariantId,"$($run.variantId)")
      if ("$($run.variantId)" -ne 'baseline' -and ($variantIndex -lt 0 -or $variantIndex -gt $groupIndex)) { throw '运行记录方案与候选顺序不一致' }
    }
    if (-not (Test-TuningFiniteNumber $run.runNo 1 100) -or [double]$run.runNo -ne [math]::Truncate([double]$run.runNo) -or
        -not (Test-TuningFiniteNumber $run.sequenceNo 1 300) -or [double]$run.sequenceNo -ne [math]::Truncate([double]$run.sequenceNo) -or
        -not $sequences.Add([int]$run.sequenceNo)) { throw '运行记录序号无效' }
    if ("$($run.validity)" -notin $script:TuningAllowedValidity) { throw '运行有效性无效' }
    if (("$($run.validity)" -eq 'valid' -and $run.invalidReason) -or
        ("$($run.validity)" -ne 'valid' -and "$($run.invalidReason)" -notin $script:TuningInvalidReasons)) { throw '运行无效原因无效' }
    if (-not (Test-TuningRunMetrics $run ("$($run.validity)" -eq 'valid'))) { throw '运行指标无效' }
    if ("$($run.settingsHash)" -notmatch '^[0-9a-f]{64}$' -or "$($run.environmentHash)" -notmatch '^[0-9a-f]{64}$' -or
        $run.orderControlled -isnot [bool]) { throw '运行摘要或顺序标识无效' }
    if ($run.PSObject.Properties['presentMonExitCode'] -and
        (-not (Test-TuningFiniteNumber $run.presentMonExitCode -2147483648 2147483647) -or
         [double]$run.presentMonExitCode -ne [math]::Truncate([double]$run.presentMonExitCode))) { throw 'PresentMon 退出码无效' }
    foreach ($name in 'gameExitedEarly','captureFailed') {
      if ($run.PSObject.Properties[$name] -and $run.$name -isnot [bool]) { throw "运行状态字段无效：$name" }
    }
    if ("$($run.validity)" -eq 'valid' -and (($run.PSObject.Properties['captureFailed'] -and [bool]$run.captureFailed) -or
        ($run.PSObject.Properties['gameExitedEarly'] -and [bool]$run.gameExitedEarly))) { throw '有效运行与采集状态矛盾' }
    foreach ($name in 'startedAt','completedAt') { $when=[DateTime]::MinValue; if (-not [DateTime]::TryParse("$($run.$name)",[ref]$when)) { throw "运行时间无效：$name" } }
  }
  $allIds = @($State.runs | ForEach-Object { "$($_.runId)" })
  foreach ($name in 'initialBaselineRunIds','finalRunIds') {
    if ($State.PSObject.Properties[$name]) {
      $refs=@($State.$name); if (@($refs|Select-Object -Unique).Count -ne $refs.Count -or @($refs|Where-Object{$allIds -notcontains "$_"}).Count) { throw "$name 运行引用无效" }
    }
  }
  if ($State.PSObject.Properties['phase']) {
    $allowedPhases = @('baseline','group_control_pre','group_apply_b1','group_capture_b1','group_rollback_a',
      'group_capture_a','group_apply_b2','group_capture_b2','group_rollback_extra_a','group_capture_extra_a',
      'group_apply_extra_b','group_capture_extra_b','final_capture','applying','rolling_back','completed','failed')
    if ("$($State.phase)" -notin $allowedPhases) { throw '实验阶段无效' }
  }
  if ($State.PSObject.Properties['gamePath']) {
    if (-not $State.gamePath -or -not [IO.Path]::IsPathRooted("$($State.gamePath)") -or
        [IO.Path]::GetFileName("$($State.gamePath)") -notin @('DeltaForceClient-Win64-Shipping.exe','DeltaForce.exe')) {
      throw '实验游戏路径无效'
    }
  }
  if ($State.PSObject.Properties['configGeneration'] -and
      (-not (Test-TuningFiniteNumber $State.configGeneration 0 2147483647) -or
       [double]$State.configGeneration -ne [math]::Truncate([double]$State.configGeneration))) { throw '实验配置代次无效' }
  if ($State.PSObject.Properties['pendingActionId'] -and $State.pendingActionId -and
      "$($State.pendingActionId)" -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { throw '实验待处理动作 ID 无效' }
  if ($State.PSObject.Properties['pendingResumePhase'] -and $State.pendingResumePhase -and
      "$($State.pendingResumePhase)" -notin $allowedPhases) { throw '实验恢复阶段无效' }
  if ($State.PSObject.Properties['pendingTuningCommit'] -and $State.pendingTuningCommit) {
    if(-not $State.PSObject.Properties['phase']){throw '实验待提交步骤缺少当前阶段'}
    $pending = $State.pendingTuningCommit
    $pendingFields = @('schemaVersion','kind','telemetryType','sourcePhase','candidateIndex','entityId',
      'resumePhase','outcome','unsafeFailure','reason','payload')
    Assert-TuningExactProperties $pending $pendingFields @() '实验待提交步骤'
    if ([int]$pending.schemaVersion -ne 1 -or "$($pending.kind)" -notin @('run','variant') -or
        "$($pending.telemetryType)" -notin @('run_completed','variant_applied')) { throw '实验待提交步骤类型无效' }
    if (($pending.kind -eq 'run' -and $pending.telemetryType -ne 'run_completed') -or
        ($pending.kind -eq 'variant' -and $pending.telemetryType -ne 'variant_applied')) { throw '实验待提交步骤遥测类型不一致' }
    if ("$($pending.sourcePhase)" -notin @('baseline','group_control_pre','group_capture_b1','group_capture_a',
        'group_capture_b2','group_capture_extra_a','group_capture_extra_b','final_capture','applying')) { throw '实验待提交来源阶段无效' }
    if (-not (Test-TuningFiniteNumber $pending.candidateIndex -1 $library.Count) -or
        [double]$pending.candidateIndex -ne [math]::Truncate([double]$pending.candidateIndex)) { throw '实验待提交候选索引无效' }
    if ($pending.unsafeFailure -isnot [bool]) { throw '实验待提交安全失败标记无效' }
    Assert-TuningScalarText $pending.reason '实验待提交原因' 500 -AllowEmpty
    if ($pending.kind -eq 'run') {
      if ("$($pending.entityId)" -notmatch '^run_[0-9a-f]{32}$' -or
          -not @($State.runs | Where-Object runId -eq "$($pending.entityId)").Count) { throw '实验待提交运行引用无效' }
      if ($pending.resumePhase -or $pending.outcome -or [bool]$pending.unsafeFailure) { throw '实验待提交运行续接字段无效' }
      $pendingRun=@($State.runs | Where-Object runId -eq "$($pending.entityId)")[0]
      if (("$($pending.sourcePhase)" -eq 'baseline' -and ([int]$pending.candidateIndex -ne -1 -or "$($pendingRun.groupId)" -ne 'baseline')) -or
          ("$($pending.sourcePhase)" -eq 'final_capture' -and ([int]$pending.candidateIndex -ne $library.Count -or "$($pendingRun.groupId)" -ne 'final')) -or
          ("$($pending.sourcePhase)" -notin @('baseline','final_capture') -and
            ([int]$pending.candidateIndex -lt 0 -or [int]$pending.candidateIndex -ge $library.Count -or
             "$($pendingRun.groupId)" -ne "$($library[[int]$pending.candidateIndex].GroupId)"))) { throw '实验待提交运行阶段归属无效' }
      $expectedRunVariant=$(switch -Regex ("$($pending.sourcePhase)") {
        '^baseline$'{'baseline';break}
        '^final_capture$'{$(if("$($State.phase)" -eq 'final_capture'){"$($State.currentBestVariantId)"}else{"$($pendingRun.variantId)"});break}
        '^group_(control_pre|capture_a|capture_extra_a)$'{"$($stateCandidates[[int]$pending.candidateIndex].controlVariantId)";break}
        default{"$($stateCandidates[[int]$pending.candidateIndex].variantId)"}
      })
      if(-not $expectedRunVariant -or "$($pendingRun.variantId)" -ne $expectedRunVariant){throw '实验待提交运行方案归属无效'}
      if("$($pending.sourcePhase)" -eq 'final_capture' -and "$($State.phase)" -ne 'final_capture'){
        $finalVariants=@($State.runs|Where-Object{@($State.finalRunIds) -contains "$($_.runId)"}|ForEach-Object{"$($_.variantId)"}|Select-Object -Unique)
        if($finalVariants.Count -gt 1 -or ($finalVariants.Count -eq 1 -and "$($finalVariants[0])" -ne "$($pendingRun.variantId)")){throw '最终复核运行方案在回滚期间发生漂移'}
      }
      if("$($pending.sourcePhase)" -notin @('baseline','final_capture') -and "$($State.phase)" -eq "$($pending.sourcePhase)" -and
          [int]$State.candidateIndex -ne [int]$pending.candidateIndex){throw '实验待提交运行与当前候选进度不一致'}
      if("$($State.phase)" -ne "$($pending.sourcePhase)"){
        $consumed=$(switch("$($pending.sourcePhase)"){
          'baseline'{@($State.initialBaselineRunIds) -contains "$($pending.entityId)";break}
          'final_capture'{@($State.finalRunIds) -contains "$($pending.entityId)";break}
          'group_control_pre'{@($stateCandidates[[int]$pending.candidateIndex].controlRunIds) -contains "$($pending.entityId)";break}
          'group_capture_b1'{@($stateCandidates[[int]$pending.candidateIndex].candidateRunIds) -contains "$($pending.entityId)";break}
          'group_capture_a'{@($stateCandidates[[int]$pending.candidateIndex].controlRunIds) -contains "$($pending.entityId)";break}
          'group_capture_b2'{@($stateCandidates[[int]$pending.candidateIndex].candidateRunIds) -contains "$($pending.entityId)";break}
          'group_capture_extra_a'{@($stateCandidates[[int]$pending.candidateIndex].controlRunIds) -contains "$($pending.entityId)";break}
          'group_capture_extra_b'{@($stateCandidates[[int]$pending.candidateIndex].candidateRunIds) -contains "$($pending.entityId)";break}
          default{$false}
        })
        if(-not $consumed){throw '实验待提交运行尚未完成来源阶段推进'}
      }
    } else {
      if ("$($pending.entityId)" -notin $library.VariantId -or "$($pending.sourcePhase)" -ne 'applying' -or
          "$($pending.resumePhase)" -ne 'group_capture_b1' -or "$($pending.outcome)" -notin @('succeeded','failed') -or
          [int]$pending.candidateIndex -lt 0 -or [int]$pending.candidateIndex -ge $library.Count -or
          "$($pending.entityId)" -ne "$($library[[int]$pending.candidateIndex].VariantId)" -or
          -not $stateCandidates[[int]$pending.candidateIndex].PSObject.Properties['sequenceNo'] -or
          [int]$stateCandidates[[int]$pending.candidateIndex].sequenceNo -lt 1 -or
          ([bool]$pending.unsafeFailure -and "$($pending.outcome)" -ne 'failed')) { throw '实验待提交候选结果无效' }
      $pendingCandidate=$stateCandidates[[int]$pending.candidateIndex]
      $variantUnprocessed=("$($State.phase)" -eq 'applying' -and [int]$State.candidateIndex -eq [int]$pending.candidateIndex -and [bool]$State.pendingActionId)
      $variantRollback=("$($pending.outcome)" -eq 'failed' -and "$($State.phase)" -eq 'rolling_back' -and [int]$State.candidateIndex -eq [int]$pending.candidateIndex)
      $variantSuccessCommitted=("$($pending.outcome)" -eq 'succeeded' -and "$($State.phase)" -eq "$($pending.resumePhase)" -and
        [int]$State.candidateIndex -eq [int]$pending.candidateIndex -and -not $State.pendingActionId)
      $variantFailureCommitted=("$($pending.outcome)" -eq 'failed' -and "$($pendingCandidate.status)" -eq 'complete' -and
        [int]$State.candidateIndex -gt [int]$pending.candidateIndex)
      if(-not ($variantUnprocessed -or $variantRollback -or $variantSuccessCommitted -or $variantFailureCommitted)){
        throw '实验待提交候选与当前实验阶段不一致'
      }
      if("$($pending.outcome)" -eq 'succeeded' -and -not $pendingCandidate.activeBackup){throw '成功候选待提交结果缺少活动备份'}
    }
    if ($pending.payload) {
      if (-not $pending.payload.PSObject -or "$($pending.payload.event)" -ne 'tuning' -or
          "$($pending.payload.tuningType)" -ne "$($pending.telemetryType)" -or
          "$($pending.payload.experimentId)" -ne "$($State.experimentId)") { throw '实验待提交遥测载荷无效' }
      if (($pending.kind -eq 'run' -and "$($pending.payload.runId)" -ne "$($State.experimentId).$($pending.entityId)") -or
          ($pending.kind -eq 'variant' -and "$($pending.payload.variantId)" -ne "$($State.experimentId).$($library[[int]$pending.candidateIndex].GroupId)")) {
        throw '实验待提交遥测业务 ID 无效'
      }
    }
  }
  if ($State.PSObject.Properties['groupRestartAfter'] -and $State.groupRestartAfter) {
    $restartAt=[DateTime]::MinValue; if (-not [DateTime]::TryParse("$($State.groupRestartAfter)",[ref]$restartAt)) { throw '实验重启等待时间无效' }
  }
  if ($State.PSObject.Properties['lastMessage']) { Assert-TuningScalarText $State.lastMessage '实验状态说明' 1000 -AllowEmpty }
  if ($State.PSObject.Properties['finalComparison'] -and $State.finalComparison) {
    Assert-TuningExactProperties $State.finalComparison @('result','reason') @('controlRuns','candidateRuns','thresholdPct',
      'baselineNoisePct','avgFpsDeltaPct','fps1LowDeltaPct','p99FrameMsDeltaPct','stutterDeltaPct','gpuTempDeltaC',
      'gpuPowerDeltaPct','directionWins','requiredDirectionWins','score') '最终比较结果'
    if ("$($State.finalComparison.result)" -notin @('insufficient','inconclusive','win','rollback')) { throw '最终比较结果无效' }
    Assert-TuningScalarText $State.finalComparison.reason '最终比较原因' 160
    foreach ($name in 'controlRuns','candidateRuns','thresholdPct','baselineNoisePct','avgFpsDeltaPct','fps1LowDeltaPct',
      'p99FrameMsDeltaPct','stutterDeltaPct','gpuTempDeltaC','gpuPowerDeltaPct','directionWins','requiredDirectionWins','score') {
      $property = $State.finalComparison.PSObject.Properties[$name]
      if ($property -and $null -ne $property.Value -and -not (Test-TuningFiniteNumber $property.Value -10000000 10000000)) {
        throw "最终比较指标无效：$name"
      }
    }
  }

  $lastCandidateBoundary = 0
  for ($i = 0; $i -lt $stateCandidates.Count; $i++) {
    $actual = $stateCandidates[$i]
    if ($actual.PSObject.Properties['extraAttempted'] -and $actual.extraAttempted -isnot [bool]) { throw '候选追加采样标记无效' }
    if ($actual.PSObject.Properties['sequenceNo']) {
      if (-not (Test-TuningFiniteNumber $actual.sequenceNo 1 300) -or
          [double]$actual.sequenceNo -ne [math]::Truncate([double]$actual.sequenceNo) -or
          [int]$actual.sequenceNo -le $lastCandidateBoundary) { throw '候选运行边界序号无效' }
      $lastCandidateBoundary = [int]$actual.sequenceNo
    }
    if ($actual.PSObject.Properties['controlVariantId'] -and $actual.controlVariantId) {
      $controlIndex = [array]::IndexOf($library.VariantId,"$($actual.controlVariantId)")
      if ("$($actual.controlVariantId)" -ne 'baseline' -and ($controlIndex -lt 0 -or $controlIndex -ge $i)) { throw '候选对照方案无效' }
      $rollbackUnwind=("$($State.phase)" -eq 'rolling_back' -or "$($State.status)" -in @('rolled_back','cancelled','failed'))
      if ($controlIndex -ge 0 -and "$($stateCandidates[$controlIndex].result)" -ne 'win' -and -not $rollbackUnwind) { throw '候选对照方案尚未胜出' }
    }
    foreach ($field in 'controlRunIds','candidateRunIds') {
      if (-not $actual.PSObject.Properties[$field]) { continue }
      $refs = @($actual.$field)
      if (@($refs | Select-Object -Unique).Count -ne $refs.Count) { throw "候选运行引用重复：$field" }
      foreach ($ref in $refs) {
        $matched = @($State.runs | Where-Object runId -eq "$ref")
        if ($matched.Count -ne 1) { throw "候选运行引用无效：$field" }
        if ($field -eq 'candidateRunIds' -and "$($matched[0].variantId)" -ne "$($actual.variantId)") { throw '候选运行引用到错误方案' }
        if ($field -eq 'controlRunIds' -and $actual.controlVariantId -and "$($matched[0].variantId)" -ne "$($actual.controlVariantId)") { throw '对照运行引用到错误方案' }
      }
    }
    if (("$($actual.status)" -eq 'pending' -and $actual.result) -or
        ("$($actual.status)" -eq 'complete' -and -not $actual.result)) { throw '候选状态与结果不一致' }
    if ("$($actual.result)" -eq 'win' -and (@($actual.appliedBackups).Count -lt 1 -or $actual.activeBackup)) { throw '胜出候选备份状态无效' }
    if ("$($actual.result)" -in @('rollback','no_gain') -and $actual.activeBackup) { throw '已结束候选仍有活动备份' }
  }
  $true
}

function Write-TuningStateAtomic([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$State) {
  [void](Assert-TuningExperimentState $State)
  $State.updatedAt = ConvertTo-TuningUtcText
  $dir = Split-Path -Parent $Path
  if (-not $dir) { throw '实验状态路径必须包含目录' }
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $tmp = Join-Path $dir ('.experiment-' + [guid]::NewGuid().ToString('N') + '.tmp')
  $json = ConvertTo-Json -InputObject $State -Depth 12
  $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes($json)
  $stream = New-Object IO.FileStream($tmp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
  try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
  $backup = Join-Path $dir ('.experiment-' + [guid]::NewGuid().ToString('N') + '.bak')
  try {
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp,$Path,$backup,$true) }
    else { [IO.File]::Move($tmp,$Path) }
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
  }
  $Path
}

function Read-TuningState([Parameter(Mandatory)][string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $file = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($file.Length -gt 2097152 -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw '实验状态文件无效' }
  $state = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  [void](Assert-TuningExperimentState $state)
  $state
}

function Get-TuningMedian([object[]]$Values) {
  $numbers = @($Values | ForEach-Object {
    if (Test-TuningFiniteNumber $_ ([double]::MinValue) ([double]::MaxValue)) { [double]$_ }
  } | Sort-Object)
  if (-not $numbers.Count) { return $null }
  $mid = [math]::Floor($numbers.Count / 2)
  if ($numbers.Count % 2) { return [double]$numbers[$mid] }
  ([double]$numbers[$mid - 1] + [double]$numbers[$mid]) / 2.0
}

function Get-TuningPercentile([object[]]$Values, [ValidateRange(0,1)][double]$Fraction) {
  $numbers = @($Values | ForEach-Object {
    if (Test-TuningFiniteNumber $_ ([double]::MinValue) ([double]::MaxValue)) { [double]$_ }
  } | Sort-Object)
  if (-not $numbers.Count) { return $null }
  $position = ($numbers.Count - 1) * $Fraction
  $lower = [math]::Floor($position); $upper = [math]::Ceiling($position)
  if ($lower -eq $upper) { return [double]$numbers[$lower] }
  [double]$numbers[$lower] + (([double]$numbers[$upper] - [double]$numbers[$lower]) * ($position - $lower))
}

function Get-TuningCoefficientOfVariation([object[]]$Values) {
  $numbers = @($Values | ForEach-Object {
    if (Test-TuningFiniteNumber $_ ([double]::MinValue) ([double]::MaxValue)) { [double]$_ }
  })
  if ($numbers.Count -lt 2) { return $null }
  $mean = [double](($numbers | Measure-Object -Average).Average)
  if ($mean -eq 0) { return $null }
  $sum = 0.0; foreach ($n in $numbers) { $sum += [math]::Pow($n - $mean,2) }
  [math]::Sqrt($sum / ($numbers.Count - 1)) * 100.0 / [math]::Abs($mean)
}

function Get-TuningMetricSummary([object[]]$Runs, [string]$Property) {
  $values = @($Runs | Where-Object { $_.validity -eq 'valid' } | ForEach-Object {
    $propertyValue = $_.PSObject.Properties[$Property]
    if ($propertyValue -and (Test-TuningFiniteNumber $propertyValue.Value ([double]::MinValue) ([double]::MaxValue))) {
      [double]$propertyValue.Value
    }
  })
  if (-not $values.Count) { return [pscustomobject]@{ count=0; median=$null; mean=$null; p25=$null; p75=$null; cvPct=$null } }
  [pscustomobject][ordered]@{
    count = $values.Count
    median = [math]::Round((Get-TuningMedian $values),2)
    mean = [math]::Round([double](($values | Measure-Object -Average).Average),2)
    p25 = [math]::Round((Get-TuningPercentile $values .25),2)
    p75 = [math]::Round((Get-TuningPercentile $values .75),2)
    cvPct = $(if ($values.Count -gt 1) { [math]::Round((Get-TuningCoefficientOfVariation $values),2) } else { $null })
  }
}

function Get-TuningRunValidity {
  param(
    [Parameter(Mandatory)]$Metrics,
    [Parameter(Mandatory)][string]$ExpectedEnvironmentHash,
    [Parameter(Mandatory)][string]$ActualEnvironmentHash,
    [bool]$ApplySucceeded = $true,
    [bool]$SceneMatches = $true,
    [bool]$DriverMatches = $true,
    [bool]$GameVersionMatches = $true,
    [bool]$SettingsMatch = $true
  )
  $reason = ''
  if (-not $ApplySucceeded) { $reason = 'apply_failed' }
  elseif (-not $Metrics -or [bool]$Metrics.captureFailed) { $reason = 'capture_failed' }
  elseif ([bool]$Metrics.gameExitedEarly) { $reason = 'game_exited' }
  elseif (-not (Test-TuningRunMetrics $Metrics $false)) { $reason = 'capture_failed' }
  elseif ([double]$Metrics.durationSec -lt 90) { $reason = 'sample_too_short' }
  elseif ([int64]$Metrics.frameCount -lt 1000) { $reason = 'insufficient_frames' }
  elseif (-not (Test-TuningRunMetrics $Metrics $true)) { $reason = 'capture_failed' }
  elseif (-not $SceneMatches) { $reason = 'scene_changed' }
  elseif (-not $DriverMatches) { $reason = 'driver_changed' }
  elseif (-not $GameVersionMatches) { $reason = 'game_version_changed' }
  elseif (-not $SettingsMatch -or $ExpectedEnvironmentHash -ne $ActualEnvironmentHash) { $reason = 'settings_changed' }
  elseif ([double]$Metrics.focusLostSec -gt 5) { $reason = 'focus_lost' }
  elseif ([double]$Metrics.gpuTempMax -ge 95) { $reason = 'thermal_anomaly' }
  if ($reason) { return [pscustomobject]@{ validity='invalid'; invalidReason=$reason } }
  if ([double]$Metrics.focusLostSec -gt 0 -or [double]$Metrics.gpuTempMax -ge 90) {
    return [pscustomobject]@{ validity='suspect'; invalidReason=$(if ([double]$Metrics.focusLostSec -gt 0) {'focus_lost'} else {'thermal_anomaly'}) }
  }
  [pscustomobject]@{ validity='valid'; invalidReason='' }
}

function New-TuningRunRecord {
  param(
    [Parameter(Mandatory)][string]$ExperimentId,
    [Parameter(Mandatory)][string]$VariantId,
    [Parameter(Mandatory)][string]$GroupId,
    [Parameter(Mandatory)][int]$RunNo,
    [Parameter(Mandatory)][int]$SequenceNo,
    [Parameter(Mandatory)]$Metrics,
    [Parameter(Mandatory)]$Validity,
    [Parameter(Mandatory)][string]$EnvironmentHash,
    [Parameter(Mandatory)][string]$SettingsHash,
    [bool]$OrderControlled = $true
  )
  if ($ExperimentId -notmatch '^exp_[0-9a-f]{32}$') { throw '实验 ID 无效' }
  if ($VariantId -notmatch '^(?:baseline|[a-z0-9_]{2,64})$' -or $GroupId -notin @('baseline','final','G1','G2','G3')) { throw '运行方案或分组无效' }
  if ($RunNo -lt 1 -or $RunNo -gt 100 -or $SequenceNo -lt 1 -or $SequenceNo -gt 300) { throw '运行序号无效' }
  if ($Validity.validity -notin $script:TuningAllowedValidity -or
      (($Validity.validity -eq 'valid') -and $Validity.invalidReason) -or
      (($Validity.validity -ne 'valid') -and $Validity.invalidReason -notin $script:TuningInvalidReasons)) { throw '运行有效性无效' }
  if ($EnvironmentHash -notmatch '^[0-9a-f]{64}$' -or $SettingsHash -notmatch '^[0-9a-f]{64}$') { throw '运行摘要无效' }
  if (-not (Test-TuningRunMetrics $Metrics ($Validity.validity -eq 'valid'))) { throw '运行指标无效' }
  $record = [pscustomobject][ordered]@{
    runId = 'run_' + [guid]::NewGuid().ToString('N')
    experimentId = $ExperimentId; variantId = $VariantId; groupId = $GroupId
    runNo = $RunNo; sequenceNo = $SequenceNo
    startedAt = "$($Metrics.startedAt)"; completedAt = $(if ($Metrics.completedAt) { "$($Metrics.completedAt)" } else { ConvertTo-TuningUtcText })
    validity = "$($Validity.validity)"; invalidReason = "$($Validity.invalidReason)"
    durationSec = [int]$Metrics.durationSec; frameCount = [int]$Metrics.frameCount
    avgFps = [double]$Metrics.avgFps; fps1Low = [double]$Metrics.fps1Low
    p99FrameMs = [double]$Metrics.p99FrameMs; frameTimeMadMs = [double]$Metrics.frameTimeMadMs
    stutter50Ms = [int]$Metrics.stutter50Ms; stutter100Ms = [int]$Metrics.stutter100Ms
    stuttersPerMin = [double]$Metrics.stuttersPerMin; focusLostSec = [double]$Metrics.focusLostSec
    gpuUtilAvg = [double]$Metrics.gpuUtilAvg; gpuTempAvg = [double]$Metrics.gpuTempAvg
    gpuTempMax = [double]$Metrics.gpuTempMax; gpuPowerAvg = [double]$Metrics.gpuPowerAvg
    settingsHash = $SettingsHash; environmentHash = $EnvironmentHash
    orderControlled = [bool]$OrderControlled
  }
  if (-not (Test-TuningRunMetrics $record ($Validity.validity -eq 'valid'))) { throw '运行指标无效' }
  $record
}

function Get-TuningBaselineSummary([object[]]$Runs) {
  $valid = @($Runs | Where-Object { $_.validity -eq 'valid' -and (Test-TuningRunMetrics $_ $true) })
  $avg = Get-TuningMetricSummary $valid 'avgFps'; $low = Get-TuningMetricSummary $valid 'fps1Low'
  $stable = $valid.Count -ge 3 -and $null -ne $avg.cvPct -and $null -ne $low.cvPct -and $avg.cvPct -le 5 -and $low.cvPct -le 10
  [pscustomobject][ordered]@{
    runs = @($Runs).Count; validRuns = $valid.Count; stable = [bool]$stable
    avgFps = $avg; fps1Low = $low
    p99FrameMs = Get-TuningMetricSummary $valid 'p99FrameMs'
    stuttersPerMin = Get-TuningMetricSummary $valid 'stuttersPerMin'
    gpuTempAvg = Get-TuningMetricSummary $valid 'gpuTempAvg'
    gpuPowerAvg = Get-TuningMetricSummary $valid 'gpuPowerAvg'
    noisePercent = $(if ($null -ne $low.cvPct) { [math]::Round([double]$low.cvPct,2) } else { $null })
  }
}

function Get-TuningDeltaPct($Candidate, $Baseline) {
  if ($null -eq $Candidate -or $null -eq $Baseline -or [double]$Baseline -eq 0) { return $null }
  ([double]$Candidate - [double]$Baseline) * 100.0 / [math]::Abs([double]$Baseline)
}

function Compare-TuningVariant {
  param(
    [Parameter(Mandatory)][object[]]$ControlRuns,
    [Parameter(Mandatory)][object[]]$CandidateRuns,
    [ValidateRange(0,7)][double]$MaxTempIncreaseC = 3,
    [ValidateRange(0,20)][double]$MaxPowerIncreasePct = 0,
    [bool]$AllowHigherPower = $false,
    [switch]$SafetyOnly
  )
  if (-not $AllowHigherPower -and $MaxPowerIncreasePct -ne 0) {
    throw '不允许增加功耗时，功耗增幅上限必须为 0'
  }
  $control = @($ControlRuns | Where-Object { $_.validity -eq 'valid' -and (Test-TuningRunMetrics $_ $true) })
  $candidate = @($CandidateRuns | Where-Object { $_.validity -eq 'valid' -and (Test-TuningRunMetrics $_ $true) })
  if ($control.Count -lt 3 -or $candidate.Count -lt 2) {
    return [pscustomobject]@{ result='insufficient'; reason='有效样本不足'; controlRuns=$control.Count; candidateRuns=$candidate.Count }
  }
  $base = Get-TuningBaselineSummary $control
  if (-not $base.stable) {
    return [pscustomobject]@{ result='insufficient'; reason='对照样本波动过大'; controlRuns=$control.Count; candidateRuns=$candidate.Count }
  }
  $controlVariants = @($control | ForEach-Object { "$($_.variantId)" } | Select-Object -Unique)
  $candidateVariants = @($candidate | ForEach-Object { "$($_.variantId)" } | Select-Object -Unique)
  $environments = @((@($control) + @($candidate)) | ForEach-Object { "$($_.environmentHash)" } | Select-Object -Unique)
  $controlSettings = @($control | ForEach-Object { "$($_.settingsHash)" } | Select-Object -Unique)
  $candidateSettings = @($candidate | ForEach-Object { "$($_.settingsHash)" } | Select-Object -Unique)
  if ($controlVariants.Count -ne 1 -or $candidateVariants.Count -ne 1 -or
      -not $controlVariants[0] -or -not $candidateVariants[0] -or $controlVariants[0] -eq $candidateVariants[0] -or
      $environments.Count -ne 1 -or -not $environments[0] -or $controlSettings.Count -ne 1 -or
      $candidateSettings.Count -ne 1 -or (-not $SafetyOnly -and
      @((@($control) + @($candidate)) | Where-Object { $_.orderControlled -ne $true }).Count)) {
    return [pscustomobject]@{ result='insufficient'; reason='实验环境、设置或顺序不一致'; controlRuns=$control.Count; candidateRuns=$candidate.Count }
  }
  $bAvg = (Get-TuningMetricSummary $control 'avgFps').median; $cAvg = (Get-TuningMetricSummary $candidate 'avgFps').median
  $bLow = (Get-TuningMetricSummary $control 'fps1Low').median; $cLow = (Get-TuningMetricSummary $candidate 'fps1Low').median
  $bP99 = (Get-TuningMetricSummary $control 'p99FrameMs').median; $cP99 = (Get-TuningMetricSummary $candidate 'p99FrameMs').median
  $bStutter = (Get-TuningMetricSummary $control 'stuttersPerMin').median; $cStutter = (Get-TuningMetricSummary $candidate 'stuttersPerMin').median
  $bTemp = (Get-TuningMetricSummary $control 'gpuTempAvg').median; $cTemp = (Get-TuningMetricSummary $candidate 'gpuTempAvg').median
  $bPower = (Get-TuningMetricSummary $control 'gpuPowerAvg').median; $cPower = (Get-TuningMetricSummary $candidate 'gpuPowerAvg').median
  $avgPct = Get-TuningDeltaPct $cAvg $bAvg; $lowPct = Get-TuningDeltaPct $cLow $bLow
  $p99Pct = Get-TuningDeltaPct $cP99 $bP99; $stutterPct = Get-TuningDeltaPct $cStutter $bStutter
  $powerPct = Get-TuningDeltaPct $cPower $bPower
  $tempDelta = $(if ($null -ne $cTemp -and $null -ne $bTemp) { [double]$cTemp - [double]$bTemp } else { $null })
  $noise = $(if ($null -ne $base.noisePercent) { [double]$base.noisePercent } else { 0.0 })
  $threshold = [math]::Max(5.0,$noise * 1.5)
  $directionWins = @($candidate | Where-Object { [double]$_.fps1Low -gt [double]$bLow }).Count
  $requiredDirectionWins = [math]::Ceiling($candidate.Count * 2.0 / 3.0)
  if ($null -eq $avgPct -or $null -eq $lowPct -or $null -eq $p99Pct -or $null -eq $tempDelta) {
    return [pscustomobject]@{ result='insufficient'; reason='对比指标不完整'; controlRuns=$control.Count; candidateRuns=$candidate.Count }
  }
  $hardRollback = ($lowPct -lt -5) -or ($avgPct -lt -4) -or ($tempDelta -gt $MaxTempIncreaseC) -or
                  ($cStutter -gt $bStutter -and ([double]$bStutter -eq 0 -or ($null -ne $stutterPct -and $stutterPct -gt 20))) -or
                  ($null -ne $powerPct -and $powerPct -gt $MaxPowerIncreasePct)
  $wins = (-not $hardRollback) -and $lowPct -ge $threshold -and $avgPct -ge -2 -and
          $cStutter -le $bStutter -and $tempDelta -le $MaxTempIncreaseC -and
          ($null -eq $powerPct -or $powerPct -le $MaxPowerIncreasePct) -and
          $directionWins -ge $requiredDirectionWins
  $scoreP99 = $(if ($null -ne $p99Pct) { $p99Pct } else { 0.0 })
  $scoreStutter = $(if ($null -ne $stutterPct) { $stutterPct } else { 0.0 })
  # 最终组合可用非交替的 A×3/B×3 做一次安全复核，但它不具备独立胜出证据：
  # -SafetyOnly 只允许发现回退风险，安全通过也始终返回 inconclusive。
  $result = $(if ($hardRollback) { 'rollback' } elseif ($wins -and -not $SafetyOnly) { 'win' } else { 'inconclusive' })
  $score = 50.0 + ([math]::Max(-25,[math]::Min(25,$lowPct)) * 0.9) +
           ([math]::Max(-15,[math]::Min(15,$avgPct)) * 0.5) -
           ([math]::Max(-20,[math]::Min(20,$scoreP99)) * 0.45) -
           ([math]::Max(-20,[math]::Min(20,$scoreStutter)) * 0.25)
  if ($null -ne $tempDelta -and $tempDelta -gt 0) { $score -= $tempDelta * 2 }
  if ($null -ne $powerPct -and $powerPct -gt 0) { $score -= $powerPct * 0.35 }
  [pscustomobject][ordered]@{
    result = $result; reason = $(if ($hardRollback) {'触发安全回滚阈值'} elseif ($SafetyOnly) {'最终安全复核通过；非交替样本不作为胜出证据'} elseif ($wins) {'达到确定性保留规则'} else {'变化未超过设备自身噪声或约束'})
    controlRuns = $control.Count; candidateRuns = $candidate.Count
    thresholdPct = [math]::Round($threshold,2); baselineNoisePct = [math]::Round($noise,2)
    avgFpsDeltaPct = [math]::Round($avgPct,2); fps1LowDeltaPct = [math]::Round($lowPct,2)
    p99FrameMsDeltaPct = $(if ($null -ne $p99Pct) {[math]::Round($p99Pct,2)} else {$null})
    stutterDeltaPct = $(if ($null -ne $stutterPct) {[math]::Round($stutterPct,2)} else {$null})
    gpuTempDeltaC = $(if ($null -ne $tempDelta) {[math]::Round($tempDelta,2)} else {$null})
    gpuPowerDeltaPct = $(if ($null -ne $powerPct) {[math]::Round($powerPct,2)} else {$null})
    directionWins = $directionWins; requiredDirectionWins = $requiredDirectionWins
    score = [math]::Round([math]::Max(0,[math]::Min(100,$score)),1)
  }
}

function Add-TuningRun([Parameter(Mandatory)]$State, [Parameter(Mandatory)]$Run) {
  [void](Assert-TuningExperimentState $State)
  if ("$($Run.experimentId)" -ne "$($State.experimentId)") { throw '运行记录不属于当前实验' }
  if (@($State.runs | Where-Object runId -eq $Run.runId).Count -gt 0) { return $State }
  $previous = @($State.runs)
  $State.runs = $previous + @($Run)
  try { [void](Assert-TuningExperimentState $State) }
  catch { $State.runs = $previous; throw }
  $State.updatedAt = ConvertTo-TuningUtcText
  $State
}
