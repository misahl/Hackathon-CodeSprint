import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class IoCameraFeed extends StatefulWidget {
  final ValueChanged<bool> onCameraReady;
  final ValueChanged<String> onError;

  const IoCameraFeed({
    super.key,
    required this.onCameraReady,
    required this.onError,
  });

  @override
  State<IoCameraFeed> createState() => _IoCameraFeedState();
}

class _IoCameraFeedState extends State<IoCameraFeed> {
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      widget.onError('Camera permission denied. Please allow camera access in Settings.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        widget.onError('No camera sensor found on this device.');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = controller;
      await controller.initialize();

      if (mounted) {
        widget.onCameraReady(true);
        setState(() {});
      }
    } catch (e) {
      widget.onError('Failed to open camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize?.height ?? 1920,
          height: _controller!.value.previewSize?.width ?? 1080,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }
}

Widget createPlatformCameraView({
  required ValueChanged<bool> onCameraReady,
  required ValueChanged<String> onError,
}) {
  return IoCameraFeed(
    onCameraReady: onCameraReady,
    onError: onError,
  );
}
