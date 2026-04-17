-- Core schema for FBLA Connect (Supabase)
-- Run in Supabase SQL editor or via migrations.

create extension if not exists "pgcrypto";

-- NOTE: districts and chapters use human-readable text PKs (e.g. 'CA-N', 'CA-N-001')
-- rather than auto-generated UUIDs so seed data is self-documenting.
create table if not exists public.districts (
  id text primary key,
  name text not null unique
);

create table if not exists public.chapters (
  id text primary key,
  district_id text not null references public.districts(id) on delete cascade,
  name text not null,
  school text  -- human-readable school name (same as chapter name by convention)
);

create table if not exists public.users (
  id uuid primary key,
  role text not null default 'member',
  display_name text,
  username text unique,
  email text,
  chapter_id text references public.chapters(id),
  district_id text references public.districts(id),
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  bio text,
  avatar_url text,
  grade text,
  school text,
  location text,
  interests text[] not null default '{}'::text[],
  points integer not null default 0,
  events_attended integer not null default 0,
  awards_count integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  caption text not null,
  media_url text,
  visibility text not null default 'public',
  chapter_id text references public.chapters(id),
  district_id text references public.districts(id),
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.threads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.thread_members (
  thread_id uuid not null references public.threads(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  body text not null,
  media_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text,
  start_at timestamptz not null,
  end_at timestamptz,
  location text,
  visibility text not null default 'public',
  chapter_id text references public.chapters(id),
  district_id text references public.districts(id),
  created_at timestamptz not null default now()
);

create table if not exists public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  registered_at timestamptz not null default now(),
  attended boolean not null default false,
  attended_at timestamptz,
  unique (event_id, user_id)
);

create table if not exists public.awards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  description text,
  awarded_by uuid references public.users(id),
  awarded_at timestamptz not null default now()
);

create table if not exists public.hub_items (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  category text,
  file_path text,
  visibility text not null default 'public',
  created_at timestamptz not null default now()
);

create table if not exists public.advisor_invites (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  expires_at timestamptz,
  used_by uuid references public.users(id),
  used_at timestamptz,
  chapter_id text references public.chapters(id),
  district_id text references public.districts(id),
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete cascade,
  target_type text not null,
  target_id text not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  scope text not null default 'national',
  district_id text references public.districts(id),
  chapter_id text references public.chapters(id),
  created_at timestamptz not null default now()
);

-- ── Competitive Events ──────────────────────────────────────────────────────

create table if not exists public.competitive_events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  category text not null check (category in ('business_management', 'finance', 'marketing', 'information_technology', 'communication', 'economics', 'entrepreneurship', 'leadership', 'career_development')),
  description text,
  event_type text not null check (event_type in ('test', 'presentation', 'performance', 'project')),
  icon_name text,
  color_hex text,
  is_individual boolean not null default true,
  team_size_min integer default 1,
  team_size_max integer default 1,
  created_at timestamptz not null default now()
);

create table if not exists public.competitive_event_resources (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.competitive_events(id) on delete cascade,
  title text not null,
  description text,
  resource_type text not null check (resource_type in ('pdf', 'link', 'study_guide', 'sample_test', 'video')),
  url text,
  file_path text,
  created_by uuid references public.users(id) on delete set null,
  source text default 'fbla_official',
  created_at timestamptz not null default now()
);

create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.competitive_events(id) on delete cascade,
  title text not null,
  description text,
  time_limit_seconds integer,
  created_by uuid references public.users(id) on delete set null,
  question_count integer not null default 0,
  difficulty text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard')),
  points_per_correct integer not null default 5,
  is_ai_generated boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  question_text text not null,
  options jsonb,
  correct_answer text not null,
  explanation text,
  question_type text not null default 'multiple_choice' check (question_type in ('multiple_choice', 'true_false', 'flashcard')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  mode text not null check (mode in ('test', 'practice')),
  total_questions integer not null,
  time_taken_seconds integer,
  answers jsonb,
  score integer not null default 0,
  correct_count integer not null default 0,
  points_earned integer not null default 0,
  completed_at timestamptz not null default now()
);

create index if not exists idx_posts_user_id on public.posts (user_id);
create index if not exists idx_posts_chapter on public.posts (chapter_id);
create index if not exists idx_comments_post_id on public.comments (post_id);
create index if not exists idx_events_start_at on public.events (start_at);
create index if not exists idx_events_chapter on public.events (chapter_id);
create index if not exists idx_hub_items_category on public.hub_items (category);
create index if not exists idx_thread_members_user on public.thread_members (user_id);
create index if not exists idx_messages_thread on public.messages (thread_id);
create index if not exists idx_chapters_district on public.chapters (district_id);
create index if not exists idx_announcements_scope on public.announcements (scope);
create index if not exists idx_event_registrations_event on public.event_registrations (event_id);
create index if not exists idx_event_registrations_user on public.event_registrations (user_id);
create index if not exists idx_awards_user on public.awards (user_id);

-- Competitive events indexes
create index if not exists idx_competitive_events_category on public.competitive_events (category);
create index if not exists idx_competitive_events_slug on public.competitive_events (slug);
create index if not exists idx_competitive_event_resources_event on public.competitive_event_resources (event_id);
create index if not exists idx_quizzes_event on public.quizzes (event_id);
create index if not exists idx_quiz_questions_quiz on public.quiz_questions (quiz_id);
create index if not exists idx_quiz_questions_sort on public.quiz_questions (quiz_id, sort_order);
create index if not exists idx_quiz_attempts_user on public.quiz_attempts (user_id);
create index if not exists idx_quiz_attempts_quiz on public.quiz_attempts (quiz_id);

-- ── Gamification triggers ────────────────────────────────────────────────────

-- Award +10 pts and increment events_attended when attendance is marked true.
create or replace function public.handle_attendance_marked()
returns trigger language plpgsql as $$
begin
  if new.attended = true and (old.attended is null or old.attended = false) then
    insert into public.profiles (user_id, points, events_attended)
    values (new.user_id, 10, 1)
    on conflict (user_id) do update
      set points          = profiles.points + 10,
          events_attended = profiles.events_attended + 1,
          updated_at      = now();
  end if;
  return new;
end;
$$;

drop trigger if exists on_attendance_marked on public.event_registrations;
create trigger on_attendance_marked
  after update on public.event_registrations
  for each row execute procedure public.handle_attendance_marked();

-- Increment awards_count when an award is granted.
create or replace function public.handle_award_granted()
returns trigger language plpgsql as $$
begin
  insert into public.profiles (user_id, awards_count)
  values (new.user_id, 1)
  on conflict (user_id) do update
    set awards_count = profiles.awards_count + 1,
        updated_at   = now();
  return new;
end;
$$;

drop trigger if exists on_award_granted on public.awards;
create trigger on_award_granted
  after insert on public.awards
  for each row execute procedure public.handle_award_granted();

-- ── Competitive Events RLS Policies ──────────────────────────────────────────

-- Enable RLS on competitive events tables
alter table public.competitive_events enable row level security;
alter table public.competitive_event_resources enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_attempts enable row level security;

-- Competitive events: public read access (no authentication needed)
create policy "Public read access" on public.competitive_events
  for select
  using (true);

-- Competitive event resources: authenticated users can read
create policy "Authenticated read" on public.competitive_event_resources
  for select
  using (auth.role() = 'authenticated');

-- Advisors/admins can create resources
create policy "Advisor create resources" on public.competitive_event_resources
  for insert
  with check (auth.role() = 'authenticated');

-- Quizzes: authenticated users can read
create policy "Authenticated read" on public.quizzes
  for select
  using (auth.role() = 'authenticated');

-- Quiz questions: authenticated users can read
create policy "Authenticated read" on public.quiz_questions
  for select
  using (auth.role() = 'authenticated');

-- Quiz attempts: users can insert own and see own attempts
create policy "Authenticated user inserts" on public.quiz_attempts
  for insert
  with check (auth.role() = 'authenticated' and user_id = auth.uid());

create policy "User can see own attempts" on public.quiz_attempts
  for select
  using (auth.role() = 'authenticated' and user_id = auth.uid());