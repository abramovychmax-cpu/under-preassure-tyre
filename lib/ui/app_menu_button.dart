import 'package:flutter/material.dart';
import '../safety_guide_page.dart';
import '../sensor_setup_page.dart';
import '../wheel_metrics_page.dart';
import 'common_widgets.dart';

/// Three-dot menu button giving quick access to setup pages from anywhere in the app.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Color(0xFF222222)),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'wheel':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WheelMetricsPage()));
          case 'safety':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyGuidePage()));
          case 'sensors':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SensorSetupPage()));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'wheel',
          child: Row(children: [
            Icon(Icons.tune, color: accentGemini, size: 20),
            SizedBox(width: 12),
            Text('Wheel Setup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'safety',
          child: Row(children: [
            Icon(Icons.shield_outlined, color: accentGemini, size: 20),
            SizedBox(width: 12),
            Text('Safety Guide', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'sensors',
          child: Row(children: [
            Icon(Icons.sensors, color: accentGemini, size: 20),
            SizedBox(width: 12),
            Text('Sensor Setup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    );
  }
}

/// Use this on full-screen pages (no AppBar) — wraps [child] in a Stack
/// with the menu button positioned top-right.
class AppMenuOverlay extends StatelessWidget {
  final Widget child;
  const AppMenuOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          top: 0,
          right: 0,
          child: SafeArea(child: AppMenuButton()),
        ),
      ],
    );
  }
}
