#!/bin/bash
# Server Performance Monitor for USSD Gateway
# Usage: ./monitor-server.sh [wildfly_pid]

WILDFLY_PID=${1:-$(pgrep -f "wildfly")}
LOG_DIR="/opt/restcomm-ussd/wildfly-10.0.0.Final/standalone/log"

if [ -z "$WILDFLY_PID" ]; then
    echo "ERROR: WildFly process not found. Is USSD Gateway running?"
    exit 1
fi

echo "================================"
echo "USSD Gateway Performance Monitor"
echo "PID: $WILDFLY_PID"
echo "Time: $(date)"
echo "================================"

echo ""
echo "--- SYSTEM ---"
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | head -1

echo ""
echo "Memory:"
free -h | grep -E "Mem|Swap"

echo ""
echo "Load Average:"
cat /proc/loadavg

echo ""
echo "--- JVM ($WILDFLY_PID) ---"
echo "GC Utilization:"
jstat -gcutil $WILDFLY_PID 1 1

echo ""
echo "Heap Capacity:"
jstat -gccapacity $WILDFLY_PID 1 1 | tail -1

echo ""
echo "Thread States:"
jstack $WILDFLY_PID 2>/dev/null | grep "java.lang.Thread.State:" | sort | uniq -c | sort -rn | head -10

echo ""
echo "Open File Descriptors:"
ls /proc/$WILDFLY_PID/fd 2>/dev/null | wc -l
cat /proc/$WILDFLY_PID/limits 2>/dev/null | grep "Max open files"

echo ""
echo "--- SCTP ---"
echo "Active Associations:"
ss -Sntpi state established 2>/dev/null | grep -c "SCTP" || echo "0"

echo ""
echo "SCTP Stats:"
cat /proc/net/sctp/snmp 2>/dev/null | head -20 || echo "N/A"

echo ""
echo "--- SS7 Stack (from logs) ---"
echo "MAP Dialog Requests:"
grep -c "onProcessUnstructuredSSRequest" $LOG_DIR/server.log 2>/dev/null || echo "0"

echo ""
echo "Completed Dialogs:"
grep -c "onDialogRelease" $LOG_DIR/server.log 2>/dev/null || echo "0"

echo ""
echo "Dialog Timeouts:"
grep -c "onDialogTimeout" $LOG_DIR/server.log 2>/dev/null || echo "0"

echo ""
echo "Dialog Rejects:"
grep -c "onDialogReject" $LOG_DIR/server.log 2>/dev/null || echo "0"

echo ""
echo "Recent Errors (last 10):"
grep -i "error\|exception" $LOG_DIR/server.log 2>/dev/null | tail -10 || echo "None"

echo ""
echo "================================"
echo "Monitor complete: $(date)"
echo "================================"
