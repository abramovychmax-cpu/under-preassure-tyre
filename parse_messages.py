#!/usr/bin/env python3
"""Parse FIT messages properly"""
import struct

with open('assets/sample_fake.fit', 'rb') as f:
    data = f.read()

header = data[:14]
h_size = header[0]
data_size = struct.unpack('>I', header[4:8])[0]
payload = data[h_size:h_size+data_size]

print("Parsing FIT messages...")
print("=" * 80)

pos = 0
msg_num = 0

while pos < len(payload):
    record_header = payload[pos]
    print(f"\n[{msg_num:2d}] Position 0x{pos:04x}: Header byte = 0x{record_header:02x}")
    pos += 1
    msg_num += 1
    
    if msg_num > 20:  # Limit output
        print("...")
        break
    
    is_definition = (record_header & 0x40) != 0
    lmt = record_header & 0x0F
    
    if is_definition:
        print(f"     Type: DEFINITION MESSAGE")
        print(f"     Local Message Type (LMT): {lmt}")
        
        if pos + 5 > len(payload):
            print("     ERROR: Not enough bytes for definition header")
            break
        
        reserved = payload[pos]
        arch = payload[pos+1]
        gmn_bytes = payload[pos+2:pos+4]
        gmn = struct.unpack('>H', gmn_bytes)[0]
        num_fields = payload[pos+4]
        
        print(f"     Reserved: 0x{reserved:02x}")
        print(f"     Architecture: {arch} ({'Big-Endian' if arch == 1 else 'Little-Endian'})")
        print(f"     Global Message Number: {gmn}")
        print(f"     Number of Fields: {num_fields}")
        
        pos += 5
        
        # Skip field definitions
        for i in range(num_fields):
            if pos + 3 > len(payload):
                print(f"     ERROR: Not enough bytes for field {i}")
                break
            fid = payload[pos]
            fsize = payload[pos+1]
            ftype = payload[pos+2]
            print(f"       Field {i}: ID={fid}, Size={fsize}, Type={ftype}")
            pos += 3
    else:
        print(f"     Type: DATA MESSAGE")
        print(f"     Local Message Type (LMT): {lmt}")
        print(f"     Data follows... (not fully parsed)")
        # For data messages, we'd need to know the definition to parse correctly
        break

print("\n" + "=" * 80)
