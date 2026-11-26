import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/database/company_registry.dart';
import 'package:kifino/core/di/company_controller.dart';
import 'package:kifino/core/di/injection.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform {
  final Directory dir;
  _FakePathProvider(this.dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoucherSettingsService company isolation', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('isolates VoucherAccountSettings across companies', () async {
      final defaultService = VoucherSettingsService(prefs);
      final company2Service = VoucherSettingsService(
        prefs,
        companyId: 'company_2',
      );

      await defaultService.save(
        const VoucherAccountSettings(salesCode: '060999'),
      );
      await company2Service.save(
        const VoucherAccountSettings(salesCode: '060777', bankCode: '010999'),
      );

      expect(defaultService.load().salesCode, equals('060999'));
      expect(
        defaultService.load().bankCode,
        equals(VoucherAccountSettings.defaults.bankCode),
      );
      expect(company2Service.load().salesCode, equals('060777'));
      expect(company2Service.load().bankCode, equals('010999'));
      expect(
        defaultService.storageKey,
        equals('accounting_voucher_account_settings_default'),
      );
      expect(
        company2Service.storageKey,
        equals('accounting_voucher_account_settings_company_2'),
      );
    });

    test('loads legacy unscoped settings only for default company', () async {
      const legacySettings = VoucherAccountSettings(
        salesCode: '060123',
        receivableCode: '012456',
      );
      await prefs.setString(
        VoucherSettingsService.legacyStorageKey,
        legacySettings.encode(),
      );

      final defaultService = VoucherSettingsService(prefs);
      final company2Service = VoucherSettingsService(
        prefs,
        companyId: 'company_2',
      );

      expect(defaultService.load().salesCode, equals('060123'));
      expect(defaultService.load().receivableCode, equals('012456'));
      // Non-default companies must NOT inherit legacy default settings.
      expect(
        company2Service.load().salesCode,
        equals(VoucherAccountSettings.defaults.salesCode),
      );
      expect(
        company2Service.load().receivableCode,
        equals(VoucherAccountSettings.defaults.receivableCode),
      );
    });
  });

  group('ServiceLocator company scope & shared root dependencies', () {
    late Directory tempDir;

    setUp(() async {
      await sl.reset(dispose: true);
      tempDir = await Directory.systemTemp.createTemp('kifino_di_test_');
      PathProviderPlatform.instance = _FakePathProvider(tempDir);
      SharedPreferences.setMockInitialValues({});

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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'dev.fluttercommunity.plus/connectivity_status',
            ),
            (call) async => null,
          );
    });

    tearDown(() async {
      await sl.reset(dispose: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('switching company via ServiceLocator.init isolates VoucherSettingsService, injects singleton into AutoVoucherService, shares root FlutterSecureStorage, and disposes AppDatabase cleanly', () async {
      await ServiceLocator.initRoot();
      final rootStorage = sl<FlutterSecureStorage>();

      // Initialize default company scope
      await ServiceLocator.init(companyId: CompanyRegistry.defaultCompanyId);
      final defaultStorage = sl<FlutterSecureStorage>();
      final defaultDb = sl<AppDatabase>();
      final defaultVoucherSettings = sl<VoucherSettingsService>();
      final defaultAutoVoucher = sl<AutoVoucherService>();

      expect(identical(rootStorage, defaultStorage), isTrue);
      expect(
        identical(defaultAutoVoucher.settingsService, defaultVoucherSettings),
        isTrue,
      );
      expect(
        defaultVoucherSettings.companyId,
        equals(CompanyRegistry.defaultCompanyId),
      );

      await defaultVoucherSettings.save(
        const VoucherAccountSettings(salesCode: '060111'),
      );
      expect(defaultAutoVoucher.settingsService.load().salesCode, '060111');

      // Switch via CompanyController (tests _closeActiveDatabaseSafely +
      // AppDatabase dispose callback together without double-close errors).
      final controller = sl<CompanyController>();
      await controller.initialize();
      await controller.switchTo('company_2');

      final company2Storage = sl<FlutterSecureStorage>();
      final company2Db = sl<AppDatabase>();
      final company2VoucherSettings = sl<VoucherSettingsService>();
      final company2AutoVoucher = sl<AutoVoucherService>();

      expect(identical(rootStorage, company2Storage), isTrue);
      expect(identical(defaultDb, company2Db), isFalse);
      expect(company2VoucherSettings.companyId, equals('company_2'));
      expect(
        identical(company2AutoVoucher.settingsService, company2VoucherSettings),
        isTrue,
      );
      // Company 2 starts with defaults, isolated from default company's '060111'.
      expect(
        company2AutoVoucher.settingsService.load().salesCode,
        equals(VoucherAccountSettings.defaults.salesCode),
      );

      await company2VoucherSettings.save(
        const VoucherAccountSettings(salesCode: '060222'),
      );
      expect(company2AutoVoucher.settingsService.load().salesCode, '060222');

      // Switching back preserves default company's settings.
      await controller.switchTo(CompanyRegistry.defaultCompanyId);
      expect(
        sl<AutoVoucherService>().settingsService.load().salesCode,
        equals('060111'),
      );
    });
  });
}
