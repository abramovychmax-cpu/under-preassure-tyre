#!/usr/bin/env python3
"""Debug FIT message parser"""
import struct

with open('assets/sample_fake.fit', 'rb') as f:
    data = f.read()

# Parse header
header = data[:14]
h_size = header[0]
data_size = struct.unpack('>I', header[4:8])[0]
print(f"Header size: {h_size}, Data size: {data_size}")

# Extract payload
payload = data[h_size:h_size+data_size]
print(f"Payload starts at offset {h_size}, length {len(payload)}")
print()

# Hex dump first 100 bytes of payload
print("Hex dump (payload offsets):")
for i in range(0, min(100, len(payload)), 16):
    chunk = payload[i:i+16]
    hex_str = ' '.join(f'{b:02x}' for b in chunk)
    print(f"{i:04x}: {hex_str}")

print("\nMessage parsing:")
pos = 0
def_index = 0

record_header = payload[pos]
print(f"\npos={pos:04x}: record_header={record_header:02x}")
pos += 1

is_definition = (record_header & 0x40) != 0
lmt = record_header & 0x0F
print(f"  is_definition={is_definition}, lmt={lmt}")

if is_definition:
    reserved = payload[pos]
    arch = payload[pos+1]
    gmn_bytes = payload[pos+2:pos+4]
    gmn = struct.unpack('>H', gmn_bytes)[0]
    num_fields = payload[pos+4]
    
    print(f"  reserved={reserved:02x} (at pos+0={pos:04x})")
    print(f"  arch={arch:02x} (at pos+1={pos+1:04x})")
    print(f"  gmn_bytes={gmn_bytes.hex()} (at pos+2:pos+4={pos+2:04x}:{pos+4:04x})")
    print(f"  gmn={gmn} (decoded)")
    print(f"  num_fields={num_fields} (at pos+4={pos+4:04x})")
    
    pos += 5
    print(f"  After reading definition: pos={pos:04x}")
    
    # Read field definitions
    print(f"  Field definitions:")
    for i in range(num_fields):
        if pos + 3 > len(payload):
            break
        field_id = payload[pos]
        field_size = payload[pos+1]
        field_type = payload[pos+2]
        print(f"    Field {i}: id={field_id}, size={field_size}, type={field_type:02x}")
        pos += 3
    
    print(f"  After reading {num_fields} fields: pos={pos:04x}")

# Now read first data message
print(f"\nNext message at pos={pos:04x}:")
if pos < len(payload):
    record_header = payload[pos]
    print(f"pos={pos:04x}: record_header={record_header:02x}")
    is_definition = (record_header & 0x40) != 0
    lmt = record_header & 0x0F
    print(f"  is_definition={is_definition}, lmt={lmt}")
    pos += 1
    
    # Read some data bytes
    if not is_definition and pos < len(payload):
        print(f"  Data starts at pos={pos:04x}")
        data_chunk = payload[pos:min(pos+20, len(payload))]
        hex_str = ' '.join(f'{b:02x}' for b in data_chunk)
        print(f"  Hex: {hex_str}")
