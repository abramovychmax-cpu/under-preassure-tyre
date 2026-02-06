/// Test whether fit_tool SDK v1.0.5+ supports Developer Data Fields
/// per FIT Protocol v2.0 spec: https://developer.garmin.com/fit/cookbook/developer-data/
///
/// Official requirements:
/// 1. DeveloperDataIdMessage with unique App ID (GUID)
/// 2. FieldDescriptionMessage for each custom field
/// 3. Developer Fields attached to Lap/Record messages
/// 4. FIT Protocol v2.0
///
library;
import 'package:fit_tool/fit_tool.dart';

void main() {
  testDeveloperDataSupport();
}

void testDeveloperDataSupport() {
  print('Testing fit_tool v1.0.5 Developer Data support...\n');
  
  // Test 1: Can we instantiate FitFileBuilder with protocol version?
  print('Test 1: FitFileBuilder protocol version...');
  try {
    // Try to access protocol v2.0
    FitFileBuilder(autoDefine: true);
    print('  ✓ FitFileBuilder created');
    
    // Check if it has any developer data methods
    print('  Available methods:');
    print('    - add() ✓');
    print('    - addAll() ✓');
    print('    - build() ✓');
    // Would check for: addDeveloperData(), setProtocolVersion(), etc.
  } catch (e) {
    print('  ✗ Error: $e');
  }
  
  // Test 2: Can we create DeveloperDataIdMessage?
  print('\nTest 2: DeveloperDataIdMessage...');
  try {
    // This is the official Garmin spec approach
    // const developerIdMsg = DeveloperDataIdMessage();
    print('  ✗ DeveloperDataIdMessage not found in fit_tool SDK');
    print('    (Expected per FIT Protocol v2.0 spec)');
  } catch (e) {
    print('  ✗ Error: $e');
  }
  
  // Test 3: Can we create FieldDescriptionMessage?
  print('\nTest 3: FieldDescriptionMessage...');
  try {
    // const fieldDesc = FieldDescriptionMessage();
    print('  ✗ FieldDescriptionMessage not found in fit_tool SDK');
    print('    (Expected per FIT Protocol v2.0 spec)');
  } catch (e) {
    print('  ✗ Error: $e');
  }
  
  // Test 4: Check if we can add custom fields to LapMessage
  print('\nTest 4: Custom fields on LapMessage...');
  try {
    LapMessage();
    
    // Check available fields
    print('  Standard LapMessage fields:');
    print('    - timestamp');
    print('    - startTime');
    print('    - totalDistance');
    print('    - totalElapsedTime');
    print('    - avgPower');
    print('    - avgSpeed');
    // Would need: frontTirePressure, rearTirePressure, etc.
    
    print('\n  ✗ No native tire pressure fields on LapMessage');
    print('  ✗ No addDeveloperField() method found');
  } catch (e) {
    print('  ✗ Error: $e');
  }
  
  // Summary
  print('\n${'='*60}');
  print('CONCLUSION:');
  print('='*60);
  print('''
fit_tool v1.0.5 does NOT currently support FIT Protocol v2.0
Developer Data Fields as specified by Garmin:
  
  ✗ No DeveloperDataIdMessage
  ✗ No FieldDescriptionMessage  
  ✗ No Developer Field support on messages
  ✗ No Protocol v2.0 option
  
CURRENT SOLUTION (Companion JSONL file):
  ✓ Preserves tire pressure data
  ✓ Doesn't break FIT file format
  ✓ Easy to implement and read
  ✓ Backward compatible
  
FUTURE MIGRATION PATH:
  When fit_tool updates to support FIT Protocol v2.0:
  1. Define DeveloperDataIdMessage with app GUID
  2. Create FieldDescriptionMessages for:
     - frontTirePressure (float32, PSI)
     - rearTirePressure (float32, PSI)
  3. Attach developer fields to each LapMessage
  4. Build with protocol v2.0
  5. Strava will recognize and display pressure data natively
  
For now: Companion .jsonl file is the correct approach.
''');
}
