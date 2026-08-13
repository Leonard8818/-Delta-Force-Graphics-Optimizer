#requires -Version 5.1
param()

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$guiPath=Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'
$serverPath=Join-Path $root 'server\report_server.py'
$adminPath=Join-Path $root 'website\admin\index.html'
$script:Assertions=0
function Assert-True([bool]$Condition,[string]$Message){$script:Assertions++;if(-not $Condition){throw "ASSERT: $Message"}}

$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($guiPath,[ref]$tokens,[ref]$errors)
Assert-True ($errors.Count -eq 0) ('GUI PowerShell parse failed: '+(($errors|ForEach-Object Message)-join '; '))
$gui=Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
$xaml=[regex]::Match($gui,"(?s)\$xaml = @'\r?\n(.*?)\r?\n'@")
Assert-True $xaml.Success 'main GUI XAML was not found'
Add-Type -AssemblyName PresentationFramework
[void][Windows.Markup.XamlReader]::Parse($xaml.Groups[1].Value)

foreach($needle in @(
  'x:Name="NoticeBtn"','x:Name="NoticeBadge"','x:Name="NoticeBadgeTxt"','x:Name="NoticeText"',
  "`$script:NotificationUrl = 'https://df.ltz88.cn/report/notifications'",
  '$script:NotificationCheckIntervalSeconds = 60','notifications.json',
  'function Start-NotificationCheck','function Show-NotificationHistory','function ConvertTo-NotificationList',
  'Write-DfbTelemetryConfigAtomic $script:NotificationStatePath $state',
  '$ui.NoticeBtn.Add_Click','Start-NotificationCheck -ShowHistory'
)){Assert-True $gui.Contains($needle) "software notification integration is missing: $needle"}
Assert-True ($gui.Contains('[PowerShell]::Create()') -and $gui.Contains('Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 8')) `
  'notification polling is not performed asynchronously with a bounded timeout'
Assert-True ($gui.Contains("if (`$level -notin 'info','important','warning')") -and
  $gui.Contains('$title.Length -gt 80') -and $gui.Contains('$content.Length -gt 2000')) `
  'software does not validate the notification response before rendering it'
$historyFunction=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Show-NotificationHistory'},$true)|Select-Object -First 1)
Assert-True ($historyFunction.Count -eq 1) 'notification history dialog function was not found'
$historyXaml=[regex]::Match($historyFunction[0].Extent.Text,"(?s)\$nxaml = @'\r?\n(.*?)\r?\n'@")
Assert-True $historyXaml.Success 'notification history dialog XAML was not found'
[void][Windows.Markup.XamlReader]::Parse($historyXaml.Groups[1].Value)

$server=Get-Content -LiteralPath $serverPath -Raw -Encoding UTF8
foreach($needle in @(
  'CREATE TABLE IF NOT EXISTS notifications','def _create_notification','def _withdraw_notification',
  'path == "/report/notifications"','path == "/api/notifications"',
  'r"/api/notifications/(\d+)/withdraw"','"public, max-age=15"'
)){Assert-True $server.Contains($needle) "server notification contract is missing: $needle"}

if(Test-Path -LiteralPath $adminPath -PathType Leaf){
  $admin=Get-Content -LiteralPath $adminPath -Raw -Encoding UTF8
  foreach($needle in @(
    'id="notificationManager"','id="noticeForm"','id="noticeList"','id="noticePublish"',
    "fetch('api/notifications'",'fetch(`api/notifications/${id}/withdraw`',
    'function loadNotifications','function publishNotification','function withdrawNotification',
    'notice-admin-grid','notice-card.withdrawn'
  )){Assert-True $admin.Contains($needle) "admin notification UI is missing: $needle"}
  $ids=@([regex]::Matches($admin,'\bid="([A-Za-z][A-Za-z0-9_-]*)"')|ForEach-Object{$_.Groups[1].Value})
  $duplicates=@($ids|Group-Object|Where-Object Count -gt 1)
  Assert-True ($duplicates.Count -eq 0) ('duplicate admin HTML ids: '+(($duplicates|ForEach-Object Name)-join ', '))
}else{Write-Host 'SKIP: private admin notification UI is not present in this checkout'}

Write-Host "notification feature tests passed: $script:Assertions assertions"
