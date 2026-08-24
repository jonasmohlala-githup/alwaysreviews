-- Seeds two demo businesses (with customers + activity history) so the
-- admin business-switcher has more than one option to demonstrate, and links
-- the admin account to both. Print Express stays the only real client;
-- these are clearly-marked fake accounts for demo/pitch purposes only.
-- The businesses_after_insert trigger auto-creates each one's "Unmatched
-- Reviewer" placeholder customer on insert, same as any real business.

insert into businesses (id, business_name, contact_person, contact_email, contact_phone, status, notes)
values
  ('a1b2c3d4-0001-4000-8000-000000000001', 'Kimberley Auto Care', 'Pieter van der Merwe', 'demo+autocare@alwaysreviews.com', '27820000001', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'Bright Smile Dental', 'Dr. Naledi Khumalo', 'demo+dental@alwaysreviews.com', '27820000002', 'Active', 'Demo business for pitch/demo purposes only.');

insert into customers (id, business_id, first_name, full_name, phone, email, service_type, job_completion_date, consent_optin, date_added, source)
values
  ('b1b2c3d4-0001-4000-8000-000000000001', 'a1b2c3d4-0001-4000-8000-000000000001', 'Sarah', 'Sarah Botha', '27820000011', 'demo.sarah@example.com', 'Brake service', '2026-08-10', true, now() - interval '12 days', 'demo'),
  ('b1b2c3d4-0002-4000-8000-000000000001', 'a1b2c3d4-0001-4000-8000-000000000001', 'Michael', 'Michael Dlamini', '27820000012', 'demo.michael@example.com', 'Full service', '2026-08-15', true, now() - interval '7 days', 'demo'),
  ('b1b2c3d4-0001-4000-8000-000000000002', 'a1b2c3d4-0002-4000-8000-000000000002', 'Ayesha', 'Ayesha Patel', '27820000021', 'demo.ayesha@example.com', 'Teeth cleaning', '2026-08-12', true, now() - interval '10 days', 'demo'),
  ('b1b2c3d4-0002-4000-8000-000000000002', 'a1b2c3d4-0002-4000-8000-000000000002', 'Johan', 'Johan Pretorius', '27820000022', 'demo.johan@example.com', 'Filling', '2026-08-18', true, now() - interval '4 days', 'demo');

insert into activities (business_id, customer_id, activity_type, review_received, activity_status, channel, "timestamp", star_rating, star_number, review_comment, attempts)
values
  ('a1b2c3d4-0001-4000-8000-000000000001', 'b1b2c3d4-0001-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '11 days', 'FIVE', 5, 'Quick and honest service, will be back!', 1),
  ('a1b2c3d4-0001-4000-8000-000000000001', 'b1b2c3d4-0002-4000-8000-000000000001', 'Request Sent', false, 'Sent', 'WhatsApp', now() - interval '6 days', null, null, null, 1),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'b1b2c3d4-0001-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'Email', now() - interval '9 days', 'FOUR', 4, 'Friendly staff, a bit of a wait but worth it.', 1),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'b1b2c3d4-0002-4000-8000-000000000002', 'Request Sent', false, 'Sent', 'Email', now() - interval '3 days', null, null, null, 1);

insert into business_members (business_id, user_id, role)
select b.id, u.id, 'admin'
from businesses b
cross join auth.users u
where u.email = 'jonas.mohlala@gmail.com'
  and b.id in ('a1b2c3d4-0001-4000-8000-000000000001', 'a1b2c3d4-0002-4000-8000-000000000002')
on conflict (business_id, user_id) do update set role = 'admin';
