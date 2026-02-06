#!/usr/bin/env python3
"""Check FIT file CRC"""

def crc16_ccitt(data):
    """Calculate CRC-16/CCITT (polynomial 0x1021)"""
    crc = 0
    for byte in data:
        crc ^= (byte << 8)
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc

with open('minimal_test.fit', 'rb') as f:
    data = f.read()

header = data[:12]
header_crc_file = int.from_bytes(data[12:14], 'little')
header_crc_computed = crc16_ccitt(header)

print(f"Header CRC (file):     0x{header_crc_file:04X}")
print(f"Header CRC (computed): 0x{header_crc_computed:04X}")
print(f"Match: {header_crc_file == header_crc_computed}")

file_crc_file = int.from_bytes(data[-2:], 'little')
file_crc_computed = crc16_ccitt(data[:-2])

print(f"\nFile CRC (file):       0x{file_crc_file:04X}")
print(f"File CRC (computed):   0x{file_crc_computed:04X}")
print(f"Match: {file_crc_file == file_crc_computed}")
