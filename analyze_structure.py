#!/usr/bin/env python3
"""Check exact byte positions"""
import struct

with open('assets/sample_fake.fit', 'rb') as f:
    data = f.read()

payload = data[14:]  # Skip header

print("First 150 bytes of payload (hex):")
for i in range(0, min(150, len(payload)), 16):
    chunk = payload[i:i+16]
    hex_str = ' '.join(f'{b:02x}' for b in chunk)
    print(f"{i:04x}: {hex_str}")

print("\n" + "=" * 80)
print("\nMessage analysis:")
print("FileID Definition (0x0000-0x0014):")
print("  0x40 (header)")
print("  0x00 0x01 0x00 0x00 (reserved, arch, GMN)")
print("  0x05 (5 fields)")
print("  0x00 0x01 0x00 (field 0)")
print("  0x01 0x02 0x84 (field 1)")
print("  0x02 0x02 0x84 (field 2)")
print("  0x03 0x04 0x86 (field 3)")
print("  0xfe 0x04 0x86 (field 254)")
print("  = 1 + 4 + 1 + 3*5 = 21 bytes")

print("\nFileID Data (0x0015-0x0021):")
print("  0x00 (LMT 0)")
print("  0x04 (field 0, 1 byte)")
print("  0x00 0x01 (field 1, 2 bytes)")
print("  0x00 0x01 (field 2, 2 bytes)")
print("  0x00 0x01 0xe2 0x40 (field 3, 4 bytes)")
print("  0x41 0xfe 0x01 0xa0 (field 254, 4 bytes)")
print("  = 1 + 1 + 2 + 2 + 4 + 4 = 14 bytes")

print("\nNext record should be at 0x0023 (35 decimal)")
print(f"Actual byte at 0x0023: {payload[0x23]:02x}")
