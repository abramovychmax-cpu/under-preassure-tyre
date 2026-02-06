#!/usr/bin/env python3
"""Parse FIT file messages manually"""

with open('minimal_test.fit', 'rb') as f:
    data = f.read()

print("Message sequence:")
offset = 14  # Skip header
msg_num = 0

while offset < len(data) - 2:  # Stop before file CRC
    header_byte = data[offset]
    is_definition = bool(header_byte & 0x40)
    local_type = header_byte & 0x0F
    
    msg_num += 1
    print(f"\nMsg {msg_num} @ offset {offset}:")
    print(f"  Header: 0x{header_byte:02X}")
    print(f"  Type: {'DEFINITION' if is_definition else 'DATA'}")
    print(f"  Local type: {local_type}")
    
    if is_definition:
        # Skip definition message (variable length)
        reserved = data[offset+1]
        arch = data[offset+2]
        global_msg = int.from_bytes(data[offset+3:offset+5], 'little')
        num_fields = data[offset+5]
        print(f"  Global message: {global_msg}")
        print(f"  Fields: {num_fields}")
        # Each field = 3 bytes, plus header (6 bytes) + dev fields byte
        msg_len = 6 + (num_fields * 3) + 1
        offset += msg_len
    else:
        # Data message - need to know size from definition
        # Just skip a fixed amount for now
        print(f"  (Skipping data...)")
        offset += 20  # Approximate
        
    if msg_num > 15:  # Safety limit
        break

print(f"\n\nFile ends at offset {len(data)}")
