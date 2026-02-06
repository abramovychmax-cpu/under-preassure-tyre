#!/usr/bin/env python3
"""
CRITICAL FINDING: Garmin FIT CRC is NOT CRC-16/CCITT!

From official Garmin docs:
https://developer.garmin.com/fit/protocol/

The Garmin FIT CRC is a DIFFERENT algorithm than CRC-16/CCITT.
It uses a nibble-based (4-bit) computation, NOT byte-based!

Official Garmin CRC code:
```c
FIT_UINT16 FitCRC_Get16(FIT_UINT16 crc, FIT_UINT8 byte)
{
   static const FIT_UINT16 crc_table[16] =
   {
      0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
      0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400
   };
   FIT_UINT16 tmp;

   // compute checksum of lower four bits of byte
   tmp = crc_table[crc & 0xF];
   crc = (crc >> 4) & 0x0FFF;
   crc = crc ^ tmp ^ crc_table[byte & 0xF];

   // now compute checksum of upper four bits of byte
   tmp = crc_table[crc & 0xF];
   crc = (crc >> 4) & 0x0FFF;
   crc = crc ^ tmp ^ crc_table[(byte >> 4) & 0xF];

   return crc;
}
```

THIS IS THE ACTUAL GARMIN CRC ALGORITHM!
"""

def fit_crc_get16(crc, byte):
    """
    The ACTUAL Garmin FIT CRC algorithm
    This is different from CRC-16/CCITT!
    """
    crc_table = [
        0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400
    ]
    
    # compute checksum of lower four bits of byte
    tmp = crc_table[crc & 0xF]
    crc = (crc >> 4) & 0x0FFF
    crc = crc ^ tmp ^ crc_table[byte & 0xF]
    
    # now compute checksum of upper four bits of byte
    tmp = crc_table[crc & 0xF]
    crc = (crc >> 4) & 0x0FFF
    crc = crc ^ tmp ^ crc_table[(byte >> 4) & 0xF]
    
    return crc

def garmin_fit_crc(data):
    """Calculate Garmin FIT CRC over data"""
    crc = 0
    for byte in data:
        crc = fit_crc_get16(crc, byte)
    return crc

import struct

def validate_with_garmin_crc(filepath):
    """Validate a FIT file using the ACTUAL Garmin CRC algorithm"""
    try:
        with open(filepath, 'rb') as f:
            data = f.read()
    except:
        return None
    
    if len(data) < 14:
        return None
    
    # Extract stored CRCs
    header_crc_stored = struct.unpack('<H', data[12:14])[0]  # Little Endian!
    file_crc_stored = struct.unpack('<H', data[-2:])[0]      # Little Endian!
    
    # Calculate CRCs using Garmin algorithm
    header_crc_calc = garmin_fit_crc(data[:12])
    file_crc_calc = garmin_fit_crc(data[:-2])
    
    return {
        'size': len(data),
        'header_crc_stored': header_crc_stored,
        'header_crc_calc': header_crc_calc,
        'header_crc_ok': header_crc_stored == header_crc_calc,
        'file_crc_stored': file_crc_stored,
        'file_crc_calc': file_crc_calc,
        'file_crc_ok': file_crc_stored == file_crc_calc,
    }

print("\n" + "="*100)
print("CRITICAL: GARMIN FIT CRC IS DIFFERENT!")
print("="*100)
print("\nOur files were using CRC-16/CCITT (WRONG)")
print("Garmin FIT uses a DIFFERENT algorithm - nibble-based (4-bit) computation")
print("File CRC and Header CRC are in LITTLE ENDIAN format")
print("\n" + "="*100)

files = [
    'test_minimal.fit',
    'test_comprehensive.fit',
    'test_fixed_writer.fit',
]

for fname in files:
    result = validate_with_garmin_crc(fname)
    if result:
        print(f"\n{fname} ({result['size']} bytes):")
        print(f"  Header CRC: Stored=0x{result['header_crc_stored']:04X}, "
              f"Calc=0x{result['header_crc_calc']:04X}, "
              f"Match={'✓ YES' if result['header_crc_ok'] else '✗ NO'}")
        print(f"  File CRC:   Stored=0x{result['file_crc_stored']:04X}, "
              f"Calc=0x{result['file_crc_calc']:04X}, "
              f"Match={'✓ YES' if result['file_crc_ok'] else '✗ NO'}")

# Try Strava file
print("\n" + "-"*100)
result = validate_with_garmin_crc('test_data/export_57540117/activities/8422253208.fit/8422253208.fit')
if result:
    print(f"\nStrava file (366,397 bytes):")
    print(f"  Header CRC: Stored=0x{result['header_crc_stored']:04X}, "
          f"Calc=0x{result['header_crc_calc']:04X}, "
          f"Match={'✓ YES' if result['header_crc_ok'] else '✗ NO'}")
    print(f"  File CRC:   Stored=0x{result['file_crc_stored']:04X}, "
          f"Calc=0x{result['file_crc_calc']:04X}, "
          f"Match={'✓ YES' if result['file_crc_ok'] else '✗ NO'}")

print("\n" + "="*100)
