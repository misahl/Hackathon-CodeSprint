// ─────────────────────────────────────────────────────────────
//  Admin Manage Floors Screen
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';

class AdminManageFloorsScreen extends StatelessWidget {
  const AdminManageFloorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navService = NavigationService();
    final groundNodes = navService.getNodesForFloor('ground').length;
    final groundEdges = navService.getEdgesForFloor('ground').length;

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
          'Manage Campus Floors',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFloorCard(
            context,
            floorName: 'Ground Floor (Level 0)',
            floorId: 'ground',
            subtitle: 'Primary Academic Block & Engineering Labs',
            nodeCount: groundNodes,
            edgeCount: groundEdges,
            isConfigured: true,
          ),
          const SizedBox(height: 14),
          _buildFloorCard(
            context,
            floorName: 'First Floor (Level 1)',
            floorId: 'first',
            subtitle: 'Classrooms & Computer Science Department',
            nodeCount: 0,
            edgeCount: 0,
            isConfigured: false,
          ),
          const SizedBox(height: 14),
          _buildFloorCard(
            context,
            floorName: 'Second Floor (Level 2)',
            floorId: 'second',
            subtitle: 'Lecture Halls & Research Labs',
            nodeCount: 0,
            edgeCount: 0,
            isConfigured: false,
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard(
    BuildContext context, {
    required String floorName,
    required String floorId,
    required String subtitle,
    required int nodeCount,
    required int edgeCount,
    required bool isConfigured,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfigured ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                floorName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isConfigured ? 'ACTIVE NETWORK' : 'READY TO MAP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isConfigured ? const Color(0xFF10B981) : Colors.white60,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                '$nodeCount Nodes • $edgeCount Edges',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                context.push('/admin/editor');
              },
              icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
              label: const Text('Open Floor in Map Editor'),
            ),
          ),
        ],
      ),
    );
  }
}
