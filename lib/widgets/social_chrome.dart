import 'package:flutter/material.dart';

class SocialBackground extends StatelessWidget {
  final Widget child;
  final bool showOrbs;

  const SocialBackground({
    super.key,
    required this.child,
    this.showOrbs = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF020405),
                Color(0xFF020405),
                Color(0xFF010304),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0),
              radius: 0.95,
              colors: [
                Color(0x1722C55E),
                Color(0x0016A34A),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8, -0.9),
              radius: 1.2,
              colors: [
                Color(0x332DD4BF),
                Color(0x00141F1C),
              ],
            ),
          ),
        ),
        if (showOrbs) ...[
          Positioned(
            top: -90,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22D3EE).withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            top: 170,
            right: -55,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF34D399).withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -45,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF99F6E4).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2DD4BF).withValues(alpha: 0.12),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

class SocialPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SocialPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 20, 12, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: padding,
          child: IconTheme(
            data: const IconThemeData(color: Colors.white70),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
