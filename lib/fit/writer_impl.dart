import 'dart:io';
import 'dart:typed_data';

import 'package:tyre_preassure/fit/protocol.dart';

/// Implements the low-level logic for writing a FIT file using the proper interleaved message structure.
class RealFitWriter {
  final IOSink _sink;
  final String _filePath;
  final List<int> _fileBuffer = [];
  int _dataSize = 0;
  
  /// Track which message types have been defined and their LMT
  /// Key: GMN (global message number), Value: LMT (local message type)
  final Map<int, int> _definedMessages = {};
  int _nextLmt = 0; // Counter for assigning local message types

  RealFitWriter(this._sink, this._filePath);

  void writeFileHeader() {
    final b = BytesBuilder();
    FitProtocol.writeUint8(b, 14);       // Header size
    FitProtocol.writeUint8(b, 0x20);     // Protocol version (2.0)
    FitProtocol.writeUint16(b, 2163);    // Profile version (21.63 = 2021 Sep+Dec updates)
    FitProtocol.writeUint32(b, 0);       // Data size (placeholder)
    b.add('.FIT'.codeUnits);              // Data type
    FitProtocol.writeUint16(b, 0x0000);  // Header CRC (calculated during finalize)

    final headerBytes = b.toBytes();
    _sink.add(headerBytes);
    _fileBuffer.addAll(headerBytes);
  }

  void writeMessage(int globalMessageNum, Map<int, dynamic> fields) {
    // Assign a local message type for this GMN if not already defined
    int lmt;
    bool isFirstTime = false;
    
    if (!_definedMessages.containsKey(globalMessageNum)) {
      lmt = _nextLmt++;
      _definedMessages[globalMessageNum] = lmt;
      isFirstTime = true;
    } else {
      lmt = _definedMessages[globalMessageNum]!;
    }

    // Step 1: Write Definition Message (only on first occurrence of this GMN)
    if (isFirstTime) {
      final defBuilder = BytesBuilder();
      
      // Record header: 0x40 = definition message bit set, LSBs = local message type
      final recordHeader = 0x40 | lmt;
      FitProtocol.writeUint8(defBuilder, recordHeader);
      FitProtocol.writeUint8(defBuilder, 0);           // Reserved
      FitProtocol.writeUint8(defBuilder, 1);           // Architecture: Big Endian
      FitProtocol.writeUint16(defBuilder, globalMessageNum);
      FitProtocol.writeUint8(defBuilder, fields.length); // Number of fields

      // Build field definitions in sorted order (by field ID for consistency)
      final sortedFields = fields.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

      for (final entry in sortedFields) {
        final fieldId = entry.key;
        final value = entry.value;
        final typeInfo = _getTypeInfo(value, fieldId);
        
        FitProtocol.writeUint8(defBuilder, fieldId);
        FitProtocol.writeUint8(defBuilder, typeInfo['size']!);
        FitProtocol.writeUint8(defBuilder, typeInfo['baseType']!);
      }

      final defBytes = defBuilder.toBytes();
      _sink.add(defBytes);
      _fileBuffer.addAll(defBytes);
      _dataSize += defBytes.length;
    }

    // Step 2: Write Data Message
    final dataBuilder = BytesBuilder();
    
    // Record header for data message: just the local message type (no definition bit)
    FitProtocol.writeUint8(dataBuilder, lmt);

    // Write field values in the same order as definition
    final sortedFields = fields.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in sortedFields) {
      final fieldId = entry.key;
      final value = entry.value;
      _writeValue(dataBuilder, value, fieldId);
    }

    final dataBytes = dataBuilder.toBytes();
    _sink.add(dataBytes);
    _fileBuffer.addAll(dataBytes);
    _dataSize += dataBytes.length;
  }

  Future<void> finalize() async {
    // Flush all pending data
    await _sink.flush();
    await _sink.close();

    // Update the data size in the file header
    final headerUpdater = ByteData(4);
    headerUpdater.setUint32(0, _dataSize, Endian.big);
    final dataSizeBytes = headerUpdater.buffer.asUint8List();

    // Update in-memory buffer for CRC
    if (_fileBuffer.length >= 8) {
      _fileBuffer[4] = dataSizeBytes[0];
      _fileBuffer[5] = dataSizeBytes[1];
      _fileBuffer[6] = dataSizeBytes[2];
      _fileBuffer[7] = dataSizeBytes[3];
    }

    // Calculate header CRC (from bytes 0-11)
    // IMPORTANT: Garmin FIT CRC is stored in LITTLE ENDIAN!
    final headerForCrc = _fileBuffer.sublist(0, 12);
    final headerCrc = FitProtocol.crc16Ccitt(headerForCrc);
    if (_fileBuffer.length >= 14) {
      final headerCrcBytes = ByteData(2)..setUint16(0, headerCrc, Endian.little);
      _fileBuffer[12] = headerCrcBytes.getUint8(0);
      _fileBuffer[13] = headerCrcBytes.getUint8(1);
    }

    // Calculate and append file CRC
    // IMPORTANT: Garmin FIT CRC is stored in LITTLE ENDIAN!
    // CRC is calculated over the DATA portion only (after the 14-byte header)
    final dataPortion = _fileBuffer.sublist(14);
    final fileCrc = FitProtocol.crc16Ccitt(dataPortion);
    final crcBytes = ByteData(2)..setUint16(0, fileCrc, Endian.little);
    _fileBuffer.addAll(crcBytes.buffer.asUint8List());

    // Write the complete file to disk
    try {
      final file = File(_filePath);
      await file.writeAsBytes(_fileBuffer);
    } catch (e) {
      print('Error writing FIT file: $e');
    }
  }

  void _writeValue(BytesBuilder b, dynamic value, int fieldId) {
    if (value is int) {
      final typeInfo = _getTypeInfo(value, fieldId);
      switch (typeInfo['size']) {
        case 1:
          FitProtocol.writeUint8(b, value);
          break;
        case 2:
          FitProtocol.writeUint16(b, value);
          break;
        case 4:
          if (typeInfo['baseType'] == 0x85) { // sint32
            FitProtocol.writeSint32(b, value);
          } else {
            FitProtocol.writeUint32(b, value);
          }
          break;
        default:
          throw ArgumentError('Unsupported int size: ${typeInfo['size']}');
      }
    } else if (value is double) {
      if (fieldId == 0 || fieldId == 1) { // lat/lon as semicircles
        FitProtocol.writeSemicircles(b, value);
      } else {
        FitProtocol.writeFloat32(b, value);
      }
    } else if (value is String) {
      b.add(value.codeUnits);
      b.addByte(0); // Null terminator
    } else if (value is DateTime) {
      FitProtocol.writeTimestamp(b, value);
    } else if (value is List<int>) {
      b.add(value);
    } else {
      throw ArgumentError('Unsupported type for value: ${value.runtimeType}');
    }
  }

  Map<String, int> _getTypeInfo(dynamic value, int fieldId) {
    if (value is int) {
      // Specific overrides for common field IDs across all messages
      switch (fieldId) {
        case 0: 
          // Field 0: position_lat (Record) = sint32, or type (FileID) = uint8
          // In Record context, it's sint32; in FileID context, it's uint8
          // Heuristic: if value is large (> 100), it's semicircles (sint32), else uint8
          return (value.abs() > 100) 
            ? {'size': 4, 'baseType': 0x85} // sint32 (semicircles)
            : {'size': 1, 'baseType': 0x00}; // uint8 (type in FileID)
        case 1:
          // Field 1: position_long (Record) = sint32, or manufacturer (FileID) = uint16
          return (value.abs() > 100)
            ? {'size': 4, 'baseType': 0x85} // sint32 (semicircles)
            : {'size': 2, 'baseType': 0x84}; // uint16 (manufacturer in FileID)
        case 2:
          // Field 2: altitude (Record) = uint16, or product (FileID) = uint16
          return {'size': 2, 'baseType': 0x84}; // uint16
        case 3:
          // Field 3: speed (Record) = uint16, or serial (FileID) = uint32
          return (value > 0xFFFF)
            ? {'size': 4, 'baseType': 0x86} // uint32 (serial in FileID)
            : {'size': 2, 'baseType': 0x84}; // uint16 (speed in Record)
        case 4: return {'size': 1, 'baseType': 0x02}; // uint8 (cadence)
        case 5: return {'size': 4, 'baseType': 0x86}; // uint32 (distance scaled)
        case 7: return {'size': 2, 'baseType': 0x84}; // uint16 (power)
        case 253: return {'size': 4, 'baseType': 0x86}; // uint32 (timestamp)
        case 254: return {'size': 4, 'baseType': 0x86}; // uint32 (timestamp)
      }
      
      // General integer sizing based on value
      if (value >= 0) {
        if (value <= 0xFF) return {'size': 1, 'baseType': 0x02}; // uint8
        if (value <= 0xFFFF) return {'size': 2, 'baseType': 0x84}; // uint16
        return {'size': 4, 'baseType': 0x86}; // uint32
      } else {
        if (value >= -128) return {'size': 1, 'baseType': 0x01}; // sint8
        if (value >= -32768) return {'size': 2, 'baseType': 0x83}; // sint16
        return {'size': 4, 'baseType': 0x85}; // sint32
      }
    } else if (value is double) {
      return {'size': 4, 'baseType': 0x88}; // float32
    } else if (value is String) {
      return {'size': value.length + 1, 'baseType': 0x07}; // string
    } else if (value is DateTime) {
      return {'size': 4, 'baseType': 0x86}; // uint32 (timestamp)
    } else if (value is List<int>) {
      return {'size': value.length, 'baseType': 0x0D}; // byte array
    }
    throw ArgumentError('Unknown type for field $fieldId: ${value.runtimeType}');
  }
}
