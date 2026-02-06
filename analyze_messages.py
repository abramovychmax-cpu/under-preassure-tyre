import struct

def analyze_messages(filepath, max_messages=5):
    with open(filepath, 'rb') as f:
        data = f.read()
    
    print(f"\n{filepath}: {len(data)} bytes")
    
    if len(data) < 14:
        print("File too small for header")
        return
    
    # Parse header
    header_size = data[0]
    data_size = struct.unpack('>I', data[4:8])[0]
    
    print(f"Header size: {header_size}, Data size: {data_size}")
    print(f"\nFirst {max_messages} messages:")
    
    offset = 14
    msg_num = 0
    local_messages = {}  # Track message definitions
    
    while offset < min(14 + data_size, len(data) - 2) and msg_num < max_messages:
        if offset >= len(data):
            break
        
        record_header = data[offset]
        is_definition = (record_header & 0x40) != 0
        lmt = record_header & 0x0F
        
        print(f"\nMessage {msg_num} @ offset {offset}:")
        print(f"  Record Header: 0x{record_header:02X} (DEF={is_definition}, LMT={lmt})")
        
        if is_definition:
            if offset + 6 > len(data):
                break
            
            reserved = data[offset + 1]
            architecture = data[offset + 2]
            gmn = struct.unpack('>H', data[offset + 3:offset + 5])[0]
            num_fields = data[offset + 5]
            
            print(f"  Definition: GMN={gmn}, NumFields={num_fields}, Arch={'BE' if architecture else 'LE'}")
            
            # Store definition
            local_messages[lmt] = {
                'gmn': gmn,
                'num_fields': num_fields,
                'fields': []
            }
            
            field_start = offset + 6
            field_size_total = 0
            for i in range(num_fields):
                field_id = data[field_start + i*3]
                field_sz = data[field_start + i*3 + 1]
                field_type = data[field_start + i*3 + 2]
                field_size_total += field_sz
                local_messages[lmt]['fields'].append({
                    'id': field_id,
                    'size': field_sz,
                    'type': field_type
                })
                print(f"    Field {i}: ID={field_id}, Size={field_sz}, Type=0x{field_type:02X}")
            
            local_messages[lmt]['total_size'] = field_size_total
            offset += 6 + num_fields * 3
        else:
            # Data message
            print(f"  Data Message (LMT={lmt})")
            if lmt in local_messages:
                msg_def = local_messages[lmt]
                print(f"    Uses GMN={msg_def['gmn']}, expects {msg_def['total_size']} bytes of data")
                offset += 1  # Skip message header
                # Don't actually parse data, just skip it
                offset += msg_def['total_size']
            else:
                print(f"    ERROR: LMT {lmt} not defined!")
                offset += 1
        
        msg_num += 1
    
    print(f"\nTotal messages parsed: {msg_num}")

# Analyze both files
analyze_messages("test_output_new.fit")
analyze_messages("test_data/export_57540117/activities/8422253208.fit/8422253208.fit", max_messages=10)
