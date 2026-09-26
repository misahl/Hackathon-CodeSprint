import 'package:flutter_test/flutter_test.dart';
import 'package:sahyadri_ar/models/navigation_edge.dart';
import 'package:sahyadri_ar/models/navigation_node.dart';
import 'package:sahyadri_ar/services/admin_floor_service.dart';
import 'package:sahyadri_ar/services/navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Universal Walkable Path Network & Admin Editor Tests', () {
    late NavigationService navService;
    late AdminFloorService adminService;

    setUp(() {
      navService = NavigationService();
      adminService = AdminFloorService();
    });

    test('1. Node moving recalculates edge distances accurately', () {
      final nodeA = NavigationNode(
        id: 'node_A',
        floor: 'ground',
        x: 100.0,
        y: 100.0,
        type: NodeType.corridor,
      );
      final nodeB = NavigationNode(
        id: 'node_B',
        floor: 'ground',
        x: 200.0,
        y: 100.0,
        type: NodeType.corridor,
      );

      final initialDist = adminService.calculateDistance(nodeA, nodeB);
      expect(initialDist, equals(11.0)); // 100px * 0.11 = 11.0m

      // Move node B to x: 300.0
      final movedNodeB = nodeB.copyWith(x: 300.0);
      final updatedDist = adminService.calculateDistance(nodeA, movedNodeB);
      expect(updatedDist, equals(22.0)); // 200px * 0.11 = 22.0m
    });

    test('2. Turn node creation and intermediate routing along real corridor bends', () {
      // Create path: Entrance (100, 100) -> TURN (100, 200) -> Room Door (200, 200)
      final entrance = NavigationNode(
        id: 'ENTRY_01',
        floor: 'ground',
        x: 100.0,
        y: 100.0,
        type: NodeType.entrance,
        label: 'Main Entry',
      );
      final turnNode = NavigationNode(
        id: 'TURN_01',
        floor: 'ground',
        x: 100.0,
        y: 200.0,
        type: NodeType.turn,
        label: 'Corridor Bend Turn',
      );
      final labDoor = NavigationNode(
        id: 'LAB27_DOOR',
        floor: 'ground',
        x: 200.0,
        y: 200.0,
        type: NodeType.roomDoor,
        roomId: 'computer-lab-27',
        label: 'Computer Lab 27 Door',
      );

      final edge1 = NavigationEdge(
        fromNode: 'ENTRY_01',
        toNode: 'TURN_01',
        distance: 11.0,
        floor: 'ground',
        enabled: true,
      );
      final edge2 = NavigationEdge(
        fromNode: 'TURN_01',
        toNode: 'LAB27_DOOR',
        distance: 11.0,
        floor: 'ground',
        enabled: true,
      );

      navService.loadDataForFloor(
        floor: 'ground',
        nodes: [entrance, turnNode, labDoor],
        edges: [edge1, edge2],
      );
      navService.setRoomDoor('computer-lab-27', 'LAB27_DOOR');

      // Routing from ENTRY_01 to LAB27_DOOR MUST pass through TURN_01
      final route = navService.findRoute('ENTRY_01', 'LAB27_DOOR');
      expect(route.nodes.length, equals(3));
      expect(route.nodes[0].id, equals('ENTRY_01'));
      expect(route.nodes[1].id, equals('TURN_01'));
      expect(route.nodes[2].id, equals('LAB27_DOOR'));

      // Bidirectional verification: LAB27_DOOR to ENTRY_01 must also work seamlessly
      final reverseRoute = navService.findRoute('LAB27_DOOR', 'ENTRY_01');
      expect(reverseRoute.nodes.length, equals(3));
      expect(reverseRoute.nodes[0].id, equals('LAB27_DOOR'));
      expect(reverseRoute.nodes[1].id, equals('TURN_01'));
      expect(reverseRoute.nodes[2].id, equals('ENTRY_01'));
    });

    test('3. Disabled path is NOT traversed in Dijkstra', () {
      final nodeA = NavigationNode(id: 'A', floor: 'ground', x: 0, y: 0, type: NodeType.corridor);
      final nodeB = NavigationNode(id: 'B', floor: 'ground', x: 10, y: 0, type: NodeType.corridor);
      final edgeAB = NavigationEdge(
        fromNode: 'A',
        toNode: 'B',
        distance: 1.0,
        floor: 'ground',
        enabled: false, // DISABLED PATH
      );

      navService.loadDataForFloor(
        floor: 'ground',
        nodes: [nodeA, nodeB],
        edges: [edgeAB],
      );

      final route = navService.findRoute('A', 'B');
      expect(route.nodes.isEmpty, isTrue); // Cannot route through disabled edge
    });

    test('4. Nearest node finding & point coordinate routing', () {
      final entrance = NavigationNode(id: 'ENTRY', floor: 'ground', x: 150, y: 700, type: NodeType.entrance);
      final door = NavigationNode(id: 'DOOR_LAB', floor: 'ground', x: 600, y: 700, type: NodeType.roomDoor, roomId: 'lab-1');
      final edge = NavigationEdge(fromNode: 'ENTRY', toNode: 'DOOR_LAB', distance: 45.0, floor: 'ground', enabled: true);

      navService.loadDataForFloor(floor: 'ground', nodes: [entrance, door], edges: [edge]);
      navService.setRoomDoor('lab-1', 'DOOR_LAB');

      // User standing at (145, 710) near entrance
      final nearest = navService.findNearestNode(145, 710, floor: 'ground');
      expect(nearest?.id, equals('ENTRY'));

      final pointRoute = navService.findRouteFromCoordinates(
        startX: 145,
        startY: 710,
        destinationRoomId: 'lab-1',
        floor: 'ground',
      );
      expect(pointRoute.nodes.isNotEmpty, isTrue);
      expect(pointRoute.nodes.last.id, equals('DOOR_LAB'));
    });

    test('5. Clear All resets floor navigation graph completely', () {
      final nodeA = NavigationNode(id: 'N1', floor: 'ground', x: 10, y: 10, type: NodeType.corridor);
      final edgeA = NavigationEdge(fromNode: 'N1', toNode: 'N2', distance: 5.0, floor: 'ground');

      navService.loadDataForFloor(floor: 'ground', nodes: [nodeA], edges: [edgeA]);
      expect(navService.getNodesForFloor('ground').length, equals(1));

      // Clear floor
      navService.loadDataForFloor(floor: 'ground', nodes: [], edges: []);
      expect(navService.getNodesForFloor('ground').isEmpty, isTrue);
      expect(navService.getEdgesForFloor('ground').isEmpty, isTrue);
    });
  });
}
