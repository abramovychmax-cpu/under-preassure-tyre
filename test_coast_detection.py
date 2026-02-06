#!/usr/bin/env python3
"""
Test the analysis pipeline with generated JSONL files.
Simulates what the Flutter app does when loading FIT+JSONL for analysis.
"""

import json
from pathlib import Path
from collections import defaultdict
import math


def test_coast_detection():
    """Test coast detection logic on generated sensor records."""
    
    fit_path = 'test_data/10255893432.fit'
    sensor_path = f'{fit_path}.sensor_records.jsonl'
    metadata_path = f'{fit_path}.jsonl'
    
    # Load sensor records
    sensor_records = defaultdict(list)
    with open(sensor_path, 'r') as f:
        for line in f:
            try:
                record = json.loads(line.strip())
                lap_idx = record['lapIndex']
                sensor_records[lap_idx].append(record)
            except:
                continue
    
    # Load pressure metadata
    metadata = {}
    with open(metadata_path, 'r') as f:
        for line in f:
            try:
                record = json.loads(line.strip())
                lap_idx = record['lapIndex']
                metadata[lap_idx] = record
            except:
                continue
    
    print(f"Loaded {len(sensor_records)} laps of sensor data")
    print(f"Loaded {len(metadata)} laps of pressure metadata\n")
    
    # Test coast detection for each descent lap (1-11)
    results = []
    
    for lap_idx in sorted(sensor_records.keys()):
        records = sensor_records[lap_idx]
        if not records:
            continue
        
        # Calculate coast metrics
        total_cadence = 0.0
        cadence_count = 0
        coast_duration = 0.0
        coast_start_speed = 0.0
        coast_end_speed = 0.0
        in_coast = False
        
        for i, record in enumerate(records):
            cadence = record.get('cadence', 0)
            speed = record.get('speed_kmh', 0)
            
            # Track cadence
            total_cadence += cadence
            cadence_count += 1
            
            # Detect coast: cadence == 0 AND speed > 3 km/h
            if cadence == 0 and speed > 3.0:
                if not in_coast:
                    in_coast = True
                    coast_start_speed = speed
                coast_duration += 0.1  # 10 Hz = 0.1s per record
                coast_end_speed = speed
            else:
                in_coast = False
        
        avg_cadence = total_cadence / cadence_count if cadence_count > 0 else 0
        deceleration = (coast_start_speed - coast_end_speed) / coast_duration if coast_duration > 0 else 0
        
        # Get pressure info if available
        pres = metadata.get(lap_idx)
        pressure = f"{pres['frontPressure']} bar" if pres else "N/A"
        vibration = f"{pres['vibrationAvg']:.3f}g" if pres else "N/A"
        
        result = {
            'lap_idx': lap_idx,
            'pressure': pressure,
            'vibration': vibration,
            'avg_cadence': round(avg_cadence, 1),
            'coast_duration': round(coast_duration, 1),
            'deceleration': round(deceleration, 4),
            'num_records': len(records),
        }
        results.append(result)
        
        if lap_idx >= 1 and lap_idx <= 11:  # Only descents
            print(f"Lap {lap_idx}: {pressure:>8} | "
                  f"Cadence: {result['avg_cadence']:>6.1f} RPM | "
                  f"Coast: {result['coast_duration']:>6.1f}s | "
                  f"Decel: {result['deceleration']:>8.4f} km/h/s | "
                  f"Vibration: {vibration:>8} | "
                  f"Records: {result['num_records']}")
    
    # Analyze deceleration trend
    print("\n" + "="*80)
    print("ANALYSIS: Should see LOWER deceleration at optimal pressure")
    print("="*80)
    
    descent_results = [r for r in results if r['lap_idx'] >= 1 and r['lap_idx'] <= 11]
    
    if descent_results:
        min_decel = min(r['deceleration'] for r in descent_results)
        max_decel = max(r['deceleration'] for r in descent_results)
        opt_pressure = descent_results[[r['deceleration'] for r in descent_results].index(min_decel)]['pressure']
        
        print(f"\nOptimal Pressure (lowest deceleration): {opt_pressure}")
        print(f"Deceleration Range: {min_decel:.4f} - {max_decel:.4f} km/h/s")
        print(f"Spread: {(max_decel - min_decel):.4f} km/h/s\n")
        
        if max_decel - min_decel > 0.001:
            print("✓ Deceleration varies significantly - good data for regression!")
        else:
            print("⚠ Deceleration very similar across pressures - may indicate coast detection issue")


if __name__ == '__main__':
    fit_path = Path('test_data/10255893432.fit')
    
    if not fit_path.exists():
        print(f"ERROR: {fit_path} not found")
        exit(1)
    
    sensor_path = f'{fit_path}.sensor_records.jsonl'
    metadata_path = f'{fit_path}.jsonl'
    
    if not Path(sensor_path).exists():
        print(f"ERROR: {sensor_path} not generated. Run generate_10hz_jsonl.py first")
        exit(1)
    
    if not Path(metadata_path).exists():
        print(f"ERROR: {metadata_path} not generated. Run generate_10hz_jsonl.py first")
        exit(1)
    
    print("Testing Coast Detection Analysis\n")
    test_coast_detection()
