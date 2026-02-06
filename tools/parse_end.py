#!/usr/bin/env python3
"""Manually parse last messages in FIT file."""
import glob
import os

# Auto-detect newest file
test_data = r'd:\TYRE PREASSURE APP\tyre_preassure\test_data'
fit_files = glob.glob(f'{test_data}/*.fit')
path = max(fit_files, key=os.path.getmtime)
print(f"Analyzing: {os.path.basename(path)}\n")

with open(path, 'rb') as f:
    data = f.read()

print("Scanning for session definition (local type 5):")
print()

# Scan from start of data section (byte 14) to find session
pos = 14
session_def_pos = None
session_data_pos = None
while pos < len(data) - 2:  # -2 for file CRC
    header_byte = data[pos]
    
    if header_byte & 0x80:
        # Compressed timestamp - skip
        pos += 1
        continue
    
    if header_byte & 0x40:
        # Definition message
        local_type = header_byte & 0x0F
        if local_type == 5:
            session_def_pos = pos
            print(f"Found session definition at position {pos}")
        has_dev_fields = (header_byte & 0x20) != 0
        pos += 6  # header + reserved + arch + global_msg_num
        num_fields = data[pos]
        pos += 1 + num_fields * 3
        if has_dev_fields:
            num_dev = data[pos]
            pos += 1 + num_dev * 3
    else:
        # Data message
        local_type = header_byte & 0x0F
        if local_type == 5:
            session_data_pos = pos
            print(f"Found session data at position {pos}")
            print(f"  Remaining bytes: {len(data) - 2 - pos}")
            # Show next bytes
            print(f"  Next 10 bytes: {' '.join(f'{data[pos+i]:02x}' for i in range(min(10, len(data)-2-pos)))}")
        pos += 1
        # Can't determine size without tracking definitions, so break
        break

print()
if session_def_pos and session_data_pos:
    print(f"Session definition at {session_def_pos}, data at {session_data_pos}")

print()
print(f"Final position: {pos}")
print(f"File CRC at {len(data)-2}: 0x{data[-2]:02X}{data[-1]:02X}")
