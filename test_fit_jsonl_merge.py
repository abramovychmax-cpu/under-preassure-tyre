import json
from datetime import datetime
import math

# Test: Extract metrics from FIT + JSONL (simulated)
# FIT provides: GPS, speed, duration
# JSONL provides: pressure, vibration

jsonl_file = 'test_data/coast_down_20260129_194342.jsonl'

class LapMetrics:
    def __init__(self, lap_index, front_psi, rear_psi, duration_s, max_speed, vibration_rms, num_records):
        self.lap_index = lap_index
        self.front_psi = front_psi
        self.rear_psi = rear_psi
        self.duration_s = duration_s
        self.max_speed = max_speed
        self.vibration_rms = vibration_rms
        self.num_records = num_records

# Parse JSONL (pressure, vibration)
lap_metadata = {}
lap_vibrations = {}
current_lap = 0

with open(jsonl_file, 'r') as f:
    for line in f:
        data = json.loads(line)
        
        if data['type'] == 'lap':
            current_lap = data['lap_index']
            lap_metadata[current_lap] = data
            lap_vibrations[current_lap] = []
        elif data['type'] == 'record' and 'vibration_g' in data:
            if current_lap in lap_vibrations:
                lap_vibrations[current_lap].append(data['vibration_g'])

# Simulate FIT extraction (speed, duration)
# This would come from fit_tool in Dart
fit_lap_data = {
    0: {'max_speed': 22.37, 'duration': 52.1, 'num_records': 190},
    1: {'max_speed': 22.06, 'duration': 55.9, 'num_records': 209},
    2: {'max_speed': 19.95, 'duration': 72.0, 'num_records': 283},
}

# Merge FIT + JSONL
all_laps = []

for lap_idx in sorted(lap_metadata.keys()):
    meta = lap_metadata[lap_idx]
    fit_data = fit_lap_data.get(lap_idx)
    vib_samples = lap_vibrations.get(lap_idx, [])
    
    if not fit_data:
        print(f"Lap {lap_idx}: Missing FIT data, skipping")
        continue
    
    vib_rms = sum(vib_samples) / len(vib_samples) if vib_samples else 0.0
    
    lap = LapMetrics(
        lap_idx,
        meta['front_psi'],
        meta['rear_psi'],
        fit_data['duration'],
        fit_data['max_speed'],
        vib_rms,
        fit_data['num_records']
    )
    all_laps.append(lap)

print("=== MERGED LAP METRICS (FIT + JSONL) ===\n")
for lap in all_laps:
    print(f"Lap {lap.lap_index}:")
    print(f"  Pressure: {lap.front_psi} PSI (front), {lap.rear_psi} PSI (rear)")
    print(f"  Duration: {lap.duration_s:.1f}s")
    print(f"  Max speed: {lap.max_speed:.2f} km/h (from FIT RECORD messages)")
    print(f"  Vibration RMS: {lap.vibration_rms:.3f}g (from JSONL)")
    print(f"  Data points: {lap.num_records}")
    print()

# Clustering by duration
DURATION_TOLERANCE = 10

clusters = []
for lap in all_laps:
    assigned = False
    
    for cluster in clusters:
        ref = cluster[0]
        avg_duration = sum(m.duration_s for m in cluster) / len(cluster)
        duration_diff = abs(lap.duration_s - avg_duration)
        
        if duration_diff <= DURATION_TOLERANCE:
            cluster.append(lap)
            assigned = True
            break
    
    if not assigned:
        clusters.append([lap])

print(f"=== CLUSTERING RESULTS ===\n")
print(f"Found {len(clusters)} cluster(s)")

def cluster_quality(cluster):
    score = float(len(cluster))
    if len(cluster) >= 2:
        durations = [m.duration_s for m in cluster]
        mean = sum(durations) / len(durations)
        variance = sum((d - mean)**2 for d in durations) / len(durations)
        std = math.sqrt(variance) if variance > 0 else 0
        cv = (std / mean) if mean > 0 else 0
        consistency = 1.0 / (1.0 + cv)
        score = score * consistency
    return score

clusters_sorted = sorted(clusters, key=cluster_quality, reverse=True)

print("\nRanked by quality:\n")
for i, cluster in enumerate(clusters_sorted, 1):
    score = cluster_quality(cluster)
    print(f"Cluster {i}: Quality = {score:.2f}, Laps = {len(cluster)}")
    for lap in cluster:
        print(f"  - {lap.front_psi} PSI: {lap.max_speed:.2f} km/h")

# Select best 3
selected = clusters_sorted[:min(3, len(clusters_sorted))]

print(f"\n=== SELECTED FOR ANALYSIS ===\n")
print(f"Using {len(selected)} best cluster(s)\n")

all_selected = []
for cluster in selected:
    all_selected.extend(cluster)

all_selected.sort(key=lambda x: x.front_psi)

print(f"Combined laps for regression:")
for lap in all_selected:
    efficiency = lap.max_speed / 25.0  # Normalized efficiency
    print(f"  {lap.front_psi} PSI: speed={lap.max_speed:.2f} km/h, efficiency={efficiency:.3f}")

print(f"\n✓ Ready for quadratic regression")
print(f"  X-axis: Pressure (PSI)")
print(f"  Y-axis: Efficiency (normalized speed)")
print(f"  Data points: {len(all_selected)}")
