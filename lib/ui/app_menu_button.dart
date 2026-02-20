import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../analysis_page.dart';
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

/// Opens [page] as a 90 % height partial overlay with slide-up animation.
/// A semi-transparent scrim fills the top 10 %; tapping it dismisses the overlay.
void openPartialOverlay(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, _) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return Stack(
          children: [
            // Semi-transparent scrim — tapping closes the overlay
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),
            // 90 % content panel
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.9,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: page,
                  ),
                  // Floating close button at top-right of panel
                  Positioned(
                    top: 8,
                    right: 8,
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

/// Opens the most recently saved AnalysisPage result from SharedPreferences.
Future<void> _openLastAnalysis(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getStringList('test_keys') ?? [];
  if (keys.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No past results found. Complete a session first.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  final lastKey = keys.last;
  final raw = prefs.getString(lastKey);
  if (raw == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not load last result.'), behavior: SnackBarBehavior.floating),
    );
    return;
  }
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final fitPath  = data['fitFilePath'] as String? ?? '';
  final protocol = data['protocol']    as String? ?? 'coast_down';
  final bikeType = data['bikeType']    as String? ?? 'road';
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AnalysisPage(
        fitFilePath: fitPath,
        protocol: protocol,
        bikeType: bikeType,
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
            openPartialOverlay(context, const WheelMetricsPage(isOverlay: true));
          case 'safety':
            openMenuOverlay(context, const SafetyGuidePage(isOverlay: true));
          case 'sensors':
            openMenuOverlay(context, const SensorSetupPage(isOverlay: true));
          case 'results':
            _openLastAnalysis(context);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'results',
          child: Row(children: [
            Icon(Icons.bar_chart, color: accentGemini, size: 20),
            SizedBox(width: 12),
            Text('Past Results', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'wheel',
          child: Row(children: [
            Icon(Icons.tune, color: accentGemini, size: 20),
            SizedBox(width: 12),
            Text('Metrics Setup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
