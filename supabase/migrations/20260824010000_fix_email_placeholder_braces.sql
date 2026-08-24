-- send-review-request.json's email subject .replace() calls used to look for
-- literal '{{business_name}}' / '{{first_name}}' inside email_subject_1..4.
-- That collides with n8n's own {{ }} expression delimiter syntax -- the
-- expression editor misparses the nested double braces as a second
-- expression boundary ("[ERROR: invalid syntax]"), discovered while
-- inspecting the cloned "Send a message Attempt N" nodes added for
-- attempt-based switching. Fixed workflow-side by switching to single-brace
-- placeholders ({business_name}, {first_name}); this migration updates the
-- one business with real values (Print Express) to match, so its emails
-- keep substituting correctly instead of leaking the raw placeholder text.

update businesses
set
  email_subject_1 = replace(replace(email_subject_1, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}'),
  email_subject_2 = replace(replace(email_subject_2, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}'),
  email_subject_3 = replace(replace(email_subject_3, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}'),
  email_subject_4 = replace(replace(email_subject_4, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}'),
  email_intro_1 = replace(replace(email_intro_1, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}'),
  email_intro_2 = replace(replace(email_intro_2, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}'),
  email_intro_3 = replace(replace(email_intro_3, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}'),
  email_intro_4 = replace(replace(email_intro_4, '{{business_name}}', '{business_name}'), '{{first_name}}', '{first_name}')
where email_subject_1 like '%{{%' or email_subject_2 like '%{{%'
   or email_subject_3 like '%{{%' or email_subject_4 like '%{{%'
   or email_intro_1 like '%{{%' or email_intro_2 like '%{{%'
   or email_intro_3 like '%{{%' or email_intro_4 like '%{{%';
