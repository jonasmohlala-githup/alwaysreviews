-- review_request_v1..4 are unavailable as template names in Meta Business
-- Manager (already taken/registered elsewhere), so switch every business to
-- the alwaysreviews_ask_v1..4 naming instead, and update the column defaults
-- so new businesses get the new names too.

alter table businesses
  alter column whatsapp_template_1 set default 'alwaysreviews_ask_v1',
  alter column whatsapp_template_2 set default 'alwaysreviews_ask_v2',
  alter column whatsapp_template_3 set default 'alwaysreviews_ask_v3',
  alter column whatsapp_template_4 set default 'alwaysreviews_ask_v4';

update businesses
set
  whatsapp_template_1 = case when whatsapp_template_1 = 'review_request_v1' then 'alwaysreviews_ask_v1' else whatsapp_template_1 end,
  whatsapp_template_2 = case when whatsapp_template_2 = 'review_request_v2' then 'alwaysreviews_ask_v2' else whatsapp_template_2 end,
  whatsapp_template_3 = case when whatsapp_template_3 = 'review_request_v3' then 'alwaysreviews_ask_v3' else whatsapp_template_3 end,
  whatsapp_template_4 = case when whatsapp_template_4 = 'review_request_v4' then 'alwaysreviews_ask_v4' else whatsapp_template_4 end;
