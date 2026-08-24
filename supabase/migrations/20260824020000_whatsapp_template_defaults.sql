-- whatsapp_template_1..4 turn out to be the SAME Meta-approved template names
-- for every business (not per-business custom templates -- confirmed with the
-- user), so every new business needs the identical 4 values. Rather than
-- typing them per business at onboarding, give the columns DEFAULTs so a
-- plain insert (manual SQL, or any future onboarding form) gets them for free.
--
-- Values match what's already live on Print Express (the one business with
-- real data). v2-v4 are still placeholder names pending Meta approval -- see
-- alwaysreviews-project-context.md -- but the column-level default is correct
-- regardless: it's "the name every business should use," approved or not yet.
--
-- Existing businesses are backfilled to match (only Print Express already had
-- non-null values, which are left untouched by the where clause).

alter table businesses
  alter column whatsapp_template_1 set default 'review_request_v1',
  alter column whatsapp_template_2 set default 'review_request_v2',
  alter column whatsapp_template_3 set default 'review_request_v3',
  alter column whatsapp_template_4 set default 'review_request_v4';

update businesses
set
  whatsapp_template_1 = coalesce(whatsapp_template_1, 'review_request_v1'),
  whatsapp_template_2 = coalesce(whatsapp_template_2, 'review_request_v2'),
  whatsapp_template_3 = coalesce(whatsapp_template_3, 'review_request_v3'),
  whatsapp_template_4 = coalesce(whatsapp_template_4, 'review_request_v4');
