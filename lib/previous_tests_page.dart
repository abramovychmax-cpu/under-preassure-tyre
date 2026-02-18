import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'ui/common_widgets.dart';

/// Previous Tests Page: Display list of past optimal tire pressures
class PreviousTestsPage extends StatefulWidget {
  const PreviousTestsPage({super.key});

  @override
  State<PreviousTestsPage> createState() => _PreviousTestsPageState();
}

class _PreviousTestsPageState extends State<PreviousTestsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tests = [];

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    final tests = <Map<String, dynamic>>[];

    // Load durable history file (JSONL); gracefully skip bad lines
    try {
      final file = await _historyFile();
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final data = jsonDecode(line) as Map<String, dynamic>;
            tests.add(data);
          } catch (_) {}
        }
      }
    } catch (_) {}

    tests.sort((a, b) {
      final at = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });

    if (!mounted) return;
    setState(() {
      _tests = tests;
      _isLoading = false;
    });
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatPressure(double value, String unit) {
    if (unit == 'Bar') {
      return (value * 0.0689476).toStringAsFixed(2);
    }
    return value.toStringAsFixed(1);
  }

  String _protocolLabel(String protocol) {
    switch (protocol) {
      case 'constant_power':
        return 'CONSTANT POWER';
      case 'lap_efficiency':
        return 'LAP EFFICIENCY';
      case 'coast_down':
        return 'COAST DOWN';
      default:
        return protocol.toUpperCase();
    }
  }

  Future<File> _historyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'test_history.jsonl'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'PREVIOUS TESTS',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGemini))
          : _tests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 64,
                          color: Colors.grey.withAlpha((0.3 * 255).round()),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No tests saved yet',
                          style: TextStyle(
                            color: Colors.grey.withAlpha((0.7 * 255).round()),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Complete your first tire pressure test to see results here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.withAlpha((0.5 * 255).round()),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _tests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final test = _tests[index];
                    final protocol = test['protocol']?.toString() ?? '';
                    final bikeType = test['bikeType']?.toString() ?? 'road';
                    final timestamp = test['timestamp']?.toString() ?? '';
                    final unit = test['pressureUnit']?.toString() ?? 'PSI';
                    final front = (test['optimalFrontPressure'] as num?)?.toDouble() ?? 0.0;
                    final rear = (test['optimalRearPressure'] as num?)?.toDouble() ?? 0.0;
                    final vibrationLoss = (test['vibrationLossPercent'] as num?)?.toDouble() ?? 0.0;
                    final fitFilePath = test['fitFilePath']?.toString();
                    final hasFitPath = fitFilePath != null && fitFilePath.isNotEmpty;

                    return AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _protocolLabel(protocol),
                                  style: const TextStyle(color: accentGemini, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _formatDate(timestamp),
                                      style: const TextStyle(color: Color(0xFF888888), fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                    if (hasFitPath) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final file = File(fitFilePath);
                                          // Capture navigator/messenger to avoid async gap issues
                                          final messenger = ScaffoldMessenger.of(context);
                                          
                                          if (await file.exists()) {
                                            await Share.shareXFiles(
                                              [XFile(fitFilePath)], 
                                              text: 'Tire Pressure Test Result (${_formatDate(timestamp)})'
                                            );
                                          } else {
                                            messenger.showSnackBar(
                                              const SnackBar(content: Text('File not found (may have been deleted)')),
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.share_outlined, size: 18, color: accentGemini),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Bike: ${bikeType.toUpperCase()}',
                              style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('FRONT', style: TextStyle(color: Color(0xFF999999), fontSize: 9, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_formatPressure(front, unit)} $unit',
                                        style: const TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('REAR', style: TextStyle(color: Color(0xFF999999), fontSize: 9, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_formatPressure(rear, unit)} $unit',
                                        style: const TextStyle(color: accentGemini, fontSize: 16, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Vibration reduction: ${vibrationLoss.toStringAsFixed(1)}%',
                              style: const TextStyle(color: Color(0xFF888888), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
