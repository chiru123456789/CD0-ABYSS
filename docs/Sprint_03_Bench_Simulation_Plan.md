# Sprint 03 — Bench Simulation & Toolchain Readiness

**Branch:** `sprint03-bench-simulation`  
**Status:** Planning / software-only validation  
**Hardware policy:** No physical wiring, board programming, power-up, or purchase during this sprint phase.  
**Project:** CD0-ABYSS — Low-Power, Real-Time Adaptive Software-Defined Sonar Transmitter Payload for AUVs.

## Sprint objective

Establish a reproducible software toolchain and a virtual bench model for the sonar transmitter path before purchasing or connecting hardware. Reuse the Sprint 02 waveform core and verify the controller, waveform engine, sample stream, and analog-output assumptions at the appropriate simulation levels.

Simulation results must be labelled by fidelity. A functional model is not proof of target FPGA fit, real-time timing closure, electrical compatibility, acoustic output, or measured power.

## Provisional system partition

- **Controller candidate:** STM32F407VET6 remains the leading candidate because it provides two 12-bit DACs, timer and DMA resources. ESP32-C3 remains an alternative only if the FPGA plus an external DAC owns the sample-output path and the controller is primarily for configuration/supervision.
- **FPGA candidate:** Vicharak Shrike-lite (Renesas ForgeFPGA SLG47910 + RP2040 host). It is selected as the intended FPGA platform, but has not been purchased or validated.
- **Waveform engine:** Existing DDS/LFM RTL and quarter-wave ROM.
- **Analog output:** Model the DAC, reconstruction filter, driver and transducer load separately. Do not assume the FPGA board contains a suitable DAC.
- **Interconnect:** Model STM32-to-RP2040 control messages and RP2040-to-FPGA interface as separate links. Final protocol and pin assignment remain unapproved until the board documentation and target implementation are checked.

## Simulation strategy

### 1. Existing RTL regression

- Re-run the Sprint 02 full-wave versus quarter-wave equivalence test.
- Re-run directed and deterministic-random wavecore tests.
- Preserve simulator version, exact command, stdout/stderr, and generated VCD.
- Treat equivalence as simulation evidence, not formal proof.

### 2. BenchTwin exploration

**Observed by the project operator (2026-11-16):** the BenchTwin catalogue returns 18 results for `RP2040`; it includes the Waveshare RP2040-Zero, which can be added to a circuit and run code. The operator also confirmed that GPIO, UART, and SPI workflows are available in the simulator. Use this board as an RP2040 controller proxy for host-side control experiments.

**Fidelity boundary:** Waveshare RP2040-Zero is a separate RP2040 development board, not the RP2040 section of Shrike-lite. It cannot validate Shrike-lite's exact pin multiplexing, six-bit MCU/FPGA link, board-level wiring, or the SLG47910. Do not represent the Renesas SLG47910 as supported unless BenchTwin explicitly lists that device and exposes the required FPGA behaviour. Keep FPGA RTL validation in Icarus Verilog/Verilator and target-specific implementation in Renesas ForgeFPGA tools.

BenchTwin's oscilloscope/serial tools may be used for supported MCU-side functional demonstrations, but simulated traces are not physical electrical measurements. Exact STM32F407 and SLG47910 catalogue support remain unverified; do not substitute a different MCU/FPGA and claim equivalence.

### 3. Controller firmware model

- [x] Define a portable command interface: `SET_MODE`, `SET_START_FREQ`, `SET_STOP_FREQ`, `SET_SWEEP_RATE`, `SET_AMPLITUDE`, `START`, `STOP`, `STATUS`, and `FAULT_CLEAR`.
- [x] Define protocol v1 framing, field widths, byte order, units, response codes, and invalid-command behaviour in `docs/Sprint_03B_Controller_Protocol.md`.
- [x] Add a host-side Python functional model and unit tests under `sim/sprint03b/`.
- [ ] Execute the protocol test suite in the project WSL environment and archive the result.
- [ ] Add explicit timeout/retry/duplicate-command behaviour after the command transport and operating requirements are settled.
- Keep UART as the initial control-link candidate unless measured requirements justify SPI.

### 4. Sample-stream and analog model

- Connect the RTL sample sequence to a Python model of DAC quantization and update timing.
- Model zero-order hold, reconstruction filtering, output offset/full-scale, clipping, and a representative load.
- Use ngspice or an equivalent circuit simulator only after the DAC/output electrical requirements and candidate components are defined.
- Compare output metrics against the Python golden model: sample count, frequency trajectory, amplitude, phase continuity, clipping, and spectral artefacts.

### 5. Target-toolchain readiness

- Install Renesas Go Configure Software Hub on a supported host OS and verify ForgeFPGA Workshop launches.
- Record the installed version and supported target/device selection.
- Create a minimal ForgeFPGA project and confirm the tool can generate a target bitstream without connecting or programming a physical board.
- Attempt synthesis/implementation of the existing DDS/ROM design only after confirming the supported HDL subset, clock constraints, I/O constraints, and target mapping flow.
- Keep generic Yosys cell counts separate from target-specific ForgeFPGA resource/timing reports.

## Purchase verification — no order yet

Before any purchase, obtain and archive:

1. Exact Shrike-lite SKU/revision, price, shipping, included accessories, warranty/return terms, and official schematic/pinout.
2. Confirmation of the FPGA device marking and supported ForgeFPGA tool version.
3. RP2040–FPGA interface details, pin multiplexing, voltage limits, and accessible I/O.
4. Exact STM32F407VET6 development-board variant, schematic, DAC pin breakout, clock source, SWD/debug method, USB/power circuitry, and seller return policy.
5. Whether an external DAC is required by the chosen partition; if yes, its resolution, sample rate, interface, output range, and cost.
6. Total bill of materials against the ₹6,000 project budget, including cables, connectors, power regulation, analogue filter/driver, and transducer interface.

No MCU purchase decision is final until the software model shows whether the MCU must generate DAC samples or only supervise/configure the FPGA.

## Exit criteria

- [x] Sprint 02 RTL regression re-run and logs archived (10/10 testbenches; Sprint 03A evidence).
- [ ] BenchTwin RP2040 proxy checked; exact Shrike-lite FPGA behaviour remains excluded pending exact SLG47910 support evidence.
- [ ] Controller command protocol documented and Python tests pass (documentation and tests authored; local execution pending).
- [ ] MCU–RP2040 control-link simulator passes normal, malformed, timeout, and reset cases.
- [ ] DAC/sample-stream model produces repeatable plots and quantitative checks.
- [ ] Renesas Go Configure Software Hub installed and ForgeFPGA project/bitstream generation verified offline.
- [ ] Shrike-lite and MCU purchase checklist completed with official documentation.
- [ ] Architecture decision record selects the MCU/DAC partition based on evidence and budget.

## Non-goals for this phase

- No physical board wiring or powering.
- No real FPGA programming or MCU flashing.
- No claims of acoustic transmission, AUV integration, power savings, or hardware timing closure.
- No final MCU purchase until the DAC and control partition is settled.


## Sprint 03B implementation log — 2026-11-16

- BenchTwin catalogue: 18 results for RP2040; Waveshare RP2040-Zero is available and runs code. Project operator confirms GPIO, UART, and SPI are usable in the simulator.
- Controller protocol v1 and a Python state-machine/frame parser were added. The model includes CRC-16/CCITT-FALSE, fragmented UART stream parsing, configuration commands, ACK/result codes, CW/LFM start validation, status, stop, fault and reset behaviour.
- Test cases cover CRC reference vector, frame round-trip, fragmented stream, noise/corrupt-frame recovery, invalid frame/version, normal CW and LFM configuration, invalid arguments, fault clearing, status, unknown commands, and reset.
- Current validation status: source and tests authored; execution in the project WSL environment is still required. No test-pass claim is made yet.
- No hardware was purchased, wired, powered, flashed, or acoustically tested.
