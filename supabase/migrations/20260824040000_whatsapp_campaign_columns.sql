-- Pabbly's "API Campaign" broadcast type ties one Meta-approved template to
-- a Campaign Name at creation time in their dashboard (confirmed via a real
-- Pabbly curl example: {templateName, campaignName} are both distinct,
-- required fields). Since each attempt (1-4) needs its own template, each
-- attempt also needs its own pre-created Pabbly campaign -- campaignName was
-- previously hardcoded to "review" (the one campaign that exists so far,
-- covering attempt 1 only). These columns hold the other 3 campaign names
-- once created in Pabbly, mirroring whatsapp_template_1..4's per-attempt
-- pattern exactly.
--
-- Default for attempt 1 is 'review' (the real, already-created campaign).
-- Attempts 2-4 default to null -- deliberately NOT a placeholder name like
-- whatsapp_template_2..4 got, since a wrong-but-plausible campaign name
-- would pass validation and then fail at Pabbly with a less clear error.
-- Set these once the corresponding campaign actually exists in Pabbly.

alter table businesses
  add column whatsapp_campaign_1 text default 'review',
  add column whatsapp_campaign_2 text,
  add column whatsapp_campaign_3 text,
  add column whatsapp_campaign_4 text;

update businesses
set whatsapp_campaign_1 = coalesce(whatsapp_campaign_1, 'review');
