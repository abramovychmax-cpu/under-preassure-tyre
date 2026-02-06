#!/usr/bin/env python3
"""Hex dump the FIT file to see what's actually written"""
import sys

with open('assets/sample_fake.fit', 'rb') as f:
    data = f.read()

print("First 300 bytes of FIT file (hex):")
print("=" * 80)

for i in range(0, min(300, len(data)), 16):
    chunk = data[i:i+16]
    hex_str = ' '.join(f'{b:02x}' for b in chunk)
    ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
    print(f"{i:04x}: {hex_str:<48} {ascii_str}")

print("\n" + "=" * 80)
print("\nHeader bytes (bytes 0-13):")
h = data[:14]
for i, b in enumerate(h):
    print(f"  [{i:2d}]: 0x{b:02x} ({b:3d})")

print("\nExpected structure:")
print("  [0]: 0x0e (header size = 14)")
print("  [1]: 0x20 (protocol version = 2.0)")
print("  [2-3]: profile version (big-endian)")
print("  [4-7]: data size (big-endian)")
print("  [8-11]: data type = '.FIT'")
print("  [12-13]: header CRC (little-endian)")
