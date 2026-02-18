import 'package:flutter/material.dart';
import 'sensor_setup_page.dart';
import 'ui/common_widgets.dart';

/// Sensor Setup Guide Page
/// Brief preparation instructions before sensor pairing
class SensorGuidePage extends StatefulWidget {
  const SensorGuidePage({super.key});

  @override
  State<SensorGuidePage> createState() => _SensorGuidePageState();
}

class _SensorGuidePageState extends State<SensorGuidePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _swipeSlideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _swipeSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: const Offset(0, -0.1),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToSetup() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SensorSetupPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // Swipe up to continue
          if (details.primaryVelocity! < -500) {
            _navigateToSetup();
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                const Spacer(flex: 2),
                
                // Main Content
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: const Column(
                      children: [
                        // Icon
                        Icon(
                          Icons.sensors,
                          size: 80,
                          color: accentGemini,
                        ),
                        
                        SizedBox(height: 48),
                        
                        // Main Title
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
                        
                        // Instructions
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Please prepare to connect all needed sensors to run tests.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Hint
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Turn on your Bluetooth sensors and keep them nearby.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(flex: 3),
                
                // Swipe Up Indicator
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _swipeSlideAnimation,
                    child: const Column(
                      children: [
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: accentGemini,
                          size: 32,
                        ),
                        Text(
                          'SWIPE UP TO CONTINUE',
                          style: TextStyle(
                            color: accentGemini,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
