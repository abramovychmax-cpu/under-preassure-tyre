#!/usr/bin/env python3
"""
Test descent detection using Python fitparse
Validates the algorithm logic before running in Dart
"""

import fitparse
import math
import json

FIT_FILE = 'test_data/10255893432.fit'

def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in meters between two GPS points"""
    R = 6371000.0  # Earth radius in meters
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
    """Find start of descent: altitude drops consistently"""
    for i in range(start_idx, len(records) - 5):
        alt1 = records[i].get('altitude')
        alt2 = records[i+1].get('altitude')
        alt3 = records[i+2].get('altitude')
        
        if alt1 is None or alt2 is None or alt3 is None:
            continue
        
        # Check for consistent descent
        if alt1 > alt2 and alt2 > alt3:
            speed = records[i].get('speed', 0)
            if speed > 2.0:
                return i  # Found start
    return -1

def find_descent_end(records, start_idx):
    """Find end of descent: altitude stops dropping or reverses"""
    consecutive_flat_or_up = 0
    flat_threshold = 3
    
    for i in range(start_idx + 1, len(records) - 1):
        alt_current = records[i].get('altitude')
        alt_next = records[i+1].get('altitude')
        speed = records[i].get('speed', 0)
        
        if alt_current is None or alt_next is None:
            break
        
        # Check for descent
        if alt_current > alt_next:
            consecutive_flat_or_up = 0
        else:
            consecutive_flat_or_up += 1
        
        # Check for stop
        if speed < 1.0:
            consecutive_flat_or_up += 1
        
        # Check for turnaround (GPS reversal)
        if i > 10 and _is_gps_turnaround(records, i):
            return i
        
        if consecutive_flat_or_up >= flat_threshold:
            return i
    
    return len(records) - 1

def _is_gps_turnaround(records, idx):
    """Check if GPS is reversing direction"""
    if idx < 10:
        return False
    
    lat = records[idx].get('lat')
    lon = records[idx].get('lon')
    
    if lat is None or lon is None:
        return False
    
    # Check last 10 points
    total_distance = 0
    max_distance = 0
    
    for i in range(idx - 10, idx):
        prev_lat = records[i].get('lat')
        prev_lon = records[i].get('lon')
        if prev_lat is None or prev_lon is None:
            continue
        
        dist = haversine_distance(prev_lat, prev_lon, lat, lon)
        total_distance += dist
        if dist > max_distance:
            max_distance = dist
    
    return total_distance < max_distance * 0.5

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
        'start_idx': start_idx,
        'end_idx': end_idx,
        'altitude_drop': altitude_drop,
        'duration': duration,
        'avg_speed': avg_speed,
        'max_speed': max_speed,
        'start_lat': start_lat,
        'start_lon': start_lon,
        'end_lat': end_lat,
        'end_lon': end_lon,
        'altitudes': altitudes,
        'speeds': speeds,
    }

def validate_descent(segment):
    """Check if descent passes quality checks"""
    # Must have meaningful altitude drop
    if segment['altitude_drop'] < 10.0:
        return False
    
    # Must be reasonable duration
    if segment['duration'] < 10 or segment['duration'] > 90:
        return False
    
    # Must be moving
    if segment['avg_speed'] < 2.0:
        return False
    
    # Check altitude consistency
    alt_consistency_errors = 0
    for i in range(len(segment['altitudes']) - 1):
        if segment['altitudes'][i] <= segment['altitudes'][i+1]:
            alt_consistency_errors += 1
    
    error_rate = alt_consistency_errors / len(segment['altitudes'])
    if error_rate > 0.2:
        return False
    
    return True

def cluster_by_gps(descents, radius_m=100.0):
    """Cluster descents by GPS proximity"""
    clusters = []
    used = set()
    
    for i in range(len(descents)):
        if i in used:
            continue
        
        cluster = [descents[i]]
        used.add(i)
        
        for j in range(i + 1, len(descents)):
            if j in used:
                continue
            
            dist = haversine_distance(
                descents[i]['start_lat'], descents[i]['start_lon'],
                descents[j]['start_lat'], descents[j]['start_lon'],
            )
            
            if dist < radius_m:
                cluster.append(descents[j])
                used.add(j)
        
        clusters.append(cluster)
    
    return clusters

def quality_score(descent, avg_drop, avg_speed):
    """Calculate quality score for a descent"""
    # Similarity to cluster average
    drop_sim = 1.0 - abs(descent['altitude_drop'] - avg_drop) / avg_drop
    speed_sim = 1.0 - abs(descent['avg_speed'] - avg_speed) / avg_speed
    
    # Gradient consistency
    reversals = 0
    for i in range(len(descent['altitudes']) - 1):
        if descent['altitudes'][i] <= descent['altitudes'][i+1]:
            reversals += 1
    
    consistency = 1.0 - (reversals / len(descent['altitudes']))
    
    # Weighted average
    return (drop_sim * 0.4 + speed_sim * 0.4 + consistency * 0.2)

def main():
    print('🔍 Testing Descent Detection on Agricola FIT file...\n')
    
    # Load FIT file
    fitfile = fitparse.FitFile(FIT_FILE)
    records = extract_records(fitfile)
    
    print(f'📊 FIT File Analysis')
    print('═' * 60)
    print(f'✅ Loaded {len(records)} records with GPS + altitude\n')
    
    # Detect descents
    print(f'🔎 Detecting Descent Segments...')
    print('─' * 60)
    
    descents = []
    i = 0
    while i < len(records):
        start = find_descent_start(records, i)
        if start == -1:
            break
        
        end = find_descent_end(records, start)
        segment = extract_descent_segment(records, start, end)
        
        if segment and validate_descent(segment):
            descents.append(segment)
        
        i = end + 1
    
    print(f'✅ Detected {len(descents)} descent segments\n')
    
    # Cluster by GPS
    print(f'📍 Clustering by GPS Location (radius=100m)...')
    print('─' * 60)
    
    clusters = cluster_by_gps(descents, radius_m=100.0)
    print(f'✅ Found {len(clusters)} cluster(s)\n')
    
    # Display results
    for cluster_idx, cluster in enumerate(clusters):
        print(f'📍 CLUSTER {cluster_idx} ({len(cluster)} descents)')
        print('─' * 60)
        
        # Cluster statistics
        avg_drop = sum(d['altitude_drop'] for d in cluster) / len(cluster)
        avg_duration = sum(d['duration'] for d in cluster) / len(cluster)
        avg_speed = sum(d['avg_speed'] for d in cluster) / len(cluster)
        
        print(f'Average Drop:    {avg_drop:.1f}m')
        print(f'Average Duration: {avg_duration:.1f}s')
        print(f'Average Speed:    {avg_speed:.1f}m/s\n')
        
        # Sort by quality
        sorted_descents = sorted(cluster, key=lambda d: quality_score(d, avg_drop, avg_speed), reverse=True)
        
        print('Top 3 Quality Descents:')
        for i, d in enumerate(sorted_descents[:3]):
            score = quality_score(d, avg_drop, avg_speed)
            print(f'  {i+1}. Score={score:.3f} | Drop={d["altitude_drop"]:.1f}m | Duration={d["duration"]:.0f}s | Speed={d["avg_speed"]:.1f}m/s')
        print('')
    
    # Summary
    print('═' * 60)
    print('✅ DESCENT DETECTION COMPLETE')
    print('═' * 60)
    print(f'Found {len(descents)} descents in {len(clusters)} location(s)')
    print('Ready for quadratic regression on tire pressure optimization!\n')

if __name__ == '__main__':
    main()
