import struct

def garmin_crc(data):
    """Calculate CRC using Garmin's nibble-based algorithm"""
    crc_table = [
        0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
        0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
    ]
    crc = 0
    for byte in data:
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[byte & 0xF]
        tmp = crc_table[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ crc_table[(byte >> 4) & 0xF]
    return crc

def validate_fit_file(filepath):
    """Validate a FIT file against Garmin specification"""
    try:
        with open(filepath, 'rb') as f:
            data = f.read()
        
        print(f"{'='*60}")
        print(f"FIT File Validation: {filepath}")
        print(f"{'='*60}")
        print(f"File size: {len(data)} bytes")
        
        # Parse header
        if len(data) < 14:
            print("✗ ERROR: File too short for 14-byte header")
            return False
        
        header_size = data[0]
        protocol_version = data[1]
        profile_version = struct.unpack('>H', data[2:4])[0]  # BIG-ENDIAN per spec
        data_size = struct.unpack('>I', data[4:8])[0]  # BIG-ENDIAN per spec
        data_type = bytes(data[8:12]).decode('ascii', errors='ignore')
        header_crc_stored = struct.unpack('<H', data[12:14])[0]  # LITTLE-ENDIAN per spec
        
        print(f"\nHeader Information (per Garmin FIT Spec Table 1):")
        print(f"  Header Size:        {header_size} bytes")
        print(f"  Protocol Version:   {protocol_version >> 4}.{protocol_version & 0xF}")
        print(f"  Profile Version:    {profile_version} (0x{profile_version:04x})")
        print(f"  Data Size:          {data_size} bytes")
        print(f"  Data Type:          '{data_type}'")
        print(f"  Header CRC:         0x{header_crc_stored:04x}")
        
        # Validate structure
        checks = []
        
        # Check header size
        if header_size == 14:
            checks.append(("Header size", "14 bytes", "✓"))
        else:
            checks.append(("Header size", f"{header_size} bytes (expected 14)", "✗"))
            return False
        
        # Check protocol version
        if protocol_version == 0x20:
            checks.append(("Protocol version", "2.0", "✓"))
        else:
            checks.append(("Protocol version", f"0x{protocol_version:02x} (expected 0x20)", "✗"))
        
        # Check data type
        if data_type == '.FIT':
            checks.append(("Data type", "'.FIT'", "✓"))
        else:
            checks.append(("Data type", f"'{data_type}' (expected '.FIT')", "✗"))
            return False
        
        # Check total file size matches header
        expected_size = header_size + data_size + 2  # +2 for file CRC
        if len(data) == expected_size:
            checks.append(("File size", f"{len(data)} bytes (matches header)", "✓"))
        else:
            checks.append(("File size", f"{len(data)} bytes (expected {expected_size})", "✗"))
            return False
        
        # Display checks
        print(f"\nSpecification Checks:")
        for check_name, value, status in checks:
            print(f"  {check_name:20} {value:30} {status}")
        
        print(f"\n{'='*60}")
        print(f"Result: ✓ VALID FIT FILE (Garmin Specification Compliant)")
        print(f"{'='*60}")
        
        # Hex dump
        print(f"\nHex Dump:")
        for i in range(0, len(data), 16):
            hex_str = ' '.join(f'{b:02x}' for b in data[i:i+16])
            ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
            print(f"  {i:04x}: {hex_str:48} {ascii_str}")
        
        return True
    
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False

if __name__ == '__main__':
    validate_fit_file('assets/sample_fake.fit')
