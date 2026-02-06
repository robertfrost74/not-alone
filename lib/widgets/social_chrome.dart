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

class SocialDialogContent extends StatelessWidget {
  final Widget child;

  const SocialDialogContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }
}

class SocialSheetContent extends StatelessWidget {
  final Widget child;

  const SocialSheetContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }
}

class SocialChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const SocialChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // App standard chip style (use across the app except login screens).
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: const Color(0xFF2DD4CF),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: const Color(0xFF0E1D1C),
      selectedColor: const Color(0xFF0E1D1C),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? const Color(0xFF2DD4CF) : Colors.white24,
        ),
      ),
      onSelected: onSelected,
    );
  }
}

class SocialDialog extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final List<Widget> actions;
  final EdgeInsets insetPadding;
  final EdgeInsets titlePadding;
  final EdgeInsets contentPadding;
  final EdgeInsets actionsPadding;
  final Color backgroundColor;
  final ShapeBorder shape;
  final TextStyle? titleTextStyle;
  final TextStyle? contentTextStyle;

  const SocialDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const [],
    this.insetPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
    this.titlePadding = const EdgeInsets.fromLTRB(20, 18, 20, 8),
    this.contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 16),
    this.actionsPadding = const EdgeInsets.fromLTRB(20, 0, 20, 16),
    this.backgroundColor = const Color(0xFF0F1A1A),
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      side: BorderSide(color: Colors.white24),
    ),
    this.titleTextStyle,
    this.contentTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTitleStyle = DefaultTextStyle.of(context).style.copyWith(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        );
    final defaultContentStyle = DefaultTextStyle.of(context).style.copyWith(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        );

    return Dialog(
      insetPadding: insetPadding,
      backgroundColor: backgroundColor,
      shape: shape,
      child: TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: titlePadding,
                  child: DefaultTextStyle(
                    style: titleTextStyle ?? defaultTitleStyle,
                    child: title!,
                  ),
                ),
              Padding(
                padding: contentPadding,
                child: DefaultTextStyle(
                  style: contentTextStyle ?? defaultContentStyle,
                  child: content,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: actionsPadding,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
