$ErrorActionPreference = 'Stop'
$engine = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\delta-booster.ps1'
. $engine

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT: $Message" }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ("dfb-selective-restore-test-" + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
  $script:ProgramDataRoot = Join-Path $temp 'programdata'
  $script:BackupDir = Join-Path $script:ProgramDataRoot 'backup'
  $script:IpcDir = Join-Path $script:ProgramDataRoot 'ipc'
  $script:BackupKeyFile = Join-Path $script:ProgramDataRoot 'backup.key'
  $script:LegacyBackupDir = Join-Path $temp 'legacy\backup'
  $script:LegacyRootsFile = Join-Path $script:ProgramDataRoot 'legacy-roots.json'
  $script:TargetUserSid = 'S-1-5-21-1000000000-1000000001-1000000002-1001'
  $script:TargetLocalAppData = $temp
  function Test-Admin { $true }
  function New-ProtectedDirectory([string]$Path, [bool]$UsersRead) {
    if (-not (Test-Path -LiteralPath $Path)) { [void][IO.Directory]::CreateDirectory($Path) }
  }
  function Set-ProtectedFileAcl([string]$Path) {}
  function Test-ProtectedFileAcl([string]$Path) { $true }

  $script:RegState = @{}
  $script:FailRestoreKey = ''
  $script:FailRestoreValue = $null
  function Get-TestRegKey([string]$Path, [string]$Name) { ($Path + '|' + $Name).ToLowerInvariant() }
  function Get-RegValueKind([string]$Path, [string]$Name) {
    $key = Get-TestRegKey $Path $Name
    if ($script:RegState.ContainsKey($key)) { return $script:RegState[$key].Kind }
    $null
  }
  function Get-RegValue([string]$Path, [string]$Name) {
    $key = Get-TestRegKey $Path $Name
    if ($script:RegState.ContainsKey($key)) { return $script:RegState[$key].Value }
    $null
  }
  function Set-RegValue([string]$Path, [string]$Name, $Value, [string]$Kind) {
    $key = Get-TestRegKey $Path $Name
    if ($key -eq $script:FailRestoreKey -and "$Value" -ceq "$script:FailRestoreValue") { throw 'fixture write failure' }
    $script:RegState[$key] = [pscustomobject]@{ Value=$Value;Kind=$Kind }
  }
  function Remove-RegValue([string]$Path, [string]$Name) {
    [void]$script:RegState.Remove((Get-TestRegKey $Path $Name))
  }

  function New-TestV3RegBackup([string]$ItemId, [string]$DisplayName, [object[]]$Specs,
                               [bool]$RebootRequired = $false, [DateTime]$When = (Get-Date)) {
    $doc = New-BackupDocument $When
    $doc.State = 'complete'
    $item = [pscustomobject][ordered]@{
      ItemId=$ItemId;RestoreGroupId=$ItemId;DisplayName=$DisplayName;DefinitionHash=('a' * 64)
      RebootRequired=$RebootRequired;OpIds=@()
    }
    $ops = @(); $index = 0
    foreach ($spec in $Specs) {
      $opId = [guid]::NewGuid().ToString('D')
      $item.OpIds = @($item.OpIds) + @($opId)
      $ops += [pscustomobject][ordered]@{
        Id=$opId;Status='applied';ApplyId=$doc.ApplyId;ItemId=$ItemId;RestoreGroupId=$ItemId;OpIndex=$index;Kind='reg'
        Path=$spec.Path;Name=$spec.Name;Existed=[bool]$spec.Existed;OldValue=$spec.OldValue;OldKind="$($spec.OldKind)"
        AppliedValue=$spec.AppliedValue;AppliedKind="$($spec.AppliedKind)"
      }
      $index++
    }
    $doc.Items = @($item); $doc.Ops = $ops
    $path = Join-Path $script:BackupDir ("backup-$($doc.BackupId).json")
    Write-BackupDocumentAtomic $path $doc
    $path
  }

  function New-TestV3PowerSettingBackup([string]$SchemeGuid, [string]$Setting,
                                        [string]$Label = 'fixture power setting') {
    $doc = New-BackupDocument ([DateTime]::UtcNow)
    $doc.State = 'complete'
    $opId = [guid]::NewGuid().ToString('D')
    $doc.Items = @([pscustomobject][ordered]@{
      ItemId='power-tuning';RestoreGroupId='power-tuning';DisplayName='电源计划隐藏项深度调优'
      DefinitionHash=('c' * 64);RebootRequired=$true;OpIds=@($opId)
    })
    $doc.Ops = @([pscustomobject][ordered]@{
      Id=$opId;Status='applied';ApplyId=$doc.ApplyId;ItemId='power-tuning';RestoreGroupId='power-tuning'
      OpIndex=0;Kind='pcfg';Sub=$script:SubProc;Setting=$Setting;Label=$Label
      Existed=$false;OldValue=$null;SchemeGuid=$SchemeGuid
    })
    $path = Join-Path $script:BackupDir ("backup-$($doc.BackupId).json")
    Write-BackupDocumentAtomic $path $doc
    $path
  }

  Initialize-ProtectedStore
  # power/sched 等项目没有 Ops。PowerShell 5.1 的 @($null) 仍会迭代一次，定义哈希必须
  # 显式跳过 null；否则实际执行 power-ultimate 会在备份阶段报空值方法异常。
  $powerRecord = New-BackupItemRecord @{
    Id='power-ultimate';Tier='safe';Name='电源计划切换到「卓越性能」';Admin=$true
    Default=$true;Kind='power';Reboot=$true
  }
  Assert-True ($powerRecord.ItemId -eq 'power-ultimate' -and $powerRecord.DefinitionHash -match '^[0-9a-f]{64}$') `
    '没有 Ops 的电源项目必须能够生成 schema v3 备份项目记录'

  Assert-True ((Test-ManagedPowerSetting $script:SubProc '4d2b0152-7d5c-498b-88e2-34345392a2c5') -and
    -not (Test-ManagedPowerSetting $script:SubProc 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee')) `
    'SYSTEM 电源还原目标必须限制在产品实际管理的隐藏项白名单'

  $originalGetPowerSchemesForOwnership = ${function:Get-PowerSchemes}
  $originalInvokeSchemeActivateForOwnership = ${function:Invoke-SchemeActivate}
  try {
    $script:OwnershipActiveGuid = '11111111-2222-4333-8444-555555555555'
    $script:OwnershipToolGuid = '66666666-7777-4888-8999-aaaaaaaaaaaa'
    $script:OwnershipActivateCalls = New-Object System.Collections.Generic.List[string]
    function Get-PowerSchemes {
      @(
        [pscustomobject]@{Guid=$script:OwnershipActiveGuid;Name='Ultimate Performance';Active=($script:OwnershipActiveGuid -eq $script:OwnershipCurrentGuid)},
        [pscustomobject]@{Guid=$script:OwnershipToolGuid;Name=$script:ToolSchemeName;Active=($script:OwnershipToolGuid -eq $script:OwnershipCurrentGuid)}
      )
    }
    function Invoke-SchemeActivate([string]$SchemeGuid) {
      [void]$script:OwnershipActivateCalls.Add($SchemeGuid)
      $script:OwnershipCurrentGuid = $SchemeGuid
      $true
    }
    $script:OwnershipCurrentGuid = $script:OwnershipActiveGuid
    $foreignState = Get-ItemState @{Kind='power'}
    $isolated = Enable-UltimateScheme
    $toolState = Get-ItemState @{Kind='power'}
    Assert-True (-not $foreignState.Optimized -and $isolated.Guid -eq $script:OwnershipToolGuid -and
      (@($script:OwnershipActivateCalls.ToArray()) -join ',') -eq $script:OwnershipToolGuid -and $toolState.Optimized) `
      '用户/OEM Ultimate 方案必须被视为待隔离，执行时只可复用工具专属方案'
  } finally {
    Set-Item -LiteralPath Function:\Get-PowerSchemes -Value $originalGetPowerSchemesForOwnership
    Set-Item -LiteralPath Function:\Invoke-SchemeActivate -Value $originalInvokeSchemeActivateForOwnership
  }

  $originalGetOptItemsForIsolation = ${function:Get-OptItems}
  $originalFindGamePathForIsolation = ${function:Find-GamePath}
  $originalGetActiveSchemeForIsolation = ${function:Get-ActiveScheme}
  try {
    function Find-GamePath { $null }
    function Get-ActiveScheme { [pscustomobject]@{Guid='11111111-2222-4333-8444-555555555555';Name='Ultimate Performance';Active=$true} }
    function Get-OptItems([string]$GamePath,[string]$GpuSpoofModel) {
      @(@{Id='power-tuning';Tier='safe';Name='电源计划隐藏项深度调优';Admin=$true;Default=$true;Kind='multi';Reboot=$true
          Ops=@(@{Kind='pcfg';Sub=$script:SubProc;Setting='4d2b0152-7d5c-498b-88e2-34345392a2c5';Value=5000;Label='fixture'})})
    }
    $backupCountBeforeIsolationReject = @(Get-ChildItem -LiteralPath $script:BackupDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue).Count
    $isolatedApplyRejected = $false
    try { [void](Invoke-Apply @('power-tuning') $null $false $null $null) }
    catch { $isolatedApplyRejected = $_.Exception.Message -like '*需要同时执行*工具专属方案*' }
    $backupCountAfterIsolationReject = @(Get-ChildItem -LiteralPath $script:BackupDir -Filter 'backup-*.json' -ErrorAction SilentlyContinue).Count
    Assert-True ($isolatedApplyRejected -and $backupCountAfterIsolationReject -eq $backupCountBeforeIsolationReject) `
      '手动只选 power-tuning 时必须在备份和系统写入前拒绝污染非工具电源方案'
  } finally {
    Set-Item -LiteralPath Function:\Get-OptItems -Value $originalGetOptItemsForIsolation
    Set-Item -LiteralPath Function:\Find-GamePath -Value $originalFindGamePathForIsolation
    Set-Item -LiteralPath Function:\Get-ActiveScheme -Value $originalGetActiveSchemeForIsolation
  }

  $restoreOrder = @(Get-RestoreExecutionOps @(
    [pscustomobject]@{Kind='reg';Name='late-reg'}, [pscustomobject]@{Kind='pcfg';Name='power-setting'},
    [pscustomobject]@{Kind='power';Name='active-plan'}, [pscustomobject]@{Kind='sched';Name='plan-lock'}
  ))
  Assert-True ((@($restoreOrder | ForEach-Object Kind) -join ',') -eq 'sched,power,reg,pcfg') `
    '全部还原必须先删除电源锁定任务并回切活动方案，再处理电源隐藏项'

  # 对所有非注册表操作类型做一次端到端完整还原。纯注册表路径在下方逐项目测试；这里
  # 确认电源方案、计划任务、电源隐藏项、MMAgent、休眠与 BCD 都实际进入对应还原器，
  # 而不只是“备份 schema 里有字段”。
  $allKindDoc = New-BackupDocument ([DateTime]::UtcNow)
  $allKindDoc.State = 'complete'
  $allKindSpecs = @(
    [pscustomobject]@{ ItemId='power-ultimate';Name='电源计划';Reboot=$true;Kind='power';Fields=[ordered]@{
      Old='11111111-2222-4333-8444-555555555555';ToolCreated=$false;NewGuid='66666666-7777-4888-8999-aaaaaaaaaaaa' } },
    [pscustomobject]@{ ItemId='powerplan-lock';Name='电源锁定任务';Reboot=$false;Kind='sched';Fields=[ordered]@{
      TaskName=$script:LockTask } },
    [pscustomobject]@{ ItemId='power-tuning';Name='电源隐藏项';Reboot=$true;Kind='pcfg';Fields=[ordered]@{
      Sub=$script:SubProc;Setting='4d2b0152-7d5c-498b-88e2-34345392a2c5';Label='处理器性能时间检查间隔'
      Existed=$true;OldValue=15;SchemeGuid='66666666-7777-4888-8999-aaaaaaaaaaaa' } },
    [pscustomobject]@{ ItemId='mem-compress-off';Name='内存压缩';Reboot=$true;Kind='mmagent';Fields=[ordered]@{
      Feature='mc';OldEnabled=$true } },
    [pscustomobject]@{ ItemId='hibernate-off';Name='休眠';Reboot=$false;Kind='hib';Fields=[ordered]@{
      OldEnabled=$true } },
    [pscustomobject]@{ ItemId='dyntick-off';Name='动态计时器';Reboot=$true;Kind='bcd';Fields=[ordered]@{
      Name='disabledynamictick';OldValue='absent' } }
  )
  $allKindItems = @(); $allKindOps = @(); $allKindIndex = 0
  foreach ($spec in $allKindSpecs) {
    $opId = [guid]::NewGuid().ToString('D')
    $opFields = [ordered]@{
      Id=$opId;Status='applied';ApplyId=$allKindDoc.ApplyId;ItemId=$spec.ItemId
      RestoreGroupId=$spec.ItemId;OpIndex=0;Kind=$spec.Kind
    }
    foreach ($key in $spec.Fields.Keys) { $opFields[$key] = $spec.Fields[$key] }
    $allKindOps += [pscustomobject]$opFields
    $allKindItems += [pscustomobject][ordered]@{
      ItemId=$spec.ItemId;RestoreGroupId=$spec.ItemId;DisplayName=$spec.Name
      DefinitionHash=(('{0:x}' -f ($allKindIndex + 1)) * 64).Substring(0,64)
      RebootRequired=[bool]$spec.Reboot;OpIds=@($opId)
    }
    $allKindIndex++
  }
  $allKindDoc.Items = $allKindItems; $allKindDoc.Ops = $allKindOps
  $allKindPath = Join-Path $script:BackupDir ("backup-$($allKindDoc.BackupId).json")
  Write-BackupDocumentAtomic $allKindPath $allKindDoc

  $originalInvokeRestorePowerSchemeForKinds = ${function:Invoke-RestorePowerScheme}
  $originalGetTaskXmlForKinds = ${function:Get-TaskXml}
  $originalTestBoosterLockTaskForKinds = ${function:Test-BoosterLockTask}
  $originalSetPowerSettingAcForKinds = ${function:Set-PowerSettingAc}
  $originalGetMMAgentStateForKinds = ${function:Get-MMAgentState}
  $originalSetMMAgentStateForKinds = ${function:Set-MMAgentState}
  $originalGetHibernateStateForKinds = ${function:Get-HibernateState}
  $originalSetHibernateEnabledForKinds = ${function:Set-HibernateEnabled}
  $originalGetBcdValueForKinds = ${function:Get-BcdValue}
  $originalRemoveBcdEntryValueForKinds = ${function:Remove-BcdEntryValue}
  $originalSchTasksExeForKinds = $script:SchTasksExe
  try {
    $script:AllKindPower = ''; $script:AllKindTaskQueries = 0; $script:AllKindPowerSetting = $null
    $script:AllKindMMAgent = $false; $script:AllKindHibernate = $false; $script:AllKindBcd = 'yes'
    function Invoke-RestorePowerScheme([string]$OldGuid) {
      $script:AllKindPower = $OldGuid
      [pscustomobject]@{Exact=$true;Guid=$OldGuid;Message='fixture restored'}
    }
    function Get-TaskXml([string]$TaskName) {
      $script:AllKindTaskQueries++
      if ($script:AllKindTaskQueries -eq 1) { return [xml]'<Task />' }
      $null
    }
    function Test-BoosterLockTask([string]$TaskName) { $true }
    function Set-PowerSettingAc([string]$Sub,[string]$Setting,[int]$Value,[string]$SchemeGuid) {
      $script:AllKindPowerSetting = "$Sub|$Setting|$Value|$SchemeGuid"
    }
    function Get-MMAgentState([string]$Feature) { [bool]$script:AllKindMMAgent }
    function Set-MMAgentState([string]$Feature,[bool]$Enabled) { $script:AllKindMMAgent = $Enabled }
    function Get-HibernateState { [bool]$script:AllKindHibernate }
    function Set-HibernateEnabled([bool]$On) { $script:AllKindHibernate = $On }
    function Get-BcdValue([string]$Name) { $script:AllKindBcd }
    function Remove-BcdEntryValue([string]$Name) { $script:AllKindBcd = 'absent' }
    $taskStub = Join-Path $temp 'schtasks-fixture.cmd'
    [IO.File]::WriteAllText($taskStub, "@echo off`r`nexit /b 0`r`n", [Text.Encoding]::ASCII)
    $script:SchTasksExe = $taskStub

    $allKindRestore = Invoke-Restore $allKindPath
    Assert-True ($allKindRestore.Failed.Count -eq 0 -and $allKindRestore.RestoredOps -eq 6 -and
      $script:AllKindPower -eq '11111111-2222-4333-8444-555555555555' -and
      $script:AllKindTaskQueries -eq 2 -and
      $script:AllKindPowerSetting -like "*$($script:SubProc)*|15|66666666-7777-4888-8999-aaaaaaaaaaaa" -and
      $script:AllKindMMAgent -and $script:AllKindHibernate -and $script:AllKindBcd -eq 'absent' -and
      (Test-Path -LiteralPath $allKindRestore.Receipt)) `
      '非注册表优化类型没有全部通过真实完整还原分支'
  } finally {
    Set-Item -LiteralPath Function:\Invoke-RestorePowerScheme -Value $originalInvokeRestorePowerSchemeForKinds
    Set-Item -LiteralPath Function:\Get-TaskXml -Value $originalGetTaskXmlForKinds
    Set-Item -LiteralPath Function:\Test-BoosterLockTask -Value $originalTestBoosterLockTaskForKinds
    Set-Item -LiteralPath Function:\Set-PowerSettingAc -Value $originalSetPowerSettingAcForKinds
    Set-Item -LiteralPath Function:\Get-MMAgentState -Value $originalGetMMAgentStateForKinds
    Set-Item -LiteralPath Function:\Set-MMAgentState -Value $originalSetMMAgentStateForKinds
    Set-Item -LiteralPath Function:\Get-HibernateState -Value $originalGetHibernateStateForKinds
    Set-Item -LiteralPath Function:\Set-HibernateEnabled -Value $originalSetHibernateEnabledForKinds
    Set-Item -LiteralPath Function:\Get-BcdValue -Value $originalGetBcdValueForKinds
    Set-Item -LiteralPath Function:\Remove-BcdEntryValue -Value $originalRemoveBcdEntryValueForKinds
    $script:SchTasksExe = $originalSchTasksExeForKinds
  }

  # 历史版本会把继承值写进用户现有 Ultimate 方案。管理员删除受 ACL 拒绝时必须自动
  # 提升到一次性 SYSTEM 清理；若 SYSTEM 也被策略拦截，则自动切平衡并消费备份。
  $originalRemovePowerOverride = ${function:Remove-PowerSettingAcOverride}
  $originalRemovePowerOverrideSystem = ${function:Remove-PowerSettingAcOverrideAsSystem}
  $originalGetPowerExplicit = ${function:Get-PowerSettingAcExplicit}
  $originalGetActiveSchemeForLegacy = ${function:Get-ActiveScheme}
  $originalGetPowerSchemesForLegacy = ${function:Get-PowerSchemes}
  $originalInvokeSchemeActivateForLegacy = ${function:Invoke-SchemeActivate}
  try {
    $script:LegacyPowerState = @{}
    $script:LegacyPowerSystemCalls = 0
    $script:LegacyPowerSystemFails = $false
    $script:LegacyPowerActiveGuid = ''
    function Get-LegacyPowerKey([string]$SchemeGuid,[string]$Sub,[string]$Setting) { "$SchemeGuid|$Sub|$Setting".ToLowerInvariant() }
    function Get-PowerSettingAcExplicit([string]$SchemeGuid,[string]$Sub,[string]$Setting) {
      $key = Get-LegacyPowerKey $SchemeGuid $Sub $Setting
      if ($script:LegacyPowerState.ContainsKey($key)) { return $script:LegacyPowerState[$key] }
      $null
    }
    function Remove-PowerSettingAcOverride([string]$SchemeGuid,[string]$Sub,[string]$Setting) { throw 'fixture administrator ACL denied' }
    function Remove-PowerSettingAcOverrideAsSystem([string]$SchemeGuid,[string]$Sub,[string]$Setting) {
      $script:LegacyPowerSystemCalls++
      if ($script:LegacyPowerSystemFails) { throw 'fixture SYSTEM task blocked' }
      [void]$script:LegacyPowerState.Remove((Get-LegacyPowerKey $SchemeGuid $Sub $Setting))
    }
    function Get-ActiveScheme {
      if (-not $script:LegacyPowerActiveGuid) { return $null }
      [pscustomobject]@{Guid=$script:LegacyPowerActiveGuid;Name=$(if($script:LegacyPowerActiveGuid -eq $script:BalancedGuid){'平衡'}else{'Ultimate Performance'});Active=$true}
    }
    function Get-PowerSchemes {
      @(
        [pscustomobject]@{Guid=$script:LegacyPowerCustomGuid;Name='Ultimate Performance';Active=($script:LegacyPowerActiveGuid -eq $script:LegacyPowerCustomGuid)},
        [pscustomobject]@{Guid=$script:BalancedGuid;Name='平衡';Active=($script:LegacyPowerActiveGuid -eq $script:BalancedGuid)}
      )
    }
    function Invoke-SchemeActivate([string]$SchemeGuid) {
      if ($SchemeGuid -notin @($script:LegacyPowerCustomGuid,$script:BalancedGuid)) { return $false }
      $script:LegacyPowerActiveGuid = $SchemeGuid
      $true
    }

    $setting = '4d2b0152-7d5c-498b-88e2-34345392a2c5'
    $script:LegacyPowerCustomGuid = '12345678-1234-4234-8234-1234567890ab'
    $script:LegacyPowerActiveGuid = $script:LegacyPowerCustomGuid
    $script:LegacyPowerState[(Get-LegacyPowerKey $script:LegacyPowerCustomGuid $script:SubProc $setting)] = 5000
    $systemRepairPath = New-TestV3PowerSettingBackup $script:LegacyPowerCustomGuid $setting
    $systemRepair = Invoke-Restore $systemRepairPath
    $systemRepairRetry = Invoke-Restore $systemRepairPath
    Assert-True ($systemRepair.Failed.Count -eq 0 -and $systemRepair.RestoredOps -eq 1 -and
      $systemRepair.Skipped.Count -eq 0 -and $script:LegacyPowerSystemCalls -eq 1 -and
      $systemRepair.RebootItemIds -contains 'power-tuning' -and
      $systemRepair.RebootItems -contains '电源计划隐藏项深度调优' -and
      (Test-Path -LiteralPath $systemRepair.Receipt) -and $systemRepairRetry.RestoredOps -eq 0) `
      '管理员 ACL 拒绝时必须经 SYSTEM 精确清理、返回重启项目并保持重复还原幂等'

    $script:LegacyPowerCustomGuid = 'abcdefab-cdef-4abc-8def-abcdefabcdef'
    $script:LegacyPowerActiveGuid = $script:LegacyPowerCustomGuid
    $script:LegacyPowerState[(Get-LegacyPowerKey $script:LegacyPowerCustomGuid $script:SubProc $setting)] = 5000
    $script:LegacyPowerSystemFails = $true
    $fallbackRepairPath = New-TestV3PowerSettingBackup $script:LegacyPowerCustomGuid $setting
    $fallbackRepair = Invoke-Restore $fallbackRepairPath
    Assert-True ($fallbackRepair.Failed.Count -eq 0 -and $fallbackRepair.RestoredOps -eq 0 -and
      $fallbackRepair.Skipped.Count -eq 1 -and $fallbackRepair.Skipped[0] -like '*Windows「平衡」*' -and
      $script:LegacyPowerActiveGuid -eq $script:BalancedGuid -and (Test-Path -LiteralPath $fallbackRepair.Receipt)) `
      'SYSTEM 精确清理受策略拦截时必须自动切平衡并结束还原循环'
  } finally {
    Set-Item -LiteralPath Function:\Remove-PowerSettingAcOverride -Value $originalRemovePowerOverride
    Set-Item -LiteralPath Function:\Remove-PowerSettingAcOverrideAsSystem -Value $originalRemovePowerOverrideSystem
    Set-Item -LiteralPath Function:\Get-PowerSettingAcExplicit -Value $originalGetPowerExplicit
    Set-Item -LiteralPath Function:\Get-ActiveScheme -Value $originalGetActiveSchemeForLegacy
    Set-Item -LiteralPath Function:\Get-PowerSchemes -Value $originalGetPowerSchemesForLegacy
    Set-Item -LiteralPath Function:\Invoke-SchemeActivate -Value $originalInvokeSchemeActivateForLegacy
  }

  $originalGetPowerSchemes = ${function:Get-PowerSchemes}
  $originalInvokeSchemeActivate = ${function:Invoke-SchemeActivate}
  try {
    $script:RestorePowerActivateCalls = New-Object System.Collections.Generic.List[string]
    $missingOriginalGuid = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
    function Get-PowerSchemes {
      @([pscustomobject]@{Guid=$script:BalancedGuid;Name='平衡';Active=$false})
    }
    function Invoke-SchemeActivate([string]$SchemeGuid) {
      [void]$script:RestorePowerActivateCalls.Add($SchemeGuid)
      $script:LastActivateOut = $(if ($SchemeGuid -ieq $script:BalancedGuid) { '' } else { 'The power scheme does not exist.' })
      $SchemeGuid -ieq $script:BalancedGuid
    }
    $powerFallback = Invoke-RestorePowerScheme $missingOriginalGuid
    Assert-True (-not $powerFallback.Exact -and $powerFallback.Guid -ieq $script:BalancedGuid -and
      $powerFallback.Message -like '*已不存在*安全回退*' -and
      (@($script:RestorePowerActivateCalls.ToArray()) -join ',') -eq "$missingOriginalGuid,$script:BalancedGuid") `
      '原电源方案消失时必须明确回退到 Windows 平衡方案，不能继续把工具方案留在活动状态'

    $fallbackDoc = New-BackupDocument ([DateTime]::UtcNow)
    $fallbackDoc.State = 'complete'
    $fallbackOpId = [guid]::NewGuid().ToString('D')
    $fallbackDoc.Items = @([pscustomobject][ordered]@{
      ItemId='power-ultimate';RestoreGroupId='power-ultimate';DisplayName='电源计划切换到「卓越性能」'
      DefinitionHash=('b' * 64);RebootRequired=$true;OpIds=@($fallbackOpId)
    })
    $fallbackDoc.Ops = @([pscustomobject][ordered]@{
      Id=$fallbackOpId;Status='applied';ApplyId=$fallbackDoc.ApplyId;ItemId='power-ultimate';RestoreGroupId='power-ultimate'
      OpIndex=0;Kind='power';Old=$missingOriginalGuid;ToolCreated=$true;NewGuid='bbbbbbbb-cccc-4ddd-8eee-ffffffffffff'
    })
    $fallbackPath = Join-Path $script:BackupDir ("backup-$($fallbackDoc.BackupId).json")
    Write-BackupDocumentAtomic $fallbackPath $fallbackDoc
    $script:RestorePowerActivateCalls.Clear()
    $fallbackRestore = Invoke-Restore $fallbackPath
    $fallbackRetry = Invoke-Restore $fallbackPath
    Assert-True ($fallbackRestore.Failed.Count -eq 0 -and $fallbackRestore.RestoredOps -eq 0 -and
      $fallbackRestore.Skipped.Count -eq 1 -and $fallbackRestore.Skipped[0] -like '*Windows「平衡」*安全回退*' -and
      (Test-Path -LiteralPath $fallbackRestore.Receipt) -and $fallbackRetry.RestoredOps -eq 0 -and
      "$($fallbackRetry.Notes)" -like '*此前已完成还原*') `
      '电源原方案消失后的全量还原必须落消费凭证并幂等结束，不能每次点击都重复复原'
  } finally {
    Set-Item -LiteralPath Function:\Get-PowerSchemes -Value $originalGetPowerSchemes
    Set-Item -LiteralPath Function:\Invoke-SchemeActivate -Value $originalInvokeSchemeActivate
  }
  # 用完整的游戏/GPU fixture 展开所有条件项目，逐项审计当前目录。否则没有游戏路径或
  # 恰好运行在无独显机器上时，fso/gpu/IFEO 等动态 Ops 会为空，测试会漏掉这些写入。
  $auditGamePath = Join-Path $temp 'DeltaForceClient-Win64-Shipping.exe'
  [IO.File]::WriteAllText($auditGamePath, 'fixture')
  $originalGetHardwareInfoForAudit = ${function:Get-HardwareInfo}
  $originalGetGpuClassKeyPathForAudit = ${function:Get-GpuClassKeyPath}
  $originalGetGpuIrqOpsForAudit = ${function:Get-GpuIrqOps}
  $originalTestGpuNameSpoofSupportedForAudit = ${function:Test-GpuNameSpoofSupported}
  $originalGetGpuNameEnumPathForAudit = ${function:Get-GpuNameEnumPath}
  try {
    function Get-HardwareInfo {
      [pscustomobject]@{ RamGB=64;IsLaptop=$false;MainGpuVendor='NVIDIA';MainGpuName='NVIDIA GeForce RTX 3070';Gpus=@() }
    }
    function Get-GpuClassKeyPath { 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000' }
    function Get-GpuIrqOps {
      $base = 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_10DE&DEV_1234\INSTANCE\Device Parameters\Interrupt Management\Affinity Policy'
      @(
        @{ Kind='reg';Path=$base;Name='DevicePolicy';Value=4;Kind2='DWord';Label='中断亲和性策略' },
        @{ Kind='reg';Path=$base;Name='AssignmentSetOverride';Value=[byte[]](0,2);Kind2='Binary';Label='中断亲和性掩码' }
      )
    }
    function Test-GpuNameSpoofSupported { $true }
    function Get-GpuNameEnumPath { 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_10DE&DEV_1234\INSTANCE' }
    $catalogItems = @(Get-OptItems $auditGamePath 'NVIDIA GeForce RTX 4090')
  } finally {
    Set-Item -LiteralPath Function:\Get-HardwareInfo -Value $originalGetHardwareInfoForAudit
    Set-Item -LiteralPath Function:\Get-GpuClassKeyPath -Value $originalGetGpuClassKeyPathForAudit
    Set-Item -LiteralPath Function:\Get-GpuIrqOps -Value $originalGetGpuIrqOpsForAudit
    Set-Item -LiteralPath Function:\Test-GpuNameSpoofSupported -Value $originalTestGpuNameSpoofSupportedForAudit
    Set-Item -LiteralPath Function:\Get-GpuNameEnumPath -Value $originalGetGpuNameEnumPathForAudit
  }

  # 当前所有会写系统的项目，必须使用写前日志支持的操作类型；只读体检和可自动重建的
  # 缓存清理不需要还原。旧页面文件修改及无自动备份的 NPI 导入不得再出现在应用目录。
  $memoryItem = @($catalogItems | Where-Object Id -eq 'mem-compress-off') | Select-Object -First 1
  $cacheItem = @($catalogItems | Where-Object Id -eq 'shader-cache-clean') | Select-Object -First 1
  $mainPreset = @(Get-BuiltinPresets | Where-Object Id -eq 'main') | Select-Object -First 1
  Assert-True (@($catalogItems | Where-Object Id -in @('pagefile-custom','nvidia-profile')).Count -eq 0 -and
    $memoryItem -and -not $memoryItem.Default -and $memoryItem.BulkSelect -eq $false -and
    $cacheItem -and -not $cacheItem.Default -and $cacheItem.BulkSelect -eq $false -and
    $mainPreset.Items -notcontains 'mem-compress-off' -and $mainPreset.Items -notcontains 'pagefile-custom') `
    '高页面文件占用项或无自动备份项仍可能被默认、全选、内置方案或新应用流程带上'

  $restoreKindMap = @{ power='power';sched='sched';reg='reg';pcfg='pcfg';mmagent='mmagent';kvstr='reg';hib='hib';bcd='bcd' }
  $engineTokens = $null; $engineErrors = $null
  $engineAst = [Management.Automation.Language.Parser]::ParseFile($engine,[ref]$engineTokens,[ref]$engineErrors)
  Assert-True ($engineErrors.Count -eq 0) 'engine parse failed during restore coverage audit'
  $fullRestoreFunction = @($engineAst.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Restore'},$true)) | Select-Object -First 1
  $pureRegIds = @()
  foreach ($item in $catalogItems) {
    if ($item.Kind -in @('check','cache')) { continue }
    Assert-True ($item.Kind -ne 'npi') "允许新应用的项目没有自动还原：$($item.Id)"
    $sourceKinds = $(if ($item.Kind -in @('power','sched')) { @($item.Kind) } else { @($item.Ops | ForEach-Object Kind) })
    Assert-True (@($sourceKinds).Count -gt 0) "完整 fixture 下优化项目仍没有可审计操作：$($item.Id)"
    foreach ($sourceKind in $sourceKinds) {
      Assert-True $restoreKindMap.ContainsKey("$sourceKind") "优化项目使用了没有备份映射的操作：$($item.Id)/$sourceKind"
      $backupKind = $restoreKindMap["$sourceKind"]
      Assert-True (@(Get-BackupOpFields $backupKind 3).Count -gt 0) "备份 schema 不支持项目操作：$($item.Id)/$backupKind"
      Assert-True $fullRestoreFunction.Extent.Text.Contains("'$backupKind'") "全量还原缺少项目操作：$($item.Id)/$backupKind"
    }
    if (@($sourceKinds | Where-Object { $restoreKindMap["$_"] -ne 'reg' }).Count -eq 0) { $pureRegIds += $item.Id }
  }

  $selectiveIds = @(Get-SelectiveRestoreItemIds)
  $expectedSelectiveIds = @('hags','game-mode','dvr-off','prio-separation','paging-exec','wer-off','transparency-off',
    'visualfx-perf','mouse-accel-off','mpo-off','net-throttling-off','sys-responsiveness','sysmain-off','wsearch-off',
    'gpu-pstate-lock','gpu-irq-affinity','mmcss-games','windowed-opt-off','pagefile-custom','fso-off','gpu-pref',
    'game-priority','gpu-name-spoof')
  Assert-True ($selectiveIds.Count -eq $expectedSelectiveIds.Count -and
    @($expectedSelectiveIds | Where-Object { $selectiveIds -notcontains $_ }).Count -eq 0) `
    '所有纯注册表项目（含历史虚拟内存）必须开放带冲突保护的按项目精确复原'
  $derivedSelectiveIds = @($pureRegIds + 'pagefile-custom' | Select-Object -Unique)
  Assert-True ($selectiveIds.Count -eq $derivedSelectiveIds.Count -and
    @($derivedSelectiveIds | Where-Object { $selectiveIds -notcontains $_ }).Count -eq 0) `
    '按项目复原白名单与当前全部纯注册表项目不一致'
  $fullOnlyIds = @($catalogItems | Where-Object {
    $_.Kind -notin @('check','cache') -and $pureRegIds -notcontains $_.Id
  } | ForEach-Object Id)
  Assert-True ((@($fullOnlyIds | Sort-Object) -join ',') -eq
    ((@('dyntick-off','hibernate-off','mem-compress-off','power-tuning','power-ultimate','powerplan-lock') | Sort-Object) -join ',')) `
    '非纯注册表项目的完整还原覆盖清单发生未审计变化'
  $dvrSpecs = @(
    [pscustomobject]@{Path='HKCU:\System\GameConfigStore';Name='GameDVR_Enabled';Existed=$true;OldValue=1;OldKind='DWord';AppliedValue=0;AppliedKind='DWord'},
    [pscustomobject]@{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';Name='AppCaptureEnabled';Existed=$true;OldValue=1;OldKind='DWord';AppliedValue=0;AppliedKind='DWord'}
  )
  foreach ($spec in $dvrSpecs) { $script:RegState[(Get-TestRegKey $spec.Path $spec.Name)] = [pscustomobject]@{Value=0;Kind='DWord'} }
  $dvrBackup = New-TestV3RegBackup 'dvr-off' '关闭 Xbox 后台录制（Game DVR）' $dvrSpecs
  $catalog = Get-RestoreItemCatalog
  $dvrRow = @($catalog.Items | Where-Object Id -eq 'dvr-off')
  Assert-True ($catalog.HasActiveChanges -and $dvrRow.Count -eq 1 -and $dvrRow[0].CanRestore -and $dvrRow[0].SettingCount -eq 2) `
    'v3 项目应以可精确复原状态进入目录'
  $dvrResult = Invoke-RestoreSelected @('dvr-off')
  Assert-True ($dvrResult.RestoredItems -eq 1 -and $dvrResult.RestoredOps -eq 2 -and $dvrResult.Failed.Count -eq 0) `
    '单项复原应写回整个项目'
  foreach ($spec in $dvrSpecs) { Assert-True ((Get-RegValue $spec.Path $spec.Name) -eq 1) '单项复原未写回最早原值' }
  Assert-True ((Test-Path -LiteralPath $dvrBackup) -and (Test-Path -LiteralPath $dvrResult.Receipt)) `
    '选择性复原必须保留原备份并写入不可变消费凭证'
  $tamperedReceiptPath = Join-Path $script:BackupDir ("restore-receipt-$([guid]::NewGuid().ToString('D')).json")
  $tamperedReceipt = Get-Content -LiteralPath $dvrResult.Receipt -Raw -Encoding UTF8 | ConvertFrom-Json
  $tamperedReceipt.CreatedUtc = [DateTime]::UtcNow.AddMinutes(1).ToString('o')
  [IO.File]::WriteAllText($tamperedReceiptPath, ($tamperedReceipt | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
  $receiptRejected = $false
  try { [void](Read-ValidatedRestoreReceipt $tamperedReceiptPath) } catch { $receiptRejected = ($_.Exception.Message -like '*完整性校验失败*') }
  Remove-Item -LiteralPath $tamperedReceiptPath -Force
  Assert-True $receiptRejected '被修改的消费凭证必须由 HMAC 校验拒绝'
  Assert-True (@((Get-RestoreItemCatalog).Items | Where-Object Id -eq 'dvr-off').Count -eq 0) `
    '已消费项目不得再次出现在可复原目录'

  # 旧版虚拟内存优化必须能够单独恢复到应用前的系统管理值，并明确返回重启要求。
  $pagefileSpec = [pscustomobject]@{
    Path='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management';Name='PagingFiles';Existed=$true
    OldValue=[string[]]@('?:\pagefile.sys 0 0');OldKind='MultiString'
    AppliedValue=[string[]]@('C:\pagefile.sys 24576 32768');AppliedKind='MultiString'
  }
  $script:RegState[(Get-TestRegKey $pagefileSpec.Path $pagefileSpec.Name)] = [pscustomobject]@{
    Value=$pagefileSpec.AppliedValue;Kind='MultiString'
  }
  [void](New-TestV3RegBackup 'pagefile-custom' '虚拟内存固定为 24–32 GB' @($pagefileSpec) $true)
  $pagefileRow = @((Get-RestoreItemCatalog).Items | Where-Object Id -eq 'pagefile-custom')
  Assert-True ($pagefileRow.Count -eq 1 -and $pagefileRow[0].CanRestore -and $pagefileRow[0].RebootRequired) `
    '历史虚拟内存备份没有进入可单独精确复原目录'
  $pagefileRestore = Invoke-RestoreSelected @('pagefile-custom')
  Assert-True ($pagefileRestore.RestoredItems -eq 1 -and $pagefileRestore.Failed.Count -eq 0 -and
    $pagefileRestore.RebootItemIds -contains 'pagefile-custom' -and
    (Test-ValueEqual (Get-RegValue $pagefileSpec.Path $pagefileSpec.Name) $pagefileSpec.OldValue)) `
    '虚拟内存单项复原没有写回应用前的 MultiString 系统管理值'

  $prioSpec = [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl';Name='Win32PrioritySeparation';Existed=$true;OldValue=38;OldKind='DWord';AppliedValue=40;AppliedKind='DWord'}
  $netSpec = [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile';Name='NetworkThrottlingIndex';Existed=$true;OldValue=10;OldKind='DWord';AppliedValue=-1;AppliedKind='DWord'}
  foreach ($spec in @($prioSpec,$netSpec)) { $script:RegState[(Get-TestRegKey $spec.Path $spec.Name)] = [pscustomobject]@{Value=$spec.AppliedValue;Kind='DWord'} }
  [void](New-TestV3RegBackup 'prio-separation' '前台程序调度权重' @($prioSpec))
  [void](New-TestV3RegBackup 'net-throttling-off' '解除多媒体网络限流' @($netSpec))
  $multiResult = Invoke-RestoreSelected @('prio-separation','net-throttling-off')
  Assert-True ($multiResult.RestoredItems -eq 2 -and $multiResult.RestoredOps -eq 2 -and $multiResult.Failed.Count -eq 0 -and
    (Get-RegValue $prioSpec.Path $prioSpec.Name) -eq 38 -and (Get-RegValue $netSpec.Path $netSpec.Name) -eq 10) `
    '多选复原必须在一个操作中独立恢复全部勾选项目'

  $gpuNameSpec = [pscustomobject]@{
    Path='HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_10DE&DEV_2783\0001';Name='DeviceDesc';Existed=$true
    OldValue='NVIDIA GeForce RTX 4070 SUPER';OldKind='String';AppliedValue='NVIDIA GeForce GTX 1050 Ti';AppliedKind='String'
  }
  $script:RegState[(Get-TestRegKey $gpuNameSpec.Path $gpuNameSpec.Name)] = [pscustomobject]@{Value=$gpuNameSpec.AppliedValue;Kind='String'}
  [void](New-TestV3RegBackup 'gpu-name-spoof' '★ 显卡型号伪装' @($gpuNameSpec))
  $gpuNameRow = @((Get-RestoreItemCatalog).Items | Where-Object Id -eq 'gpu-name-spoof')
  Assert-True ($gpuNameRow.Count -eq 1 -and $gpuNameRow[0].CanRestore -and $gpuNameRow[0].SettingCount -eq 1) `
    '显卡型号伪装必须显示为可单独复原项目'
  $gpuNameResult = Invoke-RestoreSelected @('gpu-name-spoof')
  Assert-True ($gpuNameResult.RestoredItems -eq 1 -and $gpuNameResult.RestoredOps -eq 1 -and
    (Get-RegValue $gpuNameSpec.Path $gpuNameSpec.Name) -eq $gpuNameSpec.OldValue) `
    '显卡型号伪装单独复原没有写回真实型号'

  $sysPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
  $sysOld = [pscustomobject]@{Path=$sysPath;Name='SystemResponsiveness';Existed=$true;OldValue=20;OldKind='DWord';AppliedValue=10;AppliedKind='DWord'}
  $sysNew = [pscustomobject]@{Path=$sysPath;Name='SystemResponsiveness';Existed=$true;OldValue=30;OldKind='DWord';AppliedValue=10;AppliedKind='DWord'}
  $script:RegState[(Get-TestRegKey $sysPath 'SystemResponsiveness')] = [pscustomobject]@{Value=10;Kind='DWord'}
  [void](New-TestV3RegBackup 'sys-responsiveness' '提高系统响应度' @($sysOld) $false ([DateTime]::UtcNow.AddMinutes(-2)))
  [void](New-TestV3RegBackup 'sys-responsiveness' '提高系统响应度' @($sysNew) $false ([DateTime]::UtcNow.AddMinutes(-1)))
  $earliestResult = Invoke-RestoreSelected @('sys-responsiveness')
  Assert-True ($earliestResult.RestoredItems -eq 1 -and (Get-RegValue $sysPath 'SystemResponsiveness') -eq 20) `
    '多次优化同一项目时必须恢复到最早一次真实原值并消费整条活动链'

  $gpuPrefSpec = [pscustomobject]@{Path='HKCU:\Software\Microsoft\DirectX\UserGpuPreferences';Name='C:\Games\DeltaForceClient-Win64-Shipping.exe';Existed=$true;OldValue='GpuPreference=1;';OldKind='String';AppliedValue='GpuPreference=2;';AppliedKind='String'}
  $script:RegState[(Get-TestRegKey $gpuPrefSpec.Path $gpuPrefSpec.Name)] = [pscustomobject]@{Value='GpuPreference=0;';Kind='String'}
  [void](New-TestV3RegBackup 'gpu-pref' '强制游戏使用高性能 GPU' @($gpuPrefSpec))
  $gpuPrefRow = @((Get-RestoreItemCatalog).Items | Where-Object Id -eq 'gpu-pref')
  Assert-True ($gpuPrefRow.Count -eq 1 -and -not $gpuPrefRow[0].CanRestore -and $gpuPrefRow[0].Status -eq 'conflict') `
    '优化后发生变化的项目必须在预检时标记冲突'
  $gpuPrefResult = Invoke-RestoreSelected @('gpu-pref')
  Assert-True ($gpuPrefResult.RestoredItems -eq 0 -and $gpuPrefResult.Failed.Count -eq 1 -and
    (Get-RegValue $gpuPrefSpec.Path $gpuPrefSpec.Name) -eq 'GpuPreference=0;') '冲突项目必须保留后续修改且不写消费凭证'

  $mmcssSpec = [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games';Name='GPU Priority';Existed=$true;OldValue=2;OldKind='DWord';AppliedValue=8;AppliedKind='DWord'}
  $script:RegState[(Get-TestRegKey $mmcssSpec.Path $mmcssSpec.Name)] = [pscustomobject]@{Value=8;Kind='DWord'}
  [void](New-TestV3RegBackup 'mmcss-games' 'MMCSS 游戏任务档位拉满' @($mmcssSpec))
  $originalWriteReceipt = ${function:Write-RestoreReceipt}
  try {
    function Write-RestoreReceipt($Receipt) { throw 'fixture receipt failure' }
    $receiptFailure = Invoke-RestoreSelected @('mmcss-games')
  } finally { Set-Item -LiteralPath Function:\Write-RestoreReceipt -Value $originalWriteReceipt }
  Assert-True ($receiptFailure.RestoredItems -eq 0 -and $receiptFailure.Failed.Count -eq 1 -and
    (Get-RegValue $mmcssSpec.Path $mmcssSpec.Name) -eq 8 -and
    @((Get-RestoreItemCatalog).Items | Where-Object Id -eq 'mmcss-games').Count -eq 1) `
    '消费凭证写入失败时必须撤销已完成项目并保留活动备份'

  $gameModeSpecs = @(
    [pscustomobject]@{Path='HKCU:\Software\Microsoft\GameBar';Name='AutoGameModeEnabled';Existed=$true;OldValue=0;OldKind='DWord';AppliedValue=1;AppliedKind='DWord'},
    [pscustomobject]@{Path='HKCU:\Software\Microsoft\GameBar';Name='AllowAutoGameMode';Existed=$true;OldValue=0;OldKind='DWord';AppliedValue=1;AppliedKind='DWord'}
  )
  foreach ($spec in $gameModeSpecs) { $script:RegState[(Get-TestRegKey $spec.Path $spec.Name)] = [pscustomobject]@{Value=1;Kind='DWord'} }
  [void](New-TestV3RegBackup 'game-mode' '开启 Windows 游戏模式' $gameModeSpecs)
  $script:FailRestoreKey = Get-TestRegKey $gameModeSpecs[1].Path $gameModeSpecs[1].Name
  $script:FailRestoreValue = 0
  $atomicResult = Invoke-RestoreSelected @('game-mode')
  Assert-True ($atomicResult.RestoredItems -eq 0 -and $atomicResult.Failed.Count -eq 1) '项目中途失败必须整项失败'
  foreach ($spec in $gameModeSpecs) { Assert-True ((Get-RegValue $spec.Path $spec.Name) -eq 1) '项目中途失败后必须回滚已写回的子设置' }
  Assert-True (@((Get-RestoreItemCatalog).Items | Where-Object Id -eq 'game-mode').Count -eq 1) '原子失败项目不得被消费'

  # 真实 Apply 路径必须生成可复验的 v3 Items/Ops 归属，而不只是测试手工文档。
  $werPath = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'
  $script:RegState[(Get-TestRegKey $werPath 'Disabled')] = [pscustomobject]@{Value=0;Kind='DWord'}
  function Find-GamePath { $null }
  function Get-OptItems([string]$GamePath, [string]$GpuSpoofModel) {
    @(@{Id='wer-off';Tier='safe';Name='关闭 Windows 错误报告';Admin=$false;Default=$true;Kind='multi';Reboot=$false
        Ops=@(@{Kind='reg';Path=$werPath;Name='Disabled';Value=1;Kind2='DWord'})})
  }
  $applyResult = Invoke-Apply -ItemIds @('wer-off') -GamePath $null -AllowRisky $false -Progress $null -GpuSpoofModel $null
  $applyDoc = (Read-ValidatedBackup $applyResult.Backup).Document
  Assert-True ($applyResult.Backup -and -not $applyResult.BackupError -and $applyResult.ApplyId -eq $applyDoc.ApplyId -and $applyDoc.SchemaVersion -eq 3 -and
    $applyDoc.Items.Count -eq 1 -and $applyDoc.Items[0].ItemId -eq 'wer-off' -and
    $applyDoc.Ops.Count -eq 1 -and $applyDoc.Ops[0].ItemId -eq 'wer-off' -and
    $applyDoc.Ops[0].AppliedValue -eq 1 -and $applyDoc.Ops[0].AppliedKind -eq 'DWord') `
    'Apply 写前日志没有完整生成 schema v3 项目归属与实际写入值'
  $v3FullRestore = Invoke-Restore $applyResult.Backup
  $v3FullRetry = Invoke-Restore $applyResult.Backup
  Assert-True ($v3FullRestore.Failed.Count -eq 0 -and $v3FullRestore.RestoredOps -eq 1 -and
    (Get-RegValue $werPath 'Disabled') -eq 0 -and (Test-Path -LiteralPath $applyResult.Backup) -and
    (Test-Path -LiteralPath $v3FullRestore.Receipt) -and $v3FullRetry.RestoredOps -eq 0 -and
    "$($v3FullRetry.Notes)" -like '*此前已完成还原*') `
    'v3 全量/指定备份还原必须保留原备份、写消费凭证并支持崩溃重试幂等'

  # v2 缺少 ItemId/ApplyId：目录只提示旧备份，全量还原仍保持原契约。
  $v2PathName = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
  $script:RegState[(Get-TestRegKey $v2PathName 'SystemResponsiveness')] = [pscustomobject]@{Value=10;Kind='DWord'}
  $v2 = [pscustomobject][ordered]@{
    SchemaVersion=2;BackupId=[guid]::NewGuid().ToString('D');CreatedUtc=[DateTime]::UtcNow.ToString('o')
    UserSid=$script:TargetUserSid;UserLocalAppData=$script:TargetLocalAppData;State='complete';Ops=@(
      [pscustomobject][ordered]@{Id=[guid]::NewGuid().ToString('D');Status='applied';Kind='reg';Path=$v2PathName;Name='SystemResponsiveness';Existed=$true;OldValue=20;OldKind='DWord'}
    );Integrity=$null
  }
  $v2Path = Join-Path $script:BackupDir ("backup-$($v2.BackupId).json")
  Write-BackupDocumentAtomic $v2Path $v2
  $catalogWithV2 = Get-RestoreItemCatalog
  Assert-True ($catalogWithV2.LegacyBackupCount -eq 1 -and @($catalogWithV2.Items | Where-Object Id -eq 'sys-responsiveness').Count -eq 0) `
    'v2 备份必须只显示旧版完整还原提示，不能猜测项目归属'
  $v2Restore = Invoke-Restore $v2Path
  Assert-True ((Test-Path -LiteralPath ($v2Path + '.restored')) -and $v2Restore.Failed.Count -eq 0 -and
    (Get-RegValue $v2PathName 'SystemResponsiveness') -eq 20) 'v2 备份必须继续支持整份还原'

  Write-Output 'selective-restore-tests: PASS'
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
