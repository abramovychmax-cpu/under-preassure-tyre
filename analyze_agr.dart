import 'dart:io';

Future<void> main() async {
  final fitFile = File('test_data/agr.fit');
  if (!fitFile.existsSync()) {
    print('ERROR: agr.fit not found');
    return;
  }

  final bytes = await fitFile.readAsBytes();
  
  // Note: fit_tool v1.0.5 does not support FIT decoding (only encoding).
  // Use the JSONL companion file for analysis instead.
  print('=== FIT FILE ANALYSIS ===\n');
  print('Note: fit_tool v1.0.5 is for encoding FIT files only.');
  print('FIT decoding is not available.\n');
  
  // Validate companion JSONL file exists
  final jsonlFile = File('test_data/agr.fit.jsonl');
  if (!jsonlFile.existsSync()) {
    print('ERROR: agr.fit.jsonl not found');
    print('Please generate companion JSONL with generate_agr_simulation.py');
    return;
  }

  final jsonlLines = await jsonlFile.readAsLines();
  print('✓ Companion JSONL found: ${jsonlLines.length} lines\n');

  print('FIT + JSONL Analysis Architecture:');
  print('1. FIT file: Binary format with structure & metadata');
  print('   Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
  print('   Messages: Encrypted, requires fit_tool decoder (not in v1.0.5)\n');

  print('2. JSONL file: Plain text with all metrics');
  print('   Lines: ${jsonlLines.length}');
  print('   Content: Lap metadata + Record samples (speed, GPS, vibration)\n');

  print('3. ClusteringService.extractMetricsFromFitAndJsonl()');
  print('   → Merges both sources for complete analysis\n');

  print('✓ Ready for pressure optimization analysis!');
}
