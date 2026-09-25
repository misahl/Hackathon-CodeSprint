import 'package:flutter/material.dart';
import '../models/floor.dart';
import '../theme/app_theme.dart';

/// Horizontal pill-style floor selector.
/// Displays Ground / 1st / 2nd floor tabs.
class FloorSelector extends StatelessWidget {
  final Floor selectedFloor;
  final ValueChanged<Floor> onFloorChanged;

  const FloorSelector({
    super.key,
    required this.selectedFloor,
    required this.onFloorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: Floors.all.map((floor) {
          final isSelected = floor.id == selectedFloor.id;
          return _FloorTab(
            floor: floor,
            isSelected: isSelected,
            isFirst: floor == Floors.all.first,
            isLast: floor == Floors.all.last,
            onTap: () => onFloorChanged(floor),
          );
        }).toList(),
      ),
    );
  }
}

class _FloorTab extends StatelessWidget {
  final Floor floor;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _FloorTab({
    required this.floor,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(11) : Radius.zero,
      right: isLast ? const Radius.circular(11) : Radius.zero,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary : Colors.transparent,
        borderRadius: radius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            floor.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
