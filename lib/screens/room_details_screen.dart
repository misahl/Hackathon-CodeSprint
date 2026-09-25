// ─────────────────────────────────────────────────────────────
//  Room Details Screen
//  Displays full info for a selected room with action buttons.
//
//  TODO (Navigation): The "Navigate" button should trigger
//  NavigationService.findRoute(from, to) and pass the result
//  to MapService.drawRoute() before pushing /ar or /map.
//
//  TODO (Firebase): Load live occupancy status, booking info,
//  and room images from Firestore and Firebase Storage.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../providers/app_state.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

class RoomDetailsScreen extends StatelessWidget {
  final String roomId;

  const RoomDetailsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final room = SearchService().findById(roomId);

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Details')),
        body: const Center(child: Text('Room not found.')),
      );
    }

    return _RoomDetailsView(room: room);
  }
}

class _RoomDetailsView extends StatelessWidget {
  final Room room;

  const _RoomDetailsView({required this.room});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColor(room.category.name);
    final icon  = AppTheme.categoryIcon(room.category.name);
    final floorLabel = room.floor == 'ground'
        ? 'Ground Floor'
        : room.floor == 'first'
            ? '1st Floor'
            : '2nd Floor';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero app bar ───────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: color,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Detail cards ───────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Info grid
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.tag_rounded,
                        label: 'Room Number',
                        value: room.roomNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.layers_rounded,
                        label: 'Floor',
                        value: floorLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: icon,
                  label: 'Category',
                  value: room.category.displayName,
                  wide: true,
                ),
                const SizedBox(height: 12),

                // Description card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        room.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Action buttons
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<AppState>().setNavigationDestination(room);
                    // TODO (Navigation): Call NavigationService.findRoute() here
                    // before pushing AR screen.
                    context.push('/ar');
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Navigate Here'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AppState>().selectRoom(room);
                    context.go('/map');
                  },
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('View on Map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool wide;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
