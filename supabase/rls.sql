-- RLS policies for FBLA Connect (mixed access model)

create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role = 'admin'
  );
$$;

create or replace function public.is_advisor()
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.role in ('advisor', 'admin')
  );
$$;

alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.events enable row level security;
alter table public.threads enable row level security;
alter table public.thread_members enable row level security;
alter table public.messages enable row level security;
alter table public.hub_items enable row level security;
alter table public.advisor_invites enable row level security;
alter table public.reports enable row level security;
alter table public.districts enable row level security;
alter table public.chapters enable row level security;
alter table public.announcements enable row level security;

-- Users
create policy "users_select_self_or_admin" on public.users
for select using (auth.uid() = id or public.is_admin());

create policy "users_insert_self" on public.users
for insert with check (auth.uid() = id);

create policy "users_update_self_or_admin" on public.users
for update using (auth.uid() = id or public.is_admin());

-- Profiles
create policy "profiles_select_self_or_admin" on public.profiles
for select using (auth.uid() = user_id or public.is_admin());

create policy "profiles_insert_self" on public.profiles
for insert with check (auth.uid() = user_id);

create policy "profiles_update_self_or_admin" on public.profiles
for update using (auth.uid() = user_id or public.is_admin());

-- Posts
create policy "posts_select_public_or_owner_or_admin" on public.posts
for select using (
  visibility = 'public'
  or (visibility = 'members' and auth.uid() is not null)
  or auth.uid() = user_id
  or public.is_admin()
);

create policy "posts_insert_owner" on public.posts
for insert with check (auth.uid() = user_id);

create policy "posts_update_owner_or_admin" on public.posts
for update using (auth.uid() = user_id or public.is_admin());

create policy "posts_delete_owner_or_admin" on public.posts
for delete using (auth.uid() = user_id or public.is_admin());

-- Likes
create policy "likes_select_public_or_owner_or_admin" on public.post_likes
for select using (
  public.is_admin()
  or auth.uid() = user_id
  or exists (
    select 1 from public.posts p
    where p.id = post_id and p.visibility = 'public'
  )
);

create policy "likes_insert_owner" on public.post_likes
for insert with check (auth.uid() = user_id);

create policy "likes_delete_owner_or_admin" on public.post_likes
for delete using (auth.uid() = user_id or public.is_admin());

-- Comments
create policy "comments_select_public_or_owner_or_admin" on public.comments
for select using (
  public.is_admin()
  or auth.uid() = user_id
  or exists (
    select 1 from public.posts p
    where p.id = post_id and p.visibility = 'public'
  )
);

create policy "comments_insert_owner" on public.comments
for insert with check (auth.uid() = user_id);

create policy "comments_update_owner_or_admin" on public.comments
for update using (auth.uid() = user_id or public.is_admin());

create policy "comments_delete_owner_or_admin" on public.comments
for delete using (auth.uid() = user_id or public.is_admin());

-- Events
create policy "events_select_public_or_owner_or_admin" on public.events
for select using (
  visibility = 'public'
  or (visibility = 'members' and auth.uid() is not null)
  or auth.uid() = created_by
  or public.is_admin()
);

create policy "events_insert_owner" on public.events
for insert with check (auth.uid() = created_by);

create policy "events_update_owner_or_admin" on public.events
for update using (auth.uid() = created_by or public.is_admin());

create policy "events_delete_owner_or_admin" on public.events
for delete using (auth.uid() = created_by or public.is_admin());

-- Threads and messages
create policy "threads_select_member_or_admin" on public.threads
for select using (
  public.is_admin() or exists (
    select 1 from public.thread_members tm
    where tm.thread_id = id and tm.user_id = auth.uid()
  )
);

create policy "threads_insert_authenticated" on public.threads
for insert with check (auth.uid() is not null);

create policy "thread_members_select_self_or_admin" on public.thread_members
for select using (auth.uid() = user_id or public.is_admin());

create policy "thread_members_insert_self" on public.thread_members
for insert with check (auth.uid() = user_id);

create policy "messages_select_member_or_admin" on public.messages
for select using (
  public.is_admin() or exists (
    select 1 from public.thread_members tm
    where tm.thread_id = thread_id and tm.user_id = auth.uid()
  )
);

create policy "messages_insert_member" on public.messages
for insert with check (
  exists (
    select 1 from public.thread_members tm
    where tm.thread_id = thread_id and tm.user_id = auth.uid()
  )
);

-- Hub items
create policy "hub_select_public_or_owner_or_admin" on public.hub_items
for select using (
  visibility = 'public'
  or (visibility = 'members' and auth.uid() is not null)
  or auth.uid() = created_by
  or public.is_admin()
);

create policy "hub_insert_owner" on public.hub_items
for insert with check (auth.uid() = created_by);

create policy "hub_update_owner_or_admin" on public.hub_items
for update using (auth.uid() = created_by or public.is_admin());

create policy "hub_delete_owner_or_admin" on public.hub_items
for delete using (auth.uid() = created_by or public.is_admin());

-- Advisor invites (admin only)
create policy "advisor_invites_admin_only" on public.advisor_invites
for all using (public.is_admin()) with check (public.is_admin());

-- Reports
create policy "reports_insert_owner" on public.reports
for insert with check (auth.uid() = reporter_id);

create policy "reports_select_admin_only" on public.reports
for select using (public.is_admin());

-- Districts and chapters (read for authenticated users; admin manage)
create policy "districts_select_authenticated" on public.districts
for select using (auth.uid() is not null);

create policy "districts_admin_manage" on public.districts
for all using (public.is_admin()) with check (public.is_admin());

create policy "chapters_select_authenticated" on public.chapters
for select using (auth.uid() is not null);

create policy "chapters_admin_manage" on public.chapters
for all using (public.is_admin()) with check (public.is_admin());

-- Announcements (national/district/chapter visibility)
create policy "announcements_select_visible" on public.announcements
for select using (
  public.is_admin()
  or (
    scope = 'national' and auth.uid() is not null
  )
  or (
    scope = 'district'
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.district_id = announcements.district_id
    )
  )
  or (
    scope = 'chapter'
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.chapter_id = announcements.chapter_id
    )
  )
);

create policy "announcements_insert_admin_or_advisor" on public.announcements
for insert with check (public.is_admin() or public.is_advisor());

create policy "announcements_update_admin_or_owner" on public.announcements
for update using (public.is_admin() or auth.uid() = created_by);

create policy "announcements_delete_admin_or_owner" on public.announcements
for delete using (public.is_admin() or auth.uid() = created_by);
