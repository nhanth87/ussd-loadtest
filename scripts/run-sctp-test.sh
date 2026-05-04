#!/bin/bash
export PATH=/opt/jdk-sctp/bin:$PATH
export JAVA_HOME=/opt/jdk-sctp

cd /opt/jss7-load-test
rm -rf server client
mkdir -p server client

echo '[1/2] Starting Server with SCTP...'
java -version

# Start tcpdump
tcpdump -i lo -w pcap-output/jss7-sctp-test.pcap -s 0 sctp or port 8011 or port 8012 2>/dev/null &
TCPDUMP_PID=$!
sleep 3

# Run server with SCTP
ant -f mo_sms_build.xml server \
    -Dtest.server.channelType=sctp \
    -Dtest.server.hostIp=0.0.0.0 \
    -Dtest.server.hostPort=8011 \
    -Dtest.server.peerIp=127.0.0.1 \
    -Dtest.server.peerPort=8012 > server.log 2>&1 &

SERVER_PID=$!
sleep 15

echo '[2/2] Starting Client with SCTP...'
ant -f mo_sms_build.xml client \
    -Dtest.client.numOfDialogs=1000 \
    -Dtest.client.concurrentDialog=100 \
    -Dtest.client.channelType=sctp \
    -Dtest.client.hostIp=127.0.0.1 \
    -Dtest.client.hostPort=8011 \
    -Dtest.client.peerIp=127.0.0.1 \
    -Dtest.client.peerPort=8012

sleep 10
echo 'Stopping server and tcpdump...'
kill $SERVER_PID 2>/dev/null || true
sleep 2
kill $TCPDUMP_PID 2>/dev/null || true

echo '=== Test Complete ==='
ls -la pcap-output/
