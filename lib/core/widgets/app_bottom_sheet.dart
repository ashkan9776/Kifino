import 'package:flutter/material.dart';

import '../utils/persian_input.dart';

/// Standard wrapper for every `showModalBottomSheet` body: keeps content
/// clear of the system gesture nav bar and above the keyboard, so buttons
/// never end up hidden underneath either.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (ctx) => AppBottomSheet(
///     child: Padding(padding: ..., child: Column(...)),
///   ),
/// );
/// ```
class AppBottomSheet extends StatelessWidget {
  final Widget child;

  const AppBottomSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Keyboard height beyond what SafeArea already covers, so we never
    // double-count the gesture nav bar inset.
    final extraKeyboard =
        (mq.viewInsets.bottom - mq.padding.bottom).clamp(0.0, double.infinity);

    return Padding(
      padding: EdgeInsets.only(bottom: extraKeyboard),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Standard sheet header: grab-handle look, title, and optional close button.
class AppSheetHeader extends StatelessWidget {
  final String title;

  const AppSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isFa = isFaLocale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ],
        ),
      ],
    );
  }
}
