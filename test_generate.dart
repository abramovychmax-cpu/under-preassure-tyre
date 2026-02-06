import 'dart:io';
import 'package:tyre_preassure/fit/writer_impl.dart';

/// Quick test to generate a FIT file with actual messages
void main() async {
  final outputPath = 'test_output_new.fit';
  final file = File(outputPath);
  final sink = file.openWrite();

  final writer = RealFitWriter(sink, outputPath);
  
  // Write header
  writer.writeFileHeader();

  // Write a File ID message (GMN 0)
  writer.writeMessage(0, {
    0: 4,      // type = Activity
    1: 1,      // manufacturer
    2: 1,      // product
    3: 12345,  // serial_number
    4: DateTime.now(),  // time_created
  });

  // Write a Record message (GMN 20) with sensor data
  writer.writeMessage(20, {
    253: DateTime.now(),  // timestamp
    0: 37.7749,  // position_lat
    1: -122.4194,  // position_long
    78: 100.0,  // distance
    3: 25.5,  // speed
    7: 250,  // power
    4: 85,  // cadence
  });

  // Write another record
  writer.writeMessage(20, {
    253: DateTime.now(),  // timestamp
    0: 37.7750,  // position_lat
    1: -122.4195,  // position_long
    78: 110.0,  // distance
    3: 26.0,  // speed
    7: 260,  // power
    4: 86,  // cadence
  });

  // Write a Lap message (GMN 19)
  writer.writeMessage(19, {
    253: DateTime.now(),  // timestamp
    254: DateTime.now(),  // start_time
    9: 1000.0,  // total_distance
    7: 300,  // total_elapsed_time
    14: 20.0,  // avg_speed
    5: 35.0,  // max_speed
    20: 200,  // avg_power
    21: 300,  // max_power
    23: 80,  // avg_cadence
    24: 120,  // max_cadence
  });

  // Write Session message (GMN 18)
  writer.writeMessage(18, {
    253: DateTime.now(),  // timestamp
    254: DateTime.now(),  // start_time
    7: 300,  // total_elapsed_time
    8: 300,  // total_timer_time
    9: 1000.0,  // total_distance
    10: 300,  // total_cycles
    14: 20.0,  // avg_speed
    5: 35.0,  // max_speed
    20: 200,  // avg_power
    21: 300,  // max_power
    23: 80,  // avg_cadence
  });

  // Close and finalize
  await writer.finalize();

  // Read what was actually written
  final bytes = await file.readAsBytes();
  print('Generated file size: ${bytes.length} bytes');
  print('\nFirst 128 bytes (hex):');
  for (int i = 0; i < 128 && i < bytes.length; i += 16) {
    final hex = bytes.skip(i).take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final offset = i.toRadixString(16).padLeft(4, '0');
    print('$offset: $hex');
  }

  print('\nHeader Analysis:');
  print('  Header Size: ${bytes[0]} (0x${bytes[0].toRadixString(16).padLeft(2, '0')})');
  print('  Proto Ver:   ${bytes[1]} (0x${bytes[1].toRadixString(16).padLeft(2, '0')})');
  print('  Prof Ver:    0x${bytes[2].toRadixString(16).padLeft(2, '0')}${bytes[3].toRadixString(16).padLeft(2, '0')}');
  
  int dataSize = 0;
  for (int i = 0; i < 4; i++) {
    dataSize = (dataSize << 8) | bytes[4 + i];
  }
  print('  Data Size:   $dataSize (0x${dataSize.toRadixString(16)})');
  print('  File Type:   ${String.fromCharCodes(bytes.sublist(8, 12))}');
  
  int headerCrc = (bytes[12] << 8) | bytes[13];
  print('  Header CRC:  0x${headerCrc.toRadixString(16).padLeft(4, '0')}');
  
  int fileCrc = (bytes[bytes.length - 2] << 8) | bytes[bytes.length - 1];
  print('  File CRC (stored):  0x${fileCrc.toRadixString(16).padLeft(4, '0')}');
}

