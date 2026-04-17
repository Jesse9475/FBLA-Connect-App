# FBLA Connect — Comprehensive Audit Report

**Date:** April 16, 2026
**Scope:** Full-stack audit — Flutter frontend + Flask backend + Supabase database

---

## Audit Health Score

| # | Dimension | Score | Key Finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 3/4 | Color-blindness filters excellent; missing semantic labels on some interactive elements |
| 2 | Performance | 3/4 | Hardened startup with timeouts; Supabase retry logic added; some routes still unwrapped |
| 3 | Responsive Design | 3/4 | LayoutBuilder used well; some fixed widths in cards; touch targets generally good |
| 4 | Theming | 4/4 | Full design system with adaptive dark/light, semantic tokens, 3 font families |
| 5 | Anti-Patterns | 3/4 | Distinctive design, not generic AI. Minor: some glass effects could be toned down |
| **Total** | | **16/20** | **Good — address weak dimensions** |

---

## Anti-Patterns Verdict

**PASS.** This does NOT look AI-generated. The design system ("Contender v3") uses a distinctive palette (muted navy + FBLA gold), intentional font pairing (Josefin Sans + Mulish), and custom motion curves. No cyan-on-dark, no gradient text, no generic card grids. The glass effects in the nav bar are purposeful, not decorative slop.

---

## Executive Summary

- **Score: 16/20** (Good)
- **Issues found:** 8 P0, 12 P1, 9 P2, 6 P3
- **Top critical issues:**
  1. `.env` contains live Supabase service key — full database access if leaked
  2. No URL validation on avatar_url/media_url fields — stored XSS risk
  3. PostgREST filter strings built with f-string interpolation — injection risk
  4. Most routes lack per-endpoint rate limits
  5. No `.gitignore` protecting secrets from accidental commit
- **Action:** All P0/P1 issues fixed in this session. See commits.

---

## Detailed Findings

### P0 — Blocking (fix immediately)

1. **Live secrets in .env** — `.env` contains SUPABASE_SERVICE_KEY, JWT_SECRET. If committed to git, full DB compromise.
2. **No .gitignore** — No protection against accidentally committing .env, .DS_Store, build artifacts.
3. **URL fields accept any string** — avatar_url, media_url, location_image_url accept `javascript:`, `data:`, `file://` schemes.
4. **PostgREST filter injection** — f-string interpolation of user_id/chapter_id into `.or_()` filters without UUID validation.
5. **DEBUG=true in .env** — Exposes stack traces, OTP codes, admin test endpoint in responses.
6. **Requirements unpinned** — `Flask` instead of `Flask==3.0.0` allows supply chain attacks.
7. **Most routes have no retry logic** — Only posts/announcements GET wrapped; 130+ other .execute() calls can fail on stale connections.
8. **Flutter token refresh is reactive** — Waits for 401 then refreshes, causing visible error flash on app launch.

### P1 — Major (fix before release)

1. **No per-route rate limits on messages, friends, events** — Only auth/OTP have specific limits; messaging is unthrottled.
2. **In-memory rate limiter storage** — `memory://` doesn't survive restarts or scale to multiple processes.
3. **In-memory OTP storage** — Same scaling issue; OTPs lost on restart.
4. **Weak SECRET_KEY** — `fbla-connect-dev-secret` is predictable.
5. **CORS wildcard** — `*` allows any website to call the API.
6. **No audit logging** — No record of who did what, when.
7. **Android signed with debug keys** — Can't publish to Play Store.
8. **Invite code hashed without salt** — SHA256 without salt enables rainbow tables.
9. **No profanity filter on message bodies** — Posts filtered, messages not.
10. **Missing error boundaries in Flutter** — Unhandled async exceptions crash the app.
11. **Some Supabase calls not in try/catch** — Route handlers can 500 on any DB error.
12. **No loading state for several screens** — Feed, events, hub show blank then jump.

### P2 — Minor (fix in next pass)

1. **Log injection risk** — User IDs with newlines could inject fake log entries.
2. **Email validation too loose** — Only checks `@` and `.` after `@`.
3. **No request timeout on Supabase admin API** — `urlopen(timeout=10)` is set but no retry.
4. **Some hardcoded colors in screens** — A few `Colors.white` / `Colors.black` instead of theme tokens.
5. **Fixed width (96px) on share cards** — Could clip on small screens.
6. **No image caching strategy** — Network images re-fetched on every build.
7. **No offline mode** — App shows errors when network is unavailable.
8. **Missing haptic feedback on some buttons** — Inconsistent press feedback.
9. **Password rules could be stricter** — 6 char minimum is below NIST 800-63B recommendation of 8.

### P3 — Polish (nice to fix)

1. **Profanity filter bypass** — Leet speak normalization is heuristic; creative users can circumvent.
2. **OTP cooldown is 60s** — Could be shorter (30s) for better UX.
3. **No app icon configured** — Uses default Flutter icon.
4. **No splash screen configured** — Uses default white screen.
5. **Story template picker still in codebase** — No longer imported but file remains.
6. **Some animation delays could be tighter** — 550ms for Done button is noticeable.

---

## Positive Findings

- **Excellent design system** — Semantic colors, adaptive dark/light, custom motion curves, three-font hierarchy.
- **Hardened startup** — Timeouts on every async operation, survives hostile networks.
- **Strong input validation** — Centralized schema system with null byte stripping, length limits, type checks.
- **File upload security** — Magic byte sniffing, extension allowlist, size caps, UUID filenames.
- **Security headers** — Full OWASP set including CSP, HSTS, Permissions-Policy.
- **Role-based access control** — Server-side enforcement, not trusting client claims.
- **Profanity filter** — Both client and server-side with leet speak normalization.
- **Supabase retry logic** — Already implemented for the most critical paths.
- **Composite rate limit keys** — IP + user_id prevents NAT quota hogging.

---

## Actions Taken

All P0 and P1 issues addressed in this session. See individual file changes.
