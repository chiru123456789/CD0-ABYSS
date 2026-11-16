# Sprint 03B — Controller Protocol v1

**Status:** Provisional software contract for simulation only  
**Transport candidate:** UART, point-to-point, full duplex  
**Target role:** RP2040 host/controller proxy in BenchTwin; later adaptable to the selected MCU  
**Not a hardware specification:** UART baud rate, physical connector, voltage, timing guarantees, and final command ranges remain TBD.

## Scope

This protocol models configuration and supervisory control of the sonar waveform engine. It deliberately separates the controller command link from the RP2040-to-FPGA interface. It does not define the Shrike-lite six-bit MCU/FPGA interface or claim that BenchTwin models the SLG47910.

Implementation: `sim/sprint03b/controller_protocol.py`  
Tests: `sim/sprint03b/test_controller_protocol.py`

## Frame format

All multi-byte integer fields are little-endian.

| Field | Size | Value |
|---|---:|---|
| Sync | 2 bytes | `C3 3C` |
| Version | 1 byte | `01` |
| Sequence | 1 byte | 0–255, wraps modulo 256 |
| Command | 1 byte | Command ID |
| Payload length | 1 byte | 0–64 |
| Payload | 0–64 bytes | Command-specific |
| CRC | 2 bytes | CRC-16/CCITT-FALSE, little-endian |

CRC covers Version through the final payload byte; it excludes Sync and the CRC field. CRC parameters: polynomial `0x1021`, initial value `0xFFFF`, no reflection, xorout `0x0000`. The standard `123456789` test vector is `0x29B1`.

A receiver must reject unsupported versions, invalid lengths, and CRC mismatches. The stream parser must tolerate fragmented reads, noise before a sync word, and recover after a corrupted frame.

## Command IDs

| Command | ID | Payload |
|---|---:|---|
| SET_MODE | `0x01` | 1 byte: CW=0, LFM=1 |
| SET_START_FREQ | `0x02` | uint32 frequency in Hz |
| SET_STOP_FREQ | `0x03` | uint32 frequency in Hz |
| SET_SWEEP_RATE | `0x04` | uint32 sweep rate in Hz/s |
| SET_AMPLITUDE | `0x05` | uint16 amplitude in permille (0–1000) |
| START | `0x06` | Empty |
| STOP | `0x07` | Empty |
| STATUS | `0x08` | Empty |
| FAULT_CLEAR | `0x09` | Empty |

These units and field widths are provisional software interface choices, not approved acoustic/electrical operating limits. Frequency zero is rejected. The final safe operating range must be derived from the transducer, DAC, analog chain, sampling constraints, and project requirements.

## Response format

A response uses the request sequence number and command ID with bit 7 set. Its payload begins with one result byte:

- `0`: OK
- `1`: INVALID_ARGUMENT
- `2`: INVALID_STATE
- `3`: UNKNOWN_COMMAND

STATUS appends a fixed binary snapshot: running (uint8), mode (uint8), start frequency (uint32), stop frequency (uint32), sweep rate (uint32), amplitude permille (uint16), fault code (uint16), all little-endian.

## State and safety behaviour in the model

- Reset returns to idle, CW mode, zeroed configuration, and no fault.
- START is rejected when a fault is active or required configuration is missing.
- LFM requires stop frequency greater than start frequency and a nonzero sweep rate.
- Configuration writes while running are rejected; STOP remains accepted.
- FAULT_CLEAR is accepted only while stopped.
- A fault immediately stops the model output state.

## Explicitly deferred

- Baud rate, timeout duration, retry policy, duplicate-command/idempotency policy.
- Authentication or bus arbitration (not currently required for a point-to-point internal link).
- Physical UART pin mapping, connector, cable, voltage levels, and isolation.
- MCU firmware port and real peripheral timing.
- RP2040-to-SLG47910 command/data protocol.
- DAC sample streaming and analog output interface.

## Test command

From the repository root:

```bash
python -m unittest discover -s sim/sprint03b -p 'test_*.py' -v
```

This test suite validates only the host-side Python protocol model. It is not a test of BenchTwin's UART implementation or physical UART electrical behaviour.
