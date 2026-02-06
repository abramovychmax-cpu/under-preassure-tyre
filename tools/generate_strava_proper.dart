import 'dart:io';
import 'dart:math';
import 'package:fit_tool/fit_tool.dart';

/// Realistic physics-based FIT file generator for Agricola Street
/// Uses Garmin FIT SDK (fit_tool) for proper Strava compatibility

class PhysicsSimulator {
  final double tirePressureBar;
  static const double gravity = 9.81;
  static const double totalMass = 90.0; // kg
  static const double airDensity = 1.225;
  static const double cd = 1.1;
  static const double frontalArea = 0.5;
  
  static const double streetLength = 500.0;
  static const double elevationDrop = 25.0;
  static const double streetGradient = elevationDrop / streetLength;
  late final double streetAngle;
  
  late double crr; // Rolling resistance coefficient
  
  PhysicsSimulator(this.tirePressureBar) {
    streetAngle = atan(streetGradient);
    // Lower pressure = higher rolling resistance
    crr = max(0.003, 0.008 - 0.0006 * (tirePressureBar - 3.0));
  }
  
  double _rollingResistance(double speedMs) {
    final normalForce = totalMass * gravity * cos(streetAngle);
    return crr * normalForce;
  }
  
  double _airDrag(double speedMs) {
    return 0.5 * airDensity * cd * frontalArea * (speedMs * speedMs);
  }
  
  double _gravityComponent() {
    return totalMass * gravity * sin(streetAngle);
  }
  
  List<Map<String, dynamic>> simulateDescent({int durationSeconds = 120}) {
    final data = <Map<String, dynamic>>[];
    var speed = 0.0;
    var position = 0.0;
    const dt = 0.05; // 20 Hz sampling (more data points)
    
    for (var step = 0; step < (durationSeconds / dt).toInt(); step++) {
      final time = step * dt;
      
      final gravityForce = _gravityComponent();
      final rollingForce = _rollingResistance(speed);
      final dragForce = _airDrag(speed);
      
      final brakePosition = streetLength * 0.8;
      double brakeForce = 0;
      if (position >= brakePosition) {
        final brakeIntensity = (position - brakePosition) / (streetLength - brakePosition);
        brakeForce = 400 * brakeIntensity;
      }
      
      final netForce = gravityForce - rollingForce - dragForce - brakeForce;
      final acceleration = netForce / totalMass;
      speed = max(0, speed + acceleration * dt);
      position = min(streetLength, position + speed * dt);
      
      final elevation = 100.0 - (position / streetLength) * elevationDrop;
      var cadence = 0;
      if (speed >= 5) {
        cadence = (30 + (speed - 5) * 2).toInt();
      }
      final power = (speed * brakeForce).toInt();
      
      data.add({
        'time': time,
        'position': position,
        'speed': speed,
        'power': power,
        'elevation': elevation,
        'cadence': min(120, cadence),
      });
      
      if (position >= streetLength && speed < 1.0) break;
    }
    
    return data;
  }
  
  List<Map<String, dynamic>> simulateClimb({int durationSeconds = 180}) {
    final data = <Map<String, dynamic>>[];
    var position = streetLength;
    var speed = 2.0;
    const pedalPower = 300.0; // Watts
    const dt = 0.05; // 20 Hz sampling (more data points)
    final random = Random();
    
    for (var step = 0; step < (durationSeconds / dt).toInt(); step++) {
      final time = step * dt;
      
      final gravityForce = _gravityComponent();
      final rollingForce = _rollingResistance(speed);
      final dragForce = _airDrag(speed);
      
      double pedalForce = 200;
      if (speed > 0.5) {
        pedalForce = pedalPower / speed;
      }
      
      final netForce = pedalForce - gravityForce - rollingForce - dragForce;
      final acceleration = netForce / totalMass;
      speed = max(0.5, speed + acceleration * dt);
      position = max(0, position - speed * dt);
      
      final elevation = 100.0 - (position / streetLength) * elevationDrop;
      var cadence = (85 + random.nextGaussian() * 5).toInt();
      cadence = max(70, min(110, cadence));
      final power = (pedalPower + random.nextGaussian() * 10).toInt();
      
      data.add({
        'time': time,
        'position': position,
        'speed': speed,
        'power': max(0, power),
        'elevation': elevation,
        'cadence': cadence,
      });
      
      if (position <= 0) break;
    }
    
    return data;
  }
}

extension on Random {
  double nextGaussian() {
    double u1, u2, s;
    do {
      u1 = 2.0 * nextDouble() - 1.0;
      u2 = 2.0 * nextDouble() - 1.0;
      s = u1 * u1 + u2 * u2;
    } while (s >= 1.0 || s == 0.0);
    final multiplier = sqrt(-2.0 * log(s) / s);
    return u1 * multiplier;
  }
}

// FIT epoch: Dec 31, 1989 00:00:00 UTC
int dateTimeToFitTime(DateTime dt) {
  const fitEpoch = 631065600; // Seconds from Unix epoch to FIT epoch
  return dt.millisecondsSinceEpoch ~/ 1000 - fitEpoch;
}

Future<void> generateContinuousFIT() async {
  print('=' * 70);
  print('Generating Strava-Compatible FIT File (Garmin SDK)');
  print('=' * 70);
  
  const startLat = 52.2420;
  const startLon = 21.0455;
  const endLat = 52.2370;  // Expanded: 5.6 km route, not 500m
  const endLon = 21.0520;  // Creates visible map trace
  
  final pressures = [(3.5, 1), (4.4, 2), (5.0, 3)];
  
  final builder = FitFileBuilder(autoDefine: true);
  final baseTime = DateTime.now();
  final fitEpochTime = dateTimeToFitTime(baseTime);
  
  var globalTime = 0;
  final allStats = <Map<String, dynamic>>[];
  final allRecords = <RecordMessage>[];
  final allLaps = <LapMessage>[];
  
  for (final (pressureBar, runNum) in pressures) {
    print('\n✓ Run $runNum: ${pressureBar.toStringAsFixed(1)} bar (continuous)');
    
    final sim = PhysicsSimulator(pressureBar);
    final descentData = sim.simulateDescent();
    final climbData = sim.simulateClimb();
    final runData = [...descentData, ...climbData];
    
    final allSpeeds = <double>[];
    final allPowers = <int>[];
    final allElevations = <double>[];
    final allCadences = <int>[];
    final allPositions = <double>[];
    final descentSpeeds = <double>[];
    final climbSpeeds = <double>[];
    final climbPowers = <int>[];
    
    final runStartTime = fitEpochTime + globalTime;
    
    for (var idx = 0; idx < runData.length; idx++) {
      final point = runData[idx];
      final timeOffset = (point['time'] as double).toInt();
      
      final progress = min(1.0, (point['position'] as double) / 500.0);
      // For descent: start → end, for climb: end → start then back to start
      var lat = startLat;
      var lon = startLon;
      
      if (idx < descentData.length) {
        // Descent phase: interpolate from start to end
        lat = startLat + (endLat - startLat) * progress;
        lon = startLon + (endLon - startLon) * progress;
      } else {
        // Climb phase: start from end, go back to start
        final climbProgress = min(1.0, ((point['position'] as double) - 0) / 500.0);
        lat = endLat + (startLat - endLat) * climbProgress;
        lon = endLon + (startLon - endLon) * climbProgress;
      }
      
      final elevation = point['elevation'] as double;
      final speed = point['speed'] as double; // m/s
      final cadence = point['cadence'] as int;
      final power = point['power'] as int;
      
      allSpeeds.add(speed);
      allPowers.add(power);
      allElevations.add(elevation);
      allCadences.add(cadence);
      allPositions.add(point['position'] as double);
      
      if (idx < descentData.length) {
        descentSpeeds.add(speed);
      } else {
        climbSpeeds.add(speed);
        climbPowers.add(power);
      }
      
      // Add record message
      final record = RecordMessage()
        ..timestamp = runStartTime + timeOffset
        ..positionLat = lat * (pow(2, 31) / 180.0)
        ..positionLong = lon * (pow(2, 31) / 180.0)
        ..altitude = elevation
        ..speed = speed
        ..distance = point['position'] as double
        ..cadence = cadence
        ..power = power;
      allRecords.add(record);
      
      // Debug: print first and last GPS coordinates
      if (idx == 0) {
        print('  📍 Start: $lat, $lon');
      }
      if (idx == runData.length - 1) {
        print('  📍 End: $lat, $lon');
      }
    }
    
    // Calculate stats
    final avgSpeed = allSpeeds.isEmpty ? 0.0 : allSpeeds.reduce((a, b) => a + b) / allSpeeds.length;
    final maxSpeed = allSpeeds.isEmpty ? 0.0 : allSpeeds.reduce((a, b) => a > b ? a : b);
    final avgCadence = allCadences.isEmpty ? 0.0 : allCadences.reduce((a, b) => a + b) / allCadences.length;
    final maxCadence = allCadences.isEmpty ? 0.0 : allCadences.reduce((a, b) => a > b ? a : b);
    final avgPower = allPowers.isEmpty ? 0.0 : allPowers.reduce((a, b) => a + b) / allPowers.length;
    final maxPower = allPowers.isEmpty ? 0.0 : allPowers.reduce((a, b) => a > b ? a : b);
    final elevationLoss = allElevations.isEmpty ? 0.0 : (allElevations.reduce((a, b) => a > b ? a : b) - allElevations.reduce((a, b) => a < b ? a : b));
    
    final runDuration = (runData.length * 0.1).toInt();
    final totalDistance = allPositions.isEmpty ? 0.0 : allPositions.reduce((a, b) => a > b ? a : b);
    
    final maxDescent = descentSpeeds.isEmpty ? 0.0 : descentSpeeds.reduce((a, b) => a > b ? a : b);
    final avgDescent = descentSpeeds.isEmpty ? 0.0 : descentSpeeds.reduce((a, b) => a + b) / descentSpeeds.length;
    final avgClimb = climbSpeeds.isEmpty ? 0.0 : climbSpeeds.reduce((a, b) => a + b) / climbSpeeds.length;
    final avgClimbPower = climbPowers.isEmpty ? 0.0 : climbPowers.reduce((a, b) => a + b) / climbPowers.length;
    
    // Add lap message
    final lapTime = runStartTime + runDuration;
    final lap = LapMessage()
      ..timestamp = lapTime
      ..startTime = runStartTime
      ..totalElapsedTime = runDuration.toDouble()
      ..totalDistance = totalDistance
      ..avgSpeed = avgSpeed
      ..maxSpeed = maxSpeed
      ..avgCadence = avgCadence.toInt()
      ..maxCadence = maxCadence.toInt()
      ..avgPower = avgPower.toInt()
      ..maxPower = maxPower.toInt()
      ..totalDescent = elevationLoss.toInt()
      ..sport = Sport.cycling;
    allLaps.add(lap);
    
    print('  ⬇️ Descent: ${(maxDescent * 3.6).toStringAsFixed(1)} km/h max, ${(avgDescent * 3.6).toStringAsFixed(1)} km/h avg');
    print('  ⬆️ Climb: ${(avgClimb * 3.6).toStringAsFixed(1)} km/h, ${avgClimbPower.toStringAsFixed(0)}W');
    
    allStats.add({
      'pressure': pressureBar,
      'maxDescent': maxDescent * 3.6,
      'avgDescent': avgDescent * 3.6,
    });
    
    globalTime += runDuration + 1;
  }
  
  // Build FIT file with proper message order
  builder.add(FileIdMessage()
    ..type = FileType.activity
    ..manufacturer = 1 // Garmin
    ..product = 0
    ..serialNumber = 12345
    ..timeCreated = dateTimeToFitTime(baseTime));
  
  builder.addAll(allRecords);
  builder.addAll(allLaps);
  
  // Add session
  final sessionTime = fitEpochTime + globalTime;
  builder.add(SessionMessage()
    ..timestamp = sessionTime
    ..startTime = fitEpochTime
    ..totalElapsedTime = globalTime.toDouble()
    ..totalDistance = 500.0 * 3
    ..avgSpeed = 10.0
    ..maxSpeed = 37.0
    ..sport = Sport.cycling);
  
  // Add activity (wrapper)
  builder.add(ActivityMessage()
    ..timestamp = sessionTime
    ..numSessions = 1
    ..type = Activity.manual);
  
  // Write FIT file
  final outputDir = Directory('assets/simulations');
  await outputDir.create(recursive: true);
  
  final fitBytes = builder.build().toBytes();
  final fitFile = File('${outputDir.path}/agricola_strava_proper.fit');
  await fitFile.writeAsBytes(fitBytes);
  
  print('\n✅ FIT File: ${fitFile.path}');
  print('   Size: ${fitBytes.length} bytes');
  print('\n📊 Pressure Effect (Descent Speed):');
  for (final stat in allStats) {
    print('   ${(stat['pressure'] as double).toStringAsFixed(1)} bar: ${(stat['maxDescent'] as double).toStringAsFixed(1)} km/h max');
  }
  print('\n✅ Strava-ready! (Generated with Garmin FIT SDK)');
  print('=' * 70);
}

void main() async {
  await generateContinuousFIT();
}
