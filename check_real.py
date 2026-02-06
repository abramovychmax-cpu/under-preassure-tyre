#!/usr/bin/env python3
import struct
import os

real_file = 'test_data/coast_down_20260129_223459.fit'

with open(real_file, 'rb') as f:
    h = f.read(14)
    
    # Parse header with both endianness
    pver_be = struct.unpack('>H', h[2:4])[0]
    pver_le = struct.unpack('<H', h[2:4])[0]
    dsize_be = struct.unpack('>I', h[4:8])[0]
    dsize_le = struct.unpack('<I', h[4:8])[0]
    
    f.seek(0, 2)
    actual_size = f.tell()
    
    print(f"Real File: {real_file}")
    print(f"Profile version (BE): {pver_be:#06x} ({pver_be})")
    print(f"Profile version (LE): {pver_le:#06x} ({pver_le})")
    print(f"Data size (BE): {dsize_be}")
    print(f"Data size (LE): {dsize_le}")
    print(f"Actual file size: {actual_size}")
    print(f"Expected (BE): {14 + dsize_be + 2}")
    print(f"Expected (LE): {14 + dsize_le + 2}")
    
    # Check if data size is LE (462 is what we expect)
    print(f"\nData section should be: {actual_size - 14 - 2} = {actual_size - 16} bytes")
    print(f"Matches LE? {dsize_le == actual_size - 16}")
    print(f"Matches BE? {dsize_be == actual_size - 16}")
