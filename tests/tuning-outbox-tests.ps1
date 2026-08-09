#requires -Version 5.1
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$client = Join-Path $repo 'scripts\telemetry-client.ps1'
. $client

$script:Assertions = 0
function Assert-True([bool]$Condition, [string]$Message) {
  $script:Assertions++
  if (-not $Condition) { throw "ASSERT: $Message" }
}
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$Message) {
  $script:Assertions++
  try { & $Action; throw "ASSERT: $Message (did not throw)" }
  catch {
    if ("$($_.Exception.Message)" -like 'ASSERT:*') { throw }
    if ($Pattern -and "$($_.Exception.Message)" -notmatch $Pattern) {
      throw "ASSERT: $Message (unexpected: $($_.Exception.Message))"
    }
  }
}
function Throw-TestHttp([int]$Status, [string]$Body) {
  $exception = New-Object Exception("HTTP $Status")
  $exception.Data['DfbStatus'] = $Status
  $exception.Data['DfbBody'] = $Body
  throw $exception
}

function New-CommonPayload([string]$ExperimentId, [string]$Type) {
  [ordered]@{
    installId = '11111111-1111-4111-8111-111111111111'
    event = 'tuning'; version = '0.20.0'; os = 'Windows 11'; build = '26100'; cpu = 'CPU'
    gpuVendor = 'NVIDIA'; gpuModel = 'NVIDIA GeForce RTX 5060 Ti'; gpuModelVerified = $true
    ramGb = 32.0; deviceType = 'desktop'; tuningType = $Type; experimentId = $ExperimentId
  }
}
function New-StartPayload([string]$ExperimentId) {
  $p = New-CommonPayload $ExperimentId 'experiment_started'
  $p.status='created'; $p.goal='frame_rate_stability'; $p.riskLevel='low'; $p.allowReboot=$false
  $p.allowHigherPower=$false; $p.maxTempIncreaseC=3.0; $p.maxPowerIncreasePct=0.0
  $p.gameVersion='game'; $p.driverVersion='driver'; $p.baselineVariantId="$ExperimentId.baseline"
  $p.libraryVersion=1
  [pscustomobject]$p
}
function New-VariantPayload([string]$ExperimentId, [string]$Suffix = 'G1') {
  $p = New-CommonPayload $ExperimentId 'variant_applied'
  $p.status='variant_applied'; $p.variantId="$ExperimentId.$Suffix"; $p.controlVariantId="$ExperimentId.baseline"
  $p.sequenceNo=1; $p.groupId='G1'; $p.itemSetHash=('0'*64); $p.itemIds=@('fullscreen_optimizations')
  $p.source='rules'; $p.riskLevel='low'; $p.requiresReboot=$false; $p.applyResult='succeeded'
  $p.appliedCount=1; $p.failedCount=0; $p.skippedCount=0
  [pscustomobject]$p
}
function New-RunPayload([string]$ExperimentId, [string]$RunId = 'run-1') {
  $p = New-CommonPayload $ExperimentId 'run_completed'
  $p.runId="$ExperimentId.$RunId"; $p.variantId="$ExperimentId.baseline"; $p.runNo=1; $p.sequenceNo=1
  $p.validity='valid'; $p.invalidReason=''; $p.durationSec=120; $p.avgFps=120.0; $p.fps1Low=80.0
  $p.p99FrameMs=15.0; $p.stutter50Ms=0; $p.stutter100Ms=0; $p.gpuUtilAvg=70.0
  $p.gpuTempAvg=60.0; $p.gpuPowerAvg=100.0; $p.settingsHash=('1'*64); $p.environmentHash=('2'*64)
  $p.orderControlled=$true
  [pscustomobject]$p
}

$temp = Join-Path $env:TEMP ('dfb-tuning-outbox-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
  # PS5 AST and public surface.
  $tokens=$null; $errors=$null
  [void][Management.Automation.Language.Parser]::ParseFile($client,[ref]$tokens,[ref]$errors)
  Assert-True ($errors.Count -eq 0) 'telemetry client has parser errors'
  Assert-True ([bool](Get-Command Add-DfbTuningOutboxEvent -ErrorAction SilentlyContinue)) 'enqueue API missing'
  Assert-True ([bool](Get-Command Invoke-DfbTuningOutboxFlush -ErrorAction SilentlyContinue)) 'flush API missing'

  # Synchronous durable enqueue, pending dedupe, strict path/schema.
  $case1 = Join-Path $temp 'case1'; [void][IO.Directory]::CreateDirectory($case1)
  $cfg1 = Join-Path $case1 'telemetry.json'; [IO.File]::WriteAllText($cfg1, '{}')
  $startA = New-StartPayload 'exp-order-a'
  $a1 = Add-DfbTuningOutboxEvent $startA $cfg1 -NowUnix 1786248000
  $a2 = Add-DfbTuningOutboxEvent $startA $cfg1 -NowUnix 1786248001
  Assert-True ($a1.enqueued -and -not $a2.enqueued) 'pending business key was not deduplicated'
  Assert-True ($a1.eventId -ceq $a2.eventId) 'pending dedupe changed stable eventId'
  Assert-True (Test-Path -LiteralPath $a1.outboxPath -PathType Leaf) 'enqueue returned before durable file existed'
  $different = New-StartPayload 'exp-order-a'; $different.goal = 'average_fps'
  Assert-Throws { Add-DfbTuningOutboxEvent $different $cfg1 -NowUnix 1786248002 } 'different payload' 'changed business payload was accepted'
  Assert-Throws { Add-DfbTuningOutboxEvent (New-StartPayload 'exp-path') $cfg1 (Join-Path $temp 'outside.json') -NowUnix 1786248002 } 'beside' 'outbox escaped config directory'
  $unknown = New-StartPayload 'exp-unknown'; $unknown | Add-Member extraField 1
  Assert-Throws { Add-DfbTuningOutboxEvent $unknown $cfg1 -NowUnix 1786248002 } 'unknown tuning payload field' 'unknown payload field was accepted'
  $ordinaryFields = New-StartPayload 'exp-ordinary-fields'; $ordinaryFields | Add-Member configTier 'balanced'
  Assert-Throws { Add-DfbTuningOutboxEvent $ordinaryFields $cfg1 -NowUnix 1786248002 } 'unknown tuning payload field' 'ordinary telemetry fields leaked into tuning schema'

  # One failed experiment head must not let its child overtake it, while another experiment may drain.
  [void](Add-DfbTuningOutboxEvent (New-VariantPayload 'exp-order-a') $cfg1 -NowUnix 1786248002)
  [void](Add-DfbTuningOutboxEvent (New-StartPayload 'exp-order-b') $cfg1 -NowUnix 1786248003)
  $script:OrderCalls = New-Object Collections.ArrayList
  $script:FailAOnce = $true
  $orderedSender = {
    param($Url,$Payload,$ConfigPath,$EventId)
    [void]$script:OrderCalls.Add("$($Payload.experimentId):$($Payload.tuningType):$EventId")
    if ($Payload.experimentId -eq 'exp-order-a' -and $Payload.tuningType -eq 'experiment_started' -and $script:FailAOnce) {
      $script:FailAOnce=$false; Throw-TestHttp 0 ''
    }
    [pscustomobject]@{ok=$true}
  }
  $first = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg1 -NowUnix 1786248010 -Sender $orderedSender
  Assert-True ($first.sent -eq 1 -and $first.deferred -eq 1 -and $first.remaining -eq 2) 'cross-experiment first drain summary is wrong'
  Assert-True ($script:OrderCalls.Count -eq 2 -and $script:OrderCalls[0] -like 'exp-order-a:experiment_started:*' -and
    $script:OrderCalls[1] -like 'exp-order-b:experiment_started:*') 'failed parent blocked another experiment or child overtook parent'
  $beforeDue = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg1 -NowUnix 1786248014 -Sender $orderedSender
  Assert-True ($beforeDue.acknowledged -eq 0 -and $script:OrderCalls.Count -eq 2) 'backoff deadline was ignored'
  $afterDue = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg1 -NowUnix 1786248015 -Sender $orderedSender
  Assert-True ($afterDue.sent -eq 2 -and $afterDue.remaining -eq 0) 'parent and child did not resume in order'
  Assert-True ($script:OrderCalls[2] -like 'exp-order-a:experiment_started:*' -and
    $script:OrderCalls[3] -like 'exp-order-a:variant_applied:*') 'restart drain reordered experiment events'
  Assert-True (-not @(Get-ChildItem $case1 -Filter '.tuning-outbox-*' -Force).Count) 'atomic writer left temporary files'

  # Acknowledged receipt survives dequeue/restart and preserves the original eventId.
  . $client
  $again = Add-DfbTuningOutboxEvent $startA $cfg1 -NowUnix 1786248016
  Assert-True (-not $again.enqueued -and $again.eventId -ceq $a1.eventId) 'receipt tombstone did not preserve stable eventId'
  Assert-Throws { Add-DfbTuningOutboxEvent $different $cfg1 -NowUnix 1786248017 } 'different payload' 'receipt allowed business payload mutation'

  # Accepted response lost: restart retries the same eventId; explicit duplicate 409 is an acknowledgement.
  $case2 = Join-Path $temp 'case2'; [void][IO.Directory]::CreateDirectory($case2)
  $cfg2 = Join-Path $case2 'telemetry.json'; [IO.File]::WriteAllText($cfg2, '{}')
  $queued = Add-DfbTuningOutboxEvent (New-StartPayload 'exp-crash') $cfg2 -NowUnix 1786248100
  $script:LostEventId = ''
  $lostSender = { param($u,$p,$c,$id) $script:LostEventId=$id; Throw-TestHttp 0 '' }
  $lost = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg2 -NowUnix 1786248101 -Sender $lostSender
  Assert-True ($lost.remaining -eq 1 -and $lost.deferred -eq 1 -and $script:LostEventId -ceq $queued.eventId) 'lost response removed event or changed eventId'
  . $client
  $duplicateSender = {
    param($u,$p,$c,$id)
    if ($id -cne $script:LostEventId) { throw 'eventId changed after restart' }
    Throw-TestHttp 409 '{"error":"duplicate telemetry event"}'
  }
  $recovered = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg2 -NowUnix 1786248106 -Sender $duplicateSender
  Assert-True ($recovered.acknowledged -eq 1 -and $recovered.sent -eq 0 -and $recovered.remaining -eq 0) 'idempotent 409 was not dequeued'
  $crashAgain = Add-DfbTuningOutboxEvent (New-StartPayload 'exp-crash') $cfg2 -NowUnix 1786248107
  Assert-True (-not $crashAgain.enqueued -and $crashAgain.eventId -ceq $queued.eventId) 'duplicate receipt was not durable'

  # 422 parent-missing class and non-idempotent 409 stay queued; 5xx uses exponential deadlines.
  $case3 = Join-Path $temp 'case3'; [void][IO.Directory]::CreateDirectory($case3)
  $cfg3 = Join-Path $case3 'telemetry.json'; [IO.File]::WriteAllText($cfg3, '{}')
  [void](Add-DfbTuningOutboxEvent (New-StartPayload 'exp-422') $cfg3 -NowUnix 1786248200)
  $sender422 = { param($u,$p,$c,$id) Throw-TestHttp 422 '{"error":"invalid tuning event"}' }
  $r422 = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg3 -NowUnix 1786248201 -Sender $sender422
  $s422 = Read-DfbTuningOutbox (Get-DfbTuningOutboxPath $cfg3)
  Assert-True ($r422.remaining -eq 1 -and $s422.items[0].lastError -eq 'parent_pending' -and
    [long]$s422.items[0].nextAttemptAt -eq 1786248216) '422 was not delayed as a parent dependency'

  $case4 = Join-Path $temp 'case4'; [void][IO.Directory]::CreateDirectory($case4)
  $cfg4 = Join-Path $case4 'telemetry.json'; [IO.File]::WriteAllText($cfg4, '{}')
  [void](Add-DfbTuningOutboxEvent (New-StartPayload 'exp-conflict') $cfg4 -NowUnix 1786248300)
  $conflictSender = { param($u,$p,$c,$id) Throw-TestHttp 409 '{"error":"tuning business key conflict"}' }
  $conflict = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg4 -NowUnix 1786248301 -Sender $conflictSender
  Assert-True ($conflict.remaining -eq 1 -and $conflict.acknowledged -eq 0) 'non-idempotent 409 was incorrectly discarded'
  $fakeIdempotentSender = { param($u,$p,$c,$id) Throw-TestHttp 409 '{"error":"tuning business key conflict","idempotent":true}' }
  $fakeConflict = Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg4 -NowUnix 1786248601 -Sender $fakeIdempotentSender
  Assert-True ($fakeConflict.remaining -eq 1 -and $fakeConflict.acknowledged -eq 0) 'fake idempotent 409 was incorrectly discarded'

  $case5 = Join-Path $temp 'case5'; [void][IO.Directory]::CreateDirectory($case5)
  $cfg5 = Join-Path $case5 'telemetry.json'; [IO.File]::WriteAllText($cfg5, '{}')
  [void](Add-DfbTuningOutboxEvent (New-StartPayload 'exp-503') $cfg5 -NowUnix 1786248400)
  $script:ServerCalls=0
  $serverSender = { param($u,$p,$c,$id) $script:ServerCalls++; Throw-TestHttp 503 '{"error":"telemetry unavailable"}' }
  [void](Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg5 -NowUnix 1786248401 -Sender $serverSender)
  $serverState = Read-DfbTuningOutbox (Get-DfbTuningOutboxPath $cfg5)
  Assert-True ([long]$serverState.items[0].nextAttemptAt -eq 1786248411) 'first 5xx backoff is not 10 seconds'
  [void](Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg5 -NowUnix 1786248410 -Sender $serverSender)
  Assert-True ($script:ServerCalls -eq 1) '5xx event retried before deadline'
  [void](Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg5 -NowUnix 1786248411 -Sender $serverSender)
  $serverState = Read-DfbTuningOutbox (Get-DfbTuningOutboxPath $cfg5)
  Assert-True ($script:ServerCalls -eq 2 -and [long]$serverState.items[0].nextAttemptAt -eq 1786248431) '5xx retry delay did not double'

  # Flush releases the cross-process mutex while its network sender is blocked, so synchronous enqueue stays responsive.
  $caseLock = Join-Path $temp 'case-lock'; [void][IO.Directory]::CreateDirectory($caseLock)
  $cfgLock = Join-Path $caseLock 'telemetry.json'; [IO.File]::WriteAllText($cfgLock, '{}')
  [void](Add-DfbTuningOutboxEvent (New-StartPayload 'exp-lock-a') $cfgLock -NowUnix 1786248450)
  $entered = Join-Path $caseLock 'entered.signal'; $release = Join-Path $caseLock 'release.signal'
  $worker = [PowerShell]::Create()
  [void]$worker.AddScript({
    param($ClientPath,$ConfigPath,$EnteredPath,$ReleasePath)
    . $ClientPath
    $script:EnteredPath=$EnteredPath; $script:ReleasePath=$ReleasePath
    $sender = {
      param($u,$p,$c,$id)
      [IO.File]::WriteAllText($script:EnteredPath, 'entered')
      $deadline=[DateTime]::UtcNow.AddSeconds(15)
      while (-not (Test-Path -LiteralPath $script:ReleasePath) -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 25
      }
      [pscustomobject]@{ok=$true}
    }
    Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $ConfigPath -MaxEvents 1 -NowUnix 1786248451 -Sender $sender
  }).AddArgument($client).AddArgument($cfgLock).AddArgument($entered).AddArgument($release)
  $async=$worker.BeginInvoke()
  try {
    $deadline=[DateTime]::UtcNow.AddSeconds(8)
    while (-not (Test-Path -LiteralPath $entered) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 25 }
    Assert-True (Test-Path -LiteralPath $entered) 'blocking sender did not start'
    $watch=[Diagnostics.Stopwatch]::StartNew()
    [void](Add-DfbTuningOutboxEvent (New-StartPayload 'exp-lock-b') $cfgLock -NowUnix 1786248452)
    $watch.Stop()
    Assert-True ($watch.Elapsed.TotalSeconds -lt 3) 'flush held outbox mutex across network I/O'
  } finally {
    [IO.File]::WriteAllText($release, 'release')
    try { [void]$worker.EndInvoke($async) } finally { $worker.Dispose() }
  }

  # Corrupt state is rejected and preserved rather than silently reordered or dropped.
  $case6 = Join-Path $temp 'case6'; [void][IO.Directory]::CreateDirectory($case6)
  $cfg6 = Join-Path $case6 'telemetry.json'; [IO.File]::WriteAllText($cfg6, '{}')
  $out6 = Get-DfbTuningOutboxPath $cfg6
  $bad = '{"schemaVersion":1,"nextSequence":1,"items":[],"receipts":[],"extra":1}'
  [IO.File]::WriteAllText($out6, $bad)
  Assert-Throws { Invoke-DfbTuningOutboxFlush 'https://df.ltz88.cn/report/telemetry' $cfg6 -NowUnix 1786248500 -Sender { [pscustomobject]@{ok=$true} } } 'root schema' 'corrupt root schema was accepted'
  Assert-True ([IO.File]::ReadAllText($out6) -ceq $bad) 'corrupt outbox was overwritten'

  # Existing immediate telemetry remains immediate and receives a fresh eventId per ordinary call.
  $case7 = Join-Path $temp 'case7'; [void][IO.Directory]::CreateDirectory($case7)
  $cfg7 = Join-Path $case7 'telemetry.json'
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  [IO.File]::WriteAllText($cfg7, (@{Enabled=$true;InstallId='22222222-2222-4222-8222-222222222222';DeviceToken='v1.test';TokenExpiresAt=$now+3600} | ConvertTo-Json))
  $script:ImmediateIds = New-Object Collections.ArrayList
  function Invoke-DfbTelemetryJsonPost([string]$Url, $Payload, [int]$TimeoutSec=8) {
    [void]$script:ImmediateIds.Add("$($Payload.eventId)")
    [pscustomobject]@{ok=$true}
  }
  $ordinary = [pscustomobject]@{installId='22222222-2222-4222-8222-222222222222';event='launch';version='0.20.0'}
  [void](Send-DfbTelemetryEvent 'https://df.ltz88.cn/report/telemetry' $ordinary $cfg7)
  [void](Send-DfbTelemetryEvent 'https://df.ltz88.cn/report/telemetry' $ordinary $cfg7)
  Assert-True ($script:ImmediateIds.Count -eq 2 -and $script:ImmediateIds[0] -ne $script:ImmediateIds[1]) 'ordinary telemetry no longer generates fresh event IDs'

  # The outbox-owned stable EventId also survives the client's one allowed 401 registration retry.
  $script:StableIds = New-Object Collections.ArrayList
  $script:StableAttempt = 0
  function Invoke-DfbTelemetryJsonPost([string]$Url, $Payload, [int]$TimeoutSec=8) {
    if ($Url.EndsWith('/register',[StringComparison]::Ordinal)) {
      return [pscustomobject]@{deviceToken='v1.refreshed';expiresAt=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+3600)}
    }
    [void]$script:StableIds.Add("$($Payload.eventId)")
    $script:StableAttempt++
    if ($script:StableAttempt -eq 1) { Throw-TestHttp 401 '{"error":"device authentication failed"}' }
    [pscustomobject]@{ok=$true}
  }
  $stableId=[guid]::NewGuid().ToString()
  [void](Send-DfbTelemetryEvent 'https://df.ltz88.cn/report/telemetry' $ordinary $cfg7 -EventId $stableId)
  Assert-True ($script:StableIds.Count -eq 2 -and $script:StableIds[0] -ceq $stableId -and
    $script:StableIds[1] -ceq $stableId) '401 registration retry changed outbox eventId'

  "PASS: tuning outbox ($script:Assertions assertions)"
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
