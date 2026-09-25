import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/navigation_edge.dart';
import '../models/navigation_node.dart';
import '../models/navigation_route.dart';

/// NavigationService implements Dijkstra shortest-path routing on the campus walkable graph.
/// Modular architecture allows A* or multi-floor elevator/stair traversal algorithms to replace or extend it.
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final Map<String, List<NavigationNode>> _nodesByFloor = {};
  final Map<String, List<NavigationEdge>> _edgesByFloor = {};
  final Map<String, NavigationNode> _nodesById = {};
  final Map<String, String> _roomDoorMap = {}; // roomId -> doorNodeId

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Load Ground Floor Nodes
      final nodesStr = await rootBundle.loadString('lib/data/navigation/ground_floor_nodes.json');
      final nodesJson = json.decode(nodesStr) as Map<String, dynamic>;
      final rawNodes = (nodesJson['nodes'] as List<dynamic>)
          .map((item) => NavigationNode.fromJson(item as Map<String, dynamic>))
          .toList();

      _nodesByFloor['ground'] = rawNodes;
      for (final n in rawNodes) {
        _nodesById[n.id] = n;
        if (n.roomId != null && n.roomId!.isNotEmpty) {
          _roomDoorMap[n.roomId!] = n.id;
        }
      }

      // 2. Load Ground Floor Edges
      final edgesStr = await rootBundle.loadString('lib/data/navigation/ground_floor_edges.json');
      final edgesJson = json.decode(edgesStr) as Map<String, dynamic>;
      final rawEdges = (edgesJson['edges'] as List<dynamic>)
          .map((item) => NavigationEdge.fromJson(item as Map<String, dynamic>))
          .toList();

      _edgesByFloor['ground'] = rawEdges;
      _initialized = true;
      debugPrint('🗺️ NavigationService initialized: ${rawNodes.length} nodes, ${rawEdges.length} edges.');
    } catch (e) {
      debugPrint('⚠️ Error initializing NavigationService: $e');
    }
  }

  List<NavigationNode> getNodesForFloor(String floor) => _nodesByFloor[floor] ?? [];
  List<NavigationEdge> getEdgesForFloor(String floor) => _edgesByFloor[floor] ?? [];
  NavigationNode? getNodeById(String id) => _nodesById[id];

  /// Find the navigation door node corresponding to a room ID
  NavigationNode? getNodeForRoom(String roomId) {
    final doorId = _roomDoorMap[roomId];
    if (doorId != null) {
      return _nodesById[doorId];
    }
    // Fallback: search nodes with matching roomId
    for (final node in _nodesById.values) {
      if (node.roomId == roomId) return node;
    }
    return null;
  }

  /// Calculates total distance in meters along a node path
  double calculateDistance(List<NavigationNode> path) {
    if (path.length < 2) return 0.0;
    double dist = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      dist += math.sqrt(dx * dx + dy * dy) * 0.11; // ~10px = 1.1m
    }
    return double.parse(dist.toStringAsFixed(1));
  }

  /// Finds the shortest walkable route from startNodeId to destinationNodeId using Dijkstra's algorithm.
  NavigationRoute findRoute(String startNodeId, String destinationNodeId) {
    if (!_initialized) {
      debugPrint('⚠️ NavigationService not initialized before findRoute');
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0.0,
        estimatedWalkingMinutes: 0,
        instructions: [],
      );
    }

    final start = _nodesById[startNodeId];
    final dest = _nodesById[destinationNodeId];
    if (start == null || dest == null) {
      debugPrint('⚠️ Invalid start ($startNodeId) or destination ($destinationNodeId)');
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0.0,
        estimatedWalkingMinutes: 0,
        instructions: [],
      );
    }

    // Build adjacency list for the floor
    final floorEdges = _edgesByFloor[start.floor] ?? [];
    final Map<String, List<NavigationEdge>> adj = {};
    for (final e in floorEdges) {
      if (!e.accessible) continue;
      adj.setdefault(e.fromNode, []).add(e);
    }

    // Dijkstra Priority Queue / distances
    final Map<String, double> dist = {};
    final Map<String, String> prev = {};
    final Set<String> visited = {};

    for (final n in _nodesById.values) {
      if (n.floor == start.floor) {
        dist[n.id] = double.infinity;
      }
    }
    dist[startNodeId] = 0.0;

    final unvisited = <String>{...dist.keys};

    while (unvisited.isNotEmpty) {
      // Find lowest distance node in unvisited
      String? current;
      double minDist = double.infinity;
      for (final nId in unvisited) {
        final d = dist[nId] ?? double.infinity;
        if (d < minDist) {
          minDist = d;
          current = nId;
        }
      }

      if (current == null || minDist == double.infinity) break;
      if (current == destinationNodeId) break;

      unvisited.remove(current);
      visited.add(current);

      final neighbors = adj[current] ?? [];
      for (final edge in neighbors) {
        final neighborId = edge.toNode;
        if (visited.contains(neighborId)) continue;

        final alt = dist[current]! + edge.distance;
        if (alt < (dist[neighborId] ?? double.infinity)) {
          dist[neighborId] = alt;
          prev[neighborId] = current;
        }
      }
    }

    // Reconstruct path
    final List<NavigationNode> path = [];
    String? step = destinationNodeId;
    while (step != null) {
      final node = _nodesById[step];
      if (node != null) {
        path.add(node);
      }
      step = prev[step];
    }
    final orderedPath = path.reversed.toList();

    if (orderedPath.isEmpty || orderedPath.first.id != startNodeId) {
      debugPrint('⚠️ No route found between $startNodeId and $destinationNodeId');
      return const NavigationRoute(
        nodes: [],
        totalDistance: 0.0,
        estimatedWalkingMinutes: 0,
        instructions: [],
      );
    }

    final totalDist = calculateDistance(orderedPath);
    // Average walking speed ~1.3 m/s = ~80 m/min
    final walkingMinutes = math.max(1, (totalDist / 60).ceil());
    final instructions = generateInstructions(orderedPath, dest.label ?? 'Destination');

    return NavigationRoute(
      nodes: orderedPath,
      totalDistance: totalDist,
      estimatedWalkingMinutes: walkingMinutes,
      instructions: instructions,
    );
  }

  /// Generates natural turn-by-turn navigation instructions from a node sequence
  List<TurnInstruction> generateInstructions(List<NavigationNode> path, String destinationName) {
    if (path.isEmpty) return [];
    if (path.length == 1) {
      return [
        TurnInstruction(
          text: 'You are at $destinationName',
          icon: 'arrive',
          distance: 0.0,
          node: path.first,
        ),
      ];
    }

    final List<TurnInstruction> list = [];
    final startLabel = path.first.label ?? 'starting point';
    list.add(TurnInstruction(
      text: 'Start from $startLabel',
      icon: 'start',
      distance: 0.0,
      node: path.first,
    ));

    double segmentDistance = 0.0;

    for (int i = 0; i < path.length - 1; i++) {
      final current = path[i];
      final next = path[i + 1];
      final dx = next.x - current.x;
      final dy = next.y - current.y;
      final segDist = math.sqrt(dx * dx + dy * dy) * 0.11;
      segmentDistance += segDist;

      // Check if there is a turn at path[i+1]
      if (i < path.length - 2) {
        final nextNext = path[i + 2];
        final angle1 = math.atan2(next.y - current.y, next.x - current.x);
        final angle2 = math.atan2(nextNext.y - next.y, nextNext.x - next.x);
        var diff = angle2 - angle1;
        while (diff > math.pi) {
          diff -= 2 * math.pi;
        }
        while (diff < -math.pi) {
          diff += 2 * math.pi;
        }

        final degrees = diff * 180 / math.pi;

        // Landmark hints
        String landmarkHint = '';
        if (next.y > 600 && next.x > 500 && next.x < 750) {
          landmarkHint = ' past Courtyard 1';
        } else if (next.y < 350 && next.x > 500) {
          landmarkHint = ' past Courtyard 4';
        } else if (next.y > 800) {
          landmarkHint = ' along Computer Labs corridor';
        }

        if (degrees.abs() >= 40) {
          final isLeft = degrees < 0;
          final turnText = isLeft ? 'Turn left' : 'Turn right';
          final walkDistRounded = segmentDistance.round();

          if (walkDistRounded > 5) {
            list.add(TurnInstruction(
              text: 'Walk straight for $walkDistRounded m$landmarkHint',
              icon: 'straight',
              distance: segmentDistance,
              node: current,
            ));
          }

          list.add(TurnInstruction(
            text: '$turnText at ${next.label ?? 'corridor'}',
            icon: isLeft ? 'turn_left' : 'turn_right',
            distance: segDist,
            node: next,
          ));

          segmentDistance = 0.0;
        }
      }
    }

    final finalWalkDist = segmentDistance.round();
    if (finalWalkDist > 3) {
      list.add(TurnInstruction(
        text: 'Continue straight for $finalWalkDist m',
        icon: 'straight',
        distance: segmentDistance,
        node: path[path.length - 2],
      ));
    }

    list.add(TurnInstruction(
      text: '$destinationName is ahead on your path',
      icon: 'arrive',
      distance: 0.0,
      node: path.last,
    ));

    return list;
  }
}
extension _MapDefault<K, V> on Map<K, V> {
  V setdefault(K key, V defaultValue) {
    return putIfAbsent(key, () => defaultValue);
  }
}
