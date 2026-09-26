import 'package:flutter_test/flutter_test.dart';
import 'package:sahyadri_ar/models/navigation_edge.dart';
import 'package:sahyadri_ar/models/navigation_node.dart';
import 'package:sahyadri_ar/services/navigation_service.dart';

void main() {
  test('Admin graph models and navigation service integrity test', () {
    final nodeA = NavigationNode(
      id: 'GF_ENTRANCE_TEST',
      floor: 'ground',
      x: 100.0,
      y: 200.0,
      type: NodeType.entrance,
      label: 'Main Gate Test',
    );

    final nodeB = NavigationNode(
      id: 'GF_CORRIDOR_TEST',
      floor: 'ground',
      x: 150.0,
      y: 200.0,
      type: NodeType.corridor,
      label: 'Corridor Test',
    );

    final edge = NavigationEdge(
      fromNode: nodeA.id,
      toNode: nodeB.id,
      distance: 5.5,
      floor: 'ground',
      enabled: true,
    );

    expect(nodeA.type, NodeType.entrance);
    expect(nodeB.type, NodeType.corridor);
    expect(edge.distance, 5.5);
    expect(edge.enabled, true);

    // Test NavigationService live updates
    final navService = NavigationService();
    navService.addOrUpdateNode(nodeA);
    navService.addOrUpdateNode(nodeB);
    navService.addEdge(edge);

    expect(navService.getNodeById(nodeA.id), isNotNull);
    expect(navService.getNodeById(nodeB.id), isNotNull);
  });
}
