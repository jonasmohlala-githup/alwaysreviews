-- Adds business_members join table and enables RLS on businesses/customers/activities.
-- n8n continues to use the service role key, which bypasses RLS, so the existing
-- outbound-send workflow is unaffected. This gates the new universal customer-intake
-- form/login page, where each business's staff only see/write their own data.

create table business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'staff' check (role in ('owner', 'staff')),
  unique (business_id, user_id)
);

alter table businesses enable row level security;
alter table customers enable row level security;
alter table activities enable row level security;

create policy "member access" on businesses
  for all using (
    id in (select business_id from business_members where user_id = auth.uid())
  );

create policy "member access" on customers
  for all using (
    business_id in (select business_id from business_members where user_id = auth.uid())
  );

create policy "member access" on activities
  for all using (
    business_id in (select business_id from business_members where user_id = auth.uid())
  );
