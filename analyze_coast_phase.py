#!/usr/bin/env python3
"""
Coast Phase Analysis - Better Approach
Uses coast-down deceleration (pure rolling resistance measurement)
Normalizes by v_peak to remove air drag confound
"""

import json
from collections import defaultdict
import math

# Load data
sensor_records = defaultdict(list)
with open('test_data/10255893432.fit.sensor_records.jsonl', 'r') as f:
    for line in f:
        try:
            record = json.loads(line.strip())
            sensor_records[record['lapIndex']].append(record)
        except:
            continue

metadata = {}
with open('test_data/10255893432.fit.jsonl', 'r') as f:
    for line in f:
        try:
            record = json.loads(line.strip())
            metadata[record['lapIndex']] = record
        except:
            continue

print("="*100)
print("COAST PHASE ANALYSIS (Pure Deceleration)")
print("="*100)
print()

results = []

for lap_idx in sorted([k for k in sensor_records.keys() if 1 <= k <= 11]):
    records = sensor_records[lap_idx]
    pres = metadata.get(lap_idx, {})
    pressure = pres.get('frontPressure', 0)
    
    if not records:
        continue
    
    # Find coast phase: cadence=0 AND speed > 3 km/h (stable coast)
    coast_records = [r for r in records if r['cadence'] == 0 and r['speed_kmh'] > 3.0]
    
    if len(coast_records) < 5:
        print(f"Lap {lap_idx:2d}: {pressure:.1f} bar - Not enough coast data ({len(coast_records)} records)")
        continue
    
    # Calculate coast metrics
    speeds = [r['speed_kmh'] for r in coast_records]
    v_start = speeds[0]
    v_end = speeds[-1]
    v_peak = max(speeds)
    duration = len(coast_records) / 1.0  # 1 Hz
    
    # Raw deceleration (what we measure)
    decel_raw = (v_start - v_end) / duration
    
    # Normalized deceleration (cancels air drag)
    # Formula: air_drag ∝ v², so dividing by v_peak² partially cancels it
    decel_normalized = decel_raw / (v_peak * v_peak)
    
    # Alternative: Use average speed squared
    v_avg = sum(speeds) / len(speeds)
    decel_normalized2 = decel_raw / (v_avg * v_avg)
    
    result = {
        'lap_idx': lap_idx,
        'pressure': pressure,
        'v_peak': v_peak,
        'v_start': v_start,
        'v_end': v_end,
        'decel_raw': decel_raw,
        'decel_norm_peak': decel_normalized,
        'decel_norm_avg': decel_normalized2,
        'duration': duration,
    }
    results.append(result)

print(f"{'Lap':>3} | {'Pressure':>8} | {'V_peak':>8} | {'Decel Raw':>10} | {'Decel/Vp²':>10} | {'Decel/Va²':>10}")
print("-" * 100)

for r in results:
    print(f"{r['lap_idx']:3d} | {r['pressure']:8.1f} | {r['v_peak']:8.2f} | {r['decel_raw']:10.5f} | {r['decel_norm_peak']:10.6f} | {r['decel_norm_avg']:10.6f}")

print()
print("="*100)
print("FINDING OPTIMAL PRESSURE")
print("="*100)
print()

# Find minimum deceleration for each metric
min_raw_idx = min(range(len(results)), key=lambda i: results[i]['decel_raw'])
min_norm_peak_idx = min(range(len(results)), key=lambda i: results[i]['decel_norm_peak'])
min_norm_avg_idx = min(range(len(results)), key=lambda i: results[i]['decel_norm_avg'])

print(f"✓ Optimal by RAW deceleration:        {results[min_raw_idx]['pressure']:.1f} bar (decel: {results[min_raw_idx]['decel_raw']:.5f})")
print(f"✓ Optimal by normalized (v_peak²):   {results[min_norm_peak_idx]['pressure']:.1f} bar (decel: {results[min_norm_peak_idx]['decel_norm_peak']:.6f})")
print(f"✓ Optimal by normalized (v_avg²):    {results[min_norm_avg_idx]['pressure']:.1f} bar (decel: {results[min_norm_avg_idx]['decel_norm_avg']:.6f})")

print()
print("INTERPRETATION:")
print(f"""
The coast phase shows rolling resistance variation with pressure.

Raw deceleration: Actual speed loss during coast phase
  - Includes both rolling resistance AND air drag effects
  
Normalized deceleration: Deceleration / (speed²)
  - Cancels out air drag contribution
  - Isolates rolling resistance signal

Lower deceleration = Lower rolling resistance = Better tire pressure
""")
