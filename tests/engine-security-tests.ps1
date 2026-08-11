$ErrorActionPreference = 'Stop'
$engine = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\delta-booster.ps1'
. $engine

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT: $Message" }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ("dfb-engine-test-" + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
  # 把所有写入导向测试临时目录；ACL API 仍真实执行，但不会触碰产品或系统目录。
  $script:ProgramDataRoot = Join-Path $temp 'programdata'
  $script:BackupDir = Join-Path $script:ProgramDataRoot 'backup'
  $script:IpcDir = Join-Path $script:ProgramDataRoot 'ipc'
  $script:BackupKeyFile = Join-Path $script:ProgramDataRoot 'backup.key'
  $legacyRoot = Join-Path $temp '.DeltaForceBooster.migrated-0123456789abcdef0123456789abcdef'
  $script:LegacyBackupDir = Join-Path $legacyRoot 'backup'
  $script:LegacyRootsFile = Join-Path $script:ProgramDataRoot 'legacy-roots.json'
  function Test-Admin { $true }
  $precreated = Join-Path $temp 'precreated-by-user'
  [void][IO.Directory]::CreateDirectory($precreated)
  $unsafeDirRejected = $false
  try { New-ProtectedDirectory $precreated $false } catch { $unsafeDirRejected = ($_.Exception.Message -like '*权限不安全*') }
  Assert-True $unsafeDirRejected '预先由普通用户创建的 ProgramData 目录必须关闭失败，不得接管后继续'
  $readAce = [pscustomobject]@{ FileSystemRights=[Security.AccessControl.FileSystemRights]'ReadAndExecute, Synchronize' }
  $writeAce = [pscustomobject]@{ FileSystemRights=[Security.AccessControl.FileSystemRights]::FullControl }
  Assert-True (-not (Test-AclRuleAllowsWrite $readAce)) '只读 ACE 不得被误判为可写'
  Assert-True (Test-AclRuleAllowsWrite $writeAce) 'FullControl ACE 必须被判定为可写'
  function New-ProtectedDirectory([string]$Path, [bool]$UsersRead) {
    if (-not (Test-Path -LiteralPath $Path)) { [void][IO.Directory]::CreateDirectory($Path) }
  }
  function Set-ProtectedFileAcl([string]$Path) {}
  function Test-ProtectedFileAcl([string]$Path) { $true }

  $currentSid = 'S-1-5-21-1000000000-1000000001-1000000002-1001'
  $script:TargetUserSid = $currentSid
  $script:TargetLocalAppData = $temp
  $script:UseExplicitUserHive = $true
  $regBase, $regSub = Split-RegPath 'HKCU:\Software\DeltaForceBooster-Test'
  Assert-True ($regBase.Name -eq 'HKEY_USERS' -and $regSub -eq "$currentSid\Software\DeltaForceBooster-Test") 'HKCU 必须映射到显式目标用户 HKEY_USERS\SID'
  $badContext = $false
  try { Set-TargetUserContext $currentSid $null } catch { $badContext = $true }
  Assert-True $badContext 'UserSid/UserLocalAppData 必须成对传入'
  Assert-True ($env:PSModulePath -notmatch '(?i)\\Users\\[^\\]+\\Documents\\WindowsPowerShell\\Modules') '提权引擎必须从 PSModulePath 移除用户可写模块目录'

  Initialize-ProtectedStore
  $doc = New-BackupDocument (Get-Date)
  $doc.State = 'complete'
  $path = Join-Path $script:BackupDir ("backup-$($doc.BackupId).json")
  Write-BackupDocumentAtomic $path $doc
  $read = Read-ValidatedBackup $path
  Assert-True ($read.Document.BackupId -eq $doc.BackupId -and $read.Document.SchemaVersion -eq 3 -and
    $read.Document.ApplyId -eq $doc.ApplyId -and $read.Document.AppVersion -eq $script:AppVersion) `
    'schema v3 签名备份应可读并记录与 GUI 一致的 AppVersion/ApplyId'

  # v2 没有项目归属，继续使用整份 .restored 归档，保证旧版显式备份回滚幂等。
  $idempotentDoc = [pscustomobject][ordered]@{
    SchemaVersion=2;BackupId=[guid]::NewGuid().ToString('D');CreatedUtc=[DateTime]::UtcNow.ToString('o')
    UserSid=$script:TargetUserSid;UserLocalAppData=$script:TargetLocalAppData;State='complete';Ops=@();Integrity=$null
  }
  $idempotentPath = Join-Path $script:BackupDir ("backup-$($idempotentDoc.BackupId).json")
  Write-BackupDocumentAtomic $idempotentPath $idempotentDoc
  $firstRestore = Invoke-Restore $idempotentPath
  $secondRestore = Invoke-Restore $idempotentPath
  Assert-True ((-not (Test-Path -LiteralPath $idempotentPath)) -and
    (Test-Path -LiteralPath ($idempotentPath + '.restored')) -and $firstRestore.Failed.Count -eq 0) 'v2 显式备份还原成功后必须写入 consumed 标记'
  Assert-True ($secondRestore.RestoredOps -eq 0 -and $secondRestore.Failed.Count -eq 0 -and
    "$($secondRestore.Notes)" -like '*此前已完成还原*') '显式备份在 GUI 落盘前崩溃后重试必须幂等成功'

  $entra = New-BackupDocument (Get-Date)
  $entra.UserSid = 'S-1-12-1-1-2-3-4'; $entra.State = 'complete'
  $entraPath = Join-Path $script:BackupDir ("backup-$($entra.BackupId).json")
  Write-BackupDocumentAtomic $entraPath $entra
  Assert-True ((Read-ValidatedBackup $entraPath).Document.UserSid -eq $entra.UserSid) 'Entra/Azure AD 用户 SID 必须被备份 schema 接受'

  $tampered = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  $tampered.State = 'pending'
  [IO.File]::WriteAllText($path, ($tampered | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
  $rejected = $false
  try { [void](Read-ValidatedBackup $path) } catch { $rejected = ($_.Exception.Message -like '*完整性校验失败*') }
  Assert-True $rejected '篡改后的 HMAC 备份必须拒绝'

  $badLegacy = [pscustomobject]@{ Time = (Get-Date).ToString('s'); Ops = @([pscustomobject]@{
    Kind = 'file'; Path = (Join-Path $temp 'outside.txt'); OrigB64 = [Convert]::ToBase64String([byte[]](1,2,3))
  }) }
  $rejected = $false
  try { Assert-BackupDocument $badLegacy $false } catch { $rejected = ($_.Exception.Message -match '停用|白名单') }
  Assert-True $rejected '旧备份的用户文件操作必须整类拒绝'

  $badRegValue = [pscustomobject]@{ Time = (Get-Date).ToString('s'); Ops = @([pscustomobject]@{
    Kind='reg'; Path='HKLM:\SYSTEM\CurrentControlSet\Services\SysMain'; Name='Start'
    Existed=$true; OldValue=99; OldKind='DWord'
  }) }
  $rejected = $false
  try { Assert-BackupDocument $badRegValue $false } catch { $rejected = ($_.Exception.Message -like '*启动类型*') }
  Assert-True $rejected '未签名旧备份的旧值也必须经过目标特定值域校验'

  $unknown = [pscustomobject]@{ Time = (Get-Date).ToString('s'); Ops = @(); Extra = 'x' }
  $rejected = $false
  try { Assert-BackupDocument $unknown $false } catch { $rejected = ($_.Exception.Message -like '*未知字段*') }
  Assert-True $rejected '未知 schema 字段必须拒绝'

  [void][IO.Directory]::CreateDirectory($script:LegacyBackupDir)
  [IO.File]::WriteAllText($script:LegacyRootsFile, (([ordered]@{ SchemaVersion=1; Roots=@($legacyRoot) }) | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
  $legacyPath = Join-Path $script:LegacyBackupDir 'backup-20260810-000000.json'
  $safeLegacy = [pscustomobject]@{ Time = '2026-08-10T00:00:00'; Ops = @([pscustomobject]@{
    Kind='reg'; Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Name='SystemResponsiveness'; Existed=$true; OldValue=20; OldKind='DWord'
  }) }
  [IO.File]::WriteAllText($legacyPath, ($safeLegacy | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
  $migrated = Read-ValidatedBackup $legacyPath
  Assert-True ($migrated.Document.SchemaVersion -eq 2 -and $migrated.Document.Ops[0].Status -eq 'applied') '安全旧备份应迁移为签名 schema v2'
  Assert-True ((Test-Path -LiteralPath $migrated.Path) -and (Test-Path -LiteralPath $legacyPath)) '旧备份迁移应保留受保护副本，提权进程不得写用户可写旧源'
  Assert-True ((Read-ValidatedBackup $migrated.Path).Document.Ops[0].Kind -eq 'reg') '迁移后带操作记录的 HMAC 必须可复验'
  $sameMigration = Read-ValidatedBackup $legacyPath
  Assert-True ($sameMigration.Path -eq $migrated.Path) '同一旧备份重试必须复用确定性受保护副本'
  Rename-Item -LiteralPath $migrated.Path -NewName ((Split-Path -Leaf $migrated.Path) + '.restored')
  Assert-True ((Read-ValidatedBackup $legacyPath).Consumed) '已还原的旧备份必须由受保护标记识别，不得再次消费'

  $older = [pscustomobject]@{ Path='backup-ffffffff.json'; Document=[pscustomobject]@{ CreatedUtc='2026-08-01T00:00:00Z' } }
  $newer = [pscustomobject]@{ Path='backup-00000000.json'; Document=[pscustomobject]@{ CreatedUtc='2026-08-02T00:00:00Z' } }
  $sorted = @(Sort-BackupRecordsNewestFirst @($older,$newer))
  Assert-True ($sorted[0].Path -eq $newer.Path -and $sorted[1].Path -eq $older.Path) 'GUID 文件名不得决定备份合并时间顺序'

  function Get-CpuCoreTopology {
    @([pscustomobject]@{ Class = 1; Mask = [uint64]2 }, [pscustomobject]@{ Class = 1; Mask = [uint64]4 })
  }
  $hw = [pscustomobject]@{
    Threads = 8; MainGpuPnp = 'PCI\VEN_10DE&DEV_MAIN\GPU0'
    Gpus = @([pscustomobject]@{ Vendor='AMD'; Pnp='PCI\VEN_1002&DEV_IGPU\GPU0' },
             [pscustomobject]@{ Vendor='NVIDIA'; Pnp='PCI\VEN_10DE&DEV_MAIN\GPU0' })
  }
  $irq = @(Get-GpuIrqOps $hw)
  Assert-True ($irq.Count -eq 2 -and $irq[0].Path -like '*VEN_10DE&DEV_MAIN*') 'IRQ 必须精确使用 MainGpuPnp'
  $multi = [pscustomobject]@{
    Threads=8; MainGpuPnp='PCI\VEN_10DE&DEV_A\GPU0'; MainGpuPciMatched=$false
    Gpus=@([pscustomobject]@{Vendor='NVIDIA';Pnp='PCI\VEN_10DE&DEV_A\GPU0'},[pscustomobject]@{Vendor='NVIDIA';Pnp='PCI\VEN_10DE&DEV_B\GPU0'})
  }
  Assert-True ($null -eq (Get-GpuIrqOps $multi)) '多 NVIDIA 未按 PCI BDF 匹配时必须禁用 IRQ 写入'
  [void](Get-PciBusLocation 'PCI\NONEXISTENT')
  Assert-True ([bool]('DfbPciLocation' -as [type])) 'PCI BDF 映射 helper 应可加载'

  $mainPreset = Get-BuiltinPresets | Where-Object Id -eq 'main'
  Assert-True ($mainPreset.Items -notcontains 'nvidia-profile') 'NPI 不得进入主推方案'
  Assert-True ($mainPreset.Items -notcontains 'nv-autoopt-off') '用户可写 NVIDIA 配置文件不得进入提权主推方案'
  Assert-True ($mainPreset.Items -contains 'gpu-name-spoof') '主推方案应包含显卡型号伪装，执行仍由 -Risky 契约拦截'
  Assert-True (Test-GpuNameSpoofSupported ([pscustomobject]@{ MainGpuVendor='NVIDIA' })) 'NVIDIA 主显卡应启用显卡型号伪装'
  Assert-True (Test-GpuNameSpoofSupported ([pscustomobject]@{ MainGpuVendor='AMD' })) 'AMD 主显卡应重新启用显卡型号伪装'
  Assert-True (-not (Test-GpuNameSpoofSupported ([pscustomobject]@{ MainGpuVendor='Intel' }))) 'Intel 主显卡必须禁用显卡型号伪装'
  Assert-True (-not (Test-GpuNameSpoofSupported $null)) '显卡未识别时必须禁用显卡型号伪装'
  $spoofModels = @(Get-GpuSpoofModels)
  Assert-True ($spoofModels.Count -eq 5 -and
    $spoofModels[0] -eq 'NVIDIA GeForce GTX 750 Ti' -and
    $spoofModels[1] -eq 'NVIDIA GeForce GTX 1050 Ti' -and
    $spoofModels[2] -eq 'NVIDIA GeForce RTX 2050' -and
    $spoofModels[3] -eq 'NVIDIA GeForce RTX 2060' -and
    $spoofModels[4] -eq 'AMD Radeon RX560') '显卡型号伪装下拉选项不完整或顺序漂移'
  Assert-True ((Test-RecommendedGpuSpoofModel $spoofModels[0]) -and
    (Test-RecommendedGpuSpoofModel $spoofModels[1]) -and
    (-not (Test-RecommendedGpuSpoofModel $spoofModels[2])) -and
    (-not (Test-RecommendedGpuSpoofModel $spoofModels[3])) -and
    (Test-RecommendedGpuSpoofModel $spoofModels[4])) '推荐星标必须只覆盖 750 Ti/1050 Ti/RX560'
  Assert-True ((Get-DefaultGpuSpoofModel 'NVIDIA GeForce RTX 3060 Ti' $false) -eq 'NVIDIA GeForce GTX 750 Ti') 'RTX 30 系默认应伪装为 GTX 750 Ti'
  Assert-True ((Get-DefaultGpuSpoofModel 'NVIDIA GeForce RTX 4070' $false) -eq 'NVIDIA GeForce GTX 1050 Ti') 'RTX 40 系默认应伪装为 GTX 1050 Ti'
  Assert-True ((Get-DefaultGpuSpoofModel 'NVIDIA GeForce RTX 5060 Laptop GPU' $true) -eq 'NVIDIA GeForce GTX 1050 Ti') 'RTX 50 系笔记本默认应伪装为 GTX 1050 Ti'
  Assert-True ((Get-DefaultGpuSpoofModel 'NVIDIA GeForce GTX 1660 Ti' $false) -eq 'NVIDIA GeForce GTX 750 Ti') '其他台式 N 卡兜底应伪装为 GTX 750 Ti'
  Assert-True ((Get-DefaultGpuSpoofModel 'AMD Radeon RX 7900 XTX' $false 'AMD') -eq 'AMD Radeon RX560') 'AMD 默认应伪装为 AMD Radeon RX560'
  Assert-True ((Get-GpuVendor 'PCI\VEN_1002&DEV_744C\GPU0' 'NVIDIA GeForce RTX 2060') -eq 'AMD') 'AMD 设备伪装成 GeForce 后不得改变真实厂商判定'

  $originalGetRegValue = ${function:Get-RegValue}
  try {
    $script:TestGpuClassGuid = '{4d36e968-e325-11ce-bfc1-08002be10318}'
    function Get-RegValue([string]$Path, [string]$Name) {
      if ($Name -eq 'ClassGUID') { return $script:TestGpuClassGuid }
      if ($Name -eq 'Driver') { return '{4d36e968-e325-11ce-bfc1-08002be10318}\0007' }
      if ($Name -eq 'DriverDesc') { return 'AMD Radeon RX 7900 XTX' }
      $null
    }
    $amdHw = [pscustomobject]@{
      MainGpuVendor='AMD'; MainGpuPnp='PCI\VEN_1002&DEV_744C\GPU0'; MainGpuPciMatched=$false
      Gpus=@([pscustomobject]@{Vendor='AMD';Pnp='PCI\VEN_1002&DEV_744C\GPU0'})
    }
    Assert-True ((Get-GpuNameEnumPath $amdHw) -eq 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_1002&DEV_744C\GPU0') 'AMD DeviceDesc 必须使用精确主显卡 Enum 路径'
    Assert-True ((Get-GpuDriverDescription $amdHw.MainGpuPnp 'AMD') -eq 'AMD Radeon RX 7900 XTX') 'AMD 真实型号必须从对应显示驱动 Class 键恢复'
    $script:TestGpuClassGuid = '{4d36e96c-e325-11ce-bfc1-08002be10318}'
    Assert-True ($null -eq (Get-GpuNameEnumPath $amdHw)) '非显示适配器 ClassGUID 不得进入显卡型号伪装'
  } finally {
    Set-Item -LiteralPath Function:\Get-RegValue -Value $originalGetRegValue
  }
  Assert-True (Test-AllowedBackupRegTarget ([pscustomobject]@{Path='HKLM:\SYSTEM\CurrentControlSet\Enum\PCI\VEN_1002&DEV_744C\GPU0';Name='DeviceDesc'})) 'AMD DeviceDesc 必须进入签名备份白名单以支持完整还原'

  $thinkPad = Resolve-ComputerBrand 'LENOVO' 'ThinkPad X1 Carbon' 'LENOVO'
  $hp = Resolve-ComputerBrand 'HP' 'OMEN 16' 'HP'
  $asusBoard = Resolve-ComputerBrand 'To Be Filled By O.E.M.' 'System Product Name' 'ASUSTeK COMPUTER INC.'
  Assert-True ($thinkPad.Key -eq 'thinkpad' -and (Get-BiosEntryInstruction $thinkPad.Key $true) -like '*F1*') 'ThinkPad BIOS 教程必须提示 F1'
  Assert-True ($hp.Key -eq 'hp' -and (Get-BiosEntryInstruction $hp.Key $true) -like '*Esc*F10*') '惠普 BIOS 教程必须提示 Esc 后 F10'
  Assert-True ($asusBoard.Key -eq 'asus' -and (Get-BiosEntryInstruction $asusBoard.Key $false) -like '*Del*') '华硕台式机/主板 BIOS 教程必须提示 Del'
  $brandTutorial = Get-XmpBiosTutorial ([pscustomobject]@{ComputerBrand='惠普';ComputerModel='OMEN 16';ComputerBrandKey='hp';IsLaptop=$true})
  Assert-True ($brandTutorial -like '*检测到电脑：惠普 · OMEN 16*' -and $brandTutorial -like '*Esc*F10*') 'XMP/EXPO 教程必须显示检测品牌和对应 BIOS 进入步骤'
  $msiTutorial = Get-XmpBiosTutorial ([pscustomobject]@{
    ComputerBrand='微星';ComputerModel='MS-7B84';ComputerBrandKey='msi';IsLaptop=$false
    CpuVendor='AMD';CPU='AMD Ryzen 5';MemoryType='DDR4'
  })
  Assert-True ($msiTutorial -like '*OC → A-XMP*' -and $msiTutorial -like '*不叫 EXPO 或 DOCP*') `
    'MSI AMD DDR4 教程必须指向 A-XMP，不能继续让用户寻找 EXPO/DOCP'
  $rogTutorial = Get-XmpBiosTutorial ([pscustomobject]@{
    ComputerBrand='华硕 ROG';ComputerModel='ROG Strix G15 / 魔霸';ComputerBrandKey='asus';IsLaptop=$true
    CpuVendor='AMD';CPU='AMD Ryzen 9';MemoryType='DDR4'
  })
  Assert-True ($rogTutorial -like '*包括魔霸系列*' -and $rogTutorial -like '*若没有 Ai Tweaker*' -and
    $rogTutorial -like '*不需要继续找*') 'ROG 魔霸笔记本教程必须明确许多机型没有可用内存档位菜单'

  # ConfiguredClockSpeed 已达到 SMBIOS Speed 时没有降频证据；旧逻辑仅因为 2667 <=
  # DDR4 JEDEC 上限就弹“XMP/EXPO 未开启”，会让没有性能档位的整机用户白找 BIOS 菜单。
  $script:MockMemoryRatedMHz = 2667
  function Get-CimInstance {
    [CmdletBinding()] param([Parameter(Position=0)][string]$ClassName)
    if ($ClassName -eq 'Win32_PhysicalMemory') {
      return [pscustomobject]@{ ConfiguredClockSpeed=2667;Speed=$script:MockMemoryRatedMHz;SMBIOSMemoryType=26 }
    }
    throw "unexpected CIM class: $ClassName"
  }
  try {
    $ratedState = Get-MemoryXmpStatus
    Assert-True ($ratedState.Ok -eq $true -and $ratedState.Text -like '*已达到 SMBIOS 标称 2667 MHz*' -and
      $ratedState.Text -like '*找不到相关菜单属于正常情况*') '达到标称频率的 DDR4-2667 不得误报性能档位未开启'
    $script:MockMemoryRatedMHz = 3200
    $underclockedState = Get-MemoryXmpStatus
    Assert-True ($underclockedState.Ok -eq $false -and $underclockedState.Text -like '*低于 SMBIOS 标称 3200 MHz*' -and
      $underclockedState.Text -like '*A-XMP*') '确实低于标称频率时必须保留多种厂商菜单名与限频原因'
  } finally {
    Remove-Item -LiteralPath Function:\Get-CimInstance -Force
    Remove-Variable MockMemoryRatedMHz -Scope Script -ErrorAction SilentlyContinue
  }
  Assert-True ((Get-AmdGpuPerformanceClass 'AMD Radeon RX 7900 XTX') -eq 'high') 'RX 7900 XTX 应归入高性能 A 卡'
  Assert-True ((Get-AmdGpuPerformanceClass 'AMD Radeon RX 7600') -eq 'mid') 'RX 7600 应归入主流 A 卡'
  Assert-True ((Get-AmdGpuPerformanceClass 'AMD Radeon RX 6500 XT') -eq 'entry') 'RX 6500 XT 应归入入门 A 卡'
  Assert-True ((Get-AmdGpuPerformanceClass 'AMD Radeon 780M Graphics') -eq 'integrated-or-legacy') 'Radeon 780M 应归入核显/较早型号'
  $amdHighGuide = Get-GpuGuideText 'AMD' 'AMD Radeon RX 7900 XTX' $false ([pscustomobject]@{
    DisplayWidth=1920;DisplayHeight=1080;DisplayRefreshHz=240;RamGB=32
  })
  Assert-True ($amdHighGuide -like '*【方案一：原推荐方案】*' -and
    $amdHighGuide -like '*Radeon Anti-Lag = 开*' -and
    $amdHighGuide -like '*纹理过滤质量 = 性能*') 'AMD 原推荐方案必须原样保留'
  Assert-True ($amdHighGuide -like '*【方案二：按本机配置推荐】*' -and
    $amdHighGuide -like '*1920×1080 @ 240Hz*' -and
    $amdHighGuide -like '*Anti-Lag = 开；Chill / Boost = 关*' -and
    $amdHighGuide -like '*VSR 2560×1440*' -and
    $amdHighGuide -like '*237 FPS*') '高性能 A 卡的 1080P/高刷配置推荐不正确'
  $amdMidGuide = Get-AmdConfiguredGuideText ([pscustomobject]@{
    DisplayWidth=2560;DisplayHeight=1440;DisplayRefreshHz=165;RamGB=16
  }) 'AMD Radeon RX 7600' $false
  Assert-True ($amdMidGuide -like '*主流 A 卡*' -and
    $amdMidGuide -like '*纹理过滤质量 = 标准*' -and
    $amdMidGuide -like '*RSR / VSR = 关*') '主流 A 卡配置推荐不正确'
  $amdLaptopGuide = Get-AmdConfiguredGuideText ([pscustomobject]@{
    DisplayWidth=1920;DisplayHeight=1080;DisplayRefreshHz=60;RamGB=8
  }) 'AMD Radeon 780M Graphics' $true
  Assert-True ($amdLaptopGuide -like '*入门、核显或较早型号*' -and
    $amdLaptopGuide -like '*纹理过滤质量 = 性能*' -and
    $amdLaptopGuide -like '*笔记本补充*' -and
    $amdLaptopGuide -like '*少于 16 GB*') '核显低内存笔记本配置推荐不正确'
  $noChange = [pscustomobject]@{ Ok=$true; Skipped=$false; Msg='已写入' }
  [void](Set-ApplyResultChangeState $noChange $false)
  Assert-True (-not $noChange.Changed -and $noChange.Skipped -and $noChange.Msg -like '无需修改*') '0 个 applied WAL 的成功项必须标记 Changed=false/Skipped=true'
  $didChange = [pscustomobject]@{ Ok=$true; Skipped=$false; Msg='已写入' }
  [void](Set-ApplyResultChangeState $didChange $true)
  Assert-True ($didChange.Changed -and -not $didChange.Skipped) '真实变更项必须标记 Changed=true'

  $originalGetTaskXml = ${function:Get-TaskXml}
  try {
    $script:TaskCommandForTest = (Join-Path $temp 'powercfg.exe')
    function Get-TaskXml([string]$TaskName) {
      [xml]("<Task><Actions><Exec><Command>$script:TaskCommandForTest</Command><Arguments>/setactive 11111111-1111-1111-1111-111111111111</Arguments></Exec></Actions></Task>")
    }
    Assert-True (-not (Test-BoosterLockTask $script:LockTask)) '用户路径中的同名 powercfg.exe 不得被认为本工具计划任务'
    $script:TaskCommandForTest = $script:PowerCfgExe
    Assert-True (Test-BoosterLockTask $script:LockTask) '仅 System32 powercfg.exe + 严格 GUID 参数的任务可被认领'
  } finally { Set-Item -Path Function:\Get-TaskXml -Value $originalGetTaskXml }
  $wrongExe = Join-Path $temp 'not-the-game.exe'
  [IO.File]::WriteAllText($wrongExe,'fixture')
  $gamePathRejected = $false
  try { [void](Resolve-ValidatedGamePath $wrongExe) } catch { $gamePathRejected = ($_.Exception.Message -like '*三角洲行动主程序*') }
  Assert-True $gamePathRejected '任意 exe 必须在生成 AppCompat/GPU/IFEO 操作前被拒绝'
  $validExe = Join-Path $temp 'DeltaForceClient-Win64-Shipping.exe'
  [IO.File]::WriteAllText($validExe,'fixture')
  Assert-True ((Resolve-ValidatedGamePath $validExe) -eq [IO.Path]::GetFullPath($validExe)) '允许的游戏主程序应返回规范绝对路径'

  # 第三方平台偶尔会把 REG_SZ 写成带尾随 NUL；WinPS 5.1 原先会在 Find-GamePath 的
  # Test-Path 直接抛 Illegal characters in path，GUI 因而停在“检测失败 / 定位中”。
  $searchRoot = Join-Path $temp 'game-search-fixture'
  $searchExe = Join-Path $searchRoot 'DeltaForce\Binaries\Win64\DeltaForceClient-Win64-Shipping.exe'
  [void][IO.Directory]::CreateDirectory((Split-Path -Parent $searchExe))
  [IO.File]::WriteAllText($searchExe,'fixture')
  $uninstaller = Join-Path $searchRoot 'uninstall.exe'
  [IO.File]::WriteAllText($uninstaller,'fixture')
  Assert-True ((Resolve-RegistryFileParent ('"' + $uninstaller + '" /S') $false) -eq $searchRoot) '带引号和参数的 UninstallString 应只解析 EXE 父目录'
  Assert-True ((Resolve-RegistryFileParent ('"' + $uninstaller + '",0') $true) -eq $searchRoot) 'DisplayIcon 的引号和资源索引不得混进目录'
  Assert-True ((Resolve-RegistryFileParent ($uninstaller + ' /quiet') $false) -eq $searchRoot) '未加引号且路径含空格的卸载命令应解析到首个完整 EXE'
  Assert-True ($null -eq (Resolve-ExistingGameSearchRoot ([IO.Path]::GetPathRoot($searchRoot)))) '损坏候选不得把整盘根加入递归扫描'
  Assert-True ($null -eq (Resolve-ExistingGameSearchRoot ("C:\bad" + [char]0 + 'embedded'))) '含内嵌 NUL 的损坏候选应跳过'

  $originalGetRegValue = ${function:Get-RegValue}
  try {
    $script:MockGameSearchRoot = $searchRoot + [char]0
    $script:ObservedGameSearchRoots = New-Object System.Collections.Generic.List[string]
    function Get-RegValue([string]$Path, [string]$Name) {
      if ($Path -match 'Tencent\\WeGame') { return $script:MockGameSearchRoot }
      $null
    }
    function Get-Process { [CmdletBinding()]param([string[]]$Name) @() }
    function Get-ItemProperty { [CmdletBinding()]param([object[]]$Path) @() }
    function Get-PSDrive { [CmdletBinding()]param([string[]]$PSProvider) @() }
    function Get-ChildItem {
      [CmdletBinding()]param([string]$LiteralPath,[switch]$Recurse,[int]$Depth,[string]$Filter,[switch]$File)
      if ($LiteralPath) { [void]$script:ObservedGameSearchRoots.Add($LiteralPath) }
      @()
    }
    Assert-True ((Find-GamePath) -eq $searchExe) '尾随 NUL 应被清理，合法 WeGame 根仍须自动定位游戏'
    $script:MockGameSearchRoot = [IO.Path]::GetPathRoot($searchRoot)
    $script:ObservedGameSearchRoots.Clear()
    Assert-True ($null -eq (Find-GamePath)) '只有整盘根候选时应返回未定位而不是递归整盘'
    Assert-True ($script:ObservedGameSearchRoots.Count -eq 0) 'Get-ChildItem 不得收到文件系统根候选'
    $script:MockGameSearchRoot = "C:\bad" + [char]0 + 'embedded'
    Assert-True ($null -eq (Find-GamePath)) '坏平台注册表候选不得使自动定位抛异常'
  } finally {
    Set-Item -Path Function:\Get-RegValue -Value $originalGetRegValue
    foreach ($fn in 'Get-Process','Get-ItemProperty','Get-PSDrive','Get-ChildItem') {
      Remove-Item -Path ("Function:\" + $fn) -Force -ErrorAction SilentlyContinue
    }
  }

  $noGameItems = @(Get-OptItems $null)
  $nonGameItem = $noGameItems | Where-Object Id -eq 'game-mode' | Select-Object -First 1
  $gameOnlyItem = $noGameItems | Where-Object Id -eq 'fso-off' | Select-Object -First 1
  Assert-True (@($nonGameItem.Ops).Count -gt 0) '未定位游戏时，非游戏系统项仍应保留可执行操作'
  Assert-True ($gameOnlyItem.RequiresGame -and -not $gameOnlyItem.Ops) '未定位游戏时，只应让依赖路径的项目进入明确跳过分支'
  $engineText = Get-Content -LiteralPath $engine -Raw -Encoding UTF8
  Assert-True ($engineText -notmatch '(?i)705\s*Ti') '引擎参数、注册表目标字符串及文案不得残留错误型号 705 Ti'
  Assert-True ($engineText -match "Name = 'SystemResponsiveness'; Value = 10") 'SystemResponsiveness 必须使用有效最低值 10'
  $partial = [pscustomobject]@{ BackupError=$null; Results=@([pscustomobject]@{Ok=$false;Skipped=$false;Attention=$false}) }
  $backupFail = [pscustomobject]@{ BackupError='disk'; Results=@() }
  Assert-True ((Get-ApplyExitCode $partial) -eq 2 -and (Get-ApplyExitCode $backupFail) -eq 3) 'Apply 失败必须返回约定的 2/3'
  Assert-True ((Get-RestoreExitCode ([pscustomobject]@{Failed=@('x')})) -eq 4) 'Restore 不完整必须返回 4'

  $cacheRoot = Join-Path $temp 'cache'
  $outside = Join-Path $temp 'outside'
  [void][IO.Directory]::CreateDirectory($cacheRoot); [void][IO.Directory]::CreateDirectory($outside)
  [IO.File]::WriteAllText((Join-Path $outside 'keep.bin'), 'keep')
  try {
    New-Item -ItemType Junction -Path (Join-Path $cacheRoot 'linked') -Target $outside -ErrorAction Stop | Out-Null
    $scan = Get-SafeFilesUnderRoot $cacheRoot
    Assert-True (@($scan.Rejected).Count -eq 1) '缓存扫描必须拒绝 junction'
    Assert-True ((Get-Content -LiteralPath (Join-Path $outside 'keep.bin') -Raw) -eq 'keep') '越界文件不得被修改'
  } catch {
    Write-Output "SKIP junction：$($_.Exception.Message)"
  }

  $invalidIdRejected = $false
  try { Write-IpcResult '..\bad' 'Detect' $null 1 'x' } catch { $invalidIdRejected = $true }
  Assert-True $invalidIdRejected 'IPC 只接受标准 GUID'

  $m1 = Enter-EngineMutex
  try {
    $job = Start-Job -ScriptBlock {
      param($Engine)
      . $Engine
      try { $m = Enter-EngineMutex; Exit-EngineMutex $m; 'acquired' } catch { 'locked' }
    } -ArgumentList $engine
    $jobResult = Receive-Job -Job $job -Wait
    Remove-Job -Job $job -Force
    Assert-True ($jobResult -contains 'locked') '核心全局 mutex 必须阻止第二个进程'
  } finally { Exit-EngineMutex $m1 }

  Write-Output 'engine-security-tests: PASS'
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
