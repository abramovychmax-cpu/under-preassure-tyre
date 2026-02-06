import 'dart:io';
import 'package:tyre_preassure/fit/writer_impl.dart';

/// Test the fixed writer with proper message sequence
void main() async {
  final outputPath = 'test_fixed_writer.fit';
  final file = File(outputPath);
  final sink = file.openWrite();

  final writer = RealFitWriter(sink, outputPath);
  
  // Write header
  writer.writeFileHeader();

  // Message 1: File ID (GMN 0)
  writer.writeMessage(0, {
    0: 4,      // type = Activity
    1: 1,      // manufacturer
    2: 1,      // product
    4: DateTime.now(),  // time_created
  });

  // Messages 2-3: Record data (GMN 20) - SAME field set
  for (int i = 0; i < 2; i++) {
    writer.writeMessage(20, {
      253: DateTime.now(),  // timestamp
      0: 37.7749 + i * 0.0001,  // position_lat
      1: -122.4194 + i * 0.0001,  // position_long
      3: 25.5 + i * 0.5,  // speed
      4: 85 + i,  // cadence
      6: 100.0 + i * 10,  // distance
      7: 250 + i * 10,  // power
    });
  }

  // Message 4: Activity (GMN 34) - REQUIRED by Strava
  writer.writeMessage(34, {
    254: DateTime.now(),  // timestamp
    0: 600.0,  // total_timer_time
    1: 1,  // num_sessions
    2: 1,  // type: manual
  });

  // Close and finalize
  await writer.finalize();

  // Read and validate
  final bytes = await file.readAsBytes();
  print('Generated test file size: ${bytes.length} bytes');
  
  // Hex dump
  print('\nFirst 160 bytes:');
  for (int i = 0; i < 160 && i < bytes.length; i += 16) {
    final hex = bytes.skip(i).take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final offset = i.toRadixString(16).padLeft(4, '0');
    print('$offset: $hex');
  }
}
