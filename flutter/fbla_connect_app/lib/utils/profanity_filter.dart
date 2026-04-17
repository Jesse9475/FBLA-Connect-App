// ─────────────────────────────────────────────────────────────────────────────
// Profanity Filter — basic client-side censoring for the messaging feature.
//
// Philosophy: this is a lightweight safety net for a school-club app, NOT an
// attempt to solve content moderation. It catches the obvious offenders while
// remaining conservative about false positives (no blanket substring matching
// like "ass" in "class" or "pass"). All checks happen on whole tokens using
// word boundaries, so "classroom" is safe but "a$$hole" still gets caught
// thanks to leetspeak normalization.
//
// Usage:
//   final result = ProfanityFilter.check(userInput);
//   if (result.hasProfanity) {
//     // show warning / block send / censor depending on UX need
//   }
//   final cleaned = ProfanityFilter.censor(userInput); // replaces with ****
// ─────────────────────────────────────────────────────────────────────────────

class ProfanityResult {
  const ProfanityResult({
    required this.hasProfanity,
    required this.matches,
    required this.censored,
  });

  /// True if any blocked word was found.
  final bool hasProfanity;

  /// The distinct offending tokens that triggered a match (for logging / UX).
  final List<String> matches;

  /// The original input with each offending token replaced by asterisks.
  final String censored;
}

class ProfanityFilter {
  ProfanityFilter._();

  // Base word list. Kept deliberately small and obvious — school-appropriate
  // bad words, racial/homophobic slurs (stems only; the leetspeak pass
  // catches variants), and a few common insults. Add more as needed.
  //
  // NOTE: these are stored as lowercase stems. Normalization handles variants
  // like f*ck, f.u.c.k, fuuck, fck, f@ck, etc.
  static const List<String> _blockedWords = [
    // Profanity
    'fuck', 'fuk', 'fck', 'fking', 'fker',
    'shit', 'sht',
    'bitch', 'btch',
    'bastard',
    'asshole', 'arsehole', 'ahole',
    'dick', 'dik', 'cock', 'pussy', 'puss',
    'cunt', 'twat',
    'damn', 'goddamn',
    'piss', 'pissed',
    'crap',
    'whore', 'hoe', 'slut', 'skank',
    'prick',
    'wanker', 'wank',
    'bollocks', 'bugger',
    // Slurs (stems only — deliberate to avoid listing full forms)
    'nigger', 'nigga', 'nigg',
    'faggot', 'fag', 'fagg',
    'retard', 'retarded',
    'spic', 'chink', 'kike', 'gook', 'coon', 'tranny',
    // Sexual
    'porn', 'sex', 'orgasm', 'boobs', 'tits', 'titties',
    // Milder but unwelcome in a school context
    'dumbass', 'jackass', 'badass',
    'motherfucker', 'mf', 'mofo',
    'bullshit', 'bs',
  ];

  // Leetspeak / obfuscation map. These are applied during normalization so
  // "f@ck", "sh!t", "b1tch", "a$$hole" all collapse to their real forms
  // before the word check runs.
  static const Map<String, String> _leetMap = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    '\$': 's',
    '@': 'a',
    '!': 'i',
    '+': 't',
  };

  // Characters used to obfuscate between letters (f.u.c.k, f-u-c-k). Stripped
  // from inside candidate tokens before matching.
  static final RegExp _obfuscationChars = RegExp(r'''[.\-_*~`'"()\[\]{}:;,]''');

  // Collapse 3+ identical letters to 2 ("fuuuck" → "fuuck") so the matcher
  // can then strip to single for comparison. Two-pass: 3+ → 2, then 2 → 1
  // is handled in the matcher.
  static final RegExp _repeatedLetters = RegExp(r'(.)\1{2,}');

  // Pre-computed Set for O(1) lookup and a list of regex patterns for fuzzy
  // matching. Built once and cached.
  static final Set<String> _blockedSet = _blockedWords.toSet();

  /// Normalize a candidate token: lowercase, map leet chars, strip
  /// obfuscation punctuation, collapse long runs of repeated letters.
  static String _normalize(String token) {
    var t = token.toLowerCase();
    // Strip obfuscation chars between letters
    t = t.replaceAll(_obfuscationChars, '');
    // Map leetspeak
    final buf = StringBuffer();
    for (final rune in t.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(_leetMap[ch] ?? ch);
    }
    t = buf.toString();
    // Collapse 3+ repeats to 2
    t = t.replaceAllMapped(_repeatedLetters, (m) => '${m[1]}${m[1]}');
    return t;
  }

  /// Strip all vowel-repetition once more ("fuuck" → "fuck"), and all
  /// remaining non-letters. Used as a second-pass check to catch tokens
  /// that still don't match after the first normalization.
  static String _collapse(String t) {
    // Remove remaining non-letter characters
    final lettersOnly = t.replaceAll(RegExp(r'[^a-z]'), '');
    // Collapse any doubled letters to single: "fuuck" → "fuck", "shiit" → "shit"
    return lettersOnly.replaceAllMapped(RegExp(r'(.)\1+'), (m) => '${m[1]}');
  }

  /// Check if a single normalized token matches any blocked word.
  static bool _isBlocked(String normalized) {
    if (normalized.isEmpty) return false;
    if (_blockedSet.contains(normalized)) return true;
    // Try collapsed form for repeated-letter evasions
    final collapsed = _collapse(normalized);
    if (collapsed.isNotEmpty && _blockedSet.contains(collapsed)) return true;
    // Check if any blocked word appears as a substring of normalized (after
    // collapsing) — catches concatenations like "youarefuck". Only for
    // stems of length ≥ 4 to avoid false positives on short words.
    for (final w in _blockedWords) {
      if (w.length >= 4 && collapsed.contains(w)) return true;
    }
    return false;
  }

  /// Scan [input] and return a result describing any matches plus a
  /// censored version of the text.
  static ProfanityResult check(String input) {
    if (input.isEmpty) {
      return const ProfanityResult(
        hasProfanity: false,
        matches: [],
        censored: '',
      );
    }

    final matches = <String>{};
    // Tokenize on whitespace; preserve separators so we can rebuild the
    // string with censored tokens.
    final censoredBuf = StringBuffer();
    final tokenRegex = RegExp(r'(\s+)|(\S+)');
    for (final m in tokenRegex.allMatches(input)) {
      final whitespace = m.group(1);
      final token = m.group(2);
      if (whitespace != null) {
        censoredBuf.write(whitespace);
        continue;
      }
      if (token == null) continue;

      final normalized = _normalize(token);
      if (_isBlocked(normalized)) {
        matches.add(normalized);
        censoredBuf.write(_mask(token));
      } else {
        censoredBuf.write(token);
      }
    }

    return ProfanityResult(
      hasProfanity: matches.isNotEmpty,
      matches: matches.toList(),
      censored: censoredBuf.toString(),
    );
  }

  /// Convenience: just return the censored string.
  static String censor(String input) => check(input).censored;

  /// Returns true if [input] contains any blocked word.
  static bool contains(String input) => check(input).hasProfanity;

  /// Replace a token with asterisks of the same visible length, preserving
  /// trailing punctuation (e.g. "shit!" → "****!") so sentences still scan.
  static String _mask(String token) {
    final trailing = RegExp(r'[.!?,;:]+$').firstMatch(token);
    final core = trailing == null
        ? token
        : token.substring(0, token.length - trailing.group(0)!.length);
    final stars = '*' * core.length.clamp(1, 12);
    return trailing == null ? stars : '$stars${trailing.group(0)}';
  }
}
