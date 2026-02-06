#!/usr/bin/env python3
"""Show session message bytes."""
path = r'd:\TYRE PREASSURE APP\tyre_preassure\test_data\coast_down_20260129_202618.fit'
with open(path, 'rb') as f:
    data = f.read()

print("Last 20 bytes before file CRC:")
for i in range(len(data) - 22, len(data)):
    b = data[i]
    binary = f"{b:08b}"
    desc = ""
    if i == len(data) - 2:
        desc = " <-- File CRC starts"
    elif b == 0x45:
        desc = " <-- Session definition header? (0x45 = 01000101b = local type 5)"
    elif b == 0x05:
        desc = " <-- Session data header? (0x05 = 00000101b = local type 5)"
    print(f"{i:3d}: 0x{b:02x} = {binary}b {desc}")
