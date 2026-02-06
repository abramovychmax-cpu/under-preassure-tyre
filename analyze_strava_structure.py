#!/usr/bin/env python3
"""
Detailed analysis of Strava FIT file message structure
to understand what fields and messages are required
"""

import struct
from pathlib import Path

def crc16_ccitt(data):
    """Calculate CRC-16/CCITT"""
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

# Global message names
GMN_NAMES = {
    0: "FileID",
    1: "Capabilities",
    2: "Device Settings",
    3: "User Profile",
    4: "HRM Profile",
    5: "SDM Profile",
    6: "Bike Profile",
    7: "Zones Target",
    8: "HR Zone",
    9: "Power Zone",
    10: "Met Zone",
    12: "Sport",
    13: "Goal",
    14: "Session",
    15: "Lap",
    16: "Record",
    17: "Event",
    18: "Device Info",
    19: "Activity",
    20: "Software",
    21: "File Capabilities",
    23: "Mesg Capabilities",
    24: "Field Capabilities",
    25: "File Creator",
}

# Field names for key message types
FIELD_NAMES = {
    0: {  # FileID
        0: "Type",
        1: "Manufacturer",
        2: "Product",
        3: "Serial Number",
        4: "Time Created",
        5: "Manufacturer ID"
    },
    14: {  # Session
        254: "Message Index",
        253: "Timestamp",
        0: "Event",
        1: "Event Type",
        2: "Start Time",
        3: "Start Position Lat",
        4: "Start Position Long",
        5: "Sport",
        6: "Sub Sport",
        7: "Total Elapsed Time",
        8: "Total Timer Time",
        9: "Total Distance",
        10: "Total Cycles",
        11: "Total Calories",
        13: "Total Ascent",
        14: "Total Descent",
        15: "Total Training Effect",
        16: "First Lap Index",
        17: "Num Laps",
        18: "Event Group",
        19: "Trigger",
        20: "NC",
        21: "Training Load Effect",
        22: "Timestamps Correlation",
    },
    15: {  # Lap
        254: "Message Index",
        253: "Timestamp",
        0: "Event",
        1: "Event Type",
        2: "Start Time",
        3: "Start Position Lat",
        4: "Start Position Long",
        5: "End Position Lat",
        6: "End Position Long",
        7: "Total Elapsed Time",
        8: "Total Timer Time",
        9: "Total Distance",
        10: "Total Cycles",
        11: "Total Calories",
        12: "Total Fat Calories",
        13: "Avg Speed",
        14: "Max Speed",
        15: "Avg Heart Rate",
        16: "Max Heart Rate",
        17: "Avg Cadence",
        18: "Max Cadence",
        19: "Avg Power",
        20: "Max Power",
        21: "Total Ascent",
        22: "Total Descent",
        23: "Intensity",
        24: "Lap Trigger",
        25: "Swim",
    },
    16: {  # Record
        253: "Timestamp",
        0: "Position Lat",
        1: "Position Long",
        2: "Altitude",
        3: "Heart Rate",
        4: "Cadence",
        5: "Distance",
        6: "Speed",
        7: "Power",
        8: "Compressed Speed Distance",
        9: "Grade",
        10: "Resistance",
        11: "Time from Course",
        12: "Temperature",
        13: "Ball Speed",
        14: "Cadence 256",
        15: "Fractional Cadence",
        16: "Total Hemoglobin Conc",
        17: "Total Myoglobin Conc",
        18: "Saturated Hemoglobin Percent",
        19: "Saturated Myoglobin Percent",
        20: "Left Pco2",
        21: "Right Pco2",
        22: "Left Pedal Smoothness",
        23: "Right Pedal Smoothness",
        24: "Left Torque Effectiveness",
        25: "Right Torque Effectiveness",
        26: "Swimmer's Distance",
        27: "Stroke Rate",
        28: "Zone",
        29: "Ball Speed",
        30: "Left Real Cadence",
        31: "Right Real Cadence",
        32: "Left Muscular Efficiency",
        33: "Right Muscular Efficiency",
    }
}

def analyze_file(filepath):
    """Analyze FIT file structure"""
    path = Path(filepath)
    
    if not path.exists():
        print(f"File not found: {filepath}")
        return
    
    with open(filepath, 'rb') as f:
        data = f.read()
    
    print(f"\n{'='*80}")
    print(f"ANALYZING: {path.name} ({len(data)} bytes)")
    print(f"{'='*80}\n")
    
    # Parse header
    if len(data) < 14:
        print("File too small")
        return
    
    header_size = data[0]
    proto = data[1]
    profile = struct.unpack('>H', data[2:4])[0]
    data_size = struct.unpack('>I', data[4:8])[0]
    data_type = data[8:12]
    
    print(f"HEADER: {header_size} bytes, Proto {proto}, Profile {profile}")
    print(f"Data section: {data_size} bytes")
    print(f"Type: {data_type}\n")
    
    # Parse messages
    offset = header_size
    msg_num = 0
    definitions = {}
    
    print(f"MESSAGES:")
    print(f"{'#':<4} {'Type':<4} {'GMN':<4} {'Name':<20} {'Fields':<50}")
    print(f"{'-'*100}")
    
    while offset < len(data) - 2 and msg_num < 100:
        if offset >= len(data):
            break
        
        record_header = data[offset]
        is_definition = (record_header & 0x40) != 0
        lmt = record_header & 0x0F
        
        try:
            if is_definition:
                # Definition message
                if offset + 6 > len(data):
                    break
                
                reserved = data[offset + 1]
                architecture = data[offset + 2]
                gmn = struct.unpack('>H', data[offset + 3:offset + 5])[0]
                num_fields = data[offset + 5]
                
                field_info = []
                for i in range(num_fields):
                    if offset + 6 + i*3 + 3 > len(data):
                        break
                    field_id = data[offset + 6 + i*3]
                    field_size = data[offset + 6 + i*3 + 1]
                    field_type = data[offset + 6 + i*3 + 2]
                    field_info.append((field_id, field_size, field_type))
                
                gmn_name = GMN_NAMES.get(gmn, f"Unknown({gmn})")
                field_str = ", ".join([f"F{fid}({fs}b)" for fid, fs, _ in field_info])
                
                print(f"{msg_num:<4} {'DEF':<4} {gmn:<4} {gmn_name:<20} {field_str[:48]}")
                
                definitions[lmt] = {
                    'gmn': gmn,
                    'fields': field_info,
                    'num_fields': num_fields
                }
                
                offset += 6 + num_fields * 3
            else:
                # Data message
                if lmt not in definitions:
                    print(f"{msg_num:<4} {'DATA':<4} {'?':<4} {'[Undefined LMT]':<20}")
                    offset += 1
                    msg_num += 1
                    continue
                
                defn = definitions[lmt]
                gmn = defn['gmn']
                gmn_name = GMN_NAMES.get(gmn, f"Unknown({gmn})")
                
                # Calculate message size
                msg_size = sum(fs for _, fs, _ in defn['fields'])
                
                if offset + 1 + msg_size > len(data):
                    break
                
                field_str = f"{len(defn['fields'])} fields, {msg_size} bytes"
                print(f"{msg_num:<4} {'DATA':<4} {gmn:<4} {gmn_name:<20} {field_str}")
                
                offset += 1 + msg_size
        
        except Exception as e:
            print(f"{msg_num:<4} ERROR: {e}")
            break
        
        msg_num += 1
    
    print(f"\nTotal messages parsed: {msg_num}")
    print(f"File CRC: 0x{struct.unpack('>H', data[-2:])[0]:04X}")

# Analyze both files
print("\n" + "="*80)
print("COMPARING OUR FILE vs STRAVA FILE")
print("="*80)

analyze_file('test_output_new.fit')
analyze_file('test_data/export_57540117/activities/8422253208.fit/8422253208.fit')
