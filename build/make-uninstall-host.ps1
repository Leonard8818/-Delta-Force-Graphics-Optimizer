#requires -Version 5.1
param(
  [Parameter(Mandatory)][string]$StageDirectory,
  [Parameter(Mandatory)][string]$Version,
  [switch]$TestBuild
)
$ErrorActionPreference = 'Stop'
$build = $PSScriptRoot
$root = Split-Path -Parent $build
$stage = [IO.Path]::GetFullPath($StageDirectory)
$scriptPath = Join-Path $stage 'uninstall.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw 'uninstall.ps1 尚未写入 stage' }
$parts = @($Version -split '\.') + @('0','0','0','0')
$ver4 = ($parts[0..3] -join '.')
$work = Join-Path $env:TEMP ('dfb-uninstall-build-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
try {
  $windows = Split-Path -Parent ([Environment]::SystemDirectory)
  $csc = Join-Path $windows 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
  if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $windows 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
  if (-not (Test-Path -LiteralPath $csc)) { throw '本机没有受信 .NET Framework csc.exe' }
  $icon = Join-Path $stage 'gui\app.ico'
  $runtime = Join-Path $build 'runtime-root-validation.cs'
  $token = Join-Path $build 'token-validation.cs'
  $scriptSha = (Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToUpperInvariant()
  $enc = New-Object Text.UTF8Encoding($true)

  $highManifest = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><trustInfo xmlns="urn:schemas-microsoft-com:asm.v2"><security><requestedPrivileges><requestedExecutionLevel level="requireAdministrator" uiAccess="false"/></requestedPrivileges></security></trustInfo></assembly>
'@
  $lowManifest = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><trustInfo xmlns="urn:schemas-microsoft-com:asm.v2"><security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false"/></requestedPrivileges></security></trustInfo></assembly>
'@
  $highManifestPath = Join-Path $work 'UninstallHost.manifest'
  $lowManifestPath = Join-Path $work 'UninstallLauncher.manifest'
  [IO.File]::WriteAllText($highManifestPath, $highManifest, (New-Object Text.UTF8Encoding($false)))
  [IO.File]::WriteAllText($lowManifestPath, $lowManifest, (New-Object Text.UTF8Encoding($false)))

  $commonAssembly = @"
using System.Reflection;
[assembly: AssemblyProduct("DeltaForceBooster")]
[assembly: AssemblyCompany("DeltaForceBooster 开源项目")]
[assembly: AssemblyVersion("$ver4")]
[assembly: AssemblyFileVersion("$ver4")]
"@
  $hostAttributes = @'
[assembly: AssemblyTitle("三角洲行动优化助手 卸载助手")]
[assembly: AssemblyDescription("三角洲行动优化助手 卸载助手")]
'@
  $hostRaw = ([IO.File]::ReadAllText((Join-Path $build 'uninstall-host.cs'), [Text.Encoding]::UTF8)).Replace('__SCRIPT_SHA256__', $scriptSha)
  $hostSource = $hostRaw.Replace('using Microsoft.Win32;',
    'using Microsoft.Win32;' + "`r`n" + $commonAssembly + "`r`n" + $hostAttributes)
  $hostCs = Join-Path $work 'UninstallHost.cs'
  [IO.File]::WriteAllText($hostCs, $hostSource, $enc)
  $hostOut = Join-Path $stage 'UninstallHost.exe'
  $defines = @($(if ($TestBuild) { '/define:DFB_TESTING' }))
  & $csc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /out:"$hostOut" `
    /win32icon:"$icon" /win32manifest:"$highManifestPath" /r:System.Windows.Forms.dll /r:System.Core.dll `
    @defines "$runtime" "$token" "$hostCs"
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $hostOut)) { throw "UninstallHost 编译失败（$LASTEXITCODE）" }

  $hostSha = (Get-FileHash -LiteralPath $hostOut -Algorithm SHA256).Hash.ToUpperInvariant()
  $launcherAttributes = @'
[assembly: AssemblyTitle("三角洲行动优化助手 卸载")]
[assembly: AssemblyDescription("三角洲行动优化助手 卸载入口")]
'@
  $launcherRaw = ([IO.File]::ReadAllText((Join-Path $build 'uninstall-launcher.cs'), [Text.Encoding]::UTF8)).Replace('__SCRIPT_SHA256__', $scriptSha).Replace('__HOST_SHA256__', $hostSha)
  $launcherSource = $launcherRaw.Replace('using Microsoft.Win32;',
    'using Microsoft.Win32;' + "`r`n" + $commonAssembly + "`r`n" + $launcherAttributes)
  $launcherCs = Join-Path $work 'UninstallLauncher.cs'
  [IO.File]::WriteAllText($launcherCs, $launcherSource, $enc)
  $launcherOut = Join-Path $stage '卸载.exe'
  & $csc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /out:"$launcherOut" `
    /win32icon:"$icon" /win32manifest:"$lowManifestPath" /r:System.Windows.Forms.dll /r:System.Core.dll `
    @defines "$runtime" "$token" "$launcherCs"
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $launcherOut)) { throw "卸载入口编译失败（$LASTEXITCODE）" }
  "卸载组件构建完成：$launcherOut / $hostOut"
} finally {
  if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
