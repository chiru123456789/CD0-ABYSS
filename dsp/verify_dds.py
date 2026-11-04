import csv
import math
from pathlib import Path

CAPTURE = Path("plots/dds_capture.csv")
PHASE_MODULUS = 1 << 32
FREQUENCY_WORD = 0x01000000
SAMPLE_RATE = 1_000_000

def expected_sample(index):
    angle = 2 * math.pi * index / 256
    return round(2047.5 + 2047.5 * math.sin(angle))

with CAPTURE.open(newline="") as file:
    rows = list(csv.DictReader(file))

assert len(rows) == 1024, "Incorrect capture length"

errors = []
for row in rows:
    cycle = int(row["cycle"])
    index = int(row["phase_index"])
    actual = int(row["sample"])

    expected_phase = (cycle * FREQUENCY_WORD) % PHASE_MODULUS
    expected_index = expected_phase >> 24
    expected = expected_sample(expected_index)

    assert index == expected_index, (
        f"Phase mismatch at cycle {cycle}: "
        f"expected {expected_index}, got {index}"
    )

    errors.append(abs(actual - expected))

max_error = max(errors)
mean_error = sum(errors) / len(errors)

frequency = FREQUENCY_WORD * SAMPLE_RATE / PHASE_MODULUS

print(f"Samples checked: {len(rows)}")
print(f"Expected DDS frequency: {frequency:.6f} Hz")
print(f"Maximum amplitude error: {max_error} LSB")
print(f"Mean absolute error: {mean_error:.6f} LSB")

assert max_error == 0, "RTL samples differ from mathematical reference"

print("PASS: Independent Python vs RTL DDS verification")
