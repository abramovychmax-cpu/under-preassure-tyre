import 'dart:io';
import 'package:fit_tool/fit_tool.dart';

/// Validate the generated FIT file by converting to CSV
void main() async {
  final file = File('assets/sample_fake.fit');
  final bytes = await file.readAsBytes();
  
  try {
    final fitFile = FitFile.fromBytes(bytes);
    
    final rows = fitFile.toRows();
    
    // Count message types by looking at first column (message type)
    Map<String, int> messageCounts = {};
    
    for (var row in rows) {
      if (row.isNotEmpty) {
        final messageType = row[0].toString();
        messageCounts[messageType] = (messageCounts[messageType] ?? 0) + 1;
      }
    }
  } catch (e) {
    // Validation failed silently
  }
}
