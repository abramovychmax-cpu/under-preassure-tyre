#!/usr/bin/env python3
"""
Generate 13-lap JSONL metadata + sensor_records files from FIT file.
- 10 Hz data (10 records per second)
- Lap 0: Warm-up (no pressure metadata)
- Laps 1-11: Descents with varying pressures (3.0-5.0 bar)
- Lap 12: Cool-down (no pressure metadata)
"""

import json
import sys
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict

try:
    from fitparse import FitFile
except ImportError:
    print("ERROR: fitparse not installed. Install with: pip install fitparse")
    sys.exit(1)


def generate_jsonl_files(fit_path: str) -> None:
    """Generate JSONL metadata and sensor records from FIT file."""
    
    fit = FitFile(fit_path)
    
    # Extract all records from FIT
    records = []
    for message in fit.messages:
        if message.name == 'record':
            timestamp = message.get_value('timestamp')
            cadence = message.get_value('cadence') or 0
            speed = message.get_value('speed')  # m/s
            power = message.get_value('power') or 0
            distance = message.get_value('distance') or 0.0
            altitude = message.get_value('altitude') or 0.0
            lat = message.get_value('position_lat')
            lon = message.get_value('position_long')
            
            # Convert speed m/s to km/h
            speed_kmh = (speed * 3.6) if speed else 0.0
            
            if timestamp:
                records.append({
                    'timestamp': timestamp,
                    'cadence': int(cadence),
                    'speed_kmh': round(speed_kmh, 2),
                    'power': int(power),
                    'distance': round(distance, 1),
                    'altitude': round(altitude, 1),
                    'lat': lat,
                    'lon': lon,
                })
    
    print(f"Total records in FIT: {len(records)}")
    
    # Detect descents (find altitude drops)
    descents = []
    MIN_DROP = 20.0
    MAX_DURATION = 60
    
    i = 0
    while i < len(records):
        start_alt = records[i]['altitude']
        start_idx = i
        min_alt = start_alt
        
        j = i + 1
        while j < len(records) and j - i <= MAX_DURATION:
            alt = records[j]['altitude']
            if alt < min_alt:
                min_alt = alt
            j += 1
        
        drop = start_alt - min_alt
        
        if drop >= MIN_DROP:
            end_idx = min(i + MAX_DURATION, len(records) - 1)
            descents.append({
                'start_idx': start_idx,
                'end_idx': end_idx,
                'drop': drop,
            })
            i = end_idx
        else:
            i += 1
    
    print(f"Descents detected: {len(descents)}")
    
    # Define lap structure (13 laps total)
    # Lap 0: warm-up (first part of FIT)
    # Laps 1-11: descents with pressures
    # Lap 12: cool-down (last part of FIT)
    
    laps = []
    
    # Lap 0: Warm-up (first 100 records)
    warmup_end = min(100, len(records))
    laps.append({
        'lap_idx': 0,
        'type': 'warmup',
        'start_idx': 0,
        'end_idx': warmup_end,
        'front_psi': None,
        'rear_psi': None,
    })
    
    # Laps 1-11: Descents (with detected descent data)
    for i, descent in enumerate(descents[:11]):  # Only first 11 descents
        # Calculate pressure: 3.0-5.0 bar in 11 steps
        pressure = 3.0 + (i * 0.2)
        laps.append({
            'lap_idx': i + 1,
            'type': 'descent',
            'start_idx': descent['start_idx'],
            'end_idx': descent['end_idx'],
            'front_psi': round(pressure, 1),
            'rear_psi': round(pressure, 1),
        })
    
    # Lap 12: Cool-down (last 100 records)
    cooldown_start = max(warmup_end, len(records) - 100)
    laps.append({
        'lap_idx': 12,
        'type': 'cooldown',
        'start_idx': cooldown_start,
        'end_idx': len(records),
        'front_psi': None,
        'rear_psi': None,
    })
    
    print(f"\nLap structure:")
    for lap in laps:
        print(f"  Lap {lap['lap_idx']}: {lap['type']} "
              f"(records {lap['start_idx']}-{lap['end_idx']}, "
              f"pressure={lap['front_psi']} bar)")
    
    # Generate 10 Hz sensor records
    sensor_records = []
    
    for lap in laps:
        lap_idx = lap['lap_idx']
        records_in_lap = records[lap['start_idx']:lap['end_idx']+1]
        
        # Interpolate to 10 Hz (assuming 1 Hz input, expand each record to 10)
        for record_idx, record in enumerate(records_in_lap):
            # Get initial speed and simulate coast deceleration based on pressure
            base_speed = record['speed_kmh']
            
            # For descent laps, simulate realistic coasting with pressure-dependent deceleration
            if 1 <= lap_idx <= 11:
                # Lower pressure = lower rolling resistance = slower deceleration (better)
                # Higher pressure = higher rolling resistance = faster deceleration (worse)
                decel_rate = 0.001 + (lap_idx - 1) * 0.0003  # 0.001 to 0.0035 km/h per record
                
                # Create 10 samples per second with realistic speed decay
                for i in range(10):
                    # Speed decreases gradually during descent (realistic coast)
                    t_fraction = (record_idx * 10 + i) / (len(records_in_lap) * 10)
                    speed_decay = decel_rate * (record_idx * 10 + i) * 0.5
                    speed = max(5.0, base_speed - speed_decay)
                    
                    # Cadence is near zero during coast (maybe occasional pedal input)
                    cadence = max(0, 5 - (i % 3) * 2)  # Slight variation: 5, 3, 1, 5, 3, 1...
                    
                    ts = record['timestamp'] + timedelta(milliseconds=i*100)
                    sensor_record = {
                        'lapIndex': lap_idx,
                        'timestamp': ts.isoformat(),
                        'speed_kmh': round(speed, 2),
                        'cadence': cadence,
                        'power': max(0, 50 - (i * 5)),  # Power decreases as coasting
                        'distance': record['distance'],
                        'altitude': record['altitude'],
                    }
                    if record['lat'] is not None:
                        sensor_record['lat'] = record['lat']
                    if record['lon'] is not None:
                        sensor_record['lon'] = record['lon']
                    
                    sensor_records.append(sensor_record)
            else:
                # Warmup and cooldown: normal riding (not coasting)
                for i in range(10):
                    ts = record['timestamp'] + timedelta(milliseconds=i*100)
                    sensor_record = {
                        'lapIndex': lap_idx,
                        'timestamp': ts.isoformat(),
                        'speed_kmh': base_speed + (i * 0.01),
                        'cadence': max(0, record['cadence'] + (i - 5)),
                        'power': record['power'] + (i - 5),
                        'distance': record['distance'],
                        'altitude': record['altitude'],
                    }
                    if record['lat'] is not None:
                        sensor_record['lat'] = record['lat']
                    if record['lon'] is not None:
                        sensor_record['lon'] = record['lon']
                    
                    sensor_records.append(sensor_record)
    
    # Write sensor_records.jsonl
    sensor_path = f"{fit_path}.sensor_records.jsonl"
    with open(sensor_path, 'w') as f:
        for record in sensor_records:
            f.write(json.dumps(record) + '\n')
    
    print(f"\n✓ Generated {sensor_path}")
    print(f"  Total sensor records: {len(sensor_records)}")
    
    # Generate pressure metadata JSONL
    metadata_records = []
    
    for lap in laps:
        if lap['front_psi'] is None:
            continue  # Skip warmup/cooldown laps
        
        lap_idx = lap['lap_idx']
        records_in_lap = records[lap['start_idx']:lap['end_idx']+1]
        
        # Calculate vibration stats (using speed variation as proxy)
        speeds = [r['speed_kmh'] for r in records_in_lap]
        speed_range = max(speeds) - min(speeds) if speeds else 0
        
        # Generate synthetic vibration based on terrain roughness
        vibration_samples = [0.5 + (s / 50.0) for s in speeds]
        
        vib_avg = sum(vibration_samples) / len(vibration_samples) if vibration_samples else 0.5
        vib_min = min(vibration_samples) if vibration_samples else 0.5
        vib_max = max(vibration_samples) if vibration_samples else 0.5
        
        vib_stddev = 0.0
        if len(vibration_samples) > 1:
            variance = sum((v - vib_avg) ** 2 for v in vibration_samples) / len(vibration_samples)
            vib_stddev = variance ** 0.5
        
        metadata_record = {
            'lapIndex': lap_idx,
            'frontPressure': lap['front_psi'],
            'rearPressure': lap['rear_psi'],
            'timestamp': records_in_lap[0]['timestamp'].isoformat(),
            'vibrationAvg': round(vib_avg, 4),
            'vibrationMin': round(vib_min, 4),
            'vibrationMax': round(vib_max, 4),
            'vibrationStdDev': round(vib_stddev, 4),
            'vibrationSampleCount': len(vibration_samples),
        }
        
        metadata_records.append(metadata_record)
    
    # Write pressure metadata JSONL
    metadata_path = f"{fit_path}.jsonl"
    with open(metadata_path, 'w') as f:
        for record in metadata_records:
            f.write(json.dumps(record) + '\n')
    
    print(f"\n✓ Generated {metadata_path}")
    print(f"  Total metadata records: {len(metadata_records)}")
    print()
    
    # Show sample records
    if metadata_records:
        print("Sample metadata records:")
        for record in metadata_records[:3]:
            print(f"  Lap {record['lapIndex']}: "
                  f"{record['frontPressure']} bar, "
                  f"vibration={record['vibrationAvg']:.3f}g")


if __name__ == '__main__':
    fit_path = 'test_data/10255893432.fit'
    fit_file = Path(fit_path)
    
    if not fit_file.exists():
        print(f"ERROR: File not found: {fit_path}")
        sys.exit(1)
    
    print(f"Generating JSONL files from: {fit_path}\n")
    generate_jsonl_files(str(fit_file))
