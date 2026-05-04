#!/bin/bash
# Client Performance Monitor for MAP Load Test
# Usage: ./monitor-client.sh [client_pid]

CLIENT_PID=${1:-$(pgrep -f "org.restcomm.protocols.ss7.map.load.ussd.Client")}
CLIENT_DIR="/opt/paic/map-load/client"

if [ -z "$CLIENT_PID" ]; then
    echo "WARNING: Client process not found. Is load test running?"
fi

echo "================================"
echo "MAP Load Test Client Monitor"
echo "PID: ${CLIENT_PID:-N/A}"
echo "Time: $(date)"
echo "================================"

echo ""
echo "--- CLIENT JVM ---"
if [ -n "$CLIENT_PID" ]; then
    echo "GC Utilization:"
    jstat -gcutil $CLIENT_PID 1 1

    echo ""
    echo "Thread States:"
    jstack $CLIENT_PID 2>/dev/null | grep "java.lang.Thread.State:" | sort | uniq -c | sort -rn | head -10

    echo ""
    echo "CPU Usage (per thread):"
    pidstat -u -p $CLIENT_PID 1 1 2>/dev/null | tail -5
fi

echo ""
echo "--- THROUGHPUT METRICS ---"
echo "Instant Rates (dialogs/sec):"
grep "dialogs per second" $CLIENT_DIR/log4j-client.log 2>/dev/null | tail -5 || echo "N/A"

echo ""
echo "Final Throughput:"
grep "Throughput" $CLIENT_DIR/log4j-client.log 2>/dev/null | tail -1 || echo "N/A"

echo ""
echo "Total Completed Dialogs:"
grep "completed dialogs" $CLIENT_DIR/log4j-client.log 2>/dev/null | tail -1 || echo "N/A"

echo ""
echo "--- CSV COUNTERS ---"
echo "Last 5 CSV entries (Created, Completed, Failed):"
tail -5 $CLIENT_DIR/map.csv 2>/dev/null || echo "N/A"

echo ""
echo "--- ERRORS ---"
echo "Dialog Rejects:"
grep -c "onDialogReject" $CLIENT_DIR/log4j-client.log 2>/dev/null || echo "0"

echo ""
echo "Dialog Timeouts:"
grep -c "onDialogTimeout" $CLIENT_DIR/log4j-client.log 2>/dev/null || echo "0"

echo ""
echo "Send Exceptions:"
grep -c "Exception when sending" $CLIENT_DIR/log4j-client.log 2>/dev/null || echo "0"

echo ""
echo "Recent Errors (last 5):"
grep -i "error" $CLIENT_DIR/log4j-client.log 2>/dev/null | tail -5 || echo "None"

echo ""
echo "================================"
echo "Monitor complete: $(date)"
echo "================================"
