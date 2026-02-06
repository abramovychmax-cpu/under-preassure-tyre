#!/usr/bin/env python3
"""Deep dive into binary message structure"""

import struct

def analyze_messages(filepath, max_msgs=20):
    """Analyze messages in detail"""
    with open(filepath, 'rb') as f:
        data = f.read()
    
    print(f"\n{filepath}:")
    print(f"File size: {len(data)} bytes\n")
    
    # Skip header
    offset = 14
    msg_num = 0
    definitions = {}
    
    while offset < len(data) - 2 and msg_num < max_msgs:
        record_header = data[offset]
        is_def = (record_header & 0x40) != 0
        lmt = record_header & 0x0F
        
        print(f"Offset 0x{offset:04X} | ", end="")
        
        if is_def:
            # Definition message
            reserved = data[offset + 1]
            arch = data[offset + 2]
            gmn = struct.unpack('>H', data[offset + 3:offset + 5])[0]
            num_fields = data[offset + 5]
            
            print(f"DEF LMT={lmt} GMN={gmn} ({num_fields} fields)")
            
            field_info = []
            for i in range(num_fields):
                fid = data[offset + 6 + i*3]
                fsize = data[offset + 6 + i*3 + 1]
                ftype = data[offset + 6 + i*3 + 2]
                field_info.append((fid, fsize, ftype))
                print(f"         └─ Field {fid}: {fsize} bytes, type 0x{ftype:02X}")
            
            definitions[lmt] = {'gmn': gmn, 'fields': field_info}
            offset += 6 + num_fields * 3
        else:
            # Data message
            if lmt in definitions:
                gmn = definitions[lmt]['gmn']
                field_info = definitions[lmt]['fields']
                data_size = sum(fs for _, fs, _ in field_info)
                hex_bytes = ' '.join(f'{b:02X}' for b in data[offset + 1:min(offset + 1 + 10, len(data))])
                print(f"DATA LMT={lmt} GMN={gmn} ({data_size} bytes) | {hex_bytes}")
                offset += 1 + data_size
            else:
                print(f"DATA LMT={lmt} [UNDEFINED]")
                offset += 1
        
        msg_num += 1
    
    print(f"\nFile CRC: 0x{struct.unpack('>H', data[-2:])[0]:04X}")

# Analyze both files
analyze_messages('test_minimal.fit')
analyze_messages('test_output_new.fit')
