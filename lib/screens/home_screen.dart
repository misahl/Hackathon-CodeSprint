// ─────────────────────────────────────────────────────────────
//  Home Screen — MAPO Campus Navigation
//  Clean modern campus navigation landing page.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../providers/app_state.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';

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
      duration: const Duration(milliseconds: 700),
    );

    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
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
              // ── Top Bar ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildTopBar(),
              ),

              // ── Hero Section ────────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: _buildHeroSection(),
                  ),
                ),
              ),

              // ── Search Field ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: _buildSearchField(context),
                  ),
                ),
              ),

              // ── Primary Action Buttons ──────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: _buildPrimaryActions(context),
                ),
              ),

              // ── Floor Selector ──────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: _buildFloorSelector(state),
                ),
              ),

              // ── Featured & Recent Destinations ──────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: _buildRecentSection(context, state),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/mapo_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mapo',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'The Sahyadri AR',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Sahyadri Campus',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Section ───────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Indoor Navigation\nMade Simple.',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              height: 1.15,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Interactive indoor map & routing for classrooms, labs, and faculty offices.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Field ───────────────────────────────────────────────
  Widget _buildSearchField(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              'Search room, lab or office...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Primary Action Buttons ─────────────────────────────────────
  Widget _buildPrimaryActions(BuildContext context) {
    return Row(
      children: [
        // View Map Button
        Expanded(
          child: _ActionButton(
            label: 'View Map',
            subtitle: 'Interactive Mapbox',
            icon: Icons.map_rounded,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            onTap: () => context.go('/map'),
          ),
        ),
        const SizedBox(width: 12),
        // AR Navigation Button
        Expanded(
          child: _ActionButton(
            label: 'AR Navigation',
            subtitle: 'Next Phase Preview',
            icon: Icons.view_in_ar_rounded,
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            onTap: () => context.push('/ar'),
          ),
        ),
      ],
    );
  }

  // ── Floor Selector ─────────────────────────────────────────────
  Widget _buildFloorSelector(AppState state) {
    final floors = [Floors.ground, Floors.first, Floors.second];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Building Level',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Ground Active',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: floors.map((floor) {
            final isSelected = state.selectedFloor.id == floor.id;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => state.selectFloor(floor),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        floor.name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
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

  // ── Recent / Quick Destinations ────────────────────────────────
  Widget _buildRecentSection(BuildContext context, AppState state) {
    // Curated quick destinations if recent is empty, featuring Computer Lab 27
    final List<Room> displayRooms = state.recentRooms.isNotEmpty
        ? state.recentRooms
        : [
            SearchService().findById('gf_computer_lab_27') ??
                const Room(
                  id: 'gf_computer_lab_27',
                  name: 'Computer Lab 27',
                  roomNumber: '27',
                  floor: 'ground',
                  floorLevel: 0,
                  category: RoomCategory.lab,
                  description: 'Programming and CS laboratory',
                  coordinates: RoomCoordinates(x: 800, y: 878),
                ),
            SearchService().findById('gf_principals_chamber_2') ??
                const Room(
                  id: 'gf_principals_chamber_2',
                  name: "Principal's Chamber",
                  roomNumber: '2',
                  floor: 'ground',
                  floorLevel: 0,
                  category: RoomCategory.office,
                  description: "Principal's administrative chamber",
                  coordinates: RoomCoordinates(x: 790, y: 260),
                ),
            SearchService().findById('gf_seminar_hall') ??
                const Room(
                  id: 'gf_seminar_hall',
                  name: 'Seminar Hall',
                  roomNumber: '19',
                  floor: 'ground',
                  floorLevel: 0,
                  category: RoomCategory.hall,
                  description: 'Ground Floor seminar auditorium',
                  coordinates: RoomCoordinates(x: 165, y: 415),
                ),
            SearchService().findById('gf_admission_section_37') ??
                const Room(
                  id: 'gf_admission_section_37',
                  name: 'Admission Section',
                  roomNumber: '37',
                  floor: 'ground',
                  floorLevel: 0,
                  category: RoomCategory.office,
                  description: 'Student admissions counter',
                  coordinates: RoomCoordinates(x: 225, y: 900),
                ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.recentRooms.isNotEmpty ? 'Recent Destinations' : 'Popular Destinations',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/search'),
              child: const Text(
                'See All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...displayRooms.take(4).map((room) {
          final catColor = AppTheme.categoryColor(room.category.name);
          final catIcon = AppTheme.categoryIcon(room.category.name);
          final isDemoRoute = room.id == 'gf_computer_lab_27';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDemoRoute
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : const Color(0xFFE2E8F0),
                width: isDemoRoute ? 1.5 : 1.0,
              ),
            ),
            child: ListTile(
              onTap: () {
                state.selectRoom(room);
                context.push('/room/${room.id}');
              },
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDemoRoute)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DEMO ROUTE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${room.roomNumber.isNotEmpty ? 'Room ${room.roomNumber} • ' : ''}${room.floor == 'ground' ? 'Ground Floor' : room.floor}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.navigation_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
                tooltip: 'Direct Navigate',
                onPressed: () {
                  state.setNavigationDestination(room);
                  state.startNavigation();
                  context.go('/map');
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foregroundColor, size: 28),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: foregroundColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: foregroundColor.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
