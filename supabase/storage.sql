-- Storage policies for bucket "media"
-- Adjust bucket name if different.
--
-- Threat model: the public read policy used to allow ANY authenticated
-- user to read ANY object. That meant a logged-in attacker could
-- enumerate all uploads (DMs, advisor docs, private posts) by guessing
-- UUID paths. We now require either:
--   (a) the object's metadata explicitly marks it `visibility=public`, or
--   (b) the object's metadata marks it `visibility=authenticated` AND
--       the caller is logged in (legacy behavior, opt-in per upload), or
--   (c) the caller owns it, or
--   (d) the caller is an admin.
--
-- The application layer is responsible for setting the metadata
-- correctly when uploading. Default uploads SHOULD be private unless
-- the feature explicitly needs broader access.

alter table storage.objects enable row level security;

-- Drop the old over-permissive policy if it exists so this file can be
-- re-applied without manual cleanup.
drop policy if exists "media_read_public_or_owner_or_admin" on storage.objects;

create policy "media_read_scoped" on storage.objects
for select
using (
  bucket_id = 'media'
  and (
    (metadata->>'visibility' = 'public')
    or (metadata->>'visibility' = 'authenticated' and auth.uid() is not null)
    or owner = auth.uid()
    or public.is_admin()
  )
);

-- Write: only authenticated owner (or admin) can insert/update/delete.
drop policy if exists "media_write_owner_or_admin" on storage.objects;
create policy "media_write_owner_or_admin" on storage.objects
for all
using (bucket_id = 'media' and (owner = auth.uid() or public.is_admin()))
with check (bucket_id = 'media' and (owner = auth.uid() or public.is_admin()));
