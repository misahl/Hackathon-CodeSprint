// ─────────────────────────────────────────────────────────────
//  Admin Floor Service
//  Handles Firestore synchronization and local graph persistence
//  for admin-created walkable corridors, nodes, and room doors.
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/navigation_edge.dart';
import '../models/navigation_node.dart';
import 'navigation_service.dart';

class AdminFloorService {
  static final AdminFloorService _instance = AdminFloorService._internal();
  factory AdminFloorService() => _instance;
  AdminFloorService._internal();

  FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  @visibleForTesting
  set firestore(FirebaseFirestore fs) => _customFirestore = fs;

  String _floorDocId(String floorId) {
    if (floorId == 'ground' || floorId == 'ground_floor') return 'ground_floor';
    if (floorId == 'first' || floorId == 'first_floor') return 'first_floor';
    if (floorId == 'second' || floorId == 'second_floor') return 'second_floor';
    return '${floorId}_floor';
  }

  /// Calculates metric walking distance in meters between two node positions.
  /// ~10px canvas distance ≈ 1.1 meters in the real Sahyadri building.
  double calculateDistance(NavigationNode a, NavigationNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final meters = math.sqrt(dx * dx + dy * dy) * 0.11;
    return double.parse(meters.toStringAsFixed(1));
  }

  /// Saves the complete navigation network (nodes, edges, room door mappings)
  /// directly to Firebase Firestore, and syncs immediately to NavigationService.
  Future<bool> saveFloorNetwork({
    required String floorId,
    required List<NavigationNode> nodes,
    required List<NavigationEdge> edges,
    required Map<String, String> roomDoorMap,
  }) async {
    final docId = _floorDocId(floorId);

    // 1. Immediately apply to in-memory routing service so navigation is instantly active
    final navFloor = floorId.contains('first') ? 'first' : (floorId.contains('second') ? 'second' : 'ground');
    NavigationService().loadDataForFloor(
      floor: navFloor,
      nodes: nodes,
      edges: edges,
    );
    NavigationService().setRoomDoorMap(roomDoorMap);

    // 2. Persist to Firebase Firestore
    try {
      final docRef = _firestore.collection('floors').doc(docId);
      final payload = {
        'floorId': docId,
        'updatedAt': FieldValue.serverTimestamp(),
        'nodeCount': nodes.length,
        'edgeCount': edges.length,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'roomDoors': roomDoorMap,
      };

      await docRef.set(payload, SetOptions(merge: true));
      debugPrint('🔥 AdminFloorService: Successfully saved $docId (${nodes.length} nodes, ${edges.length} edges) to Firestore.');
      return true;
    } catch (e) {
      debugPrint('⚠️ AdminFloorService Firestore write error: $e');
      // Even if Firestore write is blocked by rules or network, the in-memory update succeeded!
      return false;
    }
  }

  /// Loads navigation network from Firestore if available.
  Future<Map<String, dynamic>?> loadFloorFromFirestore(String floorId) async {
    final docId = _floorDocId(floorId);
    try {
      final doc = await _firestore.collection('floors').doc(docId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      final data = doc.data()!;
      final rawNodes = (data['nodes'] as List<dynamic>? ?? [])
          .map((item) => NavigationNode.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final rawEdges = (data['edges'] as List<dynamic>? ?? [])
          .map((item) => NavigationEdge.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final rawDoors = Map<String, String>.from(data['roomDoors'] as Map? ?? {});

      final navFloor = floorId.contains('first') ? 'first' : (floorId.contains('second') ? 'second' : 'ground');
      NavigationService().loadDataForFloor(
        floor: navFloor,
        nodes: rawNodes,
        edges: rawEdges,
      );
      NavigationService().setRoomDoorMap(rawDoors);

      return {
        'nodes': rawNodes,
        'edges': rawEdges,
        'roomDoors': rawDoors,
      };
    } catch (e) {
      debugPrint('⚠️ AdminFloorService Firestore load error: $e');
      return null;
    }
  }
}
