#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
cd /mnt/c/Users/Windows/Desktop/ethiopia-working-dir/jSS7/map/load
rm -rf server client pcap-output/*
mkdir -p server client pcap-output

echo '[1/3] SCTP Check:'
checksctp
java -version 2>&1 | head -1

echo '[2/3] Starting Server...'
tcpdump -i any -w pcap-output/jss7-sctp.pcap -s 0 sctp or port 8011 2>/dev/null &
sleep 3

ant -f mo_sms_build.xml server -Dtest.server.channelType=sctp -Dtest.server.hostIp=127.0.0.1 -Dtest.server.hostPort=8011 > server.log 2>&1 &
SERVER=$!
sleep 15

echo '[3/3] Starting Client...'
timeout 60 ant -f mo_sms_build.xml client -Dtest.client.numOfDialogs=500 -Dtest.client.concurrentDialog=50 -Dtest.client.channelType=sctp -Dtest.client.hostIp=127.0.0.1 -Dtest.client.hostPort=8011 2>&1 | tail -30

sleep 5
kill $SERVER 2>/dev/null
killall tcpdump 2>/dev/null

echo '=== Results ==='
ls -lh pcap-output/
