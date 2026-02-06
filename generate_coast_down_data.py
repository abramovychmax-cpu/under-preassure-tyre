#!/usr/bin/env python3
"""
Generate realistic coast-down test data from real FIT file.
- Uses all real data from 10255893432.fit
- Keeps all fields, data frequency, GPS, altitude, etc.
- Sets cadence=0 for descent laps (1-11) to simulate coasting
- Generates new JSONL files for testing
"""

import json
from pathlib import Path
from collections import defaultdict
from datetime import datetime

try:
    from fitparse import FitFile
except ImportError:
    print("ERROR: fitparse not installed. Install with: pip install fitparse")
    exit(1)


def generate_coast_down_test_data(fit_path: str) -> None:
    """Generate coast-down test data by modifying cadence in descents."""
    
    # Parse real FIT file
    fit = FitFile(fit_path)
    
    # Extract all records with all fields
    records = []
    for message in fit.messages:
        if message.name == 'record':
            record = {
                'timestamp': message.get_value('timestamp'),
                'cadence': message.get_value('cadence') or 0,
                'speed': message.get_value('speed'),
                'enhanced_speed': message.get_value('enhanced_speed'),
                'distance': message.get_value('distance') or 0.0,
                'altitude': message.get_value('altitude'),
                'enhanced_altitude': message.get_value('enhanced_altitude'),
                'position_lat': message.get_value('position_lat'),
                'position_long': message.get_value('position_long'),
                'heart_rate': message.get_value('heart_rate'),
                'temperature': message.get_value('temperature'),
                'ascent': message.get_value('ascent'),
                'descent': message.get_value('descent'),
                'grade': message.get_value('grade'),
                'calories': message.get_value('calories'),
                'gps_accuracy': message.get_value('gps_accuracy'),
                'battery_soc': message.get_value('battery_soc'),
            }
            records.append(record)
    
    print(f"Total records in FIT: {len(records)}")
    
    # Detect descents using altitude drops
    descents = []
    MIN_DROP = 20.0
    MAX_DURATION = 60
    
    i = 0
    while i < len(records):
        if records[i]['altitude'] is None:
            i += 1
            continue
            
        start_alt = records[i]['altitude']
        start_idx = i
        min_alt = start_alt
        
        j = i + 1
        while j < len(records) and j - i <= MAX_DURATION:
            if records[j]['altitude'] is not None:
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
    
    # Define lap structure
    # Lap 0: records before first descent
    # Laps 1-11: descents
    # Lap 12: records after last descent
    
    lap_assignments = {}
    
    # Lap 0: warmup (before first descent)
    if descents:
        warmup_end = descents[0]['start_idx']
    else:
        warmup_end = len(records) // 2
    
    for i in range(warmup_end):
        lap_assignments[i] = 0
    
    # Laps 1-11: descents
    for lap_num, descent in enumerate(descents[:11]):
        for i in range(descent['start_idx'], descent['end_idx'] + 1):
            lap_assignments[i] = lap_num + 1
    
    # Lap 12: cooldown (after last descent)
    if descents:
        cooldown_start = descents[-1]['end_idx'] + 1
    else:
        cooldown_start = len(records) // 2
    
    for i in range(cooldown_start, len(records)):
        lap_assignments[i] = 12
    
    # Modify records: set cadence=0 for descents
    modified_records = []
    for idx, record in enumerate(records):
        lap_idx = lap_assignments.get(idx, 0)
        
        # Set cadence=0 for descent laps (1-11) to simulate coasting
        if 1 <= lap_idx <= 11:
            record['cadence'] = 0
        
        modified_records.append({
            'lap_idx': lap_idx,
            'record': record
        })
    
    print(f"\nLap structure:")
    lap_counts = defaultdict(int)
    for m in modified_records:
        lap_counts[m['lap_idx']] += 1
    
    for lap_idx in sorted(lap_counts.keys()):
        count = lap_counts[lap_idx]
        lap_type = "warmup" if lap_idx == 0 else "descent" if 1 <= lap_idx <= 11 else "cooldown"
        print(f"  Lap {lap_idx:2}: {count:4} records ({lap_type})")
    
    # Generate pressure metadata JSONL
    # Calculate pressure for descent laps
    metadata_records = []
    
    for lap_idx in range(1, 12):  # Only descents
        records_in_lap = [m['record'] for m in modified_records if m['lap_idx'] == lap_idx]
        
        if not records_in_lap:
            continue
        
        # Pressure: 3.0-5.0 bar distributed across 11 descents
        pressure = 3.0 + (lap_idx - 1) * 0.2
        
        # Calculate vibration stats based on heart_rate variation (as proxy for terrain roughness)
        hr_values = [r['heart_rate'] for r in records_in_lap if r['heart_rate'] is not None]
        
        if hr_values:
            hr_avg = sum(hr_values) / len(hr_values)
            # Vibration correlates roughly with heart rate elevation
            vib_avg = 0.5 + (hr_avg - min(hr_values)) / (max(hr_values) - min(hr_values) + 1) * 0.5
        else:
            vib_avg = 0.75
        
        vib_min = max(0.3, vib_avg - 0.3)
        vib_max = min(1.5, vib_avg + 0.3)
        
        vib_stddev = (vib_max - vib_min) / 4
        
        metadata_record = {
            'lapIndex': lap_idx,
            'frontPressure': round(pressure, 1),
            'rearPressure': round(pressure, 1),
            'timestamp': records_in_lap[0]['timestamp'].isoformat(),
            'vibrationAvg': round(vib_avg, 4),
            'vibrationMin': round(vib_min, 4),
            'vibrationMax': round(vib_max, 4),
            'vibrationStdDev': round(vib_stddev, 4),
            'vibrationSampleCount': len(records_in_lap),
        }
        
        metadata_records.append(metadata_record)
    
    # Write pressure metadata JSONL
    metadata_path = f"{fit_path}.jsonl"
    with open(metadata_path, 'w') as f:
        for record in metadata_records:
            f.write(json.dumps(record) + '\n')
    
    print(f"\n✓ Generated {metadata_path}")
    print(f"  Total metadata records: {len(metadata_records)}")
    
    # Generate sensor records JSONL (all records with all fields)
    sensor_records = []
    
    for m in modified_records:
        lap_idx = m['lap_idx']
        record = m['record']
        
        # Convert speed from m/s to km/h if available
        speed_kmh = 0.0
        if record['enhanced_speed'] is not None:
            speed_kmh = record['enhanced_speed'] * 3.6
        elif record['speed'] is not None:
            speed_kmh = record['speed'] * 3.6
        
        sensor_record = {
            'lapIndex': lap_idx,
            'timestamp': record['timestamp'].isoformat() if record['timestamp'] else '',
            'speed_kmh': round(speed_kmh, 2),
            'cadence': int(record['cadence']),
            'distance': round(record['distance'], 1) if record['distance'] else 0.0,
            'altitude': round(record['altitude'], 1) if record['altitude'] else 0.0,
            'heart_rate': record['heart_rate'] or 0,
            'temperature': round(record['temperature'], 1) if record['temperature'] is not None else 0.0,
            'power': 0,  # Not available in this FIT file
        }
        
        # Add optional GPS fields
        if record['position_lat'] is not None:
            sensor_record['lat'] = round(record['position_lat'], 6)
        if record['position_long'] is not None:
            sensor_record['lon'] = round(record['position_long'], 6)
        
        # Add other optional fields if available
        if record['ascent'] is not None:
            sensor_record['ascent'] = round(record['ascent'], 1)
        if record['descent'] is not None:
            sensor_record['descent'] = round(record['descent'], 1)
        if record['grade'] is not None:
            sensor_record['grade'] = round(record['grade'], 2)
        if record['gps_accuracy'] is not None:
            sensor_record['gps_accuracy'] = int(record['gps_accuracy'])
        if record['battery_soc'] is not None:
            sensor_record['battery_soc'] = int(record['battery_soc'])
        
        sensor_records.append(sensor_record)
    
    # Write sensor records JSONL
    sensor_path = f"{fit_path}.sensor_records.jsonl"
    with open(sensor_path, 'w') as f:
        for record in sensor_records:
            f.write(json.dumps(record) + '\n')
    
    print(f"\n✓ Generated {sensor_path}")
    print(f"  Total sensor records: {len(sensor_records)}")
    print()
    
    # Show sample data
    print("Sample records (first descent, lap 1):")
    lap1_records = [m for m in modified_records if m['lap_idx'] == 1]
    if lap1_records:
        for i, m in enumerate(lap1_records[:3]):
            r = m['record']
            print(f"  Record {i}: "
                  f"cadence={r['cadence']} RPM, "
                  f"speed={r['enhanced_speed']*3.6 if r['enhanced_speed'] else 0:.1f} km/h, "
                  f"alt={r['altitude']:.1f}m" if r['altitude'] else "")


if __name__ == '__main__':
    fit_path = 'test_data/10255893432.fit'
    fit_file = Path(fit_path)
    
    if not fit_file.exists():
        print(f"ERROR: File not found: {fit_path}")
        exit(1)
    
    print(f"Generating coast-down test data from: {fit_path}\n")
    generate_coast_down_test_data(str(fit_file))
