import 'package:flutter/material.dart';

/// Color constants used throughout the app

// Light theme colors
const Color bgLight = Color(0xFFFAFAFA);

// Dark theme colors  
const Color bgDark = Color(0xFF121418);
const Color cardGrey = Color(0xFF1E2228);

// Accent colors
const Color accentGemini = Color(0xFF47D1C1);

// Border colors
const Color cardBorder = Color(0xFFDDDDDD);

/// Common card widget with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // Black with 5% opacity
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Navigation bar for onboarding pages.
/// Back chevron on the left (hidden when [onBack] is null — first page).
/// Forward button (dark rounded box) on the right; greyed when [onForward] is null.
class OnboardingNavBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  const OnboardingNavBar({super.key, this.onBack, this.onForward});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (onBack != null)
              GestureDetector(
                onTap: onBack,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.chevron_left, color: accentGemini, size: 32),
                ),
              )
            else
              const SizedBox(width: 48),
            GestureDetector(
              onTap: onForward,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: onForward != null
                      ? const Color(0xFF222222)
                      : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
