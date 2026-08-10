#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$tokens, [ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI PowerShell AST parse failed: ' + (($errors | ForEach-Object Message) -join '; '))
$raw = [IO.File]::ReadAllText($guiPath, [Text.Encoding]::UTF8)

$failureHelpers = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Get-ApplyFailureContext'
}, $true))
Assert-True ($failureHelpers.Count -eq 1) 'Apply failure context helper missing or duplicated'

# 行为测试只执行纯格式化 helper，不加载 WPF，也不访问系统设置。
& {
  param([string]$FunctionText)
  Invoke-Expression $FunctionText

  try { throw [InvalidOperationException]::new('original preflight error') }
  catch { $preflightError = $_ }
  $preflight = Get-ApplyFailureContext $preflightError $false $null
  Assert-True (-not $preflight.AdminBatchReturned) 'preflight failure was marked as a completed admin batch'
  Assert-True ($preflight.UserMessage -ceq 'original preflight error') 'preflight user message did not preserve the original error text'
  Assert-True ($preflight.ErrorMessage -ceq 'original preflight error') 'preflight diagnostic message changed the original error text'
  Assert-True ($preflight.ExceptionType -eq 'System.InvalidOperationException') 'preflight exception type was not captured'
  Assert-True (-not [string]::IsNullOrWhiteSpace($preflight.ScriptStackTrace)) 'preflight ScriptStackTrace was not captured'
  Assert-True (-not $preflight.BackupPath) 'preflight failure invented a backup path'

  try { throw [ArgumentException]::new('post-admin finalization error') }
  catch { $postError = $_ }
  $backup = 'C:\ProgramData\DeltaForceBooster\backup\backup-fixture.json'
  $post = Get-ApplyFailureContext $postError $true ([pscustomobject]@{ Backup = $backup })
  Assert-True $post.AdminBatchReturned 'post-admin failure lost its completed-batch marker'
  Assert-True ($post.BackupPath -ceq $backup) 'post-admin failure lost the returned backup path'
  Assert-True ($post.ExceptionType -eq 'System.ArgumentException') 'post-admin exception type was not captured'
  foreach ($phrase in '系统批次可能已经执行','请不要重复点击「执行优化」','优先点击「还原设置」','点击「重新检测」','post-admin finalization error') {
    Assert-True $post.UserMessage.Contains($phrase) "post-admin user message omitted: $phrase"
  }
} $failureHelpers[0].Extent.Text

$applyStart = $raw.IndexOf('$ui.ApplyBtn.Add_Click({', [StringComparison]::Ordinal)
$restoreStart = $raw.IndexOf('$ui.RestoreBtn.Add_Click({', $applyStart, [StringComparison]::Ordinal)
Assert-True ($applyStart -ge 0 -and $restoreStart -gt $applyStart) 'Apply click handler boundaries not found'
$applyText = $raw.Substring($applyStart, $restoreStart - $applyStart)

$engineOffset = $applyText.IndexOf('$r = Invoke-ElevatedEngineAction -Action Apply', [StringComparison]::Ordinal)
$returnedOffset = $applyText.IndexOf('$adminBatchReturned = $true', [StringComparison]::Ordinal)
$earlyBackupOffset = $applyText.IndexOf('Write-Log "备份已保存：$($r.Backup)"', [StringComparison]::Ordinal)
$localOffset = $applyText.IndexOf('Invoke-LocalNoBackupItems $localItems', [StringComparison]::Ordinal)
Assert-True ($engineOffset -ge 0 -and $returnedOffset -gt $engineOffset) 'admin batch completion marker is not set after the engine returns'
Assert-True ($earlyBackupOffset -gt $returnedOffset -and $localOffset -gt $earlyBackupOffset) 'backup path is not logged before local check/cache finalization'
Assert-True $applyText.Contains('Get-ApplyFailureContext $_ $adminBatchReturned $r') 'Apply catch does not classify post-admin failures'
Assert-True $applyText.Contains('异常类型：$($failure.ExceptionType)') 'Apply catch does not log the exception type'
Assert-True $applyText.Contains('ScriptStackTrace：$($failure.ScriptStackTrace)') 'Apply catch does not log ScriptStackTrace'
Assert-True $applyText.Contains('系统批次可能已执行，请不要重复点击「执行优化」') 'Apply catch does not warn against repeating a possibly completed batch'
Assert-True $applyText.Contains("Show-ConfirmDialog '执行未完成' 'APPLY NOT COMPLETED' `$failure.UserMessage") 'ordinary preflight failure dialog path was not preserved'

'GUI apply finalization tests passed.'
