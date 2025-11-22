<#
.SYNOPSIS
  inbash :: windows/system_check.ps1
  Quick system spec + status report for Windows (OS, CPU, GPU, memory, disks).
.DESCRIPTION
  Generates a brief system summary plus GPU and disk details. Supports plain
  text output or structured JSON via -AsJson.
.EXAMPLE
  .\system_check.ps1
.EXAMPLE
  .\system_check.ps1 -AsJson
.NOTES
  Run from an elevated PowerShell session for the most complete hardware info.
#>

param(
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────
# Collect base info
# ─────────────────────────────────────────────────────────────
$os   = Get-CimInstance Win32_OperatingSystem
$cs   = Get-CimInstance Win32_ComputerSystem
$cpu  = Get-CimInstance Win32_Processor
$gpus = Get-CimInstance Win32_VideoController
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" # local fixed disks

# Uptime
$bootTime = $os.LastBootUpTime
$uptime   = (Get-Date) - $bootTime

# Memory (MB + %)
$totalMemMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 1)
$freeMemMB  = [math]::Round($os.FreePhysicalMemory / 1024, 1)
$usedMemMB  = $totalMemMB - $freeMemMB

if ($totalMemMB -gt 0) {
    $memUsagePct = [math]::Round(($usedMemMB / $totalMemMB) * 100, 1)
} else {
    $memUsagePct = $null
}

# CPU load (instant)
$cpuLoad = $cpu.LoadPercentage

# ─────────────────────────────────────────────────────────────
# Build main system summary
# ─────────────────────────────────────────────────────────────
$systemSummary = [pscustomobject]@{
    ComputerName        = $env:COMPUTERNAME
    Manufacturer        = $cs.Manufacturer
    Model               = $cs.Model
    OS                  = $os.Caption
    OSVersion           = $os.Version
    OSArchitecture      = $os.OSArchitecture
    LastBootTime        = $bootTime
    Uptime              = ("{0:dd}d {0:hh}h {0:mm}m" -f $uptime)
    CPU                 = $cpu.Name
    Cores               = $cpu.NumberOfCores
    LogicalProcessors   = $cpu.NumberOfLogicalProcessors
    CPULoadPercent      = $cpuLoad
    TotalMemoryMB       = $totalMemMB
    UsedMemoryMB        = $usedMemMB
    FreeMemoryMB        = $freeMemMB
    MemoryUsagePercent  = $memUsagePct
}

# ─────────────────────────────────────────────────────────────
# GPU info
# ─────────────────────────────────────────────────────────────
$gpuInfo = $gpus | Select-Object `
    @{ Name = 'Name';      Expression = { $_.Name } },
    @{ Name = 'VRAM_GB';   Expression = {
            if ($_.AdapterRAM) {
                [math]::Round($_.AdapterRAM / 1GB, 2)
            } else {
                $null
            }
        }
    },
    @{ Name = 'DriverVersion'; Expression = { $_.DriverVersion } }

# ─────────────────────────────────────────────────────────────
# Disk info (per logical drive)
# ─────────────────────────────────────────────────────────────
$diskInfo = $disks | Select-Object `
    @{ Name = 'Drive';      Expression = { $_.DeviceID } },
    @{ Name = 'FileSystem'; Expression = { $_.FileSystem } },
    @{ Name = 'Size_GB';    Expression = {
            if ($_.Size) { [math]::Round($_.Size / 1GB, 1) } else { $null }
        }
    },
    @{ Name = 'Free_GB';    Expression = {
            if ($_.FreeSpace) { [math]::Round($_.FreeSpace / 1GB, 1) } else { $null }
        }
    },
    @{ Name = 'UsedPercent'; Expression = {
            if ($_.Size -and $_.FreeSpace -ne $null) {
                [math]::Round((1 - ($_.FreeSpace / $_.Size)) * 100, 1)
            } else {
                $null
            }
        }
    }

# ─────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────
if ($AsJson) {
    # Structured JSON for logging or other tools
    [pscustomobject]@{
        System = $systemSummary
        GPUs   = $gpuInfo
        Disks  = $diskInfo
    } | ConvertTo-Json -Depth 5
}
else {
    Write-Host "===== SYSTEM SUMMARY =====" -ForegroundColor Cyan
    $systemSummary | Format-List

    Write-Host "`n===== GPU(S) =====" -ForegroundColor Cyan
    if ($gpuInfo) {
        $gpuInfo | Format-Table -AutoSize
    } else {
        Write-Host "No GPU information found."
    }

    Write-Host "`n===== DISKS =====" -ForegroundColor Cyan
    if ($diskInfo) {
        $diskInfo | Format-Table -AutoSize
    } else {
        Write-Host "No disk information found."
    }
}
