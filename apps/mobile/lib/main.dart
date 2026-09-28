/// Sunnah Life mobile entrypoint — আস-সুন্নাহ ফাউন্ডেশন.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Offline-first: the bundled TTFs under assets/google_fonts/ cover every
  // style the token theme requests — no runtime font fetching, ever.
  GoogleFonts.config.allowRuntimeFetching = false;
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: BootstrapGate()));
}
