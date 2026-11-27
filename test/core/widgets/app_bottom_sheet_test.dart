import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/widgets/app_bottom_sheet.dart';

/// The shared sheet frame must keep content clear of the system navigation
/// bar and the keyboard, while its painted surface still reaches the bottom
/// edge (no see-through strip under the sheet).
void main() {
  const screen = Size(400, 800);
  const navBar = 34.0;
  const keyboard = 300.0;

  late MediaQueryData inner;

  Future<void> openSheet(
    WidgetTester tester, {
    double insetBottom = 0,
    bool nested = false,
  }) async {
    tester.view
      ..physicalSize = screen
      ..devicePixelRatio = 1
      ..viewPadding = const FakeViewPadding(bottom: navBar)
      // Android reports padding = max(viewPadding - viewInsets, 0).
      ..padding = FakeViewPadding(bottom: insetBottom > 0 ? 0 : navBar)
      ..viewInsets = FakeViewPadding(bottom: insetBottom);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAppModalSheet<void>(
                  context: context,
                  builder: (_) {
                    final body = Builder(
                      builder: (ctx) {
                        inner = MediaQuery.of(ctx);
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(),
                              SizedBox(
                                key: Key('save'),
                                height: 48,
                                width: double.infinity,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    // A sheet body that still wraps itself (legacy pattern).
                    return nested
                        ? AppBottomSheet(child: SafeArea(child: body))
                        : body;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Rect saveRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const Key('save')));

  Rect surfaceRect(WidgetTester tester) => tester.getRect(
    find
        .ancestor(of: find.byType(TextField), matching: find.byType(Material))
        .last,
  );

  testWidgets('content clears the navigation bar; surface reaches the edge', (
    tester,
  ) async {
    await openSheet(tester);

    expect(saveRect(tester).bottom, lessThanOrEqualTo(screen.height - navBar));
    expect(surfaceRect(tester).bottom, screen.height);
    // Insets are consumed, so nothing inside can add them a second time.
    expect(inner.padding.bottom, 0);
    expect(inner.viewInsets.bottom, 0);
  });

  testWidgets('content rises above the keyboard (no nav-bar double count)', (
    tester,
  ) async {
    await openSheet(tester, insetBottom: keyboard);

    final bottom = saveRect(tester).bottom;
    expect(bottom, lessThanOrEqualTo(screen.height - keyboard));
    // Exactly the keyboard's height is reserved, not keyboard + nav bar
    // (16 = the body's own padding).
    expect(bottom, closeTo(screen.height - keyboard - 16, 0.5));
  });

  testWidgets('a nested AppBottomSheet/SafeArea adds no extra space', (
    tester,
  ) async {
    await openSheet(tester);
    final plain = saveRect(tester).bottom;

    await tester.pumpWidget(const SizedBox());
    await openSheet(tester, nested: true);

    expect(saveRect(tester).bottom, plain);
  });

  testWidgets('draws exactly one drag handle', (tester) async {
    await openSheet(tester, nested: true);

    final handles = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == 36 &&
          w.constraints?.maxHeight == 4,
    );
    expect(handles, findsOneWidget);
  });
}
