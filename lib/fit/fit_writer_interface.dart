/// Defines the public interface for a FIT file writer.
abstract class FitWriterInterface {
  /// Starts the session and writes the file header and file_id message.
  Future<void> startSession(Map<String, dynamic> metadata);

  /// Writes a lap message to the FIT file.
  Future<void> writeLap(double front, double rear, {required int lapIndex});

  /// Writes a record message (containing sensor data) to the FIT file.
  Future<void> writeRecord(Map<String, dynamic> record);

  /// Flushes any buffered data to the file.
  Future<void> flush();

  /// Writes the final session/activity messages and the file CRC to finalize the file.
  Future<void> finish();
}
