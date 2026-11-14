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

BenchTwin is a browser-based virtual electronics bench. First verify whether its current component catalogue contains the exact MCU development board and peripherals we intend to model. Use it only for supported MCU-side wiring/code experiments (for example, GPIO/UART/SPI behaviour) where the exact board/peripheral model exists.

Do not represent the Renesas SLG47910 as supported unless BenchTwin explicitly lists that device and exposes the required FPGA behaviour. If it does not, keep FPGA validation in Icarus Verilog/Verilator and the Renesas ForgeFPGA toolchain.

### 3. Controller firmware model

- Define a portable command interface: `SET_MODE`, `SET_START_FREQ`, `SET_STOP_FREQ`, `SET_SWEEP_RATE`, `SET_AMPLITUDE`, `START`, `STOP`, `STATUS`, and `FAULT_CLEAR`.
- Define packet framing, field widths, byte order, units, limits, acknowledgement, timeout, and invalid-command behaviour.
- Build a host-side Python protocol simulator first; only port to an MCU SDK after interface tests pass.
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

- [ ] Sprint 02 RTL regression re-run and logs archived.
- [ ] BenchTwin exact-board support checked; unsupported FPGA behaviour explicitly excluded.
- [ ] Controller command protocol documented and Python tests pass.
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
