// ─────────────────────────────────────────────────────────────
//  FloorPlanService
//  Loads and manages indoor GeoJSON floor plans locally.
//  Can later be extended to fetch from Firestore / remote storage.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class FloorPlanService {
  static final FloorPlanService _instance = FloorPlanService._internal();
  factory FloorPlanService() => _instance;
  FloorPlanService._internal();

  final Map<String, String> _geojsonCache = {};
  final Map<String, Map<String, dynamic>> _parsedCache = {};

  /// Loads the raw GeoJSON string for the specified floor.
  Future<String> getFloorGeoJson(String floorId) async {
    final normalized = floorId.toLowerCase().replaceAll(' ', '_');
    if (_geojsonCache.containsKey(normalized)) {
      return _geojsonCache[normalized]!;
    }

    try {
      final assetPath = 'assets/maps/${normalized}_floor.geojson';
      final jsonString = await rootBundle.loadString(assetPath);
      _geojsonCache[normalized] = jsonString;
      _parsedCache[normalized] = json.decode(jsonString) as Map<String, dynamic>;
      debugPrint('📍 Loaded floor plan GeoJSON for $normalized (${jsonString.length} bytes)');
      return jsonString;
    } catch (e) {
      debugPrint('⚠️ Could not load floor GeoJSON for $normalized: $e');
      // Return a valid empty FeatureCollection so Mapbox doesn't crash
      const emptyCollection = '{"type":"FeatureCollection","features":[]}';
      _geojsonCache[normalized] = emptyCollection;
      return emptyCollection;
    }
  }

  /// Returns parsed GeoJSON features for inspection / markers
  Future<List<Map<String, dynamic>>> getFeaturesForFloor(String floorId) async {
    final normalized = floorId.toLowerCase().replaceAll(' ', '_');
    if (!_parsedCache.containsKey(normalized)) {
      await getFloorGeoJson(normalized);
    }
    final parsed = _parsedCache[normalized];
    if (parsed == null || parsed['features'] == null) return [];
    return List<Map<String, dynamic>>.from(parsed['features'] as List);
  }

  /// Clears cache (useful when reloading or fetching fresh data from cloud)
  void clearCache() {
    _geojsonCache.clear;
    _parsedCache.clear;
  }
}
