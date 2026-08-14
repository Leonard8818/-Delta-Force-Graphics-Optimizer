#requires -Version 5.1
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$guiPath = Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}

function Assert-Throws([scriptblock]$Action, [string]$Message) {
  try {
    & $Action
    throw "ASSERT FAILED: $Message"
  } catch {
    if ($_.Exception.Message -like 'ASSERT FAILED:*') { throw }
  }
}

$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$tokens, [ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI PowerShell AST parse failed: ' + (($errors | ForEach-Object Message) -join '; '))
$raw = [IO.File]::ReadAllText($guiPath, [Text.Encoding]::UTF8)
$referenceRaw = Get-Content -LiteralPath (Join-Path $root 'data\streamer-settings.json') -Raw -Encoding UTF8
$referenceData = $referenceRaw | ConvertFrom-Json

Assert-True ($raw -match '(?s)\$window\.ShowDialog\(\)\s*\|\s*Out-Null\s*#.*?Invoke-AppExit') `
  'normal main-window close does not terminate background runspaces and release the launcher session'
Assert-True ($raw.Contains("`$script:GuiVersion = '0.23.0.5'") -and
    $raw.Contains("`$script:DisplayVersion = '0.23.0.5'") -and
    $raw.Contains('Text="[ v0.23.0.5 ]"')) `
  'the unified v0.23.0.5 version is missing or inconsistent'
Assert-True ($raw.Contains('以下内容请进入BIOS按照教程手动操作。') -and
  -not $raw.Contains('以下问题本工具改不了，但按教程手动处理并不难：')) `
  'health-check BIOS guidance still uses the old wording'
Assert-True (-not $raw.Contains('「立即更新」全程自动：')) 'obsolete inline-update explanation is still shown'
Assert-True $raw.Contains("`$script:UpdUi.InlineNote.Visibility = 'Collapsed'") 'inline-update explanation row is not collapsed'
Assert-True ($raw -match 'Start-Process\s+-FilePath\s+\$PresentMon\s+-WorkingDirectory\s+\(\[Environment\]::SystemDirectory\)') `
  'PresentMon does not use the trusted neutral working directory'
Assert-True ($raw -match 'Start-Process\s+-FilePath\s+\$SetupFile\s+-WorkingDirectory\s+\(\[Environment\]::SystemDirectory\)') `
  'inline setup still inherits the product working directory'
Assert-True ($raw.Contains('Content="上传完整诊断"') -and
  $raw.Contains("`$lines.Add('== 运行环境与显示 / 音频 ==')") -and
  $raw.Contains("`$lines.Add('== 关键环境变量（脱敏） ==')")) `
  'expanded negative-effect diagnostic collection is missing from the report button'
Assert-True ($raw.Contains('function Show-DiagnosticFeedbackDialog') -and
  $raw.Contains("Id = 'frame_drops'; Label = '掉帧 / 帧率波动'") -and
  $raw.Contains("Id = 'black_screen_audio'; Label = '游戏全屏黑屏，但仍有声音'") -and
  $raw.Contains("Id = 'black_screen_no_audio'; Label = '游戏全屏黑屏，声音也中断'") -and
  $raw.Contains("Id = 'partial_black_screen'; Label = '游戏内部分区域黑屏 / 黑块'") -and
  $raw.Contains("Id = 'black_screen_alt_tab'; Label = 'Alt+Tab / 切换显示模式后黑屏'") -and
  $raw.Contains("Id = 'black_screen_frame_generation'; Label = '开启帧生成后出现黑屏'") -and
  $raw.Contains("Id = 'black_screen_external_display'; Label = '外接显示器 / 独显直连时黑屏'") -and
  $raw.Contains("Id = 'system_lag'; Label = '电脑整体卡顿 / 响应慢'") -and
  $raw.Contains("Id = 'gpu_heat'; Label = 'GPU 占用或温度过高'") -and
  $raw.Contains("Id = 'fps_gain'; Label = '平均帧率提升（涨帧）'") -and
  $raw.Contains("Id = 'one_percent_gain'; Label = '1% Low 提升 / 掉帧减少'")) `
  'diagnostic feedback page is missing required multi-select problem/improvement choices'
Assert-True ($raw.Contains('New-Object Windows.Controls.ComboBoxItem') -and
  $raw.Contains("Test-RecommendedGpuSpoofModel `$model") -and
  $raw.Contains("`$this.SelectedItem.Tag")) `
  'GPU model selector does not render recommendation stars separately from the registry value'
Assert-True ($raw.Contains("Get-XmpBiosTutorial `$script:HardwareInfo") -and
  $raw.Contains("New-HwCard 'SYSTEM' `$systemName") -and
  $raw.Contains('电脑：$($hw.ComputerBrand) $($hw.ComputerModel)')) `
  'computer brand is not displayed or the BIOS tutorial is not brand-aware'
Assert-True ($raw.Contains('Get-GpuGuideText $Hw.MainGpuVendor $Hw.MainGpuName $Hw.IsLaptop $Hw')) `
  'GPU guide does not pass detected hardware into the configuration-aware recommendation'
Assert-True ($raw.Contains('x:Name="TabFrameFixBtn" Content="掉帧修复"') -and
  $raw.Contains('x:Name="FrameFixPage"') -and
  $raw.Contains("@('framefix', 'TabFrameFixBtn', 'FrameFixPage')") -and
  $raw.Contains("`$ui.TabFrameFixBtn.Add_Click({ Select-Tab 'framefix' })")) `
  'frame-drop repair tab is not wired into the main navigation'
Assert-True ($raw.Contains('x:Name="TabTuneBtn" Style="{StaticResource TabBtn}" Tag="" IsEnabled="False" Opacity="1"') -and
  $raw.Contains('Text="AI定制优化"') -and
  $raw.Contains('Text="（敬请期待）" Foreground="{DynamicResource Gold}" FontWeight="Bold"') -and
  -not $raw.Contains("`$ui.TabTuneBtn.Add_Click({ Select-Tab 'tune' })")) `
  'AI custom optimization placeholder is not disabled or its coming-soon label is not highlighted'
Assert-True ($raw.Contains('x:Name="FrameFixCacheBtn" Content="清理着色器缓存"') -and
  $raw.Contains('x:Name="FrameFixGpuPrefBtn" Content="设置高性能 GPU"') -and
  $raw.Contains('x:Name="FrameFixVcBtn" Content="检查 VC++ 运行库"') -and
  $raw.Contains("`$ui.FrameFixCacheBtn.Add_Click({ Invoke-FrameFixCacheCleanup })") -and
  $raw.Contains("`$ui.FrameFixGpuPrefBtn.Add_Click({ Invoke-FrameFixGpuPreference })") -and
  $raw.Contains("`$ui.FrameFixVcBtn.Add_Click({ Invoke-FrameFixVcredistCheck })") -and
  $raw.Contains('x:Name="FrameFixProgressPanel"') -and
  $raw.Contains('x:Name="FrameFixProgressBar"') -and
  $raw.Contains('x:Name="FrameFixProgressText"')) `
  'frame-drop page still exposes text-only advice without direct software actions'
Assert-True ($raw.Contains('@($ui.ItemPanel.Children) + @($ui.RiskyPanel.Children)') -and
  $raw.Contains('包含 ★ 显卡型号伪装 · 执行前二次确认')) `
  'optimization select-all does not include the GPU model spoof row'
Assert-True ($raw.Contains("Show-ConfirmDialog '未选择优化项' 'NO ITEMS SELECTED'") -and
  $raw.Contains('请先勾选至少一个优化项目，再点击「执行优化」。')) `
  'execute optimization does not show a visible prompt when no item is selected'
Assert-True ($raw.Contains("`$lines.Add('== 用户反馈选择 ==')") -and
  $raw.Contains('New-DiagnosticReport -Feedback $feedback') -and
  $raw.Contains("if ((`$issueChoices.Count + `$benefitChoices.Count) -eq 0)")) `
  'diagnostic feedback selection is not required and embedded in the uploaded report'
$recommended = @($referenceData.streamers | Where-Object { $_.featured -eq $true })
Assert-True ($recommended.Count -eq 1 -and $referenceData.streamers[0].featured -eq $true) `
  'game settings reference does not expose exactly one featured recommendation as the first column'
Assert-True (-not $recommended[0].platform -and -not $referenceRaw.Contains('本次推荐')) `
  'featured recommendation still shows the redundant small subtitle'
Assert-True (-not $raw.Contains('$meta = New-Text "数据更新：') -and
  -not $raw.Contains('$nt = New-WrapText "备注：$($s.notes)"') -and
  $raw.Contains('$s.captured -and $s.featured -ne $true')) `
  'reference page still shows the removed metadata/note or the recommendation capture date'
$recommendedSettings = $recommended[0].settings
foreach ($expected in @(
  @('显示模式', '全屏（频繁切屏可用无边框）'), @('武器动态模糊', '关闭'),
  @('场景视距', '极高'), @('渲染倍率', '100%'), @('纹理质量', '极高'),
  @('阴影贴图分辨率', '低'), @('DLSS 帧生成', '开启'), @('后台帧数上限', '5')
)) {
  Assert-True ("$($recommendedSettings.PSObject.Properties[$expected[0]].Value)" -eq $expected[1]) `
    "recommended game setting mismatch: $($expected[0])"
}
$referenceSchemaNames = @($referenceData.settings_schema | ForEach-Object { "$($_.name)" })
Assert-True ($referenceSchemaNames -contains '显示适配器' -and
  $referenceSchemaNames -contains 'Intel Xe 低延迟（实验性）') `
  'recommended settings are missing from the displayed reference schema'
Assert-True ($raw.Contains("'★ 推荐设置'") -and $raw.Contains('性能优先推荐 · 设备相关项请按本机调整')) `
  'featured recommendation is not visually distinguished in the game settings page'
$screenshotTerm = -join @([char]0x622A, [char]0x56FE)
Assert-True (-not $raw.Contains($screenshotTerm) -and -not $referenceRaw.Contains($screenshotTerm)) `
  'game settings reference still contains screenshot-related wording'
Assert-True ($raw.Contains('x:Name="InlineRestorePanel"') -and
  -not $raw.Contains('function Show-RestoreManagerDialog') -and
  $raw.Contains('可单选、多选或全选') -and $raw.Contains('全选可复原项目') -and
  $raw.Contains('复原所选项目') -and $raw.Contains('确认全部复原') -and
  $raw.Contains('Invoke-ElevatedEngineAction -Action Restore -ListRestoreItems') -and
  $raw.Contains('Invoke-ElevatedEngineAction -Action Restore -RestoreItemIds')) `
  'optimization page does not expose inline single/multi/select-all plus full restore through the protected engine'
Assert-True ($raw.Contains("'SystemRoot','WINDIR','ProgramData','ProgramFiles','ProgramFiles(x86)','TEMP','TMP','PATH','PSModulePath','COMSPEC','PATHEXT','__COMPAT_LAYER'") -and
  $raw.Contains('（仅记录名称，不上传值）')) `
  'diagnostic environment collection is not value-allowlisted or does not redact injection values'
Assert-True ($raw.Contains("`$lines.Add('== 分析字段（schema v3） ==')") -and
  $raw.Contains('feedback_issue_ids=') -and $raw.Contains('cpu_visible_cores=') -and
  $raw.Contains('memory_configured_mhz=') -and $raw.Contains('virtual_display_count=') -and
  $raw.Contains('gpu_panel_status=') -and $raw.Contains('pagefile_auto_managed=') -and
  $raw.Contains('main_gpu_driver_version=') -and $raw.Contains('main_gpu_model_verified=') -and
  $raw.Contains('main_gpu_pci_matched=') -and $raw.Contains('display_mode=') -and
  $raw.Contains('active_related_process_keys=')) `
  'diagnostic report is missing stable machine-readable recommendation fields'
Assert-True ($raw.Contains('function Get-TelemetryAnalysisContext') -and
  $raw.Contains('function Get-TelemetryRegValue') -and
  $raw.Contains('cpuEfficiencyClasses =') -and $raw.Contains('windowsReleaseChannel =') -and
  $raw.Contains('optimizationItemIds =') -and $raw.Contains('gpuPanelInstalledKeys =') -and
  $raw.Contains('activeSoftwareKeys =') -and $raw.Contains('pendingBackupCount =') -and
  $raw.Contains('systemDriveMediaType =') -and $raw.Contains('gameDriveMediaType =')) `
  'future personalization context is missing required fixed-schema fields'
Assert-True ($raw.Contains("'GamePP'='gamepp'") -and
  $raw.Contains('processCpuAvgPct=') -and $raw.Contains('systemMemoryUsedAvgPct=') -and
  $raw.Contains('gpuDedicatedMemoryAvgMb=') -and $raw.Contains('presentedFrameTimeCvPct=') -and
  $raw.Contains('$physicalIndexByAdapter') -and
  $raw.Contains('$physicalIndexByAdapter[$gameRenderAdapterLuid]') -and
  $raw.Contains('$dedicatedCounters.Count') -and $raw.Contains('$sharedCounters.Count')) `
  'Game++-inspired runtime signals are missing from collection'
Assert-True ($raw.Contains('[math]::Max($gpuDedicatedMb.Count,$gpuSharedMb.Count)')) `
  'partial GPU process-memory counters can still be mislabeled as zero samples'
Assert-True ($raw.Contains("`$session.validity -eq 'valid'") -and
  $raw.Contains("`$session.frameCount -lt 1000") -and $raw.Contains("`$session.focusLostSec -gt 5") -and
  -not $raw.Contains('if ($session.avgFps -le 0 -and $session.gpuUtilAvg -le 0)')) `
  'ordinary performance capture can still upload a known-invalid frame sample'

function Find-GuiFunction([string]$Name) {
  $matches = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name
  }, $true))
  Assert-True ($matches.Count -eq 1) "GUI helper missing or duplicated: $Name"
  return $matches[0]
}

$getUacFunction = Find-GuiFunction 'Get-UacEnableLuaValue'
$getFilterFunction = Find-GuiFunction 'Get-UacFilterAdministratorTokenValue'
$sidFunction = Find-GuiFunction 'Test-IsBuiltInAdministratorSid'
$enableUacFunction = Find-GuiFunction 'Enable-UacForNextRestart'
$localNoBackupFunction = Find-GuiFunction 'Invoke-LocalNoBackupItems'
$validatedCandidateFunction = Find-GuiFunction 'Get-ValidatedTuningCandidateRuntime'
$restoreManagerFunction = Find-GuiFunction 'Initialize-InlineRestorePanel'
$restoreActionFunction = Find-GuiFunction 'Invoke-InlineRestoreAction'
$restoreSelectionFunction = Find-GuiFunction 'Update-InlineRestoreSelection'
$hideRestoreFunction = Find-GuiFunction 'Hide-InlineRestorePanel'
$dropFramePlanFunction = Find-GuiFunction 'Get-DropFrameRepairPlan'
$frameCacheFunction = Find-GuiFunction 'Invoke-FrameFixCacheCleanup'
$frameGpuFunction = Find-GuiFunction 'Invoke-FrameFixGpuPreference'
$frameVcFunction = Find-GuiFunction 'Invoke-FrameFixVcredistCheck'
$frameProgressFunction = Find-GuiFunction 'Set-FrameFixProgress'
$commonHighlightFunction = Find-GuiFunction 'Set-DropFrameCommonText'
$vendorLinkFunction = Find-GuiFunction 'Set-DropFrameVendorText'
$updateDropFrameFunction = Find-GuiFunction 'Update-DropFrameRepairPage'
$itemRowFunction = Find-GuiFunction 'New-ItemRow'
$protectReportFunction = Find-GuiFunction 'Protect-ReportText'
$gpuPanelInventoryFunction = Find-GuiFunction 'Get-GuiGpuPanelInventory'

& {
  param([string]$FunctionText)
  $script:OriginalUserLocalAppData = 'C:\Users\Administrator\AppData\Local'
  Invoke-Expression $FunctionText
  $machine = [Environment]::MachineName
  $protected = Protect-ReportText "FilterAdministratorToken=1; C:\Users\Administrator\AppData\Local; user Administrator; pc $machine"
  Assert-True $protected.Contains('FilterAdministratorToken=1') `
    'diagnostic redaction corrupts an identifier containing the original user name'
  Assert-True ($protected.Contains('C:\Users\<user>\AppData\Local') -and
    $protected.Contains('user <user>') -and $protected.Contains('pc <pc>')) `
    'diagnostic redaction does not cover the authenticated original profile and machine token'
} $protectReportFunction.Extent.Text

& {
  param([string]$FunctionText)
  $script:BrokerCalls = New-Object System.Collections.ArrayList
  $script:ReturnInvalidGpuInventory = $false
  function Invoke-EngineHostUserAction([string]$Action, [string]$Payload = '') {
    [void]$script:BrokerCalls.Add([pscustomobject]@{ Action=$Action; Payload=$Payload })
    if ($script:ReturnInvalidGpuInventory) { return '[]' }
    switch ($Action) {
      'GetNvidiaPanelApps' { '[{"Key":"nv-cpl","Installed":true},{"Key":"nv-app","Installed":false}]' }
      'GetAmdPanelApps' { '[{"Key":"amd-sw","Installed":true}]' }
      'GetIntelPanelApps' { '[{"Key":"intel-gcc","Installed":true}]' }
    }
  }
  function Write-Log([string]$Message) { $script:GpuInventoryLog = $Message }
  Invoke-Expression $FunctionText
  $script:RepairOnlySession = $true
  $compatibility = Get-GuiGpuPanelInventory 'NVIDIA'
  $script:RepairOnlySession = $false
  $nvidia = Get-GuiGpuPanelInventory ' nViDiA '
  $amd = Get-GuiGpuPanelInventory 'AMD'
  $intel = Get-GuiGpuPanelInventory 'intel'
  $unknown = Get-GuiGpuPanelInventory 'Unknown'
  Assert-True (($script:BrokerCalls.Action -join ',') -eq 'GetNvidiaPanelApps,GetAmdPanelApps,GetIntelPanelApps') `
    'GPU software detection does not map vendors to fixed broker actions'
  Assert-True (@($script:BrokerCalls | Where-Object Payload).Count -eq 0) `
    'GPU software detection still sends vendor identity as a free-text broker payload'
  Assert-True ($compatibility.Status -eq 'unavailable_in_compatibility_mode' -and
    @($compatibility.Apps).Count -eq 0 -and $nvidia.Status -eq 'ok' -and
    $amd.Status -eq 'ok' -and $intel.Status -eq 'ok' -and
    $unknown.Status -eq 'unsupported_vendor' -and @($unknown.Apps).Count -eq 0) `
    "GPU software inventory status classification is inconsistent: compatibility=$($compatibility.Status), NVIDIA=$($nvidia.Status), AMD=$($amd.Status), Intel=$($intel.Status), unknown=$($unknown.Status), log=$script:GpuInventoryLog"
  $script:ReturnInvalidGpuInventory = $true
  $invalid = Get-GuiGpuPanelInventory 'NVIDIA'
  Assert-True ($invalid.Status -eq 'broker_failed' -and @($invalid.Apps).Count -eq 0) `
    'malformed GPU software inventory is treated as a successful detection'
} $gpuPanelInventoryFunction.Extent.Text
$dropFramePlanText = $dropFramePlanFunction.Extent.Text
Assert-True ($dropFramePlanText.Contains("'NVIDIA'") -and $dropFramePlanText.Contains("'AMD'") -and
  $dropFramePlanText.Contains("'Intel'") -and $dropFramePlanText.Contains('MainGpuVendor') -and
  $dropFramePlanText.Contains('MainGpuName')) `
  'frame-drop repair plan is not generated from the detected primary GPU vendor and model'
$accountTerm = -join @([char]0x8D26, [char]0x53F7)
Assert-True (-not $dropFramePlanText.Contains($accountTerm)) `
  'frame-drop repair plan still includes account-based diagnosis'
. ([scriptblock]::Create($dropFramePlanText))
$nvPlan = Get-DropFrameRepairPlan ([pscustomobject]@{ MainGpuVendor='NVIDIA'; MainGpuName='GeForce RTX 4070' })
$amdPlan = Get-DropFrameRepairPlan ([pscustomobject]@{ MainGpuVendor='AMD'; MainGpuName='Radeon RX 7800 XT' })
$intelPlan = Get-DropFrameRepairPlan ([pscustomobject]@{ MainGpuVendor='Intel'; MainGpuName='Intel Arc B580' })
Assert-True ($nvPlan.VendorTitle -eq 'NVIDIA 专项排查' -and $nvPlan.VendorText.Contains('NVIDIA 控制面板')) `
  'NVIDIA frame-drop recommendation is missing'
Assert-True ($amdPlan.VendorTitle -eq 'AMD Radeon 专项排查' -and $amdPlan.VendorText.Contains('Radeon Anti-Lag')) `
  'AMD frame-drop recommendation is missing'
Assert-True ($intelPlan.VendorTitle -eq 'Intel 显卡专项排查' -and $intelPlan.VendorText.Contains('Resizable BAR')) `
  'Intel frame-drop recommendation is missing'
Assert-True ($nvPlan.Summary.StartsWith('近期版本掉帧') -and -not $nvPlan.Summary.Contains('检测到主力显卡')) `
  'frame-drop summary still repeats the detected primary GPU sentence'
Assert-True ($nvPlan.Common.Contains('【可执行】') -and $nvPlan.Common.Contains('【可检查】') -and
  -not $nvPlan.Common.Contains('【软件可执行】') -and -not $nvPlan.Common.Contains('【软件可检查】')) `
  'frame-drop common plan does not distinguish direct actions from manual advice'
Assert-True ($commonHighlightFunction.Extent.Text.Contains('FrameFixCommonText.Inlines.Clear()') -and
  $commonHighlightFunction.Extent.Text.Contains("`$run.Background") -and
  $commonHighlightFunction.Extent.Text.Contains("`$run.FontWeight = 'Bold'")) `
  'frame-drop direct-action labels are not rendered as highlighted inline runs'
Assert-True ($vendorLinkFunction.Extent.Text.Contains('Windows.Documents.Hyperlink') -and
  $vendorLinkFunction.Extent.Text.Contains('NVIDIA 控制面板') -and
  $vendorLinkFunction.Extent.Text.Contains('NVIDIA App') -and
  $vendorLinkFunction.Extent.Text.Contains('Open-GpuPanel $this.Tag.App') -and
  $vendorLinkFunction.Extent.Text.Contains('Open-HelpLink') -and
  $vendorLinkFunction.Extent.Text.Contains("`$link.Foreground = New-Brush `$script:C.Green") -and
  $updateDropFrameFunction.Extent.Text.Contains('Set-DropFrameVendorText')) `
  'NVIDIA control panel and NVIDIA App names are not highlighted clickable direct links'
Assert-True ($frameCacheFunction.Extent.Text.Contains("Get-FrameFixActionItem 'shader-cache-clean'") -and
  $frameCacheFunction.Extent.Text.Contains('Invoke-LocalNoBackupItems') -and
  $frameGpuFunction.Extent.Text.Contains("-ItemIds @('gpu-pref')") -and
  $frameGpuFunction.Extent.Text.Contains('BackupError') -and
  $frameVcFunction.Extent.Text.Contains("Get-FrameFixActionItem 'vcredist-check'") -and
  $frameVcFunction.Extent.Text.Contains('Show-HealthDialog')) `
  'frame-drop direct actions do not reuse the protected apply/check/cache paths'
Assert-True ($frameProgressFunction.Extent.Text.Contains("IsIndeterminate = `$true") -and
  $frameProgressFunction.Extent.Text.Contains("Value = 100") -and
  $frameCacheFunction.Extent.Text.Contains('Set-FrameFixProgress') -and
  $frameGpuFunction.Extent.Text.Contains('Set-FrameFixProgress') -and
  $frameVcFunction.Extent.Text.Contains('Set-FrameFixProgress')) `
  'one or more frame-drop direct actions do not display start/completion progress'
Assert-True ($itemRowFunction.Extent.Text.Contains("`$Item.Id -eq 'xmp-check'") -and
  $itemRowFunction.Extent.Text.Contains("`$starRun.Text = '★ '") -and
  $itemRowFunction.Extent.Text.Contains('Windows.Thickness 21, 0, 0, 0') -and
  $itemRowFunction.Extent.Text.Contains("`$starRun.Foreground = New-Brush `$nameColor") -and
  $itemRowFunction.Extent.Text.Contains("`$nameRun.Foreground = New-Brush `$nameColor") -and
  $itemRowFunction.Extent.Text.Contains('Add_MouseLeftButtonUp') -and
  $itemRowFunction.Extent.Text.Contains('Show-HealthDialog')) `
  'memory frequency item is not starred and clickable through the existing health dialog'
$restoreManagerText = $restoreManagerFunction.Extent.Text
Assert-True ($restoreManagerText.Contains("`$item.Status -eq 'conflict'") -and
  $restoreManagerText.Contains('旧版本备份') -and $restoreManagerText.Contains('仅支持下方「全部复原」')) `
  'inline restore manager does not explain conflict protection or v2 full-restore-only compatibility'
Assert-True ($restoreActionFunction.Extent.Text.Contains("ValidateSet('selected_items','all')") -and
  $restoreActionFunction.Extent.Text.Contains('Invoke-ElevatedEngineAction -Action Restore -RestoreItemIds $itemIds') -and
  $restoreActionFunction.Extent.Text.Contains('Invoke-ElevatedEngineAction -Action Restore })') -and
  $raw.Contains("`$ui.InlineRestoreSelectedBtn.Add_Click({ Invoke-InlineRestoreAction 'selected_items' })") -and
  $raw.Contains("`$ui.InlineRestoreAllBtn.Add_Click({ Invoke-InlineRestoreAction 'all' })") -and
  $raw.Contains('检测到后续修改的项目不会被选择性覆盖。')) `
  'inline restore buttons are not connected to selected/full protected restore actions'
Assert-True ($restoreActionFunction.Extent.Text.Contains("if (`$failN -gt 0) { '还原未完成' } else { '还原完成' }") -and
  $restoreActionFunction.Extent.Text.Contains("if (`$failN -gt 0) { 'RESTORE INCOMPLETE' } else { 'RESTORE DONE' }") -and
  $restoreActionFunction.Extent.Text.Contains("if (`$failN -gt 0) { '全部复原未完成' } else { '全部复原完成' }")) `
  'full restore still presents a partial failure as completed'
$mainXamlMatch = [regex]::Match($raw, '(?s)\$xaml\s*=\s*@''\r?\n(.*?)\r?\n''@\r?\n\r?\n\$window\s*=')
Assert-True $mainXamlMatch.Success 'main window XAML block is missing'
Add-Type -AssemblyName PresentationFramework
$mainXamlWindow = [Windows.Markup.XamlReader]::Parse($mainXamlMatch.Groups[1].Value)
Assert-True ($mainXamlWindow.FindName('InlineRestorePanel') -and
  $mainXamlWindow.FindName('InlineRestoreSelectedBtn') -and $mainXamlWindow.FindName('InlineRestoreAllBtn') -and
  $mainXamlWindow.FindName('InlineRestoreSelectAllBtn') -and $mainXamlWindow.FindName('InlineRestoreClearBtn')) `
  'main optimization page XAML does not parse with all inline restore controls'
$window = $mainXamlWindow
$ui = @{}
foreach ($name in 'InlineRestorePanel','InlineRestoreItemsPanel','InlineRestoreEmptyText',
                   'InlineRestoreLegacyNotice','InlineRestoreLegacyText','InlineRestoreSelectedText','InlineRestoreAllSummary',
                   'InlineRestoreSelectAllBtn','InlineRestoreClearBtn','InlineRestoreSelectedBtn','InlineRestoreAllBtn',
                   'InlineRestoreCloseBtn','RestoreBtn') {
  $ui[$name] = $window.FindName($name)
}
$script:C = @{ LineSoft='#FF16241F'; TextPri='#FFFFFFFF'; TextMut='#FF7A8580'; Green='#FF00E884'; Danger='#FFFF6B6B'; Gold='#FFE5C46A' }
$script:Busy = $false
function New-Brush([string]$Hex) { (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex) }
function Test-TuningExperimentActive { $false }
. ([scriptblock]::Create($restoreSelectionFunction.Extent.Text))
. ([scriptblock]::Create($hideRestoreFunction.Extent.Text))
. ([scriptblock]::Create($restoreManagerFunction.Extent.Text))
$restoreCatalogFixture = [pscustomobject]@{
  Items = @(
    [pscustomobject]@{ Id='gpu-pref'; Name='强制游戏使用高性能 GPU'; CanRestore=$true; SettingCount=1; Status='ready'; StatusText='可精确复原'; RebootRequired=$false; Reason='' },
    [pscustomobject]@{ Id='conflict-item'; Name='后续已修改项目'; CanRestore=$false; SettingCount=1; Status='conflict'; StatusText='检测到后续修改'; RebootRequired=$false; Reason='保持当前值' }
  )
  LegacyBackupCount = 0; UnsupportedV3ItemCount = 0; ActiveItemCount = 2; ActiveOpCount = 2
  ActiveBackupCount = 1; HasActiveChanges = $true
}
Initialize-InlineRestorePanel $restoreCatalogFixture
$readyRestoreCheck = @($script:InlineRestoreChecks.ToArray() | Where-Object Tag -eq 'gpu-pref')[0]
$conflictRestoreCheck = @($script:InlineRestoreChecks.ToArray() | Where-Object Tag -eq 'conflict-item')[0]
Assert-True ($ui.InlineRestorePanel.Visibility -eq 'Visible' -and $ui.InlineRestoreItemsPanel.Children.Count -eq 2 -and
  $readyRestoreCheck.IsEnabled -and -not $conflictRestoreCheck.IsEnabled -and
  -not $ui.InlineRestoreSelectedBtn.IsEnabled -and $ui.InlineRestoreAllBtn.IsEnabled) `
  'inline restore catalog did not render directly in the optimization page with safe enablement'
$readyRestoreCheck.IsChecked = $true
Update-InlineRestoreSelection
Assert-True ($ui.InlineRestoreSelectedText.Text -eq '已选择 1 项' -and $ui.InlineRestoreSelectedBtn.IsEnabled) `
  'inline restore selection does not enable the selected restore action'
Hide-InlineRestorePanel
Assert-True ($ui.InlineRestorePanel.Visibility -eq 'Collapsed' -and $ui.RestoreBtn.Content -eq '还原设置') `
  'inline restore panel does not collapse back into the optimization page'
$repairBranches = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.IfStatementAst] -and
    $node.Clauses.Count -gt 0 -and $node.Clauses[0].Item1.Extent.Text.Trim() -eq '$needsUacRepair'
}, $true))
Assert-True ($repairBranches.Count -eq 1) 'disabled-UAC recovery branch missing or duplicated'
$repairText = $repairBranches[0].Extent.Text
$hostAssignments = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
    $node.Left.VariablePath.UserPath -ieq 'Host'
}, $true))
Assert-True ($hostAssignments.Count -eq 0) 'GUI assigns PowerShell built-in read-only $Host variable'
Assert-True ($raw.Contains('$engineHostProcess = Get-CimInstance Win32_Process')) `
  'GUI bootstrap does not store the EngineHost process in a non-reserved variable'

Assert-True $raw.Contains('Test-IsBuiltInAdministratorSid $script:OriginalUserSid') `
  'startup does not identify RID-500 from the authenticated original user SID'
Assert-True (-not $raw.Contains('Test-IsBuiltInAdministratorSid $currentSidValue')) `
  'startup can mistake an OTS approval administrator for the original user'
Assert-True (-not ($raw -match '\$env:(?:USERNAME|USERDOMAIN|COMPUTERNAME)')) `
  'high GUI diagnostics still read the UAC approval account environment'
Assert-True ($raw.Contains('Split-Path -Parent $script:OriginalUserLocalAppData') -and
  $raw.Contains('[Environment]::MachineName')) `
  'diagnostic redaction is not derived from the authenticated original user context'
Assert-True $raw.Contains('if (-not $isAdminGui) { Stop-UntrustedGuiStartup') 'main GUI does not fail closed without an administrator token'
Assert-True $raw.Contains('$enableLUA = Get-UacEnableLuaValue') 'elevated startup does not inspect the real EnableLUA policy'
Assert-True $raw.Contains('$filterAdministratorToken') 'RID-500 startup does not inspect FilterAdministratorToken'
Assert-True $repairText.Contains('[Windows.MessageBoxButton]::YesNoCancel') 'UAC/net-cafe choice is not explicitly confirmed by the user'
Assert-True $repairText.Contains('Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode:$isBuiltInAdministrator') 'confirmed recovery does not select the correct ordinary/RID-500 write set'
Assert-True $repairText.Contains('管理员审批模式') 'RID-500 recovery does not explain Administrator Approval Mode'
Assert-True $repairText.Contains('软件不会自动重启') 'UAC recovery does not state that restart timing remains with the user'
Assert-True ($repairText.Contains('$script:NetCafeCompatibilityMode = $true') -and
  $repairText.Contains('本次不修改 UAC，也不要求重启') -and
  $repairText.Contains('用户缓存清理、显卡软件检测和外链入口会停用')) `
  'repair-only session does not offer the explicit no-restart net-cafe compatibility mode'
Assert-True ($repairText -match '(?s)MessageBoxResult\]::No.*Enable-UacForNextRestart.*exit') `
  'policy-repair choice does not exit after persisting restart-required UAC settings'
Assert-True ($repairText -match '(?s)else \{ exit \}\s*\}') `
  'cancelled UAC/net-cafe choice can continue into the GUI'
Assert-True (-not $repairText.Contains('Restart-Computer') -and -not $repairText.Contains('shutdown.exe')) 'UAC recovery must not force a restart'
Assert-True ($raw -match 'NetCafeCompatibilityMode[\s\S]{0,500}Where-Object \{ \$_\.Kind -ne ''cache'' \}') `
  'net-cafe compatibility mode does not remove the medium-token cache action from the UI'

$uacWrites = @($enableUacFunction.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'New-ItemProperty'
}, $true))
Assert-True ($uacWrites.Count -eq 2) 'UAC helper must define only the EnableLUA and conditional FilterAdministratorToken writes'

# PowerShell 对 Generic.List<T> 的直接数组子表达式 `@($list)` 会抛
# System.ArgumentException: Argument types do not match。扫描每个 GUI helper 内的 List 声明，
# 禁止以后再次写回这种会在 Windows PowerShell 5.1 实机上阻断执行收尾的形式。
$genericListWrapFailures = New-Object 'System.Collections.Generic.List[string]'
$guiFunctions = @($ast.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst]
}, $true))
foreach ($function in $guiFunctions) {
  $listAssignments = @($function.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
      $node.Right.Extent.Text -match '(?i)^\s*New-Object\s+[''"]?(?:System\.)?Collections\.Generic\.List\['
  }, $true))
  foreach ($assignment in $listAssignments) {
    $variableName = $assignment.Left.VariablePath.UserPath
    $directWrapPattern = '^@\(\s*\$' + [regex]::Escape($variableName) + '\s*\)$'
    $badWraps = @($function.FindAll({
      param($node)
      $node -is [Management.Automation.Language.ArrayExpressionAst]
    }, $true) | Where-Object { $_.Extent.Text -match $directWrapPattern })
    foreach ($badWrap in $badWraps) {
      [void]$genericListWrapFailures.Add("$($function.Name):$($badWrap.Extent.StartLineNumber) $($badWrap.Extent.Text)")
    }
  }
}
Assert-True ($genericListWrapFailures.Count -eq 0) `
  ('Generic.List must call ToArray() before @(): ' + ($genericListWrapFailures -join '; '))

# 只执行四个纯 helper，并用同名 mock 拦截注册表访问；测试不得改变测试机的真实 UAC。
$getUacFunctionText = $getUacFunction.Extent.Text
$getFilterFunctionText = $getFilterFunction.Extent.Text
$sidFunctionText = $sidFunction.Extent.Text
$enableUacFunctionText = $enableUacFunction.Extent.Text
& {
  param(
    [string]$GetFunctionText,
    [string]$GetFilterFunctionText,
    [string]$SidFunctionText,
    [string]$EnableFunctionText
  )

  $script:MockUacValues = @{ EnableLUA = 0; FilterAdministratorToken = 0 }
  $script:MockUacReadFailureName = ''
  $script:MockUacWriteFailureName = ''
  $script:MockUacHoldWriteName = ''
  $script:MockUacWrites = New-Object 'System.Collections.Generic.List[object]'
  $script:MockUacReads = New-Object 'System.Collections.Generic.List[string]'

  function Reset-MockUac([int]$EnableLUA = 0, [int]$FilterAdministratorToken = 0) {
    $script:MockUacValues = @{ EnableLUA = $EnableLUA; FilterAdministratorToken = $FilterAdministratorToken }
    $script:MockUacReadFailureName = ''
    $script:MockUacWriteFailureName = ''
    $script:MockUacHoldWriteName = ''
    $script:MockUacWrites.Clear()
    $script:MockUacReads.Clear()
  }

  function Get-ItemProperty {
    param([string]$LiteralPath, [string]$Name, [object]$ErrorAction)
    [void]$script:MockUacReads.Add($Name)
    if ($script:MockUacReadFailureName -eq $Name) { throw 'simulated registry read failure' }
    if ($Name -eq 'EnableLUA') {
      return [pscustomobject]@{ EnableLUA = $script:MockUacValues.EnableLUA }
    }
    if ($Name -eq 'FilterAdministratorToken') {
      return [pscustomobject]@{ FilterAdministratorToken = $script:MockUacValues.FilterAdministratorToken }
    }
    throw "unexpected registry read: $Name"
  }

  function New-ItemProperty {
    param(
      [string]$LiteralPath,
      [string]$Name,
      [object]$Value,
      [string]$PropertyType,
      [switch]$Force,
      [object]$ErrorAction
    )
    [void]$script:MockUacWrites.Add([pscustomobject]@{
      LiteralPath = $LiteralPath
      Name = $Name
      Value = $Value
      PropertyType = $PropertyType
      Force = [bool]$Force
    })
    if ($script:MockUacWriteFailureName -eq $Name) { throw 'simulated registry write failure' }
    if ($script:MockUacHoldWriteName -ne $Name) { $script:MockUacValues[$Name] = $Value }
  }

  Invoke-Expression $GetFunctionText
  Invoke-Expression $GetFilterFunctionText
  Invoke-Expression $SidFunctionText
  Invoke-Expression $EnableFunctionText

  Assert-True (Test-IsBuiltInAdministratorSid 'S-1-5-21-111-222-333-500') 'RID-500 SID was not identified'
  Assert-True (-not (Test-IsBuiltInAdministratorSid 'S-1-5-21-111-222-333-5000')) 'non-RID-500 SID was misidentified'
  Assert-True (-not (Test-IsBuiltInAdministratorSid '')) 'empty SID was misidentified'

  Reset-MockUac 0 0
  Assert-True ((Get-UacEnableLuaValue) -eq 0) 'EnableLUA=0 was not detected'
  Assert-True ((Get-UacFilterAdministratorTokenValue) -eq 0) 'FilterAdministratorToken=0 was not detected'
  $script:MockUacReadFailureName = 'EnableLUA'
  Assert-True ($null -eq (Get-UacEnableLuaValue)) 'unreadable EnableLUA was guessed instead of returning unknown'
  $script:MockUacReadFailureName = 'FilterAdministratorToken'
  Assert-True ($null -eq (Get-UacFilterAdministratorTokenValue)) 'unreadable FilterAdministratorToken was guessed instead of returning unknown'

  # 普通管理员只写 EnableLUA=1，并复读确认；FilterAdministratorToken 必须保持不变。
  Reset-MockUac 0 0
  Enable-UacForNextRestart
  Assert-True ($script:MockUacWrites.Count -eq 1) 'ordinary administrator recovery wrote more than EnableLUA'
  Assert-True (($script:MockUacReads -join ',') -eq 'EnableLUA') 'ordinary administrator recovery read back values other than EnableLUA'
  $ordinaryWrite = $script:MockUacWrites[0]
  Assert-True ($ordinaryWrite.LiteralPath -eq 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System') 'ordinary UAC writer targeted the wrong registry path'
  Assert-True ($ordinaryWrite.Name -eq 'EnableLUA' -and $ordinaryWrite.Value -eq 1) 'ordinary UAC writer did not write only EnableLUA=1'
  Assert-True ($ordinaryWrite.PropertyType -eq 'DWord' -and $ordinaryWrite.Force) 'ordinary UAC writer did not persist a forced DWORD'
  Assert-True ($script:MockUacValues.FilterAdministratorToken -eq 0) 'ordinary administrator recovery changed FilterAdministratorToken'

  # RID-500 账户还必须开启并复验内置 Administrator 的管理员审批模式。
  Reset-MockUac 0 0
  Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode
  Assert-True ($script:MockUacWrites.Count -eq 2) 'RID-500 recovery did not perform exactly two writes'
  Assert-True ((@($script:MockUacWrites | ForEach-Object Name) -join ',') -eq 'FilterAdministratorToken,EnableLUA') 'RID-500 recovery did not write approval mode before enabling UAC'
  Assert-True (($script:MockUacReads -join ',') -eq 'FilterAdministratorToken,EnableLUA') 'RID-500 recovery did not immediately read back each policy in safe order'
  Assert-True (@($script:MockUacWrites | Where-Object { $_.Value -ne 1 -or $_.PropertyType -ne 'DWord' -or -not $_.Force }).Count -eq 0) 'RID-500 recovery did not write both policies as forced DWORD 1'

  # 写入报错和写后读回未生效都必须失败，由启动守卫统一退出。
  Reset-MockUac 0 0
  $script:MockUacWriteFailureName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart } 'ordinary EnableLUA write failure was ignored'
  Reset-MockUac 0 0
  $script:MockUacHoldWriteName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart } 'ordinary EnableLUA readback failure was ignored'
  Reset-MockUac 0 0
  $script:MockUacWriteFailureName = 'FilterAdministratorToken'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 FilterAdministratorToken write failure was ignored'
  Assert-True (($script:MockUacWrites.Count -eq 1) -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 approval-mode write failure still enabled UAC'
  Reset-MockUac 0 0
  $script:MockUacHoldWriteName = 'FilterAdministratorToken'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 FilterAdministratorToken readback failure was ignored'
  Assert-True (($script:MockUacWrites.Count -eq 1) -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 approval-mode readback failure still enabled UAC'
  Reset-MockUac 0 0
  $script:MockUacWriteFailureName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 EnableLUA write failure was ignored after approval-mode success'
  Assert-True ($script:MockUacValues.FilterAdministratorToken -eq 1 -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 EnableLUA write failure corrupted the safe partial state'
  Reset-MockUac 0 0
  $script:MockUacHoldWriteName = 'EnableLUA'
  Assert-Throws { Enable-UacForNextRestart -EnableBuiltInAdministratorApprovalMode } 'RID-500 EnableLUA readback failure was ignored after approval-mode success'
  Assert-True ($script:MockUacValues.FilterAdministratorToken -eq 1 -and $script:MockUacValues.EnableLUA -eq 0) 'RID-500 EnableLUA readback failure corrupted the safe partial state'

  Remove-Variable MockUacValues,MockUacReadFailureName,MockUacWriteFailureName,MockUacHoldWriteName,MockUacWrites,MockUacReads -Scope Script -ErrorAction SilentlyContinue
} $getUacFunctionText $getFilterFunctionText $sidFunctionText $enableUacFunctionText

$localNoBackupFunctionText = $localNoBackupFunction.Extent.Text
& {
  param([string]$FunctionText)

  function Get-MockHealthyCheck { [pscustomobject]@{ Ok = $true; Text = 'healthy' } }
  function Get-MockAttentionCheck { [pscustomobject]@{ Ok = $false; Text = 'attention' } }
  function Invoke-EngineHostUserAction([string]$Action) {
    if ($Action -ne 'ClearShaderCache') { throw "unexpected broker action: $Action" }
    '{"Cleared":["mock cache cleared"],"Failed":[]}'
  }

  Invoke-Expression $FunctionText
  $items = @(
    [pscustomobject]@{ Id = 'check-ok'; Name = 'check ok'; Kind = 'check'; Check = 'Get-MockHealthyCheck' }
    [pscustomobject]@{ Id = 'check-attention'; Name = 'check attention'; Kind = 'check'; Check = 'Get-MockAttentionCheck' }
    [pscustomobject]@{ Id = 'cache'; Name = 'cache'; Kind = 'cache'; Check = $null }
  )
  $results = @(Invoke-LocalNoBackupItems $items)
  Assert-True ($results.Count -eq 3) 'local no-backup runner did not return every result under Windows PowerShell 5.1'
  Assert-True (($results.Id -join ',') -eq 'check-ok,check-attention,cache') 'local no-backup results changed order or identity'
  Assert-True ($results[0].Ok -and -not $results[0].Attention) 'healthy local check result was misclassified'
  Assert-True (-not $results[1].Ok -and $results[1].Attention) 'attention local check result was misclassified'
  Assert-True ($results[2].Ok -and -not $results[2].Skipped) 'local cache result was misclassified'

  $noItems = @()
  Assert-True (@(Invoke-LocalNoBackupItems $noItems).Count -eq 0) 'empty local no-backup batch did not return an empty result set'
} $localNoBackupFunctionText

$validatedCandidateFunctionText = $validatedCandidateFunction.Extent.Text
& {
  param([string]$FunctionText)

  $previousTargetExe = $script:TargetExe
  try {
    $script:TargetExe = 'C:\Games\DeltaForceClient-Win64-Shipping.exe'
    function Get-TuningCandidate([string]$GroupId) {
      [pscustomobject]@{
        GroupId = $GroupId; Source = 'rules'; RiskLevel = 'low'; RequiresReboot = $false
        ItemIds = @('candidate-a', 'candidate-b')
      }
    }
    function Get-OptItems([string]$GamePath) {
      @(
        [pscustomobject]@{ Id = 'candidate-a'; Tier = 'safe'; Reboot = $false; Kind = 'multi'
          RequiresGame = $false; Ops = @([pscustomobject]@{ Kind = 'reg' }) }
        [pscustomobject]@{ Id = 'candidate-b'; Tier = 'safe'; Reboot = $false; Kind = 'multi'
          RequiresGame = $false; Ops = @([pscustomobject]@{ Kind = 'kvstr' }) }
      )
    }
    function Test-AllowedGameExecutable([string]$GamePath) { $true }

    Invoke-Expression $FunctionText
    $runtime = Get-ValidatedTuningCandidateRuntime 'G1'
    Assert-True (@($runtime.Items).Count -eq 2) 'validated tuning candidate lost Generic.List items under Windows PowerShell 5.1'
    Assert-True (($runtime.Items.Id -join ',') -eq 'candidate-a,candidate-b') 'validated tuning candidate changed item order or identity'
  } finally {
    $script:TargetExe = $previousTargetExe
  }
} $validatedCandidateFunctionText

Write-Host 'PASS: GUI UAC recovery and WinPS5.1 Generic.List result paths are regression covered'
