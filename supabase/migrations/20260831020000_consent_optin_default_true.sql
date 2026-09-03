-- consent_optin now defaults to true: a customer is eligible for review
-- requests from the moment they're added, until a business explicitly
-- opts them out via customers.opt_out (set through web/customers.html).
-- The website's Add Customer form already always submits true (its consent
-- checkbox was removed 2026-08-31); this migration makes the same default
-- true at the schema level so any other insert path (manual SQL, a future
-- integration) doesn't silently fall back to false and get excluded from
-- send-review-request.json's eligibility query with no obvious error.
alter table customers alter column consent_optin set default true;
