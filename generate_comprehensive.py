#!/usr/bin/env python3
"""
Create a comprehensive test FIT file that includes all recommended messages for Strava.
Hand-crafted for maximum compatibility.
"""

import struct

def write_uint8(b, v):
    b.append(v & 0xFF)

def write_uint16_be(b, v):
    b.append((v >> 8) & 0xFF)
    b.append(v & 0xFF)

def write_uint32_be(b, v):
    b.append((v >> 24) & 0xFF)
    b.append((v >> 16) & 0xFF)
    b.append((v >> 8) & 0xFF)
    b.append(v & 0xFF)

def write_float32_be(b, v):
    # IEEE 754 single precision
    import struct as s
    packed = s.pack('>f', v)
    b.extend(packed)

def write_sint32_be(b, v):
    if v < 0:
        v = (1 << 32) + v  # Two's complement
    write_uint32_be(b, v)

def garmin_fit_crc(data):
    """Garmin FIT CRC (nibble-based, NOT CRC-16/CCITT)"""
    crc_table = [
        0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
    ]
    
    crc = 0
    for byte in data:
        # compute checksum of lower four bits of byte
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[byte & 0xF]
        
        # now compute checksum of upper four bits of byte
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[(byte >> 4) & 0xF]
    return crc

def create_comprehensive_fit():
    """Create a comprehensive Strava-compatible FIT file"""
    
    header = []
    data_msg = []
    
    # HEADER (14 bytes)
    header.append(14)                      # Header size
    header.append(0x20)                    # Protocol 2.0
    write_uint16_be(header, 2163)          # Profile version
    # Data size (placeholder, will update)
    write_uint32_be(header, 0)
    header.extend(b'.FIT')                 # Data type
    write_uint16_be(header, 0)             # Header CRC (placeholder)
    
    # MESSAGE 1: FileID definition (LMT=0, GMN=0)
    data_msg.append(0x40)                  # DEF, LMT=0
    data_msg.append(0x00)                  # Reserved
    data_msg.append(0x01)                  # Architecture (Big Endian)
    write_uint16_be(data_msg, 0)           # GMN = 0 (FileID)
    data_msg.append(0x04)                  # Number of fields
    
    # FileID fields
    data_msg.append(0x00); data_msg.append(0x01); data_msg.append(0x00)  # Field 0: 1 byte, enum
    data_msg.append(0x01); data_msg.append(0x02); data_msg.append(0x84)  # Field 1: 2 bytes, uint16
    data_msg.append(0x02); data_msg.append(0x02); data_msg.append(0x84)  # Field 2: 2 bytes, uint16
    data_msg.append(0x04); data_msg.append(0x04); data_msg.append(0x86)  # Field 4: 4 bytes, uint32
    
    # MESSAGE 1: FileID data
    data_msg.append(0x00)                  # LMT=0
    data_msg.append(0x04)                  # type = Activity
    write_uint16_be(data_msg, 1)           # manufacturer = Garmin
    write_uint16_be(data_msg, 1)           # product = 1
    write_uint32_be(data_msg, 0x30390000)  # timestamp
    
    # MESSAGE 2: Record definition (LMT=1, GMN=20)
    data_msg.append(0x41)                  # DEF, LMT=1
    data_msg.append(0x00)                  # Reserved
    data_msg.append(0x01)                  # Architecture
    write_uint16_be(data_msg, 20)          # GMN = 20 (Record)
    data_msg.append(0x06)                  # Number of fields
    
    # Record fields
    data_msg.append(0xFD); data_msg.append(0x04); data_msg.append(0x86)  # Field 253: 4 bytes, uint32 (timestamp)
    data_msg.append(0x00); data_msg.append(0x04); data_msg.append(0x85)  # Field 0: 4 bytes, sint32 (lat)
    data_msg.append(0x01); data_msg.append(0x04); data_msg.append(0x85)  # Field 1: 4 bytes, sint32 (lon)
    data_msg.append(0x06); data_msg.append(0x04); data_msg.append(0x86)  # Field 6: 4 bytes, uint32 (distance)
    data_msg.append(0x07); data_msg.append(0x02); data_msg.append(0x84)  # Field 7: 2 bytes, uint16 (power)
    data_msg.append(0x04); data_msg.append(0x01); data_msg.append(0x02)  # Field 4: 1 byte, uint8 (cadence)
    
    # MESSAGE 2: Record data (10 sample points)
    for i in range(10):
        data_msg.append(0x01)              # LMT=1
        write_uint32_be(data_msg, 0x30390000 + i*2)  # timestamp
        # Latitude as semicircles (37.7749° = 909_310_272)
        write_sint32_be(data_msg, 909310272 + i * 100)
        # Longitude as semicircles (-122.4194° = -2_967_996_672)
        write_sint32_be(data_msg, -2967996672 + i * 100)
        write_uint32_be(data_msg, 100 + i * 10)  # distance in meters
        write_uint16_be(data_msg, 250 + i * 5)   # power in watts
        data_msg.append(85 + i % 10)       # cadence in rpm
    
    # MESSAGE 3: Activity definition (LMT=2, GMN=34)
    data_msg.append(0x42)                  # DEF, LMT=2
    data_msg.append(0x00)                  # Reserved
    data_msg.append(0x01)                  # Architecture
    write_uint16_be(data_msg, 34)          # GMN = 34 (Activity)
    data_msg.append(0x03)                  # Number of fields
    
    # Activity fields
    data_msg.append(0xFE); data_msg.append(0x04); data_msg.append(0x86)  # Field 254: 4 bytes, uint32 (timestamp)
    data_msg.append(0x00); data_msg.append(0x01); data_msg.append(0x00)  # Field 0: 1 byte, enum (type)
    data_msg.append(0x01); data_msg.append(0x01); data_msg.append(0x02)  # Field 1: 1 byte, uint8 (num_sessions)
    
    # MESSAGE 3: Activity data
    data_msg.append(0x02)                  # LMT=2
    write_uint32_be(data_msg, 0x30390000)  # timestamp
    data_msg.append(0x00)                  # type = manual
    data_msg.append(0x01)                  # num_sessions = 1
    
    # Update header data size
    data_size = len(data_msg)
    header[4:8] = [(data_size >> 24) & 0xFF, (data_size >> 16) & 0xFF,
                   (data_size >> 8) & 0xFF, data_size & 0xFF]
    
    # Calculate header CRC (stored in LITTLE ENDIAN as per Garmin spec)
    header_crc = garmin_fit_crc(header[:12])
    header[12] = header_crc & 0xFF          # Low byte first (little-endian)
    header[13] = (header_crc >> 8) & 0xFF   # High byte second
    
    # Combine file
    full_file = header + data_msg
    
    # Calculate file CRC (stored in LITTLE ENDIAN as per Garmin spec)
    file_crc = garmin_fit_crc(full_file)
    full_file.append(file_crc & 0xFF)         # Low byte first (little-endian)
    full_file.append((file_crc >> 8) & 0xFF)  # High byte second
    
    return bytes(full_file)

# Generate and save
fit_data = create_comprehensive_fit()
with open('test_comprehensive.fit', 'wb') as f:
    f.write(fit_data)

print(f'Generated comprehensive FIT file: test_comprehensive.fit')
print(f'File size: {len(fit_data)} bytes')
