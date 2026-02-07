# Perfect Pressure - Mathematical Verification Report

Generated: 2026-02-07

## Summary

This document verifies the mathematical correctness of all three tire pressure optimization protocols implemented in the Perfect Pressure app.

---

## 🔴 CRITICAL ISSUE: Coast-Down CRR Formula is INCORRECT

### Current Implementation (clustering_service.dart:644)

```dart
static double _calculateCRR(double altDrop, double distance) {
  if (distance <= 0) return 0.01;
  return (altDrop / distance).clamp(0.002, 0.020);
}
```

### Problem

**This formula is physically WRONG**. It ignores the change in kinetic energy during the coast-down.

### Correct Physics

During coast-down, energy balance equation:

```
m·g·Δh = CRR·m·g·d + ½m·(v_end² - v_start²) + air_drag_losses
```

Rearranging for CRR:
```
CRR = (Δh - (v_end² - v_start²)/(2g)) / d
```

where:
- `Δh` = altitude drop (meters)
- `v_start` = speed at coast start (m/s)
- `v_end` = speed at coast end (m/s)  
- `g` = 9.81 m/s²
- `d` = distance traveled (meters)

### Why Current Formula Fails

The current formula `CRR ≈ Δh / d` is only valid when `v_start ≈ v_end`, which **NEVER happens in a coast-down**!

Example error magnitude:
- Altitude drop: 50m
- Distance: 1000m
- v_start: 15 m/s (54 km/h)
- v_end: 3 m/s (11 km/h)

**Incorrect CRR** = 50/1000 = 0.050
**Correct CRR** = (50 - (3² - 15²)/(2×9.81))/1000 = (50 - (-10.71))/1000 = **0.0607**

**Error: 21% underestimate!**

### Required Fix

```dart
/// Coefficient of Rolling Resistance from energy balance.
/// CRR = (altitude_drop - ΔKE/mg) / distance
/// where ΔKE = ½m(v_end² - v_start²)
static double _calculateCRR(
  double altDrop, 
  double distance,
  double vStart,  // m/s
  double vEnd,    // m/s
) {
  if (distance <= 0) return 0.01;
  
  const g = 9.81; // m/s²
  
  // Change in kinetic energy per unit mass: Δ(v²/2)
  final deltaKE_per_mass = (vEnd * vEnd - vStart * vStart) / 2.0;
  
  // CRR = (gravitational_drop - kinetic_change/g) / distance
  final crr = (altDrop - deltaKE_per_mass / g) / distance;
  
  return crr.clamp(0.002, 0.020);
}
```

**Call sites need to pass v_start and v_end from DescentSegment.**

---

## ✅ Constant Power Protocol - CORRECT

### Implementation (constant_power_clustering_service.dart:241)

```dart
final efficiency = avgPower > 0 ? avgSpeed / avgPower : 0.0;
```

### Physics Verification

Power equation for cycling:
```
P = (F_rolling + F_drag) · v
P = (CRR·m·g + ½ρ·Cd·A·v²) · v
```

At constant power and low speeds where drag is small:
```
P ≈ CRR·m·g·v
v ≈ P / (CRR·m·g)
```

**Therefore: v/P ∝ 1/CRR**

✅ **Higher efficiency (v/P) = Lower CRR = Better tire pressure**

### Caveats

1. **Assumes constant power** (CV < 10%) - properly validated
2. **Assumes similar speeds** across pressure tests - if speeds vary significantly, air drag differences corrupt results
3. **GPS matching** (±50m) ensures same road segment

**Verdict: Mathematically sound for comparing tire pressures at matched power levels.**

---

## ✅ Circle/Lap Efficiency Protocol (Chung Method) - CORRECT

### Implementation (circle_protocol_service.dart:219)

```dart
final efficiency = avgPower > 0 ? avgSpeed / avgPower : 0.0;
```

### Physics Verification

The Chung method averages power and speed over a complete closed loop:
```
CRR ∝ P_avg / v_avg  (at constant mass, terrain cancels over loop)
```

Efficiency metric:
```
η = v_avg / P_avg  ∝  1 / CRR
```

✅ **Higher efficiency = Lower CRR = Optimal tire pressure**

### Validation Checks

1. **Duration matching** (±10%) - ensures same route
2. **Power stability** (CV < 25%) - ensures steady effort
3. **Complete laps** (≥30 records) - ensures full circuit

**Verdict: Correct implementation of Chung method.**

---

## ⚠️ Quadratic Regression - NEEDS VERIFICATION

### Implementation (tire_optimization_service.dart:123-200)

Fits parabola: `y = a·P² + b·P + c`

Optimal pressure: `P_opt = -b / (2a)`

### Matrix Formulation

For centered data (P_centered = P - mean(P)), the normal equations are:

```
| ΣP⁴   ΣP³   ΣP² | | a |   | ΣP²y |
| ΣP³   ΣP²   ΣP  | | b | = | ΣPy  |
| ΣP²   ΣP    n   | | c |   | Σy   |
```

Since data is centered: ΣP = 0

```
| ΣP⁴   ΣP³   ΣP² | | a |   | ΣP²y |
| ΣP³   ΣP²   0   | | b | = | ΣPy  |
| ΣP²   0     n   | | c |   | Σy   |
```

### Current Determinant Calculation (line 204)

```dart
final det = sumP4 * (sumP2 * n - 0) - sumP3 * (sumP3 * n - 0) +
            sumP2 * (sumP3 * 0 - sumP2 * sumP2);
```

Expanding:
```dart
det = sumP4·sumP2·n - sumP3·sumP3·n - sumP2·sumP2·sumP2
    = n·(sumP4·sumP2 - sumP3²) - (sumP2)³
```

**Correct formula** (3×3 determinant with Sarrus rule):
```
det = sumP4·(sumP2·n - 0) - sumP3·(sumP3·n - 0·sumP2) + sumP2·(sumP3·0 - sumP2·0)
    = sumP4·sumP2·n - sumP3·sumP3·n + 0
    = n·(sumP4·sumP2 - sumP3²)
```

❌ **ERROR FOUND**: Extra term `- (sumP2)³` in implementation!

### Required Fix

```dart
// Correct determinant calculation
final det = n * (sumP4 * sumP2 - sumP3 * sumP3);

if (det.abs() < 1e-10) {
  return OptimizationResult(/* singular matrix error */);
}

// Cramer's rule for a (coefficient of P²)
final detA = sumP2A * (sumP2 * n - 0) - 
             sumPA * (sumP3 * n - 0) + 
             sumA * (sumP3 * 0 - sumP2 * 0);
// Simplifies to:
final detA = n * (sumP2A * sumP2 - sumPA * sumP3);

// Cramer's rule for b (coefficient of P)
final detB = sumP4 * (sumPA * n - sumA * 0) - 
             sumP3 * (sumP2A * n - sumA * 0) + 
             sumP2 * (sumP2A * 0 - sumPA * 0);
// Simplifies to:
final detB = n * (sumP4 * sumPA - sumP3 * sumP2A);

// Cramer's rule for c (constant)
final detC = sumP4 * (sumP2 * sumA - 0 * sumPA) - 
             sumP3 * (sumP3 * sumA - 0 * sumP2A) + 
             sumP2 * (sumP3 * sumPA - sumP2 * sumP2A);
// Simplifies to (this is complex, verify numerically):
final detC = sumA * (sumP4 * sumP2 - sumP3 * sumP3) + 
             sumP2 * (sumP3 * sumPA - sumP2 * sumP2A);
```

**Note**: The R² calculation appears correct.

---

## Action Items

### 🔴 CRITICAL (Must Fix Before Production)

1. **Fix Coast-Down CRR formula** in `clustering_service.dart`
   - Add v_start, v_end parameters to `_calculateCRR()`
   - Extract start/end speeds from DescentSegment
   - Update formula to account for kinetic energy change

### ⚠️ HIGH PRIORITY (Verify and Fix)

2. **Verify Quadratic Regression determinant** in `tire_optimization_service.dart`
   - Check if extra `- (sumP2)³` term causes numerical errors
   - Run test cases with known parabola data
   - Fix if verified incorrect

### ✅ LOW PRIORITY (Optional Improvements)

3. **Add air drag correction** to Constant Power protocol
   - Optional: Estimate Cd·A from rider data
   - Correct for speed differences between runs
   - Only needed if speed varies >10% between pressure tests

---

## Test Cases Required

### Coast-Down CRR Validation

```dart
// Test case: Verify CRR calculation
final testCases = [
  {
    'altDrop': 50.0,      // meters
    'distance': 1000.0,   // meters
    'vStart': 15.0,       // m/s (54 km/h)
    'vEnd': 3.0,          // m/s (11 km/h)
    'expectedCRR': 0.0607, // hand-calculated
  },
  // Add more test cases...
];
```

### Quadratic Regression Validation

```dart
// Test case: Known parabola y = -0.01x² + 0.4x + 2
final testPoints = [
  (pressure: 10.0, efficiency: 4.0),  // -0.01(100) + 4 + 2 = 5.0
  (pressure: 20.0, efficiency: 6.0),  // -0.01(400) + 8 + 2 = 6.0
  (pressure: 30.0, efficiency: 5.0),  // -0.01(900) + 12 + 2 = 5.0
];

final result = TireOptimizationService.fitQuadraticRegression(testPoints);
assert((result.a - (-0.01)).abs() < 0.001);
assert((result.optimalPressure - 20.0).abs() < 0.5);
```

---

## References

1. **Rolling Resistance**: Schwalbe Tire Pressure Guide - CRR physics
2. **Chung Method**: Andrew Coggan's tire pressure optimization protocol
3. **Quadratic Regression**: Numerical Recipes (Press et al.) - Least squares fitting
4. **Coast-Down Energy Balance**: Vehicle dynamics textbooks (Gillespie, Fundamentals of Vehicle Dynamics)

---

**Report prepared by**: AI Code Auditor  
**Verification Status**: ⚠️ CRITICAL ISSUES FOUND - DO NOT DEPLOY WITHOUT FIXES
