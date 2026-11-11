import csv
import math
from pathlib import Path

CAPTURE = Path("plots/lfm_capture.csv")

START_WORD = 0x01000000
STEP_WORD = 0x00100000
SAMPLE_COUNT = 64

MODULUS = 1 << 32
SAMPLE_RATE = 1_000_000

def ideal_sample(index):
    angle = 2 * math.pi * index / 256
    return round(2047.5 + 2047.5 * math.sin(angle))

with CAPTURE.open(newline="") as file:
    rows = list(csv.DictReader(file))

assert len(rows) == SAMPLE_COUNT, (
    f"Expected {SAMPLE_COUNT} rows, got {len(rows)}"
)

phase = 0
errors = []

for n, row in enumerate(rows):
    applied_word = (START_WORD + n * STEP_WORD) % MODULUS
    phase = (phase + applied_word) % MODULUS

    expected_index = phase >> 24
    expected_sample = ideal_sample(expected_index)

    actual_index = int(row["phase_index"])
    actual_sample = int(row["sample"])
    actual_word = int(row["frequency_word"])
    actual_active = int(row["active"])
    actual_done = int(row["done"])

    expected_next_word = (
        START_WORD + min(n + 1, SAMPLE_COUNT - 1) * STEP_WORD
    ) % MODULUS

    assert int(row["cycle"]) == n, (
        f"Cycle mismatch at sample {n}"
    )

    assert actual_index == expected_index, (
        f"Phase mismatch at sample {n}: "
        f"expected {expected_index}, got {actual_index}"
    )

    assert actual_word == expected_next_word, (
        f"Frequency word mismatch at sample {n}: "
        f"expected {expected_next_word}, got {actual_word}"
    )

    assert actual_active == int(n < SAMPLE_COUNT - 1), (
        f"Active mismatch at sample {n}"
    )

    assert actual_done == int(n == SAMPLE_COUNT - 1), (
        f"Done mismatch at sample {n}"
    )

    errors.append(abs(actual_sample - expected_sample))

max_error = max(errors)
mean_error = sum(errors) / len(errors)

first_frequency = START_WORD * SAMPLE_RATE / MODULUS
last_word = START_WORD + (SAMPLE_COUNT - 1) * STEP_WORD
last_frequency = last_word * SAMPLE_RATE / MODULUS

print(f"Samples verified: {len(rows)}")
print(f"Reference sample rate: {SAMPLE_RATE:,} Hz")
print(f"First frequency: {first_frequency:.6f} Hz")
print(f"Last frequency: {last_frequency:.6f} Hz")
print(f"Maximum sample error: {max_error} LSB")
print(f"Mean absolute error: {mean_error:.6f} LSB")

assert max_error == 0, (
    "RTL output differs from mathematical sine reference"
)

print("PASS: Independent Python vs RTL LFM verification")
