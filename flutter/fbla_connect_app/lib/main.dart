import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/signup_screen.dart';
import 'services/accessibility_settings.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

/// Entry point — initialise Supabase then run the app.
///
/// Hardened so the UI ALWAYS renders, even on a slow or captive-portal
/// network where DNS / TLS to Supabase can hang. Every awaited call has a
/// hard timeout; if any one of them trips, we log, swallow, and still call
/// runApp(). The AuthGate downstream handles missing sessions gracefully,
/// and the API layer surfaces "couldn't reach server" banners normally —
/// the user sees the app, not a black launch screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers for uncaught exceptions and async errors.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  // 1. Accessibility prefs — disk-only, fast. A half-second cap is
  //    plenty and guards against the rare case of a hung SharedPreferences.
  await _safely(
    () => AccessibilitySettings.instance.load(),
    timeout: const Duration(milliseconds: 500),
    label: 'a11y.load',
  );

  // 2. Auto-start the Flask backend if it isn't already running. This is a
  //    desktop-only convenience; its own internals cap at ~4 s, but we
  //    still wrap it so a wedged child process can't block the UI.
  await _safely(
    _ensureBackendRunning,
    timeout: const Duration(seconds: 5),
    label: 'backend.ensure',
  );

  // 3. Supabase init — the most likely culprit on a restricted/new wifi
  //    network. DNS can hang for a minute+ on captive portals, so a 4 s cap
  //    keeps us honest. If it fails, supabase.auth.currentSession will be
  //    null and AuthGate will just land on the Login screen.
  await _safely(
    () => Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
      // IMPORTANT: implicit flow is required for 6-digit OTP codes.
      // PKCE would send magic links instead.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    ),
    timeout: const Duration(seconds: 4),
    label: 'supabase.init',
  );

  // 4. Seed the ApiService with an existing token if one is stored on disk.
  //    Purely local work; tiny timeout is defense-in-depth.
  await _safely(
    () => ApiService.instance.init(),
    timeout: const Duration(milliseconds: 500),
    label: 'api.init',
  );

  // Wrap runApp in runZonedGuarded to catch async errors.
  runZonedGuarded(() {
    runApp(const FblaConnectApp());
  }, (error, stack) {
    debugPrint('Zoned error: $error\n$stack');
  });
}

/// Runs [body] with a hard timeout. Any exception or timeout is logged to
/// stderr and swallowed — callers can assume control returns within
/// [timeout] regardless of what the task does. This is the primary reason
/// the app can survive a new / hostile network instead of hanging on a
/// black launch screen.
Future<void> _safely(
  Future<void> Function() body, {
  required Duration timeout,
  required String label,
}) async {
  try {
    await body().timeout(timeout);
  } on TimeoutException {
    // Network or DNS is wedged — proceed without this piece of init.
    // The app keeps working in an offline / unauthenticated state.
    stderr.writeln('[boot] $label timed out after ${timeout.inMilliseconds}ms');
  } catch (e) {
    stderr.writeln('[boot] $label failed: $e');
  }
}

/// Starts the Flask backend automatically if it isn't already listening on
/// port 5050.  Finds [app.py] by walking up from the Dart script path
/// (debug/JIT mode) or the resolved executable (AOT/release mode).
Future<void> _ensureBackendRunning() async {
  const backendPort = 5050;

  // 1. Probe the port — if Flask is already up, do nothing.
  try {
    final socket = await Socket.connect(
      '127.0.0.1',
      backendPort,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
    return; // Already running.
  } catch (_) {
    // Not yet running — fall through to start it.
  }

  // 2. Locate app.py.
  //    In debug (flutter run) mode Platform.script is the URI of main.dart,
  //    which lives inside the project tree — walk up from there.
  //    In AOT/release builds fall back to Platform.resolvedExecutable.
  final appPyPath = _locateAppPy();
  if (appPyPath == null) return; // Can't find it — skip silently.

  final projectRoot = File(appPyPath).parent.path;

  // 3. Launch Flask as a detached background process.
  //    macOS apps inherit a minimal PATH — Homebrew python3 is NOT on it.
  //    Try known locations in order; fall back to a login-shell invocation
  //    which loads the user's full PATH (including /opt/homebrew/bin).
  final python3 = _findPython3();
  try {
    if (python3 != null) {
      await Process.start(
        python3,
        [appPyPath],
        workingDirectory: projectRoot,
        mode: ProcessStartMode.detached,
      );
    } else {
      // Login-shell fallback: sources ~/.zprofile / ~/.bash_profile so
      // Homebrew and pyenv are on the PATH.
      await Process.start(
        '/bin/bash',
        ['-lc', r'python3 "$@"', '--', appPyPath],
        workingDirectory: projectRoot,
        mode: ProcessStartMode.detached,
      );
    }
    // Poll until Flask is ready (avoids a fixed 2s sleep — unlocks as soon
    // as the server actually responds, up to a 3 s maximum).
    await _waitForBackend(backendPort);
  } catch (_) {
    // If something goes wrong the app will show its normal
    // "unable to reach server" state — no crash.
  }
}

/// Polls [port] on localhost every 200 ms until a TCP connection succeeds
/// or [maxWait] elapses.  Replaces the old `Future.delayed(2s)` so the UI
/// unlocks as soon as the server is actually ready.
Future<void> _waitForBackend(int port, {Duration maxWait = const Duration(seconds: 3)}) async {
  final deadline = DateTime.now().add(maxWait);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 200));
      socket.destroy();
      return; // Server is up.
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
  // Timed out — proceed anyway; the API layer will surface errors normally.
}

/// Tries several starting points and walks up the directory tree looking
/// for [app.py].  Returns the absolute path if found, otherwise null.
String? _locateAppPy() {
  // Priority 1: Platform.script — in `flutter run` debug mode this is the
  // URI of main.dart (e.g. .../FBLACONNECTNEW-1/flutter/.../lib/main.dart),
  // so walking up a few levels lands on the project root.
  try {
    final scriptPath = Platform.script.toFilePath();
    final found = _walkUpFor('app.py', scriptPath);
    if (found != null) return found;
  } catch (_) {}

  // Priority 2: Platform.resolvedExecutable — useful for AOT/release builds
  // where the .app bundle is inside the project tree.
  try {
    final found = _walkUpFor('app.py', Platform.resolvedExecutable);
    if (found != null) return found;
  } catch (_) {}

  return null;
}

/// Returns the absolute path of the first python3 binary found in common
/// macOS locations.  Returns null if none are found (caller uses login-shell).
String? _findPython3() {
  const candidates = [
    '/opt/homebrew/bin/python3', // Apple-Silicon Homebrew
    '/usr/local/bin/python3',    // Intel Homebrew
    '/usr/bin/python3',          // Xcode CLT shim (always present on macOS)
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// Walks up the directory tree from [startPath] looking for [filename].
String? _walkUpFor(String filename, String startPath, {int maxLevels = 15}) {
  var dir = Directory(File(startPath).parent.path);
  for (int i = 0; i < maxLevels; i++) {
    final candidate = File('${dir.path}/$filename');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break; // Reached filesystem root.
    dir = parent;
  }
  return null;
}

/// Convenience accessor for the Supabase client.
SupabaseClient get supabase => Supabase.instance.client;

/// Root app widget.  Listens to [AccessibilitySettings] so that toggling
/// "High-Contrast Dark Mode" instantly switches [MaterialApp.themeMode]
/// without a hot-restart.
class FblaConnectApp extends StatefulWidget {
  const FblaConnectApp({super.key});

  @override
  State<FblaConnectApp> createState() => _FblaConnectAppState();
}

class _FblaConnectAppState extends State<FblaConnectApp> {
  final _a11y = AccessibilitySettings.instance;

  @override
  void initState() {
    super.initState();
    _a11y.addListener(_onA11yChanged);
  }

  @override
  void dispose() {
    _a11y.removeListener(_onA11yChanged);
    super.dispose();
  }

  void _onA11yChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Tag the home tree with a key derived from the current themeMode +
    // color-blind type. When EITHER changes we want every screen to be
    // rebuilt from scratch so nothing keeps a stale `FblaColors.darkBg`
    // value baked in from the previous brightness. This is the
    // "hard-refresh on appearance change" the user explicitly asked
    // for; the small trade-off is that the navigator stack resets to
    // AuthGate's default route, which is correct because most stale
    // routes (e.g. a half-loaded chat) would render with the wrong
    // colors anyway.
    final tag = '${_a11y.themeMode.name}-${_a11y.colorBlindType}';
    final app = MaterialApp(
      title: 'FBLA Connect',
      debugShowCheckedModeBanner: false,
      theme: FblaTheme.light,
      darkTheme: FblaTheme.dark,
      themeMode: _a11y.themeMode,
      // Wrapping `home` in a Builder + ValueKey ensures the entire
      // descendant tree is reconstructed on theme change. Without this
      // key swap, screens that store color values in build-time
      // closures (every screen that uses `FblaColors.darkBg` directly
      // instead of `Theme.of(context)`) keep painting with the old
      // brightness until the user manually pops/pushes them.
      home: KeyedSubtree(
        key: ValueKey('app-tree-$tag'),
        child: const AuthGate(),
      ),
    );

    // Global color-blindness simulation filter. Keeps the original tree
    // but recolors everything rendered under it through a [ColorFilter].
    final filter = _a11y.colorFilter;
    if (filter == null) return app;
    return ColorFiltered(colorFilter: filter, child: app);
  }
}

/// Listens to Supabase auth-state changes and routes accordingly.
///
/// Routing table:
///   session present  → [HomeShell]
///   no session, first launch (onboarding not seen) → [OnboardingScreen]
///   no session, returning user (onboarding seen)   → [LoginScreen]
///
/// Unlike the old StatelessWidget approach, this widget re-reads the
/// onboarding flag every time the session changes, so sign-out always
/// lands on [LoginScreen] rather than replaying onboarding.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});


  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // null = still loading the flag from storage.
  bool? _onboardingSeen;
  StreamSubscription<AuthState>? _authSub;

  // Track the current session directly — no StreamBuilder needed.
  // Seeded from the persisted session on init, then kept in sync via
  // the auth state listener.
  Session? _currentSession;

  @override
  void initState() {
    super.initState();

    // Seed with existing session (supabase_flutter persists it to disk).
    // But DON'T trust an expired session — the SDK will try to refresh it
    // internally and sign out if the refresh token is also dead.  Showing
    // HomeShell for a dead session causes a jarring flash-then-sign-out.
    //
    // Defensive read: if Supabase.initialize() was skipped (e.g. the
    // startup timed out on a restricted wifi network), Supabase.instance
    // throws on access. Treat that as "no session" and continue to the
    // login screen rather than crashing the app into a black screen.
    Session? persisted;
    try {
      persisted = supabase.auth.currentSession;
    } catch (e) {
      debugPrint('[AUTH_GATE] Supabase not initialized yet: $e');
      persisted = null;
    }
    if (persisted != null && persisted.expiresAt != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          persisted.expiresAt! * 1000);
      if (expiresAt.isAfter(DateTime.now())) {
        _currentSession = persisted;
      } else {
        debugPrint('[AUTH_GATE] Persisted session is EXPIRED — ignoring');
        _currentSession = null;
      }
    } else {
      _currentSession = persisted;
    }

    _loadOnboarding();

    // Single auth listener: updates session state AND handles side effects.
    // Wrap subscription in a try/catch for the same reason — if Supabase
    // failed to initialize we skip the listener and the user stays on the
    // login screen. It'll re-attach after a hot-restart or next launch.
    try {
      _authSub = supabase.auth.onAuthStateChange.listen((event) {
      debugPrint('[AUTH_GATE] event=${event.event}, session=${event.session != null}');

      if (event.event == AuthChangeEvent.signedOut ||
          event.event == AuthChangeEvent.userDeleted) {
        if (mounted) setState(() => _currentSession = null);
        _loadOnboarding();
        return;
      }

      // For signedIn, tokenRefreshed, etc. — update the session.
      final session = event.session ?? supabase.auth.currentSession;
      if (session != null) {
        ApiService.instance.setToken(session.accessToken);
      }
      if (mounted) setState(() => _currentSession = session);
      });
    } catch (e) {
      debugPrint('[AUTH_GATE] Skipped auth listener — Supabase not ready: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadOnboarding() async {
    final seen = await OnboardingScreen.hasBeenSeen();
    if (mounted) setState(() => _onboardingSeen = seen);
  }

  @override
  Widget build(BuildContext context) {
    // Still reading the flag from storage → show splash.
    if (_onboardingSeen == null) return const _SplashScreen();

    final session = _currentSession;
    debugPrint('[AUTH_GATE] build: session=${session != null}');

    if (session != null) {
      final meta = session.user.userMetadata;
      final onboardingComplete = meta?['onboarding_complete'] == true
          || _accountIsLikelyComplete(session.user);
      debugPrint('[AUTH_GATE] onboardingComplete=$onboardingComplete');
      if (!onboardingComplete) {
        return const _IncompleteSetupGate();
      }
      return const HomeShell();
    }

    // No session → show login or onboarding.
    return _onboardingSeen! ? const LoginScreen() : const OnboardingScreen();
  }
}

/// Returns true if the account was likely created before the
/// [onboarding_complete] metadata flag was introduced (migration path).
///
/// Intentionally does NOT gate on [emailConfirmedAt] — many Supabase projects
/// disable email confirmation, in which case that field is always null even
/// for fully set-up accounts.  The 30-second threshold is enough to
/// distinguish a completed multi-step signup from a bare account creation.
///
/// If [updatedAt] is null (Supabase may not return it for all accounts) we
/// err on the side of letting the user in rather than blocking them.
bool _accountIsLikelyComplete(User user) {
  // updatedAt is null → Supabase didn't report it; assume setup is complete.
  if (user.updatedAt == null) return true;
  try {
    final created = DateTime.parse(user.createdAt);
    final updated = DateTime.parse(user.updatedAt!);
    // 30 s is enough — a fresh sign-up completes all steps in a few minutes.
    return updated.difference(created).inSeconds >= 30;
  } catch (_) {
    // If we can't parse dates, err on the side of letting the user in.
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Shown when a session exists but onboarding was never completed.
///
/// The user can either continue setting up their account (pushed to
/// [SignupScreen]) or delete their account and start fresh.
// ─────────────────────────────────────────────────────────────────────────────
class _IncompleteSetupGate extends StatefulWidget {
  const _IncompleteSetupGate();

  @override
  State<_IncompleteSetupGate> createState() => _IncompleteSetupGateState();
}

class _IncompleteSetupGateState extends State<_IncompleteSetupGate> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    try {
      // Sign out first — cleans up local state.
      // (A full server-side delete requires the admin key; signing out is
      // the safe client-side equivalent that prevents re-entry.)
      await supabase.auth.signOut();
    } catch (_) {
      // Even if sign-out fails, the AuthGate will re-evaluate on next build.
    }
    if (mounted) setState(() => _deleting = false);
  }

  void _continueSetup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => const SignupScreen(resumeMode: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FblaSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FblaColors.secondary.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: FblaColors.secondary.withAlpha(60), width: 2),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 36,
                  color: FblaColors.secondary,
                ),
              ),
              const SizedBox(height: FblaSpacing.lg),

              Text(
                'Setup Incomplete',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: FblaColors.darkTextPrimary,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FblaSpacing.sm),
              Text(
                'Your account was created but you haven\'t finished setting up your profile. Complete setup to use FBLA Connect.',
                style: TextStyle(
                  fontSize: 15,
                  color: FblaColors.darkTextSecond,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: FblaSpacing.xxl),

              // Continue setup
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _continueSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FblaColors.secondary,
                    foregroundColor: FblaColors.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                    ),
                  ),
                  child: const Text(
                    'Complete Setup',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: FblaSpacing.md),

              // Delete & start over
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _deleting ? null : _deleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FblaColors.error,
                    side: const BorderSide(color: FblaColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                    ),
                  ),
                  child: _deleting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FblaColors.error,
                          ),
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Delete Account & Start Over',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Branded loading screen shown on cold start.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FblaColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // FBLA logo mark — new brand icon
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo_128.png',
                width: 88,
                height: 88,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: FblaSpacing.lg),
            Text(
              'FBLA Connect',
              style: FblaFonts.heading(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: FblaColors.onPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: FblaSpacing.sm),
            Text(
              'Student business leaders. Connected.',
              style: TextStyle(
                fontSize: 13,
                color: FblaColors.onPrimary.withAlpha(180),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: FblaSpacing.xxl),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).brightness == Brightness.dark
                      ? FblaColors.secondary
                      : FblaColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
