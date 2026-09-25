// ─────────────────────────────────────────────────────────────
//  FirebaseRoomService
//  Provides real-time room data fetching and syncing with Firebase
//  Cloud Firestore, with seamless local fallback to rooms.json.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/room.dart';

class FirebaseRoomService {
  static final FirebaseRoomService _instance = FirebaseRoomService._internal();
  factory FirebaseRoomService() => _instance;
  FirebaseRoomService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'rooms';

  /// Fetches rooms live from Firebase Cloud Firestore.
  /// Falls back to local asset if Firebase is unreachable or empty.
  Future<List<Room>> fetchRooms() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('🔥 Loaded ${snapshot.docs.length} rooms from Firebase Cloud Firestore.');
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Room.fromJson(data);
        }).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Firebase fetch error or unconfigured (falling back to local data): $e');
    }

    return _loadLocalAssetRooms();
  }

  /// Listens to real-time room updates from Firebase Cloud Firestore.
  Stream<List<Room>> streamRooms() {
    return _firestore.collection(_collectionName).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Room.fromJson(data);
      }).toList();
    });
  }

  /// Helper utility: Uploads/seeds local rooms from rooms.json into Firebase Cloud Firestore.
  Future<void> seedLocalRoomsToFirebase() async {
    try {
      final rooms = await _loadLocalAssetRooms();
      final batch = _firestore.batch();

      for (final room in rooms) {
        final docRef = _firestore.collection(_collectionName).doc(room.id);
        batch.set(docRef, room.toJson(), SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('✅ Successfully seeded ${rooms.length} rooms to Firebase Cloud Firestore!');
    } catch (e) {
      debugPrint('❌ Error seeding rooms to Firebase: $e');
      rethrow;
    }
  }

  /// Private helper to load fallback local JSON rooms.
  Future<List<Room>> _loadLocalAssetRooms() async {
    final jsonString = await rootBundle.loadString('lib/data/rooms.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    final List<dynamic> rawRooms = data['rooms'] as List<dynamic>;
    return rawRooms.map((r) => Room.fromJson(r as Map<String, dynamic>)).toList();
  }
}
