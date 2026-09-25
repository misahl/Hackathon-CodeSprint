import 'navigation_node.dart';

class TurnInstruction {
  final String text;
  final String icon; // 'straight', 'turn_left', 'turn_right', 'arrive', 'start'
  final double distance;
  final NavigationNode node;

  const TurnInstruction({
    required this.text,
    this.icon = 'straight',
    required this.distance,
    required this.node,
  });
}

class NavigationRoute {
  final List<NavigationNode> nodes;
  final double totalDistance;
  final int estimatedWalkingMinutes;
  final List<TurnInstruction> instructions;

  const NavigationRoute({
    required this.nodes,
    required this.totalDistance,
    required this.estimatedWalkingMinutes,
    required this.instructions,
  });

  bool get isEmpty => nodes.isEmpty;
  bool get isNotEmpty => nodes.isNotEmpty;
}
