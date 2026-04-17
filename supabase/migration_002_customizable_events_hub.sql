-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 002: Customizable event upload & resource upload
--
-- Adds optional metadata columns used by the enhanced Create Event and
-- Create Resource flows in the Flutter app. All columns are nullable so
-- existing rows continue to validate against the schema.
-- ─────────────────────────────────────────────────────────────────────────────

-- Event metadata
alter table public.events
  add column if not exists category      text,
  add column if not exists accent_color  text,     -- e.g. '#FF6F00'
  add column if not exists capacity      integer,
  add column if not exists tags          text[] not null default '{}',
  add column if not exists location_image_url text,
  add column if not exists place_id      text,
  add column if not exists registration_deadline timestamptz;

-- Soft constraint: capacity must be positive when set
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_capacity_positive'
  ) then
    alter table public.events
      add constraint events_capacity_positive
      check (capacity is null or capacity > 0);
  end if;
end$$;

-- Hub resource metadata
alter table public.hub_items
  add column if not exists url           text,
  add column if not exists resource_type text,     -- 'document' | 'link' | 'video' | 'study_guide' | 'sample_test'
  add column if not exists tags          text[] not null default '{}';

-- Resource-type constraint, nullable so existing rows remain valid
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'hub_items_resource_type_valid'
  ) then
    alter table public.hub_items
      add constraint hub_items_resource_type_valid
      check (
        resource_type is null or
        resource_type in ('document', 'link', 'video', 'study_guide', 'sample_test', 'template')
      );
  end if;
end$$;

-- Indexes for filtering by tag
create index if not exists idx_events_tags     on public.events     using gin (tags);
create index if not exists idx_hub_items_tags  on public.hub_items  using gin (tags);
create index if not exists idx_events_category on public.events (category);
create index if not exists idx_hub_items_type  on public.hub_items (resource_type);
