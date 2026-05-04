#!/bin/bash
# USSD MAP Load Test - Duration-based mode
# Usage: ./run-duration-test.sh <duration_minutes> [target_ip] [target_port]
#   duration_minutes: 10, 30, or 60
#   target_ip: default 127.0.0.1
#   target_port: default 8012

set -e

DURATION=${1:-10}
TARGET_IP=${2:-127.0.0.1}
TARGET_PORT=${3:-8012}

case $DURATION in
  10|30|60)
    echo "Running USSD MAP Load Test for ${DURATION} minutes..."
    ;;
  *)
    echo "Error: Duration must be 10, 30, or 60 minutes"
    echo "Usage: $0 <10|30|60> [target_ip] [target_port]"
    exit 1
    ;;
esac

cd "$(dirname "$0")/.."

# Duration mode: NDIALOGS set to very high number, test stops by time
# Args: numOfDialogs concurrentDialog channelType hostIp hostPort extraHost peerIp peerPort
#       asFunctionality rc na origPc destPc si ni ussdSsn hlrSsn mscSsn
#       clientAddress serverAddress routingIndicator deliveryThreads rampUpPeriod durationMinutes

java -Xms4g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=20 \
  -cp "lib/*" \
  -Dlog.file.name=log4j-client-duration-${DURATION}m.log \
  org.restcomm.protocols.ss7.map.load.ussd.Client \
  99999999 10000 sctp 127.0.0.1 8011 -1 ${TARGET_IP} ${TARGET_PORT} \
  IPSP 101 102 1 2 3 2 147 6 8 \
  1111112 9960639999 1 16 -100 ${DURATION}

echo "Load test completed. Check log4j-client-duration-${DURATION}m.log for results."
