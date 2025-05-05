# Diagnostic Tool for Network and System Performance
# Author: [Angelito Lemuel Balat/KMC Community Inc.]
# Collects system metrics and runs network tests only. No changes are made.

# KMC Initial Network Checking Tool V1.3

Write-Output "Diagnostic Tool for Network and System Performance"
Write-Output ""
Write-Output "Author: [Angelito Lemuel Balat/KMC Community Inc.]"
Write-Output ""
Write-Output "Collects system metrics and runs network tests only. No changes are made."
Write-Output ""

$ScriptVersion = "1.3"
Write-Output "KMC Initial Network Checking Tool - Version $ScriptVersion"
Write-Output ""


# Set execution policy temporarily for the current session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Initialize summary object
$summary = @{
    Hostname         = $env:COMPUTERNAME
    NetworkAdapters  = @()
    CPULoad          = $null
    MemoryUsage      = $null
    DiskUsage        = @()
    Uptime           = $null
    WiFiSSID         = "No active WiFi connections detected"
    WiFiSignal       = "N/A"
    PingTest         = @()
    Traceroute       = @()
    PathPing         = @()
    NSLookup         = @()
    IPConfig         = $null
    MACAddresses     = @()
}

# Function: Display IP Configuration
Write-Output "IP Configuration"
try {
    $ipConfig = ipconfig /all | Out-String
    $summary.IPConfig = $ipConfig
    Write-Output $ipConfig
} catch {
    Write-Output "Error retrieving IP configuration: $($_.Exception.Message)"
}

# Function: WLAN Info
Write-Output "WLAN Interface Information"
$wlanInfo = netsh wlan show interfaces

$ssidMatch = $wlanInfo | Select-String -Pattern "^\s*SSID\s+:\s+(.+)$"
if ($ssidMatch) {
    $summary.WiFiSSID = ($ssidMatch.Matches[0].Groups[1].Value).Trim()
} else {
    $summary.WiFiSSID = "No active WiFi connections detected"
    Write-Output "No WiFi connections detected."
}

$signalMatch = $wlanInfo | Select-String -Pattern "^\s*Signal\s+:\s+(.+)$"
if ($signalMatch) {
    $summary.WiFiSignal = ($signalMatch.Matches[0].Groups[1].Value).Trim()
} else {
    $summary.WiFiSignal = "N/A"
    Write-Output "No signal information available."
}

$wlanInfo | ForEach-Object { Write-Output $_ }

# Function: NSLookup
$targets = @("8.8.8.8", "1.1.1.1", "www.google.com", "208.67.222.222", "www.nasa.gov", "www.starwars.com", "www.godaddy.com", "www.att.com", "www.kmc.solutions")

Write-Output "NSLookup (IPv4 Only)"
foreach ($target in $targets) {
    Write-Output "`nNSLookup for $target"
    try {
        $result = nslookup.exe -type=A $target | Out-String
        $summary.NSLookup += "NSLookup for $target`n$result"
        Write-Output $result
    } catch {
        $msg = "NSLookup failed for $target $($_.Exception.Message)"
        $summary.NSLookup += $msg
        Write-Output $msg
    }
}

# Function: Get Network Adapter Info
function Get-NetworkAdapterInfo {
    Write-Output "`n=== Network Adapter Information ==="
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

    if ($adapters.Count -eq 0) {
        Write-Output "No active network adapters found."
    } else {
        foreach ($adapter in $adapters) {
            $linkSpeedMbps = if ($adapter.LinkSpeed -match '(\d+)\s*Mbps') { [int]$matches[1] } else { "Unknown" }
            $mac = $adapter.MacAddress

            $adapterSummary = @{
                Name           = $adapter.Name
                Description    = $adapter.InterfaceDescription
                MACAddress     = $mac
                LinkSpeedMbps  = $linkSpeedMbps
                ConnectionType = $adapter.MediaType
            }

            $summary.NetworkAdapters += $adapterSummary
            $summary.MACAddresses += $mac

            Write-Output "Adapter Name: $($adapter.Name)"
            Write-Output "Description : $($adapter.InterfaceDescription)"
            Write-Output "MAC Address : $mac"
            Write-Output "Link Speed  : $linkSpeedMbps Mbps"
            Write-Output "Type        : $($adapter.MediaType)`n"
        }
    }

    
}

# Function: System Performance Metrics
function Get-PerformanceCheck {
    Write-Output "Performance Check"
    try {
        $cpuLoad = Get-WmiObject -Class Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
        $summary.CPULoad = "$cpuLoad%"
        Write-Output "CPU Load: $cpuLoad%"

        $memory = Get-CimInstance -ClassName Win32_OperatingSystem
        $totalMemory = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
        $freeMemory = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
        $usedMemory = $totalMemory - $freeMemory
        $percentUsed = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
        $summary.MemoryUsage = "$usedMemory MB / $totalMemory MB ($percentUsed%)"
        Write-Output "Memory Usage: $usedMemory MB / $totalMemory MB ($percentUsed%)"

        $drives = Get-PSDrive -PSProvider FileSystem
        foreach ($drive in $drives) {
            $used = [math]::Round(($drive.Used / 1GB), 2)
            $free = [math]::Round(($drive.Free / 1GB), 2)
            $total = $used + $free
            $driveSummary = @{
                Drive      = $drive.Name
                UsedSpace  = "$used GB"
                FreeSpace  = "$free GB"
                TotalSpace = "$total GB"
            }
            $summary.DiskUsage += $driveSummary
            Write-Output "Drive $($drive.Name): Used $used GB, Free $free GB, Total $total GB"
        }

        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $summary.Uptime = "$($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
        Write-Output "System Uptime: $($summary.Uptime)"
    } catch {
        Write-Output "Error retrieving performance metrics: $_"
    }
}

# Function: Ping and Traceroute
Write-Output "Ping and Traceroute for Multiple Targets"
foreach ($target in $targets) {
    Write-Output "`nPerforming Ping Test for: $target"
    try {
        $pingResults = Test-Connection -ComputerName $target -Count 15 -ErrorAction Stop
        $pingText = $pingResults | Out-String
        $summary.PingTest += "Ping to $target`n$pingText"
        Write-Output $pingText

        $avgLatency = ($pingResults | Measure-Object -Property ResponseTime -Average).Average
        $rating = switch ($avgLatency) {
            { $_ -le 20 }  { "Excellent"; break }
            { $_ -le 40 }  { "Good"; break }
            { $_ -le 100 } { "Acceptable"; break }
            { $_ -le 200 } { "Poor"; break }
            default        { "Bad" }
        }

        $color = switch ($rating) {
            "Excellent" { "Green" }
            "Good"      { "Yellow" }
            "Acceptable" { "DarkYellow" }
            "Poor"      { "Red" }
            "Bad"       { "DarkRed" }
        }

        Write-Host "Average Latency: $([math]::Round($avgLatency, 2)) ms - Performance Rating: $rating" -ForegroundColor $color
    } catch {
        $msg = "Ping test failed for $target $_"
        $summary.PingTest += $msg
        Write-Output $msg
    }

    Write-Output "`nPerforming Traceroute for: $target"
    try {
        $trace = tracert.exe $target | Out-String
        $summary.Traceroute += "Traceroute to $target`n$trace"
        Write-Output $trace
    } catch {
        $msg = "Traceroute failed for $target $_"
        $summary.Traceroute += $msg
        Write-Output $msg
    }
}

# --- Link Speed Overview ---
Write-Output "`n=== Link Speed Overview ==="
$linkSpeedInfo = Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table -AutoSize | Out-String
Write-Output $linkSpeedInfo

# --- Total Bytes Sent/Received per Interface ---
Write-Output "`n=== Total Bytes Sent/Received per Interface ==="
$bytesInfo = Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface |
    Select-Object Name, BytesTotalPersec | Format-Table -AutoSize | Out-String
Write-Output $bytesInfo

$speedtestCLIPath = Join-Path -Path (Get-Location) -ChildPath "speedtest.exe"

if (Test-Path $speedtestCLIPath) {
    Write-Output "Running speed test to KMC Makati Server..."
    Write-Output "----------------------------------------`n"
    $speedtestOutput = & $speedtestCLIPath --server-id 62521
    
    foreach ($line in $speedtestOutput) {
        Write-Output $line
    }

    # Extract and clean up speeds for summary
    $downloadSpeed = ($speedtestOutput | Select-String -Pattern "Download:" -CaseSensitive).Line -replace "Download:\s*", ""
    $uploadSpeed = ($speedtestOutput | Select-String -Pattern "Upload:" -CaseSensitive).Line -replace "Upload:\s*", ""
    
    Write-Output "`nTest Summary:"
    Write-Output "----------------------------------------"
    Write-Output "Download Speed: $downloadSpeed"
    Write-Output "Upload Speed  : $uploadSpeed"
    
    $summary.Speedtest = @"
Speed Test Results:
Download Speed: $downloadSpeed
Upload Speed: $uploadSpeed
"@
} else {
    $errorMsg = "Error: Speedtest CLI not found at $speedtestCLIPath"
    Write-Output $errorMsg
    $summary.Speedtest = $errorMsg
}

# Run Data Collection
Get-NetworkAdapterInfo
Get-PerformanceCheck

# Final Summary
Write-Output "`n========================================="
Write-Output "         OVERALL DIAGNOSTIC SUMMARY       "
Write-Output "========================================="
Write-Output "`nHostname          : $($summary.Hostname)"
Write-Output "CPU Load           : $($summary.CPULoad)"
Write-Output "Memory Usage       : $($summary.MemoryUsage)"
Write-Output "System Uptime      : $($summary.Uptime)"
Write-Output "Connected to SSID  : $($summary.WiFiSSID)"
Write-Output "Signal Strength    : $($summary.WiFiSignal)"

Write-Output " Network Adapters "
foreach ($adapter in $summary.NetworkAdapters) {
    Write-Output "Name              : $($adapter.Name)"
    Write-Output "Description       : $($adapter.Description)"
    Write-Output "MAC Address       : $($adapter.MACAddress)"
    Write-Output "Link Speed        : $($adapter.LinkSpeedMbps) Mbps"
    Write-Output "Connection Type   : $($adapter.ConnectionType)"
    Write-Output "--------------------------------------"
}

Write-Output " Disk Usage"
foreach ($disk in $summary.DiskUsage) {
    Write-Output "Drive $($disk.Drive)  |  Used: $($disk.UsedSpace), Free: $($disk.FreeSpace), Total: $($disk.TotalSpace)"
}
Write-Output "--------------------------------------"

# Save Diagnostic Output to TXT File
$logPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "KMC_Diagnostic_Results.txt"
try {
    $fullLog = @"
=== Network Diagnostic Summary ===

Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Hostname: $($summary.Hostname)
Uptime: $($summary.Uptime)

CPU Usage: $($summary.CPULoad)
Memory Usage: $($summary.MemoryUsage)

Disk Usage:
$(foreach ($disk in $summary.DiskUsage) { "Drive $($disk.Drive): Used: $($disk.UsedSpace), Free: $($disk.FreeSpace), Total: $($disk.TotalSpace)" } -join "`n")

IP Configuration:
$($summary.IPConfig)

MAC Addresses:
$($summary.MACAddresses -join "`n")

Link Speed Overview:
$(Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table -AutoSize | Out-String)

Total Bytes Sent/Received per Interface:
$(Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface |
    Select-Object Name, BytesTotalPersec | Format-Table -AutoSize | Out-String)

Ping Results:
$($summary.PingTest -join "`n`n")

Traceroute Results:
$($summary.Traceroute -join "`n`n")

PathPing Results:
$($summary.PathPing -join "`n`n")

NSLookup (DNS Resolution):
$($summary.NSLookup -join "`n`n")

Network Adapters:
$(foreach ($adapter in $summary.NetworkAdapters) {
    "Name: $($adapter.Name), MAC: $($adapter.MACAddress), Link Speed: $($adapter.LinkSpeedMbps) Mbps, Type: $($adapter.ConnectionType)"
} -join "`n")

"@
    $fullLog | Out-File -FilePath $logPath -Encoding UTF8 -Force
    Write-Output "Diagnostic summary saved to: $logPath"
} catch {
    Write-Output "Failed to write log file: $_"
}

Read-Host -Prompt "Press Enter to exit"
# End of Script
# KMC Initial Network Checking Tool
# Version 1.3