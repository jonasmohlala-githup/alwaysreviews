-- Auto-creates a per-business "Unmatched Reviewer" placeholder customer whenever a
-- new business is inserted. This is the fallback customer_id the inbound GBP review
-- capture workflow uses when a review's reviewer name can't be confidently matched
-- to a real customer (activities.customer_id is not null, so a fallback is required).
-- Without this trigger, every newly onboarded business would need this row created
-- manually, and forgetting it would break the review-matching workflow for that business.

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

create trigger businesses_after_insert
  after insert on businesses
  for each row
  execute function create_unmatched_reviewer_placeholder();
