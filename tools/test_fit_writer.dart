import 'dart:io';
import 'package:tyre_preassure/fit_writer.dart';

/// Test script to generate a minimal valid FIT file
void main() async {
  print('Creating minimal test FIT file...');

  final writer = await FitWriter.create(protocol: 'minimal_test');
  await writer.startSession({'test': true});

  // Write just one record
  await writer.writeRecord({
    'lat': 37.7749,
    'lon': -122.4194,
    'speed_kmh': 25.0,
    'power': 200,
    'cadence': 90,
    'distance': 100.0,
  });

  // Write a lap
  await writer.writeLap(85.0, 88.0, lapIndex: 1);

  // Finish session
  await writer.finish();

  print('Test FIT file created at: ${writer.fitPath}');
  print('File size: ${await File(writer.fitPath).length()} bytes');
}

