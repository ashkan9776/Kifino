import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/core/widgets/app_amount_field.dart';

/// Regression test for the quick-amount chips bug: external changes via
/// [ValueNotifier] must appear inside the field (chips previously updated
/// only the page variable and the field stayed empty).
void main() {
  late ValueNotifier<int> amountNotifier;

  Future<void> pumpField(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppAmountField(
            currency: Currency.toman,
            amountNotifier: amountNotifier,
            onAmountMinorChanged: (_) {},
            autoFocus: false,
            usePersianDigits: false,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    amountNotifier = ValueNotifier<int>(0);
  });

  testWidgets('chip-style external increment fills the field', (tester) async {
    await pumpField(tester);

    // Simulate a quick chip: +50,000
    amountNotifier.value += 50000;
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, equals('50,000'));

    // Another chip: +100,000 → cumulative 150,000
    amountNotifier.value += 100000;
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      equals('150,000'),
    );
  });

  testWidgets('typing pushes back into the notifier (two-way sync)', (
    tester,
  ) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), '2,500');
    await tester.pump();

    expect(amountNotifier.value, equals(2500));
  });

  testWidgets('external set to zero clears the field', (tester) async {
    amountNotifier.value = 120000;
    await pumpField(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      equals('120,000'),
    );

    amountNotifier.value = 0;
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      equals('0'), // zero renders like typing 0
    );
  });
}
