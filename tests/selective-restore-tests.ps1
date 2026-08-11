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

  Initialize-ProtectedStore
  # power/sched 等项目没有 Ops。PowerShell 5.1 的 @($null) 仍会迭代一次，定义哈希必须
  # 显式跳过 null；否则实际执行 power-ultimate 会在备份阶段报空值方法异常。
  $powerRecord = New-BackupItemRecord @{
    Id='power-ultimate';Tier='safe';Name='电源计划切换到「卓越性能」';Admin=$true
    Default=$true;Kind='power';Reboot=$true
  }
  Assert-True ($powerRecord.ItemId -eq 'power-ultimate' -and $powerRecord.DefinitionHash -match '^[0-9a-f]{64}$') `
    '没有 Ops 的电源项目必须能够生成 schema v3 备份项目记录'
  $selectiveIds = @(Get-SelectiveRestoreItemIds)
  Assert-True ($selectiveIds.Count -eq 8 -and
    @('game-mode','dvr-off','prio-separation','net-throttling-off','sys-responsiveness','mmcss-games','fso-off','gpu-pref' |
      Where-Object { $selectiveIds -notcontains $_ }).Count -eq 0) '第一版按项目复原白名单必须固定为八个低风险项目'
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

  $prioSpec = [pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl';Name='Win32PrioritySeparation';Existed=$true;OldValue=38;OldKind='DWord';AppliedValue=40;AppliedKind='DWord'}
  $netSpec = [pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile';Name='NetworkThrottlingIndex';Existed=$true;OldValue=10;OldKind='DWord';AppliedValue=-1;AppliedKind='DWord'}
  foreach ($spec in @($prioSpec,$netSpec)) { $script:RegState[(Get-TestRegKey $spec.Path $spec.Name)] = [pscustomobject]@{Value=$spec.AppliedValue;Kind='DWord'} }
  [void](New-TestV3RegBackup 'prio-separation' '前台程序调度权重' @($prioSpec))
  [void](New-TestV3RegBackup 'net-throttling-off' '解除多媒体网络限流' @($netSpec))
  $multiResult = Invoke-RestoreSelected @('prio-separation','net-throttling-off')
  Assert-True ($multiResult.RestoredItems -eq 2 -and $multiResult.RestoredOps -eq 2 -and $multiResult.Failed.Count -eq 0 -and
    (Get-RegValue $prioSpec.Path $prioSpec.Name) -eq 38 -and (Get-RegValue $netSpec.Path $netSpec.Name) -eq 10) `
    '多选复原必须在一个操作中独立恢复全部勾选项目'

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
