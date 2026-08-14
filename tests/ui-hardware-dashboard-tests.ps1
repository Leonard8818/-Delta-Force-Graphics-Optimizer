#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'
$enginePath = Join-Path $root 'scripts\delta-booster.ps1'

function Assert-True([bool]$Condition,[string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

$tokens = $null; $errors = $null
$guiAst = [Management.Automation.Language.Parser]::ParseFile($guiPath,[ref]$tokens,[ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI AST parse failed: ' + (($errors | ForEach-Object Message) -join '; '))
$tokens = $null; $errors = $null
$engineAst = [Management.Automation.Language.Parser]::ParseFile($enginePath,[ref]$tokens,[ref]$errors)
Assert-True ($errors.Count -eq 0) ('engine AST parse failed: ' + (($errors | ForEach-Object Message) -join '; '))

$raw = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
$engineRaw = Get-Content -LiteralPath $enginePath -Raw -Encoding UTF8
Assert-True ($raw -match '(?s)<Grid>\s*<Grid\.ColumnDefinitions>\s*<ColumnDefinition Width="Auto"/>\s*<ColumnDefinition Width="\*"/>\s*<ColumnDefinition Width="Auto"/>\s*</Grid\.ColumnDefinitions>.*?x:Name="GameText" Grid\.Column="1".*?x:Name="BrowseBtn" Grid\.Column="2"') `
  'game path row does not keep the relocate button pinned to the right edge'
foreach ($needle in @(
  'x:Name="ThemeBtn"','Visibility="Collapsed"','$script:LightThemeEnabled = $false','x:Name="MetricsGrid"','x:Name="HwGrid" Columns="4"',
  'Width="780" Height="1200" MinHeight="640"','$workAreaHeight-32.0','$script:DefaultAppWindowHeight = 1200.0',
  'function New-FpsMetricCard',"@('cpu','CPU 占用','%',100)","@('gpu','GPU 占用','%',100)","@('memory','内存占用','%',100)",
  'function New-MetricHistoryButton','MetricHistoryButton','function Set-LiveMetricComparison',
  'function Select-PerformanceComparisonPair','function Show-PerformanceMetricHistory','Refresh-PerformanceComparison -Force',
  "`$readout.Orientation = 'Horizontal'",
  "Set-HardwareTemperature 'cpu'","Set-HardwareTemperature 'gpu'","-TemperatureKey 'cpu'","-TemperatureKey 'gpu'",
  "`$v.TextWrapping = 'Wrap'","`$v.TextTrimming = 'None'","`$v.ToolTip = `$Value",
  'DfbLivePresentMonSampler','DfbProcessorUtilitySampler','DfbLiveSystemMetrics','Get-TemperatureColor','Start-LiveMetricsMonitor',
  "`$State.FpsStatus = '等待有效帧'",
  '@"\Processor Information(_Total)\% Processor Utility"','处理器效用',
  'windowHeight=[math]::Round($WindowHeight,0)','Set-SavedAppWindowHeight','Save-AppUiPreferences $script:CurrentTheme',
  "Set-AppTheme (Get-SavedAppTheme)","Set-AppTheme `$(if (`$script:CurrentTheme -eq 'dark') { 'light' } else { 'dark' }) -Persist"
)) { Assert-True $raw.Contains($needle) "GUI missing hardware dashboard/theme integration: $needle" }
Assert-True (-not $raw.Contains('较优化前')) 'metric cards still assume that the user has run optimization'
Assert-True (-not $raw.Contains("@('fps','FPS','帧',240)")) 'FPS was still configured as a circular gauge'
Assert-True (-not $raw.Contains("@('cpuTemp','CPU 温度','°C',100)")) 'CPU temperature was still configured as a circular gauge'
Assert-True (-not $raw.Contains("@('gpuTemp','GPU 温度','°C',100)")) 'GPU temperature was still configured as a circular gauge'
Assert-True (-not $raw.Contains('$script:LiveMetricAnimations')) 'occupancy rings still contained flow-animation state'
Assert-True (-not $raw.Contains('ArcColorStops')) 'occupancy rings still contained animated glass gradients'
Assert-True (-not $raw.Contains('CtaFill')) 'primary action still used the contour-line drawing brush'
Assert-True (-not $raw.Contains('PathGeometry Figures="M 0,7 C')) 'primary action still contained decorative contour curves'
Assert-True ($raw.Contains('<Path x:Name="Bg" Stretch="Fill" Fill="{DynamicResource Green}"')) 'primary action does not use the shared theme green'
Assert-True ($raw.Contains("GreenLine='#FF00E884';Gold='#FFE5C46A'") -and
  $raw.Contains("GreenLine='#FF00E884';Gold='#FF1677B8'")) `
  'both themes do not share the primary green or their yellow/blue accents are missing'
Assert-True (-not $raw.Contains('#FFB5840D') -and -not $raw.Contains('#FFFFF5D9')) `
  'legacy light-theme yellow surfaces are still present'
Assert-True ($raw.IndexOf('x:Name="HwGrid" Columns="4"') -lt $raw.IndexOf('x:Name="MetricsGrid"')) `
  'CPU/GPU hardware row is not above the FPS and occupancy row'
Assert-True (-not $raw.Contains('MSAcpi_ThermalZoneTemperature')) 'motherboard ACPI thermal zone was still presented as CPU package temperature'
foreach ($needle in 'WmiMonitorID','PrimaryDisplayName','DisplayName','DisplayNames') {
  Assert-True $engineRaw.Contains($needle) "engine missing display identity field: $needle"
}

Add-Type -AssemblyName PresentationFramework
$xamlBlocks = [regex]::Matches($raw,"(?s)=\s*@'\r?\n(\s*<(?:Window|ResourceDictionary).*?)\r?\n'@")
Assert-True ($xamlBlocks.Count -ge 10) 'expected GUI XAML blocks were not found'
foreach ($block in $xamlBlocks) {
  $parsed = [Windows.Markup.XamlReader]::Parse($block.Groups[1].Value)
  if ($parsed -is [Windows.Window]) { $parsed.Close() }
}

foreach ($functionName in 'Resolve-DisplayClassLabel','Get-TemperatureColor','Initialize-LiveMetricsTypes') {
  $function = @($guiAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
  },$true) | Select-Object -First 1)
  Assert-True ($function.Count -eq 1) "function not found: $functionName"
  Invoke-Expression $function[0].Extent.Text
}

Assert-True ((Resolve-DisplayClassLabel 1920 1080) -eq '1K') '1920x1080 was not labeled 1K'
Assert-True ((Resolve-DisplayClassLabel 2560 1440) -eq '2K') '2560x1440 was not labeled 2K'
Assert-True ((Resolve-DisplayClassLabel 3840 2160) -eq '4K') '3840x2160 was not labeled 4K'
Assert-True ((Resolve-DisplayClassLabel 3440 1440) -eq '3440 × 1440') 'non-standard resolution did not keep its dimensions'
$script:C = @{ Green='#FF00E884' }
Assert-True ((Get-TemperatureColor 40) -eq $script:C.Green) 'low temperature does not use the active theme green'
Assert-True ((Get-TemperatureColor 40) -ne (Get-TemperatureColor 95)) 'temperature color does not change from low to high'

& {
  $script:C = @{
    Panel='#FF0E1B17';Line='#FF1B2E28';LineHi='#FF2C443B';TextPri='#FFFFFFFF'
    TextSec='#FF9AA5A0';TextMut='#FF7A8580';Green='#FF00E884';Gold='#FFE5C46A'
  }
  function New-Brush([string]$Hex) { (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex) }
  foreach ($functionName in 'New-Text','New-HwCard','New-MetricHistoryButton','New-FpsMetricCard','New-LiveMetricGauge','Set-LiveMetricGauge','Set-LiveMetricComparison','Set-HardwareTemperature','Initialize-LiveMetricsDashboard') {
    $wanted = $functionName
    $function = @($guiAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $wanted
    },$true) | Select-Object -First 1)
    Assert-True ($function.Count -eq 1) "dashboard function not found: $functionName"
    Invoke-Expression $function[0].Extent.Text
  }
  $ui = @{ MetricsGrid = New-Object Windows.Controls.Grid }
  $script:MetricGauges = @{}
  $script:HardwareTemperatureReadouts = @{}
  Initialize-LiveMetricsDashboard
  Assert-True ($ui.MetricsGrid.Children.Count -eq 4) 'dashboard did not render one FPS card and three circular gauges'
  Assert-True ($script:MetricGauges.fps.Kind -eq 'number' -and $null -eq $script:MetricGauges.fps.Arc) 'FPS card still owns circular-gauge geometry'
  Assert-True ($script:MetricGauges.fps.ValueText.Foreground.Color -eq ([Windows.Media.ColorConverter]::ConvertFromString($script:C.Green))) 'FPS value was not rendered in the active theme green'
  Assert-True ($script:MetricGauges.fps.ValueText.Parent.HorizontalAlignment -eq [Windows.HorizontalAlignment]::Center) 'FPS value and unit are not horizontally centered'
  Assert-True ($script:MetricGauges.fps.SubText.HorizontalAlignment -eq [Windows.HorizontalAlignment]::Center) 'FPS status is not horizontally centered'
  Assert-True ($script:MetricGauges.fps.TitleText.HorizontalAlignment -eq [Windows.HorizontalAlignment]::Center) 'FPS title is not horizontally centered'
  foreach ($key in 'fps','cpu','gpu','memory') {
    Assert-True ($script:MetricGauges[$key].HistoryButton.Content -eq '记录') "history marker is missing from metric card: $key"
    Assert-True ("$($script:MetricGauges[$key].HistoryButton.Tag)" -eq $key) "history marker points to the wrong metric: $key"
  }
  Set-LiveMetricComparison -Key fps -Before 100 -After 120 -Mode percent -Prefix '变化'
  Assert-True ($script:MetricGauges.fps.CompareText.Text -eq '变化 +20.0%') 'FPS card did not show its compact neutral change'
  Assert-True ($script:MetricGauges.fps.CompareText.Foreground.Color -eq ([Windows.Media.ColorConverter]::ConvertFromString($script:C.Green))) 'positive FPS change was not highlighted green'
  Set-LiveMetricComparison -Key cpu -Before 50 -After 45 -Mode points -Prefix '变化'
  Assert-True ($script:MetricGauges.cpu.CompareText.Text -eq '变化 -5.0点') 'CPU card did not show its compact neutral change'
  foreach ($key in 'cpu','gpu','memory') {
    Assert-True ($script:MetricGauges[$key].Kind -eq 'ring') "occupancy gauge was not circular: $key"
    Assert-True ($script:MetricGauges[$key].Arc.Stroke -is [Windows.Media.SolidColorBrush]) "occupancy gauge did not use the ordinary solid ring: $key"
    Assert-True ($script:MetricGauges[$key].UnitText.FontSize -eq $script:MetricGauges[$key].ValueText.FontSize) "percentage unit size differs from its number: $key"
    Assert-True ($script:MetricGauges[$key].ValueText.FontSize -eq 14) "occupancy number is too large for decimal values: $key"
    Assert-True ($script:MetricGauges[$key].UnitText.FontWeight -eq $script:MetricGauges[$key].ValueText.FontWeight) "percentage unit weight differs from its number: $key"
    Assert-True ($script:MetricGauges[$key].UnitText.Foreground.Color -eq $script:MetricGauges[$key].ValueText.Foreground.Color) "percentage unit color differs from its number: $key"
  }
  [void](New-HwCard 'CPU' 'CPU fixture' '8核 / 16线程' -TemperatureKey 'cpu')
  Set-HardwareTemperature 'cpu' 48 'fixture sensor'
  Assert-True ($script:HardwareTemperatureReadouts.cpu.ValueText.Text -eq '48') 'CPU temperature was not rendered inside its hardware card'
  Assert-True ($script:HardwareTemperatureReadouts.cpu.Container.ToolTip -eq '数据源：fixture sensor') 'CPU temperature source is not visible'
  Assert-True ($script:HardwareTemperatureReadouts.cpu.UnitText.FontSize -eq $script:HardwareTemperatureReadouts.cpu.ValueText.FontSize) 'temperature unit size differs from its number'
  Assert-True ($script:HardwareTemperatureReadouts.cpu.UnitText.FontWeight -eq $script:HardwareTemperatureReadouts.cpu.ValueText.FontWeight) 'temperature unit weight differs from its number'
  Assert-True ($script:HardwareTemperatureReadouts.cpu.UnitText.Foreground.Color -eq $script:HardwareTemperatureReadouts.cpu.ValueText.Foreground.Color) 'temperature unit color differs from its number'
  Set-HardwareTemperature 'cpu' $null '' 'fixture unavailable reason'
  Assert-True ($script:HardwareTemperatureReadouts.cpu.ValueText.Text -eq 'N/A' -and
    $script:HardwareTemperatureReadouts.cpu.UnitText.Text -eq '' -and
    $script:HardwareTemperatureReadouts.cpu.Container.ToolTip -eq 'fixture unavailable reason') `
    'missing CPU temperature does not explain the unavailable sensor source'
  Set-HardwareTemperature 'cpu' 52 'fixture sensor'
  Assert-True ($script:HardwareTemperatureReadouts.cpu.UnitText.Text -eq '°C') `
    'temperature unit was not restored after a sensor source became available'
}

foreach ($functionName in 'Expand-PerformanceSessions','Get-PerformanceSessionTimestamp','Test-PerformanceSessionValid',
  'Get-PerformanceSessionDisplayMode','Get-PerformanceSessionToolState','Get-PerformanceSessionToolStateLabel',
  'Get-PerformanceSessionComparisonConfidence','Select-PerformanceComparisonPair',
  'Get-PerformanceComparisonMetricValue','Get-PerformanceMetricHistoryDefinition','Get-PerformanceMetricHistoryRows') {
  $wanted = $functionName
  $function = @($guiAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $wanted
  },$true) | Select-Object -First 1)
  Assert-True ($function.Count -eq 1) "performance comparison function not found: $functionName"
  Invoke-Expression $function[0].Extent.Text
}
$baseContext = [pscustomobject]@{
  gameExeVersion='1.2.3.4';powerSource='ac'
  gpuAdapters=@([pscustomobject]@{main=$true;displayMode='2560x1440@165'})
}
$beforeSession = [pscustomobject]@{
  recordedAt='2026-08-14T01:00:00Z';validity='valid';configTier='baseline';optimizationScheme='baseline'
  optimizationItemSetHash='';gpuModel='NVIDIA GeForce RTX 4070 SUPER';avgFps=100.0;gpuUtilAvg=70.0
  analysisContext=$baseContext;performanceContext=[pscustomobject]@{processCpuAvgPct=30.0;systemMemoryUsedAvgPct=60.0}
}
$afterSession = [pscustomobject]@{
  recordedAt='2026-08-14T02:00:00Z';validity='valid';configTier='full';optimizationScheme='main'
  optimizationItemSetHash='fixture-hash';gpuModel='NVIDIA GeForce RTX 4070 SUPER';avgFps=120.0;gpuUtilAvg=75.0
  analysisContext=$baseContext;performanceContext=[pscustomobject]@{processCpuAvgPct=27.0;systemMemoryUsedAvgPct=58.0}
}
$pair = Select-PerformanceComparisonPair @($beforeSession,$afterSession) ([pscustomobject]@{ItemSetHash='fixture-hash'})
Assert-True ($pair.Status -eq 'paired' -and $pair.Confidence -eq 'comparable' -and $pair.PairKind -eq 'tool_change') 'valid same-environment tool-state sessions were not paired'
Assert-True ((Get-PerformanceComparisonMetricValue $pair.After 'cpu') -eq 27.0) 'comparison did not read the game CPU summary'
$secondBaseline = $beforeSession.PSObject.Copy()
$secondBaseline.recordedAt = '2026-08-14T03:00:00Z'; $secondBaseline.avgFps = 105.0
$baselinePair = Select-PerformanceComparisonPair @($beforeSession,$secondBaseline,$afterSession) ([pscustomobject]@{ItemSetHash=''})
Assert-True ($baselinePair.Status -eq 'paired' -and $baselinePair.PairKind -eq 'history') 'two sessions without tool changes were not compared as ordinary history'
Assert-True ((Get-PerformanceSessionToolStateLabel $secondBaseline) -eq '未使用工具') 'baseline history was not clearly labeled as not using the tool'
$historyRows = @(Get-PerformanceMetricHistoryRows @($beforeSession,$secondBaseline,$afterSession) 'fps')
Assert-True ($historyRows.Count -eq 3 -and $historyRows[0].ValueText -eq '105.0 帧') 'FPS history rows were not built in newest-first order'
Assert-True (@($historyRows | Where-Object { $_.StateText -eq '未使用工具' }).Count -eq 2) 'history did not preserve unoptimized sessions'
$differentContext = [pscustomobject]@{
  gameExeVersion='1.2.3.4';powerSource='ac'
  gpuAdapters=@([pscustomobject]@{main=$true;displayMode='1920x1080@165'})
}
$mismatchedAfter = $afterSession.PSObject.Copy(); $mismatchedAfter.analysisContext = $differentContext
$mismatch = Select-PerformanceComparisonPair @($beforeSession,$mismatchedAfter) ([pscustomobject]@{ItemSetHash='fixture-hash'})
Assert-True ($mismatch.Status -eq 'environment_mismatch') 'known display-mode mismatch was still presented as an optimization change'

$displayFunction = @($engineAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-DisplayTopologyInfo'
},$true) | Select-Object -First 1)
Assert-True ($displayFunction.Count -eq 1) 'Get-DisplayTopologyInfo not found'
& {
  param([string]$FunctionText)
  function Get-CimInstance {
    param([string]$Namespace,[string]$ClassName)
    if ($ClassName -eq 'WmiMonitorConnectionParams') {
      return [pscustomobject]@{ Active=$true; VideoOutputTechnology=10 }
    }
    if ($ClassName -eq 'WmiMonitorID') {
      return [pscustomobject]@{ Active=$true; UserFriendlyName=[uint16[]]@(83,65,78,67,0,0) }
    }
  }
  Invoke-Expression $FunctionText
  $display = Get-DisplayTopologyInfo
  Assert-True ($display.PrimaryDisplayName -eq 'SANC') 'monitor friendly name was not decoded'
  Assert-True ($display.ActiveDisplayCount -eq 1 -and $display.Connectors -contains 'displayport') 'display topology fields regressed'
} $displayFunction[0].Extent.Text

Initialize-LiveMetricsTypes
Assert-True ([bool]('DfbLivePresentMonSampler' -as [type])) 'PresentMon live sampler type did not compile'
Assert-True ([bool]('DfbProcessorUtilitySampler' -as [type])) 'processor utility sampler type did not compile'
Assert-True ([bool]('DfbLiveSystemMetrics' -as [type])) 'system metrics type did not compile'
$displaySampler = New-Object DfbLivePresentMonSampler
try {
  $displaySampler.AcceptCsvLine('Application,ProcessID,SwapChainAddress,DisplayedTime,FrameTime')
  foreach ($index in 1..10) { $displaySampler.AcceptCsvLine("game.exe,42,0xMAIN,10,8") }
  foreach ($index in 1..5) { $displaySampler.AcceptCsvLine("game.exe,42,0xUI,50,5") }
  $displaySampler.AcceptCsvLine('game.exe,42,0xMAIN,NA,8')
  Assert-True ([math]::Abs($displaySampler.ReadFps()-100.0) -lt 0.01) `
    'live FPS mixed secondary swap chains or counted a dropped displayed frame'
  Assert-True ($displaySampler.MetricLabel -eq '显示帧率') 'live FPS did not prefer the actual display cadence'
} finally { $displaySampler.Dispose() }
$presentSampler = New-Object DfbLivePresentMonSampler
try {
  $presentSampler.AcceptCsvLine('Application,ProcessID,SwapChainAddress,DisplayedTime,FrameTime')
  foreach ($index in 1..8) { $presentSampler.AcceptCsvLine("game.exe,42,0xMAIN,NA,20") }
  Assert-True ([math]::Abs($presentSampler.ReadFps()-50.0) -lt 0.01) 'live FPS fallback did not read PresentMon FrameTime'
  Assert-True ($presentSampler.MetricLabel -eq '呈现帧率') 'unavailable display tracking was not labeled as present FPS'
} finally { $presentSampler.Dispose() }
$cpuSampler = New-Object DfbProcessorUtilitySampler
try {
  Start-Sleep -Milliseconds 1000
  $cpuUtility = $cpuSampler.Read()
  Assert-True (-not [double]::IsNaN($cpuUtility) -and $cpuUtility -ge 0 -and $cpuUtility -le 100) 'processor utility counter returned an invalid value'
} finally { $cpuSampler.Dispose() }
$memory = [DfbLiveSystemMetrics]::ReadMemoryUsage()
Assert-True (-not [double]::IsNaN($memory) -and $memory -ge 0 -and $memory -le 100) 'memory usage probe returned an invalid value'

'UI hardware dashboard tests passed.'
