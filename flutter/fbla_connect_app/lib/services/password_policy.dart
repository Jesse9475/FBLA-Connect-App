/// Shared password policy for FBLA Connect.
///
/// Requirements (as of April 2026):
///   • minimum 6 characters
///   • at least one lowercase letter (a-z)
///   • at least one uppercase letter (A-Z)
///   • at least one digit (0-9)
///   • at least one symbol (non-alphanumeric)
///
/// Used by the signup flow and the "Change password" screen so both surfaces
/// enforce the exact same rule, show the same error copy, and drive the same
/// live requirements checklist.
library;

/// A single testable requirement, used by the checklist widget to render a
/// live list of rules and tick them off as the user types.
class PasswordRule {
  const PasswordRule({required this.label, required this.test});
  final String label;
  final bool Function(String value) test;
}

/// The canonical rule set, in display order.
final List<PasswordRule> passwordRules = [
  PasswordRule(
    label: 'At least 6 characters',
    test: (v) => v.length >= 6,
  ),
  PasswordRule(
    label: 'One lowercase letter',
    test: (v) => RegExp(r'[a-z]').hasMatch(v),
  ),
  PasswordRule(
    label: 'One uppercase letter',
    test: (v) => RegExp(r'[A-Z]').hasMatch(v),
  ),
  PasswordRule(
    label: 'One number',
    test: (v) => RegExp(r'\d').hasMatch(v),
  ),
  PasswordRule(
    label: r'One symbol (e.g. ! @ # $ %)',
    test: (v) => RegExp(r'[^A-Za-z0-9]').hasMatch(v),
  ),
];

/// Short one-liner version — used as helper text when the full checklist is
/// not shown (e.g. a compact field).
const String passwordPolicyHelp =
    'At least 6 characters with uppercase, lowercase, a number, and a symbol.';

/// True when [value] passes every rule in [passwordRules]. Convenience
/// predicate for UI (e.g. driving the padlock mascot to "locked" once the
/// password is strong enough).
bool passwordMeetsPolicy(String value) {
  for (final rule in passwordRules) {
    if (!rule.test(value)) return false;
  }
  return true;
}

/// Returns `null` when [value] meets every rule, otherwise a short error
/// message keyed to the first failed rule — suitable for a TextFormField
/// validator.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required.';
  for (final rule in passwordRules) {
    if (!rule.test(value)) {
      // Keep error copy short and actionable.
      return switch (rule.label) {
        'At least 6 characters' => 'Must be at least 6 characters.',
        'One lowercase letter' => 'Must include a lowercase letter.',
        'One uppercase letter' => 'Must include an uppercase letter.',
        'One number' => 'Must include a number.',
        _ => r'Must include a symbol (e.g. ! @ # $ %).',
      };
    }
  }
  return null;
}
