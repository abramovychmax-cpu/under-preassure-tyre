import json
from datetime import datetime
import math

jsonl_file = 'test_data/coast_down_20260129_194342.jsonl'

laps = {}
lap_gps = {}

with open(jsonl_file, 'r') as f:
    for line in f:
        data = json.loads(line)
        
        if data['type'] == 'lap':
            lap_idx = data['lap_index']
            laps[lap_idx] = {
                'ts': data['ts'],
                'front_psi': data['front_psi'],
                'rear_psi': data['rear_psi']
            }
            lap_gps[lap_idx] = {'start': None, 'end': None, 'gps_records': []}
        
        elif data['type'] == 'record' and 'lat' in data:
            # Find which lap this record belongs to
            if laps:
                lap_idx = max(laps.keys())  # Current lap
                lap_gps[lap_idx]['gps_records'].append({
                    'ts': data['ts'],
                    'lat': data['lat'],
                    'lon': data['lon'],
                    'alt': data.get('altitude_m')
                })

# Extract start/end points
for lap_idx in sorted(laps.keys()):
    gps_recs = lap_gps[lap_idx]['gps_records']
    if gps_recs:
        lap_gps[lap_idx]['start'] = gps_recs[0]
        lap_gps[lap_idx]['end'] = gps_recs[-1]

print("=== LAP GPS ANALYSIS ===\n")

lap_metrics = {}

for lap_idx in sorted(laps.keys()):
    lap = laps[lap_idx]
    gps = lap_gps[lap_idx]
    start = gps['start']
    end = gps['end']
    
    if start and end:
        # Calculate haversine distance
        lat1, lon1 = start['lat'], start['lon']
        lat2, lon2 = end['lat'], end['lon']
        
        R = 6371  # Earth radius in km
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        distance_km = R * c
        distance_m = distance_km * 1000
        
        # Duration
        ts_start = datetime.fromisoformat(start['ts'])
        ts_end = datetime.fromisoformat(end['ts'])
        duration = (ts_end - ts_start).total_seconds()
        
        lap_metrics[lap_idx] = {
            'pressure': lap['front_psi'],
            'start_lat': lat1,
            'start_lon': lon1,
            'end_lat': lat2,
            'end_lon': lon2,
            'gps_distance': distance_m,
            'duration': duration,
            'num_records': len(gps['gps_records'])
        }
        
        print(f"LAP {lap_idx}:")
        print(f"  Pressure: {lap['front_psi']} PSI (front)")
        print(f"  Start GPS: ({lat1:.6f}, {lon1:.6f})")
        print(f"  End GPS:   ({lat2:.6f}, {lon2:.6f})")
        print(f"  GPS Distance: {distance_m:.1f} meters")
        print(f"  Duration: {duration:.1f} seconds")
        print(f"  GPS Records: {len(gps['gps_records'])}")
        print()

print("\n=== CLUSTERING ANALYSIS ===\n")

# Define clustering tolerances
GPS_TOLERANCE_M = 100  # 100 meters
DURATION_TOLERANCE_S = 10  # 10 seconds

# Group laps by GPS proximity
clusters = []
for lap_idx, metrics in lap_metrics.items():
    assigned = False
    
    for cluster in clusters:
        # Check if this lap is close to the cluster
        cluster_start_lat, cluster_start_lon = cluster[0]['start_lat'], cluster[0]['start_lon']
        
        # Haversine distance to cluster start
        dlat = math.radians(metrics['start_lat'] - cluster_start_lat)
        dlon = math.radians(metrics['start_lon'] - cluster_start_lon)
        R = 6371
        a = math.sin(dlat/2)**2 + math.cos(math.radians(cluster_start_lat)) * math.cos(math.radians(metrics['start_lat'])) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        distance_m = R * c * 1000
        
        # Check duration similarity
        avg_duration = sum(m['duration'] for m in cluster) / len(cluster)
        duration_diff = abs(metrics['duration'] - avg_duration)
        
        if distance_m <= GPS_TOLERANCE_M and duration_diff <= DURATION_TOLERANCE_S:
            cluster.append(metrics)
            assigned = True
            break
    
    if not assigned:
        clusters.append([metrics])

print(f"Found {len(clusters)} cluster(s):\n")

for i, cluster in enumerate(clusters):
    print(f"CLUSTER {i+1}:")
    print(f"  Number of laps: {len(cluster)}")
    
    laps_list = sorted(cluster, key=lambda x: x['pressure'])
    
    pressures = [m['pressure'] for m in laps_list]
    durations = [m['duration'] for m in laps_list]
    
    print(f"  Pressures: {pressures}")
    print(f"  Durations: {[f'{d:.1f}s' for d in durations]}")
    print(f"  GPS Spread: {max(m['gps_distance'] for m in cluster) - min(m['gps_distance'] for m in cluster):.1f}m")
    print()

# Recommendation
largest_cluster = max(clusters, key=len)
print(f"\n=== RECOMMENDATION ===")
print(f"Largest cluster has {len(largest_cluster)} laps")
print(f"Use ONLY these laps for regression analysis:")
for m in sorted(largest_cluster, key=lambda x: x['pressure']):
    print(f"  - {m['pressure']} PSI")
