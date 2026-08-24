-- Adds an 'admin' role value to business_members and links Jonas's user to
-- every existing business as admin. RLS policies need no changes: they already
-- use `business_id in (select ... where user_id = auth.uid())`, which already
-- unions across however many business_members rows a user has — an admin with
-- multiple rows automatically sees every linked business's data.
--
-- The frontend (web/shared.js) uses this role only to decide whether to show
-- a business-switcher dropdown; it has no other special privilege server-side.

alter table business_members drop constraint business_members_role_check;
alter table business_members add constraint business_members_role_check
  check (role in ('owner', 'staff', 'admin'));

insert into business_members (business_id, user_id, role)
select b.id, u.id, 'admin'
from businesses b
cross join auth.users u
where u.email = 'jonas.mohlala@gmail.com'
on conflict (business_id, user_id) do update set role = 'admin';
