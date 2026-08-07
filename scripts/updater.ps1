<#
  DeltaForceBooster 更新检查模块 — v0.4
  独立于优化引擎：负责「取清单 → 比版本 → 报告结果」+「带校验的内置下载」。
  v0.4：更新改为一键完成——校验通过后直接静默安装并自启新版，用户不必再走安装向导。
  清单格式：{ "version", "notes", "url"(下载页), "setupUrl"(安装包), "sha256", "size" }

  安全约定（每条都是硬红线）：
    - 下载源域名白名单硬编码在本文件（$script:BoosterDownloadHosts）：setupUrl 必须是
      https 且主机在白名单内，否则拒绝下载——清单本身可能被篡改，绝不信任清单里的任意 URL。
    - 清单必须携带合法的 sha256 与 size，缺任何一个都视为不可信，界面层退化为
      「仅提示 + 跳浏览器」的旧行为；下载完成后强制校验哈希与大小，任一不匹配立即删除
      临时文件并终止，绝不执行。
    - 授权边界：用户点「立即更新」即为授权，此后下载→校验→安装一气呵成，不必再点一次；
      安装只发生在校验通过之后。自动检查永远只提醒，绝不自行下载或安装。
    - 局限要如实告知：SHA256 防的是传输途中被篡改；清单与安装包在同一台服务器上，
      服务器本身被攻破时两者可被同时替换，SHA256 无法防护（详见 build\README.md）。
    - 网络不可达、超时、JSON 坏掉一律静默返回 $null——检查更新不许影响主程序启动。
#>
#requires -Version 5.1

# 清单地址：托管在自有服务器（Caddy 站点 df.ltz88.cn）。发新版时覆盖服务器上的
# update-manifest.json，客户端下次检查即可发现。
# 本地测试用 Test-BoosterUpdate -ManifestUrl 'file:///...' 临时覆盖。
$script:BoosterManifestUrl = 'https://df.ltz88.cn/update-manifest.json'

# 下载源域名白名单（硬编码，不从任何配置/清单读取）：清单文件本身可能被篡改，
# 若照单全收 setupUrl，攻击者改一行 JSON 就能把用户导去任意恶意地址——这是内置下载
# 最关键的一道闸，改动它必须走代码审查而不是改配置。
$script:BoosterDownloadHosts = @('df.ltz88.cn')

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

# setupUrl 安检：只放行「https + 白名单域名」。返回 Allowed/Reason 而不是裸布尔，
# 拒绝时界面层要把原因落日志（用户看得见拦截，而不是按钮悄悄失灵）。
function Test-BoosterSetupUrl([string]$Url) {
  $deny = { param($why) [pscustomobject]@{ Allowed = $false; Reason = $why } }
  if (-not "$Url".Trim()) { return (& $deny '清单未提供安装包地址') }
  $u = $null
  # 相对路径、裸盘符残片等连 Uri 都构造不出来，直接拒
  if (-not [Uri]::TryCreate("$Url".Trim(), [UriKind]::Absolute, [ref]$u)) {
    return (& $deny "不是合法的绝对地址：$Url")
  }
  # file:// 与 C:\ 本地路径都会解析成 file 协议，和 http 明文一起挡在这条之外
  if ($u.Scheme -ne 'https') { return (& $deny "只允许 https 下载（实际是 $($u.Scheme)）：$Url") }
  if ($script:BoosterDownloadHosts -notcontains $u.Host.ToLowerInvariant()) {
    return (& $deny "下载域名不在白名单内：$($u.Host)")
  }
  [pscustomobject]@{ Allowed = $true; Reason = '' }
}

# 完整性校验：大小与 SHA256 任一不符即删除文件并报告失败——留着一个校验失败的
# 安装包等于留着一颗雷，谁都不该有机会再去双击它。
function Test-BoosterFileIntegrity([string]$Path, [string]$Sha256, [long]$Size) {
  $fail = {
    param($why)
    try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force } } catch {}
    [pscustomobject]@{ Ok = $false; Reason = $why }
  }
  try {
    if (-not (Test-Path -LiteralPath $Path)) { return (& $fail '下载文件不存在') }
    if ("$Sha256" -notmatch '^[0-9a-fA-F]{64}$') { return (& $fail '清单里的 SHA256 不合法，文件按不可信处理已删除') }
    $actualSize = (Get-Item -LiteralPath $Path).Length
    if ($actualSize -ne $Size) {
      return (& $fail "文件大小不符（清单 $Size 字节 / 实际 $actualSize 字节），已删除")
    }
    $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actualHash -ne "$Sha256".ToUpperInvariant()) {
      return (& $fail 'SHA256 校验不通过（文件可能在传输中被篡改），已删除')
    }
    [pscustomobject]@{ Ok = $true; Reason = '' }
  } catch { & $fail "校验过程出错：$($_.Exception.Message)" }
}

# 内置更新下载：URL 安检 → 流式下载（写进度、可取消）→ 完整性校验。
# 同步函数，由界面层丢进后台 runspace 跑，进度经 Synchronized 哈希表回报——
# PS 5.1 + WPF 下跨线程事件回调很脆，轮询共享状态最稳。
# $State 键：Received/Total(字节)、Phase(downloading|done|failed|cancelled)、
#            Error、File(校验通过后的成品路径)、Cancel(界面置 $true 请求中止)、Done
function Invoke-BoosterSetupDownload {
  param(
    [Parameter(Mandatory)][string]$SetupUrl,
    [Parameter(Mandatory)][string]$Sha256,
    [Parameter(Mandatory)][long]$Size,
    [Parameter(Mandatory)][hashtable]$State,
    [int]$TimeoutMs = 15000
  )
  $finish = { param($phase, $err) $State.Phase = $phase; $State.Error = "$err"; $State.Done = $true }
  $tmpFile = $null
  try {
    $State.Received = 0; $State.Total = $Size; $State.Phase = 'downloading'
    $State.Error = ''; $State.File = ''; $State.Done = $false

    $verdict = Test-BoosterSetupUrl $SetupUrl
    if (-not $verdict.Allowed) { & $finish 'failed' "已拦截下载：$($verdict.Reason)"; return }
    # sha256/size 不合法时根本不开始下载：校验注定失败的传输是白费流量
    if ("$Sha256" -notmatch '^[0-9a-fA-F]{64}$') { & $finish 'failed' '清单缺少合法的 SHA256，拒绝下载'; return }
    if ($Size -le 0) { & $finish 'failed' '清单缺少合法的文件大小，拒绝下载'; return }

    # 临时目录自建子目录并清掉上次残留：校验通过前文件绝不落到程序目录
    $tmpDir = Join-Path $env:TEMP 'DeltaForceBooster-Update'
    if (Test-Path -LiteralPath $tmpDir) {
      try { Get-ChildItem -LiteralPath $tmpDir -File | Remove-Item -Force -ErrorAction SilentlyContinue } catch {}
    } else { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }
    # 随机文件名：上次下载的同名文件若被别的进程占着，不至于卡死这次更新
    $tmpFile = Join-Path $tmpDir ("DFB-Setup-{0}.exe" -f [Guid]::NewGuid().ToString('N').Substring(0, 8))

    [Net.ServicePointManager]::SecurityProtocol = `
      [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $req = [Net.WebRequest]::Create($SetupUrl)
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = $TimeoutMs
    $req.UserAgent = 'DeltaForceBooster-Updater'
    $resp = $req.GetResponse()
    $inStream = $resp.GetResponseStream()
    $outStream = [IO.File]::Create($tmpFile)
    try {
      $buf = New-Object byte[] 65536
      while ($true) {
        if ($State.Cancel) { & $finish 'cancelled' '已取消下载'; break }
        $n = $inStream.Read($buf, 0, $buf.Length)
        if ($n -le 0) { break }
        $outStream.Write($buf, 0, $n)
        $State.Received = [long]$State.Received + $n
        # 服务器回的字节数超过清单声明即刻中止：反正校验必失败，没必要让它填满磁盘
        if ([long]$State.Received -gt $Size) { & $finish 'failed' '下载内容超过清单声明的大小，已中止并删除'; break }
      }
    } finally {
      $outStream.Close(); $inStream.Close(); $resp.Close()
    }
    if ($State.Done) {
      try { Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue } catch {}
      return
    }

    $chk = Test-BoosterFileIntegrity $tmpFile $Sha256 $Size
    if (-not $chk.Ok) { & $finish 'failed' $chk.Reason; return }
    $State.File = $tmpFile
    & $finish 'done' ''
  } catch {
    try { if ($tmpFile -and (Test-Path -LiteralPath $tmpFile)) { Remove-Item -LiteralPath $tmpFile -Force } } catch {}
    & $finish 'failed' "下载失败：$($_.Exception.Message)"
  }
}

function Test-BoosterUpdate {
  param(
    [Parameter(Mandatory)][string]$CurrentVersion,
    [string]$ManifestUrl = $script:BoosterManifestUrl,
    [int]$TimeoutMs = 5000,
    [switch]$IncludeSkipped
  )
  try {
    $m = Get-BoosterManifest $ManifestUrl $TimeoutMs
    if (-not $m) { return $null }
    if ((Compare-BoosterVersion "$($m.version)" $CurrentVersion) -le 0) { return $null }
    # 用户点过「不再提醒此版本」的就不再弹；出了更新的版本会重新提醒。
    # 手动检查（-IncludeSkipped）例外：用户主动点按钮就是想看结果，不该被跳过记录挡住
    if (-not $IncludeSkipped) {
      $cfg = Get-BoosterUpdateConfig
      if ("$($cfg.SkippedVersion)" -eq "$($m.version)") { return $null }
    }
    $setupUrl = "$($m.setupUrl)"
    $sha = "$($m.sha256)"
    $size = 0L
    try { if ($m.size) { $size = [long]$m.size } } catch {}
    # 内置更新的准入在这里一次算清：sha256/size 缺失或 setupUrl 过不了安检都退回
    # 「仅提示 + 跳浏览器」的旧行为——降级永远可用，升级必须过全部关卡
    $urlVerdict = Test-BoosterSetupUrl $setupUrl
    $canInline = ($urlVerdict.Allowed -and $sha -match '^[0-9a-fA-F]{64}$' -and $size -gt 0)
    [pscustomobject]@{
      Version    = "$($m.version)"
      Notes      = "$($m.notes)"
      Url        = "$($m.url)"
      Current    = "$CurrentVersion"
      SetupUrl   = $setupUrl
      Sha256     = $sha
      Size       = $size
      CanInline  = $canInline
      InlineDeny = $(if ($canInline) { '' } elseif (-not $urlVerdict.Allowed) { $urlVerdict.Reason } else { '清单缺少 SHA256 或文件大小，内置更新已禁用' })
    }
  } catch { $null }
}
