<#
  DeltaForceBooster 原交互用户 worker。
  只由 UAC 前长期存活的 asInvoker 启动器以原用户令牌启动，且只提供固定低权限动作：
    - 读取旧版白名单 JSON 并通过认证管道返回（不写 ProgramData）；
    - 清理该用户自己的着色器缓存。
  结果通过随机命名管道回传，不让提权 GUI 依赖用户可写结果文件。
#>
#requires -Version 5.1
param(
  [Parameter(Mandatory)][ValidateSet('MigrateLegacyData','ClearShaderCache','GetGpuPanelApps','GetNvAutoOptStatus')][string]$Action,
  [string]$Payload = '',
  [Parameter(Mandatory)][string]$ReplyPipe,
  [Parameter(Mandatory)][string]$Session
)

$ErrorActionPreference = 'Stop'
$trustedRoots = @(
  (Join-Path $PSHOME 'Modules'),
  (Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'WindowsPowerShell\Modules')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
$env:PSModulePath = ($trustedRoots -join [IO.Path]::PathSeparator)

function Test-WorkerAdmin {
  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WorkerReparsePath([string]$Path) {
  try {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [IO.Path]::GetPathRoot($full); $current = $root
    foreach ($part in @($full.Substring($root.Length) -split '\\' | Where-Object { $_ })) {
      $current = Join-Path $current $part
      if (-not (Test-Path -LiteralPath $current)) { break }
      if (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $true }
    }
    $false
  } catch { $true }
}

function Get-WorkerLocalAppData {
  $path = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
  if (-not $path) { throw '原用户 LocalAppData 不可用' }
  $full = [IO.Path]::GetFullPath($path).TrimEnd('\')
  if (-not (Test-Path -LiteralPath $full -PathType Container) -or (Test-WorkerReparsePath $full) -or
      (New-Object IO.DriveInfo([IO.Path]::GetPathRoot($full))).DriveType -ne [IO.DriveType]::Fixed) {
    throw '原用户 LocalAppData 不在可验证的本地固定磁盘路径'
  }
  $full
}

function Invoke-WorkerLegacyMigration {
  $root = Split-Path -Parent $PSScriptRoot
  $local = Get-WorkerLocalAppData
  $sources = @((Join-Path $local 'DeltaForceBooster'), $root)
  $files = New-Object System.Collections.Generic.List[object]
  $skipped = New-Object System.Collections.Generic.List[string]
  $seen = @{}
  $migrationState = @{ TotalBytes = 0L }

  function Add-LegacyJson([string]$Source, [string]$RelativePath, [int]$MaxBytes) {
    if ($seen.ContainsKey($RelativePath) -or -not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    try {
      if (Test-WorkerReparsePath $Source) { throw '路径包含重解析点' }
      $info = Get-Item -LiteralPath $Source -Force -ErrorAction Stop
      if ($info.Length -lt 2 -or $info.Length -gt $MaxBytes) { throw '文件大小超限' }
      $bytes = [IO.File]::ReadAllBytes($Source)
      if ($bytes.Length -lt 2 -or $bytes.Length -gt $MaxBytes) { throw '读取后文件大小超限' }
      $offset = $(if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 3 } else { 0 })
      $strictUtf8 = New-Object Text.UTF8Encoding($false, $true)
      $text = $strictUtf8.GetString($bytes, $offset, $bytes.Length - $offset)
      $null = $text | ConvertFrom-Json -ErrorAction Stop
      if (($migrationState.TotalBytes + $bytes.Length) -gt 12MB) { throw '迁移包总大小超过上限' }
      $sha = [Security.Cryptography.SHA256]::Create()
      try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') }
      finally { $sha.Dispose() }
      [void]$files.Add([pscustomobject][ordered]@{
        RelativePath = $RelativePath; Length = [long]$bytes.Length; Sha256 = $hash
        ContentBase64 = [Convert]::ToBase64String($bytes)
      })
      $migrationState.TotalBytes += $bytes.Length
      $seen[$RelativePath] = $true
    } catch { [void]$skipped.Add("$RelativePath：$($_.Exception.Message)") }
  }

  # LocalAppData 是 v0.19.4-v0.20.4 的最新来源；程序目录仅用于更早版本兜底。
  foreach ($sourceRoot in $sources) {
    $configRoot = Join-Path $sourceRoot 'config'
    foreach ($entry in @(
      [pscustomobject]@{ Name='telemetry.json'; Max=1MB },
      [pscustomobject]@{ Name='disclaimer.json'; Max=64KB },
      [pscustomobject]@{ Name='updater.json'; Max=64KB },
      [pscustomobject]@{ Name='performance-sessions.json'; Max=2MB },
      [pscustomobject]@{ Name='power-scheme.json'; Max=1MB },
      [pscustomobject]@{ Name='tuning-telemetry-outbox.json'; Max=4MB }
    )) {
      Add-LegacyJson (Join-Path $configRoot $entry.Name) ("config\" + $entry.Name) ([int]$entry.Max)
    }
    $experiments = Join-Path $configRoot 'experiments'
    if ((Test-Path -LiteralPath $experiments -PathType Container) -and -not (Test-WorkerReparsePath $experiments)) {
      foreach ($file in @(Get-ChildItem -LiteralPath $experiments -File -Filter '*.json' -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -match '^(?:active-experiment|exp_[0-9a-f]{32})\.json$' } | Select-Object -First 32)) {
        Add-LegacyJson $file.FullName ("config\experiments\" + $file.Name) 1MB
      }
    }
    $profiles = Join-Path $sourceRoot 'profiles'
    if ((Test-Path -LiteralPath $profiles -PathType Container) -and -not (Test-WorkerReparsePath $profiles)) {
      foreach ($file in @(Get-ChildItem -LiteralPath $profiles -File -Filter '*.json' -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -match '^[^\\/:*?"<>|]{1,80}\.json$' } | Select-Object -First 100)) {
        Add-LegacyJson $file.FullName ("profiles\" + $file.Name) 256KB
      }
    }
  }
  [pscustomobject][ordered]@{ SchemaVersion = 1; Files = @($files.ToArray()); Skipped = @($skipped.ToArray()) }
}

function Invoke-WorkerShaderCache {
  $root = Split-Path -Parent $PSScriptRoot
  . (Join-Path $root 'scripts\delta-booster.ps1')
  $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $local = Get-WorkerLocalAppData
  Set-TargetUserContext $sid $local
  Clear-ShaderCache
}

function Get-WorkerGpuPanelApps([string]$Vendor) {
  if ($Vendor -notin 'NVIDIA','AMD','Intel') { throw '显卡厂商不在白名单' }
  $programFiles = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
  $system = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
  $apps = @()
  if ($Vendor -eq 'NVIDIA') {
    $pkg = try { @(Get-AppxPackage -Name 'NVIDIACorp.NVIDIAControlPanel' -ErrorAction SilentlyContinue)[0] } catch { $null }
    $legacy = Join-Path $programFiles 'NVIDIA Corporation\Control Panel Client\nvcplui.exe'
    $apps += [pscustomobject]@{ Key='nv-cpl'; Name='NVIDIA 控制面板'; Installed=[bool]($pkg -or (Test-Path -LiteralPath $legacy));
      Kind=$(if($pkg){'appx'}else{'exe'}); Target=''; Download='https://www.nvidia.cn/geforce/drivers/';
      Missing='随显卡驱动一起安装，没有说明驱动装得不完整，重装驱动即可' }
    $nvApp = @((Join-Path $programFiles 'NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe'),
      (Join-Path $programFiles 'NVIDIA Corporation\NVIDIA App\CEF\NVIDIA app.exe')) |
      Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    $apps += [pscustomobject]@{ Key='nv-app'; Name='NVIDIA App'; Installed=[bool]$nvApp; Kind='exe'; Target='';
      Download='https://www.nvidia.cn/software/nvidia-app/'; Missing='DLSS 预设、驱动更新等新功能在这里，建议装' }
  } elseif ($Vendor -eq 'AMD') {
    $rs = @((Join-Path $programFiles 'AMD\CNext\CNext\RadeonSoftware.exe'), (Join-Path $system 'amdow.exe')) |
      Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    $apps += [pscustomobject]@{ Key='amd-sw'; Name='AMD Software (Adrenalin)'; Installed=[bool]$rs; Kind='exe'; Target='';
      Download='https://www.amd.com/zh-cn/support/download/drivers.html'; Missing='随 Adrenalin 驱动一起安装，没有就去官网装完整版驱动' }
  } else {
    $pkg = try { @(Get-AppxPackage -Name 'AppUp.IntelGraphicsExperience' -ErrorAction SilentlyContinue)[0] } catch { $null }
    $apps += [pscustomobject]@{ Key='intel-gcc'; Name='Intel 显卡控制中心'; Installed=[bool]$pkg; Kind='appx'; Target='';
      Download='https://www.intel.cn/content/www/cn/zh/download-center/home.html'; Missing='随 Intel 显卡驱动一起安装，也可在微软商店搜索安装' }
  }
  @($apps)
}

function Get-WorkerNvAutoOptStatus {
  $root = Split-Path -Parent $PSScriptRoot
  . (Join-Path $root 'scripts\delta-booster.ps1')
  $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $local = Get-WorkerLocalAppData
  Set-TargetUserContext $sid $local
  Get-NvAutoOptStatus
}

function Send-WorkerReply([bool]$Ok, [string]$Payload) {
  if ($ReplyPipe -notmatch '^DeltaForceBooster\.UserWorker\.[0-9a-fA-F]{32}$' -or
      $Session -notmatch '^[0-9a-fA-F]{32}$') { throw '用户 worker 回复会话参数无效' }
  $pipe = New-Object IO.Pipes.NamedPipeClientStream('.', $ReplyPipe,
    [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::None)
  try {
    $pipe.Connect(30000)
    $writer = New-Object IO.BinaryWriter($pipe, (New-Object Text.UTF8Encoding($false)), $true)
    $writer.Write('DFB_USER_WORKER/1'); $writer.Write([int]$PID); $writer.Write($Session)
    $writer.Write($Ok)
    $payloadBytes = [Text.Encoding]::UTF8.GetBytes($(if ($Payload) { $Payload } else { '' }))
    if ($payloadBytes.Length -gt 24MB) { throw '用户 worker 回复超过 24MB 上限' }
    $writer.Write([int]$payloadBytes.Length); $writer.Write($payloadBytes); $writer.Flush()
  } finally { $pipe.Dispose() }
}

$ok = $false; $payload = ''
try {
  if (Test-WorkerAdmin) { throw '原用户 worker 意外获得了管理员令牌，已拒绝执行' }
  $result = $(switch ($Action) {
    'MigrateLegacyData' { Invoke-WorkerLegacyMigration }
    'ClearShaderCache' { Invoke-WorkerShaderCache }
    'GetGpuPanelApps' { Get-WorkerGpuPanelApps $Payload }
    'GetNvAutoOptStatus' { Get-WorkerNvAutoOptStatus }
  })
  $payload = $result | ConvertTo-Json -Depth 6 -Compress
  $ok = $true
} catch { $payload = $_.Exception.Message }

try { Send-WorkerReply $ok $payload } catch { exit 2 }
exit $(if ($ok) { 0 } else { 1 })
