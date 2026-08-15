param([switch]$KeepArtifacts)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$guiText = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'))
if ($guiText -notmatch "\`$script:GuiVersion\s*=\s*'([0-9.]+)'") { throw '无法解析 GUI 版本号' }
if ($guiText -notmatch "\`$script:DisplayVersion\s*=\s*'([0-9.]+)'") { throw '无法解析 GUI 显示版本号' }
$setup = Join-Path $root "build\DeltaForceBooster-Setup-v$($Matches[1])-TEST.exe"
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) {
  throw '请先运行：powershell -File build\make-installer.ps1 -TestBuild'
}
$testBase = Join-Path ([IO.Path]::GetTempPath()) ('DeltaForceBooster-Tests\installer-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testBase)

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT: $Message" }
}
$installerBuildSource = [IO.File]::ReadAllText((Join-Path $root 'build\make-installer.ps1'))
$launcherBuildSource = [IO.File]::ReadAllText((Join-Path $root 'build\make-launcher.ps1'))
$updaterSource = [IO.File]::ReadAllText((Join-Path $root 'scripts\updater.ps1'))
$stagingAclFunction = [regex]::Match($updaterSource, '(?s)function Set-BoosterStagingFileAcl\s*\{.*?\n\}').Value
Assert-True ($stagingAclFunction -match 'GetAccessControl' -and
  $stagingAclFunction -match 'GetAccessRules' -and
  $stagingAclFunction -match 'ReadAndExecute' -and
  $stagingAclFunction -match 'FullControl' -and
  $stagingAclFunction -match 'ACL 写入后复验失败') `
  'secure update staging does not re-read and verify the file ACL after writing it'
$releaseManifest = Get-Content -LiteralPath (Join-Path $root 'build\update-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$currentVersion = [regex]::Match($guiText, "(?m)^\`$script:GuiVersion\s*=\s*'([0-9.]+)'\s*$").Groups[1].Value
Assert-True ($installerBuildSource -match "minimumSupportedVersion\s*=\s*'0\.23\.0\.8'" -and
  "$($releaseManifest.version)" -eq $currentVersion -and "$($releaseManifest.displayVersion)" -eq $currentVersion -and
  "$($releaseManifest.minimumSupportedVersion)" -eq '0.23.0.8') `
  'release manifest version or mandatory-upgrade floor is stale'
$expectedReleaseNotes = @'
- 修复从早期版本升级后，还原游戏进程优先级可能提示“备份注册表目标不在白名单”、导致还原列表读取失败的问题。
- 历史兼容仅开放 DeltaForceClient.exe 的 CpuPriorityClass 与 IoPriority 原优化项，其他进程名和 IFEO 值继续按安全白名单拒绝。
- v0.23.0.8 以前的版本仍需完成更新后继续使用。
'@
Assert-True (("$($releaseManifest.notes)" -replace "`r`n", "`n") -eq ($expectedReleaseNotes -replace "`r`n", "`n") -and
  $installerBuildSource.Contains("`$manifestNotes = @'")) `
  'v0.23.0.13 release notes are missing or inconsistent'
Assert-True ($launcherBuildSource.Contains('const string ActiveMarkerName = @"Global\DeltaForceBooster.LaunchSession";') -and
  $launcherBuildSource.Contains('const string InstanceMarkerName = @"Local\DeltaForceBooster.LaunchInstance";') -and
  $launcherBuildSource.Contains('activeMarker = CreateSessionMarker(ActiveMarkerName') -and
  $launcherBuildSource.Contains('instanceMarker = CreateSessionMarker(InstanceMarkerName') -and
  $launcherBuildSource.Contains('TryActivateExistingWindow()')) `
  'launcher still conflates the global lifecycle marker with the current-session instance marker'
$disclaimerText = [IO.File]::ReadAllText((Join-Path $root 'DISCLAIMER.md'))
Assert-True ($disclaimerText -notmatch '自动寻找最佳配置|自动调优|experiments') `
  'usage notice still exposes automatic best-configuration Beta information'
Assert-True ($guiText -match "\`$script:DisclaimerVersion\s*=\s*'8'") `
  'usage notice changed without advancing the acceptance version'
Assert-True ($disclaimerText.Contains('### 电源计划优化的兼容性风险') -and
  $disclaimerText.Contains('游戏无法启动或进入') -and
  $disclaimerText.Contains('通过二次确认并继续执行') -and
  $disclaimerText.Contains('恢复本次电源相关项目并重启电脑')) `
  'power-plan compatibility risks are missing from the accepted usage notice'
$updaterPolicyDir = Join-Path $testBase 'updater-policy'
[void][IO.Directory]::CreateDirectory($updaterPolicyDir)
$policyManifestPath = Join-Path $updaterPolicyDir 'manifest.json'
$policyManifest = [ordered]@{
  version = $currentVersion; displayVersion = $currentVersion; minimumSupportedVersion = $currentVersion; notes = '- test'
  url = 'https://df.ltz88.cn/'; setupUrl = 'https://df.ltz88.cn/DeltaForceBooster-Setup.exe'
  sha256 = ('0' * 64); size = 1
}
[IO.File]::WriteAllText($policyManifestPath, ($policyManifest | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
$script:BoosterUserConfigDir = Join-Path $updaterPolicyDir 'config'
. (Join-Path $root 'scripts\updater.ps1')
Set-BoosterSkipVersion $currentVersion | Out-Null
$mandatoryUpdate = Test-BoosterUpdate -CurrentVersion '0.23.0.6' -ManifestUrl ([Uri]$policyManifestPath).AbsoluteUri
Assert-True ($mandatoryUpdate -and $mandatoryUpdate.Mandatory -and $mandatoryUpdate.CanInline -and
  "$($mandatoryUpdate.MinimumSupportedVersion)" -eq $currentVersion -and "$($mandatoryUpdate.DisplayVersion)" -eq $currentVersion) `
  'the immediately previous release can skip or defer the mandatory current update'
Assert-True ($null -eq (Test-BoosterUpdate -CurrentVersion $currentVersion -ManifestUrl ([Uri]$policyManifestPath).AbsoluteUri)) `
  'current release incorrectly detects itself as an update'
$setupSource = [IO.File]::ReadAllText((Join-Path $root 'build\setup-wizard.cs'))
Assert-True ($installerBuildSource -match "(?s)'PawnIO_setup\.exe'\s*=\s*'1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032'" -and
  $installerBuildSource -match 'Get-AuthenticodeSignature' -and
  $installerBuildSource.Contains('CN=namazso\.eu')) `
  'build no longer pins and verifies the signed PawnIO 2.2.0 installer'
Assert-True ($setupSource -match 'EnsurePawnIoInstalled\(stage, onProgress\)' -and
  $setupSource -match 'Arguments = "-install -silent"' -and
  $setupSource -match 'PawnIoInstallerSha256 = "1F519A22E47187F70A1379A48CA604981C4FCF694F4E65B734AAA74A9FBA3032"' -and
  $setupSource -match '测试模式已跳过 PawnIO 驱动安装') `
  'installer no longer installs the verified PawnIO driver or isolates driver installation from test builds'
$pawnIoSection = [regex]::Match($setupSource, '(?s)static bool IsPawnIoCurrent.*?static bool IsTrustedInstallWriter').Value
Assert-True ($pawnIoSection.Contains('SYSTEM\CurrentControlSet\Services\PawnIO') -and
  $pawnIoSection.Contains('SYSTEM\CurrentControlSet\Enum\ROOT\PAWNIO') -and
  $pawnIoSection.Contains('DriverStore') -and
  $pawnIoSection.Contains('PawnIO.sys') -and
  ([regex]::Matches($pawnIoSection, 'new Version\(2, 2, 0\)').Count -ge 2) -and
  -not $pawnIoSection.Contains('new Version(2, 2, 0, 0)') -and
  $pawnIoSection.Contains('bool currentAfterInstall = IsPawnIoCurrent') -and
  $pawnIoSection.Contains('if (exitCode == 183)') -and
  $pawnIoSection.Contains('软件主体将继续安装') -and
  -not $pawnIoSection.Contains('throw new InvalidOperationException("PawnIO 驱动安装失败')) `
  'PawnIO detection/failure regression: existing driver or exit 183 can still abort the application install'
Assert-True ($setupSource -match 'SetNamedSecurityInfoW' -and
  $setupSource -match 'LABEL_SECURITY_INFORMATION' -and
  $setupSource -match 'S:\(ML;OICI;NW;;;HI\)' -and
  $setupSource -match '/setintegritylevel \(CI\)\(OI\)H') `
  'installer high-integrity labeling is missing the native API path or documented icacls fallback'
$stageProtection = [regex]::Match($setupSource, '(?s)static void CreateProtectedTransactionStage\s*\(.*?\n    \}').Value
Assert-True ($stageProtection -match 'TryApplyHighIntegrityLabel' -and
  $stageProtection -match 'EnsureExactAdminSystemEntry\(stage, true\)' -and
  $stageProtection -match 'High MIC.*附加纵深防护') `
  'staging label failure still blocks every drive instead of falling back to the verified Admin/SYSTEM DACL'
Assert-True ($setupSource -match 'DFB_TEST_FORCE_INTEGRITY_LABEL_FAILURE') `
  'test build cannot exercise the staging-label fallback path'
Assert-True ($setupSource -match '若所有磁盘都出现同一错误，无需继续换盘') `
  'installer still misleads users into retrying every drive for a machine-wide security-label failure'
$anchorLabeling = [regex]::Match($setupSource, '(?s)static void SetHighIntegrityAnchor\s*\(.*?\n    \}').Value
Assert-True ($anchorLabeling -match 'throw new IOException' -and
  $anchorLabeling -notmatch 'EnsureExactAdminSystemEntry') `
  'permanent custom-drive anchor must still fail closed when its High MIC label cannot be established'
Assert-True ($setupSource -match 'PROC_THREAD_ATTRIBUTE_PARENT_PROCESS' -and
  $setupSource -match 'PROCESS_CREATE_PROCESS' -and $setupSource -match 'EXTENDED_STARTUPINFO_PRESENT') `
  'elevated run-after does not create through the verified desktop Explorer parent'
Assert-True ($setupSource -match 'CREATE_SUSPENDED' -and
  $setupSource -match '(?s)VerifySuspendedDesktopChild\(processInformation\.hProcess.*?\).*?ResumeThread') `
  'run-after executes the child before exact path/session/SID/integrity verification'
Assert-True ($setupSource -match 'QueryFullProcessImageNameW' -and
  $setupSource -match '新版启动器用户与安装前用户不一致' -and
  $setupSource -match '新版启动器没有继承当前桌面的受支持令牌') `
  'run-after no longer verifies the exact created image and desktop token identity'
Assert-True ($setupSource -notmatch 'static\s+extern\s+bool\s+CreateProcessWithTokenW|static\s+extern\s+bool\s+CreateProcessAsUserW|TokenLinkedToken\s*=') `
  'run-after still relies on token APIs that fail on RID-500 with errors 5/1314'
Assert-True ($setupSource -match 'CreateEnvironmentBlock') 'run-after does not build the original desktop user environment'
Assert-True ($setupSource -match 'StartWithDesktopShellParent\(exe, originSid\)') 'run-after is not connected to the desktop parent launcher'
Assert-True ($setupSource -notmatch 'FileName\s*=\s*explorer') 'run-after still delegates through explorer.exe and may inherit the elevated installer token'
Assert-True ($setupSource -match 'InstallForLaunchValidation' -and $setupSource -match 'WaitForStartupReadiness' -and
  $setupSource -match 'RollbackDeferredInstall') 'run-after no longer retains the old version through startup validation'
Assert-True ($setupSource -match 'EnumWindows\(callback, IntPtr\.Zero\)' -and
  $setupSource -notmatch 'IntPtr\s+window\s*=\s*process\.MainWindowHandle') `
  'startup health check can miss WPF when PowerShell exposes another main window first'
function Invoke-TestSetup([string[]]$Arguments, [string]$WorkingDirectory = '') {
  $start = @{ FilePath = $setup; ArgumentList = $Arguments; Wait = $true; PassThru = $true }
  if ($WorkingDirectory) { $start.WorkingDirectory = $WorkingDirectory }
  $p = Start-Process @start
  $p.ExitCode
}
function Set-TestPaths([string]$Case, [string]$ProgramFiles) {
  $env:DFB_TEST_PROGRAMFILES = $ProgramFiles
  $env:DFB_TEST_PROGRAMDATA = Join-Path $Case 'PD'
  $env:DFB_TEST_LOCALAPPDATA = Join-Path $Case 'LA'
  $env:DFB_TEST_DESKTOP = Join-Path $Case 'Desktop'
  $env:DFB_TEST_PROGRAMS = Join-Path $Case 'Programs'
  $env:DFB_TEST_ALLOW_WRITABLE_INSTALL = '1'
  $env:DFB_TEST_SKIP_ACL = '1'
  $env:DFB_TEST_NOLAUNCH = '1'
  foreach ($path in $ProgramFiles,$env:DFB_TEST_PROGRAMDATA,$env:DFB_TEST_LOCALAPPDATA,
      $env:DFB_TEST_DESKTOP,$env:DFB_TEST_PROGRAMS) { [void][IO.Directory]::CreateDirectory($path) }
}

function Test-UpdaterHandleSharing {
  $path = Join-Path $testBase 'sharing.bin'
  [IO.File]::WriteAllBytes($path, [byte[]](1,2,3,4))
  $parent = $null; $helper = $null; $writer = $null
  try {
    $parent = [IO.FileStream]::new($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite,
      [IO.FileShare]::Read)
    # This is the exact updater/helper pairing: helper must allow the already-open parent's
    # write access, while the parent's share mask continues to reject every new writer.
    $helper = [IO.FileStream]::new($path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
      [IO.FileShare]::ReadWrite)
    $writeBlocked = $false
    try {
      $writer = [IO.FileStream]::new($path, [IO.FileMode]::Open, [IO.FileAccess]::Write,
        [IO.FileShare]::ReadWrite)
    } catch [IO.IOException] { $writeBlocked = $true }
    Assert-True $writeBlocked 'download handle did not block a third-party writer'
  } finally {
    if ($writer) { $writer.Dispose() }
    if ($helper) { $helper.Dispose() }
    if ($parent) { $parent.Dispose() }
  }
}

function New-TestLockingPresentMon([string]$Path) {
  $windows = Split-Path -Parent ([Environment]::SystemDirectory)
  $csc = Join-Path $windows 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  if (-not (Test-Path -LiteralPath $csc -PathType Leaf)) {
    $csc = Join-Path $windows 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
  }
  Assert-True (Test-Path -LiteralPath $csc -PathType Leaf) 'system csc missing for PresentMon lock fixture'
  $source = [IO.Path]::ChangeExtension($Path, '.fixture.cs')
  $code = @'
using System;
using System.IO;
using System.Threading;
static class PresentMonLockFixture {
    static void Main(string[] args) {
        Environment.CurrentDirectory = Path.GetFullPath(args[0]);
        Thread.Sleep(Timeout.Infinite);
    }
}
'@
  if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
  [IO.File]::WriteAllText($source, $code, (New-Object Text.UTF8Encoding($false)))
  try {
    & $csc /nologo /target:winexe /optimize+ "/out:$Path" $source
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $Path -PathType Leaf)) 'PresentMon lock fixture compile failed'
  } finally {
    Remove-Item -LiteralPath $source -Force -ErrorAction SilentlyContinue
  }
}

function New-TestLegacyLauncher([string]$Path, [string]$Version = '0.19.3.0') {
  $windows = Split-Path -Parent ([Environment]::SystemDirectory)
  $csc = Join-Path $windows 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  if (-not (Test-Path -LiteralPath $csc -PathType Leaf)) {
    $csc = Join-Path $windows 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
  }
  Assert-True (Test-Path -LiteralPath $csc -PathType Leaf) 'system csc missing for legacy fixture'
  $source = [IO.Path]::ChangeExtension($Path, '.fixture.cs')
  $code = @"
using System.Reflection;
[assembly: AssemblyProduct("DeltaForceBooster")]
[assembly: AssemblyCompany("DeltaForceBooster 开源项目")]
[assembly: AssemblyVersion("$Version")]
[assembly: AssemblyFileVersion("$Version")]
static class LegacyLauncherFixture { [System.STAThread] static void Main() {} }
"@
  [IO.File]::WriteAllText($source, $code, (New-Object Text.UTF8Encoding($false)))
  try {
    & $csc /nologo /target:winexe /optimize+ "/out:$Path" $source
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $Path -PathType Leaf)) 'legacy launcher fixture compile failed'
  } finally {
    Remove-Item -LiteralPath $source -Force -ErrorAction SilentlyContinue
  }
}

function Set-TestProductVersion([string]$Path, [string]$GuiVersion, [string]$LauncherVersion = $GuiVersion) {
  New-TestLegacyLauncher (Join-Path $Path '启动优化工具.exe') "$LauncherVersion.0"
  $gui = Join-Path $Path 'gui\DeltaForceBooster-GUI.ps1'
  $text = [IO.File]::ReadAllText($gui)
  $rx = New-Object Text.RegularExpressions.Regex '(?m)^\$script:GuiVersion\s*=\s*''[^'']+''\s*$'
  $text = $rx.Replace($text, "`$script:GuiVersion = '$GuiVersion'", 1)
  Assert-True ($rx.IsMatch($text)) 'legacy GUI fixture version rewrite failed'
  [IO.File]::WriteAllText($gui, $text, (New-Object Text.UTF8Encoding($true)))
}

function Convert-ToLegacyInstallFixture([string]$Path, [string]$GuiVersion = '0.19.3', [string]$LauncherVersion = $GuiVersion) {
  Remove-Item -LiteralPath (Join-Path $Path 'install.identity') -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath (Join-Path $Path 'scripts\tuning-experiment.ps1') -Force -ErrorAction SilentlyContinue
  # Current packages route the .bat through EngineHost.exe.  A real v0.18/v0.19 root instead
  # contained the historical PowerShell GUI fallback that the migration identity check expects.
  [IO.File]::WriteAllText((Join-Path $Path '启动优化工具.bat'),
    "@echo off`r`nrem DeltaForceBooster launcher`r`nrem gui\DeltaForceBooster-GUI.ps1`r`n",
    [Text.Encoding]::ASCII)
  Set-TestProductVersion $Path $GuiVersion $LauncherVersion
}

function Convert-ToHistoricalIdentityFixture([string]$Path, [string]$Version = '0.19.4') {
  Remove-Item -LiteralPath (Join-Path $Path 'scripts\tuning-experiment.ps1') -Force -ErrorAction SilentlyContinue
  Set-TestProductVersion $Path $Version $Version
  $sha = (Get-FileHash -LiteralPath (Join-Path $Path '启动优化工具.exe') -Algorithm SHA256).Hash.ToUpperInvariant()
  $identity = "SchemaVersion=1`nProductId=DeltaForceBooster`nLauncherSha256=$sha`n"
  [IO.File]::WriteAllText((Join-Path $Path 'install.identity'), $identity, (New-Object Text.UTF8Encoding($false)))
}

try {
  Test-UpdaterHandleSharing
  # TestBuild 用临时目录模拟一个固定 NTFS 卷边界；正式构建没有该钩子，只接受真实卷根。
  # 其他盘布局必须恰好是 <volume>\<anchor>\app，任意中间层都 fail closed。
  $setupAssembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes($setup))
  $installerType = $setupAssembly.GetType('DfbSetup.Installer', $true)
  $tryApplyIntegrity = $installerType.GetMethod('TryApplyHighIntegrityLabel', [Reflection.BindingFlags]'Static,NonPublic')
  $savedIntegrityFailure = $env:DFB_TEST_FORCE_INTEGRITY_LABEL_FAILURE
  try {
    $env:DFB_TEST_FORCE_INTEGRITY_LABEL_FAILURE = '1'
    $integrityArgs = [object[]]::new(2)
    $integrityArgs[0] = [string](Join-Path $testBase '.dfb-stage-integrity-fixture')
    $integrityArgs[1] = [string]::Empty
    Assert-True (-not [bool]$tryApplyIntegrity.Invoke($null, $integrityArgs) -and
      [string]$integrityArgs[1] -like '*测试注入*') `
      'test build did not exercise the machine-wide High MIC failure signal'
  } finally {
    if ($null -eq $savedIntegrityFailure) { Remove-Item Env:DFB_TEST_FORCE_INTEGRITY_LABEL_FAILURE -ErrorAction SilentlyContinue }
    else { $env:DFB_TEST_FORCE_INTEGRITY_LABEL_FAILURE = $savedIntegrityFailure }
  }
  # 健康检查必须识别进程树里的任意可交互 WPF 顶层窗口，而不是只相信
  # Process.MainWindowHandle（PowerShell 可能先暴露隐藏控制台/辅助窗口）。
  Add-Type -AssemblyName PresentationFramework
  $savedNoLaunch = $env:DFB_TEST_NOLAUNCH
  $savedHealthFailure = $env:DFB_TEST_STARTUP_HEALTH_FAIL
  Remove-Item Env:DFB_TEST_NOLAUNCH,Env:DFB_TEST_STARTUP_HEALTH_FAIL -ErrorAction SilentlyContinue
  $healthWindow = New-Object Windows.Window
  $healthWindow.Title = 'DFB startup health fixture'
  $healthWindow.Width = 120; $healthWindow.Height = 80
  $healthWindow.WindowStartupLocation = 'Manual'
  $healthWindow.Left = -30000; $healthWindow.Top = -30000
  $healthWindow.ShowInTaskbar = $false
  $healthWindow.Show()
  try {
    $healthWindow.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)
    $waitForStartup = $installerType.GetMethod('WaitForStartupReadiness', [Reflection.BindingFlags]'Static,Public')
    $healthArgs = New-Object 'object[]' 3
    $healthArgs[0] = [string]$testBase; $healthArgs[1] = [int]$PID; $healthArgs[2] = $null
    Assert-True ([bool]$waitForStartup.Invoke($null, $healthArgs)) 'startup health check missed an interactive WPF window'
    Assert-True ([string]$healthArgs[2] -like '*DFB startup health fixture*') 'startup health result did not identify the ready WPF window'
  } finally {
    $healthWindow.Close()
    if ($null -eq $savedNoLaunch) { Remove-Item Env:DFB_TEST_NOLAUNCH -ErrorAction SilentlyContinue }
    else { $env:DFB_TEST_NOLAUNCH = $savedNoLaunch }
    if ($null -eq $savedHealthFailure) { Remove-Item Env:DFB_TEST_STARTUP_HEALTH_FAIL -ErrorAction SilentlyContinue }
    else { $env:DFB_TEST_STARTUP_HEALTH_FAIL = $savedHealthFailure }
  }
  $checkSecure = $installerType.GetMethod('CheckSecureInstallLocation', [Reflection.BindingFlags]'Static,Public')
  $checkDesktopOrigin = $installerType.GetMethod('CheckDesktopShellOrigin', [Reflection.BindingFlags]'Static,Public')
  $supportedDesktopIntegrity = $installerType.GetMethod('IsSupportedDesktopShellIntegrity', [Reflection.BindingFlags]'Static,NonPublic')
  $volumeReplaceRights = $installerType.GetMethod('HasVolumeRootReplacementRights', [Reflection.BindingFlags]'Static,NonPublic')
  $invokeSecure = {
    param([string]$Path)
    [string]$checkSecure.Invoke($null, [object[]]@($Path))
  }
  $invokeVolumeReplaceRights = {
    param([int64]$Mask)
    $rights = [Enum]::ToObject([Security.AccessControl.FileSystemRights], [int]$Mask)
    [bool]$volumeReplaceRights.Invoke($null, [object[]]@($rights))
  }
  Assert-True (-not (& $invokeVolumeReplaceRights 0x1301bf)) 'ordinary data-volume root Modify mask was treated as DeleteChild'
  Assert-True (-not (& $invokeVolumeReplaceRights 0x10000)) 'DELETE on the volume root object was treated as child replacement'
  foreach ($dangerousMask in 0x40,0x40000,0x80000,0x10000000) {
    Assert-True (& $invokeVolumeReplaceRights $dangerousMask) ("dangerous volume-root mask was accepted: 0x{0:x}" -f $dangerousMask)
  }
  Assert-True ([bool]$supportedDesktopIntegrity.Invoke($null, [object[]]@(0x2000))) 'normal medium desktop shell was rejected'
  Assert-True ([bool]$supportedDesktopIntegrity.Invoke($null, [object[]]@(0x3000))) 'RID-500/UAC-disabled high desktop shell was rejected'
  Assert-True (-not [bool]$supportedDesktopIntegrity.Invoke($null, [object[]]@(0x1000))) 'low-integrity shell was accepted'
  Assert-True (-not [bool]$supportedDesktopIntegrity.Invoke($null, [object[]]@(0x4000))) 'system-integrity shell was accepted'
  $currentUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $env:DFB_TEST_SHELL_SID = $currentUserSid
  $originArgs = New-Object 'object[]' 1; $originArgs[0] = $currentUserSid
  Assert-True ($null -eq $checkDesktopOrigin.Invoke($null, $originArgs)) 'matching original/desktop-shell SID was rejected'
  $originArgs[0] = 'S-1-5-21-1-2-3-1001'
  Assert-True ([string]$checkDesktopOrigin.Invoke($null, $originArgs) -like '*不一致*') 'OTS shell/user SID mismatch was accepted'
  $originArgs[0] = 'not-a-sid'
  Assert-True ([string]$checkDesktopOrigin.Invoke($null, $originArgs) -like '*缺失或格式无效*') 'invalid origin SID was accepted'
  $customVolume = Join-Path $testBase 'custom-volume'
  [void][IO.Directory]::CreateDirectory($customVolume)
  $env:DFB_TEST_CUSTOM_DRIVE_ROOT = $customVolume
  $env:DFB_TEST_ALLOW_WRITABLE_INSTALL = '1'
  $env:DFB_TEST_SKIP_ACL = '1'
  $customProtected = Join-Path $customVolume 'DeltaForceBooster'
  Assert-True ((& $invokeSecure $customProtected) -eq '') 'new root-level fixed-NTFS anchor was rejected'
  Assert-True ((& $invokeSecure ($customProtected + ':foreign')) -ne '') 'custom anchor ADS path was accepted'
  Assert-True ((& $invokeSecure $customVolume) -like '*不能是磁盘根目录*') 'custom volume root was accepted as the anchor'
  Assert-True ((& $invokeSecure '\\localhost\share\DeltaForceBooster') -like '*UNC*') 'UNC path was accepted'
  [void][IO.Directory]::CreateDirectory((Join-Path $customVolume 'Games'))
  Assert-True ((& $invokeSecure (Join-Path $customVolume 'Games\DeltaForceBooster')) -like '*一级受保护安装目录*') 'nested custom anchor was accepted'
  [void][IO.Directory]::CreateDirectory((Join-Path $customVolume 'ExistingEmpty'))
  Assert-True ((& $invokeSecure (Join-Path $customVolume 'ExistingEmpty')) -like '*anchor.identity*') 'unverified existing empty anchor was accepted'
  Assert-True ((& $invokeSecure (Join-Path $customVolume 'Missing\app')) -ne '') 'physical app path without a verified anchor was accepted'
  $env:DFB_TEST_DRIVE_TYPE = 'Removable'
  Assert-True ((& $invokeSecure (Join-Path $testBase 'removable\DeltaForceBooster')) -like '*固定磁盘*') 'removable-volume fixture was accepted'
  Remove-Item Env:DFB_TEST_DRIVE_TYPE
  $env:DFB_TEST_DRIVE_FORMAT = 'FAT32'
  Assert-True ((& $invokeSecure (Join-Path $testBase 'fat32\DeltaForceBooster')) -like '*NTFS*') 'non-NTFS fixture was accepted'
  Remove-Item Env:DFB_TEST_DRIVE_FORMAT
  $setupSource = [IO.File]::ReadAllText((Join-Path $root 'build\setup-wizard.cs'))
  Assert-True ($setupSource -match 'users,\s*FileSystemRights\.ReadAndExecute' -and $setupSource -match 'admins,\s*FileSystemRights\.FullControl' -and $setupSource -match 'system,\s*FileSystemRights\.FullControl') 'installed-tree ACL policy no longer grants Admin/SYSTEM full and Users read/execute'
  Assert-True ($setupSource -match 'Layout=PermanentAnchor' -and $setupSource -match 'LABEL_SECURITY_INFORMATION' -and
    $setupSource -match 'AnchorNeverDelete=1') 'permanent-anchor identity/MIC verification is missing'
  Assert-True ($setupSource -match 'Directory\.CreateDirectory\(anchor, acl\)' -and
    $setupSource -match 'pre-create race') 'custom anchor is no longer created with atomic ACL plus post-create race validation'
  Assert-True ($setupSource -match '/originsid=' -and $setupSource -match 'GetShellWindow' -and
    $setupSource -match 'TokenIntegrityLevel' -and $setupSource -match 'IsSupportedDesktopShellIntegrity' -and
    $setupSource -match 'childIntegrityRid != expectedIntegrityRid') `
    'setup no longer binds automatic launch to the original user and exact supported desktop token'

  $case = Join-Path $testBase 'transaction'
  $pf = Join-Path $case 'PF'
  [string]$dest = Join-Path $pf 'DeltaForceBooster'
  Set-TestPaths $case $pf
  Remove-Item Env:DFB_TEST_INSECURE_PREFIX,Env:DFB_TEST_INSTALL_FAIL_AT -ErrorAction SilentlyContinue

  $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case 'install.log')`"")
  Assert-True ($code -eq 0) "fresh install exit=$code"
  $identity = Join-Path $dest 'install.identity'
  Assert-True (Test-Path -LiteralPath $identity) 'identity missing'
  $expectedPayload = @(
    'DISCLAIMER.md','LICENSE','NOTICE.md','README.md','SKILL.md','install.identity',
    'data\streamer-settings.json','EngineHost.exe','UninstallHost.exe','gui\app.ico','gui\DeltaForceBooster-GUI.ps1',
    'scripts\delta-booster.ps1','scripts\diagnose.ps1','scripts\hardware-sensors.ps1','scripts\telemetry-client.ps1','scripts\tuning-experiment.ps1','scripts\updater.ps1','scripts\user-context-worker.ps1',
    'tools\BlackSharp.Core.dll','tools\DeltaForce-Recommended.nip','tools\DiskInfoToolkit.dll','tools\HidSharp.dll',
    'tools\LibreHardwareMonitor-LICENSE.txt','tools\LibreHardwareMonitor-THIRD-PARTY-NOTICES.txt','tools\LibreHardwareMonitorLib.dll',
    'tools\PawnIO-LICENSE.txt','tools\PawnIO_setup.exe','tools\PresentMon-LICENSE.txt','tools\PresentMon.exe','tools\RAMSPDToolkit-NDD.dll',
    'tools\System.Buffers.dll','tools\System.Memory.dll','tools\System.Numerics.Vectors.dll','tools\System.Runtime.CompilerServices.Unsafe.dll',
    '启动优化工具.bat','启动优化工具.exe','卸载.bat','卸载.exe','uninstall.ps1'
  ) | Sort-Object
  $destPrefix = [IO.Path]::GetFullPath($dest).TrimEnd('\') + '\'
  $actualPayload = @(Get-ChildItem -LiteralPath $dest -Recurse -File | ForEach-Object {
    $_.FullName.Substring($destPrefix.Length)
  } | Sort-Object)
  $payloadDiff = @(Compare-Object $expectedPayload $actualPayload)
  Assert-True ($payloadDiff.Count -eq 0) ('installed payload differs from whitelist: ' + ($payloadDiff | Out-String))
  Assert-True ((Get-FileHash -LiteralPath (Join-Path $dest 'scripts\delta-booster.ps1') -Algorithm SHA256).Hash -eq
    (Get-FileHash -LiteralPath (Join-Path $root 'scripts\delta-booster.ps1') -Algorithm SHA256).Hash) `
    'installed engine payload differs from the locally tested RequestFile fix'
  $uninstallText = [IO.File]::ReadAllText((Join-Path $dest 'uninstall.ps1'))
  Assert-True ($uninstallText -notmatch '是否保留优化备份') 'ordinary uninstall still offers protected-backup deletion'
  Assert-True ($uninstallText -notmatch 'Remove-TreeNoFollow\s+\$protectedBackup') 'ordinary uninstall can still recursively delete protected backups'
  Assert-True ($uninstallText -notmatch '\$backupDeleteFailed|已按选择清理 ProgramData') 'obsolete protected-backup deletion branch remains'
  Assert-True ($uninstallText -match '普通卸载始终保留受保护备份' -and
    $uninstallText -match '重新安装本工具后仍可点击「还原设置」') 'uninstall does not explain retained-backup recovery'
  Assert-True ($uninstallText -match 'Test-CustomAnchor' -and $uninstallText -match 'Dfb\.AnchorLabel' -and
    $uninstallText -match 'AnchorNeverDelete=1') 'uninstall does not revalidate permanent custom anchor/MIC'
  Assert-True ($uninstallText -notmatch 'Remove-TreeNoFollow\s+\$customAnchor' -and
    $uninstallText -match '已保留其他盘永久安装锚点') 'uninstall can delete or fails to retain custom anchor'
  Assert-True ($uninstallText -notmatch '-Verb\s+RunAs' -and $uninstallText -match 'Wait-VerifiedProcessExit' -and
    $uninstallText -match '\[Parameter\(Mandatory\)\]\[string\]\$InstallRoot') `
    'uninstall script still creates a PowerShell UAC boundary or runs from the product root'
  $uninstallHostInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $dest 'UninstallHost.exe'))
  Assert-True ($uninstallHostInfo.FileDescription -eq '三角洲行动优化助手 卸载助手') `
    'UninstallHost FileDescription is not the UAC-facing product name'
  $lines = [IO.File]::ReadAllLines($identity)
  $sha = (Get-FileHash (Join-Path $dest '启动优化工具.exe') -Algorithm SHA256).Hash
  $hostSha = (Get-FileHash (Join-Path $dest 'EngineHost.exe') -Algorithm SHA256).Hash
  Assert-True ($lines.Count -eq 4 -and $lines[0] -ceq 'SchemaVersion=2' -and
    $lines[2] -eq "LauncherSha256=$sha" -and $lines[3] -eq "EngineHostSha256=$hostSha") `
    'identity/launcher/EngineHost hash mismatch'

  $otsSentinel = 'OTS-OLD-VERSION'
  [IO.File]::WriteAllText((Join-Path $dest 'README.md'), $otsSentinel, [Text.UTF8Encoding]::new($false))
  $otsLog = Join-Path $case 'ots-runafter.log'
  $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", '/runafter',
    '/originsid=S-1-5-21-1-2-3-1001', "/log=`"$otsLog`"")
  Assert-True ($code -eq 1) "OTS run-after rollback exit=$code"
  $otsText = [IO.File]::ReadAllText($otsLog)
  Assert-True ($otsText -like '*已跳过自动启动*' -and $otsText -like '*启动验证被跳过，已恢复旧版*') `
    'OTS /runafter did not roll back when startup validation was skipped'
  Assert-True ([IO.File]::ReadAllText((Join-Path $dest 'README.md')) -eq $otsSentinel) `
    'OTS /runafter did not restore the exact old install tree'
  Assert-True (@(Get-ChildItem $pf -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-pending-*').Count -eq 0) `
    'skipped run-after rollback left a pending old version'

  # Restore the valid packaged payload before the remaining integrity tests.
  [IO.File]::Copy((Join-Path $root 'README.md'), (Join-Path $dest 'README.md'), $true)

  $launcherBytes = [IO.File]::ReadAllBytes((Join-Path $dest '启动优化工具.exe'))
  $launcherAssembly = [Reflection.Assembly]::Load($launcherBytes)
  $launcherType = $launcherAssembly.GetType('Launcher', $true)
  $activeMarkerField = $launcherType.GetField('ActiveMarkerName', [Reflection.BindingFlags]'Static,NonPublic')
  $instanceMarkerField = $launcherType.GetField('InstanceMarkerName', [Reflection.BindingFlags]'Static,NonPublic')
  $activateExisting = $launcherType.GetMethod('TryActivateExistingWindow', [Reflection.BindingFlags]'Static,NonPublic')
  $createSessionMarker = $launcherType.GetMethod('CreateSessionMarker', [Reflection.BindingFlags]'Static,NonPublic')
  Assert-True ($activeMarkerField -and $instanceMarkerField -and $activateExisting -and
    $createSessionMarker -and
    $activeMarkerField.GetRawConstantValue() -eq 'Global\DeltaForceBooster.LaunchSession' -and
    $instanceMarkerField.GetRawConstantValue() -eq 'Local\DeltaForceBooster.LaunchInstance') `
    'compiled launcher lost the separate global lifecycle/current-session instance markers or activation path'
  # Reproduce the multi-user failure without creating another account: the first handle exposes only
  # Synchronize/Modify, so a second Mutex(..., MutexSecurity) FullControl open is denied. The launcher
  # must reopen with the rights actually granted instead of reporting this as a duplicate instance.
  $limitedMarkerName = 'Local\DeltaForceBooster.Tests.' + [guid]::NewGuid().ToString('N')
  $limitedMarkerAcl = New-Object Security.AccessControl.MutexSecurity
  $limitedMarkerAcl.SetAccessRuleProtection($true, $false)
  $limitedMarkerRights = [Security.AccessControl.MutexRights]::Synchronize -bor [Security.AccessControl.MutexRights]::Modify
  $limitedMarkerAcl.AddAccessRule((New-Object Security.AccessControl.MutexAccessRule(
    [Security.Principal.WindowsIdentity]::GetCurrent().User, $limitedMarkerRights,
    [Security.AccessControl.AccessControlType]::Allow)))
  $limitedMarkerCreated = $false
  $limitedMarkerOwner = New-Object Threading.Mutex($false, $limitedMarkerName, [ref]$limitedMarkerCreated, $limitedMarkerAcl)
  try {
    $markerInvokeArgs = New-Object 'object[]' 2
    $markerInvokeArgs[0] = $limitedMarkerName; $markerInvokeArgs[1] = $false
    $limitedMarkerOpened = [Threading.Mutex]$createSessionMarker.Invoke($null, $markerInvokeArgs)
    try {
      Assert-True ($limitedMarkerOpened -and -not [bool]$markerInvokeArgs[1]) `
        'launcher treated a limited-ACL existing marker as a new marker or failed to reopen it'
    } finally { if ($limitedMarkerOpened) { $limitedMarkerOpened.Dispose() } }
  } finally { $limitedMarkerOwner.Dispose() }
  $validateFiles = $launcherType.GetMethod('ValidateFiles', [Reflection.BindingFlags]'Static,NonPublic')
  $invokeArgs = New-Object 'object[]' 1; $invokeArgs[0] = $dest
  Assert-True ($null -eq $validateFiles.Invoke($null, $invokeArgs)) 'launcher rejected intact payload'
  $updater = Join-Path $dest 'scripts\updater.ps1'
  $updaterBytes = [IO.File]::ReadAllBytes($updater)
  try {
    $append = [IO.FileStream]::new($updater, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $append.WriteByte(10); $append.Flush($true) } finally { $append.Dispose() }
    $integrityError = [string]$validateFiles.Invoke($null, $invokeArgs)
    Assert-True ($integrityError -like 'scripts\updater.ps1*完整性校验失败*') 'launcher accepted a modified updater'
  } finally { [IO.File]::WriteAllBytes($updater, $updaterBytes) }

  $tuningModule = Join-Path $dest 'scripts\tuning-experiment.ps1'
  $tuningBytes = [IO.File]::ReadAllBytes($tuningModule)
  try {
    $append = [IO.FileStream]::new($tuningModule, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $append.WriteByte(10); $append.Flush($true) } finally { $append.Dispose() }
    $integrityError = [string]$validateFiles.Invoke($null, $invokeArgs)
    Assert-True ($integrityError -like 'scripts\tuning-experiment.ps1*完整性校验失败*') 'launcher accepted a modified tuning rules module'
  } finally { [IO.File]::WriteAllBytes($tuningModule, $tuningBytes) }

  # The released launcher sets the GUI CWD to the product root.  Old GUIs pass that CWD to setup,
  # and an ordinary performance worker can leave an orphaned product PresentMon with the same CWD.
  # The new installer must release its own inherited lock, stop only that verified product helper,
  # wait for it, and then complete the directory transaction.
  $productPresentMon = $null
  $oldGui = $null
  $productPresentMonPath = Join-Path $dest 'tools\PresentMon.exe'
  New-TestLockingPresentMon $productPresentMonPath
  try {
    $productPresentMon = Start-Process -FilePath $productPresentMonPath -WorkingDirectory $dest `
      -ArgumentList "`"$dest`"" -PassThru
    $oldGui = Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe') `
      -WorkingDirectory $dest -WindowStyle Hidden -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 2') -PassThru
    Start-Sleep -Milliseconds 300
    Assert-True (-not $productPresentMon.HasExited) 'product PresentMon lock fixture exited early'
    Assert-True (-not $oldGui.HasExited) 'old GUI waitpid fixture exited before setup started'
    $productLockLog = Join-Path $case 'product-presentmon-lock.log'
    $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/waitpid=$($oldGui.Id)", "/log=`"$productLockLog`"") $dest
    Assert-True ($code -eq 0) "product PresentMon/CWD update exit=$code"
    Assert-True ($oldGui.HasExited) 'installer did not wait for the old GUI fixture to exit'
    Assert-True ($productPresentMon.WaitForExit(5000)) 'installer did not stop product PresentMon'
    Assert-True ((Get-Content $productLockLog -Raw) -like '*更新前已停止旧版性能采样进程：1 个*') 'installer did not log product PresentMon cleanup'
    Assert-True ((Get-FileHash $productPresentMonPath -Algorithm SHA256).Hash -eq
      (Get-FileHash (Join-Path $root 'tools\PresentMon.exe') -Algorithm SHA256).Hash) 'update did not restore released PresentMon payload'
  } finally {
    if ($oldGui -and -not $oldGui.HasExited) { $oldGui.Kill(); $oldGui.WaitForExit() }
    if ($oldGui) { $oldGui.Dispose() }
    if ($productPresentMon -and -not $productPresentMon.HasExited) {
      $productPresentMon.Kill(); $productPresentMon.WaitForExit()
    }
    if ($productPresentMon) { $productPresentMon.Dispose() }
  }

  # A same-named executable outside the verified product path is not ours to terminate.  Give it
  # the product root as CWD to create a permanent unknown lock: install must fail before moving the
  # old tree, leave the foreign process alive, and preserve all existing files/user data.
  [IO.Directory]::CreateDirectory((Join-Path $case 'external')) | Out-Null
  $externalPresentMonPath = Join-Path $case 'external\PresentMon.exe'
  New-TestLockingPresentMon $externalPresentMonPath
  [IO.Directory]::CreateDirectory((Join-Path $dest 'config')) | Out-Null
  $foreignMarker = Join-Path $dest 'config\foreign-lock-marker.json'
  [IO.File]::WriteAllText($foreignMarker, '{"keep":true}')
  $beforeForeignLock = (Get-FileHash (Join-Path $dest '启动优化工具.exe') -Algorithm SHA256).Hash
  $externalPresentMon = $null
  try {
    $externalPresentMon = Start-Process -FilePath $externalPresentMonPath -WorkingDirectory $dest `
      -ArgumentList "`"$dest`"" -PassThru
    Start-Sleep -Milliseconds 300
    Assert-True (-not $externalPresentMon.HasExited) 'external PresentMon lock fixture exited early'
    $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case 'external-presentmon-lock.log')`"")
    Assert-True ($code -eq 1) "foreign PresentMon lock was not fail-closed (exit=$code)"
    Assert-True (-not $externalPresentMon.HasExited) 'installer terminated a same-named process outside the product path'
    Assert-True ((Get-FileHash (Join-Path $dest '启动优化工具.exe') -Algorithm SHA256).Hash -eq $beforeForeignLock) 'foreign lock changed old launcher'
    Assert-True ((Test-Path -LiteralPath $foreignMarker -PathType Leaf) -and
      ([IO.File]::ReadAllText($foreignMarker) -eq '{"keep":true}')) 'foreign lock lost existing user data'
    Assert-True (@(Get-ChildItem -LiteralPath $pf -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-*').Count -eq 0) `
      'foreign lock left a transaction directory'
  } finally {
    if ($externalPresentMon -and -not $externalPresentMon.HasExited) {
      $externalPresentMon.Kill(); $externalPresentMon.WaitForExit()
    }
    if ($externalPresentMon) { $externalPresentMon.Dispose() }
  }

  # 正式 v0.19.4 已有 install.identity，但 payload 还没有 tuning-experiment.ps1。
  # 该受保护 Program Files 形态必须能凭 identity→launcher hash 和版本链原地升级。
  [void][IO.Directory]::CreateDirectory((Join-Path $dest 'config'))
  [IO.File]::WriteAllText((Join-Path $dest 'config\identity-marker.json'), '{"keep":true}')
  Convert-ToHistoricalIdentityFixture $dest
  $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case 'identity-0194.log')`"")
  Assert-True ($code -eq 0) "v0.19.4 identity-root update exit=$code"
  Assert-True (Test-Path -LiteralPath (Join-Path $dest 'scripts\tuning-experiment.ps1') -PathType Leaf) 'current tuning module not restored after identity-root update'
  Assert-True (Test-Path -LiteralPath (Join-Path $dest 'config\identity-marker.json') -PathType Leaf) 'identity-root user data not preserved'

  $unknown = Join-Path $pf 'Important'
  [void][IO.Directory]::CreateDirectory($unknown)
  [IO.File]::WriteAllText((Join-Path $unknown 'secret.txt'), 'keep')
  $code = Invoke-TestSetup @('/silent', "/dir=`"$unknown`"", "/log=`"$(Join-Path $case 'unknown.log')`"")
  Assert-True ($code -eq 2) "unknown nonempty exit=$code"
  Assert-True ((Get-Content (Join-Path $unknown 'secret.txt') -Raw) -eq 'keep') 'unknown target changed'

  $junctionTarget = Join-Path $case 'junction-target'
  $junction = Join-Path $pf 'LinkedParent'
  [void][IO.Directory]::CreateDirectory($junctionTarget)
  [IO.File]::WriteAllText((Join-Path $junctionTarget 'sentinel.txt'), 'keep')
  $cmd = Join-Path ([Environment]::SystemDirectory) 'cmd.exe'
  & $cmd /d /c "mklink /J `"$junction`" `"$junctionTarget`"" | Out-Null
  Assert-True ($LASTEXITCODE -eq 0 -and ((Get-Item -LiteralPath $junction -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) 'failed to create junction fixture'
  try {
    $linkedDest = Join-Path $junction 'DeltaForceBooster'
    $code = Invoke-TestSetup @('/silent', "/dir=`"$linkedDest`"", "/log=`"$(Join-Path $case 'reparse.log')`"")
    Assert-True ($code -ne 0) "reparse target unexpectedly accepted (exit=$code)"
    Assert-True ((Get-Content (Join-Path $junctionTarget 'sentinel.txt') -Raw) -eq 'keep') 'reparse target changed'
    Assert-True (-not (Test-Path (Join-Path $junctionTarget 'DeltaForceBooster'))) 'installer followed reparse target'
  } finally {
    if (Test-Path -LiteralPath $junction) { [IO.Directory]::Delete($junction, $false) }
  }

  [void][IO.Directory]::CreateDirectory((Join-Path $dest 'config'))
  [IO.File]::WriteAllText((Join-Path $dest 'config\marker.json'), '{"keep":true}')
  $before = (Get-FileHash (Join-Path $dest '启动优化工具.exe')).Hash
  foreach ($point in 'after-extract','after-old-move','after-new-move') {
    $env:DFB_TEST_INSTALL_FAIL_AT = $point
    $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case "$point.log")`"")
    Assert-True ($code -eq 1) "$point exit=$code"
    Assert-True (Test-Path (Join-Path $dest 'config\marker.json')) "$point marker lost"
    Assert-True ((Get-FileHash (Join-Path $dest '启动优化工具.exe')).Hash -eq $before) "$point changed old launcher"
    Assert-True (@(Get-ChildItem $pf -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-*').Count -eq 0) "$point left transaction directory"
  }
  Remove-Item Env:DFB_TEST_INSTALL_FAIL_AT -ErrorAction SilentlyContinue

  # CreateProcess 成功不等于新版能打开。测试构建在窗口健康检查处注入失败，安装器必须
  # 把尚未提交的旧目录恢复回来，而不是留下“更新完成但软件上不去”的状态。
  $oldReadme = Join-Path $dest 'README.md'
  [IO.File]::WriteAllText($oldReadme, 'OLD-STARTUP-HEALTH', (New-Object Text.UTF8Encoding($false)))
  $healthLog = Join-Path $case 'startup-health-failure.log'
  $env:DFB_TEST_STARTUP_HEALTH_FAIL = '1'
  try {
    $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", '/runafter', "/originsid=$currentUserSid", "/log=`"$healthLog`"")
  } finally { Remove-Item Env:DFB_TEST_STARTUP_HEALTH_FAIL -ErrorAction SilentlyContinue }
  Assert-True ($code -eq 1) "startup health failure exit=$code"
  Assert-True ([IO.File]::ReadAllText($oldReadme) -eq 'OLD-STARTUP-HEALTH') 'startup health failure did not restore exact old tree'
  Assert-True (([IO.File]::ReadAllText($healthLog)) -like '*启动验证失败，已恢复旧版*') 'startup health rollback was not logged'
  Assert-True (@(Get-ChildItem $pf -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-*').Count -eq 0) `
    'startup health rollback left a transaction directory'

  # 模拟安装器在“目录已切换、启动验证尚未提交”时崩溃。下一次安装先恢复 pending 旧版；
  # 随后在新一轮 after-extract 注入失败，最终落盘内容必须仍是旧树。
  $installDeferred = $installerType.GetMethod('InstallForLaunchValidation', [Reflection.BindingFlags]'Static,Public')
  $deferredArgs = New-Object 'object[]' 3
  $deferredArgs[0] = $dest; $deferredArgs[1] = $null; $deferredArgs[2] = $null
  [void]$installDeferred.Invoke($null, $deferredArgs)
  Assert-True (@(Get-ChildItem $pf -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-pending-*').Count -eq 1) `
    'deferred install did not retain one pending old version'
  Assert-True ([IO.File]::ReadAllText($oldReadme) -ne 'OLD-STARTUP-HEALTH') 'deferred install did not switch to the new tree'
  $env:DFB_TEST_INSTALL_FAIL_AT = 'after-extract'
  try { $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case 'pending-recovery.log')`"") }
  finally { Remove-Item Env:DFB_TEST_INSTALL_FAIL_AT -ErrorAction SilentlyContinue }
  Assert-True ($code -eq 1) "pending recovery follow-up exit=$code"
  Assert-True ([IO.File]::ReadAllText($oldReadme) -eq 'OLD-STARTUP-HEALTH') 'interrupted pending update did not restore old tree first'
  Assert-True (@(Get-ChildItem $pf -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-*').Count -eq 0) `
    'interrupted pending recovery left a transaction directory'

  $id = [guid]::NewGuid().ToString('N')
  $rollback = Join-Path $pf ".DeltaForceBooster.dfb-rollback-$id"
  Move-Item -LiteralPath $dest -Destination $rollback
  $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case 'recovery.log')`"")
  Assert-True ($code -eq 0) "interrupted rollback recovery exit=$code"
  Assert-True ((Test-Path (Join-Path $dest 'config\marker.json')) -and -not (Test-Path $rollback)) 'rollback recovery failed'

  $staleRollback = Join-Path $pf ('.DeltaForceBooster.dfb-rollback-' + [guid]::NewGuid().ToString('N'))
  $staleStage = Join-Path $pf ('.DeltaForceBooster.dfb-stage-' + [guid]::NewGuid().ToString('N'))
  Copy-Item -LiteralPath $dest -Destination $staleRollback -Recurse
  Copy-Item -LiteralPath $dest -Destination $staleStage -Recurse
  $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case 'stale-cleanup.log')`"")
  Assert-True ($code -eq 0) "stale transaction cleanup exit=$code"
  Assert-True (-not (Test-Path $staleRollback)) 'completed-install rollback was not cleaned'
  Assert-True (-not (Test-Path $staleStage)) 'completed staging was not cleaned'

  # Other-drive layout: the user-facing install root is a permanent first-level anchor; code and
  # every transaction live under anchor\app.  A GUI update passes the physical app path back.
  $customCase = Join-Path $testBase 'custom-anchor'
  $customPf = Join-Path $customCase 'PF'
  $customVolume = Join-Path $customCase 'volume'
  [void][IO.Directory]::CreateDirectory($customVolume)
  Set-TestPaths $customCase $customPf
  $env:DFB_TEST_CUSTOM_DRIVE_ROOT = $customVolume
  $anchor = Join-Path $customVolume 'DeltaForceBooster'
  $appRoot = Join-Path $anchor 'app'
  $customLog = Join-Path $customCase 'install.log'
  $code = Invoke-TestSetup @('/silent', "/dir=`"$anchor`"", "/log=`"$customLog`"")
  Assert-True ($code -eq 0) "custom-anchor fresh install exit=$code"
  Assert-True (Test-Path -LiteralPath (Join-Path $anchor 'anchor.identity') -PathType Leaf) 'custom anchor identity missing'
  Assert-True (Test-Path -LiteralPath (Join-Path $appRoot '启动优化工具.exe') -PathType Leaf) 'custom physical app root missing'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $anchor '启动优化工具.exe'))) 'payload leaked into logical anchor root'
  $anchorLines = [IO.File]::ReadAllLines((Join-Path $anchor 'anchor.identity'))
  Assert-True ($anchorLines.Count -eq 6 -and $anchorLines[0] -ceq 'SchemaVersion=1' -and
    $anchorLines[2] -ceq 'Layout=PermanentAnchor' -and $anchorLines[3] -ceq 'CodeDirectory=app' -and
    $anchorLines[4] -cmatch '^AnchorId=[0-9a-f]{32}$' -and $anchorLines[5] -ceq 'AnchorNeverDelete=1') 'custom anchor identity format mismatch'
  $codeRootMethod = $installerType.GetMethod('CodeRootForInstall', [Reflection.BindingFlags]'Static,Public')
  $displayRootMethod = $installerType.GetMethod('InstallRootForDisplay', [Reflection.BindingFlags]'Static,Public')
  $layoutArgs = New-Object 'object[]' 1; $layoutArgs[0] = [string]$anchor
  Assert-True ([string]$codeRootMethod.Invoke($null, $layoutArgs) -eq $appRoot) 'logical anchor did not resolve to app root'
  $layoutArgs[0] = [string]$appRoot
  Assert-True ([string]$codeRootMethod.Invoke($null, $layoutArgs) -eq $appRoot) 'physical app /dir was not normalized'
  Assert-True ([string]$displayRootMethod.Invoke($null, $layoutArgs) -eq $anchor) 'physical app /dir was not normalized back to its logical anchor'

  [void][IO.Directory]::CreateDirectory((Join-Path $appRoot 'config'))
  $customMarker = Join-Path $appRoot 'config\custom-marker.json'
  [IO.File]::WriteAllText($customMarker, '{"keep":true}')
  $unknownSibling = Join-Path $anchor 'administrator-note.txt'
  [IO.File]::WriteAllText($unknownSibling, 'keep-anchor')
  $code = Invoke-TestSetup @('/silent', "/dir=`"$appRoot`"", "/log=`"$(Join-Path $customCase 'physical-update.log')`"")
  Assert-True ($code -eq 0) "custom physical-app update exit=$code"
  Assert-True ((Test-Path -LiteralPath $customMarker) -and ([IO.File]::ReadAllText($customMarker) -eq '{"keep":true}')) 'custom app update lost user data'
  Assert-True ([IO.File]::ReadAllText($unknownSibling) -eq 'keep-anchor') 'custom update deleted an unknown anchor sibling'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $customPf 'DeltaForceBooster'))) 'verified custom app was migrated back to Program Files'

  $customBefore = (Get-FileHash -LiteralPath (Join-Path $appRoot '启动优化工具.exe')).Hash
  foreach ($point in 'after-extract','after-old-move') {
    $env:DFB_TEST_INSTALL_FAIL_AT = $point
    $code = Invoke-TestSetup @('/silent', "/dir=`"$appRoot`"", "/log=`"$(Join-Path $customCase "$point.log")`"")
    Assert-True ($code -eq 1) "custom $point exit=$code"
    Assert-True (Test-Path -LiteralPath $anchor -PathType Container) "custom $point removed permanent anchor"
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $appRoot '启动优化工具.exe')).Hash -eq $customBefore) "custom $point changed old launcher"
    Assert-True (@(Get-ChildItem -LiteralPath $anchor -Force | Where-Object Name -Like '.app.dfb-*').Count -eq 0) "custom $point left transaction directory"
    Assert-True (@(Get-ChildItem -LiteralPath $customVolume -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-*').Count -eq 0) "custom $point created a volume-root transaction"
  }
  Remove-Item Env:DFB_TEST_INSTALL_FAIL_AT -ErrorAction SilentlyContinue

  $customRollbackId = [guid]::NewGuid().ToString('N')
  $customRollback = Join-Path $anchor ".app.dfb-rollback-$customRollbackId"
  Move-Item -LiteralPath $appRoot -Destination $customRollback
  $code = Invoke-TestSetup @('/silent', "/dir=`"$anchor`"", "/log=`"$(Join-Path $customCase 'recovery.log')`"")
  Assert-True ($code -eq 0) "custom rollback recovery exit=$code"
  Assert-True ((Test-Path -LiteralPath $customMarker) -and -not (Test-Path -LiteralPath $customRollback)) 'custom rollback recovery failed'

  # 单机现场回归：永久 anchor 仍有效，但安全软件/中断使 app 缺少启动器。向导预检应允许
  # 保留式修复；旧树必须原样留在 anchor 内，普通目录的严格身份检查不得被放宽。
  $customLauncher = Join-Path $appRoot '启动优化工具.exe'
  Remove-Item -LiteralPath $customLauncher -Force
  $checkWritable = $installerType.GetMethod('CheckWritable', [Reflection.BindingFlags]'Static,Public')
  $writableArgs = New-Object 'object[]' 1; $writableArgs[0] = [string]$appRoot
  Assert-True ($null -eq $checkWritable.Invoke($null, $writableArgs)) 'verified custom anchor rejected repairable damaged app during preflight'
  $repairLog = Join-Path $customCase 'damaged-repair.log'
  $code = Invoke-TestSetup @('/silent', "/dir=`"$appRoot`"", '/runafter', "/originsid=$currentUserSid", "/log=`"$repairLog`"")
  Assert-True ($code -eq 0) "damaged custom app repair exit=$code"
  Assert-True (Test-Path -LiteralPath $customLauncher -PathType Leaf) 'damaged custom app launcher was not restored'
  Assert-True ((Test-Path -LiteralPath $customMarker) -and ([IO.File]::ReadAllText($customMarker) -eq '{"keep":true}')) 'damaged custom app repair lost user data'
  $damagedCopies = @(Get-ChildItem -LiteralPath $anchor -Force | Where-Object Name -Like '.app.dfb-damaged-*')
  Assert-True ($damagedCopies.Count -eq 1) 'damaged custom app was not retained exactly once'
  Assert-True ((Test-Path -LiteralPath (Join-Path $damagedCopies[0].FullName 'config\custom-marker.json')) -and
    -not (Test-Path -LiteralPath (Join-Path $damagedCopies[0].FullName '启动优化工具.exe'))) 'retained damaged app does not match the original state'
  Assert-True (([IO.File]::ReadAllText($repairLog)) -like '*残缺目录原样保留在*') 'damaged custom app repair was not logged'

  # 默认安装流程会启动新版并等窗口就绪；健康检查失败时也必须恢复安装前的残缺现场。
  Remove-Item -LiteralPath $customLauncher -Force
  $env:DFB_TEST_STARTUP_HEALTH_FAIL = '1'
  try {
    $code = Invoke-TestSetup @('/silent', "/dir=`"$appRoot`"", '/runafter', "/originsid=$currentUserSid",
      "/log=`"$(Join-Path $customCase 'damaged-startup-failure.log')`"")
  } finally { Remove-Item Env:DFB_TEST_STARTUP_HEALTH_FAIL -ErrorAction SilentlyContinue }
  Assert-True ($code -eq 1) "damaged custom app startup rollback exit=$code"
  Assert-True (-not (Test-Path -LiteralPath $customLauncher)) 'startup rollback did not restore the original damaged app'
  Assert-True ([IO.File]::ReadAllText($customMarker) -eq '{"keep":true}') 'startup rollback lost damaged-app user data'

  # 安全软件若在新树切入后再次隔离启动器，回滚仍须成功；这棵再次损坏的新版只保留，
  # 不按完整产品目录递归删除。
  $damagedDeferredArgs = New-Object 'object[]' 3
  $damagedDeferredArgs[0] = [string]$appRoot; $damagedDeferredArgs[1] = $null; $damagedDeferredArgs[2] = $null
  $damagedReceipt = $installDeferred.Invoke($null, $damagedDeferredArgs)
  Remove-Item -LiteralPath $customLauncher -Force
  $rollbackDeferred = $installerType.GetMethod('RollbackDeferredInstall', [Reflection.BindingFlags]'Static,Public')
  $rollbackArgs = New-Object 'object[]' 1; $rollbackArgs[0] = $damagedReceipt
  [void]$rollbackDeferred.Invoke($null, $rollbackArgs)
  Assert-True (-not (Test-Path -LiteralPath $customLauncher)) 'second launcher quarantine blocked restoration of the original damaged app'
  Assert-True (@(Get-ChildItem -LiteralPath $anchor -Force | Where-Object Name -Like '.app.dfb-stage-*').Count -eq 1) `
    'secondarily damaged new tree was not retained for diagnosis'

  # 新树切入后若事务失败，必须把残缺现场恢复到原 app，而不是留下半次修复。
  $env:DFB_TEST_INSTALL_FAIL_AT = 'after-new-move'
  try { $code = Invoke-TestSetup @('/silent', "/dir=`"$appRoot`"", "/log=`"$(Join-Path $customCase 'damaged-repair-failure.log')`"") }
  finally { Remove-Item Env:DFB_TEST_INSTALL_FAIL_AT -ErrorAction SilentlyContinue }
  Assert-True ($code -eq 1) "damaged custom app rollback exit=$code"
  Assert-True (-not (Test-Path -LiteralPath $customLauncher)) 'failed damaged repair did not restore the original missing-launcher state'
  Assert-True ([IO.File]::ReadAllText($customMarker) -eq '{"keep":true}') 'failed damaged repair lost original user data'
  $code = Invoke-TestSetup @('/silent', "/dir=`"$appRoot`"", "/log=`"$(Join-Path $customCase 'damaged-repair-final.log')`"")
  Assert-True ($code -eq 0 -and (Test-Path -LiteralPath $customLauncher -PathType Leaf)) 'custom app did not recover after the injected repair failure'

  $anchorIdentity = Join-Path $anchor 'anchor.identity'
  $anchorIdentityBytes = [IO.File]::ReadAllBytes($anchorIdentity)
  try {
    [IO.File]::WriteAllText($anchorIdentity, 'not-an-anchor')
    $code = Invoke-TestSetup @('/silent', "/dir=`"$appRoot`"", "/log=`"$(Join-Path $customCase 'bad-anchor.log')`"")
    Assert-True ($code -ne 0) "corrupt anchor identity was accepted (exit=$code)"
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $appRoot '启动优化工具.exe')).Hash -eq $customBefore) 'corrupt anchor identity changed app tree'
  } finally { [IO.File]::WriteAllBytes($anchorIdentity, $anchorIdentityBytes) }

  $unrelated = Join-Path $customVolume 'Important'
  [void][IO.Directory]::CreateDirectory($unrelated)
  [IO.File]::WriteAllText((Join-Path $unrelated 'secret.txt'), 'keep')
  $code = Invoke-TestSetup @('/silent', "/dir=`"$unrelated`"", "/log=`"$(Join-Path $customCase 'unrelated.log')`"")
  Assert-True ($code -ne 0) "unrelated nonempty root became an anchor (exit=$code)"
  Assert-True ([IO.File]::ReadAllText((Join-Path $unrelated 'secret.txt')) -eq 'keep') 'unrelated custom root changed'

  $case2 = Join-Path $testBase 'migration'
  $pf2 = Join-Path $case2 'PF'
  $downloads = Join-Path $case2 'Downloads'
  [void][IO.Directory]::CreateDirectory($downloads)
  Set-TestPaths $case2 $pf2

  # v0.20 首次加入 tuning-experiment.ps1/install.identity。真实 v0.18/v0.19 根没有
  # 这两个文件，仍应凭历史启动器版本 + 完整运行文件集迁移；同版本残缺根不能降级冒充 legacy。
  $notLegacy = Join-Path $downloads 'CurrentButIncomplete'
  Copy-Item -LiteralPath $dest -Destination $notLegacy -Recurse
  Remove-Item -LiteralPath (Join-Path $notLegacy 'install.identity') -Force
  Remove-Item -LiteralPath (Join-Path $notLegacy 'scripts\tuning-experiment.ps1') -Force
  [IO.File]::WriteAllText((Join-Path $notLegacy 'keep.txt'), 'same-version')
  $env:DFB_TEST_INSECURE_PREFIX = $notLegacy
  $code = Invoke-TestSetup @('/silent', "/dir=`"$notLegacy`"", "/log=`"$(Join-Path $case2 'same-version.log')`"")
  Assert-True ($code -eq 1) "same-version incomplete root exit=$code"
  Assert-True ((Get-Content (Join-Path $notLegacy 'keep.txt') -Raw) -eq 'same-version') 'same-version incomplete root changed'

  $lookalike = Join-Path $downloads 'Lookalike'
  foreach ($folder in $lookalike,(Join-Path $lookalike 'gui'),(Join-Path $lookalike 'scripts')) {
    [void][IO.Directory]::CreateDirectory($folder)
  }
  New-TestLegacyLauncher (Join-Path $lookalike '启动优化工具.exe')
  Copy-Item (Join-Path $dest 'gui\DeltaForceBooster-GUI.ps1') (Join-Path $lookalike 'gui\DeltaForceBooster-GUI.ps1')
  Copy-Item (Join-Path $dest 'scripts\delta-booster.ps1') (Join-Path $lookalike 'scripts\delta-booster.ps1')
  [IO.File]::WriteAllText((Join-Path $lookalike 'keep.txt'), 'lookalike')
  $env:DFB_TEST_INSECURE_PREFIX = $lookalike
  $code = Invoke-TestSetup @('/silent', "/dir=`"$lookalike`"", "/log=`"$(Join-Path $case2 'lookalike.log')`"")
  Assert-True ($code -eq 1) "partial lookalike root exit=$code"
  Assert-True ((Get-Content (Join-Path $lookalike 'keep.txt') -Raw) -eq 'lookalike') 'partial lookalike root changed'

  $legacyMatrices = @(
    @{ Gui = '0.18.0'; Launcher = '0.17.0' },
    @{ Gui = '0.19.0'; Launcher = '0.18.4' },
    @{ Gui = '0.19.1'; Launcher = '0.18.4' },
    @{ Gui = '0.19.3'; Launcher = '0.19.3' }
  )
  for ($n = 1; $n -le $legacyMatrices.Count; $n++) {
    $matrix = $legacyMatrices[$n - 1]
    $legacy = Join-Path $downloads "OldCustom$n"
    Copy-Item -LiteralPath $dest -Destination $legacy -Recurse
    Convert-ToLegacyInstallFixture $legacy $matrix.Gui $matrix.Launcher
    foreach ($folder in 'config','profiles') { [void][IO.Directory]::CreateDirectory((Join-Path $legacy $folder)) }
    [IO.File]::WriteAllText((Join-Path $legacy 'config\telemetry.json'), ('{"source":' + $n + '}'))
    [IO.File]::WriteAllText((Join-Path $legacy "profiles\profile$n.json"), ('{"name":"p' + $n + '"}'))
    # 最后一项不靠“不安全路径”钩子：父链位置本身可接受时，也必须根据旧版产品身份
    # 识别普通用户可写 legacy 树并迁往默认受保护目录。
    if ($n -eq $legacyMatrices.Count) { Remove-Item Env:DFB_TEST_INSECURE_PREFIX -ErrorAction SilentlyContinue }
    else { $env:DFB_TEST_INSECURE_PREFIX = $legacy }
    $migrationLog = Join-Path $case2 "migration$n.log"
    $migrationArgs = @('/silent', "/dir=`"$legacy`"", "/log=`"$migrationLog`"")
    if ($n -eq 1) { $migrationArgs += '/runafter' }
    $code = Invoke-TestSetup $migrationArgs
    Assert-True ($code -eq 0) "migration$n exit=$code"
    Assert-True (-not (Test-Path $legacy)) "legacy$n not quarantined"
    if ($n -eq 1) {
      $newLauncher = Join-Path $pf2 'DeltaForceBooster\启动优化工具.exe'
      Assert-True ((Get-Content $migrationLog -Raw) -like "*启动新版: 测试模式跳过启动: $newLauncher*") 'migrated update did not resolve the new launcher for run-after'
    }
  }
  $userRoot = Join-Path $env:DFB_TEST_LOCALAPPDATA 'DeltaForceBooster'
  Assert-True (Test-Path (Join-Path $userRoot 'config\telemetry.json')) 'config not migrated'
  foreach ($n in 1..$legacyMatrices.Count) {
    Assert-True (Test-Path (Join-Path $userRoot "profiles\profile$n.json")) "profile$n not migrated"
  }
  $inventory = Get-Content (Join-Path $env:DFB_TEST_PROGRAMDATA 'DeltaForceBooster\legacy-roots.json') -Raw | ConvertFrom-Json
  Assert-True ($inventory.SchemaVersion -eq 1 -and @($inventory.Roots).Count -eq $legacyMatrices.Count) 'inventory did not merge all legacy roots'
  Assert-True (@($inventory.Roots | Where-Object { (Split-Path $_ -Leaf) -notmatch '^\.DeltaForceBooster\.migrated-[0-9a-f]{32}$' }).Count -eq 0) 'inventory leaf mismatch'
  foreach ($legacyBackup in @($inventory.Roots)) {
    Assert-True (Test-Path -LiteralPath $legacyBackup -PathType Container) "legacy backup missing: $legacyBackup"
    Assert-True (Test-Path -LiteralPath (Join-Path $legacyBackup 'config\telemetry.json') -PathType Leaf) "legacy config not preserved: $legacyBackup"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $legacyBackup 'profiles') -Filter '*.json' -File).Count -eq 1) "legacy profiles not preserved: $legacyBackup"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $legacyBackup 'scripts\tuning-experiment.ps1'))) "legacy fixture unexpectedly contains v0.20 tuning module: $legacyBackup"
  }

  "PASS installer security: files=$(@(Get-ChildItem $dest -Recurse -File).Count), inventoryRoots=$(@($inventory.Roots).Count)"
} finally {
  Get-ChildItem Env:DFB_TEST_* -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item ("Env:" + $_.Name) -ErrorAction SilentlyContinue
  }
  if ($KeepArtifacts) { "artifacts: $testBase" }
  elseif (Test-Path $testBase) { Remove-Item -LiteralPath $testBase -Recurse -Force }
}
