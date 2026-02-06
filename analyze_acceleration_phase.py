#!/usr/bin/env python3
"""
Tire Pressure Optimization Analysis - Acceleration Phase Method
Uses gravity acceleration phase (cadence=0) with 95% v_peak threshold
"""

import json
from pathlib import Path
from collections import defaultdict
import math


def analyze_with_acceleration_phase():
    """Analyze using acceleration phase (0 → 95% v_peak)."""
    
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
    print("ACCELERATION PHASE ANALYSIS (0 → 95% v_peak)")
    print("="*100)
    print()
    
    results = []
    
    # First pass: find all v_peaks to calculate threshold
    v_peaks = []
    for lap_idx in sorted([k for k in sensor_records.keys() if 1 <= k <= 11]):
        records = sensor_records[lap_idx]
        if records:
            speeds = [r['speed_kmh'] for r in records]
            v_peak = max(speeds)
            v_peaks.append(v_peak)
    
    min_v_peak = min(v_peaks)
    threshold_speed = 0.95 * min_v_peak
    
    print(f"V_peak values: {[f'{v:.2f}' for v in v_peaks]}")
    print(f"Min v_peak: {min_v_peak:.2f} km/h")
    print(f"Acceleration threshold (95%): {threshold_speed:.2f} km/h")
    print()
    
    # Second pass: extract acceleration phase for each lap
    print(f"{'Lap':>3} | {'Press':>6} | {'V_peak':>8} | {'Accel':>8} | {'Notes':>40}")
    print("-" * 100)
    
    for lap_idx in sorted([k for k in sensor_records.keys() if 1 <= k <= 11]):
        records = sensor_records[lap_idx]
        if not records:
            continue
        
        pres = metadata.get(lap_idx)
        pressure = pres['frontPressure'] if pres else 0
        
        # Extract acceleration phase: cadence=0 until speed reaches threshold
        accel_records = []
        for record in records:
            if record['cadence'] == 0.0 and record['speed_kmh'] <= threshold_speed:
                accel_records.append(record)
            elif record['speed_kmh'] > threshold_speed:
                break
        
        if not accel_records:
            print(f"{lap_idx:3d} | {pressure:6.1f} | {'ERROR':>8} | {'---':>8} | No acceleration phase found")
            continue
        
        # Calculate acceleration
        speeds = [r['speed_kmh'] for r in accel_records]
        v_peak = max(speeds)
        v_start = speeds[0]
        v_end = speeds[-1]
        
        # Duration in seconds (assuming 1 Hz data)
        duration = len(accel_records) / 1.0
        
        # Acceleration = Δspeed / Δtime
        acceleration = (v_end - v_start) / duration
        
        # Store for regression
        result = {
            'lap_idx': lap_idx,
            'pressure': pressure,
            'v_peak': v_peak,
            'v_start': v_start,
            'v_end': v_end,
            'acceleration': acceleration,
            'duration': duration,
            'num_records': len(accel_records),
        }
        results.append(result)
        
        status = "✓ OK" if len(accel_records) > 10 else "⚠ SHORT"
        print(f"{lap_idx:3d} | {pressure:6.1f} | {v_peak:8.2f} | {acceleration:8.4f} | {status}")
    
    print()
    print("="*100)
    print("QUADRATIC REGRESSION: Acceleration(P) = a·P² + b·P + c")
    print("="*100)
    print()
    
    # Prepare data for regression
    pressures = [r['pressure'] for r in results]
    accelerations = [r['acceleration'] for r in results]
    
    # Center the pressure data to improve numerical stability
    p_mean = sum(pressures) / len(pressures)
    p_centered = [p - p_mean for p in pressures]
    
    # Fit quadratic: a(p-p_mean)^2 + b(p-p_mean) + c
    n = len(pressures)
    sum_p2 = sum(pc**2 for pc in p_centered)
    sum_p3 = sum(pc**3 for pc in p_centered)
    sum_p4 = sum(pc**4 for pc in p_centered)
    sum_p = sum(p_centered)
    sum_p_a = sum(pc*a for pc, a in zip(p_centered, accelerations))
    sum_p2_a = sum(pc**2*a for pc, a in zip(p_centered, accelerations))
    sum_a = sum(accelerations)
    
    # System: [sum_p4  sum_p3   sum_p2 ] [a]   [sum_p2_a]
    #         [sum_p3  sum_p2   sum_p  ] [b] = [sum_p_a ]
    #         [sum_p2  sum_p    n      ] [c]   [sum_a   ]
    
    # Determinant
    det = (sum_p4*(sum_p2*n - sum_p*sum_p) - sum_p3*(sum_p3*n - sum_p*sum_p2) + sum_p2*(sum_p3*sum_p - sum_p2*sum_p2))
    
    # Solve for coefficients
    det_a = (sum_p2_a*(sum_p2*n - sum_p*sum_p) - sum_p_a*(sum_p3*n - sum_p*sum_p2) + sum_a*(sum_p3*sum_p - sum_p2*sum_p2))
    det_b = (sum_p4*(sum_p_a*n - sum_a*sum_p2) - sum_p3*(sum_p2_a*n - sum_a*sum_p2) + sum_p2*(sum_p2_a*sum_p - sum_p_a*sum_p2))
    det_c = (sum_p4*(sum_p2*sum_a - sum_p*sum_p_a) - sum_p3*(sum_p2*sum_p_a - sum_p*sum_p2_a) + sum_p2*(sum_p3*sum_a - sum_p*sum_p_a))
    
    a = det_a / det if det != 0 else 0
    b = det_b / det if det != 0 else 0
    c = det_c / det if det != 0 else 0
    
    print(f"Fitted curve (centered at P={p_mean:.2f}): a={a:.6f}, b={b:.6f}, c={c:.6f}")
    print()
    
    # Vertex of parabola in centered coords: p_opt = -b/(2a)
    # Then convert back: P_opt = p_opt + p_mean
    if a != 0:
        p_opt_centered = -b / (2 * a)
        p_optimal = p_opt_centered + p_mean
        a_optimal = a * p_opt_centered**2 + b * p_opt_centered + c
        print(f"Optimal Pressure: {p_optimal:.2f} bar")
        print(f"Max Acceleration at optimal: {a_optimal:.6f} km/h/s")
    else:
        print("ERROR: Cannot find vertex (a=0)")
        p_optimal = None
    
    print()
    print(f"{'Lap':>3} | {'Press':>6} | {'Accel':>10} | {'Fitted':>10} | {'Error':>10}")
    print("-" * 60)
    
    errors = []
    for r in results:
        p = r['pressure']
        a_measured = r['acceleration']
        # Evaluate fitted curve at this pressure
        p_c = p - p_mean
        a_fitted = a * p_c**2 + b * p_c + c
        error = abs(a_measured - a_fitted)
        errors.append(error)
        
        print(f"{r['lap_idx']:3d} | {p:6.1f} | {a_measured:10.6f} | {a_fitted:10.6f} | {error:10.6f}")
    
    print()
    rmse = math.sqrt(sum(e**2 for e in errors) / len(errors))
    mean_a = sum(accelerations) / len(accelerations)
    ss_tot = sum((a - mean_a)**2 for a in accelerations)
    ss_res = sum(e**2 for e in errors)
    r_squared = 1 - (ss_res / ss_tot) if ss_tot != 0 else 0
    
    print(f"RMSE: {rmse:.6f}")
    print(f"R²: {r_squared:.4f}")
    
    print()
    print("="*100)
    print("INTERPRETATION")
    print("="*100)
    print(f"""
The acceleration phase reveals tire pressure effects on rolling resistance:

• Higher acceleration → Lower rolling resistance (easier to accelerate)
• Lower acceleration → Higher rolling resistance (harder to accelerate)

Optimal Pressure: {p_optimal:.2f} bar
  → Minimizes rolling resistance
  → Provides maximum acceleration from gravity

Physics:
  a(P) = g·sin(θ) - CRR(P)·g·cos(θ)
  
  Where CRR is minimum at P_optimal
  → Maximum net acceleration occurs there
""")

if __name__ == '__main__':
    analyze_with_acceleration_phase()
