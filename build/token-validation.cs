using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

sealed class DfbTokenFacts {
    public string Sid;
    public bool Elevated;
    public int IntegrityRid;
    public int SessionId;
    public bool IsMedium { get { return !Elevated && IntegrityRid >= 0x2000 && IntegrityRid < 0x3000; } }
}

static class DfbTokenValidation {
    const uint TOKEN_QUERY = 0x0008;
    const int TokenUser = 1, TokenSessionId = 12, TokenElevation = 20, TokenIntegrityLevel = 25;
    [StructLayout(LayoutKind.Sequential)] struct SID_AND_ATTRIBUTES { public IntPtr Sid; public uint Attributes; }
    [StructLayout(LayoutKind.Sequential)] struct TOKEN_USER { public SID_AND_ATTRIBUTES User; }
    [StructLayout(LayoutKind.Sequential)] struct TOKEN_MANDATORY_LABEL { public SID_AND_ATTRIBUTES Label; }
    [StructLayout(LayoutKind.Sequential)] struct TOKEN_ELEVATION { public uint TokenIsElevated; }
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool GetTokenInformation(IntPtr token, int infoClass,
        IntPtr information, int informationLength, out int returnLength);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr handle);

    static IntPtr Query(IntPtr token, int infoClass) {
        int length;
        GetTokenInformation(token, infoClass, IntPtr.Zero, 0, out length);
        if (length <= 0) throw new Win32Exception(Marshal.GetLastWin32Error(), "读取进程令牌长度失败");
        IntPtr buffer = Marshal.AllocHGlobal(length);
        if (!GetTokenInformation(token, infoClass, buffer, length, out length)) {
            int error = Marshal.GetLastWin32Error(); Marshal.FreeHGlobal(buffer);
            throw new Win32Exception(error, "读取进程令牌失败");
        }
        return buffer;
    }
    static int IntegrityRid(SecurityIdentifier sid) {
        byte[] data = new byte[sid.BinaryLength]; sid.GetBinaryForm(data, 0);
        int count = data[1];
        if (count <= 0 || data.Length < 8 + count * 4) throw new InvalidOperationException("令牌完整性 SID 无效");
        return BitConverter.ToInt32(data, 8 + (count - 1) * 4);
    }
    static DfbTokenFacts ReadToken(IntPtr token) {
        IntPtr user = IntPtr.Zero, elevation = IntPtr.Zero, integrity = IntPtr.Zero, session = IntPtr.Zero;
        try {
            user = Query(token, TokenUser); elevation = Query(token, TokenElevation);
            integrity = Query(token, TokenIntegrityLevel); session = Query(token, TokenSessionId);
            var userInfo = (TOKEN_USER)Marshal.PtrToStructure(user, typeof(TOKEN_USER));
            var label = (TOKEN_MANDATORY_LABEL)Marshal.PtrToStructure(integrity, typeof(TOKEN_MANDATORY_LABEL));
            return new DfbTokenFacts {
                Sid = new SecurityIdentifier(userInfo.User.Sid).Value,
                Elevated = ((TOKEN_ELEVATION)Marshal.PtrToStructure(elevation, typeof(TOKEN_ELEVATION))).TokenIsElevated != 0,
                IntegrityRid = IntegrityRid(new SecurityIdentifier(label.Label.Sid)),
                SessionId = Marshal.ReadInt32(session)
            };
        } finally {
            if (user != IntPtr.Zero) Marshal.FreeHGlobal(user);
            if (elevation != IntPtr.Zero) Marshal.FreeHGlobal(elevation);
            if (integrity != IntPtr.Zero) Marshal.FreeHGlobal(integrity);
            if (session != IntPtr.Zero) Marshal.FreeHGlobal(session);
        }
    }
    public static DfbTokenFacts FromCurrentProcess() {
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent()) { return ReadToken(identity.Token); }
    }
    public static DfbTokenFacts FromProcessHandle(IntPtr process) {
        IntPtr token;
        if (!OpenProcessToken(process, TOKEN_QUERY, out token))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "无法读取启动器进程令牌");
        try { return ReadToken(token); } finally { CloseHandle(token); }
    }
}
