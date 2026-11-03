# ClockDomain Zero — CD0 ABYSS Requirements v0.1

Source: official IDP #53 statement supplied by team. This repository is an initial development kit, not a completed transmitter.

## College-required deliverables
1. Physical MCU or FPGA with robust C/C++/Verilog/VHDL firmware.
2. Hardware timers and DMA to a DAC, without per-sample CPU feeding.
3. LFM, geometric frequency sweeps and phase-coded pulses (CW as extra).
4. Physical environmental control (potentiometers or sensor), demonstrably changing bandwidth/centre frequency, pulse duration, and amplitude.
5. Physical active/passive low-pass filtering, op-amp amplification and pulse-edge shaping.
6. Physical DAC/output validation, FFT evidence and an AUV payload enclosure.
7. Power-aware hardware/software control and measured results.

## Decisions
- Budget cap: INR 6,000.
- Oscilloscope and bench power supply: available through college.
- MCU candidate: STM32F407VET6; verify breakout PA4/PA5, SWD, firmware toolchain, bandwidth.
- Optional physical FPGA: Vicharak Shrike Lite at listed INR 389 (RP2040 + 1120 LUT Renesas ForgeFPGA); evaluate toolchain, RTL fit and GPIO/voltage compatibility. Do not assume it can host a large 32-bit ROM or the full waveform engine.
- Digital signal route: STM32 timer + DMA + integrated 12-bit DAC; FPGA handles a small real hardware timing/control module if validated.
- Exact transducer operating frequency, voltage, impedance and waterproofing: NOT YET SELECTED.

## First demonstration acceptance checks
- Python golden model outputs four sample arrays; FFT plots reproducible.
- Digital DDS index generator passes 1000 self-checking testbench cycles.
- Physical design remains on hold until a frequency/driver/transducer matched BOM is approved.

## Separation of evidence
Mark every chart/report as SIMULATED, RTL-SIMULATED, or PHYSICALLY MEASURED.
