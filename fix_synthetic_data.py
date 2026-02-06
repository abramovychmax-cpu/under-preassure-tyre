#!/usr/bin/env python3
"""
Generate proper coast-down test data:
- Lap 0: Warmup (original)
- Laps 1-11: REVERSED speeds (acceleration starts at v_peak, decreases)
- Lap 12: Cooldown (original)
"""

import json
from pathlib import Path

# Read original FIT data
fit_path = 'test_data/10255893432.fit'
sensor_path = f'{fit_path}.sensor_records.jsonl'

# Read all records
all_records = []
with open(sensor_path, 'r') as f:
    for line in f:
        try:
            record = json.loads(line.strip())
            all_records.append(record)
        except:
            continue

print(f"Loaded {len(all_records)} records from original FIT file")

# Group by lap and process
output_records = []

for record in all_records:
    lap_idx = record['lapIndex']
    
    # Laps 1-11: Reverse speed (descent with deceleration)
    if 1 <= lap_idx <= 11:
        # For descent laps: reverse the speed progression
        # This simulates going from peak speed DOWN to low speed
        speed = record['speed_kmh']
        
        # Map speed: 0→50, 1→49, ..., 50→0
        # Reverse: peak_speed - current_speed gives descent profile
        max_speed_in_lap = 50.11  # approximate peak from real descents
        reversed_speed = max_speed_in_lap - speed
        
        record = record.copy()
        record['speed_kmh'] = max(0, reversed_speed)  # Ensure non-negative
        record['cadence'] = 0.0  # Ensure coasting
    
    output_records.append(record)

# Write updated sensor records
with open(sensor_path, 'w') as f:
    for record in output_records:
        f.write(json.dumps(record) + '\n')

print(f"✓ Updated {len(output_records)} sensor records with reversed speeds for descent laps")

# Verify
print("\nVerifying descent laps now have DECREASING speed:")
by_lap = {}
for record in output_records:
    lap = record['lapIndex']
    if lap not in by_lap:
        by_lap[lap] = []
    by_lap[lap].append(record)

for lap_idx in sorted([k for k in by_lap.keys() if 1 <= k <= 11])[:3]:  # Show first 3
    records = by_lap[lap_idx]
    speeds = [r['speed_kmh'] for r in records]
    print(f"Lap {lap_idx}: First={speeds[0]:.2f}, ..., Last={speeds[-1]:.2f} km/h (declining: {speeds[0] > speeds[-1]})")
