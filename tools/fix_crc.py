#!/usr/bin/env python3
"""Fix CRC in malformed FIT file"""
import sys

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

# Read file
with open(r'..\test_data\coast_down_20260129_225448.fit', 'rb') as f:
    data = bytearray(f.read())

print(f'Original file: {len(data)} bytes')

# Remove old 2-byte CRC
data_no_crc = data[:-2]
print(f'Without old CRC: {len(data_no_crc)} bytes')

# Calculate correct data_size
data_size = len(data_no_crc) - 14
print(f'Data size: {data_size} bytes')

# Update data_size in header (bytes 4-7)
data_no_crc[4:8] = data_size.to_bytes(4, 'little')

# Recalculate header CRC (bytes 12-13)
hdr_crc = crc16_ccitt(data_no_crc[:12])
data_no_crc[12:14] = hdr_crc.to_bytes(2, 'little')
print(f'Header CRC: 0x{hdr_crc:04X}')

# Calculate file CRC
file_crc = crc16_ccitt(data_no_crc)
print(f'File CRC: 0x{file_crc:04X}')

# Append file CRC
final_data = data_no_crc + file_crc.to_bytes(2, 'little')

# Save fixed file
with open(r'..\test_data\coast_down_FIXED.fit', 'wb') as f:
    f.write(final_data)

print(f'Fixed file saved: {len(final_data)} bytes')
print(f'Verification: 14 + {data_size} + 2 = {14 + data_size + 2}')
