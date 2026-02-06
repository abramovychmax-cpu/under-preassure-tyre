#!/usr/bin/env python3
import struct

with open('test_data/coast_down_20260129_223459.fit', 'rb') as f:
    all_data = f.read()
    header = all_data[:14]
    data_no_crc = all_data[14:-2]
    crc = all_data[-2:]

total = len(header) + len(data_no_crc) + len(crc)
data_size_from_header_le = struct.unpack('<I', header[4:8])[0]

print(f"Header size: {len(header)}")
print(f"Data (no CRC): {len(data_no_crc)}")
print(f"CRC size: {len(crc)}")
print(f"Total: {total}")
print(f"Data size from header (LE): {data_size_from_header_le}")
print(f"Data size should equal data without CRC? {data_size_from_header_le == len(data_no_crc)}")
print(f"Data size should equal data with CRC? {data_size_from_header_le == len(data_no_crc) + len(crc)}")

# So data_size in header = data + CRC? Let me check our generation
print("\nOur generated file:")
with open('assets/sample_fake.fit', 'rb') as f:
    header2 = f.read(14)
    data_size_ours = struct.unpack('<I', header2[4:8])[0]
    print(f"Total size: 9283")
    print(f"Header: 14")
    print(f"Data size from header: {data_size_ours}")
    print(f"Actual data+CRC: {9283 - 14} = 9269")
    print(f"Match? {data_size_ours == 9269}")
