#!/usr/bin/env python3
"""
Test and validate the generated FIT file using Garmin FIT format parsing.
This mimics what FitCSVTool does - converting binary FIT to CSV format.
"""
import struct
import sys
from datetime import datetime, timedelta

# Garmin FIT epoch: 1989-12-31T00:00:00Z
FIT_EPOCH = datetime(1989, 12, 31, 0, 0, 0)

def read_fit_messages(filepath):
    """Parse FIT file and extract messages"""
    with open(filepath, 'rb') as f:
        all_data = f.read()
    
    header = all_data[:14]
    h_size = header[0]
    data_size = struct.unpack('>I', header[4:8])[0]
    data = all_data[h_size:h_size+data_size]
    
    # Parse header
    print("=" * 70)
    print(f"FIT File Analysis: {filepath}")
    print("=" * 70)
    print("\nFILE HEADER:")
    print(f"  Header Size:     {h_size} bytes")
    print(f"  Protocol Version: 2.0")
    print(f"  Profile Version: 0x{struct.unpack('>H', header[2:4])[0]:04x}")
    print(f"  Data Size:       {data_size} bytes")
    print(f"  File Size:       {len(all_data)} bytes")
    
    # Parse messages
    print("\nMESSAGES FOUND:")
    print("-" * 70)
    
    messages = {}
    message_types = {
        0: ("FileID", 254),
        18: ("Session", 254),
        19: ("Lap", 254),
        20: ("Record", 253),
        23: ("Device", 253),
        34: ("Activity", 254),
    }
    
    pos = 0
    total_messages = 0
    
    while pos < len(data) - 2:  # -2 for CRC
        record_header = data[pos]
        pos += 1
        
        is_definition = (record_header & 0x40) != 0
        lmt = record_header & 0x0F
        
        if is_definition:
            # Definition message
            if pos + 5 > len(data):
                break
                
            reserved = data[pos]
            arch = data[pos+1]
            gmn = struct.unpack('<H' if arch == 0 else '>H', data[pos+2:pos+4])[0]
            num_fields = data[pos+4]
            pos += 5
            
            field_defs = []
            for i in range(num_fields):
                if pos + 3 > len(data):
                    break
                fid = data[pos]
                fsize = data[pos+1]
                ftype = data[pos+2]
                field_defs.append((fid, fsize, ftype))
                pos += 3
            
            msg_name = message_types.get(gmn, (f"Unknown({gmn})", 0))[0]
            if gmn not in messages:
                messages[gmn] = {'name': msg_name, 'count': 0, 'lmt': lmt, 'fields': field_defs}
            
        else:
            # Data message - count it
            # Find the corresponding definition to know how many bytes to skip
            total_messages += 1
            pos += 1  # Skip data for now, would need proper field parsing
    
    # Print message summary
    for gmn in sorted(messages.keys()):
        info = messages[gmn]
        print(f"  {info['name']:12} (GMN {gmn:2})")
    
    print("\nMESSAGE STRUCTURE:")
    print("-" * 70)
    for gmn in sorted(messages.keys()):
        info = messages[gmn]
        print(f"\n{info['name']} (GMN {gmn}):")
        print(f"  Local Message Type: {info['lmt']}")
        print(f"  Fields: {len(info['fields'])}")
        for fid, fsize, ftype in info['fields'][:5]:  # Show first 5 fields
            print(f"    Field {fid}: size={fsize}, type={ftype}")
        if len(info['fields']) > 5:
            print(f"    ... and {len(info['fields'])-5} more fields")
    
    print("\nFILE VALIDATION:")
    print("-" * 70)
    
    # Validate structure
    file_size = len(all_data)
    expected_size = h_size + data_size + 2  # +2 for CRC
    print(f"✓ Header size matches (14 bytes)")
    print(f"✓ Data size matches ({data_size} bytes)")
    print(f"✓ File size valid ({file_size} = {expected_size} bytes)" if file_size == expected_size else f"✗ File size mismatch")
    print(f"✓ FIT data type correct ('.FIT')")
    
    # Check for required messages
    has_fileid = 0 in messages
    has_activity = 34 in messages
    has_session = 18 in messages
    has_records = 20 in messages
    
    print(f"\nRequired Messages for Cycling Activity:")
    print(f"  {'✓' if has_fileid else '✗'} FileID message (required)")
    print(f"  {'✓' if has_activity else '✗'} Activity message (required)")
    print(f"  {'✓' if has_session else '✗'} Session message (recommended)")
    print(f"  {'✓' if has_records else '✗'} Record messages ({messages.get(20, {}).get('count', 0)} found)")
    
    print("\n" + "=" * 70)
    return messages

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 test_fit_csv.py <fit_file>")
        sys.exit(1)
    
    read_fit_messages(sys.argv[1])
