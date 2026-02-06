import json
from datetime import datetime
import math

# Simulate the NEW clustering approach: 3+ best clusters, raw metrics

jsonl_file = 'test_data/coast_down_20260129_194342.jsonl'

class LapMetrics:
    def __init__(self, lap_index, front_psi, duration_s, max_speed, vibration_rms, num_records):
        self.lap_index = lap_index
        self.front_psi = front_psi
        self.duration_s = duration_s
        self.max_speed = max_speed
        self.vibration_rms = vibration_rms
        self.num_records = num_records

# Parse JSONL
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

# Extract metrics
lap_metrics_list = []

for lap_idx in sorted(lap_metadata.keys()):
    meta = lap_metadata[lap_idx]
    records = lap_records[lap_idx]
    
    if not records:
        continue
    
    # Duration
    ts_records = [r for r in records if 'ts' in r]
    duration = 0.0
    if len(ts_records) >= 2:
        try:
            start_time = datetime.fromisoformat(ts_records[0]['ts'])
            end_time = datetime.fromisoformat(ts_records[-1]['ts'])
            duration = (end_time - start_time).total_seconds()
        except:
            pass
    
    # Max speed
    speed_records = [r for r in records if 'speed_kmh' in r]
    max_speed = max([r['speed_kmh'] for r in speed_records]) if speed_records else 0.0
    
    # Vibration RMS
    vib_samples = [r['vibration_g'] for r in records if 'vibration_g' in r]
    vibration_rms = sum(vib_samples) / len(vib_samples) if vib_samples else 0.0
    
    lap_metrics_list.append(LapMetrics(
        lap_idx,
        meta['front_psi'],
        duration,
        max_speed,
        vibration_rms,
        len(records)
    ))

print("=== EXTRACTED LAP METRICS ===\n")
for lap in lap_metrics_list:
    print(f"Lap {lap.lap_index}: {lap.front_psi} PSI")
    print(f"  Duration: {lap.duration_s:.1f}s")
    print(f"  Max speed: {lap.max_speed:.2f} km/h")
    print(f"  Vibration RMS: {lap.vibration_rms:.3f}g")
    print(f"  Data points: {lap.num_records}")
    print()

# Clustering by duration only (since this test data is all same location)
DURATION_TOLERANCE = 10

clusters = []
for lap in lap_metrics_list:
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

print("=== CLUSTERING RESULTS ===\n")
print(f"Found {len(clusters)} cluster(s)\n")

def cluster_quality_score(cluster):
    """Score cluster by: sample count, duration consistency, etc"""
    score = float(len(cluster))  # More samples = better
    
    if len(cluster) >= 2:
        durations = [m.duration_s for m in cluster]
        mean_duration = sum(durations) / len(durations)
        variance = sum((d - mean_duration)**2 for d in durations) / len(durations)
        std_dev = math.sqrt(variance) if variance > 0 else 0.0
        coeff_variation = (std_dev / mean_duration) if mean_duration > 0 else 0.0
        duration_consistency = 1.0 / (1.0 + coeff_variation)
        score = score * duration_consistency
    
    return score

# Rank clusters by quality
clusters_ranked = sorted(clusters, key=cluster_quality_score, reverse=True)

print(f"Ranked by quality:\n")
for i, cluster in enumerate(clusters_ranked, 1):
    score = cluster_quality_score(cluster)
    print(f"Cluster {i}: Quality score = {score:.2f}")
    print(f"  Laps: {len(cluster)}")
    print(f"  Pressures: {sorted([m.front_psi for m in cluster])}")
    print()

# Select best 3 clusters (or fewer if not available)
min_clusters = 3
selected = clusters_ranked[:min(len(clusters_ranked), min_clusters)]

print(f"=== SELECTED FOR ANALYSIS ===")
print(f"Using {len(selected)} cluster(s) (best of {len(clusters_ranked)} found)\n")

all_selected_laps = []
for cluster in selected:
    all_selected_laps.extend(cluster)

all_selected_laps.sort(key=lambda x: x.front_psi)

print(f"Combined {len(all_selected_laps)} laps:\n")
for lap in all_selected_laps:
    print(f"  {lap.front_psi} PSI: {lap.max_speed:.2f} km/h, {lap.vibration_rms:.3f}g vibration")

print(f"\n✓ Ready for quadratic regression on RAW METRICS (no thresholds)")
print(f"   Y-axis: max_speed (efficiency)")
print(f"   X-axis: pressure")
