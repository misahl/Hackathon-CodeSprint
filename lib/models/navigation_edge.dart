import 'package:equatable/equatable.dart';

class NavigationEdge extends Equatable {
  final String fromNode;
  final String toNode;
  final double distance;
  final bool accessible;

  const NavigationEdge({
    required this.fromNode,
    required this.toNode,
    required this.distance,
    this.accessible = true,
  });

  factory NavigationEdge.fromJson(Map<String, dynamic> json) {
    return NavigationEdge(
      fromNode: json['fromNode'] as String,
      toNode: json['toNode'] as String,
      distance: (json['distance'] as num).toDouble(),
      accessible: json['accessible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'fromNode': fromNode,
        'toNode': toNode,
        'distance': distance,
        'accessible': accessible,
      };

  @override
  List<Object?> get props => [fromNode, toNode, distance, accessible];
}
