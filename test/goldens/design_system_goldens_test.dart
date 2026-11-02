import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/app/theme/app_theme.dart';
import 'package:kifino/core/design_system/components/financial/app_metric_card.dart';
import 'package:kifino/core/design_system/components/financial/app_status_badge.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/core/widgets/app_button.dart';
import 'package:kifino/core/widgets/app_card.dart';
import 'package:kifino/core/widgets/app_money_text.dart';
import 'package:kifino/core/widgets/app_transaction_tile.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

/// Golden tests for critical Design System components (§75).
/// Regenerate with:  flutter test --update-goldens test/goldens/
void main() {
  group('Design System goldens', () {
    Future<void> pumpShot(
      WidgetTester tester,
      Widget child,
      String goldenName, {
      bool dark = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(360, 160));
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$goldenName.png'),
      );
    }

    // Real font (not Ahem blocks) so goldens are meaningful.
    setUpAll(() async {
      final regular = await rootBundle.load(
        'packages/vazirmatn/fonts/Vazirmatn-Regular.ttf',
      );
      final bold = await rootBundle.load(
        'packages/vazirmatn/fonts/Vazirmatn-Bold.ttf',
      );
      final loader = FontLoader('Vazirmatn')
        ..addFont(Future.value(regular))
        ..addFont(Future.value(bold));
      await loader.load();
    });

    testWidgets('primary button (light)', (tester) async {
      await pumpShot(
        tester,
        AppButton(label: 'ثبت هزینه', onPressed: () {}),
        'app_button_primary_light',
      );
    });

    testWidgets('status badges (light)', (tester) async {
      await pumpShot(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppStatusBadge(
              label: 'پرداخت شد',
              icon: Icons.check_rounded,
              tone: AppStatusTone.success,
            ),
            SizedBox(height: 8),
            AppStatusBadge(
              label: 'معوق',
              icon: Icons.error_outline_rounded,
              tone: AppStatusTone.danger,
            ),
          ],
        ),
        'app_status_badges_light',
      );
    });

    testWidgets('metric card (light)', (tester) async {
      await pumpShot(
        tester,
        AppMetricCard(
          label: 'درآمد',
          value: Money.fromMinor(12500000, Currency.toman),
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF25C997),
          sign: MoneyDisplaySign.positiveNegative,
        ),
        'app_metric_card_light',
      );
    });

    testWidgets('transaction tile (dark)', (tester) async {
      await pumpShot(
        tester,
        AppCard(
          child: AppTransactionTile(
            transaction: TransactionEntity(
              id: 'demo',
              accountId: 'demo',
              amount: Money.fromMinor(850000, Currency.toman),
              type: TransactionType.expense,
              date: DateTime(2026, 10, 1, 12, 30),
              description: 'رستوران',
              createdAt: DateTime(2026, 10, 1),
              updatedAt: DateTime(2026, 10, 1),
            ),
          ),
        ),
        'app_transaction_tile_dark',
        dark: true,
      );
    });

    testWidgets('money text compact (light)', (tester) async {
      await pumpShot(
        tester,
        AppMoneyText(
          money: Money.fromMinor(248500000, Currency.toman),
          style: AppTheme.lightTheme.textTheme.headlineSmall,
        ),
        'app_money_text_light',
      );
    });
  });
}
