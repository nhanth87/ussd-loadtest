# PowerShell script to run jSS7 load test with pcap capture
# For Windows with Docker Desktop

param(
    [int]$TPS = 1000,
    [int]$Duration = 60,
    [string]$OutputDir = "$PSScriptRoot\pcap-output"
)

$ErrorActionPreference = "Stop"

Write-Host "=== jSS7 MAP Load Test with PCAP Capture ===" -ForegroundColor Green
Write-Host "TPS: $TPS"
Write-Host "Duration: $Duration seconds"
Write-Host ""

# Calculate parameters for 1000 TPS
# TPS = numOfDialogs / duration
$numDialogs = $TPS * $Duration
$concurrentDialogs = [math]::Min($TPS * 2, 10000)  # 2x TPS for concurrency, max 10000

Write-Host "Test Parameters:" -ForegroundColor Yellow
Write-Host "  Num Dialogs: $numDialogs"
Write-Host "  Concurrent Dialogs: $concurrentDialogs"
Write-Host "  Target TPS: $TPS"
Write-Host ""

# Create output directory
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Write-Host "Output directory: $OutputDir" -ForegroundColor Gray

# Create network
Write-Host "[1/5] Creating Docker network..." -ForegroundColor Cyan
$networkName = "jss7-test-net"
docker network rm $networkName 2>$null
docker network create --driver bridge $networkName

# Start server with tcpdump sidecar
Write-Host "[2/5] Starting Server with PCAP capture..." -ForegroundColor Cyan
$serverContainer = "jss7-server"
docker rm -f $serverContainer 2>$null

# Run server
docker run -d --rm `
    --name $serverContainer `
    --network $networkName `
    -p 8011:8011 `
    -p 8012:8012 `
    -e TEST_SERVER_HOST_IP=0.0.0.0 `
    -e TEST_SERVER_HOST_PORT=8011 `
    -e TEST_SERVER_PEER_IP=127.0.0.1 `
    -e TEST_SERVER_PEER_PORT=8012 `
    -e TEST_SERVER_AS_FUNCTIONALITY=IPSP `
    -e TEST_SERVER_ORIGINATING_PC=1 `
    -e TEST_SERVER_DESTINATION_PC=2 `
    -e TEST_SERVER_SSN=8 `
    -e TEST_SERVER_REMOTE_SSN=8 `
    jss7-map-load-test:latest server

# Wait for server to start
Write-Host "  Waiting for server to start..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# Start tcpdump in server container for pcap capture
Write-Host "  Starting tcpdump capture..." -ForegroundColor Gray
docker exec -d $serverContainer sh -c "tcpdump -i any -w /tmp/jss7-server.pcap -s 0 tcp port 8011 or tcp port 8012 or sctp 2>/dev/null || tcpdump -i any -w /tmp/jss7-server.pcap -s 0 port 8011 or port 8012"

Start-Sleep -Seconds 2

# Start client
Write-Host "[3/5] Starting Client with $TPS TPS..." -ForegroundColor Cyan
$clientContainer = "jss7-client"
docker rm -f $clientContainer 2>$null

# Calculate ramp up (negative value in original script)
$rampUp = -100  # Enable single dialog injection mode for high TPS

docker run -d --rm `
    --name $clientContainer `
    --network $networkName `
    -e TEST_CLIENT_NUM_OF_DIALOGS=$numDialogs `
    -e TEST_CLIENT_CONCURRENT_DIALOG=$concurrentDialogs `
    -e TEST_CLIENT_CHANNEL_TYPE=tcp `
    -e TEST_CLIENT_HOST_IP=$serverContainer `
    -e TEST_CLIENT_HOST_PORT=8011 `
    -e TEST_CLIENT_PEER_IP=$serverContainer `
    -e TEST_CLIENT_PEER_PORT=8012 `
    -e TEST_CLIENT_AS_FUNCTIONALITY=IPSP `
    -e TEST_CLIENT_ORIGINATING_PC=1 `
    -e TEST_CLIENT_DESTINATION_PC=2 `
    -e TEST_CLIENT_SSN=8 `
    -e TEST_CLIENT_REMOTE_SSN=8 `
    -e TEST_CLIENT_CLIENT_ADDRESS=1111112 `
    -e TEST_CLIENT_SERVER_ADDRESS=9960639999 `
    jss7-map-load-test:latest client

# Monitor test progress
Write-Host "[4/5] Running test for ~$Duration seconds..." -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date
$lastStats = ""

while ($true) {
    Start-Sleep -Seconds 5
    
    # Get elapsed time
    $elapsed = (Get-Date) - $startTime
    $elapsedSeconds = [math]::Floor($elapsed.TotalSeconds)
    
    # Check if containers are still running
    $serverRunning = docker ps -q -f name=$serverContainer 2>$null
    $clientRunning = docker ps -q -f name=$clientContainer 2>$null
    
    if (-not $clientRunning) {
        Write-Host "  Client finished after $elapsedSeconds seconds" -ForegroundColor Green
        break
    }
    
    # Show progress
    Write-Host "  Elapsed: ${elapsedSeconds}s / ${Duration}s - Containers running: Server=$([bool]$serverRunning), Client=$([bool]$clientRunning)" -ForegroundColor Gray
    
    # Get client logs last lines
    $logs = docker logs --tail 3 $clientContainer 2>&1
    if ($logs) {
        Write-Host "    Client: $logs" -ForegroundColor DarkGray
    }
    
    # Timeout check
    if ($elapsedSeconds -gt ($Duration + 30)) {
        Write-Host "  Timeout reached, stopping..." -ForegroundColor Yellow
        break
    }
}

# Stop tcpdump and copy pcap
Write-Host ""
Write-Host "[5/5] Stopping capture and copying pcap..." -ForegroundColor Cyan

# Stop tcpdump
docker exec $serverContainer sh -c "pkill tcpdump || true"
Start-Sleep -Seconds 2

# Copy pcap file
docker cp "${serverContainer}:/tmp/jss7-server.pcap" "$OutputDir\jss7-server-$((Get-Date -Format 'yyyyMMdd-HHmmss')).pcap"

# Copy logs
docker cp "${serverContainer}:/opt/jss7-load-test/log4j-server.log" "$OutputDir\server.log" 2>$null
docker cp "${clientContainer}:/opt/jss7-load-test/log4j-client.log" "$OutputDir\client.log" 2>$null

# Cleanup
Write-Host "  Cleaning up containers..." -ForegroundColor Gray
docker stop $serverContainer $clientContainer 2>$null
docker rm -f $serverContainer $clientContainer 2>$null
docker network rm $networkName 2>$null

# Show results
Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green
Write-Host "Output files in: $OutputDir" -ForegroundColor Yellow
Get-ChildItem $OutputDir | ForEach-Object {
    $size = [math]::Round($_.Length / 1KB, 2)
    Write-Host "  $($_.Name) - ${size} KB" -ForegroundColor Gray
}

# Verify pcap
$pcapFile = Get-ChildItem "$OutputDir\*.pcap" | Select-Object -First 1
if ($pcapFile -and $pcapFile.Length -gt 100) {
    Write-Host ""
    Write-Host "✅ PCAP capture successful: $($pcapFile.Name)" -ForegroundColor Green
    Write-Host "   Use Wireshark to analyze: wireshark '$($pcapFile.FullName)'" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "⚠️ PCAP file may be empty or missing" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Commands to analyze:" -ForegroundColor Cyan
Write-Host "  # View summary" -ForegroundColor Gray
Write-Host "  capinfos '$($pcapFile.FullName)'" -ForegroundColor White
Write-Host "  # Extract MAP packets" -ForegroundColor Gray
Write-Host "  tshark -r '$($pcapFile.FullName)' -Y 'tcap'" -ForegroundColor White
