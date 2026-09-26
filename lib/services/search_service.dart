// ─────────────────────────────────────────────────────────────
//  SearchService
//  Loads room data from local JSON asset and provides search.
//
//  TODO (Firebase): Replace _loadFromAsset() with a Firestore
//  query when remote data is ready:
//
//    final snapshot = await FirebaseFirestore.instance
//        .collection('rooms')
//        .get();
//    return snapshot.docs.map((d) => Room.fromJson(d.data())).toList();
//
//  TODO (Search): Add fuzzy-matching or Algolia integration for
//  better search relevance at scale.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/room.dart';
import 'firebase_room_service.dart';

class SearchService {
  static SearchService? _instance;
  List<Room> _rooms = [];
  bool _loaded = false;

  SearchService._internal();

  factory SearchService() {
    _instance ??= SearchService._internal();
    return _instance!;
  }

  /// Loads room data from local JSON immediately and updates from Firebase in background.
  Future<void> init() async {
    if (_loaded) return;
    try {
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/data/rooms.json');
      } catch (_) {
        jsonString = await rootBundle.loadString('lib/data/rooms.json');
      }
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> rawRooms = data['rooms'] as List<dynamic>;
      _rooms = rawRooms.map((r) => Room.fromJson(r as Map<String, dynamic>)).toList();
      _loaded = true;
    } catch (_) {}

    // Background Firebase refresh
    FirebaseRoomService().fetchRooms().then((remoteRooms) {
      if (remoteRooms.isNotEmpty) {
        _rooms = remoteRooms;
      }
    }).catchError((_) {});
  }

  /// Returns all rooms (optionally filtered by floor).
  List<Room> getAllRooms({String? floorId}) {
    if (floorId == null) return List.unmodifiable(_rooms);
    return _rooms.where((r) => r.floor == floorId).toList();
  }

  /// Case-insensitive search across name, roomNumber, and category.
  List<Room> search(String query, {String? floorId}) {
    if (query.trim().isEmpty) {
      return getAllRooms(floorId: floorId);
    }
    final q = query.toLowerCase().trim();
    return _rooms.where((room) {
      final matchesQuery = room.name.toLowerCase().contains(q) ||
          room.roomNumber.toLowerCase().contains(q) ||
          room.category.displayName.toLowerCase().contains(q) ||
          room.description.toLowerCase().contains(q);
      final matchesFloor = floorId == null || room.floor == floorId;
      return matchesQuery && matchesFloor;
    }).toList();
  }

  /// Finds a room by its unique [id].
  Room? findById(String id) {
    try {
      return _rooms.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
