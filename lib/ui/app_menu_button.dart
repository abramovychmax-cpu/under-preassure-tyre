import 'package:flutter/material.dart';
import '../safety_guide_page.dart';
import '../sensor_setup_page.dart';
import '../wheel_metrics_page.dart';
import 'common_widgets.dart';

/// Opens [page] as a modal overlay that slides up from the bottom.
/// A floating × button lets the user dismiss and return to wherever they came from.
void openMenuOverlay(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, _) {
        return Stack(
          children: [
            page,
            // Floating close button — sits above the page's own AppBar
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 4,
              left: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close, size: 20, color: Color(0xFF222222)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionsBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

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
            openMenuOverlay(context, const WheelMetricsPage(isOverlay: true));
          case 'safety':
            openMenuOverlay(context, const SafetyGuidePage(isOverlay: true));
          case 'sensors':
            openMenuOverlay(context, const SensorSetupPage(isOverlay: true));
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
            Text('Safety & Guidelines', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
