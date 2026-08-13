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

# 构建顺序固定为 final icon/scripts → EngineHost → launcher。EngineHost 固化脚本/icon
# 哈希，launcher 再固化 EngineHost 与同一 payload 哈希；clean tree 也能一次完成。
$launcher = Join-Path $root '启动优化工具.exe'
$engineHost = Join-Path $root 'EngineHost.exe'
$trustedPowerShell = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $trustedPowerShell -PathType Leaf)) { throw "未找到受信 PowerShell：$trustedPowerShell" }
& $trustedPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'make-engine-host.ps1')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $engineHost -PathType Leaf)) {
  throw "EngineHost 现场编译失败（退出码 $LASTEXITCODE），先运行 build\make-engine-host.ps1 排查"
}
$launcherBuildArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'make-launcher.ps1'))
if ($TestBuild) { $launcherBuildArgs += '-TestBuild' }
& $trustedPowerShell @launcherBuildArgs
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
  '启动优化工具.exe', 'EngineHost.exe', '启动优化工具.bat', 'README.md', 'SKILL.md',
  'DISCLAIMER.md', 'LICENSE', 'NOTICE.md',
  'scripts\delta-booster.ps1', 'scripts\diagnose.ps1', 'scripts\updater.ps1',
  'scripts\telemetry-client.ps1', 'scripts\tuning-experiment.ps1', 'scripts\user-context-worker.ps1',
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
$engineHostSha = (Get-FileHash -LiteralPath $engineHost -Algorithm SHA256).Hash.ToUpperInvariant()
$installIdentity = "SchemaVersion=2`nProductId=DeltaForceBooster`nLauncherSha256=$launcherSha`nEngineHostSha256=$engineHostSha`n"
[IO.File]::WriteAllText((Join-Path $stage 'install.identity'), $installIdentity,
  (New-Object Text.UTF8Encoding($false)))

# 卸载脚本随包落到安装目录。
# 安装位置从 v0.3 起可自选，卸载目标以脚本自身所在目录为准，不再假定 %LOCALAPPDATA%。
# 全程不用 WScript.Shell：它按系统 ANSI 代码页转字符串，非中文代码页（如 1252）的系统上
# 中文全变 "?"。消息框走 .NET WinForms（原生 Unicode）。
$uninstallPs = @'
# DeltaForceBooster 卸载：①可选先按备份还原系统改动；跳过或失败时仍永久保留备份
# ②无条件清理 PowerPlanLock 计划任务（SYSTEM 每分钟重设电源方案，残留后没人能停）
# ③删快捷方式与完整程序目录；受保护备份位于 ProgramData，普通卸载始终保留供重装后还原
param(
  [Parameter(Mandatory)][string]$InstallRoot,
  [Parameter(Mandatory)][string]$UserSid,
  [Parameter(Mandatory)][string]$UserLocalAppData,
  [int]$WaitPid = 0,
  [int]$WaitPid2 = 0,
  [string]$StageRoot
)
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
# 脚本由 UninstallHost 复制到受保护 ProgramData 后运行，不能再以脚本目录为卸载目标。
$dest = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
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
function Wait-VerifiedProcessExit([int]$Id) {
  if ($Id -le 0) { return $true }
  try {
    $process = [Diagnostics.Process]::GetProcessById($Id)
    try { return $process.WaitForExit(30000) } finally { $process.Dispose() }
  } catch [ArgumentException] { return $true }
  catch { return $false }
}
if (-not (Wait-VerifiedProcessExit $WaitPid) -or
    ($WaitPid2 -ne $WaitPid -and -not (Wait-VerifiedProcessExit $WaitPid2))) {
  [Windows.Forms.MessageBox]::Show('卸载助手未能安全退出旧进程，卸载已停止；程序与备份均未删除。',
    'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 3
}
# 脚本被单独拷到别处运行时绝不能误删所在目录：严格绑定产品 marker 与启动器 SHA256。
function Test-InstallIdentity([string]$Root) {
  try {
    $marker = Join-Path $Root 'install.identity'
    $candidateLauncher = Join-Path $Root '启动优化工具.exe'
    $candidateHost = Join-Path $Root 'EngineHost.exe'
    $candidateEngine = Join-Path $Root 'scripts\delta-booster.ps1'
    $lines = [IO.File]::ReadAllLines($marker, (New-Object Text.UTF8Encoding($false, $true)))
    $v1 = ($lines.Count -eq 3 -and $lines[0] -ceq 'SchemaVersion=1')
    $v2 = ($lines.Count -eq 4 -and $lines[0] -ceq 'SchemaVersion=2')
    $launcherMatch = [Text.RegularExpressions.Regex]::Match($(if ($lines.Count -gt 2) { $lines[2] } else { '' }),
      '^LauncherSha256=([0-9A-Fa-f]{64})$')
    if ((-not $v1 -and -not $v2) -or $lines[1] -cne 'ProductId=DeltaForceBooster' -or
        -not $launcherMatch.Success -or
        -not (Test-Path -LiteralPath $candidateEngine -PathType Leaf) -or
        -not (Test-Path -LiteralPath $candidateLauncher -PathType Leaf)) { return $false }
    if ((Get-FileHash -LiteralPath $candidateLauncher -Algorithm SHA256).Hash -ine $launcherMatch.Groups[1].Value) { return $false }
    if ($v2) {
      $hostMatch = [Text.RegularExpressions.Regex]::Match($lines[3], '^EngineHostSha256=([0-9A-Fa-f]{64})$')
      if (-not $hostMatch.Success -or -not (Test-Path -LiteralPath $candidateHost -PathType Leaf) -or
          (Get-FileHash -LiteralPath $candidateHost -Algorithm SHA256).Hash -ine $hostMatch.Groups[1].Value) { return $false }
    }
    $true
  } catch { $false }
}
$identityOk = Test-InstallIdentity $dest
if (-not $identityOk) {
  [Windows.Forms.MessageBox]::Show('安装目录产品身份校验失败，卸载已取消。请从系统“已安装的应用”确认正确版本。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 1
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
if (-not ('Dfb.AnchorLabel' -as [type])) {
  Add-Type -Namespace Dfb -Name AnchorLabel -MemberDefinition @"
    [System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode, SetLastError=true, EntryPoint="GetNamedSecurityInfoW")]
    static extern uint GetNamedSecurityInfo(string name, int type, uint info, out System.IntPtr owner, out System.IntPtr group, out System.IntPtr dacl, out System.IntPtr sacl, out System.IntPtr descriptor);
    [System.Runtime.InteropServices.DllImport("advapi32.dll", CharSet=System.Runtime.InteropServices.CharSet.Unicode, SetLastError=true, EntryPoint="ConvertSecurityDescriptorToStringSecurityDescriptorW")]
    [return: System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.Bool)]
    static extern bool ConvertSecurityDescriptorToStringSecurityDescriptor(System.IntPtr descriptor, uint revision, uint info, out System.IntPtr text, out uint length);
    [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError=true)]
    static extern System.IntPtr LocalFree(System.IntPtr memory);
    public static string Read(string path) {
      const uint LabelInfo = 0x10; System.IntPtr o,g,d,s,sd;
      uint result = GetNamedSecurityInfo(path, 1, LabelInfo, out o, out g, out d, out s, out sd);
      if (result != 0) throw new System.ComponentModel.Win32Exception((int)result);
      try {
        System.IntPtr text; uint length;
        if (!ConvertSecurityDescriptorToStringSecurityDescriptor(sd, 1, LabelInfo, out text, out length))
          throw new System.ComponentModel.Win32Exception(System.Runtime.InteropServices.Marshal.GetLastWin32Error());
        try { return System.Runtime.InteropServices.Marshal.PtrToStringUni(text); }
        finally { if (text != System.IntPtr.Zero) LocalFree(text); }
      } finally { if (sd != System.IntPtr.Zero) LocalFree(sd); }
    }
"@
}
function Test-SafeCustomVolumeRoot([string]$Root) {
  try {
    $item = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
    $acl = (New-Object IO.DirectoryInfo($Root)).GetAccessControl(
      [Security.AccessControl.AccessControlSections]'Owner, Access')
    $trusted = @('S-1-5-18','S-1-5-32-544','S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $trusted) { return $false }
    $replaceChildMask = [int64]0x40 -bor [int64]0x40000 -bor [int64]0x80000
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $raw = [int64]$rule.FileSystemRights
      if ($rule.AccessControlType -eq 'Allow' -and
          ($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -eq 0 -and
          $rule.IdentityReference.Value -notin $trusted -and
          ((($raw -band $replaceChildMask) -ne 0) -or (($raw -band 0x10000000) -ne 0))) { return $false }
    }
    $true
  } catch { $false }
}
function Test-ExactCustomAnchorAcl([string]$Anchor) {
  try {
    $acl = (New-Object IO.DirectoryInfo($Anchor)).GetAccessControl(
      [Security.AccessControl.AccessControlSections]'Owner, Access')
    if (-not $acl.AreAccessRulesProtected -or
        $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin @('S-1-5-18','S-1-5-32-544')) { return $false }
    $admin = $false; $system = $false; $users = $false; $count = 0
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      $count++
      if ($rule.AccessControlType -ne 'Allow' -or $rule.IsInherited -or
          $rule.InheritanceFlags -ne ([Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit') -or
          $rule.PropagationFlags -ne [Security.AccessControl.PropagationFlags]::None) { return $false }
      $sid = $rule.IdentityReference.Value
      if ($sid -eq 'S-1-5-32-544' -and $rule.FileSystemRights -eq [Security.AccessControl.FileSystemRights]::FullControl) { $admin = $true }
      elseif ($sid -eq 'S-1-5-18' -and $rule.FileSystemRights -eq [Security.AccessControl.FileSystemRights]::FullControl) { $system = $true }
      elseif ($sid -eq 'S-1-5-32-545' -and $rule.FileSystemRights -eq
          ([Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [Security.AccessControl.FileSystemRights]::Synchronize)) { $users = $true }
      else { return $false }
    }
    ($count -eq 3 -and $admin -and $system -and $users)
  } catch { $false }
}
function Test-CustomAnchor([string]$Anchor, [string]$CodeRoot) {
  try {
    $fullAnchor = [IO.Path]::GetFullPath($Anchor).TrimEnd('\')
    $fullCode = [IO.Path]::GetFullPath($CodeRoot).TrimEnd('\')
    $driveRoot = [IO.Path]::GetPathRoot($fullAnchor)
    if ((Split-Path $fullAnchor -Parent).TrimEnd('\') -ine $driveRoot.TrimEnd('\') -or
        (Split-Path $fullCode -Leaf) -ine 'app' -or (Split-Path $fullCode -Parent).TrimEnd('\') -ine $fullAnchor) { return $false }
    $drive = [IO.DriveInfo]::new($driveRoot)
    if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady -or $drive.DriveFormat -ine 'NTFS' -or
        -not (Test-SafeCustomVolumeRoot $driveRoot)) { return $false }
    foreach ($path in $fullAnchor,(Join-Path $fullAnchor 'anchor.identity'),$fullCode) {
      $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    }
    if (-not (Test-ExactCustomAnchorAcl $fullAnchor) -or
        -not (Test-ProtectedProgramEntry (Join-Path $fullAnchor 'anchor.identity') $false)) { return $false }
    $sddl = [Dfb.AnchorLabel]::Read($fullAnchor)
    if ($sddl -notmatch '\(ML;(?=[^;]*OI)(?=[^;]*CI)[^;]*;(?=[^;]*NW)[^;]*;;;HI\)') { return $false }
    $lines = [IO.File]::ReadAllLines((Join-Path $fullAnchor 'anchor.identity'),
      (New-Object Text.UTF8Encoding($false, $true)))
    ($lines.Count -eq 6 -and $lines[0] -ceq 'SchemaVersion=1' -and
      $lines[1] -ceq 'ProductId=DeltaForceBooster' -and $lines[2] -ceq 'Layout=PermanentAnchor' -and
      $lines[3] -ceq 'CodeDirectory=app' -and $lines[4] -cmatch '^AnchorId=[0-9a-f]{32}$' -and
      $lines[5] -ceq 'AnchorNeverDelete=1')
  } catch { $false }
}
$customAnchor = $null
$possibleAnchor = Split-Path $dest -Parent
$possibleDrive = [IO.Path]::GetPathRoot($dest)
if ((Split-Path $dest -Leaf) -ieq 'app' -and $possibleAnchor -and
    (Split-Path $possibleAnchor -Parent).TrimEnd('\') -ieq $possibleDrive.TrimEnd('\')) {
  if (-not (Test-CustomAnchor $possibleAnchor $dest)) {
    [Windows.Forms.MessageBox]::Show('其他盘安装锚点身份、权限或完整性标签校验失败，卸载已停止；未删除任何程序文件。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
    exit 1
  }
  $customAnchor = [IO.Path]::GetFullPath($possibleAnchor).TrimEnd('\')
}
function Ask-YesNo([string]$Msg) {
  ([Windows.Forms.MessageBox]::Show($Msg, 'DeltaForceBooster 卸载', 'YesNo', 'Question') -ne 'No')
}
# UAC 只由带产品版本资源的 UninstallHost.exe 触发；这里继承其 high token，
# 不再从 PowerShell 自己 RunAs，避免第二次 UAC 和“Windows PowerShell”提示。
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  [Windows.Forms.MessageBox]::Show('未获得 UninstallHost 管理员会话，卸载已停止。',
    'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 2
}
if (-not $UserSid -or -not $UserLocalAppData -or
    $UserSid -notmatch '^S-1-[0-9-]{3,184}$' -or -not [IO.Path]::IsPathRooted($UserLocalAppData)) {
  [Windows.Forms.MessageBox]::Show('卸载用户上下文参数不完整，已停止。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 2
}
if (-not (Test-ProtectedProgramTree $dest)) {
  [Windows.Forms.MessageBox]::Show('安装目录权限或重解析点状态异常，卸载已停止；未递归删除任何程序文件。', 'DeltaForceBooster 卸载', 'OK', 'Warning') | Out-Null
  exit 1
}
# 原交互用户的 per-user 快捷方式由 asInvoker 卸载入口按原 token 清理；high 脚本
# 只处理公共快捷方式，不以批准管理员的 Known Folder 冒充原用户。
$menuDirs = @((Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'DeltaForceBooster'))
$deskDirs = @([Environment]::GetFolderPath('CommonDesktopDirectory')) | Where-Object { $_ }
# ① 卸载前先还原系统改动（默认是）：有备份记录才问；$restoreDone 三态=成功/失败/没做
$restoreDone = $null
$hasBackup = [bool](@(
  Get-ChildItem (Join-Path $dest 'backup') -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue
  Get-ChildItem $protectedBackup -Filter 'backup-*.json' -File -ErrorAction SilentlyContinue
  Get-Item $legacyRoots -ErrorAction SilentlyContinue
).Count)
if ($hasBackup) {
  if (Ask-YesNo "卸载前是否先还原本工具做过的系统改动？`n`n建议选择「是」。如果暂不还原，受保护备份仍会保留，之后重新安装本工具也可继续还原。") {
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
# ③ 普通卸载始终保留受保护备份。还原成功、失败或用户跳过还原都不得删除：
# 它是精确回到优化前状态的唯一凭据，而且 ProgramData 备份区可能同时包含其他 Windows
# 用户的备份。需要彻底清理时，应在确认所有用户均已成功还原后由管理员单独处理。
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
foreach ($m in $menuDirs) {
  if (-not (Test-Path -LiteralPath $m -PathType Container)) { continue }
  $menuItem = Get-Item -LiteralPath $m -Force
  if (($menuItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
  foreach ($name in '三角洲行动优化助手.lnk','卸载优化助手.lnk') {
    $lnk = Join-Path $m $name
    if (Test-Path -LiteralPath $lnk -PathType Leaf) { Remove-Item -LiteralPath $lnk -Force }
  }
  if (@(Get-ChildItem -LiteralPath $m -Force).Count -eq 0) { Remove-Item -LiteralPath $m -Force }
}
foreach ($d in $deskDirs) {
  $lnk = Join-Path $d '三角洲行动优化助手.lnk'
  if (Test-Path $lnk) { Remove-Item $lnk -Force }
}
$customTransactionsRemoved = 0; $customTransactionsPreserved = 0
if ($customAnchor) {
  foreach ($candidate in @(Get-ChildItem -LiteralPath $customAnchor -Force -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -cmatch '^\.app\.dfb-(stage|rollback)-[0-9a-f]{32}$' })) {
    # Only a complete product tree with its launcher-bound install.identity belongs to us.  A
    # same-looking but incomplete/reparse/foreign directory is evidence, not garbage: retain it.
    if ((Test-InstallIdentity $candidate.FullName) -and (Test-ProtectedProgramTree $candidate.FullName)) {
      try { Remove-TreeNoFollow $candidate.FullName; $customTransactionsRemoved++ }
      catch { $customTransactionsPreserved++ }
    } else { $customTransactionsPreserved++ }
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
if ($hasBackup) {
  $sum += "· 已保留受保护备份：$protectedBackup"
  $sum += '  重新安装本工具后仍可点击「还原设置」读取这些备份。'
}
if ($customAnchor) {
  $sum += "· 已保留其他盘永久安装锚点：$customAnchor"
  if ($customTransactionsRemoved) { $sum += "· 已清理 $customTransactionsRemoved 个经过身份复验的更新事务目录。" }
  if ($customTransactionsPreserved) { $sum += "· 有 $customTransactionsPreserved 个事务名目录未通过完整身份复验，已原样保留。" }
  $sum += '  anchor.identity 与任何未知文件均未删除；重装时可复用该受保护位置。'
}
[Windows.Forms.MessageBox]::Show(($sum -join "`n"), 'DeltaForceBooster', 'OK', 'Information') | Out-Null
if ($StageRoot) {
  try {
    $stageFull = [IO.Path]::GetFullPath($StageRoot).TrimEnd('\')
    $trustedParent = Join-Path $programData 'DeltaForceBooster\uninstall-stage'
    if ((Split-Path $stageFull -Parent) -ieq $trustedParent -and
        (Split-Path $stageFull -Leaf) -match '^[0-9a-f]{32}$') {
      Remove-Item -LiteralPath $stageFull -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}
'@
$uninstallBat = @"
@echo off
rem Compatibility entry only; the asInvoker helper starts the product UninstallHost UAC boundary.
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

# asInvoker 卸载入口只负责保留原交互用户 token；唯一 UAC 由带产品版本资源的
# requireAdministrator UninstallHost.exe 触发。Host 把受哈希绑定的脚本复制到受保护
# ProgramData 后，以 System32 为 CWD 等待两个根目录进程退出，再执行删除。
$uninstallBuildArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',
  (Join-Path $PSScriptRoot 'make-uninstall-host.ps1'), '-StageDirectory', $stage, '-Version', $ver)
if ($TestBuild) { $uninstallBuildArgs += '-TestBuild' }
& $trustedPowerShell @uninstallBuildArgs
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $stage '卸载.exe')) -or
    -not (Test-Path -LiteralPath (Join-Path $stage 'UninstallHost.exe'))) {
  throw "卸载组件编译失败（退出码 $LASTEXITCODE）"
}

# ---------- 2. 压 payload ----------
# 先对最终 stage 做“恰好等于白名单”的断言，再生成独立嵌入的哈希清单。安装器会按该清单
# 拒绝未知 ZIP 条目，并在原子切换前复验每个文件的大小与 SHA256。
$expectedStage = @($payloadFiles + @('install.identity', 'uninstall.ps1', '卸载.bat', '卸载.exe', 'UninstallHost.exe')) | ForEach-Object { $_.Replace('/', '\') }
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
$manifestNotes = @'
- 新增「通知中心」，支持新通知实时提醒、未读角标和历史消息查看。
- 最近消息会缓存在本机，网络暂时不可用时仍可查看已同步内容。
'@
$manifestObj = [ordered]@{
  # 与 $script:GuiVersion 逐字一致：客户端拿自身版本跟这里比大小，补位只会让
  # 「已是最新」和「有新版本」的判定跟着版本号写法漂
  version  = "$ver"
  # 旧版存在必须淘汰的问题；支持该字段的客户端低于本版时不允许跳过。
  minimumSupportedVersion = '0.22.3'
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
