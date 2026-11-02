import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../database/company_registry.dart';
import 'injection.dart';

/// Orchestrates multi-company lifecycle (Phase 5): create/switch/delete
/// companies. Each company owns a separate SQLite file; switching disposes
/// the company-scoped singletons and re-initializes them against the new
/// file, then the widget tree rebuilds under a new company key.
class CompanyController extends ChangeNotifier {
  final CompanyRegistry registry;

  bool _switching = false;
  bool _initialized = false;

  bool get initialized => _initialized;

  CompanyController(this.registry);

  String get activeCompanyId => registry.activeCompanyId;

  bool get isSwitching => _switching;

  /// Must be called once at bootstrap before the first frame.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await registry.getCompanies(); // seeds default company on first run
    notifyListeners();
  }

  Future<List<CompanyInfo>> companies() => registry.getCompanies();

  /// Creates a new company and immediately switches to it.
  Future<CompanyInfo> createCompany(String name) async {
    final company = await registry.addCompany(name);
    await switchTo(company.id);
    return company;
  }

  /// Switches the active company: closes the old database, resets the
  /// company scope and re-initializes every service against the new file.
  Future<void> switchTo(String companyId) async {
    if (companyId == registry.activeCompanyId || _switching) return;
    _switching = true;
    notifyListeners();
    try {
      await _closeActiveDatabaseSafely();
      await ServiceLocator.init(companyId: companyId);
      await registry.setActiveCompanyId(companyId);
      notifyListeners();
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  /// Deletes a non-active company and its database file. The default
  /// company cannot be deleted (registry enforces this too).
  Future<void> deleteCompany(String companyId) async {
    assert(
      companyId != CompanyRegistry.defaultCompanyId,
      'شرکت پیش‌فرض قابل حذف نیست',
    );
    await registry.removeCompany(companyId);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        p.join(dir.path, CompanyRegistry.dbFileNameFor(companyId)),
      );
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A locked/missing file must not break the registry cleanup.
    }
    notifyListeners();
  }

  Future<void> renameCompany(String companyId, String name) async {
    await registry.renameCompany(companyId, name);
    notifyListeners();
  }

  Future<void> _closeActiveDatabaseSafely() async {
    try {
      if (sl.isRegistered<AppDatabase>()) {
        await sl<AppDatabase>().close();
      }
    } catch (_) {}
  }

  /// Convenience used by pages: the user-facing name of a company id.
  Future<String> companyName(String id) async {
    final companies = await registry.getCompanies();
    for (final c in companies) {
      if (c.id == id) return c.name;
    }
    return 'دفتر پیش‌فرض';
  }
}
