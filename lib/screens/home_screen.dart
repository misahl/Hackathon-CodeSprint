// ─────────────────────────────────────────────────────────────
//  Home Screen — Sahyadri AR
//  Premium, minimal campus navigation landing page.
//  Design inspiration: restrained typography, generous whitespace,
//  strong visual hierarchy (Apple design language applied to
//  a campus navigation product).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/floor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    ));

    _heroController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Minimal Top Navigation Bar ─────────────────────
              SliverToBoxAdapter(
                child: _buildTopBar(),
              ),

              // ── Hero Section ───────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: _buildHeroSection(),
                  ),
                ),
              ),

              // ── Search Field ───────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: _buildSearchField(context),
                  ),
                ),
              ),

              // ── Primary Actions ────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverToBoxAdapter(
                  child: _buildPrimaryActions(context),
                ),
              ),

              // ── Floor Selector ─────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverToBoxAdapter(
                  child: _buildFloorSelector(state),
                ),
              ),

              // ── Recent Destinations ────────────────────────────
              if (state.recentRooms.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildRecentSection(state),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sahyadri AR',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Campus Navigation',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hero Section ────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your way\naround Sahyadri.',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.12,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Indoor campus navigation with\nmaps and AR guidance.',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Field ────────────────────────────────────────────
  Widget _buildSearchField(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Search rooms, labs, offices and facilities',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Primary Actions ─────────────────────────────────────────
  Widget _buildPrimaryActions(BuildContext context) {
    return Column(
      children: [
        // Explore Campus
        _PrimaryActionButton(
          label: 'Explore Campus',
          subtitle: 'Interactive indoor floor maps',
          icon: Icons.map_outlined,
          color: AppTheme.primary,
          onTap: () => context.go('/map'),
        ),
        const SizedBox(height: 12),
        // Start AR Navigation
        _PrimaryActionButton(
          label: 'Start AR Navigation',
          subtitle: 'Live camera with direction overlay',
          icon: Icons.view_in_ar_rounded,
          color: const Color(0xFF1A1A2E),
          onTap: () => context.push('/ar'),
        ),
      ],
    );
  }

  // ── Floor Selector ──────────────────────────────────────────
  Widget _buildFloorSelector(AppState state) {
    final floors = [Floors.ground, Floors.first, Floors.second];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Floor',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: floors.map((floor) {
            final isSelected = state.selectedFloor.id == floor.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => state.selectFloor(floor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    floor.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Recent Destinations ─────────────────────────────────────
  Widget _buildRecentSection(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        ...state.recentRooms.take(3).map((room) {
          final floorName = room.floor == 'ground'
              ? 'Ground Floor'
              : (room.floor == 'first' ? '1st Floor' : '2nd Floor');

          return GestureDetector(
            onTap: () {
              state.selectRoom(room);
              context.go('/map');
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Room ${room.roomNumber} · $floorName',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFFADB5BD),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Reusable Primary Action Button ─────────────────────────────
class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
