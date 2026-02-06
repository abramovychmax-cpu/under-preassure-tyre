#!/usr/bin/env python3
"""Fixed FIT message parser"""
import struct

MESSAGE_NAMES = {
    0: "FileID",
    18: "Session",
    19: "Lap",
    20: "Record",
    23: "Device",
    34: "Activity",
}

with open('assets/sample_fake.fit', 'rb') as f:
    data = f.read()

header = data[:14]
h_size = header[0]
data_size = struct.unpack('>I', header[4:8])[0]
payload = data[h_size:h_size+data_size]

pos = 0
message_defs = {}  # lmt -> {gmn, sizes}
def_count = 0
data_count = 0
data_counts = {}   # gmn -> count

while pos < len(payload):
    record_header = payload[pos]
    pos += 1
    
    is_definition = (record_header & 0x40) != 0
    lmt = record_header & 0x0F
    
    if is_definition:
        if pos + 5 > len(payload):
            break
        
        reserved = payload[pos]
        arch = payload[pos+1]
        gmn_bytes = payload[pos+2:pos+4]
        gmn = struct.unpack('>H', gmn_bytes)[0]
        num_fields = payload[pos+4]
        pos += 5
        
        # Read field definitions to know how to skip data messages
        field_sizes = []
        for i in range(num_fields):
            if pos + 3 > len(payload):
                break
            field_id = payload[pos]
            field_size = payload[pos+1]
            field_type = payload[pos+2]
            field_sizes.append(field_size)
            pos += 3
        
        message_defs[lmt] = {'gmn': gmn, 'sizes': field_sizes}
        msg_name = MESSAGE_NAMES.get(gmn, f"Unknown({gmn})")
        print(f"DEF[{def_count:3d}] LMT {lmt} -> GMN {gmn:2d} ({msg_name:10s}), {num_fields} fields, data_size={sum(field_sizes)}")
        def_count += 1
    else:
        # Data message - calculate size from definition
        msg_info = message_defs.get(lmt)
        if msg_info:
            gmn = msg_info['gmn']
            data_size = sum(msg_info['sizes'])
            
            msg_name = MESSAGE_NAMES.get(gmn, f"Unknown({gmn})")
            if gmn not in data_counts:
                data_counts[gmn] = 0
            data_counts[gmn] += 1
            data_count += 1
            
            if gmn == 0 or gmn == 23 or gmn == 19 or gmn == 18 or gmn == 34:
                print(f"DATA[{data_count:3d}] LMT {lmt} -> GMN {gmn:2d} ({msg_name:10s})")
            elif gmn == 20:
                if data_counts[gmn] <= 5 or data_counts[gmn] % 50 == 0:
                    print(f"DATA[{data_count:3d}] LMT {lmt} -> GMN {gmn:2d} ({msg_name:10s}) [{data_counts[gmn]}]")
            
            # Skip the data bytes
            pos += data_size
        else:
            print(f"DATA: Unknown LMT {lmt} (not defined)")
            break

print("\n" + "=" * 80)
print("\nSummary:")
for gmn in sorted(data_counts.keys()):
    msg_name = MESSAGE_NAMES.get(gmn, f"Unknown({gmn})")
    print(f"  {msg_name:12s} (GMN {gmn:2d}): {data_counts[gmn]:3d} messages")

print("\nMessages found:")
print("  OK FileID" if 0 in data_counts else "  FAIL FileID")
print("  OK Device" if 23 in data_counts else "  FAIL Device")
print("  OK Lap" if 19 in data_counts else "  FAIL Lap")
print(f"  OK Records ({data_counts.get(20, 0)} found)" if 20 in data_counts else "  FAIL Records")
print("  OK Session" if 18 in data_counts else "  FAIL Session")
print("  OK Activity" if 34 in data_counts else "  FAIL Activity")
