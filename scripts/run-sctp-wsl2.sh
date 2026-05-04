#!/bin/bash
# Run jSS7 MAP Load Test using WSL2 JDK with SCTP support

set -e

echo "=== jSS7 MAP Load Test - SCTP via WSL2 JDK ==="

# Use WSL2 JDK with SCTP support
export JAVA_HOME=/mnt/wsl/openjdk-17
export PATH=$JAVA_HOME/bin:$PATH

# Create symlink to WSL2 JDK
mkdir -p /mnt/wsl
cp -r /usr/lib/jvm/java-17-openjdk-amd64 /mnt/wsl/openjdk-17 2>/dev/null || true

cd /opt/jss7-load-test

# Clean up
rm -rf server client log4j-*.log
mkdir -p server client

# Start tcpdump for pcap capture
tcpdump -i lo -w pcap-output/jss7-sctp-test.pcap -s 0 sctp or port 8011 or port 8012 2>/dev/null &
TCPDUMP_PID=$!
sleep 3

echo "[1/2] Starting Server with SCTP..."
ant -f mo_sms_build.xml server \
    -Dtest.server.channelType=sctp \
    -Dtest.server.hostIp=0.0.0.0 \
    -Dtest.server.hostPort=8011 \
    -Dtest.server.peerIp=127.0.0.1 \
    -Dtest.server.peerPort=8012 > server.log 2>&1 &
SERVER_PID=$!

# Wait for server
sleep 15

echo "[2/2] Starting Client with SCTP..."
ant -f mo_sms_build.xml client \
    -Dtest.client.numOfDialogs=1000 \
    -Dtest.client.concurrentDialog=100 \
    -Dtest.client.channelType=sctp \
    -Dtest.client.hostIp=127.0.0.1 \
    -Dtest.client.hostPort=8011 \
    -Dtest.client.peerIp=127.0.0.1 \
    -Dtest.client.peerPort=8012

# Wait for test
sleep 10

# Cleanup
echo "Stopping server and tcpdump..."
kill $SERVER_PID 2>/dev/null || true
sleep 2
kill $TCPDUMP_PID 2>/dev/null || true

echo "=== Test Complete ==="
ls -la pcap-output/
