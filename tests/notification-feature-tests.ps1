#requires -Version 5.1
param()

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$guiPath=Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'
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
  'function ConvertTo-NotificationTextSegments','function New-NotificationBodyTextBlock',
  'Windows.Documents.Hyperlink','Add_RequestNavigate','Start-Process -FilePath $target.AbsoluteUri',
  'Write-DfbTelemetryConfigAtomic $script:NotificationStatePath $state',
  '$ui.NoticeBtn.Add_Click','Start-NotificationCheck -ShowHistory'
)){Assert-True $gui.Contains($needle) "software notification integration is missing: $needle"}
Assert-True $gui.Contains('x:Name="NoticeBadge" Visibility="Collapsed" Background="{DynamicResource Green}"') `
  'unread notification badge is not green'
Assert-True ($gui.Contains('[PowerShell]::Create()') -and $gui.Contains('Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 8')) `
  'notification polling is not performed asynchronously with a bounded timeout'
Assert-True ($gui.Contains("if (`$level -notin 'info','important','warning')") -and
  $gui.Contains('$title.Length -gt 80') -and $gui.Contains('$content.Length -gt 10000')) `
  'software does not validate the notification response before rendering it'
$historyFunction=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Show-NotificationHistory'},$true)|Select-Object -First 1)
Assert-True ($historyFunction.Count -eq 1) 'notification history dialog function was not found'
$historyXaml=[regex]::Match($historyFunction[0].Extent.Text,"(?s)\$nxaml = @'\r?\n(.*?)\r?\n'@")
Assert-True $historyXaml.Success 'notification history dialog XAML was not found'
[void][Windows.Markup.XamlReader]::Parse($historyXaml.Groups[1].Value)

$segmentFunction=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-NotificationTextSegments'},$true)|Select-Object -First 1)
Assert-True ($segmentFunction.Count -eq 1) 'notification link tokenizer function was not found'
. ([ScriptBlock]::Create($segmentFunction[0].Extent.Text))
$segments=@(ConvertTo-NotificationTextSegments 'Docs: https://docs.qq.com/doc/ABC?x=1. More http://example.com/help, done')
$links=@($segments|Where-Object Url)
Assert-True ($links.Count -eq 2) 'notification link tokenizer did not find both web links'
Assert-True ($links[0].Url -eq 'https://docs.qq.com/doc/ABC?x=1') 'notification link tokenizer included Chinese punctuation in the URL'
$reconstructed=($segments|ForEach-Object Text)-join ''
Assert-True ($reconstructed -eq 'Docs: https://docs.qq.com/doc/ABC?x=1. More http://example.com/help, done') 'notification link tokenizer did not preserve the original notification text'
$bodyFunction=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'New-NotificationBodyTextBlock'},$true)|Select-Object -First 1)
Assert-True ($bodyFunction.Count -eq 1) 'notification hyperlink text block function was not found'
. ([ScriptBlock]::Create($bodyFunction[0].Extent.Text))
function New-Brush([string]$Color){$converter=New-Object Windows.Media.BrushConverter;$converter.ConvertFromString($Color)}
$script:C=[pscustomobject]@{TextSec='#91A49B';Green='#00E884'}
$body=New-NotificationBodyTextBlock 'Read https://example.com/help now.'
$bodyLinks=@($body.Inlines|Where-Object{$_ -is [Windows.Documents.Hyperlink]})
Assert-True ($bodyLinks.Count -eq 1) 'notification body did not create one WPF hyperlink'
Assert-True ($bodyLinks[0].NavigateUri.AbsoluteUri -eq 'https://example.com/help') 'notification WPF hyperlink points to the wrong URL'

$server=Get-Content -LiteralPath (Join-Path $root 'server\report_server.py') -Raw -Encoding UTF8
$admin=Get-Content -LiteralPath (Join-Path $root 'website\admin\index.html') -Raw -Encoding UTF8
Assert-True $server.Contains('NOTIFICATION_CONTENT_LIMIT = 10000') 'server notification content limit is not 10000'
Assert-True $server.Contains('MAX_NOTIFICATION_BODY = 64 * 1024') 'server request body limit cannot carry a 10000-character notification'
Assert-True ($admin.Contains('maxlength="10000"') -and $admin.Contains('content.length>10000')) `
  'admin notification composer limit is not 10000'
Assert-True ($admin.Contains('function linkifyNoticeContent') -and $admin.Contains('target="_blank" rel="noopener noreferrer"')) `
  'admin notification history does not render safe clickable web links'

Write-Host "notification client tests passed: $script:Assertions assertions"
