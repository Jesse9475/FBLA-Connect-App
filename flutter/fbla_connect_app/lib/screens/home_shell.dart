import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/accessibility_settings.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import 'events_screen.dart';
import 'feed_screen.dart';
import 'hub_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

/// Root scaffold that hosts the five primary sections via a custom floating
/// glass bottom navigation bar.
///
/// Tab order: Feed · Messages · Events · Hub · Profile
///
/// On first mount it silently fetches the current user's profile so that
/// [UserState] is populated before any child screen renders.  A [setState]
/// call after the fetch ensures role-gated FABs appear without requiring a
/// manual refresh.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;

  // Screens are kept alive via IndexedStack so scroll position is preserved.
  static const List<Widget> _screens = [
    FeedScreen(),
    MessagesScreen(),
    EventsScreen(),
    HubScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserRole();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app comes back to the foreground, re-fetch the role so a
    // user who was just promoted to advisor in another session sees the
    // Create FAB without needing a fresh install.
    if (state == AppLifecycleState.resumed) {
      _loadUserRole();
    }
  }

  /// Fetch the logged-in user's profile from the backend and cache their role.
  /// Uses [addPostFrameCallback] to notify listeners so the notification never
  /// fires while a descendant widget is still in its build phase.
  Future<void> _loadUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await ApiService.instance.get<Map<String, dynamic>>(
        '/users/$userId',
        parser: (json) => (json['user'] as Map<String, dynamic>?) ?? {},
      );
      // Populate chapter/district first (no notification).
      UserState.instance.setChapter(
        data['chapter_id'] as String?,
        data['district_id'] as String?,
      );
      UserState.instance.setDisplayName(data['display_name'] as String?);
      // setRole calls notifyListeners — defer to avoid firing during build.
      final role = data['role'] as String? ?? 'member';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UserState.instance.setRole(role);
        if (mounted) setState(() {});
      });
    } catch (_) {
      // Network error or backend down — stay with default 'member' role.
    }
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;
    final navHeight = 68.0 + FblaSpacing.lg + safe;

    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      body: Stack(
        children: [
          // Content area (IndexedStack preserves scroll position)
          // Padding at bottom ensures content isn't hidden under nav
          Padding(
            padding: EdgeInsets.only(bottom: navHeight),
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          // Floating glass nav bar positioned at bottom
          _FloatingGlassNav(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            vsync: this,
          ),
        ],
      ),
    );
  }
}

// ── Nav bar data ────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.semanticLabel,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String semanticLabel;
}

const List<_NavItem> _navItems = [
  _NavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
    semanticLabel: 'Feed tab',
  ),
  _NavItem(
    icon: Icons.forum_outlined,
    selectedIcon: Icons.forum_rounded,
    label: 'Messages',
    semanticLabel: 'Messages tab',
  ),
  _NavItem(
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    label: 'Events',
    semanticLabel: 'Events tab',
  ),
  _NavItem(
    icon: Icons.auto_stories_outlined,
    selectedIcon: Icons.auto_stories,
    label: 'Hub',
    semanticLabel: 'Hub tab',
  ),
  _NavItem(
    icon: Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle_rounded,
    label: 'Profile',
    semanticLabel: 'Profile tab',
  ),
];

// ── Floating glass nav bar ──────────────────────────────────────────────────

class _FloatingGlassNav extends StatelessWidget {
  const _FloatingGlassNav({
    required this.currentIndex,
    required this.onTap,
    required this.vsync,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final TickerProvider vsync;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: FblaSpacing.lg + safe,
      left: FblaSpacing.lg,
      right: FblaSpacing.lg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FblaRadius.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: FblaColors.darkBg.withAlpha(204), // 0xCC opacity
              borderRadius: BorderRadius.circular(FblaRadius.full),
              border: Border.all(
                color: Colors.white.withAlpha(20),
                width: 1,
              ),
              boxShadow: FblaShadow.floatingNav,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_navItems.length, (i) {
                return _NavBarItem(
                  item: _navItems[i],
                  isSelected: i == currentIndex,
                  onTap: () => onTap(i),
                  vsync: vsync,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Individual nav item ─────────────────────────────────────────────────────
//
// Design: Active tab shows a gold indicator dot beneath the icon that SLIDES
// smoothly between tabs. Icons scale subtly on tap with press feedback.
// Emil Kowalski rules applied:
//   • Press scale 1.0→0.95 (100 ms strongEaseOut) — instant tactile feedback
//   • Icon swap: scale 0.85→1.0 + fade — never animate from scale(0)
//   • Active indicator: animated slide with smoothEaseOut (250 ms)
//   • HapticFeedback.selectionClick() on every tap

class _NavBarItem extends StatefulWidget {
  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.vsync,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final TickerProvider vsync;

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.item.semanticLabel,
      selected: widget.isSelected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _pressCtrl.forward().then((_) => _pressCtrl.reverse());
          widget.onTap();
        },
        child: ScaleTransition(
          scale: _pressScale,
          child: SizedBox(
            // WCAG 2.5.5: expand nav targets when Large Touch Targets is on.
            width: AccessibilitySettings.instance.largeTargets ? 64 : 56,
            height: AccessibilitySettings.instance.largeTargets ? 76 : 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with smooth transition
                SizedBox(
                  width: 40,
                  height: 32,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: FblaMotion.fast,
                      switchInCurve: FblaMotion.strongEaseOut,
                      switchOutCurve: FblaMotion.strongEaseOut,
                      // Scale from 0.85 + fade — never from scale(0).
                      transitionBuilder: (child, animation) {
                        final scaled = Tween<double>(
                          begin: 0.85,
                          end: 1.0,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: scaled, child: child),
                        );
                      },
                      child: Icon(
                        widget.isSelected
                            ? widget.item.selectedIcon
                            : widget.item.icon,
                        key: ValueKey<bool>(widget.isSelected),
                        size: 22,
                        color: widget.isSelected
                            ? FblaColors.primary
                            : FblaColors.darkTextTertiary,
                      ),
                    ),
                  ),
                ),
                // Active indicator dot below icon (shows only when selected)
                const SizedBox(height: 4),
                AnimatedOpacity(
                  opacity: widget.isSelected ? 1.0 : 0.0,
                  duration: FblaMotion.fast,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: FblaColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
