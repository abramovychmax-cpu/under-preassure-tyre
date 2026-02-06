#!/usr/bin/env python3
"""Extract GPS data from FIT file."""

import sys
try:
    from fitparse import FitFile
except ImportError:
    print('fitparse not installed. Run: python -m pip install fitparse')
    sys.exit(1)

fitfile = FitFile(r'test_data\10255893432.fit', check_crc=False)

# Collect all records
all_records = list(fitfile.get_messages('record'))
print(f'Total records in FIT file: {len(all_records)}')

# Filter out corrupted end data (same GPS coordinate repeated)
# Find last unique GPS position
valid_records = []
for record in all_records:
    lat = record.get_value('position_lat')
    lon = record.get_value('position_long')
    if lat is not None and lon is not None:
        valid_records.append(record)

print(f'Records with valid GPS: {len(valid_records)}')

# Identify descents by altitude drops
descents = []
in_descent = False
descent_start_idx = None
descent_start_alt = None
descent_min_alt = None

for i, record in enumerate(valid_records):
    alt = record.get_value('altitude')
    speed = record.get_value('speed') or 0
    
    if alt is None:
        continue
    
    if i > 0:
        prev_alt = valid_records[i-1].get_value('altitude')
        if prev_alt is None:
            continue
        
        # Start of descent: altitude drops and speed is reasonable
        if prev_alt > alt and speed > 2:
            if not in_descent:
                in_descent = True
                descent_start_idx = i
                descent_start_alt = prev_alt
                descent_min_alt = alt
            else:
                descent_min_alt = min(descent_min_alt, alt)
        
        # End of descent: altitude stops dropping (starts going up or flat)
        elif in_descent and prev_alt <= alt:
            if descent_min_alt < descent_start_alt:
                descents.append({
                    'start_idx': descent_start_idx,
                    'end_idx': i,
                    'start_alt': descent_start_alt,
                    'min_alt': descent_min_alt,
                    'drop': descent_start_alt - descent_min_alt,
                    'duration': i - descent_start_idx
                })
            in_descent = False

# Handle if last record is still in descent
if in_descent and descent_min_alt < descent_start_alt:
    descents.append({
        'start_idx': descent_start_idx,
        'end_idx': len(valid_records),
        'start_alt': descent_start_alt,
        'min_alt': descent_min_alt,
        'drop': descent_start_alt - descent_min_alt,
        'duration': len(valid_records) - descent_start_idx
    })

print(f'\n=== DESCENTS FOUND: {len(descents)} ===')
for i, descent in enumerate(descents, 1):
    start_time = valid_records[descent['start_idx']].get_value('timestamp')
    end_time = valid_records[descent['end_idx']-1].get_value('timestamp')
    print(f"Descent {i}:")
    print(f"  Time: {start_time} to {end_time}")
    print(f"  Altitude drop: {descent['start_alt']:.1f}m → {descent['min_alt']:.1f}m ({descent['drop']:.1f}m)")
    print(f"  Duration: {descent['duration']}s")
