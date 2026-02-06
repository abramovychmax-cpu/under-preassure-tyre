import 'dart:typed_data';

/// Low-level FIT primitives: CRC and basic encoders used by the FIT writer.
class FitProtocol {
  // FIT epoch: 1989-12-31 00:00:00 UTC
  static final DateTime _fitEpoch = DateTime.utc(1989, 12, 31);

  // GARMIN FIT CRC table (nibble-based, NOT CRC-16/CCITT!)
  // From official Garmin spec: https://developer.garmin.com/fit/protocol/
  static const List<int> _fitCrcTable = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
  ];

  /// Compute GARMIN FIT CRC (nibble-based) for FIT files.
  /// CRITICAL: This is the official Garmin algorithm, NOT CRC-16/CCITT!
  /// From: https://developer.garmin.com/fit/protocol/
  static int crc16Ccitt(List<int> bytes) {
    int crc = 0;
    for (final byte in bytes) {
      // compute checksum of lower four bits of byte
      int tmp = _fitCrcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ _fitCrcTable[byte & 0xF];

      // now compute checksum of upper four bits of byte
      tmp = _fitCrcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ _fitCrcTable[(byte >> 4) & 0xF];
    }
    return crc;
  }

  static void writeUint8(BytesBuilder b, int v) {
    b.addByte(v & 0xFF);
  }

  static void writeSint8(BytesBuilder b, int v) {
    final bd = ByteData(1)..setInt8(0, v);
    b.add(bd.buffer.asUint8List());
  }

  static void writeUint16(BytesBuilder b, int v) {
    final bd = ByteData(2)..setUint16(0, v, Endian.big);
    b.add(bd.buffer.asUint8List());
  }

  static void writeUint32(BytesBuilder b, int v) {
    final bd = ByteData(4)..setUint32(0, v, Endian.big);
    b.add(bd.buffer.asUint8List());
  }

  static void writeSint32(BytesBuilder b, int v) {
    final bd = ByteData(4)..setInt32(0, v, Endian.big);
    b.add(bd.buffer.asUint8List());
  }

  static void writeFloat32(BytesBuilder b, double v) {
    final bd = ByteData(4)..setFloat32(0, v, Endian.big);
    b.add(bd.buffer.asUint8List());
  }

  static void writeTimestamp(BytesBuilder b, DateTime dt) {
    final utc = dt.toUtc();
    final secs = utc.difference(_fitEpoch).inSeconds;
    writeUint32(b, secs);
  }

  /// Convert degrees to FIT semicircles (sint32)
  static int degreesToSemicircles(double degrees) {
    // semicircles = degrees * (2^31 / 180)
    final factor = 2147483648.0 / 180.0; // 2^31
    return (degrees * factor).round();
  }

  static void writeSemicircles(BytesBuilder b, double degrees) {
    writeSint32(b, degreesToSemicircles(degrees));
  }
}
