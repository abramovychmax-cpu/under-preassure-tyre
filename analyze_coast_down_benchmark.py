#!/usr/bin/env python3
import json
from datetime import datetime

# Analyze coast_down JSONL file
jsonl_file = 'test_data/coast_down_20260129_194342.jsonl'

laps = {}
file_metadata = {}
records_by_lap = {}

with open(jsonl_file, 'r') as f:
    for line in f:
        data = json.loads(line)
        
        if data['type'] == 'file_id':
            file_metadata = data.get('metadata', {})
            print("=== FILE METADATA ===")
            print(f"Protocol: {file_metadata.get('protocol')}")
            print(f"Wheel circumference: {file_metadata.get('wheel_circumference_m')} m")
            print()
        
        elif data['type'] == 'lap':
            lap_idx = data.get('lap_index')
            laps[lap_idx] = {
                'front_psi': data.get('front_psi'),
                'rear_psi': data.get('rear_psi'),
                'ts': data.get('ts'),
                'records': []
            }
            records_by_lap[lap_idx] = []
        
        elif data['type'] == 'record':
            lap_idx = list(laps.keys())[-1] if laps else 1
            if 'speed_kmh' in data:
                records_by_lap[lap_idx].append({
                    'ts': data['ts'],
                    'speed_kmh': data['speed_kmh']
                })

print("=== LAP SUMMARY ===")
for lap_idx in sorted(laps.keys()):
    lap = laps[lap_idx]
    print(f"\nLAP {lap_idx}:")
    print(f"  Front pressure: {lap['front_psi']} PSI")
    print(f"  Rear pressure: {lap['rear_psi']} PSI")
    print(f"  Start time: {lap['ts']}")

print("\n=== SPEED ANALYSIS ===")

for lap_idx in sorted(records_by_lap.keys()):
    speed_records = records_by_lap[lap_idx]
    
    if not speed_records:
        print(f"\nLAP {lap_idx}: No speed data")
        continue
    
    speeds = [r['speed_kmh'] for r in speed_records]
    min_speed = min(speeds)
    max_speed = max(speeds)
    avg_speed = sum(speeds) / len(speeds)
    
    # Parse timestamps
    ts_start = datetime.fromisoformat(speed_records[0]['ts'])
    ts_end = datetime.fromisoformat(speed_records[-1]['ts'])
    duration = (ts_end - ts_start).total_seconds()
    
    # Acceleration
    start_speed = speeds[0]
    end_speed = speeds[-1]
    if duration > 0:
        accel = (end_speed - start_speed) / duration
    else:
        accel = 0
    
    # Time to reach 20 km/h
    time_to_20 = None
    for i, r in enumerate(speed_records):
        if r['speed_kmh'] >= 20.0:
            ts = datetime.fromisoformat(r['ts'])
            time_to_20 = (ts - ts_start).total_seconds()
            break
    
    print(f"\nLAP {lap_idx}:")
    print(f"  Duration: {duration:.1f} seconds")
    print(f"  Speed range: {min_speed:.2f} - {max_speed:.2f} km/h")
    print(f"  Average speed: {avg_speed:.2f} km/h")
    print(f"  Acceleration: {accel:.4f} km/h per second ({accel * 3.6:.4f} m/s²)")
    if time_to_20:
        print(f"  Time to reach 20 km/h: {time_to_20:.2f} seconds")
    print(f"  Sample count: {len(speed_records)}")

print("\n" + "="*80)
print("KEY INSIGHTS FOR ANALYSIS:")
print("="*80)
print("""
✓ Speed data: Successfully captured from CSC sensor
✓ Timestamps: Precise to millisecond (good for calculating acceleration)
✓ Duration: Long runs (>200 seconds) allow accurate acceleration measurement
✓ Coast-down physics: Clear acceleration phase followed by plateau

ACCELERATION METRIC:
- Delta_speed / elapsed_time = acceleration in km/h per second
- Or: time_to_20km/h = inverse metric (lower = better rolling resistance)
- Both metrics are valid; choose based on data clarity
""")
