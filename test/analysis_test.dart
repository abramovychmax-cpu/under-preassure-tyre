import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clustering & Analysis Tests', () {
    test('Load and analyze agr.fit + agr.fit.jsonl', () async {
      print('\n=== CLUSTERING ANALYSIS TEST (JSONL-based) ===\n');

      const fitPath = 'test_data/agr.fit';
      const jsonlPath = 'test_data/agr.fit.jsonl';

      // Verify files exist
      expect(File(fitPath).existsSync(), isTrue, reason: 'FIT file should exist');
      expect(File(jsonlPath).existsSync(), isTrue, reason: 'JSONL file should exist');

      // 1. Parse JSONL
      print('1. Reading JSONL file...');
      final jsonlFile = File(jsonlPath);
      final lines = await jsonlFile.readAsLines();

      print('   ✓ Read ${lines.length} JSON lines');
      expect(lines, isNotEmpty, reason: 'JSONL should have data');

      // 2. Extract lap metadata and records from JSONL
      print('\n2. Extracting lap data...');
      final lapMetadata = <int, Map<String, dynamic>>{};
      final lapRecords = <int, List<Map<String, dynamic>>>{};
      int currentLap = -1;
      
      for (final line in lines) {
        try {
          final data = jsonDecode(line) as Map<String, dynamic>;
          if (data['type'] == 'lap') {
            final lapIdx = data['lap_index'] as int;
            lapMetadata[lapIdx] = data;
            currentLap = lapIdx;
            if (!lapRecords.containsKey(currentLap)) {
              lapRecords[currentLap] = [];
            }
          } else if (data['type'] == 'record' && currentLap >= 0) {
            lapRecords[currentLap]!.add(data);
          }
        } catch (e) {
          // Skip malformed lines
        }
      }

      print('   ✓ Found ${lapMetadata.length} lap metadata entries');
      expect(lapMetadata.length, greaterThanOrEqualTo(3), reason: 'Should have at least 3 laps');

      // 3. Build metrics from JSONL
      print('\n3. Building metrics from JSONL...');
      final metrics = <double, Map<String, dynamic>>{};

      for (final lapIdx in lapMetadata.keys) {
        final meta = lapMetadata[lapIdx]!;
        final records = lapRecords[lapIdx] ?? [];

        if (records.isEmpty) {
          print('   ⚠ Lap $lapIdx: No records');
          continue;
        }

        final frontPsi = (meta['front_psi'] as num?)?.toDouble() ?? 0.0;
        final rearPsi = (meta['rear_psi'] as num?)?.toDouble() ?? 0.0;
        
        // Calculate average speed from records (in m/s)
        double speedSum = 0.0;
        int speedCount = 0;
        double totalDistance = 0.0;
        int duration = 0;
        
        for (final rec in records) {
          final speed = (rec['speed_kmh'] as num?)?.toDouble() ?? 0.0;
          if (speed > 0) {
            speedSum += speed;
            speedCount++;
          }
          totalDistance = (rec['distance_m'] as num?)?.toDouble() ?? totalDistance;
          duration = (rec['elapsed_time'] as num?)?.toInt() ?? duration;
        }

        final avgSpeedKmh = speedCount > 0 ? speedSum / speedCount : 0.0;

        metrics[frontPsi] = {
          'rear_psi': rearPsi,
          'avg_speed_kmh': avgSpeedKmh,
          'duration_s': duration,
          'distance_m': totalDistance,
        };

        print('   Lap $lapIdx: $frontPsi PSI, Speed: ${avgSpeedKmh.toStringAsFixed(2)} km/h, Duration: ${duration}s');
      }

      expect(metrics.length, greaterThanOrEqualTo(3), reason: 'Should have at least 3 valid metrics');

      // 4. Verify cluster locality (GPS)
      print('\n4. Verifying GPS clustering...');
      
      double? firstLat, firstLon;
      int gpsPointsCount = 0;

      for (final lapIdx in lapRecords.keys) {
        for (final record in lapRecords[lapIdx]!) {
          final lat = record['latitude'] as num?;
          final lon = record['longitude'] as num?;
          
          if (lat != null && lon != null) {
            gpsPointsCount++;
            
            if (firstLat == null) {
              firstLat = lat.toDouble();
              firstLon = lon.toDouble();
              print('   ✓ First GPS point: ($firstLat, $firstLon)');
            }

            // Verify all points are within 1km (realistic descent)
            final dist = _haversineDistance(firstLat!, firstLon, lat.toDouble(), lon.toDouble());
            
            expect(dist, lessThan(1000), reason: 'All GPS points should be within 1km (descent route)');
          }
        }
      }

      print('   ✓ Verified $gpsPointsCount GPS points (all within 1km)');

      // 5. Analyze pressure vs speed relationship
      print('\n5. Analyzing pressure-speed relationship...');

      final pressures = metrics.keys.toList()..sort();
      final speeds = pressures.map((p) => metrics[p]!['avg_speed_kmh'] as double).toList();

      print('   Pressure | Speed');
      print('   ---------|-------');
      for (int i = 0; i < pressures.length; i++) {
        print('   ${pressures[i].toStringAsFixed(1)} PSI | ${speeds[i].toStringAsFixed(2)} km/h');
      }

      // Verify pressure-speed relationship (higher pressure = higher speed)
      final minSpeed = speeds.reduce((a, b) => a < b ? a : b);
      final maxSpeed2 = speeds.reduce((a, b) => a > b ? a : b);
      
      print('\n   Speed range: ${minSpeed.toStringAsFixed(2)} - ${maxSpeed2.toStringAsFixed(2)} km/h');
      print('   Speed delta: ${(maxSpeed2 - minSpeed).toStringAsFixed(2)} km/h');

      expect(maxSpeed2 > minSpeed, isTrue, reason: 'Should have speed variation');

      // 6. Quadratic regression
      print('\n6. Performing quadratic regression...');
      
      final result = _quadraticRegression(pressures, speeds);
      
      expect(result, isNotNull, reason: 'Regression should succeed');

      final a = result!['a'] as double;
      final b = result['b'] as double;
      final c = result['c'] as double;
      final rSquared = result['rSquared'] as double;

      print('   ✓ Equation: y = ${a.toStringAsFixed(8)}x² + ${b.toStringAsFixed(8)}x + ${c.toStringAsFixed(8)}');
      print('   ✓ R²: ${rSquared.toStringAsFixed(4)} (${(rSquared * 100).toStringAsFixed(1)}% of variance explained)');

      expect(rSquared, greaterThan(0.5), reason: 'R² should indicate reasonable fit');

      // 8. Find optimal pressure
      print('\n8. Finding optimal pressure...');

      final optimalPressure = -b / (2 * a);
      final optimalSpeed = a * optimalPressure * optimalPressure + b * optimalPressure + c;

      print('   ✓ Optimal Front Pressure: ${optimalPressure.toStringAsFixed(1)} PSI');
      print('   ✓ Optimal Rear Pressure: ${(optimalPressure * 1.1).toStringAsFixed(1)} PSI');
      print('   ✓ Expected Max Speed: ${optimalSpeed.toStringAsFixed(2)} km/h');

      // Verify optimal is within range
      expect(
        optimalPressure,
        allOf(greaterThan(pressures.first - 5), lessThan(pressures.last + 5)),
        reason: 'Optimal should be near data range',
      );

      print('\n✅ All tests passed! Ready for phone deployment.');
    });
  });
}

// Note: GPS coordinates are stored as decimal degrees in JSONL, no conversion needed

/// Haversine distance in meters
double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // Earth radius in km
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.asin(math.sqrt(a));
  return R * c * 1000; // Convert to meters
}

double _toRadians(double degrees) {
  return degrees * 3.141592653589793 / 180.0;
}

/// Quadratic regression: y = ax² + bx + c
Map<String, double>? _quadraticRegression(List<double> x, List<double> y) {
  final n = x.length;
  if (n < 3) return null;

  double sumX = 0, sumX2 = 0, sumX3 = 0, sumX4 = 0;
  double sumY = 0, sumXY = 0, sumX2Y = 0;

  for (int i = 0; i < n; i++) {
    final xi = x[i];
    final yi = y[i];
    final xi2 = xi * xi;

    sumX += xi;
    sumX2 += xi2;
    sumX3 += xi2 * xi;
    sumX4 += xi2 * xi2;
    sumY += yi;
    sumXY += xi * yi;
    sumX2Y += xi2 * yi;
  }

  final detA = n * (sumX2 * sumX4 - sumX3 * sumX3) -
      sumX * (sumX * sumX4 - sumX3 * sumX2) +
      sumX2 * (sumX * sumX3 - sumX2 * sumX2);

  if (detA.abs() < 1e-10) return null;

  final detA1 = sumY * (sumX2 * sumX4 - sumX3 * sumX3) -
      sumX * (sumXY * sumX4 - sumX3 * sumX2Y) +
      sumX2 * (sumXY * sumX3 - sumX2 * sumX2Y);

  final detA2 = n * (sumXY * sumX4 - sumX3 * sumX2Y) -
      sumY * (sumX * sumX4 - sumX3 * sumX2) +
      sumX2 * (sumX * sumX2Y - sumXY * sumX2);

  final detA3 = n * (sumX2 * sumX2Y - sumX3 * sumXY) -
      sumX * (sumX * sumX2Y - sumX3 * sumY) +
      sumY * (sumX * sumX3 - sumX2 * sumX2);

  final c = detA1 / detA;
  final b = detA2 / detA;
  final a = detA3 / detA;

  // Calculate R²
  double ssRes = 0, ssTot = 0;
  final meanY = sumY / n;
  for (int i = 0; i < n; i++) {
    final yPred = a * x[i] * x[i] + b * x[i] + c;
    ssRes += (y[i] - yPred) * (y[i] - yPred);
    ssTot += (y[i] - meanY) * (y[i] - meanY);
  }

  final rSquared = ssTot > 0 ? 1 - (ssRes / ssTot) : 0.0;

  return {
    'a': a,
    'b': b,
    'c': c,
    'rSquared': rSquared,
  };
}
