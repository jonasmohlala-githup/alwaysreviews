-- Replaces the single businesses.template_name with per-attempt template/copy
-- columns, so attempt 1 ("please review us") can read differently from attempt
-- 4 ("last reminder"). WhatsApp uses named templates (Pabbly looks these up by
-- name); email keeps its existing HTML shell (image, styled button, layout) but
-- injects a per-attempt subject + short intro line instead of being fully static.

alter table businesses
  add column whatsapp_template_1 text,
  add column whatsapp_template_2 text,
  add column whatsapp_template_3 text,
  add column whatsapp_template_4 text,
  add column email_subject_1 text,
  add column email_subject_2 text,
  add column email_subject_3 text,
  add column email_subject_4 text,
  add column email_intro_1 text,
  add column email_intro_2 text,
  add column email_intro_3 text,
  add column email_intro_4 text;

-- Backfill existing template_name into attempt 1 for any business that had one set,
-- so nothing silently breaks for rows created before this migration.
update businesses
set whatsapp_template_1 = template_name
where template_name is not null;

alter table businesses drop column template_name;
