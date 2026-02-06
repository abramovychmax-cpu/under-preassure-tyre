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

def crc16_ccitt(data):
    crc_table = [
        0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7, 0x8108,
        0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef, 0x1231, 0x0210,
        0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6, 0x9339, 0x8318, 0xb37b,
        0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de, 0x2462, 0x3443, 0x0420, 0x1401,
        0x64e6, 0x74c7, 0x44a4, 0x5485, 0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee,
        0xf5cf, 0xc5ac, 0xd58d, 0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6,
        0x5695, 0x46b4, 0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d,
        0xc7bc, 0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
        0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b, 0x5af5,
        0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12, 0xdbfd, 0xcbdc,
        0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a, 0x6ca6, 0x7c87, 0x4ce4,
        0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41, 0xedae, 0xfd8f, 0xcdec, 0xddcd,
        0xad2a, 0xbd0b, 0x8d68, 0x9d49, 0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13,
        0x2e32, 0x1e51, 0x0e70, 0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a,
        0x9f59, 0x8f78, 0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e,
        0xe16f, 0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
        0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e, 0x02b1,
        0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256, 0xb5ea, 0xa5cb,
        0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d, 0x34e2, 0x24c3, 0x14a0,
        0x0481, 0x7466, 0x6447, 0x5424, 0x4405, 0xa7db, 0xb7fa, 0x8799, 0x97b8,
        0xe75f, 0xf77e, 0xc71d, 0xd73c, 0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657,
        0x7676, 0x4615, 0x5634, 0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9,
        0xb98a, 0xa9ab, 0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882,
        0x28a3, 0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
        0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92, 0xfd2e,
        0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9, 0x7c26, 0x6c07,
        0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1, 0xef1f, 0xff3e, 0xcf5d,
        0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8, 0x6e17, 0x7e36, 0x4e55, 0x5e74,
        0x2e93, 0x3eb2, 0x0ed1, 0x1ef0,
    ]
    
    crc = 0
    for byte in data:
        crc = (crc << 8) & 0xFFFF
        crc ^= crc_table[(crc >> 8) ^ byte]
        crc &= 0xFFFF
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
    
    # Calculate header CRC
    header_crc = crc16_ccitt(header[:12])
    header[12:14] = [(header_crc >> 8) & 0xFF, header_crc & 0xFF]
    
    # Combine file
    full_file = header + data_msg
    
    # Calculate file CRC
    file_crc = crc16_ccitt(full_file)
    full_file.append((file_crc >> 8) & 0xFF)
    full_file.append(file_crc & 0xFF)
    
    return bytes(full_file)

# Generate and save
fit_data = create_comprehensive_fit()
with open('test_comprehensive.fit', 'wb') as f:
    f.write(fit_data)

print(f'Generated comprehensive FIT file: test_comprehensive.fit')
print(f'File size: {len(fit_data)} bytes')
