#!/usr/bin/env python3
"""
Convert agr.fit.jsonl to sensor_records.jsonl format.
Consolidates scattered record fields into unified sensor records per second.
"""

import json
from pathlib import Path
from collections import defaultdict
from datetime import datetime

def parse_jsonl_to_sensor_records(jsonl_path: str, output_path: str = None) -> None:
    """
    Parse original JSONL format and consolidate into sensor_records format.
    
    Original format (scattered records):
      {"type": "record", "ts": "2026-01-30T14:30:00", "speed_kmh": 12.04, ...}
      {"type": "record", "ts": "2026-01-30T14:30:00", "vibration_g": 0.708}
      {"type": "record", "ts": "2026-01-30T14:30:00", "lat": 52.254397, ...}
      {"type": "record", "ts": "2026-01-30T14:30:00", "cadence_rpm": 76.7}
    
    Output format (consolidated):
      {"lapIndex": 0, "timestamp": "2026-01-30T14:30:00", "speed_kmh": 12.04, "cadence": 77, "power": 0, "distance": 0.0, "altitude": 137.5, "lat": 52.254397, "lon": 20.986851}
    """
    
    if output_path is None:
        output_path = f"{jsonl_path}.sensor_records.jsonl"
    
    # Read JSONL file
    with open(jsonl_path, 'r') as f:
        lines = f.readlines()
    
    # Group records by timestamp
    lap_index = 0
    records_by_ts = defaultdict(dict)
    
    for line in lines:
        try:
            data = json.loads(line.strip())
        except:
            continue
        
        # Track lap changes
        if data.get('type') == 'lap':
            lap_index = data.get('lap_index', 0)
            continue
        
        # Skip non-record types
        if data.get('type') != 'record':
            continue
        
        ts = data.get('ts')
        if not ts:
            continue
        
        # Initialize record dict for this timestamp if needed
        if ts not in records_by_ts:
            records_by_ts[ts] = {
                'lapIndex': lap_index,
                'timestamp': ts,
                'speed_kmh': 0.0,
                'cadence': 0,
                'power': 0,
                'distance': 0.0,
                'altitude': 0.0,
            }
        
        # Merge fields from this record
        record = records_by_ts[ts]
        
        if 'speed_kmh' in data:
            record['speed_kmh'] = round(data['speed_kmh'], 2)
        
        if 'cadence_rpm' in data:
            record['cadence'] = int(round(data['cadence_rpm']))
        
        if 'power_w' in data:
            record['power'] = int(data['power_w'])
        
        if 'distance_km' in data:
            record['distance'] = round(data['distance_km'] * 1000, 1)  # Convert to meters
        
        if 'altitude_m' in data:
            record['altitude'] = round(data['altitude_m'], 1)
        
        if 'lat' in data:
            record['lat'] = round(data['lat'], 6)
        
        if 'lon' in data:
            record['lon'] = round(data['lon'], 6)
    
    # Write consolidated records to output file
    with open(output_path, 'w') as f:
        for ts in sorted(records_by_ts.keys()):
            record = records_by_ts[ts]
            # Only write if we have speed or cadence data
            if record['speed_kmh'] > 0 or record['cadence'] > 0:
                f.write(json.dumps(record) + '\n')
    
    # Print summary
    print(f"✓ Generated {output_path}")
    print(f"  Total records: {len(records_by_ts)}")
    
    # Group by lap
    laps = defaultdict(list)
    for ts in sorted(records_by_ts.keys()):
        lap_idx = records_by_ts[ts]['lapIndex']
        laps[lap_idx].append(records_by_ts[ts])
    
    print(f"  Total laps: {len(laps)}")
    for lap_idx in sorted(laps.keys()):
        records = laps[lap_idx]
        print(f"  Lap {lap_idx}: {len(records)} records")
        if records:
            first = records[0]
            last = records[-1]
            print(f"    Speed: {first['speed_kmh']:.1f} -> {last['speed_kmh']:.1f} km/h")
            print(f"    Cadence: {first['cadence']} -> {last['cadence']} RPM")

if __name__ == '__main__':
    jsonl_path = 'test_data/agr.fit.jsonl'
    jsonl_file = Path(jsonl_path)
    
    if not jsonl_file.exists():
        print(f"ERROR: File not found: {jsonl_path}")
        exit(1)
    
    print(f"Processing: {jsonl_path}\n")
    parse_jsonl_to_sensor_records(str(jsonl_file))
