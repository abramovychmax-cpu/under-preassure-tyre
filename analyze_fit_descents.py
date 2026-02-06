#!/usr/bin/env python3
"""
Analyze FIT file to detect descents.
"""

import sys
from pathlib import Path

try:
    from fitparse import FitFile
except ImportError:
    print("ERROR: fitparse not installed. Install with: pip install fitparse")
    sys.exit(1)


def analyze_descents(fit_path: str) -> None:
    """Analyze FIT file and detect descents."""
    fit = FitFile(fit_path)
    
    records = []
    laps = []
    
    for message in fit.messages:
        if message.name == 'lap':
            lap_info = {
                'index': message.get_value('message_index') or len(laps),
                'timestamp': message.get_value('timestamp'),
                'distance': message.get_value('total_distance') or 0,
            }
            laps.append(lap_info)
            print(f"Lap {lap_info['index']}: {lap_info['distance']:.0f}m")
            
        elif message.name == 'record':
            timestamp = message.get_value('timestamp')
            altitude = message.get_value('altitude')
            speed = message.get_value('speed')
            lat = message.get_value('position_lat')
            lon = message.get_value('position_long')
            
            if timestamp and altitude is not None:
                records.append({
                    'timestamp': timestamp,
                    'altitude': altitude,
                    'speed': speed or 0,
                    'lat': lat,
                    'lon': lon,
                })
    
    print(f"\nTotal records: {len(records)}")
    print(f"Total laps: {len(laps)}")
    
    if not records:
        print("No altitude records found")
        return
    
    # Find descents: altitude drop > 20m in < 60 seconds
    descents = []
    MIN_DROP = 20.0
    MAX_DURATION = 60
    
    i = 0
    while i < len(records):
        start_alt = records[i]['altitude']
        start_idx = i
        min_alt = start_alt
        
        # Look ahead for descent
        j = i + 1
        while j < len(records) and j - i <= MAX_DURATION:
            alt = records[j]['altitude']
            if alt < min_alt:
                min_alt = alt
            j += 1
        
        drop = start_alt - min_alt
        
        if drop >= MIN_DROP:
            end_idx = min(i + MAX_DURATION, len(records) - 1)
            duration = end_idx - start_idx
            
            descents.append({
                'start_idx': start_idx,
                'end_idx': end_idx,
                'duration': duration,
                'drop': drop,
                'start_alt': start_alt,
                'end_alt': records[end_idx]['altitude'],
            })
            
            i = end_idx
        else:
            i += 1
    
    print(f"\nDescents detected (drop >= {MIN_DROP}m): {len(descents)}")
    for i, d in enumerate(descents):
        print(f"  {i+1}. Drop: {d['drop']:.1f}m, Duration: {d['duration']}s, "
              f"Altitude: {d['start_alt']:.1f}m -> {d['end_alt']:.1f}m")


if __name__ == '__main__':
    fit_path = 'test_data/10255893432.fit'
    fit_file = Path(fit_path)
    
    if not fit_file.exists():
        print(f"ERROR: File not found: {fit_path}")
        sys.exit(1)
    
    print(f"Analyzing: {fit_path}\n")
    analyze_descents(str(fit_file))
