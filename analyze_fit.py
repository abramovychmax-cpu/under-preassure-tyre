#!/usr/bin/env python3
import struct
import os
import sys

def analyze_fit_file(filepath):
    """Analyze FIT file structure"""
    with open(filepath, 'rb') as f:
        data = f.read()
    
    if len(data) < 14:
        print(f"File too small: {len(data)} bytes")
        return
    
    # Parse header
    header_size = data[0]
    proto_version = data[1]
    profile_version = struct.unpack('>H', data[2:4])[0]
    data_size = struct.unpack('>I', data[4:8])[0]
    data_type = data[8:12].decode('ascii', errors='ignore')
    header_crc = struct.unpack('>H', data[12:14])[0]
    
    print(f"=== FIT File Header Analysis ===")
    print(f"File: {os.path.basename(filepath)}")
    print(f"Total file size: {len(data)} bytes")
    print(f"Header size: {header_size}")
    print(f"Protocol version: {proto_version >> 4}.{proto_version & 0x0F}")
    print(f"Profile version: {profile_version >> 8}.{profile_version & 0xFF}")
    print(f"Data size: {data_size}")
    print(f"Data type: '{data_type}'")
    print(f"Header CRC: 0x{header_crc:04X}")
    print(f"File CRC offset: {14 + data_size}")
    
    if len(data) >= 14 + data_size + 2:
        file_crc = struct.unpack('>H', data[14 + data_size:14 + data_size + 2])[0]
        print(f"File CRC: 0x{file_crc:04X}")
    
    # Parse first few messages
    print(f"\n=== Message Structure (first 15 messages) ===")
    offset = 14
    msg_count = 0
    while offset < min(14 + data_size, len(data) - 2) and msg_count < 15:
        record_header = data[offset]
        is_definition = (record_header & 0x40) != 0
        lmt = record_header & 0x0F
        
        if is_definition:
            # Definition message
            reserved = data[offset + 1]
            architecture = data[offset + 2]
            gmn = struct.unpack('>H', data[offset + 3:offset + 5])[0]
            num_fields = data[offset + 5]
            
            print(f"\nMsg {msg_count} (DEF): Offset {offset}, LMT={lmt}, GMN={gmn}, NumFields={num_fields}, Arch={'BE' if architecture else 'LE'}")
            
            field_start = offset + 6
            for i in range(num_fields):
                field_id = data[field_start + i*3]
                field_sz = data[field_start + i*3 + 1]
                field_type = data[field_start + i*3 + 2]
                print(f"  Field {field_id}: size={field_sz}, type=0x{field_type:02X}")
            
            offset += 6 + num_fields * 3
        else:
            # Data message
            print(f"\nMsg {msg_count} (DATA): Offset {offset}, LMT={lmt}")
            offset += 1
        
        msg_count += 1
    
    print(f"\nTotal messages analyzed: {msg_count}")
    print(f"\n=== File Structure ===")
    print(f"Expected structure: [14-byte header][{data_size}-byte data][2-byte CRC]")
    print(f"Actual file size:   [{header_size}-byte header][{14 + data_size}-byte to data end][{len(data)}-byte total]")
    if len(data) == 14 + data_size + 2:
        print("✓ File structure matches expected FIT format")
    else:
        print(f"✗ File size mismatch! Expected {14 + data_size + 2}, got {len(data)}")

# Analyze the Strava file
strava_file = "test_data/export_57540117/activities/8422253208.fit"
if os.path.exists(strava_file):
    print("=" * 70)
    print("STRAVA FILE (Reference - Known Good)")
    print("=" * 70)
    analyze_fit_file(strava_file)
else:
    print(f"File not found: {strava_file}")

# Try to generate a test file
print("\n\n")
print("=" * 70)
print("GENERATED TEST FILE")
print("=" * 70)

# Run the test script to generate a file
import subprocess
result = subprocess.run([sys.executable, "tools/test_fit_writer.dart"], 
                       capture_output=True, text=True, cwd=".")
print("Test script output:")
print(result.stdout)
if result.stderr:
    print("Errors:")
    print(result.stderr)

# Look for generated files
test_files = [
    "test_fit_output.fit",
    "test_data/test_fit_output.fit",
    "build/test_fit_output.fit"
]

found_file = None
for test_file in test_files:
    if os.path.exists(test_file):
        found_file = test_file
        break

if found_file:
    analyze_fit_file(found_file)
else:
    print("Could not find generated test file")
    print("Searching for recent .fit files...")
    for root, dirs, files in os.walk("."):
        for f in files:
            if f.endswith(".fit") and "test" in f.lower():
                filepath = os.path.join(root, f)
                stat = os.stat(filepath)
                print(f"  {filepath} ({stat.st_size} bytes)")
