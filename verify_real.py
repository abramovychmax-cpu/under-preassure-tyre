#!/usr/bin/env python3
import struct

with open('test_data/coast_down_20260129_223459.fit', 'rb') as f:
    content = f.read()
    
total_size = len(content)
header = content[:14]
footer_crc = content[-2:]

# Parse header
h_size = header[0]
data_size_be = struct.unpack('>I', header[4:8])[0]
data_size_le = struct.unpack('<I', header[4:8])[0]

print(f"Total file size: {total_size}")
print(f"Header: {h_size}")
print(f"Data size (LE interpretation): {data_size_le}")
print(f"CRC at end: {footer_crc.hex()}")
print(f"Data section: {h_size} to {total_size - 2}")
print(f"Data section length: {total_size - h_size - 2}")
print(f"Header + data_size_le + 2: {h_size + data_size_le + 2}")
print(f"Match? {total_size == h_size + data_size_le + 2}")
