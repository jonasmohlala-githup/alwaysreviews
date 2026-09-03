-- Print Express's review_request_link has been null since the column was
-- added, blocking both the email "Leave a Review" button and every WhatsApp
-- send (both "Validate WhatsApp Template" and "Validate Email Content" in
-- send-review-request.json throw if this is unset -- see
-- alwaysreviews-project-context.md line 550). Set it to the real GBP short
-- link so send-review-request.json can actually send once re-imported.

update businesses
set review_request_link = 'https://g.page/r/CfoxDhgwSOL5EBM/review'
where business_name = 'Print Express'
  and review_request_link is null;
