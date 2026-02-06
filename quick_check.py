#!/usr/bin/env python3
import struct

with open('assets/sample_fake.fit', 'rb') as f:
    header = f.read(14)
    
    # Parse header
    h_size = header[0]
    p_ver = header[1]
    profile_ver = struct.unpack('>H', header[2:4])[0]  # Big-endian
    data_size = struct.unpack('>I', header[4:8])[0]  # Big-endian
    dtype = header[9:13]
    h_crc = struct.unpack('<H', header[12:14])[0]  # Little-endian
    
    # Get actual file size
    f.seek(0, 2)
    file_size = f.tell()
    
    print(f"Header Size: {h_size}")
    print(f"Protocol Version: {p_ver >> 4}.{p_ver & 0xF}")
    print(f"Profile Version: {profile_ver:#06x}")
    print(f"Data Size (from header): {data_size} bytes")
    print(f"Data Type: {dtype}")
    print(f"Header CRC: {h_crc:#06x}")
    print(f"Actual File Size: {file_size} bytes")
    print(f"Expected File Size: {h_size + data_size + 2} bytes")
    print(f"✓ File structure is valid!" if file_size == h_size + data_size + 2 else "✗ File size mismatch!")
