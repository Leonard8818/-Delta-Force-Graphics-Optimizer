#requires -Version 5.1
param()

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$weeklyPath=Join-Path $root 'website\admin\index.html'
$dataPath=Join-Path $root 'website\admin\data\index.html'
if(-not (Test-Path -LiteralPath $weeklyPath -PathType Leaf) -or -not (Test-Path -LiteralPath $dataPath -PathType Leaf)){
  Write-Host 'SKIP: private admin dashboard files are not present in this checkout'
  exit 0
}
$weekly=Get-Content -LiteralPath $weeklyPath -Raw -Encoding UTF8
$data=Get-Content -LiteralPath $dataPath -Raw -Encoding UTF8
$script:Assertions=0
function Assert-True([bool]$Condition,[string]$Message){$script:Assertions++;if(-not $Condition){throw "ASSERT: $Message"}}

Assert-True ($weekly.Contains('<title>Delta Force Booster · 生产工作台</title>')) 'admin root is not the weekly production workspace'
Assert-True ($weekly.Contains('href="/admin/data/"')) 'weekly workspace does not link to the data dashboard'
Assert-True ($weekly.Contains('fetch(query(live)')) 'weekly workspace no longer loads its weekly API'
Assert-True ($weekly.Contains('viewport-fit=cover')) 'weekly workspace is missing safe-area viewport support'
Assert-True ($weekly.Contains('@media(max-width:780px)')) 'weekly workspace is missing phone/tablet layout rules'
Assert-True ($weekly.Contains('activeTouchChartHit')) 'weekly charts are missing touch data-point support'
Assert-True ($data.Contains('<title>Delta Force Booster · 用户分析</title>')) 'data dashboard file has the wrong page type'
Assert-True ($data.Contains('href="/admin/"')) 'data dashboard does not link back to the weekly workspace'
Assert-True (-not $data.Contains('href="../">周报工作台')) 'data dashboard still uses a path-sensitive weekly link'

Write-Host "admin dashboard navigation tests passed: $script:Assertions assertions"
