import struct

with open('test_minimal.fit', 'rb') as f:
    data = f.read()
    
    # Show raw bytes
    print('Raw hex dump (all 62 bytes):')
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_str = ' '.join(f'{b:02x}' for b in chunk)
        print(f'{i:04d}: {hex_str}')
    
    # Parse header
    header = data[:12]
    print(f'\nHeader (12 bytes): {" ".join(f"{b:02x}" for b in header)}')
    
    # Check CRC bytes position
    print(f'Bytes at 12-13 (header CRC): {data[12]:02x} {data[13]:02x}')
    print(f'Bytes at 60-61 (file CRC): {data[60]:02x} {data[61]:02x}')
    
    # Parse as little-endian
    header_crc_raw = struct.unpack('<H', data[12:14])[0]
    file_crc_raw = struct.unpack('<H', data[60:62])[0]
    print(f'\nAs little-endian:')
    print(f'Header CRC: {hex(header_crc_raw)}')
    print(f'File CRC: {hex(file_crc_raw)}')
