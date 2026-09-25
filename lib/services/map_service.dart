// ─────────────────────────────────────────────────────────────
//  MapService
//  Centralises Mapbox map operations and state.
//
//  TODO (Floor Plan): When indoor GeoJSON floor-plan overlays are
//  ready, add methods here to:
//    - loadFloorLayer(String floorId)
//    - removeFloorLayer(String floorId)
//    - updateRoomMarkers(List<Room> rooms)
//
//  TODO (Navigation): Add route-drawing methods:
//    - drawRoute(List<LatLng> waypoints)
//    - clearRoute()
//
//  TODO (Indoor Positioning): Hook into BLE/WiFi positioning to
//  call updateUserLocation(LatLng position) in real time.
// ─────────────────────────────────────────────────────────────

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapService {
  static MapService? _instance;
  MapboxMap? _mapboxMap;

  MapService._internal();

  factory MapService() {
    _instance ??= MapService._internal();
    return _instance!;
  }

  /// Called when the MapWidget is created and provides the controller.
  void onMapCreated(MapboxMap map) {
    _mapboxMap = map;
  }

  /// Center the camera on Sahyadri College campus.
  /// Coordinates: Sahyadri College, Mangalore, India.
  Future<void> flyToCollege() async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(74.8479, 12.9173), // lng, lat
        ),
        zoom: 17.0,
        pitch: 45.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  /// Moves the camera without animation (useful for floor switches).
  Future<void> jumpToCollege() async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(74.8479, 12.9173),
        ),
        zoom: 17.0,
      ),
    );
  }

  /// TODO (Floor Plan): Called when the user switches floors.
  /// Currently only logs — will toggle GeoJSON layers per floor.
  Future<void> switchFloor(String floorId) async {
    // ignore: avoid_print
    print('[MapService] switchFloor: $floorId — floor plan not yet implemented.');
    // Future implementation:
    // await _hideAllFloorLayers();
    // await _showFloorLayer(floorId);
  }

  void dispose() {
    _mapboxMap = null;
  }
}
