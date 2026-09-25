import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahyadri_ar/models/navigation_edge.dart';
import 'package:sahyadri_ar/models/navigation_node.dart';
import 'package:sahyadri_ar/services/navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Verify Ground Floor nodes, edges and Main Entry to Lab 27 route', () async {
    final nodesRaw = File('lib/data/navigation/ground_floor_nodes.json').readAsStringSync();
    final edgesRaw = File('lib/data/navigation/ground_floor_edges.json').readAsStringSync();

    final nodesJson = json.decode(nodesRaw) as Map<String, dynamic>;
    final edgesJson = json.decode(edgesRaw) as Map<String, dynamic>;

    final nodes = (nodesJson['nodes'] as List<dynamic>)
        .map((e) => NavigationNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final edges = (edgesJson['edges'] as List<dynamic>)
        .map((e) => NavigationEdge.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(nodes.isNotEmpty, true);
    expect(edges.isNotEmpty, true);

    // Check start and destination nodes exist
    final mainEntry = nodes.firstWhere((n) => n.id == 'node_main_entry');
    expect(mainEntry, isNotNull);

    final lab27Door = nodes.firstWhere((n) => n.roomId == 'gf_computer_lab_27');
    expect(lab27Door, isNotNull);
    expect(lab27Door.id, 'door_lab_27');

    final nav = NavigationService();
    await nav.init();

    final route = nav.findRoute('node_main_entry', 'door_lab_27');
    expect(route.nodes.isNotEmpty, true, reason: 'Route nodes should not be empty');
    expect(route.nodes.first.id, 'node_main_entry');
    expect(route.nodes.last.id, 'door_lab_27');
    expect(route.totalDistance > 0, true, reason: 'Total distance must be positive');
    expect(route.instructions.isNotEmpty, true, reason: 'Instructions must be generated');


  });
}
