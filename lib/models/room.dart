// ─────────────────────────────────────────────────────────────
//  Room model
//  Represents a physical space (room, lab, office, facility)
//  within the college campus.
//
//  TODO (Firebase): Replace local JSON loading in SearchService
//  with a Firestore collection fetch when Firebase is integrated.
//
//  TODO (Indoor Positioning): Add real-time occupancy status field
//  once BLE beacon / WiFi fingerprinting data is available.
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

/// Categories for campus spaces.
enum RoomCategory {
  lab,
  office,
  facility,
  hall,
  classroom,
  staircase,
  entrance,
  other;

  String get displayName {
    switch (this) {
      case RoomCategory.lab:
        return 'Laboratory';
      case RoomCategory.office:
        return 'Office';
      case RoomCategory.facility:
        return 'Facility';
      case RoomCategory.hall:
        return 'Hall';
      case RoomCategory.classroom:
        return 'Classroom';
      case RoomCategory.staircase:
        return 'Staircase';
      case RoomCategory.entrance:
        return 'Entrance';
      case RoomCategory.other:
        return 'Other';
    }
  }

  /// Icon name hint for the UI layer.
  String get iconHint {
    switch (this) {
      case RoomCategory.lab:
        return 'computer';
      case RoomCategory.office:
        return 'business';
      case RoomCategory.facility:
        return 'place';
      case RoomCategory.hall:
        return 'meeting_room';
      case RoomCategory.classroom:
        return 'school';
      case RoomCategory.staircase:
        return 'stairs';
      case RoomCategory.entrance:
        return 'login';
      case RoomCategory.other:
        return 'room';
    }
  }

  static RoomCategory fromString(String value) {
    return RoomCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RoomCategory.other,
    );
  }
}

/// Lightweight 2-D coordinate placeholder.
/// TODO (Navigation): Replace with MapboxCoordinate (lat/lng) or
/// a graph node reference once indoor navigation is implemented.
class RoomCoordinates extends Equatable {
  final double x;
  final double y;

  const RoomCoordinates({required this.x, required this.y});

  factory RoomCoordinates.fromJson(Map<String, dynamic> json) {
    return RoomCoordinates(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  @override
  List<Object?> get props => [x, y];
}

/// Core room data model.
class Room extends Equatable {
  final String id;
  final String name;
  final String roomNumber;
  final String floor;        // 'ground' | 'first' | 'second'
  final int floorLevel;      // 0, 1, 2 …
  final RoomCategory category;
  final String description;
  final RoomCoordinates coordinates;

  const Room({
    required this.id,
    required this.name,
    required this.roomNumber,
    required this.floor,
    required this.floorLevel,
    required this.category,
    required this.description,
    required this.coordinates,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      roomNumber: json['roomNumber'] as String,
      floor: json['floor'] as String,
      floorLevel: json['floorLevel'] as int,
      category: RoomCategory.fromString(json['category'] as String),
      description: json['description'] as String,
      coordinates: RoomCoordinates.fromJson(
        json['coordinates'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roomNumber': roomNumber,
        'floor': floor,
        'floorLevel': floorLevel,
        'category': category.name,
        'description': description,
        'coordinates': coordinates.toJson(),
      };

  @override
  List<Object?> get props => [id, name, roomNumber, floor, floorLevel, category];
}
