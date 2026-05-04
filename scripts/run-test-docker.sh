#!/bin/bash
# Run jSS7 MAP Load Test with 1000 TPS and PCAP capture
# Usage: ./run-test-docker.sh [TPS] [DURATION]

set -e

TPS=${1:-1000}
DURATION=${2:-60}
OUTPUT_DIR="./pcap-output"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== jSS7 MAP Load Test - 1000 TPS with PCAP ==="
echo "TPS: $TPS, Duration: ${DURATION}s"
echo ""

# Calculate parameters
NUM_DIALOGS=$((TPS * DURATION))
CONCURRENT=$((TPS * 2))
if [ $CONCURRENT -gt 5000 ]; then
    CONCURRENT=5000
fi

echo "Test Parameters:"
echo "  Num Dialogs: $NUM_DIALOGS"
echo "  Concurrent: $CONCURRENT"
echo "  Target TPS: $TPS"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
PCAP_FILE="$OUTPUT_DIR/jss7-test-$TIMESTAMP.pcap"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker not found"
    exit 1
fi

# Check if image exists
if ! docker images | grep -q "jss7-map-load-test"; then
    echo "Building Docker image..."
    docker build -t jss7-map-load-test:latest .
fi

# Create network
docker network rm jss7-test-net 2>/dev/null || true
docker network create --driver bridge jss7-test-net

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    docker stop jss7-server jss7-client 2>/dev/null || true
    docker rm jss7-server jss7-client 2>/dev/null || true
    docker network rm jss7-test-net 2>/dev/null || true
    
    # Stop tcpdump
    if [ -n "$TCPDUMP_PID" ]; then
        kill $TCPDUMP_PID 2>/dev/null || true
        sleep 2
    fi
}
trap cleanup EXIT

# Start server
echo "[1/5] Starting Server container..."
docker run -d --rm \
    --name jss7-server \
    --network jss7-test-net \
    --cap-add=NET_RAW \
    --cap-add=NET_ADMIN \
    -p 8011:8011 \
    -p 8012:8012 \
    -e TEST_SERVER_CHANNEL_TYPE=tcp \
    -e TEST_SERVER_HOST_IP=0.0.0.0 \
    -e TEST_SERVER_HOST_PORT=8011 \
    -e TEST_SERVER_PEER_IP=127.0.0.1 \
    -e TEST_SERVER_PEER_PORT=8012 \
    -e TEST_SERVER_AS_FUNCTIONALITY=IPSP \
    jss7-map-load-test:latest server

sleep 5

# Start tcpdump in server container
echo "[2/5] Starting tcpdump capture..."
docker exec -d jss7-server tcpdump -i any -w /tmp/jss7-capture.pcap -s 0 tcp port 8011 or tcp port 8012 2>/dev/null || true

sleep 2

# Start client
echo "[3/5] Starting Client with $TPS TPS..."
docker run -d --rm \
    --name jss7-client \
    --network jss7-test-net \
    -e TEST_CLIENT_NUM_OF_DIALOGS=$NUM_DIALOGS \
    -e TEST_CLIENT_CONCURRENT_DIALOG=$CONCURRENT \
    -e TEST_CLIENT_CHANNEL_TYPE=tcp \
    -e TEST_CLIENT_HOST_IP=jss7-server \
    -e TEST_CLIENT_HOST_PORT=8011 \
    -e TEST_CLIENT_PEER_IP=jss7-server \
    -e TEST_CLIENT_PEER_PORT=8012 \
    -e TEST_CLIENT_AS_FUNCTIONALITY=IPSP \
    jss7-map-load-test:latest client

# Monitor
echo "[4/5] Running test..."
elapsed=0
while [ $elapsed -lt $((DURATION + 30)) ]; do
    sleep 5
    elapsed=$((elapsed + 5))
    
    # Check client status
    if ! docker ps | grep -q jss7-client; then
        echo "  Client finished after ${elapsed}s"
        break
    fi
    
    echo "  Elapsed: ${elapsed}s"
done

# Stop tcpdump and copy pcap
echo "[5/5] Saving PCAP..."
docker exec jss7-server pkill tcpdump 2>/dev/null || true
sleep 2

docker cp jss7-server:/tmp/jss7-capture.pcap "$PCAP_FILE" 2>/dev/null || true
docker cp jss7-server:/opt/jss7-load-test/log4j-server.log "$OUTPUT_DIR/server-$TIMESTAMP.log" 2>/dev/null || true
docker cp jss7-client:/opt/jss7-load-test/log4j-client.log "$OUTPUT_DIR/client-$TIMESTAMP.log" 2>/dev/null || true

# Results
echo ""
echo "=== Test Complete ==="
echo "Output: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR/"

if [ -f "$PCAP_FILE" ]; then
    PCAP_SIZE=$(du -h "$PCAP_FILE" | cut -f1)
    echo ""
    echo "✅ PCAP captured: $PCAP_FILE ($PCAP_SIZE)"
    echo "   Analyze with: wireshark '$PCAP_FILE'"
    echo "   Or: tshark -r '$PCAP_FILE' -Y 'tcap'"
fi

echo ""
echo "To factcheck:"
echo "  1. Open pcap in Wireshark"
echo "  2. Filter: tcap or diameter or sctp"
echo "  3. Check Statistics > IO Graphs for TPS"
