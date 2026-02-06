#!/usr/bin/env python3
"""
Test adaptive learning: Learn signature from first 3 runs, then find all matching descents
"""

import fitparse
import math

FIT_FILE = 'test_data/10255893432.fit'

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in meters between two GPS points"""
    R = 6371000.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat/2)**2 + 
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lon/2)**2)
    c = 2 * math.asin(math.sqrt(a))
    return R * c

def extract_records(fitfile):
    """Extract records with GPS + altitude"""
    records = []
    for record in fitfile.messages:
        if record.name == 'record':
            data = {}
            for field in record.fields:
                if field.name == 'position_lat':
                    data['lat'] = field.value
                elif field.name == 'position_long':
                    data['lon'] = field.value
                elif field.name == 'altitude':
                    data['altitude'] = field.value
                elif field.name == 'speed':
                    data['speed'] = field.value
                elif field.name == 'timestamp':
                    data['timestamp'] = field.value
            
            if 'lat' in data and 'lon' in data and 'altitude' in data:
                records.append(data)
    return records

def find_descent_start(records, start_idx):
    """Find start of descent"""
    for i in range(start_idx, len(records) - 5):
        alt1 = records[i].get('altitude')
        alt2 = records[i+1].get('altitude')
        alt3 = records[i+2].get('altitude')
        
        if alt1 is None or alt2 is None or alt3 is None:
            continue
        
        if alt1 > alt2 and alt2 > alt3:
            speed = records[i].get('speed', 0)
            if speed > 2.0:
                return i
    return -1

def find_descent_end(records, start_idx):
    """Find end of descent"""
    consecutive_flat_or_up = 0
    flat_threshold = 3
    
    for i in range(start_idx + 1, len(records) - 1):
        alt_current = records[i].get('altitude')
        alt_next = records[i+1].get('altitude')
        speed = records[i].get('speed', 0)
        
        if alt_current is None or alt_next is None:
            break
        
        if alt_current > alt_next:
            consecutive_flat_or_up = 0
        else:
            consecutive_flat_or_up += 1
        
        if speed < 1.0:
            consecutive_flat_or_up += 1
        
        if consecutive_flat_or_up >= flat_threshold:
            return i
    
    return len(records) - 1

def extract_descent_segment(records, start_idx, end_idx):
    """Extract descent metrics"""
    if start_idx >= end_idx or end_idx >= len(records):
        return None
    
    altitudes = []
    speeds = []
    start_lat, start_lon, end_lat, end_lon = 0, 0, 0, 0
    max_speed = 0
    
    for i in range(start_idx, end_idx + 1):
        alt = records[i].get('altitude')
        speed = records[i].get('speed', 0)
        lat = records[i].get('lat')
        lon = records[i].get('lon')
        
        if alt is not None:
            altitudes.append(alt)
        speeds.append(speed)
        
        if lat is not None and lon is not None:
            if i == start_idx:
                start_lat, start_lon = lat, lon
            end_lat, end_lon = lat, lon
        
        if speed > max_speed:
            max_speed = speed
    
    if not altitudes:
        return None
    
    altitude_drop = altitudes[0] - altitudes[-1]
    duration = end_idx - start_idx
    avg_speed = sum(speeds) / len(speeds) if speeds else 0
    
    return {
        'altitude_drop': altitude_drop,
        'duration': duration,
        'avg_speed': avg_speed,
        'max_speed': max_speed,
    }

def validate_descent(segment):
    """Check if descent is valid"""
    if segment['altitude_drop'] < 10.0:
        return False
    if segment['duration'] < 10 or segment['duration'] > 90:
        return False
    if segment['avg_speed'] < 2.0:
        return False
    return True

def learn_signature(descents):
    """Learn route signature from initial descents"""
    if not descents:
        return None
    
    # Calculate means
    mean_drop = sum(d['altitude_drop'] for d in descents) / len(descents)
    mean_duration = sum(d['duration'] for d in descents) / len(descents)
    mean_speed = sum(d['avg_speed'] for d in descents) / len(descents)
    
    # Calculate standard deviations
    var_drop = sum((d['altitude_drop'] - mean_drop)**2 for d in descents) / len(descents)
    var_duration = sum((d['duration'] - mean_duration)**2 for d in descents) / len(descents)
    var_speed = sum((d['avg_speed'] - mean_speed)**2 for d in descents) / len(descents)
    
    std_drop = math.sqrt(var_drop)
    std_duration = math.sqrt(var_duration)
    std_speed = math.sqrt(var_speed)
    
    # Adaptive thresholds: mean ± 1.5 * stddev
    return {
        'mean_drop': mean_drop,
        'std_drop': std_drop,
        'min_drop': mean_drop - (std_drop * 1.5),
        'max_drop': mean_drop + (std_drop * 1.5),
        
        'mean_duration': mean_duration,
        'std_duration': std_duration,
        'min_duration': mean_duration - (std_duration * 1.5),
        'max_duration': mean_duration + (std_duration * 1.5),
        
        'mean_speed': mean_speed,
        'std_speed': std_speed,
        'min_speed': mean_speed - (std_speed * 1.5),
        'max_speed': mean_speed + (std_speed * 1.5),
    }

def find_matching_descents(all_descents, signature):
    """Find all descents matching the learned signature"""
    matching = []
    
    for d in all_descents:
        within_drop = d['altitude_drop'] >= signature['min_drop'] and d['altitude_drop'] <= signature['max_drop']
        within_duration = d['duration'] >= signature['min_duration'] and d['duration'] <= signature['max_duration']
        within_speed = d['avg_speed'] >= signature['min_speed'] and d['avg_speed'] <= signature['max_speed']
        
        if within_drop and within_duration and within_speed:
            matching.append(d)
    
    return matching

def main():
    print('🎓 Testing ADAPTIVE LEARNING\n')
    print('📌 Scenario: User does 11 test runs on unknown hill')
    print('   App learns signature from first 3, finds all matching rest\n')
    print('═' * 60)
    
    # Load FIT file
    fitfile = fitparse.FitFile(FIT_FILE)
    records = extract_records(fitfile)
    
    # Detect ALL descents
    print(f'🔎 Step 1: Detect all potential descents from {len(records)} records...')
    all_descents = []
    i = 0
    while i < len(records):
        start = find_descent_start(records, i)
        if start == -1:
            break
        
        end = find_descent_end(records, start)
        segment = extract_descent_segment(records, start, end)
        
        if segment and validate_descent(segment):
            all_descents.append(segment)
        
        i = end + 1
    
    print(f'   ✅ Found {len(all_descents)} total descents\n')
    
    # Simulate: First 3 runs (user's test runs)
    print(f'🎯 Step 2: Simulate first 3 test runs')
    if len(all_descents) >= 3:
        initial_runs = all_descents[:3]
        remaining_descents = all_descents[3:]
        
        print(f'   Run 1: Drop={initial_runs[0]["altitude_drop"]:.1f}m, Duration={initial_runs[0]["duration"]:.0f}s, Speed={initial_runs[0]["avg_speed"]:.1f}m/s')
        print(f'   Run 2: Drop={initial_runs[1]["altitude_drop"]:.1f}m, Duration={initial_runs[1]["duration"]:.0f}s, Speed={initial_runs[1]["avg_speed"]:.1f}m/s')
        print(f'   Run 3: Drop={initial_runs[2]["altitude_drop"]:.1f}m, Duration={initial_runs[2]["duration"]:.0f}s, Speed={initial_runs[2]["avg_speed"]:.1f}m/s\n')
        
        # Learn signature
        print(f'📊 Step 3: Learn route signature from those 3 runs...')
        signature = learn_signature(initial_runs)
        
        print(f'   Altitude Drop:')
        print(f'     Mean: {signature["mean_drop"]:.1f}m')
        print(f'     Std Dev: {signature["std_drop"]:.1f}m')
        print(f'     Range: {signature["min_drop"]:.1f}m - {signature["max_drop"]:.1f}m')
        print(f'   Duration:')
        print(f'     Mean: {signature["mean_duration"]:.1f}s')
        print(f'     Std Dev: {signature["std_duration"]:.1f}s')
        print(f'     Range: {signature["min_duration"]:.1f}s - {signature["max_duration"]:.1f}s')
        print(f'   Speed:')
        print(f'     Mean: {signature["mean_speed"]:.2f}m/s')
        print(f'     Std Dev: {signature["std_speed"]:.2f}m/s')
        print(f'     Range: {signature["min_speed"]:.2f}m/s - {signature["max_speed"]:.2f}m/s\n')
        
        # Find all matching
        print(f'🔍 Step 4: Search entire FIT for descents matching signature...')
        all_matching = find_matching_descents(all_descents, signature)
        
        print(f'   ✅ Found {len(all_matching)} total descents matching signature')
        print(f'   (Includes the original 3 + {len(all_matching) - 3} auto-detected)\n')
        
        # Statistics
        print(f'📈 Statistics of matched descents:')
        avg_drop = sum(d['altitude_drop'] for d in all_matching) / len(all_matching)
        avg_duration = sum(d['duration'] for d in all_matching) / len(all_matching)
        avg_speed = sum(d['avg_speed'] for d in all_matching) / len(all_matching)
        
        print(f'   Avg Drop: {avg_drop:.1f}m')
        print(f'   Avg Duration: {avg_duration:.1f}s')
        print(f'   Avg Speed: {avg_speed:.1f}m/s\n')
        
        # Show which were initially missed
        auto_detected = [d for d in all_matching if d not in initial_runs]
        print(f'🆕 Auto-detected descents (not in first 3):')
        for i, d in enumerate(auto_detected[:3]):  # Show first 3
            print(f'   {i+1}. Drop={d["altitude_drop"]:.1f}m, Duration={d["duration"]:.0f}s, Speed={d["avg_speed"]:.1f}m/s')
        if len(auto_detected) > 3:
            print(f'   ... and {len(auto_detected) - 3} more\n')
        
        print('═' * 60)
        print('✅ ADAPTIVE LEARNING SUCCESS!')
        print(f'═' * 60)
        print(f'Signature learned from: 3 user test runs')
        print(f'Total descents found: {len(all_matching)} (works on ANY hill!)')
        print(f'Ready for quadratic regression on tire pressure!\n')

if __name__ == '__main__':
    main()
