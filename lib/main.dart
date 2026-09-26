// ─────────────────────────────────────────────────────────────
//  main.dart — Sahyadri AR App Entry Point
//
//  Run the app with:
//    flutter run --dart-define ACCESS_TOKEN=YOUR_MAPBOX_TOKEN
//
//  TODO (Firebase): Call Firebase.initializeApp() here before
//  runApp() when Firebase is integrated.
//    await Firebase.initializeApp(
//        options: DefaultFirebaseOptions.currentPlatform);
//
//  TODO (Permissions): Request CAMERA, LOCATION, and BLUETOOTH
//  permissions here at startup using permission_handler when
//  AR and indoor positioning are added.
// ─────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'router/app_router.dart';
import 'services/camera_initializer.dart';
import 'services/navigation_service.dart';
import 'services/search_service.dart';
import 'theme/app_theme.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize Firebase ──
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 Firebase initialized successfully.');
  } catch (e) {
    debugPrint('ℹ️ Firebase init: $e');
  }

  // ── Mapbox token (Mobile only; web uses interactive blueprint canvas) ──
  if (!kIsWeb) {
    try {
      const accessToken = String.fromEnvironment('ACCESS_TOKEN');
      MapboxOptions.setAccessToken(accessToken);
    } catch (e) {
      debugPrint('ℹ️ Mapbox options init: $e');
    }
  }

  // ── Initialize Camera plugin across platforms ──
  initCameraPlugin();

  // ── Pre-load room data, navigation graph & floor plan ──
  await SearchService().init();
  await NavigationService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SahyadriApp(),
    ),
  );
}

class SahyadriApp extends StatelessWidget {
  const SahyadriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mapo - The Sahyadri AR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
