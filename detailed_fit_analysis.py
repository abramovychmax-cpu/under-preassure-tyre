#!/usr/bin/env python3
import struct
import os

def analyze_fit_file(filepath, label):
    """Analyze FIT file structure in detail"""
    print(f"\n{'='*70}")
    print(f"{label}")
    print(f"{'='*70}")
    
    try:
        with open(filepath, 'rb') as f:
            data = f.read()
    except Exception as e:
        print(f"Error reading file: {e}")
        return
    
    if len(data) < 14:
        print(f"File too small: {len(data)} bytes")
        return
    
    # Parse header
    header_size = data[0]
    proto_version = data[1]
    profile_version = struct.unpack('>H', data[2:4])[0]
    data_size = struct.unpack('>I', data[4:8])[0]
    data_type = data[8:12]
    header_crc = struct.unpack('>H', data[12:14])[0]
    
    print(f"File: {os.path.basename(filepath)}")
    print(f"Total file size: {len(data)} bytes")
    print(f"\nHeader (14 bytes):")
    print(f"  Header Size:      {header_size}")
    print(f"  Protocol Version: {proto_version >> 4}.{proto_version & 0x0F}")
    print(f"  Profile Version:  {profile_version}")
    print(f"  Data Size:        {data_size}")
    print(f"  Data Type:        {data_type.hex()} ('{data_type.decode('ascii', errors='ignore')}')")
    print(f"  Header CRC:       0x{header_crc:04X}")
    
    # Expected layout
    data_end = 14 + data_size
    crc_offset = data_end
    
    print(f"\nExpected Structure:")
    print(f"  Bytes 0-13:       Header (14 bytes)")
    print(f"  Bytes 14-{data_end-1}: Data ({data_size} bytes)")
    print(f"  Bytes {crc_offset}-{crc_offset+1}: File CRC (2 bytes)")
    print(f"  Total Expected:   {data_end + 2} bytes")
    print(f"  Actual Size:      {len(data)} bytes")
    
    if len(data) >= crc_offset + 2:
        file_crc = struct.unpack('>H', data[crc_offset:crc_offset + 2])[0]
        print(f"  File CRC:         0x{file_crc:04X}")
        if len(data) == data_end + 2:
            print(f"  ✓ Size matches expected FIT format")
        else:
            print(f"  ✗ File size mismatch! Expected {data_end + 2}, got {len(data)}")
    else:
        print(f"  ✗ File too short for CRC (need {crc_offset + 2}, have {len(data)})")
    
    # Parse messages in detail
    print(f"\nMessage Structure (first 10 messages):")
    offset = 14
    msg_count = 0
    
    while offset < data_end and msg_count < 10:
        if offset >= len(data):
            break
            
        record_header = data[offset]
        is_definition = (record_header & 0x40) != 0
        lmt = record_header & 0x0F
        
        if is_definition:
            # Definition message
            if offset + 6 > len(data):
                break
                
            reserved = data[offset + 1]
            architecture = data[offset + 2]
            gmn = struct.unpack('>H', data[offset + 3:offset + 5])[0]
            num_fields = data[offset + 5]
            
            field_data_size = num_fields * 3
            if offset + 6 + field_data_size > len(data):
                break
            
            msg_size = 6 + field_data_size
            print(f"\n  Msg {msg_count}: DEF (offset {offset}, {msg_size} bytes)")
            print(f"    Header: 0x{record_header:02X}, LMT={lmt}, Reserved={reserved}")
            print(f"    Global Message: {gmn}, Architecture: {'BE' if architecture else 'LE'}, Fields: {num_fields}")
            
            field_start = offset + 6
            for i in range(num_fields):
                field_id = data[field_start + i*3]
                field_sz = data[field_start + i*3 + 1]
                field_type = data[field_start + i*3 + 2]
                print(f"      Field {field_id:2d}: size={field_sz}, type=0x{field_type:02X}")
            
            offset += msg_size
        else:
            # Data message
            print(f"\n  Msg {msg_count}: DATA (offset {offset}, 1-byte header)")
            print(f"    Header: 0x{record_header:02X}, LMT={lmt}")
            offset += 1
        
        msg_count += 1
    
    print(f"\nTotal messages analyzed: {msg_count}")
    
    # Show first 100 bytes of raw data for debugging
    print(f"\nFirst 100 bytes (hex):")
    hex_data = ' '.join(f'{b:02X}' for b in data[:min(100, len(data))])
    for i in range(0, len(hex_data), 96):
        print(f"  {hex_data[i:i+96]}")


# Analyze files
files_to_analyze = [
    ("test_data/coast_down_20260119_173429.fit", "Generated Coastal Down Test (our app)"),
    ("test_data/wahoo_test_new.fit", "Wahoo Reference File"),
    ("test_data/export_57540117/activities/11684379633.fit", "Strava Reference File #1"),
    ("test_data/export_57540117/activities/8422253208.fit/8422253208.fit", "Strava Reference File #2"),
]

for filepath, label in files_to_analyze:
    if os.path.exists(filepath):
        analyze_fit_file(filepath, label)
    else:
        print(f"\nFile not found: {filepath}")
