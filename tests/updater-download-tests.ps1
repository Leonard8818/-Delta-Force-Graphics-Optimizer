param([switch]$KeepArtifacts)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$testBase = Join-Path ([IO.Path]::GetTempPath()) ('DeltaForceBooster-Tests\updater-download-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testBase)

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "ASSERT: $Message" }
}

if (-not ('DfbRangeRetryServer' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

public sealed class DfbRangeRetryServer : IDisposable {
  private readonly TcpListener listener;
  private readonly Thread thread;
  private readonly byte[] payload;
  private readonly int slowChunkBytes;
  private readonly int stallMilliseconds;
  private readonly int successfulRequest;
  private readonly int maximumRequests;
  private readonly int busyRequests;
  private readonly List<string> ranges = new List<string>();
  private volatile bool stopping;
  private int requestCount;

  public DfbRangeRetryServer(byte[] payload, int slowChunkBytes, int stallMilliseconds,
      int successfulRequest, int maximumRequests)
      : this(payload, slowChunkBytes, stallMilliseconds, successfulRequest, maximumRequests, 0) { }

  public DfbRangeRetryServer(byte[] payload, int slowChunkBytes, int stallMilliseconds,
      int successfulRequest, int maximumRequests, int busyRequests) {
    this.payload = payload;
    this.slowChunkBytes = slowChunkBytes;
    this.stallMilliseconds = stallMilliseconds;
    this.successfulRequest = successfulRequest;
    this.maximumRequests = maximumRequests;
    this.busyRequests = busyRequests;
    listener = new TcpListener(IPAddress.Loopback, 0);
    listener.Start();
    Port = ((IPEndPoint)listener.LocalEndpoint).Port;
    thread = new Thread(Run);
    thread.IsBackground = true;
    thread.Start();
  }

  public int Port { get; private set; }
  public string Url { get { return "http://127.0.0.1:" + Port + "/setup.exe"; } }
  public int RequestCount { get { return Volatile.Read(ref requestCount); } }
  public Exception Error { get; private set; }
  public string[] Ranges { get { lock (ranges) { return ranges.ToArray(); } } }

  private static string ReadHeaders(NetworkStream stream, out string range) {
    range = "";
    var all = new StringBuilder();
    using (var reader = new StreamReader(stream, Encoding.ASCII, false, 1024, true)) {
      string line;
      while ((line = reader.ReadLine()) != null) {
        if (line.Length == 0) break;
        all.AppendLine(line);
        if (line.StartsWith("Range:", StringComparison.OrdinalIgnoreCase)) {
          range = line.Substring(6).Trim();
        }
      }
    }
    return all.ToString();
  }

  private static long ParseStart(string range) {
    if (String.IsNullOrEmpty(range)) return 0;
    const string prefix = "bytes=";
    if (!range.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return -1;
    string value = range.Substring(prefix.Length);
    int dash = value.IndexOf('-');
    long result;
    return dash > 0 && Int64.TryParse(value.Substring(0, dash), out result) ? result : -1;
  }

  private void Run() {
    try {
      while (!stopping && RequestCount < maximumRequests) {
        using (TcpClient client = listener.AcceptTcpClient()) {
          client.ReceiveTimeout = 5000;
          client.SendTimeout = 5000;
          using (NetworkStream stream = client.GetStream()) {
            string range;
            ReadHeaders(stream, out range);
            lock (ranges) { ranges.Add(range); }
            int current = Interlocked.Increment(ref requestCount);
            if (current <= busyRequests) {
              byte[] busy = Encoding.ASCII.GetBytes(
                "HTTP/1.1 429 Too Many Requests\r\nRetry-After: 1\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");
              stream.Write(busy, 0, busy.Length);
              stream.Flush();
              continue;
            }
            long start = ParseStart(range);
            if (start < 0 || start >= payload.LongLength) {
              byte[] invalid = Encoding.ASCII.GetBytes("HTTP/1.1 416 Range Not Satisfiable\r\nConnection: close\r\nContent-Length: 0\r\n\r\n");
              stream.Write(invalid, 0, invalid.Length);
              stream.Flush();
              continue;
            }

            long remaining = payload.LongLength - start;
            bool partial = start > 0;
            var header = new StringBuilder();
            header.Append(partial ? "HTTP/1.1 206 Partial Content\r\n" : "HTTP/1.1 200 OK\r\n");
            header.Append("Accept-Ranges: bytes\r\n");
            header.Append("Content-Length: ").Append(remaining).Append("\r\n");
            if (partial) {
              header.Append("Content-Range: bytes ").Append(start).Append('-')
                .Append(payload.LongLength - 1).Append('/').Append(payload.LongLength).Append("\r\n");
            }
            header.Append("Connection: close\r\n\r\n");
            byte[] headerBytes = Encoding.ASCII.GetBytes(header.ToString());
            stream.Write(headerBytes, 0, headerBytes.Length);

            bool succeeds = successfulRequest > 0 && current == successfulRequest;
            int count = succeeds ? checked((int)remaining) : (int)Math.Min((long)slowChunkBytes, remaining);
            stream.Write(payload, checked((int)start), count);
            stream.Flush();
            if (!succeeds) Thread.Sleep(stallMilliseconds);
          }
        }
      }
    } catch (Exception ex) {
      if (!stopping) Error = ex;
    }
  }

  public void Dispose() {
    stopping = true;
    try { listener.Stop(); } catch { }
    if (thread != null && thread.IsAlive) thread.Join(3000);
  }
}
'@
}

function Get-TestSha256([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
  finally { $sha.Dispose() }
}

function New-TestPayload([int]$Length) {
  $bytes = New-Object byte[] $Length
  for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = [byte](($i * 37 + 11) % 251) }
  $bytes
}

. (Join-Path $root 'scripts\updater.ps1')

# 下载逻辑的生产白名单保持不变；测试只把同进程 loopback fixture 放行。
function Test-BoosterSetupUrl([string]$Url) {
  $uri = $null
  $allowed = ([Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) -and ($uri.Host -eq '127.0.0.1')
  [pscustomobject]@{ Allowed = $allowed; Reason = $(if ($allowed) { '' } else { 'test URL denied' }) }
}

$script:TestUpdaterStageRoot = $testBase
$script:TestUpdaterStageCounter = 0
function New-BoosterSecureStaging {
  param([switch]$ForceProgramData, [string]$Id, [Security.Principal.SecurityIdentifier]$ReaderSid)
  $script:TestUpdaterStageCounter++
  $dir = Join-Path $script:TestUpdaterStageRoot ("stage-$script:TestUpdaterStageCounter")
  [void][IO.Directory]::CreateDirectory($dir)
  [pscustomobject]@{ Directory = $dir; Elevated = $true }
}
function Protect-BoosterStaging {
  param([string]$Directory, [string[]]$Files, [bool]$Elevated, [Security.Principal.SecurityIdentifier]$ReaderSid)
}

try {
  # 下载入口临时返回 429 时自动遵从 Retry-After 重试，不向用户暴露 GetResponse 内部异常。
  $busyPayload = New-TestPayload 98317
  $busySha = Get-TestSha256 $busyPayload
  $busyServer = [DfbRangeRetryServer]::new($busyPayload, 8192, 0, 2, 2, 1)
  try {
    $busyState = @{ Received = 0L; Total = [long]$busyPayload.Length; Phase = ''; Error = ''; File = ''; Cancel = $false; Done = $false }
    Invoke-BoosterSetupDownload -SetupUrl $busyServer.Url -Sha256 $busySha -Size $busyPayload.Length -State $busyState `
      -TimeoutMs 1000 -MaxAttempts 3 -RetryDelayMs 50
    Assert-True ($busyState.Phase -eq 'done' -and $busyState.Done) 'HTTP 429 did not recover to a completed download'
    Assert-True ([int]$busyState.RetryCount -eq 1 -and $busyServer.RequestCount -eq 2) 'HTTP 429 retry count is wrong'
    Assert-True ($busyState.Error -notmatch '(?i)GetResponse|Too Many Requests|429') 'HTTP 429 exposed a raw WebException'
    Assert-True ((Test-Path -LiteralPath $busyState.File -PathType Leaf) -and (Get-FileHash -LiteralPath $busyState.File).Hash -eq $busySha) `
      'HTTP 429 retry failed final byte/hash verification'
  } finally { $busyServer.Dispose() }

  $busyFailedServer = [DfbRangeRetryServer]::new($busyPayload, 8192, 0, 0, 2, 2)
  try {
    $busyFailedState = @{ Received = 0L; Total = [long]$busyPayload.Length; Phase = ''; Error = ''; File = ''; Cancel = $false; Done = $false }
    Invoke-BoosterSetupDownload -SetupUrl $busyFailedServer.Url -Sha256 $busySha -Size $busyPayload.Length -State $busyFailedState `
      -TimeoutMs 1000 -MaxAttempts 2 -RetryDelayMs 50
    Assert-True ($busyFailedState.Phase -eq 'failed' -and $busyFailedState.Done) 'persistent HTTP 429 did not enter failed state'
    Assert-True ($busyFailedState.Error -like '*下载服务器持续繁忙*已自动尝试 2 次*' -and
      $busyFailedState.Error -notmatch '(?i)GetResponse|Too Many Requests|使用.*参数调用') `
      'persistent HTTP 429 did not produce a user-friendly error'
  } finally { $busyFailedServer.Dispose() }

  # 第一次响应只发送一段后停顿，触发与用户现场相同的 Read 超时；第二次必须带 Range 续传。
  $payload = New-TestPayload 196731
  $sha = Get-TestSha256 $payload
  $server = [DfbRangeRetryServer]::new($payload, 24576, 350, 2, 2)
  try {
    $state = @{ Received = 0L; Total = [long]$payload.Length; Phase = ''; Error = ''; File = ''; Cancel = $false; Done = $false }
    Invoke-BoosterSetupDownload -SetupUrl $server.Url -Sha256 $sha -Size $payload.Length -State $state `
      -TimeoutMs 100 -MaxAttempts 3 -RetryDelayMs 400
    Assert-True ($state.Phase -eq 'done' -and $state.Done) 'read timeout did not recover to a completed download'
    Assert-True ([long]$state.Received -eq $payload.Length -and [int]$state.RetryCount -eq 1) 'resumed progress or retry count is wrong'
    Assert-True ((Test-Path -LiteralPath $state.File -PathType Leaf) -and (Get-FileHash -LiteralPath $state.File).Hash -eq $sha) `
      'resumed file failed the final byte/hash verification'
    Assert-True ($server.RequestCount -eq 2 -and $server.Ranges.Count -eq 2 -and
      $server.Ranges[0] -eq '' -and $server.Ranges[1] -eq 'bytes=24576-') 'retry did not request the exact remaining range'
    Assert-True ($null -eq $server.Error) "loopback resume server failed: $($server.Error)"
  } finally { $server.Dispose() }

  # 连续失败达到上限时，不再把“使用 3 个参数调用 Read”这类运行时内部错误直接展示给用户。
  $failedPayload = New-TestPayload 65539
  $failedSha = Get-TestSha256 $failedPayload
  $failedServer = [DfbRangeRetryServer]::new($failedPayload, 8192, 350, 0, 2)
  try {
    $failedState = @{ Received = 0L; Total = [long]$failedPayload.Length; Phase = ''; Error = ''; File = ''; Cancel = $false; Done = $false }
    Invoke-BoosterSetupDownload -SetupUrl $failedServer.Url -Sha256 $failedSha -Size $failedPayload.Length -State $failedState `
      -TimeoutMs 100 -MaxAttempts 2 -RetryDelayMs 400
    Assert-True ($failedState.Phase -eq 'failed' -and $failedState.Done) 'retry exhaustion did not enter failed state'
    Assert-True ($failedState.Error -like '*连续中断或超时*已自动尝试 2 次*' -and
      $failedState.Error -notmatch '(?i)Read|3\s*个参数|调用.*参数') 'retry exhaustion exposed the raw Read invocation exception'
    Assert-True ($failedServer.RequestCount -eq 2 -and $failedServer.Ranges[1] -eq 'bytes=8192-') `
      'retry exhaustion did not preserve progress between attempts'
  } finally { $failedServer.Dispose() }

  $guiSource = [IO.File]::ReadAllText((Join-Path $root 'gui\DeltaForceBooster-GUI.ps1'))
  Assert-True ($guiSource -match '\$st\.Status' -and $guiSource -match "Status = '正在进入服务器下载队列…'; RetryCount = 0" -and
    $guiSource -match "Phase -in @\('queued','downloading'\)") `
    'update dialog does not surface queue/retry/resume status'

  'PASS updater download: Read timeout resumes with Range and exhaustion is user-friendly'
} finally {
  if ($KeepArtifacts) { "artifacts: $testBase" }
  elseif (Test-Path -LiteralPath $testBase) { Remove-Item -LiteralPath $testBase -Recurse -Force }
}
