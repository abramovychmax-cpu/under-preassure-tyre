#!/usr/bin/env python3
"""Inspect the actual message content"""
import struct

with open('assets/sample_fake.fit', 'rb') as f:
    data = f.read()

payload = data[14:14+3591]

# FileID definition
print('=== FileID Definition ===')
pos = 0
print(f'Offset {pos:04x}: {payload[pos:pos+21].hex()}')
print(f'  Header: 0x{payload[pos]:02x} (def, lmt=0)')
print(f'  GMN: {struct.unpack(">H", payload[pos+3:pos+5])[0]}')
num_fields = payload[pos+5]
print(f'  Fields: {num_fields}')
for i in range(num_fields):
    fid = payload[pos+6+i*3]
    fsize = payload[pos+6+i*3+1]
    ftype = payload[pos+6+i*3+2]
    print(f'    Field {i}: id={fid}, size={fsize}, type=0x{ftype:02x}')

# FileID data
pos = 0x15
print(f'\n=== FileID Data (at 0x{pos:04x}) ===')
print(f'Bytes: {payload[pos:pos+14].hex()}')
record_header = payload[pos]
print(f'  Header: 0x{record_header:02x} (lmt=0)')
# Field 0: type (uint8, 1 byte)
type_val = payload[pos+1]
print(f'  Field 0 (type): {type_val}')
# Field 1: manufacturer (uint16, 2 bytes, big-endian)
manuf_val = struct.unpack('>H', payload[pos+2:pos+4])[0]
print(f'  Field 1 (manufacturer): {manuf_val}')
# Field 2: product (uint16, 2 bytes, big-endian)
prod_val = struct.unpack('>H', payload[pos+4:pos+6])[0]
print(f'  Field 2 (product): {prod_val}')
# Field 3: serial_number (uint32, 4 bytes, big-endian)
serial_val = struct.unpack('>I', payload[pos+6:pos+10])[0]
print(f'  Field 3 (serial): {serial_val}')
# Field 4: time_created (uint32, 4 bytes, big-endian)
time_val = struct.unpack('>I', payload[pos+10:pos+14])[0]
print(f'  Field 4 (time): {time_val}')

# Record definition
print(f'\n=== Record Definition (at 0x23) ===')
pos = 0x23
print(f'Offset {pos:04x}: {payload[pos:pos+18].hex()}')
print(f'  Header: 0x{payload[pos]:02x} (def, lmt=1)')
print(f'  GMN: {struct.unpack(">H", payload[pos+3:pos+5])[0]}')
num_fields = payload[pos+5]
print(f'  Fields: {num_fields}')
for i in range(num_fields):
    fid = payload[pos+6+i*3]
    fsize = payload[pos+6+i*3+1]
    ftype = payload[pos+6+i*3+2]
    fname = {253: 'timestamp', 3: 'speed', 4: 'cadence', 7: 'power'}.get(fid, f'field{fid}')
    print(f'    Field {i}: id={fid} ({fname}), size={fsize}, type=0x{ftype:02x}')

# First Record data
pos = 0x35
print(f'\n=== First Record Data (at 0x{pos:04x}) ===')
print(f'Bytes: {payload[pos:pos+12].hex()}')
record_header = payload[pos]
print(f'  Header: 0x{record_header:02x} (lmt=1)')
# Field 253: timestamp (uint32, 4 bytes, big-endian)
ts_val = struct.unpack('>I', payload[pos+1:pos+5])[0]
print(f'  Field 253 (timestamp): {ts_val}')
# Field 3: speed (float32, 4 bytes, big-endian)
speed_val = struct.unpack('>f', payload[pos+5:pos+9])[0]
print(f'  Field 3 (speed): {speed_val:.2f} m/s')
# Field 4: cadence (uint8, 1 byte)
cadence_val = payload[pos+9]
print(f'  Field 4 (cadence): {cadence_val} rpm')
# Field 7: power (uint16, 2 bytes, big-endian)
power_val = struct.unpack('>H', payload[pos+10:pos+12])[0]
print(f'  Field 7 (power): {power_val} watts')

# Activity definition
print(f'\n=== Activity Definition ===')
# Activity is at 0x35 + 300*11 = 0x35 + 0xB88 = 0xBBD
pos = 0x035 + 300 * 11
print(f'Expected Activity definition at 0x{pos:04x}')
if pos < len(payload):
    print(f'Offset {pos:04x}: {payload[pos:pos+15].hex()}')
    record_header = payload[pos]
    print(f'  Header: 0x{record_header:02x} (is_def={bool(record_header & 0x40)}, lmt={record_header & 0x0f})')
    if record_header & 0x40:
        gmn = struct.unpack(">H", payload[pos+3:pos+5])[0]
        num_fields = payload[pos+5]
        print(f'  GMN: {gmn}, Fields: {num_fields}')
        for i in range(num_fields):
            fid = payload[pos+6+i*3]
            fsize = payload[pos+6+i*3+1]
            ftype = payload[pos+6+i*3+2]
            print(f'    Field {i}: id={fid}, size={fsize}, type=0x{ftype:02x}')

print(f'\n=== CRC Check ===')
# Last 2 bytes should be CRC
crc_bytes = payload[-2:]
crc_val = struct.unpack('<H', crc_bytes)[0]
print(f'CRC at end: {crc_bytes.hex()} = {crc_val}')

# Calculate CRC of payload[:-2]
from fit_summary_fixed import *  # Import the CRC function if available
# Or use a simple nibble-based CRC
FIT_CRC_TABLE = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
]

def calc_crc(data):
    crc = 0
    for byte in data:
        tmp = FIT_CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ FIT_CRC_TABLE[byte & 0xF]
        tmp = FIT_CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ FIT_CRC_TABLE[(byte >> 4) & 0xF]
    return crc

calculated_crc = calc_crc(payload[:-2])
print(f'Calculated CRC: {calculated_crc} (expected {crc_val})')
print(f'CRC match: {calculated_crc == crc_val}')
