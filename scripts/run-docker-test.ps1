# PowerShell script to run jSS7 MAP Load Test in Docker
param(
    [int]$Dialogs = 1000,
    [int]$Concurrent = 100
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDir = "$PSScriptRoot\pcap-output"

# Create output directory
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host "=== jSS7 MAP Load Test - Docker Mode ===" -ForegroundColor Green
Write-Host "Dialogs: $Dialogs, Concurrent: $Concurrent" -ForegroundColor Yellow
Write-Host ""

# Run test in Docker
$dockerCmd = @"
docker run --rm --name jss7-load-test `
  -e TEST_SERVER_CHANNEL_TYPE=tcp `
  -e TEST_CLIENT_CHANNEL_TYPE=tcp `
  -e TEST_CLIENT_NUM_OF_DIALOGS=$Dialogs `
  -e TEST_CLIENT_CONCURRENT_DIALOG=$Concurrent `
  jss7-sctp:latest bash -c '
    cd /opt/jss7-load-test
    rm -rf server client log4j-*.log
    mkdir -p server client
    
    # Start tcpdump
    tcpdump -i lo -w pcap-output/test-$timestamp.pcap -s 0 tcp port 8011 or 8012 2>/dev/null &
    TCPDUMP_PID=\$!
    sleep 3
    
    # Start server
    echo "Starting Server..."
    ant -f mo_sms_build.xml server -Dtest.server.channelType=tcp > server.log 2>&1 &
    SERVER_PID=\$!
    sleep 10
    
    # Start client
    echo "Starting Client..."
    timeout 120 ant -f mo_sms_build.xml client -Dtest.client.numOfDialogs=$Dialogs -Dtest.client.concurrentDialog=$Concurrent -Dtest.client.channelType=tcp 2>&1 || true
    
    sleep 5
    kill \$SERVER_PID 2>/dev/null || true
    sleep 2
    kill \$TCPDUMP_PID 2>/dev/null || true
    
    # Copy logs
    cp log4j-*.log pcap-output/ 2>/dev/null || true
    cp server.log pcap-output/ 2>/dev/null || true
    
    echo "Test complete!"
    ls -la pcap-output/
  '
"@

Invoke-Expression $dockerCmd

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green
if (Test-Path "$outputDir\test-$timestamp.pcap") {
    Write-Host "PCAP file created: test-$timestamp.pcap" -ForegroundColor Green
}
