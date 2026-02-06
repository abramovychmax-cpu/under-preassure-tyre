#!/usr/bin/env python3
"""Quick check: is there actually a parabolic trend in the data?"""

import json
from collections import defaultdict

# Load sensor records
sensor_records = defaultdict(list)
with open('test_data/10255893432.fit.sensor_records.jsonl', 'r') as f:
    for line in f:
        try:
            record = json.loads(line.strip())
            lap_idx = record['lapIndex']
            sensor_records[lap_idx].append(record)
        except:
            continue

# Load metadata
metadata = {}
with open('test_data/10255893432.fit.jsonl', 'r') as f:
    for line in f:
        try:
            record = json.loads(line.strip())
            metadata[record['lapIndex']] = record
        except:
            continue

print("RAW ACCELERATION DATA:")
print("Lap | Pressure | V_peak | Min V | Max V | Duration | Speed Change")
print("-" * 70)

for lap_idx in sorted([k for k in sensor_records.keys() if 1 <= k <= 11]):
    records = sensor_records[lap_idx]
    pres = metadata.get(lap_idx, {})
    pressure = pres.get('frontPressure', 0)
    
    speeds = [r['speed_kmh'] for r in records]
    v_peak = max(speeds)
    v_min = min(speeds)
    v_max = max(speeds)
    speed_change = v_max - v_min
    duration = len(records) / 1.0
    accel_raw = speed_change / duration
    
    print(f"{lap_idx:3d} | {pressure:8.1f} | {v_peak:6.2f} | {v_min:5.1f} | {v_max:5.1f} | {duration:8.1f} | {accel_raw:7.4f}")

print("\nOBSERVATION:")
print("All acceleration values are POSITIVE (speed increases through lap)")
print("This is WRONG - in a coast-down, speed should DECREASE")
print("The synthetic data has speed in wrong order!")
