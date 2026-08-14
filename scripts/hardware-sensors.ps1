#requires -Version 5.1

# Bundled LibreHardwareMonitor provider.  The GUI dot-sources this file inside its
# metrics runspace so the Computer instance stays open between two-second samples.

function Open-DfbHardwareMonitor([Parameter(Mandatory)][string]$LibraryDirectory) {
  $ErrorActionPreference = 'Stop'
  $dependencyNames = @(
    'System.Buffers.dll',
    'System.Numerics.Vectors.dll',
    'System.Runtime.CompilerServices.Unsafe.dll',
    'System.Memory.dll',
    'BlackSharp.Core.dll',
    'DiskInfoToolkit.dll',
    'RAMSPDToolkit-NDD.dll',
    'HidSharp.dll',
    'LibreHardwareMonitorLib.dll'
  )
  foreach ($name in $dependencyNames) {
    $path = Join-Path $LibraryDirectory $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "内置硬件传感器组件缺失：$name"
    }
    [void][Reflection.Assembly]::LoadFrom($path)
  }

  $computer = New-Object -TypeName 'LibreHardwareMonitor.Hardware.Computer'
  try {
    # CPU/GPU 温度来自各自硬件节点；主板同时启用 Super I/O，读取路径与
    # Game++ 这类硬件监控器一样直接访问传感器，而不是依赖外部 WMI 服务。
    $computer.IsCpuEnabled = $true
    $computer.IsGpuEnabled = $true
    $computer.IsMotherboardEnabled = $true
    $computer.Open()
    $computer
  } catch {
    try { $computer.Close() } catch {}
    throw
  }
}

function Add-DfbTemperatureSensors($Hardware, [string]$RootHardwareType, $Output) {
  if (-not $Hardware) { return }
  $Hardware.Update()
  foreach ($sensor in @($Hardware.Sensors)) {
    if ("$($sensor.SensorType)" -ne 'Temperature' -or $null -eq $sensor.Value) { continue }
    $value = [double]$sensor.Value
    if ($value -lt 10 -or $value -gt 125) { continue }
    [void]$Output.Add([pscustomobject]@{
      HardwareType = $RootHardwareType
      Name = "$($sensor.Name)"
      Value = $value
    })
  }
  foreach ($subHardware in @($Hardware.SubHardware)) {
    Add-DfbTemperatureSensors $subHardware $RootHardwareType $Output
  }
}

function Select-DfbPreferredTemperature([object[]]$Sensors, [string[]]$NamePatterns) {
  foreach ($pattern in $NamePatterns) {
    $matches = @($Sensors | Where-Object { "$($_.Name)" -match $pattern } |
      Sort-Object Value -Descending)
    if ($matches.Count) {
      return [pscustomobject]@{
        Value = [math]::Round([double]$matches[0].Value, 1)
        Name = "$($matches[0].Name)"
      }
    }
  }
  $null
}

function Get-DfbHardwareTemperatures([Parameter(Mandatory)]$Computer) {
  $ErrorActionPreference = 'Stop'
  $sensors = New-Object Collections.ArrayList
  foreach ($hardware in @($Computer.Hardware)) {
    Add-DfbTemperatureSensors $hardware "$($hardware.HardwareType)" $sensors
  }

  $cpu = Select-DfbPreferredTemperature `
    @($sensors | Where-Object { $_.HardwareType -eq 'Cpu' }) `
    @('(?i)^CPU Package$','(?i)(?:Tctl/Tdie|Tdie)$','(?i)^Core Max$','(?i)^CPU Cores?$','(?i)^CPU Core #\d+$')
  $gpu = Select-DfbPreferredTemperature `
    @($sensors | Where-Object { $_.HardwareType -like 'Gpu*' }) `
    @('(?i)^GPU Core$','(?i)^GPU Temperature$')

  [pscustomobject]@{
    Cpu = $(if ($cpu) { $cpu.Value } else { $null })
    Gpu = $(if ($gpu) { $gpu.Value } else { $null })
    CpuSensor = $(if ($cpu) { $cpu.Name } else { '' })
    GpuSensor = $(if ($gpu) { $gpu.Name } else { '' })
  }
}

function Close-DfbHardwareMonitor($Computer) {
  if (-not $Computer) { return }
  try { $Computer.Close() } catch {}
  try { $Computer.Dispose() } catch {}
}
