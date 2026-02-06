import json

with open('test_data/coast_down_20260129_194342.jsonl', 'r') as f:
    all_speeds = []
    lap_speeds = {}
    current_lap = 0
    
    for line in f:
        data = json.loads(line)
        
        if data['type'] == 'lap':
            current_lap = data['lap_index']
            lap_speeds[current_lap] = []
        elif data['type'] == 'record' and 'speed_kmh' in data:
            speed = data['speed_kmh']
            all_speeds.append(speed)
            lap_speeds[current_lap].append(speed)

print("=== SPEED STATISTICS ===\n")
print(f"Overall stats:")
print(f"  Min speed: {min(all_speeds):.2f} km/h")
print(f"  Max speed: {max(all_speeds):.2f} km/h")
print(f"  Total speed samples: {len(all_speeds)}")

print("\n=== PER-LAP SPEED RANGE ===\n")
for lap_idx in sorted(lap_speeds.keys()):
    speeds = lap_speeds[lap_idx]
    if speeds:
        print(f"Lap {lap_idx}:")
        print(f"  Speed range: {min(speeds):.2f} - {max(speeds):.2f} km/h")
        print(f"  Samples: {len(speeds)}")
        
        # Find when it crosses different thresholds
        for threshold in [5, 10, 15, 18, 20, 22, 25]:
            for i, speed in enumerate(speeds):
                if speed >= threshold:
                    print(f"  Reaches {threshold} km/h at sample {i}")
                    break
        print()
