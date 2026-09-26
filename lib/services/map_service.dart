// ─────────────────────────────────────────────────────────────
//  MapService
//  Centralizes Mapbox map operations, floor plan GeoJSON rendering,
//  indoor routing layer management, and debug graph inspection.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/navigation_route.dart';
import 'floor_plan_service.dart';
import 'navigation_service.dart';

class MapService {
  static MapService? _instance;
  MapboxMap? _mapboxMap;

  // Source & Layer IDs
  static const String floorSourceId = 'floor-geojson-source';
  static const String buildingFillLayerId = 'floor-building-fill';
  static const String courtyardFillLayerId = 'floor-courtyard-fill';
  static const String roomsFillLayerId = 'floor-rooms-fill';
  static const String corridorsFillLayerId = 'floor-corridors-fill';
  static const String roomsOutlineLayerId = 'floor-rooms-outline';
  static const String roomLabelsLayerId = 'floor-room-labels';

  static const String routeSourceId = 'route-geojson-source';
  static const String routeCasingLayerId = 'route-casing-layer';
  static const String routeLineLayerId = 'route-line-layer';
  static const String routeEndpointsLayerId = 'route-endpoints-layer';

  static const String debugNodesSourceId = 'debug-nodes-source';
  static const String debugNodesLayerId = 'debug-nodes-layer';
  static const String debugEdgesSourceId = 'debug-edges-source';
  static const String debugEdgesLayerId = 'debug-edges-layer';

  // Campus Center Coordinates (Sahyadri College Main Academic Block)
  static const double campusCenterLng = 74.92552;
  static const double campusCenterLat = 12.86602;

  bool _styleInitialized = false;
  bool _debugMode = false;
  String _currentFloor = 'ground';

  MapService._internal();

  factory MapService() {
    _instance ??= MapService._internal();
    return _instance!;
  }

  bool get isMapReady => _mapboxMap != null && _styleInitialized;
  bool get isDebugMode => _debugMode;
  String get currentFloor => _currentFloor;

  void onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    _styleInitialized = false;
  }

  /// Called when Mapbox style finishes loading
  Future<void> onStyleLoaded() async {
    if (_mapboxMap == null) return;
    try {
      _styleInitialized = true;
      await _setupFloorLayers(_currentFloor);
      await _setupRouteLayers();
      if (_debugMode) {
        await _setupDebugLayers(_currentFloor);
      }
      debugPrint('🗺️ Mapbox indoor floor & route layers initialized successfully.');
    } catch (e) {
      debugPrint('⚠️ Error setting up Mapbox style layers: $e');
    }
  }

  /// Sets up or updates the indoor floor GeoJSON source & layers
  Future<void> _setupFloorLayers(String floorId) async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    final geoJson = await FloorPlanService().getFloorGeoJson(floorId);

    // If source exists, update its GeoJSON data
    final sourceExists = await style.styleSourceExists(floorSourceId);
    if (sourceExists) {
      final source = await style.getSource(floorSourceId);
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geoJson);
      } else {
        await style.setStyleSourceProperty(floorSourceId, 'data', geoJson);
      }
      return;
    }

    // Add GeoJSON source
    await style.addSource(GeoJsonSource(id: floorSourceId, data: geoJson));

    // 1. Building perimeter fill
    await style.addLayer(
      FillLayer(
        id: buildingFillLayerId,
        sourceId: floorSourceId,
        filter: [
          '==',
          ['get', 'type'],
          'building',
        ],
        fillColor: 0xFFF8FAFC, // slate-50
        fillOpacity: 1.0,
      ),
    );

    // 2. Courtyard fills
    await style.addLayer(
      FillLayer(
        id: courtyardFillLayerId,
        sourceId: floorSourceId,
        filter: [
          '==',
          ['get', 'type'],
          'courtyard',
        ],
        fillColor: 0xFFE0E7FF, // indigo-100
        fillOpacity: 0.9,
      ),
    );

    // 3. Room polygons fill
    await style.addLayer(
      FillLayer(
        id: roomsFillLayerId,
        sourceId: floorSourceId,
        filter: [
          '==',
          ['get', 'type'],
          'room',
        ],
        fillColor: 0xFFF1F5F9, // slate-100
        fillOpacity: 0.95,
      ),
    );

    // 4. Corridors fill
    await style.addLayer(
      FillLayer(
        id: corridorsFillLayerId,
        sourceId: floorSourceId,
        filter: [
          '==',
          ['get', 'type'],
          'corridor',
        ],
        fillColor: 0xFFFFFFFF,
        fillOpacity: 1.0,
      ),
    );

    // 5. Room wall outlines
    await style.addLayer(
      LineLayer(
        id: roomsOutlineLayerId,
        sourceId: floorSourceId,
        lineColor: 0xFF475569, // slate-600
        lineWidth: 1.4,
      ),
    );

    // 6. Room labels (Symbol layer)
    await style.addLayer(
      SymbolLayer(
        id: roomLabelsLayerId,
        sourceId: floorSourceId,
        filter: [
          '==',
          ['get', 'type'],
          'room_label',
        ],
        textField: '{label}',
        textSize: 10.5,
        textColor: 0xFF1E293B, // slate-800
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 1.5,
      ),
    );
  }

  /// Sets up Navigation Route line and endpoint layers
  Future<void> _setupRouteLayers() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';
    final sourceExists = await style.styleSourceExists(routeSourceId);
    if (!sourceExists) {
      await style.addSource(GeoJsonSource(id: routeSourceId, data: emptyGeoJson));

      // White outline casing for the route
      await style.addLayer(
        LineLayer(
          id: routeCasingLayerId,
          sourceId: routeSourceId,
          filter: [
            '==',
            ['get', 'type'],
            'route',
          ],
          lineColor: 0xFFFFFFFF,
          lineWidth: 8.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );

      // Vivid blue route line
      await style.addLayer(
        LineLayer(
          id: routeLineLayerId,
          sourceId: routeSourceId,
          filter: [
            '==',
            ['get', 'type'],
            'route',
          ],
          lineColor: 0xFF2563EB, // blue-600
          lineWidth: 5.5,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );

      // Start & destination endpoints
      await style.addLayer(
        CircleLayer(
          id: routeEndpointsLayerId,
          sourceId: routeSourceId,
          circleColor: 0xFFDC2626, // red-600
          circleRadius: 6.0,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.0,
        ),
      );
    }
  }

  /// Sets up or refreshes Debug layers showing all nodes and edges
  Future<void> _setupDebugLayers(String floorId) async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;
    final navService = NavigationService();

    final edgesGeoJson = navService.debugEdgesToGeoJson(floorId);
    final nodesGeoJson = navService.debugNodesToGeoJson(floorId);

    // Edges Source & Layer
    if (await style.styleSourceExists(debugEdgesSourceId)) {
      final s = await style.getSource(debugEdgesSourceId);
      if (s is GeoJsonSource) await s.updateGeoJSON(edgesGeoJson);
    } else {
      await style.addSource(GeoJsonSource(id: debugEdgesSourceId, data: edgesGeoJson));
      await style.addLayer(
        LineLayer(
          id: debugEdgesLayerId,
          sourceId: debugEdgesSourceId,
          lineColor: 0xFF94A3B8, // slate-400
          lineWidth: 1.5,
        ),
      );
    }

    // Nodes Source & Layer
    if (await style.styleSourceExists(debugNodesSourceId)) {
      final s = await style.getSource(debugNodesSourceId);
      if (s is GeoJsonSource) await s.updateGeoJSON(nodesGeoJson);
    } else {
      await style.addSource(GeoJsonSource(id: debugNodesSourceId, data: nodesGeoJson));
      await style.addLayer(
        CircleLayer(
          id: debugNodesLayerId,
          sourceId: debugNodesSourceId,
          circleColor: 0xFF10B981, // emerald-500
          circleRadius: 4.5,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 1.0,
        ),
      );
    }
  }

  /// Switches active floor. Replaces floor GeoJSON without reloading entire map.
  Future<void> switchFloor(String floorId) async {
    _currentFloor = floorId;
    if (_mapboxMap == null || !_styleInitialized) return;

    try {
      await _setupFloorLayers(floorId);
      if (_debugMode) {
        await _setupDebugLayers(floorId);
      }
      debugPrint('🏢 Switched map view to floor: $floorId');
    } catch (e) {
      debugPrint('⚠️ Error switching floor in MapService: $e');
    }
  }

  /// Dynamically renders a calculated navigation route onto the Mapbox map.
  Future<void> drawRoute(NavigationRoute route) async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    try {
      final geoJson = NavigationService().routeToGeoJson(route);
      if (await style.styleSourceExists(routeSourceId)) {
        final source = await style.getSource(routeSourceId);
        if (source is GeoJsonSource) {
          await source.updateGeoJSON(geoJson);
        } else {
          await style.setStyleSourceProperty(routeSourceId, 'data', geoJson);
        }
      } else {
        await _setupRouteLayers();
        final source = await style.getSource(routeSourceId);
        if (source is GeoJsonSource) {
          await source.updateGeoJSON(geoJson);
        }
      }
      debugPrint('🚀 Route drawn dynamically on Mapbox (${route.nodes.length} nodes).');
    } catch (e) {
      debugPrint('⚠️ Error drawing route on Mapbox: $e');
    }
  }

  /// Clears the displayed navigation route
  Future<void> clearRoute() async {
    if (_mapboxMap == null) return;
    final style = _mapboxMap!.style;

    try {
      const emptyGeoJson = '{"type":"FeatureCollection","features":[]}';
      if (await style.styleSourceExists(routeSourceId)) {
        final source = await style.getSource(routeSourceId);
        if (source is GeoJsonSource) {
          await source.updateGeoJSON(emptyGeoJson);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing route: $e');
    }
  }

  /// Toggles debug visualization mode (nodes and edges)
  Future<void> toggleDebugMode() async {
    _debugMode = !_debugMode;
    if (_mapboxMap == null || !_styleInitialized) return;

    final style = _mapboxMap!.style;
    if (_debugMode) {
      await _setupDebugLayers(_currentFloor);
    } else {
      if (await style.styleLayerExists(debugNodesLayerId)) {
        await style.removeStyleLayer(debugNodesLayerId);
      }
      if (await style.styleSourceExists(debugNodesSourceId)) {
        await style.removeStyleSource(debugNodesSourceId);
      }
      if (await style.styleLayerExists(debugEdgesLayerId)) {
        await style.removeStyleLayer(debugEdgesLayerId);
      }
      if (await style.styleSourceExists(debugEdgesSourceId)) {
        await style.removeStyleSource(debugEdgesSourceId);
      }
    }
  }

  /// Centers the camera smoothly on Sahyadri College building
  Future<void> flyToCollege() async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(campusCenterLng, campusCenterLat),
        ),
        zoom: 18.2,
        pitch: 35.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  /// Smoothly flies the camera to a specific coordinate
  Future<void> flyToCoordinates(double lng, double lat, {double zoom = 19.5}) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
        pitch: 40.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  /// Adjusts camera to fit an entire route with padding
  Future<void> fitRoute(NavigationRoute route) async {
    if (_mapboxMap == null || route.nodes.isEmpty) return;

    double minLng = 180.0, maxLng = -180.0;
    double minLat = 90.0, maxLat = -90.0;

    for (final n in route.nodes) {
      if (n.lng < minLng) minLng = n.lng;
      if (n.lng > maxLng) maxLng = n.lng;
      if (n.lat < minLat) minLat = n.lat;
      if (n.lat > maxLat) maxLat = n.lat;
    }

    final centerLng = (minLng + maxLng) / 2;
    final centerLat = (minLat + maxLat) / 2;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: 18.6,
        pitch: 25.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  void dispose() {
    _mapboxMap = null;
    _styleInitialized = false;
  }
}
