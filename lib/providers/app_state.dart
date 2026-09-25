// ─────────────────────────────────────────────────────────────
//  AppState (Provider)
//  Central reactive state store for the application.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../models/floor.dart';
import '../models/navigation_node.dart';
import '../models/navigation_route.dart';
import '../models/room.dart';
import '../services/navigation_service.dart';

class AppState extends ChangeNotifier {
  // ── Floor state ──────────────────────────────────────────────
  Floor _selectedFloor = Floors.ground;
  Floor get selectedFloor => _selectedFloor;

  void selectFloor(Floor floor) {
    if (_selectedFloor == floor) return;
    _selectedFloor = floor;
    if (_navigationDestination != null && _navigationDestination!.floor == floor.id) {
      calculateRoute();
    }
    notifyListeners();
  }

  // ── Search / room state ──────────────────────────────────────
  Room? _selectedRoom;
  Room? _navigationDestination;
  Room? _startRoom;
  NavigationNode? _startNode;
  NavigationRoute? _currentRoute;
  List<Room> _recentRooms = [];
  bool _debugMode = false;

  Room? get selectedRoom => _selectedRoom;
  Room? get navigationDestination => _navigationDestination;
  Room? get startRoom => _startRoom;
  NavigationNode? get startNode => _startNode;
  NavigationRoute? get currentRoute => _currentRoute;
  List<Room> get recentRooms => List.unmodifiable(_recentRooms);
  bool get debugMode => _debugMode;

  void toggleDebugMode() {
    _debugMode = !_debugMode;
    notifyListeners();
  }

  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    notifyListeners();
  }

  void selectRoom(Room room) {
    _selectedRoom = room;
    _selectedFloor = Floors.fromId(room.floor);
    _addToRecent(room);
    notifyListeners();
  }

  void clearSelectedRoom() {
    _selectedRoom = null;
    notifyListeners();
  }

  void setStartNode(NavigationNode node) {
    _startNode = node;
    _startRoom = null;
    if (_navigationDestination != null) {
      calculateRoute();
    }
    notifyListeners();
  }

  void setStartRoom(Room room) {
    _startRoom = room;
    final node = NavigationService().getNodeForRoom(room.id);
    if (node != null) {
      _startNode = node;
    }
    if (_navigationDestination != null) {
      calculateRoute();
    }
    notifyListeners();
  }

  void setNavigationDestination(Room room, {String? startNodeId}) {
    _navigationDestination = room;
    _selectedRoom = room;
    _selectedFloor = Floors.fromId(room.floor);
    if (startNodeId != null) {
      _startNode = NavigationService().getNodeById(startNodeId);
    } else {
      _startNode ??= NavigationService().getNodeById('node_main_entry');
    }
    calculateRoute();
  }

  void calculateRoute() {
    if (_navigationDestination == null) {
      _currentRoute = null;
      _isNavigating = false;
      notifyListeners();
      return;
    }

    final navService = NavigationService();
    final destNode = navService.getNodeForRoom(_navigationDestination!.id);
    if (destNode == null) {
      debugPrint('⚠️ No door node found for room ${_navigationDestination!.id}');
      _currentRoute = null;
      notifyListeners();
      return;
    }

    final startId = _startNode?.id ?? 'node_main_entry';
    _currentRoute = navService.findRoute(startId, destNode.id);
    _isNavigating = true;
    notifyListeners();
  }

  void clearNavigation() {
    _navigationDestination = null;
    _currentRoute = null;
    _isNavigating = false;
    notifyListeners();
  }

  void _addToRecent(Room room) {
    _recentRooms.removeWhere((r) => r.id == room.id);
    _recentRooms.insert(0, room);
    if (_recentRooms.length > 5) {
      _recentRooms = _recentRooms.sublist(0, 5);
    }
  }

  // ── Navigation mode ──────────────────────────────────────────
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  void startNavigation() {
    _isNavigating = true;
    calculateRoute();
  }

  void stopNavigation() {
    _isNavigating = false;
    _currentRoute = null;
    notifyListeners();
  }
}
