-- RLS validation helpers (run in Supabase SQL editor)
-- Replace UUIDs with real auth.uid() values from your project.

-- Simulate a member user
select set_config('request.jwt.claims', '{"sub":"<MEMBER_UID>"}', true);
select * from public.posts limit 5;
select * from public.events limit 5;
select * from public.hub_items limit 5;

-- Simulate an admin user
select set_config('request.jwt.claims', '{"sub":"<ADMIN_UID>"}', true);
select * from public.reports limit 5;
select * from public.advisor_invites limit 5;
