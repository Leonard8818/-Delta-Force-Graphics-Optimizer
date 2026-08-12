#requires -Version 5.1
param()

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$path=Join-Path $root 'website\admin\data\index.html'
if(-not (Test-Path -LiteralPath $path -PathType Leaf)){
  Write-Host 'SKIP: private admin dashboard is not present in this checkout'
  exit 0
}
$raw=Get-Content -LiteralPath $path -Raw -Encoding UTF8
$script:Assertions=0
function Assert-True([bool]$Condition,[string]$Message){$script:Assertions++;if(-not $Condition){throw "ASSERT: $Message"}}

foreach($needle in @(
  'data-main-tab="usage"','data-main-tab="experiments"','id="usageView"','id="experimentsView"',
  'role="tablist"','role="tabpanel"','function selectMainTab','function renderExperiments',
  'data.experiments','id="expItemSets"','id="expItems"','id="expEnvironments"',
  'id="expConfigurations"','id="expDiagnosticReports"','id="expDiagnosticIssues"',
  'id="expDiagnosticErrors"','id="expDiagnosticConfigs"','id="expDiagnosticIssueEnvironments"',
  'id="expDiagnosticProcesses"','id="expDiagnosticIssueProcesses"',
  'id="expDiagnosticPanelApps"','id="expDiagnosticVersions"',
  'id="expPerfContextComplete"','id="expPerfContextIncomplete"','id="expPerfItemSets"',
  'id="expTuningEnrichedHint"','validEnrichedRuns','gpuDriverVersion','gpuModelVerified',
  'data.performanceOptimization','DESCRIPTIVE ONLY','普通游戏会话没有固定地图',
  'TRAINING READINESS','ENVIRONMENT MATRIX','DIAGNOSTIC SIGNALS','结构化操作','还原验证结果',
  '诊断报告是用户遇到问题或观察到变化后主动提交的有偏样本','历史性能记录仅作描述性参考'
)){Assert-True $raw.Contains($needle) "experiment dashboard is missing: $needle"}

$ids=@([regex]::Matches($raw,'\bid="([A-Za-z][A-Za-z0-9_-]*)"')|ForEach-Object{$_.Groups[1].Value})
$duplicates=@($ids|Group-Object|Where-Object Count -gt 1)
Assert-True ($duplicates.Count -eq 0) ('duplicate HTML ids: '+(($duplicates|ForEach-Object Name)-join ', '))

$experimentIds=@([regex]::Matches($raw,"(?:set|renderExperimentRows)\('(?<id>exp[A-Za-z0-9]+)'")|ForEach-Object{$_.Groups['id'].Value}|Sort-Object -Unique)
foreach($id in $experimentIds){Assert-True ($ids -contains $id) "renderExperiments references a missing node: $id"}
Assert-True (-not $raw.Contains('client_hash')) 'private dashboard exposes a raw client hash field'
Assert-True ($raw.Contains("fetch('/admin/api/stats'")) 'dashboard no longer loads the protected aggregate stats API'
Assert-True ($raw.Contains("history.replaceState(null,'',selected==='experiments'?'#experiments':'#usage')")) 'main tab selection is not addressable by hash'
Assert-True ($raw.Contains('不会上传项目的注册表路径、键值、原值或新值')) 'privacy notice does not explain the new project-level telemetry boundary'
foreach($needle in @(
  'viewport-fit=cover','@media (max-width:1024px)','@media (max-width:760px)','@media (max-width:520px)',
  'class="table-scroll"','← 左右滑动查看完整表格 →','activeTouchChartHit',"event.pointerType==='touch'",
  "wrap.setAttribute('role','region')",'grid-template-columns:repeat(2,minmax(0,1fr))'
)){Assert-True $raw.Contains($needle) "responsive dashboard is missing: $needle"}
Assert-True (-not $raw.Contains('style="overflow-x:auto"')) 'responsive tables still use inaccessible inline scrolling containers'

Write-Host "admin experiment dashboard tests passed: $script:Assertions assertions"
