import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Persistent bottom navigation bar shell.
/// Wraps all top-level tab screens.
class ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;

  const ScaffoldWithBottomNav({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined,     activeIcon: Icons.home_rounded,          label: 'Home',   path: '/'),
    _TabItem(icon: Icons.map_outlined,       activeIcon: Icons.map_rounded,           label: 'Map',    path: '/map'),
    _TabItem(icon: Icons.search_outlined,    activeIcon: Icons.search_rounded,        label: 'Search', path: '/search'),
    _TabItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,   label: 'More',   path: '/profile'),
  ];

  int _locationToTabIndex(String location) {
    if (location.startsWith('/map'))    return 1;
    if (location.startsWith('/search')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToTabIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;
                return _NavBarItem(
                  tab: tab,
                  isActive: isActive,
                  onTap: () => context.go(tab.path),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

class _NavBarItem extends StatelessWidget {
  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? tab.activeIcon : tab.icon,
                  key: ValueKey(isActive),
                  color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
