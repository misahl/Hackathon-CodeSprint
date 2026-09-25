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
import '../widgets/scaffold_with_bottom_nav.dart';

class AppRoutes {
  AppRoutes._();
  static const home        = '/';
  static const map         = '/map';
  static const search      = '/search';
  static const ar          = '/ar';
  static const roomDetails = '/room/:id';
  static const profile     = '/profile';
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

/// Minimal profile placeholder — expand in a future sprint.
class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          // TODO (Firebase): Add login/logout, user profile, and
          // saved locations once Firebase Auth is integrated.
          ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('About Sahyadri AR'),
            subtitle: Text('Version 1.0.0-beta'),
          ),
          ListTile(
            leading: Icon(Icons.school_rounded),
            title: Text('Sahyadri College'),
            subtitle: Text('Adyar, Mangaluru, Karnataka — 575007'),
          ),
          ListTile(
            leading: Icon(Icons.bug_report_outlined),
            title: Text('Report an Issue'),
            subtitle: Text('Help us improve the campus map'),
          ),
        ],
      ),
    );
  }
}
