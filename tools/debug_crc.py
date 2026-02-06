#!/usr/bin/env python3
"""Debug CRC calculation for FIT files."""
import struct

def crc16_ccitt(data):
    """Calculate CRC-16/CCITT (poly 0x1021) like Dart implementation."""
    crc = 0
    for byte in data:
        crc ^= (byte << 8) & 0xFFFF
        for _ in range(8):
            if (crc & 0x8000) != 0:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc & 0xFFFF

# Read file (auto-detect newest)
import os
import glob
test_data = r'd:\TYRE PREASSURE APP\tyre_preassure\test_data'
fit_files = glob.glob(f'{test_data}/*.fit')
path = max(fit_files, key=os.path.getmtime)
print(f"Analyzing: {os.path.basename(path)}")
with open(path, 'rb') as f:
    data = f.read()

print(f"Total file size: {len(data)} bytes")
print()

# Parse structure
header = data[:14]
data_section = data[14:-2]
file_crc_bytes = data[-2:]

print(f"Header (14 bytes): {' '.join(f'{b:02x}' for b in header)}")
print(f"Data section: {len(data_section)} bytes")
print(f"File CRC field: {' '.join(f'{b:02x}' for b in file_crc_bytes)}")
print()

# Header CRC (first 12 bytes)
header_crc_computed = crc16_ccitt(header[:12])
header_crc_stored = struct.unpack('<H', header[12:14])[0]
print(f"Header CRC (bytes 0-11):")
print(f"  Computed: 0x{header_crc_computed:04X}")
print(f"  Stored:   0x{header_crc_stored:04X}")
print(f"  Match: {header_crc_computed == header_crc_stored}")
print()

# File CRC (should be over data section only, NOT including header)
file_crc_computed_wrong = crc16_ccitt(data[:-2])  # What Dart code does (includes header)
file_crc_computed_correct = crc16_ccitt(data_section)  # What it SHOULD do (data only)
file_crc_stored = struct.unpack('<H', file_crc_bytes)[0]

print(f"File CRC:")
print(f"  Stored in file:     0x{file_crc_stored:04X}")
print(f"  Computed (WRONG - includes header): 0x{file_crc_computed_wrong:04X}")
print(f"  Computed (CORRECT - data only):    0x{file_crc_computed_correct:04X}")
print()

# What fitparse expects
print("Analysis:")
if file_crc_stored == header_crc_stored:
    print("  ❌ File CRC equals header CRC - code is writing header CRC twice!")
if file_crc_computed_wrong != file_crc_computed_correct:
    print(f"  ⚠️  CRC differs: including header gives 0x{file_crc_computed_wrong:04X}, data-only gives 0x{file_crc_computed_correct:04X}")
if file_crc_stored == file_crc_computed_wrong:
    print("  ❌ Stored CRC matches 'includes header' calculation - BUG CONFIRMED")
if file_crc_computed_correct == 0xF4B0:
    print(f"  ✅ Correct CRC (0x{file_crc_computed_correct:04X}) matches fitparse expectation (0xF4B0)")

# Check what Garmin SDK actually says
print()
print("Per Garmin FIT SDK:")
print("  - File CRC should be calculated over ALL BYTES except the final 2 CRC bytes")
print(f"  - This means: CRC over bytes 0-{len(data)-3} (header + data)")
print(f"  - Result: 0x{file_crc_computed_wrong:04X}")
print()
print("FIX: Line 386 in writer_impl.dart is correct!")
print("  Current: FitProtocol.crc16Ccitt(patched)")
print("  This computes CRC over entire file before appending CRC bytes.")
print(f"  Matches stored value: {file_crc_stored == file_crc_computed_wrong}")
