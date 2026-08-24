-- Seeds 10 demo businesses with customers + review activity history, for
-- demoing the dashboard/admin business-switcher with realistic-looking data.
-- Print Express remains the only real client; these are clearly-marked fake
-- accounts (contact_email uses a demo+ tag, notes flag them explicitly).
-- The businesses_after_insert trigger auto-creates each one's "Unmatched
-- Reviewer" placeholder customer on insert, same as any real business.
--
-- Each business gets 4-6 customers and a mix of activity outcomes (5★, 4★,
-- 3★ reviews received; some requests still Pending/Sent with no review yet;
-- one Failed send) so dashboard stats (requests sent, reviews received,
-- conversion rate, average rating) vary meaningfully business to business.

insert into businesses (id, business_name, contact_person, contact_email, contact_phone, status, notes)
values
  ('d1000000-0000-4000-8000-000000000001', 'Kimberley Auto Care', 'Pieter van der Merwe', 'demo+autocare@alwaysreviews.com', '27820000001', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000002', 'Bright Smile Dental', 'Dr. Naledi Khumalo', 'demo+dental@alwaysreviews.com', '27820000002', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000003', 'GreenLeaf Landscaping', 'Willem Botha', 'demo+landscaping@alwaysreviews.com', '27820000003', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000004', 'Diamond City Plumbing', 'Sipho Mokoena', 'demo+plumbing@alwaysreviews.com', '27820000004', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000005', 'Northgate Hair Studio', 'Chantelle du Preez', 'demo+hair@alwaysreviews.com', '27820000005', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000006', 'Sunrise Electrical Services', 'Thabo Nkosi', 'demo+electrical@alwaysreviews.com', '27820000006', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000007', 'Karoo Kitchen Restaurant', 'Elana Joubert', 'demo+restaurant@alwaysreviews.com', '27820000007', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000008', 'PawsCare Veterinary Clinic', 'Dr. Riaan Fourie', 'demo+vet@alwaysreviews.com', '27820000008', 'Active', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000009', 'Halfway House Fitness', 'Kagiso Molefe', 'demo+fitness@alwaysreviews.com', '27820000009', 'Paused', 'Demo business for pitch/demo purposes only.'),
  ('d1000000-0000-4000-8000-000000000010', 'Big Hole Bakery', 'Marlene Steyn', 'demo+bakery@alwaysreviews.com', '27820000010', 'Active', 'Demo business for pitch/demo purposes only.');

insert into customers (id, business_id, first_name, full_name, phone, email, service_type, job_completion_date, consent_optin, opt_out, do_not_call, date_added, source)
values
  -- Kimberley Auto Care
  ('c1000000-0001-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', 'Sarah', 'Sarah Botha', '27820000101', 'demo.sarah.botha@example.com', 'Brake service', '2026-08-10', true, false, false, now() - interval '14 days', 'demo'),
  ('c1000000-0001-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000001', 'Michael', 'Michael Dlamini', '27820000102', 'demo.michael.dlamini@example.com', 'Full service', '2026-08-15', true, false, false, now() - interval '9 days', 'demo'),
  ('c1000000-0001-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000001', 'Lindiwe', 'Lindiwe Mahlangu', '27820000103', 'demo.lindiwe@example.com', 'Tyre replacement', '2026-08-18', true, false, false, now() - interval '6 days', 'demo'),
  ('c1000000-0001-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000001', 'Frank', 'Frank Visser', '27820000104', 'demo.frank.visser@example.com', 'Wheel alignment', '2026-08-20', true, false, false, now() - interval '4 days', 'demo'),
  ('c1000000-0001-4000-8000-000000000005', 'd1000000-0000-4000-8000-000000000001', 'Portia', 'Portia Nkwe', '27820000105', 'demo.portia@example.com', 'Battery replacement', '2026-08-05', true, true, false, now() - interval '19 days', 'demo'),

  -- Bright Smile Dental
  ('c1000000-0002-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000002', 'Ayesha', 'Ayesha Patel', '27820000201', 'demo.ayesha@example.com', 'Teeth cleaning', '2026-08-12', true, false, false, now() - interval '12 days', 'demo'),
  ('c1000000-0002-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000002', 'Johan', 'Johan Pretorius', '27820000202', 'demo.johan@example.com', 'Filling', '2026-08-18', true, false, false, now() - interval '6 days', 'demo'),
  ('c1000000-0002-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000002', 'Zanele', 'Zanele Cele', '27820000203', 'demo.zanele@example.com', 'Root canal', '2026-08-14', true, false, false, now() - interval '10 days', 'demo'),
  ('c1000000-0002-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000002', 'Dawid', 'Dawid Human', '27820000204', 'demo.dawid@example.com', 'Whitening', '2026-08-21', true, false, false, now() - interval '3 days', 'demo'),

  -- GreenLeaf Landscaping
  ('c1000000-0003-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000003', 'Ben', 'Ben Coetzee', '27820000301', 'demo.ben@example.com', 'Garden redesign', '2026-08-08', true, false, false, now() - interval '16 days', 'demo'),
  ('c1000000-0003-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000003', 'Precious', 'Precious Zulu', '27820000302', 'demo.precious@example.com', 'Lawn installation', '2026-08-16', true, false, false, now() - interval '8 days', 'demo'),
  ('c1000000-0003-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000003', 'Riaan', 'Riaan Kruger', '27820000303', 'demo.riaan@example.com', 'Irrigation setup', '2026-08-19', true, false, false, now() - interval '5 days', 'demo'),
  ('c1000000-0003-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000003', 'Nomvula', 'Nomvula Radebe', '27820000304', 'demo.nomvula@example.com', 'Tree trimming', '2026-08-02', true, false, true, now() - interval '22 days', 'demo'),

  -- Diamond City Plumbing
  ('c1000000-0004-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000004', 'Werner', 'Werner Smit', '27820000401', 'demo.werner@example.com', 'Geyser replacement', '2026-08-11', true, false, false, now() - interval '13 days', 'demo'),
  ('c1000000-0004-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000004', 'Thandeka', 'Thandeka Mbeki', '27820000402', 'demo.thandeka@example.com', 'Burst pipe repair', '2026-08-17', true, false, false, now() - interval '7 days', 'demo'),
  ('c1000000-0004-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000004', 'Gert', 'Gert Nel', '27820000403', 'demo.gert@example.com', 'Drain unblocking', '2026-08-21', true, false, false, now() - interval '3 days', 'demo'),
  ('c1000000-0004-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000004', 'Fatima', 'Fatima Adams', '27820000404', 'demo.fatima@example.com', 'Bathroom fitting', '2026-08-13', true, false, false, now() - interval '11 days', 'demo'),

  -- Northgate Hair Studio
  ('c1000000-0005-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000005', 'Chané', 'Chané Fourie', '27820000501', 'demo.chane@example.com', 'Colour + cut', '2026-08-09', true, false, false, now() - interval '15 days', 'demo'),
  ('c1000000-0005-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000005', 'Boitumelo', 'Boitumelo Sithole', '27820000502', 'demo.boitumelo@example.com', 'Braids', '2026-08-17', true, false, false, now() - interval '7 days', 'demo'),
  ('c1000000-0005-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000005', 'Annelie', 'Annelie Venter', '27820000503', 'demo.annelie@example.com', 'Blow-out', '2026-08-22', true, false, false, now() - interval '2 days', 'demo'),

  -- Sunrise Electrical Services
  ('c1000000-0006-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000006', 'Kobus', 'Kobus Erasmus', '27820000601', 'demo.kobus@example.com', 'DB board upgrade', '2026-08-06', true, false, false, now() - interval '18 days', 'demo'),
  ('c1000000-0006-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000006', 'Nozipho', 'Nozipho Buthelezi', '27820000602', 'demo.nozipho@example.com', 'Load-shedding rewiring', '2026-08-15', true, false, false, now() - interval '9 days', 'demo'),
  ('c1000000-0006-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000006', 'Deon', 'Deon Marais', '27820000603', 'demo.deon@example.com', 'Solar inverter install', '2026-08-20', true, false, false, now() - interval '4 days', 'demo'),
  ('c1000000-0006-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000006', 'Palesa', 'Palesa Mokwena', '27820000604', 'demo.palesa@example.com', 'Fault finding', '2026-08-01', true, false, false, now() - interval '23 days', 'demo'),

  -- Karoo Kitchen Restaurant
  ('c1000000-0007-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000007', 'Jaco', 'Jaco Roux', '27820000701', 'demo.jaco@example.com', 'Dine-in', '2026-08-19', true, false, false, now() - interval '5 days', 'demo'),
  ('c1000000-0007-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000007', 'Naledi', 'Naledi Motaung', '27820000702', 'demo.naledi@example.com', 'Private function', '2026-08-14', true, false, false, now() - interval '10 days', 'demo'),
  ('c1000000-0007-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000007', 'Herman', 'Herman Swart', '27820000703', 'demo.herman@example.com', 'Dine-in', '2026-08-08', true, false, false, now() - interval '16 days', 'demo'),

  -- PawsCare Veterinary Clinic
  ('c1000000-0008-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000008', 'Elmarie', 'Elmarie Basson', '27820000801', 'demo.elmarie@example.com', 'Vaccination', '2026-08-12', true, false, false, now() - interval '12 days', 'demo'),
  ('c1000000-0008-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000008', 'Sizwe', 'Sizwe Ndlovu', '27820000802', 'demo.sizwe@example.com', 'Sterilisation', '2026-08-16', true, false, false, now() - interval '8 days', 'demo'),
  ('c1000000-0008-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000008', 'Retha', 'Retha Oosthuizen', '27820000803', 'demo.retha@example.com', 'Dental cleaning', '2026-08-20', true, false, false, now() - interval '4 days', 'demo'),
  ('c1000000-0008-4000-8000-000000000004', 'd1000000-0000-4000-8000-000000000008', 'Katlego', 'Katlego Phiri', '27820000804', 'demo.katlego@example.com', 'Emergency consult', '2026-08-03', true, false, false, now() - interval '21 days', 'demo'),

  -- Halfway House Fitness (paused business)
  ('c1000000-0009-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000009', 'Anton', 'Anton Grobler', '27820000901', 'demo.anton@example.com', 'Personal training', '2026-07-28', true, false, false, now() - interval '27 days', 'demo'),
  ('c1000000-0009-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000009', 'Lerato', 'Lerato Sekhukhune', '27820000902', 'demo.lerato@example.com', 'Group class package', '2026-08-01', true, false, false, now() - interval '23 days', 'demo'),

  -- Big Hole Bakery
  ('c1000000-0010-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000010', 'Melissa', 'Melissa Jacobs', '27820001001', 'demo.melissa@example.com', 'Wedding cake', '2026-08-15', true, false, false, now() - interval '9 days', 'demo'),
  ('c1000000-0010-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000010', 'Vusi', 'Vusi Khumalo', '27820001002', 'demo.vusi@example.com', 'Birthday order', '2026-08-19', true, false, false, now() - interval '5 days', 'demo'),
  ('c1000000-0010-4000-8000-000000000003', 'd1000000-0000-4000-8000-000000000010', 'Elani', 'Elani Pretorius', '27820001003', 'demo.elani@example.com', 'Daily bread order', '2026-08-22', true, false, false, now() - interval '2 days', 'demo');

insert into activities (business_id, customer_id, activity_type, review_received, activity_status, channel, "timestamp", star_rating, star_number, review_comment, attempts)
values
  -- Kimberley Auto Care (5 customers: 5★, 4★, pending, sent no review yet, opted-out no send)
  ('d1000000-0000-4000-8000-000000000001', 'c1000000-0001-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '13 days', 'FIVE', 5, 'Quick and honest service, will be back!', 1),
  ('d1000000-0000-4000-8000-000000000001', 'c1000000-0001-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '8 days', 'FOUR', 4, 'Good work, took a bit longer than quoted.', 1),
  ('d1000000-0000-4000-8000-000000000001', 'c1000000-0001-4000-8000-000000000003', 'Follow-up', false, 'Sent', 'WhatsApp', now() - interval '1 days', null, null, null, 2),
  ('d1000000-0000-4000-8000-000000000001', 'c1000000-0001-4000-8000-000000000004', 'Request Sent', false, 'Sent', 'WhatsApp', now() - interval '3 days', null, null, null, 1),

  -- Bright Smile Dental (5★, 4★, 3★, pending)
  ('d1000000-0000-4000-8000-000000000002', 'c1000000-0002-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'Email', now() - interval '11 days', 'FIVE', 5, 'Painless and the staff are so friendly!', 1),
  ('d1000000-0000-4000-8000-000000000002', 'c1000000-0002-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'Email', now() - interval '5 days', 'FOUR', 4, 'Friendly staff, a bit of a wait but worth it.', 1),
  ('d1000000-0000-4000-8000-000000000002', 'c1000000-0002-4000-8000-000000000003', 'Request Sent', true, 'Completed', 'Email', now() - interval '9 days', 'THREE', 3, 'Procedure was fine but reception was slow to confirm my appointment.', 1),
  ('d1000000-0000-4000-8000-000000000002', 'c1000000-0002-4000-8000-000000000004', 'Request Sent', false, 'Sent', 'Email', now() - interval '2 days', null, null, null, 1),

  -- GreenLeaf Landscaping (5★, 5★, pending, do_not_call customer excluded so only 3 activities)
  ('d1000000-0000-4000-8000-000000000003', 'c1000000-0003-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '15 days', 'FIVE', 5, 'Transformed our garden, highly recommend!', 1),
  ('d1000000-0000-4000-8000-000000000003', 'c1000000-0003-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '7 days', 'FIVE', 5, 'Lawn looks amazing, great communication throughout.', 1),
  ('d1000000-0000-4000-8000-000000000003', 'c1000000-0003-4000-8000-000000000003', 'Request Sent', false, 'Sent', 'WhatsApp', now() - interval '4 days', null, null, null, 1),

  -- Diamond City Plumbing (5★, 4★, failed send, pending)
  ('d1000000-0000-4000-8000-000000000004', 'c1000000-0004-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '12 days', 'FIVE', 5, 'Came out same day, fixed it fast. Fair price too.', 1),
  ('d1000000-0000-4000-8000-000000000004', 'c1000000-0004-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '6 days', 'FOUR', 4, 'Solid job, cleaned up after themselves.', 1),
  ('d1000000-0000-4000-8000-000000000004', 'c1000000-0004-4000-8000-000000000003', 'Failed', false, 'Failed', 'WhatsApp', now() - interval '2 days', null, null, null, 1),
  ('d1000000-0000-4000-8000-000000000004', 'c1000000-0004-4000-8000-000000000004', 'Request Sent', false, 'Sent', 'Email', now() - interval '10 days', null, null, null, 1),

  -- Northgate Hair Studio (5★, pending, sent)
  ('d1000000-0000-4000-8000-000000000005', 'c1000000-0005-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '14 days', 'FIVE', 5, 'Obsessed with my colour, exactly what I wanted!', 1),
  ('d1000000-0000-4000-8000-000000000005', 'c1000000-0005-4000-8000-000000000002', 'Follow-up', false, 'Sent', 'WhatsApp', now() - interval '1 days', null, null, null, 2),
  ('d1000000-0000-4000-8000-000000000005', 'c1000000-0005-4000-8000-000000000003', 'Request Sent', false, 'Sent', 'WhatsApp', now() - interval '1 days', null, null, null, 1),

  -- Sunrise Electrical Services (5★, 3★, 5★, pending)
  ('d1000000-0000-4000-8000-000000000006', 'c1000000-0006-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '17 days', 'FIVE', 5, 'Professional and explained everything clearly.', 1),
  ('d1000000-0000-4000-8000-000000000006', 'c1000000-0006-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '8 days', 'THREE', 3, 'Job got done but arrived 2 hours late without a call.', 1),
  ('d1000000-0000-4000-8000-000000000006', 'c1000000-0006-4000-8000-000000000003', 'Request Sent', true, 'Completed', 'Email', now() - interval '3 days', 'FIVE', 5, 'Excellent install, very neat cabling work.', 1),
  ('d1000000-0000-4000-8000-000000000006', 'c1000000-0006-4000-8000-000000000004', 'Request Sent', false, 'Sent', 'WhatsApp', now() - interval '22 days', null, null, null, 1),

  -- Karoo Kitchen Restaurant (4★, 5★, pending)
  ('d1000000-0000-4000-8000-000000000007', 'c1000000-0007-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '4 days', 'FOUR', 4, 'Great food, lovely atmosphere. Service was a little slow.', 1),
  ('d1000000-0000-4000-8000-000000000007', 'c1000000-0007-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'Email', now() - interval '9 days', 'FIVE', 5, 'Best lamb potjie in Kimberley, hands down.', 1),
  ('d1000000-0000-4000-8000-000000000007', 'c1000000-0007-4000-8000-000000000003', 'Request Sent', false, 'Sent', 'WhatsApp', now() - interval '15 days', null, null, null, 1),

  -- PawsCare Veterinary Clinic (5★, 5★, 4★, pending)
  ('d1000000-0000-4000-8000-000000000008', 'c1000000-0008-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'Email', now() - interval '11 days', 'FIVE', 5, 'So gentle with our nervous dog, thank you!', 1),
  ('d1000000-0000-4000-8000-000000000008', 'c1000000-0008-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'Email', now() - interval '7 days', 'FIVE', 5, 'Caring team, fair pricing, highly recommend.', 1),
  ('d1000000-0000-4000-8000-000000000008', 'c1000000-0008-4000-8000-000000000003', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '3 days', 'FOUR', 4, 'Good visit, parking is a bit tricky.', 1),
  ('d1000000-0000-4000-8000-000000000008', 'c1000000-0008-4000-8000-000000000004', 'Request Sent', false, 'Sent', 'Email', now() - interval '20 days', null, null, null, 1),

  -- Halfway House Fitness (paused; older activity only, no recent sends)
  ('d1000000-0000-4000-8000-000000000009', 'c1000000-0009-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '26 days', 'FOUR', 4, 'Good trainers, gym could use more equipment.', 1),
  ('d1000000-0000-4000-8000-000000000009', 'c1000000-0009-4000-8000-000000000002', 'Request Sent', false, 'Sent', 'WhatsApp', now() - interval '22 days', null, null, null, 1),

  -- Big Hole Bakery (5★, 5★, pending)
  ('d1000000-0000-4000-8000-000000000010', 'c1000000-0010-4000-8000-000000000001', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '8 days', 'FIVE', 5, 'The cake was stunning and tasted even better!', 1),
  ('d1000000-0000-4000-8000-000000000010', 'c1000000-0010-4000-8000-000000000002', 'Request Sent', true, 'Completed', 'WhatsApp', now() - interval '4 days', 'FIVE', 5, 'Kids loved it, will order again for sure.', 1),
  ('d1000000-0000-4000-8000-000000000010', 'c1000000-0010-4000-8000-000000000003', 'Request Sent', false, 'Sent', 'Email', now() - interval '1 days', null, null, null, 1);

insert into business_members (business_id, user_id, role)
select b.id, u.id, 'admin'
from businesses b
cross join auth.users u
where u.email = 'jonas.mohlala@gmail.com'
  and b.id in (
    'd1000000-0000-4000-8000-000000000001',
    'd1000000-0000-4000-8000-000000000002',
    'd1000000-0000-4000-8000-000000000003',
    'd1000000-0000-4000-8000-000000000004',
    'd1000000-0000-4000-8000-000000000005',
    'd1000000-0000-4000-8000-000000000006',
    'd1000000-0000-4000-8000-000000000007',
    'd1000000-0000-4000-8000-000000000008',
    'd1000000-0000-4000-8000-000000000009',
    'd1000000-0000-4000-8000-000000000010'
  )
on conflict (business_id, user_id) do update set role = 'admin';
