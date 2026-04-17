import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted accessibility preferences for FBLA Connect.
///
/// Implements [ChangeNotifier] so the root [MaterialApp] can reactively
/// switch its [ThemeMode] when the user toggles High-Contrast Dark Mode.
///
/// Uses [SharedPreferences] for reliable persistence across all platforms,
/// including macOS without keychain entitlements.
///
/// Usage:
///   await AccessibilitySettings.instance.load();   // once in main()
///   AccessibilitySettings.instance.highContrastDark // read
///   await AccessibilitySettings.instance.setHighContrastDark(true); // write
class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._();

  static final AccessibilitySettings instance = AccessibilitySettings._();

  // Storage keys
  static const _kDarkMode     = 'a11y_dark_mode';
  static const _kAppearance   = 'a11y_appearance'; // 'system' | 'light' | 'dark'
  static const _kColorBlind   = 'a11y_color_blind';
  static const _kColorBlindType = 'a11y_color_blind_type';
  static const _kHeadings     = 'a11y_headings';
  static const _kLargeTargets = 'a11y_large_targets';

  /// Allowed color-blindness types. When set to anything other than
  /// 'none', a [ColorFilter] is applied at the app root to shift hues
  /// toward the confused-color axis so affected users can distinguish
  /// status colors, links, and icons.
  static const colorBlindTypes = [
    'none',
    'protanopia',    // red-blind
    'deuteranopia',  // green-blind
    'tritanopia',    // blue-blind
    'achromatopsia', // monochrome
  ];

  // In-memory values (defaults match screenshot's "off" state except headings)
  bool _highContrastDark   = false;
  /// Explicit appearance preference. Takes precedence over
  /// [_highContrastDark] when set to something other than 'system'. This
  /// lets users force Light mode even if the OS is set to dark.
  String _appearance       = 'system'; // 'system' | 'light' | 'dark'
  bool _colorBlindFriendly = false;
  String _colorBlindType   = 'none';
  bool _logicalHeadings    = true;   // on by default — safe, low-friction
  bool _largeTargets       = false;

  // Cache SharedPreferences instance to avoid repeated lookups
  SharedPreferences? _prefs;

  // ── Getters ────────────────────────────────────────────────────────────────

  /// When true the app forces dark theme regardless of the system setting.
  bool get highContrastDark => _highContrastDark;

  /// Status badges always include a text label (never color-only). Color-
  /// blind support is no longer user-toggleable — it's a baked-in part of
  /// the design system, so the getter always returns true.
  bool get colorBlindFriendly => true;

  /// Current color-blindness type: 'none', 'protanopia', 'deuteranopia',
  /// 'tritanopia', or 'achromatopsia'.
  String get colorBlindType => _colorBlindType;

  /// Returns a [ColorFilter] to apply at the app root that shifts the
  /// palette to help the selected color-blindness type distinguish
  /// confused colors. Returns null when the type is 'none'.
  ///
  /// Matrices are based on published daltonization LMS→RGB simulation
  /// approximations. They are intentionally mild so the app still looks
  /// like itself.
  ColorFilter? get colorFilter {
    switch (_colorBlindType) {
      case 'protanopia':
        return const ColorFilter.matrix([
          0.567, 0.433, 0.000, 0, 0,
          0.558, 0.442, 0.000, 0, 0,
          0.000, 0.242, 0.758, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case 'deuteranopia':
        return const ColorFilter.matrix([
          0.625, 0.375, 0.000, 0, 0,
          0.700, 0.300, 0.000, 0, 0,
          0.000, 0.300, 0.700, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case 'tritanopia':
        return const ColorFilter.matrix([
          0.950, 0.050, 0.000, 0, 0,
          0.000, 0.433, 0.567, 0, 0,
          0.000, 0.475, 0.525, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      case 'achromatopsia':
        return const ColorFilter.matrix([
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0.299, 0.587, 0.114, 0, 0,
          0,     0,     0,     1, 0,
        ]);
      default:
        return null;
    }
  }

  /// Event lists are always grouped under date-header rows for screen-
  /// reader hierarchy. No longer user-toggleable.
  bool get logicalHeadings => true;

  /// Interactive elements always meet WCAG 2.5.5 (≥ 48 dp touch targets).
  /// No longer user-toggleable.
  bool get largeTargets => true;

  /// Current explicit appearance setting. Callers should prefer this
  /// over [highContrastDark] when they need three-way state.
  String get appearance => _appearance;

  /// Derived [ThemeMode] for [MaterialApp.themeMode].
  ///
  /// Resolution order:
  ///   1. Explicit [_appearance] preference ('light' | 'dark' | 'system').
  ///   2. Legacy [_highContrastDark] flag (kept for backwards compat).
  ///   3. Otherwise follow the system.
  ThemeMode get themeMode {
    switch (_appearance) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return _highContrastDark ? ThemeMode.dark : ThemeMode.system;
    }
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  /// Load persisted values from SharedPreferences.  Call once during [main].
  /// Storage errors are swallowed so the app always starts with valid defaults.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _highContrastDark   = _prefs?.getBool(_kDarkMode)     ?? false;
      // Three-way appearance takes precedence if set. Fall back to a
      // value derived from the legacy flag so existing users don't lose
      // their dark-mode choice when they upgrade.
      final stored = _prefs?.getString(_kAppearance);
      if (stored == 'light' || stored == 'dark' || stored == 'system') {
        _appearance = stored!;
      } else {
        _appearance = _highContrastDark ? 'dark' : 'system';
      }
      _colorBlindFriendly = _prefs?.getBool(_kColorBlind)   ?? false;
      final storedType = _prefs?.getString(_kColorBlindType);
      if (storedType != null && colorBlindTypes.contains(storedType)) {
        _colorBlindType = storedType;
      }
      // logicalHeadings defaults true — only flip if explicitly stored false
      _logicalHeadings    = _prefs?.getBool(_kHeadings)     ?? true;
      _largeTargets       = _prefs?.getBool(_kLargeTargets) ?? false;
    } catch (e) {
      // SharedPreferences unavailable. Defaults remain in effect.
      debugPrint('[A11Y] Storage load failed: $e');
    }
    notifyListeners();
  }

  // ── Setters ────────────────────────────────────────────────────────────────

  Future<void> setHighContrastDark(bool value) async {
    if (_highContrastDark == value) return;
    _highContrastDark = value;
    // Keep the three-way appearance in lockstep so the legacy toggle
    // in the settings screen still functions as a direct Light↔Dark switch.
    _appearance = value ? 'dark' : 'system';
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kDarkMode, value);
      await _prefs!.setString(_kAppearance, _appearance);
    } catch (e) {
      debugPrint('[A11Y] Failed to persist dark mode: $e');
    }
  }

  /// Set the explicit appearance preference. Accepts 'system', 'light',
  /// or 'dark'. Any other value is coerced to 'system'.
  Future<void> setAppearance(String value) async {
    final normalized = (value == 'light' || value == 'dark') ? value : 'system';
    if (_appearance == normalized) return;
    _appearance = normalized;
    // Keep legacy flag in sync: 'dark' → true, anything else → false.
    _highContrastDark = normalized == 'dark';
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kAppearance, normalized);
      await _prefs!.setBool(_kDarkMode, _highContrastDark);
    } catch (e) {
      debugPrint('[A11Y] Failed to persist appearance: $e');
    }
  }

  Future<void> setColorBlindFriendly(bool value) async {
    if (_colorBlindFriendly == value) return;
    _colorBlindFriendly = value;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kColorBlind, value);
    } catch (e) {
      debugPrint('[A11Y] Failed to persist color-blind mode: $e');
    }
  }

  /// Set the color-blindness simulation type. Accepts one of
  /// [colorBlindTypes]; any other value is coerced to 'none'.
  Future<void> setColorBlindType(String value) async {
    final normalized = colorBlindTypes.contains(value) ? value : 'none';
    if (_colorBlindType == normalized) return;
    _colorBlindType = normalized;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kColorBlindType, normalized);
    } catch (e) {
      debugPrint('[A11Y] Failed to persist color-blind type: $e');
    }
  }

  Future<void> setLogicalHeadings(bool value) async {
    if (_logicalHeadings == value) return;
    _logicalHeadings = value;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kHeadings, value);
    } catch (e) {
      debugPrint('[A11Y] Failed to persist heading structure: $e');
    }
  }

  Future<void> setLargeTargets(bool value) async {
    if (_largeTargets == value) return;
    _largeTargets = value;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kLargeTargets, value);
    } catch (e) {
      debugPrint('[A11Y] Failed to persist large targets: $e');
    }
  }
}
