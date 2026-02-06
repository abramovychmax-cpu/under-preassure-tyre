import json
from datetime import datetime
import math

# Test clustering logic in Dart with the real test data

jsonl_file = 'test_data/coast_down_20260129_194342.jsonl'

# Simulate what Dart's clustering_service.dart will do
class LapMetrics:
    def __init__(self, lap_index, front_psi, start_lat, start_lon, end_lat, end_lon, 
                 gps_distance_m, duration_s, accel_score, max_speed, vibration_rms):
        self.lap_index = lap_index
        self.front_psi = front_psi
        self.start_lat = start_lat
        self.start_lon = start_lon
        self.end_lat = end_lat
        self.end_lon = end_lon
        self.gps_distance_m = gps_distance_m
        self.duration_s = duration_s
        self.accel_score = accel_score  # seconds to 20 km/h
        self.max_speed = max_speed
        self.vibration_rms = vibration_rms

def haversine(lat1, lon1, lat2, lon2):
    R = 6371  # km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    return R * c * 1000  # meters

# Parse JSONL like Dart will
laps = {}
lap_records = {}
lap_metadata = {}
current_lap_idx = 0

with open(jsonl_file, 'r') as f:
    for line in f:
        data = json.loads(line)
        
        if data['type'] == 'lap':
            current_lap_idx = data['lap_index']
            lap_metadata[current_lap_idx] = data
            lap_records[current_lap_idx] = []
        elif data['type'] == 'record':
            if current_lap_idx in lap_records:
                lap_records[current_lap_idx].append(data)

# Extract metrics for each lap
lap_metrics_list = []

for lap_idx in sorted(lap_metadata.keys()):
    meta = lap_metadata[lap_idx]
    records = lap_records[lap_idx]
    
    if not records:
        continue
    
    # GPS data (may not be in this test file)
    gps_records = [r for r in records if 'lat' in r and 'lon' in r]
    start_lat, start_lon, end_lat, end_lon, gps_dist = 0.0, 0.0, 0.0, 0.0, 0.0
    
    if gps_records:
        start_lat = gps_records[0]['lat']
        start_lon = gps_records[0]['lon']
        end_lat = gps_records[-1]['lat']
        end_lon = gps_records[-1]['lon']
        gps_dist = haversine(start_lat, start_lon, end_lat, end_lon)
    
    # Duration - use all records that have timestamps
    ts_records = [r for r in records if 'ts' in r]
    duration = 0.0
    if len(ts_records) >= 2:
        try:
            start_time = datetime.fromisoformat(ts_records[0]['ts'])
            end_time = datetime.fromisoformat(ts_records[-1]['ts'])
            duration = (end_time - start_time).total_seconds()
        except:
            pass
    
    # Acceleration (time to 20 km/h)
    speed_records = [r for r in records if 'speed_kmh' in r]
    accel_score = float('inf')
    if speed_records:
        try:
            start_time = datetime.fromisoformat(speed_records[0]['ts'])
            for rec in speed_records:
                if rec['speed_kmh'] >= 20.0:
                    rec_time = datetime.fromisoformat(rec['ts'])
                    accel_score = (rec_time - start_time).total_seconds()
                    break
        except:
            pass
    
    # Max speed
    max_speed = max([r['speed_kmh'] for r in speed_records]) if speed_records else 0.0
    
    # Vibration RMS (using vibration_g field)
    vib_samples = [r['vibration_g'] for r in records if 'vibration_g' in r]
    vibration_rms = sum(vib_samples) / len(vib_samples) if vib_samples else 0.0
    
    lap_metrics_list.append(LapMetrics(
        lap_idx,
        meta['front_psi'],
        start_lat, start_lon,
        end_lat, end_lon,
        gps_dist,
        duration,
        accel_score,
        max_speed,
        vibration_rms
    ))

print("=== EXTRACTED LAP METRICS ===\n")
for lap in lap_metrics_list:
    print(f"Lap {lap.lap_index}: {lap.front_psi} PSI")
    if lap.gps_distance_m > 0:
        print(f"  GPS: ({lap.start_lat:.6f}, {lap.start_lon:.6f}) -> ({lap.end_lat:.6f}, {lap.end_lon:.6f})")
        print(f"  GPS Distance: {lap.gps_distance_m:.1f}m")
    else:
        print(f"  GPS: (not available)")
    print(f"  Duration: {lap.duration_s:.1f}s")
    print(f"  Acceleration (time to 20 km/h): {lap.accel_score if lap.accel_score != float('inf') else 'N/A'}")
    print(f"  Max speed: {lap.max_speed:.2f} km/h")
    print(f"  Vibration RMS: {lap.vibration_rms:.3f} g")
    print()

# For cases without GPS, cluster by duration only
print("=== CLUSTERING (Duration-based, since GPS not available) ===\n")

DURATION_TOLERANCE = 10  # seconds

clusters = []
for lap in lap_metrics_list:
    assigned = False
    
    for cluster in clusters:
        ref = cluster[0]
        
        # Check duration similarity
        avg_duration = sum(m.duration_s for m in cluster) / len(cluster)
        duration_diff = abs(lap.duration_s - avg_duration)
        
        if duration_diff <= DURATION_TOLERANCE:
            cluster.append(lap)
            assigned = True
            break
    
    if not assigned:
        clusters.append([lap])

print(f"Found {len(clusters)} cluster(s)\n")

for i, cluster in enumerate(clusters):
    print(f"CLUSTER {i+1}: {len(cluster)} laps")
    pressures = sorted([m.front_psi for m in cluster])
    print(f"  Pressures: {pressures}")
    
    # Prepare regression data
    print(f"  Regression data:")
    for lap in sorted(cluster, key=lambda x: x.front_psi):
        efficiency = 10.0 / (lap.accel_score + 0.1) if lap.accel_score != float('inf') else 0.0
        accel_str = f"{lap.accel_score:.2f}s" if lap.accel_score != float('inf') else "N/A"
        print(f"    {lap.front_psi} PSI: accel={accel_str} -> efficiency={efficiency:.4f}, "
              f"vibration={lap.vibration_rms:.3f}g, max_speed={lap.max_speed:.1f} km/h")
    print()

# Recommendation
if clusters:
    largest = sorted(clusters, key=len, reverse=True)[0]
    print(f"=== RECOMMENDATION ===")
    print(f"Use largest cluster with {len(largest)} laps:")
    for lap in sorted(largest, key=lambda x: x.front_psi):
        print(f"  - {lap.front_psi} PSI")
    
    if len(largest) >= 3:
        print("\n✓ Ready for quadratic regression")
    else:
        print(f"\n✗ Only {len(largest)} laps (need 3)")
        print("NOTE: The test data only has 3 laps total.")
        print("      Ideal scenario: multiple sessions at same location with different pressures")

