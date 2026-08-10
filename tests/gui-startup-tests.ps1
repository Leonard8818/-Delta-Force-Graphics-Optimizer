#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

function Assert-Throws([scriptblock]$Action, [string]$Message) {
  try {
    & $Action
    throw "ASSERT FAILED: $Message"
  } catch {
    if ($_.Exception.Message -like 'ASSERT FAILED:*') { throw }
  }
}

$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$tokens, [ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI PowerShell AST parse failed: ' + (($errors | ForEach-Object Message) -join '; '))
$raw = [IO.File]::ReadAllText($guiPath, [Text.Encoding]::UTF8)

Assert-True (-not $raw.Contains('「立即更新」全程自动：')) 'obsolete inline-update explanation is still shown'
Assert-True $raw.Contains("`$script:UpdUi.InlineNote.Visibility = 'Collapsed'") 'inline-update explanation row is not collapsed'
Assert-True ($raw -match 'Start-Process\s+-FilePath\s+\$PresentMon\s+-WorkingDirectory\s+\(\[Environment\]::SystemDirectory\)') `
  'PresentMon does not use the trusted neutral working directory'
Assert-True ($raw -match 'Start-Process\s+-FilePath\s+\$SetupFile\s+-WorkingDirectory\s+\(\[Environment\]::SystemDirectory\)') `
  'inline setup still inherits the product working directory'
Assert-True ($raw.Contains('Content="上传完整诊断"') -and
  $raw.Contains("`$lines.Add('== 运行环境与显示 / 音频 ==')") -and
  $raw.Contains("`$lines.Add('== 关键环境变量（脱敏） ==')")) `
  'expanded negative-effect diagnostic collection is missing from the report button'
Assert-True ($raw.Contains("'SystemRoot','WINDIR','ProgramData','ProgramFiles','ProgramFiles(x86)','TEMP','TMP','PATH','PSModulePath','COMSPEC','PATHEXT','__COMPAT_LAYER'") -and
  $raw.Contains('（仅记录名称，不上传值）')) `
  'diagnostic environment collection is not value-allowlisted or does not redact injection values'

function Find-GuiFunction([string]$Name) {
  $matches = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name
  }, $true))
  Assert-True ($matches.Count -eq 1) "GUI helper missing or duplicated: $Name"
  return $matches[0]
}

$getUacFunction = Find-GuiFunction 'Get-UacEnableLuaValue'
$getFilterFunction = Find-GuiFunction 'Get-UacFilterAdministratorTokenValue'
$sidFunction = Find-GuiFunction 'Test-IsBuiltInAdministratorSid'
$enableUacFunction = Find-GuiFunction 'Enable-UacForNextRestart'
$localNoBackupFunction = Find-GuiFunction 'Invoke-LocalNoBackupItems'
$validatedCandidateFunction = Find-GuiFunction 'Get-ValidatedTuningCandidateRuntime'
$repairBranches = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.IfStatementAst] -and
    $node.Clauses.Count -gt 0 -and $node.Clauses[0].Item1.Extent.Text.Trim() -eq '$needsUacRepair'
}, $true))
Assert-True ($repairBranches.Count -eq 1) 'disabled-UAC recovery branch missing or duplicated'
$repairText = $repairBranches[0].Extent.Text
$hostAssignments = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
    $node.Left.VariablePath.UserPath -ieq 'Host'
}, $true))
Assert-True ($hostAssignments.Count -eq 0) 'GUI assigns PowerShell built-in read-only $Host variable'
Assert-True ($raw.Contains('$engineHostProcess = Get-CimInstance Win32_Process')) `
  'GUI bootstrap does not store the EngineHost process in a non-reserved variable'

Assert-True $raw.Contains('Test-IsBuiltInAdministratorSid $script:OriginalUserSid') `
  'startup does not identify RID-500 from the authenticated original user SID'
Assert-True (-not $raw.Contains('Test-IsBuiltInAdministratorSid $currentSidValue')) `
  'startup can mistake an OTS approval administrator for the original user'
Assert-True (-not ($raw -match '\$env:(?:USERNAME|USERDOMAIN|COMPUTERNAME)')) `
  'high GUI diagnostics still read the UAC approval account environment'
Assert-True ($raw.Contains('Split-Path -Parent $script:OriginalUserLocalAppData') -and
  $raw.Contains('[Environment]::MachineName')) `
  'diagnostic redaction is not derived from the authenticated original user context'
Assert-True $raw.Contains('if (-not $isAdminGui) { Stop-UntrustedGuiStartup') 'main GUI does not fail closed without an administrator token'
Assert-True $raw.Contains('$enableLUA = Get-UacEnableLuaValue') 'elevated startup does not inspect the real EnableLUA policy'
Assert-True $raw.Contains('$filterAdministratorToken') 'RID-500 startup does not inspect FilterAdministratorToken'
Assert-True $repairText.Contains('[Windows.MessageBoxButton]::YesNoCancel') 'UAC/net-cafe choice is not explicitly confirmed by the user'
Assert-True $repairText.Contains('Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode:$isBuiltInAdministrator') 'confirmed recovery does not select the correct ordinary/RID-500 write set'
Assert-True $repairText.Contains('管理员审批模式') 'RID-500 recovery does not explain Administrator Approval Mode'
Assert-True $repairText.Contains('软件不会自动重启') 'UAC recovery does not state that restart timing remains with the user'
Assert-True ($repairText.Contains('$script:NetCafeCompatibilityMode = $true') -and
  $repairText.Contains('本次不修改 UAC，也不要求重启') -and
  $repairText.Contains('用户缓存清理、显卡软件检测和外链入口会停用')) `
  'repair-only session does not offer the explicit no-restart net-cafe compatibility mode'
Assert-True ($repairText -match '(?s)MessageBoxResult\]::No.*Enable-UacForNextRestart.*exit') `
  'policy-repair choice does not exit after persisting restart-required UAC settings'
Assert-True ($repairText -match '(?s)else \{ exit \}\s*\}') `
  'cancelled UAC/net-cafe choice can continue into the GUI'
Assert-True (-not $repairText.Contains('Restart-Computer') -and -not $repairText.Contains('shutdown.exe')) 'UAC recovery must not force a restart'
Assert-True ($raw -match 'NetCafeCompatibilityMode[\s\S]{0,500}Where-Object \{ \$_\.Kind -ne ''cache'' \}') `
  'net-cafe compatibility mode does not remove the medium-token cache action from the UI'

$uacWrites = @($enableUacFunction.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'New-ItemProperty'
}, $true))
Assert-True ($uacWrites.Count -eq 2) 'UAC helper must define only the EnableLUA and conditional FilterAdministratorToken writes'

# PowerShell 对 Generic.List<T> 的直接数组子表达式 `@($list)` 会抛
# System.ArgumentException: Argument types do not match。扫描每个 GUI helper 内的 List 声明，
# 禁止以后再次写回这种会在 Windows PowerShell 5.1 实机上阻断执行收尾的形式。
$genericListWrapFailures = New-Object 'System.Collections.Generic.List[string]'
$guiFunctions = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst]
}, $true))
foreach ($function in $guiFunctions) {
  $listAssignments = @($function.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
      $node.Right.Extent.Text -match '(?i)^\s*New-Object\s+[''"]?(?:System\.)?Collections\.Generic\.List\['
  }, $true))
  foreach ($assignment in $listAssignments) {
    $variableName = $assignment.Left.VariablePath.UserPath
    $directWrapPattern = '^@\(\s*\$' + [regex]::Escape($variableName) + '\s*\)$'
    $badWraps = @($function.FindAll({
      param($node)
      $node -is [Management.Automation.Language.ArrayExpressionAst]
    }, $true) | Where-Object { $_.Extent.Text -match $directWrapPattern })
    foreach ($badWrap in $badWraps) {
      [void]$genericListWrapFailures.Add("$($function.Name):$($badWrap.Extent.StartLineNumber) $($badWrap.Extent.Text)")
    }
  }
}
Assert-True ($genericListWrapFailures.Count -eq 0) `
  ('Generic.List must call ToArray() before @(): ' + ($genericListWrapFailures -join '; '))

# 只执行四个纯 helper，并用同名 mock 拦截注册表访问；测试不得改变测试机的真实 UAC。
$getUacFunctionText = $getUacFunction.Extent.Text
$getFilterFunctionText = $getFilterFunction.Extent.Text
$sidFunctionText = $sidFunction.Extent.Text
$enableUacFunctionText = $enableUacFunction.Extent.Text
& {
  param(
    [string]$GetFunctionText,
    [string]$GetFilterFunctionText,
    [string]$SidFunctionText,
    [string]$EnableFunctionText
  )

  $script:MockUacValues = @{ EnableLUA = 0; FilterAdministratorToken = 0 }
  $script:MockUacReadFailureName = ''
  $script:MockUacWriteFailureName = ''
  $script:MockUacHoldWriteName = ''
  $script:MockUacWrites = New-Object 'System.Collections.Generic.List[object]'
  $script:MockUacReads = New-Object 'System.Collections.Generic.List[string]'

  function Reset-MockUac([int]$EnableLUA = 0, [int]$FilterAdministratorToken = 0) {
    $script:MockUacValues = @{ EnableLUA = $EnableLUA; FilterAdministratorToken = $FilterAdministratorToken }
    $script:MockUacReadFailureName = ''
    $script:MockUacWriteFailureName = ''
    $script:MockUacHoldWriteName = ''
    $script:MockUacWrites.Clear()
    $script:MockUacReads.Clear()
  }

  function Get-ItemProperty {
    param([string]$LiteralPath, [string]$Name, [object]$ErrorAction)
    [void]$script:MockUacReads.Add($Name)
    if ($script:MockUacReadFailureName -eq $Name) { throw 'simulated registry read failure' }
    if ($Name -eq 'EnableLUA') {
      return [pscustomobject]@{ EnableLUA = $script:MockUacValues.EnableLUA }
    }
    if ($Name -eq 'FilterAdministratorToken') {
      return [pscustomobject]@{ FilterAdministratorToken = $script:MockUacValues.FilterAdministratorToken }
    }
    throw "unexpected registry read: $Name"
  }

  function New-ItemProperty {
    param(
      [string]$LiteralPath,
      [string]$Name,
      [object]$Value,
      [string]$PropertyType,
      [switch]$Force,
      [object]$ErrorAction
    )
    [void]$script:MockUacWrites.Add([pscustomobject]@{
      LiteralPath = $LiteralPath
      Name = $Name
      Value = $Value
      PropertyType = $PropertyType
      Force = [bool]$Force
    })
    if ($script:MockUacWriteFailureName -eq $Name) { throw 'simulated registry write failure' }
    if ($script:MockUacHoldWriteName -ne $Name) { $script:MockUacValues[$Name] = $Value }
  }

  Invoke-Expression $GetFunctionText
  Invoke-Expression $GetFilterFunctionText
  Invoke-Expression $SidFunctionText
  Invoke-Expression $EnableFunctionText

  Assert-True (Test-IsBuiltInAdministratorSid 'S-1-5-21-111-222-333-500') 'RID-500 SID was not identified'
  Assert-True (-not (Test-IsBuiltInAdministratorSid 'S-1-5-21-111-222-333-5000')) 'non-RID-500 SID was misidentified'
  Assert-True (-not (Test-IsBuiltInAdministratorSid '')) 'empty SID was misidentified'

  Reset-MockUac 0 0
  Assert-True ((Get-UacEnableLuaValue) -eq 0) 'EnableLUA=0 was not detected'
  Assert-True ((Get-UacFilterAdministratorTokenValue) -eq 0) 'FilterAdministratorToken=0 was not detected'
  $script:MockUacReadFailureName = 'EnableLUA'
  Assert-True ($null -eq (Get-UacEnableLuaValue)) 'unreadable EnableLUA was guessed instead of returning unknown'
  $script:MockUacReadFailureName = 'FilterAdministratorToken'
  Assert-True ($null -eq (Get-UacFilterAdministratorTokenValue)) 'unreadable FilterAdministratorToken was guessed instead of returning unknown'

  # 普通管理员只写 EnableLUA=1，并复读确认；FilterAdministratorToken 必须保持不变。
  Reset-MockUac 0 0
  Enable-UacForNextRestart
  Assert-True ($script:MockUacWrites.Count -eq 1) 'ordinary administrator recovery wrote more than EnableLUA'
  Assert-True (($script:MockUacReads -join ',') -eq 'EnableLUA') 'ordinary administrator recovery read back values other than EnableLUA'
  $ordinaryWrite = $script:MockUacWrites[0]
  Assert-True ($ordinaryWrite.LiteralPath -eq 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System') 'ordinary UAC writer targeted the wrong registry path'
  Assert-True ($ordinaryWrite.Name -eq 'EnableLUA' -and $ordinaryWrite.Value -eq 1) 'ordinary UAC writer did not write only EnableLUA=1'
  Assert-True ($ordinaryWrite.PropertyType -eq 'DWord' -and $ordinaryWrite.Force) 'ordinary UAC writer did not persist a forced DWORD'
  Assert-True ($script:MockUacValues.FilterAdministratorToken -eq 0) 'ordinary administrator recovery changed FilterAdministratorToken'

  # RID-500 账户还必须开启并复验内置 Administrator 的管理员审批模式。
  Reset-MockUac 0 0
  Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode
  Assert-True ($script:MockUacWrites.Count -eq 2) 'RID-500 recovery did not perform exactly two writes'
  Assert-True ((@($script:MockUacWrites | ForEach-Object Name) -join ',') -eq 'FilterAdministratorToken,EnableLUA') 'RID-500 recovery did not write approval mode before enabling UAC'
  Assert-True (($script:MockUacReads -join ',') -eq 'FilterAdministratorToken,EnableLUA') 'RID-500 recovery did not immediately read back each policy in safe order'
  Assert-True (@($script:MockUacWrites | Where-Object { $_.Value -ne 1 -or $_.PropertyType -ne 'DWord' -or -not $_.Force }).Count -eq 0) 'RID-500 recovery did not write both policies as forced DWORD 1'

  # 写入报错和写后读回未生效都必须失败，由启动守卫统一退出。
  Reset-MockUac 0 0
  $script:MockUacWriteFailureName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart } 'ordinary EnableLUA write failure was ignored'
  Reset-MockUac 0 0
  $script:MockUacHoldWriteName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart } 'ordinary EnableLUA readback failure was ignored'
  Reset-MockUac 0 0
  $script:MockUacWriteFailureName = 'FilterAdministratorToken'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 FilterAdministratorToken write failure was ignored'
  Assert-True (($script:MockUacWrites.Count -eq 1) -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 approval-mode write failure still enabled UAC'
  Reset-MockUac 0 0
  $script:MockUacHoldWriteName = 'FilterAdministratorToken'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 FilterAdministratorToken readback failure was ignored'
  Assert-True (($script:MockUacWrites.Count -eq 1) -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 approval-mode readback failure still enabled UAC'
  Reset-MockUac 0 0
  $script:MockUacWriteFailureName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 EnableLUA write failure was ignored after approval-mode success'
  Assert-True ($script:MockUacValues.FilterAdministratorToken -eq 1 -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 EnableLUA write failure corrupted the safe partial state'
  Reset-MockUac 0 0
  $script:MockUacHoldWriteName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 EnableLUA readback failure was ignored after approval-mode success'
  Assert-True ($script:MockUacValues.FilterAdministratorToken -eq 1 -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 EnableLUA readback failure corrupted the safe partial state'

  Remove-Variable MockUacValues,MockUacReadFailureName,MockUacWriteFailureName,MockUacHoldWriteName,MockUacWrites,MockUacReads -Scope Script -ErrorAction SilentlyContinue
} $getUacFunctionText $getFilterFunctionText $sidFunctionText $enableUacFunctionText

$localNoBackupFunctionText = $localNoBackupFunction.Extent.Text
& {
  param([string]$FunctionText)

  function Get-MockHealthyCheck { [pscustomobject]@{ Ok = $true; Text = 'healthy' } }
  function Get-MockAttentionCheck { [pscustomobject]@{ Ok = $false; Text = 'attention' } }
  function Invoke-EngineHostUserAction([string]$Action) {
    if ($Action -ne 'ClearShaderCache') { throw "unexpected broker action: $Action" }
    '{"Cleared":["mock cache cleared"],"Failed":[]}'
  }

  Invoke-Expression $FunctionText
  $items = @(
    [pscustomobject]@{ Id = 'check-ok'; Name = 'check ok'; Kind = 'check'; Check = 'Get-MockHealthyCheck' }
    [pscustomobject]@{ Id = 'check-attention'; Name = 'check attention'; Kind = 'check'; Check = 'Get-MockAttentionCheck' }
    [pscustomobject]@{ Id = 'cache'; Name = 'cache'; Kind = 'cache'; Check = $null }
  )
  $results = @(Invoke-LocalNoBackupItems $items)
  Assert-True ($results.Count -eq 3) 'local no-backup runner did not return every result under Windows PowerShell 5.1'
  Assert-True (($results.Id -join ',') -eq 'check-ok,check-attention,cache') 'local no-backup results changed order or identity'
  Assert-True ($results[0].Ok -and -not $results[0].Attention) 'healthy local check result was misclassified'
  Assert-True (-not $results[1].Ok -and $results[1].Attention) 'attention local check result was misclassified'
  Assert-True ($results[2].Ok -and -not $results[2].Skipped) 'local cache result was misclassified'

  $noItems = @()
  Assert-True (@(Invoke-LocalNoBackupItems $noItems).Count -eq 0) 'empty local no-backup batch did not return an empty result set'
} $localNoBackupFunctionText

$validatedCandidateFunctionText = $validatedCandidateFunction.Extent.Text
& {
  param([string]$FunctionText)

  $previousTargetExe = $script:TargetExe
  try {
    $script:TargetExe = 'C:\Games\DeltaForceClient-Win64-Shipping.exe'
    function Get-TuningCandidate([string]$GroupId) {
      [pscustomobject]@{
        GroupId = $GroupId; Source = 'rules'; RiskLevel = 'low'; RequiresReboot = $false
        ItemIds = @('candidate-a', 'candidate-b')
      }
    }
    function Get-OptItems([string]$GamePath) {
      @(
        [pscustomobject]@{ Id = 'candidate-a'; Tier = 'safe'; Reboot = $false; Kind = 'multi'
          RequiresGame = $false; Ops = @([pscustomobject]@{ Kind = 'reg' }) }
        [pscustomobject]@{ Id = 'candidate-b'; Tier = 'safe'; Reboot = $false; Kind = 'multi'
          RequiresGame = $false; Ops = @([pscustomobject]@{ Kind = 'kvstr' }) }
      )
    }
    function Test-AllowedGameExecutable([string]$GamePath) { $true }

    Invoke-Expression $FunctionText
    $runtime = Get-ValidatedTuningCandidateRuntime 'G1'
    Assert-True (@($runtime.Items).Count -eq 2) 'validated tuning candidate lost Generic.List items under Windows PowerShell 5.1'
    Assert-True (($runtime.Items.Id -join ',') -eq 'candidate-a,candidate-b') 'validated tuning candidate changed item order or identity'
  } finally {
    $script:TargetExe = $previousTargetExe
  }
} $validatedCandidateFunctionText

Write-Host 'PASS: GUI UAC recovery and WinPS5.1 Generic.List result paths are regression covered'
