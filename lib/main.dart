import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/database/company_registry.dart';
import 'core/di/injection.dart';
import 'features/sync/domain/services/sync_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Root scope: preferences, company registry, secure storage.
  final prefs = await SharedPreferences.getInstance();
  final registry = CompanyRegistry(prefs);
  await ServiceLocator.initRoot();

  // 2. Company scope: database + services of the ACTIVE company.
  await ServiceLocator.init(companyId: registry.activeCompanyId);

  // Keep the offline outbox bounded while no sync server exists.
  unawaited(sl<SyncEngine>().pruneIfNoBackend());

  runApp(const KifinoApp());
}
