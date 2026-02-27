-- Seed an initial admin user by auth UID.
-- Replace <ADMIN_UID> with the Supabase auth user id.

insert into public.users (id, role)
values ('<ADMIN_UID>', 'admin')
on conflict (id) do update set role = 'admin';
