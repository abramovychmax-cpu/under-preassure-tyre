import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/common_widgets.dart';

class FitInspectorPage extends StatefulWidget {
  const FitInspectorPage({super.key});

  @override
  State<FitInspectorPage> createState() => _FitInspectorPageState();
}

class _FitInspectorPageState extends State<FitInspectorPage> {
  String _speedUnit = 'km/h'; // Load from SharedPreferences

  @override
  void initState() {
    super.initState();
    _loadSpeedUnit();
  }

  Future<void> _loadSpeedUnit() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speedUnit = prefs.getString('speed_unit') ?? 'km/h';
    });
  }

  double _convertSpeed(double kmh) {
    if (_speedUnit == 'mph') {
      return kmh * 0.621371;
    }
    return kmh;
  }

  Future<List<Map<String, dynamic>>> _loadLatestFit() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext == null) return [];
      final dir = Directory(ext.path);
      if (!await dir.exists()) return [];

      final files = await dir.list().where((f) => f is File && f.path.endsWith('.fit')).cast<File>().toList();
      if (files.isEmpty) return [];

      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      final file = files.first;
      final bytes = await file.readAsBytes();
      if (bytes.length < 14) return [];

      final headerSize = bytes[0];
      final dataSize = bytes.length > 7 ? (bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | (bytes[7] << 24)) : 0;
      final dataStart = headerSize;
      final dataEnd = (dataStart + dataSize).clamp(0, bytes.length);
      final data = bytes.sublist(dataStart, dataEnd);

      final records = <Map<String, dynamic>>[];
      const recSize = 19;
      if (data.length >= recSize) {
        for (int i = 0; i + recSize <= data.length; i += recSize) {
          final d = data.sublist(i, i + recSize);
          int u32(int off) => d[off] | (d[off + 1] << 8) | (d[off + 2] << 16) | (d[off + 3] << 24);
          int i32(int off) {
            final v = u32(off);
            return v & 0x80000000 != 0 ? v - 0x100000000 : v;
          }
          int u16(int off) => d[off] | (d[off + 1] << 8);
          final ts = u32(0);
          final latE7 = i32(4);
          final lonE7 = i32(8);
          final speedCmps = u16(12);
          final power = u16(14);
          final cadence = d[16];
          final distance = u16(17);

          records.add({
            'time': DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true).toLocal().toIso8601String(),
            'lat': latE7 / 1e7,
            'lon': lonE7 / 1e7,
            'speed_kmh': (speedCmps / 100.0) * 3.6,
            'power_w': power,
            'cadence': cadence,
            'distance_m': distance,
          });
        }
      }

      return records;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bgLight,
        elevation: 0,
        title: const Text(
          'FIT INSPECTOR',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadLatestFit(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final records = snap.data ?? [];
          if (records.isEmpty) return const Center(child: Text('No structured records found in latest .fit'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, i) {
              final r = records[i];
              return ListTile(
                title: Text(r['time'] ?? ''),
                subtitle: Text('lat:${r['lat'].toStringAsFixed(6)} lon:${r['lon'].toStringAsFixed(6)} • ${_convertSpeed(r['speed_kmh']).toStringAsFixed(1)} $_speedUnit • ${r['power_w']}W • ${r['cadence']}rpm • ${r['distance_m']}m'),
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: records.length,
          );
        },
      ),
    );
  }
}
