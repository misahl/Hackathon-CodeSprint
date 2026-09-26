// ─────────────────────────────────────────────────────────────
//  App Router — go_router configuration
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/map_screen.dart';
import '../screens/search_screen.dart';
import '../screens/room_details_screen.dart';
import '../screens/ar_screen.dart';
import '../screens/admin_map_editor_screen.dart';
import '../screens/admin_manage_floors_screen.dart';
import '../screens/admin_manage_paths_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/scaffold_with_bottom_nav.dart';

class AppRoutes {
  AppRoutes._();
  static const home        = '/';
  static const map         = '/map';
  static const search      = '/search';
  static const ar          = '/ar';
  static const roomDetails = '/room/:id';
  static const profile     = '/profile';
  static const adminEditor = '/admin/editor';
  static const adminFloors = '/admin/floors';
  static const adminPaths  = '/admin/paths';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    // Shell wraps the bottom-nav screens
    ShellRoute(
      builder: (context, state, child) =>
          ScaffoldWithBottomNav(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) =>
              _fade(state, const HomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.map,
          pageBuilder: (context, state) =>
              _fade(state, const MapScreen()),
        ),
        GoRoute(
          path: AppRoutes.search,
          pageBuilder: (context, state) =>
              _fade(state, const SearchScreen()),
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) =>
              _fade(state, const _ProfilePlaceholder()),
        ),
      ],
    ),

    // Full-screen routes (no bottom nav)
    GoRoute(
      path: '/room/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RoomDetailsScreen(roomId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.ar,
      builder: (context, state) => const ArScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminEditor,
      builder: (context, state) => const AdminMapEditorScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminFloors,
      builder: (context, state) => const AdminManageFloorsScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminPaths,
      builder: (context, state) => const AdminManagePathsScreen(),
    ),
  ],
);

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, widget) =>
        FadeTransition(opacity: animation, child: widget),
  );
}

/// Rich Campus Directory, Emergency Contacts & Mapo MVP Guide screen
class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Campus Directory & Info'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sahyadri College',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Campus Indoor Navigation (Mapo)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Sahyadri College of Engineering & Management, Adyar, Mangaluru, Karnataka 575007',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Key Sections
          const Text(
            'KEY DEPARTMENTS & OFFICES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          _buildInfoTile(
            context,
            icon: Icons.computer_rounded,
            title: 'Computer Science & Engineering',
            subtitle: 'Ground & First Floor • Computer Lab 27, Labs 21-26',
            actionText: 'Find on Map',
            onTap: () => context.go('/map'),
          ),
          _buildInfoTile(
            context,
            icon: Icons.precision_manufacturing_rounded,
            title: 'Mechanical Engineering',
            subtitle: 'Ground Floor • Foundry & Forging, Workshops, Seminar Hall',
            actionText: 'Find on Map',
            onTap: () => context.go('/map'),
          ),
          _buildInfoTile(
            context,
            icon: Icons.account_balance_rounded,
            title: 'Administrative Block',
            subtitle: 'Ground Floor • Principal\'s Chamber, Foundation Office',
            actionText: 'Find on Map',
            onTap: () => context.go('/map'),
          ),

          const SizedBox(height: 20),
          const Text(
            'CAMPUS EMERGENCY CONTACTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          _buildEmergencyCard(
            title: 'Campus Security & Main Gate',
            phone: '+91 824 2277222',
            icon: Icons.security_rounded,
          ),
          _buildEmergencyCard(
            title: 'First Aid & Health Center',
            phone: 'Ext: 108 / Ground Floor Block A',
            icon: Icons.local_hospital_rounded,
          ),

          const SizedBox(height: 20),
          const Text(
            'APP INFORMATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/mapo_logo.png',
                            width: 26,
                            height: 26,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Mapo - The Sahyadri AR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                    const Text('v1.0.0 MVP', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Powered by custom Dijkstra indoor pathfinding, full campus GeoJSON blueprint, and live Camera AR guidance.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ADMIN SECTION ──────────────────────────────────────────
          const Text(
            'ADMIN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          _buildAdminTile(
            context,
            icon: Icons.edit_location_alt_rounded,
            title: 'Admin Map Editor',
            subtitle: 'Manually draw walkable corridors, drop nodes & set room doors',
            badge: 'HACKATHON CORE',
            badgeColor: const Color(0xFF10B981),
            onTap: () => context.push(AppRoutes.adminEditor),
          ),
          _buildAdminTile(
            context,
            icon: Icons.layers_rounded,
            title: 'Manage Floors',
            subtitle: 'Configure Ground, 1st & 2nd floor navigation plans',
            onTap: () => context.push(AppRoutes.adminFloors),
          ),
          _buildAdminTile(
            context,
            icon: Icons.alt_route_rounded,
            title: 'Manage Navigation Paths',
            subtitle: 'Review & toggle corridor segments and node connections',
            onTap: () => context.push(AppRoutes.adminPaths),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(actionText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard({
    required String title,
    required String phone,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFEF4444), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(phone, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF38BDF8), size: 22),
        ),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppTheme.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: badgeColor ?? AppTheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
        onTap: onTap,
      ),
    );
  }
}
