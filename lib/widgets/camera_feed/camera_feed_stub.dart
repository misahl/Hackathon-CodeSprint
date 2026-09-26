import 'package:flutter/material.dart';

Widget createPlatformCameraView({
  required ValueChanged<bool> onCameraReady,
  required ValueChanged<String> onError,
}) {
  throw UnsupportedError('Cannot create camera view without platform implementation');
}
