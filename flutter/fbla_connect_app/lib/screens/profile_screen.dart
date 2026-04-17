import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fbla_error_view.dart';
import 'friends_screen.dart';
import 'saved_screen.dart';
import 'settings_screen.dart';

/// User profile screen with account details and sign-out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Use the Supabase user ID from the active session.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // Fetch users + profiles in parallel and merge results.
      final results = await Future.wait([
        ApiService.instance.get<Map<String, dynamic>>(
          '/users/$userId',
          parser: (data) => (data['user'] as Map<String, dynamic>?) ?? {},
        ),
        ApiService.instance
            .get<Map<String, dynamic>>(
              '/profiles/$userId',
              parser: (data) =>
                  (data['profile'] as Map<String, dynamic>?) ?? {},
            )
            .catchError((_) => <String, dynamic>{}),
      ]);

      final userData = results[0];
      final profileData = results[1];

      // Keep UserState in sync so other screens see the correct role + chapter.
      final role = userData['role'] as String? ?? 'member';
      UserState.instance.setRole(role);
      UserState.instance.setChapter(
        userData['chapter_id'] as String?,
        userData['district_id'] as String?,
      );
      UserState.instance.setDisplayName(userData['display_name'] as String?);

      // Merge profiles data into the map (profiles fields take precedence for grade/school/bio).
      final merged = {...userData, ...profileData};

      // Resolve chapter_id → chapter name if present. Bound the lookup
      // with a 5s timeout so a slow Supabase round-trip can't block the
      // whole profile from rendering. We fall back to showing the raw
      // chapter id if anything goes wrong.
      final chapterId = merged['chapter_id'] as String?;
      if (chapterId != null && chapterId.isNotEmpty) {
        try {
          final chRes = await Supabase.instance.client
              .from('chapters')
              .select('name')
              .eq('id', chapterId)
              .limit(1)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));
          if (chRes != null) {
            merged['chapter_name'] = chRes['name'] as String? ?? chapterId;
          }
        } catch (_) {
          merged['chapter_name'] = chapterId;
        }
      }

      if (mounted) setState(() {
        _profile = merged;
        _loading = false;
      });
    } catch (_) {
      // Fall back gracefully to Supabase auth metadata if backend unavailable.
      if (mounted) setState(() {
        _profile = null;
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FblaColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FblaRadius.lg),
          side: BorderSide(color: FblaColors.darkOutline),
        ),
        title: Text(
          'Sign out?',
          style: TextStyle(
            color: FblaColors.darkTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'You will need to sign in again to access FBLA Connect.',
          style: TextStyle(color: FblaColors.darkTextSecond),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: FblaColors.darkTextSecond),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FblaColors.error,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _signingOut = true);

    // Always clear local state first — even if the network call fails the
    // user should never be stuck in a signed-in state on this device.
    UserState.instance.clear();
    await ApiService.instance.clearToken();

    try {
      // SignOutScope.local clears the Supabase session from device storage
      // and fires the signedOut auth event — AuthGate rebuilds to LoginScreen.
      //
      // IMPORTANT: Do NOT fire a second global sign-out in the background.
      // If the user signs back in before the background call completes,
      // the global sign-out fires another signedOut event and invalidates
      // the new session, kicking the user out immediately after sign-in.
      await Supabase.instance.client.auth.signOut(
        scope: SignOutScope.local,
      );
      // AuthGate handles navigation — no Navigator call needed here.
    } catch (_) {
      // signOut(local) failed but local state is already cleared above.
      // Force the AuthGate to re-evaluate by setting the token to null.
      // The stream may not have fired, so we need a fallback.
      if (mounted) {
        // The profile screen will be disposed when AuthGate rebuilds.
        // If that doesn't happen automatically, the user is at least
        // in a clean state (no token, no role).
        setState(() => _signingOut = false);
      }
    }
  }

  void _showEditProfileSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FblaColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
        side: BorderSide(color: FblaColors.darkOutline),
      ),
      builder: (ctx) => _EditProfileSheet(
        profile: _profile,
        displayName: _displayName,
        onSaved: _load,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────

  String get _displayName {
    // Prefer the display_name stored in the backend users table.
    final dn = _profile?['display_name'] as String?;
    if (dn != null && dn.isNotEmpty) return dn;

    // Fall back to first_name + last_name.
    if (_profile != null) {
      final fn = _profile!['first_name'] as String?;
      final ln = _profile!['last_name'] as String?;
      if (fn != null || ln != null) return '${fn ?? ''} ${ln ?? ''}'.trim();
    }

    // Last resort: Supabase auth metadata / email prefix.
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    final full = meta?['full_name'] as String? ?? meta?['name'] as String?;
    if (full != null && full.isNotEmpty) return full;
    return user?.email?.split('@').first ?? 'Member';
  }

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '—';

  String get _role {
    final r = _profile?['role'] as String?;
    if (r == null) return 'Member';
    return r[0].toUpperCase() + r.substring(1);
  }

  bool get _isAdvisor => (_profile?['role'] as String?)?.toLowerCase() == 'advisor';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      body: _loading
          ? const _ProfileSkeleton()
          : _error != null
              ? FblaErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FblaColors.secondary,
                  backgroundColor: FblaColors.darkSurface,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // ── Hero section ──────────────────────────────────
                      _ProfileHero(
                        displayName: _displayName,
                        role: _role,
                        profile: _profile,
                        isAdvisor: _isAdvisor,
                        onEditTap: () => _showEditProfileSheet(context),
                      ),

                      // ── Body content ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            FblaSpacing.md, FblaSpacing.lg, FblaSpacing.md, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Stats row ─────────────────────────────
                            _StatsRow(profile: _profile)
                                .animate()
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.06, end: 0, duration: 300.ms,
                                    curve: FblaMotion.easeOut),

                            const SizedBox(height: FblaSpacing.lg),

                            // ── Profile details card ──────────────────
                            _ProfileDetailsCard(
                              profile: _profile,
                              email: _email,
                              role: _role,
                            )
                                .animate(delay: 60.ms)
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.06, end: 0, duration: 300.ms,
                                    curve: FblaMotion.easeOut),

                            const SizedBox(height: FblaSpacing.lg),

                            // ── FBLA Info section ─────────────────────
                            if (_profile != null)
                              _FblaInfoCard(profile: _profile)
                                  .animate(delay: 100.ms)
                                  .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                  .slideY(begin: 0.06, end: 0, duration: 300.ms,
                                      curve: FblaMotion.easeOut),

                            const SizedBox(height: FblaSpacing.lg),

                            // ── Digital ID Card ──────────────────────
                            _DigitalIdCard(
                              userId:
                                  Supabase.instance.client.auth.currentUser?.id ??
                                      '',
                              displayName: _displayName,
                              role: _role,
                            )
                                .animate(delay: 140.ms)
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.06, end: 0, duration: 300.ms,
                                    curve: FblaMotion.easeOut),

                            const SizedBox(height: FblaSpacing.lg),

                            // ── Friends link ─────────────────────────
                            _FriendsLink(context: context)
                                .animate(delay: 160.ms)
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.06, end: 0, duration: 300.ms,
                                    curve: FblaMotion.easeOut),

                            const SizedBox(height: FblaSpacing.sm),

                            // ── Saved hub link ───────────────────────
                            _SavedLink(context: context)
                                .animate(delay: 165.ms)
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.06, end: 0, duration: 300.ms,
                                    curve: FblaMotion.easeOut),

                            const SizedBox(height: FblaSpacing.sm),

                            // ── Settings link ────────────────────────
                            _SettingsLink(context: context)
                                .animate(delay: 170.ms)
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.06, end: 0, duration: 300.ms,
                                    curve: FblaMotion.easeOut),

                            const SizedBox(height: FblaSpacing.lg),

                            // ── Sign out button ──────────────────────
                            OutlinedButton.icon(
                              onPressed:
                                  _signingOut ? null : _signOut,
                              icon: _signingOut
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                FblaColors.error),
                                      ),
                                    )
                                  : const Icon(Icons.logout),
                              label: const Text('Sign out'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FblaColors.error,
                                side: const BorderSide(
                                    color: FblaColors.error, width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                    vertical: FblaSpacing.md),
                              ),
                            ),

                            const SizedBox(height: 100), // space for floating nav
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero section — editorial precision with competitive achievement aesthetic
//
// Design: Large avatar with gold border (advisor only), display name in
// Josefin Sans for editorial impact, role badge with gold for advisor/blue
// for member, chapter info in Mulish.
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.role,
    required this.profile,
    required this.isAdvisor,
    required this.onEditTap,
  });

  final String displayName;
  final String role;
  final Map<String, dynamic>? profile;
  final bool isAdvisor;
  final VoidCallback onEditTap;

  /// A deterministic avatar color derived from the first character.
  Color get _avatarColor {
    final hue = (displayName.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.38).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final chapter = profile?['chapter_name'] as String?;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: FblaGradient.brand,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Watermark: giant faint "FBLA" in background ───────────────
          Positioned(
            right: -24,
            bottom: -16,
            child: Text(
              'FBLA',
              style: TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.w900,
                color: Colors.white.withAlpha(7),
                letterSpacing: -4,
              ),
            ),
          ),

          // ── Ambient highlight — top right ─────────────────────────────
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x20FFFFFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Small white dot accent ────────────────────────────────────
          Positioned(
            top: 56,
            right: 80,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(60),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FblaSpacing.lg,
                FblaSpacing.md,
                FblaSpacing.md,
                FblaSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Edit button — top-right aligned
                  Align(
                    alignment: Alignment.topRight,
                    child: Semantics(
                      label: 'Edit profile',
                      button: true,
                      child: GestureDetector(
                        onTap: onEditTap,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(FblaRadius.full),
                                border: Border.all(
                                  color: Colors.white.withAlpha(35),
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: FblaSpacing.md),

                  // ── Left-aligned: avatar + name/role ─────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with double-ring (gold outer for advisor, standard inner)
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isAdvisor
                              ? FblaGradient.goldShimmer
                              : LinearGradient(
                                  colors: [
                                    Colors.white.withAlpha(40),
                                    Colors.white.withAlpha(20),
                                  ],
                                ),
                          boxShadow: isAdvisor
                              ? FblaShadow.goldGlow
                              : [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(60),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _avatarColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: FblaSpacing.md),

                      // Name + role + chapter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name in Josefin Sans (display)
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontFamily: 'Josefin Sans',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Role badge — gold for advisor, blue for member
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isAdvisor
                                    ? FblaColors.secondary.withAlpha(40)
                                    : FblaColors.primary.withAlpha(40),
                                borderRadius:
                                    BorderRadius.circular(FblaRadius.full),
                                border: Border.all(
                                  color: isAdvisor
                                      ? FblaColors.secondary
                                      : FblaColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: isAdvisor
                                      ? FblaColors.secondary
                                      : FblaColors.primary,
                                ),
                              ),
                            ),

                            // Chapter name — right of role badge
                            if (chapter != null && chapter.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                chapter,
                                style: TextStyle(
                                  fontFamily: 'Mulish',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withAlpha(180),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row: Points / Awards / Events with count-up animation
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final points = (profile?['points'] as int?) ?? 0;
    final awards = (profile?['awards_count'] as int?) ?? 0;
    final events = (profile?['events_attended'] as int?) ?? 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatCard(count: points, label: 'Points', color: FblaColors.secondary),
          const SizedBox(width: FblaSpacing.sm),
          _StatCard(count: awards, label: 'Awards', color: FblaColors.primary),
          const SizedBox(width: FblaSpacing.sm),
          _StatCard(count: events, label: 'Events', color: const Color(0xFF22C55E)),
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.count, required this.label, this.color = FblaColors.secondary});
  final int count;
  final String label;
  final Color color;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _countCtrl;
  late Animation<int> _countAnim;

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _countAnim = IntTween(begin: 0, end: widget.count).animate(
      CurvedAnimation(parent: _countCtrl, curve: Curves.easeOut),
    );
    _countCtrl.forward();
  }

  @override
  void didUpdateWidget(_StatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _countAnim = IntTween(begin: oldWidget.count, end: widget.count).animate(
        CurvedAnimation(parent: _countCtrl, curve: Curves.easeOut),
      );
      _countCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FblaRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.sm,
            vertical: FblaSpacing.md,
          ),
          decoration: BoxDecoration(
            color: FblaColors.darkSurfaceHigh,
            border: Border.all(color: FblaColors.darkOutline, width: 1),
            boxShadow: FblaShadow.glass,
          ),
          // Colored accent line at the top
          foregroundDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: widget.color.withAlpha(140), width: 2.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _countAnim,
                builder: (context, _) {
                  return Text(
                    '${_countAnim.value}',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: FblaColors.darkTextSecond,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile details card with bio, grade, school, chapter
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({
    required this.profile,
    required this.email,
    required this.role,
  });

  final Map<String, dynamic>? profile;
  final String email;
  final String role;

  @override
  Widget build(BuildContext context) {
    final bio = profile?['bio'] as String?;
    // Role-aware: advisors and admins never show a grade — that's a student-
    // only field. Prevents the "why does reyansh.siotia show 11th grade?" bug
    // caused by stale/defaulted data on non-student profiles.
    final isStudent = role.toLowerCase() == 'member' || role.toLowerCase() == 'student';
    final rawGrade = profile?['grade'] as String?;
    final grade = isStudent ? rawGrade : null;
    final school = profile?['school'] as String?;
    final chapter = profile?['chapter_name'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('PROFILE DETAILS'),
        const SizedBox(height: FblaSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: FblaColors.darkSurfaceHigh,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: Border.all(color: FblaColors.darkOutline, width: 1),
            boxShadow: FblaShadow.glass,
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              if (bio != null && bio.isNotEmpty) ...[
                _DetailRow(
                  icon: Icons.notes_outlined,
                  label: 'Bio',
                  value: bio,
                ),
              ],
              if (grade != null && grade.isNotEmpty) ...[
                if (bio != null && bio.isNotEmpty)
                  Divider(height: 1, color: FblaColors.darkOutline),
                _DetailRow(
                  icon: Icons.school_outlined,
                  label: 'Grade',
                  value: grade,
                ),
              ],
              if (school != null && school.isNotEmpty) ...[
                if ((bio != null && bio.isNotEmpty) ||
                    (grade != null && grade.isNotEmpty))
                  Divider(height: 1, color: FblaColors.darkOutline),
                _DetailRow(
                  icon: Icons.account_balance_outlined,
                  label: 'School',
                  value: school,
                ),
              ],
              if (chapter != null && chapter.isNotEmpty) ...[
                if ((bio != null && bio.isNotEmpty) ||
                    (grade != null && grade.isNotEmpty) ||
                    (school != null && school.isNotEmpty))
                  Divider(height: 1, color: FblaColors.darkOutline),
                _DetailRow(
                  icon: Icons.group_outlined,
                  label: 'Chapter',
                  value: chapter,
                ),
              ],
              Divider(height: 1, color: FblaColors.darkOutline),
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
              Divider(height: 1, color: FblaColors.darkOutline),
              _DetailRow(
                icon: Icons.badge_outlined,
                label: 'Role',
                value: role,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FblaColors.secondary),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: FblaColors.darkTextSecond,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Mulish',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FBLA Info section
// ─────────────────────────────────────────────────────────────────────────────

class _FblaInfoCard extends StatelessWidget {
  const _FblaInfoCard({required this.profile});

  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final chapterName = profile?['chapter_name'] as String?;
    final memberSince = profile?['created_at'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('FBLA MEMBERSHIP'),
        const SizedBox(height: FblaSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: FblaColors.darkSurfaceHigh,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: Border.all(color: FblaColors.darkOutline, width: 1),
            boxShadow: FblaShadow.glass,
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              if (chapterName != null && chapterName.isNotEmpty)
                _DetailRow(
                  icon: Icons.group_outlined,
                  label: 'Chapter',
                  value: chapterName,
                ),
              if (memberSince != null && memberSince.isNotEmpty) ...[
                if (chapterName != null && chapterName.isNotEmpty)
                  Divider(height: 1, color: FblaColors.darkOutline),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member Since',
                  value: _formatDate(memberSince),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Digital ID Card — the showpiece with premium ID badge feel
// ─────────────────────────────────────────────────────────────────────────────

class _DigitalIdCard extends StatefulWidget {
  const _DigitalIdCard({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String role;

  @override
  State<_DigitalIdCard> createState() => _DigitalIdCardState();
}

class _DigitalIdCardState extends State<_DigitalIdCard>
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _showFullQr(BuildContext context) {
    // Use a fullscreen dialog route instead of a bottom sheet — the
    // sheet was capped to its content height (`MainAxisSize.min`),
    // making the QR ~360 pt at most. A real fullscreen route lets us
    // size the QR to the SHORT edge of the screen so it dominates the
    // display and is scannable from across a hall.
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenQr(
          displayName: widget.displayName,
          userId: widget.userId,
          vCard: _buildVCard(
            displayName: widget.displayName,
            role: widget.role,
            userId: widget.userId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('DIGITAL ID'),
        const SizedBox(height: FblaSpacing.sm),
        ScaleTransition(
          scale: _pressScale,
          child: GestureDetector(
            onTapDown: (_) {
              _pressCtrl.forward();
            },
            onTapUp: (_) {
              _pressCtrl.reverse();
              _showFullQr(context);
            },
            onTapCancel: () => _pressCtrl.reverse(),
            child: Container(
              decoration: BoxDecoration(
                color: FblaColors.darkSurfaceHigh,
                borderRadius: BorderRadius.circular(FblaRadius.md),
                border: Border.all(color: FblaColors.darkOutline, width: 1),
                boxShadow: FblaShadow.glass,
              ),
              child: Padding(
                padding: const EdgeInsets.all(FblaSpacing.md),
                child: Row(
                  children: [
                    // Mini QR preview
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(FblaRadius.sm),
                        border: Border.all(color: FblaColors.darkOutline),
                      ),
                      child: _QrCodeView(
                        data: _buildVCard(
                          displayName: widget.displayName,
                          role: widget.role,
                          userId: widget.userId.isNotEmpty
                              ? widget.userId
                              : 'demo',
                        ),
                        size: 60,
                        foreground: FblaColors.primaryDark,
                        accent: FblaColors.primary,
                      ),
                    ),
                    const SizedBox(width: FblaSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_2,
                                  size: 16, color: FblaColors.secondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Digital ID & QR Code',
                                  style: TextStyle(
                                    fontFamily: 'Josefin Sans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: FblaColors.darkTextPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan to connect at FBLA events — no searching required.',
                            style: TextStyle(
                              fontFamily: 'Mulish',
                              fontSize: 12,
                              color: FblaColors.darkTextSecond,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: FblaColors.secondary.withAlpha(20),
                              borderRadius:
                                  BorderRadius.circular(FblaRadius.full),
                            ),
                            child: const Text(
                              'Tap to expand',
                              style: TextStyle(
                                fontFamily: 'Mulish',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: FblaColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: FblaColors.secondary, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friends link — opens the Friends screen with three tabs (Friends,
// Requests, Find People).
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsLink extends StatelessWidget {
  const _FriendsLink({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const FriendsScreen(),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FblaColors.darkSurfaceHigh,
          borderRadius: BorderRadius.circular(FblaRadius.md),
          border: Border.all(color: FblaColors.darkOutline, width: 1),
          boxShadow: FblaShadow.glass,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.md,
            vertical: FblaSpacing.md,
          ),
          child: Row(
            children: [
              const Icon(Icons.group_outlined,
                  size: 20, color: FblaColors.secondary),
              const SizedBox(width: FblaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Friends',
                      style: TextStyle(
                        fontFamily: 'Josefin Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FblaColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add friends, accept requests, find members',
                      style: TextStyle(
                        fontFamily: 'Mulish',
                        fontSize: 12,
                        color: FblaColors.darkTextSecond,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: FblaColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved hub link
// ─────────────────────────────────────────────────────────────────────────────

class _SavedLink extends StatelessWidget {
  const _SavedLink({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const SavedScreen()),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FblaColors.darkSurfaceHigh,
          borderRadius: BorderRadius.circular(FblaRadius.md),
          border: Border.all(color: FblaColors.darkOutline, width: 1),
          boxShadow: FblaShadow.glass,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.md,
            vertical: FblaSpacing.md,
          ),
          child: Row(
            children: [
              const Icon(Icons.bookmark_outline,
                  size: 20, color: FblaColors.secondary),
              const SizedBox(width: FblaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved',
                      style: TextStyle(
                        fontFamily: 'Josefin Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FblaColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bookmarked events, posts, and competitive events',
                      style: TextStyle(
                        fontFamily: 'Mulish',
                        fontSize: 12,
                        color: FblaColors.darkTextSecond,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: FblaColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings link
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const SettingsScreen(),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FblaColors.darkSurfaceHigh,
          borderRadius: BorderRadius.circular(FblaRadius.md),
          border: Border.all(color: FblaColors.darkOutline, width: 1),
          boxShadow: FblaShadow.glass,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.md,
            vertical: FblaSpacing.md,
          ),
          child: Row(
            children: [
              const Icon(Icons.settings_outlined,
                  size: 20, color: FblaColors.secondary),
              const SizedBox(width: FblaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'Josefin Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FblaColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Accessibility, theme, preferences',
                      style: TextStyle(
                        fontFamily: 'Mulish',
                        fontSize: 12,
                        color: FblaColors.darkTextSecond,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: FblaColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label helper — industrial tick + Josefin Sans
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            left: 4, bottom: FblaSpacing.sm, top: FblaSpacing.md),
        child: Row(
          children: [
            // Industrial tick
            Container(
              width: 2,
              height: 12,
              decoration: BoxDecoration(
                color: FblaColors.secondary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              text.toUpperCase(),
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FblaColors.secondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// vCard builder — payload that actually does something when scanned
// ─────────────────────────────────────────────────────────────────────────────
//
// A custom URL scheme like `fblaconnect://member/<id>` is invisible to iOS
// Camera and Google Lens, so scanning the previous QR led nowhere. A vCard
// 3.0 payload is recognized natively by every smartphone camera and pops a
// "Add to Contacts" sheet with the member's name, role, and ID — which
// actually delivers on the "scan to connect at FBLA events" promise without
// requiring any web infrastructure.
//
// We also embed a NOTE field with the FBLA Connect member ID so the in-app
// scanner (when added) can match the contact back to a profile.
String _buildVCard({
  required String displayName,
  required String role,
  required String userId,
}) {
  // vCard fields are CRLF-delimited per RFC 6350. Escape commas, semicolons,
  // and backslashes in any user-controlled string so the payload stays
  // well-formed even with unusual names.
  String esc(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\n', '\\n');

  final fn = esc(displayName.trim().isEmpty ? 'FBLA Member' : displayName);
  final title = esc(role.trim().isEmpty ? 'FBLA Connect Member' : role);
  final note = esc('FBLA Connect ID: $userId');

  return [
    'BEGIN:VCARD',
    'VERSION:3.0',
    'FN:$fn',
    'ORG:FBLA Connect',
    'TITLE:$title',
    'NOTE:$note',
    'END:VCARD',
  ].join('\r\n');
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom QR code view using qr_flutter package
// ─────────────────────────────────────────────────────────────────────────────

class _QrCodeView extends StatelessWidget {
  const _QrCodeView({
    required this.data,
    required this.size,
    required this.foreground,
    required this.accent,
  });

  final String data;
  final double size;
  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // iOS's Camera/Wallet scanners require very high contrast to decode QR
    // codes — a navy-on-white code (which we previously rendered) drops
    // below the perceived-luminance threshold and surfaces "No usable data
    // found". We force pure black on white here, which is the canonical
    // QR colour pair, and remove the multi-tone eye treatment that also
    // confused some scanners.
    //
    // We also pad the widget by a quiet zone equal to ~4 module widths,
    // which the QR spec requires for reliable detection.
    final quietZone = (size * 0.06).clamp(8.0, 24.0);

    return Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(quietZone),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size - quietZone * 2,
        gapless: true,
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        backgroundColor: Colors.white,
        // Medium error correction is the standard sweet-spot for short
        // payloads — High creates denser modules that scan WORSE at
        // small physical sizes (which is exactly when this code is
        // rendered on a phone screen).
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen Digital ID — fills the entire visible area
// ─────────────────────────────────────────────────────────────────────────────
//
// Replaces the previous bottom-sheet QR view, which was capped to its
// content's intrinsic height and never got bigger than ~360 pt regardless
// of screen size. This page sizes the QR to the SHORT edge of the device
// so it dominates the screen (≈90% on phones, ≈75% on tablets) and is
// scannable from across an event hall.

class _FullScreenQr extends StatelessWidget {
  const _FullScreenQr({
    required this.displayName,
    required this.userId,
    required this.vCard,
  });

  final String displayName;
  final String userId;
  final String vCard;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FblaColors.darkBg : FblaColors.background;
    final surface = isDark ? FblaColors.darkSurface : Colors.white;
    final textPrim =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;
    final textSec =
        isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary;
    final outline = isDark ? FblaColors.darkOutline : FblaColors.outline;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textPrim),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Digital Member ID',
          style: TextStyle(
            fontFamily: 'Josefin Sans',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textPrim,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use the SHORT edge so the QR is square AND huge regardless
            // of orientation. Reserve a small slice for header/footer so
            // text isn't cropped on landscape phones.
            final shortEdge =
                constraints.maxWidth < constraints.maxHeight - 200
                    ? constraints.maxWidth
                    : constraints.maxHeight - 200;
            final qrSize = (shortEdge - 40).clamp(260.0, 720.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Scan with any phone camera',
                    style: TextStyle(
                      fontFamily: 'Mulish',
                      fontSize: 14,
                      color: textSec,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(FblaSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(FblaRadius.lg),
                      border: Border.all(color: outline, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 80 : 30),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _QrCodeView(
                      data: vCard,
                      size: qrSize,
                      foreground: FblaColors.primaryDark,
                      accent: FblaColors.primary,
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.xl),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FblaSpacing.lg,
                      vertical: FblaSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      border: Border.all(color: outline, width: 1),
                    ),
                    child: Column(
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontFamily: 'Josefin Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: textPrim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userId.length > 8
                              ? userId.substring(0, 8).toUpperCase()
                              : userId.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            color: textSec,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileSkeleton extends StatefulWidget {
  const _ProfileSkeleton();
  @override
  State<_ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<_ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = Color.lerp(
          FblaColors.darkOutline,
          FblaColors.darkSurfaceHigh,
          _anim.value,
        )!;

        Widget box(double w, double h, {double radius = FblaRadius.sm}) =>
            Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: shimmer,
                borderRadius: BorderRadius.circular(radius),
              ),
            );

        return ListView(
          padding: const EdgeInsets.all(FblaSpacing.md),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Hero section skeleton
            Container(
              decoration: const BoxDecoration(
                gradient: FblaGradient.brand,
              ),
              padding: const EdgeInsets.all(FblaSpacing.lg),
              child: Column(
                children: [
                  box(36, 36, radius: FblaRadius.full),
                  const SizedBox(height: FblaSpacing.md),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: shimmer,
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.md),
                  box(140, 22),
                  const SizedBox(height: FblaSpacing.sm),
                  box(80, 16, radius: FblaRadius.full),
                ],
              ),
            ),
            const SizedBox(height: FblaSpacing.lg),

            // Stats skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: FblaColors.darkSurfaceHigh,
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      border: Border.all(color: FblaColors.darkOutline),
                    ),
                    child: Center(child: box(40, 40)),
                  ),
                ),
                const SizedBox(width: FblaSpacing.sm),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: FblaColors.darkSurfaceHigh,
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      border: Border.all(color: FblaColors.darkOutline),
                    ),
                    child: Center(child: box(40, 40)),
                  ),
                ),
                const SizedBox(width: FblaSpacing.sm),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: FblaColors.darkSurfaceHigh,
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      border: Border.all(color: FblaColors.darkOutline),
                    ),
                    child: Center(child: box(40, 40)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FblaSpacing.lg),

            // Profile details skeleton
            box(56, 10),
            const SizedBox(height: FblaSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: FblaColors.darkSurfaceHigh,
                borderRadius: BorderRadius.circular(FblaRadius.md),
                border: Border.all(color: FblaColors.darkOutline),
              ),
              child: Column(
                children: List.generate(3, (i) => Column(
                  children: [
                    if (i > 0)
                      Divider(
                          height: 1, color: FblaColors.darkOutline),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FblaSpacing.md,
                        vertical: FblaSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          box(20, 20, radius: 4),
                          const SizedBox(width: FblaSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              box(48, 10),
                              const SizedBox(height: 4),
                              box(120, 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                )),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile Sheet — grade dropdown + school autocomplete from chapters DB
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.profile,
    required this.displayName,
    required this.onSaved,
  });

  final Map<String, dynamic>? profile;
  final String displayName;
  final VoidCallback onSaved;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _bioCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bioCtrl =
        TextEditingController(text: widget.profile?['bio'] as String? ?? '');
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Only bio is editable after onboarding. Grade and school are fixed
      // at signup so they can't drift out of sync with chapter rosters.
      await ApiService.instance.patch(
        '/profiles/$userId',
        body: {
          'bio': _bioCtrl.text.trim(),
        },
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Advisors/admins don't have a grade — hide the row entirely for them
    // and for any profile where grade wasn't set during onboarding.
    final isAdvisor = UserState.instance.isAdvisorOrAdmin;
    final grade = widget.profile?['grade'] as String?;
    final school = widget.profile?['school'] as String?;
    final showGrade = !isAdvisor && grade != null && grade.isNotEmpty;
    final showSchool = school != null && school.isNotEmpty;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: FblaSpacing.lg,
          right: FblaSpacing.lg,
          top: FblaSpacing.lg,
          bottom: FblaSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FblaColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: FblaSpacing.xs),
            Text(
              'Only your bio can be edited here. Grade and school were set during onboarding.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: FblaColors.darkTextSecond,
                height: 1.35,
              ),
            ),
            const SizedBox(height: FblaSpacing.lg),

            // Bio — the only editable field
            TextField(
              controller: _bioCtrl,
              minLines: 3,
              maxLines: 4,
              maxLength: 256,
              style: TextStyle(color: FblaColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself...',
                filled: true,
                fillColor: FblaColors.darkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                  borderSide: BorderSide(color: FblaColors.darkOutline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                  borderSide: BorderSide(color: FblaColors.darkOutline),
                ),
              ),
            ),
            const SizedBox(height: FblaSpacing.lg),

            // Read-only info: grade + school. Rendered as locked rows so users
            // see what's on file without being able to mutate it.
            if (showGrade)
              _LockedInfoRow(
                icon: Icons.school_outlined,
                label: 'Grade',
                value: grade,
              ),
            if (showGrade && showSchool) const SizedBox(height: FblaSpacing.sm),
            if (showSchool)
              _LockedInfoRow(
                icon: Icons.apartment_outlined,
                label: 'School',
                value: school,
              ),
            if (showGrade || showSchool) const SizedBox(height: FblaSpacing.lg),

            // Save button
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A read-only information row used in the Edit Profile sheet for fields
// that were locked-in at onboarding (grade, school). Visually distinct
// from editable fields via a subtle lock affordance.
class _LockedInfoRow extends StatelessWidget {
  const _LockedInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: FblaColors.darkSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(FblaRadius.md),
        border: Border.all(
          color: FblaColors.darkOutline.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: FblaColors.darkTextSecond),
          const SizedBox(width: FblaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: FblaColors.darkTextSecond,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: FblaColors.darkTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline,
            size: 14,
            color: FblaColors.darkTextSecond.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}
