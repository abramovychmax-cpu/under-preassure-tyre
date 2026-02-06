#!/usr/bin/env python3
import struct
import os

def analyze_fit_file(filepath, label):
    """Analyze FIT file structure in detail"""
    print(f"\n{'='*80}")
    print(f"{label}")
    print(f"{'='*80}")
    
    try:
        with open(filepath, 'rb') as f:
            data = f.read()
    except Exception as e:
        print(f"Error reading file: {e}")
        return None
    
    if len(data) < 14:
        print(f"File too small: {len(data)} bytes")
        return None
    
    # Parse header
    header_size = data[0]
    proto_version = data[1]
    profile_version = struct.unpack('>H', data[2:4])[0]
    data_size = struct.unpack('>I', data[4:8])[0]
    data_type = data[8:12]
    header_crc = struct.unpack('>H', data[12:14])[0]
    
    print(f"File: {os.path.basename(filepath)}")
    print(f"Total size: {len(data)} bytes\n")
    print(f"Header Analysis (first 14 bytes):")
    print(f"  [0]       Header Size:      {header_size}")
    print(f"  [1]       Proto Version:    {proto_version >> 4}.{proto_version & 0x0F}")
    print(f"  [2-3]     Profile Version:  {profile_version}")
    print(f"  [4-7]     Data Size:        {data_size}")
    print(f"  [8-11]    Data Type:        {repr(data_type)}")
    print(f"  [12-13]   Header CRC:       0x{header_crc:04X}")
    
    data_end = 14 + data_size
    crc_offset = data_end
    
    print(f"\nStructure Check:")
    print(f"  Expected end of data: byte {data_end}")
    print(f"  Expected CRC at:      bytes {crc_offset}-{crc_offset+1}")
    print(f"  Expected total size:  {data_end + 2} bytes")
    print(f"  Actual total size:    {len(data)} bytes")
    
    if len(data) >= crc_offset + 2:
        file_crc = struct.unpack('>H', data[crc_offset:crc_offset + 2])[0]
        print(f"  File CRC at offset {crc_offset}: 0x{file_crc:04X}")
        if len(data) == data_end + 2:
            print(f"  ✓ File structure is CORRECT")
        else:
            print(f"  ✗ File size mismatch!")
    
    # Show first 150 bytes
    print(f"\nFirst 150 bytes (hex dump):")
    for i in range(0, min(150, len(data)), 16):
        hex_part = ' '.join(f'{b:02X}' for b in data[i:i+16])
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
        print(f"  {i:04X}: {hex_part:<48} {ascii_part}")
    
    return data

# Generate a fresh test file using our current code
import subprocess
import sys

print("Generating fresh test file with current code...")
result = subprocess.run([sys.executable, "-c", """
import 'dart:io';
import 'dart:typed_data';
import 'package:tyre_preassure/fit/protocol.dart';
import 'package:tyre_preassure/fit/writer_impl.dart';

void main() async {
  final outputPath = 'test_fresh.fit';
  final file = File(outputPath);
  final sink = file.openWrite();
  final writer = RealFitWriter(sink, outputPath);
  writer.writeFileHeader();
  await writer.finalize();
}
"""], capture_output=True, text=True, cwd=".")

if result.returncode == 0:
    print("Test file generation succeeded")
else:
    print(f"Generation output: {result.stdout}")

# Analyze the Strava file
print("\n" + "="*80)
print("COMPARING: Strava Reference vs Our Generated Files")
print("="*80)

strava_data = analyze_fit_file(
    "test_data/export_57540117/activities/8422253208.fit/8422253208.fit",
    "REFERENCE: Strava Downloaded FIT File"
)

# Compare with our generated files
ours_data = analyze_fit_file(
    "test_fresh.fit" if os.path.exists("test_fresh.fit") else "test_output_new.fit",
    "GENERATED: Fresh Test File (Current Code)"
)

if strava_data and ours_data:
    print(f"\n\n{'='*80}")
    print("DETAILED COMPARISON")
    print(f"{'='*80}")
    print(f"\nStrava File Size:  {len(strava_data)} bytes")
    print(f"Our File Size:     {len(ours_data)} bytes")
    print(f"Difference:        {len(strava_data) - len(ours_data)} bytes")
    
    # Compare headers
    print(f"\nHeader Comparison (first 14 bytes):")
    strava_header = strava_data[:14]
    ours_header = ours_data[:14]
    
    for i in range(14):
        s = strava_header[i]
        o = ours_header[i]
        match = "✓" if s == o else "✗"
        print(f"  [{i:2d}] Strava: 0x{s:02X}  Ours: 0x{o:02X}  {match}")
