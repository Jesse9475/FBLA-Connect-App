-- ─────────────────────────────────────────────────────────────────────────────
-- migration_001_security_hardening.sql
--
-- Reconciles the live schema with the columns the application code actually
-- references. Without these, several routes (PATCH /reports/<id>, group
-- thread creation, member-role checks) raise "column does not exist" errors
-- at runtime.
--
-- Also tightens public-facing CHECK constraints on visibility columns so
-- a malicious client cannot smuggle invalid values past the application
-- layer (e.g. 'private' on a posts row that's enforced by RLS to be
-- 'public' or 'chapter').
--
-- Safe to re-run: every statement is idempotent (IF NOT EXISTS / IF EXISTS).
-- ─────────────────────────────────────────────────────────────────────────────

begin;

-- ── threads ─────────────────────────────────────────────────────────────────
alter table public.threads
  add column if not exists type        text not null default 'direct',
  add column if not exists created_by  uuid references public.users(id) on delete set null,
  add column if not exists name        text,
  add column if not exists icon_emoji  text,
  add column if not exists chapter_id  text references public.chapters(id),
  add column if not exists updated_at  timestamptz not null default now();

-- Type must be one of the values the app produces; tighten with a CHECK.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'threads_type_check'
  ) then
    alter table public.threads
      add constraint threads_type_check
      check (type in ('direct', 'group'));
  end if;
end$$;

-- updated_at trigger so message inserts can `update threads set updated_at = now()`.
create or replace function public.set_threads_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_threads_updated_at on public.threads;
create trigger trg_threads_updated_at
  before update on public.threads
  for each row execute function public.set_threads_updated_at();

-- ── thread_members ──────────────────────────────────────────────────────────
alter table public.thread_members
  add column if not exists member_role text not null default 'member',
  add column if not exists created_at  timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'thread_members_role_check'
  ) then
    alter table public.thread_members
      add constraint thread_members_role_check
      check (member_role in ('owner', 'admin', 'member'));
  end if;
end$$;

-- ── reports ────────────────────────────────────────────────────────────────
alter table public.reports
  add column if not exists status      text not null default 'open',
  add column if not exists context     jsonb,
  add column if not exists chapter_id  text references public.chapters(id),
  add column if not exists resolved    boolean not null default false,
  add column if not exists resolved_by uuid references public.users(id) on delete set null,
  add column if not exists resolved_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'reports_status_check'
  ) then
    alter table public.reports
      add constraint reports_status_check
      check (status in ('open', 'reviewed', 'closed'));
  end if;
end$$;

-- ── profiles updated_at trigger ─────────────────────────────────────────────
do $$
begin
  if exists (select 1 from pg_tables where schemaname = 'public' and tablename = 'profiles') then
    -- Add updated_at if missing
    execute 'alter table public.profiles add column if not exists updated_at timestamptz not null default now()';

    -- (Re)create the trigger
    execute 'create or replace function public.set_profiles_updated_at()
             returns trigger language plpgsql as $f$
             begin new.updated_at := now(); return new; end;
             $f$';

    execute 'drop trigger if exists trg_profiles_updated_at on public.profiles';
    execute 'create trigger trg_profiles_updated_at
               before update on public.profiles
               for each row execute function public.set_profiles_updated_at()';
  end if;
end$$;

-- ── visibility CHECK constraints ────────────────────────────────────────────
-- posts.visibility — 'public' | 'chapter' | 'district' | 'private'
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'posts'
               and column_name = 'visibility')
     and not exists (select 1 from pg_constraint where conname = 'posts_visibility_check') then
    alter table public.posts
      add constraint posts_visibility_check
      check (visibility in ('public', 'chapter', 'district', 'private'));
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'events_visibility_check') then
    alter table public.events
      add constraint events_visibility_check
      check (visibility in ('public', 'chapter', 'district', 'private'));
  end if;
end$$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'hub_items_visibility_check') then
    alter table public.hub_items
      add constraint hub_items_visibility_check
      check (visibility in ('public', 'chapter', 'district', 'private'));
  end if;
end$$;

-- ── Index reports for quicker advisor dashboards ────────────────────────────
create index if not exists idx_reports_status      on public.reports (status);
create index if not exists idx_reports_chapter_id  on public.reports (chapter_id);
create index if not exists idx_reports_reporter_id on public.reports (reporter_id);

-- ── Index threads for quicker DM resolution ────────────────────────────────
create index if not exists idx_threads_type       on public.threads (type);
create index if not exists idx_threads_created_by on public.threads (created_by);
create index if not exists idx_threads_chapter_id on public.threads (chapter_id);

-- ── chapters.thread_id ──────────────────────────────────────────────────────
-- The chapter-group-chat route (`GET /threads/chapter/<id>`) stores the
-- auto-created group thread's id back on the chapter row so a chapter only
-- ever has ONE group chat. Without this column the route crashes with
-- "column does not exist" the first time any student opens their chapter
-- chat.
alter table public.chapters
  add column if not exists thread_id uuid references public.threads(id) on delete set null;

create index if not exists idx_chapters_thread_id on public.chapters (thread_id);

-- ── shared_platforms on posts / events / announcements ──────────────────────
-- The advisor "Share to…" feature records which external platforms a piece
-- of content has been shared to (instagram, twitter, native). The Flask
-- route competitive_events._track_share reads and writes this column on
-- three tables; all three need the column or the endpoint 500s.
alter table public.posts
  add column if not exists shared_platforms text[] not null default '{}';

alter table public.events
  add column if not exists shared_platforms text[] not null default '{}';

alter table public.announcements
  add column if not exists shared_platforms text[] not null default '{}';

commit;
