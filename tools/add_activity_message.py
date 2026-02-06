#!/usr/bin/env python3
"""Add activity message to FIT file and fix CRC"""
import struct
from datetime import datetime

def crc16_ccitt(data):
    crc = 0
    for b in data:
        crc ^= (b << 8) & 0xFFFF
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc

def write_uint8(data, val):
    data.append(val & 0xFF)

def write_uint16(data, val):
    data.extend([val & 0xFF, (val >> 8) & 0xFF])

def write_uint32(data, val):
    data.extend([val & 0xFF, (val >> 8) & 0xFF, (val >> 16) & 0xFF, (val >> 24) & 0xFF])

def timestamp_to_fit(dt):
    """Convert datetime to FIT timestamp (seconds since 1989-12-31 00:00:00 UTC)"""
    fit_epoch = datetime(1989, 12, 31, 0, 0, 0)
    return int((dt - fit_epoch).total_seconds())

# Read existing file
with open(r'..\test_data\coast_down_20260129_225448.fit', 'rb') as f:
    data = bytearray(f.read())

print(f'Original file: {len(data)} bytes')

# Remove old 2-byte CRC
data = data[:-2]
print(f'Without old CRC: {len(data)} bytes')

# Create activity definition message (local type 6, message 34)
act_def = bytearray()
act_def.append(0x40 | 0x06)  # Definition message, local type 6
act_def.append(0x00)  # reserved
act_def.append(0x00)  # architecture (little endian)
write_uint16(act_def, 34)  # message number (activity)
write_uint8(act_def, 4)  # 4 fields
# Field 253: timestamp (uint32)
write_uint8(act_def, 253)
write_uint8(act_def, 4)
write_uint8(act_def, 0x86)
# Field 1: total_timer_time (uint32)
write_uint8(act_def, 1)
write_uint8(act_def, 4)
write_uint8(act_def, 0x86)
# Field 2: num_sessions (uint16)
write_uint8(act_def, 2)
write_uint8(act_def, 2)
write_uint8(act_def, 0x84)
# Field 5: type (enum, uint8)
write_uint8(act_def, 5)
write_uint8(act_def, 1)
write_uint8(act_def, 0x00)
write_uint8(act_def, 0)  # 0 dev fields

# Create activity data message
act_data = bytearray()
act_data.append(0x06)  # Data message, local type 6
# timestamp - use current time
now = datetime.utcnow()
fit_ts = timestamp_to_fit(now)
write_uint32(act_data, fit_ts)
# total_timer_time - use 10 seconds (10000 ms)
write_uint32(act_data, 10000)
# num_sessions - 1
write_uint16(act_data, 1)
# type - manual = 0
write_uint8(act_data, 0)

# Append activity messages to data
data.extend(act_def)
data.extend(act_data)

print(f'After adding activity: {len(data)} bytes')

# Calculate new data_size
data_size = len(data) - 14
print(f'Data size: {data_size} bytes')

# Update data_size in header (bytes 4-7)
data[4:8] = data_size.to_bytes(4, 'little')

# Recalculate header CRC (bytes 12-13)
hdr_crc = crc16_ccitt(data[:12])
data[12:14] = hdr_crc.to_bytes(2, 'little')
print(f'Header CRC: 0x{hdr_crc:04X}')

# Calculate file CRC over everything
file_crc = crc16_ccitt(data)
print(f'File CRC: 0x{file_crc:04X}')

# Append file CRC
final_data = data + file_crc.to_bytes(2, 'little')

# Save fixed file
with open(r'..\test_data\coast_down_FIXED.fit', 'wb') as f:
    f.write(final_data)

print(f'Fixed file saved: {len(final_data)} bytes')
print(f'Verification: 14 + {data_size} + 2 = {14 + data_size + 2}')
print(f'Match: {len(final_data) == 14 + data_size + 2}')
