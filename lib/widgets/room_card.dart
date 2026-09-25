import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';

/// A list tile card representing a single room search result.
class RoomCard extends StatelessWidget {
  final Room room;

  const RoomCard({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColor(room.category.name);
    final icon  = AppTheme.categoryIcon(room.category.name);

    return Card(
      child: InkWell(
        onTap: () => context.push('/room/${room.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Category icon bubble ───────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),

              // ── Room info ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(label: room.roomNumber),
                        const SizedBox(width: 6),
                        _Chip(
                          label: room.floor == 'ground'
                              ? 'Ground Floor'
                              : room.floor == 'first'
                                  ? '1st Floor'
                                  : '2nd Floor',
                          icon: Icons.layers_outlined,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          label: room.category.displayName,
                          color: color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Arrow ──────────────────────────────────────────
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const _Chip({required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? AppTheme.textSecondary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color ?? AppTheme.textSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
