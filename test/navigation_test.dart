import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahyadri_ar/models/navigation_edge.dart';
import 'package:sahyadri_ar/models/navigation_node.dart';
import 'package:sahyadri_ar/services/navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Verify Ground Floor nodes, edges, Main Entry to Lab 27 route and GeoJSON generation', () async {
    final nodesRaw = File('assets/navigation/ground_floor_nodes.json').readAsStringSync();
    final edgesRaw = File('assets/navigation/ground_floor_edges.json').readAsStringSync();

    final nodesJson = json.decode(nodesRaw) as Map<String, dynamic>;
    final edgesJson = json.decode(edgesRaw) as Map<String, dynamic>;

    final nodes = (nodesJson['nodes'] as List<dynamic>)
        .map((e) => NavigationNode.fromJson(e as Map<String, dynamic>))
        .toList();
    final edges = (edgesJson['edges'] as List<dynamic>)
        .map((e) => NavigationEdge.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(nodes.isNotEmpty, true, reason: 'Nodes should not be empty');
    expect(edges.isNotEmpty, true, reason: 'Edges should not be empty');

    // 1. Check start and destination nodes exist
    final mainEntry = nodes.firstWhere((n) => n.id == 'node_main_entry');
    expect(mainEntry, isNotNull);
    expect(mainEntry.type, NodeType.entrance);
    expect(mainEntry.lng > 70.0, true, reason: 'Node must have valid longitude');
    expect(mainEntry.lat > 10.0, true, reason: 'Node must have valid latitude');

    final lab27Door = nodes.firstWhere((n) => n.roomId == 'gf_computer_lab_27');
    expect(lab27Door, isNotNull);
    expect(lab27Door.id, 'door_lab_27');
    expect(lab27Door.type, NodeType.roomDoor);

    // 2. Initialize NavigationService with loaded data
    final nav = NavigationService();
    nav.loadDataForFloor(floor: 'ground', nodes: nodes, edges: edges);

    // 3. Find shortest route from Main Entry to Computer Lab 27
    final route = nav.findRoute('node_main_entry', 'door_lab_27');
    expect(route.nodes.isNotEmpty, true, reason: 'Route nodes should not be empty');
    expect(route.nodes.first.id, 'node_main_entry');
    expect(route.nodes.last.id, 'door_lab_27');
    expect(route.totalDistance > 0, true, reason: 'Total distance must be positive');
    expect(route.instructions.isNotEmpty, true, reason: 'Turn-by-turn instructions must be generated');

    // 4. Test route GeoJSON generation for Mapbox
    final routeGeoJson = nav.routeToGeoJson(route);
    final routeMap = json.decode(routeGeoJson) as Map<String, dynamic>;
    expect(routeMap['type'], 'FeatureCollection');
    final features = routeMap['features'] as List;
    expect(features.isNotEmpty, true);
    final lineFeature = features.firstWhere((f) => f['geometry']['type'] == 'LineString');
    expect(lineFeature, isNotNull);
    final coords = lineFeature['geometry']['coordinates'] as List;
    expect(coords.length, route.nodes.length);

    // 5. Verify Ground Floor map GeoJSON asset
    final geojsonRaw = File('assets/maps/ground_floor.geojson').readAsStringSync();
    final mapGeoJson = json.decode(geojsonRaw) as Map<String, dynamic>;
    expect(mapGeoJson['type'], 'FeatureCollection');
    final mapFeatures = mapGeoJson['features'] as List;
    expect(mapFeatures.isNotEmpty, true, reason: 'Ground floor must have polygon features');

    final lab27Polygon = mapFeatures.firstWhere((f) => f['id'] == 'gf_computer_lab_27');
    expect(lab27Polygon, isNotNull);
    expect(lab27Polygon['properties']['name'], 'Computer Lab 27');
    expect(lab27Polygon['properties']['roomNumber'], '27');
    expect(lab27Polygon['geometry']['type'], 'Polygon');
  });
}
