import 'package:equatable/equatable.dart';

enum NodeType {
  entrance,
  corridor,
  junction,
  turn,
  roomDoor,
  staircase,
  elevator,
  destination;

  static NodeType fromString(String val) {
    switch (val) {
      case 'entrance':
        return NodeType.entrance;
      case 'junction':
        return NodeType.junction;
      case 'turn':
        return NodeType.turn;
      case 'room_door':
      case 'roomDoor':
        return NodeType.roomDoor;
      case 'staircase':
      case 'stair':
        return NodeType.staircase;
      case 'elevator':
        return NodeType.elevator;
      case 'destination':
        return NodeType.destination;
      default:
        return NodeType.corridor;
    }
  }

  String get displayName {
    switch (this) {
      case NodeType.entrance:
        return 'Entrance';
      case NodeType.corridor:
        return 'Corridor';
      case NodeType.junction:
        return 'Junction';
      case NodeType.turn:
        return 'Turn Node';
      case NodeType.roomDoor:
        return 'Room Door';
      case NodeType.staircase:
        return 'Staircase';
      case NodeType.elevator:
        return 'Elevator';
      case NodeType.destination:
        return 'Destination';
    }
  }
}

class NavigationNode extends Equatable {
  static const double baseLng = 74.92500;
  static const double baseLat = 12.86550;
  static const double scale = 0.00105;

  final String id;
  final String floor;
  final double x;
  final double y;
  final NodeType type;
  final String? roomId;
  final String? label;
  final double lng;
  final double lat;

  const NavigationNode({
    required this.id,
    required this.floor,
    required this.x,
    required this.y,
    required this.type,
    this.roomId,
    this.label,
    double? lng,
    double? lat,
  })  : lng = lng ?? (baseLng + (x / 1000.0) * scale),
        lat = lat ?? (baseLat + ((1080.0 - y) / 1080.0) * scale);

  factory NavigationNode.fromJson(Map<String, dynamic> json) {
    final x = (json['x'] as num).toDouble();
    final y = (json['y'] as num).toDouble();
    final lng = json['lng'] != null ? (json['lng'] as num).toDouble() : null;
    final lat = json['lat'] != null ? (json['lat'] as num).toDouble() : null;

    return NavigationNode(
      id: json['id'] as String,
      floor: json['floor'] as String? ?? 'ground',
      x: x,
      y: y,
      type: NodeType.fromString(json['type'] as String? ?? 'corridor'),
      roomId: json['roomId'] as String?,
      label: json['label'] as String?,
      lng: lng,
      lat: lat,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor': floor,
        'x': x,
        'y': y,
        'type': type.name,
        'lng': lng,
        'lat': lat,
        if (roomId != null) 'roomId': roomId,
        if (label != null) 'label': label,
      };

  NavigationNode copyWith({
    String? id,
    String? floor,
    double? x,
    double? y,
    NodeType? type,
    String? roomId,
    String? label,
    double? lng,
    double? lat,
  }) {
    return NavigationNode(
      id: id ?? this.id,
      floor: floor ?? this.floor,
      x: x ?? this.x,
      y: y ?? this.y,
      type: type ?? this.type,
      roomId: roomId ?? this.roomId,
      label: label ?? this.label,
      lng: lng ?? (x != null ? (baseLng + (x / 1000.0) * scale) : this.lng),
      lat: lat ?? (y != null ? (baseLat + ((1080.0 - y) / 1080.0) * scale) : this.lat),
    );
  }

  @override
  List<Object?> get props => [id, floor, x, y, type, roomId, label, lng, lat];
}
