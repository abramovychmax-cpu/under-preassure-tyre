import struct

def garmin_crc(data):
    crc_table = [0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401, 0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400]
    crc = 0
    for byte in data:
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[byte & 0xF]
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[(byte >> 4) & 0xF]
    return crc

with open('dart_test_output.fit', 'rb') as f:
    data = f.read()

header = data[:12]
file_data = data[:-2]

header_crc_calc = garmin_crc(header)
file_crc_calc = garmin_crc(file_data)

header_crc_stored = struct.unpack('<H', data[12:14])[0]
file_crc_stored = struct.unpack('<H', data[-2:])[0]

print(f'dart_test_output.fit: {len(data)} bytes')
print(f'  Header CRC: {hex(header_crc_calc)} {"✓" if header_crc_stored == header_crc_calc else "✗"}')
print(f'  File CRC: {hex(file_crc_calc)} {"✓" if file_crc_stored == file_crc_calc else "✗"}')
