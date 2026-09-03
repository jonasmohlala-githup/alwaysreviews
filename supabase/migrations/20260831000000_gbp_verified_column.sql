-- Tracks whether a business's Google Business Profile is verified with Google.
-- Verification is a precondition for the AI reply workflow (Post Reply to GBP)
-- to actually work — Google rejects reply attempts on unverified profiles.
-- This is a manual onboarding check (not derivable via the existing GBP API
-- calls this project makes), set by whoever onboards the business.
alter table businesses
  add column gbp_verified boolean not null default false;

comment on column businesses.gbp_verified is
  'Whether this business''s Google Business Profile is verified with Google. Verification is required before Google will accept automated review replies (inbound-gbp-review-capture.json''s Post Reply to GBP step). Set manually during onboarding — not derived from any API call this project makes.';
