<#
  DeltaForceBooster 更新检查模块 — v0.8
  独立于优化引擎：负责「取清单 → 比版本 → 报告结果」+「带校验的内置下载」。
  v0.8：排队时显示前方人数与服务器预计等待时间；用户取消后立即通知服务器释放票据。
  v0.7：官网安装包下载先进入服务器队列；获得名额后使用短时签名地址下载，并继续支持
        Range 断点续传。排队位置和重试状态都会回报给界面。
  v0.6：下载读取超时或连接中断时自动按已接收字节断点续传；有限重试耗尽后返回
        用户可理解的网络错误，不再暴露 PowerShell 的 Read(...) 调用异常。
  v0.5：下载改用 CreateNew + 独占句柄完成大小/SHA256 校验；成品与完整性 sidecar
        落在封闭 ACL staging，交给安装器后启动第一时间再次复验。
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
param(
  [switch]$SecureStageHelper,
  [string]$StageSource,
  [string]$StageId,
  [string]$StageReaderSid,
  [string]$StageSha256,
  [long]$StageSize = 0
)

# 清单地址：托管在自有服务器（Caddy 站点 df.ltz88.cn）。发新版时覆盖服务器上的
# update-manifest.json，客户端下次检查即可发现。
# 本地测试用 Test-BoosterUpdate -ManifestUrl 'file:///...' 临时覆盖。
$script:BoosterManifestUrl = 'https://df.ltz88.cn/update-manifest.json'

# 下载源域名白名单（硬编码，不从任何配置/清单读取）：清单文件本身可能被篡改，
# 若照单全收 setupUrl，攻击者改一行 JSON 就能把用户导去任意恶意地址——这是内置下载
# 最关键的一道闸，改动它必须走代码审查而不是改配置。
$script:BoosterDownloadHosts = @('df.ltz88.cn')

# 本模块位于 scripts\，工具根目录是它的上一级。长期 high GUI 会把
# $script:BoosterUserConfigDir 指向 ProgramData 的受保护 per-SID 状态区；只有旧的
# medium 调用方才回退到它自己的 LocalAppData。
$script:BoosterUpdaterRoot = Split-Path -Parent $PSScriptRoot
$script:BoosterUpdaterPath = $PSCommandPath

function Get-BoosterUpdateConfigPath {
  $d = $script:BoosterUserConfigDir
  if (-not $d) {
    if (Test-BoosterUpdaterElevated) { throw '管理员更新器缺少受保护 per-SID 配置目录' }
    $la = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $d = Join-Path $la 'DeltaForceBooster\config'
  }
  $d = [IO.Path]::GetFullPath($d)
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

function Get-BoosterDownloadQueueEndpoints([string]$SetupUrl) {
  $uri = $null
  if (-not [Uri]::TryCreate("$SetupUrl", [UriKind]::Absolute, [ref]$uri)) { return $null }
  if ($uri.Scheme -ne 'https' -or $script:BoosterDownloadHosts -notcontains $uri.Host.ToLowerInvariant()) {
    return $null
  }
  $origin = $uri.GetLeftPart([UriPartial]::Authority)
  [pscustomobject]@{
    Join = "$origin/report/download-queue/join"
    Status = "$origin/report/download-queue/status"
    Cancel = "$origin/report/download-queue/cancel"
  }
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

function Test-BoosterUpdaterElevated {
  $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-BoosterNoReparsePath([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path)
  $root = [IO.Path]::GetPathRoot($full)
  if (-not $root) { throw "路径没有有效根目录：$Path" }
  $current = $root.TrimEnd('\')
  $rest = $full.Substring($root.Length)
  foreach ($part in @($rest -split '\\' | Where-Object { $_ })) {
    if ($current -match '^[A-Za-z]:$') { $current = "$current\$part" }
    else { $current = Join-Path $current $part }
    if (-not (Test-Path -LiteralPath $current)) { break }
    if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
      throw "更新 staging 路径包含 junction/symlink/reparse point：$current"
    }
  }
}

function Set-BoosterStagingDirectoryAcl {
  param([string]$Path, [bool]$Writable, [Security.Principal.SecurityIdentifier]$ReaderSid, [switch]$TraverseOnly)
  $current = [Security.Principal.WindowsIdentity]::GetCurrent().User
  if (-not $ReaderSid) { $ReaderSid = $current }
  $admins = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
  $system = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
  $elevated = Test-BoosterUpdaterElevated
  $owner = $(if ($elevated) { $admins } else { $current })
  $inherit = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
  $none = [Security.AccessControl.PropagationFlags]::None
  $allow = [Security.AccessControl.AccessControlType]::Allow
  $acl = New-Object Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true, $false)
  $acl.SetOwner($owner)
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($system, 'FullControl', $inherit, $none, $allow)))
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($admins, 'FullControl', $inherit, $none, $allow)))
  $userRights = $(if ($TraverseOnly) { 'Traverse' } elseif ($Writable) { 'FullControl' } else { 'ReadAndExecute' })
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($ReaderSid, $userRights, $inherit, $none, $allow)))
  (New-Object IO.DirectoryInfo($Path)).SetAccessControl($acl)
}

function Set-BoosterStagingFileAcl {
  param([string]$Path, [Security.Principal.SecurityIdentifier]$ReaderSid)
  $current = [Security.Principal.WindowsIdentity]::GetCurrent().User
  if (-not $ReaderSid) { $ReaderSid = $current }
  $admins = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
  $system = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
  $elevated = Test-BoosterUpdaterElevated
  $owner = $(if ($elevated) { $admins } else { $current })
  $allow = [Security.AccessControl.AccessControlType]::Allow
  $acl = New-Object Security.AccessControl.FileSecurity
  $acl.SetAccessRuleProtection($true, $false)
  $acl.SetOwner($owner)
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($system, 'FullControl', $allow)))
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($admins, 'FullControl', $allow)))
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($ReaderSid, 'ReadAndExecute', $allow)))
  (New-Object IO.FileInfo($Path)).SetAccessControl($acl)
  # staging 一旦被错误的 ACL 工具或平台差异写成空 DACL，连提权安装器也读不到文件。
  # 因此不能只相信 SetAccessControl 没抛异常：写完必须从磁盘重新读取并验证。
  $written = (New-Object IO.FileInfo($Path)).GetAccessControl([Security.AccessControl.AccessControlSections]'Owner, Access')
  $writtenOwner = $written.GetOwner([Security.Principal.SecurityIdentifier]).Value
  if ($writtenOwner -ne $owner.Value) { throw "更新 staging 文件所有者写入失败：$Path" }
  $rights = @{}
  foreach ($rule in $written.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier])) {
    if ($rule.AccessControlType -eq $allow) {
      $sid = $rule.IdentityReference.Value
      if (-not $rights.ContainsKey($sid)) { $rights[$sid] = [Security.AccessControl.FileSystemRights]0 }
      $rights[$sid] = $rights[$sid] -bor $rule.FileSystemRights
    }
  }
  $readExecute = [Security.AccessControl.FileSystemRights]::ReadAndExecute
  $fullControl = [Security.AccessControl.FileSystemRights]::FullControl
  if (-not $rights.ContainsKey($system.Value) -or (($rights[$system.Value] -band $fullControl) -ne $fullControl) -or
      -not $rights.ContainsKey($admins.Value) -or (($rights[$admins.Value] -band $fullControl) -ne $fullControl) -or
      -not $rights.ContainsKey($ReaderSid.Value) -or (($rights[$ReaderSid.Value] -band $readExecute) -ne $readExecute)) {
    throw "更新 staging 文件 ACL 写入后复验失败：$Path"
  }
}

function Test-BoosterProtectedDirectoryAcl([string]$Path) {
  try {
    $acl = (New-Object IO.DirectoryInfo($Path)).GetAccessControl([Security.AccessControl.AccessControlSections]'Owner, Access')
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin @('S-1-5-18','S-1-5-32-544')) { return $false }
    # 不要把 Modify/FullControl 这类复合枚举直接 OR 进掩码：它们也包含 Read/Execute，
    # 会把合法的普通用户 RX ACE 误判成可写，导致第二次更新永远失败。
    $writeMask = [Security.AccessControl.FileSystemRights]'WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, DeleteSubdirectoriesAndFiles, Delete, ChangePermissions, TakeOwnership'
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544') -and
          (($rule.FileSystemRights -band $writeMask) -ne 0)) { return $false }
    }
    $true
  } catch { $false }
}

function Test-BoosterProtectedCodeFile([string]$Path) {
  try {
    Assert-BoosterNoReparsePath $Path
    $acl = (New-Object IO.FileInfo($Path)).GetAccessControl([Security.AccessControl.AccessControlSections]'Owner, Access')
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin @('S-1-5-18','S-1-5-32-544') -and $owner -notlike 'S-1-5-80-*') { return $false }
    $writeMask = [Security.AccessControl.FileSystemRights]'WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, DeleteSubdirectoriesAndFiles, Delete, ChangePermissions, TakeOwnership'
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $sid = $rule.IdentityReference.Value
      if ($rule.AccessControlType -eq 'Allow' -and $sid -notin @('S-1-5-18','S-1-5-32-544') -and $sid -notlike 'S-1-5-80-*' -and
          (($rule.FileSystemRights -band $writeMask) -ne 0)) { return $false }
    }
    $true
  } catch { $false }
}

# 提权链不能信任调用进程继承来的 ProgramData/SystemRoot 环境变量；普通用户可以在启动
# Setup/UAC 前自行覆盖进程环境。这里全部走系统 Known Folder/API 返回的真实目录。
function Get-BoosterTrustedProgramData {
  $path = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
  if (-not $path) { throw '系统未提供受信 ProgramData 路径' }
  [IO.Path]::GetFullPath($path)
}

function Get-BoosterTrustedSystemDirectory {
  $path = [Environment]::SystemDirectory
  if (-not $path) { throw '系统未提供受信 System32 路径' }
  [IO.Path]::GetFullPath($path)
}

function Remove-BoosterProtectedStagingTree([string]$Path) {
  Assert-BoosterNoReparsePath $Path
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
  if (-not (Test-BoosterProtectedDirectoryAcl $Path)) { throw "旧更新 staging 目录 ACL/所有者不可信：$Path" }
  foreach ($entry in @(Get-ChildItem -LiteralPath $Path -Force)) {
    if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "旧更新 staging 包含 junction/symlink/reparse point：$($entry.FullName)"
    }
    if ($entry.PSIsContainer) {
      Remove-BoosterProtectedStagingTree $entry.FullName
    } else {
      if (-not (Test-BoosterProtectedCodeFile $entry.FullName)) {
        throw "旧更新 staging 文件 ACL/所有者不可信：$($entry.FullName)"
      }
      Remove-Item -LiteralPath $entry.FullName -Force -ErrorAction Stop
    }
  }
  Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
}

function Remove-BoosterExpiredAdminStaging([string]$Root) {
  if (-not (Test-BoosterUpdaterElevated)) { return }
  Assert-BoosterNoReparsePath $Root
  if (-not (Test-BoosterProtectedDirectoryAcl $Root)) { throw "更新 staging 根目录 ACL/所有者不可信：$Root" }
  $cutoff = [DateTime]::UtcNow.AddHours(-24)
  foreach ($item in @(Get-ChildItem -LiteralPath $Root -Force -Directory)) {
    # 只处理本更新器创建的单层 GUID 目录；最近 24 小时目录可能仍被另一个更新流程使用。
    if ($item.Name -notmatch '^[0-9a-fA-F]{32}$' -or $item.CreationTimeUtc -gt $cutoff) { continue }
    Remove-BoosterProtectedStagingTree $item.FullName
  }
}

function New-BoosterSecureStaging {
  param([switch]$ForceProgramData, [string]$Id, [Security.Principal.SecurityIdentifier]$ReaderSid)
  $elevated = Test-BoosterUpdaterElevated
  if ($ForceProgramData -and -not $elevated) { throw 'ProgramData 安全 staging 只能由提权 helper 创建' }
  if (-not $ReaderSid) { $ReaderSid = [Security.Principal.WindowsIdentity]::GetCurrent().User }
  $baseRoot = $(if ($elevated) {
    Get-BoosterTrustedProgramData
  } else {
    [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
  })
  if (-not $baseRoot) { throw '系统未提供更新 staging 根目录' }
  # 与 engine 的 %ProgramData%\DeltaForceBooster（backup/ipc/keys）彻底隔离；更新根需要
  # 给原用户 Traverse/RX，而 engine 根的 exact ACL 只允许 Admin/SYSTEM，两者不能复用。
  $programRoot = Join-Path $baseRoot $(if ($elevated) { 'DeltaForceBooster-UpdateStaging' } else { 'DeltaForceBooster' })
  if ($elevated) {
    Assert-BoosterNoReparsePath $programRoot
    if (Test-Path -LiteralPath $programRoot) {
      if (-not (Test-BoosterProtectedDirectoryAcl $programRoot)) { throw "ProgramData 根目录 ACL/所有者不可信：$programRoot" }
    } else {
      # .NET Framework 的 ACL 重载原子创建目录，不留下“先创建、后加固”的可抢占窗口。
      $admins = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
      $system = New-Object Security.Principal.SecurityIdentifier([Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
      $inherit = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
      $none = [Security.AccessControl.PropagationFlags]::None
      $allow = [Security.AccessControl.AccessControlType]::Allow
      $rootAcl = New-Object Security.AccessControl.DirectorySecurity
      $rootAcl.SetAccessRuleProtection($true, $false); $rootAcl.SetOwner($admins)
      $rootAcl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($system, 'FullControl', $inherit, $none, $allow)))
      $rootAcl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($admins, 'FullControl', $inherit, $none, $allow)))
      $rootAcl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($ReaderSid, 'Traverse', $inherit, $none, $allow)))
      [IO.Directory]::CreateDirectory($programRoot, $rootAcl) | Out-Null
    }
    Set-BoosterStagingDirectoryAcl -Path $programRoot -Writable $false -ReaderSid $ReaderSid -TraverseOnly
    Remove-BoosterExpiredAdminStaging $programRoot
  }
  $base = $(if ($elevated) { $programRoot } else { Join-Path $programRoot 'UpdateStaging' })
  Assert-BoosterNoReparsePath $base
  [IO.Directory]::CreateDirectory($base) | Out-Null
  Assert-BoosterNoReparsePath $base
  # 提权态只给 Administrators/SYSTEM 写；普通 GUI 只在完成后读取并执行。
  Set-BoosterStagingDirectoryAcl -Path $base -Writable (-not $elevated) -ReaderSid $ReaderSid
  if (-not $Id) { $Id = [Guid]::NewGuid().ToString('N') }
  if ($Id -notmatch '^[0-9a-fA-F]{32}$') { throw '更新 staging Id 无效' }
  $dir = Join-Path $base $Id.ToLowerInvariant()
  [IO.Directory]::CreateDirectory($dir) | Out-Null
  Set-BoosterStagingDirectoryAcl -Path $dir -Writable (-not $elevated) -ReaderSid $ReaderSid
  Assert-BoosterNoReparsePath $dir
  [pscustomobject]@{ Directory = $dir; Elevated = $elevated }
}

function Protect-BoosterStaging {
  param([string]$Directory, [string[]]$Files, [bool]$Elevated, [Security.Principal.SecurityIdentifier]$ReaderSid)
  foreach ($file in $Files) { Set-BoosterStagingFileAcl -Path $file -ReaderSid $ReaderSid }
  Set-BoosterStagingDirectoryAcl -Path $Directory -Writable $false -ReaderSid $ReaderSid
  if ($Elevated) {
    # 高完整性标签再挡住管理员账号的 medium token；DACL 所有者已经是 Administrators。
    $icacls = Join-Path (Get-BoosterTrustedSystemDirectory) 'icacls.exe'
    & $icacls $Directory /setintegritylevel '(OI)(CI)H' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "无法给更新 staging 设置高完整性标签（icacls 退出码 $LASTEXITCODE）" }
  }
}

function Invoke-BoosterSecureStageHelper {
  param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Id,
    [Parameter(Mandatory)][string]$ReaderSid,
    [Parameter(Mandatory)][string]$Sha256,
    [Parameter(Mandatory)][long]$Size
  )
  $stage = $null; $input = $null; $output = $null; $side = $null
  try {
    if (-not (Test-BoosterUpdaterElevated)) { throw '安全 staging helper 未获得管理员权限' }
    if ($Id -notmatch '^[0-9a-fA-F]{32}$' -or "$Sha256" -notmatch '^[0-9a-fA-F]{64}$' -or $Size -le 0) {
      throw '安全 staging helper 参数无效'
    }
    try { $reader = New-Object Security.Principal.SecurityIdentifier($ReaderSid) }
    catch { throw '安全 staging helper ReaderSid 无效' }
    if (-not $reader.IsAccountSid()) { throw '安全 staging helper ReaderSid 不是账户 SID' }
    Assert-BoosterNoReparsePath $Source
    $input = [IO.FileStream]::new($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read,
      [IO.FileShare]::ReadWrite, 65536, [IO.FileOptions]::SequentialScan)
    if ($input.Length -ne $Size) { throw "源安装包大小不符（预期 $Size / 实际 $($input.Length)）" }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $sourceHash = ([BitConverter]::ToString($sha.ComputeHash($input))).Replace('-', '') }
    finally { $sha.Dispose() }
    if ($sourceHash -ne "$Sha256".ToUpperInvariant()) { throw '源安装包 SHA256 复验失败' }
    $input.Position = 0

    $stage = New-BoosterSecureStaging -ForceProgramData -Id $Id -ReaderSid $reader
    $dest = Join-Path $stage.Directory 'DeltaForceBooster-Setup.exe'
    $metaPath = "$dest.integrity"
    $output = [IO.FileStream]::new($dest, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite,
      [IO.FileShare]::None, 65536, [IO.FileOptions]::WriteThrough)
    $input.CopyTo($output)
    $output.Flush($true)
    if ($output.Length -ne $Size) { throw '安全 staging 复制后的大小不符' }
    $output.Position = 0
    $sha2 = [Security.Cryptography.SHA256]::Create()
    try { $destHash = ([BitConverter]::ToString($sha2.ComputeHash($output))).Replace('-', '') }
    finally { $sha2.Dispose() }
    if ($destHash -ne "$Sha256".ToUpperInvariant()) { throw '安全 staging 复制后的 SHA256 不符' }

    $bytes = [Text.Encoding]::ASCII.GetBytes("$($destHash.ToUpperInvariant())`r`n$Size`r`n")
    $side = [IO.FileStream]::new($metaPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
      [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
    $side.Write($bytes, 0, $bytes.Length); $side.Flush($true)
    Protect-BoosterStaging -Directory $stage.Directory -Files @($dest, $metaPath) -Elevated $true -ReaderSid $reader
    $side.Close(); $side = $null; $output.Close(); $output = $null; $input.Close(); $input = $null
    return 0
  } catch {
    try { if ($side) { $side.Close() } } catch {}
    try { if ($output) { $output.Close() } } catch {}
    try { if ($input) { $input.Close() } } catch {}
    try { if ($stage -and (Test-Path -LiteralPath $stage.Directory)) { Remove-Item -LiteralPath $stage.Directory -Recurse -Force } } catch {}
    return 1
  }
}

function Copy-BoosterSetupToAdminStaging {
  param([string]$Source, [string]$Sha256, [long]$Size)
  if (-not (Test-BoosterUpdaterElevated)) {
    throw '更新安装必须在 EngineHost 管理员会话中执行，请从“启动优化工具.exe”重新打开软件'
  }
  if (-not $script:BoosterUpdaterPath -or -not (Test-Path -LiteralPath $script:BoosterUpdaterPath -PathType Leaf)) {
    throw '更新 helper 脚本路径不存在'
  }
  if (-not (Test-BoosterProtectedCodeFile $script:BoosterUpdaterPath)) {
    throw '更新 helper 脚本不在受保护代码目录，已拒绝提权执行；请从官网安装到 Program Files'
  }
  # helper 代码必须来自受保护的已安装 scripts\updater.ps1；启动器发布哈希也覆盖该文件。
  $id = [Guid]::NewGuid().ToString('N')
  $readerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $psExe = Join-Path (Get-BoosterTrustedSystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
  $args = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script:BoosterUpdaterPath`"",
    '-SecureStageHelper', '-StageSource', "`"$Source`"", '-StageId', $id, '-StageReaderSid', $readerSid,
    '-StageSha256', "$Sha256", '-StageSize', "$Size"
  )
  # 正常会话已经由 EngineHost 提权；此兼容 helper 继承 high token，不再制造第二次 UAC。
  $p = Start-Process $psExe -WindowStyle Hidden -Wait -PassThru -ArgumentList $args
  if (-not $p -or $p.ExitCode -ne 0) { throw "安全 staging helper 失败或 UAC 被取消（退出码 $($p.ExitCode)）" }
  $programData = Get-BoosterTrustedProgramData
  $dest = Join-Path (Join-Path $programData 'DeltaForceBooster-UpdateStaging') "$id\DeltaForceBooster-Setup.exe"
  Assert-BoosterNoReparsePath $dest
  $chk = Test-BoosterFileIntegrity $dest $Sha256 $Size
  if (-not $chk.Ok) { throw "安全 staging helper 结果复验失败：$($chk.Reason)" }
  if (-not (Test-Path -LiteralPath "$dest.integrity" -PathType Leaf)) { throw '安全 staging helper 未生成完整性 sidecar' }
  $dest
}

# 给网络读取失败打内部标记：只重试 GetResponse/Read/提前 EOF，磁盘写入、响应范围异常、
# 重定向越过白名单等错误继续立即失败，避免把本地故障或安全校验失败误当成网络抖动。
function New-BoosterRetryableDownloadException {
  param([string]$Message, [Exception]$InnerException)
  $e = $(if ($InnerException) { [IO.IOException]::new($Message, $InnerException) } else { [IO.IOException]::new($Message) })
  $e.Data['DeltaForceBooster.RetryableDownload'] = $true
  $e
}

function Test-BoosterRetryableDownloadException([Exception]$Exception) {
  $cursor = $Exception
  while ($cursor) {
    if ($cursor.Data -and $cursor.Data.Contains('DeltaForceBooster.RetryableDownload')) { return $true }
    if ($cursor -is [Net.WebException]) {
      return $cursor.Status -in @(
        [Net.WebExceptionStatus]::ConnectFailure,
        [Net.WebExceptionStatus]::ConnectionClosed,
        [Net.WebExceptionStatus]::KeepAliveFailure,
        [Net.WebExceptionStatus]::NameResolutionFailure,
        [Net.WebExceptionStatus]::PipelineFailure,
        [Net.WebExceptionStatus]::ProxyNameResolutionFailure,
        [Net.WebExceptionStatus]::ReceiveFailure,
        [Net.WebExceptionStatus]::RequestCanceled,
        [Net.WebExceptionStatus]::SendFailure,
        [Net.WebExceptionStatus]::Timeout
      )
    }
    $cursor = $cursor.InnerException
  }
  $false
}

function Wait-BoosterDownloadRetry {
  param([hashtable]$State, [int]$DelayMs)
  $remaining = [Math]::Max(0, $DelayMs)
  while ($remaining -gt 0) {
    if ($State.Cancel) { return $false }
    $slice = [Math]::Min(100, $remaining)
    Start-Sleep -Milliseconds $slice
    $remaining -= $slice
  }
  -not [bool]$State.Cancel
}

function Invoke-BoosterQueueJsonRequest {
  param(
    [Parameter(Mandatory)][string]$Url,
    [ValidateSet('GET','POST')][string]$Method = 'GET',
    [ValidateRange(500, 30000)][int]$TimeoutMs = 5000,
    [string]$Body = '{}'
  )
  $resp = $null; $stream = $null; $reader = $null
  try {
    [Net.ServicePointManager]::SecurityProtocol = `
      [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $req = [Net.HttpWebRequest]::Create($Url)
    $req.Method = $Method
    $req.Timeout = $TimeoutMs
    $req.ReadWriteTimeout = $TimeoutMs
    $req.UserAgent = 'DeltaForceBooster-Updater'
    $req.Accept = 'application/json'
    $req.AllowAutoRedirect = $false
    if ($Method -eq 'POST') {
      $bodyBytes = [Text.Encoding]::UTF8.GetBytes($Body)
      $req.ContentType = 'application/json'
      $req.ContentLength = $bodyBytes.Length
      $requestStream = $req.GetRequestStream()
      try { $requestStream.Write($bodyBytes, 0, $bodyBytes.Length) } finally { $requestStream.Close() }
    }
    try { $resp = $req.GetResponse() }
    catch [Net.WebException] {
      if (-not $_.Exception.Response) {
        throw (New-BoosterRetryableDownloadException '排队服务器连接超时或中断' $_.Exception)
      }
      $resp = $_.Exception.Response
    }
    $statusCode = [int]$resp.StatusCode
    $stream = $resp.GetResponseStream()
    $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    if ($raw.Length -gt 65536) { throw '排队服务器响应过大' }
    $payload = $null
    if ($raw.Trim()) {
      try { $payload = $raw | ConvertFrom-Json }
      catch { throw '排队服务器返回了无效数据' }
    }
    [pscustomobject]@{ StatusCode = $statusCode; Payload = $payload }
  } catch {
    if (Test-BoosterRetryableDownloadException $_.Exception) { throw }
    if ($_.Exception -is [Net.WebException] -or $_.Exception -is [IO.IOException]) {
      throw (New-BoosterRetryableDownloadException '排队服务器连接超时或中断' $_.Exception)
    }
    throw
  } finally {
    try { if ($reader) { $reader.Close() } } catch {}
    try { if ($stream) { $stream.Close() } } catch {}
    try { if ($resp) { $resp.Close() } } catch {}
  }
}

function Stop-BoosterDownloadQueueTicket {
  param(
    [Parameter(Mandatory)][string]$SetupUrl,
    [Parameter(Mandatory)][string]$Ticket,
    [ValidateRange(500, 30000)][int]$TimeoutMs = 3000
  )
  if ($Ticket -notmatch '^[A-Za-z0-9_-]{20,128}$') { return $false }
  $endpoints = Get-BoosterDownloadQueueEndpoints $SetupUrl
  if (-not $endpoints -or -not "$($endpoints.Cancel)") { return $false }
  $body = @{ ticket = $Ticket } | ConvertTo-Json -Compress
  try {
    $response = Invoke-BoosterQueueJsonRequest -Url $endpoints.Cancel -Method POST `
      -TimeoutMs $TimeoutMs -Body $body
    return ($response.StatusCode -eq 200)
  } catch {
    return $false
  }
}

function Wait-BoosterDownloadQueue {
  param(
    [Parameter(Mandatory)][string]$SetupUrl,
    [Parameter(Mandatory)][hashtable]$State,
    [ValidateRange(500, 30000)][int]$TimeoutMs = 5000,
    [ValidateRange(1, 10)][int]$MaxFailures = 5
  )
  $endpoints = Get-BoosterDownloadQueueEndpoints $SetupUrl
  if (-not $endpoints) { return $SetupUrl }

  $setupUri = [Uri]$SetupUrl
  $ticket = ''
  $consecutiveFailures = 0
  $State.Phase = 'queued'
  $State.Status = '正在进入服务器下载队列…'
  $State.QueuePosition = 0; $State.QueueAhead = 0
  $State.QueueActive = 0; $State.QueueCapacity = 0
  $State.QueueEstimatedWaitSeconds = 0
  $State.QueueTicket = ''

  $releaseTicket = $true
  try {
    while (-not $State.Cancel) {
      $requestUrl = $(if ($ticket) {
        "$($endpoints.Status)?ticket=$([Uri]::EscapeDataString($ticket))"
      } else { "$($endpoints.Join)" })
      $method = $(if ($ticket) { 'GET' } else { 'POST' })
      try {
        $response = Invoke-BoosterQueueJsonRequest -Url $requestUrl -Method $method -TimeoutMs $TimeoutMs
      } catch {
        if (-not (Test-BoosterRetryableDownloadException $_.Exception)) { throw }
        $consecutiveFailures++
        if ($consecutiveFailures -ge $MaxFailures) {
          throw "排队服务器连续无法响应（已自动重试 $MaxFailures 次）。请稍后重试或打开官网下载。"
        }
        $State.Status = "排队连接短暂中断，正在重试（$consecutiveFailures/$MaxFailures）…"
        if (-not (Wait-BoosterDownloadRetry -State $State -DelayMs 2000)) { return $null }
        continue
      }

      if ($response.StatusCode -eq 404 -and $ticket) {
        $ticket = ''; $State.QueueTicket = ''
        $State.Status = '排队名额已过期，正在重新进入队列…'
        continue
      }
      if ($response.StatusCode -eq 429 -or $response.StatusCode -ge 500) {
        $consecutiveFailures++
        if ($consecutiveFailures -ge $MaxFailures) {
          throw "排队服务器繁忙（已自动重试 $MaxFailures 次）。请稍后重试或打开官网下载。"
        }
        $State.Status = "排队服务器繁忙，正在重试（$consecutiveFailures/$MaxFailures）…"
        if (-not (Wait-BoosterDownloadRetry -State $State -DelayMs 2000)) { return $null }
        continue
      }
      if ($response.StatusCode -ne 200 -or -not $response.Payload) {
        throw "排队服务器返回了异常状态：HTTP $($response.StatusCode)"
      }
      $consecutiveFailures = 0
      $payload = $response.Payload
      $nextTicket = "$($payload.ticket)"
      if ($nextTicket -notmatch '^[A-Za-z0-9_-]{20,128}$') { throw '排队服务器返回了无效票据' }
      $ticket = $nextTicket
      $State.QueueTicket = $ticket

      $State.QueuePosition = [Math]::Max(0, [int]$payload.position)
      $State.QueueAhead = [Math]::Max(0, [int]$payload.ahead)
      $State.QueueActive = [Math]::Max(0, [int]$payload.active)
      $State.QueueCapacity = [Math]::Max(1, [int]$payload.capacity)
      try {
        $State.QueueEstimatedWaitSeconds = [Math]::Max(0, [Math]::Min(86400, [int]$payload.estimatedWaitSeconds))
      } catch { $State.QueueEstimatedWaitSeconds = 0 }
      if ("$($payload.state)" -eq 'ready') {
        $downloadUrl = "$($payload.downloadUrl)"
        $verdict = Test-BoosterSetupUrl $downloadUrl
        if (-not $verdict.Allowed) { throw "排队下载地址已拦截：$($verdict.Reason)" }
        $downloadUri = [Uri]$downloadUrl
        if ($downloadUri.AbsolutePath -ne $setupUri.AbsolutePath) {
          throw '排队下载地址与清单安装包路径不一致'
        }
        $State.Phase = 'downloading'
        $State.Status = '已获得服务器下载名额，正在开始下载…'
        $releaseTicket = $false
        return $downloadUrl
      }
      if ("$($payload.state)" -ne 'queued') { throw '排队服务器返回了未知状态' }

      $estimateText = $(if ([int]$State.QueueEstimatedWaitSeconds -ge 60) {
        "预计约 $([Math]::Ceiling([int]$State.QueueEstimatedWaitSeconds / 60.0)) 分钟"
      } elseif ([int]$State.QueueEstimatedWaitSeconds -gt 0) {
        "预计约 $([int]$State.QueueEstimatedWaitSeconds) 秒"
      } else { '正在估算等待时间' })
      $State.Status = "服务器排队中：前方 $($State.QueueAhead) 位，$estimateText…"
      $retrySeconds = 2
      try { $retrySeconds = [Math]::Max(1, [Math]::Min(10, [int]$payload.retryAfter)) } catch {}
      if (-not (Wait-BoosterDownloadRetry -State $State -DelayMs ($retrySeconds * 1000))) { return $null }
    }
    $null
  } finally {
    if ($releaseTicket -and $ticket) {
      [void](Stop-BoosterDownloadQueueTicket -SetupUrl $SetupUrl -Ticket $ticket `
        -TimeoutMs ([Math]::Min($TimeoutMs, 3000)))
      $State.QueueTicket = ''
    }
  }
}

# 内置更新下载：URL 安检 → 流式下载（写进度、可取消、超时断点续传）→ 完整性校验。
# 同步函数，由界面层丢进后台 runspace 跑，进度经 Synchronized 哈希表回报——
# PS 5.1 + WPF 下跨线程事件回调很脆，轮询共享状态最稳。
# $State 键：Received/Total(字节)、Phase(queued|downloading|done|failed|cancelled)、
#            Status/QueuePosition/QueueAhead/QueueActive/QueueCapacity/QueueEstimatedWaitSeconds/
#            QueueTicket/RetryCount、
#            Error、File(校验通过后的成品路径)、
#            Cancel(界面置 $true 请求中止)、Done
function Invoke-BoosterSetupDownload {
  param(
    [Parameter(Mandatory)][string]$SetupUrl,
    [Parameter(Mandatory)][string]$Sha256,
    [Parameter(Mandatory)][long]$Size,
    [Parameter(Mandatory)][hashtable]$State,
    [ValidateRange(100, 300000)][int]$TimeoutMs = 15000,
    [ValidateRange(1, 8)][int]$MaxAttempts = 4,
    [ValidateRange(0, 10000)][int]$RetryDelayMs = 750
  )
  $finish = { param($phase, $err) $State.Phase = $phase; $State.Error = "$err"; $State.Done = $true }
  $tmpFile = $null
  $sidecar = $null
  $stageInfo = $null
  $outStream = $null
  $sideStream = $null
  try {
    $State.Received = 0; $State.Total = $Size; $State.Phase = 'downloading'
    $State.Status = '正在下载更新…'; $State.RetryCount = 0
    $State.QueuePosition = 0; $State.QueueAhead = 0
    $State.QueueActive = 0; $State.QueueCapacity = 0
    $State.QueueEstimatedWaitSeconds = 0
    $State.QueueTicket = ''
    $State.Error = ''; $State.File = ''; $State.Done = $false
    $State.ExpectedSha256 = "$Sha256".ToUpperInvariant(); $State.ExpectedSize = $Size

    $verdict = Test-BoosterSetupUrl $SetupUrl
    if (-not $verdict.Allowed) { & $finish 'failed' "已拦截下载：$($verdict.Reason)"; return }
    # sha256/size 不合法时根本不开始下载：校验注定失败的传输是白费流量
    if ("$Sha256" -notmatch '^[0-9a-fA-F]{64}$') { & $finish 'failed' '清单缺少合法的 SHA256，拒绝下载'; return }
    if ($Size -le 0) { & $finish 'failed' '清单缺少合法的文件大小，拒绝下载'; return }

    $downloadUrl = Wait-BoosterDownloadQueue -SetupUrl $SetupUrl -State $State `
      -TimeoutMs ([Math]::Max(500, [Math]::Min(30000, $TimeoutMs)))
    if ($State.Cancel -or -not $downloadUrl) { & $finish 'cancelled' '已取消下载'; return }
    $State.Phase = 'downloading'
    $State.Status = '正在下载更新…'

    # GUID staging + CreateNew。非提权态保留源句柄禁止写/删，同时让管理员 helper 只读打开、
    # 复验并复制到 Administrators-owned ProgramData；普通 GUI 最终绝不执行 user-owned 文件。
    $stageInfo = New-BoosterSecureStaging
    $tmpFile = Join-Path $stageInfo.Directory 'DeltaForceBooster-Setup.exe'
    $sidecar = "$tmpFile.integrity"

    [Net.ServicePointManager]::SecurityProtocol = `
      [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $outStream = [IO.FileStream]::new($tmpFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite,
      [IO.FileShare]::Read, 65536, [IO.FileOptions]::WriteThrough)

    $buf = New-Object byte[] 65536
    $attempt = 0
    while ([long]$State.Received -lt $Size -and -not $State.Done) {
      $attempt++
      $requestedOffset = [long]$State.Received
      $resp = $null; $inStream = $null; $retryError = $null
      try {
        if ($outStream.Length -ne $requestedOffset) { throw '本地下载进度与临时文件长度不一致' }
        $outStream.Position = $requestedOffset
        $req = [Net.WebRequest]::Create($downloadUrl)
        $req.Timeout = $TimeoutMs
        $req.ReadWriteTimeout = $TimeoutMs
        $req.UserAgent = 'DeltaForceBooster-Updater'
        $req.AllowAutoRedirect = $true
        if ($requestedOffset -gt 0) { $req.AddRange($requestedOffset) }
        try { $resp = $req.GetResponse() }
        catch { throw $_.Exception }

        $redirectVerdict = Test-BoosterSetupUrl "$($resp.ResponseUri.AbsoluteUri)"
        if (-not $redirectVerdict.Allowed) { throw "下载重定向已拦截：$($redirectVerdict.Reason)" }

        if ($resp -is [Net.HttpWebResponse]) {
          $status = [int]$resp.StatusCode
          if ($status -notin @(200, 206)) { throw "下载服务器返回了不支持的状态码：$status" }
          if ($status -eq 206) {
            $contentRange = "$($resp.Headers['Content-Range'])"
            if ($contentRange -notmatch '^bytes\s+(\d+)-(\d+)/(\d+)$') {
              throw '断点续传响应缺少合法的 Content-Range'
            }
            $rangeStart = [long]$Matches[1]; $rangeEnd = [long]$Matches[2]; $rangeTotal = [long]$Matches[3]
            if ($rangeStart -ne $requestedOffset -or $rangeEnd -lt $rangeStart -or
                $rangeEnd -ge $Size -or $rangeTotal -ne $Size) {
              throw "断点续传范围与清单不一致：$contentRange"
            }
          } elseif ($requestedOffset -gt 0) {
            # 少数代理会忽略 Range 并回 200；此时只能从零覆盖，绝不能把完整响应追加到旧片段。
            $outStream.SetLength(0); $outStream.Position = 0
            $State.Received = 0L; $requestedOffset = 0L
          }
        }

        $remainingBytes = $Size - [long]$State.Received
        if ($resp.ContentLength -gt $remainingBytes) {
          throw "下载响应超过清单声明的剩余大小（剩余 $remainingBytes / 响应 $($resp.ContentLength) 字节）"
        }
        $State.Status = $(if ([long]$State.Received -gt 0) { '正在从中断位置继续下载…' } else { '正在下载更新…' })
        $inStream = $resp.GetResponseStream()
        while ([long]$State.Received -lt $Size) {
          if ($State.Cancel) { & $finish 'cancelled' '已取消下载'; break }
          $want = [int][Math]::Min([long]$buf.Length, $Size - [long]$State.Received)
          try { $n = $inStream.Read($buf, 0, $want) }
          catch { throw (New-BoosterRetryableDownloadException '更新包网络读取超时或连接中断' $_.Exception) }
          if ($n -le 0) {
            throw (New-BoosterRetryableDownloadException '下载连接提前结束' $null)
          }
          # 每次最多只请求清单剩余字节；仍在写入前再检查一次，永不让响应填满磁盘。
          if ($n -gt ($Size - [long]$State.Received)) { throw '下载内容超过清单声明的大小，已中止并删除' }
          $outStream.Write($buf, 0, $n)
          $State.Received = [long]$State.Received + $n
        }
      } catch {
        $retryError = $_.Exception
      } finally {
        try { if ($inStream) { $inStream.Close() } } catch {}
        try { if ($resp) { $resp.Close() } } catch {}
      }

      if ($State.Done) { break }
      if ($retryError) {
        if (-not (Test-BoosterRetryableDownloadException $retryError)) { throw $retryError }
        if ($State.Cancel) { & $finish 'cancelled' '已取消下载'; break }
        if ($attempt -ge $MaxAttempts) {
          throw "网络连接在下载过程中连续中断或超时（已自动尝试 $MaxAttempts 次）。请检查网络后重试，或改为打开下载页。"
        }
        $State.RetryCount = $attempt
        $State.Status = "网络短暂中断，正在断点续传（重试 $attempt/$($MaxAttempts - 1)）…"
        if (-not (Wait-BoosterDownloadRetry -State $State -DelayMs $RetryDelayMs)) {
          & $finish 'cancelled' '已取消下载'
          break
        }
      }
    }
    if ($State.Done) {
      $outStream.Close(); $outStream = $null
      try { Remove-Item -LiteralPath $stageInfo.Directory -Recurse -Force -ErrorAction SilentlyContinue } catch {}
      return
    }

    $outStream.Flush($true)
    if ([long]$State.Received -ne $Size -or $outStream.Length -ne $Size) {
      throw "文件大小不符（清单 $Size 字节 / 实际 $($outStream.Length) 字节）"
    }
    $outStream.Position = 0
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actualHash = ([BitConverter]::ToString($sha.ComputeHash($outStream))).Replace('-', '') }
    finally { $sha.Dispose() }
    if ($actualHash -ne "$Sha256".ToUpperInvariant()) { throw 'SHA256 校验不通过（文件可能在传输中被篡改）' }

    if ([bool]$stageInfo.Elevated) {
      $meta = [Text.Encoding]::ASCII.GetBytes("$($actualHash.ToUpperInvariant())`r`n$Size`r`n")
      $sideStream = [IO.FileStream]::new($sidecar, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
        [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
      $sideStream.Write($meta, 0, $meta.Length)
      $sideStream.Flush($true)
      Protect-BoosterStaging -Directory $stageInfo.Directory -Files @($tmpFile, $sidecar) -Elevated $true `
        -ReaderSid ([Security.Principal.WindowsIdentity]::GetCurrent().User)
      $sideStream.Close(); $sideStream = $null
      $outStream.Close(); $outStream = $null
    } else {
      # 父句柄仍打开且 share 只允许 Read：helper 校验/复制期间同 SID 进程也改不了或删不了源。
      $localStage = $stageInfo.Directory
      $secureFile = Copy-BoosterSetupToAdminStaging $tmpFile $Sha256 $Size
      $outStream.Close(); $outStream = $null
      try { Remove-Item -LiteralPath $localStage -Recurse -Force -ErrorAction Stop } catch {}
      $tmpFile = $secureFile
      $sidecar = "$tmpFile.integrity"
      $stageInfo = [pscustomobject]@{ Directory = Split-Path -Parent $tmpFile; Elevated = $true }
    }

    # 交付路径前再按路径复验一次；安装器进程启动第一行还会根据 sidecar/参数第三次复验。
    $chk = Test-BoosterFileIntegrity $tmpFile $Sha256 $Size
    if (-not $chk.Ok) { throw $chk.Reason }
    $State.File = $tmpFile
    & $finish 'done' ''
  } catch {
    try { if ($sideStream) { $sideStream.Close() } } catch {}
    try { if ($outStream) { $outStream.Close() } } catch {}
    try { if ($stageInfo -and (Test-Path -LiteralPath $stageInfo.Directory)) { Remove-Item -LiteralPath $stageInfo.Directory -Recurse -Force } } catch {}
    & $finish 'failed' "下载失败：$($_.Exception.Message)"
  } finally {
    if ($State.Phase -ne 'done' -and "$($State.QueueTicket)") {
      [void](Stop-BoosterDownloadQueueTicket -SetupUrl $SetupUrl -Ticket "$($State.QueueTicket)" `
        -TimeoutMs ([Math]::Max(500, [Math]::Min(3000, $TimeoutMs))))
      $State.QueueTicket = ''
    }
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
    $minimum = "$($m.minimumSupportedVersion)"
    $mandatory = [bool]($minimum -and (Compare-BoosterVersion $CurrentVersion $minimum) -lt 0)
    # 用户点过「不再提醒此版本」的就不再弹；出了更新的版本会重新提醒。
    # 手动检查（-IncludeSkipped）例外：用户主动点按钮就是想看结果，不该被跳过记录挡住
    if (-not $IncludeSkipped -and -not $mandatory) {
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
      DisplayVersion = $(if ("$($m.displayVersion)".Trim()) { "$($m.displayVersion)".Trim() } else { "$($m.version)" })
      Notes      = "$($m.notes)"
      Url        = "$($m.url)"
      Current    = "$CurrentVersion"
      SetupUrl   = $setupUrl
      Sha256     = $sha
      Size       = $size
      CanInline  = $canInline
      Mandatory  = $mandatory
      MinimumSupportedVersion = $minimum
      InlineDeny = $(if ($canInline) { '' } elseif (-not $urlVerdict.Allowed) { $urlVerdict.Reason } else { '清单缺少 SHA256 或文件大小，内置更新已禁用' })
    }
  } catch { $null }
}

# 仅供非提权 GUI 调起的管理员 helper 入口；正常 dot-source 本模块时开关为空，不执行。
if ($SecureStageHelper) {
  exit (Invoke-BoosterSecureStageHelper -Source $StageSource -Id $StageId -ReaderSid $StageReaderSid -Sha256 $StageSha256 -Size $StageSize)
}
