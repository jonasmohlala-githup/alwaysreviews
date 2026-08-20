-- Inbound GBP Review Capture (n8n/inbound-gbp-review-capture.json) previously
-- had no error handling on the "List Reviews for Location" HTTP node. A
-- single business with a bad/unlinked gbp_account_id or location_id (Google
-- returns 400/403/404) would throw and abort the ENTIRE scheduled run,
-- silently skipping every other business's reviews for that cycle with no
-- record anywhere that anything failed.
--
-- Fix (workflow side): the HTTP node now uses onError: continueErrorOutput,
-- routing a failed fetch to its own error output instead of throwing. That
-- error output's item is just {error: "..."} -- business_id etc. are not
-- preserved on it, and pairedItem/itemMatching lookups back to the earlier
-- "Get Active Businesses with GBP" node are documented as unreliable
-- specifically across this node's error output (n8n issues #30050, #12558).
-- So a "Pair Failure with Business (by position)" Merge node re-attaches the
-- correct business_id by list position instead, before "Log GBP Fetch
-- Failure" writes the columns below.
--
-- Fix (schema side, this migration): give that logging step somewhere to
-- write. activities isn't a fit -- customer_id is NOT NULL and there's no
-- real customer for a sync failure, and activity_type/activity_status are
-- constrained enums that don't have a "sync error" value. Tracking the
-- failure directly on the businesses row is simpler and matches what an
-- operator actually wants to see ("is this business's GBP link broken right
-- now"), rather than an audit trail of every failed poll.

alter table businesses
  add column last_sync_error text,
  add column last_sync_error_at timestamptz;
