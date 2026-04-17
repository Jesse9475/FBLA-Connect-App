"""
Server-side profanity filter.

This is a defense-in-depth layer on top of the Flutter client-side filter
(see flutter/fbla_connect_app/lib/utils/profanity_filter.dart). The client
already censors bad words before sending, but we never trust the client:
a crafted request to /threads/<id>/messages could bypass it entirely.

Philosophy — this is a school-club product, so we censor rather than
hard-reject. Replacing slurs/profanity with asterisks keeps the
conversation flowing and mirrors the client UX (one subtle toast + the
word blanked out) without creating a moderation nightmare.

Usage:
    from fbla.services.profanity_filter import censor, contains_profanity

    cleaned = censor(user_input)
    if contains_profanity(user_input):
        # optional telemetry
        ...
"""

from __future__ import annotations

import re

# Keep this list in rough parity with the Flutter-side list. Stems only —
# the leet/obfuscation pass catches common variants.
_BLOCKED_WORDS = {
    # Profanity
    "fuck", "fuk", "fck", "fking", "fker",
    "shit", "sht",
    "bitch", "btch",
    "bastard",
    "asshole", "arsehole", "ahole",
    "dick", "dik", "cock", "pussy", "puss",
    "cunt", "twat",
    "damn", "goddamn",
    "piss", "pissed",
    "crap",
    "whore", "hoe", "slut", "skank",
    "prick",
    "wanker", "wank",
    "bollocks", "bugger",
    # Slurs (stems only)
    "nigger", "nigga", "nigg",
    "faggot", "fag", "fagg",
    "retard", "retarded",
    "spic", "chink", "kike", "gook", "coon", "tranny",
    # Sexual
    "porn", "sex", "orgasm", "boobs", "tits", "titties",
    # School-context milder
    "dumbass", "jackass", "badass",
    "motherfucker", "mofo",
    "bullshit",
}

_LEET_MAP = str.maketrans({
    "0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
    "7": "t", "8": "b", "$": "s", "@": "a", "!": "i", "+": "t",
})

_OBFUSCATION_RE = re.compile(r"""[.\-_*~`'"()\[\]{}:;,]""")
_TRIPLE_PLUS_RE = re.compile(r"(.)\1{2,}")
_DOUBLED_RE = re.compile(r"(.)\1+")
_NON_LETTER_RE = re.compile(r"[^a-z]")
_TRAILING_PUNCT_RE = re.compile(r"[.!?,;:]+$")
_TOKEN_RE = re.compile(r"(\s+)|(\S+)")


def _normalize(token: str) -> str:
    """Lowercase, strip obfuscation chars, map leetspeak, collapse triples."""
    t = token.lower()
    t = _OBFUSCATION_RE.sub("", t)
    t = t.translate(_LEET_MAP)
    t = _TRIPLE_PLUS_RE.sub(lambda m: m.group(1) * 2, t)
    return t


def _collapse(t: str) -> str:
    """Strip non-letters and collapse any doubled letters to singles."""
    letters_only = _NON_LETTER_RE.sub("", t)
    return _DOUBLED_RE.sub(lambda m: m.group(1), letters_only)


def _is_blocked(normalized: str) -> bool:
    if not normalized:
        return False
    if normalized in _BLOCKED_WORDS:
        return True
    collapsed = _collapse(normalized)
    if collapsed and collapsed in _BLOCKED_WORDS:
        return True
    # Substring check on the collapsed form, but only for stems ≥ 4 chars
    # (avoids false positives on short words like "ass" in "class").
    for w in _BLOCKED_WORDS:
        if len(w) >= 4 and w in collapsed:
            return True
    return False


def _mask(token: str) -> str:
    """Replace the token's core with asterisks, keep trailing punctuation."""
    m = _TRAILING_PUNCT_RE.search(token)
    if m:
        core = token[: m.start()]
        tail = m.group(0)
    else:
        core = token
        tail = ""
    stars = "*" * max(1, min(len(core), 12))
    return stars + tail


def censor(text: str) -> str:
    """Return [text] with any blocked words replaced by asterisks."""
    if not text:
        return ""
    out = []
    for m in _TOKEN_RE.finditer(text):
        whitespace = m.group(1)
        token = m.group(2)
        if whitespace is not None:
            out.append(whitespace)
            continue
        if token is None:
            continue
        if _is_blocked(_normalize(token)):
            out.append(_mask(token))
        else:
            out.append(token)
    return "".join(out)


def contains_profanity(text: str) -> bool:
    """Fast existence check — stops on the first match."""
    if not text:
        return False
    for m in _TOKEN_RE.finditer(text):
        token = m.group(2)
        if token is None:
            continue
        if _is_blocked(_normalize(token)):
            return True
    return False
