#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT/reports/sprint03"
RUN_DIR="$(mktemp -d /tmp/cd0-sprint03.XXXXXX)"

mkdir -p "$REPORT_DIR" "$RUN_DIR/plots"
ln -s "$ROOT/rtl" "$RUN_DIR/rtl"

cleanup() {
    rm -rf "$RUN_DIR"
}
trap cleanup EXIT

PASS_COUNT=0
TOTAL_COUNT=10

run_test() {
    local name="$1"
    local top="$2"
    shift 2

    echo
    echo "========================================"
    echo "TEST: $name"
    echo "========================================"

    iverilog -g2012 -Wall \
        -s "$top" \
        -o "$RUN_DIR/$name.vvp" \
        "$@"

    if (cd "$RUN_DIR" && vvp "$RUN_DIR/$name.vvp") \
        2>&1 | tee "$REPORT_DIR/$name.log"; then

        if grep -q "PASS:" "$REPORT_DIR/$name.log"; then
            echo "RESULT: PASS"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo "RESULT: FAIL - PASS marker missing"
            return 1
        fi
    else
        echo "RESULT: FAIL - simulation error"
        return 1
    fi
}

# 1. DDS phase accumulator
run_test "dds_phase_core" "tb_dds_phase_core" \
    "$ROOT/rtl/dds_phase_core.sv" \
    "$ROOT/tb/tb_dds_phase_core.sv"

# 2. DDS waveform core
run_test "dds_wavecore" "tb_dds_wavecore" \
    "$ROOT/rtl/dds_phase_core.sv" \
    "$ROOT/rtl/dds_sine_rom.sv" \
    "$ROOT/rtl/dds_wavecore.sv" \
    "$ROOT/tb/tb_dds_wavecore.sv"

# 3. Extended DDS verification
run_test "dds_extended" "tb_dds_extended" \
    "$ROOT/rtl/dds_phase_core.sv" \
    "$ROOT/rtl/dds_sine_rom.sv" \
    "$ROOT/rtl/dds_wavecore.sv" \
    "$ROOT/tb/tb_dds_extended.sv"

# 4. DDS sample capture
run_test "dds_capture" "tb_dds_capture" \
    "$ROOT/rtl/dds_phase_core.sv" \
    "$ROOT/rtl/dds_sine_rom.sv" \
    "$ROOT/rtl/dds_wavecore.sv" \
    "$ROOT/tb/tb_dds_capture.sv"

# 5. LFM controller
run_test "lfm_chirp_controller" "tb_lfm_chirp_controller" \
    "$ROOT/rtl/lfm_chirp_controller.sv" \
    "$ROOT/tb/tb_lfm_chirp_controller.sv"

# 6. Integrated LFM wavecore
run_test "lfm_wavecore" "tb_lfm_wavecore" \
    "$ROOT/rtl/lfm_chirp_controller.sv" \
    "$ROOT/rtl/dds_sine_rom.sv" \
    "$ROOT/rtl/lfm_wavecore.sv" \
    "$ROOT/tb/tb_lfm_wavecore.sv"

# 7. LFM sample capture
run_test "lfm_capture" "tb_lfm_capture" \
    "$ROOT/rtl/lfm_chirp_controller.sv" \
    "$ROOT/rtl/dds_sine_rom.sv" \
    "$ROOT/rtl/lfm_wavecore.sv" \
    "$ROOT/tb/tb_lfm_capture.sv"

# 8. LFM edge cases
run_test "lfm_edge_cases" "tb_lfm_edge_cases" \
    "$ROOT/rtl/lfm_chirp_controller.sv" \
    "$ROOT/tb/tb_lfm_edge_cases.sv"

# 9. Quarter-wave ROM equivalence
run_test "rom_equivalence" "tb_sine_rom_quarter" \
    "$ROOT/rtl/dds_sine_rom.sv" \
    "$ROOT/rtl/dds_sine_rom_quarter.sv" \
    "$ROOT/tb/tb_sine_rom_quarter.sv"

# 10. Original vs optimized LFM wavecore
run_test "wavecore_equivalence" "tb_lfm_wavecore_equivalence" \
    "$ROOT/rtl/lfm_chirp_controller.sv" \
    "$ROOT/rtl/dds_sine_rom.sv" \
    "$ROOT/rtl/dds_sine_rom_quarter.sv" \
    "$ROOT/rtl/lfm_wavecore.sv" \
    "$ROOT/rtl/lfm_wavecore_quarter.sv" \
    "$ROOT/tb/tb_lfm_wavecore_equivalence.sv"

# Archive newly generated captures without touching existing plots.
mkdir -p "$REPORT_DIR/captures"

for capture in dds_capture.csv lfm_capture.csv; do
    if [ -f "$RUN_DIR/plots/$capture" ]; then
        cp "$RUN_DIR/plots/$capture" "$REPORT_DIR/captures/$capture"
    fi
done

echo
echo "========================================"
echo "SPRINT 03 REGRESSION SUMMARY"
echo "========================================"
echo "Passed testbenches: $PASS_COUNT / $TOTAL_COUNT"
echo "Logs: $REPORT_DIR"

if [ "$PASS_COUNT" -ne "$TOTAL_COUNT" ]; then
    echo "OVERALL RESULT: FAIL"
    exit 1
fi

echo "OVERALL RESULT: PASS"
echo "Generated captures: $REPORT_DIR/captures"
