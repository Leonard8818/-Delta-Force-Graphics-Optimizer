#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'
$enginePath = Join-Path $root 'scripts\delta-booster.ps1'
$script:Assertions = 0

function Assert-True([bool]$Condition,[string]$Message) {
  $script:Assertions++
  if (-not $Condition) { throw "ASSERT: $Message" }
}
function Assert-Equal($Expected,$Actual,[string]$Message) {
  $script:Assertions++
  if ("$Expected" -cne "$Actual") { throw "ASSERT: $Message (expected=$Expected actual=$Actual)" }
}

$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($guiPath,[ref]$tokens,[ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI parse failed: '+(($errors|ForEach-Object Message)-join '; '))
$functions=@{}
foreach($name in 'ConvertTo-OptimizationTelemetryIds','New-OptimizationTelemetryOperation','Send-AnonymousTelemetry','New-TuningTelemetryPayload') {
  $node=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)|Select-Object -First 1)
  Assert-True ($node.Count -eq 1) "missing GUI function: $name"
  $functions[$name]=$node[0].Extent.Text
}
Invoke-Expression $functions['ConvertTo-OptimizationTelemetryIds']
Invoke-Expression $functions['New-OptimizationTelemetryOperation']

$applyId=[guid]::NewGuid().ToString('D')
$applyReply=[pscustomobject]@{
  ApplyId=$applyId;Backup='backup.json';BackupError='partial backup failure'
  Results=@(
    [pscustomobject]@{Id='gpu-pref';Ok=$true;Changed=$true;Skipped=$false;Attention=$false},
    [pscustomobject]@{Id='timer-resolution';Ok=$false;Changed=$false;Skipped=$false;Attention=$false},
    [pscustomobject]@{Id='vcredist-check';Ok=$false;Changed=$false;Skipped=$false;Attention=$true}
  )
}
$apply=New-OptimizationTelemetryOperation -Event apply -Source manual_selection -Reply $applyReply `
  -ItemIds @('gpu-pref','timer-resolution','vcredist-check')
Assert-Equal $applyId.ToLowerInvariant() $apply.operationId 'apply id was not preserved'
Assert-Equal 'partial' $apply.result 'mixed apply did not become partial'
Assert-Equal 'partial' $apply.backupStatus 'partial backup state was lost'
Assert-Equal 'gpu-pref' ($apply.changedItemIds -join ',') 'changed project attribution is wrong'
Assert-Equal 'gpu-pref' ($apply.succeededItemIds -join ',') 'successful project attribution is wrong'
Assert-Equal 'timer-resolution' ($apply.failedItemIds -join ',') 'failed project attribution is wrong'
Assert-Equal 'vcredist-check' ($apply.attentionItemIds -join ',') 'attention project attribution is wrong'
Assert-Equal 1 $apply.succeededUnitCount 'apply success count is wrong'
Assert-Equal 1 $apply.failedUnitCount 'apply failure count is wrong'

$restoreReply=[pscustomobject]@{
  RestoredOps=2;Failed=@('timer-resolution: readback mismatch');Skipped=@()
  ItemResults=@(
    [pscustomobject]@{Id='gpu-pref';Ok=$true},
    [pscustomobject]@{Id='timer-resolution';Ok=$false}
  )
  RebootItemIds=@('gpu-pref');ApplyIds=@($applyId)
}
$restore=New-OptimizationTelemetryOperation -Event restore -Source restore_manager -Reply $restoreReply `
  -ItemIds @('gpu-pref','timer-resolution') -RestoreMode selected_items
Assert-Equal 'partial' $restore.result 'mixed restore did not become partial'
Assert-Equal 'failed' $restore.verificationStatus 'restore failure verification status is wrong'
Assert-Equal 1 $restore.residualCount 'restore residual count is wrong'
Assert-Equal $applyId.ToLowerInvariant() ($restore.relatedOperationIds -join ',') 'restore/apply lineage was lost'
Assert-Equal 'gpu-pref' ($restore.rebootItemIds -join ',') 'reboot project id was lost'
Assert-True ($restore.operationId -match '^[0-9a-f-]{36}$' -and $restore.operationId -ne $applyId) 'restore operation id is not fresh'

$sendText=$functions['Send-AnonymousTelemetry']
foreach($needle in 'driverVersion','gpuCount','displayMode','operation','ConvertTo-Json -Compress -Depth 6') {
  Assert-True $sendText.Contains($needle) "ordinary telemetry is missing $needle"
}
$tuningText=$functions['New-TuningTelemetryPayload']
foreach($needle in 'frameCount','frameTimeMadMs','stuttersPerMin','focusLostSec','gpuTempMax','gameExitedEarly','captureFailed','presentMonExitCode') {
  Assert-True $tuningText.Contains($needle) "tuning telemetry is missing $needle"
}

$engineRaw=Get-Content -LiteralPath $enginePath -Raw -Encoding UTF8
foreach($needle in 'ActiveItemIds','RestoredItemIds','RebootItemIds','ApplyIds') {
  Assert-True $engineRaw.Contains($needle) "restore engine output is missing $needle"
}

Write-Host "optimization telemetry tests passed: $script:Assertions assertions"
