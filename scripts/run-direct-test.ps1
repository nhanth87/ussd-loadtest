# Direct test run with tcpdump on host
param(
    [int]$TPS = 1000,
    [int]$Duration = 60,
    [string]$OutputDir = "$PSScriptRoot\pcap-output"
)

$ErrorActionPreference = "Stop"

Write-Host "=== jSS7 MAP Load Test - Direct Run ===" -ForegroundColor Green
Write-Host "TPS: $TPS, Duration: ${Duration}s" -ForegroundColor Yellow
Write-Host ""

# Calculate test parameters
$numDialogs = $TPS * $Duration
$concurrent = [math]::Min($TPS * 2, 5000)

Write-Host "Test Parameters:" -ForegroundColor Cyan
Write-Host "  Num Dialogs: $numDialogs"
Write-Host "  Concurrent: $concurrent"
Write-Host "  Target TPS: $TPS"
Write-Host ""

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$pcapFile = "$OutputDir\jss7-test-$timestamp.pcap"

# Check if running as admin (required for tcpdump on Windows)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. Tcpdump may not work properly."
}

# Start tcpdump on host (if available)
$tcpdumpProcess = $null
if (Get-Command "tcpdump" -ErrorAction SilentlyContinue) {
    Write-Host "[1/4] Starting tcpdump on host..." -ForegroundColor Cyan
    $tcpdumpProcess = Start-Process -FilePath "tcpdump" -ArgumentList "-i any -w `"$pcapFile`" -s 0 port 8011 or port 8012" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2
}
else {
    Write-Host "[1/4] tcpdump not available on host, skipping pcap capture" -ForegroundColor Yellow
}

# Alternative: Use tshark if available
if (-not $tcpdumpProcess -and (Get-Command "tshark" -ErrorAction SilentlyContinue)) {
    Write-Host "[1/4] Starting tshark on host..." -ForegroundColor Cyan
    $tcpdumpProcess = Start-Process -FilePath "tshark" -ArgumentList "-i any -w `"$pcapFile`" -f 'port 8011 or port 8012'" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

# Clean up previous runs
Write-Host "[2/4] Cleaning up previous runs..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$PSScriptRoot\server" -ErrorAction SilentlyContinue
Remove-Item -Force "$PSScriptRoot\log4j-server.log" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$PSScriptRoot\client" -ErrorAction SilentlyContinue
Remove-Item -Force "$PSScriptRoot\log4j-client.log" -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Force -Path "$PSScriptRoot\server" | Out-Null
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\client" | Out-Null

# Start server
Write-Host "[3/4] Starting Server..." -ForegroundColor Cyan
$serverJob = Start-Job -ScriptBlock {
    param($dir, $cp)
    Set-Location $dir
    $env:CLASSPATH = $cp
    & java -cp $env:CLASSPATH `
        -Xms2048m -Xmx2048m -Xmn128m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=256m `
        -XX:+UseParallelGC -XX:+HeapDumpOnOutOfMemoryError `
        -Dlog.file.name=log4j-server.log `
        org.restcomm.protocols.ss7.map.load.sms.mo.Server `
        tcp 0.0.0.0 8011 -1 127.0.0.1 8012 IPSP 101 102 1 2 3 2 8 8 16
} -ArgumentList $PSScriptRoot, (Get-Content "$PSScriptRoot\classpath.txt" -ErrorAction SilentlyContinue)

# Wait for server
Write-Host "  Waiting for server to start..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# Start client
Write-Host "[4/4] Starting Client with $TPS TPS..." -ForegroundColor Cyan
$clientStartTime = Get-Date

$clientJob = Start-Job -ScriptBlock {
    param($dir, $cp, $numDialogs, $concurrent)
    Set-Location $dir
    $env:CLASSPATH = $cp
    & java -cp $env:CLASSPATH `
        -Xms2048m -Xmx2048m -Xmn128m -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=256m `
        -XX:+UseParallelGC -XX:+HeapDumpOnOutOfMemoryError `
        -Dlog.file.name=log4j-client.log `
        org.restcomm.protocols.ss7.map.load.sms.mo.Client `
        $numDialogs $concurrent tcp 127.0.0.1 8012 -1 127.0.0.1 8011 IPSP 101 102 1 2 3 2 8 8 1111112 9960639999 1 16 -100
} -ArgumentList $PSScriptRoot, (Get-Content "$PSScriptRoot\classpath.txt" -ErrorAction SilentlyContinue), $numDialogs, $concurrent

# Monitor
Write-Host ""
Write-Host "Monitoring test..." -ForegroundColor Cyan
$maxWait = $Duration + 30
$elapsed = 0

while ($elapsed -lt $maxWait) {
    Start-Sleep -Seconds 5
    $elapsed += 5
    
    $serverStatus = if ($serverJob.State -eq 'Running') { "Running" } else { "Stopped" }
    $clientStatus = if ($clientJob.State -eq 'Running') { "Running" } else { "Stopped" }
    
    Write-Host "  Elapsed: ${elapsed}s - Server: $serverStatus, Client: $clientStatus" -ForegroundColor Gray
    
    # Check client output
    $clientOutput = $clientJob | Receive-Job -Keep 2>&1
    if ($clientOutput) {
        $lastLines = $clientOutput | Select-Object -Last 3
        Write-Host "    $lastLines" -ForegroundColor DarkGray
    }
    
    if ($clientJob.State -ne 'Running') {
        Write-Host "  Client finished!" -ForegroundColor Green
        break
    }
}

# Cleanup
Write-Host ""
Write-Host "Stopping server and tcpdump..." -ForegroundColor Cyan

if ($tcpdumpProcess) {
    Stop-Process -Id $tcpdumpProcess.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Copy pcap
    if (Test-Path $pcapFile) {
        Write-Host "✅ PCAP saved: $pcapFile" -ForegroundColor Green
        $pcapSize = (Get-Item $pcapFile).Length / 1KB
        Write-Host "   Size: $([math]::Round($pcapSize, 2)) KB" -ForegroundColor Gray
    }
}

# Stop jobs
Stop-Job -Job $serverJob, $clientJob -ErrorAction SilentlyContinue
Remove-Job -Job $serverJob, $clientJob -ErrorAction SilentlyContinue

# Copy logs
Copy-Item "$PSScriptRoot\log4j-server.log" "$OutputDir\server-$timestamp.log" -ErrorAction SilentlyContinue
Copy-Item "$PSScriptRoot\log4j-client.log" "$OutputDir\client-$timestamp.log" -ErrorAction SilentlyContinue

# Results
Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green
Write-Host "Output directory: $OutputDir" -ForegroundColor Yellow
Get-ChildItem $OutputDir | ForEach-Object {
    Write-Host "  $($_.Name)" -ForegroundColor Gray
}

# Calculate actual TPS
if (Test-Path "$OutputDir\client-$timestamp.log") {
    $logContent = Get-Content "$OutputDir\client-$timestamp.log"
    $duration = $null
    $completed = $null
    
    # Parse log for duration and completed dialogs
    foreach ($line in $logContent) {
        if ($line -match "Time:\s+(\d+)\s+sec") {
            $duration = $matches[1]
        }
        if ($line -match "Completed:\s+(\d+)") {
            $completed = $matches[1]
        }
    }
    
    if ($duration -and $completed) {
        $actualTps = [math]::Round($completed / $duration, 2)
        Write-Host ""
        Write-Host "Performance Summary:" -ForegroundColor Cyan
        Write-Host "  Target TPS: $TPS" -ForegroundColor Gray
        Write-Host "  Actual TPS: $actualTps" -ForegroundColor $(if($actualTps -ge $TPS * 0.9) { "Green" } else { "Yellow" })
        Write-Host "  Completed: $completed dialogs in $duration seconds" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "To analyze pcap:" -ForegroundColor Cyan
Write-Host "  wireshark '$pcapFile'" -ForegroundColor White
