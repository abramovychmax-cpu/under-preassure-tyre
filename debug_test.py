#!/usr/bin/env python3
"""
Debug script to test the clustering analysis locally with agr.fit.jsonl
"""
import json
import sys

def main():
    jsonl_path = 'test_data/agr.fit.jsonl'
    
    print("=" * 60)
    print("DEBUG: Loading agr.fit.jsonl")
    print("=" * 60)
    
    lap_metadata = {}
    lap_records = {}
    
    try:
        with open(jsonl_path, 'r') as f:
            lines = f.readlines()
        
        print(f"\n✓ Loaded {len(lines)} lines from JSONL")
        
        # Parse lap metadata and records
        current_lap = 0
        for line_num, line in enumerate(lines):
            try:
                data = json.loads(line)
                
                if data.get('type') == 'lap':
                    lap_idx = data.get('lap_index')
                    current_lap = lap_idx
                    lap_metadata[lap_idx] = data
                    lap_records[lap_idx] = []
                    print(f"  Lap {lap_idx}: {data.get('front_psi')} PSI, "
                          f"rear={data.get('rear_psi')} PSI, "
                          f"ts={data.get('ts')}")
                
                elif data.get('type') == 'record':
                    # Records don't have lap_index, so we track the current lap
                    if current_lap in lap_records:
                        lap_records[current_lap].append(data)
            
            except json.JSONDecodeError:
                pass
        
        print(f"\n✓ Extracted {len(lap_metadata)} laps")
        print(f"✓ Total records: {sum(len(recs) for recs in lap_records.values())}")
        
        # Analyze each lap
        print("\n" + "=" * 60)
        print("LAP ANALYSIS")
        print("=" * 60)
        
        for lap_idx in sorted(lap_metadata.keys()):
            meta = lap_metadata[lap_idx]
            records = lap_records.get(lap_idx, [])
            
            if not records:
                print(f"\nLap {lap_idx}: No records!")
                continue
            
            # Extract speed data
            speeds = [r.get('speed_kmh', 0) for r in records if r.get('speed_kmh')]
            vibrations = [r.get('vibration_g', 0) for r in records if r.get('vibration_g')]
            lats = [r.get('lat') for r in records if r.get('lat')]
            lons = [r.get('lon') for r in records if r.get('lon')]
            
            max_speed = max(speeds) if speeds else 0
            avg_vibration = sum(vibrations) / len(vibrations) if vibrations else 0
            
            print(f"\nLap {lap_idx}:")
            print(f"  Pressure: {meta.get('front_psi')} PSI (front), {meta.get('rear_psi')} PSI (rear)")
            print(f"  Records: {len(records)} points")
            print(f"  Speed range: {min(speeds):.2f} - {max(speeds):.2f} km/h" if speeds else "  Speed: N/A")
            print(f"  Max speed: {max_speed:.2f} km/h")
            print(f"  Vibration (avg): {avg_vibration:.3f}g")
            if lats:
                print(f"  GPS: ({lats[0]:.6f}, {lons[0]:.6f}) to ({lats[-1]:.6f}, {lons[-1]:.6f})")
                # Calculate Haversine distance
                from math import sin, cos, sqrt, atan2, radians
                R = 6371  # km
                lat1, lon1 = radians(lats[0]), radians(lons[0])
                lat2, lon2 = radians(lats[-1]), radians(lons[-1])
                dlat = lat2 - lat1
                dlon = lon2 - lon1
                a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
                c = 2 * atan2(sqrt(a), sqrt(1-a))
                dist_m = R * c * 1000
                print(f"  GPS distance: {dist_m:.1f}m")
        
        # Clustering check
        print("\n" + "=" * 60)
        print("CLUSTERING VALIDATION")
        print("=" * 60)
        
        # Check if all laps are at same location
        all_lats = []
        all_lons = []
        for lap_idx in lap_records:
            records = lap_records[lap_idx]
            for r in records:
                if r.get('lat'):
                    all_lats.append(r['lat'])
                    all_lons.append(r['lon'])
        
        if all_lats:
            lat_min, lat_max = min(all_lats), max(all_lats)
            lon_min, lon_max = min(all_lons), max(all_lons)
            print(f"\nGPS bounds:")
            print(f"  Latitude: {lat_min:.6f} to {lat_max:.6f}")
            print(f"  Longitude: {lon_min:.6f} to {lon_max:.6f}")
            print(f"  Spread: ({lat_max - lat_min:.6f}°, {lon_max - lon_min:.6f}°)")
            
            # All laps should be within ~100m
            from math import sin, cos, sqrt, atan2, radians
            R = 6371
            lat1, lon1 = radians(lat_min), radians(lon_min)
            lat2, lon2 = radians(lat_max), radians(lon_max)
            dlat = lat2 - lat1
            dlon = lon2 - lon1
            a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
            c = 2 * atan2(sqrt(a), sqrt(1-a))
            spread_m = R * c * 1000
            
            print(f"  Max distance: {spread_m:.1f}m")
            if spread_m < 100:
                print(f"  ✓ All laps cluster together (< 100m)")
            else:
                print(f"  ⚠ Laps are spread out (> 100m)")
        
        # Pressure-speed relationship
        print("\n" + "=" * 60)
        print("REGRESSION ANALYSIS")
        print("=" * 60)
        
        pressures = []
        max_speeds = []
        for lap_idx in sorted(lap_metadata.keys()):
            meta = lap_metadata[lap_idx]
            records = lap_records.get(lap_idx, [])
            
            speeds = [r.get('speed_kmh', 0) for r in records if r.get('speed_kmh')]
            if speeds:
                pressures.append(meta.get('front_psi', 0))
                max_speeds.append(max(speeds))
        
        print(f"\nPressure-Speed data:")
        print(f"{'Pressure (PSI)':>15} | {'Max Speed (km/h)':>15} | {'Efficiency':>12}")
        print("-" * 45)
        
        for p, s in zip(pressures, max_speeds):
            efficiency = s / 25.0  # Normalize
            print(f"{p:>15.1f} | {s:>15.2f} | {efficiency:>12.3f}")
        
        if len(pressures) >= 3:
            print(f"\n✓ Sufficient data for quadratic regression ({len(pressures)} points)")
            # Simple quadratic fit hint
            print(f"  Expected: Optimal pressure should be around 55-58 PSI")
        else:
            print(f"\n⚠ Need at least 3 pressure points, have {len(pressures)}")
        
    except FileNotFoundError:
        print(f"❌ ERROR: {jsonl_path} not found!")
        return 1
    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    print("\n" + "=" * 60)
    print("DEBUG COMPLETE")
    print("=" * 60)
    return 0

if __name__ == '__main__':
    sys.exit(main())
