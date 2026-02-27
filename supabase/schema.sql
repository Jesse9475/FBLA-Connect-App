-- Core schema for FBLA Connect (Supabase)
-- Run in Supabase SQL editor or via migrations.

create extension if not exists "pgcrypto";

create table if not exists public.districts (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table if not exists public.chapters (
  id uuid primary key default gen_random_uuid(),
  district_id uuid not null references public.districts(id) on delete cascade,
  name text not null
);

create table if not exists public.users (
  id uuid primary key,
  role text not null default 'member',
  display_name text,
  username text unique,
  email text,
  chapter_id uuid references public.chapters(id),
  district_id uuid references public.districts(id),
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  bio text,
  avatar_url text,
  grade text,
  school text,
  location text,
  updated_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  caption text not null,
  media_url text,
  visibility text not null default 'public',
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
  created_at timestamptz not null default now()
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
  district_id uuid references public.districts(id),
  chapter_id uuid references public.chapters(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_posts_user_id on public.posts (user_id);
create index if not exists idx_comments_post_id on public.comments (post_id);
create index if not exists idx_messages_created_at on public.events (start_at);
create index if not exists idx_hub_items_category on public.hub_items (category);
create index if not exists idx_thread_members_user on public.thread_members (user_id);
create index if not exists idx_messages_thread on public.messages (thread_id);
create index if not exists idx_chapters_district on public.chapters (district_id);
create index if not exists idx_announcements_scope on public.announcements (scope);