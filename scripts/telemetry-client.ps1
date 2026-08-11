<#
  DeltaForceBooster 匿名遥测客户端。
  注册得到的短期设备令牌只用于限额、防重放和把同一匿名安装的会话关联起来；
  它不是账号凭据，也不包含用户名、机器名或硬件序列号。
#>
#requires -Version 5.1

function Write-DfbTelemetryConfigAtomic([string]$Path, $Config) {
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $tmp = Join-Path $dir ('.telemetry-' + [guid]::NewGuid().ToString('N') + '.tmp')
  $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes(($Config | ConvertTo-Json -Depth 6))
  $stream = New-Object IO.FileStream($tmp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
  $backup = Join-Path $dir ('.telemetry-' + [guid]::NewGuid().ToString('N') + '.bak')
  try {
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, $backup, $true) }
    else { [IO.File]::Move($tmp, $Path) }
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
  }
}

function Get-DfbTelemetryHttpStatus($ErrorRecord) {
  try {
    $value = $ErrorRecord.Exception.Data['DfbStatus']
    if ($null -ne $value) { return [int]$value }
  } catch {}
  try { return [int]$ErrorRecord.Exception.Response.StatusCode } catch { return 0 }
}

function Get-DfbTelemetryHttpErrorBody($ErrorRecord) {
  try {
    $value = $ErrorRecord.Exception.Data['DfbBody']
    if ($null -ne $value) { return "$value" }
  } catch {}
  try {
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.PSObject.Properties['Content'] -and $response.Content) {
      return "$($response.Content)"
    }
    $stream = $response.GetResponseStream()
    if (-not $stream) { return '' }
    $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $true, 1024, $true)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
  } catch { return '' }
}

function Invoke-DfbTelemetryJsonPost([string]$Url, $Payload, [int]$TimeoutSec = 8) {
  if (-not [uri]::IsWellFormedUriString($Url, [UriKind]::Absolute)) { throw '遥测地址无效' }
  $uri = [uri]$Url
  if ($uri.Scheme -ne 'https' -or $uri.Host -ne 'df.ltz88.cn') { throw '遥测地址不在官方 HTTPS 白名单内' }
  [Net.ServicePointManager]::SecurityProtocol = `
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
  $body = [Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Compress -Depth 8))
  $response = Invoke-WebRequest -Uri $Url -Method Post -Body $body -ContentType 'application/json; charset=utf-8' `
    -TimeoutSec $TimeoutSec -UseBasicParsing
  if (-not $response.Content) { return $null }
  $response.Content | ConvertFrom-Json
}

function Register-DfbTelemetryDevice([string]$UploadUrl, [string]$InstallId, [string]$ConfigPath, $Config) {
  $registerUrl = $UploadUrl.TrimEnd('/') + '/register'
  $reply = Invoke-DfbTelemetryJsonPost $registerUrl ([ordered]@{ installId = $InstallId })
  if (-not $reply -or "$($reply.deviceToken)" -notmatch '^v1\.') { throw '遥测服务没有返回有效设备令牌' }
  $Config | Add-Member -NotePropertyName DeviceToken -NotePropertyValue "$($reply.deviceToken)" -Force
  $Config | Add-Member -NotePropertyName TokenExpiresAt -NotePropertyValue ([long]$reply.expiresAt) -Force
  Write-DfbTelemetryConfigAtomic $ConfigPath $Config
  "$($reply.deviceToken)"
}

function Send-DfbTelemetryEvent {
  param(
    [Parameter(Mandatory)][string]$UploadUrl,
    [Parameter(Mandatory)]$Payload,
    [Parameter(Mandatory)][string]$ConfigPath,
    [ValidatePattern('^[0-9a-fA-F-]{32,64}$')][string]$EventId = ''
  )
  $installId = "$($Payload.installId)"
  if ($installId -notmatch '^[0-9a-fA-F-]{32,64}$') { return $null }
  # telemetry.json 同时会被 GUI（配置档位）和多个后台采样 runspace 更新；固定互斥锁让
  # 令牌刷新与档位写入串行化，避免两个原子替换彼此覆盖最新字段。
  $mutex = New-Object Threading.Mutex($false, 'Local\DeltaForceBooster.Telemetry.Config')
  $locked = $false
  try {
    $locked = $mutex.WaitOne([TimeSpan]::FromSeconds(10))
    if (-not $locked) { return $null }
    $cfg = $null
    if (Test-Path -LiteralPath $ConfigPath) {
      try { $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    if (-not $cfg) { return $null }
    if ($cfg.Enabled -eq $false -or "$($cfg.InstallId)" -ne $installId) { return $null }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $token = "$($cfg.DeviceToken)"
    $expires = 0L
    try { $expires = [long]$cfg.TokenExpiresAt } catch {}
    if ($token -notmatch '^v1\.' -or $expires -le ($now + 300)) {
      $token = Register-DfbTelemetryDevice $UploadUrl $installId $ConfigPath $cfg
    }
    $event = [ordered]@{}
    foreach ($property in $Payload.PSObject.Properties) { $event[$property.Name] = $property.Value }
    $stableEventId = $EventId -match '^[0-9a-fA-F-]{32,64}$'
    $event.deviceToken = $token
    $event.eventId = $(if ($stableEventId) { $EventId } else { [guid]::NewGuid().ToString() })
    $event.sentAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    try {
      return Invoke-DfbTelemetryJsonPost $UploadUrl $event
    } catch {
      if ((Get-DfbTelemetryHttpStatus $_) -ne 401) { throw }
      # 令牌被服务端轮换或吊销时只重新注册并重试一次，避免错误状态下无限请求。
      $token = Register-DfbTelemetryDevice $UploadUrl $installId $ConfigPath $cfg
      $event.deviceToken = $token
      if (-not $stableEventId) { $event.eventId = [guid]::NewGuid().ToString() }
      $event.sentAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
      return Invoke-DfbTelemetryJsonPost $UploadUrl $event
    }
  } finally {
    if ($locked) { try { $mutex.ReleaseMutex() } catch {} }
    $mutex.Dispose()
  }
}

# ---------- 自动调优专用持久 outbox ----------
# 普通启动/应用/性能遥测仍走 Send-DfbTelemetryEvent 的原有即时路径。
# 调优事件有父子关系，必须先原子入队，再按 experiment 串行送达。
$script:DfbTuningOutboxSchemaVersion = 1
$script:DfbTuningOutboxMaxItems = 512
$script:DfbTuningOutboxMaxReceipts = 512
$script:DfbTuningOutboxMaxBytes = 4194304
$script:DfbTuningPayloadMaxBytes = 7168
$script:DfbTuningOutboxMutexName = 'Local\DeltaForceBooster.Telemetry.TuningOutbox'

function Get-DfbTuningOutboxPath([string]$ConfigPath, [string]$OutboxPath = '') {
  if ([string]::IsNullOrWhiteSpace($ConfigPath)) { throw 'telemetry config path is required' }
  $configDir = [IO.Path]::GetFullPath((Split-Path -Parent ([IO.Path]::GetFullPath($ConfigPath))))
  if (-not $OutboxPath) { $OutboxPath = Join-Path $configDir 'tuning-telemetry-outbox.json' }
  $full = [IO.Path]::GetFullPath($OutboxPath)
  $outboxDir = [IO.Path]::GetFullPath((Split-Path -Parent $full))
  if ($outboxDir.TrimEnd('\','/') -ine $configDir.TrimEnd('\','/')) {
    throw 'tuning outbox must be stored beside telemetry config'
  }
  if ([IO.Path]::GetExtension($full) -ine '.json') { throw 'tuning outbox must be a JSON file' }
  $full
}

function Test-DfbExactProperties($Value, [string[]]$Expected) {
  if ($null -eq $Value) { return $false }
  $actual = @($Value.PSObject.Properties | ForEach-Object { $_.Name })
  if ($actual.Count -ne $Expected.Count) { return $false }
  foreach ($name in $Expected) { if ($actual -cnotcontains $name) { return $false } }
  $true
}

function Test-DfbJsonInteger($Value) {
  $Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or
    $Value -is [uint16] -or $Value -is [int32] -or $Value -is [uint32] -or
    $Value -is [int64] -or $Value -is [uint64]
}

function Get-DfbSha256Text([string]$Text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
    ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-DfbTuningPayloadInfo($Payload) {
  if ($null -eq $Payload) { throw 'tuning payload is required' }
  try { $json = $Payload | ConvertTo-Json -Compress -Depth 8 -ErrorAction Stop } catch { throw 'tuning payload is not JSON serializable' }
  if ([Text.Encoding]::UTF8.GetByteCount($json) -gt $script:DfbTuningPayloadMaxBytes) {
    throw 'tuning payload is too large'
  }
  try { $copy = $json | ConvertFrom-Json -ErrorAction Stop } catch { throw 'tuning payload JSON is invalid' }
  if ($copy -is [array] -or $copy -is [string] -or $null -eq $copy) { throw 'tuning payload must be an object' }

  $common = @('installId','event','version','os','build','cpu','gpuVendor','gpuModel','gpuModelVerified',
    'ramGb','deviceType','tuningType','experimentId','driverVersion','gpuCount','displayMode',
    'cpuCores','cpuThreads','cpuPackages','memoryType','memoryConfiguredMhz','memoryRatedMhz',
    'memoryModuleCount','virtualDisplayCount','pagefileAutoManaged','gpuReportedModelDiffers')
  $requiredCommon = @('installId','event','version','os','build','cpu','gpuVendor','gpuModel','gpuModelVerified',
    'ramGb','deviceType','tuningType','experimentId')
  $typeFields = @{
    experiment_started = @('status','goal','riskLevel','allowReboot','allowHigherPower','maxTempIncreaseC',
      'maxPowerIncreasePct','gameVersion','driverVersion','baselineVariantId','libraryVersion')
    variant_applied = @('status','variantId','controlVariantId','sequenceNo','groupId','itemSetHash','itemIds',
      'source','riskLevel','requiresReboot','applyResult','appliedCount','failedCount','skippedCount')
    run_completed = @('runId','variantId','runNo','sequenceNo','validity','invalidReason','durationSec','avgFps',
      'fps1Low','p99FrameMs','stutter50Ms','stutter100Ms','gpuUtilAvg','gpuTempAvg','gpuPowerAvg',
      'settingsHash','environmentHash','orderControlled','frameCount','frameTimeMadMs','stuttersPerMin',
      'focusLostSec','gpuTempMax','gameExitedEarly','captureFailed','presentMonExitCode')
    experiment_completed = @('status','result','stopReason','winningVariantId','autoRollback')
  }
  $type = "$($copy.tuningType)"
  if (@('experiment_started','variant_applied','run_completed','experiment_completed') -cnotcontains $type) {
    throw 'unknown tuning event type'
  }
  $allowed = @($common + $typeFields[$type])
  $actual = @($copy.PSObject.Properties | ForEach-Object { $_.Name })
  foreach ($name in $actual) {
    if ($allowed -cnotcontains $name) { throw "unknown tuning payload field: $name" }
  }
  $requiredTypeFields = @($typeFields[$type])
  if ($type -eq 'run_completed') {
    $requiredTypeFields = @($requiredTypeFields | Where-Object { $_ -notin @(
      'frameCount','frameTimeMadMs','stuttersPerMin','focusLostSec','gpuTempMax',
      'gameExitedEarly','captureFailed','presentMonExitCode'
    ) })
  }
  foreach ($name in @($requiredCommon + $requiredTypeFields)) {
    if ($actual -cnotcontains $name) { throw "missing tuning payload field: $name" }
  }
  if ("$($copy.event)" -cne 'tuning') { throw 'outbox accepts tuning events only' }
  if ("$($copy.installId)" -notmatch '^[0-9a-fA-F-]{32,64}$') { throw 'invalid tuning installId' }
  $experimentId = "$($copy.experimentId)"
  if ($experimentId -notmatch '^[A-Za-z0-9][A-Za-z0-9._:\-]{0,95}$') { throw 'invalid tuning experimentId' }
  if ($copy.gpuModelVerified -isnot [bool] -or -not [bool]$copy.gpuModelVerified) {
    throw 'tuning payload requires a verified GPU model'
  }

  $entityId = ''
  switch ($type) {
    'experiment_started' { $entityId = 'start' }
    'experiment_completed' { $entityId = 'complete' }
    'variant_applied' { $entityId = "$($copy.variantId)" }
    'run_completed' { $entityId = "$($copy.runId)" }
  }
  if ($type -in 'variant_applied','run_completed' -and
      $entityId -notmatch '^[A-Za-z0-9][A-Za-z0-9._:\-]{0,95}$') {
    throw 'invalid tuning business identifier'
  }
  $normalizedJson = $copy | ConvertTo-Json -Compress -Depth 8
  [pscustomobject]@{
    Payload = $copy
    PayloadHash = Get-DfbSha256Text $normalizedJson
    ExperimentId = $experimentId
    BusinessKey = "$experimentId|$type|$entityId"
    TuningType = $type
  }
}

function New-DfbTuningOutboxState {
  [pscustomobject][ordered]@{
    schemaVersion = [int]$script:DfbTuningOutboxSchemaVersion
    nextSequence = [long]1
    items = @()
    receipts = @()
  }
}

function Assert-DfbTuningOutboxState($State) {
  if (-not (Test-DfbExactProperties $State @('schemaVersion','nextSequence','items','receipts'))) {
    throw 'invalid tuning outbox root schema'
  }
  if (-not (Test-DfbJsonInteger $State.schemaVersion) -or
      [int]$State.schemaVersion -ne $script:DfbTuningOutboxSchemaVersion) {
    throw 'unsupported tuning outbox schema'
  }
  if (-not (Test-DfbJsonInteger $State.nextSequence) -or [long]$State.nextSequence -lt 1 -or
      [long]$State.nextSequence -gt 1000000000) { throw 'invalid tuning outbox sequence' }
  if ($State.items -isnot [array] -or $State.receipts -isnot [array]) {
    throw 'tuning outbox collections must be arrays'
  }
  $items = @($State.items)
  $receipts = @($State.receipts)
  if ($items.Count -gt $script:DfbTuningOutboxMaxItems -or
      $receipts.Count -gt $script:DfbTuningOutboxMaxReceipts) { throw 'tuning outbox exceeds its item limit' }
  $eventIds = @{}
  $businessKeys = @{}
  $previousSequence = 0L
  foreach ($item in $items) {
    if (-not (Test-DfbExactProperties $item @('eventId','experimentId','businessKey','sequence','createdAt',
          'attemptCount','nextAttemptAt','lastStatus','lastError','inFlightOwner','inFlightUntil','payloadHash','payload'))) {
      throw 'invalid tuning outbox item schema'
    }
    $eventId = "$($item.eventId)"
    if ($eventId -notmatch '^[0-9a-fA-F-]{32,64}$' -or $eventIds.ContainsKey($eventId)) {
      throw 'invalid or duplicate tuning outbox eventId'
    }
    foreach ($field in 'sequence','createdAt','attemptCount','nextAttemptAt','lastStatus','inFlightUntil') {
      if (-not (Test-DfbJsonInteger $item.$field)) { throw "invalid tuning outbox $field" }
    }
    $sequence = [long]$item.sequence
    if ($sequence -le $previousSequence -or $sequence -ge [long]$State.nextSequence) {
      throw 'tuning outbox order is invalid'
    }
    if ([long]$item.createdAt -lt 1 -or [long]$item.createdAt -gt 4102444800 -or
        [long]$item.nextAttemptAt -lt 0 -or [long]$item.nextAttemptAt -gt 4102444800 -or
        [long]$item.attemptCount -lt 0 -or [long]$item.attemptCount -gt 1000000 -or
        [long]$item.lastStatus -lt 0 -or [long]$item.lastStatus -gt 599 -or
        [long]$item.inFlightUntil -lt 0 -or [long]$item.inFlightUntil -gt 4102444800) {
      throw 'tuning outbox numeric boundary is invalid'
    }
    $owner = "$($item.inFlightOwner)"
    if (($owner -and $owner -notmatch '^[0-9a-fA-F-]{32,64}$') -or
        (($owner -eq '') -ne ([long]$item.inFlightUntil -eq 0))) {
      throw 'tuning outbox in-flight lease is invalid'
    }
    if ("$($item.payloadHash)" -notmatch '^[0-9a-f]{64}$' -or "$($item.lastError)".Length -gt 32) {
      throw 'tuning outbox metadata is invalid'
    }
    $info = Get-DfbTuningPayloadInfo $item.payload
    if ($info.ExperimentId -cne "$($item.experimentId)" -or
        $info.BusinessKey -cne "$($item.businessKey)" -or
        $info.PayloadHash -cne "$($item.payloadHash)") {
      throw 'tuning outbox payload metadata mismatch'
    }
    if ($businessKeys.ContainsKey($info.BusinessKey)) { throw 'duplicate tuning outbox business key' }
    $eventIds[$eventId] = $true; $businessKeys[$info.BusinessKey] = $true
    $previousSequence = $sequence
  }
  foreach ($receipt in $receipts) {
    if (-not (Test-DfbExactProperties $receipt @('eventId','experimentId','businessKey','payloadHash','acknowledgedAt'))) {
      throw 'invalid tuning outbox receipt schema'
    }
    $eventId = "$($receipt.eventId)"; $businessKey = "$($receipt.businessKey)"
    if ($eventId -notmatch '^[0-9a-fA-F-]{32,64}$' -or $eventIds.ContainsKey($eventId) -or
        "$($receipt.experimentId)" -notmatch '^[A-Za-z0-9][A-Za-z0-9._:\-]{0,95}$' -or
        -not $businessKey.StartsWith("$($receipt.experimentId)|", [StringComparison]::Ordinal) -or
        $businessKey.Length -gt 320 -or "$($receipt.payloadHash)" -notmatch '^[0-9a-f]{64}$' -or
        -not (Test-DfbJsonInteger $receipt.acknowledgedAt) -or [long]$receipt.acknowledgedAt -lt 1 -or
        [long]$receipt.acknowledgedAt -gt 4102444800) {
      throw 'invalid tuning outbox receipt'
    }
    if ($businessKeys.ContainsKey($businessKey)) { throw 'duplicate tuning outbox receipt business key' }
    $eventIds[$eventId] = $true; $businessKeys[$businessKey] = $true
  }
  $true
}

function Read-DfbTuningOutbox([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return New-DfbTuningOutboxState }
  $file = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      $file.Length -gt $script:DfbTuningOutboxMaxBytes) { throw 'unsafe or oversized tuning outbox' }
  try { $state = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop }
  catch { throw 'tuning outbox JSON is invalid' }
  [void](Assert-DfbTuningOutboxState $state)
  $state
}

function Write-DfbTuningOutboxAtomic([string]$Path, $State) {
  [void](Assert-DfbTuningOutboxState $State)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { [void][IO.Directory]::CreateDirectory($dir) }
  $json = $State | ConvertTo-Json -Compress -Depth 12
  $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes($json)
  if ($bytes.Length -gt $script:DfbTuningOutboxMaxBytes) { throw 'tuning outbox is too large' }
  $tmp = Join-Path $dir ('.tuning-outbox-' + [guid]::NewGuid().ToString('N') + '.tmp')
  $stream = New-Object IO.FileStream($tmp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
    [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
  try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
  $backup = Join-Path $dir ('.tuning-outbox-' + [guid]::NewGuid().ToString('N') + '.bak')
  try {
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, $backup, $true) }
    else { [IO.File]::Move($tmp, $Path) }
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
  }
}

function Add-DfbTuningOutboxEvent {
  param(
    [Parameter(Mandatory)]$Payload,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$OutboxPath = '',
    [long]$NowUnix = 0
  )
  $path = Get-DfbTuningOutboxPath $ConfigPath $OutboxPath
  $info = Get-DfbTuningPayloadInfo $Payload
  if ($NowUnix -le 0) { $NowUnix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  if ($NowUnix -lt 1 -or $NowUnix -gt 4102444800) { throw 'invalid outbox timestamp' }
  $mutex = New-Object Threading.Mutex($false, $script:DfbTuningOutboxMutexName)
  $locked = $false
  try {
    try { $locked = $mutex.WaitOne([TimeSpan]::FromSeconds(15)) }
    catch [Threading.AbandonedMutexException] { $locked = $true }
    if (-not $locked) { throw 'timed out waiting for tuning outbox' }
    $state = Read-DfbTuningOutbox $path
    foreach ($existing in @($state.items) + @($state.receipts)) {
      if ("$($existing.businessKey)" -cne $info.BusinessKey) { continue }
      if ("$($existing.payloadHash)" -cne $info.PayloadHash) {
        throw 'tuning business key already has a different payload'
      }
      return [pscustomobject]@{ eventId="$($existing.eventId)"; enqueued=$false; outboxPath=$path }
    }
    if (@($state.items).Count -ge $script:DfbTuningOutboxMaxItems) { throw 'tuning outbox is full' }
    $sequence = [long]$state.nextSequence
    if ($sequence -ge 1000000000) { throw 'tuning outbox sequence exhausted' }
    $eventId = [guid]::NewGuid().ToString()
    $item = [pscustomobject][ordered]@{
      eventId = $eventId
      experimentId = $info.ExperimentId
      businessKey = $info.BusinessKey
      sequence = $sequence
      createdAt = [long]$NowUnix
      attemptCount = [int]0
      nextAttemptAt = [long]0
      lastStatus = [int]0
      lastError = ''
      inFlightOwner = ''
      inFlightUntil = [long]0
      payloadHash = $info.PayloadHash
      payload = $info.Payload
    }
    $state.items = @(@($state.items) + $item)
    $state.nextSequence = [long]($sequence + 1)
    Write-DfbTuningOutboxAtomic $path $state
    [pscustomobject]@{ eventId=$eventId; enqueued=$true; outboxPath=$path }
  } finally {
    if ($locked) { try { $mutex.ReleaseMutex() } catch {} }
    $mutex.Dispose()
  }
}

function Test-DfbTuningIdempotentConflict($ErrorRecord) {
  if ((Get-DfbTelemetryHttpStatus $ErrorRecord) -ne 409) { return $false }
  $body = Get-DfbTelemetryHttpErrorBody $ErrorRecord
  if (-not $body) { return $false }
  try {
    $value = $body | ConvertFrom-Json -ErrorAction Stop
    "$($value.error)" -ceq 'duplicate telemetry event'
  } catch { $false }
}

function Get-DfbTuningRetryDelay([int]$AttemptCount, [string]$Kind) {
  $base = switch ($Kind) {
    'network' { 5 }
    'server' { 10 }
    'parent_pending' { 15 }
    'rate_limited' { 60 }
    'auth' { 60 }
    'conflict' { 300 }
    default { 300 }
  }
  $cap = $(if ($Kind -in 'rate_limited','auth','conflict','client') { 21600 } else { 3600 })
  $power = [math]::Min(10, [math]::Max(0, $AttemptCount - 1))
  [long][math]::Min($cap, $base * [math]::Pow(2, $power))
}

function Add-DfbTuningReceipt($State, $Item, [long]$NowUnix) {
  $receipts = @($State.receipts)
  if ($receipts.Count -ge $script:DfbTuningOutboxMaxReceipts) {
    $receipts = @($receipts | Select-Object -Last ($script:DfbTuningOutboxMaxReceipts - 1))
  }
  $receipt = [pscustomobject][ordered]@{
    eventId = "$($Item.eventId)"
    experimentId = "$($Item.experimentId)"
    businessKey = "$($Item.businessKey)"
    payloadHash = "$($Item.payloadHash)"
    acknowledgedAt = [long]$NowUnix
  }
  $State.receipts = @($receipts + $receipt)
}

function Get-DfbTuningNextAttemptAt($State) {
  $heads = @{}
  foreach ($item in @($State.items)) {
    $experimentId = "$($item.experimentId)"
    if (-not $heads.ContainsKey($experimentId)) {
      $heads[$experimentId] = [long][math]::Max([long]$item.nextAttemptAt, [long]$item.inFlightUntil)
    }
  }
  if (-not $heads.Count) { return 0L }
  [long](($heads.Values | Measure-Object -Minimum).Minimum)
}

function Enter-DfbTuningOutboxMutex($Mutex) {
  $locked = $false
  try { $locked = $Mutex.WaitOne([TimeSpan]::FromSeconds(15)) }
  catch [Threading.AbandonedMutexException] { $locked = $true }
  if (-not $locked) { throw 'timed out waiting for tuning outbox' }
}

function Exit-DfbTuningOutboxMutex($Mutex) {
  try { $Mutex.ReleaseMutex() } catch {}
}

function Invoke-DfbTuningOutboxFlush {
  param(
    [Parameter(Mandatory)][string]$UploadUrl,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$OutboxPath = '',
    [ValidateRange(1,64)][int]$MaxEvents = 16,
    [long]$NowUnix = 0,
    [scriptblock]$Sender
  )
  $path = Get-DfbTuningOutboxPath $ConfigPath $OutboxPath
  if ($NowUnix -le 0) { $NowUnix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  if ($NowUnix -lt 1 -or $NowUnix -gt 4102444800) { throw 'invalid outbox timestamp' }
  $sent = 0; $acknowledged = 0; $deferred = 0; $processed = 0
  $mutex = New-Object Threading.Mutex($false, $script:DfbTuningOutboxMutexName)
  $locked = $false
  try {
    while ($processed -lt $MaxEvents) {
      # 只在读写队列时持锁；网络请求通过有界 lease 占位，避免阻塞 GUI 同步入队。
      Enter-DfbTuningOutboxMutex $mutex; $locked = $true
      $state = Read-DfbTuningOutbox $path
      # 同一 experiment 只允许队首候选；一个 experiment 退避不会阻塞另一个。
      $heads = @{}
      foreach ($candidate in @($state.items)) {
        $key = "$($candidate.experimentId)"
        if (-not $heads.ContainsKey($key)) { $heads[$key] = $candidate }
      }
      $item = @($heads.Values | Where-Object {
          [long]$_.nextAttemptAt -le $NowUnix -and
          (-not "$($_.inFlightOwner)" -or [long]$_.inFlightUntil -le $NowUnix)
        } |
          Sort-Object { [long]$_.sequence } | Select-Object -First 1)
      if (-not $item.Count) {
        Exit-DfbTuningOutboxMutex $mutex; $locked = $false
        break
      }
      $item = $item[0]; $processed++
      $leaseOwner = [guid]::NewGuid().ToString()
      $item.inFlightOwner = $leaseOwner
      $item.inFlightUntil = [long]($NowUnix + 120)
      Write-DfbTuningOutboxAtomic $path $state
      Exit-DfbTuningOutboxMutex $mutex; $locked = $false

      $reply = $null; $errorRecord = $null; $accepted = $false; $idempotent = $false
      try {
        if ($Sender) { $reply = & $Sender $UploadUrl $item.payload $ConfigPath "$($item.eventId)" }
        else {
          $reply = Send-DfbTelemetryEvent -UploadUrl $UploadUrl -Payload $item.payload `
            -ConfigPath $ConfigPath -EventId "$($item.eventId)"
        }
        $accepted = $null -ne $reply -and $reply.PSObject.Properties['ok'] -and $reply.ok -eq $true
      } catch { $errorRecord = $_; $idempotent = Test-DfbTuningIdempotentConflict $_ }

      Enter-DfbTuningOutboxMutex $mutex; $locked = $true
      $state = Read-DfbTuningOutbox $path
      $current = @($state.items | Where-Object { "$($_.eventId)" -ceq "$($item.eventId)" } | Select-Object -First 1)
      if (-not $current.Count -or "$($current[0].inFlightOwner)" -cne $leaseOwner) {
        # 另一 drain 已完成该事件，或在超长请求后接管了过期 lease。
        Exit-DfbTuningOutboxMutex $mutex; $locked = $false
        continue
      }
      $current = $current[0]
      if ($accepted -or $idempotent) {
        if ($accepted) { $sent++ }
        $acknowledged++
        Add-DfbTuningReceipt $state $current $NowUnix
        $state.items = @($state.items | Where-Object { "$($_.eventId)" -cne "$($current.eventId)" })
        Write-DfbTuningOutboxAtomic $path $state
        Exit-DfbTuningOutboxMutex $mutex; $locked = $false
        continue
      }

      $status = $(if ($errorRecord) { Get-DfbTelemetryHttpStatus $errorRecord } else { 0 })
      $kind = if (-not $errorRecord) { 'client' }
        elseif ($status -eq 422) { 'parent_pending' }
        elseif ($status -eq 429) { 'rate_limited' }
        elseif ($status -eq 401) { 'auth' }
        elseif ($status -eq 409) { 'conflict' }
        elseif ($status -eq 408 -or $status -ge 500 -and $status -le 599) { 'server' }
        elseif ($status -eq 0) { 'network' }
        else { 'client' }
      $current.attemptCount = [int][math]::Min(1000000, ([long]$current.attemptCount + 1))
      $current.lastStatus = [int]$status
      $current.lastError = $kind
      $current.nextAttemptAt = [long]($NowUnix + (Get-DfbTuningRetryDelay ([int]$current.attemptCount) $kind))
      $current.inFlightOwner = ''
      $current.inFlightUntil = [long]0
      $deferred++
      Write-DfbTuningOutboxAtomic $path $state
      Exit-DfbTuningOutboxMutex $mutex; $locked = $false
    }
    Enter-DfbTuningOutboxMutex $mutex; $locked = $true
    $state = Read-DfbTuningOutbox $path
    $summary =
    [pscustomobject]@{
      sent = [int]$sent
      acknowledged = [int]$acknowledged
      deferred = [int]$deferred
      remaining = [int]@($state.items).Count
      nextAttemptAt = [long](Get-DfbTuningNextAttemptAt $state)
      outboxPath = $path
    }
    Exit-DfbTuningOutboxMutex $mutex; $locked = $false
    $summary
  } finally {
    if ($locked) { Exit-DfbTuningOutboxMutex $mutex }
    $mutex.Dispose()
  }
}
