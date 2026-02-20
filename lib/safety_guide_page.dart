import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'protocol_selection_page.dart';
import 'sensor_service.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class SafetyGuidePage extends StatefulWidget {
  final bool isOverlay;
  const SafetyGuidePage({super.key, this.isOverlay = false});

  @override
  State<SafetyGuidePage> createState() => _SafetyGuidePageState();
}

class _SafetyGuidePageState extends State<SafetyGuidePage> {
  bool _firstVisit = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isOverlay) _checkFirstVisit();
  }

  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('safety_guide_seen') ?? false;
    if (!seen) {
      await prefs.setBool('safety_guide_seen', true);
      if (mounted) setState(() => _firstVisit = true);
    }
  }

  void _goToProtocols(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProtocolSelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'SAFETY & TESTING',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
        backgroundColor: bgLight,
        elevation: 0,
        actions: widget.isOverlay ? null : const [AppMenuButton()],
      ),
      body: RightEdgeSwipeDetector(
        onSwipeForward: (widget.isOverlay || SensorService().isSessionActive) ? null : () => _goToProtocols(context),
        child: Column(
          children: [
          Expanded(
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text(
              '',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF222222),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'These guidelines apply to all testing protocols.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            _sectionHeader('Safety'),
            _bulletPoint('Choose routes with minimal or no traffic.'),
            _bulletPoint('Never exceed the max or minimum pressure for your tire/rim combo.'),
            const SizedBox(height: 24),
            _sectionHeader('Consistency'),
            _bulletPoint('Ride manageable terrain and keep power and speed steady.'),
            const SizedBox(height: 24),
            _sectionHeader('Position'),
            _bulletPoint('Keep the same body position every run for reliable results.'),
            const SizedBox(height: 24),
            _sectionHeader('Runs'),
            _bulletPoint('Perform at least three runs at different pressures.'),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
          OnboardingNavBar(
            onBack: () => Navigator.pop(context),
            onForward: (widget.isOverlay || SensorService().isSessionActive) ? null : () => _goToProtocols(context),
            forwardHighlighted: _firstVisit,
          ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF222222),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 10.0),
            child: Icon(
              Icons.fiber_manual_record,
              size: 8,
              color: accentGemini,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
