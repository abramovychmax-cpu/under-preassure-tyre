import 'package:flutter/material.dart';
import 'sensor_setup_page.dart';
import 'previous_tests_page.dart';
import 'ui/common_widgets.dart';

/// Home/Intro page: Two options for user
/// 1. See Previous Tests - view past optimal pressures
/// 2. Start New Test - begin a new tire pressure optimization session
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Title
              const Column(
                children: [
                  Text(
                    'PERFECT PRESSURE',
                    style: TextStyle(
                      color: accentGemini,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find your optimal tire pressure',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),

              // See Previous Tests Button
              _buildActionButton(
                label: 'SEE PREVIOUS TESTS',
                icon: Icons.history,
                color: const Color(0xFF444444),
                isFilled: false,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PreviousTestsPage()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Start New Test Button
              _buildActionButton(
                label: 'START NEW TEST',
                icon: Icons.add_circle,
                color: accentGemini,
                isFilled: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SensorSetupPage()),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a large action button with icon and label
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isFilled = false,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFilled ? color : Colors.white,
          foregroundColor: isFilled ? Colors.white : color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isFilled ? BorderSide.none : BorderSide(color: color.withOpacity(0.2), width: 1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
