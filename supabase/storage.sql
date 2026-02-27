-- Storage policies for bucket "media"
-- Adjust bucket name if different.

alter table storage.objects enable row level security;

-- Read: allow public for objects marked public, or owner/admin.
create policy "media_read_public_or_owner_or_admin" on storage.objects
for select
using (
  bucket_id = 'media'
  and (
    (metadata->>'visibility' = 'public')
    or auth.uid() is not null
    or owner = auth.uid()
    or public.is_admin()
  )
);

-- Write: only authenticated owner (or admin) can insert/update/delete.
create policy "media_write_owner_or_admin" on storage.objects
for all
using (bucket_id = 'media' and (owner = auth.uid() or public.is_admin()))
with check (bucket_id = 'media' and (owner = auth.uid() or public.is_admin()));
