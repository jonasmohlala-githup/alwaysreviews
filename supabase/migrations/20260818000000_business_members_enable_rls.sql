-- business_members was created in 20260815000000 without RLS enabled, on the
-- assumption it would only ever be reached via the service role key. That's no
-- longer true: shared.js's getCurrentBusinessId() queries this table directly
-- from the browser using the anon key. Supabase's Security Advisor flagged it
-- as publicly readable/writable (rls_disabled_in_public) since RLS was off.
--
-- Fix: enable RLS, and add a policy so a user can read only their own
-- membership row(s) -- matching the "member access" pattern already used on
-- businesses/customers/activities. Inserts/updates/deletes stay blocked for
-- the anon/authenticated roles (no linking UI exists yet; that still goes
-- through the service role, e.g. manual SQL per the "Unassigned users" flow).

alter table business_members enable row level security;

create policy "read own membership" on business_members
  for select using (
    user_id = auth.uid()
  );
