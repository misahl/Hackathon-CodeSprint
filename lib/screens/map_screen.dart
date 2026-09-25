// ─────────────────────────────────────────────────────────────
//  Map Screen
//  Full-screen interactive map with search, floor selector,
//  and navigation overlay.
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
  }

  void _onMapCreated(MapboxMap map) {
    _mapService.onMapCreated(map);
    setState(() => _mapLoaded = true);
    _mapService.flyToCollege();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasSelectedRoom = state.selectedRoom != null;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map view (Blueprint canvas on Web & Desktop, native Mapbox only on real Android/iOS) ──
          if (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS))
            MapWidget(
              key: const ValueKey('campus-map'),
              viewport: CameraViewportState(
                center: Point(coordinates: Position(74.8479, 12.9173)),
                zoom: 17.0,
                pitch: 45.0,
              ),
              onMapCreated: _onMapCreated,
            )
          else
            CampusWebMapView(
              selectedFloor: state.selectedFloor,
              onMapTap: () {
                _searchFocusNode.unfocus();
                if (_isSearching) {
                  setState(() => _isSearching = false);
                }
              },
            ),

          // ── Floor selector overlay ───────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
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

          // ── Floor label (placeholder on native mobile until floor plan is ready) ──
          if (_mapLoaded)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: _FloatingCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_rounded,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${state.selectedFloor.name} • Indoor map coming soon',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Right-side FABs (Repositioned above bottom info card if open) ──
          Positioned(
            right: 16,
            bottom: hasSelectedRoom ? 245 : 100,
            child: Column(
              children: [
                _MapFab(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Reset Campus View',
                  onTap: () {
                    state.clearSelectedRoom();
                    _mapService.flyToCollege();
                  },
                ),
                const SizedBox(height: 10),
                _MapFab(
                  icon: Icons.navigation_rounded,
                  tooltip: 'AR Navigation',
                  onTap: () => context.push('/ar'),
                  color: AppTheme.primary,
                  iconColor: Colors.white,
                ),
              ],
            ),
          ),

          // ── Top Search Bar Overlay & Instant Dropdown Suggestions ──
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
                            hintText: 'Search room, lab, or number (e.g. 27)...',
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

                // Instant Search Suggestions Dropdown (Requirement 8)
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
                            'Room ${room.roomNumber} • $floorName',
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
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────

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
                    : color.withValues(alpha: 0.4),
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
