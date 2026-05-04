#!/bin/bash
set -e

# Build USSD Load Test Suite for 10k TPS
# Builds: jSS7/map/load (ussd only) + ussdgateway/test/loadtest

echo "=========================================="
echo "USSD 10k TPS Load Test Builder"
echo "=========================================="

# Config
JSS7_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
USSDGW_DIR="${JSS7_DIR}/../ussdgateway"
JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk}
MAVEN_OPTS="${MAVEN_OPTS:--Xmx4g -XX:+UseG1GC}"

export JAVA_HOME
export MAVEN_OPTS

echo "JAVA_HOME: $JAVA_HOME"
echo "jSS7 dir: $JSS7_DIR"
echo "ussdgateway dir: $USSDGW_DIR"

# Step 1: Build jSS7 parent POMs first (if not already installed)
echo ""
echo "[1/5] Building jSS7 parent POMs..."
cd "$JSS7_DIR"
mvn install -N -DskipTests -q

# Step 2: Build MAP parent
echo ""
echo "[2/5] Building MAP parent..."
cd "$JSS7_DIR/map"
mvn install -N -DskipTests -q

# Step 3: Build map-load module with assemble profile (USSD only)
echo ""
echo "[3/5] Building map-load (USSD variant) with dependencies..."
cd "$JSS7_DIR/map/load"
mvn clean package -Passemble -DskipTests

echo ""
echo "[4/5] Building ussdgateway test/loadtest..."
cd "$USSDGW_DIR"
mvn install -N -DskipTests -q
cd "$USSDGW_DIR/test"
mvn install -N -DskipTests -q
cd "$USSDGW_DIR/test/loadtest"
mvn clean package -DskipTests

# Step 5: Package into distribution
echo ""
echo "[5/5] Packaging load test distribution..."
DIST_DIR="$USSDGW_DIR/test/loadtest/target/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/lib" "$DIST_DIR/config" "$DIST_DIR/bin"

# Copy map-load jar and deps
MAP_LOAD_DIR="$JSS7_DIR/map/load/target/load"
cp "$MAP_LOAD_DIR/map-load.jar" "$DIST_DIR/lib/"
cp "$MAP_LOAD_DIR"/*.jar "$DIST_DIR/lib/"

# Copy loadtest jar
cp "$USSDGW_DIR/test/loadtest/target/loadtest-*.jar" "$DIST_DIR/lib/loadtest.jar"

# Copy config files
cp "$JSS7_DIR/map/load/client/"*.xml "$DIST_DIR/config/" 2>/dev/null || true
cp "$JSS7_DIR/map/load/server/"*.xml "$DIST_DIR/config/" 2>/dev/null || true

# Create runner scripts
cat > "$DIST_DIR/bin/run-map-client.sh" << 'EOF'
#!/bin/bash
# Run jSS7 MAP USSD Load Client
# Usage: ./run-map-client.sh <args...>
# Args: ndialogs concurrent channel hostIp hostPort extraHost peerIp peerPort asFunctionality rc na origPc destPc si ni ussdSsn hlrSsn mscSsn clientAddr serverAddr routingIndicator deliveryThreads rampUp

DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLASSPATH="$DIR/lib/*"

java -cp "$CLASSPATH" \
  -Xms4g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=20 \
  -XX:+UnlockExperimentalVMOptions -XX:+UseStringDeduplication \
  -Dlog.file.name=client.log \
  org.restcomm.protocols.ss7.map.load.ussd.Client "$@"
EOF

cat > "$DIST_DIR/bin/run-map-server.sh" << 'EOF'
#!/bin/bash
# Run jSS7 MAP USSD Load Server
DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLASSPATH="$DIR/lib/*"

java -cp "$CLASSPATH" \
  -Xms4g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=20 \
  -Dlog.file.name=server.log \
  org.restcomm.protocols.ss7.map.load.ussd.Server "$@"
EOF

cat > "$DIST_DIR/bin/run-http-load.sh" << 'EOF'
#!/bin/bash
# Run HTTP Load Generator
# Usage: ./run-http-load.sh <url> <targetTps> [threads] [maxConcurrent]
# Example: ./run-http-load.sh http://localhost:8080/ussdhttpdemo/ 10000 20 50000

DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLASSPATH="$DIR/lib/*"

java -cp "$CLASSPATH" \
  -Xms4g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=20 \
  -XX:+UnlockExperimentalVMOptions -XX:+UseStringDeduplication \
  org.mobicents.ussd.loadtest.UssdHttpLoadGenerator "$@"
EOF

chmod +x "$DIST_DIR/bin/"*.sh

# Create README
cat > "$DIST_DIR/README-10k-TPS.md" << 'EOF'
# USSD 10k TPS Load Test Suite

## Quick Start

### 1. MAP Load Test (SS7 Protocol Level)

Start server (on target machine or separate node):
```bash
./bin/run-map-server.sh \
  sctp 127.0.0.1 8012 -1 127.0.0.1 8011 IPSP 101 102 1 2 3 2 147 6 8 \
  16
```

Start client (load generator):
```bash
./bin/run-map-client.sh \
  1000000 10000 sctp 127.0.0.1 8011 -1 127.0.0.1 8012 IPSP 101 102 1 2 3 2 147 6 8 \
  1111112 9960639999 1 16 -100
```

Arguments explained:
- `1000000` - Total dialogs to send
- `10000` - Max concurrent dialogs
- `sctp` - Channel type (sctp/tcp)
- `127.0.0.1:8011` - Client local endpoint
- `127.0.0.1:8012` - Server peer endpoint
- `IPSP` - M3UA functionality (AS/SGW/IPSP)
- `101/102` - Routing context / Network appearance
- `1/2` - Originating / Destination point codes
- `3/2` - Service indicator / Network indicator
- `147/6/8` - USSD/HLR/MSC SSNs
- `1111112/9960639999` - SCCP client/server addresses
- `1` - Routing indicator (1=PC+SSN, 0=GT)
- `16` - Delivery transfer message threads
- `-100` - Ramp up period (-100 = immediate)

### 2. HTTP Load Test (Application Level)

Requires USSD Gateway running with HTTP endpoint (e.g. ussdhttpdemo.war deployed).

```bash
./bin/run-http-load.sh http://localhost:8080/ussdhttpdemo/ 10000 20 50000
```

Arguments:
- `http://localhost:8080/ussdhttpdemo/` - HTTP endpoint URL
- `10000` - Target TPS
- `20` - Worker threads
- `50000` - Max concurrent requests

## Performance Tuning for 10k TPS

### JVM Options (already set in scripts)
```
-Xms4g -Xmx4g
-XX:+UseG1GC
-XX:MaxGCPauseMillis=20
-XX:+UseStringDeduplication
```

### Linux OS Tuning
```bash
# Network buffers
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.core.netdev_max_backlog=65536
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr

# File descriptors
ulimit -n 1000000

# CPU governor
sudo cpupower frequency-set -g performance

# Disable swap
sudo swapoff -a
```

### USSD Gateway Server Tuning
```bash
# WildFly standalone.conf
JAVA_OPTS="$JAVA_OPTS -Xms8g -Xmx8g -XX:+UseG1GC -XX:MaxGCPauseMillis=50"
JAVA_OPTS="$JAVA_OPTS -Dorg.jboss.modcluster.cluster.UssdCluster-default-1.maxThreads=500"
```

## Architecture

```
┌─────────────────┐     SCTP/M3UA/SCCP/TCAP/MAP     ┌─────────────────┐
│  MAP Client     │ ◄──────────────────────────────► │  MAP Server     │
│  (jSS7 stack)   │                                   │  (USSD GW)      │
└─────────────────┘                                   └─────────────────┘
        │                                                    │
        │ HTTP POST (XmlMAPDialog)                            │
        ▼                                                    ▼
┌─────────────────┐                                   ┌─────────────────┐
│  HTTP Client    │ ────────────────────────────────► │  HTTP Servlet   │
│  (OkHttp)       │                                   │  (ussdhttpdemo) │
└─────────────────┘                                   └─────────────────┘
```

## Monitoring

Watch TPS in real-time:
```bash
tail -f client.log | grep "Throughput"
tail -f http-load.log | grep "TPS"
```

Check network:
```bash
ss -tin | grep sctp
watch -n1 'cat /proc/net/sctp/snmp'
```
EOF

# Create tarball
cd "$DIST_DIR/.."
tar czf ussd-10k-loadtest.tar.gz dist/

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo "Distribution: $USSDGW_DIR/test/loadtest/target/ussd-10k-loadtest.tar.gz"
echo ""
echo "Contents:"
ls -lh "$DIST_DIR/lib/" | head -20
echo "..."
echo ""
echo "Next steps:"
echo "  1. Copy ussd-10k-loadtest.tar.gz to Linux test machine"
echo "  2. tar xzf ussd-10k-loadtest.tar.gz"
echo "  3. cd dist && ./bin/run-map-client.sh ..."
echo "     or ./bin/run-http-load.sh ..."
