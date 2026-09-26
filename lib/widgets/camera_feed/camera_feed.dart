import 'package:flutter/material.dart';
import 'camera_feed_stub.dart'
    if (dart.library.js_interop) 'camera_feed_web.dart'
    if (dart.library.io) 'camera_feed_io.dart';

class PlatformCameraFeed extends StatelessWidget {
  final ValueChanged<bool> onCameraReady;
  final ValueChanged<String> onError;

  const PlatformCameraFeed({
    super.key,
    required this.onCameraReady,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return createPlatformCameraView(
      onCameraReady: onCameraReady,
      onError: onError,
    );
  }
}
