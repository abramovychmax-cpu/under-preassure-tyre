#!/usr/bin/env python3
"""Detailed analysis of first few messages"""
import struct

with open('assets/sample_fake.fit', 'rb') as f:
    data = f.read()

header = data[:14]
h_size = header[0]
data_size = struct.unpack('>I', header[4:8])[0]
payload = data[h_size:h_size+data_size]

print("Detailed FIT Message Parse")
print("=" * 80)

pos = 0
msg_num = 0

while pos < min(len(payload), 500):  # Stop after 500 bytes
    record_header = payload[pos]
    print(f"\n[Offset 0x{pos:04x}] Record header = 0x{record_header:02x}")
    pos += 1
    msg_num += 1
    
    is_definition = (record_header & 0x40) != 0
    lmt = record_header & 0x0F
    
    if is_definition:
        print(f"  Type: DEFINITION MESSAGE, LMT={lmt}")
        
        if pos + 5 > len(payload):
            print("  ERROR: Not enough bytes")
            break
        
        reserved = payload[pos]
        arch = payload[pos+1]
        gmn_bytes = payload[pos+2:pos+4]
        gmn = struct.unpack('>H', gmn_bytes)[0]
        num_fields = payload[pos+4]
        
        print(f"  Reserved: 0x{reserved:02x}")
        print(f"  Architecture: {arch} ({'BE' if arch == 1 else 'LE'})")
        print(f"  GMN bytes: {gmn_bytes.hex()} -> {gmn}")
        print(f"  Field count: {num_fields}")
        
        pos += 5
        
        # Show field definitions
        for i in range(min(num_fields, 15)):  # Show first 15 fields
            if pos + 3 > len(payload):
                print(f"  Field {i}: ERROR - not enough bytes")
                break
            fid = payload[pos]
            fsize = payload[pos+1]
            ftype = payload[pos+2]
            print(f"    Field {i}: ID=0x{fid:02x}({fid:3d}) Size={fsize:2d} Type=0x{ftype:02x}")
            pos += 3
        
        if num_fields > 15:
            pos += (num_fields - 15) * 3
            print(f"    ... and {num_fields - 15} more fields")
    else:
        # Data message
        print(f"  Type: DATA MESSAGE, LMT={lmt}")
        print(f"  First 32 data bytes: {payload[pos:pos+32].hex()}")
        # Would need to know field layout to skip correctly
        break

print("\n" + "=" * 80)
