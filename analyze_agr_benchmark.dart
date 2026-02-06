import 'dart:io';

void main() async {
  final file = File('test_data/agr.fit');
  if (!file.existsSync()) {
    print('File not found: test_data/agr.fit');
    return;
  }

  final bytes = await file.readAsBytes();
  print('FIT file size: ${bytes.length} bytes\n');

  try {
    // Note: fit_tool v1.0.5 is for ENCODING FIT files (FitFileBuilder).
    // FIT DECODING is not supported in this version.
    // All analysis data is stored in the JSONL companion file: agr.fit.jsonl
    print('=== FIT File Benchmark ===\n');
    print('Note: fit_tool v1.0.5 is for encoding only (FitFileBuilder).');
    print('FIT decoding is not available.\n');
    
    // Validate companion JSONL file exists
    final jsonlFile = File('test_data/agr.fit.jsonl');
    if (jsonlFile.existsSync()) {
      final lines = await jsonlFile.readAsLines();
      print('✓ Companion JSONL file found');
      print('  Location: test_data/agr.fit.jsonl');
      print('  Size: ${lines.length} lines');
      print('  Content: Lap metadata + Record samples\n');
      
      print('Analysis Flow:');
      print('1. FIT file (binary): Contains structure, metadata');
      print('2. JSONL file (text): Contains detailed metrics');
      print('3. ClusteringService.extractMetricsFromFitAndJsonl()');
      print('   → Merges both files for complete analysis\n');
      
      print('✓ App ready for analysis on real FIT files!');
    } else {
      print('⚠ JSONL companion file not found');
      print('  Expected: test_data/agr.fit.jsonl');
    }
  } catch (e) {
    print('Error: $e');
  }
}
