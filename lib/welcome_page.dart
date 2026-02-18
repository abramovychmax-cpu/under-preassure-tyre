import 'package:flutter/material.dart';
import 'sensor_guide_page.dart';
import 'previous_tests_page.dart';
import 'ui/common_widgets.dart';
import 'dart:math' as math;

/// Modern Welcome/Entry Page
/// Swipeable iPhone-style onboarding with cycling wheel visual
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
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
      begin: const Offset(0, 0.15),
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
        pageBuilder: (context, animation, secondaryAnimation) => const SensorGuidePage(),
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
          child: Stack(
            children: [
              // Main Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Previous Results Button (Top Left)
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.assessment, color: Color(0xFF888888)),
                        tooltip: 'Previous Results',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PreviousTestsPage()),
                          );
                        },
                      ),
                    ),
                    
                    const Spacer(flex: 2),
                    
                    // Hero Section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: const Column(
                          children: [
                            // Cycling Wheel Icon (Side View)
                            CyclingWheelIcon(size: 160),
                            
                            SizedBox(height: 48),
                            
                            // App Name - Keep as is
                            Text(
                              'PERFECT\nPRESSURE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF222222),
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                height: 1.1,
                              ),
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Descriptive Text
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'This app will help you find the fastest tire pressure for you and your bike setup.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 16),
                            
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Get ready to set up the app.',
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Painted Cycling Wheel (Side View)
/// Draws a realistic bike wheel with spokes and tire
class CyclingWheelIcon extends StatelessWidget {
  final double size;
  
  const CyclingWheelIcon({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WheelPainter(),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Tire (outer ring) - thicker, darker
    final tirePaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    
    canvas.drawCircle(center, radius - 4, tirePaint);
    
    // Rim (inner circle) - teal accent
    final rimPaint = Paint()
      ..color = const Color(0x4D47D1C1) // accentGemini with 30% opacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(center, radius - 16, rimPaint);
    
    // Hub (center) - solid teal
    final hubPaint = Paint()
      ..color = accentGemini
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 8, hubPaint);
    
    // Spokes - 16 radial lines from hub to rim
    final spokePaint = Paint()
      ..color = const Color(0x66666666) // Grey with 40% opacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    for (int i = 0; i < 16; i++) {
      final angle = (i * 360 / 16) * math.pi / 180;
      final spokeStart = Offset(
        center.dx + 8 * math.cos(angle),
        center.dy + 8 * math.sin(angle),
      );
      final spokeEnd = Offset(
        center.dx + (radius - 16) * math.cos(angle),
        center.dy + (radius - 16) * math.sin(angle),
      );
      canvas.drawLine(spokeStart, spokeEnd, spokePaint);
    }
    
    // Valve stem (small detail at bottom for realism)
    final valvePaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.fill;
    
    final valveRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius - 4),
      width: 3,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(valveRect, const Radius.circular(1.5)),
      valvePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
