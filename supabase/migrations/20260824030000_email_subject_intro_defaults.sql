-- email_subject_1..4 / email_intro_1..4 turn out to be the same shared
-- wording for every business too (same decision as whatsapp_template_1..4 in
-- 20260824020000) -- confirmed with the user. Values are copied from Print
-- Express, the one business with real content; the {business_name}/
-- {first_name} placeholders in the subjects are substituted per-customer at
-- send time (see send-review-request.json's "Send a message" node), so the
-- shared default text is already correct for any business without edits.

alter table businesses
  alter column email_subject_1 set default 'Thanks for choosing {business_name}, {first_name}!',
  alter column email_subject_2 set default 'A quick favour, {first_name}?',
  alter column email_subject_3 set default 'We''d love your thoughts, {first_name}',
  alter column email_subject_4 set default 'One last thing, {first_name}',
  alter column email_intro_1 set default 'Thanks again for your business!',
  alter column email_intro_2 set default 'Just checking in — we''d still love to hear how we did.',
  alter column email_intro_3 set default 'Your feedback means a lot to us, whenever you have a moment.',
  alter column email_intro_4 set default 'This is our last note about it — no pressure at all!';

update businesses
set
  email_subject_1 = coalesce(email_subject_1, 'Thanks for choosing {business_name}, {first_name}!'),
  email_subject_2 = coalesce(email_subject_2, 'A quick favour, {first_name}?'),
  email_subject_3 = coalesce(email_subject_3, 'We''d love your thoughts, {first_name}'),
  email_subject_4 = coalesce(email_subject_4, 'One last thing, {first_name}'),
  email_intro_1 = coalesce(email_intro_1, 'Thanks again for your business!'),
  email_intro_2 = coalesce(email_intro_2, 'Just checking in — we''d still love to hear how we did.'),
  email_intro_3 = coalesce(email_intro_3, 'Your feedback means a lot to us, whenever you have a moment.'),
  email_intro_4 = coalesce(email_intro_4, 'This is our last note about it — no pressure at all!');
