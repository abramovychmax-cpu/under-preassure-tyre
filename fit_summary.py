#!/usr/bin/env python3
"""Complete FIT message parser with proper counting"""
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

print("Complete FIT Message Parse")
print("=" * 80)

message_defs = {}  # lmt -> GMN mapping
data_counts = {}   # GMN -> count
pos = 0
def_count = 0
data_count = 0

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
        
        message_defs[lmt] = gmn
        msg_name = MESSAGE_NAMES.get(gmn, f"Unknown({gmn})")
        print(f"DEF[{def_count:3d}] LMT {lmt} -> GMN {gmn:2d} ({msg_name:10s}), {num_fields} fields")
        def_count += 1
        
        # Skip field definitions
        for i in range(num_fields):
            if pos + 3 > len(payload):
                break
            pos += 3
    else:
        # Data message
        gmn = message_defs.get(lmt, -1)
        if gmn >= 0:
            msg_name = MESSAGE_NAMES.get(gmn, f"Unknown({gmn})")
            data_count += 1
            if gmn not in data_counts:
                data_counts[gmn] = 0
            data_counts[gmn] += 1
            
            if gmn == 0 or gmn == 23 or gmn == 19 or gmn == 18 or gmn == 34:
                print(f"DATA[{data_count:3d}] LMT {lmt} -> GMN {gmn:2d} ({msg_name:10s})")
            elif gmn == 20:
                if data_counts[gmn] <= 5 or data_counts[gmn] % 50 == 0:
                    print(f"DATA[{data_count:3d}] LMT {lmt} -> GMN {gmn:2d} ({msg_name:10s}) [{data_counts[gmn]}]")

print("\n" + "=" * 80)
print("\nSummary:")
for gmn in sorted(data_counts.keys()):
    msg_name = MESSAGE_NAMES.get(gmn, f"Unknown({gmn})")
    print(f"  {msg_name:12} (GMN {gmn:2d}): {data_counts[gmn]:3d} messages")

print("\nMessages found:")
print("  ✓ FileID" if 0 in data_counts else "  ✗ FileID")
print("  ✓ Device" if 23 in data_counts else "  ✗ Device")
print("  ✓ Lap" if 19 in data_counts else "  ✗ Lap")
print(f"  ✓ Records ({data_counts.get(20, 0)} found)" if 20 in data_counts else "  ✗ Records")
print("  ✓ Session" if 18 in data_counts else "  ✗ Session")
print("  ✓ Activity" if 34 in data_counts else "  ✗ Activity")
