import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../design_system/tokens/radii.dart';
import '../utils/persian_input.dart';

/// The single entry point for modal bottom sheets.
///
/// Every sheet in the app opens through here so they all behave the same:
/// - never taller than the area below the status bar / notch,
/// - one drag handle,
/// - the painted surface reaches the bottom edge of the screen while its
///   content stays clear of the gesture/navigation bar,
/// - content rises above the keyboard.
///
/// The [builder] supplies only the sheet's content. Content that can grow
/// taller than the screen (forms, lists) must scroll — the frame gives it a
/// bounded height, which shrinks while the keyboard is open. Pass
/// [scrollable] for a plain column of fields that doesn't scroll itself
/// (it must not contain `Expanded`/`Flexible` along the vertical axis).
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollable = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showHandle = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => AppBottomSheet(
      showHandle: showHandle,
      child: scrollable
          ? SingleChildScrollView(child: builder(sheetContext))
          : builder(sheetContext),
    ),
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    // The frame paints the surface, so the route itself stays transparent
    // (otherwise the theme's drag handle floats on the scrim above it).
    backgroundColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
  );
}

/// Sheet surface colour: white in light mode, the raised night tone in dark
/// mode (a sheet sits above the page, so it is one step lighter).
Color appSheetColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.darkSurfaceVariant
    : AppColors.lightSurface;

/// Frame of every bottom sheet: paints the rounded surface, draws the drag
/// handle, keeps [child] above the keyboard and the system navigation bar.
///
/// It consumes those insets: inside the frame `MediaQuery` reports zero
/// bottom padding/insets, so a nested [SafeArea], `viewInsets` padding or a
/// second [AppBottomSheet] can't add them twice. Wrapping an existing
/// sheet body in it again is therefore harmless.
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final bool showHandle;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    // Already inside a frame: the insets are consumed, nothing left to do.
    if (_SheetFrameScope.of(context)) return child;

    final mq = MediaQuery.of(context);
    // With the keyboard up it covers the navigation bar, so the larger of
    // the two is the space to keep clear — never their sum.
    final bottom = math.max(mq.viewInsets.bottom, mq.viewPadding.bottom);

    return _SheetFrameScope(
      child: Material(
        color: appSheetColor(context),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KifinoRadii.bottomSheet),
          ),
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottom),
          child: MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: 0),
              viewPadding: mq.viewPadding.copyWith(bottom: 0),
              viewInsets: mq.viewInsets.copyWith(bottom: 0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHandle) const _DragHandle(),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetFrameScope extends InheritedWidget {
  const _SheetFrameScope({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SheetFrameScope>() != null;

  @override
  bool updateShouldNotify(_SheetFrameScope oldWidget) => false;
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Standard sheet title row with a close button. The drag handle belongs to
/// the frame ([AppBottomSheet]), not to the header.
class AppSheetHeader extends StatelessWidget {
  final String title;

  const AppSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final isFa = isFaLocale(context);
    return Row(
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
    );
  }
}
