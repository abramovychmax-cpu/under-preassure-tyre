#!/usr/bin/env python3
import struct
import os

def analyze_fit_file(path):
    """Analyze FIT file structure"""
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return
        
    with open(path, 'rb') as f:
        header = f.read(14)
        
        # Parse header
        h_size = header[0]
        p_ver = header[1]
        profile_ver = struct.unpack('>H', header[2:4])[0]
        data_size = struct.unpack('>I', header[4:8])[0]
        dtype = header[9:13]
        h_crc = struct.unpack('<H', header[12:14])[0]
        
        # Get actual file size
        f.seek(0, 2)
        file_size = f.tell()
        
        # Count messages
        f.seek(h_size)
        data = f.read(data_size)
        msg_count = 0
        
        print(f"\n{'='*50}")
        print(f"File: {path}")
        print(f"{'='*50}")
        print(f"File Size: {file_size} bytes")
        print(f"Header: {h_size} bytes")
        print(f"Data: {data_size} bytes")
        print(f"Protocol Version: {p_ver >> 4}.{p_ver & 0xF}")
        print(f"Profile Version: {profile_ver:#06x}")
        print(f"Data Type: {dtype}")
        print(f"First 40 bytes (hex):")
        
        # Print hex
        for i in range(0, min(40, len(header + data)), 16):
            chunk = (header + data)[i:i+16]
            hex_str = ' '.join(f'{b:02x}' for b in chunk)
            print(f"  {i:04x}: {hex_str}")

# Compare files
files = [
    'assets/sample_fake.fit',
    'test_data/coast_down_20260129_223459.fit',
]

for f in files:
    analyze_fit_file(f)
