import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/app/localization/app_localizations.dart';
import 'package:kifino/app/localization/persian_localizations.dart';
import 'package:kifino/core/widgets/app_date_picker.dart';

Widget _buildTestApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('fa', 'IR'), Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      AppPersianMaterialLocalizations.delegate,
      AppPersianCupertinoLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  group('App Date Picker Persian Tests', () {
    testWidgets(
      'showAppDatePicker opens Shamsi picker and displays Persian months and returns correct DateTime',
      (tester) async {
        DateTime? selectedDate;

        await tester.pumpWidget(
          _buildTestApp(
            locale: const Locale('fa'),
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedDate = await showAppDatePicker(
                      context: context,
                      initialDate: DateTime(
                        2026,
                        3,
                        21,
                      ), // 1405-01-01 in Jalali
                    );
                  },
                  child: const Text('Pick Date'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pick Date'));
        await tester.pumpAndSettle();

        // Check if Persian month 'فروردین' is displayed in header/calendar
        expect(find.textContaining('فروردین'), findsWidgets);

        // Verify Persian digits in year header
        expect(find.textContaining('۱۴۰۵'), findsWidgets);

        // Tap 'تأیید'
        expect(find.text('تأیید'), findsOneWidget);
        await tester.tap(find.text('تأیید'));
        await tester.pumpAndSettle();

        expect(selectedDate, isNotNull);
        // Selected date should be year 2026, NOT year 1405
        expect(selectedDate!.year, equals(2026));
        expect(selectedDate!.month, equals(3));
        expect(selectedDate!.day, equals(21));
      },
    );

    testWidgets(
      'showAppDatePicker handles default bounds safely with DateTime.now()',
      (tester) async {
        DateTime? selectedDate;

        await tester.pumpWidget(
          _buildTestApp(
            locale: const Locale('fa'),
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedDate = await showAppDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                    );
                  },
                  child: const Text('Pick Date'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pick Date'));
        await tester.pumpAndSettle();

        // Dialog must be open and have confirm button
        expect(find.text('تأیید'), findsOneWidget);
        expect(find.text('انصراف'), findsOneWidget);

        await tester.tap(find.text('انصراف'));
        await tester.pumpAndSettle();

        expect(selectedDate, isNull);
      },
    );

    testWidgets(
      'showAppDatePicker clamps safely when initialDate is before firstDate',
      (tester) async {
        DateTime? selectedDate;
        final now = DateTime(2026, 6, 15);

        await tester.pumpWidget(
          _buildTestApp(
            locale: const Locale('fa'),
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedDate = await showAppDatePicker(
                      context: context,
                      initialDate: now.subtract(const Duration(days: 10)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 30)),
                    );
                  },
                  child: const Text('Pick Date'),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pick Date'));
        await tester.pumpAndSettle();

        expect(find.text('تأیید'), findsOneWidget);
        await tester.tap(find.text('تأیید'));
        await tester.pumpAndSettle();

        expect(selectedDate, isNotNull);
        // It clamped to 'firstDate' (now)
        expect(selectedDate!.year, equals(now.year));
        expect(selectedDate!.month, equals(now.month));
        expect(selectedDate!.day, equals(now.day));
      },
    );

    testWidgets(
      'AppPersianMaterialLocalizations formats dates and numbers with Persian digits',
      (tester) async {
        const loc = AppPersianMaterialLocalizations();
        expect(loc.formatDecimal(42), equals('۴۲'));
        expect(loc.formatYear(DateTime(2026, 3, 21)), equals('۱۴۰۵'));
        expect(loc.okButtonLabel, equals('تأیید'));
        expect(loc.cancelButtonLabel, equals('لغو'));
      },
    );
  });
}
