// ─────────────────────────────────────────────────────────────
//  AR Navigation Screen
//  Live camera footage preview with Augmented Reality indoor
//  guidance overlays, direction arrows, and turn-by-turn HUD.
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/navigation_route.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/camera_feed/camera_feed.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> with TickerProviderStateMixin {
  bool _cameraInitialized = false;
  bool _cameraError = false;
  bool _forceSimulated = false;
  String _errorMessage = '';
  int _retryKey = 0;

  // AR Animation controls
  late AnimationController _pulseController;
  late Animation<double> _arrowBounce;
  late AnimationController _pathFlowController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _arrowBounce = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pathFlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pathFlowController.dispose();
    super.dispose();
  }

  void _retryCamera() {
    setState(() {
      _retryKey++;
      _cameraInitialized = false;
      _cameraError = false;
      _forceSimulated = false;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final destination = state.navigationDestination?.name ??
        (state.selectedRoom?.name ?? 'Computer Lab 27');
    final route = state.currentRoute;
    final distanceText =
        route != null ? '${route.totalDistance} m' : '77.1 m';
    final walkTime =
        route != null ? '~${route.estimatedWalkingMinutes} min' : '~1 min';

    // Primary instruction
    String primaryInstruction = 'Follow pathway straight';
    if (route != null && route.instructions.isNotEmpty) {
      primaryInstruction = route.instructions.first.text;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Live Camera Feed (Web & Mobile) or Perspective Grid ──
          if (!_cameraError && !_forceSimulated)
            KeyedSubtree(
              key: ValueKey('camera-feed-$_retryKey'),
              child: PlatformCameraFeed(
                onCameraReady: (ready) {
                  if (mounted) {
                    setState(() {
                      _cameraInitialized = ready;
                      _cameraError = false;
                    });
                  }
                },
                onError: (err) {
                  if (mounted) {
                    setState(() {
                      _cameraError = true;
                      _errorMessage = err;
                    });
                  }
                },
              ),
            )
          else
            _buildCameraFallbackView(),

          // Camera activation banner when not yet initialized & no error
          if (!_cameraInitialized && !_cameraError && !_forceSimulated)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: _retryCamera,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tap to Request Camera Access',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Enables real-time camera footage for campus AR',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Layer 2: AR Guidance Graphic Overlay ───────────────────
          _buildArOverlay(
            destination: destination,
            distance: distanceText,
            walkTime: walkTime,
            instruction: primaryInstruction,
            floor: state.selectedFloor.name,
            route: route,
          ),

          // ── Layer 3: Top Navigation Bar ────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (!_cameraInitialized) {
                          _retryCamera();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _cameraInitialized
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : Colors.amber.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _cameraInitialized
                                    ? const Color(0xFF10B981)
                                    : Colors.orangeAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _cameraInitialized
                                        ? const Color(0xFF10B981).withValues(alpha: 0.7)
                                        : Colors.orangeAccent.withValues(alpha: 0.7),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _cameraInitialized
                                  ? 'LIVE CAMERA AR'
                                  : 'TAP TO ACTIVATE CAMERA',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildGlassIconButton(
                      icon: Icons.map_rounded,
                      onTap: () => context.go('/map'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Camera fallback view when permission is denied or simulated mode is on
  Widget _buildCameraFallbackView() {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _CameraPerspectivePainter(),
          ),
        ),
        if (!_forceSimulated)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      color: Colors.white70, size: 38),
                  const SizedBox(height: 12),
                  Text(
                    'Camera Access Required',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage.isNotEmpty
                        ? _errorMessage
                        : 'Please grant camera access in your browser or device settings to project live AR navigation paths.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _retryCamera,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Request Camera Access'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _forceSimulated = true;
                      });
                    },
                    icon: const Icon(Icons.view_in_ar_rounded, size: 16),
                    label: const Text('Continue in Simulated 3D AR Mode'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// AR overlays (Floating pathway arrow, dynamic instruction, distance, progress)
  Widget _buildArOverlay({
    required String destination,
    required String distance,
    required String walkTime,
    required String instruction,
    required String floor,
    required NavigationRoute? route,
  }) {
    return Stack(
      children: [
        // Animated flowing corridor dots on floor
        Positioned(
          left: 0,
          right: 0,
          bottom: 160,
          top: 300,
          child: AnimatedBuilder(
            animation: _pathFlowController,
            builder: (context, _) {
              return CustomPaint(
                painter: _FloorPathPainter(_pathFlowController.value),
              );
            },
          ),
        ),

        // Center Floating 3D AR Arrow
        Center(
          child: AnimatedBuilder(
            animation: _arrowBounce,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _arrowBounce.value),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    distance,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom HUD Card
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Turn instruction row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.straight_rounded,
                        color: AppTheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            instruction,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Towards $destination • $floor',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Meta row & Map Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          walkTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.directions_walk_rounded,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          distance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/map'),
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('2D Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 22),
        onPressed: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Custom Painters for AR Pathway Visuals
// ─────────────────────────────────────────────────────────────

class _FloorPathPainter extends CustomPainter {
  final double animationValue;
  _FloorPathPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bottomY = size.height;
    final topY = size.height * 0.08;

    // 1. Perspective Dotted Corridor Boundaries (converging towards horizon)
    final laneDotPaint = Paint()..style = PaintingStyle.fill;
    const laneSteps = 16;
    for (int i = 0; i < laneSteps; i++) {
      final t = i / (laneSteps - 1);
      final y = bottomY - t * (bottomY - topY);
      final halfWidth = (1.0 - t * 0.76) * 115.0;
      final alpha = (1.0 - t * 0.65).clamp(0.0, 1.0);
      final dotRadius = (3.2 * (1.0 - t * 0.55)).clamp(1.2, 3.2);

      laneDotPaint.color = Colors.white.withValues(alpha: alpha * 0.32);

      // Left dotted lane
      canvas.drawCircle(Offset(cx - halfWidth, y), dotRadius, laneDotPaint);
      // Right dotted lane
      canvas.drawCircle(Offset(cx + halfWidth, y), dotRadius, laneDotPaint);
    }

    // 2. Central Glowing Dotted Pathway
    const centerDots = 22;
    for (int i = 0; i < centerDots; i++) {
      final t = i / (centerDots - 1);
      final y = bottomY - t * (bottomY - topY);
      final alpha = (1.0 - t * 0.68).clamp(0.0, 1.0);
      final radius = (4.0 * (1.0 - t * 0.60)).clamp(1.6, 4.0);

      // Outer luminous halo
      canvas.drawCircle(
        Offset(cx, y),
        radius * 2.2,
        Paint()..color = const Color(0xFF0284C7).withValues(alpha: alpha * 0.28),
      );

      // Inner crisp cyan core dot
      canvas.drawCircle(
        Offset(cx, y),
        radius,
        Paint()..color = const Color(0xFF38BDF8).withValues(alpha: alpha * 0.85),
      );
    }

    // 3. Flowing 3D Dotted Chevron Arrows leading to destination
    const arrowCount = 5;
    const spacing = 0.20; // in normalized progress units

    for (int i = 0; i < arrowCount; i++) {
      final t = (i * spacing + animationValue * spacing) % 1.0;
      final y = bottomY - t * (bottomY - topY);
      final scale = (1.0 - t * 0.65).clamp(0.35, 1.0);
      final alpha = math.sin(t * math.pi).clamp(0.2, 1.0);

      canvas.save();
      canvas.translate(cx, y);
      canvas.scale(scale, scale);

      // Distinct 3D chevron arrow pointing forward
      final chevron = Path()
        ..moveTo(-18.0, 12.0)
        ..lineTo(0.0, -8.0)
        ..lineTo(18.0, 12.0)
        ..lineTo(13.0, 16.0)
        ..lineTo(0.0, 0.0)
        ..lineTo(-13.0, 16.0)
        ..close();

      // Outer glow
      canvas.drawPath(
        chevron,
        Paint()
          ..color = AppTheme.primary.withValues(alpha: alpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
      );

      // Solid arrow body
      canvas.drawPath(
        chevron,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.95)
          ..style = PaintingStyle.fill,
      );

      // Vibrant arrow outline
      canvas.drawPath(
        chevron,
        Paint()
          ..color = AppTheme.primary.withValues(alpha: alpha)
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke,
      );

      // Trailing dotted beads behind each arrow
      for (double dotOffset = 18.0; dotOffset <= 36.0; dotOffset += 9.0) {
        canvas.drawCircle(
          Offset(0, dotOffset),
          2.6,
          Paint()..color = const Color(0xFF38BDF8).withValues(alpha: alpha * 0.7),
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPathPainter oldDelegate) => true;
}

class _CameraPerspectivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height * 0.42;

    for (double x = 0; x <= size.width; x += size.width / 6) {
      canvas.drawLine(Offset(x, size.height), Offset(cx, cy), linePaint);
    }

    for (double t = 0.5; t < 1.0; t += 0.08) {
      final y = cy + (size.height - cy) * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
