import 'package:flutter/gestures.dart';
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
/// Forward chevron on the right (greyed when [onForward] is null).
/// Optional [statusText] and [statusColor] shown centred between the chevrons.
class OnboardingNavBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final String? statusText;
  final Color? statusColor;
  final bool forwardHighlighted;
  const OnboardingNavBar({
    super.key,
    this.onBack,
    this.onForward,
    this.statusText,
    this.statusColor,
    this.forwardHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Row(
          children: [
            // Left chevron
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
            // Centre status text
            Expanded(
              child: statusText != null
                  ? Text(
                      statusText!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusColor ?? Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Right forward chevron
            GestureDetector(
              onTap: onForward,
              child: SizedBox(
                width: 48,
                height: 48,
                child: forwardHighlighted && onForward != null
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                      )
                    : Icon(
                        Icons.chevron_right,
                        color: onForward != null ? accentGemini : const Color(0xFFCCCCCC),
                        size: 32,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds a 32px transparent strip on the right edge that responds to leftward
/// swipes — mirroring how iOS restricts back-swipe to the left edge only.
/// Fires mid-drag (50 px threshold) so it feels as instant as native back.
class RightEdgeSwipeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeForward;

  const RightEdgeSwipeDetector({
    super.key,
    required this.child,
    this.onSwipeForward,
  });

  @override
  State<RightEdgeSwipeDetector> createState() => _RightEdgeSwipeDetectorState();
}

class _RightEdgeSwipeDetectorState extends State<RightEdgeSwipeDetector> {
  double _startX = 0;
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onSwipeForward == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 32,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (details) {
              _startX = details.globalPosition.dx;
              _fired = false;
            },
            onHorizontalDragUpdate: (details) {
              if (_fired) return;
              final delta = details.globalPosition.dx - _startX;
              if (delta < -50) {
                _fired = true;
                widget.onSwipeForward!();
              }
            },
            onHorizontalDragEnd: (_) => _fired = false,
          ),
        ),
      ],
    );
  }
}
