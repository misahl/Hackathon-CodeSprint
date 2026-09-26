import 'package:camera_web/camera_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Ensures camera platform plugin is properly registered on Web
void initCameraPlugin() {
  if (kIsWeb) {
    try {
      CameraPlugin.registerWith(webPluginRegistrar);
    } catch (_) {}
  }
}
