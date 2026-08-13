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
$tokens = $null; $errors = $null
$engineAst = [Management.Automation.Language.Parser]::ParseFile($enginePath, [ref]$tokens, [ref]$errors)
Assert-True ($errors.Count -eq 0) 'engine PowerShell AST parse failed'
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

# RequestFile 没有显卡伪装型号时，不能把 JSON null/空串重新赋给带 ValidateSet 的
# 顶层参数变量；Windows PowerShell 5.1 会在赋值时再次验证并抛出 ValidateSetFailure。
$gpuRehydrateAssignments = @($engineAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left.Extent.Text -eq '$GpuSpoofModel' -and
    $node.Right.Extent.Text -eq '$engineRequest.GpuSpoofModel'
}, $true))
Assert-True ($gpuRehydrateAssignments.Count -eq 1) 'GpuSpoofModel request rehydration assignment missing or duplicated'
$gpuRehydrateGuard = $gpuRehydrateAssignments[0].Parent.Parent
Assert-True ($gpuRehydrateGuard -is [Management.Automation.Language.IfStatementAst] -and
  $gpuRehydrateGuard.Extent.Text -match '^if\s*\(\$engineRequest\.GpuSpoofModel\)') `
  'GpuSpoofModel request rehydration is not guarded against null/empty optional values'
$gpuRehydrateScript = [scriptblock]::Create(@"
param(
  [ValidateSet('NVIDIA GeForce GTX 750 Ti', 'NVIDIA GeForce GTX 1050 Ti',
               'NVIDIA GeForce RTX 2050', 'NVIDIA GeForce RTX 2060', 'AMD Radeon RX560')]
  [string]`$GpuSpoofModel,
  `$engineRequest
)
$($gpuRehydrateGuard.Extent.Text)
`$GpuSpoofModel
"@)
$nullGpu = & $gpuRehydrateScript -engineRequest ([pscustomobject]@{ GpuSpoofModel=$null })
$emptyGpu = & $gpuRehydrateScript -engineRequest ([pscustomobject]@{ GpuSpoofModel='' })
$validGpu = & $gpuRehydrateScript -engineRequest ([pscustomobject]@{ GpuSpoofModel='NVIDIA GeForce GTX 1050 Ti' })
Assert-True (-not $nullGpu -and -not $emptyGpu -and
  $validGpu -eq 'NVIDIA GeForce GTX 1050 Ti') `
  'GpuSpoofModel optional request rehydration still triggers validation or drops a valid model'

# 再执行完整的生产 RequestFile 入口块，而不只测试单条赋值。这样后续调整入口变量
# 回填顺序时，Restore 目录查询的 null 型号和 Apply 的有效型号都会走真实参数约束。
$requestFileBlocks = @($engineAst.EndBlock.Statements | Where-Object {
  $_ -is [Management.Automation.Language.IfStatementAst] -and
  $_.Clauses.Count -eq 1 -and $_.Clauses[0].Item1.Extent.Text -eq '$RequestFile'
})
Assert-True ($requestFileBlocks.Count -eq 1) 'top-level RequestFile dispatch block missing or duplicated'
$requestFileHarness = [scriptblock]::Create(@"
[CmdletBinding()]
$($engineAst.ParamBlock.Extent.Text)
function Import-EngineActionRequest([string]`$Path) { `$global:DfbEngineRequestFixture }
$($requestFileBlocks[0].Extent.Text)
[pscustomobject]@{
  Apply=[bool]`$Apply; Restore=[bool]`$Restore; ListRestoreItems=[bool]`$ListRestoreItems
  GpuSpoofModel=`$GpuSpoofModel; ItemIds=[string[]]@(`$Items)
}
"@)
try {
  $global:DfbEngineRequestFixture = [pscustomobject]@{
    ResultFile='C:\fixture-result.json';ResultId=[guid]::NewGuid().ToString('D')
    UserSid='S-1-5-21-1-2-3-1001';UserLocalAppData='C:\Users\Fixture\AppData\Local'
    UserStateRoot='C:\ProgramData\DeltaForceBooster\users\S-1-5-21-1-2-3-1001'
    Action='Restore';ListRestoreItems=$true;ItemIds=[string[]]@();GamePath=$null
    AllowRisky=$false;GpuSpoofModel=$null;BackupFile=$null;RestoreItemIds=[string[]]@()
  }
  $restoreHydrated = & $requestFileHarness -RequestFile 'C:\fixture-request.json'
  Assert-True ($restoreHydrated.ListRestoreItems -and -not $restoreHydrated.Restore -and
    -not $restoreHydrated.Apply -and -not $restoreHydrated.GpuSpoofModel) `
    'full Restore request rehydration failed with an omitted GpuSpoofModel'

  $global:DfbEngineRequestFixture.Action = 'Apply'
  $global:DfbEngineRequestFixture.ListRestoreItems = $false
  $global:DfbEngineRequestFixture.ItemIds = [string[]]@('game-mode')
  $global:DfbEngineRequestFixture.GpuSpoofModel = 'NVIDIA GeForce GTX 1050 Ti'
  $applyHydrated = & $requestFileHarness -RequestFile 'C:\fixture-request.json'
  Assert-True ($applyHydrated.Apply -and -not $applyHydrated.Restore -and
    $applyHydrated.GpuSpoofModel -eq 'NVIDIA GeForce GTX 1050 Ti' -and
    @($applyHydrated.ItemIds).Count -eq 1) `
    'full Apply request rehydration changed a valid GpuSpoofModel'
} finally {
  Remove-Variable DfbEngineRequestFixture -Scope Global -ErrorAction SilentlyContinue
  $script:EngineResultFile = $null
}

# 必须通过真实 Windows PowerShell 5.1 -File 参数绑定路径回归。点源测试不会复现脚本级
# 未绑定 [string[]] 参数在 @($Items).Count 中变成 1 的行为，正是这次实机故障漏测的原因。
$winPs = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$probeRequest = 'C:\ProgramData\DeltaForceBooster\session-temp\fixture\engine-request-00000000-0000-0000-0000-000000000000.json'
$savedEngineSession = $env:DFB_ENGINE_HOST_SESSION
$savedErrorActionPreference = $ErrorActionPreference
try {
  Remove-Item Env:DFB_ENGINE_HOST_SESSION -ErrorAction SilentlyContinue
  $ErrorActionPreference = 'Continue'
  $singleOutput = (& $winPs -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File $enginePath -RequestFile $probeRequest 2>&1 | Out-String)
  $singleExit = $LASTEXITCODE
  Assert-True ($singleExit -ne 0 -and $singleOutput -notlike '*-RequestFile 不能与其他动作或业务参数同时使用*' -and
    $singleOutput -like '*EngineHost 会话标记*') `
    "RequestFile-only WinPS5.1 launch was rejected as a mixed request: $singleOutput"

  $mixedOutput = (& $winPs -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File $enginePath -RequestFile $probeRequest -Apply 2>&1 | Out-String)
  Assert-True ($LASTEXITCODE -ne 0 -and
    $mixedOutput -like '*-RequestFile 不能与其他动作或业务参数同时使用*') `
    'RequestFile mixed with a business action was not rejected'
} finally {
  $ErrorActionPreference = $savedErrorActionPreference
  if ($null -eq $savedEngineSession) { Remove-Item Env:DFB_ENGINE_HOST_SESSION -ErrorAction SilentlyContinue }
  else { $env:DFB_ENGINE_HOST_SESSION = $savedEngineSession }
}

# PowerShell 会让 `$null | ForEach-Object { "$_" }` 产生一个空字符串。直接执行生产函数里的
# 两条归一化赋值，确保未绑定的 ItemIds / RestoreItemIds 始终得到真正的空数组。
$normalizationAssignments = @($invokeFunctions[0].Body.FindAll({
  param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left.Extent.Text -in @('$itemIdsForRequest','$restoreIdsForRequest')
}, $true))
Assert-True ($normalizationAssignments.Count -eq 2) 'request array normalization assignments missing or duplicated'
$normalizationScript = [scriptblock]::Create(@"
param([string[]]`$ItemIds, [string[]]`$RestoreItemIds)
$($normalizationAssignments[0].Extent.Text)
$($normalizationAssignments[1].Extent.Text)
[pscustomobject]@{ ItemIds = [string[]]`$itemIdsForRequest; RestoreItemIds = [string[]]`$restoreIdsForRequest }
"@)
$emptyNormalization = & $normalizationScript
Assert-True (@($emptyNormalization.ItemIds).Count -eq 0 -and
  @($emptyNormalization.RestoreItemIds).Count -eq 0) `
  'unbound request arrays were normalized to an empty-string element instead of empty arrays'
$valueNormalization = & $normalizationScript @('game-mode') @('gpu-pref')
Assert-True (@($valueNormalization.ItemIds).Count -eq 1 -and
  $valueNormalization.ItemIds[0] -eq 'game-mode' -and
  @($valueNormalization.RestoreItemIds).Count -eq 1 -and
  $valueNormalization.RestoreItemIds[0] -eq 'gpu-pref') `
  'request array normalization changed valid item IDs'

# 行为级复现截图中的两个入口。拦截请求落盘，证明 Apply 与还原目录查询都能通过
# GUI 参数组合校验，并且未绑定的另一类项目数组在请求中确实为空。
& {
  param([string]$FunctionText, [string]$RepositoryRoot)
  Invoke-Expression $FunctionText
  $isAdminGui = $true
  $saved = @{
    Validated = $script:EngineHostSessionValidated; Root = $script:RootDir
    Local = $script:OriginalUserLocalAppData; Sid = $script:OriginalUserSid
    State = $script:ProtectedUserStateRoot
  }
  try {
    $script:EngineHostSessionValidated = $true
    $script:RootDir = $RepositoryRoot
    $script:OriginalUserLocalAppData = 'C:\Users\Fixture\AppData\Local'
    $script:OriginalUserSid = 'S-1-5-21-111111111-222222222-333333333-1001'
    $script:ProtectedUserStateRoot = 'C:\ProgramData\DeltaForceBooster\users\S-1-5-21-111111111-222222222-333333333-1001'
    function Test-ProtectedProgramRoot { $true }
    function Get-ProtectedEngineExchangeRoot { 'C:\ProgramData\DeltaForceBooster\session-temp\fixture' }
    function Remove-ProtectedEngineExchangeFile {}
    function Write-ProtectedEngineRequest([string]$Path, $Request) {
      $script:CapturedRequest = $Request
      throw 'REQUEST_CAPTURED'
    }

    $caught = ''
    try { Invoke-ElevatedEngineAction -Action Apply -ItemIds @('game-mode') -GamePath 'D:\Games\DeltaForce.exe' }
    catch { $caught = $_.Exception.Message }
    Assert-True ($caught -eq 'REQUEST_CAPTURED') "normal Apply failed before request creation: $caught"
    Assert-True ($script:CapturedRequest.Action -eq 'Apply' -and
      @($script:CapturedRequest.ItemIds).Count -eq 1 -and
      @($script:CapturedRequest.RestoreItemIds).Count -eq 0 -and
      -not $script:CapturedRequest.ListRestoreItems) `
      'normal Apply request contains restore parameters'

    $script:CapturedRequest = $null; $caught = ''
    try { Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems }
    catch { $caught = $_.Exception.Message }
    Assert-True ($caught -eq 'REQUEST_CAPTURED') "restore catalog query failed before request creation: $caught"
    Assert-True ($script:CapturedRequest.Action -eq 'Restore' -and
      @($script:CapturedRequest.ItemIds).Count -eq 0 -and
      @($script:CapturedRequest.RestoreItemIds).Count -eq 0 -and
      $script:CapturedRequest.ListRestoreItems) `
      'restore catalog request contains Apply or selective-restore parameters'
  } finally {
    $script:EngineHostSessionValidated = $saved.Validated; $script:RootDir = $saved.Root
    $script:OriginalUserLocalAppData = $saved.Local; $script:OriginalUserSid = $saved.Sid
    $script:ProtectedUserStateRoot = $saved.State
    Remove-Variable CapturedRequest -Scope Script -ErrorAction SilentlyContinue
  }
} $invokeText $root

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
