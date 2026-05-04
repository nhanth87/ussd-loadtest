# USSD MAP Load Test Application

## Overview

This is a load testing application for the Restcomm USSD Gateway. It simulates USSD client traffic using the SS7/MAP protocol over SCTP or TCP connections to stress-test the gateway server.

## Prerequisites

- Java 8 (OpenJDK or Zulu)
- Apache Ant
- SCTP kernel module (for SCTP mode)

## Configuration

Edit `ussd_build.xml` to adjust test parameters:

| Property | Default | Description |
|----------|---------|-------------|
| `test.client.numOfDialogs` | 1440000 | Total number of dialogs to initiate |
| `test.client.concurrentDialog` | 400 | Max concurrent dialogs |
| `test.client.channelType` | sctp | Transport: sctp or tcp |
| `test.client.hostIp` | 127.0.0.1 | Client bind IP |
| `test.client.hostPort` | 8011 | Client bind port |
| `test.client.peerIp` | 127.0.0.1 | Server IP |
| `test.client.peerPort` | 8012 | Server port |
| `test.client.ussdSsn` | 147 | USSD Subsystem Number |
| `test.client.originatingPc` | 1 | Originating Point Code |
| `test.client.destinationPc` | 2 | Destination Point Code |

## Build & Run

```bash
# Run the load test client
ant -f ussd_build.xml client

# Run the load test server
ant -f ussd_build.xml server
```

## Architecture

The client uses:
- **jSS7** stack (M3UA, SCCP, TCAP, MAP)
- **Netty** for SCTP/TCP transport
- **JCTools** for high-performance queues
- Rate limiter for controlled TPS

## Recent Changes

- Fixed SSN mismatch between client and server (both now use 147)
- Added SCTP debug logging for connection troubleshooting
- Added JCTools for improved queue performance

## License

Same as Restcomm jSS7 project.

