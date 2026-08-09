#requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\tuning-experiment.ps1')

$script:Passed = 0
function Assert-True([bool]$Condition,[string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
  $script:Passed++
}
function Assert-Equal($Expected,$Actual,[string]$Message) {
  if ("$Expected" -cne "$Actual") { throw "ASSERT FAILED: $Message（expected=$Expected actual=$Actual）" }
  $script:Passed++
}
function Assert-Throws([scriptblock]$Action,[string]$Message) {
  $threw = $false
  try { & $Action } catch { $threw = $true }
  Assert-True $threw $Message
}

function New-TestEnvironment {
  [pscustomobject][ordered]@{
    appVersion='0.20.0'; windowsBuild='26100'; gpuModel='NVIDIA GeForce RTX 4070 Laptop GPU'
    driverVersion='32.0.15.8000'; gameVersion='1.2.3.4'; displayMode='2560x1440@165'; sceneId='训练场固定路线'
  }
}

function New-TestRun {
  param(
    [double]$Avg,[double]$Low,[double]$P99,[double]$Stutter,[double]$Temp,[double]$Power,
    [string]$Variant='baseline',[string]$SettingsHash=('a' * 64),[string]$EnvironmentHash=('e' * 64),
    [bool]$OrderControlled=$true
  )
  [pscustomobject][ordered]@{
    validity='valid'; invalidReason=''; variantId=$Variant
    durationSec=120; frameCount=12000; avgFps=$Avg; fps1Low=$Low; p99FrameMs=$P99; frameTimeMadMs=1.2
    stutter50Ms=10; stutter100Ms=2; stuttersPerMin=$Stutter; focusLostSec=0
    gpuUtilAvg=70; gpuTempAvg=$Temp; gpuTempMax=($Temp+3); gpuPowerAvg=$Power
    settingsHash=$SettingsHash; environmentHash=$EnvironmentHash; orderControlled=$OrderControlled
  }
}

function New-TestPendingRunPayload($State,$Run,[string]$WireVariantId='baseline') {
  [pscustomobject][ordered]@{
    installId='11111111-1111-1111-1111-111111111111';event='tuning';version='0.20.0'
    os='Windows 11';build='26100';cpu='Test CPU';gpuVendor='NVIDIA';gpuModel='Test GPU'
    gpuModelVerified=$true;ramGb=32.0;deviceType='desktop';tuningType='run_completed'
    experimentId="$($State.experimentId)";runId="$($State.experimentId).$($Run.runId)"
    variantId="$($State.experimentId).$WireVariantId";runNo=[int]$Run.runNo;sequenceNo=[int]$Run.sequenceNo
    validity="$($Run.validity)";invalidReason="$($Run.invalidReason)";durationSec=[int]$Run.durationSec
    avgFps=[double]$Run.avgFps;fps1Low=[double]$Run.fps1Low;p99FrameMs=[double]$Run.p99FrameMs
    stutter50Ms=[int]$Run.stutter50Ms;stutter100Ms=[int]$Run.stutter100Ms
    gpuUtilAvg=[double]$Run.gpuUtilAvg;gpuTempAvg=[double]$Run.gpuTempAvg;gpuPowerAvg=[double]$Run.gpuPowerAvg
    settingsHash="$($Run.settingsHash)";environmentHash="$($Run.environmentHash)";orderControlled=[bool]$Run.orderControlled
  }
}

$library = @(Get-TuningCandidateLibrary)
Assert-Equal 3 $library.Count '首版候选库只有三组'
Assert-Equal 'G1,G2,G3' (($library.GroupId) -join ',') '候选顺序固定且与服务端枚举一致'
Assert-True (-not (@($library.ItemIds) -contains 'gpu-name-spoof')) '显卡型号伪装不进入自动实验'
Assert-True (-not (@($library | Where-Object RequiresReboot).Count)) '首版候选均无需重启'
Assert-True (-not (@($library | Where-Object RiskLevel -ne 'low').Count)) '首版候选均为低风险'

$hashA = Get-TuningItemSetHash @('dvr-off','game-mode','game-mode')
$hashB = Get-TuningItemSetHash @('GAME-MODE','DVR-OFF')
Assert-Equal $hashA $hashB '优化项集合哈希与顺序/大小写/重复无关'
Assert-Equal '298650b980078d6a0b9d61f874b485db8588523c079e0efadc7a51406074961f' $hashA 'G1 集合哈希与服务端 golden vector 一致'
Assert-True ($hashA -match '^[0-9a-f]{64}$') '优化项集合哈希格式固定'

$environment = New-TestEnvironment
$state = New-TuningExperimentState -SceneId '训练场固定路线' -Environment $environment -MaxTempIncreaseC 3
Assert-True (Assert-TuningExperimentState $state) '新实验状态通过严格校验'
Assert-Equal 'baseline_pending' $state.status '新实验从基线待测开始'
Assert-Equal 0 $state.maxPowerIncreasePct '不允许增加功耗时默认上限为 0'
Assert-Equal $state.environmentHash (Get-TuningEnvironmentHash $environment) '环境哈希可复算'

$tempRoot = Join-Path $PSScriptRoot ('.tuning-test-' + [guid]::NewGuid().ToString('N'))
try {
  $statePath = Join-Path $tempRoot 'exp.json'
  [void](Write-TuningStateAtomic $statePath $state)
  $roundtrip = Read-TuningState $statePath
  Assert-Equal $state.experimentId $roundtrip.experimentId '实验状态原子写入后可读取'
  Assert-Equal 3 @($roundtrip.candidates).Count '候选数组在 Windows PowerShell 5.1 往返后保持平坦'

  $roundtrip.candidates[0].itemSetHash = ('0' * 64)
  Assert-Throws { Assert-TuningExperimentState $roundtrip | Out-Null } '篡改候选集合后失败关闭'
} finally {
  if (Test-Path -LiteralPath $tempRoot) { [IO.Directory]::Delete($tempRoot,$true) }
}

$stableRuns = @(
  (New-TestRun 100 60 20 5 70 100),
  (New-TestRun 101 61 19.8 5 70.5 101),
  (New-TestRun 99 59 20.2 5.2 69.5 99)
)
$stable = Get-TuningBaselineSummary $stableRuns
Assert-True $stable.stable '低波动三次基线判定稳定'
Assert-True ($stable.avgFps.cvPct -le 5 -and $stable.fps1Low.cvPct -le 10) '基线 CV 阈值正确'

$unstableRuns = @(
  (New-TestRun 100 62 20 5 70 100),
  (New-TestRun 101 91 19 5 70 100),
  (New-TestRun 99 75 21 5 70 100)
)
Assert-True (-not (Get-TuningBaselineSummary $unstableRuns).stable) '高波动 1% 低帧率拒绝开始候选比较'

$candidateWins = @(
  (New-TestRun 101 66 18 4 70.8 102 -Variant candidate -SettingsHash ('b' * 64)),
  (New-TestRun 102 67 18.2 4 71.0 103 -Variant candidate -SettingsHash ('b' * 64))
)
$win = Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $candidateWins -MaxTempIncreaseC 3 -MaxPowerIncreasePct 5 -AllowHigherPower $true
Assert-Equal 'win' $win.result '超过动态阈值且代价受控时保留候选'
Assert-True ($win.fps1LowDeltaPct -gt 5 -and $win.score -gt 50) '胜出结果包含确定性变化与得分'

$candidateBad = @(
  (New-TestRun 95 54 24 8 78 115 -Variant candidate -SettingsHash ('b' * 64)),
  (New-TestRun 94 55 25 9 79 118 -Variant candidate -SettingsHash ('b' * 64))
)
$rollback = Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $candidateBad -MaxTempIncreaseC 3 -MaxPowerIncreasePct 5 -AllowHigherPower $true
Assert-Equal 'rollback' $rollback.result '明显掉帧或温升过高立即回滚'

$candidateNoise = @(
  (New-TestRun 101 62 19.8 5 70 100 -Variant candidate -SettingsHash ('b' * 64)),
  (New-TestRun 101 63 19.7 5 70 100 -Variant candidate -SettingsHash ('b' * 64))
)
$unclear = Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $candidateNoise
Assert-Equal 'inconclusive' $unclear.result '小幅变化按噪声处理而非误判提升'

$metrics = [pscustomobject][ordered]@{
  startedAt=[DateTime]::UtcNow.AddMinutes(-2).ToString('o');completedAt=[DateTime]::UtcNow.ToString('o')
  durationSec=120;frameCount=10000;avgFps=100;fps1Low=60;p99FrameMs=20;frameTimeMadMs=1
  stutter50Ms=10;stutter100Ms=2;stuttersPerMin=5;focusLostSec=0;gpuUtilAvg=70;gpuTempAvg=75
  gpuTempMax=80;gpuPowerAvg=100;captureFailed=$false;gameExitedEarly=$false
}
$valid = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'same' -ActualEnvironmentHash 'same'
Assert-Equal 'valid' $valid.validity '满足采样条件的运行有效'
$metrics.durationSec = 80
$short = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'same' -ActualEnvironmentHash 'same'
Assert-Equal 'sample_too_short' $short.invalidReason '不足 90 秒统一枚举原因'
$metrics.durationSec = 120; $metrics.focusLostSec = 8
$focus = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'same' -ActualEnvironmentHash 'same'
Assert-Equal 'focus_lost' $focus.invalidReason '长时间切出游戏判无效'
$metrics.focusLostSec = 0
$driver = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'old' -ActualEnvironmentHash 'new' -DriverMatches $false
Assert-Equal 'driver_changed' $driver.invalidReason '驱动变化使用独立无效原因'
$game = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'old' -ActualEnvironmentHash 'new' -GameVersionMatches $false
Assert-Equal 'game_version_changed' $game.invalidReason '游戏版本变化使用独立无效原因'

$metrics.avgFps = [double]::NaN
$nan = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'same' -ActualEnvironmentHash 'same'
Assert-Equal 'capture_failed' $nan.invalidReason 'NaN 指标失败关闭'
$metrics.avgFps = 100; $metrics.fps1Low = -20
$negative = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'same' -ActualEnvironmentHash 'same'
Assert-Equal 'capture_failed' $negative.invalidReason '负帧率失败关闭'
$metrics.fps1Low = 60; $metrics.p99FrameMs = 0
$zeroP99 = Get-TuningRunValidity -Metrics $metrics -ExpectedEnvironmentHash 'same' -ActualEnvironmentHash 'same'
Assert-Equal 'capture_failed' $zeroP99.invalidReason '有效采样的 P99 为零时失败关闭'
$metrics.p99FrameMs = 20

$unstableAverage = @(
  (New-TestRun 60 59 20 5 70 100),
  (New-TestRun 100 60 20 5 70 100),
  (New-TestRun 140 61 20 5 70 100)
)
$unstableCompare = Compare-TuningVariant -ControlRuns $unstableAverage -CandidateRuns $candidateWins -AllowHigherPower $true -MaxPowerIncreasePct 5
Assert-Equal 'insufficient' $unstableCompare.result '平均帧率基线波动过大时不做胜负结论'

$powerHeavy = @(
  (New-TestRun 101 67 18 4 71 300 -Variant candidate -SettingsHash ('b' * 64)),
  (New-TestRun 102 68 18 4 71 300 -Variant candidate -SettingsHash ('b' * 64))
)
$powerCapped = Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $powerHeavy -AllowHigherPower $true -MaxPowerIncreasePct 5
Assert-Equal 'rollback' $powerCapped.result '允许较高功耗仍必须遵守用户填写的上限'
Assert-Throws { Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $candidateWins -AllowHigherPower $false -MaxPowerIncreasePct 5 | Out-Null } '未允许增功耗时拒绝非零上限'
$zeroStutterBaseline = @(
  (New-TestRun 100 60 20 0 70 100),
  (New-TestRun 101 61 20 0 70 100),
  (New-TestRun 99 59 20 0 70 100)
)
$introducedStutter = @(
  (New-TestRun 101 67 18 1 70 100 -Variant candidate -SettingsHash ('b' * 64)),
  (New-TestRun 102 68 18 1 70 100 -Variant candidate -SettingsHash ('b' * 64))
)
Assert-Equal 'rollback' (Compare-TuningVariant -ControlRuns $zeroStutterBaseline -CandidateRuns $introducedStutter).result '基线零卡顿时候选引入卡顿必须回滚'

$differentEnvironment = @(
  (New-TestRun 101 66 18 4 70 100 -Variant candidate -SettingsHash ('b' * 64) -EnvironmentHash ('f' * 64)),
  (New-TestRun 102 67 18 4 70 100 -Variant candidate -SettingsHash ('b' * 64) -EnvironmentHash ('f' * 64))
)
Assert-Equal 'insufficient' (Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $differentEnvironment).result '跨环境样本不参与比较'
$differentSettings = @(
  (New-TestRun 101 66 18 4 70 100 -Variant candidate -SettingsHash ('b' * 64)),
  (New-TestRun 102 67 18 4 70 100 -Variant candidate -SettingsHash ('c' * 64))
)
Assert-Equal 'insufficient' (Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $differentSettings).result '候选设置摘要变化时不参与比较'
$uncontrolledOrder = @(
  (New-TestRun 101 66 18 4 70 100 -Variant candidate -SettingsHash ('b' * 64) -OrderControlled $false),
  (New-TestRun 102 67 18 4 70 100 -Variant candidate -SettingsHash ('b' * 64))
)
Assert-Equal 'insufficient' (Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $uncontrolledOrder).result '顺序未受控的样本不参与比较'
$finalSafety = Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $uncontrolledOrder -SafetyOnly
Assert-Equal 'inconclusive' $finalSafety.result '非交替最终复测只作安全检查，不产生新的胜出证据'
$uncontrolledBad = @(
  (New-TestRun 80 40 30 10 80 140 -Variant candidate -SettingsHash ('b' * 64) -OrderControlled $false),
  (New-TestRun 81 41 30 10 80 140 -Variant candidate -SettingsHash ('b' * 64) -OrderControlled $false)
)
Assert-Equal 'rollback' (Compare-TuningVariant -ControlRuns $stableRuns -CandidateRuns $uncontrolledBad -SafetyOnly).result '最终安全复测即使非交替也能触发回滚'

$strictState = New-TuningExperimentState -SceneId '训练场固定路线' -Environment (New-TestEnvironment)
$strictState.candidates[0] | Add-Member -NotePropertyName injected -NotePropertyValue 'bad'
Assert-Throws { Assert-TuningExperimentState $strictState | Out-Null } '候选未知字段失败关闭'
$strictState = New-TuningExperimentState -SceneId '训练场固定路线' -Environment (New-TestEnvironment)
$strictState.candidates[0].result = 'win'
Assert-Throws { Assert-TuningExperimentState $strictState | Out-Null } '候选结果与状态/备份矛盾时失败关闭'

$runMetrics = [pscustomobject][ordered]@{}
foreach ($property in $metrics.PSObject.Properties) { $runMetrics | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value }
$validity = [pscustomobject]@{validity='valid';invalidReason=''}
$record = New-TuningRunRecord -ExperimentId $state.experimentId -VariantId baseline -GroupId baseline -RunNo 1 -SequenceNo 1 `
  -Metrics $runMetrics -Validity $validity -EnvironmentHash ('e' * 64) -SettingsHash ('a' * 64)

# pendingTuningCommit 是 run/首次 B1 的崩溃恢复事务记录。它必须严格、可原子往返，
# 且非空 exact payload 的业务实体必须和本地 run/候选引用一致。
$pendingState = New-TuningExperimentState -SceneId '训练场固定路线' -Environment (New-TestEnvironment)
$pendingState | Add-Member -NotePropertyName phase -NotePropertyValue baseline
$pendingRecord = New-TuningRunRecord -ExperimentId $pendingState.experimentId -VariantId baseline -GroupId baseline -RunNo 1 -SequenceNo 1 `
  -Metrics $runMetrics -Validity $validity -EnvironmentHash ('e' * 64) -SettingsHash ('a' * 64)
$pendingState.runs = @($pendingRecord)
$pendingPayload = New-TestPendingRunPayload $pendingState $pendingRecord
$pendingState | Add-Member -NotePropertyName pendingTuningCommit -NotePropertyValue ([pscustomobject][ordered]@{
  schemaVersion=1;kind='run';telemetryType='run_completed';sourcePhase='baseline';candidateIndex=-1
  entityId="$($pendingRecord.runId)";resumePhase='';outcome='';unsafeFailure=$false;reason='';payload=$pendingPayload
})
Assert-True (Assert-TuningExperimentState $pendingState) '合法 pending run/exact payload 未通过严格状态校验'

$pendingRoot = Join-Path $PSScriptRoot ('.tuning-pending-' + [guid]::NewGuid().ToString('N'))
try {
  $pendingPath = Join-Path $pendingRoot 'state.json'
  [void](Write-TuningStateAtomic $pendingPath $pendingState)
  $pendingRoundtrip = Read-TuningState $pendingPath
  Assert-Equal $pendingRecord.runId $pendingRoundtrip.pendingTuningCommit.entityId 'pending run ID 原子往返后漂移'
  Assert-Equal $pendingPayload.runId $pendingRoundtrip.pendingTuningCommit.payload.runId 'pending exact payload 原子往返后漂移'
  Assert-Equal 'run' $pendingRoundtrip.pendingTuningCommit.kind 'pending kind 原子往返后漂移'
  $pendingState.pendingTuningCommit.reason='second atomic replace'
  [void](Write-TuningStateAtomic $pendingPath $pendingState)
  $pendingRoundtrip = Read-TuningState $pendingPath
  Assert-Equal 'second atomic replace' $pendingRoundtrip.pendingTuningCommit.reason '同一路径第二次原子 Replace 丢失 pending commit'
} finally {
  if (Test-Path -LiteralPath $pendingRoot) { [IO.Directory]::Delete($pendingRoot,$true) }
}

$badPending = $pendingState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$badPending.pendingTuningCommit | Add-Member -NotePropertyName injected -NotePropertyValue 'bad'
Assert-Throws { Assert-TuningExperimentState $badPending | Out-Null } 'pending commit 未知字段没有失败关闭'
$badPending = $pendingState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$badPending.pendingTuningCommit.payload.runId = "$($pendingState.experimentId).run_$('f'*32)"
Assert-Throws { Assert-TuningExperimentState $badPending | Out-Null } 'pending payload 可指向不同业务 runId'
$badPending = $pendingState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$badPending.pendingTuningCommit.payload.experimentId = 'exp_'+('f'*32)
Assert-Throws { Assert-TuningExperimentState $badPending | Out-Null } 'pending payload 可跨实验恢复'

# 用户关闭遥测或真实 GPU 未验证时 payload 合法为空，但本地 run 引用和 commit schema 仍需有效。
$optOutPending = $pendingState | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$optOutPending.pendingTuningCommit.payload = $null
Assert-True (Assert-TuningExperimentState $optOutPending) '遥测 opt-out 的本地 pending run 被错误拒绝'

$badVariantPhase = New-TuningExperimentState -SceneId '训练场固定路线' -Environment (New-TestEnvironment)
$badVariantPhase | Add-Member -NotePropertyName phase -NotePropertyValue baseline
$badVariantPhase | Add-Member -NotePropertyName pendingActionId -NotePropertyValue ([guid]::NewGuid().ToString())
$badVariantPhase.candidates[0] | Add-Member -NotePropertyName sequenceNo -NotePropertyValue 1
$badVariantPhase | Add-Member -NotePropertyName pendingTuningCommit -NotePropertyValue ([pscustomobject][ordered]@{
  schemaVersion=1;kind='variant';telemetryType='variant_applied';sourcePhase='applying';candidateIndex=0
  entityId='background_low_risk';resumePhase='group_capture_b1';outcome='failed';unsafeFailure=$false;reason='fixture';payload=$null
})
Assert-Throws { Assert-TuningExperimentState $badVariantPhase | Out-Null } 'variant pending 在 baseline 阶段被错误接受'

$badB1Progress = New-TuningExperimentState -SceneId '训练场固定路线' -Environment (New-TestEnvironment)
$badB1Run = New-TuningRunRecord -ExperimentId $badB1Progress.experimentId -VariantId background_low_risk -GroupId G1 -RunNo 1 -SequenceNo 1 `
  -Metrics $runMetrics -Validity $validity -EnvironmentHash ('e' * 64) -SettingsHash ('a' * 64)
$badB1Progress.runs=@($badB1Run)
$badB1Progress | Add-Member -NotePropertyName phase -NotePropertyValue group_rollback_a
$badB1Progress.candidates[0] | Add-Member -NotePropertyName candidateRunIds -NotePropertyValue @()
$badB1Progress | Add-Member -NotePropertyName pendingTuningCommit -NotePropertyValue ([pscustomobject][ordered]@{
  schemaVersion=1;kind='run';telemetryType='run_completed';sourcePhase='group_capture_b1';candidateIndex=0
  entityId="$($badB1Run.runId)";resumePhase='';outcome='';unsafeFailure=$false;reason='';payload=$null
})
Assert-Throws { Assert-TuningExperimentState $badB1Progress | Out-Null } 'phase 已离开 B1 但 candidateRunIds 未消费 pending run 时被错误接受'

# final 安全复核可能在逐份回滚 G3→G2→G1 时崩溃。pending run 记录的是回滚前的
# 最终组合；currentBest 会逐步退回，但只要 finalRunIds 仍指向同一个真实方案就应可恢复。
$finalState = New-TuningExperimentState -SceneId '训练场固定路线' -Environment (New-TestEnvironment)
$backupRoot = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)) 'DeltaForceBooster\backup'
$backupRefs = @(1..3 | ForEach-Object { Join-Path $backupRoot ('backup-' + [guid]::NewGuid().ToString() + '.json') })
for($i=0;$i -lt 3;$i++){
  $finalState.candidates[$i].status='complete';$finalState.candidates[$i].result='win'
  $finalState.candidates[$i].appliedBackups=@($backupRefs[$i])
}
$finalState.activeBackups=@($backupRefs)
$finalState.currentBestGroups=@('G1','G2','G3');$finalState.currentBestVariantId='display_path';$finalState.candidateIndex=3
$finalRun = New-TuningRunRecord -ExperimentId $finalState.experimentId -VariantId display_path -GroupId final -RunNo 1 -SequenceNo 1 `
  -Metrics $runMetrics -Validity $validity -EnvironmentHash ('e' * 64) -SettingsHash ('a' * 64) -OrderControlled $false
$finalState.runs=@($finalRun)
$finalState | Add-Member -NotePropertyName phase -NotePropertyValue rolling_back
$finalState | Add-Member -NotePropertyName finalRunIds -NotePropertyValue @($finalRun.runId)
$finalState | Add-Member -NotePropertyName pendingTuningCommit -NotePropertyValue ([pscustomobject][ordered]@{
  schemaVersion=1;kind='run';telemetryType='run_completed';sourcePhase='final_capture';candidateIndex=3
  entityId="$($finalRun.runId)";resumePhase='';outcome='';unsafeFailure=$false;reason='';payload=$null
})
Assert-True (Assert-TuningExperimentState $finalState) 'final pending 在 G3→G2→G1 回滚开始时被拒绝'

$finalState.candidates[2].result='rollback';$finalState.candidates[2].appliedBackups=@()
$finalState.activeBackups=@($backupRefs[0..1]);$finalState.currentBestGroups=@('G1','G2');$finalState.currentBestVariantId='foreground_scheduler'
Assert-True (Assert-TuningExperimentState $finalState) 'final pending 在回滚 G3 后随 currentBest=G2 被拒绝'
$finalState.candidates[1].result='rollback';$finalState.candidates[1].appliedBackups=@()
$finalState.activeBackups=@($backupRefs[0]);$finalState.currentBestGroups=@('G1');$finalState.currentBestVariantId='background_low_risk'
Assert-True (Assert-TuningExperimentState $finalState) 'final pending 在回滚 G2 后随 currentBest=G1 被拒绝'
$finalState.candidates[0].result='rollback';$finalState.candidates[0].appliedBackups=@()
$finalState.activeBackups=@();$finalState.currentBestGroups=@();$finalState.currentBestVariantId='baseline'
Assert-True (Assert-TuningExperimentState $finalState) 'final pending 在全部回滚至 baseline 后被拒绝'

$record.avgFps = [double]::NaN
$stateWithBadRun = New-TuningExperimentState -SceneId '训练场固定路线' -Environment (New-TestEnvironment)
$stateWithBadRun.runs = @($record)
Assert-Throws { Assert-TuningExperimentState $stateWithBadRun | Out-Null } '持久化运行中的 NaN 失败关闭'

Write-Output "Tuning experiment tests passed: $script:Passed assertions"
