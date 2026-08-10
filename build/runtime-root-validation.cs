using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;

// Shared by the asInvoker launcher and requireAdministrator EngineHost.  Keep this runtime
// contract equivalent to setup-wizard.cs: Program Files uses a trusted parent chain; every
// other location is the permanent <volume>\<anchor>\app layout.
static class DfbRuntimeRoot {
    const string TrustedInstallerSid = "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464";

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "GetNamedSecurityInfoW")]
    static extern uint GetNamedSecurityInfo(string objectName, int objectType, uint securityInformation,
        out IntPtr owner, out IntPtr group, out IntPtr dacl, out IntPtr sacl, out IntPtr securityDescriptor);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "ConvertSecurityDescriptorToStringSecurityDescriptorW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool ConvertSecurityDescriptorToStringSecurityDescriptor(IntPtr securityDescriptor,
        uint requestedRevision, uint securityInformation, out IntPtr stringSecurityDescriptor, out uint stringLength);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr LocalFree(IntPtr memory);

    static bool IsTrustedInstallWriter(SecurityIdentifier sid) {
        if (sid == null) return false;
        return sid.IsWellKnown(WellKnownSidType.BuiltinAdministratorsSid) ||
               sid.IsWellKnown(WellKnownSidType.LocalSystemSid);
    }
    static bool IsTrustedProgramFilesWriter(SecurityIdentifier sid) {
        return IsTrustedInstallWriter(sid) || (sid != null && sid.Value == TrustedInstallerSid);
    }
    static bool HasWriteRights(FileSystemRights rights) {
        const FileSystemRights write = FileSystemRights.WriteData | FileSystemRights.AppendData |
            FileSystemRights.WriteExtendedAttributes | FileSystemRights.WriteAttributes |
            FileSystemRights.DeleteSubdirectoriesAndFiles | FileSystemRights.Delete |
            FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership;
        long raw = (long)rights;
        return (rights & write) != 0 || (raw & 0x10000000L) != 0 || (raw & 0x40000000L) != 0;
    }
    static bool HasVolumeRootReplacementRights(FileSystemRights rights) {
        // DELETE on D:\ itself does not authorize deleting D:\Product.  Only DELETE_CHILD,
        // WRITE_DAC, WRITE_OWNER and GENERIC_ALL let a non-trusted principal replace the anchor.
        const FileSystemRights replaceChild = FileSystemRights.DeleteSubdirectoriesAndFiles |
            FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership;
        return (rights & replaceChild) != 0 || (((long)rights) & 0x10000000L) != 0;
    }
    static void EnsureNoReparse(string path) {
        string full = Path.GetFullPath(path);
        string root = Path.GetPathRoot(full);
        if (String.IsNullOrEmpty(root)) throw new IOException("路径没有有效根目录");
        if ((File.GetAttributes(root) & FileAttributes.ReparsePoint) != 0)
            throw new IOException("卷根包含 reparse point：" + root);
        string current = root.TrimEnd('\\');
        foreach (string part in full.Substring(root.Length).Split(new char[] { '\\' }, StringSplitOptions.RemoveEmptyEntries)) {
            current = current.Length == 2 && current[1] == ':' ? current + "\\" + part : Path.Combine(current, part);
            if (!Directory.Exists(current) && !File.Exists(current)) throw new IOException("安装路径不完整：" + current);
            if ((File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("路径包含 junction/symlink/reparse point：" + current);
        }
    }
    static string ProgramFilesBoundary(string full) {
        foreach (Environment.SpecialFolder folder in new Environment.SpecialFolder[] {
            Environment.SpecialFolder.ProgramFiles, Environment.SpecialFolder.ProgramFilesX86 }) {
            string root = Environment.GetFolderPath(folder);
            if (String.IsNullOrEmpty(root)) continue;
            string canonical = Path.GetFullPath(root).TrimEnd('\\');
            if ((full.TrimEnd('\\') + "\\").StartsWith(canonical + "\\", StringComparison.OrdinalIgnoreCase)) return canonical;
        }
        return null;
    }
    static void EnsureTrustedProgramFilesChain(string boundary, string full) {
        string current = Path.GetFullPath(boundary).TrimEnd('\\');
        string target = Path.GetFullPath(full).TrimEnd('\\');
        while (true) {
            EnsureNoReparse(current);
            var security = Directory.GetAccessControl(current, AccessControlSections.Owner | AccessControlSections.Access);
            var owner = security.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier;
            if (!IsTrustedProgramFilesWriter(owner)) throw new UnauthorizedAccessException("Program Files 路径 owner 不可信：" + current);
            foreach (FileSystemAccessRule rule in security.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
                var sid = rule.IdentityReference as SecurityIdentifier;
                bool creatorInheritOnly = sid != null && sid.Value == "S-1-3-0" &&
                    (rule.PropagationFlags & PropagationFlags.InheritOnly) != 0;
                if (rule.AccessControlType == AccessControlType.Allow && HasWriteRights(rule.FileSystemRights) &&
                    !IsTrustedProgramFilesWriter(sid) && !creatorInheritOnly)
                    throw new UnauthorizedAccessException("Program Files 路径允许非受信账户写入/DeleteChild：" + current);
            }
            if (String.Equals(current, target, StringComparison.OrdinalIgnoreCase)) break;
            string remainder = target.Substring(current.Length).TrimStart('\\');
            if (remainder.Length == 0) break;
            current = Path.Combine(current, remainder.Split('\\')[0]);
        }
    }
    static void EnsureSafeVolumeRoot(string driveRoot) {
        EnsureNoReparse(driveRoot);
        var security = Directory.GetAccessControl(driveRoot, AccessControlSections.Owner | AccessControlSections.Access);
        var owner = security.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier;
        if (!IsTrustedProgramFilesWriter(owner)) throw new UnauthorizedAccessException("卷根 owner 不可信");
        foreach (FileSystemAccessRule rule in security.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
            var sid = rule.IdentityReference as SecurityIdentifier;
            bool inheritOnly = (rule.PropagationFlags & PropagationFlags.InheritOnly) != 0;
            if (!inheritOnly && rule.AccessControlType == AccessControlType.Allow &&
                !IsTrustedProgramFilesWriter(sid) && HasVolumeRootReplacementRights(rule.FileSystemRights))
                throw new UnauthorizedAccessException("卷根允许非受信账户替换一级安装锚点");
        }
    }
    static void EnsureProtectedEntry(string path, bool directory) {
        FileSystemSecurity security = directory
            ? (FileSystemSecurity)Directory.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access)
            : (FileSystemSecurity)File.GetAccessControl(path, AccessControlSections.Owner | AccessControlSections.Access);
        var owner = security.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier;
        if (!IsTrustedProgramFilesWriter(owner)) throw new UnauthorizedAccessException("安装项 owner 不可信：" + path);
        foreach (FileSystemAccessRule rule in security.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
            if (rule.AccessControlType == AccessControlType.Allow && HasWriteRights(rule.FileSystemRights) &&
                !IsTrustedProgramFilesWriter(rule.IdentityReference as SecurityIdentifier))
                throw new UnauthorizedAccessException("安装项允许非管理员写入：" + path);
        }
    }
    static void EnsureExactAnchorDirectory(string anchor) {
        var security = Directory.GetAccessControl(anchor, AccessControlSections.Owner | AccessControlSections.Access);
        var owner = security.GetOwner(typeof(SecurityIdentifier)) as SecurityIdentifier;
        if (!IsTrustedInstallWriter(owner) || !security.AreAccessRulesProtected)
            throw new UnauthorizedAccessException("安装锚点 owner/DACL 继承状态不可信");
        string admin = new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null).Value;
        string system = new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null).Value;
        string users = new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null).Value;
        bool adminFull = false, systemFull = false, usersRead = false; int count = 0;
        foreach (FileSystemAccessRule rule in security.GetAccessRules(true, true, typeof(SecurityIdentifier))) {
            count++;
            var sid = rule.IdentityReference as SecurityIdentifier;
            if (sid == null || rule.AccessControlType != AccessControlType.Allow || rule.IsInherited ||
                rule.InheritanceFlags != (InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit) ||
                rule.PropagationFlags != PropagationFlags.None) throw new UnauthorizedAccessException("安装锚点含非预期 ACL");
            if (sid.Value == admin && rule.FileSystemRights == FileSystemRights.FullControl) adminFull = true;
            else if (sid.Value == system && rule.FileSystemRights == FileSystemRights.FullControl) systemFull = true;
            else if (sid.Value == users && rule.FileSystemRights == (FileSystemRights.ReadAndExecute | FileSystemRights.Synchronize)) usersRead = true;
            else throw new UnauthorizedAccessException("安装锚点 ACL 不在精确白名单");
        }
        if (count != 3 || !adminFull || !systemFull || !usersRead)
            throw new UnauthorizedAccessException("安装锚点 ACL 必须恰好为 Admin/System Full + Users RX");
    }
    static string ReadIntegrityLabelSddl(string path) {
        const int SE_FILE_OBJECT = 1; const uint LABEL_SECURITY_INFORMATION = 0x10;
        IntPtr owner, group, dacl, sacl, descriptor;
        uint result = GetNamedSecurityInfo(path, SE_FILE_OBJECT, LABEL_SECURITY_INFORMATION,
            out owner, out group, out dacl, out sacl, out descriptor);
        if (result != 0) throw new Win32Exception((int)result, "读取安装锚点完整性标签失败");
        try {
            IntPtr sddl; uint length;
            if (!ConvertSecurityDescriptorToStringSecurityDescriptor(descriptor, 1, LABEL_SECURITY_INFORMATION, out sddl, out length))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "转换安装锚点完整性标签失败");
            try { return Marshal.PtrToStringUni(sddl) ?? ""; }
            finally { if (sddl != IntPtr.Zero) LocalFree(sddl); }
        } finally { if (descriptor != IntPtr.Zero) LocalFree(descriptor); }
    }
    static void EnsureHighIntegrityAnchor(string anchor) {
        MatchCollection labels = Regex.Matches(ReadIntegrityLabelSddl(anchor), @"\(ML;([^;]*);([^;]*);;;HI\)", RegexOptions.IgnoreCase);
        if (labels.Count != 1) throw new UnauthorizedAccessException("安装锚点缺少唯一 High mandatory label");
        string flags = labels[0].Groups[1].Value.ToUpperInvariant();
        string policy = labels[0].Groups[2].Value.ToUpperInvariant();
        if (!flags.Contains("OI") || !flags.Contains("CI") || !policy.Contains("NW"))
            throw new UnauthorizedAccessException("安装锚点 High label 缺少 OI/CI/NoWriteUp");
    }
    static void ValidateAnchorIdentity(string anchor) {
        string identity = Path.Combine(anchor, "anchor.identity");
        EnsureNoReparse(identity); EnsureProtectedEntry(identity, false);
        FileInfo info = new FileInfo(identity);
        if (info.Length <= 0 || info.Length > 512) throw new InvalidDataException("anchor.identity 大小无效");
        string text;
        using (var stream = new FileStream(identity, FileMode.Open, FileAccess.Read, FileShare.Read))
        using (var reader = new StreamReader(stream, new UTF8Encoding(false, true), false)) text = reader.ReadToEnd();
        string[] lines = text.Replace("\r\n", "\n").Split('\n');
        if (lines.Length != 7 || lines[6].Length != 0 || lines[0] != "SchemaVersion=1" ||
            lines[1] != "ProductId=DeltaForceBooster" || lines[2] != "Layout=PermanentAnchor" ||
            lines[3] != "CodeDirectory=app" || !lines[4].StartsWith("AnchorId=", StringComparison.Ordinal) ||
            !Regex.IsMatch(lines[4].Substring("AnchorId=".Length), "^[0-9a-f]{32}$") ||
            lines[5] != "AnchorNeverDelete=1") throw new InvalidDataException("anchor.identity 格式无效");
    }
#if DFB_TESTING
    static bool IsTestBypass(string full) {
        string testRoot = Path.GetFullPath(Path.Combine(Path.GetTempPath(), "DeltaForceBooster-Tests")).TrimEnd('\\') + "\\";
        return Environment.GetEnvironmentVariable("DFB_TEST_SKIP_ACL") == "1" &&
            (full.TrimEnd('\\') + "\\").StartsWith(testRoot, StringComparison.OrdinalIgnoreCase);
    }
#endif
    public static string Validate(string root) {
        try {
            string full = Path.GetFullPath(root).TrimEnd('\\');
            if (full.StartsWith(@"\\", StringComparison.Ordinal) || full.Length < 3 || full.IndexOf(':', 2) >= 0)
                throw new IOException("安装路径不是本地规范路径");
            if (!Directory.Exists(full)) throw new DirectoryNotFoundException("安装目录不存在");
            EnsureNoReparse(full);
#if DFB_TESTING
            if (IsTestBypass(full)) return null;
#endif
            string driveRoot = Path.GetPathRoot(full);
            var drive = new DriveInfo(driveRoot);
            if (drive.DriveType != DriveType.Fixed || !drive.IsReady || !String.Equals(drive.DriveFormat, "NTFS", StringComparison.OrdinalIgnoreCase))
                throw new IOException("安装卷必须是已就绪的本地固定 NTFS 卷");
            string pf = ProgramFilesBoundary(full);
            if (pf != null) { EnsureTrustedProgramFilesChain(pf, full); return null; }

            if (!String.Equals(Path.GetFileName(full), "app", StringComparison.OrdinalIgnoreCase))
                throw new IOException("其他盘代码目录必须是永久安装锚点下的 app");
            string anchor = Path.GetDirectoryName(full);
            string anchorParent = String.IsNullOrEmpty(anchor) ? null : Path.GetDirectoryName(anchor.TrimEnd('\\'));
            if (String.IsNullOrEmpty(anchor) || String.IsNullOrEmpty(anchorParent) ||
                !String.Equals(anchorParent.TrimEnd('\\'), driveRoot.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase))
                throw new IOException("其他盘只接受 <卷根>\\<一级锚点>\\app");
            EnsureSafeVolumeRoot(driveRoot); EnsureNoReparse(anchor); EnsureExactAnchorDirectory(anchor);
            EnsureHighIntegrityAnchor(anchor); ValidateAnchorIdentity(anchor); EnsureProtectedEntry(full, true);
            return null;
        } catch (Exception ex) { return ex.Message; }
    }
}
