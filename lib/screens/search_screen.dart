// ─────────────────────────────────────────────────────────────
//  Search Screen
//  Allows users to search and filter rooms by floor / category.
//
//  TODO (Firebase): Replace SearchService local JSON with a
//  Firestore-backed implementation when data is remote.
//
//  TODO (Search): Consider adding debounce or Algolia for
//  better performance at scale.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../providers/app_state.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import '../widgets/room_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService();
  final TextEditingController _controller = TextEditingController();
  List<Room> _results = [];
  bool _loading = true;
  String _selectedCategory = 'all';

  static const _categories = [
    ('all', 'All'),
    ('lab', 'Labs'),
    ('office', 'Offices'),
    ('facility', 'Facilities'),
    ('hall', 'Halls'),
  ];

  @override
  void initState() {
    super.initState();
    _init();
    _controller.addListener(_onQueryChanged);
  }

  Future<void> _init() async {
    await _searchService.init();
    _search('');
    setState(() => _loading = false);
  }

  void _onQueryChanged() => _search(_controller.text);

  void _search(String query) {
    final state = context.read<AppState>();
    final results = _searchService.search(
      query,
      floorId: state.selectedFloor.id == 'ground' ? null : state.selectedFloor.id,
    );
    setState(() {
      _results = _selectedCategory == 'all'
          ? results
          : results.where((r) => r.category.name == _selectedCategory).toList();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: AppTheme.cardSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Search field ─────────────────────────────────────
          Container(
            color: AppTheme.cardSurface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search room, lab or office...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textSecondary),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppTheme.textSecondary),
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // ── Category filter chips ─────────────────────────────
          Container(
            color: AppTheme.cardSurface,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat.$2),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.divider,
                      ),
                      backgroundColor: AppTheme.background,
                      onSelected: (_) {
                        setState(
                            () => _selectedCategory = cat.$1);
                        _search(_controller.text);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Divider ──────────────────────────────────────────
          const Divider(height: 1, color: AppTheme.divider),

          // ── Results ──────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _EmptyState(query: _controller.text)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _results.length,
                        itemBuilder: (_, i) => RoomCard(room: _results[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            query.isEmpty ? 'No rooms available.' : 'No results for "$query"',
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different keyword or category.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
