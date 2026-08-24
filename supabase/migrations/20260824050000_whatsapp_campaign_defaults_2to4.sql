-- whatsapp_campaign_1 already defaults to 'review' (20260824040000). For
-- consistency with whatsapp_template_2..4 (which already carry placeholder
-- defaults -- review_request_v2/v3/v4 -- ahead of those templates actually
-- existing/being approved), whatsapp_campaign_2..4 get the same treatment:
-- placeholder Pabbly Campaign Names, following whatsapp_campaign_1's actual
-- naming ('review') rather than whatsapp_template's naming scheme, since
-- these are Pabbly campaign names, not Meta template names.
--
-- Same caveat as the template placeholders: these campaigns do NOT exist in
-- Pabbly yet. The "Validate WhatsApp Template" guard in
-- send-review-request.json only checks the column is non-null, not that the
-- campaign is real -- attempts 2-4 will still fail at Pabbly's end until
-- review_2/review_3/review_4 are actually created there as campaigns, each
-- with its own template selected in the "Select Template here" dropdown.

alter table businesses
  alter column whatsapp_campaign_2 set default 'review_2',
  alter column whatsapp_campaign_3 set default 'review_3',
  alter column whatsapp_campaign_4 set default 'review_4';

update businesses
set
  whatsapp_campaign_2 = coalesce(whatsapp_campaign_2, 'review_2'),
  whatsapp_campaign_3 = coalesce(whatsapp_campaign_3, 'review_3'),
  whatsapp_campaign_4 = coalesce(whatsapp_campaign_4, 'review_4');
