import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Large primary navigation action button.
/// Used for "View Map" and "AR Navigation" on the home screen.
class NavigationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;

  const NavigationButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (isPrimary ? AppTheme.primary : AppTheme.secondary);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bg, bg.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.white.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
