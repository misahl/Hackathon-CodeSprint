# Sahyadri AR — Campus Navigation App

> Indoor campus navigation for Sahyadri College of Engineering & Management  
> Built for a Hackathon Sprint · Flutter + Mapbox

---

## Running the App

```bash
flutter run --dart-define ACCESS_TOKEN=<YOUR_MAPBOX_PUBLIC_TOKEN>
```

**You will need two Mapbox tokens:**

| Token | Purpose |
|---|---|
| `ACCESS_TOKEN` (public `pk.xxx`) | Passed at runtime via `--dart-define`; used by the Flutter SDK to load map tiles |
| `MAPBOX_DOWNLOADS_TOKEN` (secret `sk.xxx`) | Stored in `~/.gradle/gradle.properties`; used by Gradle to download the native Android SDK |

### Setting up the Mapbox Downloads Token

1. Go to https://account.mapbox.com → Tokens → Create a secret token with `DOWNLOADS:READ` scope
2. Add to `~/.gradle/gradle.properties` (create if it doesn't exist):

```properties
MAPBOX_DOWNLOADS_TOKEN=sk.eyJ1Ijoixxxxxxx...
```

---

## Project Structure

```
lib/
├── main.dart                    ← App entry point (Mapbox init, Provider setup)
│
├── models/
│   ├── room.dart                ← Room model (id, name, floor, category, coords)
│   └── floor.dart               ← Floor model + Floors static helper
│
├── providers/
│   └── app_state.dart           ← Central ChangeNotifier (floor, room, navigation state)
│
├── services/
│   ├── search_service.dart      ← Loads rooms.json, provides search/filter
│   ├── map_service.dart         ← Mapbox map controller wrapper
│   └── navigation_service.dart  ← Navigation graph interface (placeholder)
│
├── screens/
│   ├── home_screen.dart         ← Home with logo, search bar, quick actions, recents
│   ├── map_screen.dart          ← Full-screen Mapbox map with floor overlay
│   ├── search_screen.dart       ← Live search with category filters
│   ├── room_details_screen.dart ← Room info + Navigate/View on Map buttons
│   └── ar_screen.dart           ← AR placeholder with animated UI
│
├── widgets/
│   ├── scaffold_with_bottom_nav.dart ← Persistent bottom navigation shell
│   ├── search_bar_widget.dart        ← Reusable search field
│   ├── floor_selector.dart           ← Animated floor tab switcher
│   ├── navigation_button.dart        ← Large gradient CTA button
│   └── room_card.dart                ← Room list tile with category chip
│
├── theme/
│   └── app_theme.dart           ← Material 3 theme (Inter font, brand colours)
│
├── router/
│   └── app_router.dart          ← GoRouter config (shell + full-screen routes)
│
└── data/
    └── rooms.json               ← 14 ground-floor room mock records
```

---

## Mock Data (Ground Floor)

| Room | Number | Category |
|------|--------|----------|
| Computer Lab 27 | 27 | Lab |
| Computer Lab 28 | 28 | Lab |
| Computer Lab 29 | 29 | Lab |
| Computer Lab 30 | 30 | Lab |
| Innovation Lab | IL-01 | Lab |
| Study Space | SS-01 | Facility |
| Admission Section | ADM-01 | Office |
| Visitor Lounge | VL-01 | Facility |
| Reception | RCP-01 | Facility |
| Seminar Hall | SH-01 | Hall |
| CS Staff Room | SR-CS | Office |
| Examination Section | EX-01 | Office |
| Placement Office | PO-01 | Office |
| Principal's Chamber | PC-01 | Office |

---

## Future Development Roadmap

### Phase 2 — Indoor Map Overlay
- [ ] Integrate GeoJSON floor-plan per floor in `MapService`
- [ ] Add room pin markers as `SymbolLayer`
- [ ] Hook floor selector to layer visibility toggle

### Phase 3 — Navigation Routing
- [ ] Build `NavigationGraph` from GeoJSON corridor data
- [ ] Implement A* in `NavigationService.findRoute()`
- [ ] Draw route `LineLayer` on the map via `MapService.drawRoute()`

### Phase 4 — Firebase
- [ ] `Firebase.initializeApp()` in `main.dart`
- [ ] Replace `SearchService` JSON loading with Firestore fetch
- [ ] Firebase Auth for student login
- [ ] Firestore room management

### Phase 5 — AR Navigation
- [ ] Enable `CAMERA` permission in `AndroidManifest.xml`
- [ ] Integrate `ar_flutter_plugin` / ARCore
- [ ] Map `NavInstruction` list to 3D arrow anchors
- [ ] Real-time indoor positioning (BLE / WiFi fingerprinting)

---

## Tech Stack

- **Flutter** 3.x + **Dart** 3.x
- **Mapbox Maps SDK for Flutter** v2.x
- **go_router** for declarative routing
- **provider** for state management
- **google_fonts** (Inter typeface)
- **equatable** for value equality

---

## Team Notes

- Search keyword `TODO (Firebase)` for all integration points  
- Search keyword `TODO (AR)` for AR hook-in locations  
- Search keyword `TODO (Navigation)` for routing integration points  
- Search keyword `TODO (Floor Plan)` for map layer integration points  
- Search keyword `TODO (Indoor Positioning)` for positioning integration points
