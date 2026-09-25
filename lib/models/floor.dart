// ─────────────────────────────────────────────────────────────
//  Floor model
//  Represents a building floor level in the campus.
//
//  TODO (Floor Plan): When indoor map tiles/GeoJSON overlays are
//  added, each Floor will reference a tileSet ID or GeoJSON asset
//  path specific to that level.
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Represents a single floor of the campus building.
class Floor extends Equatable {
  final String id;
  final String name;
  final int level; // 0 = Ground, 1 = First, 2 = Second …

  const Floor({
    required this.id,
    required this.name,
    required this.level,
  });

  @override
  List<Object?> get props => [id, level];

  @override
  String toString() => 'Floor($name, level=$level)';
}

/// Static list of all available floors.
///
/// TODO (Firebase): Fetch this list from Firestore when the building
/// configuration is managed remotely.
class Floors {
  Floors._();

  static const Floor ground = Floor(
    id: 'ground',
    name: 'Ground Floor',
    level: 0,
  );

  static const Floor first = Floor(
    id: 'first',
    name: '1st Floor',
    level: 1,
  );

  static const Floor second = Floor(
    id: 'second',
    name: '2nd Floor',
    level: 2,
  );

  /// All floors in ascending order.
  static const List<Floor> all = [ground, first, second];

  /// Returns the [Floor] matching the given [id], or [ground] as default.
  static Floor fromId(String id) {
    return all.firstWhere(
      (f) => f.id == id,
      orElse: () => ground,
    );
  }
}
