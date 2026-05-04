#!/bin/bash
# Run jSS7 MAP Load Test with TCP mode and pcap capture

set -e

echo "=== jSS7 MAP Load Test - TCP Mode ==="
echo "Starting server and client with TCP..."

# Create output directory
mkdir -p pcap-output

# Start tcpdump in background for pcap capture
echo "[1/3] Starting tcpdump..."
tcpdump -i lo -w /opt/jss7-load-test/pcap-output/jss7-test.pcap -s 0 port 8011 or port 8012 &
TCPDUMP_PID=$!
sleep 2

# Clean up
echo "[2/3] Cleaning up..."
rm -rf server client log4j-*.log
mkdir -p server client

# Start server in background
echo "[3/3] Starting Server..."
cd /opt/jss7-load-test
ant -f mo_sms_build.xml server \
    -Dtest.server.channelType=tcp \
    -Dtest.server.hostIp=0.0.0.0 \
    -Dtest.server.hostPort=8011 \
    -Dtest.server.peerIp=127.0.0.1 \
    -Dtest.server.peerPort=8012 &
SERVER_PID=$!

# Wait for server
echo "Waiting for server to start..."
sleep 10

# Start client
echo "Starting Client..."
ant -f mo_sms_build.xml client \
    -Dtest.client.numOfDialogs=10000 \
    -Dtest.client.concurrentDialog=1000 \
    -Dtest.client.channelType=tcp \
    -Dtest.client.hostIp=127.0.0.1 \
    -Dtest.client.hostPort=8011 \
    -Dtest.client.peerIp=127.0.0.1 \
    -Dtest.client.peerPort=8012

# Wait for client to finish
echo "Test completed, stopping server..."
sleep 5

# Stop server
kill $SERVER_PID 2>/dev/null || true

# Stop tcpdump
sleep 2
kill $TCPDUMP_PID 2>/dev/null || true

echo "=== Test Complete ==="
echo "PCAP file: /opt/jss7-load-test/pcap-output/jss7-test.pcap"
ls -la /opt/jss7-load-test/pcap-output/
