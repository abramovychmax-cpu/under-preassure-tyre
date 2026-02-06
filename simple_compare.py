import struct

def hex_dump(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()
    
    print(f"\n{filepath}: {len(data)} bytes")
    print("\nFirst 100 bytes (hex):")
    for i in range(0, min(100, len(data)), 16):
        hex_part = ' '.join(f'{b:02X}' for b in data[i:i+16])
        print(f"  {hex_part}")
    
    if len(data) >= 14:
        print(f"\nHeader:")
        print(f"  [0]:       {data[0]} (0x{data[0]:02X}) - Header Size")
        print(f"  [1]:       {data[1]} (0x{data[1]:02X}) - Proto Version")
        print(f"  [2-3]:     {struct.unpack('>H', data[2:4])[0]} - Prof Version")
        print(f"  [4-7]:     {struct.unpack('>I', data[4:8])[0]} - Data Size")
        print(f"  [8-11]:    {data[8:12]} - Data Type")
        print(f"  [12-13]:   {struct.unpack('>H', data[12:14])[0]} (0x{struct.unpack('>H', data[12:14])[0]:04X}) - Header CRC")

hex_dump("test_output_new.fit")
hex_dump("test_data/export_57540117/activities/8422253208.fit/8422253208.fit")
