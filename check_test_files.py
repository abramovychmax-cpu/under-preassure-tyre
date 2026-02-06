#!/usr/bin/env python3
import json

print("="*80)
print("TEST DATA FILES CHECK")
print("="*80)

# Check pressure metadata
print("\n1. PRESSURE METADATA (10255893432.fit.jsonl)")
with open('test_data/10255893432.fit.jsonl', 'r') as f:
    lines = f.readlines()
    print(f"   Total laps with pressure: {len(lines)}")
    for line in lines:
        record = json.loads(line)
        lap_idx = record['lapIndex']
        p_front = record['frontPressure']
        p_rear = record['rearPressure']
        print(f"   Lap {lap_idx:2d}: P_front={p_front:.1f} bar, P_rear={p_rear:.1f} bar")

# Check sensor records
print("\n2. SENSOR RECORDS (10255893432.fit.sensor_records.jsonl)")
with open('test_data/10255893432.fit.sensor_records.jsonl', 'r') as f:
    lines = f.readlines()
    print(f"   Total records: {len(lines)}")
    
    # Group by lap
    by_lap = {}
    for line in lines:
        record = json.loads(line)
        lap = record['lapIndex']
        if lap not in by_lap:
            by_lap[lap] = []
        by_lap[lap].append(record)
    
    print(f"   Laps: {sorted(by_lap.keys())}")
    
    for lap_idx in sorted(by_lap.keys()):
        records = by_lap[lap_idx]
        print(f"\n   Lap {lap_idx}: {len(records)} records")
        
        # Check cadence
        cadences = [r['cadence'] for r in records]
        speeds = [r['speed_kmh'] for r in records]
        
        print(f"      Cadence: min={min(cadences):.1f}, max={max(cadences):.1f}, avg={sum(cadences)/len(cadences):.1f}")
        print(f"      Speed: min={min(speeds):.2f}, max={max(speeds):.2f}, avg={sum(speeds)/len(speeds):.2f} km/h")
        print(f"      First record: {records[0]['speed_kmh']:.2f} km/h, cadence={records[0]['cadence']:.1f}")
        print(f"      Last record: {records[-1]['speed_kmh']:.2f} km/h, cadence={records[-1]['cadence']:.1f}")

print("\n" + "="*80)
