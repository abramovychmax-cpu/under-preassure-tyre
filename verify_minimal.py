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

with open('test_minimal.fit', 'rb') as f:
    data = f.read()

# Calculate CRCs
header = data[:12]
file_data = data[:-2]  # Everything except the 2-byte CRC at the end

header_crc_calc = garmin_crc(header)
file_crc_calc = garmin_crc(file_data)

print(f'Calculated Header CRC: {hex(header_crc_calc)}')
print(f'Calculated File CRC: {hex(file_crc_calc)}')

# What's stored
header_crc_stored = struct.unpack('<H', data[12:14])[0]
file_crc_stored = struct.unpack('<H', data[60:62])[0]

print(f'\nStored Header CRC: {hex(header_crc_stored)}')
print(f'Stored File CRC: {hex(file_crc_stored)}')

print(f'\nHeader Match: {header_crc_stored == header_crc_calc}')
print(f'File Match: {file_crc_stored == file_crc_calc}')
