import 'dart:io';
import 'dart:async';
import 'package:tyre_preassure/fit/writer_impl.dart';

/// Test FIT writer and verify the output matches expected structure
Future<void> main() async {
  final testFile = 'dart_test_output.fit';
  final file = File(testFile);
  final sink = file.openWrite();

  final writer = RealFitWriter(sink, testFile);
  
  // Write header
  writer.writeFileHeader();

  // Message 1: File ID (GMN 0)
  final fileIdTime = DateTime.utc(2025, 1, 30, 12, 0, 0);
  writer.writeMessage(0, {
    0: 4,          // type = Activity
    1: 1,          // manufacturer = Garmin
    2: 1,          // product
    254: fileIdTime,  // time_created
  });

  // Message 2: Record data (GMN 20) 
  for (int i = 0; i < 3; i++) {
    writer.writeMessage(20, {
      253: fileIdTime.add(Duration(seconds: i * 5)),  // timestamp
      0: 37.7749,  // position_lat (as degrees, will be converted to semicircles)
      1: -122.4194,  // position_long
      3: 25.5 + i * 0.5,  // speed in m/s
    });
  }

  // Message 3: Activity (GMN 34) - REQUIRED by Strava
  writer.writeMessage(34, {
    254: fileIdTime.add(Duration(minutes: 1)),  // timestamp
    0: 600.0,  // total_timer_time
    1: 1,      // num_sessions
    2: 1,      // type: manual
  });

  // Close and finalize
  await writer.finalize();

  // Verify the file
  final bytes = await file.readAsBytes();
  print('Dart FIT Writer Test');
  print('===================');
  print('Generated file: $testFile');
  print('File size: ${bytes.length} bytes');
  
  // Show header
  print('\nHeader (14 bytes):');
  for (int i = 0; i < 14; i++) {
    print('  Byte ${i.toString().padLeft(2)}: 0x${bytes[i].toRadixString(16).padLeft(2, '0')}');
  }
  
  // Check CRCs
  final headerCrc = bytes[12] | (bytes[13] << 8);
  final fileCrc = bytes[bytes.length - 2] | (bytes[bytes.length - 1] << 8);
  
  print('\nCRCs:');
  print('  Header CRC: 0x${headerCrc.toRadixString(16).padLeft(4, '0')}');
  print('  File CRC: 0x${fileCrc.toRadixString(16).padLeft(4, '0')}');
  
  // Hex dump
  print('\nFull file (hex):');
  for (int i = 0; i < bytes.length; i += 16) {
    final hex = bytes.skip(i).take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final offset = i.toRadixString(16).padLeft(4, '0');
    print('$offset: $hex');
  }
}
