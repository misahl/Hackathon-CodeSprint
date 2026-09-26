// ─────────────────────────────────────────────────────────────
//  Map Screen
//  Full-screen Mapbox indoor interactive campus map with search,
//  floor switching, route line visualization, and debug graph.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../providers/app_state.dart';
import '../services/map_service.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import '../widgets/campus_web_map_view.dart';
import '../widgets/floor_selector.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapService _mapService = MapService();
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _mapLoaded = false;
  List<Room> _searchSuggestions = [];
  bool _isSearching = false;

  String? _renderedRouteKey;
  String? _renderedFloorId;

  @override
  void initState() {
    super.initState();
    _searchService.init();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearching = _searchFocusNode.hasFocus &&
            _searchController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    final results = _searchService.search(query);
    setState(() {
      _searchSuggestions = results.take(5).toList();
      _isSearching = true;
    });
  }

  void _onSelectRoom(Room room) {
    final state = context.read<AppState>();
    state.selectRoom(room);
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchSuggestions = [];
      _isSearching = false;
    });

    // Fly camera to room coordinates on Mapbox
    final doorNode = room.coordinates;
    final geoLng = MapService.campusCenterLng +
        ((doorNode.x - 500) / 1000.0) * 0.00105;
    final geoLat = MapService.campusCenterLat +
        ((540 - doorNode.y) / 1080.0) * 0.00105;
    _mapService.flyToCoordinates(geoLng, geoLat, zoom: 19.2);
  }

  void _onMapCreated(MapboxMap map) {
    _mapService.onMapCreated(map);
    setState(() => _mapLoaded = true);
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    await _mapService.onStyleLoaded();
    if (mounted) {
      final state = context.read<AppState>();
      if (state.currentRoute != null) {
        await _mapService.drawRoute(state.currentRoute!);
        await _mapService.fitRoute(state.currentRoute!);
      }
    }
  }

  void _handleStateUpdates(AppState state) {
    // 1. Check floor changes
    if (_mapLoaded && _renderedFloorId != state.selectedFloor.id) {
      _renderedFloorId = state.selectedFloor.id;
      _mapService.switchFloor(state.selectedFloor.id);
    }

    // 2. Check route updates
    final currentRoute = state.currentRoute;
    final routeKey = currentRoute != null
        ? '${currentRoute.nodes.first.id}->${currentRoute.nodes.last.id}'
        : null;

    if (routeKey != _renderedRouteKey) {
      _renderedRouteKey = routeKey;
      if (currentRoute != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _mapService.drawRoute(currentRoute);
          await _mapService.fitRoute(currentRoute);
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _mapService.clearRoute();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _handleStateUpdates(state);

    final hasSelectedRoom = state.selectedRoom != null;
    final isNavigating = state.isNavigating && state.currentRoute != null;

    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      body: Stack(
        children: [
          // ── Map View ───────────────────────────────────────────────
          if (isMobile)
            MapWidget(
              key: const ValueKey('campus-mapbox-native'),
              viewport: CameraViewportState(
                center: Point(
                  coordinates: Position(
                    MapService.campusCenterLng,
                    MapService.campusCenterLat,
                  ),
                ),
                zoom: 18.2,
                pitch: 30.0,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
            )
          else
            // Fallback interactive blueprint vector map for Web & Desktop Preview
            CampusWebMapView(
              selectedFloor: state.selectedFloor,
              onMapTap: () {
                _searchFocusNode.unfocus();
                if (_isSearching) {
                  setState(() => _isSearching = false);
                }
              },
            ),

          // ── Floor Selector Overlay ──────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + (isNavigating ? 108 : 76),
            left: 16,
            child: _FloatingCard(
              child: FloorSelector(
                selectedFloor: state.selectedFloor,
                onFloorChanged: (floor) {
                  state.selectFloor(floor);
                  _mapService.switchFloor(floor.id);
                },
              ),
            ),
          ),

          // ── Active Navigation Banner (When routing is active) ───────
          if (isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: _NavigationBanner(
                route: state.currentRoute!,
                destination: state.navigationDestination,
                onCancel: () {
                  state.stopNavigation();
                  _mapService.clearRoute();
                },
              ),
            )
          else
            // ── Top Search Bar Overlay & Suggestions ───────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Back button
                      _MapButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.go('/'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.cardSurface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search room, lab, or office...',
                              hintStyle: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AppTheme.primary, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: AppTheme.textSecondary),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchSuggestions = [];
                                          _isSearching = false;
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search Suggestions Dropdown
                  if (_isSearching && _searchSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6, left: 54),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: _searchSuggestions.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final room = _searchSuggestions[index];
                          final catColor =
                              AppTheme.categoryColor(room.category.name);
                          final catIcon =
                              AppTheme.categoryIcon(room.category.name);
                          final floorName = room.floor == 'ground'
                              ? 'Ground Floor'
                              : (room.floor == 'first'
                                  ? '1st Floor'
                                  : '2nd Floor');

                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(catIcon, color: catColor, size: 16),
                            ),
                            title: Text(
                              room.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${room.roomNumber.isNotEmpty ? 'Room ${room.roomNumber} • ' : ''}$floorName',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            onTap: () => _onSelectRoom(room),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // ── Right-Side Action FABs ──────────────────────────────────
          Positioned(
            right: 16,
            bottom: hasSelectedRoom && !isNavigating ? 190 : 100,
            child: Column(
              children: [
                // Re-center Campus View
                _MapFab(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Reset Campus View',
                  onTap: () {
                    _mapService.flyToCollege();
                  },
                ),
                const SizedBox(height: 10),

                // Toggle Debug Navigation Graph
                _MapFab(
                  icon: Icons.hub_rounded,
                  tooltip: 'Toggle Navigation Graph (Debug)',
                  color: state.debugMode ? AppTheme.primary : AppTheme.cardSurface,
                  iconColor: state.debugMode ? Colors.white : AppTheme.textPrimary,
                  onTap: () async {
                    state.toggleDebugMode();
                    await _mapService.toggleDebugMode();
                  },
                ),
                const SizedBox(height: 10),

                // AR Screen
                _MapFab(
                  icon: Icons.view_in_ar_rounded,
                  tooltip: 'AR Navigation',
                  onTap: () => context.push('/ar'),
                  color: AppTheme.primary,
                  iconColor: Colors.white,
                ),
              ],
            ),
          ),

          // ── Bottom Selected Room Card ───────────────────────────────
          if (hasSelectedRoom && !isNavigating)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _SelectedRoomBottomCard(
                room: state.selectedRoom!,
                onClose: () => state.clearSelectedRoom(),
                onDetails: () => context.push('/room/${state.selectedRoom!.id}'),
                onNavigate: () {
                  state.setNavigationDestination(state.selectedRoom!);
                  state.startNavigation();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Sub-Widgets
// ─────────────────────────────────────────────────────────────

class _NavigationBanner extends StatelessWidget {
  final dynamic route;
  final Room? destination;
  final VoidCallback onCancel;

  const _NavigationBanner({
    required this.route,
    required this.destination,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final destName = destination?.name ?? 'Destination';
    final dist = route.totalDistance;
    final mins = route.estimatedWalkingMinutes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'To: $destName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dist m • ~$mins min walk • Indoor Route',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'End Navigation',
          ),
        ],
      ),
    );
  }
}

class _SelectedRoomBottomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onNavigate;

  const _SelectedRoomBottomCard({
    required this.room,
    required this.onClose,
    required this.onDetails,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.categoryColor(room.category.name);
    final catIcon = AppTheme.categoryIcon(room.category.name);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${room.roomNumber.isNotEmpty ? 'Room ${room.roomNumber} • ' : ''}${room.floor == 'ground' ? 'Ground Floor' : room.floor}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Room Details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text(
                    'Navigate',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  final Widget child;
  const _FloatingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: AppTheme.textPrimary, size: 20),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppTheme.cardSurface,
    this.iconColor = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color == AppTheme.cardSurface
                    ? Colors.black.withValues(alpha: 0.10)
                    : color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}
