import 'dart:io';

/// Simple file logger that writes timestamped lines to a .log file
/// placed in the same directory as the session's FIT file.
///
/// Usage:
///   AppLogger.init('/path/to/session.fit.log');  // called by FitWriter.create()
///   AppLogger.log('[Tag] message');               // anywhere in the app
///   AppLogger.close();                            // called by FitWriter.finish()
class AppLogger {
  static IOSink? _sink;
  static String? _logPath;

  /// Open (or replace) the log file at [logPath].
  static Future<void> init(String logPath) async {
    await close(); // close any previous session log
    _logPath = logPath;
    try {
      _sink = File(logPath).openWrite(mode: FileMode.writeOnly);
      final header = '=== Session log opened at ${DateTime.now().toUtc().toIso8601String()} ===\n'
          'Log file: $logPath\n';
      _sink!.write(header);
      // ignore: avoid_print
      print('[AppLogger] Logging to $logPath');
    } catch (e) {
      // ignore: avoid_print
      print('[AppLogger] ERROR opening log file: $e');
      _sink = null;
    }
  }

  /// Write a timestamped log line to the file AND to the debug console.
  static void log(String message) {
    final line = '${DateTime.now().toUtc().toIso8601String()} $message';
    // ignore: avoid_print
    print(line);
    _sink?.writeln(line);
  }

  /// Flush and close the log file.
  static Future<void> close() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
  }

  /// Path of the current log file (null if not initialised).
  static String? get logPath => _logPath;
}
