// ─────────────────────────────────────────────────────────────
//  CampusWebMapView
//  Accurate vector floor plan for Sahyadri College of Engineering
//  & Management — Ground Floor.
//
//  Layout is reconstructed from the ORIGINAL PHOTOGRAPH (Image 4).
//  No rooms are invented. No geometry is mirrored or distorted.
//
//  Features:
//  - Compact numbered circular markers (no label clutter)
//  - Tap a marker → bottom info card → [View] [Navigate]
//  - Search → zoom → highlight → navigate flow
//  - Zoom-aware labels (names only at high zoom)
//  - Floating zoom controls + recenter
//  - Collapsible legend
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import '../models/floor.dart';
import '../models/navigation_node.dart';
import '../models/navigation_route.dart';
import '../models/room.dart';
import '../providers/app_state.dart';
import '../services/navigation_service.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

class CampusWebMapView extends StatefulWidget {
  final Floor selectedFloor;
  final VoidCallback? onMapTap;

  const CampusWebMapView({
    super.key,
    required this.selectedFloor,
    this.onMapTap,
  });

  @override
  State<CampusWebMapView> createState() => _CampusWebMapViewState();
}

class _CampusWebMapViewState extends State<CampusWebMapView>
    with TickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();

  AnimationController? _animController;
  Animation<Matrix4>? _matrixAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double _currentScale = 1.0;
  Size _viewportSize = Size.zero;
  String? _lastAnimatedRoomId;
  bool _legendExpanded = false;
  bool _showPins = true;

  static const double _canvasWidth = 1024.0;
  static const double _canvasHeight = 931.0;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformationChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ensure rooms are loaded (SearchService is a singleton; init is idempotent)
    SearchService().init().then((_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialSelection();
    });
  }

  void _onTransformationChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.04) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _checkInitialSelection() {
    final state = context.read<AppState>();
    if (state.selectedRoom != null &&
        state.selectedRoom!.floor == widget.selectedFloor.id) {
      _animateToRoom(state.selectedRoom!, targetScale: 2.2);
    } else {
      _resetView(animate: false);
    }
  }

  @override
  void didUpdateWidget(covariant CampusWebMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFloor.id != widget.selectedFloor.id) {
      _lastAnimatedRoomId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = context.read<AppState>();
        if (state.selectedRoom != null &&
            state.selectedRoom!.floor == widget.selectedFloor.id) {
          _animateToRoom(state.selectedRoom!, targetScale: 2.2);
        } else {
          _resetView(animate: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformationChanged);
    _transformController.dispose();
    _animController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _animateMatrix(Matrix4 targetMatrix) {
    _animController?.dispose();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _matrixAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeInOutCubic,
    ));

    _animController!.addListener(() {
      _transformController.value = _matrixAnimation!.value;
    });
    _animController!.forward();
  }

  void _animateToRoom(Room room, {double targetScale = 2.2}) {
    if (_viewportSize == Size.zero) return;
    _lastAnimatedRoomId = room.id;

    final targetX = room.coordinates.x;
    final targetY = room.coordinates.y;

    final tx = _viewportSize.width / 2 - targetX * targetScale;
    final ty = _viewportSize.height / 2 - targetY * targetScale;

    final targetMatrix = Matrix4.identity()
      ..translateByVector3(vmath.Vector3(tx, ty, 0.0))
      ..scaleByVector3(vmath.Vector3(targetScale, targetScale, 1.0));

    _animateMatrix(targetMatrix);
  }

  void _animateToCoordinate(double x, double y, {double targetScale = 2.2}) {
    if (_viewportSize == Size.zero) return;

    final tx = _viewportSize.width / 2 - x * targetScale;
    final ty = _viewportSize.height / 2 - y * targetScale;

    final targetMatrix = Matrix4.identity()
      ..translateByVector3(vmath.Vector3(tx, ty, 0.0))
      ..scaleByVector3(vmath.Vector3(targetScale, targetScale, 1.0));

    _animateMatrix(targetMatrix);
  }

  void _zoomIn() {
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final targetMatrix = _transformController.value.clone();
    targetMatrix.translateByVector3(vmath.Vector3(center.dx, center.dy, 0.0));
    targetMatrix.scaleByVector3(vmath.Vector3(1.35, 1.35, 1.0));
    targetMatrix.translateByVector3(vmath.Vector3(-center.dx, -center.dy, 0.0));
    _animateMatrix(targetMatrix);
  }

  void _zoomOut() {
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final targetMatrix = _transformController.value.clone();
    targetMatrix.translateByVector3(vmath.Vector3(center.dx, center.dy, 0.0));
    targetMatrix.scaleByVector3(vmath.Vector3(1 / 1.35, 1 / 1.35, 1.0));
    targetMatrix.translateByVector3(vmath.Vector3(-center.dx, -center.dy, 0.0));
    _animateMatrix(targetMatrix);
  }

  void _resetView({bool animate = true}) {
    if (_viewportSize == Size.zero) return;

    final scaleX = _viewportSize.width / (_canvasWidth + 60);
    final scaleY = _viewportSize.height / (_canvasHeight + 140);
    final fitScale = math.min(scaleX, scaleY).clamp(0.45, 1.0);

    final tx = (_viewportSize.width - _canvasWidth * fitScale) / 2;
    final ty = (_viewportSize.height - _canvasHeight * fitScale) / 2 - 10;

    final targetMatrix = Matrix4.identity()
      ..translateByVector3(vmath.Vector3(tx, ty, 0.0))
      ..scaleByVector3(vmath.Vector3(fitScale, fitScale, 1.0));

    if (animate) {
      _animateMatrix(targetMatrix);
    } else {
      _transformController.value = targetMatrix;
    }
  }

  bool _isImportantFacility(Room room) {
    if (room.category == RoomCategory.hall ||
        room.category == RoomCategory.facility) {
      return true;
    }
    final n = room.name.toLowerCase();
    return n.contains('library') ||
        n.contains('seminar') ||
        n.contains('innovation') ||
        n.contains('excellence') ||
        n.contains('principal') ||
        n.contains('board room') ||
        n.contains('director');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rooms = SearchService().getAllRooms(floorId: widget.selectedFloor.id);

    // Auto-center on selected room if changed
    if (state.selectedRoom != null &&
        state.selectedRoom!.floor == widget.selectedFloor.id &&
        state.selectedRoom!.id != _lastAnimatedRoomId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateToRoom(state.selectedRoom!, targetScale: 2.2);
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_viewportSize != Size(constraints.maxWidth, constraints.maxHeight)) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.selectedRoom != null &&
                state.selectedRoom!.floor == widget.selectedFloor.id) {
              _animateToRoom(state.selectedRoom!, targetScale: 2.2);
            } else {
              _resetView(animate: false);
            }
          });
        }

        return Container(
          color: const Color(0xFFF0F2F5),
          child: Stack(
            children: [
              // ── Interactive Map ──────────────────────────────
              GestureDetector(
                onTap: () => widget.onMapTap?.call(),
                child: InteractiveViewer(
                  transformationController: _transformController,
                  boundaryMargin: const EdgeInsets.all(600),
                  minScale: 0.35,
                  maxScale: 4.0,
                  child: Center(
                    child: SizedBox(
                      width: _canvasWidth,
                      height: _canvasHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Ground floor displays the official architectural blueprint
                          if (widget.selectedFloor.id == 'ground' ||
                              widget.selectedFloor.level == 0)
                            Image.asset(
                              'assets/images/ground_floor_plan.jpg',
                              width: _canvasWidth,
                              height: _canvasHeight,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) =>
                                  CustomPaint(
                                size: const Size(_canvasWidth, _canvasHeight),
                                painter: _GroundFloorPainter(
                                  floorLevel: widget.selectedFloor.level,
                                  floorName: widget.selectedFloor.name,
                                ),
                              ),
                            )
                          else
                            CustomPaint(
                              size: const Size(_canvasWidth, _canvasHeight),
                              painter: _GroundFloorPainter(
                                floorLevel: widget.selectedFloor.level,
                                floorName: widget.selectedFloor.name,
                              ),
                            ),

                          // 1. Navigation Graph Debug Layer (nodes & edges)
                          if (state.debugMode &&
                              (widget.selectedFloor.id == 'ground' ||
                                  widget.selectedFloor.level == 0))
                            CustomPaint(
                              size: const Size(_canvasWidth, _canvasHeight),
                              painter: _NavigationDebugPainter(
                                isEnabled: state.debugMode,
                                activeDestNodeId: state.navigationDestination != null
                                    ? NavigationService().getNodeForRoom(state.navigationDestination!.id)?.id
                                    : null,
                              ),
                            ),

                          // 2. Navigation Route Layer: calculated path with animated directional arrows
                          if (state.isNavigating &&
                              state.currentRoute != null &&
                              state.currentRoute!.nodes.isNotEmpty &&
                              (widget.selectedFloor.id == 'ground' ||
                                  widget.selectedFloor.level == 0))
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) => CustomPaint(
                                size: const Size(_canvasWidth, _canvasHeight),
                                painter: _NavigationRoutePainter(
                                  route: state.currentRoute!,
                                  pulseProgress: _pulseController.value,
                                ),
                              ),
                            ),

                          // Room markers
                          for (final room in rooms)
                            _buildInteractiveMarker(
                              context,
                              room,
                              Offset(room.coordinates.x, room.coordinates.y),
                              state,
                            ),

                          // Navigation destination pin
                          if (state.navigationDestination != null &&
                              state.navigationDestination!.floor ==
                                  widget.selectedFloor.id)
                            _buildDestinationPin(
                              state.navigationDestination!,
                              Offset(
                                state.navigationDestination!.coordinates.x,
                                state.navigationDestination!.coordinates.y,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top Navigation Panel (Active when navigating) ───────
              if (state.isNavigating &&
                  state.currentRoute != null &&
                  state.navigationDestination != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 14,
                  right: 14,
                  child: _NavigationTopPanel(
                    route: state.currentRoute!,
                    destination: state.navigationDestination!,
                    startLabel: state.startRoom?.name ??
                        state.startNode?.label ??
                        'Main Entry',
                    onClose: () => state.stopNavigation(),
                    onChangeStart: () => _showStartPointPicker(context, state),
                    onOpenAR: () => context.push('/ar'),
                    onInstructionTap: (instruction) {
                      _animateToCoordinate(
                        instruction.node.x,
                        instruction.node.y,
                        targetScale: 2.2,
                      );
                    },
                  ),
                ),

              // ── Zoom Controls ────────────────────────────────
              Positioned(
                right: 14,
                top: state.isNavigating
                    ? MediaQuery.of(context).padding.top + 164
                    : MediaQuery.of(context).padding.top + 76,
                child: _buildZoomControls(state),
              ),

              // ── Legend ───────────────────────────────────────
              Positioned(
                left: 14,
                bottom: state.selectedRoom != null && !state.isNavigating ? 180 : 32,
                child: _buildLegend(),
              ),

              // ── Bottom Info Card ─────────────────────────────
              if (state.selectedRoom != null && !state.isNavigating)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: _RoomInfoCard(
                    room: state.selectedRoom!,
                    onClose: () => state.clearSelectedRoom(),
                    onView: () => context.push('/room/${state.selectedRoom!.id}'),
                    onNavigate: () {
                      state.setNavigationDestination(state.selectedRoom!);
                      state.startNavigation();
                      _animateToRoom(state.selectedRoom!, targetScale: 1.8);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveMarker(
    BuildContext context,
    Room room,
    Offset position,
    AppState state,
  ) {
    final isSelected = state.selectedRoom?.id == room.id;
    final isTarget = state.navigationDestination?.id == room.id;
    final isStaircase = room.category == RoomCategory.staircase;
    final isEntrance = room.category == RoomCategory.entrance;
    final isFacility = _isImportantFacility(room);

    final showName = isSelected ||
        (_currentScale >= 2.0) ||
        (_currentScale >= 1.4 && isFacility);

    if (!_showPins && !isSelected && !isTarget) {
      return Positioned(
        left: position.dx - 22,
        top: position.dy - 22,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            state.selectRoom(room);
            _animateToRoom(room, targetScale: 2.2);
          },
          child: const SizedBox(width: 44, height: 44),
        ),
      );
    }

    return Positioned(
      left: position.dx - 30,
      top: position.dy - 30,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          state.selectRoom(room);
          _animateToRoom(room, targetScale: 2.2);
        },
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isSelected || isTarget)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) => Container(
                        width: 32 * _pulseAnimation.value,
                        height: 32 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isTarget ? Colors.redAccent : AppTheme.primary)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  _buildMarker(room, isSelected, isTarget, isStaircase,
                      isEntrance, isFacility),
                ],
              ),
              if (showName) _buildNameLabel(room, isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarker(Room room, bool isSelected, bool isTarget,
      bool isStaircase, bool isEntrance, bool isFacility) {
    if (isStaircase) {
      return Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary
                : (isTarget ? Colors.redAccent : const Color(0xFF7C3AED)),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Transform.rotate(
            angle: -math.pi / 4,
            child:
                const Icon(Icons.stairs_rounded, size: 12, color: Colors.white),
          ),
        ),
      );
    }

    if (isEntrance) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isTarget ? Colors.redAccent : const Color(0xFF059669)),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.arrow_upward_rounded,
            size: 14, color: Colors.white),
      );
    }

    if (isFacility) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isTarget ? Colors.redAccent : const Color(0xFFD97706)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Center(
          child: Text(
            room.roomNumber.isNotEmpty ? room.roomNumber : '■',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Default: circular room marker
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary
            : (isTarget ? Colors.redAccent : const Color(0xFF1E3A8A)),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: isSelected ? 2.0 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          room.roomNumber,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildNameLabel(Room room, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary
            : Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
          width: 0.7,
        ),
      ),
      child: Text(
        room.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildDestinationPin(Room room, Offset position) {
    return Positioned(
      left: position.dx - 20,
      top: position.dy - 50,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DEST',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.location_on_rounded,
                color: Colors.redAccent, size: 34),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControls(AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(icon: Icons.add_rounded, tooltip: 'Zoom In', onTap: _zoomIn),
          Container(height: 1, width: 28, color: const Color(0xFFE2E8F0)),
          _ZoomBtn(
              icon: Icons.remove_rounded,
              tooltip: 'Zoom Out',
              onTap: _zoomOut),
          Container(height: 1, width: 28, color: const Color(0xFFE2E8F0)),
          _ZoomBtn(
              icon: Icons.fit_screen_rounded,
              tooltip: 'Recenter',
              onTap: () => _resetView(animate: true)),
          Container(height: 1, width: 28, color: const Color(0xFFE2E8F0)),
          _ZoomBtn(
              icon: _showPins
                  ? Icons.pin_drop_rounded
                  : Icons.pin_drop_outlined,
              tooltip: _showPins ? 'Hide Room Pins' : 'Show Room Pins',
              onTap: () => setState(() => _showPins = !_showPins)),
          Container(height: 1, width: 28, color: const Color(0xFFE2E8F0)),
          _ZoomBtn(
              icon: state.debugMode
                  ? Icons.alt_route_rounded
                  : Icons.alt_route_outlined,
              tooltip: state.debugMode
                  ? 'Hide Graph (Debug Mode)'
                  : 'Show Navigation Graph (Debug)',
              iconColor: state.debugMode ? const Color(0xFF059669) : null,
              onTap: () => state.toggleDebugMode()),
        ],
      ),
    );
  }

  void _showStartPointPicker(BuildContext context, AppState state) {
    final allRooms = SearchService().getAllRooms(floorId: 'ground');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.70,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Starting Point',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.door_front_door_rounded,
                      color: Color(0xFF10B981), size: 20),
                ),
                title: const Text('Main Entry (Recommended)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('South campus entrance / porch'),
                trailing: (state.startNode?.id == 'node_main_entry' &&
                        state.startRoom == null)
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981))
                    : null,
                onTap: () {
                  final node =
                      NavigationService().getNodeById('node_main_entry');
                  if (node != null) state.setStartNode(node);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.west_rounded,
                      color: Color(0xFF0284C7), size: 20),
                ),
                title: const Text('West Entry',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Near visitor lounge & fee counter'),
                trailing: (state.startNode?.id == 'node_west_entry')
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF0284C7))
                    : null,
                onTap: () {
                  final node =
                      NavigationService().getNodeById('node_west_entry');
                  if (node != null) state.setStartNode(node);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 24),
              Text(
                'Or Start From Any Room',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  itemCount: allRooms.length,
                  itemBuilder: (context, index) {
                    final room = allRooms[index];
                    final isCurrentStart = state.startRoom?.id == room.id;
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      dense: true,
                      leading: Icon(
                        AppTheme.categoryIcon(room.category.name),
                        size: 18,
                        color: AppTheme.categoryColor(room.category.name),
                      ),
                      title: Text(room.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Room ${room.roomNumber}'),
                      trailing: isCurrentStart
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppTheme.primary)
                          : null,
                      onTap: () {
                        state.setStartRoom(room);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _legendExpanded = !_legendExpanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 5),
                const Text(
                  'Map Legend',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 3),
                Icon(
                  _legendExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          if (_legendExpanded) ...[
            const SizedBox(height: 6),
            _legendRow(
                child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: Color(0xFF1E3A8A), shape: BoxShape.circle)),
                label: 'Room'),
            const SizedBox(height: 3),
            _legendRow(
                child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(3))),
                label: 'Facility'),
            const SizedBox(height: 3),
            _legendRow(
                child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: Color(0xFF059669), shape: BoxShape.circle)),
                label: 'Entrance'),
            const SizedBox(height: 3),
            _legendRow(
                child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(2)))),
                label: 'Staircase'),
          ],
        ],
      ),
    );
  }

  Widget _legendRow({required Widget child, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 14, height: 14, child: Center(child: child)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Zoom Button
// ─────────────────────────────────────────────────────────────
class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ZoomBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: iconColor ?? AppTheme.textPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom Room Info Card
// ─────────────────────────────────────────────────────────────
class _RoomInfoCard extends StatelessWidget {
  final Room room;
  final VoidCallback onClose;
  final VoidCallback onView;
  final VoidCallback onNavigate;

  const _RoomInfoCard({
    required this.room,
    required this.onClose,
    required this.onView,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.categoryColor(room.category.name);
    final catIcon = AppTheme.categoryIcon(room.category.name);
    final floorName = room.floor == 'ground'
        ? 'Ground Floor'
        : (room.floor == 'first' ? '1st Floor' : '2nd Floor');

    return Card(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(catIcon, color: catColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Room ${room.roomNumber} · $floorName',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (room.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                room.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'View',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation_rounded, size: 16),
                    label: Text(
                      'Navigate',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Ground Floor Painter — Accurate from original photograph
//
//  Layout reference (Image 4, Sahyadri College Ground Floor):
//
//  TOP ANNEX (y=30–125):
//    [46 Foundry][45 Construction][Room]
//
//  MAIN BUILDING (y=140–1050):
//
//  Row A (y=145–295):  Admin corridor on right wing
//    Right of COURTYARD 3: Rooms 13, 14/15, 12, 11, 10
//    Far right: Foundation Office (1), Store (spare)
//    Between CY3 & CY4: Exam Sec (8), Establ (7)
//    Right of CY4: Principal (2), Academic (3)
//
//  Row B (y=295–420):  Seminar Hall level
//    Left wing: Dept Placement (18)
//    CY3 zone
//    Center: Seminar Hall (19) / Maintenance (20)
//    Entry atrium center
//    Right: CR (6), Rooms 4, 5
//    Far right: Principal/Academic continuation
//
//  Row C (y=420–550):  Study / Computer Science
//    Left wing: Board Room (44), CY2
//    Center: Study Space (21), CS Maint (22), CS Staff (23)
//    Right: HOD Dept Library zone, CY1 entry
//
//  Row D (y=550–700):  Innovation / Study
//    Left wing: Study Space (43), Rooms 41/42
//    Center: Discussion (40), Guest Lounge (36)
//    Right: Innovation Lab (32), Study Space (33), CY1
//
//  Row E (y=700–820):  Computer Labs + Central Library
//    Left: Fee Counter (39), Visitors Lounge (38), Admission (37)
//    Center: Record Rm (34), Store (35), Center for Excellence (31)
//    Right: Computer Labs 24–30, CY1 bottom
//
//  Bottom: MAIN ENTRY, compass, floor title banner
//
//  Coordinates are in canvas space (0,0) = top-left.
//  x increases rightward, y increases downward.
// ─────────────────────────────────────────────────────────────
class _GroundFloorPainter extends CustomPainter {
  final int floorLevel;
  final String floorName;

  _GroundFloorPainter({required this.floorLevel, required this.floorName});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawTopAnnex(canvas);
    _drawSahyadriCrest(canvas, 830, 28);
    _drawMainBuilding(canvas);
    _drawCourtyards(canvas);
    _drawSeminarHall(canvas);
    _drawCentralLibrary(canvas);
    _drawComputerLabs(canvas);
    _drawCorridors(canvas);
    _drawEntries(canvas);
    _drawFloorBanner(canvas, size);
    _drawCompass(canvas, 890, 1020);
  }

  // ── Shared paints ──────────────────────────────────────────
  static final _wallPaint = Paint()
    ..color = const Color(0xFF1E293B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  static final _thinWall = Paint()
    ..color = const Color(0xFF334155)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static final _annexFill = Paint()..color = const Color(0xFFF1F5F9);
  static final _buildingFill = Paint()..color = const Color(0xFFFFFFFF);
  static final _roomFill = Paint()..color = const Color(0xFFF8FAFC);
  static final _courtFill = Paint()..color = const Color(0xFFDBEAFE);
  static final _courtCross = Paint()
    ..color = const Color(0xFF93C5FD)
    ..strokeWidth = 1.2;
  static final _seminarFill = Paint()..color = const Color(0xFFFEF2F2);
  static final _libFill = Paint()..color = const Color(0xFFFEF9C3);
  static final _labFill = Paint()..color = const Color(0xFFEFF6FF);

  // ── 1. Background ──────────────────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF8FAFC),
    );
    // Outer border
    canvas.drawRect(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      Paint()
        ..color = const Color(0xFF1E3A8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  // ── 2. Top Annex (Foundry, Construction, misc room) ────────
  void _drawTopAnnex(Canvas canvas) {
    // Full annex block
    final annexRect = Rect.fromLTWH(30, 28, 540, 100);
    canvas.drawRect(annexRect, _annexFill);
    canvas.drawRect(annexRect, _wallPaint);

    // Internal dividers: 3 sections
    _vLine(canvas, 205, 28, 128); // divide foundry | construction
    _vLine(canvas, 360, 28, 128); // divide construction | room

    // Labels
    _label(canvas, '46 Foundry &\nForging', 60, 66, 9.5,
        color: const Color(0xFF374151));
    _label(canvas, '45 Construction\nOffice', 220, 62, 9.5,
        color: const Color(0xFF374151));
    _label(canvas, 'Room', 395, 72, 9.5, color: const Color(0xFF374151));
  }

  // ── 3. Main Building Perimeter ─────────────────────────────
  void _drawMainBuilding(Canvas canvas) {
    final mainRect = Rect.fromLTWH(30, 140, 940, 920);
    canvas.drawRect(mainRect, _buildingFill);
    canvas.drawRect(mainRect, _wallPaint);
  }

  // ── 4. Courtyards (exact positions from photograph) ────────
  void _drawCourtyards(Canvas canvas) {
    // COURTYARD 3 — upper left
    _drawCourtyard(canvas, 55, 155, 220, 185, 'COURTYARD 3');

    // COURTYARD 4 — upper right (center)
    _drawCourtyard(canvas, 420, 155, 230, 185, 'COURTYARD 4');

    // COURTYARD 2 — middle left
    _drawCourtyard(canvas, 55, 470, 220, 130, 'COURTYARD 2');

    // COURTYARD 1 — lower right
    _drawCourtyard(canvas, 560, 640, 220, 195, 'COURTYARD 1');
  }

  void _drawCourtyard(Canvas canvas, double x, double y, double w, double h,
      String label) {
    final rect = Rect.fromLTWH(x, y, w, h);
    canvas.drawRect(rect, _courtFill);
    canvas.drawRect(rect, _wallPaint);
    // Cross hatching
    canvas.drawLine(Offset(x, y), Offset(x + w, y + h), _courtCross);
    canvas.drawLine(Offset(x + w, y), Offset(x, y + h), _courtCross);
    _label(canvas, label, x + w / 2 - 42, y + h / 2 - 8, 10.5,
        color: const Color(0xFF1D4ED8), bold: true);
  }

  // ── 5. Seminar Hall ────────────────────────────────────────
  void _drawSeminarHall(Canvas canvas) {
    final rect = Rect.fromLTWH(55, 370, 220, 90);
    canvas.drawRect(rect, _seminarFill);
    canvas.drawRect(rect, _wallPaint);

    // Seat rows
    final seatPaint = Paint()..color = const Color(0xFFEF4444);
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 7; c++) {
        canvas.drawCircle(Offset(80 + c * 27.0, 388 + r * 20.0), 3.5, seatPaint);
      }
    }

    _label(canvas, '19 SEMINAR HALL', 100, 373, 9.0,
        color: const Color(0xFFB91C1C), bold: true);
  }

  // ── 6. Central Library (bottom-left zone) ──────────────────
  void _drawCentralLibrary(Canvas canvas) {
    final rect = Rect.fromLTWH(55, 770, 240, 220);
    canvas.drawRect(rect, _libFill);
    canvas.drawRect(rect, _wallPaint);

    // Bookshelf lines
    final shelf = Paint()
      ..color = const Color(0xFFCA8A04)
      ..strokeWidth = 2.0;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
          Offset(80 + i * 45.0, 792), Offset(80 + i * 45.0, 960), shelf);
    }
    _label(canvas, 'CENTRAL\nLIBRARY', 115, 802, 12.0,
        color: const Color(0xFF92400E), bold: true);
    _label(canvas, 'Dept Library\n(HOD)', 116, 845, 9.0,
        color: const Color(0xFF78350F));
  }

  // ── 7. Computer Labs (right column, bottom) ─────────────────
  void _drawComputerLabs(Canvas canvas) {
    // Labs 27–30 bottom row (right side)
    const labsY = 870.0;
    const labW = 100.0;
    const labH = 150.0;
    final labStartX = 590.0;

    final labs = ['27', '28', '29', '30'];
    for (int i = 0; i < labs.length; i++) {
      final x = labStartX + i * (labW + 8);
      final rect = Rect.fromLTWH(x, labsY, labW, labH);
      canvas.drawRect(rect, _labFill);
      canvas.drawRect(rect, _thinWall);
      // Desk dots
      final dotPaint = Paint()..color = const Color(0xFF60A5FA);
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          canvas.drawCircle(
              Offset(x + 18 + c * 28.0, labsY + 30 + r * 32.0), 4, dotPaint);
        }
      }
      _label(canvas, labs[i], x + labW / 2 - 6, labsY + labH - 18, 10,
          color: const Color(0xFF1E3A8A), bold: true);
    }

    // Lab 24 upper right
    {
      final rect = Rect.fromLTWH(800, 640, 160, 185);
      canvas.drawRect(rect, _labFill);
      canvas.drawRect(rect, _thinWall);
      _label(canvas, 'Computer Labs\n24–26', 820, 720, 9,
          color: const Color(0xFF1E3A8A));
    }

    // Server room label at 27 position
    _label(canvas, 'Server\nRoom', 595, 890, 8, color: const Color(0xFF374151));
  }

  // ── 8. Corridors & internal dividers ─────────────────────
  void _drawCorridors(Canvas canvas) {
    // Central horizontal corridor (midway)
    final hCorrPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(30, 610, 940, 32), hCorrPaint);

    // Vertical corridor (center of building)
    canvas.drawRect(const Rect.fromLTWH(300, 140, 38, 920), hCorrPaint);

    // Lower horizontal corridor
    canvas.drawRect(const Rect.fromLTWH(30, 850, 560, 32), hCorrPaint);

    // Right wing vertical separator
    canvas.drawRect(const Rect.fromLTWH(670, 140, 32, 880), hCorrPaint);

    // Draw room grid lines (top admin area, right wing)
    _drawAdminWing(canvas);
    _drawMiddleZone(canvas);
    _drawLowerLeftZone(canvas);
  }

  void _drawAdminWing(Canvas canvas) {
    // Right wing: rooms 1, 2, 3, 10, 11, 12, 13, 14 (top-right quadrant)
    final rooms = [
      // (x, y, w, h, label)
      (710.0, 145.0, 250.0, 75.0, '1  Foundation Office'),
      (710.0, 220.0, 160.0, 80.0, '2  Principal\'s Chamber'),
      (710.0, 300.0, 160.0, 95.0, '3  Academic Section'),
      (870.0, 220.0, 98.0, 80.0, 'Store'),
      (870.0, 300.0, 98.0, 95.0, '4 / 5'),
      (420.0, 145.0, 120.0, 80.0, '10 Director\'s\nChamber'),
      (548.0, 145.0, 160.0, 75.0, '11 Store  12 Health'),
      (300.0, 145.0, 120.0, 80.0, '13 GD  14 Placement'),
    ];
    for (final r in rooms) {
      final rect = Rect.fromLTWH(r.$1, r.$2, r.$3, r.$4);
      canvas.drawRect(rect, _roomFill);
      canvas.drawRect(rect, _thinWall);
      _label(canvas, r.$5, r.$1 + 4, r.$2 + 4, 8.0,
          color: const Color(0xFF374151));
    }

    // Rooms 7 & 8 between courtyards
    final exam = Rect.fromLTWH(300, 225, 120, 80);
    canvas.drawRect(exam, _roomFill);
    canvas.drawRect(exam, _thinWall);
    _label(canvas, '8 Examination\nSection', 305, 233, 8.0,
        color: const Color(0xFF374151));

    final estab = Rect.fromLTWH(300, 305, 120, 80);
    canvas.drawRect(estab, _roomFill);
    canvas.drawRect(estab, _thinWall);
    _label(canvas, '7 Establishment\nSection', 305, 313, 8.0,
        color: const Color(0xFF374151));

    // Room 18 dept-wise placement (left strip, upper)
    final r18 = Rect.fromLTWH(30, 155, 20, 185);
    canvas.drawRect(r18, _roomFill);
    canvas.drawRect(r18, _thinWall);
    _label(canvas, '18', 30, 230, 7.5, color: const Color(0xFF374151));
  }

  void _drawMiddleZone(Canvas canvas) {
    // Maintenance Office (center, between courtyards)
    final maint = Rect.fromLTWH(338, 370, 120, 90);
    canvas.drawRect(maint, _roomFill);
    canvas.drawRect(maint, _thinWall);
    _label(canvas, '20 Maintenance\nOffice', 343, 378, 8.0,
        color: const Color(0xFF374151));

    // CR 6 + HOD Dept zone (right of entry)
    final cr = Rect.fromLTWH(710, 395, 80, 80);
    canvas.drawRect(cr, _roomFill);
    canvas.drawRect(cr, _thinWall);
    _label(canvas, '6 CR', 725, 428, 9.0, color: const Color(0xFF374151));

    // Rooms 4 & 5 (far right middle)
    final r45 = Rect.fromLTWH(800, 395, 160, 80);
    canvas.drawRect(r45, _roomFill);
    canvas.drawRect(r45, _thinWall);
    _label(canvas, '4 / 5', 860, 428, 9.0, color: const Color(0xFF374151));

    // Study Space 21 + CS Maintenance 22 + CS Staff 23
    final s21 = Rect.fromLTWH(338, 470, 80, 130);
    canvas.drawRect(s21, _roomFill);
    canvas.drawRect(s21, _thinWall);
    _label(canvas, '21\nStudy', 347, 510, 8.5, color: const Color(0xFF374151));

    final cs22 = Rect.fromLTWH(420, 470, 120, 60);
    canvas.drawRect(cs22, _roomFill);
    canvas.drawRect(cs22, _thinWall);
    _label(canvas, '22 CS Maint', 425, 490, 8.0,
        color: const Color(0xFF374151));

    final cs23 = Rect.fromLTWH(420, 530, 240, 70);
    canvas.drawRect(cs23, _roomFill);
    canvas.drawRect(cs23, _thinWall);
    _label(canvas, '23 Dept of CS Staff Room', 428, 555, 8.0,
        color: const Color(0xFF374151));

    // Entry corridor label
    _label(canvas, '← ENTRY →', 360, 415, 9.0,
        color: const Color(0xFF059669), bold: true);
  }

  void _drawLowerLeftZone(Canvas canvas) {
    // Innovation Lab 32
    final inn = Rect.fromLTWH(338, 640, 100, 120);
    canvas.drawRect(inn, _labFill);
    canvas.drawRect(inn, _thinWall);
    _label(canvas, '32\nInnovation\nLab', 350, 660, 8.5,
        color: const Color(0xFF1E3A8A));

    // Discussion Area 40 (small)
    final disc = Rect.fromLTWH(446, 640, 110, 60);
    canvas.drawRect(disc, _roomFill);
    canvas.drawRect(disc, _thinWall);
    _label(canvas, '40 Discussion\nArea', 452, 650, 8.0,
        color: const Color(0xFF374151));

    // Study Space 33 (right of innovation)
    final s33 = Rect.fromLTWH(446, 700, 110, 60);
    canvas.drawRect(s33, _roomFill);
    canvas.drawRect(s33, _thinWall);
    _label(canvas, '33 Study\nSpace', 452, 713, 8.0,
        color: const Color(0xFF374151));

    // Center for Excellence 31
    final coe = Rect.fromLTWH(338, 760, 218, 85);
    canvas.drawRect(coe, _labFill);
    canvas.drawRect(coe, _thinWall);
    _label(canvas, '31 Center for Excellence', 345, 795, 8.0,
        color: const Color(0xFF1E3A8A));

    // Record Room 34 + Store 35
    final r34 = Rect.fromLTWH(338, 850, 100, 80);
    canvas.drawRect(r34, _roomFill);
    canvas.drawRect(r34, _thinWall);
    _label(canvas, '34 Record\nRoom', 344, 863, 8.0,
        color: const Color(0xFF374151));

    final r35 = Rect.fromLTWH(440, 850, 90, 80);
    canvas.drawRect(r35, _roomFill);
    canvas.drawRect(r35, _thinWall);
    _label(canvas, '35 Store\nRoom', 447, 863, 8.0,
        color: const Color(0xFF374151));

    // Guest Lounge 36
    final gl = Rect.fromLTWH(160, 750, 150, 90);
    canvas.drawRect(gl, _roomFill);
    canvas.drawRect(gl, _thinWall);
    _label(canvas, '36 Guest\'s\nLounge', 175, 785, 8.5,
        color: const Color(0xFF374151));

    // Visitors Lounge 38
    final vl = Rect.fromLTWH(30, 860, 130, 140);
    canvas.drawRect(vl, _roomFill);
    canvas.drawRect(vl, _thinWall);
    _label(canvas, '38 Visitor\'s\nLounge', 40, 910, 8.5,
        color: const Color(0xFF374151));

    // Admission 37
    final adm = Rect.fromLTWH(160, 860, 130, 80);
    canvas.drawRect(adm, _roomFill);
    canvas.drawRect(adm, _thinWall);
    _label(canvas, '37 Admission\nSection', 165, 877, 8.0,
        color: const Color(0xFF374151));

    // Fee Counter 39
    final fc = Rect.fromLTWH(160, 942, 130, 58);
    canvas.drawRect(fc, _roomFill);
    canvas.drawRect(fc, _thinWall);
    _label(canvas, '39 Fee\nCounter', 175, 955, 8.0,
        color: const Color(0xFF374151));

    // Discussion Room 40 (lower), Room 41, 42, Study 43 (far left column)
    final r43 = Rect.fromLTWH(30, 640, 120, 105);
    canvas.drawRect(r43, _roomFill);
    canvas.drawRect(r43, _thinWall);
    _label(canvas, '43 Study\nSpace', 50, 675, 8.5,
        color: const Color(0xFF374151));

    final r41 = Rect.fromLTWH(30, 745, 130, 50);
    canvas.drawRect(r41, _roomFill);
    canvas.drawRect(r41, _thinWall);
    _label(canvas, '41  42', 62, 763, 8.5, color: const Color(0xFF374151));

    // Board Room 44 (left wing)
    final br = Rect.fromLTWH(30, 475, 20, 130);
    canvas.drawRect(br, _roomFill);
    canvas.drawRect(br, _thinWall);
    _label(canvas, '44', 30, 527, 7.5, color: const Color(0xFF374151));

    // Study Space top zone (next to Dept Placement)
    final r13z = Rect.fromLTWH(30, 345, 266, 25);
    canvas.drawRect(r13z, Paint()..color = const Color(0xFFF1F5F9));
  }

  // ── 9. Entry points ──────────────────────────────────────
  void _drawEntries(Canvas canvas) {
    // Main Entry (bottom center-left)
    final entryPaint = Paint()
      ..color = const Color(0xFF15803D)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(195, 1060), const Offset(195, 1040), entryPaint);

    _label(canvas, '▲ MAIN ENTRY', 130, 1048, 11.0,
        color: const Color(0xFF15803D), bold: true);

    // Secondary Entry (right of visitor's lounge)
    canvas.drawLine(const Offset(100, 1000), const Offset(100, 1060), entryPaint);
    _label(canvas, 'ENTRY', 75, 1035, 8.5,
        color: const Color(0xFF15803D), bold: true);
  }

  // ── 10. Floor Banner ─────────────────────────────────────
  void _drawFloorBanner(Canvas canvas, Size size) {
    final bannerPaint = Paint()..color = const Color(0xFF1E3A8A);
    const bannerRect = Rect.fromLTWH(360, 1062, 280, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bannerRect, const Radius.circular(6)),
      bannerPaint,
    );
    _label(canvas, 'GROUND FLOOR', 400, 1069, 13.5,
        color: Colors.white, bold: true, letterSpacing: 1.5);
  }

  // ── 11. Sahyadri Crest ────────────────────────────────────
  void _drawSahyadriCrest(Canvas canvas, double x, double y) {
    final fill = Paint()..color = const Color(0xFF15803D);
    final border = Paint()
      ..color = const Color(0xFFB45309)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path()
      ..moveTo(x + 20, y)
      ..lineTo(x + 65, y)
      ..lineTo(x + 75, y + 42)
      ..quadraticBezierTo(x + 42, y + 74, x + 42, y + 78)
      ..quadraticBezierTo(x + 42, y + 74, x + 10, y + 42)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);

    _label(canvas, 'S', x + 29, y + 12, 30,
        color: Colors.white, bold: true);
    _label(canvas, 'SAHYADRI', x + 14, y + 80, 9,
        color: const Color(0xFFB45309), bold: true, letterSpacing: 1.2);
  }

  // ── 12. Compass Rose ──────────────────────────────────────
  void _drawCompass(Canvas canvas, double cx, double cy) {
    final linePaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx, cy - 22), Offset(cx, cy + 22), linePaint);
    canvas.drawLine(Offset(cx - 22, cy), Offset(cx + 22, cy), linePaint);

    final nPath = Path()
      ..moveTo(cx, cy - 22)
      ..lineTo(cx - 5, cy)
      ..lineTo(cx + 5, cy)
      ..close();
    canvas.drawPath(
        nPath,
        Paint()
          ..color = const Color(0xFFDC2626)
          ..style = PaintingStyle.fill);

    _label(canvas, 'N', cx - 4, cy - 34, 10,
        color: const Color(0xFFDC2626), bold: true);
  }

  // ── Utility: vertical line helper ─────────────────────────
  void _vLine(Canvas canvas, double x, double yTop, double yBottom) {
    canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), _thinWall);
  }

  // ── Utility: text label ────────────────────────────────────
  void _label(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize, {
    Color color = const Color(0xFF374151),
    bool bold = false,
    double letterSpacing = 0.0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: color,
          letterSpacing: letterSpacing,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _GroundFloorPainter old) =>
      old.floorLevel != floorLevel || old.floorName != floorName;
}

// ─────────────────────────────────────────────────────────────
//  Navigation Route Painter — Dijkstra shortest path with
//  directional animated walking arrows and start/dest badges.
// ─────────────────────────────────────────────────────────────
class _NavigationRoutePainter extends CustomPainter {
  final NavigationRoute route;
  final double pulseProgress;

  _NavigationRoutePainter({
    required this.route,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (route.nodes.length < 2) return;

    final path = Path();
    path.moveTo(route.nodes.first.x, route.nodes.first.y);
    for (int i = 1; i < route.nodes.length; i++) {
      path.lineTo(route.nodes[i].x, route.nodes[i].y);
    }

    // Outer vibrant glow
    final glowPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.35)
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Inner navigation core
    final corePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 4.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, corePaint);

    // Directional arrows along each segment (rotating toward next node)
    for (int i = 0; i < route.nodes.length - 1; i++) {
      final a = route.nodes[i];
      final b = route.nodes[i + 1];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final segLen = math.sqrt(dx * dx + dy * dy);
      if (segLen < 15.0) continue;

      final angle = math.atan2(dy, dx);
      const step = 34.0;
      final offset = (pulseProgress * step) % step;

      for (double d = offset; d < segLen - 8.0; d += step) {
        if (d < 6.0) continue;
        final t = d / segLen;
        final px = a.x + dx * t;
        final py = a.y + dy * t;

        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(angle);

        // Arrow chevron pointing in direction of travel
        final arrowPath = Path()
          ..moveTo(-3.5, -4.0)
          ..lineTo(4.0, 0.0)
          ..lineTo(-3.5, 4.0)
          ..lineTo(-1.0, 0.0)
          ..close();

        canvas.drawPath(
          arrowPath,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );

        canvas.restore();
      }
    }

    // Start point marker (Green)
    final start = route.nodes.first;
    final startOffset = Offset(start.x, start.y);
    canvas.drawCircle(
      startOffset,
      12.0 + (pulseProgress * 3.0),
      Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      startOffset,
      7.0,
      Paint()..color = const Color(0xFF10B981),
    );
    canvas.drawCircle(
      startOffset,
      7.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Destination point marker (Red)
    final dest = route.nodes.last;
    final destOffset = Offset(dest.x, dest.y);
    canvas.drawCircle(
      destOffset,
      12.0 + (pulseProgress * 3.0),
      Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      destOffset,
      7.0,
      Paint()..color = const Color(0xFFEF4444),
    );
    canvas.drawCircle(
      destOffset,
      7.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _NavigationRoutePainter old) =>
      old.route != route || old.pulseProgress != pulseProgress;
}

// ─────────────────────────────────────────────────────────────
//  Navigation Debug Painter — development-only graph visualizer
// ─────────────────────────────────────────────────────────────
class _NavigationDebugPainter extends CustomPainter {
  final bool isEnabled;
  final String? activeDestNodeId;

  _NavigationDebugPainter({
    required this.isEnabled,
    this.activeDestNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isEnabled) return;

    final navService = NavigationService();
    final nodes = navService.getNodesForFloor('ground');
    final edges = navService.getEdgesForFloor('ground');
    final nodeMap = {for (final n in nodes) n.id: n};

    // Draw walkable edges
    final edgePaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.60)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final from = nodeMap[edge.fromNode];
      final to = nodeMap[edge.toNode];
      if (from != null && to != null) {
        canvas.drawLine(
          Offset(from.x, from.y),
          Offset(to.x, to.y),
          edgePaint,
        );
      }
    }

    // Draw nodes
    for (final node in nodes) {
      Color color;
      if (node.id == activeDestNodeId) {
        color = const Color(0xFFEF4444); // 🔴 Active destination
      } else if (node.type == NodeType.roomDoor) {
        color = const Color(0xFF2563EB); // 🔵 Room door
      } else if (node.type == NodeType.staircase) {
        color = const Color(0xFFF97316); // 🟠 Stair
      } else if (node.type == NodeType.destination) {
        color = const Color(0xFF8B5CF6); // 🟣 Destination
      } else {
        color = const Color(0xFF10B981); // 🟢 Corridor / entrance
      }

      final offset = Offset(node.x, node.y);
      canvas.drawCircle(offset, 4.5, Paint()..color = color);
      canvas.drawCircle(
        offset,
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NavigationDebugPainter old) =>
      old.isEnabled != isEnabled || old.activeDestNodeId != activeDestNodeId;
}

// ─────────────────────────────────────────────────────────────
//  Navigation Top Panel — Turn-by-Turn banner and stepper
// ─────────────────────────────────────────────────────────────
class _NavigationTopPanel extends StatefulWidget {
  final NavigationRoute route;
  final Room destination;
  final String startLabel;
  final VoidCallback onClose;
  final VoidCallback onChangeStart;
  final VoidCallback onOpenAR;
  final ValueChanged<TurnInstruction>? onInstructionTap;

  const _NavigationTopPanel({
    required this.route,
    required this.destination,
    required this.startLabel,
    required this.onClose,
    required this.onChangeStart,
    required this.onOpenAR,
    this.onInstructionTap,
  });

  @override
  State<_NavigationTopPanel> createState() => _NavigationTopPanelState();
}

class _NavigationTopPanelState extends State<_NavigationTopPanel> {
  int _currentStep = 0;

  @override
  void didUpdateWidget(covariant _NavigationTopPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      _currentStep = 0;
    }
  }

  IconData _instructionIcon(String? iconType) {
    switch (iconType) {
      case 'turn_left':
        return Icons.turn_left_rounded;
      case 'turn_right':
        return Icons.turn_right_rounded;
      case 'straight':
        return Icons.straight_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      case 'start':
      default:
        return Icons.navigation_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructions = widget.route.instructions;
    final hasInstructions = instructions.isNotEmpty;
    final currentInstruction =
        hasInstructions && _currentStep < instructions.length
            ? instructions[_currentStep]
            : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Start -> Dest + Close
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                // Start
                InkWell(
                  onTap: widget.onChangeStart,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: Text(
                            widget.startLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more_rounded,
                            size: 14, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                ),
                // Destination
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.destination.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Distance, Time & AR button row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten_rounded,
                          size: 13, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.route.totalDistance} m',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_walk_rounded,
                          size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.route.estimatedWalkingMinutes} min walk',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: widget.onOpenAR,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.view_in_ar_rounded,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Live AR',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Turn-by-Turn Instruction Banner
          if (currentInstruction != null) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _instructionIcon(currentInstruction.icon),
                      size: 18,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentInstruction.text,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Step ${_currentStep + 1} of ${instructions.length}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stepper buttons
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _currentStep > 0
                        ? () {
                            setState(() => _currentStep--);
                            widget.onInstructionTap
                                ?.call(instructions[_currentStep]);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _currentStep < instructions.length - 1
                        ? () {
                            setState(() => _currentStep++);
                            widget.onInstructionTap
                                ?.call(instructions[_currentStep]);
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

