<#
  DeltaForceBooster 安装包构建脚本 — v0.9
  只用系统自带组件（Compress-Archive + .NET Framework csc），零第三方依赖，只产出一个东西：
    build\DeltaForceBooster-Setup-vX.Y.exe —— 图形安装向导（WPF，三角洲官网视觉）：
      欢迎/自选安装位置/进度/完成四页，payload.zip 以 /resource: 内嵌，真正单文件

  v0.9：发布文件改为严格白名单，额外 tools 文件直接阻止构建；每次强制重建带哈希校验
        的 asInvoker 启动器；payload 文件大小与 SHA256 清单作为独立资源嵌入安装器。
  v0.8：静默更新覆盖前关闭其余旧窗口，并为短暂文件共享冲突增加有限重试，修复
        gui\app.ico 偶发被占用导致安装中途失败。
  v0.7.2：profiles\ 不再进包——那里只有用户自存方案，v0.16.1 的安装包因此把构建者
        本机的方案发给了所有下载者。
  v0.7.1：版本号改以 $script:GuiVersion 为准并与界面徽标交叉校验（漏改一处就构建失败）；
        程序集四段版本号按位补齐，三段版本（0.16.1）不再拼出五段导致 csc 报错。
  v0.7：重写内嵌卸载脚本——①卸载前可先按备份还原系统改动（默认是）；②无条件清理
        PowerPlanLock 计划任务（SYSTEM 每分钟锁电源方案，残留后普通用户几乎停不掉）；
        ③保留备份时 scripts\ 一并保留（没有引擎的备份 JSON 谁也读不懂）；④完成提示
        如实交代还原了什么、系统里还剩什么。
  v0.6：不再产出绿色免安装版（用户决定只发安装版）；payload 里加入 DISCLAIMER.md——
        免责声明门控要读它，不随包分发的话装完就只剩内嵌兜底文本了。
  v0.5：构建完成后自动生成 build\update-manifest.json 清单模板（sha256/size 现算）——
        内置更新强制校验哈希，手工算迟早算错一次。

  用法：powershell -NoProfile -ExecutionPolicy Bypass -File build\make-installer.ps1
        （必须用 Windows PowerShell 5.1：WPF 程序集定位和 Compress-Archive 行为按 5.1 处理）

  发布须知（写给分发者，别粉饰）：
    1) 没有代码签名证书，Windows SmartScreen 会对 Setup.exe 弹「未知发布者」拦截页，
       用户需点「更多信息 → 仍要运行」。安装向导欢迎页也如实写了这一条。
    2) 本工具改注册表、禁系统服务，杀毒软件误报是常态，可能直接被隔离。
       两条的详细说明见 build\README.md。
#>
#requires -Version 5.1
param([switch]$TestBuild)
$ErrorActionPreference = 'Stop'

$root  = Split-Path -Parent $PSScriptRoot
$build = $PSScriptRoot

# 版本号以 $script:GuiVersion 为准：更新检查拿它跟服务器清单比版本，界面徽标只是显示。
# 两者曾经各写各的，漏改一处就会发出「版本号自称 0.16 的 0.16.1 包」，构建期直接卡住
$guiText = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'), [Text.Encoding]::UTF8)
if ($guiText -notmatch '\$script:GuiVersion\s*=\s*''([\d.]+)''') { throw '无法从 GUI 文件解析 $script:GuiVersion' }
$ver  = $Matches[1]
if ($guiText -notmatch '\[ v([\d.]+) \]') { throw '无法从 GUI 文件解析版本徽标' }
if ($Matches[1] -ne $ver) { throw "版本号不一致：`$script:GuiVersion=$ver 但徽标写的是 $($Matches[1])，先改成一致再构建" }
# 程序集版本号必须正好四段，多一段少一段 csc 都会报错
$seg  = @($ver -split '\.') + @('0', '0', '0', '0')
$ver4 = ($seg[0..3]) -join '.'

# ---------- 1. 收集要分发的文件 ----------
# tools 是第三方二进制风险最高的目录：只要出现白名单外文件或子目录，就让构建失败，
# 并且在生成任何新产物前就停止。
$allowedTools = @('PresentMon.exe', 'PresentMon-LICENSE.txt', 'DeltaForce-Recommended.nip')
$extraTools = @(Get-ChildItem -LiteralPath (Join-Path $root 'tools') -Force | Where-Object {
  $allowedTools -notcontains $_.Name
})
if ($extraTools.Count -gt 0) {
  throw "tools 目录含发布白名单外项目，构建已停止：$($extraTools.Name -join ', ')"
}

# 中间产物放 ASCII 路径的临时目录：仓库路径含「桌面」，非中文代码页（本机 ACP=1252）下
# 命令行工具处理中文路径容易翻车，成品最后再移回 build\。白名单检查通过后才创建，
# 这样额外 tools 项导致的预期失败也不会留下半成品目录。
$work  = Join-Path $env:TEMP "dfb-build-$PID"
$stage = Join-Path $work 'stage'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

# exe 启动器把关键发布文件的 SHA256 编进自身；因此不能复用上次产物，每次构建都重编。
$launcher = Join-Path $root '启动优化工具.exe'
$trustedPowerShell = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $trustedPowerShell -PathType Leaf)) { throw "未找到受信 PowerShell：$trustedPowerShell" }
& $trustedPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make-launcher.ps1')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
  throw "启动器现场编译失败（退出码 $LASTEXITCODE），先运行 build\make-launcher.ps1 排查"
}
# backup\ 是本机改动记录、build\ 是构建目录、config\ 是运行期状态，都不进包；
# profiles\ 同样不进包——内置三套方案定义在 Get-BuiltinPresets 里，profiles\ 只存
# 用户自存方案，打进包等于把构建者本机的方案发给每一个下载者（v0.16.1 已发生过）；
# .bat 保留为后备入口
# LICENSE 必须随包分发：MIT 要求保留版权声明，这不是可选项。
# DISCLAIMER.md 是免责声明门控的正文来源，NOTICE.md 是非官方声明与出处。
# SECURITY.md / CONTRIBUTING.md 是给仓库看的，不进安装包。目录不可整棵复制：本机构建者
# 放进 tools\ 的测试 EXE/DLL 曾可能被静默带进发布包，所以每个发布文件都在这里明确列出。
$payloadFiles = @(
  '启动优化工具.exe', '启动优化工具.bat', 'README.md', 'SKILL.md',
  'DISCLAIMER.md', 'LICENSE', 'NOTICE.md',
  'scripts\delta-booster.ps1', 'scripts\diagnose.ps1', 'scripts\updater.ps1',
  'scripts\telemetry-client.ps1', 'scripts\tuning-experiment.ps1',
  'gui\DeltaForceBooster-GUI.ps1', 'gui\app.ico',
  'tools\PresentMon.exe', 'tools\PresentMon-LICENSE.txt', 'tools\DeltaForce-Recommended.nip',
  'data\streamer-settings.json'
)

foreach ($rel in $payloadFiles) {
  $src = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "发布白名单文件缺失：$rel" }
  if ((Get-Item -LiteralPath $src -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "发布白名单文件是重解析点，构建已停止：$rel"
  }
  $dst = Join-Path $stage $rel
  $parent = Split-Path -Parent $dst
  if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Copy-Item -LiteralPath $src -Destination $dst
}

# 受保护安装身份：既证明目录属于本产品，也把本次启动器哈希绑定到安装根。后续覆盖、
# 卸载和启动都先复验该文件；它本身还会进入 payload 哈希清单。
$launcherSha = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash.ToUpperInvariant()
$installIdentity = "SchemaVersion=1`nProductId=DeltaForceBooster`nLauncherSha256=$launcherSha`n"
[IO.File]::WriteAllText((Join-Path $stage 'install.identity'), $installIdentity,
  (New-Object Text.UTF8Encoding($false)))

# 卸载脚本随包落到安装目录。
# 安装位置从 v0.3 起可自选，卸载目标以脚本自身所在目录为准，不再假定 %LOCALAPPDATA%。
# 全程不用 WScript.Shell：它按系统 ANSI 代码页转字符串，非中文代码页（如 1252）的系统上
# 中文全变 "?"。消息框走 .NET WinForms（原生 Unicode）。
$uninstallPs = @'
# DeltaForceBooster 卸载：①可选先按备份还原系统改动（卸载后工具就没了，这是最后机会）
# ②无条件清理 PowerPlanLock 计划任务（SYSTEM 每分钟重设电源方案，残留后没人能停）
# ③删快捷方式与完整程序目录；受保护备份位于 ProgramData，用户可选择保留供重装后还原
param([string]$UserSid, [string]$UserLocalAppData)
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
# 安装位置可自选，以脚本自身所在目录为卸载目标
$dest = Split-Path -Parent $MyInvocation.MyCommand.Path
$engine = Join-Path $dest 'scripts\delta-booster.ps1'
$launcher = Join-Path $dest '启动优化工具.exe'
$identity = Join-Path $dest 'install.identity'
$systemDir = [Environment]::SystemDirectory
$programData = [Environment]::GetFolderPath('CommonApplicationData')
$protectedRoot = Join-Path $programData 'DeltaForceBooster'
$protectedBackup = Join-Path $protectedRoot 'backup'
$legacyRoots = Join-Path $protectedRoot 'legacy-roots.json'
$psExe = Join-Path $systemDir 'WindowsPowerShell\v1.0\powershell.exe'
$schtasksExe = Join-Path $systemDir 'schtasks.exe'
$powercfgExe = Join-Path $systemDir 'powercfg.exe'
# 脚本被单独拷到别处运行时绝不能误删所在目录：严格绑定产品 marker 与启动器 SHA256。
$identityOk = $false
try {
  $lines = [IO.File]::ReadAllLines($identity, (New-Object Text.UTF8Encoding($false, $true)))
  if ($lines.Count -eq 3 -and $lines[0] -ceq 'SchemaVersion=1' -and
      $lines[1] -ceq 'ProductId=DeltaForceBooster' -and
      $lines[2] -cmatch '^LauncherSha256=([0-9A-Fa-f]{64})$' -and
      (Test-Path -LiteralPath $engine -PathType Leaf) -and (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    $identityOk = ((Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash -ieq $Matches[1])
  }
} catch {}
if (-not $identityOk) {
  [Windows.Forms.MessageBox]::Show('安装目录产品身份校验失败，卸载已取消。请从系统“已安装的应用”确认正确版本。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 1
}
function Test-ExactProtectedEntry([string]$Path, [bool]$Directory) {
  try {
    $sections = [Security.AccessControl.AccessControlSections]'Owner, Access'
    $acl = $(if ($Directory) { (New-Object IO.DirectoryInfo($Path)).GetAccessControl($sections) }
             else { (New-Object IO.FileInfo($Path)).GetAccessControl($sections) })
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin @('S-1-5-18','S-1-5-32-544') -or -not $acl.AreAccessRulesProtected) { return $false }
    $adminFull = $false; $systemFull = $false
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $sid = $rule.IdentityReference.Value
      if ($sid -notin @('S-1-5-18','S-1-5-32-544')) { return $false }
      if ($rule.AccessControlType -eq 'Allow' -and (($rule.FileSystemRights -band 'FullControl') -eq 'FullControl')) {
        if ($sid -eq 'S-1-5-18') { $systemFull = $true }
        if ($sid -eq 'S-1-5-32-544') { $adminFull = $true }
      }
    }
    ($adminFull -and $systemFull)
  } catch { $false }
}
function Test-ExactProtectedTree([string]$Path) {
  try {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        -not (Test-ExactProtectedEntry $Path ([bool]$item.PSIsContainer))) { return $false }
    if ($item.PSIsContainer) {
      foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)) {
        if (-not (Test-ExactProtectedTree $child.FullName)) { return $false }
      }
    }
    $true
  } catch { $false }
}
function Test-ProtectedProgramEntry([string]$Path, [bool]$Directory) {
  try {
    $sections = [Security.AccessControl.AccessControlSections]'Owner, Access'
    $acl = $(if ($Directory) { (New-Object IO.DirectoryInfo($Path)).GetAccessControl($sections) }
             else { (New-Object IO.FileInfo($Path)).GetAccessControl($sections) })
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin @('S-1-5-18','S-1-5-32-544') -or -not $acl.AreAccessRulesProtected) { return $false }
    $writeMask = [Security.AccessControl.FileSystemRights]'WriteData, AppendData, WriteExtendedAttributes, WriteAttributes, DeleteSubdirectoriesAndFiles, Delete, ChangePermissions, TakeOwnership'
    $adminFull = $false; $systemFull = $false
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $sid = $rule.IdentityReference.Value
      $rawRights = [int64]$rule.FileSystemRights
      $allowsWrite = (($rule.FileSystemRights -band $writeMask) -ne 0) -or (($rawRights -band 0x10000000) -ne 0) -or (($rawRights -band 0x40000000) -ne 0)
      if ($rule.AccessControlType -eq 'Allow' -and $sid -notin @('S-1-5-18','S-1-5-32-544') -and
          $allowsWrite) { return $false }
      if ($rule.AccessControlType -eq 'Allow' -and (($rule.FileSystemRights -band 'FullControl') -eq 'FullControl')) {
        if ($sid -eq 'S-1-5-18') { $systemFull = $true }
        if ($sid -eq 'S-1-5-32-544') { $adminFull = $true }
      }
    }
    ($adminFull -and $systemFull)
  } catch { $false }
}
function Test-ProtectedProgramTree([string]$Path) {
  try {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        -not (Test-ProtectedProgramEntry $Path ([bool]$item.PSIsContainer))) { return $false }
    if ($item.PSIsContainer) {
      foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)) {
        if (-not (Test-ProtectedProgramTree $child.FullName)) { return $false }
      }
    }
    $true
  } catch { $false }
}
function Ask-YesNo([string]$Msg) {
  ([Windows.Forms.MessageBox]::Show($Msg, 'DeltaForceBooster 卸载', 'YesNo', 'Question') -ne 'No')
}
# 还原改动、删 SYSTEM 计划任务和移除 Program Files 都需要管理员：非管理员整体提权重跑；
# 用户取消 UAC 时直接停止，绝不继续并误报卸载完成。
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $UserLocalAppData = [Environment]::GetFolderPath('LocalApplicationData')
  try {
    Start-Process $psExe -Verb RunAs -ErrorAction Stop -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($MyInvocation.MyCommand.Path)`"",
      '-UserSid', "`"$UserSid`"", '-UserLocalAppData', "`"$UserLocalAppData`"")
    exit
  } catch {
    [Windows.Forms.MessageBox]::Show('未获得管理员权限，卸载已取消；程序和备份均未删除。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
    exit 2
  }
}
if ([bool]$UserSid -ne [bool]$UserLocalAppData) {
  [Windows.Forms.MessageBox]::Show('卸载用户上下文参数不完整，已停止。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 2
}
if (-not $UserSid) {
  $UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $UserLocalAppData = [Environment]::GetFolderPath('LocalApplicationData')
}
if (-not (Test-ProtectedProgramTree $dest)) {
  [Windows.Forms.MessageBox]::Show('安装目录权限或重解析点状态异常，卸载已停止；未递归删除任何程序文件。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 1
}
# 安装器行为：非提权装用户开始菜单，提权装公共开始菜单——卸载把两处都兜住；
# 桌面快捷方式同理，全部使用系统 Known Folder。
$menuDirs = @(
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'DeltaForceBooster'),
  (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'DeltaForceBooster'))
$deskDirs = @([Environment]::GetFolderPath('DesktopDirectory'),
  [Environment]::GetFolderPath('CommonDesktopDirectory')) | Where-Object { $_ }
# ① 卸载前先还原系统改动（默认是）：有备份记录才问；$restoreDone 三态=成功/失败/没做
$restoreDone = $null
$hasBackup = [bool](@(
  Get-ChildItem (Join-Path $dest 'backup') -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue
  Get-ChildItem $protectedBackup -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue
  Get-Item $legacyRoots -ErrorAction SilentlyContinue
).Count)
if ($hasBackup) {
  if (Ask-YesNo "卸载前是否先还原本工具做过的系统改动？`n`n还没「还原设置」过的话请选「是」——卸载后工具就没了，这是最后一次自动还原的机会。") {
    $p = Start-Process $psExe -Wait -PassThru -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$engine`"", '-Restore',
      '-UserSid', "`"$UserSid`"", '-UserLocalAppData', "`"$UserLocalAppData`"")
    $restoreDone = ($p -and $p.ExitCode -eq 0)
  }
}
# ② 清理当前安装根对应的唯一任务名，并兼容旧固定名。哈希算法与引擎保持逐字一致。
$rootBytes = [Text.Encoding]::UTF8.GetBytes(([IO.Path]::GetFullPath($dest)).ToUpperInvariant())
$sha = [Security.Cryptography.SHA256]::Create()
try { $rootHash = $sha.ComputeHash($rootBytes) } finally { $sha.Dispose() }
$taskSuffix = (([BitConverter]::ToString($rootHash) -replace '-', '').Substring(0, 12))
$taskNames = @('DeltaForceBooster-PowerPlanLock', "DeltaForceBooster-PowerPlanLock-$taskSuffix")
$taskFound = $false; $taskDeleted = $false; $taskFailed = $false; $taskRejected = $false
$trustedPowerCfg = [IO.Path]::GetFullPath($powercfgExe)
$guidRx = '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'
foreach ($taskName in $taskNames) {
  $raw = & $schtasksExe /Query /TN $taskName /XML 2>&1
  if ($LASTEXITCODE -ne 0) { continue }
  $taskFound = $true
  try { $xml = [xml](@($raw) -join "`r`n") } catch { $xml = $null }
  $cmd = $(if ($xml) { $xml.SelectSingleNode("//*[local-name()='Exec']/*[local-name()='Command']") })
  $arg = $(if ($xml) { $xml.SelectSingleNode("//*[local-name()='Exec']/*[local-name()='Arguments']") })
  $cmdText = $(if ($cmd) { "$($cmd.InnerText)".Trim().Trim('"') } else { '' })
  $cmdOk = $false
  if ($cmdText) { try { $cmdOk = ([IO.Path]::GetFullPath($cmdText) -ieq $trustedPowerCfg) } catch {} }
  # 只有旧固定名兼容历史版本的 bare powercfg.exe；新哈希任务必须绑定 System32 绝对路径。
  if ($taskName -ceq 'DeltaForceBooster-PowerPlanLock' -and $cmdText -ieq 'powercfg.exe') { $cmdOk = $true }
  $argOk = [bool]($arg -and "$($arg.InnerText)".Trim() -match ("(?i)^/setactive\s+\{?$guidRx\}?$"))
  if (-not ($cmdOk -and $argOk)) { $taskRejected = $true; continue }
  & $schtasksExe /Delete /TN $taskName /F 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { $taskFailed = $true } else { $taskDeleted = $true }
}
$taskRemoved = $(if ($taskFailed) { $false } elseif ($taskDeleted) { $true } else { $null })
# ③ 是否保留受保护备份。程序根始终完整卸载；备份位于 ProgramData，重装后仍可还原。
$keep = $true
$keep = Ask-YesNo "是否保留优化备份？`n`n选「是」会保留 ProgramData 中受保护的备份；程序文件仍会完整卸载，之后重装本工具即可继续还原。"
function Remove-TreeNoFollow([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    return
  }
  if (-not $item.PSIsContainer) { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop; return }
  foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)) { Remove-TreeNoFollow $child.FullName }
  Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
}
foreach ($m in $menuDirs) { if (Test-Path $m) { Remove-TreeNoFollow $m } }
foreach ($d in $deskDirs) {
  $lnk = Join-Path $d '三角洲行动优化助手.lnk'
  if (Test-Path $lnk) { Remove-Item $lnk -Force }
}
$backupDeleteFailed = $false
if (-not $keep -and (Test-Path -LiteralPath $protectedBackup)) {
  $expectedBackup = [IO.Path]::GetFullPath((Join-Path $protectedRoot 'backup'))
  if ([IO.Path]::GetFullPath($protectedBackup) -ieq $expectedBackup) {
    if ((Test-ExactProtectedEntry $protectedRoot $true) -and (Test-ExactProtectedTree $protectedBackup)) {
      try { Remove-TreeNoFollow $protectedBackup } catch { $backupDeleteFailed = $true }
    } else { $backupDeleteFailed = $true }
  }
}
$programRemoved = $true
if (Test-Path -LiteralPath $dest) {
  try { Remove-TreeNoFollow $dest } catch { $programRemoved = $false }
  if (Test-Path -LiteralPath $dest) { $programRemoved = $false }
}
# ④ 完成提示如实交代：还原没还原、任务删没删、系统里还剩什么、之后怎么还原
$sum = @($(if ($programRemoved) { '卸载完成。' } else { '卸载未完整完成：部分程序文件仍被占用或删除失败。' }), '')
$sum += $(if ($restoreDone -eq $true) { '· 系统改动已按备份还原。' }
          elseif ($restoreDone -eq $false) { '· 还原未成功完成，部分系统改动可能仍留在系统里。' }
          elseif ($hasBackup) { '· 未执行还原：电源方案、休眠、系统服务等已做过的改动仍留在系统里。' }
          else { '· 未发现备份记录，未执行还原。' })
if ($taskRemoved -eq $true) { $sum += '· 电源方案锁定计划任务已删除。' }
elseif ($taskRemoved -eq $false) { $sum += '· 电源方案锁定计划任务删除失败，请在「任务计划程序」中手动删除 DeltaForceBooster-PowerPlanLock。' }
if ($taskRejected) { $sum += '· 检测到同名计划任务，但执行内容不属于本工具，已原样保留。' }
if ($keep -and $hasBackup) {
  $sum += "· 已保留受保护备份：$protectedBackup"
  $sum += '  重新安装本工具后仍可点击「还原设置」读取这些备份。'
} elseif (-not $keep) {
  $sum += $(if ($backupDeleteFailed) { '· ProgramData 受保护备份清理失败，已原样保留。' }
            else { '· 已按选择清理 ProgramData 中的受保护备份；旧版用户目录未做提权递归删除。' })
}
[Windows.Forms.MessageBox]::Show(($sum -join "`n"), 'DeltaForceBooster', 'OK', 'Information') | Out-Null
'@
$uninstallBat = @"
@echo off
rem Compatibility entry only; the protected helper resolves PowerShell from System32 via .NET.
start "" "%~dp0卸载.exe"
exit
"@
$enc = New-Object Text.UTF8Encoding($true)
$uninstallTokens = $null; $uninstallErrors = $null
[void][Management.Automation.Language.Parser]::ParseInput($uninstallPs, [ref]$uninstallTokens, [ref]$uninstallErrors)
if ($uninstallErrors.Count -gt 0) {
  throw "内嵌卸载脚本语法错误：$(@($uninstallErrors | ForEach-Object Message) -join '; ')"
}
[IO.File]::WriteAllText((Join-Path $stage 'uninstall.ps1'), $uninstallPs, $enc)
# bat 用 ANSI：cmd 不识别 UTF-8 BOM，中文注释改成 ASCII 保平安
[IO.File]::WriteAllText((Join-Path $stage '卸载.bat'), $uninstallBat, [Text.Encoding]::Default)

# 卸载入口不能裸调 powershell.exe 或信任 %SystemRoot%/PATH。小型 asInvoker helper 只从
# Environment.SpecialFolder.System 解析受信宿主，再执行同目录受 payload 校验的脚本。
$uninstallLauncherCs = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
static class UninstallLauncher {
  [STAThread] static void Main() {
    try {
      string root = AppDomain.CurrentDomain.BaseDirectory;
      string script = Path.Combine(root, "uninstall.ps1");
      string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
      string powershell = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
      if (!File.Exists(script) || !File.Exists(powershell)) throw new FileNotFoundException("卸载组件不完整");
      Process.Start(new ProcessStartInfo {
        FileName = powershell,
        Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"",
        WorkingDirectory = root, UseShellExecute = true, WindowStyle = ProcessWindowStyle.Hidden
      });
    } catch (Exception ex) {
      MessageBox.Show("卸载程序启动失败：" + ex.Message, "DeltaForceBooster 卸载", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
  }
}
'@
$uninstallCsFile = Join-Path $work 'uninstall-launcher.cs'
[IO.File]::WriteAllText($uninstallCsFile, $uninstallLauncherCs, $enc)
$windowsDirEarly = Split-Path -Parent ([Environment]::SystemDirectory)
$uninstallCsc = Join-Path $windowsDirEarly 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $uninstallCsc)) { $uninstallCsc = Join-Path $windowsDirEarly 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $uninstallCsc)) { throw '本机没有受信 .NET Framework csc.exe，无法编译卸载入口' }
& $uninstallCsc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 `
  /out:"$(Join-Path $stage '卸载.exe')" /r:System.Windows.Forms.dll "$uninstallCsFile"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $stage '卸载.exe'))) {
  throw "卸载入口编译失败（退出码 $LASTEXITCODE）"
}

# ---------- 2. 压 payload ----------
# 先对最终 stage 做“恰好等于白名单”的断言，再生成独立嵌入的哈希清单。安装器会按该清单
# 拒绝未知 ZIP 条目，并在原子切换前复验每个文件的大小与 SHA256。
$expectedStage = @($payloadFiles + @('install.identity', 'uninstall.ps1', '卸载.bat', '卸载.exe')) | ForEach-Object { $_.Replace('/', '\') }
$actualStage = @(Get-ChildItem -LiteralPath $stage -Recurse -File -Force | ForEach-Object {
  $_.FullName.Substring($stage.Length + 1).Replace('/', '\')
})
$missingStage = @($expectedStage | Where-Object { $actualStage -notcontains $_ })
$extraStage = @($actualStage | Where-Object { $expectedStage -notcontains $_ })
if ($missingStage.Count -gt 0 -or $extraStage.Count -gt 0) {
  throw "payload 白名单不一致；缺失=[$($missingStage -join ', ')]；额外=[$($extraStage -join ', ')]"
}

$payloadManifest = Join-Path $work 'payload-manifest.txt'
$manifestLines = foreach ($rel in ($actualStage | Sort-Object)) {
  $p = Join-Path $stage $rel
  $hash = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant()
  $size = (Get-Item -LiteralPath $p).Length
  $name64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($rel))
  "$hash|$size|$name64"
}
[IO.File]::WriteAllLines($payloadManifest, $manifestLines, (New-Object Text.UTF8Encoding($false)))

$payload = Join-Path $work 'payload.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $payload -Force

# ---------- 3. 生成安装器图标（与 make-launcher.ps1 同一枚三角 Logo、同一套手写 ICO 逻辑） ----------
# 不用 Icon.FromHandle(...).Save()：句柄图标序列化在部分系统上产出损坏文件，手写格式最稳
Add-Type -AssemblyName System.Drawing
$side = 48
$bmp = New-Object Drawing.Bitmap $side, $side, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::FromArgb(255, 13, 20, 23))
$pts = @(
  (New-Object Drawing.PointF 24.0, 6.0), (New-Object Drawing.PointF 45.6, 42.0),
  (New-Object Drawing.PointF 31.2, 42.0), (New-Object Drawing.PointF 24.0, 27.6),
  (New-Object Drawing.PointF 16.8, 42.0), (New-Object Drawing.PointF 2.4, 42.0)
)
$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 0, 232, 132))
$g.FillPolygon($brush, $pts)
$g.Dispose()

$rect = New-Object Drawing.Rectangle 0, 0, $side, $side
$bd = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pixels = New-Object byte[] ($side * $side * 4)
[Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $pixels, 0, $pixels.Length)
$bmp.UnlockBits($bd)
$bmp.Dispose()

$xorSize = $side * $side * 4
$andRow  = [int]([math]::Ceiling($side / 32.0) * 4)
$andSize = $andRow * $side
$bmpSize = 40 + $xorSize + $andSize
$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
$bw.Write([byte]$side); $bw.Write([byte]$side); $bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$bmpSize); $bw.Write([uint32]22)
$bw.Write([uint32]40); $bw.Write([int]$side); $bw.Write([int]($side * 2))
$bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0); $bw.Write([uint32]($xorSize + $andSize))
$bw.Write([int]0); $bw.Write([int]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
for ($y = $side - 1; $y -ge 0; $y--) { $bw.Write($pixels, $y * $side * 4, $side * 4) }
$bw.Write((New-Object byte[] $andSize))
$bw.Flush()
$icoFile = Join-Path $work 'setup.ico'
[IO.File]::WriteAllBytes($icoFile, $ms.ToArray())
$bw.Close()

# ---------- 4. asInvoker 清单：先显示向导，写入默认 Program Files 时再按需提权重启 ----------
$manifest = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
'@
$manifestFile = Join-Path $work 'setup.manifest'
[IO.File]::WriteAllText($manifestFile, $manifest, (New-Object Text.UTF8Encoding($false)))

# ---------- 5. 编译安装向导（源码在 build\setup-wizard.cs，版本号编译期注入） ----------
$windowsDir = Split-Path -Parent ([Environment]::SystemDirectory)
$csc = Join-Path $windowsDir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $windowsDir 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw '本机没有 .NET Framework csc.exe，无法编译安装向导' }

$csSrc = [IO.File]::ReadAllText((Join-Path $build 'setup-wizard.cs'), [Text.Encoding]::UTF8)
$csSrc = $csSrc.Replace('__VER4__', $ver4).Replace('__VER__', $ver)
$csFile = Join-Path $work 'setup-wizard.cs'
# UTF-8 BOM + /codepage:65001 双保险：csc 默认按当前代码页读源文件（本机 ACP=1252），
# 缺了任何一个中文字符串都会在编译期被打碎
[IO.File]::WriteAllText($csFile, $csSrc, $enc)

# WPF/压缩程序集不在 Framework 目录里，只能从 GAC 按强名定位真实路径给 /r:
# （System.Windows.Forms 不在此列：csc 默认 csc.rsp 已引用，重复给会报 CS1703）
function Resolve-GacRef([string]$name) {
  $asm = [Reflection.Assembly]::LoadWithPartialName($name)
  if (-not $asm) { throw "无法在 GAC 定位程序集：$name" }
  $asm.Location
}
$refNames = @('PresentationFramework', 'PresentationCore', 'WindowsBase', 'System.Xaml',
              'System.IO.Compression', 'System.IO.Compression.FileSystem')
$refArgs = $refNames | ForEach-Object { "/r:$(Resolve-GacRef $_)" }

$setupFileName = $(if ($TestBuild) { "DeltaForceBooster-Setup-v$ver-TEST.exe" } else { "DeltaForceBooster-Setup-v$ver.exe" })
$setupTmp = Join-Path $work $setupFileName
$defineArgs = @($(if ($TestBuild) { '/define:DFB_TESTING' }))
& $csc /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 `
  /out:"$setupTmp" /win32icon:"$icoFile" /win32manifest:"$manifestFile" `
  /resource:"$payload,DFB.Payload" /resource:"$payloadManifest,DFB.PayloadManifest" @refArgs @defineArgs "$csFile"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $setupTmp)) { throw "csc 编译安装向导失败（退出码 $LASTEXITCODE）" }

# ---------- 6. 成品落位 ----------
# payload.zip 只作为安装器的内嵌资源存在，不再单独输出成发布物
$setupOutTmp = Join-Path $build (Split-Path -Leaf $setupTmp)
if (Test-Path $setupOutTmp) { Remove-Item $setupOutTmp -Force }
Move-Item $setupTmp $setupOutTmp
Remove-Item $work -Recurse -Force

if ($TestBuild) {
  "测试构建完成（仅非提权临时目录支持 DFB_TEST_*）：$setupOutTmp"
  return
}

# ---------- 7. 更新清单（配合内置更新） ----------
# sha256/size 直接从刚构建的 Setup.exe 现算：客户端下载后强制校验这两个字段，
# 手工计算迟早抄错一次哈希。公开更新说明也在构建时固定生成，避免发布时漏改占位符。
# setupUrl 固定指向服务器上的无版本号文件名（发布即覆盖），域名必须保持在
# scripts\updater.ps1 的白名单内，否则老客户端会拒绝下载。
$setupOut = Join-Path $build "DeltaForceBooster-Setup-v$ver.exe"
$manifestOut = Join-Path $build 'update-manifest.json'
$manifestNotes = @(
  '新增「自动寻找最佳配置 Beta」：三次基线、低风险 A/B 交替测试、定向回滚和最终安全复核。'
  '修复安装更新、备份还原、权限边界、多显卡识别、性能采样与诊断历史等已知问题。'
  '本版要求升级，官网仅提供 v0.20.0 最新安装包。'
) -join "`n"
$manifestObj = [ordered]@{
  # 与 $script:GuiVersion 逐字一致：客户端拿自身版本跟这里比大小，补位只会让
  # 「已是最新」和「有新版本」的判定跟着版本号写法漂
  version  = "$ver"
  # 旧版存在必须淘汰的问题；支持该字段的客户端低于本版时不允许跳过。
  minimumSupportedVersion = '0.20.0'
  notes    = $manifestNotes
  url      = 'https://df.ltz88.cn/'
  setupUrl = 'https://df.ltz88.cn/DeltaForceBooster-Setup.exe'
  sha256   = (Get-FileHash -LiteralPath $setupOut -Algorithm SHA256).Hash.ToLowerInvariant()
  size     = (Get-Item -LiteralPath $setupOut).Length
}
# 不带 BOM：服务器上的清单由 .NET/浏览器直接消费，带 BOM 的 JSON 部分解析器会噎住
[IO.File]::WriteAllText($manifestOut, ($manifestObj | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))

"构建完成（v$ver）："
Get-ChildItem $build -File -Filter '*.exe' |
  ForEach-Object { "  {0}  ({1:N0} KB)" -f $_.Name, ($_.Length / 1KB) }
"  update-manifest.json  已生成（sha256/size 与公开更新说明均取自本次发布）"
