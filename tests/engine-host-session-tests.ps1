#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'
$enginePath = Join-Path $root 'scripts\delta-booster.ps1'
$updaterPath = Join-Path $root 'scripts\updater.ps1'
$workerPath = Join-Path $root 'scripts\user-context-worker.ps1'
$hostBuildPath = Join-Path $root 'build\make-engine-host.ps1'
$launcherBuildPath = Join-Path $root 'build\make-launcher.ps1'
$installerBuildPath = Join-Path $root 'build\make-installer.ps1'
$uninstallBuildPath = Join-Path $root 'build\make-uninstall-host.ps1'
$runtimeRootPath = Join-Path $root 'build\runtime-root-validation.cs'
$tokenValidationPath = Join-Path $root 'build\token-validation.cs'
$uninstallHostSourcePath = Join-Path $root 'build\uninstall-host.cs'
$uninstallLauncherSourcePath = Join-Path $root 'build\uninstall-launcher.cs'
$batPath = Join-Path $root '启动优化工具.bat'
$winPs = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

function Read-Utf8([string]$Path) { [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }

function Parse-PowerShell([string]$Path) {
  $tokens = $null; $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
  Assert-True ($errors.Count -eq 0) ("PowerShell AST parse failed: $Path — " + (($errors | ForEach-Object Message) -join '; '))
  $ast
}

$guiAst = Parse-PowerShell $guiPath
$null = Parse-PowerShell $enginePath
$null = Parse-PowerShell $updaterPath
$null = Parse-PowerShell $workerPath
$null = Parse-PowerShell $hostBuildPath
$null = Parse-PowerShell $launcherBuildPath
$null = Parse-PowerShell $installerBuildPath
$null = Parse-PowerShell $uninstallBuildPath

$gui = Read-Utf8 $guiPath
$engine = Read-Utf8 $enginePath
$updater = Read-Utf8 $updaterPath
$worker = Read-Utf8 $workerPath
$hostBuild = Read-Utf8 $hostBuildPath
$launcherBuild = Read-Utf8 $launcherBuildPath
$installerBuild = Read-Utf8 $installerBuildPath
$uninstallBuild = Read-Utf8 $uninstallBuildPath
$runtimeRoot = Read-Utf8 $runtimeRootPath
$tokenValidation = Read-Utf8 $tokenValidationPath
$uninstallHostSource = Read-Utf8 $uninstallHostSourcePath
$uninstallLauncherSource = Read-Utf8 $uninstallLauncherSourcePath
$bat = Read-Utf8 $batPath

# UAC 边界与 full-lifetime session。
Assert-True ($hostBuild -match 'requestedExecutionLevel level="requireAdministrator"') 'EngineHost manifest is not requireAdministrator'
Assert-True ($launcherBuild -match 'requestedExecutionLevel level="asInvoker"') 'launcher manifest is not asInvoker'
Assert-True ($launcherBuild -match 'string hostPath = Path\.Combine\(root, "EngineHost\.exe"\)' -and
  $launcherBuild -match 'psi\.FileName = hostPath' -and
  $launcherBuild -match 'psi\.Verb = "runas"') 'launcher does not request UAC only for EngineHost'
Assert-True ($launcherBuild -match 'NativeErrorCode != 8235' -and
  $launcherBuild -match 'StartEngineHostWithPolicyFallback' -and
  $launcherBuild -match 'WindowsPowerShell", "v1\.0", "powershell\.exe"' -and
  $launcherBuild -match '-EncodedCommand') `
  'launcher does not recover ERROR_DS_REFERRAL with a fixed trusted PowerShell boundary'
Assert-True ($launcherBuild -match 'QuotePowerShellLiteral\(hostPath\)' -and
  $launcherBuild -match 'QuotePowerShellLiteral\(pipeName\)' -and
  $launcherBuild -match 'QuotePowerShellLiteral\(session\)') `
  'signed-policy fallback does not quote all fixed EngineHost launch values'
Assert-True ($hostBuild -match 'AssemblyTitle\("三角洲行动优化助手 管理员助手"\)') `
  'EngineHost UAC product description missing'
Assert-True ($launcherBuild.IndexOf('if (!createdNew)', [StringComparison]::Ordinal) -lt
  $launcherBuild.IndexOf('string validationError = ValidateFiles(root)', [StringComparison]::Ordinal)) `
  'second-launch marker is not checked before validation/UAC'
Assert-True ($launcherBuild -match 'DFB_ENGINE_DONE/1' -and $hostBuild -match 'DFB_ENGINE_DONE/1') `
  'launcher is not retained through the EngineHost/GUI lifetime'

# High PowerShell 环境必须在第一次模块自动加载/原生程序搜索前收紧。
$moduleOffset = $gui.IndexOf('$env:PSModulePath =', [StringComparison]::Ordinal)
$pathOffset = $gui.IndexOf('$env:PATH =', [StringComparison]::Ordinal)
$cimOffset = $gui.IndexOf('Get-CimInstance Win32_Process', [StringComparison]::Ordinal)
Assert-True ($moduleOffset -ge 0 -and $pathOffset -ge 0 -and $cimOffset -gt $moduleOffset -and $cimOffset -gt $pathOffset) `
  'GUI bootstrap can auto-load a user module before environment hardening'
Assert-True ($hostBuild -match 'EnvironmentVariables\.Clear\(\)' -and
  $hostBuild -match 'EnvironmentVariables\["TEMP"\] = sessionTemp' -and
  $hostBuild -match 'EnvironmentVariables\["PATH"\]' -and $hostBuild -match 'EnvironmentVariables\["COMSPEC"\]') `
  'EngineHost does not provide a protected temp/trusted native environment'
Assert-True ($launcherBuild -match 'EnterTrustedElevationEnvironment' -and
  $launcherBuild -match 'Environment\.SetEnvironmentVariable\(name, null' -and
  $hostBuild -notmatch 'EnvironmentVariables\["COR_|EnvironmentVariables\["COMPlus_|EnvironmentVariables\["DOTNET_') `
  'managed RunAs/high GUI environment can inherit CLR profiler or COMPlus injection variables'
Assert-True (-not ($gui -match 'Start-Process\s+[''"]?explorer\.exe') -and -not ($gui -match '-Verb\s+RunAs')) `
  'high GUI still launches explorer or creates a second UAC boundary'
Assert-True (-not ($updater -match '-Verb\s+RunAs')) 'updater still creates a PowerShell UAC prompt'

# OTS credentials: original account context travels over authenticated pipes; high state never lives in LocalAppData.
foreach ($needle in 'DFB_ORIGINAL_USER_SID','DFB_ORIGINAL_LOCALAPPDATA','GetNamedPipeServerProcessId','GetNamedPipeClientProcessId') {
  Assert-True ($hostBuild.Contains($needle) -or $launcherBuild.Contains($needle)) "authenticated OTS context element missing: $needle"
}
foreach ($needle in 'OpenProcessToken','TokenUser','TokenIntegrityLevel','TokenSessionId') {
  Assert-True $tokenValidation.Contains($needle) "launcher token binding element missing: $needle"
}
Assert-True ($hostBuild -match 'launcherToken\.Sid' -and $hostBuild -match 'launcherToken\.SessionId' -and
  $hostBuild -match 'ResolveOriginalLocalAppData' -and $hostBuild -match 'DFB_REPAIR_ONLY') `
  'EngineHost does not bind claimed OTS identity/repair mode to the real launcher token'
Assert-True ($launcherBuild -match 'FilterAdministratorToken' -and $launcherBuild -match 'EndsWith\("-500"' -and
  $hostBuild -match 'FilterAdministratorToken' -and $gui -match 'Test-IsBuiltInAdministratorSid \$script:OriginalUserSid') `
  'RID-500 repair-only path or OTS approved-account isolation is missing'
Assert-True ($gui -match 'DeltaForceBooster\\users\\\$sessionText|DeltaForceBooster\\session-temp' -or
  $gui -match 'ProtectedUserStateRoot') 'GUI protected per-SID state root missing'
Assert-True ($gui -match 'Initialize-ProtectedUserStateStore' -and $gui -match '\$script:BoosterUserConfigDir = \$configRoot') `
  'GUI/updater state is not consistently redirected to protected ProgramData'
Assert-True ($engine -match 'Get-ProtectedUserStateRoot \$script:TargetUserSid' -and
  $engine -match '\[string\]\$UserStateRoot') 'child engine does not derive/accept protected per-SID state'
Assert-True ($gui -match '-UserStateRoot ' -and $engine -match 'UserStateRoot 与受保护 per-SID 状态分区不匹配') `
  'Apply/Restore child action can fall back to elevated LocalAppData'
Assert-True ($updater -match 'BoosterUserConfigDir' -and $updater -match '管理员更新器缺少受保护 per-SID 配置目录') `
  'elevated updater can fall back to the approval administrator LocalAppData'

# 原用户可写树动作全部留在 medium worker；参数和外部动作均为固定白名单。
Assert-True ($worker -match 'if \(Test-WorkerAdmin\).*拒绝执行' -and
  $launcherBuild -match 'psi\.CreateNoWindow = true') 'original-user worker can run high or flash a console'
foreach ($action in 'MigrateLegacyData','ClearShaderCache','GetGpuPanelApps','GetNvAutoOptStatus','OpenUrl','OpenGpuPanel') {
  Assert-True ($gui.Contains($action) -and $hostBuild.Contains($action) -and $launcherBuild.Contains($action)) `
    "broker allowlist is inconsistent: $action"
}
Assert-True ($launcherBuild -match 'UriSchemeHttps' -and $launcherBuild -match 'Array\.IndexOf\(allowed, host\)') `
  'URL broker is not constrained to fixed HTTPS hosts'
foreach ($key in 'nv-cpl','nv-app','amd-sw','intel-gcc') {
  Assert-True ($gui.Contains($key) -and $launcherBuild.Contains($key)) "GPU panel key is not end-to-end allowlisted: $key"
}
Assert-True ($gui -match 'Key = \$app\.Key') 'GPU panel button drops the allowlisted key'
Assert-True ($worker -match 'Get-AppxPackage' -and $gui -match 'Get-GuiGpuPanelApps' -and
  $engine -match 'if \(Test-Admin\) \{ return \$null \}') 'AppX detection can observe the approval administrator instead of the original user'
Assert-True ($engine -match 'Registry::HKEY_USERS\\\$script:TargetUserSid.*Uninstall') `
  'game discovery does not enumerate the original user HKEY_USERS uninstall hive'

# Update handoff explicitly waits every image that can lock the app tree.
foreach ($pidArg in '/waitpid=$script:EngineHostPid','/waitpid2=$script:LauncherPid','/waitpid3=$PID') {
  Assert-True $gui.Contains($pidArg) "update handoff PID missing: $pidArg"
}
Assert-True ($gui -match '\$script:UpdateRunAfterAllowed = \$approvalSid -ieq \$script:OriginalUserSid' -and
  $gui -match 'if \(\$script:UpdateRunAfterAllowed\) \{ \$setupArgs\.Add\(''/runafter''\) \}') `
  'OTS updater can still auto-launch under the approval administrator account'
Assert-True ($installerBuild -match 'make-engine-host\.ps1' -and
  $installerBuild.IndexOf('make-engine-host.ps1', [StringComparison]::Ordinal) -lt
  $installerBuild.IndexOf('make-launcher.ps1', [StringComparison]::Ordinal)) 'installer build order is not EngineHost before launcher'
Assert-True ($installerBuild -match "'EngineHost\.exe'" -and $installerBuild -match "'scripts\\user-context-worker\.ps1'" -and
  $installerBuild -match 'SchemaVersion=2.*EngineHostSha256') 'EngineHost/worker/identity v2 is not in installer payload'
Assert-True ($launcherBuild -match 'SchemaVersion=1' -and $launcherBuild -match 'SchemaVersion=2' -and
  $hostBuild -match 'SchemaVersion=1' -and $hostBuild -match 'SchemaVersion=2') 'runtime identity validation lost v1 upgrade compatibility'
Assert-True (-not ($bat -match '(?i)powershell') -and $bat -match '启动优化工具\.exe') 'backup BAT bypasses the launcher/EngineHost chain'

# Runtime root contract and uninstall UAC boundary.
foreach ($needle in 'PermanentAnchor','EnsureExactAnchorDirectory','EnsureHighIntegrityAnchor','AnchorNeverDelete=1','EnsureTrustedProgramFilesChain') {
  Assert-True ($runtimeRoot.Contains($needle) -and $hostBuild.Contains('DfbRuntimeRoot.Validate') -and
    $launcherBuild.Contains('DfbRuntimeRoot.Validate')) "runtime protected-root contract missing: $needle"
}
Assert-True ($uninstallBuild -match 'requestedExecutionLevel level="requireAdministrator"' -and
  $uninstallBuild -match 'AssemblyDescription\("三角洲行动优化助手 卸载助手"\)' -and
  $installerBuild -match 'make-uninstall-host\.ps1' -and $installerBuild -match 'UninstallHost\.exe') `
  'dedicated UninstallHost is not built into the installer payload'
Assert-True ($installerBuild -notmatch 'Start-Process \$psExe -Verb RunAs' -and
  $installerBuild -match 'Wait-VerifiedProcessExit' -and $uninstallHostSource -match 'WorkingDirectory = system' -and
  $uninstallLauncherSource -match 'psi\.Verb = "runas"') `
  'uninstall still prompts as PowerShell or keeps the product root locked'
Assert-True ($uninstallLauncherSource -match 'EnterTrustedElevationEnvironment' -and
  $uninstallLauncherSource -match 'Environment\.SetEnvironmentVariable\(key, null' -and
  $uninstallHostSource -match 'psi\.EnvironmentVariables\.Clear\(\)') `
  'uninstall elevation/script child can inherit CLR profiler or untrusted high-token environment'

# High GUI protected profile save/delete behavior. Mock only ACL primitives; real JSON/atomic write path runs.
$profileCase = Join-Path ([IO.Path]::GetTempPath()) ('dfb-profile-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $profileCase 'profiles'))
try {
  & {
    param($EnginePath, $StateRoot)
    . $EnginePath
    $script:TargetUserSid = 'S-1-5-21-111-222-333-1001'
    $script:UserDataRoot = $StateRoot
    $script:ConfigDir = Join-Path $StateRoot 'config'
    $script:ProfileDir = Join-Path $StateRoot 'profiles'
    function Test-Admin { $true }
    function Initialize-UserDataStore {}
    function Get-ProtectedUserStateRoot([string]$Sid) { $StateRoot }
    function Test-PathHasReparsePoint([string]$Path) { $false }
    function Test-ProtectedDirectoryAclExact([string]$Path, [bool]$UsersRead) { $true }
    function Set-ProtectedFileAcl([string]$Path) {}
    function Test-ProtectedFileAcl([string]$Path) { $true }
    $saved = Save-UserPreset '会话方案' @('game-mode')
    Assert-True (Test-Path -LiteralPath $saved -PathType Leaf) 'high GUI could not save into protected ProfileDir'
    $removed = Remove-UserPreset '会话方案'
    Assert-True ($removed -eq '会话方案' -and -not (Test-Path -LiteralPath $saved)) `
      'high GUI could not remove a protected profile'
  } $enginePath $profileCase
} finally { if (Test-Path -LiteralPath $profileCase) { Remove-Item -LiteralPath $profileCase -Recurse -Force } }

# Actual WinPS5.1 second-launch regression: a held lifetime mutex returns before ValidateFiles/RunAs.
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DeltaForceBooster-Tests\engine-session-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$testLauncher = Join-Path $testRoot 'launcher-test.exe'
$markerFile = Join-Path $testRoot 'already-running.txt'
$marker = $null
try {
  & $winPs -NoProfile -ExecutionPolicy Bypass -File $hostBuildPath | Out-Host
  Assert-True ($LASTEXITCODE -eq 0) 'EngineHost test build failed'
  & $winPs -NoProfile -ExecutionPolicy Bypass -File $launcherBuildPath -TestBuild | Out-Host
  Assert-True ($LASTEXITCODE -eq 0) 'launcher DFB_TESTING build failed'
  Copy-Item -LiteralPath (Join-Path $root '启动优化工具.exe') -Destination $testLauncher
  $created = $false
  $marker = New-Object Threading.Mutex($false, 'Global\DeltaForceBooster.LaunchSession', [ref]$created)
  Assert-True $created 'test could not acquire the lifetime launcher marker'
  $env:DFB_TEST_ALREADY_RUNNING_LOG = $markerFile
  $p = Start-Process -FilePath $testLauncher -WorkingDirectory ([Environment]::SystemDirectory) -PassThru
  Assert-True ($p.WaitForExit(10000)) 'second launcher did not return without UAC'
  Assert-True ($p.ExitCode -eq 0 -and (Test-Path -LiteralPath $markerFile -PathType Leaf) -and
    [IO.File]::ReadAllText($markerFile) -eq 'already-running') 'second launcher did not take the pre-UAC already-running path'
} finally {
  Remove-Item Env:DFB_TEST_ALREADY_RUNNING_LOG -ErrorAction SilentlyContinue
  if ($marker) { $marker.Dispose() }
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
  # Do not leave a DFB_TESTING launcher in the repository after the regression.
  & $winPs -NoProfile -ExecutionPolicy Bypass -File $hostBuildPath | Out-Null
  if ($LASTEXITCODE -eq 0) { & $winPs -NoProfile -ExecutionPolicy Bypass -File $launcherBuildPath | Out-Null }
}
Assert-True ($LASTEXITCODE -eq 0) 'production launcher rebuild after second-launch regression failed'

$hostInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $root 'EngineHost.exe'))
$launcherInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $root '启动优化工具.exe'))
Assert-True ($hostInfo.FileDescription -eq '三角洲行动优化助手 管理员助手') 'EngineHost FileDescription is not the UAC-facing product name'
Assert-True ($launcherInfo.FileDescription -eq '三角洲行动优化助手') 'launcher FileDescription changed unexpectedly'

# Behavior regression for the managed RunAs boundary: before ShellExecuteEx/AppInfo receives
# the launch request, every caller-controlled CLR/PowerShell variable is absent and the helper
# restores the medium launcher's original environment after Process.Start returns.
$launcherAssembly = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $root '启动优化工具.exe')))
$launcherType = $launcherAssembly.GetType('Launcher', $true)
$enterEnv = $launcherType.GetMethod('EnterTrustedElevationEnvironment', [Reflection.BindingFlags]'Static,NonPublic')
$restoreEnv = $launcherType.GetMethod('RestoreProcessEnvironment', [Reflection.BindingFlags]'Static,NonPublic')
$poison = [ordered]@{
  COR_ENABLE_PROFILING='1'; COR_PROFILER_PATH='C:\untrusted\profiler.dll';
  COMPlus_ReadyToRun='0'; DOTNET_STARTUP_HOOKS='C:\untrusted\hook.dll'; PSModulePath='C:\untrusted\Modules'
}
$savedPoison = @{}
foreach ($name in $poison.Keys) { $savedPoison[$name] = [Environment]::GetEnvironmentVariable($name, 'Process');
  [Environment]::SetEnvironmentVariable($name, $poison[$name], 'Process') }
$savedEnvironment = $null
try {
  $savedEnvironment = $enterEnv.Invoke($null, @())
  foreach ($name in $poison.Keys) {
    Assert-True ($null -eq [Environment]::GetEnvironmentVariable($name, 'Process')) `
      "RunAs sanitizer retained dangerous environment variable: $name"
  }
  Assert-True ([Environment]::GetEnvironmentVariable('PATH','Process').StartsWith([Environment]::SystemDirectory,
    [StringComparison]::OrdinalIgnoreCase)) 'RunAs sanitizer PATH is not rooted at trusted System32'
} finally {
  if ($savedEnvironment) { $restoreEnv.Invoke($null, [object[]]@(,$savedEnvironment)) | Out-Null }
  foreach ($name in $poison.Keys) { [Environment]::SetEnvironmentVariable($name, $savedPoison[$name], 'Process') }
}

Write-Host 'PASS: EngineHost one-UAC lifetime session, OTS broker, protected state, update handoff and profiles'
