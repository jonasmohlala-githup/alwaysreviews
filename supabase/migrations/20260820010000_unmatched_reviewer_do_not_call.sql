-- The "Unmatched Reviewer" placeholder customer (see 20260817000000) relied
-- entirely on consent_optin's column default (false) plus an explicit filter
-- added later to send-review-request.json's eligibility query to avoid ever
-- being sent a review request. Neither of those actually expresses *why* --
-- do_not_call is the semantically correct flag for "not a real, callable
-- person," and a second, independent layer of protection beyond a column
-- default that something could accidentally flip.
--
-- This migration: (1) sets do_not_call = true on any existing placeholder
-- rows, and (2) updates create_unmatched_reviewer_placeholder() so every
-- future business's placeholder is created with do_not_call = true from the
-- start (the function body in 20260817000000_unmatched_reviewer_trigger.sql
-- was also updated to match, for anyone reading migrations top-to-bottom --
-- but only this migration actually re-applies the function on the live DB).

update customers
set do_not_call = true
where source = 'system' and full_name = 'Unmatched Reviewer';

create or replace function create_unmatched_reviewer_placeholder()
returns trigger as $$
begin
  insert into customers (business_id, full_name, first_name, phone, source, notes, do_not_call)
  values (
    new.id,
    'Unmatched Reviewer',
    'Unmatched',
    'N/A',
    'system',
    'Placeholder customer for GBP reviews that could not be confidently matched to a real customer record.',
    true
  );
  return new;
end;
$$ language plpgsql;
