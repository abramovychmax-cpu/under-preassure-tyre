import 'dart:typed_data';

void main() {
  // Test little-endian write
  int value = 0x5b84;
  
  var bd = ByteData(2)..setUint16(0, value, Endian.little);
  print('Value: ${value.toRadixString(16)}');
  print('Byte 0: ${bd.getUint8(0).toRadixString(16).padLeft(2, '0')}');
  print('Byte 1: ${bd.getUint8(1).toRadixString(16).padLeft(2, '0')}');
  
  // Get as bytes
  List<int> bytes = bd.buffer.asUint8List();
  print('Bytes: ${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
  
  // Read back
  int readBack = bd.getUint16(0, Endian.little);
  print('Read back: ${readBack.toRadixString(16)}');
}
