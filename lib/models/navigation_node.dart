import 'package:equatable/equatable.dart';

enum NodeType {
  entrance,
  corridor,
  roomDoor,
  staircase,
  elevator,
  destination;

  static NodeType fromString(String val) {
    switch (val) {
      case 'entrance':
        return NodeType.entrance;
      case 'room_door':
      case 'roomDoor':
        return NodeType.roomDoor;
      case 'staircase':
        return NodeType.staircase;
      case 'elevator':
        return NodeType.elevator;
      case 'destination':
        return NodeType.destination;
      default:
        return NodeType.corridor;
    }
  }
}

class NavigationNode extends Equatable {
  final String id;
  final String floor;
  final double x;
  final double y;
  final NodeType type;
  final String? roomId;
  final String? label;

  const NavigationNode({
    required this.id,
    required this.floor,
    required this.x,
    required this.y,
    required this.type,
    this.roomId,
    this.label,
  });

  factory NavigationNode.fromJson(Map<String, dynamic> json) {
    return NavigationNode(
      id: json['id'] as String,
      floor: json['floor'] as String? ?? 'ground',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      type: NodeType.fromString(json['type'] as String? ?? 'corridor'),
      roomId: json['roomId'] as String?,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor': floor,
        'x': x,
        'y': y,
        'type': type.name,
        if (roomId != null) 'roomId': roomId,
        if (label != null) 'label': label,
      };

  @override
  List<Object?> get props => [id, floor, x, y, type, roomId, label];
}
