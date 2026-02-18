import 'package:flutter/material.dart';
import 'protocol_selection_page.dart';
import 'ui/common_widgets.dart';

class SafetyGuidePage extends StatelessWidget {
  const SafetyGuidePage({super.key});

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
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            _goToProtocols(context);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'UNIVERSAL RULES',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF222222),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'These guidelines apply to all testing protocols.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              _sectionHeader('🛡️ Safety'),
              _bulletPoint('Choose routes with minimal or no traffic.'),
              _bulletPoint('Never exceed the max or minimum pressure for your tire/rim combo.'),
              const SizedBox(height: 24),
              _sectionHeader('🎯 Consistency'),
              _bulletPoint('Ride manageable terrain and keep power and speed steady.'),
              const SizedBox(height: 24),
              _sectionHeader('📏 Position'),
              _bulletPoint('Keep the same body position every run for reliable results.'),
              const SizedBox(height: 24),
              _sectionHeader('🔢 Runs'),
              _bulletPoint('Perform at least three runs at different pressures.'),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.keyboard_arrow_up,
                      color: accentGemini,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'SWIPE UP OR TAP CONTINUE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accentGemini,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGemini,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _goToProtocols(context),
                      child: const Text('CONTINUE'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF222222),
          letterSpacing: 0.8,
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
                fontSize: 15,
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
