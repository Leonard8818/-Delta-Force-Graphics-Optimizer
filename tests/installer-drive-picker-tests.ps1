param([switch]$KeepArtifacts)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$guiText = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'))
if ($guiText -notmatch "\`$script:GuiVersion\s*=\s*'([0-9.]+)'") { throw 'ASSERT: GUI version missing' }
if ($guiText -notmatch "\`$script:DisplayVersion\s*=\s*'([0-9.]+)'") { throw 'ASSERT: GUI display version missing' }
$setup = Join-Path $root "build\DeltaForceBooster-Setup-v$($Matches[1])-TEST.exe"
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) {
  throw 'Build the test installer first: powershell -File build\make-installer.ps1 -TestBuild'
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT: $Message" }
}

$source = [IO.File]::ReadAllText((Join-Path $root 'build\setup-wizard.cs'))
Assert-True ($source -match 'INSTALL DRIVE' -and $source -match 'GetInstallDriveOptions') `
  'drive selector UI or enumeration is missing'
Assert-True ($source -match 'InstallDirForDrive' -and $source -match 'IsReadOnly\s*=\s*true') `
  'generated destination preview is missing or editable'
Assert-True ($source -notmatch 'FolderBrowserDialog|OnBrowseClick') `
  'the primary flow still exposes an arbitrary folder picker'
Assert-True ($source -match 'driveType\s*!=\s*DriveType\.Fixed' -and
  $source -match 'fileSystem,\s*"NTFS"' -and
  $source -match 'CheckSecureInstallLocation\(option\.Destination\)') `
  'drive cards are not gated by fixed-drive, NTFS, and secure-location checks'
Assert-True ($source -match 'e\.Key\s*==\s*Key\.Enter\s*\|\|\s*e\.Key\s*==\s*Key\.Space') `
  'drive cards are not keyboard selectable'
Assert-True ($source -match 'UniformGrid\s*\{\s*Columns\s*=\s*2' -and
  $source -match '_driveCards\.Count\s*>\s*4\s*\?\s*142\s*:\s*Math\.Ceiling' -and
  $source -match '_driveCards\.Count\s*>\s*4[\s\S]{0,100}ScrollBarVisibility\.Visible[\s\S]{0,100}ScrollBarVisibility\.Hidden') `
  'drive choices are not a two-column flat layout with overflow-only scrolling'
Assert-True ($source -match 'Theme\.ScrollBarStyle\(\)' -and
  $source -match "Thumb Background='#2A4A40' BorderBrush='#00E884'" -and
  $source -match "Track x:Name='PART_Track' Orientation='\{TemplateBinding Orientation\}'") `
  'overflow scrollbar does not use the installer theme'
Assert-True ($source -match '(?s)void OnInstallClick\(\).*?RelaunchElevated\(dest\)') `
  'UAC is no longer deferred until the install action'

$assembly = [Reflection.Assembly]::LoadFile((Resolve-Path -LiteralPath $setup).Path)
$installerType = $assembly.GetType('DfbSetup.Installer', $true)
$flags = [Reflection.BindingFlags]'Static,Public'
$defaultDir = [string]$installerType.GetMethod('DefaultDir', $flags).Invoke($null, @())
$forDrive = $installerType.GetMethod('InstallDirForDrive', $flags)
$defaultRoot = [IO.Path]::GetPathRoot($defaultDir)
Assert-True ([string]::Equals([string]$forDrive.Invoke($null, @($defaultRoot)), $defaultDir,
  [StringComparison]::OrdinalIgnoreCase)) 'default drive does not map to Program Files'
$alternateRoot = if ([string]::Equals($defaultRoot, 'Q:\', [StringComparison]::OrdinalIgnoreCase)) { 'R:\' } else { 'Q:\' }
$alternateDir = [string]$forDrive.Invoke($null, @($alternateRoot))
Assert-True ([string]::Equals($alternateDir, ([IO.Path]::Combine($alternateRoot, 'DeltaForceBooster')),
  [StringComparison]::OrdinalIgnoreCase)) 'non-default drive does not map to its protected root anchor'
$disabledReason = $installerType.GetMethod('DriveDisabledReason', $flags)
Assert-True ($null -eq $disabledReason.Invoke($null, @($true, [IO.DriveType]::Fixed, 'NTFS'))) `
  'a ready fixed NTFS drive is classified as disabled'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$disabledReason.Invoke(
  $null, @($false, [IO.DriveType]::Fixed, 'NTFS')))) 'an unready drive has no disabled reason'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$disabledReason.Invoke(
  $null, @($true, [IO.DriveType]::Removable, 'NTFS')))) 'a removable drive has no disabled reason'
Assert-True ([string]$disabledReason.Invoke($null, @($true, [IO.DriveType]::Fixed, 'exFAT')) -match 'NTFS') `
  'a non-NTFS drive has no filesystem reason'

$options = @($installerType.GetMethod('GetInstallDriveOptions', $flags).Invoke($null, @()))
Assert-True ($options.Count -gt 0) 'drive enumeration returned no options'
$supported = @($options | Where-Object { $_.IsSupported })
Assert-True ($supported.Count -gt 0) 'drive enumeration returned no supported option'
$checkSecure = $installerType.GetMethod('CheckSecureInstallLocation', $flags)
foreach ($option in $supported) {
  Assert-True ($option.DriveType -eq [IO.DriveType]::Fixed) 'a non-fixed drive is selectable'
  Assert-True ([string]::Equals([string]$option.FileSystem, 'NTFS', [StringComparison]::OrdinalIgnoreCase)) `
    'a non-NTFS drive is selectable'
  $securityError = $checkSecure.Invoke($null, @([string]$option.Destination))
  Assert-True ($null -eq $securityError) 'a generated drive destination is rejected by the security validator'
}
foreach ($option in @($options | Where-Object { -not $_.IsSupported })) {
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$option.DisabledReason)) `
    'a disabled drive has no user-facing reason'
}

$render = Join-Path ([IO.Path]::GetTempPath()) ('DeltaForceBooster-Tests\drive-picker-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($render)
try {
  $process = Start-Process -FilePath $setup -ArgumentList ('/render="' + $render + '"') -Wait -PassThru
  Assert-True ($process.ExitCode -eq 0) "render mode failed with exit code $($process.ExitCode)"
  foreach ($name in 'page2-location.png','page2b-location-needadmin.png','strings.txt') {
    Assert-True (Test-Path -LiteralPath (Join-Path $render $name) -PathType Leaf) "render output missing: $name"
  }
  $strings = [IO.File]::ReadAllText((Join-Path $render 'strings.txt'))
  Assert-True ($strings -match [regex]::Escape('安装位置只读=True')) 'rendered destination is not read-only'
  Assert-True ($strings -match [regex]::Escape('磁盘布局=双列平铺；超过4项滚动') -and
    $strings -match [regex]::Escape('滚动条主题=深色绿')) `
    'rendered drive layout or themed overflow marker is missing'
  Assert-True ($strings -match [regex]::Escape('磁盘选项=') -and $strings -notmatch [regex]::Escape('浏览…')) `
    'rendered UI does not expose only drive choices'
} finally {
  if (-not $KeepArtifacts) { Remove-Item -LiteralPath $render -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "Installer drive-picker tests passed ($($supported.Count)/$($options.Count) selectable drives)."
