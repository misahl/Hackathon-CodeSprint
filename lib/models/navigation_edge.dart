import 'package:equatable/equatable.dart';

class NavigationEdge extends Equatable {
  final String fromNode;
  final String toNode;
  final double distance;
  final bool accessible;
  final String? floor;
  final bool enabled;

  const NavigationEdge({
    required this.fromNode,
    required this.toNode,
    required this.distance,
    this.accessible = true,
    this.floor,
    this.enabled = true,
  });

  factory NavigationEdge.fromJson(Map<String, dynamic> json) {
    return NavigationEdge(
      fromNode: json['fromNode'] as String,
      toNode: json['toNode'] as String,
      distance: (json['distance'] as num).toDouble(),
      accessible: json['accessible'] as bool? ?? true,
      floor: json['floor'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'fromNode': fromNode,
        'toNode': toNode,
        'distance': distance,
        'accessible': accessible,
        if (floor != null) 'floor': floor,
        'enabled': enabled,
      };

  NavigationEdge copyWith({
    String? fromNode,
    String? toNode,
    double? distance,
    bool? accessible,
    String? floor,
    bool? enabled,
  }) {
    return NavigationEdge(
      fromNode: fromNode ?? this.fromNode,
      toNode: toNode ?? this.toNode,
      distance: distance ?? this.distance,
      accessible: accessible ?? this.accessible,
      floor: floor ?? this.floor,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  List<Object?> get props => [fromNode, toNode, distance, accessible, floor, enabled];
}
