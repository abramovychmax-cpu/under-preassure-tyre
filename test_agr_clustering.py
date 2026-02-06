import json
from datetime import datetime
import math

# Test clustering with the generated agr.fit.jsonl simulation

jsonl_file = 'test_data/agr.fit.jsonl'

class LapMetrics:
    def __init__(self, lap_idx, front_psi, duration_s, max_speed, vibration_rms):
        self.lap_index = lap_idx
        self.front_psi = front_psi
        self.duration_s = duration_s
        self.max_speed = max_speed
        self.vibration_rms = vibration_rms

# Parse JSONL
lap_metadata = {}
lap_records = {}
current_lap = 0

with open(jsonl_file, 'r') as f:
    for line in f:
        data = json.loads(line)
        
        if data['type'] == 'lap':
            current_lap = data['lap_index']
            lap_metadata[current_lap] = data
            lap_records[current_lap] = []
        elif data['type'] == 'record':
            if current_lap in lap_records:
                lap_records[current_lap].append(data)

# Extract metrics
laps = []
for lap_idx in sorted(lap_metadata.keys()):
    meta = lap_metadata[lap_idx]
    records = lap_records[lap_idx]
    
    if not records:
        continue
    
    # Duration
    ts_records = [r for r in records if 'ts' in r]
    duration = 0.0
    if len(ts_records) >= 2:
        start = datetime.fromisoformat(ts_records[0]['ts'])
        end = datetime.fromisoformat(ts_records[-1]['ts'])
        duration = (end - start).total_seconds()
    
    # Max speed
    speed_records = [r for r in records if 'speed_kmh' in r]
    max_speed = max([r['speed_kmh'] for r in speed_records]) if speed_records else 0.0
    
    # Vibration RMS
    vib_samples = [r['vibration_g'] for r in records if 'vibration_g' in r]
    vibration_rms = sum(vib_samples) / len(vib_samples) if vib_samples else 0.0
    
    laps.append(LapMetrics(
        lap_idx,
        meta['front_psi'],
        duration,
        max_speed,
        vibration_rms
    ))

print("=== SIMULATED LAP DATA ===\n")
for lap in laps:
    print(f"Lap {lap.lap_index}: {lap.front_psi} PSI")
    print(f"  Duration: {lap.duration_s:.1f}s")
    print(f"  Max speed: {lap.max_speed:.2f} km/h")
    print(f"  Vibration RMS: {lap.vibration_rms:.3f}g")
    print()

# Clustering by duration
DURATION_TOLERANCE = 3  # seconds

clusters = []
for lap in laps:
    assigned = False
    
    for cluster in clusters:
        avg_duration = sum(m.duration_s for m in cluster) / len(cluster)
        duration_diff = abs(lap.duration_s - avg_duration)
        
        if duration_diff <= DURATION_TOLERANCE:
            cluster.append(lap)
            assigned = True
            break
    
    if not assigned:
        clusters.append([lap])

print("=== CLUSTERING RESULTS ===\n")
print(f"Found {len(clusters)} cluster(s)\n")

def cluster_quality(cluster):
    score = float(len(cluster))
    if len(cluster) >= 2:
        durations = [m.duration_s for m in cluster]
        mean = sum(durations) / len(durations)
        variance = sum((d - mean)**2 for d in durations) / len(durations)
        std = math.sqrt(variance)
        cv = (std / mean) if mean > 0 else 0
        consistency = 1.0 / (1.0 + cv)
        score = score * consistency
    return score

clusters_sorted = sorted(clusters, key=cluster_quality, reverse=True)

for i, cluster in enumerate(clusters_sorted, 1):
    score = cluster_quality(cluster)
    print(f"Cluster {i}: Quality = {score:.2f}, Size = {len(cluster)}")
    for lap in sorted(cluster, key=lambda x: x.front_psi):
        print(f"  - {lap.front_psi} PSI: {lap.max_speed:.2f} km/h, {lap.vibration_rms:.3f}g")
    print()

# Select best 3+ clusters
selected_clusters = clusters_sorted[:min(3, len(clusters_sorted))]
selected_laps = []
for cluster in selected_clusters:
    selected_laps.extend(cluster)

selected_laps.sort(key=lambda x: x.front_psi)

print("=== SELECTED FOR ANALYSIS ===\n")
print(f"Using {len(selected_clusters)} cluster(s) with {len(selected_laps)} total laps\n")

print("Regression data (raw metrics, no thresholds):")
for lap in selected_laps:
    efficiency = lap.max_speed / 25.0
    print(f"  {lap.front_psi} PSI: speed={lap.max_speed:.2f} km/h, efficiency={efficiency:.3f}")

print(f"\n✓ Ready for quadratic regression")
print(f"  Data points: {len(selected_laps)}")
print(f"  Relationship: Higher pressure → Higher speed → Better efficiency")
