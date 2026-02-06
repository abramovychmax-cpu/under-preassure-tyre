import 'dart:io';
import 'package:tyre_preassure/fit/protocol.dart';

/// Create the ABSOLUTE MINIMUM valid FIT file for Strava
/// Based on FIT spec: just FileID + Activity required
void main() async {
  final outputPath = 'test_minimal.fit';
  final buffer = <int>[];

  // HEADER (14 bytes)
  buffer.add(14);                      // Header size
  buffer.add(0x20);                    // Protocol 2.0
  buffer.addAll([0x08, 0x73]);         // Profile version 2163 (0x0873)
  // Data size placeholder (will update)
  buffer.addAll([0x00, 0x00, 0x00, 0x00]);
  buffer.addAll('.FIT'.codeUnits);     // Data type
  // Header CRC placeholder
  buffer.addAll([0x00, 0x00]);

  // Now collect all message data
  final msgData = <int>[];

  // MESSAGE 1: FileID definition (GMN=0, LMT=0)
  msgData.add(0x40);                   // DEF, LMT=0
  msgData.add(0x00);                   // Reserved
  msgData.add(0x01);                   // Architecture (Big Endian)
  msgData.addAll([0x00, 0x00]);        // GMN = 0 (FileID)
  msgData.add(0x04);                   // Number of fields
  
  // Field definitions
  msgData.add(0x00); msgData.add(0x01); msgData.add(0x00); // Field 0: 1 byte, type enum
  msgData.add(0x01); msgData.add(0x02); msgData.add(0x84); // Field 1: 2 bytes, type uint16
  msgData.add(0x02); msgData.add(0x02); msgData.add(0x84); // Field 2: 2 bytes, type uint16
  msgData.add(0x04); msgData.add(0x04); msgData.add(0x86); // Field 4: 4 bytes, type uint32

  // MESSAGE 1: FileID data (LMT=0)
  msgData.add(0x00);                   // LMT=0
  msgData.add(0x04);                   // Field 0: type = Activity
  msgData.addAll([0x00, 0x01]);        // Field 1: manufacturer = 1
  msgData.addAll([0x00, 0x01]);        // Field 2: product = 1
  msgData.addAll([0x00, 0x00, 0x30, 0x39]); // Field 4: timestamp (FIT epoch)

  // MESSAGE 2: Activity definition (GMN=34, LMT=1)
  msgData.add(0x41);                   // DEF, LMT=1
  msgData.add(0x00);                   // Reserved
  msgData.add(0x01);                   // Architecture (Big Endian)
  msgData.addAll([0x00, 0x22]);        // GMN = 34 (Activity)
  msgData.add(0x02);                   // Number of fields

  // Field definitions
  msgData.add(0xFE); msgData.add(0x04); msgData.add(0x86); // Field 254: 4 bytes, type uint32
  msgData.add(0x00); msgData.add(0x01); msgData.add(0x00); // Field 0: 1 byte, type enum

  // MESSAGE 2: Activity data (LMT=1)
  msgData.add(0x01);                   // LMT=1
  msgData.addAll([0x00, 0x00, 0x30, 0x39]); // Field 254: timestamp
  msgData.add(0x00);                   // Field 0: type = manual

  // Update data size in header
  final dataSize = msgData.length;
  buffer[4] = (dataSize >> 24) & 0xFF;
  buffer[5] = (dataSize >> 16) & 0xFF;
  buffer[6] = (dataSize >> 8) & 0xFF;
  buffer[7] = dataSize & 0xFF;

  // Calculate header CRC (stored in LITTLE ENDIAN as per Garmin spec)
  final headerForCrc = buffer.sublist(0, 12);
  int headerCrc = FitProtocol.crc16Ccitt(headerForCrc);
  buffer[12] = headerCrc & 0xFF;         // Low byte first (little-endian)
  buffer[13] = (headerCrc >> 8) & 0xFF;  // High byte second

  // Combine header + data
  final fullFile = buffer + msgData;

  // Calculate file CRC (stored in LITTLE ENDIAN as per Garmin spec)
  int fileCrc = FitProtocol.crc16Ccitt(fullFile);
  fullFile.add(fileCrc & 0xFF);         // Low byte first (little-endian)
  fullFile.add((fileCrc >> 8) & 0xFF);  // High byte second

  // Write to file
  final file = File(outputPath);
  await file.writeAsBytes(fullFile);

  print('Generated minimal FIT file: $outputPath');
  print('File size: ${fullFile.length} bytes');
  print('Data section: $dataSize bytes');
  print('Header CRC: 0x${headerCrc.toRadixString(16).padLeft(4, '0')}');
  print('File CRC: 0x${fileCrc.toRadixString(16).padLeft(4, '0')}');
}
