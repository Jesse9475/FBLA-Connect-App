import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import '../services/password_policy.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import '../widgets/password_helpers.dart';
import 'home_shell.dart';

/// Multi-step account creation + role-branched onboarding.
///
/// Flow:
///   Role selection → Account → OTP verification
///     └─ Member  → Name → Chapter → Interests → Tour → HomeShell
///     └─ Advisor → Advisor code → Confirm → Tour → HomeShell
///     └─ Admin   → Admin code (debug-only) → Confirm → Tour → HomeShell
///
/// When [resumeMode] is true (user already authenticated but profile incomplete),
/// the account/OTP steps are skipped — starts at Name for members.
///
/// Admin test code (DEBUG only): FBLAADMIN2026
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.resumeMode = false});

  /// When true, the user is already authenticated; skip account & OTP steps.
  final bool resumeMode;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

enum _Step {
  account,
  otp,            // ← email OTP verification (new)
  role,
  // ── Member path ──────────────────────────
  memberName,
  memberChapter,
  memberInterests,
  // ── Advisor path ─────────────────────────
  advisorCode,
  advisorConfirm,
  // ── Shared final ─────────────────────────
  tour,
}

class _SignupScreenState extends State<SignupScreen> {
  // Role is now the FIRST step so the user picks their role before
  // creating their account credentials.
  _Step _step = _Step.role;
  String _selectedRole = 'member'; // 'member' | 'advisor' | 'admin'

  // ── Step 1 – Account ──────────────────────────────────────────────────────
  final _accountKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  // Focus nodes for password + confirm fields — drive the padlock mascot's
  // "peeking" state when the field has focus but no text yet.
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  // ── Step 2 – OTP ──────────────────────────────────────────────────────────
  final _otpKey   = GlobalKey<FormState>();
  final _otpCtrl  = TextEditingController();
  String? _devOtpCode;       // shown in DEBUG overlay so demo works w/o email
  bool   _otpResending = false;

  // ── Step 3m – Name & Grade ────────────────────────────────────────────────
  final _personalKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  String? _selectedGrade;
  static const _grades = [
    '9th Grade', '10th Grade', '11th Grade', '12th Grade',
    'College Freshman', 'College Sophomore', 'College Junior', 'College Senior',
    'Alumni',
  ];

  // ── Step 4m – Chapter ─────────────────────────────────────────────────────
  //
  // Two-step cascade: user types/picks a district first, then types/picks
  // a chapter from that district. Both fields are fully typeable (not
  // dropdown-only) because scrolling through 231 chapters is awful.
  List<Map<String, dynamic>> _chapters = [];
  List<Map<String, dynamic>> _districts = [];
  String? _selectedDistrictId;
  String? _selectedChapterId;
  bool _loadingChapters = false;

  // ── Step 6m – Interests ───────────────────────────────────────────────────
  final Set<String> _selectedInterests = {};
  static const _allInterests = [
    'Accounting',
    'Business Law',
    'Economics',
    'Entrepreneurship',
    'Finance',
    'Healthcare Administration',
    'Hospitality & Tourism',
    'Leadership',
    'Marketing',
    'Public Speaking',
    'Technology',
    'Management',
  ];

  // ── Step 3a – Advisor code ────────────────────────────────────────────────
  final _advisorCodeKey = GlobalKey<FormState>();
  final _advisorCodeCtrl = TextEditingController();

  // ── Shared ────────────────────────────────────────────────────────────────
  bool _loading = false;
  String? _errorMessage;
  String? _signedUpUserId;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadDistricts();
    _loadChapters();
    // Rebuild whenever the password field's focus state changes so the
    // ShyEyesMascot can switch between idle / peeking in real time.
    _passwordFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _confirmFocus.addListener(() {
      if (mounted) setState(() {});
    });
    // If resuming after incomplete onboarding (user is already authenticated),
    // skip the account/OTP steps and go straight to profile setup.
    if (widget.resumeMode) {
      _signedUpUserId = Supabase.instance.client.auth.currentUser?.id;
      _step = _Step.memberName;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _advisorCodeCtrl.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ─── Step completeness predicates ───────────────────────────────────────
  // Each returns true when the current step's inputs are all valid. Drives
  // the "Continue" button's gold-glow state — the button stays pressable
  // regardless (so form validation still runs on tap), but lights up once
  // everything's green.

  bool get _accountComplete {
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final emailOk =
        email.isNotEmpty && email.contains('@') && email.contains('.');
    final pwOk = validatePassword(pw) == null;
    final confirmOk = confirm.isNotEmpty && confirm == pw;
    return emailOk && pwOk && confirmOk;
  }

  bool get _otpComplete {
    final t = _otpCtrl.text.trim();
    return t.length == 6 && RegExp(r'^\d{6}$').hasMatch(t);
  }

  bool get _memberNameComplete {
    return _firstNameCtrl.text.trim().isNotEmpty &&
        _lastNameCtrl.text.trim().isNotEmpty &&
        _selectedGrade != null;
  }

  // The chapter step is "done enough" when either a district OR a
  // chapter is picked. Picking a chapter alone still counts because the
  // district is derived automatically from the chapter's district_id.
  bool get _memberChapterComplete =>
      _selectedChapterId != null || _selectedDistrictId != null;

  // Interests is optional (Skip is offered), so the button is always "complete".
  bool get _memberInterestsComplete => true;

  bool get _advisorCodeComplete => _advisorCodeCtrl.text.trim().isNotEmpty;

  Future<void> _loadChapters() async {
    setState(() => _loadingChapters = true);
    try {
      final res = await Supabase.instance.client
          .from('chapters')
          .select('id, name, district_id')
          .order('name');
      if (mounted) {
        setState(() {
          _chapters = List<Map<String, dynamic>>.from(res as List);
          _loadingChapters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChapters = false);
    }
  }

  /// Pulls the district list from Supabase so the cascading picker can
  /// show district names alongside their ids. Best-effort — a failure
  /// here leaves the list empty but the typeable chapter field still
  /// works via chapter.district_id fallback.
  Future<void> _loadDistricts() async {
    try {
      final res = await Supabase.instance.client
          .from('districts')
          .select('id, name')
          .order('name');
      if (mounted) {
        setState(() {
          _districts = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[signup] _loadDistricts failed: $e');
      }
    }
  }

  Future<void> _goToApp() async {
    if (!mounted) return;
    // Mark onboarding complete in Supabase user metadata so AuthGate
    // knows the account is fully set up on any device.
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'onboarding_complete': true}),
      );
    } catch (_) { /* non-fatal */ }
    if (!mounted) return;
    // Pop all routes above the root '/' so that the AuthGate widget
    // (which lives on the initial route) stays alive and continues to
    // receive auth-stream events.  AuthGate will have already rebuilt
    // to HomeShell() by the time we pop because updateUser() triggers
    // a userUpdated event that AuthGate's listener processes first.
    //
    // Previously this used pushAndRemoveUntil(HomeShell, false) which
    // destroyed the root route containing AuthGate, causing sign-out
    // to stop working (the auth-stream event fired but nothing listened).
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Back navigation ───────────────────────────────────────────────────────
  void _back() {
    if (_loading) return;
    setState(() {
      _errorMessage = null;
      switch (_step) {
        // Role is now the very first step → pop back to onboarding.
        case _Step.role:
          Navigator.of(context).pop();
        // Account comes after role selection.
        case _Step.account:
          _step = _Step.role;
        case _Step.otp:
          _step = _Step.account;
        // Member path: after OTP comes Name, not role.
        case _Step.memberName:
          _step = _Step.otp;
        case _Step.memberChapter:
          _step = _Step.memberName;
        case _Step.memberInterests:
          _step = _Step.memberChapter;
        // Advisor path: after OTP comes Code, not role.
        case _Step.advisorCode:
          _step = _Step.otp;
        case _Step.advisorConfirm:
          _step = _Step.advisorCode;
        case _Step.tour:
          _goToApp();
      }
    });
  }

  // ── Progress indicator data ───────────────────────────────────────────────
  ({int current, int total, List<String> labels}) get _progress {
    // Role is step 0 (no bar shown); bar starts from Account.
    if (_selectedRole == 'advisor' || _selectedRole == 'admin') {
      const labels = ['Account', 'Verify', 'Code', 'Confirm'];
      const ordered = [
        _Step.account, _Step.otp, _Step.advisorCode, _Step.advisorConfirm,
      ];
      final idx = ordered.indexOf(_step);
      return (current: idx < 0 ? 0 : idx, total: 4, labels: labels);
    } else {
      const labels = ['Account', 'Verify', 'Name', 'Chapter', 'Interests'];
      const ordered = [
        _Step.account, _Step.otp, _Step.memberName,
        _Step.memberChapter, _Step.memberInterests,
      ];
      final idx = ordered.indexOf(_step);
      return (current: idx < 0 ? 0 : idx, total: 5, labels: labels);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  // ── Step 1: Send OTP to email ─────────────────────────────────────────────
  //
  // We use signInWithOtp(shouldCreateUser: true) instead of signUp() because:
  //   • signUp() sends a "magic link" confirmation email — not a 6-digit code.
  //   • signInWithOtp() always sends the 6-digit OTP the user expects.
  //
  // After the user verifies the code we set their password with updateUser().
  Future<void> _handleSignUp() async {
    if (!_accountKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailCtrl.text.trim(),
        shouldCreateUser: true, // creates account on first use
      );

      if (mounted) setState(() {
        _step    = _Step.otp;
        _loading = false;
      });
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      String friendly;
      if (msg.contains('already registered') || msg.contains('already exists') ||
          msg.contains('already been registered')) {
        friendly = 'An account with that email already exists. Try signing in instead.';
      } else if (msg.contains('rate') || msg.contains('limit')) {
        friendly = 'Too many attempts. Please wait a moment and try again.';
      } else {
        friendly = 'Could not send verification code: ${e.message}';
      }
      if (mounted) setState(() { _errorMessage = friendly; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _errorMessage = 'Unable to reach server. Check your connection.';
        _loading = false;
      });
    }
  }

  // ── Step 2: OTP verify ────────────────────────────────────────────────────
  Future<void> _handleOtpVerify() async {
    if (!_otpKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });
    try {
      // OtpType.email matches the 6-digit code sent by signInWithOtp().
      // (OtpType.magiclink is for the token embedded in click-to-confirm links
      //  — wrong type, would always reject a 6-digit code.)
      final res = await Supabase.instance.client.auth.verifyOTP(
        email: _emailCtrl.text.trim(),
        token: _otpCtrl.text.trim(),
        type: OtpType.email,
      );

      // Store session token for API calls.
      final session = res.session ?? Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await ApiService.instance.setToken(session.accessToken);
        _signedUpUserId = session.user.id;
      }

      // Now set the password the user chose on the account step.
      // (signInWithOtp creates a passwordless account; we add the password here.)
      final pw = _passwordCtrl.text;
      if (pw.isNotEmpty) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: pw),
          );
        } catch (_) {
          // Non-fatal — account is usable without password if OTP login is available.
        }
      }

      // Role was already chosen before account creation; branch directly.
      if (mounted) setState(() {
        _step = (_selectedRole == 'advisor' || _selectedRole == 'admin')
            ? _Step.advisorCode
            : _Step.memberName;
        _loading = false;
        _otpCtrl.clear();
      });
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      String friendly;
      if (msg.contains('otp') && msg.contains('expired')) {
        friendly = 'Your code has expired. Tap "Resend code" to get a new one.';
      } else if (msg.contains('invalid') || msg.contains('incorrect') || msg.contains('token')) {
        friendly = 'Incorrect code. Please check your email and try again.';
      } else {
        friendly = 'Verification failed: ${e.message}';
      }
      if (mounted) setState(() { _errorMessage = friendly; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _errorMessage = 'Verification failed. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _handleResendOtp() async {
    setState(() { _otpResending = true; _errorMessage = null; });
    try {
      // Ask Supabase to resend the OTP email — no backend or SMTP needed.
      // shouldCreateUser: true — safe to use on resend; if the account already
      // exists Supabase just resends the code without creating a duplicate.
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailCtrl.text.trim(),
        shouldCreateUser: true,
      );
      if (mounted) setState(() {
        _devOtpCode   = null;
        _otpResending = false;
        _otpCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New code sent!')),
        );
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      String friendly = msg.contains('rate') || msg.contains('limit')
          ? 'Please wait before requesting another code.'
          : 'Could not resend. Check your connection.';
      if (mounted) setState(() { _errorMessage = friendly; _otpResending = false; });
    }
  }

  // ── Step 3: Role selection ────────────────────────────────────────────────
  void _selectRole(String role) {
    // Role is chosen first; move to account creation next.
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
      _step = _Step.account;
    });
  }

  // ── Member step 3: Name & Grade ──────────────────────────────────────────
  //
  // Previously wrapped in `catch (_) { /* non-fatal */ }` which swallowed
  // every error silently — including 401s from an expired session and 500s
  // from schema mismatches. The result: names looked saved locally but were
  // NULL in Supabase. Now we surface errors to `_errorMessage` so the user
  // sees the failure, AND log to console in debug for triage.
  Future<void> _handleSaveName() async {
    if (!_personalKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    String? criticalError;

    try {
      final userId = _signedUpUserId ?? Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        criticalError = 'Your session expired. Please sign in again.';
      } else {
        final body = <String, dynamic>{
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'display_name': '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
        };
        try {
          await ApiService.instance.patch<void>(
            '/users/$userId', body: body, parser: (_) {});
        } catch (e, st) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[signup] PATCH /users/$userId failed: $e\n$st');
          }
          criticalError = 'Couldn\'t save your name. ${_shortenErr(e)}';
        }
        // Grade lives in the profile table. Non-fatal if it fails (e.g.
        // the profiles row hasn't been created yet) — log but keep going.
        if (_selectedGrade != null) {
          try {
            await ApiService.instance.patch<void>(
              '/profiles/$userId',
              body: {'grade': _selectedGrade},
              parser: (_) {},
            );
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('[signup] PATCH /profiles/$userId (grade) failed: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[signup] _handleSaveName unexpected: $e');
      }
      criticalError = 'Something went wrong. ${_shortenErr(e)}';
    }

    if (!mounted) return;
    if (criticalError != null) {
      setState(() { _errorMessage = criticalError; _loading = false; });
      return;
    }
    setState(() { _step = _Step.memberChapter; _loading = false; });
  }

  // ── Member step 4: Chapter ────────────────────────────────────────────────
  Future<void> _handleSaveChapter() async {
    setState(() { _loading = true; _errorMessage = null; });

    String? criticalError;

    try {
      final userId = _signedUpUserId ?? Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        criticalError = 'Your session expired. Please sign in again.';
      } else if (_selectedChapterId != null || _selectedDistrictId != null) {
        // Resolve the chapter row (may be empty if only district picked).
        final Map<String, dynamic> chapter = _selectedChapterId == null
            ? <String, dynamic>{}
            : _chapters.firstWhere(
                (c) => c['id'] == _selectedChapterId,
                orElse: () => <String, dynamic>{},
              );

        // Build PATCH body. Chapter is only included if picked; district
        // is derived from the chapter first, then falls back to the
        // user's explicit district selection.
        final body = <String, dynamic>{};
        if (_selectedChapterId != null) {
          body['chapter_id'] = _selectedChapterId;
        }
        final chapterDistrict = chapter['district_id'];
        if (chapterDistrict is String && chapterDistrict.isNotEmpty) {
          body['district_id'] = chapterDistrict;
        } else if (_selectedDistrictId != null) {
          body['district_id'] = _selectedDistrictId;
        }

        if (body.isNotEmpty) {
          try {
            await ApiService.instance
                .patch<void>('/users/$userId', body: body, parser: (_) {});
          } catch (e, st) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('[signup] PATCH /users/$userId (chapter) failed: $e\n$st');
            }
            criticalError = 'Couldn\'t save your chapter. ${_shortenErr(e)}';
          }
        }

        // Auto-save the chapter name as the school in the user's profile
        // (chapters are named after their schools in FBLA). This is
        // best-effort — not blocking onboarding if it fails.
        final chapterName = chapter['name'];
        if (chapterName is String && chapterName.isNotEmpty) {
          try {
            await ApiService.instance
                .patch<void>('/profiles/$userId', body: {'school': chapterName}, parser: (_) {});
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('[signup] PATCH /profiles/$userId (school) failed: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[signup] _handleSaveChapter unexpected: $e');
      }
      criticalError = 'Something went wrong. ${_shortenErr(e)}';
    }

    if (!mounted) return;
    if (criticalError != null) {
      setState(() { _errorMessage = criticalError; _loading = false; });
      return;
    }
    setState(() { _step = _Step.memberInterests; _loading = false; });
  }

  // ── Member step 5: Interests ──────────────────────────────────────────────
  //
  // Interests are optional in the UI, and the backend stores them in the
  // profiles table. If the PATCH fails (e.g. the interests column doesn't
  // exist yet in some environments), we log but continue to the tour so
  // users can still finish onboarding.
  Future<void> _handleSaveInterests() async {
    setState(() { _loading = true; });
    try {
      final userId = _signedUpUserId ?? Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && _selectedInterests.isNotEmpty) {
        try {
          await ApiService.instance.patch<void>(
            '/profiles/$userId',
            body: {'interests': _selectedInterests.toList()},
            parser: (_) {},
          );
        } catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[signup] PATCH /profiles/$userId (interests) failed: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[signup] _handleSaveInterests unexpected: $e');
      }
    }
    if (mounted) setState(() { _step = _Step.tour; _loading = false; });
  }

  /// Trim a throwable to a one-line, user-facing string.
  String _shortenErr(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    return s.length > 140 ? '${s.substring(0, 140)}…' : s;
  }

  // ── Advisor / Admin step 3: Code ─────────────────────────────────────────
  Future<void> _handleAdvisorCode() async {
    if (!_advisorCodeKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final endpoint = _selectedRole == 'admin' ? '/admin/verify' : '/advisor/verify';
      await ApiService.instance.post<void>(
        endpoint,
        body: {'code': _advisorCodeCtrl.text.trim()},
        parser: (_) {},
      );

      // CRITICAL: refresh UserState immediately so role-gated FABs (Create
      // Post / Announcement / Event / Resource) appear without requiring
      // an app restart.  Without this, HomeShell._loadUserRole only fires
      // once on initial mount and never observes the new advisor role.
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          final data = await ApiService.instance.get<Map<String, dynamic>>(
            '/users/$uid',
            parser: (json) => (json['user'] as Map<String, dynamic>?) ?? {},
          );
          UserState.instance.setChapter(
            data['chapter_id'] as String?,
            data['district_id'] as String?,
          );
          UserState.instance.setDisplayName(data['display_name'] as String?);
          final newRole = (data['role'] as String?) ?? _selectedRole ?? 'member';
          UserState.instance.setRole(newRole);
        }
      } catch (_) {
        // Best-effort — fall back to local role hint so the FAB still appears.
        UserState.instance.setRole(_selectedRole ?? 'advisor');
      }

      if (mounted) setState(() { _step = _Step.advisorConfirm; _loading = false; });
    } catch (e) {
      final msg = e.toString().toLowerCase();
      String friendly;
      if (msg.contains('invalid_code') || msg.contains('invalid code')) {
        friendly = _selectedRole == 'admin'
            ? 'That admin code is invalid.'
            : 'That code is invalid. Check with your administrator.';
      } else if (msg.contains('already_used') || msg.contains('already used')) {
        friendly = 'This code has already been used. Please request a new one.';
      } else if (msg.contains('expired')) {
        friendly = 'This code has expired. Please request a new one.';
      } else {
        friendly = 'Unable to verify. Check your connection and try again.';
      }
      if (mounted) setState(() { _errorMessage = friendly; _loading = false; });
    }
  }

  // ── Advisor step 4: Confirm ───────────────────────────────────────────────
  void _handleAdvisorConfirm() => setState(() => _step = _Step.tour);

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.tour) return _buildTourScreen();

    final p = _progress;
    // Show progress bar from Account onward; hide on role selection and tour.
    final showProgress = _step != _Step.role && _step != _Step.tour;

    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          tooltip: 'Back',
          onPressed: _loading ? null : _back,
        ),
        title: Text(
          _step == _Step.role ? 'Join FBLA' : 'Create Account',
          style: FblaFonts.label(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: FblaGradient.brand),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (showProgress)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FblaSpacing.xl,
                  vertical: FblaSpacing.md,
                ),
                child: _StepProgress(
                  currentStep: p.current,
                  totalSteps: p.total,
                  labels: p.labels,
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: FblaSpacing.xl,
                  vertical: FblaSpacing.md,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      _Step.account          => _buildAccountStep(),
      _Step.otp              => _buildOtpStep(),
      _Step.role             => _buildRoleStep(),
      _Step.memberName       => _buildNameStep(),
      _Step.memberChapter    => _buildChapterStep(),
      _Step.memberInterests  => _buildInterestsStep(),
      _Step.advisorCode      => _buildAdvisorCodeStep(),
      _Step.advisorConfirm   => _buildAdvisorConfirmStep(),
      _Step.tour             => _buildTourScreen(),
    };
  }

  // ── Step 1: Account ───────────────────────────────────────────────────────
  Widget _buildAccountStep() {
    return Form(
      key: _accountKey,
      child: Column(
        key: const ValueKey('account'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create your account',
              style: FblaFonts.display(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: FblaColors.darkTextPrimary,
              )),
          const SizedBox(height: FblaSpacing.xs),
          Text('Enter your email and choose a secure password.',
              style: FblaFonts.body(
                fontSize: 15,
                color: FblaColors.darkTextSecond,
              )),
          const SizedBox(height: FblaSpacing.xl),

          _StyledTextField(
            controller: _emailCtrl,
            label: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required.';
              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email.';
              return null;
            },
          ),
          const SizedBox(height: FblaSpacing.md),

          _StyledTextField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            label: 'Password',
            icon: Icons.lock_outlined,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            // Animated padlock sits on the LEFT. Stays OPEN until the
            // password meets every requirement, then clicks shut with a
            // soft green glow — a live visual gate matching the checklist.
            prefixWidget: ShyEyesMascot(
              locked: passwordMeetsPolicy(_passwordCtrl.text),
              focused: _passwordFocus.hasFocus,
              size: 30,
            ),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            onChanged: (_) => setState(() {}),
            validator: validatePassword,
          ),
          const SizedBox(height: FblaSpacing.md),

          _StyledTextField(
            controller: _confirmCtrl,
            focusNode: _confirmFocus,
            label: 'Confirm password',
            icon: Icons.lock_outlined,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            // Matching padlock on the confirm field — locks only when
            // both passwords match AND the base password passes policy.
            prefixWidget: ShyEyesMascot(
              locked: _confirmCtrl.text.isNotEmpty &&
                  _confirmCtrl.text == _passwordCtrl.text &&
                  passwordMeetsPolicy(_passwordCtrl.text),
              focused: _confirmFocus.hasFocus,
              size: 30,
            ),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              tooltip:
                  _obscureConfirm ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _handleSignUp(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password.';
              if (v != _passwordCtrl.text) return 'Passwords do not match.';
              return null;
            },
          ),
          // Live checklist below the confirm field — each rule (plus a
          // "Passwords match" row) ticks off with a bouncy animation as
          // the user types. Single source of truth for what's required.
          PasswordRequirementsChecklist(
            value: _passwordCtrl.text,
            confirmValue: _confirmCtrl.text,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: FblaSpacing.md),
            _ErrorBanner(message: _errorMessage!),
          ],

          const SizedBox(height: FblaSpacing.xl),
          _SignupButton(
            label: 'Continue',
            onPressed: _loading ? null : _handleSignUp,
            loading: _loading,
            complete: _accountComplete,
          ),
          const SizedBox(height: FblaSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(
                'Already have an account? Sign in',
                style: FblaFonts.label(
                  fontSize: 13,
                  color: FblaColors.darkTextSecond,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: OTP ───────────────────────────────────────────────────────────
  Widget _buildOtpStep() {
    final email = _emailCtrl.text.trim();
    final maskedEmail = email.contains('@')
        ? '${email.split('@').first.substring(0, (email.split('@').first.length / 2).ceil())}***@${email.split('@').last}'
        : email;

    return Form(
      key: _otpKey,
      child: Column(
        key: const ValueKey('otp'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: FblaColors.secondary.withAlpha(18),
              borderRadius: BorderRadius.circular(FblaRadius.md),
              border: Border.all(color: FblaColors.secondary.withAlpha(60)),
            ),
            child: const Icon(Icons.mark_email_read_outlined,
                size: 32, color: FblaColors.secondary),
          )
              .animate()
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .scaleXY(begin: 0.85, end: 1.0, duration: 300.ms, curve: Curves.easeOut),
          const SizedBox(height: FblaSpacing.lg),

          Text(
            'Verify your email',
            style: FblaFonts.display(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FblaColors.darkTextPrimary,
            ),
          )
              .animate(delay: 60.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
          const SizedBox(height: FblaSpacing.xs),
          RichText(
            text: TextSpan(
              style: FblaFonts.body(
                fontSize: 15,
                color: FblaColors.darkTextSecond,
              ),
              children: [
                const TextSpan(text: 'We sent a 6-digit code to '),
                TextSpan(
                  text: maskedEmail,
                  style: FblaFonts.body(
                    fontSize: 15,
                    color: FblaColors.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '. Enter it below to verify your account.'),
              ],
            ),
          )
              .animate(delay: 80.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut),

          const SizedBox(height: FblaSpacing.xl),

          // 6-digit OTP field
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _handleOtpVerify(),
            style: TextStyle(
              fontFamily: FblaFonts.mono,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: FblaColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                fontFamily: FblaFonts.mono,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
                color: FblaColors.darkTextSecond.withAlpha(60),
              ),
              filled: true,
              fillColor: FblaColors.darkSurfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: BorderSide(color: FblaColors.darkOutline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: BorderSide(color: FblaColors.darkOutline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: const BorderSide(color: FblaColors.primary, width: 2),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter the 6-digit code.';
              if (v.trim().length != 6) return 'Code must be exactly 6 digits.';
              if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) return 'Code must be numbers only.';
              return null;
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: FblaSpacing.md),
            _ErrorBanner(message: _errorMessage!),
          ],

          const SizedBox(height: FblaSpacing.xl),
          _SignupButton(
            label: 'Verify code',
            onPressed: _loading ? null : _handleOtpVerify,
            loading: _loading,
            complete: _otpComplete,
          ),
          const SizedBox(height: FblaSpacing.sm),
          Center(
            child: TextButton.icon(
              onPressed: _otpResending ? null : _handleResendOtp,
              icon: _otpResending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: FblaColors.primary))
                  : const Icon(Icons.refresh, size: 16),
              label: Text(
                _otpResending ? 'Sending…' : 'Resend code',
                style: FblaFonts.label(
                  fontSize: 13,
                  color: FblaColors.darkTextSecond,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Role selection ────────────────────────────────────────────────
  Widget _buildRoleStep() {
    return Column(
      key: const ValueKey('role'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FblaSpacing.lg),
        Text(
          'What describes you?',
          style: FblaFonts.display(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: FblaColors.darkTextPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FblaSpacing.sm),
        Text(
          'Choose the option that best fits your role in FBLA.',
          style: FblaFonts.body(
            fontSize: 15,
            color: FblaColors.darkTextSecond,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FblaSpacing.xxl),

        // Member card
        _RoleCard(
          title: 'Student Member',
          subtitle: 'I\'m a student participating in FBLA competitions and activities.',
          icon: Icons.school_outlined,
          color: FblaColors.primary,
          onTap: () => _selectRole('member'),
        )
            .animate()
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),

        const SizedBox(height: FblaSpacing.md),

        // Advisor card
        _RoleCard(
          title: 'Chapter Advisor',
          subtitle: 'I\'m a teacher or administrator managing an FBLA chapter.',
          icon: Icons.assignment_ind_outlined,
          color: FblaColors.secondaryDark,
          onTap: () => _selectRole('advisor'),
        )
            .animate(delay: 60.ms)
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),

        if (kDebugMode) ...[
          const SizedBox(height: FblaSpacing.md),
          _RoleCard(
            title: 'Admin (Debug)',
            subtitle: 'Test admin access with code FBLAADMIN2026.',
            icon: Icons.admin_panel_settings_outlined,
            color: Colors.deepOrange,
            onTap: () => _selectRole('admin'),
          )
              .animate(delay: 120.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
        ],

        const SizedBox(height: FblaSpacing.xxl),
      ],
    );
  }

  // ── Member step 3: Name & Grade ──────────────────────────────────────────
  Widget _buildNameStep() {
    return Form(
      key: _personalKey,
      child: Column(
        key: const ValueKey('memberName'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("What's your name?",
              style: FblaFonts.display(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: FblaColors.darkTextPrimary,
              )),
          const SizedBox(height: FblaSpacing.xs),
          Text('This is how other members will see you.',
              style: FblaFonts.body(
                fontSize: 15,
                color: FblaColors.darkTextSecond,
              )),
          const SizedBox(height: FblaSpacing.xl),

          _StyledTextField(
            controller: _firstNameCtrl,
            label: 'First name',
            icon: Icons.person_outlined,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'First name is required.' : null,
          ),
          const SizedBox(height: FblaSpacing.md),

          _StyledTextField(
            controller: _lastNameCtrl,
            label: 'Last name',
            icon: Icons.person_outlined,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Last name is required.' : null,
          ),
          const SizedBox(height: FblaSpacing.md),

          // Grade dropdown
          _StyledDropdown(
            label: 'Grade / Year',
            icon: Icons.school_outlined,
            value: _selectedGrade,
            items: _grades,
            onChanged: (v) => setState(() => _selectedGrade = v),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: FblaSpacing.md),
            _ErrorBanner(message: _errorMessage!),
          ],

          const SizedBox(height: FblaSpacing.xl),
          _SignupButton(
            label: 'Continue',
            onPressed: _loading ? null : _handleSaveName,
            loading: _loading,
            complete: _memberNameComplete,
          ),
        ],
      ),
    );
  }

  // ── Member step 4: Chapter ────────────────────────────────────────────────
  //
  // Two-step cascade. The user types their district first (autocomplete
  // over `_districts`), then types a chapter filtered by that district.
  // This replaces the old single 231-row dropdown — scrolling through
  // every FBLA chapter was miserable.
  Widget _buildChapterStep() {
    // Keep only rows with proper String ids/names, so one malformed row
    // from Supabase never red-screens the whole step.
    final validDistricts = _districts.where((d) {
      final id = d['id'];
      final name = d['name'];
      return id is String && id.isNotEmpty
          && name is String && name.isNotEmpty;
    }).toList();

    // Chapters filtered to the currently-picked district. If no district
    // is picked yet, show nothing so the user can't accidentally choose
    // a chapter from the wrong district.
    final filteredChapters = _selectedDistrictId == null
        ? <Map<String, dynamic>>[]
        : _chapters.where((c) {
            final id = c['id'];
            final name = c['name'];
            final dist = c['district_id'];
            return id is String && id.isNotEmpty
                && name is String && name.isNotEmpty
                && dist == _selectedDistrictId;
          }).toList();

    final selectedDistrict = validDistricts.firstWhere(
      (d) => d['id'] == _selectedDistrictId,
      orElse: () => <String, dynamic>{},
    );
    final selectedChapter = filteredChapters.firstWhere(
      (c) => c['id'] == _selectedChapterId,
      orElse: () => <String, dynamic>{},
    );

    return Column(
      key: const ValueKey('memberChapter'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your chapter',
            style: FblaFonts.display(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FblaColors.darkTextPrimary,
            )),
        const SizedBox(height: FblaSpacing.xs),
        Text(
          'Pick your district first, then your chapter. Start typing — '
          'we\'ll match as you go.',
          style: FblaFonts.body(
            fontSize: 15,
            color: FblaColors.darkTextSecond,
          ),
        ),
        const SizedBox(height: FblaSpacing.xl),

        if (_loadingChapters && validDistricts.isEmpty)
          const Center(child: CircularProgressIndicator(color: FblaColors.primary))
        else ...[
          // ── District field ────────────────────────────────────────────
          _TypeableSearchField(
            label: 'District',
            icon: Icons.map_outlined,
            hintText: 'e.g. CA-N, Northern California…',
            entries: validDistricts,
            selectedId: _selectedDistrictId,
            onSelected: (id) {
              setState(() {
                _selectedDistrictId = id;
                // Clear the chapter whenever the district changes so the
                // user never ends up with an out-of-district chapter.
                _selectedChapterId = null;
              });
            },
            onCleared: () {
              setState(() {
                _selectedDistrictId = null;
                _selectedChapterId = null;
              });
            },
          ),
          const SizedBox(height: FblaSpacing.md),

          // ── Chapter field ─────────────────────────────────────────────
          _TypeableSearchField(
            label: 'Chapter',
            icon: Icons.groups_outlined,
            hintText: _selectedDistrictId == null
                ? 'Pick a district first'
                : 'Start typing your school…',
            enabled: _selectedDistrictId != null,
            entries: filteredChapters,
            selectedId: _selectedChapterId,
            onSelected: (id) {
              setState(() => _selectedChapterId = id);
            },
            onCleared: () {
              setState(() => _selectedChapterId = null);
            },
          ),

          if (selectedDistrict.isNotEmpty || selectedChapter.isNotEmpty) ...[
            const SizedBox(height: FblaSpacing.sm),
            _buildSelectionChip(
              districtName: selectedDistrict['name'] as String?,
              districtId: selectedDistrict['id'] as String?,
              chapterName: selectedChapter['name'] as String?,
            ),
          ],
        ],

        const SizedBox(height: FblaSpacing.xl),
        _SignupButton(
          label: 'Continue',
          onPressed: _loading ? null : _handleSaveChapter,
          loading: _loading,
          complete: _memberChapterComplete,
        ),
        const SizedBox(height: FblaSpacing.sm),
        TextButton(
          onPressed: _loading ? null : () => setState(() { _step = _Step.memberInterests; }),
          child: Text('Skip', style: FblaFonts.label(
            fontSize: 13,
            color: FblaColors.darkTextSecond,
          )),
        ),
      ],
    );
  }

  /// Summary chip shown below the cascading picker once either the
  /// district or chapter is selected.
  Widget _buildSelectionChip({
    String? districtName,
    String? districtId,
    String? chapterName,
  }) {
    final districtLabel = (districtName != null && districtName.isNotEmpty)
        ? districtName
        : districtId ?? '';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: const Cubic(0.23, 1, 0.32, 1),
      padding: const EdgeInsets.symmetric(
          horizontal: FblaSpacing.md, vertical: FblaSpacing.sm),
      decoration: BoxDecoration(
        color: FblaColors.secondary.withAlpha(12),
        borderRadius: BorderRadius.circular(FblaRadius.sm),
        border: Border.all(color: FblaColors.secondary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 16, color: FblaColors.secondary),
          const SizedBox(width: FblaSpacing.sm),
          Expanded(
            child: Text(
              chapterName != null && chapterName.isNotEmpty
                  ? '$chapterName · $districtLabel'
                  : districtLabel,
              style: FblaFonts.monoLabel(
                fontSize: 11,
                color: FblaColors.secondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.check_circle_outline, size: 16, color: FblaColors.success),
        ],
      ),
    );
  }

  // ── Member step 5: Interests ──────────────────────────────────────────────
  Widget _buildInterestsStep() {
    return Column(
      key: const ValueKey('memberInterests'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your interests',
            style: FblaFonts.display(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FblaColors.darkTextPrimary,
            )),
        const SizedBox(height: FblaSpacing.xs),
        Text('Select areas you\'re most interested in. This helps us personalize your experience.',
            style: FblaFonts.body(
              fontSize: 15,
              color: FblaColors.darkTextSecond,
            )),
        const SizedBox(height: FblaSpacing.lg),

        Wrap(
          spacing: FblaSpacing.sm,
          runSpacing: FblaSpacing.sm,
          children: _allInterests.asMap().entries.map((e) {
            final interest = e.value;
            final selected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: selected,
              onSelected: (val) => setState(() {
                if (val) {
                  _selectedInterests.add(interest);
                } else {
                  _selectedInterests.remove(interest);
                }
              }),
              selectedColor: FblaColors.secondary,
              labelStyle: TextStyle(
                color: selected ? FblaColors.primaryDark : FblaColors.darkTextSecond,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              backgroundColor: FblaColors.darkSurfaceHigh,
              side: BorderSide(
                color: selected ? FblaColors.secondary : FblaColors.darkOutline,
              ),
              showCheckmark: false,
            )
                .animate(delay: Duration(milliseconds: 40 * e.key))
                .fadeIn(duration: 240.ms, curve: Curves.easeOut)
                .scaleXY(begin: 0.9, end: 1.0, duration: 240.ms, curve: Curves.easeOut);
          }).toList(),
        ),

        const SizedBox(height: FblaSpacing.xl),
        _SignupButton(
          label: 'Finish & get started',
          onPressed: _loading ? null : _handleSaveInterests,
          loading: _loading,
          complete: _memberInterestsComplete,
        ),
        const SizedBox(height: FblaSpacing.sm),
        TextButton(
          onPressed: _loading ? null : _handleSaveInterests,
          child: Text('Skip', style: FblaFonts.label(
            fontSize: 13,
            color: FblaColors.darkTextSecond,
          )),
        ),
      ],
    );
  }

  // ── Advisor step 3: Code entry ────────────────────────────────────────────
  Widget _buildAdvisorCodeStep() {
    final isAdmin = _selectedRole == 'admin';
    final accentColor = isAdmin ? Colors.deepOrange : FblaColors.secondaryDark;
    return Form(
      key: _advisorCodeKey,
      child: Column(
        key: const ValueKey('advisorCode'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(15),
              borderRadius: BorderRadius.circular(FblaRadius.md),
              border: Border.all(color: accentColor.withAlpha(50)),
            ),
            child: Icon(
              isAdmin ? Icons.admin_panel_settings_outlined : Icons.verified_user_outlined,
              size: 32, color: accentColor),
          )
              .animate()
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .scaleXY(begin: 0.85, end: 1.0, duration: 300.ms, curve: Curves.easeOut),
          const SizedBox(height: FblaSpacing.lg),
          Text(
            isAdmin ? 'Admin verification (Test)' : 'Advisor verification',
            style: FblaFonts.display(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FblaColors.darkTextPrimary,
            ),
          )
              .animate(delay: 60.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
          const SizedBox(height: FblaSpacing.xs),
          Text(
            isAdmin
                ? 'Enter the admin test code to grant admin access. This only works in debug builds.'
                : 'Enter the advisor access code provided by your school administrator to verify your account.',
            style: FblaFonts.body(
              fontSize: 15,
              color: FblaColors.darkTextSecond,
            ),
          )
              .animate(delay: 80.ms)
              .fadeIn(duration: 300.ms, curve: Curves.easeOut),
          const SizedBox(height: FblaSpacing.xl),

          _StyledTextField(
            controller: _advisorCodeCtrl,
            label: isAdmin ? 'Admin test code' : 'Advisor code',
            icon: Icons.vpn_key_outlined,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _handleAdvisorCode(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (isAdmin ? 'Please enter the admin test code.' : 'Please enter your advisor code.')
                : null,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: FblaSpacing.md),
            _ErrorBanner(message: _errorMessage!),
          ],

          const SizedBox(height: FblaSpacing.xl),
          _SignupButton(
            label: 'Verify code',
            onPressed: _loading ? null : _handleAdvisorCode,
            loading: _loading,
            complete: _advisorCodeComplete,
          ),
          const SizedBox(height: FblaSpacing.md),
          Container(
            padding: const EdgeInsets.all(FblaSpacing.md),
            decoration: BoxDecoration(
              color: FblaColors.secondary.withAlpha(10),
              borderRadius: BorderRadius.circular(FblaRadius.sm),
              border: Border.all(color: FblaColors.secondary.withAlpha(30)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: FblaColors.secondary),
                const SizedBox(width: FblaSpacing.sm),
                Expanded(
                  child: Text(
                    isAdmin
                        ? 'Admin access is for testing only. This option is hidden in production builds.'
                        : "Don't have a code? Contact your school's FBLA administrator.",
                    style: FblaFonts.monoLabel(
                      fontSize: 11,
                      color: FblaColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Advisor step 4: Confirm ───────────────────────────────────────────────
  Widget _buildAdvisorConfirmStep() {
    final email = _emailCtrl.text.trim();
    final isAdmin = _selectedRole == 'admin';
    return Column(
      key: const ValueKey('advisorConfirm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: FblaColors.success.withAlpha(20),
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: Border.all(color: FblaColors.success.withAlpha(50)),
          ),
          child: const Icon(Icons.check_circle_outline,
              size: 36, color: FblaColors.success),
        )
            .animate()
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .scaleXY(begin: 0.85, end: 1.0, duration: 300.ms, curve: Curves.easeOut),
        const SizedBox(height: FblaSpacing.lg),
        Text('You\'re verified!',
            style: FblaFonts.display(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: FblaColors.darkTextPrimary,
            ))
            .animate(delay: 60.ms)
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
        const SizedBox(height: FblaSpacing.xs),
        Text(
          isAdmin
              ? 'Admin access granted. You have full control over events, announcements, and members.'
              : 'Your advisor status has been confirmed. You\'ll have access to create announcements, events, and manage your chapter members.',
          style: FblaFonts.body(
            fontSize: 15,
            color: FblaColors.darkTextSecond,
          ),
        )
            .animate(delay: 80.ms)
            .fadeIn(duration: 300.ms, curve: Curves.easeOut),
        const SizedBox(height: FblaSpacing.xl),

        // Account summary card
        Container(
          padding: const EdgeInsets.all(FblaSpacing.lg),
          decoration: BoxDecoration(
            color: FblaColors.darkSurfaceHigh,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: Border.all(color: FblaColors.darkOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account details',
                  style: FblaFonts.monoLabel(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: FblaColors.darkTextSecond,
                  )),
              const SizedBox(height: FblaSpacing.md),
              _ConfirmRow(icon: Icons.email_outlined, label: 'Email', value: email),
              const Divider(height: FblaSpacing.lg),
              _ConfirmRow(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: isAdmin ? 'Admin (Test)' : 'Chapter Advisor'),
            ],
          ),
        )
            .animate(delay: 120.ms)
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),

        const SizedBox(height: FblaSpacing.xl),
        _SignupButton(
          label: 'Enter FBLA Connect',
          onPressed: _handleAdvisorConfirm,
        ),
      ],
    );
  }

  // ── Tour / Welcome screen ─────────────────────────────────────────────────
  Widget _buildTourScreen() {
    final isAdvisor = _selectedRole == 'advisor';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FblaGradient.brand),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FblaSpacing.xl),
            child: Column(
              children: [
                const Spacer(),
                // Logo badge — new brand icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo_128.png',
                    width: 88,
                    height: 88,
                    filterQuality: FilterQuality.high,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                    .scaleXY(begin: 0.8, end: 1.0, duration: 400.ms, curve: Curves.easeOut),
                const SizedBox(height: FblaSpacing.xl),
                Text(
                  isAdvisor ? 'Welcome, Advisor!' : 'Welcome to FBLA Connect!',
                  style: FblaFonts.display(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate(delay: 80.ms)
                    .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut),
                const SizedBox(height: FblaSpacing.md),
                Text(
                  isAdvisor
                      ? 'You can now create announcements, manage events, post resources in the Hub, and keep your chapter connected.'
                      : 'Stay connected with your chapter, track events, access study resources, and collaborate with fellow FBLA leaders.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(200),
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate(delay: 120.ms)
                    .fadeIn(duration: 400.ms, curve: Curves.easeOut),
                const SizedBox(height: FblaSpacing.xxl),

                // Feature highlights
                ..._tourFeatures(isAdvisor).asMap().entries.map((e) => _TourFeatureRow(
                      icon: e.value.$1,
                      label: e.value.$2,
                      delay: 160 + e.key * 60,
                    )),

                const Spacer(),

                _SignupButton(
                  label: "Let's go →",
                  onPressed: _goToApp,
                )
                    .animate(delay: const Duration(milliseconds: 500))
                    .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut),
                const SizedBox(height: FblaSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<(IconData, String)> _tourFeatures(bool isAdvisor) {
    if (isAdvisor) {
      return [
        (Icons.campaign_outlined, 'Post announcements to your chapter'),
        (Icons.event_outlined, 'Create and manage chapter events'),
        (Icons.library_books_outlined, 'Share resources in the Hub'),
        (Icons.people_outlined, 'Keep your members connected'),
      ];
    }
    return [
      (Icons.feed_outlined, 'See posts from your chapter'),
      (Icons.event_outlined, 'Track upcoming events & competitions'),
      (Icons.library_books_outlined, 'Access study guides and resources'),
      (Icons.chat_bubble_outline, 'Message fellow members'),
    ];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ══════════════════════════════════════════════════════════════════════════════

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: FblaMotion.press,
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _ctrl.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            border: Border.all(
              color: widget.color.withAlpha(50),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(FblaSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(18),
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                ),
                child: Icon(widget.icon, color: widget.color, size: 26),
              ),
              const SizedBox(width: FblaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: FblaFonts.label(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: FblaFonts.body(
                        fontSize: 12,
                        color: FblaColors.darkTextSecond,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FblaSpacing.sm),
              Icon(Icons.arrow_forward_ios, size: 14, color: widget.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyledTextField extends StatefulWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixWidget,
    this.onFieldSubmitted,
    this.onChanged,
    this.validator,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffixIcon;
  /// When provided, replaces the default prefix `Icon(icon)`. Used to slot
  /// in a custom prefix like an animated mascot.
  final Widget? prefixWidget;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  @override
  State<_StyledTextField> createState() => _StyledTextFieldState();
}

class _StyledTextFieldState extends State<_StyledTextField> {
  FocusNode? _internalFocus;
  bool _isFocused = false;

  FocusNode get _focus => widget.focusNode ?? _internalFocus!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocus = FocusNode();
    }
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _isFocused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      obscureText: widget.obscureText,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      style: FblaFonts.body(
        fontSize: 15,
        color: FblaColors.darkTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        // Unified prefix slot: same padding + constraints regardless of
        // whether we're rendering the default icon or a custom prefix
        // widget (like the padlock mascot). Keeps the email field and
        // password fields identical in width / height.
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6),
          child: widget.prefixWidget ??
              Icon(widget.icon, size: 22),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: _isFocused
            ? FblaColors.darkSurfaceHigh.withAlpha(200)
            : FblaColors.darkSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: BorderSide(color: FblaColors.darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: BorderSide(color: FblaColors.darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: const BorderSide(color: FblaColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: const BorderSide(color: FblaColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: const BorderSide(color: FblaColors.error, width: 2),
        ),
      ),
    );
  }
}

/// A typeable, autocomplete-style field for picking one row from a
/// Supabase-backed list. Users can type to filter by name (or id for
/// districts), or tap the dropdown arrow to browse.
///
/// Entries are `Map<String, dynamic>` with at minimum `id` and `name`
/// fields (both String). Passing [selectedId] pre-fills the input with
/// the matching name; [onSelected] fires once the user commits a choice
/// from the overlay. [onCleared] fires when the user wipes the input.
class _TypeableSearchField extends StatefulWidget {
  const _TypeableSearchField({
    required this.label,
    required this.icon,
    required this.entries,
    required this.onSelected,
    this.onCleared,
    this.selectedId,
    this.hintText,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final List<Map<String, dynamic>> entries;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCleared;
  final String? selectedId;
  final String? hintText;
  final bool enabled;

  @override
  State<_TypeableSearchField> createState() => _TypeableSearchFieldState();
}

class _TypeableSearchFieldState extends State<_TypeableSearchField> {
  late TextEditingController _ctrl;
  late FocusNode _focus;
  bool _isFocused = false;
  bool _showingAll = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _labelForId(widget.selectedId) ?? '');
    _focus = FocusNode();
    _focus.addListener(() {
      if (!mounted) return;
      setState(() => _isFocused = _focus.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _TypeableSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External state (district cleared → chapter cleared) needs to
    // reflect in the text field.
    if (oldWidget.selectedId != widget.selectedId) {
      final next = _labelForId(widget.selectedId) ?? '';
      if (_ctrl.text != next) {
        _ctrl.text = next;
        _ctrl.selection =
            TextSelection.collapsed(offset: _ctrl.text.length);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String? _labelForId(String? id) {
    if (id == null) return null;
    final match = widget.entries.firstWhere(
      (e) => e['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    final name = match['name'];
    return name is String && name.isNotEmpty ? name : null;
  }

  List<Map<String, dynamic>> _filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || _showingAll) {
      return widget.entries.take(80).toList();
    }
    return widget.entries.where((e) {
      final name = (e['name'] as String? ?? '').toLowerCase();
      final id   = (e['id']   as String? ?? '').toLowerCase();
      return name.contains(q) || id.contains(q);
    }).take(80).toList();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;

    return RawAutocomplete<Map<String, dynamic>>(
      textEditingController: _ctrl,
      focusNode: _focus,
      displayStringForOption: (o) => (o['name'] as String?) ?? '',
      optionsBuilder: (TextEditingValue tev) {
        if (disabled) return const Iterable.empty();
        return _filter(tev.text);
      },
      onSelected: (option) {
        final id   = option['id']   as String?;
        final name = option['name'] as String?;
        if (id == null) return;
        setState(() {
          _ctrl.text = name ?? '';
          _ctrl.selection =
              TextSelection.collapsed(offset: _ctrl.text.length);
          _showingAll = false;
        });
        widget.onSelected(id);
        _focus.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: !disabled,
          onChanged: (v) {
            if (_showingAll) setState(() => _showingAll = false);
            // Clearing the field should also clear the selection.
            if (v.trim().isEmpty && widget.selectedId != null) {
              widget.onCleared?.call();
            }
          },
          style: FblaFonts.body(
            fontSize: 15,
            color: disabled
                ? FblaColors.darkTextTertiary
                : FblaColors.darkTextPrimary,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            hintStyle: FblaFonts.body(
              fontSize: 13,
              color: FblaColors.darkTextTertiary,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: disabled
                  ? FblaColors.darkTextTertiary
                  : (_isFocused
                      ? FblaColors.primary
                      : FblaColors.darkTextSecond),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_ctrl.text.isNotEmpty && !disabled)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: FblaColors.darkTextSecond,
                    onPressed: () {
                      setState(() {
                        _ctrl.clear();
                        _showingAll = false;
                      });
                      widget.onCleared?.call();
                    },
                  ),
                IconButton(
                  tooltip: 'Browse all',
                  icon: Icon(
                    _showingAll
                        ? Icons.arrow_drop_up_rounded
                        : Icons.arrow_drop_down_rounded,
                    size: 26,
                  ),
                  color: disabled
                      ? FblaColors.darkTextTertiary
                      : FblaColors.darkTextSecond,
                  onPressed: disabled
                      ? null
                      : () {
                          setState(() {
                            _showingAll = !_showingAll;
                            // Nudge the autocomplete to recompute options.
                            _ctrl.selection = TextSelection.collapsed(
                                offset: _ctrl.text.length);
                          });
                          if (_showingAll) {
                            focusNode.requestFocus();
                          }
                        },
                ),
              ],
            ),
            filled: true,
            fillColor: disabled
                ? FblaColors.darkSurfaceHigh.withAlpha(80)
                : (_isFocused
                    ? FblaColors.darkSurfaceHigh.withAlpha(200)
                    : FblaColors.darkSurfaceHigh),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md),
              borderSide: BorderSide(color: FblaColors.darkOutline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md),
              borderSide: BorderSide(color: FblaColors.darkOutline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md),
              borderSide: const BorderSide(color: FblaColors.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md),
              borderSide: BorderSide(color: FblaColors.darkOutline.withAlpha(80)),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            color: FblaColors.darkSurfaceHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(FblaSpacing.md),
                      child: Text(
                        'No matches. Check your spelling or pick a different district.',
                        style: FblaFonts.body(
                          fontSize: 13,
                          color: FblaColors.darkTextSecond,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: FblaColors.darkOutline.withAlpha(80),
                      ),
                      itemBuilder: (context, i) {
                        final option = list[i];
                        final name = option['name'] as String? ?? '';
                        final id   = option['id']   as String? ?? '';
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: FblaSpacing.md,
                              vertical: FblaSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: FblaFonts.body(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: FblaColors.darkTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (id.isNotEmpty)
                                        Text(
                                          id,
                                          style: FblaFonts.monoLabel(
                                            fontSize: 10,
                                            color:
                                                FblaColors.darkTextTertiary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: FblaColors.darkTextTertiary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _StyledDropdown extends StatefulWidget {
  const _StyledDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    this.itemValues,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final List<dynamic>? itemValues;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_StyledDropdown> createState() => _StyledDropdownState();
}

class _StyledDropdownState extends State<_StyledDropdown> {
  late FocusNode _focus;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() => setState(() => _isFocused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemValues = widget.itemValues ?? widget.items;
    // Use `String?` as the generic so a null entry (e.g. the
    // "— None / not sure —" option in the chapter step) is legal.
    // The previous `DropdownButtonFormField<String>` + `as String`
    // cast crashed the entire chapter screen with
    // "type 'Null' is not a subtype of type 'String' in type cast"
    // because `itemValues[0]` is null for the "None" option.
    return DropdownButtonFormField<String?>(
      value: widget.value,
      focusNode: _focus,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        filled: true,
        fillColor: _isFocused
            ? FblaColors.darkSurfaceHigh.withAlpha(200)
            : FblaColors.darkSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: BorderSide(color: FblaColors.darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: BorderSide(color: FblaColors.darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: const BorderSide(color: FblaColors.primary, width: 2),
        ),
      ),
      isExpanded: true,
      items: List.generate(
        widget.items.length,
        (i) {
          final raw = itemValues[i];
          // Accept String or null; coerce anything else (defensive)
          // to its string form so one bad row never red-screens us.
          final String? v = raw is String
              ? raw
              : (raw == null ? null : raw.toString());
          return DropdownMenuItem<String?>(
            value: v,
            child: Text(
              widget.items[i],
              style: FblaFonts.body(
                fontSize: 15,
                color: FblaColors.darkTextPrimary,
              ),
            ),
          );
        },
      ),
      onChanged: (v) => widget.onChanged(v),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: FblaColors.primary),
        const SizedBox(width: FblaSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: FblaFonts.monoLabel(
                  fontSize: 11,
                  color: FblaColors.darkTextSecond,
                  fontWeight: FontWeight.w500,
                )),
            Text(value,
                style: FblaFonts.label(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FblaColors.darkTextPrimary,
                )),
          ],
        ),
      ],
    );
  }
}

class _TourFeatureRow extends StatelessWidget {
  const _TourFeatureRow({
    required this.icon,
    required this.label,
    this.delay = 0,
  });

  final IconData icon;
  final String label;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FblaSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(16),
              borderRadius: BorderRadius.circular(FblaRadius.md),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Icon(icon, size: 20, color: FblaColors.secondaryLight),
          ),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(220),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .slideX(begin: -0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final done = currentStep > i ~/ 2;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                decoration: BoxDecoration(
                  gradient: done
                      ? const LinearGradient(
                          colors: [FblaColors.secondary, FblaColors.secondaryLight],
                        )
                      : null,
                  color: done ? null : FblaColors.darkOutline,
                  borderRadius: BorderRadius.circular(FblaRadius.full),
                ),
              ),
            ),
          );
        }

        final step   = i ~/ 2;
        final done   = currentStep > step;
        final active = currentStep == step;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (done || active)
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [FblaColors.secondary, FblaColors.secondaryLight],
                      )
                    : null,
                color: (done || active) ? null : FblaColors.darkSurfaceHigh,
                border: active
                    ? Border.all(color: FblaColors.secondary, width: 2)
                    : null,
                boxShadow: active ? FblaShadow.goldGlow : null,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : Text(
                        '${step + 1}',
                        style: FblaFonts.monoLabel(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : FblaColors.darkTextTertiary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            if (step < labels.length)
              Text(
                labels[step].toUpperCase(),
                style: FblaFonts.monoTag(
                  fontSize: 11,
                  color: active ? FblaColors.secondary : FblaColors.darkTextSecond,
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: FblaColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(FblaRadius.sm),
        border: Border.all(color: FblaColors.error.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline, color: FblaColors.error, size: 16),
          ),
          const SizedBox(width: FblaSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: FblaFonts.body(
                fontSize: 13,
                color: FblaColors.error,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, curve: Curves.easeOut)
        .slideY(begin: -0.1, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }
}

/// Gold gradient press-scale CTA — matches _SignInButton in login_screen.dart.
class _SignupButton extends StatefulWidget {
  const _SignupButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.complete = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// When true, the step's inputs are all valid and the button dresses up
  /// with a stronger gold gradient + bloom glow. When false, the button
  /// stays calm (subtle tint + primary-colored label) until the user
  /// finishes the step. Pressability is controlled separately by
  /// [onPressed] so we never block submission on validation.
  final bool complete;

  @override
  State<_SignupButton> createState() => _SignupButtonState();
}

class _SignupButtonState extends State<_SignupButton>
    with SingleTickerProviderStateMixin {
  // Emil-style ease-out — cubic-bezier(0.23, 1, 0.32, 1). Stronger
  // deceleration than Curves.easeOutCubic, no bounce. Used everywhere
  // motion happens on this button so the feel stays coherent.
  static const Cubic _emilEaseOut = Cubic(0.23, 1, 0.32, 1);

  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 180),
    );
    // Press dip — 1.0 → 0.97. Tight, confident, no overshoot.
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: _emilEaseOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final loading = widget.loading;
    final hovering = !disabled && !loading && _hovering;
    // Three visual states:
    //   • disabled / loading → muted grey
    //   • complete OR hovering (and enabled) → gold gradient + full glow
    //   • enabled but not complete → subtle outlined variant as a gentle
    //     nudge, while staying clickable.
    final showGold = !disabled && !loading && (widget.complete || _hovering);

    final Color labelColor;
    if (disabled || loading) {
      labelColor = FblaColors.darkTextTertiary;
    } else if (showGold) {
      labelColor = FblaColors.primaryDark;
    } else {
      labelColor = FblaColors.primary;
    }

    return MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      // setState unconditionally so stale `_hovering` state from widget
      // rebuilds can never wedge us into a "still showing hover after
      // the cursor left" bug.
      onEnter: (_) {
        if (!mounted || disabled) return;
        setState(() => _hovering = true);
      },
      onExit: (_) {
        if (!mounted) return;
        setState(() => _hovering = false);
      },
      // Make sure child misses don't swallow pointer events.
      opaque: false,
      child: GestureDetector(
        onTapDown: disabled
            ? null
            : (_) {
                _ctrl.forward();
                HapticFeedback.mediumImpact();
              },
        onTapUp: disabled
            ? null
            : (_) {
                _ctrl.reverse();
                widget.onPressed!();
              },
        onTapCancel: () => _ctrl.reverse(),
        // ── Hover lift, driven by an explicit tween ─────────────────────
        //
        // TweenAnimationBuilder gives us a single animation pass with a
        // value `t` that smoothly ramps 0 → 1 as the pointer enters and
        // 1 → 0 as it leaves. Everything hover-related is derived from
        // `t` so lift, scale, glow, and border all move in lockstep and
        // the animation is impossible to miss. Using an explicit tween
        // (instead of stacked AnimatedScale + AnimatedSlide) also keeps
        // the widget tree flatter, which makes hit-testing more
        // reliable on Flutter for web + desktop.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: hovering ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 220),
          curve: _emilEaseOut,
          builder: (context, t, _) {
            // Strong lift: −4 px translate combined with a 1.0→1.05
            // scale. Doubled compared to the old 1.035/−2 values — the
            // previous version was so subtle users were convinced it
            // wasn't firing at all.
            final yOffset = -4.0 * t;
            final scale = 1.0 + 0.05 * t;

            // Decoration lerps so the hover state is visually louder
            // than before: border brightens, gold glow blooms larger
            // and warmer, and the surface lifts off the background.
            final BoxDecoration decoration;
            if (disabled || loading) {
              decoration = BoxDecoration(
                color: FblaColors.darkOutline,
                borderRadius: BorderRadius.circular(FblaRadius.md),
              );
            } else if (showGold) {
              decoration = BoxDecoration(
                gradient: FblaGradient.goldShimmer,
                borderRadius: BorderRadius.circular(FblaRadius.md),
                border: Border.all(
                  color: Color.lerp(
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.35),
                    t,
                  )!,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x33F5A623),
                      const Color(0x80F5A623),
                      t,
                    )!,
                    blurRadius: 20 + 24 * t,
                    offset: Offset(0, 4 + 6 * t),
                  ),
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x1AF5A623),
                      const Color(0x44F5A623),
                      t,
                    )!,
                    blurRadius: 40 + 40 * t,
                    offset: Offset(0, 8 + 8 * t),
                  ),
                ],
              );
            } else {
              // Enabled but step incomplete — still react to hover
              // by brightening the border + surface so the user gets
              // feedback that the control is interactive.
              decoration = BoxDecoration(
                color: Color.lerp(
                  FblaColors.darkSurfaceHigh,
                  FblaColors.primary.withValues(alpha: 0.16),
                  t,
                ),
                borderRadius: BorderRadius.circular(FblaRadius.md),
                border: Border.all(
                  color: FblaColors.primary.withValues(alpha: 0.45 + 0.45 * t),
                  width: 1.2 + 0.6 * t,
                ),
              );
            }

            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Transform.scale(
                scale: scale,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    height: 52,
                    decoration: decoration,
                    child: Center(
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              curve: _emilEaseOut,
                              style: FblaFonts.label(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: labelColor,
                                letterSpacing: 0.2,
                              ),
                              child: Text(widget.label),
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
