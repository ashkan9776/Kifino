import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/app/app.dart';
import 'package:kifino/core/database/company_registry.dart';
import 'package:kifino/core/di/company_controller.dart';
import 'package:kifino/core/di/injection.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the real startup path (Phase 5): initRoot → company-
/// scoped init → pump KifinoApp. A missing DI registration here shows up to
/// users as a grey screen — this test catches it before release.
class FakePathProviderPlatform extends PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kifino_bootstrap_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    SharedPreferences.setMockInitialValues({
      'pref_onboarding_completed': true, // simulate a returning user
    });

    // Platform channels that have no test implementation — mock them so the
    // real bootstrap path does not surface MissingPluginException.
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['none'],
    );
    // The connectivity_status EventChannel shares its name with a method
    // channel — mocking by NAME intercepts the 'listen' call.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (call) async => null,
    );
  });

  tearDown(() async {
    await sl.reset(dispose: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('real bootstrap (initRoot + company-scope init) renders the app',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    // The exact sequence main() runs. runAsync escapes the FakeAsync zone so
    // the drift background isolate can complete in real time.
    await tester.runAsync(() async {
      await ServiceLocator.initRoot();
      await ServiceLocator.init(companyId: CompanyRegistry.defaultCompanyId);

      expect(sl.isRegistered<CompanyController>(), isTrue,
          reason: 'CompanyController must be registered in the root scope');
      expect(sl.isRegistered<VoucherSettingsService>(), isTrue);
    });

    await tester.pumpWidget(const KifinoApp());
    await tester.pump(const Duration(seconds: 1));

    // Let real (non-fake-async) file IO from the DB isolate flush.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));

    // Navigation shell rendered — i.e. no grey screen / build exception.
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);

    // Company database file exists after first use.
    final dirList = tempDir.listSync(recursive: true).map((e) => e.path).join(', ');
    final dbFile = File(
      '${tempDir.path}/${CompanyRegistry.dbFileNameFor(CompanyRegistry.defaultCompanyId)}',
    );
    expect(dbFile.existsSync(), isTrue,
        reason: 'company database file must exist after first use — found: [$dirList]');

    // Unmount and flush pending timers (SyncBloc's auto-sync timer) before
    // the test ends, mirroring widget_test.dart's teardown pattern.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
