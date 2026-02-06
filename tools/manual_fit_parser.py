import struct
import sys

# CRC-16/CCITT from the FIT SDK
CRC_TABLE = [
    0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
    0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
    0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
    0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
    0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
    0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
    0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
    0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
    0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
    0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
    0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
    0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
    0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
    0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
    0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
    0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
    0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
    0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
    0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
    0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
    0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
    0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
    0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
    0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
    0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
    0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
    0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
    0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
    0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
    0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
    0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
    0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0,
]

def get_crc(data):
    crc = 0
    for byte in data:
        crc = (crc << 8) & 0xFFFF
        crc ^= CRC_TABLE[(crc >> 8) ^ byte]
        crc &= 0xFFFF
    return crc

BASE_TYPE_FORMAT = {
    0: 'B',  # enum
    1: 'b',  # sint8
    2: 'B',  # uint8
    3: 'h',  # sint16
    4: 'H',  # uint16
    5: 'i',  # sint32
    6: 'I',  # uint32
    7: 's',  # string
    8: 'f',  # float32
    9: 'd',  # float64
    10: 'B', # uint8z
    11: 'H', # uint16z
    12: 'I', # uint32z
    13: 'B', # byte
    14: 'q', # sint64
    15: 'Q', # uint64
    16: 'L', # uint32
}

BASE_TYPE_SIZE = {
    0: 1, 1: 1, 2: 1, 3: 2, 4: 2, 5: 4, 6: 4, 7: 1, # String is special
    8: 4, 9: 8, 10: 1, 11: 2, 12: 4, 13: 1, 14: 8, 15: 8, 16: 4
}

# From FIT SDK Profile.xlsx
MESSAGE_TYPES = {
    0: "file_id",
    1: "capabilities",
    2: "device_settings",
    3: "user_profile",
    4: "hrm_profile",
    5: "sdm_profile",
    6: "bike_profile",
    7: "zones_target",
    8: "hr_zone",
    9: "power_zone",
    10: "met_zone",
    12: "sport",
    15: "goal",
    18: "session",
    19: "lap",
    20: "record",
    21: "event",
    23: "device_info",
    30: "workout",
    31: "workout_step",
    34: "activity",
    35: "software",
    49: "file_creator",
    72: "weight_scale",
    101: "course",
    103: "course_point",
    105: "totals",
    106: "weight",
    127: "blood_pressure",
    128: "monitoring_info",
    129: "monitoring",
    131: "hrv",
    142: "length",
    145: "monitoring_b",
    147: "segment",
    148: "segment_lap",
    149: "segment_id",
    150: "segment_leaderboard_entry",
    151: "segment_point",
    152: "segment_file",
    160: "mfg_range",
    200: "obdii_data",
    202: "nmea_sentence",
    206: "aviation_attitude",
    207: "video",
    208: "video_title",
    209: "video_description",
    210: "video_clip",
    225: "exd_screen_configuration",
    226: "exd_data_field_configuration",
    227: "exd_data_concept_configuration",
    228: "field_description",
    229: "developer_data_id",
}


def parse_file(file_path):
    definitions = {}
    file_bytes = b''
    with open(file_path, 'rb') as f:
        file_bytes = f.read()

    # 1. Header
    header_size = file_bytes[0]
    protocol_version = file_bytes[1]
    profile_version = struct.unpack('<H', file_bytes[2:4])[0]
    data_size = struct.unpack('<I', file_bytes[4:8])[0]
    data_type = file_bytes[8:12].decode('ascii')
    header_crc = struct.unpack('<H', file_bytes[12:14])[0] if header_size == 14 else None

    print(f"--- FIT File: {file_path} ---")
    print(f"Header Size: {header_size}")
    print(f"Protocol Version: {protocol_version}")
    print(f"Profile Version: {profile_version}")
    print(f"Data Size: {data_size} bytes")
    print(f"Data Type: '{data_type}'")

    if header_crc is not None:
        calculated_header_crc = get_crc(file_bytes[0:12])
        print(f"Header CRC: {header_crc} (Calculated: {calculated_header_crc}) -> {'OK' if header_crc == calculated_header_crc else 'FAIL'}")
    else:
        print("Header CRC: Not present")

    print("\n--- Records ---")
    
    # 2. Data Records
    pointer = header_size
    while pointer < header_size + data_size:
        print(f"\n@ Byte {pointer}")
        record_header = file_bytes[pointer]
        pointer += 1

        is_definition = (record_header >> 6) & 1
        local_msg_type = record_header & 0x0F

        if is_definition:
            # Definition Message
            reserved = file_bytes[pointer]
            architecture = file_bytes[pointer + 1]
            global_msg_num = struct.unpack('<H', file_bytes[pointer + 2:pointer + 4])[0]
            num_fields = file_bytes[pointer + 4]
            
            print(f"  [DEFINITION] Local Msg Type: {local_msg_type}")
            print(f"    Global Msg Num: {global_msg_num} ({MESSAGE_TYPES.get(global_msg_num, 'Unknown')})")
            print(f"    Architecture: {'Big' if architecture else 'Little'} Endian")
            print(f"    Num Fields: {num_fields}")

            fields = []
            field_pointer = pointer + 5
            total_size = 0
            for i in range(num_fields):
                field_def_num = file_bytes[field_pointer]
                field_size = file_bytes[field_pointer + 1]
                base_type = file_bytes[field_pointer + 2]
                fields.append({'def_num': field_def_num, 'size': field_size, 'type': base_type})
                field_pointer += 3
                total_size += field_size
                print(f"      Field {i+1}: Def Num={field_def_num}, Size={field_size}, Base Type={base_type}")

            definitions[local_msg_type] = {
                'global_msg_num': global_msg_num,
                'fields': fields,
                'total_size': total_size
            }
            pointer = field_pointer
        else:
            # Data Message
            print(f"  [DATA] Local Msg Type: {local_msg_type}")
            if local_msg_type in definitions:
                definition = definitions[local_msg_type]
                print(f"    Global Msg Num: {definition['global_msg_num']} ({MESSAGE_TYPES.get(definition['global_msg_num'], 'Unknown')})")
                
                data_bytes = file_bytes[pointer : pointer + definition['total_size']]
                
                field_offset = 0
                for i, field in enumerate(definition['fields']):
                    field_bytes = data_bytes[field_offset : field_offset + field['size']]
                    
                    # This is a simplified parser, doesn't handle all types or endianness correctly
                    # It's for structural analysis, not perfect data extraction.
                    value_str = f"0x{field_bytes.hex()}"
                    if field['size'] == 4 and field['def_num'] in [253, 4, 2, 7, 8, 0]: # Timestamps and time fields
                        try:
                            ts = struct.unpack('>I', field_bytes)[0]
                            value_str = f"{ts} (0x{field_bytes.hex()})"
                        except struct.error:
                            value_str = f"ERROR_UNPACKING ({value_str})"
                    
                    print(f"      LMT {local_msg_type} | GMN {definition['global_msg_num']:<5} | Field {field['def_num']:<3} | Size {field['size']:<2} | Value: {value_str}")
                    field_offset += field['size']

                pointer += definition['total_size']
            else:
                print(f"    ERROR: No definition found for Local Msg Type {local_msg_type}. Skipping.")
                # This is tricky. We don't know how many bytes to skip.
                # This script will likely fail here if a file isn't well-formed (defs first).
                break

    # 3. File CRC
    file_crc_bytes = file_bytes[header_size + data_size:]
    if len(file_crc_bytes) == 2:
        file_crc = struct.unpack('<H', file_crc_bytes)[0]
        body_and_header = file_bytes[:header_size + data_size]
        calculated_file_crc = get_crc(body_and_header)
        print(f"\n--- Footer ---")
        print(f"File CRC: {file_crc} (Calculated: {calculated_file_crc}) -> {'OK' if file_crc == calculated_file_crc else 'FAIL'}")
    else:
        print("\n--- Footer ---")
        print("File CRC: Not found or incorrect length.")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        parse_file(sys.argv[1])
    else:
        print("Usage: python manual_fit_parser.py <file_path.fit>")
