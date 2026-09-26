import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

@JS('mapoStartCamera')
external void _mapoStartCamera(
  web.HTMLVideoElement video,
  JSFunction onReady,
  JSFunction onError,
);

@JS('mapoStopCamera')
external void _mapoStopCamera();

class WebCameraFeed extends StatefulWidget {
  final ValueChanged<bool> onCameraReady;
  final ValueChanged<String> onError;

  const WebCameraFeed({
    super.key,
    required this.onCameraReady,
    required this.onError,
  });

  @override
  State<WebCameraFeed> createState() => _WebCameraFeedState();
}

class _WebCameraFeedState extends State<WebCameraFeed> {
  static int _viewIdCounter = 0;
  late final String _viewType;
  web.HTMLVideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'mapo-web-camera-${_viewIdCounter++}';

    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..playsInline = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.position = 'absolute'
      ..style.top = '0'
      ..style.left = '0';

    _videoElement = video;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => video,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
    });
  }

  void _startCamera() {
    if (_videoElement == null) return;
    try {
      _mapoStartCamera(
        _videoElement!,
        (() {
          if (mounted) {
            widget.onCameraReady(true);
          }
        }).toJS,
        ((JSString err) {
          if (mounted) {
            widget.onError(err.toDart);
          }
        }).toJS,
      );
    } catch (e) {
      widget.onError('Could not start camera: $e');
    }
  }

  @override
  void dispose() {
    try {
      _mapoStopCamera();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

Widget createPlatformCameraView({
  required ValueChanged<bool> onCameraReady,
  required ValueChanged<String> onError,
}) {
  return WebCameraFeed(
    onCameraReady: onCameraReady,
    onError: onError,
  );
}

