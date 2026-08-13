#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $root 'scripts\delta-booster.ps1'
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

function Write-RequestFixture([string]$Path, $Document) {
  [IO.File]::WriteAllText($Path, ($Document | ConvertTo-Json -Depth 5 -Compress),
    (New-Object Text.UTF8Encoding($false)))
}

$tokens = $null; $errors = $null
$guiAst = [Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$tokens, [ref]$errors)
Assert-True ($errors.Count -eq 0) 'GUI PowerShell AST parse failed'
$invokeFunctions = @($guiAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-ElevatedEngineAction'
}, $true))
Assert-True ($invokeFunctions.Count -eq 1) 'Invoke-ElevatedEngineAction missing or duplicated'
$invokeText = $invokeFunctions[0].Extent.Text
Assert-True (-not $invokeText.Contains('-EncodedCommand')) 'admin engine action still uses EncodedCommand'
foreach ($needle in "'-File'","'-RequestFile'",'Diagnostics.ProcessStartInfo','RedirectStandardOutput = $true',
                    'RedirectStandardError = $true','ReadToEndAsync()','Get-ProtectedEngineExchangeRoot') {
  Assert-True $invokeText.Contains($needle) "admin engine transport missing: $needle"
}
Assert-True ($invokeText.Contains('本次系统设置可能已部分执行') -and $invokeText.Contains('请不要重复点击')) `
  'missing-result path does not warn against an unsafe duplicate Apply'

foreach ($helper in 'ConvertTo-NativeFileArgument','ConvertTo-EngineDiagnosticSummary') {
  $matches = @($guiAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $helper
  }, $true))
  Assert-True ($matches.Count -eq 1) "GUI transport helper missing or duplicated: $helper"
  Invoke-Expression $matches[0].Extent.Text
}
Assert-True ((ConvertTo-NativeFileArgument 'C:\Program Files\Delta Force\engine.ps1') -eq
  '"C:\Program Files\Delta Force\engine.ps1"') 'direct -File native path quoting changed unexpectedly'
$rejected = $false
try { [void](ConvertTo-NativeFileArgument "C:\bad`npath.ps1") } catch { $rejected = $true }
Assert-True $rejected 'native file argument must reject control characters'
Assert-True ((ConvertTo-EngineDiagnosticSummary "  policy`r`nblocked  " 'ignored') -eq 'policy blocked') `
  'child stderr diagnostic normalization is incomplete'

. $enginePath

$temp = Join-Path ([IO.Path]::GetTempPath()) ('dfb-engine-request-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
  # Transport schema/route behavior is exercised against an isolated directory. ACL primitives are
  # mocked here because the production EngineHost creates the real Administrators/SYSTEM-only root.
  function Test-ProtectedDirectoryAclExact([string]$Path, [bool]$UsersRead) { $true }
  function Test-ProtectedFileAcl([string]$Path) { $true }
  function Set-ProtectedFileAcl([string]$Path) {}
  function Get-ValidatedEngineSessionRoot { $temp }

  $sid = 'S-1-5-21-111111111-222222222-333333333-1001'
  $local = 'C:\Users\Fixture\AppData\Local'
  $state = 'C:\ProgramData\DeltaForceBooster\users\S-1-5-21-111111111-222222222-333333333-1001'
  $id = [guid]::NewGuid().ToString('D')
  $applyPath = Join-Path $temp "engine-request-$id.json"
  $applyDocument = [ordered]@{
    SchemaVersion=1;ResultId=$id;Action='Apply';ItemIds=[string[]]@('game-mode','gpu-pref')
    GamePath='D:\Games\DeltaForce.exe';AllowRisky=$false;GpuSpoofModel=$null;BackupFile=$null
    ListRestoreItems=$false;RestoreItemIds=[string[]]@();UserSid=$sid
    UserLocalAppData=$local;UserStateRoot=$state
  }
  Write-RequestFixture $applyPath $applyDocument
  $applyRequest = Import-EngineActionRequest $applyPath $temp
  Assert-True ($applyRequest.ResultId -eq $id -and $applyRequest.Action -eq 'Apply' -and
    @($applyRequest.ItemIds).Count -eq 2 -and $applyRequest.ItemIds[1] -eq 'gpu-pref' -and
    $applyRequest.ResultFile -eq (Join-Path $temp "engine-result-$id.json")) `
    'valid Apply request did not round-trip through strict transport schema'

  $restoreId = [guid]::NewGuid().ToString('D')
  $restorePath = Join-Path $temp "engine-request-$restoreId.json"
  $restoreDocument = [ordered]@{
    SchemaVersion=1;ResultId=$restoreId;Action='Restore';ItemIds=[string[]]@();GamePath=$null
    AllowRisky=$false;GpuSpoofModel=$null;BackupFile=$null;ListRestoreItems=$true
    RestoreItemIds=[string[]]@();UserSid=$sid;UserLocalAppData=$local;UserStateRoot=$state
  }
  Write-RequestFixture $restorePath $restoreDocument
  $restoreRequest = Import-EngineActionRequest $restorePath $temp
  Assert-True ($restoreRequest.Action -eq 'Restore' -and $restoreRequest.ListRestoreItems -and
    @($restoreRequest.ItemIds).Count -eq 0) 'valid restore-catalog request was rejected or changed'

  $script:EngineResultFile = $applyRequest.ResultFile
  Write-IpcResult $id 'Apply' ([pscustomobject]@{ Marker='ok' }) 0 $null
  Assert-True (Test-Path -LiteralPath $applyRequest.ResultFile -PathType Leaf) `
    'request transport did not publish its result in the protected session directory'
  $resultDocument = Get-Content -LiteralPath $applyRequest.ResultFile -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($resultDocument.ResultId -eq $id -and $resultDocument.Action -eq 'Apply' -and
    [int]$resultDocument.ExitCode -eq 0 -and $resultDocument.Data.Marker -eq 'ok') `
    'protected session result schema is incomplete'
  $script:EngineResultFile = $null

  $extraId = [guid]::NewGuid().ToString('D')
  $extraPath = Join-Path $temp "engine-request-$extraId.json"
  $extraDocument = [ordered]@{} + $restoreDocument
  $extraDocument.ResultId = $extraId
  $extraDocument.Extra = 'unexpected'
  Write-RequestFixture $extraPath $extraDocument
  $caught = ''
  try { [void](Import-EngineActionRequest $extraPath $temp) } catch { $caught = $_.Exception.Message }
  Assert-True ($caught -like '*未知字段*') "unknown request fields must be rejected (actual: $caught)"

  $mixedId = [guid]::NewGuid().ToString('D')
  $mixedPath = Join-Path $temp "engine-request-$mixedId.json"
  $mixedDocument = [ordered]@{} + $restoreDocument
  $mixedDocument.ResultId = $mixedId
  $mixedDocument.GamePath = 'D:\Games\DeltaForce.exe'
  Write-RequestFixture $mixedPath $mixedDocument
  $rejected = $false
  try { [void](Import-EngineActionRequest $mixedPath $temp) } catch { $rejected = $_.Exception.Message -like '*包含 Apply 参数*' }
  Assert-True $rejected 'Restore request must reject Apply-only fields'

  $mismatchId = [guid]::NewGuid().ToString('D')
  $mismatchPath = Join-Path $temp "engine-request-$mismatchId.json"
  Write-RequestFixture $mismatchPath $applyDocument
  $rejected = $false
  try { [void](Import-EngineActionRequest $mismatchPath $temp) } catch { $rejected = $_.Exception.Message -like '*与文件名不匹配*' }
  Assert-True $rejected 'request ResultId must be bound to its protected filename'

  $outside = Join-Path (Split-Path -Parent $temp) ("engine-request-$([guid]::NewGuid().ToString('D')).json")
  Write-RequestFixture $outside $applyDocument
  try {
    $rejected = $false
    try { [void](Import-EngineActionRequest $outside $temp) } catch { $rejected = $_.Exception.Message -like '*不在当前会话目录*' }
    Assert-True $rejected 'request path outside the protected session root must be rejected'
  } finally { Remove-Item -LiteralPath $outside -Force -ErrorAction SilentlyContinue }
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}

Write-Host 'PASS: protected direct-File administrator engine request/result transport'
