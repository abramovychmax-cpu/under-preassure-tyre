#!/usr/bin/env python3
"""Test what fitparse is validating."""
import struct

path = r'd:\TYRE PREASSURE APP\tyre_preassure\test_data\coast_down_20260129_202618.fit'
with open(path, 'rb') as f:
    data = f.read()

print(f"File structure ({len(data)} bytes total):")
print(f"  Bytes 0-13:  Header (14 bytes)")
print(f"  Bytes 14-431: Data section (418 bytes)")
print(f"  Bytes 432-433: File CRC (2 bytes)")
print()

print("Header CRC (bytes 12-13):")
header_crc = struct.unpack('<H', data[12:14])[0]
print(f"  Value: 0x{header_crc:04X} ({data[12]:02x} {data[13]:02x})")
print()

print("File CRC (bytes 432-433, last 2 bytes):")
file_crc = struct.unpack('<H', data[-2:])[0]
print(f"  Value: 0x{file_crc:04X} ({data[-2]:02x} {data[-1]:02x})")
print()

print("fitparse error said:")
print("  'CRC Mismatch [computed: 0xF4B0, read: 0x3D94]'")
print()
print("  0x3D94 = header CRC at bytes 12-13")
print("  0xF4B0 = ??? (not header CRC 0x3D94, not file CRC 0x4C01)")
print()

# Maybe fitparse validates header differently?
# Let's compute CRC over different ranges
from debug_crc import crc16_ccitt

print("Trying different CRC ranges:")
print(f"  CRC(bytes 0-11):   0x{crc16_ccitt(data[:12]):04X} (header bytes before CRC)")
print(f"  CRC(bytes 0-13):   0x{crc16_ccitt(data[:14]):04X} (header including CRC field)")
print(f"  CRC(bytes 0-431):  0x{crc16_ccitt(data[:-2]):04X} (all except file CRC)")
print(f"  CRC(bytes 14-431): 0x{crc16_ccitt(data[14:-2]):04X} (data section only)")
print(f"  CRC(bytes 14-433): 0x{crc16_ccitt(data[14:]):04X} (data + file CRC)")
