import 'package:flutter/material.dart';
import 'sensor_service.dart';
import 'sensor_setup_page.dart';
import 'ui/app_menu_button.dart';
import 'ui/common_widgets.dart';

class SensorGuidePage extends StatelessWidget {
  const SensorGuidePage({super.key});

  void _navigateToSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SensorSetupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: AppMenuOverlay(
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -200 && !SensorService().isSessionActive) {
            _navigateToSetup(context);
          }
        },
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(height: 60),
                Spacer(flex: 2),
                Column(
                  children: [
                    Icon(
                      Icons.sensors,
                      size: 80,
                      color: accentGemini,
                    ),
                    SizedBox(height: 48),
                    Text(
                      'SENSOR SETUP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 32),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Please prepare to connect all needed sensors to run tests.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Activate your Bluetooth sensors and keep them nearby.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Spacer(flex: 3),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_left,
                        color: accentGemini,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'SWIPE TO CONTINUE',
                        style: TextStyle(
                          color: accentGemini,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(top: false, child: SizedBox(height: 16)),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
