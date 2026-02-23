import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/common_widgets.dart';
import 'ui/app_menu_button.dart';
import 'analysis_page.dart';

class PastResultsPage extends StatefulWidget {
  final bool isOverlay;
  const PastResultsPage({super.key, this.isOverlay = false});

  @override
  State<PastResultsPage> createState() => _PastResultsPageState();
}

class _PastResultsPageState extends State<PastResultsPage> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList('test_keys') ?? [];
    final results = <Map<String, dynamic>>[];
    for (final key in keys.reversed) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        results.add(data);
      } catch (_) {}
    }
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }

  String _formatProtocol(String p) {
    switch (p) {
      case 'constant_power': return 'Constant Power';
      case 'lap_efficiency': return 'Lap Efficiency (Chung)';
      case 'coast_down':     return 'Coast-Down';
      case 'sim':            return 'Simulation';
      default:               return p;
    }
  }

  String _formatBike(String b) {
    switch (b) {
      case 'road':     return 'Road';
      case 'tt':       return 'Time Trial';
      case 'gravel':   return 'Gravel';
      case 'mountain': return 'Mountain';
      default:         return b;
    }
  }

  IconData _protocolIcon(String p) {
    switch (p) {
      case 'constant_power': return Icons.bolt;
      case 'lap_efficiency': return Icons.loop;
      case 'coast_down':     return Icons.terrain;
      case 'sim':            return Icons.play_circle_outline;
      default:               return Icons.analytics;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOverlay,
        backgroundColor: bgLight,
        elevation: 0,
        title: const Text(
          'PAST RESULTS',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
        actions: widget.isOverlay ? null : const [AppMenuButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentGemini))
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 56, color: accentGemini.withAlpha(80)),
                      const SizedBox(height: 16),
                      const Text('No saved results yet', style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text('Complete a session and tap SAVE DATA', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) => _resultCard(_results[i]),
                ),
    );
  }

  Widget _resultCard(Map<String, dynamic> data) {
    final timestamp   = data['timestamp'] as String? ?? '';
    final protocol    = data['protocol']  as String? ?? '';
    final bikeType    = data['bikeType']  as String? ?? 'road';
    final front       = (data['optimalFrontPressure'] as num?)?.toDouble() ?? 0.0;
    final rear        = (data['optimalRearPressure']  as num?)?.toDouble() ?? 0.0;
    final unit        = data['pressureUnit'] as String? ?? 'PSI';
    final fitPath     = data['fitFilePath'] as String? ?? '';

    final String frontStr = front > 0 ? front.toStringAsFixed(1) : '—';
    final String rearStr  = rear  > 0 ? rear.toStringAsFixed(1)  : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (fitPath.isEmpty) return;
          openPartialOverlay(
            context,
            AnalysisPage(
              fitFilePath: fitPath,
              protocol: protocol,
              bikeType: bikeType,
              isOverlay: true,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon + date
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accentGemini.withAlpha(31),
                    radius: 20,
                    child: Icon(_protocolIcon(protocol), color: accentGemini, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(timestamp),
                          style: const TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatProtocol(protocol),
                          style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: accentGemini),
                ],
              ),
              const SizedBox(height: 12),
              // Bike type pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentGemini.withAlpha(31),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatBike(bikeType),
                  style: const TextStyle(color: Color(0xFF1F9D8F), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
              ),
              const SizedBox(height: 12),
              // Pressure row
              Row(
                children: [
                  _pressureTile('FRONT', frontStr, unit),
                  const SizedBox(width: 12),
                  _pressureTile('REAR', rearStr, unit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pressureTile(String label, String value, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF999999), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: const TextStyle(color: accentGemini, fontSize: 18, fontWeight: FontWeight.w900)),
                  TextSpan(text: ' $unit', style: const TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
