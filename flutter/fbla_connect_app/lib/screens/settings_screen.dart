import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/accessibility_settings.dart';
import '../services/password_policy.dart';
import '../theme/app_theme.dart';
import '../widgets/fbla_app_bar.dart';
import '../widgets/password_helpers.dart';

/// App Settings — reachable via Profile → Settings.
/// Premium "Contender" aesthetic with smooth animations, grouped sections,
/// and gold accents on active toggles.
///
/// Sections:
///   Account:        Change Password, Email Preferences, Forgot Password
///   Notifications:  Push / Chapter Announcements toggles
///   Accessibility:  High Contrast Dark, Color-Blind, Headings, Large Targets
///   Event Colors:   Legend for status chips
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _a11y = AccessibilitySettings.instance;

  // Notification prefs — persisted in secure storage.
  static const _storage = FlutterSecureStorage();
  static const _kPushNotifs       = 'notif_push';
  static const _kChapterNotifs    = 'notif_chapter';

  bool _pushNotifs          = true;
  bool _chapterAnnouncements = true;

  @override
  void initState() {
    super.initState();
    _a11y.addListener(_rebuild);
    _loadNotifPrefs();
  }

  @override
  void dispose() {
    _a11y.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNotifPrefs() async {
    try {
      final push    = await _storage.read(key: _kPushNotifs);
      final chapter = await _storage.read(key: _kChapterNotifs);
      if (mounted) {
        setState(() {
          _pushNotifs           = push    != 'false'; // default true
          _chapterAnnouncements = chapter != 'false'; // default true
        });
      }
    } catch (_) {
      // keep defaults on storage error
    }
  }

  Future<void> _setPushNotifs(bool v) async {
    setState(() => _pushNotifs = v);
    try { await _storage.write(key: _kPushNotifs, value: v.toString()); } catch (_) {}
  }

  Future<void> _setChapterAnnouncements(bool v) async {
    setState(() => _chapterAnnouncements = v);
    try { await _storage.write(key: _kChapterNotifs, value: v.toString()); } catch (_) {}
  }

  // ── Accessibility toggle helpers ─────────────────────────────────────────────
  void _toggleDark(bool v)         => _a11y.setHighContrastDark(v).ignore();
  void _toggleColorBlind(bool v)   => _a11y.setColorBlindFriendly(v).ignore();
  void _toggleHeadings(bool v)     => _a11y.setLogicalHeadings(v).ignore();
  void _toggleLargeTargets(bool v) => _a11y.setLargeTargets(v).ignore();
  void _setAppearance(String v)    => _a11y.setAppearance(v).ignore();
  void _setColorBlindType(String v) => _a11y.setColorBlindType(v).ignore();

  // ── Change password ──────────────────────────────────────────────────────────
  void _showChangePasswordSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  // ── Email preferences ────────────────────────────────────────────────────────
  void _showEmailPrefsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EmailPrefsSheet(),
    );
  }

  // ── Forgot password (same flow as login screen) ──────────────────────────────
  void _showForgotPasswordSheet() {
    final user = Supabase.instance.client.auth.currentUser;
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    bool sending = false;
    String? result;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setInner) {
          final cs = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(FblaRadius.xl)),
                boxShadow: FblaShadow.overlay,
              ),
              padding: const EdgeInsets.fromLTRB(
                  FblaSpacing.xl, FblaSpacing.lg, FblaSpacing.xl, FblaSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(FblaRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.lg),
                  Text('Reset your password',
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800)),
                  const SizedBox(height: FblaSpacing.xs),
                  Text("Enter your email and we'll send a reset link.",
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  const SizedBox(height: FblaSpacing.lg),
                  if (result != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FblaSpacing.md),
                      child: Text(
                        result!,
                        style: TextStyle(
                          color: result!.startsWith('✓')
                              ? FblaColors.success
                              : FblaColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: FblaSpacing.lg),
                  ElevatedButton(
                    onPressed: sending || result?.startsWith('✓') == true
                        ? null
                        : () async {
                            final email = emailCtrl.text.trim();
                            if (email.isEmpty) return;
                            setInner(() => sending = true);
                            try {
                              await Supabase.instance.client.auth
                                  .resetPasswordForEmail(email);
                              setInner(() {
                                result = '✓ Check your email for the reset link.';
                                sending = false;
                              });
                            } on AuthException catch (e) {
                              setInner(() {
                                result = e.message;
                                sending = false;
                              });
                            } catch (e) {
                              setInner(() {
                                result = 'Something went wrong. Try again.';
                                sending = false;
                              });
                            }
                          },
                    child: sending
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Send reset link'),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const FblaAppBar(title: Text('Settings')),
      backgroundColor: FblaColors.darkBg,
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.md, vertical: FblaSpacing.md),
        children: [

          // ── Account ────────────────────────────────────────────────────────
          _SectionLabel('Account')
              .animate()
              .fadeIn(duration: FblaMotion.fast)
              .slideX(begin: -0.1, end: 0, duration: FblaMotion.fast, curve: FblaMotion.easeOut),
          _Card(children: [
            _ActionTile(
              icon: Icons.lock_outline,
              iconColor: FblaColors.primary,
              title: 'Change Password',
              onTap: _showChangePasswordSheet,
            ),
            const _Divider(),
            _ActionTile(
              icon: Icons.email_outlined,
              iconColor: FblaColors.primary,
              title: 'Email Preferences',
              onTap: _showEmailPrefsSheet,
            ),
            const _Divider(),
            _ActionTile(
              icon: Icons.key_outlined,
              iconColor: FblaColors.primaryLight,
              title: 'Forgot Password',
              subtitle: 'Send a reset link to your email',
              onTap: _showForgotPasswordSheet,
            ),
          ]),

          const SizedBox(height: FblaSpacing.lg),

          // ── Notifications ──────────────────────────────────────────────────
          _SectionLabel('Notifications'),
          _Card(children: [
            _Toggle(
              icon: Icons.notifications_outlined,
              iconColor: FblaColors.secondary,
              title: 'Push Notifications',
              subtitle: 'Receive alerts for new announcements and events.',
              value: _pushNotifs,
              onChanged: _setPushNotifs,
            ),
            const _Divider(),
            _Toggle(
              icon: Icons.campaign_outlined,
              iconColor: FblaColors.secondary,
              title: 'Chapter Announcements',
              subtitle: 'Notify when your advisor posts to the chapter.',
              value: _chapterAnnouncements,
              onChanged: _setChapterAnnouncements,
            ),
          ]),

          const SizedBox(height: FblaSpacing.lg),

          // ── Accessibility ──────────────────────────────────────────────────
          // The three former toggles (color-blind friendly, logical heading
          // structure, large touch targets) are now baked-in defaults — see
          // the "Built-in accessibility" panel below. The color-blind
          // SIMULATION (selectable type that applies a global ColorFilter)
          // is still user-controllable and lives directly under Appearance
          // because both controls modify global rendering.
          _SectionLabel('Accessibility'),
          _Card(children: [
            _AppearanceRow(
              value: _a11y.appearance,
              onChanged: _setAppearance,
            ),
            const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            _ColorBlindRow(
              value: _a11y.colorBlindType,
              onChanged: _setColorBlindType,
            ),
          ]),

          const SizedBox(height: FblaSpacing.lg),

          // ── Event Status Color Legend ──────────────────────────────────────
          _SectionLabel('Event Status Colors'),
          _Card(children: [
            Padding(
              padding: const EdgeInsets.all(FblaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visual cues surface urgency at a glance on event cards.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withAlpha(160),
                        ),
                  ),
                  const SizedBox(height: FblaSpacing.md),
                  Wrap(
                    spacing: FblaSpacing.sm,
                    runSpacing: FblaSpacing.sm,
                    children: const [
                      _StatusChip('Registered',  Color(0xFF16A34A), Colors.white),
                      _StatusChip('8 Days Away', Color(0xFFF59E0B), Color(0xFF1A1A1A)),
                      _StatusChip('Deadline',    Color(0xFFDC2626), Colors.white),
                      _StatusChip('Past',        Color(0xFF94A3B8), Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: FblaSpacing.lg),

          // ── Built-in accessibility — passive list, no toggles ────────────
          _SectionLabel('Built-in Accessibility'),
          _Card(children: [
            Padding(
              padding: const EdgeInsets.all(FblaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'These accessibility features are always on across the app — no setup needed.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withAlpha(160),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: FblaSpacing.md),
                  _BuiltInA11yRow(
                    icon: Icons.palette_outlined,
                    title: 'Color-blind friendly',
                    subtitle:
                        'Status badges always pair color with a text label.',
                  ),
                  const SizedBox(height: FblaSpacing.sm),
                  _BuiltInA11yRow(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Logical heading structure',
                    subtitle:
                        'Events and posts are grouped under semantic headers for screen readers.',
                  ),
                  const SizedBox(height: FblaSpacing.sm),
                  _BuiltInA11yRow(
                    icon: Icons.touch_app_outlined,
                    title: 'Large touch targets',
                    subtitle:
                        'All interactive elements meet the WCAG 2.5.5 minimum (≥ 48 dp).',
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: FblaSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── Built-in accessibility row — visual-only, no toggle ──────────────────────

class _BuiltInA11yRow extends StatelessWidget {
  const _BuiltInA11yRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: FblaColors.success.withAlpha(28),
            borderRadius: BorderRadius.circular(FblaRadius.sm),
          ),
          child: Icon(icon, size: 16, color: FblaColors.success),
        ),
        const SizedBox(width: FblaSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: FblaColors.success.withAlpha(30),
                      borderRadius:
                          BorderRadius.circular(FblaRadius.full),
                    ),
                    child: const Text(
                      'ON',
                      style: TextStyle(
                        fontFamily: 'Mulish',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: FblaColors.success,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withAlpha(160),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Change Password sheet ─────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  bool _success = false;
  // Focus nodes for new + confirm password fields — drive the padlock
  // mascot's "peeking" state when each field has focus.
  final FocusNode _newPassFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _newPassFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _confirmFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    _newPassFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassCtrl.text),
      );
      if (mounted) setState(() { _success = true; _loading = false; });
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Something went wrong. Try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(FblaRadius.xl)),
          boxShadow: FblaShadow.overlay,
        ),
        padding: const EdgeInsets.fromLTRB(
            FblaSpacing.xl, FblaSpacing.lg, FblaSpacing.xl, FblaSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(FblaRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: FblaSpacing.lg),

              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: FblaColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(FblaRadius.sm),
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: FblaColors.primary, size: 22),
                  ),
                  const SizedBox(width: FblaSpacing.md),
                  Text('Change Password',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800)),
                ],
              ),

              const SizedBox(height: FblaSpacing.lg),

              if (_success) ...[
                Container(
                  padding: const EdgeInsets.all(FblaSpacing.md),
                  decoration: BoxDecoration(
                    color: FblaColors.success.withAlpha(18), // dark-mode safe
                    borderRadius: BorderRadius.circular(FblaRadius.md),
                    border: Border.all(
                        color: FblaColors.success.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: FblaColors.success, size: 20),
                      const SizedBox(width: FblaSpacing.sm),
                      const Expanded(
                        child: Text(
                          'Password updated successfully!',
                          style: TextStyle(
                              color: FblaColors.success,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FblaSpacing.lg),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ] else ...[
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(FblaSpacing.sm),
                    decoration: BoxDecoration(
                      color: FblaColors.error.withAlpha(18), // dark-mode safe
                      borderRadius: BorderRadius.circular(FblaRadius.sm),
                      border: Border.all(
                          color: FblaColors.error.withAlpha(50)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: FblaColors.error)),
                  ),
                  const SizedBox(height: FblaSpacing.md),
                ],

                // New password — animated padlock lives in the prefix
                // position so the lock state hugs the field itself.
                TextFormField(
                  controller: _newPassCtrl,
                  focusNode: _newPassFocus,
                  obscureText: _obscureNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 6),
                      child: ShyEyesMascot(
                        locked: passwordMeetsPolicy(_newPassCtrl.text),
                        focused: _newPassFocus.hasFocus,
                        size: 30,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 48, minHeight: 48),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      tooltip: _obscureNew ? 'Show password' : 'Hide password',
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: validatePassword,
                ),
                const SizedBox(height: FblaSpacing.md),

                // Confirm password
                TextFormField(
                  controller: _confirmCtrl,
                  focusNode: _confirmFocus,
                  obscureText: _obscureConfirm,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 6),
                      child: ShyEyesMascot(
                        locked: _confirmCtrl.text.isNotEmpty &&
                            _confirmCtrl.text == _newPassCtrl.text &&
                            passwordMeetsPolicy(_newPassCtrl.text),
                        focused: _confirmFocus.hasFocus,
                        size: 30,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                        minWidth: 48, minHeight: 48),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      tooltip:
                          _obscureConfirm ? 'Show password' : 'Hide password',
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _newPassCtrl.text) return 'Passwords do not match.';
                    return null;
                  },
                ),
                // Live checklist lives below the confirm field: all rules
                // plus a "Passwords match" row.
                PasswordRequirementsChecklist(
                  value: _newPassCtrl.text,
                  confirmValue: _confirmCtrl.text,
                ),
                const SizedBox(height: FblaSpacing.lg),

                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Update Password'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Email Preferences sheet ───────────────────────────────────────────────────

class _EmailPrefsSheet extends StatefulWidget {
  const _EmailPrefsSheet();

  @override
  State<_EmailPrefsSheet> createState() => _EmailPrefsSheetState();
}

class _EmailPrefsSheetState extends State<_EmailPrefsSheet> {
  bool _announcements = true;
  bool _eventReminders = true;
  bool _chapterUpdates = true;
  bool _messageNotifs = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FblaRadius.xl)),
        boxShadow: FblaShadow.overlay,
      ),
      padding: const EdgeInsets.fromLTRB(
          FblaSpacing.xl, FblaSpacing.lg, FblaSpacing.xl, FblaSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(FblaRadius.full),
              ),
            ),
          ),
          const SizedBox(height: FblaSpacing.lg),

          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: FblaColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(FblaRadius.sm),
                ),
                child: const Icon(Icons.email_outlined,
                    color: FblaColors.primary, size: 22),
              ),
              const SizedBox(width: FblaSpacing.md),
              Text('Email Preferences',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: FblaSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Choose which emails you receive from FBLA Connect.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurface.withAlpha(160)),
            ),
          ),

          const SizedBox(height: FblaSpacing.lg),

          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(FblaRadius.lg),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Chapter Announcements',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Emails when your advisor posts',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(140))),
                  value: _announcements,
                  onChanged: (v) => setState(() => _announcements = v),
                  activeColor: FblaColors.primary,
                ),
                Divider(height: 1, color: cs.outlineVariant),
                SwitchListTile.adaptive(
                  title: const Text('Event Reminders',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Reminder 24h before registered events',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(140))),
                  value: _eventReminders,
                  onChanged: (v) => setState(() => _eventReminders = v),
                  activeColor: FblaColors.primary,
                ),
                Divider(height: 1, color: cs.outlineVariant),
                SwitchListTile.adaptive(
                  title: const Text('Chapter Updates',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('New members, resources, news',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(140))),
                  value: _chapterUpdates,
                  onChanged: (v) => setState(() => _chapterUpdates = v),
                  activeColor: FblaColors.primary,
                ),
                Divider(height: 1, color: cs.outlineVariant),
                SwitchListTile.adaptive(
                  title: const Text('Direct Messages',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Email digest of unread messages',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(140))),
                  value: _messageNotifs,
                  onChanged: (v) => setState(() => _messageNotifs = v),
                  activeColor: FblaColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: FblaSpacing.lg),

          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email preferences saved!')),
              );
              Navigator.pop(context);
            },
            child: const Text('Save Preferences'),
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    // Mark as a semantic header so screen readers can navigate by heading
    // when Logical Heading Structure is enabled.
    final useHeader = AccessibilitySettings.instance.logicalHeadings;
    return Semantics(
      header: useHeader,
      child: Padding(
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
              style: FblaFonts.monoTag(
                fontSize: 11,
                color: FblaColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Single-surface settings card
    return Container(
      decoration: BoxDecoration(
        color: FblaColors.darkSurface,
        borderRadius: BorderRadius.circular(FblaRadius.xl),
        border: Border.all(color: FblaColors.darkOutline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 56),
    color: Colors.white.withAlpha(10),
  );
}

/// Three-way appearance selector: System / Light / Dark.
///
/// Replaces the old binary "High-Contrast Dark Mode" toggle because that
/// toggle could only force dark or defer to the OS — never force light.
/// Users on a dark-mode OS who wanted the app in light mode had no way
/// to get there, which surfaced as "Light Mode isn't working."
class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({required this.value, required this.onChanged});
  final String value; // 'system' | 'light' | 'dark'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FblaSpacing.md, FblaSpacing.md, FblaSpacing.md, FblaSpacing.md,
      ),
      child: Row(
        children: [
          const _IconBadge(
            icon: Icons.dark_mode_outlined,
            color: Color(0xFF1E3A5F),
          ),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: FblaFonts.label(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose light, dark, or follow system.',
                  style: FblaFonts.body(
                    fontSize: 12,
                    color: FblaColors.darkTextSecond,
                  ),
                ),
                const SizedBox(height: FblaSpacing.sm),
                _AppearanceSegmented(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSegmented extends StatelessWidget {
  const _AppearanceSegmented({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String, IconData)>[
    ('system', 'System', Icons.brightness_auto_rounded),
    ('light',  'Light',  Icons.light_mode_rounded),
    ('dark',   'Dark',   Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(FblaRadius.md),
        border: Border.all(color: Colors.white.withAlpha(18), width: 1),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((opt) {
          final (id, label, icon) = opt;
          final selected = id == value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => onChanged(id),
              borderRadius: BorderRadius.circular(FblaRadius.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? FblaColors.secondary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(FblaRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: selected
                          ? FblaColors.onSecondary
                          : FblaColors.darkTextSecond,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: FblaFonts.label(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? FblaColors.onSecondary
                            : FblaColors.darkTextSecond,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color-blind simulation selector
// ─────────────────────────────────────────────────────────────────────────────
//
// Lives directly under Appearance. Five buttons (None / Protanopia /
// Deuteranopia / Tritanopia / Achromatopsia) — each tap installs a global
// ColorFilter at the MaterialApp root so the entire app is recolored
// through the matching matrix. A scrollable button row keeps the control
// horizontally scannable on small phones without wrapping into 2 rows.
class _ColorBlindRow extends StatelessWidget {
  const _ColorBlindRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String)>[
    ('none',          'None'),
    ('protanopia',    'Protanopia'),
    ('deuteranopia',  'Deuteranopia'),
    ('tritanopia',    'Tritanopia'),
    ('achromatopsia', 'Achromatopsia'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FblaSpacing.md, FblaSpacing.md, FblaSpacing.md, FblaSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconBadge(
            icon: Icons.palette_outlined,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color-blind simulation',
                  style: FblaFonts.label(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? FblaColors.darkTextPrimary
                        : FblaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recolor the entire app to preview how it looks for '
                  'common forms of color-vision deficiency.',
                  style: FblaFonts.body(
                    fontSize: 12,
                    color: isDark
                        ? FblaColors.darkTextSecond
                        : FblaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: FblaSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _options.map((opt) {
                      final (id, label) = opt;
                      final selected = id == value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => onChanged(id),
                          borderRadius:
                              BorderRadius.circular(FblaRadius.sm),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? FblaColors.secondary
                                  : (isDark
                                      ? FblaColors.darkSurfaceHigh
                                      : FblaColors.surfaceVariant),
                              borderRadius:
                                  BorderRadius.circular(FblaRadius.sm),
                              border: Border.all(
                                color: selected
                                    ? FblaColors.secondary
                                    : (isDark
                                        ? FblaColors.darkOutline
                                        : FblaColors.outline),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              label,
                              style: FblaFonts.label(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? FblaColors.onSecondary
                                    : (isDark
                                        ? FblaColors.darkTextPrimary
                                        : FblaColors.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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

/// Reusable icon badge for list tiles.
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(FblaRadius.md),
          border: Border.all(color: color.withAlpha(40), width: 1),
        ),
        child: Icon(icon, color: color, size: 20),
      );
}

/// A simple tappable settings row with icon, title, optional subtitle.
class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile>
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: FblaSpacing.md, vertical: 12),
          child: Row(
            children: [
              _IconBadge(icon: widget.icon, color: widget.iconColor),
              const SizedBox(width: FblaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FblaColors.darkTextPrimary,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: FblaColors.darkTextTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: FblaColors.darkTextTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row with icon badge, title, subtitle, and a Switch.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: _IconBadge(icon: icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FblaColors.darkTextPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: FblaColors.darkTextTertiary,
            height: 1.4,
          ),
        ),
      ),
      value: value,
      onChanged: onChanged,
      // Gold active track in dark mode — matches the premium palette
      activeColor: FblaColors.primaryDark,
      activeTrackColor: FblaColors.secondary,
      inactiveTrackColor: FblaColors.darkSurfaceHigh,
      inactiveThumbColor: FblaColors.darkTextTertiary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.xs,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(FblaRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: fg),
        ),
      );
}

// ─── Color-Blindness Type Row ──────────────────────────────────────────────

class _ColorBlindTypeRow extends StatelessWidget {
  const _ColorBlindTypeRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String, String)>[
    ('none',          'None',         'No color adjustment'),
    ('protanopia',    'Protanopia',   'Reduced red sensitivity'),
    ('deuteranopia',  'Deuteranopia', 'Reduced green sensitivity'),
    ('tritanopia',    'Tritanopia',   'Reduced blue sensitivity'),
    ('achromatopsia', 'Achromatopsia','Full grayscale'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FblaSpacing.md, FblaSpacing.md, FblaSpacing.md, FblaSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconBadge(
            icon: Icons.visibility_outlined,
            color: Color(0xFF5B348B),
          ),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color-Blindness Type',
                  style: FblaFonts.label(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Applies a color-vision simulation filter app-wide.',
                  style: FblaFonts.body(
                    fontSize: 12,
                    color: FblaColors.darkTextSecond,
                  ),
                ),
                const SizedBox(height: FblaSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _options.map((opt) {
                    final (id, label, desc) = opt;
                    final selected = id == value;
                    return Semantics(
                      label: '$label — $desc',
                      selected: selected,
                      button: true,
                      child: InkWell(
                        onTap: () => onChanged(id),
                        borderRadius: BorderRadius.circular(FblaRadius.sm),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? FblaColors.secondary
                                : Colors.white.withAlpha(12),
                            borderRadius: BorderRadius.circular(FblaRadius.sm),
                            border: Border.all(
                              color: selected
                                  ? FblaColors.secondary
                                  : Colors.white.withAlpha(22),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            label,
                            style: FblaFonts.label(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? FblaColors.onSecondary
                                  : FblaColors.darkTextSecond,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
