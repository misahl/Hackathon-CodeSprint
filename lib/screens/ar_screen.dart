// ─────────────────────────────────────────────────────────────
//  AR Navigation Screen
//  MVP: Live camera preview + navigation overlay graphics.
//
//  Architecture is ready for future:
//    - ARCore / ARKit world anchors
//    - Computer vision room detection
//    - BLE / WiFi indoor positioning
//    - centimeter-accurate navigation
//
//  Current implementation:
//    1. Request CAMERA permission via permission_handler.
//    2. Open live camera via the Flutter `camera` package.
//    3. Render navigation overlays on top of the camera preview:
//       - Turn direction arrow (animated)
//       - Next turn instruction text
//       - Destination name + distance
//       - Floor indicator
//       - Route progress bar
//       - Animated path dots (visual route indicator)
//    4. Mini-map at the bottom.
//    5. HUD buttons: Exit AR, Mute/Unmute, Recenter, Map.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> with TickerProviderStateMixin {
  // ── Camera state ──────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraPermissionGranted = false;
  bool _cameraInitialized = false;
  bool _cameraError = false;
  String _cameraErrorMessage = '';

  // ── Navigation overlay state ──────────────────────────────
  bool _isMuted = false;
  int _simulatedDistance = 35; // metres — will be dynamic with real positioning
  String _currentInstruction = 'Turn left ahead';
  String _nextLandmark = 'Computer Lab 29';
  final String _currentFloor = 'Ground Floor';
  int _routeProgress = 45; // 0–100 progress percentage
  bool _simulatedCamera = false;

  // ── Animation controllers ─────────────────────────────────
  late AnimationController _arrowPulseController;
  late Animation<double> _arrowPulse;

  late AnimationController _pathDotsController;
  late Animation<double> _pathDotsAnim;

  late AnimationController _instructionController;
  late Animation<double> _instructionAnim;

  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    // Arrow pulse
    _arrowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _arrowPulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _arrowPulseController, curve: Curves.easeInOut),
    );

    // Path dots flowing animation
    _pathDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pathDotsAnim = CurvedAnimation(
      parent: _pathDotsController,
      curve: Curves.linear,
    );

    // Instruction panel slide-in
    _instructionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _instructionAnim = CurvedAnimation(
      parent: _instructionController,
      curve: Curves.easeOutCubic,
    );

    _instructionController.forward();

    // Request camera permission then initialize
    _requestCameraAndInit();

    // Simulate decreasing distance (prototype)
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _simulatedDistance =
              math.max(0, _simulatedDistance - math.Random().nextInt(5));
          _routeProgress = math.min(100, _routeProgress + 3);
          if (_simulatedDistance < 15) {
            _currentInstruction = 'Continue straight';
            _nextLandmark = 'Computer Lab 29';
          }
          if (_simulatedDistance == 0) {
            _currentInstruction = '✓  You have arrived';
            _nextLandmark = 'Destination reached';
          }
        });
      }
    });
  }

  Future<void> _requestCameraAndInit() async {
    if (kIsWeb) {
      // In web browsers, camera permissions are requested directly via getUserMedia
      setState(() => _cameraPermissionGranted = true);
      await _initCamera();
      return;
    }

    final status = await Permission.camera.request();

    if (!mounted) return;

    if (status.isGranted) {
      setState(() => _cameraPermissionGranted = true);
      await _initCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _cameraError = true;
        _cameraErrorMessage =
            'Camera access is permanently denied.\nPlease enable it in Settings.';
      });
      openAppSettings();
    } else {
      setState(() {
        _cameraError = true;
        _cameraErrorMessage = 'Camera permission is required for AR navigation.';
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = 'No camera found on this device.\nYou can preview navigation in Simulated AR mode.';
        });
        return;
      }

      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _cameraPermissionGranted = true;
        _cameraInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _cameraErrorMessage = 'Could not open camera: $e\nYou can continue with Simulated AR mode.';
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _cameraController?.dispose();
    _arrowPulseController.dispose();
    _pathDotsController.dispose();
    _instructionController.dispose();
    _simulationTimer?.cancel();
    super.dispose();
  }

  // ── Close AR screen ────────────────────────────────────────
  void _closeAr() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = context.watch<AppState>().navigationDestination;
    final destName = destination?.name ?? _nextLandmark;
    final roomNumber =
        destination != null ? 'Room ${destination.roomNumber}' : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Camera Background ────────────────────────────
          _buildCameraBackground(),

          // ── 2. Route Path Indicator (flowing dots) ──────────
          if (_cameraInitialized || _simulatedCamera) _buildRoutePath(),

          // ── 3. Turn Arrow + Distance HUD ────────────────────
          if (_cameraInitialized || _simulatedCamera) _buildArrowHud(destName),

          // ── 4. Top Header Row: Close, Floor Pill, Destination Pill
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHudIconButton(
                  icon: Icons.close_rounded,
                  onTap: _closeAr,
                  semantics: 'Exit AR',
                ),
                _buildFloorChip(),
                _buildDestinationChip(destName, roomNumber),
              ],
            ),
          ),

          // ── 5. Top Instruction Banner (below header row) ──────
          _buildInstructionBanner(),

          // ── 6. Bottom Mini-Map + Controls ───────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomHud(),
          ),
        ],
      ),
    );
  }

  // ── Camera background (or fallback states) ────────────────
  Widget _buildCameraBackground() {
    if (_simulatedCamera) {
      return _buildSimulatedBackground();
    }
    if (_cameraError) {
      return _buildErrorState();
    }
    if (!_cameraPermissionGranted || !_cameraInitialized) {
      return _buildLoadingState();
    }
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return _buildLoadingState();
    }

    return Positioned.fill(
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildSimulatedBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF090D16),
            Color(0xFF030712),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle architectural grid for depth perception
          CustomPaint(
            size: Size.infinite,
            painter: _CorridorPerspectivePainter(),
          ),
          Positioned(
            top: 100,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Text(
                'SIMULATED AR PREVIEW',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFF060A12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            const SizedBox(height: 20),
            Text(
              'Opening camera…',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFF060A12),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white38,
            size: 52,
          ),
          const SizedBox(height: 20),
          Text(
            _cameraErrorMessage,
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _cameraError = false;
                    _simulatedCamera = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Use Simulated AR',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _cameraError = false;
                    _simulatedCamera = false;
                  });
                  _requestCameraAndInit();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Route path dots ───────────────────────────────────────
  Widget _buildRoutePath() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 200,
      child: AnimatedBuilder(
        animation: _pathDotsAnim,
        builder: (context, _) {
          return CustomPaint(
            painter: _RoutePathPainter(_pathDotsAnim.value),
          );
        },
      ),
    );
  }

  // ── Central Arrow + Distance ──────────────────────────────
  Widget _buildArrowHud(String destName) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 210,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Direction label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              '← TURN LEFT',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Animated arrow
          AnimatedBuilder(
            animation: _arrowPulse,
            builder: (context, _) => Transform.scale(
              scale: _arrowPulse.value,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_simulatedDistance m',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Destination name
          Text(
            destName,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Instruction banner (top) ──────────────────────────────
  Widget _buildInstructionBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 0,
      right: 0,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          _instructionAnim,
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.turn_left_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentInstruction,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Destination chip ──────────────────────────────────────
  Widget _buildDestinationChip(String name, String roomNum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (roomNum.isNotEmpty)
            Text(
              roomNum,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  // ── Floor chip ────────────────────────────────────────────
  Widget _buildFloorChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_rounded, size: 13, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            _currentFloor,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom HUD (mini-map + controls) ─────────────────────
  Widget _buildBottomHud() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          30,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            _buildProgressBar(),
            const SizedBox(height: 20),

            // Mini-map + action buttons row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Mini-map
                _buildMiniMap(),

                const Spacer(),

                // Action buttons (vertical stack)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHudIconButton(
                      icon: _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: () => setState(() => _isMuted = !_isMuted),
                      semantics: _isMuted ? 'Unmute' : 'Mute',
                    ),
                    const SizedBox(height: 10),
                    _buildHudIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: () {},
                      semantics: 'Recenter',
                    ),
                    const SizedBox(height: 10),
                    _buildHudIconButton(
                      icon: Icons.map_rounded,
                      onTap: () {
                        context.read<AppState>().clearNavigation();
                        _closeAr();
                        context.go('/map');
                      },
                      semantics: 'Map',
                    ),
                    const SizedBox(height: 10),
                    _buildHudIconButton(
                      icon: Icons.stop_circle_rounded,
                      onTap: () {
                        context.read<AppState>().clearNavigation();
                        _closeAr();
                      },
                      semantics: 'Stop',
                      highlight: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Route Progress',
              style: GoogleFonts.inter(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$_routeProgress%',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _routeProgress / 100,
            backgroundColor: Colors.white12,
            valueColor:
                AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMap() {
    return Container(
      width: 120,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _MiniMapPainter(),
          child: Center(
            child: Text(
              'Mini Map',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHudIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String semantics,
    bool highlight = false,
  }) {
    return Semantics(
      label: semantics,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: highlight
                ? Colors.redAccent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: highlight ? Colors.transparent : Colors.white24,
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Route Path Painter — animated flowing dots
// ─────────────────────────────────────────────────────────────
class _RoutePathPainter extends CustomPainter {
  final double progress;

  _RoutePathPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const dotCount = 12;
    const spacing = 40.0;
    const dotRadius = 4.0;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < dotCount; i++) {
      final rawY = size.height * 0.75 - i * spacing;
      final animOffset = (progress * spacing * dotCount) % (spacing * dotCount);
      final y = rawY + animOffset - spacing * dotCount;

      if (y < 0 || y > size.height) continue;

      // Fade out dots near the top
      final opacity = (y / size.height).clamp(0.1, 0.85);
      dotPaint.color =
          Colors.white.withValues(alpha: opacity * 0.7);

      canvas.drawCircle(Offset(cx, y), dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RoutePathPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
//  Mini Map Painter — schematic floor overview
// ─────────────────────────────────────────────────────────────
class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final corridorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Horizontal corridor
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.1),
      corridorPaint,
    );

    // Vertical corridor
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.1, size.height),
      corridorPaint,
    );

    // Current position dot
    final posPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.65),
      5,
      posPaint,
    );

    // Destination dot
    final destPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.3),
      4,
      destPaint,
    );

    // Route line
    final routePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.65),
      Offset(size.width * 0.5, size.height * 0.45),
      routePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.45),
      Offset(size.width * 0.3, size.height * 0.3),
      routePaint,
    );
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
//  Corridor Perspective Painter — simulated AR 3D hallway wireframe
// ─────────────────────────────────────────────────────────────
class _CorridorPerspectivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height * 0.42;

    // Vanishing perspective rays
    for (double x = 0; x <= size.width; x += size.width / 6) {
      canvas.drawLine(Offset(x, size.height), Offset(cx, cy), linePaint);
    }
    // Floor grid rungs
    for (double t = 0.5; t < 1.0; t += 0.08) {
      final y = cy + (size.height - cy) * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_CorridorPerspectivePainter old) => false;
}

