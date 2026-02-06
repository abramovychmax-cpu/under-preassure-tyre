#!/usr/bin/env python3
"""
Comprehensive FIT File Validator
Verifies that generated FIT files conform to the Garmin FIT specification.
"""

import struct
import sys

def garmin_fit_crc(data):
    """Calculate CRC using Garmin's nibble-based algorithm"""
    crc_table = [
        0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
    ]
    
    crc = 0
    for byte in data:
        # Process lower nibble
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[byte & 0xF]
        
        # Process upper nibble
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[(byte >> 4) & 0xF]
    
    return crc

def validate_fit_file(filepath):
    """Validate a FIT file"""
    try:
        with open(filepath, 'rb') as f:
            data = f.read()
        
        print(f"\n{'='*60}")
        print(f"FIT File: {filepath}")
        print(f"{'='*60}")
        print(f"File size: {len(data)} bytes")
        
        # Parse header
        if len(data) < 14:
            print("✗ ERROR: File too short for header")
            return False
        
        header_size = data[0]
        protocol_version = data[1]
        profile_version = struct.unpack('>H', data[2:4])[0]
        data_size = struct.unpack('>I', data[4:8])[0]
        data_type = bytes(data[8:12]).decode('ascii', errors='ignore')
        
        print(f"\nHeader Information:")
        print(f"  Header Size:      {header_size} bytes")
        print(f"  Protocol Version: {protocol_version >> 4}.{protocol_version & 0xF}")
        print(f"  Profile Version:  {profile_version}")
        print(f"  Data Size:        {data_size} bytes")
        print(f"  Data Type:        '{data_type}'")
        
        # Verify data type
        if data_type != '.FIT':
            print(f"✗ ERROR: Invalid data type '{data_type}', expected '.FIT'")
            return False
        
        # Check total file size
        expected_size = header_size + data_size + 2  # +2 for file CRC
        if len(data) != expected_size:
            print(f"✗ ERROR: File size mismatch. Expected {expected_size}, got {len(data)}")
            return False
        
        # Verify header CRC
        header_data = data[:header_size-2]
        header_crc_stored = struct.unpack('<H', data[header_size-2:header_size])[0]
        header_crc_calc = garmin_fit_crc(header_data)
        
        print(f"\nCRC Verification:")
        print(f"  Header CRC:")
        print(f"    Stored:     0x{header_crc_stored:04x}")
        print(f"    Calculated: 0x{header_crc_calc:04x}")
        if header_crc_stored == header_crc_calc:
            print(f"    Status:     ✓ VALID")
        else:
            print(f"    Status:     ✗ MISMATCH")
            return False
        
        # Verify file CRC
        file_crc_stored = struct.unpack('<H', data[-2:])[0]
        file_crc_calc = garmin_fit_crc(data[:-2])
        
        print(f"  File CRC:")
        print(f"    Stored:     0x{file_crc_stored:04x}")
        print(f"    Calculated: 0x{file_crc_calc:04x}")
        if file_crc_stored == file_crc_calc:
            print(f"    Status:     ✓ VALID")
        else:
            print(f"    Status:     ✗ MISMATCH")
            return False
        
        print(f"\n{'='*60}")
        print(f"Result: ✓ VALID FIT FILE")
        print(f"{'='*60}")
        return True
    
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

if __name__ == '__main__':
    files = [
        'test_minimal.fit',
        'test_fixed_writer.fit', 
        'test_comprehensive.fit',
        'dart_test_output.fit',
    ]
    
    results = {}
    for filepath in files:
        try:
            results[filepath] = validate_fit_file(filepath)
        except FileNotFoundError:
            print(f"\n✗ File not found: {filepath}")
            results[filepath] = False
    
    # Summary
    print(f"\n\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for filepath, valid in results.items():
        status = "✓ VALID" if valid else "✗ INVALID"
        print(f"{filepath:30} {status}")
    
    all_valid = all(results.values())
    print(f"{'='*60}")
    if all_valid:
        print("✓ ALL FILES VALID")
        sys.exit(0)
    else:
        print("✗ SOME FILES INVALID")
        sys.exit(1)
