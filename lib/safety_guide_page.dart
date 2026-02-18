import 'package:flutter/material.dart';
import 'protocol_selection_page.dart';
import 'ui/common_widgets.dart';

/// Safety & Testing Guidelines shown before protocol selection
/// Displays common rules that apply to all three testing protocols
class SafetyGuidePage extends StatefulWidget {
  const SafetyGuidePage({super.key});

  @override
  State<SafetyGuidePage> createState() => _SafetyGuidePageState();
}

class _SafetyGuidePageState extends State<SafetyGuidePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bgLight,
        elevation: 0,
        title: const Text(
          'SAFETY & TESTING',
          style: TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        foregroundColor: const Color(0xFF222222),
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const ProtocolSelectionPage(),
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

              // Safety Section
              _sectionHeader('🛡️ Safety'),
              _bulletPoint('Choose routes with minimal or no traffic.'),
              _bulletPoint('Never exceed the max or minimum pressure for your tire/rim combo.'),
              const SizedBox(height: 24),

              // Consistency Section
              _sectionHeader('🎯 Consistency'),
              _bulletPoint('Ride manageable terrain and keep power and speed steady.'),
              const SizedBox(height: 24),

              // Position Section
              _sectionHeader('📏 Position'),
              _bulletPoint('Keep the same body position every run for reliable results.'),
              const SizedBox(height: 24),

              // Runs Section
              _sectionHeader('🔢 Runs'),
              _bulletPoint('Perform at least three runs at different pressures.'),
              const SizedBox(height: 40),

              // Swipe Up Indicator
              Center(
                child: FadeTransition(
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
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
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

  Widget _bulletPoint(String text) {
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
