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
foreach($name in 'ConvertTo-TelemetryOptimizationItemIds','Get-TelemetryOptimizationItemSetHash',
  'Get-SelectedTelemetryConfigTier','Get-TelemetryOptimizationContext','Set-TelemetryOptimizationContext',
  'Update-TelemetryOptimizationContextFromCatalog','ConvertTo-OptimizationTelemetryIds',
  'New-OptimizationTelemetryOperation','Send-AnonymousTelemetry','New-TuningTelemetryPayload') {
  $node=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)|Select-Object -First 1)
  Assert-True ($node.Count -eq 1) "missing GUI function: $name"
  $functions[$name]=$node[0].Extent.Text
}
Invoke-Expression $functions['ConvertTo-TelemetryOptimizationItemIds']
Invoke-Expression $functions['Get-TelemetryOptimizationItemSetHash']
Invoke-Expression $functions['Get-SelectedTelemetryConfigTier']
Invoke-Expression $functions['Get-TelemetryOptimizationContext']
Invoke-Expression $functions['Set-TelemetryOptimizationContext']
Invoke-Expression $functions['Update-TelemetryOptimizationContextFromCatalog']
Invoke-Expression $functions['ConvertTo-OptimizationTelemetryIds']
Invoke-Expression $functions['New-OptimizationTelemetryOperation']

$temp=Join-Path ([IO.Path]::GetTempPath()) ('dfb-optimization-context-'+[guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path $temp -Force|Out-Null
  $script:UserConfigDir=$temp
  [IO.File]::WriteAllText((Join-Path $temp 'telemetry.json'),(@{
    Enabled=$true;InstallId=[guid]::NewGuid().ToString();CreatedAt=[DateTime]::UtcNow.ToString('o')
    ConfigTier='full';DeviceToken='';TokenExpiresAt=0
  }|ConvertTo-Json),(New-Object Text.UTF8Encoding($true)))
  $legacy=Get-TelemetryOptimizationContext
  Assert-Equal 'full' $legacy.ConfigTier 'legacy tier was not preserved'
  Assert-Equal 'legacy-unknown' $legacy.Scheme 'legacy optimization context was misclassified'
  Assert-True (-not $legacy.ItemsComplete) 'legacy item attribution was treated as complete'

  $ids=@('dvr-off','fso-off','game-mode','game-priority','gpu-pref','mpo-off','paging-exec','prio-separation','transparency-off','wer-off')
  Set-TelemetryOptimizationContext -ItemIds $ids -Scheme balanced -ItemsComplete $true
  $context=Get-TelemetryOptimizationContext
  Assert-Equal 'balanced' $context.ConfigTier 'active item count did not determine current tier'
  Assert-Equal 'balanced' $context.Scheme 'anonymous scheme category was not persisted'
  Assert-Equal 10 $context.ItemIds.Count 'active item ids were not persisted'
  Assert-Equal (Get-TelemetryOptimizationItemSetHash $ids) $context.ItemSetHash 'item set hash is not canonical'

  Update-TelemetryOptimizationContextFromCatalog -Catalog ([pscustomobject]@{
    ActiveItemIds=@('gpu-pref');HasActiveChanges=$true;LegacyBackupCount=0
  }) -RequestedScheme frame-fix -RequestedItemIds @('gpu-pref')
  $frameFix=Get-TelemetryOptimizationContext
  Assert-Equal 'light' $frameFix.ConfigTier 'partial restore/current activity did not lower the tier'
  Assert-Equal 'frame-fix' $frameFix.Scheme 'frame-fix scheme was not attributed'

  Set-TelemetryOptimizationContext -ItemIds @() -Scheme baseline -ItemsComplete $true
  Update-TelemetryOptimizationContextFromCatalog -Catalog ([pscustomobject]@{
    ActiveItemIds=@();HasActiveChanges=$false;LegacyBackupCount=0
  }) -RequestedScheme frame-fix -RequestedItemIds @('gpu-pref') `
    -KnownChangedItemIds @('gpu-pref') -MutationIncomplete
  $backupFailure=Get-TelemetryOptimizationContext
  Assert-Equal 'light' $backupFailure.ConfigTier 'known changed item was lost after backup failure'
  Assert-Equal 'frame-fix' $backupFailure.Scheme 'backup failure lost the known scheme category'
  Assert-True (-not $backupFailure.ItemsComplete) 'backup failure was treated as an exact item set'

  Update-TelemetryOptimizationContextFromCatalog -Catalog ([pscustomobject]@{
    ActiveItemIds=@();HasActiveChanges=$false;LegacyBackupCount=0
  })
  $afterRestart=Get-TelemetryOptimizationContext
  Assert-Equal 'light' $afterRestart.ConfigTier 'empty restore catalog erased an incomplete context on restart'
  Assert-Equal 'gpu-pref' ($afterRestart.ItemIds -join ',') 'known incomplete item was erased on restart'
  Assert-True (-not $afterRestart.ItemsComplete) 'restart promoted incomplete context to baseline'
} finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }

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
foreach($needle in 'driverVersion','gpuCount','displayMode','cpuCores','cpuThreads','cpuPackages',
  'memoryType','memoryConfiguredMhz','memoryRatedMhz','memoryModuleCount','virtualDisplayCount',
  'pagefileAutoManaged','gpuReportedModelDiffers','operation','ConvertTo-Json -Compress -Depth 6') {
  Assert-True $sendText.Contains($needle) "ordinary telemetry is missing $needle"
}
$performanceWorker=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$script:PerformanceCaptureWorker'},$true)|Select-Object -First 1)
Assert-True ($performanceWorker.Count -eq 1) 'performance capture worker is missing'
foreach($needle in 'optimizationScheme','optimizationItemSetHash','optimizationItemIds','optimizationItemsComplete') {
  Assert-True $performanceWorker[0].Extent.Text.Contains($needle) "performance telemetry is missing $needle"
}
$tuningText=$functions['New-TuningTelemetryPayload']
foreach($needle in 'cpuCores','cpuThreads','cpuPackages','memoryType','memoryConfiguredMhz','memoryRatedMhz',
  'memoryModuleCount','virtualDisplayCount','pagefileAutoManaged','gpuReportedModelDiffers',
  'frameCount','frameTimeMadMs','stuttersPerMin','focusLostSec','gpuTempMax','gameExitedEarly','captureFailed','presentMonExitCode') {
  Assert-True $tuningText.Contains($needle) "tuning telemetry is missing $needle"
}

$engineRaw=Get-Content -LiteralPath $enginePath -Raw -Encoding UTF8
foreach($needle in 'ActiveItemIds','RestoredItemIds','RebootItemIds','ApplyIds') {
  Assert-True $engineRaw.Contains($needle) "restore engine output is missing $needle"
}

Write-Host "optimization telemetry tests passed: $script:Assertions assertions"
