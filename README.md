# CD0 ABYSS — Sprint 01

Initial simulation and RTL **starter package**, not a finished sonar system.

## 1. Python reference model
Requires Python 3.10+, numpy, matplotlib:

```bash
python -m pip install numpy matplotlib
python dsp/waveforms.py
cd dsp && python -m unittest test_waveforms -v
```

This generates four labeled *simulated* signal plots in `plots/`. Signal frequencies and sampling rates are provisional and NOT approved electrical specs.

## 2. DDS hardware IP prototype
`rtl/dds_phase_core.sv` is a synthesizable 32-bit phase accumulator, with 8-bit phase ROM address output, config, enable, and phase offset. It does not include a sine ROM, geometric sweep control, external DAC, or analog hardware yet.

Run with Icarus Verilog or a compatible simulator:

```bash
iverilog -g2012 -s tb_dds_phase_core -o dds_test rtl/dds_phase_core.sv tb/tb_dds_phase_core.sv
vvp dds_test
```

Expected message: `PASS: 1000 cycles...` and `dds_phase_core.vcd` for GTKWave. The RTL test has not been executed in this delivery environment (simulator unavailable); run and confirm it on your WSL installation before claiming it passed.

## 3. Architecture caveat
The Shrike Lite (if bought) is a separate RP2040 + low-density FPGA board. It is NOT a drop-in SPI FPGA DAC board. Fit and integration require validated synthesis, I/O constraints, pinout, logic-level compatibility and oscilloscope confirmation. The physical output baseline is the STM32's on-chip DAC.
