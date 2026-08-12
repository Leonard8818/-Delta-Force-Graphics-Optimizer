#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'
$rulesPath = Join-Path $root 'scripts\tuning-experiment.ps1'
$enginePath = Join-Path $root 'scripts\delta-booster.ps1'
$serverPath = Join-Path $root 'server\report_server.py'

function Assert-True([bool]$Condition,[string]$Message) {
  if(-not $Condition){throw "ASSERT FAILED: $Message"}
}
function Assert-Throws([scriptblock]$Action,[string]$Message) {
  try{& $Action;throw "ASSERT FAILED: $Message"}catch{if($_.Exception.Message -like 'ASSERT FAILED:*'){throw}}
}

$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($guiPath,[ref]$tokens,[ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI PowerShell AST parse failed: ' + (($errors|ForEach-Object Message) -join '; '))
$raw=Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
$guiVersionMatch=[regex]::Match($raw,'(?m)^\$script:GuiVersion\s*=\s*''([^'']+)''\s*$')
Assert-True $guiVersionMatch.Success 'GUI version declaration not found'
$xamlMatch=[regex]::Match($raw,"(?s)\$xaml = @'\r?\n(.*?)\r?\n'@")
Assert-True $xamlMatch.Success 'main XAML here-string not found'
Add-Type -AssemblyName PresentationFramework
[void][Windows.Markup.XamlReader]::Parse($xamlMatch.Groups[1].Value)

foreach($needle in @(
  'x:Name="TabTuneBtn"','x:Name="TunePage"','x:Name="TuneCreateBtn"','x:Name="TuneNextBtn"','x:Name="TuneStopBtn"',
  "Invoke-ElevatedEngineAction -Action Restore -BackupFile",'Test-TuningExperimentActive','active-experiment.json',
  "'DeltaForceClient-Win64-Shipping.exe','DeltaForce.exe'",'scripts\tuning-experiment.ps1',
  "Send-TuningTelemetryEvent -TuningType 'experiment_started'", "New-TuningTelemetryEventPayload -TuningType 'variant_applied'",
  "New-TuningTelemetryEventPayload -TuningType 'run_completed'", "Send-TuningTelemetryEvent -TuningType 'experiment_completed'",
  "if(`$GroupId -ne 'final')", "'final' `$false", '-SafetyOnly',
  "`$Process.StartTime.ToUniversalTime() -lt [DateTime]::Parse", "groupRestartAfter=[DateTime]::UtcNow.ToString('o')"
)) { Assert-True $raw.Contains($needle) "GUI missing required tuning integration: $needle" }

$applyFunction=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-TuningApplyCandidate'},$true)|Select-Object -First 1)
Assert-True ($applyFunction.Count -eq 1) 'tuning apply function not found'
$applyText=$applyFunction[0].Extent.Text
Assert-True (([regex]::Matches($applyText,"New-TuningTelemetryEventPayload -TuningType 'variant_applied'")).Count -eq 1) 'variant telemetry payload is created more than once across B1/B2/retry'
Assert-True $applyText.Contains("if(`$ResumePhase -eq 'group_capture_b1')") 'variant telemetry is not limited to the first committed B1 apply'
Assert-True $applyText.Contains('$expectedBoundary=[int](@($state.runs).Count+1)') 'first B1 apply does not persist the exact run-membership boundary'

# Run / first-B1 apply 使用同一个持久 commit 屏障：业务结果和 exact payload 先在同一份
# experiment state 中原子落盘，outbox Add 成功后才允许推进实验阶段。
$pendingFunctions=@{}
foreach($functionName in 'Set-PendingTuningCommit','Resume-PendingTuningCommit','Complete-TuningVariantApplyDisposition',
  'Test-PendingTuningRunConsumed','Test-PendingTuningRunCompleted','Invoke-TuningPerformanceCapture','Invoke-NextTuningStep','Load-ActiveTuningExperiment'){
  $fn=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $functionName},$true)|Select-Object -First 1)
  Assert-True ($fn.Count -eq 1) "pending tuning function not found: $functionName"
  $pendingFunctions[$functionName]=$fn[0]
}
$setPendingText=$pendingFunctions['Set-PendingTuningCommit'].Extent.Text
$resumePendingText=$pendingFunctions['Resume-PendingTuningCommit'].Extent.Text
$captureText=$pendingFunctions['Invoke-TuningPerformanceCapture'].Extent.Text
$nextText=$pendingFunctions['Invoke-NextTuningStep'].Extent.Text
$loadText=$pendingFunctions['Load-ActiveTuningExperiment'].Extent.Text

$pendingAssignOffset=$setPendingText.IndexOf('$state.pendingTuningCommit=',[StringComparison]::Ordinal)
$pendingSaveOffset=$setPendingText.IndexOf('Save-TuningExperiment',[StringComparison]::Ordinal)
Assert-True ($pendingAssignOffset -ge 0 -and $pendingSaveOffset -gt $pendingAssignOffset) 'pending commit is not atomically saved with its exact payload'
foreach($field in 'schemaVersion','kind','telemetryType','sourcePhase','candidateIndex','entityId','resumePhase','outcome','unsafeFailure','reason','payload'){
  Assert-True ($setPendingText -match ("(?m)\b"+[regex]::Escape($field)+"\s*=")) "pending commit omitted strict field: $field"
}

$pendingSendOffset=$resumePendingText.IndexOf('Send-TuningTelemetryPayload -Payload $pending.payload',[StringComparison]::Ordinal)
$pendingAdvanceOffset=$resumePendingText.IndexOf('Advance-TuningAfterValidRun',[StringComparison]::Ordinal)
$pendingVariantOffset=$resumePendingText.IndexOf('Complete-TuningVariantApplyDisposition',[StringComparison]::Ordinal)
$pendingClearOffset=$resumePendingText.IndexOf('$state.pendingTuningCommit=$null',[StringComparison]::Ordinal)
Assert-True ($pendingSendOffset -ge 0 -and $resumePendingText.Contains('-RequirePersistence')) 'pending exact payload is not durably added to outbox'
Assert-True ($pendingAdvanceOffset -gt $pendingSendOffset -and $pendingClearOffset -gt $pendingAdvanceOffset) 'pending run advances or clears before durable outbox Add'
Assert-True ($pendingVariantOffset -gt $pendingSendOffset) 'first-B1 apply disposition advances before durable outbox Add'
Assert-True ($resumePendingText.Contains('"$($pending.sourcePhase)"') -and $resumePendingText.Contains('([int]$pending.candidateIndex)')) 'pending run does not replay its persisted source phase/index'

$captureAddOffset=$captureText.IndexOf('Add-TuningRun',[StringComparison]::Ordinal)
$capturePayloadOffset=$captureText.IndexOf("New-TuningTelemetryEventPayload -TuningType 'run_completed'",[StringComparison]::Ordinal)
$capturePendingOffset=$captureText.IndexOf('Set-PendingTuningCommit -Kind run',[StringComparison]::Ordinal)
Assert-True ($capturePayloadOffset -ge 0 -and $captureAddOffset -gt $capturePayloadOffset -and $capturePendingOffset -gt $captureAddOffset) 'exact payload is not generated before adding/persisting the captured run'
Assert-True (-not $captureText.Contains("Send-TuningTelemetryEvent -TuningType 'run_completed'")) 'run telemetry bypasses the pending commit barrier'
Assert-True (-not $captureText.Contains('Advance-TuningAfterValidRun')) 'capture advances before pending outbox commit'

$nextResumeOffset=$nextText.IndexOf('Resume-PendingTuningCommit',[StringComparison]::Ordinal)
$nextCaptureOffset=$nextText.IndexOf('Invoke-TuningPerformanceCapture',[StringComparison]::Ordinal)
Assert-True ($nextResumeOffset -ge 0 -and $nextResumeOffset -lt $nextCaptureOffset) 'Next does not resume the durable pending commit before new capture/apply work'
Assert-True (-not $nextText.Contains('Advance-TuningAfterValidRun')) 'Next bypasses Resume-PendingTuningCommit and advances a fresh run directly'
$loadResumeOffset=$loadText.IndexOf('Resume-PendingTuningCommit',[StringComparison]::Ordinal)
$loadDecisionOffset=$loadText.IndexOf('if("$($state.status)"',[StringComparison]::Ordinal)
Assert-True ($loadResumeOffset -ge 0 -and $loadDecisionOffset -gt $loadResumeOffset) 'restart does not resume pending commit before terminal/apply decisions'
$advanceFunction=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Advance-TuningAfterValidRun'},$true)|Select-Object -First 1)
Assert-True ($advanceFunction.Count -eq 1) 'Advance-TuningAfterValidRun not found'
$advanceText=$advanceFunction[0].Extent.Text
Assert-True ($advanceText.Contains('$resumeSafetyRollback=') -and $advanceText.Contains('$state.finalComparison') -and
  $advanceText.Contains("status='rolled_back';result='rolled_back'")) 'final rollback restart can recompute an empty currentBest as no_gain'
Assert-True ($advanceText.Contains("`$state.stopReason=`$(if(`$autoRollback){'safety_threshold'}")) 'resumed safety rollback does not retain safety_threshold'

# 所有终态都必须走同一持久化边界：先把 completion 事件写入因果 outbox，
# 再清理活动指针。禁止任一失败/取消分支自行 Save -Terminal 或重复上报 completion。
$terminalFunction=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Complete-GuiTuningExperimentTerminal'},$true)|Select-Object -First 1)
Assert-True ($terminalFunction.Count -eq 1) 'central tuning terminal function not found'
$terminalText=$terminalFunction[0].Extent.Text
Assert-True $terminalText.Contains('Save-TuningExperiment -Terminal') 'central terminal function does not persist terminal state/clear the pointer'
Assert-True ($terminalText -match "Send-TuningTelemetryEvent\s+-TuningType\s+'experiment_completed'") 'central terminal function does not persist experiment_completed'
$completionPersistOffset=$terminalText.IndexOf("Send-TuningTelemetryEvent -TuningType 'experiment_completed'",[StringComparison]::Ordinal)
$terminalSaveOffset=$terminalText.IndexOf('Save-TuningExperiment -Terminal',[StringComparison]::Ordinal)
Assert-True ($completionPersistOffset -ge 0 -and $terminalSaveOffset -gt $completionPersistOffset) 'active pointer is cleared before experiment_completed is durably enqueued'

$terminalSaves=@($ast.FindAll({
  param($n)
  $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Save-TuningExperiment' -and
    @($n.CommandElements|Where-Object{$_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -eq 'Terminal'}).Count -eq 1
},$true))
Assert-True ($terminalSaves.Count -eq 1) 'Save-TuningExperiment -Terminal escaped the central terminal function'
Assert-True ($terminalSaves[0].Extent.StartOffset -ge $terminalFunction[0].Extent.StartOffset -and
  $terminalSaves[0].Extent.EndOffset -le $terminalFunction[0].Extent.EndOffset) 'terminal save is outside Complete-GuiTuningExperimentTerminal'

$completionSends=@($ast.FindAll({
  param($n)
  $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Send-TuningTelemetryEvent' -and
    $n.Extent.Text -match "(?s)-TuningType\s+'experiment_completed'"
},$true))
Assert-True ($completionSends.Count -eq 1) 'experiment_completed must be emitted exactly once, only by the central terminal function'
Assert-True ($completionSends[0].Extent.StartOffset -ge $terminalFunction[0].Extent.StartOffset -and
  $completionSends[0].Extent.EndOffset -le $terminalFunction[0].Extent.EndOffset) 'experiment_completed emission is outside Complete-GuiTuningExperimentTerminal'

$terminalCalls=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Complete-GuiTuningExperimentTerminal'},$true))
Assert-True ($terminalCalls.Count -ge 12) 'one or more GUI terminal branches bypass the central terminal function'
foreach($functionName in 'Complete-TuningVariantApplyDisposition','Complete-TuningCandidate','Invoke-TuningFinalRollback',
  'Advance-TuningAfterValidRun','Invoke-NextTuningStep','Stop-GuiTuningExperiment','Load-ActiveTuningExperiment'){
  $fn=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $functionName},$true)|Select-Object -First 1)
  Assert-True ($fn.Count -eq 1 -and $fn[0].Extent.Text.Contains('Complete-GuiTuningExperimentTerminal')) "$functionName has a terminal path that is not centralized"
}

. $rulesPath
. $enginePath

# 行为级验证收口顺序：completion 持久化失败时必须保留活动指针；成功时才清理并启动发送。
& {
  param([string]$FunctionText)
  $previousActive=$script:ActiveTuningExperiment
  try{
    $script:ActiveTuningExperiment=[pscustomobject]@{status='failed';completedAt='';pendingTuningCommit=$null}
    $script:TerminalTrace=New-Object 'System.Collections.Generic.List[string]'
    $script:FailTerminalPersistence=$true
    $script:TerminalAutoRollback=$null
    function Save-TuningExperiment {
      param([switch]$Terminal)
      [void]$script:TerminalTrace.Add($(if($Terminal){'save-terminal'}else{'save-active'}))
    }
    function Send-TuningTelemetryEvent {
      param([string]$TuningType,$State,$Candidate,$Run,$Result,[switch]$DeferFlush,[switch]$RequirePersistence)
      Assert-True ($TuningType -eq 'experiment_completed' -and $DeferFlush -and $RequirePersistence) 'terminal completion is not synchronously persisted before flush'
      $script:TerminalAutoRollback=[bool]$Result.autoRollback
      [void]$script:TerminalTrace.Add('persist-completion')
      if($script:FailTerminalPersistence){throw 'simulated outbox persistence failure'}
    }
    function Start-TuningTelemetryOutboxFlush {[void]$script:TerminalTrace.Add('flush')}
    function Update-TuningUi {[void]$script:TerminalTrace.Add('ui')}
    Invoke-Expression $FunctionText

    Assert-Throws {Complete-GuiTuningExperimentTerminal $true} 'terminal persistence failure cleared the pointer'
    Assert-True (($script:TerminalTrace -join ',') -eq 'save-active,persist-completion') 'terminal persistence failure did not stop before pointer cleanup'
    Assert-True ([bool]$script:TerminalAutoRollback) 'autoRollback was lost from failed completion persistence attempt'
    Assert-True ([bool]$script:ActiveTuningExperiment.completedAt) 'terminal closure did not stamp completedAt before durable save'

    $script:TerminalTrace.Clear();$script:FailTerminalPersistence=$false;$script:TerminalAutoRollback=$null
    Complete-GuiTuningExperimentTerminal $false
    Assert-True (($script:TerminalTrace -join ',') -eq 'save-active,persist-completion,save-terminal,flush,ui') 'terminal closure persistence/cleanup order changed'
    Assert-True (-not [bool]$script:TerminalAutoRollback) 'autoRollback=false was not preserved in completion payload'
  }finally{
    $script:ActiveTuningExperiment=$previousActive
    Remove-Variable TerminalTrace,FailTerminalPersistence,TerminalAutoRollback -Scope Script -ErrorAction SilentlyContinue
  }
} $terminalText

# State file Replace 成功而 active pointer 后续写失败时，Set catch 必须从磁盘读回 pending，
# 不能删除刚保存的 run 后让用户在重启后重复采样。
$saveFunction=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Save-TuningExperiment'},$true)|Select-Object -First 1)
Assert-True ($saveFunction.Count -eq 1) 'Save-TuningExperiment not found for pointer crash test'
& {
  param([string]$SaveText,[string]$SetText)
  $previousActive=$script:ActiveTuningExperiment;$previousPath=$script:ActiveTuningStatePath
  try{
    $script:PointerCommitHarness=[pscustomobject]@{Persisted=$null;Pointer='';PointerWrites=0;FailPointer=$true}
    function Assert-TuningGuiState($State){$true}
    function Write-TuningStateAtomic([string]$Path,$State){
      $script:PointerCommitHarness.Persisted=$State|ConvertTo-Json -Depth 20|ConvertFrom-Json
      $Path
    }
    function Read-TuningState([string]$Path){$script:PointerCommitHarness.Persisted|ConvertTo-Json -Depth 20|ConvertFrom-Json}
    function Read-TuningPointerStrict {$script:PointerCommitHarness.Pointer}
    function Write-TuningPointerAtomic([string]$ExperimentId){
      $script:PointerCommitHarness.PointerWrites++
      if($script:PointerCommitHarness.FailPointer){throw 'simulated pointer write failure'}
      $script:PointerCommitHarness.Pointer=$ExperimentId
    }
    function Initialize-TuningGuiStateFields($State){$State}
    function Clear-TuningPointer {}
    Invoke-Expression $SaveText
    Invoke-Expression $SetText

    $runId='run_'+[guid]::NewGuid().ToString('N');$experimentId='exp_'+[guid]::NewGuid().ToString('N')
    $script:ActiveTuningStatePath='C:\fixture\experiment.json'
    $script:ActiveTuningExperiment=[pscustomobject]@{
      experimentId=$experimentId;runs=@([pscustomobject]@{runId=$runId});pendingTuningCommit=$null
    }
    Assert-Throws {
      Set-PendingTuningCommit -Kind run -SourcePhase baseline -CandidateIndex -1 -EntityId $runId -Payload $null|Out-Null
    } 'pointer failure after state Replace did not propagate'
    Assert-True ($script:ActiveTuningExperiment.pendingTuningCommit -and
      @($script:ActiveTuningExperiment.runs|Where-Object runId -eq $runId).Count -eq 1) 'pointer failure rolled back a durably saved pending run'
    Assert-True ($script:PointerCommitHarness.PointerWrites -eq 1) 'pointer failure fixture did not reach the post-state pointer write'

    # Once the pointer already names this experiment, ordinary state saves must not rewrite it.
    $script:PointerCommitHarness.Pointer=$experimentId
    $writesBefore=$script:PointerCommitHarness.PointerWrites
    Save-TuningExperiment
    Assert-True ($script:PointerCommitHarness.PointerWrites -eq $writesBefore) 'active experiment save rewrote an already-correct pointer'
  }finally{
    $script:ActiveTuningExperiment=$previousActive;$script:ActiveTuningStatePath=$previousPath
    Remove-Variable PointerCommitHarness -Scope Script -ErrorAction SilentlyContinue
  }
} $saveFunction[0].Extent.Text $setPendingText

# 精确 payload 生成是把 run 加入活动状态的前置条件。生成器失败时不得留下没有
# pending continuation 的 ghost run，否则下一轮会错误增加 runNo/sequenceNo。
$captureTailStart=$captureText.IndexOf('$run=New-TuningRunRecord',[StringComparison]::Ordinal)
$captureTailEnd=$captureText.IndexOf('$state=$script:ActiveTuningExperiment',[Math]::Max(0,$captureAddOffset),[StringComparison]::Ordinal)
Assert-True ($captureTailStart -ge 0 -and $captureTailEnd -gt $captureTailStart) 'capture commit tail not found for payload failure test'
$captureCommitTail=$captureText.Substring($captureTailStart,$captureTailEnd-$captureTailStart)
& {
  param([string]$Tail)
  $previousActive=$script:ActiveTuningExperiment
  try{
    $script:GhostRunHarness=[pscustomobject]@{AddCalls=0;PayloadCalls=0}
    function New-TuningRunRecord {
      param($ExperimentId,$VariantId,$GroupId,$RunNo,$SequenceNo,$Metrics,$Validity,$EnvironmentHash,$SettingsHash,[bool]$OrderControlled)
      [pscustomobject]@{runId=('run_'+[guid]::NewGuid().ToString('N'));variantId=$VariantId;validity='valid'}
    }
    function New-TuningTelemetryEventPayload {
      param($TuningType,$State,$Candidate,$Run,$Result,[switch]$RequirePersistence)
      $script:GhostRunHarness.PayloadCalls++
      throw 'simulated exact payload generator failure'
    }
    function Add-TuningRun($State,$Run){$script:GhostRunHarness.AddCalls++;$State.runs=@($State.runs)+@($Run);$State}
    $script:ActiveTuningExperiment=[pscustomobject]@{experimentId=('exp_'+[guid]::NewGuid().ToString('N'));runs=@()}
    $state=$script:ActiveTuningExperiment;$VariantId='background_low_risk';$GroupId='G1';$runNo=1;$sequenceNo=1
    $metrics=[pscustomobject]@{presentMonExitCode=0;gameExitedEarly=$false;captureFailed=$false}
    $validity=[pscustomobject]@{validity='valid';invalidReason=''};$afterHash=('a'*64);$settingsAfter=('b'*64);$OrderControlled=$true
    Assert-Throws {Invoke-Expression $Tail} 'payload generator failure did not abort capture commit'
    Assert-True ($script:GhostRunHarness.PayloadCalls -eq 1 -and $script:GhostRunHarness.AddCalls -eq 0 -and
      -not @($script:ActiveTuningExperiment.runs).Count) 'payload generator failure left a ghost run in state'
  }finally{
    $script:ActiveTuningExperiment=$previousActive
    Remove-Variable GhostRunHarness -Scope Script -ErrorAction SilentlyContinue
  }
} $captureCommitTail

# 行为级故障注入：把 experiment state 当成进程重启后唯一可信输入，把 outbox 当成
# 独立持久介质。依次覆盖 run 保存前、outbox Add 前/失败、Add 后 Advance 前，以及
# Advance 已保存但 pending 清理前退出；最终业务顺序必须仍然只有 B1、A、B2。
& {
  param([string]$SetText,[string]$ResumeText,[string]$ConsumedText,[string]$CompletedText,[string]$AdvanceText,[string]$TelemetryPath)
  $previousActive=$script:ActiveTuningExperiment
  $previousGuiVersion=$script:GuiVersion
  try{
    . $TelemetryPath
    $h=[pscustomobject]@{
      PersistedJson='';FailAdd=$false;FailClearOnce=$false
      Outbox=@{};OutboxOrder=(New-Object 'System.Collections.Generic.List[string]')
      Trace=(New-Object 'System.Collections.Generic.List[string]')
    }
    $script:PendingCommitHarness=$h

    function Save-TuningExperiment {
      param([switch]$Terminal)
      if($script:PendingCommitHarness.FailClearOnce -and -not $script:ActiveTuningExperiment.pendingTuningCommit){
        $script:PendingCommitHarness.FailClearOnce=$false
        throw 'simulated crash after Advance save, before pending clear save'
      }
      $script:PendingCommitHarness.PersistedJson=$script:ActiveTuningExperiment|ConvertTo-Json -Compress -Depth 30
      [void]$script:PendingCommitHarness.Trace.Add('save')
    }
    function Restart-PendingCommitHarness {
      $script:ActiveTuningExperiment=$script:PendingCommitHarness.PersistedJson|ConvertFrom-Json
    }
    function Send-TuningTelemetryPayload {
      param($Payload,[switch]$DeferFlush,[switch]$RequirePersistence)
      if(-not $RequirePersistence){throw 'pending send lost RequirePersistence'}
      if($script:PendingCommitHarness.FailAdd){throw 'simulated outbox Add failure'}
      if(-not $Payload){return}
      $info=Get-DfbTuningPayloadInfo $Payload
      [void]$script:PendingCommitHarness.Trace.Add('outbox:'+"$($info.BusinessKey)")
      if($script:PendingCommitHarness.Outbox.ContainsKey($info.BusinessKey)){
        if("$($script:PendingCommitHarness.Outbox[$info.BusinessKey])" -cne "$($info.PayloadHash)"){
          throw 'same business key changed payload across restart'
        }
        return
      }
      $script:PendingCommitHarness.Outbox[$info.BusinessKey]="$($info.PayloadHash)"
      [void]$script:PendingCommitHarness.OutboxOrder.Add("$($info.BusinessKey)")
    }
    function Start-TuningTelemetryOutboxFlush {[void]$script:PendingCommitHarness.Trace.Add('flush')}
    function Update-TuningUi {}
    function Compare-CurrentTuningCandidate($Candidate,[bool]$FinalAttempt){
      $Candidate.status='complete'
      $script:ActiveTuningExperiment.phase='group_control_pre'
      Save-TuningExperiment
    }

    Invoke-Expression $SetText
    Invoke-Expression $ConsumedText
    Invoke-Expression $CompletedText
    Invoke-Expression $ResumeText
    Invoke-Expression $AdvanceText

    function New-HarnessRun([string]$Id,[int]$SequenceNo,[string]$VariantId){
      [pscustomobject][ordered]@{runId=$Id;validity='valid';sequenceNo=$SequenceNo;variantId=$VariantId}
    }
    function New-HarnessPayload($State,$Run,[string]$WireVariantId){
      [pscustomobject][ordered]@{
        installId='11111111-1111-1111-1111-111111111111';event='tuning';version='0.20.0'
        os='Windows 11';build='26100';cpu='Test CPU';gpuVendor='NVIDIA';gpuModel='Test GPU'
        gpuModelVerified=$true;ramGb=32.0;deviceType='desktop';tuningType='run_completed'
        experimentId="$($State.experimentId)";runId="$($State.experimentId).$($Run.runId)"
        variantId="$($State.experimentId).$WireVariantId";runNo=[int]$Run.sequenceNo;sequenceNo=[int]$Run.sequenceNo
        validity='valid';invalidReason='';durationSec=120;avgFps=120.0;fps1Low=80.0;p99FrameMs=18.0
        stutter50Ms=1;stutter100Ms=0;gpuUtilAvg=70.0;gpuTempAvg=65.0;gpuPowerAvg=120.0
        settingsHash=('a'*64);environmentHash=('b'*64);orderControlled=$true
      }
    }
    function Add-HarnessPendingRun($Run,[string]$SourcePhase,[string]$WireVariantId){
      $state=$script:ActiveTuningExperiment
      $state.runs=@($state.runs)+@($Run)
      $payload=New-HarnessPayload $state $Run $WireVariantId
      Set-PendingTuningCommit -Kind run -SourcePhase $SourcePhase -CandidateIndex 0 `
        -EntityId "$($Run.runId)" -Payload $payload|Out-Null
      $payload
    }

    $experimentId='exp_'+[guid]::NewGuid().ToString('N')
    $candidate=[pscustomobject]@{
      variantId='background_low_risk';controlRunIds=@();candidateRunIds=@();status='pending'
    }
    $script:ActiveTuningExperiment=[pscustomobject]@{
      experimentId=$experimentId;phase='group_capture_b1';candidateIndex=0;candidates=@($candidate)
      runs=@();initialBaselineRunIds=@();finalRunIds=@();pendingTuningCommit=$null;lastMessage=''
    }
    Save-TuningExperiment

    # Crash before the run+pending state save: an in-memory run disappears and no event/Advance occurs.
    $unsaved=New-HarnessRun ('run_'+[guid]::NewGuid().ToString('N')) 1 'background_low_risk'
    $script:ActiveTuningExperiment.runs=@($unsaved)
    Restart-PendingCommitHarness
    Assert-True (-not @($script:ActiveTuningExperiment.runs).Count -and -not (Resume-PendingTuningCommit)) 'run survived a crash before its atomic state save'
    Assert-True ($h.Outbox.Count -eq 0 -and $script:ActiveTuningExperiment.phase -eq 'group_capture_b1') 'pre-save crash emitted or advanced a run'

    # State save succeeds, but Add fails: pending remains durable and phase/reference progress is forbidden.
    $b1=New-HarnessRun ('run_'+[guid]::NewGuid().ToString('N')) 1 'background_low_risk'
    $b1Payload=Add-HarnessPendingRun $b1 'group_capture_b1' 'G1'
    $h.FailAdd=$true
    Assert-Throws {Resume-PendingTuningCommit|Out-Null} 'outbox Add failure advanced a pending run'
    Assert-True ($script:ActiveTuningExperiment.phase -eq 'group_capture_b1' -and
      -not @($script:ActiveTuningExperiment.candidates[0].candidateRunIds).Count -and
      $script:ActiveTuningExperiment.pendingTuningCommit) 'Add failure did not preserve the exact pending B1 state'

    # Restart, Add succeeds, then process exits immediately before Advance. A second restart must reuse
    # the exact payload/business key and advance the same local run instead of recording another B1.
    Restart-PendingCommitHarness;$h.FailAdd=$false
    function Advance-TuningAfterValidRun {param($Run,[string]$SourcePhase,[int]$SourceCandidateIndex);throw 'simulated crash before Advance'}
    Assert-Throws {Resume-PendingTuningCommit|Out-Null} 'simulated pre-Advance crash was not reached'
    $b1Info=Get-DfbTuningPayloadInfo $b1Payload
    Assert-True ($h.Outbox.Count -eq 1 -and $h.Outbox.ContainsKey($b1Info.BusinessKey)) 'B1 was not durable in outbox before Advance'
    Restart-PendingCommitHarness
    $script:GuiVersion='99.0.0' # restart/update must not rebuild the saved business payload
    Invoke-Expression $AdvanceText
    [void](Resume-PendingTuningCommit)
    Assert-True ($script:ActiveTuningExperiment.phase -eq 'group_rollback_a' -and
      (@($script:ActiveTuningExperiment.candidates[0].candidateRunIds) -join ',') -eq "$($b1.runId)") 'B1 recovery did not advance exactly once'
    Assert-True ($h.Outbox.Count -eq 1 -and "$($h.Outbox[$b1Info.BusinessKey])" -eq "$($b1Info.PayloadHash)") 'B1 payload/business key drifted after restart'

    # A commits normally.
    $script:ActiveTuningExperiment.phase='group_capture_a'
    $a=New-HarnessRun ('run_'+[guid]::NewGuid().ToString('N')) 2 'baseline'
    $aPayload=Add-HarnessPendingRun $a 'group_capture_a' 'baseline'
    [void](Resume-PendingTuningCommit)
    Assert-True ($script:ActiveTuningExperiment.phase -eq 'group_apply_b2' -and
      (@($script:ActiveTuningExperiment.candidates[0].controlRunIds) -join ',') -eq "$($a.runId)") 'A recovery/advance is not exact'

    # B2 reaches and saves Advance, then exits before clearing pending. Restart must recognize the
    # consumed run reference, skip Advance, and only clear the durable marker.
    $script:ActiveTuningExperiment.phase='group_capture_b2'
    $b2=New-HarnessRun ('run_'+[guid]::NewGuid().ToString('N')) 3 'background_low_risk'
    $b2Payload=Add-HarnessPendingRun $b2 'group_capture_b2' 'G1'
    $h.FailClearOnce=$true
    Assert-Throws {Resume-PendingTuningCommit|Out-Null} 'simulated post-Advance crash was not reached'
    Restart-PendingCommitHarness
    Assert-True ($script:ActiveTuningExperiment.pendingTuningCommit -and
      @($script:ActiveTuningExperiment.candidates[0].candidateRunIds) -contains "$($b2.runId)") 'post-Advance durable state did not retain its pending marker/reference'
    [void](Resume-PendingTuningCommit)

    $b2Info=Get-DfbTuningPayloadInfo $b2Payload;$aInfo=Get-DfbTuningPayloadInfo $aPayload
    Assert-True ((@($script:ActiveTuningExperiment.candidates[0].candidateRunIds) -join ',') -eq "$($b1.runId),$($b2.runId)") 'restart duplicated or lost B1/B2 membership'
    Assert-True ((@($script:ActiveTuningExperiment.candidates[0].controlRunIds) -join ',') -eq "$($a.runId)") 'restart duplicated or lost A membership'
    Assert-True ((@($script:ActiveTuningExperiment.runs|ForEach-Object{"$($_.runId)"}) -join ',') -eq "$($b1.runId),$($a.runId),$($b2.runId)") 'restart did not preserve exact B1,A,B2 run order'
    Assert-True (($h.OutboxOrder -join ',') -eq "$($b1Info.BusinessKey),$($aInfo.BusinessKey),$($b2Info.BusinessKey)") 'outbox business order is not exactly B1,A,B2'
    Assert-True ($h.Outbox.Count -eq 3 -and -not $script:ActiveTuningExperiment.pendingTuningCommit) 'recovery left a duplicate event or uncleared pending commit'
  }finally{
    $script:ActiveTuningExperiment=$previousActive;$script:GuiVersion=$previousGuiVersion
    Remove-Variable PendingCommitHarness -Scope Script -ErrorAction SilentlyContinue
  }
} $setPendingText $resumePendingText $pendingFunctions['Test-PendingTuningRunConsumed'].Extent.Text `
  $pendingFunctions['Test-PendingTuningRunCompleted'].Extent.Text `
  $advanceText `
  (Join-Path $root 'scripts\telemetry-client.ps1')

# 最后一份安全回滚备份已 Restore+Save 后、终态保存前退出：此时 currentBest 已经是
# baseline/空集合，但 finalComparison 的 rollback intent 仍必须胜出，恢复为 rolled_back。
& {
  param([string]$ResumeText,[string]$ConsumedText,[string]$CompletedText,[string]$AdvanceText)
  $previousActive=$script:ActiveTuningExperiment
  try{
    $script:SafetyRollbackHarness=[pscustomobject]@{RollbackCalls=0;TerminalCalls=0;TerminalAutoRollback=$false}
    function Save-TuningExperiment {param([switch]$Terminal)}
    function Send-TuningTelemetryPayload {param($Payload,[switch]$DeferFlush,[switch]$RequirePersistence);if(-not $RequirePersistence){throw 'missing durable send'}}
    function Start-TuningTelemetryOutboxFlush {}
    function Update-TuningUi {}
    function Get-TuningRunsByIds($State,[object[]]$Ids){
      $wanted=@($Ids|ForEach-Object{"$_"});@($State.runs|Where-Object{$wanted -contains "$($_.runId)"})
    }
    function Invoke-TuningFinalRollback {
      $script:SafetyRollbackHarness.RollbackCalls++
      Assert-True (-not @($script:ActiveTuningExperiment.activeBackups).Count -and
        -not @($script:ActiveTuningExperiment.currentBestGroups).Count) 'last restored backup was not durably reflected before recovery'
    }
    function Complete-GuiTuningExperimentTerminal([bool]$AutoRollback){
      $script:SafetyRollbackHarness.TerminalCalls++
      $script:SafetyRollbackHarness.TerminalAutoRollback=$AutoRollback
    }
    Invoke-Expression $ConsumedText
    Invoke-Expression $CompletedText
    Invoke-Expression $AdvanceText
    Invoke-Expression $ResumeText

    $runs=@(1..3|ForEach-Object{[pscustomobject]@{runId=('run_'+[guid]::NewGuid().ToString('N'));validity='valid';variantId='display_path'}})
    $pending=[pscustomobject]@{
      schemaVersion=1;kind='run';telemetryType='run_completed';sourcePhase='final_capture';candidateIndex=3
      entityId="$($runs[-1].runId)";resumePhase='';outcome='';unsafeFailure=$false;reason='';payload=$null
    }
    $script:ActiveTuningExperiment=[pscustomobject]@{
      phase='rolling_back';status='final_validation';result='';stopReason='';completedAt='';lastMessage=''
      candidateIndex=3;candidates=@([pscustomobject]@{},[pscustomobject]@{},[pscustomobject]@{})
      runs=$runs;initialBaselineRunIds=@();finalRunIds=@($runs|ForEach-Object{$_.runId})
      currentBestGroups=@();currentBestVariantId='baseline';activeBackups=@()
      finalComparison=[pscustomobject]@{result='rollback';reason='safety limit'}
      allowHigherPower=$false;maxTempIncreaseC=3.0;maxPowerIncreasePct=0.0
      pendingTuningCommit=$pending
    }
    [void](Resume-PendingTuningCommit)
    Assert-True ($script:ActiveTuningExperiment.status -eq 'rolled_back' -and
      $script:ActiveTuningExperiment.result -eq 'rolled_back' -and
      $script:ActiveTuningExperiment.stopReason -eq 'safety_threshold') 'post-restore restart flipped safety rollback into no_gain'
    Assert-True ($script:SafetyRollbackHarness.RollbackCalls -eq 1 -and
      $script:SafetyRollbackHarness.TerminalCalls -eq 1 -and $script:SafetyRollbackHarness.TerminalAutoRollback) 'post-restore restart lost autoRollback terminal intent'
    Assert-True (-not $script:ActiveTuningExperiment.pendingTuningCommit) 'post-restore restart left final pending commit uncleared'
  }finally{
    $script:ActiveTuningExperiment=$previousActive
    Remove-Variable SafetyRollbackHarness -Scope Script -ErrorAction SilentlyContinue
  }
} $resumePendingText $pendingFunctions['Test-PendingTuningRunConsumed'].Extent.Text `
  $pendingFunctions['Test-PendingTuningRunCompleted'].Extent.Text $advanceText

$library=@(Get-TuningCandidateLibrary)
Assert-True ($library.Count -eq 3) 'candidate library must contain exactly G1/G2/G3'
Assert-True ((@($library.GroupId) -join ',') -eq 'G1,G2,G3') 'candidate order/group ids changed'
Assert-True (@($library|Where-Object{$_.RiskLevel -ne 'low' -or $_.RequiresReboot -or $_.Source -ne 'rules'}).Count -eq 0) 'candidate metadata escaped rules/low/no-reboot boundary'
Assert-True (@($library|Where-Object{@($_.ItemIds|Where-Object{$_ -match 'spoof|risky'}).Count}).Count -eq 0) 'risky/spoof item entered candidate library'
$engineFixture=Join-Path ([IO.Path]::GetTempPath()) ('dfb-tuning-engine-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($engineFixture)
try{
  $gameFixture=Join-Path $engineFixture 'DeltaForceClient-Win64-Shipping.exe'
  [IO.File]::WriteAllBytes($gameFixture,[byte[]](0))
  $actual=@(Get-OptItems $gameFixture)
  foreach($candidate in $library){
    foreach($id in @($candidate.ItemIds)){
      $item=@($actual|Where-Object Id -eq $id)
      Assert-True ($item.Count -eq 1) "candidate item missing/duplicated in engine: $id"
      Assert-True ($item[0].Tier -eq 'safe' -and -not [bool]$item[0].Reboot) "candidate is risky/rebooting: $id"
      Assert-True ($item[0].Kind -notin 'cache','check','npi','power','sched') "candidate uses forbidden kind: $id/$($item[0].Kind)"
      Assert-True (@($item[0].Ops).Count -gt 0) "candidate has no restorable ops: $id"
      Assert-True (@($item[0].Ops|Where-Object{$_.Kind -notin 'reg','kvstr'}).Count -eq 0) "candidate op is outside reversible Beta set: $id"
    }
  }
}finally{if(Test-Path -LiteralPath $engineFixture){[IO.Directory]::Delete($engineFixture,$true)}}

# 只提取纯 payload 构造函数，不执行 GUI 顶层代码/打开窗口。
foreach($name in 'Test-AllowedGameExecutable','Test-TuningBackupReference','Add-TuningStateProperty','Initialize-TuningGuiStateFields',
  'Assert-TuningGuiState','Write-TuningPointerAtomic','Read-TuningPointerStrict','Clear-TuningPointer',
  'ConvertTo-TuningWireVariantId','ConvertTo-TuningWireRunId','Get-TuningWireItemIds','New-TuningTelemetryPayload',
  'Remove-TuningBackupFromState','Resolve-TuningFinalOutcome'){
  $node=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)|Select-Object -First 1)
  Assert-True ($node.Count -eq 1) "payload function not found: $name"
  Invoke-Expression $node[0].Extent.Text
}
$script:GuiVersion=$guiVersionMatch.Groups[1].Value
$hw=[pscustomobject]@{OS='Windows 11';Build='26100';CPU='Test CPU';MainGpuVendor='NVIDIA';MainGpuName='NVIDIA Test GPU';MainGpuNameVerified=$true;RamGB=32;IsLaptop=$false}
$environment=[pscustomobject][ordered]@{appVersion=$script:GuiVersion;windowsBuild='26100';gpuModel='NVIDIA Test GPU';driverVersion='600.1';gameVersion='1.2.3';displayMode='2560x1440@165';sceneId='靶场固定路线'}

# 这里只提取 payload 函数，没有执行 GUI 顶层的硬件/注册表检测。
# 用与服务端 v1 严格结构一致的固定上下文，验证当前版本的 tuning 事件会真正携带它。
$script:TuningAnalysisContextFixture=@'
{"schemaVersion":1,"formFactor":"desktop","formFactorConfidence":"high","chassisTypes":[3],"hasBattery":false,"hasInternalDisplay":false,"upsAmbiguous":false,"manufacturer":"Example","modelFamily":"Example Desktop","cpuEfficiencyClasses":[0],"hybridCpu":false,"hypervisorPresent":false,"gpuAdapters":[{"vendor":"NVIDIA","model":"NVIDIA GeForce RTX 4070 SUPER","modelVerified":true,"reportedModelDiffers":false,"driverVersion":"600.00","driverDate":"2026-08-01","virtualDisplay":false,"displayActive":true,"displayMode":"2560x1440@165","main":true,"displayConnected":true}],"displayAdapterVendor":"NVIDIA","displayAdapterModel":"NVIDIA GeForce RTX 4070 SUPER","displayAdapterModelVerified":true,"hybridGraphics":false,"activeDisplayCount":1,"internalDisplayCount":0,"externalDisplayCount":1,"displayConnectors":["displayport"],"windowsDisplayVersion":"24H2","windowsBuildRevision":5000,"windowsReleaseChannel":"retail","vbsState":"running","memoryIntegrityState":"enabled","hagsState":"enabled","gameModeState":"enabled","gameDvrState":"disabled","mpoState":"default","windowedOptimizationState":"enabled","autoHdrState":"disabled","vrrState":"enabled","memoryCompressionState":"enabled","fsoState":"default","gpuPreferenceState":"high_performance","optimizationScheme":"baseline","optimizationItemIds":[],"optimizationItemSetHash":"","optimizationItemsComplete":true,"gpuPanelStatus":"ok","gpuPanelInstalledKeys":["nv-cpl"],"gpuPanelMissingKeys":["nv-app"],"activeSoftwareKeys":["gamepp"],"restoreCatalogStatus":"ok","activeBackupCount":0,"activeRestoreItemCount":0,"activeRestoreOpCount":0,"legacyBackupCount":0,"pendingBackupCount":0,"restoreConflictItemCount":0,"systemDriveMediaType":"ssd","systemDriveBusType":"nvme","systemDriveFreeGb":256.5,"gameDriveMediaType":"ssd","gameDriveBusType":"nvme","gameDriveFreeGb":512.0,"activePowerPlanGuid":"381b4222-f694-41f0-9685-ff5bb260df2e","rebootPending":false,"gameExeVersion":"1.0.0.1","powerSource":"ac","batteryPercent":null,"vcRuntimeStatus":"complete","vcRuntimeX64Version":"14.50.1000.0","vcRuntimeX86Version":"14.50.1000.0","vcRuntimeComponentCount":4,"captureCompatibilityStatus":"available"}
'@|ConvertFrom-Json
function Get-TelemetryAnalysisContext { $script:TuningAnalysisContextFixture }
$script:TuningPerformanceContextTemplate=@'
{"schemaVersion":1,"legacyFpsSource":"presented","captureTool":"presentmon","captureToolVersion":"2.5.1","captureMode":"etw_summary","overlayEnabled":false,"captureOverheadMeasured":false,"presentedFrameCount":12000,"presentedFpsAvg":100,"presentedFps1Low":70,"presentedP50FrameMs":10.0,"presentedP90FrameMs":12.0,"presentedP95FrameMs":14.0,"presentedP99FrameMs":20.0,"presentedFrameTimeCvPct":15.0,"slowFrame25Ms":1000,"slowFrame33Ms":500,"slowFrame50Ms":100,"slowFrame100Ms":20,"slowFrame33Pct":4.2,"displayedFrameCount":12000,"displayedFpsAvg":100.0,"displayedFps1Low":70.0,"displayedP95FrameMs":14.0,"displayedP99FrameMs":20.0,"displayMetricSource":"displayed_time","appFrameCount":12000,"appFpsAvg":100.0,"appFps1Low":70.0,"generatedFrameCount":0,"repeatedFrameCount":0,"droppedFrameCount":0,"frameGenerationDetected":false,"displayTrackingCoveragePct":100.0,"frameTypeCoveragePct":100.0,"frameTypeDistribution":{"Application":12000},"presentModeDistribution":{"Hardware: Independent Flip":12000},"presentRuntimeDistribution":{"DXGI":12000},"syncIntervalDistribution":{"0":12000},"swapChainCount":1,"tearingFramePct":100.0,"cpuBusyAvgMs":3.0,"cpuBusyP95Ms":5.0,"gpuBusyAvgMs":7.0,"gpuBusyP95Ms":10.0,"displayLatencyAvgMs":20.0,"displayLatencyP95Ms":25.0,"captureCompatibilityStatus":"ok","gpuUtilSource":"windows-gpu-engine","gpuUtilSampleCount":60,"gpuUtilCoveragePct":100.0,"gpuTempSource":"nvidia-smi","gpuTempSampleCount":60,"gpuTempCoveragePct":100.0,"gpuPowerSource":"nvidia-smi","gpuPowerSampleCount":60,"gpuPowerCoveragePct":100.0,"processCpuAvgPct":35.0,"processCpuMaxPct":55.0,"processCpuSampleCount":59,"processCpuCoveragePct":98.3,"gameWorkingSetAvgMb":8000.0,"gameWorkingSetMaxMb":8500.0,"gamePrivateAvgMb":9000.0,"gamePrivateMaxMb":9500.0,"processMemorySampleCount":60,"systemMemoryUsedAvgPct":65.0,"systemMemoryUsedMaxPct":70.0,"systemMemoryAvailableMinMb":8000.0,"systemCommitUsedAvgPct":60.0,"systemMemorySampleCount":60,"gpuDedicatedMemoryAvgMb":7000.0,"gpuDedicatedMemoryMaxMb":7500.0,"gpuSharedMemoryAvgMb":500.0,"gpuSharedMemoryMaxMb":600.0,"gpuMemorySource":"windows-gpu-process-memory","gpuMemorySampleCount":60,"gpuMemoryCoveragePct":100.0,"gameRenderAdapterLuid":"0x1:0x2","gameRenderAdapterPhysicalIndex":0,"hybridPresentCount":null,"hybridPresentCoveragePct":null,"powerSourceStart":"ac","powerSourceEnd":"ac","powerSourceChanged":false,"batteryPercentStart":null,"batteryPercentEnd":null,"batteryDischargingUnderLoad":null,"chargerInsufficiencySuspected":null}
'@|ConvertFrom-Json
function New-TuningPerformanceContextFixture([double]$AvgFps,[double]$Fps1Low,[double]$P99FrameMs,[int]$Stutter50Ms,[int]$Stutter100Ms){
  $ctx=($script:TuningPerformanceContextTemplate|ConvertTo-Json -Depth 8|ConvertFrom-Json)
  $ctx.presentedFpsAvg=$AvgFps;$ctx.presentedFps1Low=$Fps1Low;$ctx.presentedP99FrameMs=$P99FrameMs
  $ctx.displayedFpsAvg=$AvgFps;$ctx.displayedFps1Low=$Fps1Low;$ctx.displayedP99FrameMs=$P99FrameMs
  $ctx.appFpsAvg=$AvgFps;$ctx.appFps1Low=$Fps1Low
  $ctx.slowFrame100Ms=$Stutter100Ms;$ctx.slowFrame50Ms=$Stutter50Ms
  $ctx.slowFrame33Ms=[math]::Max($Stutter50Ms,$Stutter50Ms+10)
  $ctx.slowFrame25Ms=[math]::Max($ctx.slowFrame33Ms,$ctx.slowFrame33Ms+10)
  $ctx.slowFrame33Pct=[math]::Round([double]$ctx.slowFrame33Ms*100.0/[double]$ctx.presentedFrameCount,1)
  $ctx
}

$stateTemp=Join-Path ([IO.Path]::GetTempPath()) ('dfb-tuning-state-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($stateTemp)
try{
  $gamePath=Join-Path $stateTemp 'DeltaForce.exe';[IO.File]::WriteAllBytes($gamePath,[byte[]](0))
  $state=Initialize-TuningGuiStateFields (New-TuningExperimentState -SceneId '靶场固定路线' -Environment $environment)
  $state.gamePath=$gamePath
  Assert-True (Assert-TuningGuiState $state) 'GUI-extended state failed strict validation'
  $statePath=Join-Path $stateTemp ($state.experimentId+'.json')
  Write-TuningStateAtomic $statePath $state|Out-Null
  Assert-True ((Read-TuningState $statePath).experimentId -eq $state.experimentId) 'extended state atomic roundtrip failed'
  $script:TuningExperimentDir=$stateTemp;$script:TuningActivePointer=Join-Path $stateTemp 'active-experiment.json'
  Write-TuningPointerAtomic $state.experimentId
  Assert-True ((Read-TuningPointerStrict) -eq $state.experimentId) 'strict active pointer roundtrip failed'
  [IO.File]::WriteAllText($script:TuningActivePointer,('{"schemaVersion":1,"experimentId":"'+$state.experimentId+'","extra":true}'))
  Assert-Throws {Read-TuningPointerStrict|Out-Null} 'pointer with unknown property was accepted'
}finally{if(Test-Path -LiteralPath $stateTemp){[IO.Directory]::Delete($stateTemp,$true)}}

function New-PayloadSet {
  $state=New-TuningExperimentState -SceneId '靶场固定路线' -Environment $environment
  $start=New-TuningTelemetryPayload -TuningType experiment_started -State $state -InstallId ([guid]::NewGuid().ToString()) -Hw $hw
  $candidate1=$state.candidates[0]
  $candidate1|Add-Member -NotePropertyName controlVariantId -NotePropertyValue 'baseline' -Force
  $candidate1|Add-Member -NotePropertyName sequenceNo -NotePropertyValue 1 -Force
  $runtime1=[pscustomobject]@{Library=(Get-TuningCandidate 'G1')}
  $reply1=[pscustomobject]@{Results=@($runtime1.Library.ItemIds|ForEach-Object{[pscustomobject]@{Id=$_;Ok=$true;Skipped=$false;Changed=$true}});EngineExitCode=0;BackupError=$null}
  $applied1=New-TuningTelemetryPayload -TuningType variant_applied -State $state -Candidate $candidate1 -Result ([pscustomobject]@{runtime=$runtime1;reply=$reply1;succeeded=$true;changed=$runtime1.Library.ItemIds.Count}) -InstallId $start.installId -Hw $hw
  $run1=[pscustomobject]@{runId=('run_'+[guid]::NewGuid().ToString('N'));variantId=$candidate1.variantId;runNo=1;sequenceNo=1;validity='valid';invalidReason='';durationSec=120;frameCount=12000;avgFps=140.0;fps1Low=92.0;p99FrameMs=22.0;stutter50Ms=2;stutter100Ms=0;gpuUtilAvg=71.0;gpuTempAvg=67.0;gpuPowerAvg=130.0;settingsHash=('a'*64);environmentHash=('b'*64);orderControlled=$true;performanceContext=(New-TuningPerformanceContextFixture 140 92 22 2 0)}
  $runPayload1=New-TuningTelemetryPayload -TuningType run_completed -State $state -Run $run1 -InstallId $start.installId -Hw $hw
  $state.runs=@($run1)

  # G2 的 wire variant 表示“当前保留的 G1 + 本组 G2”；本地 Apply 仍只执行 G2。
  $candidate1.status='complete';$candidate1.result='win'
  $state.currentBestGroups=@('G1');$state.currentBestVariantId=$candidate1.variantId
  $candidate2=$state.candidates[1]
  $candidate2|Add-Member -NotePropertyName controlVariantId -NotePropertyValue $candidate1.variantId -Force
  $candidate2|Add-Member -NotePropertyName sequenceNo -NotePropertyValue ([int]$state.runs.Count+1) -Force
  $runtime2=[pscustomobject]@{Library=(Get-TuningCandidate 'G2')}
  $reply2=[pscustomobject]@{Results=@($runtime2.Library.ItemIds|ForEach-Object{[pscustomobject]@{Id=$_;Ok=$true;Skipped=$false;Changed=$true}});EngineExitCode=0;BackupError=$null}
  $applied2=New-TuningTelemetryPayload -TuningType variant_applied -State $state -Candidate $candidate2 -Result ([pscustomobject]@{runtime=$runtime2;reply=$reply2;succeeded=$true;changed=$runtime2.Library.ItemIds.Count}) -InstallId $start.installId -Hw $hw
  $run2=[pscustomobject]@{runId=('run_'+[guid]::NewGuid().ToString('N'));variantId=$candidate2.variantId;runNo=1;sequenceNo=2;validity='valid';invalidReason='';durationSec=120;frameCount=12000;avgFps=144.0;fps1Low=96.0;p99FrameMs=21.0;stutter50Ms=1;stutter100Ms=0;gpuUtilAvg=72.0;gpuTempAvg=68.0;gpuPowerAvg=132.0;settingsHash=('c'*64);environmentHash=('b'*64);orderControlled=$true;performanceContext=(New-TuningPerformanceContextFixture 144 96 21 1 0)}
  $runPayload2=New-TuningTelemetryPayload -TuningType run_completed -State $state -Run $run2 -InstallId $start.installId -Hw $hw
  $state.status='completed';$state.result='no_significant_gain';$state.stopReason='completed'
  $completed=New-TuningTelemetryPayload -TuningType experiment_completed -State $state -Result ([pscustomobject]@{autoRollback=$false}) -InstallId $start.installId -Hw $hw
  @($start,$applied1,$runPayload1,$applied2,$runPayload2,$completed)
}

function New-UnstableBaselinePayloadSet {
  $state=Initialize-TuningGuiStateFields (New-TuningExperimentState -SceneId '靶场固定路线' -Environment $environment)
  $installId=[guid]::NewGuid().ToString();$events=New-Object 'System.Collections.Generic.List[object]'
  [void]$events.Add((New-TuningTelemetryPayload -TuningType experiment_started -State $state -InstallId $installId -Hw $hw))
  $averages=@(80.0,160.0,90.0)
  for($i=0;$i -lt $averages.Count;$i++){
    $run=[pscustomobject]@{
      runId=('run_'+[guid]::NewGuid().ToString('N'));variantId='baseline';runNo=($i+1);sequenceNo=($i+1)
      validity='valid';invalidReason='';durationSec=120;frameCount=12000;avgFps=$averages[$i];fps1Low=55.0;p99FrameMs=24.0
      stutter50Ms=3;stutter100Ms=1;gpuUtilAvg=68.0;gpuTempAvg=65.0;gpuPowerAvg=118.0
      settingsHash=('e'*64);environmentHash=('f'*64);orderControlled=$true
      performanceContext=(New-TuningPerformanceContextFixture $averages[$i] 55 24 3 1)
    }
    [void]$events.Add((New-TuningTelemetryPayload -TuningType run_completed -State $state -Run $run -InstallId $installId -Hw $hw))
    $state.runs=@($state.runs)+@($run)
  }
  $state.status='failed';$state.phase='failed';$state.result='';$state.stopReason='unstable_baseline';$state.completedAt=ConvertTo-TuningUtcText
  [void]$events.Add((New-TuningTelemetryPayload -TuningType experiment_completed -State $state `
    -Result ([pscustomobject]@{autoRollback=$false}) -InstallId $installId -Hw $hw))
  $events.ToArray()
}

function New-ImmediateStopPayloadSet {
  $state=Initialize-TuningGuiStateFields (New-TuningExperimentState -SceneId '靶场固定路线' -Environment $environment)
  $installId=[guid]::NewGuid().ToString()
  $started=New-TuningTelemetryPayload -TuningType experiment_started -State $state -InstallId $installId -Hw $hw
  $state.status='cancelled';$state.phase='completed';$state.result='cancelled';$state.stopReason='user_cancelled';$state.completedAt=ConvertTo-TuningUtcText
  $stopped=New-TuningTelemetryPayload -TuningType experiment_completed -State $state `
    -Result ([pscustomobject]@{autoRollback=$true}) -InstallId $installId -Hw $hw
  @($started,$stopped)
}

function New-ContractRunPayload {
  param($State,[string]$InstallId,[string]$VariantId,[int]$RunNo,[int]$SequenceNo,
        [double]$AvgFps,[double]$Fps1Low,[double]$P99FrameMs,[int]$Stutter50Ms,
        [double]$GpuTempAvg,[string]$SettingsHash)
  $run=[pscustomobject]@{
    runId=('run_'+[guid]::NewGuid().ToString('N'));variantId=$VariantId;runNo=$RunNo;sequenceNo=$SequenceNo
    validity='valid';invalidReason='';durationSec=120;frameCount=12000;avgFps=$AvgFps;fps1Low=$Fps1Low;p99FrameMs=$P99FrameMs
    stutter50Ms=$Stutter50Ms;stutter100Ms=0;gpuUtilAvg=70.0;gpuTempAvg=$GpuTempAvg;gpuPowerAvg=120.0
    settingsHash=$SettingsHash;environmentHash=('b'*64);orderControlled=$true
    performanceContext=(New-TuningPerformanceContextFixture $AvgFps $Fps1Low $P99FrameMs $Stutter50Ms 0)
  }
  New-TuningTelemetryPayload -TuningType run_completed -State $State -Run $run -InstallId $InstallId -Hw $hw
}

function New-ContractApplyPayload {
  param($State,$Candidate,[string]$InstallId)
  $runtime=[pscustomobject]@{Library=(Get-TuningCandidate "$($Candidate.groupId)")}
  $reply=[pscustomobject]@{
    Results=@($runtime.Library.ItemIds|ForEach-Object{[pscustomobject]@{Id=$_;Ok=$true;Skipped=$false;Changed=$true}})
    EngineExitCode=0;BackupError=$null
  }
  New-TuningTelemetryPayload -TuningType variant_applied -State $State -Candidate $Candidate `
    -Result ([pscustomobject]@{runtime=$runtime;reply=$reply;succeeded=$true;changed=$runtime.Library.ItemIds.Count}) `
    -InstallId $InstallId -Hw $hw
}

function New-BoundaryPayloadSet {
  $state=New-TuningExperimentState -SceneId '靶场固定路线' -Environment $environment
  $installId=[guid]::NewGuid().ToString();$events=New-Object 'System.Collections.Generic.List[object]'
  [void]$events.Add((New-TuningTelemetryPayload experiment_started $state $null $null $null $installId $hw))

  # 基线 3 次 + G1 前的 A(last)，所以首次 B1 Apply 的确定性边界是 5。
  1..4|ForEach-Object{
    [void]$events.Add((New-ContractRunPayload $state $installId baseline $_ $_ 100 60 20 2 60 ('a'*64)))
  }
  $g1=$state.candidates[0]
  $g1|Add-Member -NotePropertyName controlVariantId -NotePropertyValue baseline -Force
  $g1|Add-Member -NotePropertyName sequenceNo -NotePropertyValue 5 -Force
  [void]$events.Add((New-ContractApplyPayload $state $g1 $installId))
  [void]$events.Add((New-ContractRunPayload $state $installId $g1.variantId 1 5 110 70 18 1 61 ('c'*64)))
  [void]$events.Add((New-ContractRunPayload $state $installId baseline 5 6 100 60 20 2 60 ('a'*64)))
  [void]$events.Add((New-ContractRunPayload $state $installId $g1.variantId 2 7 110 70 18 1 61 ('c'*64)))

  # G1 胜出后成为 G2 的对照；seq 8/10 是后续 control runs，不得改写 G1 的早期结论。
  $g1.status='complete';$g1.result='win';$state.currentBestGroups=@('G1');$state.currentBestVariantId=$g1.variantId
  [void]$events.Add((New-ContractRunPayload $state $installId $g1.variantId 3 8 110 70 18 1 61 ('c'*64)))
  $g2=$state.candidates[1]
  $g2|Add-Member -NotePropertyName controlVariantId -NotePropertyValue $g1.variantId -Force
  $g2|Add-Member -NotePropertyName sequenceNo -NotePropertyValue 9 -Force
  [void]$events.Add((New-ContractApplyPayload $state $g2 $installId))
  [void]$events.Add((New-ContractRunPayload $state $installId $g2.variantId 1 9 120 80 16 1 62 ('d'*64)))
  [void]$events.Add((New-ContractRunPayload $state $installId $g1.variantId 4 10 110 70 18 1 61 ('c'*64)))
  [void]$events.Add((New-ContractRunPayload $state $installId $g2.variantId 2 11 120 80 16 1 62 ('d'*64)))
  $g2.status='complete';$g2.result='win';$state.currentBestGroups=@('G1','G2');$state.currentBestVariantId=$g2.variantId
  $state.status='completed';$state.result='found_better';$state.stopReason='completed'
  [void]$events.Add((New-TuningTelemetryPayload experiment_completed $state $null $null ([pscustomobject]@{autoRollback=$false}) $installId $hw))
  $events.ToArray()
}

$payloads=@(New-PayloadSet)+@(New-PayloadSet)
$boundaryPayloads=@(New-BoundaryPayloadSet)
$unstablePayloads=@(New-UnstableBaselinePayloadSet)
$immediateStopPayloads=@(New-ImmediateStopPayloadSet)
Assert-True ($payloads.Count -eq 12) 'did not generate complete four-type payload flows for two experiments'
Assert-True (@($payloads|Where-Object{-not $_.analysisContext}).Count -eq 0) 'current-version tuning payload omitted analysisContext'
Assert-True ($boundaryPayloads.Count -eq 15) 'deterministic boundary flow is incomplete'
Assert-True (($unstablePayloads.tuningType -join ',') -eq 'experiment_started,run_completed,run_completed,run_completed,experiment_completed') 'unstable baseline causal flow is incomplete'
Assert-True (($immediateStopPayloads.tuningType -join ',') -eq 'experiment_started,experiment_completed') 'start + immediate stop causal order changed'
Assert-True ($unstablePayloads[-1].status -eq 'failed' -and $unstablePayloads[-1].result -eq 'failed' -and
  $unstablePayloads[-1].stopReason -eq 'baseline_unstable') 'unstable baseline completion payload is not a terminal failure'
Assert-True ($immediateStopPayloads[-1].status -eq 'cancelled' -and $immediateStopPayloads[-1].stopReason -eq 'user_cancelled') 'immediate stop completion payload is invalid'
Assert-True ($boundaryPayloads[5].sequenceNo -eq 5 -and $boundaryPayloads[10].sequenceNo -eq 9) 'candidate boundary is not runs.Count+1 at first B1 apply'
Assert-True ($payloads[0].libraryVersion -eq 1) 'experiment start omitted the candidate library version'
Assert-True ($payloads[0].experimentId -ne $payloads[6].experimentId) 'experiments unexpectedly reused id'
Assert-True ($payloads[1].variantId -ne $payloads[7].variantId) 'wire variant ids are not globally scoped by experiment'
Assert-True ($payloads[1].variantId -eq ($payloads[1].experimentId+'.G1')) 'G1 wire variant id is not canonical'
Assert-True ($payloads[3].variantId -eq ($payloads[3].experimentId+'.G2')) 'G2 wire variant id is not canonical'
Assert-True ($payloads[3].controlVariantId -eq $payloads[1].variantId) 'G2 control is not the then-current best G1'
Assert-True ($payloads[2].runId.StartsWith($payloads[2].experimentId+'.run_')) 'run wire id lacks experiment namespace'
$expectedG2Items=@(@((Get-TuningCandidate G1).ItemIds)+@((Get-TuningCandidate G2).ItemIds)|Sort-Object -Unique)
Assert-True ((@($payloads[3].itemIds|Sort-Object) -join ',') -eq ($expectedG2Items -join ',')) 'G2 wire itemIds are not the cumulative active set'
Assert-True ($payloads[3].appliedCount -eq $expectedG2Items.Count -and $payloads[3].failedCount -eq 0 -and $payloads[3].skippedCount -eq 0) 'successful cumulative application counts are invalid'

# candidate.sequenceNo 是持久化的组序号，runs 增长或 B2 重新 Apply 不能改变同一 wire variant payload。
$stableState=New-TuningExperimentState -SceneId '靶场固定路线' -Environment $environment
$stableCandidate=$stableState.candidates[0]
$stableCandidate|Add-Member -NotePropertyName controlVariantId -NotePropertyValue baseline -Force
$stableCandidate|Add-Member -NotePropertyName sequenceNo -NotePropertyValue 1 -Force
$stableRuntime=[pscustomobject]@{Library=(Get-TuningCandidate G1)}
$stableReply=[pscustomobject]@{Results=@($stableRuntime.Library.ItemIds|ForEach-Object{[pscustomobject]@{Id=$_;Ok=$true;Skipped=$false;Changed=$true}})}
$stableResult=[pscustomobject]@{runtime=$stableRuntime;reply=$stableReply;succeeded=$true;changed=$stableRuntime.Library.ItemIds.Count}
$firstApply=New-TuningTelemetryPayload variant_applied $stableState $stableCandidate $null $stableResult ([guid]::NewGuid().ToString()) $hw
$stableState.runs=@([pscustomobject]@{runId='local-only-does-not-affect-variant-sequence'})
$repeatApply=New-TuningTelemetryPayload variant_applied $stableState $stableCandidate $null $stableResult $firstApply.installId $hw
foreach($field in 'variantId','controlVariantId','sequenceNo','groupId','itemSetHash','applyResult','appliedCount','failedCount','skippedCount'){
  Assert-True ("$($firstApply.$field)" -eq "$($repeatApply.$field)") "B1/B2 wire payload drifted: $field"
}

# 最终非交替复核只能否决：保留组+安全通过才沿用前面 A/B 证据；无保留组必须 no_gain。
$outcome=Resolve-TuningFinalOutcome ([pscustomobject]@{currentBestGroups=@('G1')}) ([pscustomobject]@{result='inconclusive'})
Assert-True (-not $outcome.autoRollback -and $outcome.result -eq 'found_better') 'retained controlled winner was not preserved after safe final check'
$outcome=Resolve-TuningFinalOutcome ([pscustomobject]@{currentBestGroups=@('G1')}) ([pscustomobject]@{result='rollback'})
Assert-True ($outcome.autoRollback -and $outcome.result -eq 'rolled_back') 'unsafe final check did not force rollback'
$outcome=Resolve-TuningFinalOutcome ([pscustomobject]@{currentBestGroups=@()}) ([pscustomobject]@{result='inconclusive'})
Assert-True (-not $outcome.autoRollback -and $outcome.result -eq 'no_significant_gain') 'no_gain outcome retained a non-existent winner'
Assert-Throws {Resolve-TuningFinalOutcome ([pscustomobject]@{currentBestGroups=@('G1')}) ([pscustomobject]@{result='win'})|Out-Null} 'final safety-only result was allowed to create a new win'

# 多份回滚每成功一份就从持久化进度中移除；崩溃后只会重试剩余引用。
$rollbackState=[pscustomobject]@{
  activeBackups=@('backup-g1','backup-g2');currentBestGroups=@('G1','G2');currentBestVariantId='foreground_scheduler'
  candidates=@(
    [pscustomobject]@{groupId='G1';result='win';activeBackup='';appliedBackups=@('backup-g1')},
    [pscustomobject]@{groupId='G2';result='win';activeBackup='';appliedBackups=@('backup-g2')},
    [pscustomobject]@{groupId='G3';result='';activeBackup='backup-g3';appliedBackups=@()}
  )
}
Remove-TuningBackupFromState $rollbackState 'backup-g2'
Assert-True ((@($rollbackState.activeBackups) -join ',') -eq 'backup-g1') 'successful rollback stayed in activeBackups'
Assert-True ($rollbackState.candidates[1].result -eq 'rollback' -and -not @($rollbackState.candidates[1].appliedBackups).Count) 'successful rollback stayed on candidate'
Assert-True ((@($rollbackState.currentBestGroups) -join ',') -eq 'G1' -and $rollbackState.currentBestVariantId -eq 'background_low_risk') 'rollback did not move current best to the remaining controlled winner'
foreach($functionName in 'Invoke-TuningFinalRollback','Stop-GuiTuningExperiment'){
  $fn=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $functionName},$true)|Select-Object -First 1)
  Assert-True ($fn.Count -eq 1 -and $fn[0].Extent.Text.Contains('Remove-TuningBackupFromState') -and $fn[0].Extent.Text.Contains('Save-TuningExperiment')) "$functionName does not atomically persist each restored backup"
}

$temp=Join-Path $PSScriptRoot ('.tuning-gui-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try{
  $payloadFile=Join-Path $temp 'payloads.json';$boundaryFile=Join-Path $temp 'boundary-payloads.json'
  $unstableFile=Join-Path $temp 'unstable-payloads.json';$immediateStopFile=Join-Path $temp 'immediate-stop-payloads.json'
  $pythonFile=Join-Path $temp 'validate.py'
  [IO.File]::WriteAllText($payloadFile,($payloads|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($boundaryFile,($boundaryPayloads|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($unstableFile,($unstablePayloads|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($immediateStopFile,($immediateStopPayloads|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
  $python=@'
import importlib.util, json, pathlib, sys
import tempfile, os, sqlite3, time, uuid
payload_path, boundary_path, unstable_path, immediate_stop_path, server_path = map(pathlib.Path, sys.argv[1:6])
spec = importlib.util.spec_from_file_location("dfb_report_server", server_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
payloads = json.loads(payload_path.read_text(encoding="utf-8"))
boundary_payloads = json.loads(boundary_path.read_text(encoding="utf-8"))
unstable_payloads = json.loads(unstable_path.read_text(encoding="utf-8"))
immediate_stop_payloads = json.loads(immediate_stop_path.read_text(encoding="utf-8"))
normalized = [module._normalize_telemetry(payload) for payload in payloads]
assert [x["tuning"]["type"] for x in normalized[:6]] == [
    "experiment_started", "variant_applied", "run_completed",
    "variant_applied", "run_completed", "experiment_completed"
]
assert normalized[1]["tuning"]["variant_id"] != normalized[7]["tuning"]["variant_id"]
assert normalized[1]["tuning"]["control_variant_id"] != normalized[7]["tuning"]["control_variant_id"]
assert normalized[3]["tuning"]["control_variant_id"] == normalized[1]["tuning"]["variant_id"]
assert normalized[5]["tuning"]["result"] == "no_significant_gain"
unstable_normalized = [module._normalize_telemetry(payload) for payload in unstable_payloads]
assert [item["tuning"]["type"] for item in unstable_normalized] == [
    "experiment_started", "run_completed", "run_completed", "run_completed", "experiment_completed",
]
assert unstable_normalized[-1]["tuning"]["status"] == "failed"
assert unstable_normalized[-1]["tuning"]["result"] == "failed"
assert unstable_normalized[-1]["tuning"]["stop_reason"] == "baseline_unstable"
immediate_stop_normalized = [module._normalize_telemetry(payload) for payload in immediate_stop_payloads]
assert [item["tuning"]["type"] for item in immediate_stop_normalized] == [
    "experiment_started", "experiment_completed",
]

# 不只做 schema normalize：把两台设备的完整四类事件真实写入服务端临时 SQLite，
# 验证 experiment/variant/run 业务主键全局隔离且 G2 控制链可落库。
with tempfile.TemporaryDirectory() as tmp:
    module.DATA_DIR = tmp
    module.DB_PATH = os.path.join(tmp, "telemetry.db")
    module.REPORT_DIR = os.path.join(tmp, "reports")
    module.TELEMETRY_PEPPER = "gui-contract-test-pepper"
    os.makedirs(module.REPORT_DIR)
    module._init_db()
    base = int(time.time())
    tokens = {}
    for index, payload in enumerate(payloads):
        install_id = payload["installId"]
        tokens.setdefault(install_id, module._issue_device_token(install_id, base)["deviceToken"])
        authenticated = dict(payload)
        authenticated.update({
            "deviceToken": tokens[install_id], "eventId": str(uuid.uuid4()), "sentAt": base + index,
        })
        module._record_telemetry(authenticated, base + index)
    conn = module._connect()
    try:
        experiments = conn.execute("SELECT experiment_id, client_hash FROM tuning_experiments ORDER BY experiment_id").fetchall()
        variants = conn.execute("SELECT variant_id, experiment_id, group_id, control_variant_id FROM tuning_variants ORDER BY variant_id").fetchall()
        runs = conn.execute("SELECT run_id, experiment_id, variant_id FROM tuning_runs ORDER BY run_id").fetchall()
        assert len(experiments) == 2 and len({row["client_hash"] for row in experiments}) == 2
        assert len(variants) == 6 and len({row["variant_id"] for row in variants}) == 6
        assert len(runs) == 4 and len({row["run_id"] for row in runs}) == 4
        for row in variants:
            assert row["variant_id"].startswith(row["experiment_id"] + ".")
            if row["group_id"] == "G2":
                assert row["control_variant_id"] == row["experiment_id"] + ".G1"
        for row in runs:
            assert row["run_id"].startswith(row["experiment_id"] + ".run_")
            assert row["variant_id"].startswith(row["experiment_id"] + ".")
    finally:
        conn.close()

    # 真实落库一条 A(last)→B1→A→B2 控制链。G1 已得出结论后，
    # G1 会成为 G2 的 control 并出现更晚的 runs；服务端必须仍固定取 G1 boundary 后的前两个 B。
    boundary_install = boundary_payloads[0]["installId"]
    boundary_token = module._issue_device_token(boundary_install, base + 100)["deviceToken"]
    def record_boundary(index, payload):
        authenticated = dict(payload)
        authenticated.update({
            "deviceToken": boundary_token, "eventId": str(uuid.uuid4()), "sentAt": base + 100 + index,
        })
        module._record_telemetry(authenticated, base + 100 + index)

    def load_comparison(experiment_id, variant_id):
        comparison_conn = module._connect()
        try:
            experiment = comparison_conn.execute(
                "SELECT * FROM tuning_experiments WHERE experiment_id=?", (experiment_id,),
            ).fetchone()
            return module._load_tuning_comparison(comparison_conn, experiment, variant_id)
        finally:
            comparison_conn.close()

    # 前 9 个事件止于 G1 B2，此时 G1 已有完整、可胜出的受控比较。
    for index, payload in enumerate(boundary_payloads[:9]):
        record_boundary(index, payload)
    experiment_id = boundary_payloads[0]["experimentId"]
    g1_variant = experiment_id + ".G1"
    before_later_control = load_comparison(experiment_id, g1_variant)
    assert before_later_control and before_later_control["deterministicWin"]
    assert before_later_control["controlRunIds"] == [
        boundary_payloads[2]["runId"], boundary_payloads[3]["runId"],
        boundary_payloads[4]["runId"], boundary_payloads[7]["runId"],
    ]
    assert before_later_control["candidateRunIds"] == [
        boundary_payloads[6]["runId"], boundary_payloads[8]["runId"],
    ]

    # 写入 G2 的 control-pre / A 复测以及 G2 B1/B2，但先不终结实验。
    for index, payload in enumerate(boundary_payloads[9:-1], start=9):
        record_boundary(index, payload)
    after_later_control = load_comparison(experiment_id, g1_variant)
    assert after_later_control and after_later_control["deterministicWin"]
    for key in ("controlRunIds", "candidateRunIds", "avgFpsDeltaPct", "fps1LowDeltaPct", "deterministicWin"):
        assert after_later_control[key] == before_later_control[key], key
    g2_comparison = load_comparison(experiment_id, experiment_id + ".G2")
    assert g2_comparison and g2_comparison["deterministicWin"]
    assert g2_comparison["controlVariantId"] == g1_variant
    expected_g2_controls = [
        boundary_payloads[6]["runId"], boundary_payloads[8]["runId"],
        boundary_payloads[9]["runId"], boundary_payloads[12]["runId"],
    ]
    assert g2_comparison["controlRunIds"] == expected_g2_controls, (
        g2_comparison["controlRunIds"], expected_g2_controls,
    )
    record_boundary(len(boundary_payloads) - 1, boundary_payloads[-1])
    conn = module._connect()
    try:
        winner = conn.execute(
            "SELECT winning_variant_id FROM tuning_experiments WHERE experiment_id=?", (experiment_id,),
        ).fetchone()["winning_variant_id"]
        assert winner == experiment_id + ".G2"
    finally:
        conn.close()

    # 基线波动过大是客户端真实终态，不得只清理本地指针而漏掉 completion。
    # 这里把 GUI 构造的 started + 3 baseline runs + failed completion 交给真实 validator/SQLite。
    unstable_install = unstable_payloads[0]["installId"]
    unstable_token = module._issue_device_token(unstable_install, base + 200)["deviceToken"]
    for index, payload in enumerate(unstable_payloads):
        authenticated = dict(payload)
        authenticated.update({
            "deviceToken": unstable_token, "eventId": str(uuid.uuid4()), "sentAt": base + 200 + index,
        })
        module._record_telemetry(authenticated, base + 200 + index)
    conn = module._connect()
    try:
        unstable_id = unstable_payloads[0]["experimentId"]
        experiment = conn.execute(
            "SELECT status, result, stop_reason, completed_at, auto_rollback "
            "FROM tuning_experiments WHERE experiment_id=?", (unstable_id,),
        ).fetchone()
        run_count = conn.execute(
            "SELECT COUNT(*) FROM tuning_runs WHERE experiment_id=?", (unstable_id,),
        ).fetchone()[0]
        assert experiment is not None
        assert dict(experiment) == {
            "status": "failed", "result": "failed", "stop_reason": "baseline_unstable",
            "completed_at": base + 204, "auto_rollback": 0,
        }
        assert run_count == 3
    finally:
        conn.close()

    # completion 抢在 started 前会得到“父实验不存在”；同一稳定 eventId 延迟重试，
    # started 成功后必须能按序终结。覆盖“创建后立即停止”的最短因果链。
    stop_install = immediate_stop_payloads[0]["installId"]
    stop_token = module._issue_device_token(stop_install, base + 300)["deviceToken"]
    authenticated_stop = dict(immediate_stop_payloads[1])
    authenticated_stop.update({
        "deviceToken": stop_token, "eventId": str(uuid.uuid4()), "sentAt": base + 301,
    })
    try:
        module._record_telemetry(authenticated_stop, base + 301)
    except module.TelemetryTuningError:
        pass
    else:
        raise AssertionError("completion before started unexpectedly reached the database")
    authenticated_start = dict(immediate_stop_payloads[0])
    authenticated_start.update({
        "deviceToken": stop_token, "eventId": str(uuid.uuid4()), "sentAt": base + 300,
    })
    module._record_telemetry(authenticated_start, base + 300)
    module._record_telemetry(authenticated_stop, base + 301)
    conn = module._connect()
    try:
        stopped = conn.execute(
            "SELECT status, result, stop_reason, completed_at, auto_rollback "
            "FROM tuning_experiments WHERE experiment_id=?", (immediate_stop_payloads[0]["experimentId"],),
        ).fetchone()
        assert stopped is not None
        assert dict(stopped) == {
            "status": "cancelled", "result": "cancelled", "stop_reason": "user_cancelled",
            "completed_at": base + 301, "auto_rollback": 1,
        }
    finally:
        conn.close()
print("server accepted centralized terminal flows, unstable baseline completion, and ordered immediate stop")
'@
  [IO.File]::WriteAllText($pythonFile,$python,(New-Object Text.UTF8Encoding($false)))
  $pythonCmd=Get-Command python -ErrorAction Stop
  $previousErrorAction=$ErrorActionPreference;$ErrorActionPreference='Continue'
  $output=& $pythonCmd.Source $pythonFile $payloadFile $boundaryFile $unstableFile $immediateStopFile $serverPath 2>&1
  $pythonExitCode=$LASTEXITCODE;$ErrorActionPreference=$previousErrorAction
  if($pythonExitCode -ne 0){throw "server validator rejected GUI payloads:`n$($output -join "`n")"}
  Write-Host ($output -join "`n")
}finally{if(Test-Path -LiteralPath $temp){[IO.Directory]::Delete($temp,$true)}}

Write-Host 'PASS: tuning GUI AST/XAML, candidate boundary, cumulative wire IDs and server persistence contract'
