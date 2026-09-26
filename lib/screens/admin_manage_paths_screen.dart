// ─────────────────────────────────────────────────────────────
//  Admin Manage Navigation Paths Screen
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/navigation_edge.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';

class AdminManagePathsScreen extends StatefulWidget {
  const AdminManagePathsScreen({super.key});

  @override
  State<AdminManagePathsScreen> createState() => _AdminManagePathsScreenState();
}

class _AdminManagePathsScreenState extends State<AdminManagePathsScreen> {
  String _selectedFloor = 'ground';

  @override
  Widget build(BuildContext context) {
    final navService = NavigationService();
    final edges = navService.getEdgesForFloor(_selectedFloor);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Manage Navigation Paths',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'Draw Path on Map',
            onPressed: () => context.push('/admin/editor'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Floor tab selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                _buildTab('Ground Floor', 'ground'),
                const SizedBox(width: 8),
                _buildTab('First Floor', 'first'),
                const SizedBox(width: 8),
                _buildTab('Second Floor', 'second'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${edges.length} Active Walking Connections',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/admin/editor'),
                  icon: const Icon(Icons.edit_road_rounded, size: 16),
                  label: const Text('Edit on Map'),
                ),
              ],
            ),
          ),
          Expanded(
            child: edges.isEmpty
                ? const Center(
                    child: Text('No path connections found for this floor.', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: edges.length,
                    itemBuilder: (ctx, i) {
                      final edge = edges[i];
                      return _buildEdgeTile(edge);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String id) {
    final isSelected = _selectedFloor == id;
    return InkWell(
      onTap: () => setState(() => _selectedFloor = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeTile(NavigationEdge edge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.linear_scale_rounded, color: Color(0xFF38BDF8), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      edge.fromNode,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white54),
                    ),
                    Text(
                      edge.toNode,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Distance: ${edge.distance} m • Universal Corridor',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: edge.enabled,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) {
              setState(() {
                final updated = edge.copyWith(enabled: val);
                NavigationService().addEdge(updated, floor: _selectedFloor);
              });
            },
          ),
        ],
      ),
    );
  }
}
