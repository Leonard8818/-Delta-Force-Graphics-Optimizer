$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts\updater.ps1')

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT: $Message" }
}

function New-QueuePayload {
  param([string]$Ticket, [string]$State, [int]$Position, [int]$Ahead,
        [string]$DownloadUrl = '', [int]$EstimatedWaitSeconds = 45)
  [pscustomobject]@{
    ok = $true; ticket = $Ticket; state = $State; position = $Position; ahead = $Ahead
    active = 3; capacity = 3; retryAfter = 2; downloadUrl = $DownloadUrl
    estimatedWaitSeconds = $EstimatedWaitSeconds
  }
}

function Get-BoosterDownloadQueueEndpoints([string]$SetupUrl) {
  [pscustomobject]@{
    Join = 'https://df.ltz88.cn/report/download-queue/join'
    Status = 'https://df.ltz88.cn/report/download-queue/status'
    Cancel = 'https://df.ltz88.cn/report/download-queue/cancel'
  }
}

$script:QueueResponses = New-Object Collections.Queue
$script:QueueRequests = @()
$script:QueueWaits = @()
$script:CancelQueueOnWait = $false
function Invoke-BoosterQueueJsonRequest {
  param([string]$Url, [string]$Method = 'GET', [int]$TimeoutMs = 5000, [string]$Body = '{}')
  $script:QueueRequests += [pscustomobject]@{ Url = $Url; Method = $Method; TimeoutMs = $TimeoutMs; Body = $Body }
  if ($script:QueueResponses.Count -eq 0) { throw 'mock queue response exhausted' }
  $script:QueueResponses.Dequeue()
}
function Wait-BoosterDownloadRetry {
  param([hashtable]$State, [int]$DelayMs)
  $script:QueueWaits += $DelayMs
  if ($script:CancelQueueOnWait) { $State.Cancel = $true }
  -not [bool]$State.Cancel
}

$ticket = 'QueueTicket_12345678901234567890'
$signed = "https://df.ltz88.cn/DeltaForceBooster-Setup.exe?ticket=$ticket&expires=1999999999&sig=" + ('a' * 64)
$script:QueueResponses.Enqueue([pscustomobject]@{
  StatusCode = 200; Payload = New-QueuePayload $ticket queued 3 2
})
$script:QueueResponses.Enqueue([pscustomobject]@{
  StatusCode = 200; Payload = New-QueuePayload $ticket queued 2 1
})
$script:QueueResponses.Enqueue([pscustomobject]@{
  StatusCode = 200; Payload = New-QueuePayload $ticket ready 0 0 $signed
})

$state = @{
  Phase = ''; Status = ''; Cancel = $false; QueuePosition = 0; QueueAhead = 0
  QueueActive = 0; QueueCapacity = 0
}
$resolved = Wait-BoosterDownloadQueue -SetupUrl 'https://df.ltz88.cn/DeltaForceBooster-Setup.exe' -State $state
Assert-True ($resolved -eq $signed) 'ready response did not return the signed installer URL'
Assert-True ($state.Phase -eq 'downloading') 'queue did not transition shared state to downloading'
Assert-True ($script:QueueRequests.Count -eq 3 -and $script:QueueRequests[0].Method -eq 'POST' -and
  $script:QueueRequests[1].Method -eq 'GET' -and $script:QueueRequests[1].Url -like "*ticket=$ticket") `
  'queue join/status request sequence is wrong'
Assert-True ($script:QueueWaits.Count -eq 2 -and $script:QueueWaits[0] -eq 2000) `
  'queue did not honor the server polling interval'
Assert-True ($state.QueueAhead -eq 0 -and $state.QueueActive -eq 3 -and $state.QueueCapacity -eq 3) `
  'queue slot fields were not copied into shared GUI state'

# An expired status ticket must transparently rejoin instead of exposing HTTP 404.
$script:QueueResponses.Clear(); $script:QueueRequests = @(); $script:QueueWaits = @()
$expired = 'ExpiredTicket_12345678901234567'
$fresh = 'FreshTicket_12345678901234567890'
$freshUrl = "https://df.ltz88.cn/DeltaForceBooster-Setup.exe?ticket=$fresh&expires=1999999999&sig=" + ('b' * 64)
$script:QueueResponses.Enqueue([pscustomobject]@{ StatusCode = 200; Payload = New-QueuePayload $expired queued 1 0 })
$script:QueueResponses.Enqueue([pscustomobject]@{ StatusCode = 404; Payload = [pscustomobject]@{ error = 'expired' } })
$script:QueueResponses.Enqueue([pscustomobject]@{ StatusCode = 200; Payload = New-QueuePayload $fresh ready 0 0 $freshUrl })
$state2 = @{ Phase = ''; Status = ''; Cancel = $false }
$resolved2 = Wait-BoosterDownloadQueue -SetupUrl 'https://df.ltz88.cn/DeltaForceBooster-Setup.exe' -State $state2
Assert-True ($resolved2 -eq $freshUrl -and $script:QueueRequests[2].Method -eq 'POST') `
  'expired queue ticket was not rejoined'

# Cancelling during the poll delay must stop without consuming another response.
$script:QueueResponses.Clear(); $script:QueueRequests = @(); $script:QueueWaits = @(); $script:CancelQueueOnWait = $true
$script:QueueResponses.Enqueue([pscustomobject]@{ StatusCode = 200; Payload = New-QueuePayload $fresh queued 1 0 })
$script:QueueResponses.Enqueue([pscustomobject]@{ StatusCode = 200; Payload = [pscustomobject]@{ ok = $true; cancelled = $true } })
$cancelState = @{ Phase = ''; Status = ''; Cancel = $false }
$cancelled = Wait-BoosterDownloadQueue -SetupUrl 'https://df.ltz88.cn/DeltaForceBooster-Setup.exe' -State $cancelState
Assert-True ($null -eq $cancelled -and $cancelState.Cancel -and $script:QueueResponses.Count -eq 0) `
  'queue cancellation did not stop during the polling delay'
Assert-True ($script:QueueRequests.Count -eq 2 -and
  $script:QueueRequests[1].Url -eq 'https://df.ltz88.cn/report/download-queue/cancel' -and
  $script:QueueRequests[1].Method -eq 'POST' -and
  ($script:QueueRequests[1].Body | ConvertFrom-Json).ticket -eq $fresh) `
  'queue cancellation did not immediately release the server ticket'
Assert-True ($cancelState.Status -notmatch '槽位|\d+/\d+') `
  'queue status still exposes the server slot ratio'
Assert-True ($cancelState.QueueEstimatedWaitSeconds -eq 45 -and $cancelState.Status -match '预计约 45 秒') `
  'queue status did not expose the server estimated wait time'
$script:CancelQueueOnWait = $false

# A signed response may not switch to another path even on the allowlisted host.
$script:QueueResponses.Clear()
$badUrl = "https://df.ltz88.cn/not-the-installer.exe?ticket=$fresh&expires=1999999999&sig=" + ('c' * 64)
$script:QueueResponses.Enqueue([pscustomobject]@{ StatusCode = 200; Payload = New-QueuePayload $fresh ready 0 0 $badUrl })
$blocked = ''
try {
  [void](Wait-BoosterDownloadQueue -SetupUrl 'https://df.ltz88.cn/DeltaForceBooster-Setup.exe' -State @{ Phase='';Status='';Cancel=$false })
} catch { $blocked = $_.Exception.Message }
Assert-True ([bool]$blocked) 'queue accepted a signed URL for a different path'

'PASS updater queue: FIFO polling, ticket renewal, immediate cancellation and signed-path validation'
