-- ─────────────────────────────────────────────────────────────────────────────
-- reset_users_chapters_districts.sql
--
-- Full wipe of all user accounts, advisor codes, chapters, and districts
-- plus every row that belongs to a user (posts, comments, likes, events,
-- registrations, awards, messages, threads, reports, hub items, quiz
-- attempts, profiles).
--
-- ⚠️  DESTRUCTIVE.  Run in the Supabase SQL editor.  Cannot be undone.
--
-- Preserves (reference data, NOT account-linked):
--   • public.competitive_events
--   • public.competitive_event_resources
--   • public.quizzes
--   • public.quiz_questions
-- ─────────────────────────────────────────────────────────────────────────────

begin;

-- ── 1. All account-linked + domain tables ───────────────────────────────────
-- TRUNCATE ... CASCADE handles the FK graph in one shot regardless of
-- insert order.  `restart identity` resets any serial sequences.
truncate table
    public.post_likes,
    public.comments,
    public.posts,
    public.event_registrations,
    public.awards,
    public.events,
    public.announcements,
    public.messages,
    public.thread_members,
    public.threads,
    public.reports,
    public.hub_items,
    public.quiz_attempts,
    public.advisor_invites,   -- ← all advisor codes (used + unused)
    public.profiles,
    public.users,
    public.chapters,
    public.districts
restart identity
cascade;

-- ── 2. Supabase auth users (emails / passwords) ─────────────────────────────
-- `public.users.id` mirrors `auth.users.id`.  Clearing auth.users removes
-- every email, password hash, OTP history, and session.
delete from auth.users;

commit;

-- ── Sanity checks (optional) ────────────────────────────────────────────────
-- select count(*) from public.users;            -- expect 0
-- select count(*) from public.chapters;         -- expect 0
-- select count(*) from public.districts;        -- expect 0
-- select count(*) from public.advisor_invites;  -- expect 0
-- select count(*) from auth.users;              -- expect 0
