// ─────────────────────────────────────────────────────────────
//  Admin Map Editor Screen
//  Universal Walkable Path Network Editor for Ground Floor.
//  Supports: Move Node, Add Path (Dotted line), Turn Node,
//  Universal Corridor Graph, Room Door, Node Types, Connect,
//  Edge Inspector, Clear All, Reset View, Save Floor, Debug Mode.
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/navigation_edge.dart';
import '../models/navigation_node.dart';
import '../models/room.dart';
import '../services/admin_floor_service.dart';
import '../services/navigation_service.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

enum EditorMode {
  select,
  moveNode,
  addNode,
  addTurnNode,
  addPath,
  connect,
  setDoor,
  setEntrance,
  delete,
}

class AdminMapEditorScreen extends StatefulWidget {
  const AdminMapEditorScreen({super.key});

  @override
  State<AdminMapEditorScreen> createState() => _AdminMapEditorScreenState();
}

class _AdminMapEditorScreenState extends State<AdminMapEditorScreen> {
  final AdminFloorService _adminService = AdminFloorService();
  final TransformationController _transformController = TransformationController();

  static const double _canvasWidth = 1000.0;
  static const double _canvasHeight = 1080.0;

  String _selectedFloor = 'ground'; // 'ground', 'first', 'second'
  EditorMode _mode = EditorMode.select;
  bool _debugMode = true;
  bool _isSaving = false;
  bool _isDraggingNode = false;

  // Active working copies of the navigation graph
  List<NavigationNode> _nodes = [];
  List<NavigationEdge> _edges = [];
  Map<String, String> _roomDoorMap = {};

  // Selection & active state
  NavigationNode? _selectedNode;
  NavigationNode? _connectStartNode;
  NavigationNode? _pathStartNode;
  NavigationEdge? _selectedEdge;
  Room? _selectedRoomForDoor;

  // Sequence counter
  int _nodeSeqCounter = 1;

  @override
  void initState() {
    super.initState();
    _loadFloorData(_selectedFloor);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorData(String floorId) async {
    // Try to load from Firestore first
    final firestoreData = await _adminService.loadFloorFromFirestore(floorId);
    if (firestoreData != null && mounted) {
      setState(() {
        _selectedFloor = floorId;
        _nodes = List.from(firestoreData['nodes'] as List<NavigationNode>);
        _edges = List.from(firestoreData['edges'] as List<NavigationEdge>);
        _roomDoorMap = Map.from(firestoreData['roomDoors'] as Map<String, String>);
        _selectedNode = null;
        _connectStartNode = null;
        _pathStartNode = null;
        _selectedEdge = null;
        _nodeSeqCounter = _nodes.length + 1;
      });
      return;
    }

    final navService = NavigationService();
    final rawNodes = navService.getNodesForFloor(floorId);
    final rawEdges = navService.getEdgesForFloor(floorId);
    final doorMap = Map<String, String>.from(navService.roomDoorMap);

    setState(() {
      _selectedFloor = floorId;
      _nodes = List.from(rawNodes);
      _edges = List.from(rawEdges);
      _roomDoorMap = doorMap;
      _selectedNode = null;
      _connectStartNode = null;
      _pathStartNode = null;
      _selectedEdge = null;
      _nodeSeqCounter = _nodes.length + 1;
    });
  }

  Color _getNodeColor(NodeType type) {
    switch (type) {
      case NodeType.entrance:
        return const Color(0xFF10B981); // Emerald Green
      case NodeType.corridor:
        return const Color(0xFF0284C7); // Vivid Sky Blue
      case NodeType.junction:
        return const Color(0xFF06B6D4); // Cyan
      case NodeType.turn:
        return const Color(0xFFF59E0B); // Amber / Gold
      case NodeType.roomDoor:
        return const Color(0xFFF97316); // Bright Orange
      case NodeType.staircase:
        return const Color(0xFF8B5CF6); // Royal Purple
      case NodeType.elevator:
        return const Color(0xFF14B8A6); // Teal
      case NodeType.destination:
        return const Color(0xFFEF4444); // Crimson Red
    }
  }

  void _syncToNavigationService() {
    NavigationService().loadDataForFloor(
      floor: _selectedFloor,
      nodes: _nodes,
      edges: _edges,
    );
    NavigationService().setRoomDoorMap(_roomDoorMap);
  }

  // ── GESTURE: DRAG NODE HANDLERS (Requirement 1: MOVE NODE) ───
  void _onPanStart(DragStartDetails details) {
    if (_mode != EditorMode.moveNode && _mode != EditorMode.select) return;

    final pos = details.localPosition;
    final tapped = _findNodeNear(pos.dx, pos.dy, radius: 28.0);
    if (tapped != null) {
      setState(() {
        _selectedNode = tapped;
        _isDraggingNode = true;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDraggingNode || _selectedNode == null) return;

    final pos = details.localPosition;
    final clampedX = pos.dx.clamp(8.0, _canvasWidth - 8.0);
    final clampedY = pos.dy.clamp(8.0, _canvasHeight - 8.0);
    final updatedX = double.parse(clampedX.toStringAsFixed(1));
    final updatedY = double.parse(clampedY.toStringAsFixed(1));

    _moveNodeTo(_selectedNode!, updatedX, updatedY);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDraggingNode) {
      setState(() => _isDraggingNode = false);
      _syncToNavigationService();
      if (_selectedNode != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Node "${_selectedNode!.label ?? _selectedNode!.id}" moved to (${_selectedNode!.x}, ${_selectedNode!.y})',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _moveNodeTo(NavigationNode node, double newX, double newY) {
    final updated = node.copyWith(x: newX, y: newY);

    setState(() {
      final idx = _nodes.indexWhere((n) => n.id == node.id);
      if (idx >= 0) {
        _nodes[idx] = updated;
      }
      _selectedNode = updated;

      // Update connected edges distances automatically
      for (int i = 0; i < _edges.length; i++) {
        final e = _edges[i];
        if (e.fromNode == node.id || e.toNode == node.id) {
          final fromN = e.fromNode == node.id ? updated : _findNodeById(e.fromNode);
          final toN = e.toNode == node.id ? updated : _findNodeById(e.toNode);
          if (fromN != null && toN != null) {
            final newDist = _adminService.calculateDistance(fromN, toN);
            _edges[i] = e.copyWith(distance: newDist);
          }
        }
      }
    });
  }

  // ── MAP TAP HANDLER ──────────────────────────────────────────
  void _onMapTapped(TapUpDetails details) {
    final rawPosition = details.localPosition;
    final x = double.parse(rawPosition.dx.toStringAsFixed(1));
    final y = double.parse(rawPosition.dy.toStringAsFixed(1));

    switch (_mode) {
      case EditorMode.select:
        final tappedNode = _findNodeNear(x, y, radius: 24.0);
        if (tappedNode != null) {
          setState(() {
            _selectedNode = tappedNode;
            _selectedEdge = null;
          });
          _showNodePropertiesSheet(tappedNode);
          return;
        }

        // Check if edge tapped
        final tappedEdge = _findEdgeNear(x, y, radius: 14.0);
        if (tappedEdge != null) {
          setState(() {
            _selectedEdge = tappedEdge;
            _selectedNode = null;
          });
          _showEdgeInspectorSheet(tappedEdge);
          return;
        }

        setState(() {
          _selectedNode = null;
          _selectedEdge = null;
        });
        break;

      case EditorMode.moveNode:
        final tapped = _findNodeNear(x, y, radius: 26.0);
        if (tapped != null) {
          setState(() => _selectedNode = tapped);
        }
        break;

      case EditorMode.addNode:
        _showAddNodeDialog(x, y);
        break;

      case EditorMode.addTurnNode:
        _placeTurnNode(x, y);
        break;

      case EditorMode.addPath:
        final tapped = _findNodeNear(x, y, radius: 28.0);
        if (tapped != null) {
          if (_pathStartNode == null) {
            setState(() => _pathStartNode = tapped);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Start of path: ${tapped.label ?? tapped.id}. Tap Node B to add dotted path.'),
                backgroundColor: const Color(0xFF0284C7),
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (_pathStartNode!.id != tapped.id) {
            _createWalkablePathBetween(_pathStartNode!, tapped);
            setState(() => _pathStartNode = tapped); // Chain to allow next segment
          }
        }
        break;

      case EditorMode.connect:
        final tapped = _findNodeNear(x, y, radius: 28.0);
        if (tapped != null) {
          if (_connectStartNode == null) {
            setState(() => _connectStartNode = tapped);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connect from ${tapped.label ?? tapped.id}. Tap target node.'),
                backgroundColor: const Color(0xFF0284C7),
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (_connectStartNode!.id != tapped.id) {
            _createWalkablePathBetween(_connectStartNode!, tapped);
            setState(() => _connectStartNode = null);
          }
        }
        break;

      case EditorMode.setDoor:
        if (_selectedRoomForDoor == null) {
          _pickRoomForDoor(tapPos: Offset(x, y));
        } else {
          _createDoorNodeForRoom(_selectedRoomForDoor!, x, y);
        }
        break;

      case EditorMode.setEntrance:
        _showSetEntranceDialog(x, y);
        break;

      case EditorMode.delete:
        final tappedNode = _findNodeNear(x, y, radius: 24.0);
        if (tappedNode != null) {
          _deleteNode(tappedNode);
          return;
        }
        final tappedEdge = _findEdgeNear(x, y, radius: 14.0);
        if (tappedEdge != null) {
          _deleteEdge(tappedEdge);
        }
        break;
    }
  }

  NavigationNode? _findNodeNear(double x, double y, {double radius = 22.0}) {
    for (final node in _nodes) {
      final dx = node.x - x;
      final dy = node.y - y;
      if (math.sqrt(dx * dx + dy * dy) <= radius) {
        return node;
      }
    }
    return null;
  }

  NavigationNode? _findNodeById(String id) {
    for (final n in _nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  NavigationEdge? _findEdgeNear(double x, double y, {double radius = 14.0}) {
    final nodeMap = {for (final n in _nodes) n.id: n};
    for (final edge in _edges) {
      final a = nodeMap[edge.fromNode];
      final b = nodeMap[edge.toNode];
      if (a == null || b == null) continue;
      final dist = _distanceToSegment(x, y, a.x, a.y, b.x, b.y);
      if (dist <= radius) {
        return edge;
      }
    }
    return null;
  }

  double _distanceToSegment(double px, double py, double ax, double ay, double bx, double by) {
    final l2 = (bx - ax) * (bx - ax) + (by - ay) * (by - ay);
    if (l2 == 0) return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    var t = ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2;
    t = t.clamp(0.0, 1.0);
    final projX = ax + t * (bx - ax);
    final projY = ay + t * (by - ay);
    final dx = px - projX;
    final dy = py - projY;
    return math.sqrt(dx * dx + dy * dy);
  }

  // ── ACTION: ADD TURN NODE (Requirement 3: TURN NODE) ─────────
  void _placeTurnNode(double x, double y) {
    final id = 'GF_TURN_${_nodeSeqCounter++}';
    final turnNode = NavigationNode(
      id: id,
      floor: _selectedFloor,
      x: x,
      y: y,
      type: NodeType.turn,
      label: 'Turn Node',
    );

    setState(() {
      _nodes.add(turnNode);
      _selectedNode = turnNode;
    });

    _syncToNavigationService();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Placed Turn Node at ($x, $y)'),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── ACTION: ADD NODE ─────────────────────────────────────────
  void _showAddNodeDialog(double x, double y) {
    NodeType selectedType = NodeType.corridor;
    final idController = TextEditingController(
      text: 'GF_${selectedType.name.toUpperCase()}_${_nodeSeqCounter++}',
    );
    final labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(
            'Add Navigation Node',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Coordinates: ($x, $y)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 14),
              const Text('Node Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<NodeType>(
                initialValue: selectedType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: NodeType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: _getNodeColor(t), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(t.displayName, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDlgState(() {
                      selectedType = val;
                      idController.text = 'GF_${val.name.toUpperCase()}_$_nodeSeqCounter';
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: idController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Node ID (Unique)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Label / Name (Optional)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                final id = idController.text.trim();
                if (id.isEmpty) return;
                final newNode = NavigationNode(
                  id: id,
                  floor: _selectedFloor,
                  x: x,
                  y: y,
                  type: selectedType,
                  label: labelController.text.trim().isNotEmpty ? labelController.text.trim() : null,
                );
                setState(() {
                  _nodes.add(newNode);
                  _selectedNode = newNode;
                });
                _syncToNavigationService();
                Navigator.pop(ctx);
              },
              child: const Text('Place Node', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── ACTION: ADD PATH / CONNECT (Requirements 2, 7) ───────────
  void _createWalkablePathBetween(NavigationNode a, NavigationNode b) {
    final dist = _adminService.calculateDistance(a, b);
    final newEdge = NavigationEdge(
      fromNode: a.id,
      toNode: b.id,
      distance: dist,
      floor: _selectedFloor,
      enabled: true,
    );

    setState(() {
      _edges.removeWhere((e) =>
          (e.fromNode == a.id && e.toNode == b.id) ||
          (e.fromNode == b.id && e.toNode == a.id));
      _edges.add(newEdge);
    });

    _syncToNavigationService();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ Dotted walkable path: ${a.label ?? a.id} ↔ ${b.label ?? b.id} ($dist m)'),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── ACTION: SET DOOR (Requirement 5: ROOM DOOR) ──────────────
  void _pickRoomForDoor({Offset? tapPos}) {
    final rooms = SearchService().getAllRooms(floorId: _selectedFloor);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Destination Room to Assign Door',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (ctx, i) {
                  final room = rooms[i];
                  final hasDoor = _roomDoorMap.containsKey(room.id);
                  return ListTile(
                    leading: Icon(
                      Icons.door_front_door_rounded,
                      color: hasDoor ? const Color(0xFF10B981) : Colors.white70,
                    ),
                    title: Text(room.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      hasDoor ? 'Assigned Door: ${_roomDoorMap[room.id]}' : 'No door assigned yet',
                      style: TextStyle(color: hasDoor ? const Color(0xFF10B981) : Colors.white54, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedRoomForDoor = room;
                      });
                      if (tapPos != null) {
                        _createDoorNodeForRoom(room, tapPos.dx, tapPos.dy);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Now tap the exact corridor doorway location for "${room.name}"'),
                            backgroundColor: const Color(0xFFF97316),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createDoorNodeForRoom(Room room, double x, double y) {
    final doorId = 'door_${room.id.replaceAll('-', '_')}';
    final doorNode = NavigationNode(
      id: doorId,
      floor: _selectedFloor,
      x: x,
      y: y,
      type: NodeType.roomDoor,
      roomId: room.id,
      label: '${room.name} Door',
    );

    setState(() {
      _nodes.removeWhere((n) => n.id == doorId);
      _nodes.add(doorNode);
      _roomDoorMap[room.id] = doorId;
      _selectedRoomForDoor = null;
      _selectedNode = doorNode;
    });

    // Auto-connect to nearest corridor/turn node if within 60px
    NavigationNode? nearest;
    double minD = 999999.0;
    for (final n in _nodes) {
      if (n.id == doorId) continue;
      final dist = _adminService.calculateDistance(doorNode, n);
      if (dist < minD) {
        minD = dist;
        nearest = n;
      }
    }

    if (nearest != null && minD < 12.0) {
      _createWalkablePathBetween(doorNode, nearest);
    }

    _syncToNavigationService();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚪 Door placed for "${room.name}" ($doorId)'),
        backgroundColor: const Color(0xFFF97316),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── ACTION: SET ENTRANCE ─────────────────────────────────────
  void _showSetEntranceDialog(double x, double y) {
    final idController = TextEditingController(text: 'MAIN_ENTRY_01');
    final labelController = TextEditingController(text: 'Main Campus Entrance');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          'Place Campus Entrance',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Entrance ID (e.g. MAIN_ENTRY_01)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Entrance Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () {
              final id = idController.text.trim();
              if (id.isEmpty) return;
              final entranceNode = NavigationNode(
                id: id,
                floor: _selectedFloor,
                x: x,
                y: y,
                type: NodeType.entrance,
                label: labelController.text.trim(),
              );
              setState(() {
                _nodes.removeWhere((n) => n.id == id);
                _nodes.add(entranceNode);
                _selectedNode = entranceNode;
              });
              _syncToNavigationService();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Entrance node "$id" saved at ($x, $y)'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Save Entrance', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── ACTION: DELETE NODE ──────────────────────────────────────
  void _deleteNode(NavigationNode node) {
    setState(() {
      _nodes.removeWhere((n) => n.id == node.id);
      _edges.removeWhere((e) => e.fromNode == node.id || e.toNode == node.id);
      _roomDoorMap.removeWhere((k, v) => v == node.id);
      if (_selectedNode?.id == node.id) _selectedNode = null;
      if (_pathStartNode?.id == node.id) _pathStartNode = null;
      if (_connectStartNode?.id == node.id) _connectStartNode = null;
    });

    _syncToNavigationService();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted node "${node.id}" and connected edges.'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── ACTION: DELETE EDGE (Requirement 8) ──────────────────────
  void _deleteEdge(NavigationEdge edge) {
    setState(() {
      _edges.removeWhere((e) =>
          (e.fromNode == edge.fromNode && e.toNode == edge.toNode) ||
          (e.fromNode == edge.toNode && e.toNode == edge.fromNode));
      if (_selectedEdge == edge) _selectedEdge = null;
    });

    _syncToNavigationService();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted path between ${edge.fromNode} ↔ ${edge.toNode}'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── ACTION: CLEAR ALL (Requirement 9) ────────────────────────
  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 10),
            Text(
              'Clear All Navigation Data',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Clear all navigation data for this floor?\n\n'
          'This will remove all navigation nodes, edges, universal paths, and turn nodes so you can draw from scratch.\n\n'
          'The architectural floor plan image and room details will NOT be deleted.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _nodes.clear();
                _edges.clear();
                _roomDoorMap.clear();
                _selectedNode = null;
                _connectStartNode = null;
                _pathStartNode = null;
                _selectedEdge = null;
                _nodeSeqCounter = 1;
              });
              _syncToNavigationService();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🧹 All navigation data cleared for this floor.'),
                  backgroundColor: Color(0xFFEF4444),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── ACTION: RESET VIEW (Requirement 10) ──────────────────────
  void _resetView() {
    setState(() {
      _transformController.value = Matrix4.identity();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Camera and zoom reset'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
  }

  // ── ACTION: SAVE FLOOR (Requirement 11) ──────────────────────
  Future<void> _saveFloor() async {
    setState(() => _isSaving = true);

    final success = await _adminService.saveFloorNetwork(
      floorId: _selectedFloor,
      nodes: _nodes,
      edges: _edges,
      roomDoorMap: _roomDoorMap,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.cloud_done_rounded : Icons.check_circle_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_selectedFloor.toUpperCase()} FLOOR: ${_nodes.length} nodes & ${_edges.length} edges saved live!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── INSPECTOR SHEET: NODE ────────────────────────────────────
  void _showNodePropertiesSheet(NavigationNode node) {
    final idController = TextEditingController(text: node.id);
    final labelController = TextEditingController(text: node.label ?? '');
    NodeType curType = node.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _getNodeColor(curType),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Node Inspector',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteNode(node);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Coordinates: X: ${node.x} • Y: ${node.y}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: idController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Node ID',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<NodeType>(
                initialValue: curType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Node Type',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: NodeType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t.displayName, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setSheetState(() => curType = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Label / Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              // Connected paths & distance editing from node inspector
              Builder(
                builder: (context) {
                  final connected = _edges.where((e) => e.fromNode == node.id || e.toNode == node.id).toList();
                  if (connected.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connected Paths & Distances',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: connected.map((e) {
                            final otherId = e.fromNode == node.id ? e.toNode : e.fromNode;
                            final otherNode = _findNodeById(otherId);
                            final label = otherNode?.label ?? otherId;
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              leading: const Icon(Icons.linear_scale_rounded, color: Color(0xFF38BDF8), size: 18),
                              title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      '${e.distance} m',
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 16),
                                    tooltip: 'Edit distance',
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _showEditDistanceDialog(e);
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final newId = idController.text.trim();
                    if (newId.isEmpty) return;

                    final updated = node.copyWith(
                      id: newId,
                      type: curType,
                      label: labelController.text.trim(),
                    );

                    setState(() {
                      final idx = _nodes.indexWhere((n) => n.id == node.id);
                      if (idx >= 0) {
                        _nodes[idx] = updated;
                      }
                      if (newId != node.id) {
                        for (int i = 0; i < _edges.length; i++) {
                          final e = _edges[i];
                          if (e.fromNode == node.id) {
                            _edges[i] = e.copyWith(fromNode: newId);
                          }
                          if (e.toNode == node.id) {
                            _edges[i] = e.copyWith(toNode: newId);
                          }
                        }
                      }
                      _selectedNode = updated;
                    });
                    _syncToNavigationService();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Update Node', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── INSPECTOR SHEET: EDGE & DISTANCE EDITING (Requirement 8) ──
  void _showEdgeInspectorSheet(NavigationEdge edge) {
    bool enabled = edge.enabled;
    final distController = TextEditingController(text: edge.distance.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Corridor Path Details',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteEdge(edge);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Node A:', style: TextStyle(color: Colors.white70)),
                        Text(edge.fromNode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Node B:', style: TextStyle(color: Colors.white70)),
                        Text(edge.toNode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── EDIT DISTANCE FIELD ────────────────────────────
              const Text(
                'Walking Distance (Meters)',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: distController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        suffixText: 'm',
                        suffixStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        helperText: 'Manual measured corridor distance for routing',
                        helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Auto-calculate distance from coordinates',
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      onPressed: () {
                        final a = _findNodeById(edge.fromNode);
                        final b = _findNodeById(edge.toNode);
                        if (a != null && b != null) {
                          final autoDist = _adminService.calculateDistance(a, b);
                          setSheetState(() {
                            distController.text = autoDist.toString();
                          });
                        }
                      },
                      icon: const Icon(Icons.calculate_rounded, size: 16),
                      label: const Text('Auto', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Path Enabled (Walkable)', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  enabled ? 'Users can route along this path' : 'Path is closed/blocked',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: enabled,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setSheetState(() => enabled = val);
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final parsed = double.tryParse(distController.text.trim());
                        if (parsed != null && parsed > 0) {
                          _updateEdgeDistanceAndStatus(edge, parsed, enabled);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Updated path ${edge.fromNode} ↔ ${edge.toNode}: ${parsed}m'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                      label: const Text('Save Path Distance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                    tooltip: 'Delete Path',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteEdge(edge);
                    },
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _updateEdgeDistanceAndStatus(NavigationEdge edge, double newDistance, bool isEnabled) {
    setState(() {
      final idx = _edges.indexWhere((e) =>
          (e.fromNode == edge.fromNode && e.toNode == edge.toNode) ||
          (e.fromNode == edge.toNode && e.toNode == edge.fromNode));
      if (idx >= 0) {
        _edges[idx] = _edges[idx].copyWith(distance: newDistance, enabled: isEnabled);
        if (_selectedEdge != null &&
            ((_selectedEdge!.fromNode == edge.fromNode && _selectedEdge!.toNode == edge.toNode) ||
             (_selectedEdge!.fromNode == edge.toNode && _selectedEdge!.toNode == edge.fromNode))) {
          _selectedEdge = _edges[idx];
        }
      }
    });
    _syncToNavigationService();
  }

  void _showEditDistanceDialog(NavigationEdge edge) {
    final distController = TextEditingController(text: edge.distance.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Distance Between Nodes',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${edge.fromNode} ↔ ${edge.toNode}',
              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: distController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Distance (meters)',
                labelStyle: const TextStyle(color: Colors.white70),
                suffixText: 'm',
                suffixStyle: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              final val = double.tryParse(distController.text.trim());
              if (val != null && val > 0) {
                _updateEdgeDistanceAndStatus(edge, val, edge.enabled);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Distance set to ${val}m'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedFloor,
            dropdownColor: const Color(0xFF1E293B),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'ground', child: Text('Ground Floor')),
              DropdownMenuItem(value: 'first', child: Text('First Floor')),
              DropdownMenuItem(value: 'second', child: Text('Second Floor')),
            ],
            onChanged: (val) {
              if (val != null) {
                _loadFloorData(val);
              }
            },
          ),
        ),
        actions: [
          // Reset View Button (Requirement 10)
          IconButton(
            tooltip: 'Reset View / Zoom',
            icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
            onPressed: _resetView,
          ),
          // Clear All Button (Requirement 9)
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: _confirmClearAll,
            icon: const Icon(Icons.cleaning_services_rounded, size: 16),
            label: const Text('CLEAR ALL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          // Debug Mode Toggle (Requirement 12)
          IconButton(
            tooltip: _debugMode ? 'Debug Mode ON' : 'Debug Mode OFF',
            icon: Icon(
              _debugMode ? Icons.bug_report_rounded : Icons.bug_report_outlined,
              color: _debugMode ? const Color(0xFF38BDF8) : Colors.white38,
            ),
            onPressed: () {
              setState(() => _debugMode = !_debugMode);
            },
          ),
          // Save Floor Button (Requirement 11)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 10, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: _isSaving ? null : _saveFloor,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_rounded, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'SAVE FLOOR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── MAP CANVAS (InteractiveViewer) ─────────────────────────
          InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.35,
            maxScale: 4.5,
            panEnabled: !_isDraggingNode, // REQUIREMENT 1: Disable pan while dragging node
            child: Center(
              child: SizedBox(
                width: _canvasWidth,
                height: _canvasHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onMapTapped,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    children: [
                      // Architectural Blueprint Background
                      if (_selectedFloor == 'ground')
                        Image.asset(
                          'assets/images/ground_floor_plan.jpg',
                          width: _canvasWidth,
                          height: _canvasHeight,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF1E293B),
                            child: const Center(
                              child: Text('Ground Floor Blueprint', style: TextStyle(color: Colors.white54)),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: const Color(0xFF1E293B),
                          child: Center(
                            child: Text(
                              '${_selectedFloor.toUpperCase()} FLOOR BLUEPRINT',
                              style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                      // Navigation Graph Custom Painter (Dotted Edges & Visual Nodes)
                      CustomPaint(
                        size: const Size(_canvasWidth, _canvasHeight),
                        painter: _AdminGraphPainter(
                          nodes: _nodes,
                          edges: _edges,
                          selectedNode: _selectedNode,
                          connectStartNode: _connectStartNode,
                          pathStartNode: _pathStartNode,
                          selectedEdge: _selectedEdge,
                          debugMode: _debugMode,
                          getNodeColor: _getNodeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── TOP STATUS / MODE BANNER ──────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _mode == EditorMode.moveNode
                              ? const Color(0xFF38BDF8)
                              : (_mode == EditorMode.addTurnNode ? const Color(0xFFF59E0B) : AppTheme.primary),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getModeTitle(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getModeInstruction(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${_nodes.length} Nodes • ${_edges.length} Paths',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      if (_pathStartNode != null) ...[
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(50, 26),
                          ),
                          onPressed: () {
                            setState(() {
                              _pathStartNode = null;
                            });
                          },
                          child: const Text('DONE', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM TOOLBAR (All 9 Modes) ──────────────────────────
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildToolButton(EditorMode.select, Icons.near_me_rounded, 'Select'),
                    _buildToolButton(EditorMode.moveNode, Icons.open_with_rounded, 'Move Node'),
                    _buildToolButton(EditorMode.addNode, Icons.add_location_alt_rounded, 'Add Node'),
                    _buildToolButton(EditorMode.addTurnNode, Icons.turn_right_rounded, 'Turn Node'),
                    _buildToolButton(EditorMode.addPath, Icons.route_rounded, 'Add Path'),
                    _buildToolButton(EditorMode.connect, Icons.hub_rounded, 'Connect'),
                    _buildToolButton(EditorMode.setDoor, Icons.door_front_door_rounded, 'Set Door'),
                    _buildToolButton(EditorMode.setEntrance, Icons.login_rounded, 'Set Entrance'),
                    _buildToolButton(EditorMode.delete, Icons.delete_outline_rounded, 'Delete'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getModeTitle() {
    switch (_mode) {
      case EditorMode.select:
        return 'SELECT';
      case EditorMode.moveNode:
        return 'MOVE NODE';
      case EditorMode.addNode:
        return 'ADD NODE';
      case EditorMode.addTurnNode:
        return 'TURN NODE';
      case EditorMode.addPath:
        return 'ADD PATH';
      case EditorMode.connect:
        return 'CONNECT';
      case EditorMode.setDoor:
        return 'SET DOOR';
      case EditorMode.setEntrance:
        return 'SET ENTRANCE';
      case EditorMode.delete:
        return 'DELETE';
    }
  }

  String _getModeInstruction() {
    switch (_mode) {
      case EditorMode.select:
        return 'Tap node or path to inspect / edit';
      case EditorMode.moveNode:
        return 'Drag any node to place at exact corridor location';
      case EditorMode.addNode:
        return 'Tap corridor to drop a node';
      case EditorMode.addTurnNode:
        return 'Tap corridor bend to drop Turn Node';
      case EditorMode.addPath:
        return _pathStartNode == null ? 'Tap Node A to start dotted path' : 'Tap Node B to draw walkable path';
      case EditorMode.connect:
        return _connectStartNode == null ? 'Tap Node A to start connection' : 'Tap Node B to connect';
      case EditorMode.setDoor:
        return _selectedRoomForDoor == null ? 'Select room then tap doorway' : 'Tap doorway for ${_selectedRoomForDoor!.name}';
      case EditorMode.setEntrance:
        return 'Tap map to place entrance';
      case EditorMode.delete:
        return 'Tap any node or path to delete';
    }
  }

  Widget _buildToolButton(EditorMode mode, IconData icon, String label) {
    final isActive = _mode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _mode = mode;
            _connectStartNode = null;
            if (mode != EditorMode.addPath) {
              _pathStartNode = null;
            }
          });
          if (mode == EditorMode.setDoor) {
            _pickRoomForDoor();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? Colors.white70 : Colors.white10,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : Colors.white70),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Graph Painter for Admin Map Editor
//  Requirement 2 & 14: DOTTED WALKABLE PATHS
//  Requirement 6: DISTINCT VISUAL MARKERS PER NODE TYPE
// ─────────────────────────────────────────────────────────────
class _AdminGraphPainter extends CustomPainter {
  final List<NavigationNode> nodes;
  final List<NavigationEdge> edges;
  final NavigationNode? selectedNode;
  final NavigationNode? connectStartNode;
  final NavigationNode? pathStartNode;
  final NavigationEdge? selectedEdge;
  final bool debugMode;
  final Color Function(NodeType) getNodeColor;

  _AdminGraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNode,
    required this.connectStartNode,
    required this.pathStartNode,
    required this.selectedEdge,
    required this.debugMode,
    required this.getNodeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    // 1. Draw DOTTED Walkable Edges (Requirements 2, 7, 14)
    final dotPaint = Paint()
      ..color = const Color(0xFF38BDF8) // Glowing Sky Blue Bead
      ..style = PaintingStyle.fill;

    final dotHaloPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final baseGuidePaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.25)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final disabledEdgePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final selectedEdgePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final a = nodeMap[edge.fromNode];
      final b = nodeMap[edge.toNode];
      if (a == null || b == null) continue;

      final isEdgeSelected = selectedEdge != null &&
          ((selectedEdge!.fromNode == edge.fromNode && selectedEdge!.toNode == edge.toNode) ||
           (selectedEdge!.fromNode == edge.toNode && selectedEdge!.toNode == edge.fromNode));

      if (isEdgeSelected) {
        canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), selectedEdgePaint);
      }

      if (!edge.enabled) {
        // Disabled path: faint red line
        canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), disabledEdgePaint);
      } else {
        // Subtle guiding underlay
        canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), baseGuidePaint);

        // Draw dotted walkable beads along the corridor path
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final length = math.sqrt(dx * dx + dy * dy);
        if (length > 0) {
          final ux = dx / length;
          final uy = dy / length;
          const double dotSpacing = 9.0;
          for (double dist = dotSpacing; dist < length; dist += dotSpacing) {
            final px = a.x + ux * dist;
            final py = a.y + uy * dist;
            canvas.drawCircle(Offset(px, py), 2.2, dotPaint);
            canvas.drawCircle(Offset(px, py), 3.4, dotHaloPaint);
          }
        }
      }

      // Distance tag
      if (debugMode) {
        final midX = (a.x + b.x) / 2;
        final midY = (a.y + b.y) / 2;
        final span = TextSpan(
          text: '${edge.distance}m',
          style: const TextStyle(color: Colors.white70, fontSize: 8, backgroundColor: Colors.black87),
        );
        final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(midX - tp.width / 2, midY - tp.height / 2));
      }
    }

    // 2. Draw Nodes with specific visual markers (Requirement 6)
    for (final node in nodes) {
      final isSelected = selectedNode?.id == node.id;
      final isConnectStart = connectStartNode?.id == node.id || pathStartNode?.id == node.id;
      final color = getNodeColor(node.type);
      final offset = Offset(node.x, node.y);

      // Selection Halo
      if (isSelected || isConnectStart) {
        canvas.drawCircle(
          offset,
          18.0,
          Paint()
            ..color = (isConnectStart ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)).withValues(alpha: 0.40)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          offset,
          18.0,
          Paint()
            ..color = isConnectStart ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke,
        );
      }

      // Draw distinctive marker by NodeType
      switch (node.type) {
        case NodeType.turn:
          // Amber Diamond marker for Turn Node
          final path = Path();
          path.moveTo(node.x, node.y - 8);
          path.lineTo(node.x + 8, node.y);
          path.lineTo(node.x, node.y + 8);
          path.lineTo(node.x - 8, node.y);
          path.close();
          canvas.drawPath(path, Paint()..color = Colors.white);
          final innerPath = Path();
          innerPath.moveTo(node.x, node.y - 6);
          innerPath.lineTo(node.x + 6, node.y);
          innerPath.lineTo(node.x, node.y + 6);
          innerPath.lineTo(node.x - 6, node.y);
          innerPath.close();
          canvas.drawPath(innerPath, Paint()..color = color);
          break;

        case NodeType.entrance:
          // Green Double Ring with Entrance Arrow
          canvas.drawCircle(offset, 9.0, Paint()..color = Colors.white);
          canvas.drawCircle(offset, 7.5, Paint()..color = color);
          canvas.drawCircle(offset, 4.0, Paint()..color = Colors.white);
          break;

        case NodeType.roomDoor:
          // Orange Door Marker with White border
          final rect = Rect.fromCenter(center: offset, width: 14, height: 14);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = Colors.white);
          final innerRect = Rect.fromCenter(center: offset, width: 11, height: 11);
          canvas.drawRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(2)), Paint()..color = color);
          break;

        case NodeType.junction:
          // Cyan crosshair circle
          canvas.drawCircle(offset, 8.0, Paint()..color = Colors.white);
          canvas.drawCircle(offset, 6.5, Paint()..color = color);
          canvas.drawLine(Offset(node.x - 4, node.y), Offset(node.x + 4, node.y), Paint()..color = Colors.white..strokeWidth = 1.5);
          canvas.drawLine(Offset(node.x, node.y - 4), Offset(node.x, node.y + 4), Paint()..color = Colors.white..strokeWidth = 1.5);
          break;

        case NodeType.staircase:
          // Purple staircase marker
          canvas.drawCircle(offset, 8.0, Paint()..color = Colors.white);
          canvas.drawCircle(offset, 6.5, Paint()..color = color);
          break;

        case NodeType.elevator:
          // Teal elevator marker
          canvas.drawCircle(offset, 8.0, Paint()..color = Colors.white);
          canvas.drawCircle(offset, 6.5, Paint()..color = color);
          break;

        default:
          // Corridor and Destination standard circles
          canvas.drawCircle(offset, 8.0, Paint()..color = Colors.white);
          canvas.drawCircle(offset, 6.5, Paint()..color = color);
      }

      // Labels & ID (Requirement 12: Debug Mode)
      if (debugMode || node.type == NodeType.roomDoor || node.type == NodeType.entrance || node.type == NodeType.turn) {
        final label = node.label ?? node.id;
        final span = TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black.withValues(alpha: 0.85),
          ),
        );
        final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(node.x - tp.width / 2, node.y + 11));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdminGraphPainter oldDelegate) => true;
}
