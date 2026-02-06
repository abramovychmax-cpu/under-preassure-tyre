#!/usr/bin/env python3
"""Parse and print FIT file messages"""
import struct

def read_fit_messages(filepath):
    with open(filepath, 'rb') as f:
        all_data = f.read()
    
    header = all_data[:14]
    h_size = header[0]
    data_size = struct.unpack('>I', header[4:8])[0]
    data = all_data[h_size:h_size+data_size]
    
    # Parse messages
    pos = 0
    msg_count = 0
    msg_types = {}
    
    while pos < len(data) - 2:  # -2 for CRC
        record_header = data[pos]
        pos += 1
        
        is_definition = (record_header & 0x40) != 0
        lmt = record_header & 0x0F
        
        if is_definition:
            # Definition message
            reserved = data[pos]
            arch = data[pos+1]
            gmn = struct.unpack('<H' if arch == 0 else '>H', data[pos+2:pos+4])[0]
            num_fields = data[pos+4]
            pos += 5
            
            field_defs = []
            for i in range(num_fields):
                fid = data[pos]
                fsize = data[pos+1]
                ftype = data[pos+2]
                field_defs.append((fid, fsize, ftype))
                pos += 3
            
            msg_type_name = {0: "FileID", 18: "Session", 19: "Lap", 20: "Record", 23: "Device", 34: "Activity"}.get(gmn, f"Unknown({gmn})")
            if gmn not in msg_types:
                msg_types[gmn] = {'name': msg_type_name, 'count': 0, 'lmt': lmt}
            
        else:
            # Data message
            if lmt not in msg_types.values() and pos < len(data):
                pos += 1
                continue
            pos += 1  # Skip data for now
            msg_count += 1
    
    print(f"File: {filepath}")
    print(f"Message types found:")
    for gmn in sorted(msg_types.keys()):
        info = msg_types[gmn]
        print(f"  {info['name']:12} (GMN {gmn:2})")

# Check real file
read_fit_messages('test_data/coast_down_20260129_223459.fit')
print()

# Check our file
read_fit_messages('assets/sample_fake.fit')
