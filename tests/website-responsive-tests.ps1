#requires -Version 5.1
param()

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$path=Join-Path $root 'website\index.html'
$raw=Get-Content -LiteralPath $path -Raw -Encoding UTF8
$script:Assertions=0
function Assert-True([bool]$Condition,[string]$Message){$script:Assertions++;if(-not $Condition){throw "ASSERT: $Message"}}

foreach($needle in @(
  'viewport-fit=cover','class="hero-actions"','@media (max-width:820px)','@media (max-width:600px)',
  '@media (max-width:340px)','grid-template-columns:repeat(2,minmax(0,1fr))','env(safe-area-inset-right)',
  'touch-action:manipulation','overflow-x:hidden','min-height:44px'
)){Assert-True $raw.Contains($needle) "responsive homepage is missing: $needle"}

Assert-True ($raw.Contains('href="DeltaForceBooster-Setup.exe"')) 'homepage latest installer link changed unexpectedly'
Assert-True ($raw.Contains('当前版本 v0.22.4')) 'homepage version marker changed unexpectedly'
Assert-True ($raw.Contains("fetch('/report/public-stats'")) 'homepage public statistics endpoint changed unexpectedly'
foreach($needle in @(
  '.proof-card.stat-changed','proof-value.stat-changed','@keyframes statCardFlash','@keyframes statValueFlash',
  'const highlightTimers=new WeakMap()','if(previous!==undefined&&start!==end)highlightChange(node)',
  "target.classList.add('stat-changed')",'prefers-reduced-motion:reduce'
)){Assert-True $raw.Contains($needle) "homepage statistic change highlight is missing: $needle"}
Assert-True (-not $raw.Contains('client_hash')) 'homepage exposes a private client identifier'

$ids=@([regex]::Matches($raw,'\bid="([A-Za-z][A-Za-z0-9_-]*)"')|ForEach-Object{$_.Groups[1].Value})
$duplicates=@($ids|Group-Object|Where-Object Count -gt 1)
Assert-True ($duplicates.Count -eq 0) ('duplicate homepage HTML ids: '+(($duplicates|ForEach-Object Name)-join ', '))

Write-Host "website responsive tests passed: $script:Assertions assertions"
