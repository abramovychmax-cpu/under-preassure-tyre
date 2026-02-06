#!/usr/bin/env python3
"""
Generate sensor_records.jsonl from FIT file for coast detection testing.
Extracts cadence, speed, power, GPS, altitude from FIT records.
"""

import json
import sys
from pathlib import Path

try:
    from fitparse import FitFile
except ImportError:
    print("ERROR: fitparse not installed. Install with: pip install fitparse")
    sys.exit(1)


def generate_sensor_records(fit_path: str) -> None:
    """
    Extract sensor records from FIT file and write to sensor_records.jsonl.
    
    Args:
        fit_path: Path to .fit file
    """
    fit_file = FitFile(fit_path)
    
    # Output file path
    sensor_path = f"{fit_path}.sensor_records.jsonl"
    
    records_by_lap = {}
    current_lap_idx = 0
    record_count = 0
    
    # Parse all messages from FIT file
    for message in fit_file.messages:
        if message.name == 'lap':
            # Start of new lap
            current_lap_idx = message.get_value('message_index') or 0
            records_by_lap[current_lap_idx] = []
            print(f"Found lap {current_lap_idx}")
            
        elif message.name == 'record':
            # Sensor record - extract all available fields
            timestamp = message.get_value('timestamp')
            cadence = message.get_value('cadence') or 0
            speed = message.get_value('speed')  # m/s
            power = message.get_value('power') or 0
            distance = message.get_value('distance') or 0.0  # meters
            altitude = message.get_value('altitude') or 0.0
            lat = message.get_value('position_lat')
            lon = message.get_value('position_long')
            
            # Convert speed from m/s to km/h
            speed_kmh = (speed * 3.6) if speed else 0.0
            
            # Only create record if we have at least some data
            if timestamp and (cadence or speed_kmh or power):
                record = {
                    'lapIndex': current_lap_idx,
                    'timestamp': timestamp.isoformat() if hasattr(timestamp, 'isoformat') else str(timestamp),
                    'speed_kmh': round(speed_kmh, 2),
                    'cadence': int(cadence),
                    'power': int(power),
                    'distance': round(distance, 1),
                    'altitude': round(altitude, 1) if altitude else 0.0,
                }
                
                # Add GPS if available
                if lat is not None:
                    record['lat'] = round(lat, 6)
                if lon is not None:
                    record['lon'] = round(lon, 6)
                
                if current_lap_idx not in records_by_lap:
                    records_by_lap[current_lap_idx] = []
                records_by_lap[current_lap_idx].append(record)
                record_count += 1
    
    # Write sensor records to JSONL
    with open(sensor_path, 'w') as f:
        for lap_idx in sorted(records_by_lap.keys()):
            for record in records_by_lap[lap_idx]:
                f.write(json.dumps(record) + '\n')
    
    print(f"\n✓ Generated {sensor_path}")
    print(f"  Total records: {record_count}")
    print(f"  Total laps: {len(records_by_lap)}")
    for lap_idx, records in sorted(records_by_lap.items()):
        print(f"  Lap {lap_idx}: {len(records)} records")
        if records:
            # Show first and last record for verification
            first = records[0]
            last = records[-1]
            print(f"    First: speed={first['speed_kmh']} km/h, cadence={first['cadence']} RPM, power={first['power']}W")
            print(f"    Last:  speed={last['speed_kmh']} km/h, cadence={last['cadence']} RPM, power={last['power']}W")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python generate_sensor_records.py <fit_file>")
        print()
        print("Examples:")
        print("  python generate_sensor_records.py test_data/agr.fit")
        print("  python generate_sensor_records.py assets/simulations/agricola_continuous.fit")
        sys.exit(1)
    
    fit_file = sys.argv[1]
    fit_path = Path(fit_file)
    
    if not fit_path.exists():
        print(f"ERROR: File not found: {fit_file}")
        sys.exit(1)
    
    print(f"Processing: {fit_file}")
    print()
    
    try:
        generate_sensor_records(str(fit_path))
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
