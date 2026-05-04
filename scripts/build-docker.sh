#!/bin/bash
# Build Docker image for jSS7 MAP Load Test

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "=== Building jSS7 MAP Load Test Docker Image ==="
echo ""

# Step 1: Build Maven project with assemble profile
echo "[1/3] Building Maven project and assembling JARs..."
mvn clean install -DskipTests
mvn install -Passemble -DskipTests

# Step 2: Check if target/load exists
if [ ! -d "target/load" ]; then
    echo "ERROR: target/load directory not found!"
    echo "Make sure Maven build succeeded."
    exit 1
fi

# List assembled JARs
echo ""
echo "Assembled JARs:"
ls -la target/load/*.jar | wc -l
echo ""

# Step 3: Build Docker image
echo "[2/3] Building Docker image..."
docker build -t jss7-map-load-test:latest .

# Step 4: Verify image
echo ""
echo "[3/3] Verifying Docker image..."
docker images jss7-map-load-test:latest

echo ""
echo "=== Build Complete ==="
echo ""
echo "To run the load test server:"
echo "  docker run -it --rm -p 8011:8011 -p 8012:8012 jss7-map-load-test:latest server"
echo ""
echo "To run the load test client:"
echo "  docker run -it --rm jss7-map-load-test:latest client"
echo ""
echo "To run with custom configuration:"
echo "  docker run -it --rm -e TEST_SERVER_HOST_IP=0.0.0.0 -e TEST_SERVER_PEER_IP=192.168.1.100 jss7-map-load-test:latest server"
echo ""
echo "Or use docker-compose:"
echo "  docker-compose up"
