import 'dart:io';

Future<void> main() async {
  final fitFilePath = 'test_data/coast_down_20260129_194342.fit';
  final jsonlPath = '$fitFilePath.jsonl';
  
  final fitFile = File(fitFilePath);
  final jsonlFile = File(jsonlPath);
  
  print('═══════════════════════════════════════════════════════════');
  print('📊 FIT FILE ANALYSIS (via JSONL Companion)');
  print('═══════════════════════════════════════════════════════════');
  print('');

  // Check FIT file
  if (!await fitFile.exists()) {
    print('❌ FIT file not found: $fitFilePath');
    return;
  }
  
  final fitBytes = await fitFile.readAsBytes();
  print('✓ FIT file found: ${(fitBytes.length / 1024).toStringAsFixed(1)} KB');
  print('  Note: fit_tool v1.0.5 only supports encoding (FitFileBuilder)');
  print('  FIT decoding is not available in this version.');
  print('');

  // Check companion JSONL file
  if (!await jsonlFile.exists()) {
    print('❌ Companion JSONL file not found: $jsonlPath');
    print('   Generate with: python generate_agr_simulation.py');
    return;
  }
  
  final jsonlLines = await jsonlFile.readAsLines();
  print('✓ Companion JSONL found: ${jsonlLines.length} lines');
  print('');

  // Parse JSONL to extract lap structure
  print('═══════════════════════════════════════════════════════════');
  print('📋 JSONL STRUCTURE ANALYSIS');
  print('═══════════════════════════════════════════════════════════');
  print('');

  int lapCount = 0;
  int recordCount = 0;
  
  for (final line in jsonlLines) {
    if (line.contains('"type":"LAP"')) {
      lapCount++;
      // Sample LAP output
      if (lapCount <= 3) {
        print('LAP $lapCount: $line');
      }
    } else if (line.contains('"type":"RECORD"')) {
      recordCount++;
    }
  }

  print('');
  print('Total LAP messages: $lapCount');
  print('Total RECORD messages: $recordCount');
  print('');

  print('═══════════════════════════════════════════════════════════');
  print('✓ FIT + JSONL Analysis Ready');
  print('═══════════════════════════════════════════════════════════');
  print('');
  print('Data flow:');
  print('1. FIT file: Binary structure and metadata');
  print('2. JSONL companion: Plain text metrics (speed, power, GPS, pressure)');
  print('3. ClusteringService: Merges both for complete analysis');
  print('');
}
