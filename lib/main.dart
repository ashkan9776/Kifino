import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services & Database
  await ServiceLocator.init();

  runApp(const KifinoApp());
}
