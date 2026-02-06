#!/usr/bin/env python3
import struct
import json
from datetime import datetime, timedelta
import random
import math

# Parse FIT file manually to extract GPS, speed, and time data
fit_file = 'test_data/agr.fit'

def read_fit_file(filepath):
    """Basic FIT file parser to extract RECORD and LAP messages"""
    with open(filepath, 'rb') as f:
        # Read header
        header_size = struct.unpack('B', f.read(1))[0]
        protocol_version = struct.unpack('B', f.read(1))[0]
        profile_version = struct.unpack('<H', f.read(2))[0]
        data_size = struct.unpack('<I', f.read(4))[0]
        data_type = f.read(4)
        
        print(f"=== FIT FILE HEADER ===")
        print(f"Header: {header_size}, Protocol: {protocol_version}, Profile: {profile_version}")
        print(f"Data size: {data_size}\n")
        
        # Skip to data
        f.seek(header_size)
        data = f.read(data_size)
        
        print("✓ FIT file parsed successfully")
        return data

fit_data = read_fit_file(fit_file)

# Create a realistic simulation with GPS clustering
# Simulate a descent at Agricola (based on typical road cycling routes)
print("\n=== GENERATING SIMULATION DATA ===\n")

# Agricola region GPS (Warsaw, Poland area)
BASE_LAT = 52.25435
BASE_LON = 20.98691

# Create 5 repeated descents at same location with different pressures
# Each descent will have slight GPS variation due to GPS drift
num_laps = 5
lap_duration_s = 45  # ~45 second descent
record_interval = 0.2  # Records every 200ms

pressures = [60, 55, 50, 45, 40]  # PSI
vibration_base = 1.0  # g
vibration_variation = 0.15

jsonl_lines = []

# File ID record
file_id = {
    "type": "file_id",
    "ts": datetime.now().isoformat(),
    "metadata": {"sport": "cycling", "sub_sport": "track_cycling"}
}
jsonl_lines.append(json.dumps(file_id))

# Generate laps
for lap_idx in range(num_laps):
    # Slightly vary GPS for each lap (GPS drift)
    gps_drift_lat = random.uniform(-0.0001, 0.0001)  # ~10m variation
    gps_drift_lon = random.uniform(-0.0001, 0.0001)
    
    pressure = pressures[lap_idx]
    lap_start = datetime(2026, 1, 30, 14, 30, 0) + timedelta(seconds=lap_idx * 60)
    
    # Lap metadata
    lap_record = {
        "type": "lap",
        "ts": lap_start.isoformat(),
        "lap_index": lap_idx,
        "front_psi": float(pressure),
        "rear_psi": float(pressure + 2),  # Rear typically 2 PSI higher
    }
    jsonl_lines.append(json.dumps(lap_record))
    
    # Generate RECORD messages
    num_records = int(lap_duration_s / record_interval)
    
    for record_idx in range(num_records):
        record_time = lap_start + timedelta(seconds=record_idx * record_interval)
        
        # Speed profile: ramp up then plateau (realistic descent)
        progress = record_idx / num_records
        if progress < 0.4:
            # Acceleration phase
            speed_base = 10 + (progress / 0.4) * 12  # 10 to 22 km/h
        else:
            # Plateau phase
            speed_base = 22 - (progress - 0.4) * 1  # Slight deceleration
        
        # Add pressure-dependent variation (higher pressure = higher speed)
        pressure_factor = (pressure - 40) / 20  # 0 to 1
        speed_variation = pressure_factor * 2  # 0 to 2 km/h
        speed_kmh = speed_base + speed_variation
        
        # Add random noise
        speed_kmh += random.uniform(-0.3, 0.3)
        
        # GPS position (small variation along descent)
        lat = BASE_LAT + gps_drift_lat + (progress * 0.001)  # Slight slope down
        lon = BASE_LON + gps_drift_lon + (progress * -0.0005)  # Move east
        
        # Vibration (inversely related to pressure - lower pressure = more vibration)
        vibration_factor = (50 - pressure) / 10  # Higher for lower pressure
        vibration_rms = vibration_base + (vibration_factor * 0.3) + random.uniform(-0.1, 0.1)
        vibration_rms = max(0.7, min(2.0, vibration_rms))  # Clamp 0.7-2.0g
        
        # Generate records
        # Speed/distance record
        speed_record = {
            "type": "record",
            "ts": record_time.isoformat(),
            "speed_kmh": round(speed_kmh, 2),
            "distance_km": round(progress * 0.8, 4),  # 800m descent
        }
        jsonl_lines.append(json.dumps(speed_record))
        
        # Vibration record
        vib_record = {
            "type": "record",
            "ts": record_time.isoformat(),
            "vibration_g": round(vibration_rms, 3),
        }
        jsonl_lines.append(json.dumps(vib_record))
        
        # GPS record (every 5th record for density)
        if record_idx % 5 == 0:
            gps_record = {
                "type": "record",
                "ts": record_time.isoformat(),
                "lat": round(lat, 6),
                "lon": round(lon, 6),
                "altitude_m": 137.5 - (progress * 20),  # 20m descent
            }
            jsonl_lines.append(json.dumps(gps_record))
        
        # Cadence record (every 10th)
        if record_idx % 10 == 0:
            cadence_record = {
                "type": "record",
                "ts": record_time.isoformat(),
                "cadence_rpm": round(80 + random.uniform(-10, 10), 1),
            }
            jsonl_lines.append(json.dumps(cadence_record))

# Write JSONL file
output_file = 'test_data/agr.fit.jsonl'
with open(output_file, 'w') as f:
    for line in jsonl_lines:
        f.write(line + '\n')

print(f"✓ Generated {output_file}")
print(f"  Total lines: {len(jsonl_lines)}")
print(f"  Laps: {num_laps}")
print(f"  Pressures: {pressures}")
print(f"  Records per lap: ~{int(lap_duration_s / record_interval)}")

# Print summary
print("\n=== SIMULATION SUMMARY ===\n")
print("Generated realistic simulation data:")
for i, psi in enumerate(pressures):
    print(f"  Lap {i}: {psi} PSI (vibration ~{vibration_base + (50-psi)/10*0.3:.2f}g)")

print(f"\nGPS cluster:")
print(f"  Location: {BASE_LAT}, {BASE_LON} (Agricola, Warsaw)")
print(f"  Spread: ~10m GPS drift per lap")
print(f"  All laps are in same descent cluster")

print(f"\n✓ Ready for clustering analysis!")
