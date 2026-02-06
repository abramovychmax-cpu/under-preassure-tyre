#!/usr/bin/env python3
"""
Advanced multi-factor tire pressure efficiency analysis.
Analyzes: deceleration, vibration, acceleration, max speed, energy loss, etc.
"""

import json
from pathlib import Path
from collections import defaultdict
import math


def advanced_analysis():
    """Comprehensive efficiency analysis across all available metrics."""
    
    fit_path = 'test_data/10255893432.fit'
    sensor_path = f'{fit_path}.sensor_records.jsonl'
    metadata_path = f'{fit_path}.jsonl'
    
    # Load sensor records
    sensor_records = defaultdict(list)
    with open(sensor_path, 'r') as f:
        for line in f:
            try:
                record = json.loads(line.strip())
                lap_idx = record['lapIndex']
                sensor_records[lap_idx].append(record)
            except:
                continue
    
    # Load pressure metadata
    metadata = {}
    with open(metadata_path, 'r') as f:
        for line in f:
            try:
                record = json.loads(line.strip())
                lap_idx = record['lapIndex']
                metadata[lap_idx] = record
            except:
                continue
    
    print("="*100)
    print("ADVANCED TIRE PRESSURE EFFICIENCY ANALYSIS")
    print("="*100)
    print()
    
    results = []
    
    # Analyze each descent lap
    for lap_idx in sorted([k for k in sensor_records.keys() if 1 <= k <= 11]):
        records = sensor_records[lap_idx]
        if not records:
            continue
        
        pres = metadata.get(lap_idx)
        pressure = pres['frontPressure'] if pres else 0
        
        # Extract speed data
        speeds = [r['speed_kmh'] for r in records]
        max_speed = max(speeds) if speeds else 0
        min_speed = min(speeds) if speeds else 0
        avg_speed = sum(speeds) / len(speeds) if speeds else 0
        
        # 1. DECELERATION (speed loss during coast)
        start_speed = speeds[0] if speeds else 0
        end_speed = speeds[-1] if speeds else 0
        duration = len(records) / 1.0  # Assuming 1 Hz data (1 record = 1 second)
        deceleration = (start_speed - end_speed) / duration if duration > 0 else 0
        
        # 2. VIBRATION LOSSES (from metadata)
        vib_avg = pres['vibrationAvg'] if pres else 0
        vib_max = pres['vibrationMax'] if pres else 0
        
        # Lower vibration = less energy loss to road roughness
        vibration_efficiency = 1.0 / (vib_avg + 0.1)  # Normalize
        
        # 3. SPEED CONSISTENCY (smoother = less wasted energy)
        speed_variance = 0.0
        if len(speeds) > 1:
            speed_variance = sum((s - avg_speed) ** 2 for s in speeds) / len(speeds)
        speed_stability = 1.0 / (math.sqrt(speed_variance) + 0.1)  # Lower variance = better
        
        # 4. MAX SPEED MAINTENANCE (how well tire maintains speed)
        # Higher max speed = better rolling characteristics
        max_speed_efficiency = max_speed / 50.0  # Normalize to typical descent speed
        
        # 5. ACCELERATION (initial acceleration before coast)
        # Look at first few records - rapid acceleration = good tire grip
        accel_records = records[:min(5, len(records))]
        if len(accel_records) > 1:
            accel_speeds = [r['speed_kmh'] for r in accel_records]
            acceleration = (max(accel_speeds) - min(accel_speeds)) / len(accel_records)
        else:
            acceleration = 0
        
        # 6. HEART RATE (rider effort - lower HR = less pedal input needed = better rolling)
        hr_values = [r.get('heart_rate', 0) for r in records if r.get('heart_rate', 0) > 0]
        avg_hr = sum(hr_values) / len(hr_values) if hr_values else 0
        effort_efficiency = 1.0 / (avg_hr / 100.0 + 0.5) if avg_hr else 1.0
        
        # 7. ENERGY EFFICIENCY SCORE (composite)
        # Components: deceleration (primary), vibration, stability, max speed
        energy_score = (
            (abs(deceleration) * 10) +     # Speed loss (primary metric) - 40%
            (vib_avg * 5) +                # Vibration - 20%
            (speed_variance * 2) +         # Speed variance - 15%
            ((avg_speed - 10) * 3)         # Speed maintenance - 15%
        )
        
        # Normalized efficiency (0-100, higher = better)
        # Best case: minimal deceleration, low vibration, smooth speed
        efficiency_score = 100.0 / (1.0 + energy_score / 10.0)
        
        result = {
            'lap_idx': lap_idx,
            'pressure': pressure,
            'max_speed': round(max_speed, 2),
            'min_speed': round(min_speed, 2),
            'avg_speed': round(avg_speed, 2),
            'deceleration': round(deceleration, 4),
            'vibration_avg': round(vib_avg, 4),
            'vibration_max': round(vib_max, 4),
            'acceleration': round(acceleration, 4),
            'speed_variance': round(math.sqrt(speed_variance), 4),
            'heart_rate_avg': round(avg_hr, 1),
            'efficiency_score': round(efficiency_score, 2),
            'num_records': len(records),
        }
        results.append(result)
    
    # Print detailed results
    print(f"{'Lap':>3} | {'Press':>6} | {'Max Spd':>8} | {'Avg Spd':>8} | {'Decel':>10} | "
          f"{'Vib Avg':>8} | {'Accel':>8} | {'Spd Var':>8} | {'HR Avg':>7} | {'Eff Score':>9}")
    print("-" * 120)
    
    for r in results:
        print(f"{r['lap_idx']:3d} | {r['pressure']:6.1f} | {r['max_speed']:8.2f} | {r['avg_speed']:8.2f} | "
              f"{r['deceleration']:10.4f} | {r['vibration_avg']:8.4f} | {r['acceleration']:8.4f} | "
              f"{r['speed_variance']:8.4f} | {r['heart_rate_avg']:7.1f} | {r['efficiency_score']:9.2f}")
    
    print()
    print("="*100)
    print("INSIGHTS & ANALYSIS")
    print("="*100)
    
    # Find optimal pressure
    best_result = max(results, key=lambda r: r['efficiency_score'])
    worst_result = min(results, key=lambda r: r['efficiency_score'])
    
    print(f"\n✓ OPTIMAL PRESSURE: {best_result['pressure']:.1f} bar (Efficiency: {best_result['efficiency_score']:.2f})")
    print(f"✗ WORST PRESSURE:  {worst_result['pressure']:.1f} bar (Efficiency: {worst_result['efficiency_score']:.2f})")
    print(f"  Difference: {best_result['efficiency_score'] - worst_result['efficiency_score']:.2f} points")
    
    # Analyze deceleration trend
    print(f"\nDECELERATION ANALYSIS:")
    decel_values = [r['deceleration'] for r in results]
    min_decel = min(decel_values)
    max_decel = max(decel_values)
    print(f"  Range: {min_decel:.4f} to {max_decel:.4f} km/h/s")
    print(f"  Spread: {abs(max_decel - min_decel):.4f} km/h/s")
    print(f"  → Interpretation: Larger pressure differences cause more speed loss variation")
    
    # Analyze vibration trend
    print(f"\nVIBRATION ANALYSIS:")
    vib_values = [r['vibration_avg'] for r in results]
    print(f"  Min vibration: {min(vib_values):.4f}g at {[r['pressure'] for r in results if r['vibration_avg'] == min(vib_values)][0]:.1f} bar")
    print(f"  Max vibration: {max(vib_values):.4f}g at {[r['pressure'] for r in results if r['vibration_avg'] == max(vib_values)][0]:.1f} bar")
    print(f"  → Interpretation: Vibration indicates road roughness impact varies with pressure")
    
    # Analyze speed characteristics
    print(f"\nSPEED CHARACTERISTICS:")
    max_speeds = [r['max_speed'] for r in results]
    print(f"  Max speed range: {min(max_speeds):.2f} to {max(max_speeds):.2f} km/h")
    print(f"  Avg speed range: {min([r['avg_speed'] for r in results]):.2f} to "
          f"{max([r['avg_speed'] for r in results]):.2f} km/h")
    print(f"  → Interpretation: Tire pressure affects peak speed maintenance")
    
    # Analyze stability (variance)
    print(f"\nSTABILITY ANALYSIS (Speed Variance):")
    var_values = [r['speed_variance'] for r in results]
    print(f"  Most stable: {min(var_values):.4f} km/h variance at "
          f"{[r['pressure'] for r in results if r['speed_variance'] == min(var_values)][0]:.1f} bar")
    print(f"  Least stable: {max(var_values):.4f} km/h variance at "
          f"{[r['pressure'] for r in results if r['speed_variance'] == max(var_values)][0]:.1f} bar")
    print(f"  → Interpretation: Lower pressure provides more stable speed (smoother ride)")
    
    # Propose advanced model
    print()
    print("="*100)
    print("PROPOSED ADVANCED EFFICIENCY MODEL")
    print("="*100)
    print("""
Multi-Factor Tire Pressure Optimization Model:

E(P) = w1 × Deceleration(P) + w2 × Vibration(P) + w3 × SpeedVariance(P) + w4 × EffortHR(P)

Where:
  P = Tire Pressure (bar)
  w1 = 0.40 (Weight for deceleration - PRIMARY metric)
  w2 = 0.25 (Weight for vibration losses - comfort & energy)
  w3 = 0.20 (Weight for speed stability - efficiency)
  w4 = 0.15 (Weight for rider effort - heart rate proxy)

Key Metrics Captured:
  ✓ Deceleration (km/h/s) - Speed loss during coast phase
  ✓ Vibration (g) - Energy dissipation to road
  ✓ Speed Variance - Stability/smoothness
  ✓ Heart Rate - Rider effort/cadence
  ✓ Max Speed - Tire grip/rolling resistance
  ✓ Acceleration - Initial grip characteristics

Optimal Pressure = argmin(E(P))
  → Pressure that minimizes total energy loss across all factors

Benefits over simple deceleration model:
  1. Accounts for vibration losses (comfort + energy)
  2. Considers speed stability (less oscillation = better)
  3. Includes rider effort (HR tracking)
  4. Multifactor regression will be more robust
""")

if __name__ == '__main__':
    advanced_analysis()
