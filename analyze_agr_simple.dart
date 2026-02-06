import 'dart:io';

void main() async {
  final file = File('test_data/agr.fit');
  if (!file.existsSync()) {
    print('File not found: test_data/agr.fit');
    return;
  }

  final bytes = await file.readAsBytes();
  print('FIT file size: ${bytes.length} bytes\n');

  // Parse FIT header
  final headerSize = bytes[0];
  final protocolVersion = bytes[1];
  final profileVersion = bytes[2] | (bytes[3] << 8);
  final dataSize = bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24);

  print('=== FIT HEADER ===');
  print('Header size: $headerSize bytes');
  print('Protocol version: $protocolVersion');
  print('Profile version: $profileVersion');
  print('Data size: $dataSize bytes');
  print('Total file size: ${bytes.length} bytes');
  print('');

  // Extract data section
  final dataStart = headerSize;
  final dataEnd = dataStart + dataSize;
  final fitData = bytes.sublist(dataStart, dataEnd);

  print('=== RAW DATA ANALYSIS ===');
  print('Data section size: ${fitData.length} bytes');
  print('Hex preview (first 100 bytes):');

  // Simple message parsing - look for common patterns
  print('=== MESSAGE PATTERNS ===');
  
  // Look for speed data (estimate: speed is typically in range 0-50 m/s, stored as uint16)
  final speedRecords = <int>[];
  for (int i = 0; i < fitData.length - 2; i++) {
    final val = fitData[i] | (fitData[i + 1] << 8);
    // Speed range: 0-50 m/s (0-180 km/h is reasonable for cycling)
    if (val > 0 && val < 5000) {  // Rough heuristic
      speedRecords.add(val);
    }
  }

  print('Potential speed samples found: ${speedRecords.length}');
  if (speedRecords.isNotEmpty) {
    print('  Min: ${(speedRecords.reduce((a, b) => a < b ? a : b) / 100).toStringAsFixed(2)} m/s');
    print('  Max: ${(speedRecords.reduce((a, b) => a > b ? a : b) / 100).toStringAsFixed(2)} m/s');
  }
  print('');

  print('NOTE: For proper FIT parsing, use fit_tool SDK within Flutter/Dart project context');
  print('      This standalone script can only do rough binary analysis.');
}
