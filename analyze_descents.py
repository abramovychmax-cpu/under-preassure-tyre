#!/usr/bin/env python3
"""Analyze descents using altitude, duration, GPS proximity, gradient, and speed validation."""

import math
from fitparse import FitFile

def haversine_distance(lat1, lon1, lat2, lon2):
    """Distance in meters between two GPS points (semicircles)."""
    lat1_deg = lat1 * 180.0 / (2**31)
    lon1_deg = lon1 * 180.0 / (2**31)
    lat2_deg = lat2 * 180.0 / (2**31)
    lon2_deg = lon2 * 180.0 / (2**31)
    
    R = 6371000  # Earth radius in meters
    dlat = math.radians(lat2_deg - lat1_deg)
    dlon = math.radians(lon2_deg - lon1_deg)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1_deg)) * math.cos(math.radians(lat2_deg)) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    return R * c

# Load FIT file
fitfile = FitFile(r'test_data\10255893432.fit', check_crc=False)
all_records = list(fitfile.get_messages('record'))

# Filter records with valid GPS
valid_records = []
for record in all_records:
    lat = record.get_value('position_lat')
    lon = record.get_value('position_long')
    if lat is not None and lon is not None:
        valid_records.append(record)

print(f'Total records: {len(all_records)}, Valid GPS records: {len(valid_records)}\n')

# STEP 1: Filter by altitude + duration (>20m drop, 40-50s)
major_descents = []
in_descent = False
descent_start_idx = None
descent_start_alt = None
descent_min_alt = None

for i, record in enumerate(valid_records):
    alt = record.get_value('altitude')
    speed = record.get_value('speed') or 0
    
    if alt is None:
        continue
    
    if i > 0:
        prev_alt = valid_records[i-1].get_value('altitude')
        if prev_alt is None:
            continue
        
        if prev_alt > alt and speed > 2:
            if not in_descent:
                in_descent = True
                descent_start_idx = i
                descent_start_alt = prev_alt
                descent_min_alt = alt
            else:
                descent_min_alt = min(descent_min_alt, alt)
        
        elif in_descent and prev_alt <= alt:
            duration = i - descent_start_idx
            altitude_drop = descent_start_alt - descent_min_alt
            
            # FILTER: >20m drop AND 40-50s duration
            if altitude_drop > 20 and 40 <= duration <= 50:
                major_descents.append({
                    'start_idx': descent_start_idx,
                    'end_idx': i,
                    'start_alt': descent_start_alt,
                    'min_alt': descent_min_alt,
                    'drop': altitude_drop,
                    'duration': duration
                })
            in_descent = False

print(f'STEP 1: Altitude + Duration Filter')
print(f'  Filtered descents (>20m, 40-50s): {len(major_descents)}\n')

# STEP 2: Cluster by GPS proximity (<100m radius)
clusters = []
used = set()

for i, desc in enumerate(major_descents):
    if i in used:
        continue
    
    cluster = [i]
    used.add(i)
    
    start_lat = valid_records[desc['start_idx']].get_value('position_lat')
    start_lon = valid_records[desc['start_idx']].get_value('position_long')
    
    for j, other_desc in enumerate(major_descents):
        if j in used or i == j:
            continue
        
        other_start_lat = valid_records[other_desc['start_idx']].get_value('position_lat')
        other_start_lon = valid_records[other_desc['start_idx']].get_value('position_long')
        
        distance = haversine_distance(start_lat, start_lon, other_start_lat, other_start_lon)
        
        if distance < 100:  # 100m threshold
            cluster.append(j)
            used.add(j)
    
    clusters.append(cluster)

print(f'STEP 2: GPS Proximity Clustering (<100m)')
print(f'  Clusters found: {len(clusters)}\n')

# STEP 3-5: Analyze each cluster
print('=' * 80)
for c_idx, cluster in enumerate(clusters, 1):
    cluster_descents = [major_descents[i] for i in cluster]
    
    # Calculate cluster stats
    avg_drop = sum(d['drop'] for d in cluster_descents) / len(cluster_descents)
    avg_duration = sum(d['duration'] for d in cluster_descents) / len(cluster_descents)
    
    print(f'\nCluster {c_idx}: {len(cluster)} descents (Avg drop: {avg_drop:.1f}m, Duration: {avg_duration:.1f}s)')
    
    # Score each descent
    scores = []
    for idx, local_idx in enumerate(cluster):
        d = major_descents[local_idx]
        
        # STEP 3: Gradient continuity (how many samples have unexpected rise)
        gradient_errors = 0
        for rec_idx in range(d['start_idx'], d['end_idx'] - 1):
            curr_alt = valid_records[rec_idx].get_value('altitude')
            next_alt = valid_records[rec_idx + 1].get_value('altitude')
            if curr_alt and next_alt and curr_alt <= next_alt:  # Should be descending
                gradient_errors += 1
        
        # STEP 4: Speed validation (avg speed should be 5-10 m/s)
        speeds = []
        for rec_idx in range(d['start_idx'], d['end_idx']):
            spd = valid_records[rec_idx].get_value('speed')
            if spd is not None:
                speeds.append(spd)
        avg_speed = sum(speeds) / len(speeds) if speeds else 0
        speed_valid = 5 < avg_speed < 10
        
        # STEP 5: Quality score (similarity + gradient + speed)
        drop_diff = abs(d['drop'] - avg_drop)
        duration_diff = abs(d['duration'] - avg_duration)
        
        similarity_quality = 1.0 / (1 + drop_diff + duration_diff)
        gradient_quality = 1.0 if gradient_errors < 5 else 0.5
        speed_quality = 1.0 if speed_valid else 0.7
        
        overall_quality = similarity_quality * gradient_quality * speed_quality
        
        start_time = valid_records[d['start_idx']].get_value('timestamp')
        scores.append((local_idx, overall_quality, d, start_time, avg_speed, gradient_errors))
    
    # Sort by overall quality (most similar first)
    scores.sort(key=lambda x: x[1], reverse=True)
    
    print(f'  Top candidates (sorted by quality):')
    for rank, (local_idx, quality, desc, start_time, avg_speed, grad_err) in enumerate(scores[:3], 1):
        print(f'    {rank}. Quality={quality:.3f} | Drop={desc["drop"]:.1f}m | Duration={desc["duration"]}s | Speed={avg_speed:.1f}m/s | GradErr={grad_err} | {start_time}')

print('\n' + '=' * 80)
print(f'SUMMARY: {len(clusters)} GPS clusters, ~{len(major_descents)} high-quality descents on same route')
