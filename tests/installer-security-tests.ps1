param([switch]$KeepArtifacts)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$guiText = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'))
if ($guiText -notmatch "\`$script:GuiVersion\s*=\s*'([0-9.]+)'") { throw '无法解析 GUI 版本号' }
$setup = Join-Path $root "build\DeltaForceBooster-Setup-v$($Matches[1])-TEST.exe"
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) {
  throw '请先运行：powershell -File build\make-installer.ps1 -TestBuild'
}
$testBase = Join-Path ([IO.Path]::GetTempPath()) ('DeltaForceBooster-Tests\installer-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testBase)

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT: $Message" }
}
function Invoke-TestSetup([string[]]$Arguments) {
  $p = Start-Process -FilePath $setup -ArgumentList $Arguments -Wait -PassThru
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
    'data\streamer-settings.json','gui\app.ico','gui\DeltaForceBooster-GUI.ps1',
    'scripts\delta-booster.ps1','scripts\diagnose.ps1','scripts\telemetry-client.ps1','scripts\tuning-experiment.ps1','scripts\updater.ps1',
    'tools\DeltaForce-Recommended.nip','tools\PresentMon-LICENSE.txt','tools\PresentMon.exe',
    '启动优化工具.bat','启动优化工具.exe','卸载.bat','卸载.exe','uninstall.ps1'
  ) | Sort-Object
  $destPrefix = [IO.Path]::GetFullPath($dest).TrimEnd('\') + '\'
  $actualPayload = @(Get-ChildItem -LiteralPath $dest -Recurse -File | ForEach-Object {
    $_.FullName.Substring($destPrefix.Length)
  } | Sort-Object)
  $payloadDiff = @(Compare-Object $expectedPayload $actualPayload)
  Assert-True ($payloadDiff.Count -eq 0) ('installed payload differs from whitelist: ' + ($payloadDiff | Out-String))
  $lines = [IO.File]::ReadAllLines($identity)
  $sha = (Get-FileHash (Join-Path $dest '启动优化工具.exe') -Algorithm SHA256).Hash
  Assert-True ($lines.Count -eq 3 -and $lines[2] -eq "LauncherSha256=$sha") 'identity/launcher hash mismatch'

  $launcherBytes = [IO.File]::ReadAllBytes((Join-Path $dest '启动优化工具.exe'))
  $launcherAssembly = [Reflection.Assembly]::Load($launcherBytes)
  $launcherType = $launcherAssembly.GetType('Launcher', $true)
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
  foreach ($point in 'after-extract','after-old-move') {
    $env:DFB_TEST_INSTALL_FAIL_AT = $point
    $code = Invoke-TestSetup @('/silent', "/dir=`"$dest`"", "/log=`"$(Join-Path $case "$point.log")`"")
    Assert-True ($code -eq 1) "$point exit=$code"
    Assert-True (Test-Path (Join-Path $dest 'config\marker.json')) "$point marker lost"
    Assert-True ((Get-FileHash (Join-Path $dest '启动优化工具.exe')).Hash -eq $before) "$point changed old launcher"
    Assert-True (@(Get-ChildItem $pf -Force | Where-Object Name -Like '.DeltaForceBooster.dfb-*').Count -eq 0) "$point left transaction directory"
  }
  Remove-Item Env:DFB_TEST_INSTALL_FAIL_AT -ErrorAction SilentlyContinue

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
    $env:DFB_TEST_INSECURE_PREFIX = $legacy
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
