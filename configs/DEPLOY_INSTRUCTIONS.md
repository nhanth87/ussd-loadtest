# USSD Gateway Jackson XML Config Deploy Guide

## Problem
The server-side config files were in **javolution/XStream format** (old RestComm project), but the current fork uses **Jackson XML** for persistence. This caused:
- M3UA config not loading → ASP Factory not created → SCTP association not started
- Server rejecting client connections with: `Received connect request for Association=ass1 but not started yet. Dropping the connection!`

## Solution
Replace ALL config files in `~/ussdgateway/wildfly-10.0.0.Final/standalone/data/` with the new Jackson-compatible versions.

## Files to Deploy

| File | Format | Description |
|------|--------|-------------|
| `SCTPManagement_sctp.xml` | Jackson XML | SCTP server + association config |
| `Mtp3UserPart_m3ua1.xml` | Jackson XML | M3UA ASP Factory + AS + Route config |
| `SccpStack_management2.xml` | Jackson XML | SCCP stack parameters |
| `SccpStack_sccpresource3.xml` | StAX XML v3 | SCCP remote SSNs/SPCs |
| `SccpStack_sccprouter4.xml` | StAX XML v4 | SCCP SAPs + destinations |
| `TcapStack_management.xml` | Jackson XML | TCAP timers |
| `MapStack_management.xml` | Jackson XML | MAP timers |
| `UssdManagement_ussdproperties.xml` | Jackson XML | USSD GW properties |
| `UssdManagement_scroutingrule.xml` | Jackson XML | USSD routing rules |

## Deploy Steps

### 1. Stop WildFly
```bash
# On server
~/ussdgateway/wildfly-10.0.0.Final/bin/jboss-cli.sh --connect command=:shutdown
```

### 2. Backup old configs
```bash
cd ~/ussdgateway/wildfly-10.0.0.Final/standalone/data/
mkdir -p backup-javolution-$(date +%Y%m%d)
cp *.xml backup-javolution-$(date +%Y%m%d)/
```

### 3. Copy new configs
Upload `ussdgw-jackson-configs.zip` to server, then:
```bash
cd ~/ussdgateway/wildfly-10.0.0.Final/standalone/data/
unzip -o /path/to/ussdgw-jackson-configs.zip
```

### 4. Remove old/backup config files (IMPORTANT)
Delete old format files to prevent conflicts:
```bash
cd ~/ussdgateway/wildfly-10.0.0.Final/standalone/data/
rm -f SccpStack_sccpresource2.xml SccpStack_sccprouter2.xml SccpStack_sccprouter3.xml
```

### 5. Start WildFly
```bash
~/ussdgateway/wildfly-10.0.0.Final/bin/standalone.sh -b 0.0.0.0 &
```

### 6. Verify
Check server logs for:
```
INFO  [SCTP] Association=ass1 started
INFO  [M3UA] AspFactory=asp1 started
INFO  [TCAP] TCAP Stack started
INFO  [MAP] MAP Stack started
INFO  [USSD] UssdManagement started
```

## Config Values Summary

### SCTP
- Server: `serv1` on `127.0.0.1:8012`
- Association: `ass1` (SERVER type, peer `127.0.0.1:8011`)
- `acceptAnonymousConnections=false`

### M3UA
- ASP Factory: `asp1` → `ass1`
- AS: `as1` (IPSP/SERVER)
- Route: `1:2:3` → `as1`

### SCCP
- Remote SSN: id=1, spc=1, ssn=8
- Remote SPC: id=1, spc=1
- SAP: id=1, mtp3Id=1, opc=2, ni=2
- Destination: firstDpc=1, lastDpc=1

### USSD
- USSD GT: `923330053058`
- SSN: 8
- Routing rules: HTTP (*519#), SIP (*518#)

## Important Notes

1. **JDK 8 REQUIRED**: Runtime must use JDK 8 (not JDK 25) to avoid `NoSuchMethodError: ByteBuffer.clear()Ljava/nio/ByteBuffer;`
2. **SCTP version**: Must use sctp-impl 2.0.14+ (contains IndexOutOfBoundsException fix)
3. **Client port**: Client must bind to port 8011 (not ephemeral 0)
4. **If server still rejects**: Check `acceptAnonymousConnections` - set to `true` in `SCTPManagement_sctp.xml` as temporary workaround
