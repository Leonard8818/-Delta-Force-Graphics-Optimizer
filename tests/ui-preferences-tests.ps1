#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'

function Assert-True([bool]$Condition,[string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($guiPath,[ref]$tokens,[ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI AST parse failed: ' + (($errors | ForEach-Object Message) -join '; '))

function Get-GuiFunctionText([string]$Name) {
  $node = @($ast.FindAll({
    param($candidate)
    $candidate -is [Management.Automation.Language.FunctionDefinitionAst] -and $candidate.Name -eq $Name
  },$true) | Select-Object -First 1)
  Assert-True ($node.Count -eq 1) "function not found: $Name"
  $node[0].Extent.Text
}

foreach ($name in 'Get-SavedUiPreferences','Get-SavedAppTheme','Get-SavedAppWindowHeight','Save-AppUiPreferences') {
  Invoke-Expression (Get-GuiFunctionText $name)
}

$case = Join-Path ([IO.Path]::GetTempPath()) ('dfb-ui-prefs-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($case)
$script:UiPreferencesPath = Join-Path $case 'ui-preferences.json'
$script:DefaultAppWindowHeight = 1200.0
$script:LightThemeEnabled = $true
function Write-BytesAtomic([string]$Path,[byte[]]$Bytes) { [IO.File]::WriteAllBytes($Path,$Bytes) }

try {
  Assert-True ((Get-SavedAppTheme) -eq 'dark') 'missing preferences did not default to dark theme'
  Assert-True ((Get-SavedAppWindowHeight) -eq 1200) 'missing preferences did not default to 1200 height'

  [IO.File]::WriteAllText($script:UiPreferencesPath,'{"schemaVersion":1,"theme":"light"}',[Text.UTF8Encoding]::new($false))
  Assert-True ((Get-SavedAppTheme) -eq 'light') 'legacy theme-only preference was not loaded'
  Assert-True ((Get-SavedAppWindowHeight) -eq 1200) 'legacy preference did not receive the new default height'

  Save-AppUiPreferences 'light' 1188.4
  $saved = Get-Content -LiteralPath $script:UiPreferencesPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($saved.theme -eq 'light' -and [int]$saved.windowHeight -eq 1188) 'theme and window height were not saved together'
  Assert-True ((Get-SavedAppWindowHeight) -eq 1188) 'saved window height was not restored'

  $script:LightThemeEnabled = $false
  Assert-True ((Get-SavedAppTheme) -eq 'dark') 'deferred light theme was still restored in the current version'
  Save-AppUiPreferences 'light' 1188.4
  $saved = Get-Content -LiteralPath $script:UiPreferencesPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($saved.theme -eq 'dark' -and [int]$saved.windowHeight -eq 1188) 'disabled light theme was persisted instead of dark'
  $script:LightThemeEnabled = $true

  [IO.File]::WriteAllText($script:UiPreferencesPath,'{"schemaVersion":1,"theme":"dark","windowHeight":400}',[Text.UTF8Encoding]::new($false))
  Assert-True ((Get-SavedAppWindowHeight) -eq 1200) 'unsafe short window height was not rejected'
} finally {
  Remove-Item -LiteralPath $case -Recurse -Force -ErrorAction SilentlyContinue
}

'UI preference tests passed.'
