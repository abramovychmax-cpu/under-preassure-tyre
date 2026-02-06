#!/usr/bin/env python3

# Check our file header byte by byte
with open('assets/sample_fake.fit', 'rb') as f:
    h = f.read(14)
    print("Our file header bytes:")
    for i, b in enumerate(h):
        print(f"  [{i}]: 0x{b:02x}")
    
    # Fields should be:
    # 0: header_size (1 byte)
    # 1: protocol_version (1 byte)
    # 2-3: profile_version (2 bytes, big-endian)
    # 4-7: data_size (4 bytes, big-endian per spec!)
    # 8-11: data_type (4 bytes, ".FIT")
    # 12-13: header_crc (2 bytes, little-endian)
    
    h_size = h[0]
    prot_ver = h[1]
    prof_ver_be = int.from_bytes(h[2:4], 'big')
    prof_ver_le = int.from_bytes(h[2:4], 'little')
    data_size_be = int.from_bytes(h[4:8], 'big')
    data_size_le = int.from_bytes(h[4:8], 'little')
    dtype = h[8:12]
    h_crc = int.from_bytes(h[12:14], 'little')
    
    print(f"\nParsing:")
    print(f"  Header size: {h_size}")
    print(f"  Protocol version: {prot_ver}")
    print(f"  Profile version (BE): 0x{prof_ver_be:04x} = {prof_ver_be}")
    print(f"  Profile version (LE): 0x{prof_ver_le:04x} = {prof_ver_le}")
    print(f"  Data size (BE): {data_size_be}")
    print(f"  Data size (LE): {data_size_le}")
    print(f"  Data type: {dtype}")
    print(f"  Header CRC (LE): 0x{h_crc:04x}")
    
    # File is 9283 bytes total
    # Header is 14 bytes
    # So data + CRC should be 9283 - 14 = 9269 bytes
    print(f"\nExpected data size: {9283 - 14 - 2} = 9267 bytes (excluding CRC)")
    print(f"BE interpretation matches? {data_size_be == 9267}")
    print(f"LE interpretation matches? {data_size_le == 9267}")
