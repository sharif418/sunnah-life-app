/// Sunnah Life mobile entrypoint — আস-সুন্নাহ ফাউন্ডেশন.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/prayer_bell_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Offline-first: the bundled TTFs under assets/google_fonts/ cover every
  // style the token theme requests — no runtime font fetching, ever.
  GoogleFonts.config.allowRuntimeFetching = false;
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  await _initBackgroundTasks();
  runApp(const ProviderScope(child: BootstrapGate()));
}

/// Daily WorkManager re-arm of the rolling bell window (C-W3b): keeps
/// bells + post-prayer prompts pending for days even if the app is never
/// opened. `Keep` policy: re-registering on every boot is a no-op when the
/// task exists. Failure never blocks app start (plugin missing on
/// tests/desktop is normal).
Future<void> _initBackgroundTasks() async {
  try {
    await Workmanager().initialize(prayerBellCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'prayer-bell-refresh',
      'prayerBellRefresh',
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e) {
    debugPrint('workmanager init failed: $e');
  }
}
