#!/bin/bash
# Live Performance Dashboard for USSD Load Test
# Run this in a dedicated terminal during the test

WILDFLY_PID=""
CLIENT_PID=""
LOG_DIR="/opt/restcomm-ussd/wildfly-10.0.0.Final/standalone/log"
CLIENT_DIR="/opt/paic/map-load/client"

refresh_pids() {
    WILDFLY_PID=$(pgrep -f "wildfly" | head -1)
    CLIENT_PID=$(pgrep -f "org.restcomm.protocols.ss7.map.load.ussd.Client" | head -1)
}

while true; do
    refresh_pids
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║     USSD GATEWAY + MAP LOAD TEST - LIVE DASHBOARD            ║"
    echo "║     $(date '+%Y-%m-%d %H:%M:%S')                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"

    echo ""
    echo "--- SYSTEM ---"
    printf "CPU Usage:    %s\n" "$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | sed 's/%us,//' | head -1)"
    printf "Memory Used:  %s\n" "$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    printf "Load Avg:     %s\n" "$(cat /proc/loadavg | awk '{print $1, $2, $3}')"

    echo ""
    echo "--- SERVER JVM (PID: ${WILDFLY_PID:-N/A}) ---"
    if [ -n "$WILDFLY_PID" ]; then
        GC=$(jstat -gcutil $WILDFLY_PID 1 1 2>/dev/null | tail -1)
        if [ -n "$GC" ]; then
            HEAP_USED=$(echo "$GC" | awk '{printf "%.1f%%", $3+$4+$6+$8}')
            GC_TIME=$(echo "$GC" | awk '{print $9}')
            printf "Heap Used:    %s\n" "$HEAP_USED"
            printf "GC Time:      %s%%\n" "$GC_TIME"
        fi
        printf "Open FDs:     %s\n" "$(ls /proc/$WILDFLY_PID/fd 2>/dev/null | wc -l)"
    fi

    echo ""
    echo "--- SCTP ---"
    printf "Assocations:  %s\n" "$(ss -Sntpi state established 2>/dev/null | grep -c 'SCTP' || echo 0)"

    echo ""
    echo "--- SS7 DIALOGS (Server) ---"
    REQ=$(grep -c "onProcessUnstructuredSSRequest" $LOG_DIR/server.log 2>/dev/null || echo 0)
    REL=$(grep -c "onDialogRelease" $LOG_DIR/server.log 2>/dev/null || echo 0)
    TOUT=$(grep -c "onDialogTimeout" $LOG_DIR/server.log 2>/dev/null || echo 0)
    REJ=$(grep -c "onDialogReject" $LOG_DIR/server.log 2>/dev/null || echo 0)
    printf "Requests:     %d\n" "$REQ"
    printf "Completed:    %d\n" "$REL"
    printf "Timeouts:     %d\n" "$TOUT"
    printf "Rejects:      %d\n" "$REJ"

    echo ""
    echo "--- CLIENT (PID: ${CLIENT_PID:-N/A}) ---"
    if [ -n "$CLIENT_PID" ]; then
        printf "CPU:          %s%%\n" "$(pidstat -u -p $CLIENT_PID 1 1 2>/dev/null | tail -1 | awk '{print $4}')"
    fi
    if [ -f "$CLIENT_DIR/map.csv" ]; then
        LAST=$(tail -1 $CLIENT_DIR/map.csv 2>/dev/null)
        printf "CSV Last:     %s\n" "$LAST"
    fi
    TPUT=$(grep "Throughput" $CLIENT_DIR/log4j-client.log 2>/dev/null | tail -1 | awk '{print $NF}')
    printf "Throughput:   %s\n" "${TPUT:-N/A}"

    echo ""
    echo "Press Ctrl+C to stop"
    sleep 5
done
