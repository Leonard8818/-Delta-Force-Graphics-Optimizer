<#
  DeltaForceBooster 更新检查模块 — v0.1
  独立于优化引擎：只负责「取清单 → 比版本 → 报告结果」。
  清单是一个 JSON 文件：{ "version": "0.7.0", "notes": "更新说明", "url": "https://下载页" }

  安全约定（红线）：
    - 本模块绝不下载、绝不执行任何文件；url 只交给界面层用浏览器打开（且界面层只放行 http/https）。
      自动下载并运行更新包等于给供应链攻击开门，永远不做。
    - 网络不可达、超时、JSON 坏掉一律静默返回 $null——检查更新不许影响主程序启动。
#>
#requires -Version 5.1

# 清单地址：**发版前必须填成真实地址**。留空时更新检查直接跳过（静默、不报错、不影响启动），
# 所以填错或忘填不会有任何提示，只是永远检查不到新版本。
#
# 仓库 github.com/Leonard8818/delta-force-display-utilizer 当前是私有的，
# 私有仓库的 Release 附件外部无法匿名下载，因此清单只能挂自有服务器，例如：
#   $script:BoosterManifestUrl = 'https://df.ltz88.cn/update-manifest.json'
# 将来若把仓库转为公开，才可改用 GitHub Releases 的固定资产链接（永远指向最新版）：
#   'https://github.com/Leonard8818/delta-force-display-utilizer/releases/latest/download/update-manifest.json'
#
# 清单格式：{ "version": "0.7.0", "notes": "更新说明", "url": "下载页地址" }
# 本地测试用 Test-BoosterUpdate -ManifestUrl 'file:///C:/.../manifest.json' 临时覆盖。
$script:BoosterManifestUrl = ''

# 本模块位于 scripts\，工具根目录是它的上一级；「不再提醒」状态落在根目录 config\ 下，
# 不放 profiles\（那里每个 *.json 都会被引擎当成用户预设方案扫出来）
$script:BoosterUpdaterRoot = Split-Path -Parent $PSScriptRoot

function Get-BoosterUpdateConfigPath {
  $d = Join-Path $script:BoosterUpdaterRoot 'config'
  if (-not (Test-Path -LiteralPath $d)) {
    try { New-Item -ItemType Directory -Path $d -Force | Out-Null } catch {}
  }
  Join-Path $d 'updater.json'
}

function Get-BoosterUpdateConfig {
  try {
    $f = Get-BoosterUpdateConfigPath
    if (Test-Path -LiteralPath $f) {
      $j = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($j) { return $j }
    }
  } catch {}
  [pscustomobject]@{ SkippedVersion = '' }
}

function Set-BoosterSkipVersion([string]$SkipVersion) {
  try {
    $cfg = Get-BoosterUpdateConfig
    if ($cfg.PSObject.Properties['SkippedVersion']) { $cfg.SkippedVersion = "$SkipVersion" }
    else { $cfg | Add-Member -NotePropertyName SkippedVersion -NotePropertyValue "$SkipVersion" }
    $enc = New-Object Text.UTF8Encoding($true)
    [IO.File]::WriteAllText((Get-BoosterUpdateConfigPath), ($cfg | ConvertTo-Json), $enc)
    $true
  } catch { $false }
}

function Compare-BoosterVersion([string]$Left, [string]$Right) {
  # 语义化逐段数字比较：字符串比大小会把 "0.10.0" 排在 "0.9.0" 前面，必须按段转数字。
  # 段里混了非数字（如 "1.2-beta"）时取前导数字，取不到按 0；两边段数不齐短的补 0。
  $pl = @(("$Left".Trim() -replace '^[vV]', '') -split '\.')
  $pr = @(("$Right".Trim() -replace '^[vV]', '') -split '\.')
  $n = [Math]::Max($pl.Count, $pr.Count)
  for ($i = 0; $i -lt $n; $i++) {
    $a = 0; $b = 0
    if ($i -lt $pl.Count -and "$($pl[$i])" -match '^(\d+)') { $a = [int]$Matches[1] }
    if ($i -lt $pr.Count -and "$($pr[$i])" -match '^(\d+)') { $b = [int]$Matches[1] }
    if ($a -ne $b) { return [Math]::Sign($a - $b) }
  }
  0
}

function Get-BoosterManifest([string]$Url = $script:BoosterManifestUrl, [int]$TimeoutMs = 5000) {
  try {
    # 用 WebRequest 而不是 Invoke-WebRequest：同时支持 http(s) 与 file://（本地测试），
    # 且 Timeout 可控，不会让启动流程吊死在慢网络上
    $req = [Net.WebRequest]::Create($Url)
    $req.Timeout = $TimeoutMs
    if ($req -is [Net.HttpWebRequest]) {
      $req.ReadWriteTimeout = $TimeoutMs
      $req.UserAgent = 'DeltaForceBooster-Updater'
      $req.AllowAutoRedirect = $true
      # GitHub 强制 TLS 1.2+，Win PowerShell 5.1 默认协议集可能不含它
      [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    $resp = $req.GetResponse()
    try {
      $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
      $raw = $sr.ReadToEnd()
      $sr.Close()
    } finally { $resp.Close() }
    $m = $raw | ConvertFrom-Json
    if (-not $m -or -not $m.version) { return $null }
    $m
  } catch { $null }
}

function Test-BoosterUpdate {
  param(
    [Parameter(Mandatory)][string]$CurrentVersion,
    [string]$ManifestUrl = $script:BoosterManifestUrl,
    [int]$TimeoutMs = 5000
  )
  try {
    $m = Get-BoosterManifest $ManifestUrl $TimeoutMs
    if (-not $m) { return $null }
    if ((Compare-BoosterVersion "$($m.version)" $CurrentVersion) -le 0) { return $null }
    # 用户点过「不再提醒此版本」的就不再弹；出了更新的版本会重新提醒
    $cfg = Get-BoosterUpdateConfig
    if ("$($cfg.SkippedVersion)" -eq "$($m.version)") { return $null }
    [pscustomobject]@{
      Version = "$($m.version)"
      Notes   = "$($m.notes)"
      Url     = "$($m.url)"
      Current = "$CurrentVersion"
    }
  } catch { $null }
}
