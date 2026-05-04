#!/bin/bash
# SCTP Kernel Tuning for High-Performance SS7 Signaling
# Run as root before starting load test

echo "================================"
echo "SCTP Kernel Tuning Script"
echo "================================"

if [ "$EUID" -ne 0 ]; then
    echo "WARNING: Run as root for sysctl changes"
fi

echo ""
echo "--- Current Values ---"
sysctl net.sctp.rmem_max 2>/dev/null || echo "net.sctp.rmem_max: N/A"
sysctl net.sctp.wmem_max 2>/dev/null || echo "net.sctp.wmem_max: N/A"
sysctl net.core.rmem_max 2>/dev/null
sysctl net.core.wmem_max 2>/dev/null

echo ""
echo "--- Applying Tuning ---"

# SCTP-specific buffers
sysctl -w net.sctp.rmem_max=16777216 2>/dev/null || echo "Failed to set sctp.rmem_max"
sysctl -w net.sctp.wmem_max=16777216 2>/dev/null || echo "Failed to set sctp.wmem_max"

# Core network buffers
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.core.netdev_max_backlog=5000
sysctl -w net.core.optmem_max=65536

# TCP/SCTP general tuning (affects socket behavior)
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
sysctl -w net.ipv4.tcp_no_metrics_save=1

# Disable slow start after idle (for long-lived SCTP associations)
sysctl -w net.ipv4.tcp_slow_start_after_idle=0

# Increase local port range (for many associations)
sysctl -w net.ipv4.ip_local_port_range="1024 65535"

# File descriptor limits
ulimit -n 65535
echo "File descriptor limit: $(ulimit -n)"

echo ""
echo "--- Verify Changes ---"
sysctl net.sctp.rmem_max 2>/dev/null
sysctl net.sctp.wmem_max 2>/dev/null
sysctl net.core.rmem_max
sysctl net.core.wmem_max

echo ""
echo "--- Persist to /etc/sysctl.conf ---"
if [ "$EUID" -eq 0 ]; then
    cat >> /etc/sysctl.conf << 'EOF'

# SCTP Tuning for SS7/USSD Gateway
net.sctp.rmem_max=16777216
net.sctp.wmem_max=16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.netdev_max_backlog=5000
net.core.optmem_max=65536
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.ip_local_port_range=1024 65535
EOF
    echo "Changes persisted to /etc/sysctl.conf"
    sysctl -p
else
    echo "Run as root to persist changes"
fi

echo ""
echo "================================"
echo "SCTP Tuning Complete"
echo "================================"
