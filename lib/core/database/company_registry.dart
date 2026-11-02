import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Company (دفتر) registry for multi-company support (Phase 5).
///
/// Companies are isolated by separate SQLite files:
///  - default company → `kifino_local.db` (backward-compatible path, so
///    existing installs keep all their data under the default company)
///  - other companies → `kifino_company_<id>.db`
///
/// The registry itself lives in SharedPreferences because it must be
/// readable BEFORE any company database is opened (chicken-and-egg).
class CompanyRegistry {
  static const String defaultCompanyId = 'default';
  static const String _storageKey = 'kifino_companies_registry';

  final SharedPreferences prefs;

  CompanyRegistry(this.prefs);

  static String dbFileNameFor(String companyId) => companyId == defaultCompanyId
      ? 'kifino_local.db'
      : 'kifino_company_$companyId.db';

  List<CompanyInfo> _decode() {
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map(
            (e) => CompanyInfo(
              id: (e as Map<String, dynamic>)['id'] as String,
              name: e['name'] as String,
              createdAt: DateTime.parse(e['createdAt'] as String),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _encode(List<CompanyInfo> companies) async {
    await prefs.setString(
      _storageKey,
      jsonEncode([
        for (final c in companies)
          {
            'id': c.id,
            'name': c.name,
            'createdAt': c.createdAt.toIso8601String(),
          },
      ]),
    );
  }

  /// All registered companies; seeds the default company on first run so a
  /// fresh install always has exactly one company that maps to the legacy
  /// database file.
  Future<List<CompanyInfo>> getCompanies() async {
    var companies = _decode();
    if (companies.isEmpty) {
      companies = [
        CompanyInfo(
          id: defaultCompanyId,
          name: 'دفتر پیش‌فرض',
          createdAt: DateTime.now(),
        ),
      ];
      await _encode(companies);
    }
    return companies;
  }

  Future<CompanyInfo> addCompany(String name) async {
    final companies = await getCompanies();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final company = CompanyInfo(id: id, name: name, createdAt: DateTime.now());
    companies.add(company);
    await _encode(companies);
    return company;
  }

  Future<void> renameCompany(String id, String name) async {
    final companies = await getCompanies();
    final updated = [
      for (final c in companies)
        if (c.id == id)
          CompanyInfo(id: c.id, name: name, createdAt: c.createdAt)
        else
          c,
    ];
    await _encode(updated);
  }

  Future<void> removeCompany(String id) async {
    assert(id != defaultCompanyId, 'شرکت پیش‌فرض قابل حذف نیست');
    final companies = await getCompanies();
    await _encode([
      for (final c in companies)
        if (c.id != id) c,
    ]);
    if (activeCompanyId == id) {
      await setActiveCompanyId(defaultCompanyId);
    }
  }

  String get activeCompanyId =>
      prefs.getString('$_storageKey.active') ?? defaultCompanyId;

  Future<void> setActiveCompanyId(String id) async {
    await prefs.setString('$_storageKey.active', id);
  }
}

class CompanyInfo {
  final String id;
  final String name;
  final DateTime createdAt;

  const CompanyInfo({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  CompanyInfo withName(String name) =>
      CompanyInfo(id: id, name: name, createdAt: createdAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyInfo && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
