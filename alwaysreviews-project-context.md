# Always Reviews — Project Context & Conversation Log

Saved so context isn't lost if the conversation is cleared. Covers everything decided/built in the Supabase + n8n review-automation project, in order.

## Project summary

Moving a 3-sheet Google Sheets design (Business / Customer / Activity) into Supabase, to back: (1) n8n automations that send WhatsApp/email review requests to customers, follow up over time, and capture/reply to reviews from Google Business Profile (GBP); and (2) a small authenticated website where each business logs in to add their own customers and see their own activity dashboard, with Row Level Security enforcing that businesses can never see or write each other's data.

Supabase project ref: `xbmoomufmxicwymwbovg`
Dashboard: https://supabase.com/dashboard/project/xbmoomufmxicwymwbovg

## Original Google Sheets design (starting point)

Three sheets, relational, linked by IDs:
- **Business** (parent) — one row per client business
- **Customer** — belongs to a business via `business_id`
- **Activity** — one row per event (request sent, review received, etc.), links to both `business_id` and `customer_id`

Why Activity as one event log: every meaningful event (request sent, follow-up, review landing, reply posted) is a new row with a different `activity_type` — makes reporting (conversion rate, ROI proof) trivial.

## Key decisions made (in order)

1. **Multi-tenant vs backend-only access** → started backend-only (only n8n via service role key), later reversed (see Auth/RLS addendum below) once a *universal* customer-intake form was needed.
2. **ID strategy** → UUIDs (`gen_random_uuid()`), not human-readable codes like the sheet's B001/C0001/A00001.
3. **Data migration** → none; fresh schema, no import from the old sheet.
4. Removed `staff_member` from customers; added `do_not_call` boolean.
5. Removed `scheduled_time` from activities.
6. Renamed `followup_number` → `attempts` on activities.
7. Split `activity_type` — removed `'Review Received'` as a type value, added standalone `review_received boolean` column instead (a review can land against any activity type, e.g. a Follow-up, so it shouldn't be conflated with the type field itself).
8. Removed `delivery_status` from activities (redundant with `activity_status`).
9. Auth/RLS initially deferred, then **reinstated** (see addendum) once the intake form needed to be a single universal link shared by all businesses rather than one link per business — this made a real per-business identity check necessary, not just optional.

## Final schema (as currently live in Supabase)

### `businesses`
- `id` uuid PK, default `gen_random_uuid()`
- `business_name` text, not null
- `gbp_account_id` text — e.g. `106094372846074475885`
- `location_id` text — e.g. `16453991512344519012`
- `whatsapp_sender_number` text
- `contact_person`, `contact_email`, `contact_phone` text
- `status` text, `Active`/`Paused`, default `Active`
- `onboarded_date` date, default now()
- `notes` text
- `created_at` timestamptz, default now()
- `review_request_link` text — added later; the business's Google "leave a review" URL, same for every customer of that business
- **`template_name` removed**, replaced with per-attempt columns (see below) so follow-up wording can differ from the first ask:
  - `whatsapp_template_1`, `whatsapp_template_2`, `whatsapp_template_3`, `whatsapp_template_4` text — Pabbly Chatflow template names, one per attempt number
  - `email_subject_1..4`, `email_intro_1..4` text — per-attempt email subject line and opening sentence; the rest of the email (photo, button, footer) stays a fixed HTML shell in the n8n workflow
  - Migration: `supabase/migrations/20260817120000_per_attempt_templates.sql` — backfilled the old `template_name` value into `whatsapp_template_1` for any existing business before dropping the column, so nothing broke on migration
  - Print Express has all 12 columns filled with real example values (see workflow #1 below for the actual wording)

### `customers`
- `id` uuid PK
- `business_id` uuid, FK → businesses, `on delete cascade`
- `first_name`, `full_name` text
- `phone` text, not null — WhatsApp intl format, no `+`
- `email` text
- `service_type` text
- `job_completion_date` date
- `consent_optin`, `opt_out`, `do_not_call` boolean, default false
- `date_added` timestamptz, default now()
- `source` text
- `notes` text
- `project_image_url` text — added later; photo of the customer's specific job/project (increases review-request personalization/conversion). **Per-customer, not per-business** — this was explicitly discussed and confirmed.
- index on `business_id`

### `activities`
- `id` uuid PK
- `business_id`, `customer_id` uuid, FKs, `on delete cascade`
- `activity_type` text, not null, check in `('Request Sent','Follow-up','Reply Sent','Failed','Opt-Out')`
- `review_received` boolean, not null, default false
- `activity_status` text, check in `('Pending','Sent','Delivered','Read','Failed','Completed')`
- `channel` text, check in `('WhatsApp','SMS','Email')`
- `template_name` text
- `personalized_image_url` text — copy of the image actually sent with that specific request (immutable historical record, even if `customers.project_image_url` changes later)
- `timestamp` timestamptz, default now()
- `message_id` text — wamid from Chatflow
- `review_id`, `star_rating` (word form, e.g. `FIVE`), `star_number` (1-5, checked), `review_comment`, `review_link`, `reply_text` text
- `attempts` smallint — tracks how many requests sent to this customer; capped at 4 in the eligibility query to prevent spam
- `notes` text
- indexes on `business_id`, `customer_id`, `activity_type`

### `business_members` (added later, for Auth/RLS)
- `id` uuid PK
- `business_id` uuid, FK → businesses
- `user_id` uuid, FK → `auth.users`
- `role` text, default `staff`, check in `('owner','staff')`
- unique `(business_id, user_id)`

### Row Level Security
RLS enabled on `businesses`, `customers`, `activities`. Policy pattern (same on all three, keyed on `business_id` or `id`):
```sql
create policy "member access" on customers
  for all using (
    business_id in (select business_id from business_members where user_id = auth.uid())
  );
```
n8n continues to use the **service role key**, which bypasses RLS — existing workflows unaffected. `business_members` itself has no RLS policy (only reachable via service role for now).

## Migrations applied (in `supabase/migrations/`)

1. `20260813000000_init.sql` — the three core tables, constraints, indexes.
2. `20260815000000_business_members_rls.sql` — `business_members` table + RLS policies on all three core tables.
3. `20260817000000_unmatched_reviewer_trigger.sql` — `after insert on businesses` trigger that auto-creates each new business's "Unmatched Reviewer" placeholder customer (see workflow #3 below).
4. `20260817120000_per_attempt_templates.sql` — replaces `businesses.template_name` with 12 per-attempt columns (`whatsapp_template_1..4`, `email_subject_1..4`, `email_intro_1..4`), backfilling the old value into attempt 1.
5. `20260818000000_business_members_enable_rls.sql` — enables RLS on `business_members` + "read own membership" policy. **Note**: this migration existed as a file since 2026-08-18 but was never actually pushed to the remote database until 2026-08-20 (see below) — the policy itself was already live on the DB (applied manually at some point), just not recorded in Supabase's migration-history table. Repaired via `supabase migration repair --status applied` rather than re-run.
6. `20260820000000_business_sync_error_tracking.sql` — adds `businesses.last_sync_error` (text) and `businesses.last_sync_error_at` (timestamptz), written by the GBP-capture workflow's new error-handling branch (see workflow #3). Pushed to the remote database 2026-08-20 via `supabase db push` (project linked with `supabase link --project-ref xbmoomufmxicwymwbovg` using the personal access token from `.env`).
7. `20260820010000_unmatched_reviewer_do_not_call.sql` — sets `do_not_call = true` on the "Unmatched Reviewer" placeholder (both backfilling existing rows and updating `create_unmatched_reviewer_placeholder()` so every future business's placeholder is created this way from the start). Previously this placeholder was excluded from outbound review requests only by coincidence (`consent_optin`'s column default happens to be `false`) plus a query-level filter added the same session (see workflow #1) — `do_not_call = true` is a second, independent, semantically-correct layer: it's not a real, callable person, and this flag says so directly rather than relying on a default that something could accidentally flip. Verified: existing Print Express placeholder now shows `do_not_call: true`; a fresh throwaway test business's auto-created placeholder also came through correctly, then the test business was deleted (cascade removed its placeholder too).

(Note: `review_request_link` and `project_image_url` were added via ad-hoc `ALTER TABLE` through the CLI, not as tracked migration files — worth formalizing into a migration later if this repo needs to stay fully reproducible from migrations alone.)

## Supabase Storage

Bucket: `customer-project-images`
- Public read, 10MB file size limit
- Allowed MIME types: png, jpeg, jpg, webp, heic
- Used to store customer project photos uploaded via the intake form; public URL gets written to `customers.project_image_url`

## Test data currently in the database

- **Business**: Print Express, `id = 36154da1-adb4-4487-a47a-c09d1e9509bd`
  - `gbp_account_id = 106094372846074475885`, `location_id = 16453991512344519012`
  - Kimberley location, toner cartridge supplier
- **Customer**: Veronica Mohlala (originally "Thabo Nkosi", renamed), `id = 28fe3adc-adff-49f9-9369-166431533dbd`
  - `email = printexpressnamakwa@gmail.com`
  - phone `27608491313`
- **Activity**: one "Request Sent" / WhatsApp / Sent row, `id = 0d997886-7516-4d94-9629-c1cf756c8523`
- **Auth user**: `jonas.mohlala@gmail.com`, `id = 0b146b20-42a0-4d63-a26e-afc507838c69`, linked to Print Express via `business_members` as `owner`

## n8n workflows

### 1. Outbound "send review request" workflow — ✅ built, corrected twice, and extended with follow-up scheduling
File: `n8n/send-review-request.json` (exported from n8n as "Google GBP Send Review Request", edited here, needs re-import; `active: false` as of 2026-08-20)

**User originally reported this as done**, but exporting it from n8n to add follow-up scheduling revealed the live version had real gaps not visible from the n8n canvas alone:
- **The IF node's true/false branches were disconnected** (`"main": [[], []]` in the export) — neither WhatsApp nor email paths were actually wired to fire.
- **No activity-logging node existed at all** — the workflow ended at the Gmail/HTTP Request send steps with nothing writing back to `activities`. This meant `attempt_count` could never increase, silently breaking the spam cap and (once added) the follow-up spacing, since there'd be nothing to count.
- **The Pabbly Chatflow HTTP body and Gmail fields still had hardcoded test values** left over from manual testing (`destination: "27795079693"`, `userName: "Jon"`, `sendTo: "printexpressnamakwa@gmail.com"`, `subject: "hello"`, a hardcoded Pexels image URL) instead of live expressions pulling from the query results.

**All fixed in the same pass as adding follow-up scheduling** (user approved this broader scope rather than just the originally-planned query change):

**Full current chain:**
```
Every Day (Schedule Trigger, daily) → Execute a SQL query (Postgres, eligible customers incl. follow-up logic)
  → If (phone exists?)
      ├─ true  → HTTP Request (Pabbly Chatflow, live expressions) → Log WhatsApp Send (Postgres insert, channel='WhatsApp')
      └─ false → Send a message (Gmail, HTML template, live expressions) → Log Email Send (Postgres insert, channel='Email')
```

**Eligibility query — includes follow-up scheduler logic AND per-attempt template selection:**
```sql
select c.id as customer_id, c.business_id, c.first_name, c.full_name, c.phone, c.email,
       c.project_image_url,
       b.business_name, b.review_request_link, b.whatsapp_sender_number,
       coalesce(a.attempt_count, 0) as attempt_count,
       case coalesce(a.attempt_count, 0) + 1
         when 1 then b.whatsapp_template_1
         when 2 then b.whatsapp_template_2
         when 3 then b.whatsapp_template_3
         when 4 then b.whatsapp_template_4
       end as whatsapp_template,
       case coalesce(a.attempt_count, 0) + 1
         when 1 then b.email_subject_1
         when 2 then b.email_subject_2
         when 3 then b.email_subject_3
         when 4 then b.email_subject_4
       end as email_subject,
       case coalesce(a.attempt_count, 0) + 1
         when 1 then b.email_intro_1
         when 2 then b.email_intro_2
         when 3 then b.email_intro_3
         when 4 then b.email_intro_4
       end as email_intro
from customers c
join businesses b on b.id = c.business_id
left join (
  select customer_id, count(*) as attempt_count, max(timestamp) as last_attempt_at
  from activities
  where activity_type = 'Request Sent'
  group by customer_id
) a on a.customer_id = c.id
where c.opt_out = false
  and c.do_not_call = false
  and c.consent_optin = true
  and not (c.source = 'system' and c.full_name = 'Unmatched Reviewer')
  and b.status = 'Active'
  and coalesce(a.attempt_count, 0) < 4
  and not exists (
    select 1 from activities r
    where r.customer_id = c.id and r.review_received = true
  )
  and (
    a.last_attempt_at is null
    or a.last_attempt_at <= now() - (
      case coalesce(a.attempt_count, 0)
        when 1 then interval '5 days'
        when 2 then interval '10 days'
        when 3 then interval '20 days'
      end
    )
  )
```
- **Follow-up gap schedule**: 5 days after attempt 1, 10 days after attempt 2, 20 days after attempt 3 (increasing gaps, chosen over fixed/aggressive options — user picked the more relaxed schedule).
- **Stop condition**: `not exists (... review_received = true ...)` — a customer stops receiving follow-ups the instant their review is matched via workflow #3 (only works when matched to the real customer, not the "Unmatched Reviewer" placeholder — inherent limitation of name-based matching).
- **`do_not_call`/`opt_out` were already excluding customers from every attempt, not just follow-ups** — confirmed explicitly with the user, no change needed, this was already correct in the original query.
- **Per-attempt template selection** (added after the follow-up scheduler): three `case` expressions pick the right WhatsApp template name / email subject / email intro based on `attempt_count + 1` — i.e. which attempt is about to be sent. Replaces the old single fixed `template_name`.
- Note: `activity_type = 'Request Sent'` filter matters because without it, the count would include unrelated activity types (Reply Sent, Opt-Out, etc.) and wrongly inflate/deflate the spam-cap count — it needs to count only actual outbound asks.
- **Added 2026-08-20**: `not (c.source = 'system' and c.full_name = 'Unmatched Reviewer')` — explicitly excludes the auto-created GBP-matching placeholder customer (see workflow #3) from ever receiving a review request. Was already excluded today only by coincidence, via `consent_optin`'s column default (`false`) — this makes the exclusion explicit and no longer dependent on that default never changing. Verified via `EXPLAIN` and a live-data comparison (no behavior change today, since the placeholder's `consent_optin` was already `false`). Also see the `do_not_call = true` fix below — now two independent layers of protection.

**Both "Log ... Send" queries** (one per channel; `notes` records which attempt number was sent, and for email, the actual subject used). **Rewritten 2026-08-20 as parameterized queries** — see "SQL injection fixes" note below:
```sql
insert into activities (
  business_id, customer_id, activity_type, activity_status, channel,
  template_name, personalized_image_url, attempts, notes
) values (
  $1, $2, 'Request Sent', 'Sent', 'Email', $3, $4, $5, $6
)
returning id;
```
(`queryReplacement`: `={{ [$json.business_id, $json.customer_id, $json.email_subject, $json.project_image_url, $json.attempt_count + 1, "Sent via n8n email workflow — attempt " + ($json.attempt_count + 1)] }}` — WhatsApp version identical shape, `channel = 'WhatsApp'`, `$3 = whatsapp_template`.)

**Email HTML template (Gmail node), now varies per attempt:**
- Square project image via a `<table>`-contained `<img>` (Gmail strips CSS sizing unless done this way), 300px, `object-fit: cover`, with a fallback to the Pexels placeholder if `project_image_url` is null
- **Subject** = `{{ $json.email_subject }}` (with `{{business_name}}`/`{{first_name}}` placeholders substituted via `.replace()`), **opening line** = `{{ $json.email_intro }}` — both vary by attempt number. Rest of the layout (photo, "Could you leave us a quick Google review?", button, "Thank you!", sign-off) is a fixed shell, same every time.
- Left-aligned "Leave a Review" button (`{{ $json.review_request_link }}`)

**Current example wording set for Print Express** (same warm tone across all 4 attempts, no escalation in urgency — user's explicit preference):

| Attempt | Email subject | Email intro | WhatsApp template name |
|---|---|---|---|
| 1 | Thanks for choosing {{business_name}}, {{first_name}}! | Thanks again for your business! | `review_request_v1` (real, approved) |
| 2 | A quick favour, {{first_name}}? | Just checking in — we'd still love to hear how we did. | `review_request_v2` (**placeholder name only — not yet written/approved**) |
| 3 | We'd love your thoughts, {{first_name}} | Your feedback means a lot to us, whenever you have a moment. | `review_request_v3` (**placeholder**) |
| 4 | One last thing, {{first_name}} | This is our last note about it — no pressure at all! | `review_request_v4` (**placeholder**) |

**Open gap**: only `review_request_v1` is a real WhatsApp template that Meta has approved (it's the one already in use). `v2`/`v3`/`v4` are just names sitting in the database — no actual message content has been written or submitted for approval yet. WhatsApp requires every template to be pre-approved before it can send. Attempts 2-4 via WhatsApp will not actually send until real templates are written and approved (email attempts 2-4 work today, since email has no equivalent approval requirement).

**Channel branching logic**: branch on `customers.phone` (not `businesses.whatsapp_sender_number` — that field is per-business, identical across all of a business's customers, so it can't distinguish which *customers* have WhatsApp). The IF node's condition is `$json.phone notExists` (true when phone is NULL/missing).

**Real bug found and fixed 2026-08-20 — branches were STILL inverted, despite the earlier "now actually wired" note above being written in good faith**: the IF node's true output (`main[0]`, phone does NOT exist) was connected to "HTTP Request" (WhatsApp/Pabbly), and its false output (`main[1]`, phone DOES exist) was connected to "Send a message" (Gmail) — exactly backwards. Confirmed against live data: Veronica Mohlala has a real phone number (`27608491313`), so she'd have been routed to email, not WhatsApp, under this wiring. A customer with no phone would have been sent to WhatsApp, guaranteed to fail (`destination: null`). Verified n8n's `notExists` semantics directly against source code first (checks for `undefined`/`null`/`NaN`, not falsy-in-general; SQL `NULL` deserializes to JSON `null`, key always present — so `notExists` correctly resolves true for a customer with no phone on file) before concluding the wiring itself, not the condition, was wrong. **Fixed** by swapping which node each branch output connects to: true (no phone) → Gmail, false (has phone) → WhatsApp — now matches the intent described in this very paragraph.

**Credential handling**: the Pabbly Chatflow API key (`pcf_7cc763...`) was hardcoded in the exported workflow JSON — moved to `.env` as `PABBLY_CHATFLOW_API_KEY`, and the HTTP Request node now references a proper n8n **Header Auth** credential (`pabblyChatflowApi`, placeholder ID — needs creating in n8n: header name `Authorization`, value `Bearer <key from .env>`) instead of a bare string in the node. **Never put an API token inside a JSON request body** — it belongs in the `Authorization` header via a credential, not as a data field; this was explicitly clarified with the user after they asked whether pasting a token into the body (copied from a Pabbly curl example) was safe. Same exposure caveat as other keys — was visible in the export and in chat, worth rotating with Pabbly eventually.

**Setup needed before this can run:**
- Re-import `n8n/send-review-request.json` into n8n (Postgres/Gmail credential IDs preserved from the original export, may reconnect automatically)
- Create the `pabblyChatflowApi` Header Auth credential and attach it to "HTTP Request"
- Write and submit real WhatsApp template content for attempts 2-4 for Meta approval
- Verify the Pabbly Chatflow request body shape actually matches what their API expects (based on the user's original working test payload, now parameterized — not independently re-verified against Pabbly's docs)
- **Re-import into n8n to pick up the 2026-08-20 fixes** (IF-branch swap, placeholder exclusion, parameterized Log Send queries) — none of these are live until re-imported; `active: false` currently.

### 2. Customer intake — ✅ website + n8n webhook (Gemini personalization restored)

**Resolved (this session)**: rather than building a separate Supabase Edge Function for the Gemini overlay, the user pointed out the existing n8n workflow already did the overlay+upload+insert chain correctly — it just needed its entry point swapped from a public Form Trigger (dropdown business selection, no auth) to a Webhook that the authenticated website calls, passing the RLS-verified `business_id` directly instead of trusting a dropdown value. This reuses all the working Gemini/Storage/Postgres logic instead of rebuilding it.

**`n8n/customer-intake-form.json` rebuilt** (workflow renamed "Customer Intake (Webhook)"):
```
Webhook (POST /webhook/customer-intake, JSON body incl. business_id + photo_base64)
  → Prepare Filename (validates business_id/first_name present; builds filename from photo_base64/photo_ext)
  → Has Photo? (IF)
      ├─ true  → Personalize Image with Gemini → Decode Personalized Image → Upload Photo to Storage
      └─ false → (skip straight to Build Image URL)
  → Build Image URL → Insert Customer (business_id taken directly from payload — no lookup node needed)
  → Respond Success (JSON: success, customer_id, project_image_url)
```
- **"Look Up Business ID" node removed entirely** — the website already resolves the real `business_id` via its own RLS-scoped `business_members` query before calling the webhook, so n8n no longer needs (or should trust) a business name/dropdown value from the request.
- **Photo now travels as base64 in the JSON body** (`photo_base64`, `photo_mime_type`, `photo_ext`) rather than as a multipart form file, since a webhook JSON payload can't carry n8n's binary form-file shape the way the old Form Trigger did. Browser reads the file via `FileReader.readAsDataURL` and strips the data-URL prefix before sending.
- **New fallback added in "Decode Personalized Image"**: if the Gemini response doesn't contain an image (API failure, safety block, etc.), the workflow now falls back to uploading the *original* uploaded photo instead of throwing and losing the whole customer submission — personalization is best-effort, not a hard requirement for the customer to be saved.
- **New `Respond Error`/`Respond Success` nodes** (Respond to Webhook) so the website gets a real JSON response (`{success, customer_id, project_image_url}` or `{success: false, error}`) instead of nothing, since a webhook has no default response the way a Form Trigger page did.
- Same open setup gaps as before: `geminiApi` Header Auth credential placeholder ID, Postgres credential placeholder ID, and the Supabase service-role key still referenced via `$credentials.supabaseServiceRole.serviceRoleKey` in "Upload Photo to Storage" (needs that credential created in n8n, same as it needed before this change — not new).
- **Webhook Production URL**: `https://n8n.ai4smartautomations.com/webhook/customer-intake` — wired into `CUSTOMER_INTAKE_WEBHOOK_URL` in `web/add-customer.html`.
- **Accuracy pass after initial build found and fixed two real bugs, before this had ever run**:
  1. **`Respond Error` node was unreachable** — it existed in the workflow but had no incoming connection, so any failure (missing `business_id`, Gemini/Storage/Postgres error) would have fallen through to n8n's default error response instead of the clean `{success: false, error}` JSON the website expects — and `add-customer.html`'s `response.json()` call would have thrown on n8n's non-JSON error page. Fixed by setting `"onError": "continueErrorOutput"` on `Prepare Filename`, `Upload Photo to Storage`, and `Insert Customer`, and wiring each node's error output (index 1) to `Respond Error`.
  2. **SQL injection risk in `Insert Customer`** — the insert built its VALUES clause via string interpolation (`'{{ $json.full_name }}'` etc.) directly into the SQL text, carried over unchanged from the old Form Trigger version. This was already a latent issue, but converting the intake path to a public-ish JSON webhook made it a more direct attack surface (any of `first_name`/`full_name`/`phone`/`email`/`service_type` containing a quote could break or inject into the query). Fixed by converting to n8n's parameterized query syntax (`$1..$9` placeholders + `queryReplacement` option), so values are bound by the Postgres driver instead of interpolated into the SQL string.

**`web/add-customer.html` updated**: no longer inserts into `customers` or uploads to Storage directly via `supabase-js`. Now: resolves `business_id` via `getCurrentBusinessId()` (unchanged — still the RLS-scoped auth step), base64-encodes the photo file if present, and POSTs everything as JSON to the n8n webhook. Success/error is read from the webhook's JSON response. This is a **behavior-preserving swap of the write path**, not a UI change — same form fields, same auth gate, same redirect-to-login-if-signed-out behavior.

**Two more real bugs found and fixed (2026-08-20), before this had ever been live-tested**:
3. **`Insert Customer`'s parameterized-query fix from the earlier pass was itself broken** — `queryReplacement` was a comma-joined string (`={{ $json.a }},{{ $json.b }},...}}`), which n8n's Postgres node parses by rendering the whole expression to one string first, then naively `.split(',')`-ing it (confirmed against n8n source; also documented n8n GitHub issues #14955, #16354). Demonstrated concretely with realistic input: a customer named "Jacob, Jr. Smith" or a `service_type` of "Kitchen, bathroom remodel" — both entirely normal, non-adversarial submissions via the public intake form, no malicious intent required — would fragment into 11 pieces instead of the required 9, shifting every parameter after the first comma and corrupting the insert. **Fixed** by switching to a single expression that evaluates to a real JS array (`={{ [$json.a, $json.b, ...] }}`) instead of a comma-joined string — this bypasses the comma-split entirely, since n8n checks `Array.isArray()` first. Verified by running the actual extracted expression in Node with comma-containing test data, confirming exactly 9 correctly-ordered parameters.
4. **`Respond Error` read the wrong field name, silently swallowing every validation error**: it read only `$json.message`, but per n8n's actual error-output construction (verified against source): a Code node's thrown `Error` produces `$json.error` (a string), an HTTP Request node's error output is also `$json.error` (a string), and only a Postgres node's *own* execution error populates `$json.message`. Since this "Respond Error" node receives failures from all three node types (`Prepare Filename` is a Code node, `Upload Photo to Storage` is HTTP Request, `Insert Customer` is Postgres), every validation failure from `Prepare Filename` (missing `business_id`, missing `first_name` — the two checks that exist specifically to give the website a clear, actionable error) was silently collapsing to the generic `"Unknown error"` response instead of surfacing the real message. **Fixed** with a fallback chain: `$json.message || (typeof $json.error === 'string' ? $json.error : $json.error?.message) || 'Unknown error'` — verified against all three real error shapes plus the empty case.

**Still open**: the workflow itself hasn't been live-tested end-to-end since this restructuring (only the previous Form Trigger version was live-tested) — needs re-import (or update) in n8n with credentials re-attached, then a real submission from the website with and without a photo. Worth noting: the original live-test attempt (whenever it happens) would very likely have hit bug #3 above on the first submission containing any comma in a name or service type, so this is a meaningfully different starting point than "untested" — it was untested *and* would have failed.

**Credential exposure note:** a Gemini API key (`AIzaSyAh...`) was pasted in chat during setup — same rotation caveat as the Supabase keys: low urgency while only test data exists, but rotate via https://aistudio.google.com/apikey before handling real client data.

### 3. Inbound GBP review capture, AI reply, and business notification — ✅ built and live-tested end-to-end (2026-08-20 session: real reviews flowed through matching → insert → reply → notify successfully)
File: `n8n/inbound-gbp-review-capture.json` (29 nodes as of 2026-08-20; was 25)

**Full chain (updated 2026-08-20 — adds GBP-fetch error handling and an "already replied on Google?" guard, both described in detail below):**
```
Schedule Trigger (6h) → Get Active Businesses with GBP (Postgres)
  → List Reviews for Location (GBP API v4; onError: continueErrorOutput)
      ├─ success → Flatten Reviews (word rating → number; also attaches gbp_account_id,
      │             location_id, has_existing_google_reply, existing_google_reply_comment)
      │             → Keep Review Data → Check Already Logged (Postgres)
      │             → Merge Review + Check Result → New Review? (IF: existing_status != 'Completed')
      │                 → Needs Insert or Just Retry? (IF: existing_activity_id empty?)
      │                     ├─ true (no row yet)  → Find Best Match Customer → Merge Match Result
      │                     │                        → Insert Review Activity (status='Pending')
      │                     └─ false (row exists, still Pending) → Prep Retry (Skip Insert)
      │                 → [both converge] Attach Activity ID
      │                     → Already Replied on Google? (IF: has_existing_google_reply)
      │                         ├─ true  → Log Already-Replied (Skip AI Reply) — marks Completed,
      │                         │           records the existing Google reply text, NO Gemini call,
      │                         │           NO repost — straight to Get Business Contact Email (Low-Star path node, reused)
      │                         └─ false → Good Review? (star_number >= 4)
      │                             ├─ true (4-5★)  → Generate AI Reply (Gemini) → Extract Reply Text
      │                             │                   → Post Reply to GBP → Log Reply on Activity (sets Completed)
      │                             │                   → Get Business Contact Email (Reply path) → Merge Email
      │                             └─ false (1-3★) → Flag Low-Star for Manual Reply (appends note, no auto-reply)
      │                                                 → Get Business Contact Email (Low-Star path) → Merge Email
      │                 → [all three paths converge] Notify Business of New Review (Gmail)
      └─ error → Pair Failure with Business (by position) [Merge node] → Log GBP Fetch Failure (Postgres,
                  writes businesses.last_sync_error/last_sync_error_at)
```

**Matching logic (Find Best Match Customer node):**
- Uses Postgres `similarity()` (from `pg_trgm` extension — **now enabled** on the project) to fuzzy-match the reviewer's GBP display name against `customers.full_name`, restricted to customers of that business with a "Request Sent" activity in the last 60 days.
- **Match threshold: 0.3** — below this, treated as no real match.
- **Fallback for no/weak match**: falls back to a per-business placeholder customer (`full_name = 'Unmatched Reviewer'`, `source = 'system'`) rather than leaving `customer_id` null — avoids a schema change since `activities.customer_id` is `not null`. The insert's `notes` field records whether it was a real match (with name_score) or fell back to the placeholder.
- **Placeholder customer created for Print Express**: `id = 005c8feb-6f60-4419-bbe9-bae361f04b08` (created manually, before the automation below existed).
- **Now fully automated via a Postgres trigger** (`supabase/migrations/20260817000000_unmatched_reviewer_trigger.sql`): an `after insert on businesses` trigger (`businesses_after_insert`, function `create_unmatched_reviewer_placeholder()`) automatically creates each new business's placeholder customer the instant the `businesses` row is inserted — no matter whether that insert comes from manual SQL, the Supabase dashboard, or any future onboarding tool. This was built specifically because customer data itself is added by each business independently via their own n8n intake form (outside Jonas's control), so the placeholder can't depend on anything happening on the customer-intake side — it only depends on the `businesses` row existing, which is the one step Jonas always does himself. Tested: inserted a throwaway "Trigger Test Business" row, confirmed its placeholder customer appeared automatically, then deleted the test business (cascade delete correctly removed its placeholder too, no orphaned data).
- **Placeholder now created with `do_not_call = true` from the start (2026-08-20, migration `20260820010000`)** — was previously excluded from the outbound send-request workflow only by coincidence (see workflow #1's `send-review-request.json` notes); now explicit and independent of that.
- **Why "guest reviewers" aren't a distinct case**: GBP requires reviewers to be signed into a Google account to post at all — no true anonymous path exists. The real problem is display-name mismatches (nicknames, someone else reviewing on the customer's behalf, unprompted reviewers with no matching "Request Sent" row) — handled by the threshold + placeholder fallback, not special-cased.
- **New review from a repeat customer (e.g. same person, new job, new review) is already handled correctly with no extra logic**: every GBP review has its own unique `review_id`, so a second review from the same reviewer is treated as entirely new — flows through the full insert→match→reply→notify path independently of any prior review from that person. Confirmed by walkthrough, no changes needed.

**Reply generation (Generate AI Reply / Extract Reply Text):**
- Calls Gemini (`gemini-3.6-flash` as of 2026-08-20 — `gemini-2.5-flash` was deprecated, returned "no longer available to new users"; see model-deprecation note further down; text model, not the image model used elsewhere) with the reviewer's name, star rating, and actual review comment; asks for a genuine 2-3 sentence reply referencing what they said, not a generic template.
- **Extract Reply Text has a safe fallback**: if Gemini fails or returns an unexpected response shape, falls back to a fixed thank-you template rather than blocking the workflow.
- Only runs for 4-5★ reviews. 1-3★ reviews are never auto-replied to — deliberately, since a wrong tone on a complaint can make things worse than no reply; these get flagged in `notes` for a human to handle.

**Business notification (Notify Business of New Review):**
- Runs for **every** review regardless of star rating (both branches converge here) — emails `businesses.contact_email` with the star rating, reviewer name, comment, review link, and either the AI reply that was posted (4-5★) or a note that it needs personal attention (1-3★).
- This effectively covers most of workflow #6's intent (low-star-review alerting) — the two may not need to be a fully separate workflow, revisit when picking up #6.

**Reply-status tracking & retry logic (added after initial build):**
- **Problem identified**: originally, `activities.activity_status` was hardcoded to `'Completed'` at insert time, before any reply had actually been attempted. If the Gemini call or the GBP reply POST failed partway through, the review would be permanently stuck — logged in the database but never actually replied to or retried, since "Check Already Logged" would treat it as already handled on the next run.
- **Fix**: insert now sets `activity_status = 'Pending'` instead. "Check Already Logged" now also selects `activity_status`. "New Review?" now passes through anything where `existing_status != 'Completed'` (catches both brand-new reviews and previously-failed ones). A new **"Needs Insert or Just Retry?"** IF node checks whether an activity row already exists (`existing_activity_id`): if yes, skips straight to retrying the reply via **"Prep Retry (Skip Insert)"** (no duplicate insert, no re-matching); if no, runs the full original insert path. Both paths converge at "Attach Activity ID" before continuing to the reply/notify logic. Only a **confirmed successful** GBP reply post sets `activity_status = 'Completed'` (in "Log Reply on Activity").
- **Now addressed (2026-08-20)**: "Flatten Reviews" reads Google's `reviewReply` field off the raw API response (absent entirely if no reply exists yet, per Google's v4 reviews.list schema) and attaches `has_existing_google_reply`/`existing_google_reply_comment` to every review item. A new **"Already Replied on Google?"** IF node, inserted right after "Attach Activity ID" and *before* "Good Review?"/"Generate AI Reply", routes any review that already has a Google-side reply straight to **"Log Already-Replied (Skip AI Reply)"** — which marks the activity `Completed` and records the existing reply text, without ever calling Gemini or reposting. This matters for onboarding a business with pre-existing review history (replies posted manually, or by a previous system before this automation existed) — those reviews are detected and left alone instead of getting a duplicate/conflicting reply. The "Notify Business of New Review" email message logic was also updated to describe this case correctly (previously it only branched on star rating, which would have misleadingly said "we auto-replied" or "needs attention" for an already-handled review).

**Earlier bug found and fixed during initial testing**: with 2+ reviews flowing through in one run, several nodes used `$('NodeName').item` expressions that rely on n8n's automatic item-pairing — this broke ("Multiple matching items") once more than one review was in flight, because n8n couldn't determine which upstream item corresponded to which downstream one. Fixed by restructuring the chain so each review's data flows forward via `$json` on the current item rather than reaching back to a named earlier node (added **Keep Review Data**, **Merge Review + Check Result**, **Merge Match Result** as pass-through/merge Code nodes). Confirmed fixed: re-ran with all nodes unpinned, both real reviews (Hannelien Goosen, Janice Julius — both 5-star) landed correctly in `activities`, no duplicates on repeat runs.

**Lesson for future n8n workflows (refined 2026-08-20 after a second, related bug was found and fixed)**: `.item` (singular, no index) is actually **safe** in a strict 1-input-item-in → 1-output-item-out chain — confirmed via n8n's own docs (pairedItem metadata auto-links correctly across any number of hops, as long as no node ever combines items from different lineages, e.g. a Merge/Aggregate node). The real, distinct bug this session found was **`.first()`** — it explicitly ignores item pairing and always grabs array position 0 of a node's *entire* output, regardless of which item is actually flowing through the current branch. Three places in this workflow used `$('Get Active Businesses with GBP').first()` (in "Flatten Reviews", "Post Reply to GBP", "Notify Business of New Review") to fetch business fields — harmless with exactly one business in the system (Print Express), but silently wrong the moment a second business exists, since every one of those three nodes would keep reading Print Express's `gbp_account_id`/`location_id`/`business_name` regardless of which business's review was actually being processed. **Fixed**: "Flatten Reviews" now uses `.item` (safe, single incoming item) instead of `.first()`, and also attaches `gbp_account_id`/`location_id` onto every review item; "Post Reply to GBP" and "Notify Business of New Review" were changed to read those fields straight off `$json` (already flowing forward via object-spread through every downstream Code node) instead of reaching back to any node at all. **Separately**, a bad `gbp_account_id`/`location_id` for one business used to abort the *entire* scheduled run for every other business too — fixed by adding `onError: continueErrorOutput` on "List Reviews for Location", with a **"Pair Failure with Business (by position)"** Merge node (mode: combine, combineBy: combineByPosition) re-attaching the correct `business_id` to a failure, since the HTTP node's error output is just `{error: "..."}` with the original item's fields gone entirely — and pairedItem/itemMatching lookups are documented as unreliable specifically across an HTTP Request node's error output (n8n GitHub issues #30050, #12558), so reaching back by name there would have reproduced the same class of bug. Failures are now recorded on `businesses.last_sync_error`/`last_sync_error_at` (migration `20260820000000_business_sync_error_tracking.sql`) instead of silently vanishing.

**Also found and fixed this session — SQL injection via raw string interpolation**: several Postgres nodes built queries by interpolating `{{ $json.field }}` expressions directly into the SQL text (`'{{ $json.reviewer_name }}'` etc.), with inconsistent/partial manual escaping. Since `reviewer_name` and `review_comment` come from **public, adversarial-controllable Google review text** — not just internal data — this was a real exploitable gap, not theoretical (e.g. a reviewer named `O'Brien'; DROP TABLE activities; --` would break or inject). Fixed in "Log GBP Fetch Failure", "Find Best Match Customer", and "Insert Review Activity" by converting to n8n's parameterized query syntax (`$1, $2, ...` placeholders + `options.queryReplacement`). **Important gotcha hit and fixed along the way**: n8n's Postgres node parses a comma-*joined string* `queryReplacement` by naively `.split(',')`-ing the rendered result (confirmed via n8n source + GitHub issues #14955, #16354) — so `"={{ $json.a }},{{ $json.b }}"` breaks the instant either value contains a literal comma (extremely likely for review text, e.g. "Fast, friendly, professional!"). The correct, safe form is a single expression that evaluates to a real JS **array**: `"={{ [$json.a, $json.b] }}"` — this bypasses the comma-split entirely since n8n checks `Array.isArray()` first. Verified by running the actual extracted expressions in Node with comma-containing mock data before trusting the fix. One remaining node with the same raw-interpolation pattern, not yet converted: "Log Reply on Activity" (`activity_id` only, lower risk since it's a UUID from our own database, not public review text) — flagged, not yet fixed.

**Model deprecation hit during live testing**: `gemini-2.5-flash` (used in "Generate AI Reply") returned a 404 — "no longer available to new users" — as of testing on 2026-08-20. Updated to `gemini-3.6-flash`. A note was added directly on the node pointing at `https://ai.google.dev/gemini-api/docs/models` for whoever hits this again.

**Setup still needed / confirmed done:**
- ✅ Credentials reselected and live-tested (Postgres, Google OAuth2, `geminiApi`, Gmail) — this session confirmed the full chain works end-to-end with real reviews.
- `activities` table was cleared twice during this session's testing (once at the start, once after discovering manual per-node test executions had left `Pending` rows behind) — if picking this up again, check row count before assuming a clean slate.

**Design alternative considered but not implemented**: a self-referencing `related_activity_id` column on `activities` to make the request→review link explicit rather than inferred at match-time — flagged as an option if audit trail requirements grow.

## Not yet built — full list of anticipated workflows

1. ✅ Customer intake — website (`web/add-customer.html`, RLS-enforced business_id resolution) calls an n8n webhook (`https://n8n.ai4smartautomations.com/webhook/customer-intake`, from `n8n/customer-intake-form.json`) which does Gemini name-overlay personalization + Storage upload + `customers` insert. Needs (re-)import/update in n8n with credentials attached before it's live (see workflow #2 section above).
2. ✅ Send review request — WhatsApp + email branches, per-attempt templates (see workflow #1 above). WhatsApp attempts 2-4 need real template content written and Meta-approved before they'll actually send.
3. ✅ Inbound GBP review capture + customer matching + AI reply + business notification — capture portion tested end-to-end with 2 real Print Express reviews; reply/notify extension (Gemini-generated replies for 4-5★, business email for every review, Pending/Completed retry logic) built but not yet live-tested — needs credentials wired (Postgres, Google OAuth2, geminiApi, Gmail)
4. ✅ Follow-up scheduler — built into workflow #1 (send-review-request): Schedule Trigger (daily), 5/10/20-day increasing gaps between attempts, stops on matched review or opt-out/do-not-call. Also fixed real bugs discovered in the live workflow while doing this (disconnected IF branches, missing activity-log nodes, hardcoded test values) — see workflow #1 notes above. Not yet live-tested after re-import.
5. ✅ Opt-out handling — **decided against automation**: no WhatsApp "STOP"/email-unsubscribe listener will be built. Instead, business staff set `opt_out`/`do_not_call` manually via a new **Customers** page in the website (`web/customers.html`) — a status dropdown (Active / Opted Out / Do Not Call) per customer, updating `customers` directly via `supabase-js` under RLS. See "Web app" section below for detail.
6. ✅ Low-star-review alert — covered by workflow #3's "Notify Business of New Review" step (every review, including low-star, triggers a business email; low-star ones are explicitly flagged as needing personal attention). Confirmed done by user — no separate workflow needed.
7. ✅ Business onboarding — confirmed done by user. Onboarding a business is just the manual `businesses` row insert (Jonas); the placeholder customer, and everything downstream (customer intake via the website, review capture/matching/reply/notification), all work automatically off that one insert with no further manual steps required.
8. ✅ Auth + RLS-gated web app (login, intake form, dashboard) — see dedicated "Web app" section above. Was tracked as a deferred addendum, now fully built and confirmed working.

## Web app — ✅ BUILT: Auth + RLS-gated multi-page site (login, intake form, dashboard)

Plan originally written to: `C:\Users\Jonas Mohlala\.claude\plans\what-approach-will-you-compiled-lollipop.md` (that plan is now implemented, not just planned).

**Why this was needed**: the n8n form was a stopgap — it used the service role key (bypasses RLS) and trusted a dropdown selection with zero verification; nothing stopped a submitter picking a different business than their own. The fix is real auth: derive `business_id` from who's logged in, enforced at the database layer via RLS, not from a form field the submitter controls.

**Key architectural fact, confirmed and now proven true in practice**: the schema needed no changes at all — `business_members` and RLS were already fully live in the database from earlier work. Only the frontend/access-path changed. The n8n workflows (service role key) remain completely unaffected, since RLS and service-role access are two independent paths — confirmed working side-by-side.

### Files (all in `web/`)

- **`shared.js`** — one Supabase client (`sb`, using the anon/publishable key `sb_publishable_0_B9D...` — safe to embed client-side since every query is still RLS-scoped) plus shared auth helpers: `getSession()`, `getCurrentBusinessId(userId)` (queries `business_members`, RLS-scoped — a staff member sees only their own business), `sendMagicLink(email, redirectTo)`, `signOut()`.
- **`styles.css`** — one shared stylesheet (centered-card layout for login/forms, topbar+nav shell for logged-in pages, stat tiles, activity table with status badges and star ratings).
- **`index.html`** — login page. Email → magic link via `sb.auth.signInWithOtp`. Auto-redirects to `dashboard.html` if already signed in.
- **`add-customer.html`** — the intake form, now living behind auth instead of a public dropdown-based form. Same core logic as the earlier proof-of-concept (`customer-intake.html`, now superseded): looks up `business_id` via RLS-scoped `business_members` query, uploads photo directly to the `customer-project-images` Storage bucket from the browser, inserts into `customers`. Redirects to `index.html` if not signed in.
- **`dashboard.html`** — built to satisfy the user's request for businesses to see their own activity. Stat tiles (requests sent, reviews received, conversion rate, average star rating — all computed client-side from a single `activities` query) plus a recent-activity table (date, type, channel, status badge, star rating, truncated comment). Query is `.eq("business_id", businessId).order("timestamp", desc).limit(100)` — RLS would enforce the boundary even without the explicit filter, but the filter is kept for query clarity.
- **`customers.html`** — **new**, added this session for manual opt-out/do-not-call management (see decision below). Lists all of the business's customers (name, phone, email, service type, date added) with a status dropdown per row (Active / Opted Out / Do Not Call). `statusFromCustomer()` maps the two underlying booleans to one display value (`do_not_call` takes priority if both are somehow true); changing the dropdown does a direct `sb.from("customers").update({opt_out, do_not_call}).eq("id", customerId)` under RLS, with the select disabled during the write and reverted to its previous class/value on error (via `alert()` — kept simple, matches this app's existing error-handling style elsewhere).
- **`settings.html`** — **new**, added this session to give businesses self-service control over their own `businesses` row. Shows business name (read-only — renaming a business isn't exposed here, no use case identified for it yet), editable contact person/email/phone, and an **Active/Paused status dropdown** — the same `businesses.status` column that already gates the send-review-request eligibility query (`b.status = 'Active'`). Previously this could only be changed by hand via SQL. One `sb.from("businesses").update(...).eq("id", businessId)` on submit, same auth-gate pattern as the other pages. Prompted by the user noticing this column had no UI, right after building the customer-status dropdown — same underlying idea (give staff a lever instead of requiring a SQL run) applied to the business level.
- All four pages (`dashboard.html`, `add-customer.html`, `customers.html`, `settings.html`) now share the same 4-item nav: Dashboard / Add Customer / Customers / Settings.
- **`customer-intake.html`** — the original single-file proof-of-concept from earlier in the session; superseded by the `index.html`/`add-customer.html`/`dashboard.html` split, kept as-is (not deleted).

### How auth works end-to-end

1. Staff visits `index.html`, enters their email, gets a magic link (Supabase Auth, no passwords).
2. Clicking the link signs them in and redirects to `dashboard.html`.
3. Every page calls `getCurrentBusinessId(session.user.id)` — queries `business_members` **as that user**, so RLS only ever returns rows they're actually linked to. No dropdown, no typed business ID anywhere in the UI.
4. All reads/writes (`customers` insert, `activities` select, Storage upload) happen directly from the browser via `supabase-js`, under that authenticated session — RLS enforces the business boundary at the database layer itself, not just in the app's logic. Confirmed with the user: this means a staff member genuinely cannot see or write another business's data, even via tampered requests — verified by walking through why the policy holds (`business_id in (select business_id from business_members where user_id = auth.uid())` runs inside Postgres on every query).

### Unassigned users, linking to a business, and multi-user businesses (clarified this session)

- **What happens when an unrecognized email logs in**: Supabase Auth doesn't check `business_members` at sign-in — `signInWithOtp` will happily create a brand-new `auth.users` row and send a magic link to any email, recognized or not (see self-registration note below; `shouldCreateUser` is intentionally left at its default `true`). If they click the link, they get a fully valid session and land on `dashboard.html` — but `getCurrentBusinessId()` finds zero matching `business_members` rows and throws "Your account is not linked to a business yet," so the page renders nothing. Same fail-closed behavior on every other page, since they all call the same helper first. The only real-world side effect is that the login still consumes one slot against Supabase's shared 2/hour test-mailer cap.
- **How to link that unassigned user to a business (manual today, no UI yet)**:
  1. Find their `auth.users.id` — Dashboard → Authentication → Users (search by email) or `select id, email from auth.users where email = '...';`
  2. Find or create the target `businesses` row (creating one auto-fires the `businesses_after_insert` placeholder-customer trigger, no extra step needed).
  3. `insert into business_members (business_id, user_id, role) values ('<business-id>', '<user-id>', 'owner');` — `role` is `'owner'` or `'staff'`.
  4. No further step — the next page load for that user resolves normally, no re-login needed. `business_members` has no RLS policy of its own, so this insert must be done via service role / SQL editor / dashboard, not from the web app.
- **Multiple users can be linked to one business** — the schema was built for this. The unique constraint on `business_members` is `(business_id, user_id)`, which only blocks linking the *same* user twice to the *same* business; it doesn't limit how many distinct users point at one `business_id`. Two staff (e.g. an owner + front-desk person), each with their own login, both resolve to the same `business_id` and see identical data (same activity feed, same customer list, same settings) — RLS scopes by `business_id`, not by `user_id`. **Known gap**: the `role` column exists but nothing currently reads it to gate actions — `owner` vs `staff` behave identically today (e.g. both can edit Settings). Would need explicit role-checking logic added to restrict owner-only actions if that's ever wanted.
- **Natural next feature (not built)**: a self-service "invite staff" control on `settings.html` (owner enters an email, app inserts a `business_members` row scoped to their own `business_id` under RLS) would remove the need for the manual SQL step above. Flagged as a good candidate to build later; not started.

### Local dev / testing setup

- Served via `python -m http.server 8000` from inside `web/` — needed because Supabase's Auth redirect URL validator **rejects `file://` URLs outright** ("Please provide a valid URL"), so testing directly by double-clicking the HTML file doesn't work for the login flow. Confirmed this the hard way after first trying to whitelist a `file://` path.
- Supabase Auth → URL Configuration → Redirect URLs must include whichever page the magic link redirects to. Currently whitelisted: `http://localhost:8000/dashboard.html` (was `customer-intake.html` during the single-file prototype, updated for the multi-page split).
- **"email rate limit exceeded" hit during testing, THREE times across sessions (two on the exact same underlying limit)** — not a bug. Supabase's built-in test mailer caps auth emails at **`rate_limit_email_sent: 2` per hour, project-wide** (not per-recipient), plus a 60-second minimum gap between sends (`smtp_max_frequency: 60`). First hit: user chose to wait it out. **Second hit (2026-08-20)**: switched to **Resend** as custom SMTP, per the earlier-flagged decision (see `[[alwaysreviews_resend_smtp_todo]]` memory file). Configured via the Supabase Management API (`PATCH /v1/projects/xbmoomufmxicwymwbovg/config/auth`) rather than the dashboard: `smtp_host: smtp.resend.com`, `smtp_port: 465`, `smtp_user: resend`, `smtp_pass: <Resend API key>`, `smtp_sender_name: "Always Reviews"`, `smtp_admin_email: onboarding@resend.dev`.
- **Third hit, same day, after Resend was already configured and confirmed delivering** — assumption that "configuring custom SMTP automatically lifts Supabase's built-in cap" turned out to be **wrong**, confirmed via Supabase docs (`supabase.com/docs/guides/platform/going-into-prod#rate-limits`) and a live GitHub discussion: `rate_limit_email_sent` is a separate config value that Supabase does NOT auto-raise just because `smtp_host` is non-null — it stays at the default `2` until manually changed. Confirmed the real cause first by checking Resend's own send log via its API (`GET /emails`), which showed the *previous* magic-link email had genuinely sent and been marked `"delivered"` — ruling out Resend itself as broken before looking elsewhere. **Fixed**: raised `rate_limit_email_sent` to `30`/hour via the same Management API PATCH endpoint.
- **Important caveat, still open**: no domain was verified on Resend at setup time (`GET /domains` returned empty) — `alwaysreviews.com` needs to be added and DNS-verified on Resend before switching the from-address away from the shared `onboarding@resend.dev` test address. Until then, Resend's test mode only delivers to the Resend account's own verified email (confirmed working: `jonas.mohlala@gmail.com`) — **not to real business customers/staff**. Confirmed directly: a login attempt with `printexpressnamakwa@gmail.com` failed with "Error sending confirmation email," and Resend's own send log showed **no attempt was even recorded** for that address — rejected at the SMTP layer before Resend logged it, consistent with the test-mode restriction rather than a bug. This is a hard blocker before onboarding any real business beyond solo testing. **Resend pricing confirmed NOT a blocker**: domain verification and sending to any recipient are both free-tier features (up to 3 domains, 3,000 emails/month capped at 100/day) — no paid plan needed until well past early-stage usage (the 100/day cap, not the 3,000/month figure, is the real future constraint — likely relevant around 10-15+ active businesses). Confirmed working end-to-end: login → magic link email arrives via Resend → click → lands on live dashboard.
- **Login self-registration behavior — investigated, then confirmed as intended (this session)**: the user noticed that typing an unrecognized email (`printexpressnamakwa@gmail.com`, a test customer's address, not real staff) into the login page was accepted rather than rejected. First tried adding `shouldCreateUser: false` to `signInWithOtp` to block unrecognized emails from creating accounts — but this was a misread of the actual requirement. **User clarified the intended model**: sign-in should stay open to anyone (self-service, no admin step to create an account) — the real access boundary is, and always was, `business_members` + RLS. An unrecognized/unlinked email can create an auth account and log in, but `getCurrentBusinessId()` in `shared.js` immediately throws "Your account is not linked to a business yet" and no business data is ever reachable. **`shouldCreateUser: false` was reverted** — `sendMagicLink()` is back to plain `signInWithOtp` with just `emailRedirectTo`, matching original behavior. No actual security gap existed; open self-service sign-in + RLS-gated data access is the correct, already-working design. Worth remembering if this comes up again: don't conflate "who can get a session" with "who can see data" — only the latter needs to be restricted here, and it already was.
- **A bug was hit and fixed during the single-file prototype phase**: naming the Supabase client variable `supabase` (`const supabase = window.supabase.createClient(...)`) collides with the global `supabase` object the CDN script itself creates, causing `Uncaught SyntaxError: Identifier 'supabase' has already been declared`. Fixed by renaming the client variable to `sb` everywhere — carried forward as the naming convention in `shared.js` and all pages from the start of the multi-page build, so this bug shouldn't recur.
- **Deployed for real (2026-08-20)** — see new "Deployment & rebrand" section below. The migration from local-only was indeed easy, exactly as anticipated: no code changes needed beyond updating Supabase's `site_url`/redirect allowlist to the new domain.

### Verified working end-to-end
User confirmed: signed in via magic link, landed on the dashboard, saw real Print Express activity data render correctly (stat tiles + activity table), nav between Dashboard/Add Customer works, sign-out works.

**Supabase Data API**: the mechanism this page uses — an auto-generated REST/GraphQL API (via PostgREST) sitting on top of the tables, callable from a browser with `supabase-js`, respecting RLS. Different from: n8n's direct Postgres connection (bypasses RLS, used by all n8n workflows) and the Storage API (files only, also used here for photo uploads).

## Deployment & rebrand (2026-08-20 session)

**Rename**: the app/business was named **"Always Reviews"** this session (previously "Review Harvest" throughout). Domain `alwaysreviews.com` confirmed available (not yet purchased as of this session). Renamed everywhere: brand text in all 5 web pages (`index.html`'s `<h1>`, the `.brand` div on `dashboard.html`/`add-customer.html`/`customers.html`/`settings.html`), and this file itself — `review-harvest-project-context.md` → `alwaysreviews-project-context.md`, including its `# ... — Project Context & Conversation Log` title. Note the two-word spacing is deliberate ("Always Reviews", not "AlwaysReviews") — corrected after an initial no-space pass.

**GitHub repo created**: https://github.com/jonasmohlala-githup/alwaysreviews (pushed to `main`). Repo scope decision: everything except `.env` and machine-local state. Added `.gitignore` excluding:
- `.env`/`.env.*` (live secrets)
- `.claude/` (Claude Code's own config/skills — spans unrelated projects/clients, not part of this app)
- `AGENTS.md`/`CLAUDE.md` (generic Claude/Codex skill-system docs, not app content)
- `supabase/.temp/` (Supabase CLI's local session cache — project ref, pooler URL, version pins)
- `.vercel` (Vercel CLI's local project-link metadata, added automatically by the CLI itself)

**Vercel deployment**: live at **https://alwaysreviews.vercel.app** (project name `alwaysreviews` under Vercel team `jonas-projects21`). Deployed via `vercel deploy --cwd web --yes --prod` from the repo root — `web/` is the actual site root, not the repo root, so `--cwd web` (or a `web/.vercel/project.json` pointing at the same project ID) is required each deploy; there's no `vercel.json` field that relocates the project root (`outputDirectory` does NOT do this — confirmed via Vercel docs — Root Directory is a project-setting concept, either set via the dashboard or effectively achieved here via `--cwd`). `vercel.json` at the repo root is minimal: `{"cleanUrls": true}`. **Mistake made and corrected**: the first deploy attempt (`vercel deploy --cwd web` with no existing link) created a *second*, separate Vercel project called "web" instead of reusing the already-linked "alwaysreviews" project — caught immediately, the stray "web" project was deleted (`vercel remove web --yes`) and a matching `web/.vercel/project.json` was hand-created pointing at "alwaysreviews"'s real project ID before redeploying correctly. **GitHub auto-deploy is NOT connected** — `vercel link`'s attempt to connect the GitHub repo failed ("Failed to connect... Make sure there aren't any typos and that you have access to the repository") — likely needs the Vercel-for-GitHub App authorized via the dashboard first, a one-time interactive step not done yet. Until that's set up, deploys only happen via manual `vercel deploy`, not automatically on `git push`.

**Supabase Auth reconfigured for the live domain**: `site_url` was still Supabase's out-of-box default (`http://localhost:3000` — never actually changed, despite the earlier local-dev section referencing `localhost:8000`) and `uri_allow_list` only had a stale single-file-prototype URL. This caused the first live login attempt to fail with `otp_expired`/redirect-to-localhost. Fixed via the Management API: `site_url` → `https://alwaysreviews.vercel.app`, `uri_allow_list` → `https://alwaysreviews.vercel.app/dashboard.html,https://alwaysreviews.vercel.app/**` (wildcard covers all pages). **Reminder for later**: if/when a custom domain is connected to Vercel, both of these need updating again to match — Supabase does not follow domain changes automatically.

**Diagnostic logging added**: `dashboard.html`'s `requireAuthAndLoad()` now logs the actual `sessionError` and `window.location.hash` to the console before redirecting to `index.html` on a missing session, instead of silently bouncing with no trace — added while debugging the login redirect loop (which turned out to be caused by the stale `site_url`/rate-limit issues above, not a code bug in the session-handling logic itself; researched and confirmed `supabase-js`'s `getSession()` safely awaits URL-hash token parsing internally, so no race condition exists in the vanilla-JS-on-CDN setup here).

**Git identity**: set locally (repo-scoped, not global) via `git config user.email`/`user.name` using `jonas.mohlala@gmail.com` — no prior git identity existed on this machine for this repo.

**Next domain step (not yet done, user's plan)**: once a custom domain is purchased, connect it in Vercel, verify it on Resend (for a real from-address instead of `onboarding@resend.dev`), and update Supabase's `site_url`/`uri_allow_list` again to match.

## Credential handling notes (important, recurring pattern)

- Supabase **personal access tokens** (`sbp_...`) were repeatedly generated, used once for a CLI operation, and revoked immediately after each use — this pattern should continue for any future CLI/Management API work.
- The Supabase **secret/service-role key** (`sb_secret_...` / legacy JWT) was exposed in this chat's tool output twice (once creating the Storage bucket, once fetching it for the n8n Storage-upload node). Unlike access tokens, this key doesn't expire and isn't meant to be rotated after every use — but because it's now been printed in a persistent chat transcript, **the recommended action before handling real client data is to rotate it** via Supabase dashboard → Settings → API Keys → "+ New secret key", then update the two n8n header fields (and anywhere else using it) with the new value. Not urgent while only test data (Print Express) exists in the system.
- Risk assessment discussed: exposure risk isn't really about the local PC's security (single user, presumed secure) — it's about the chat transcript itself being a persistent, server-stored copy outside the user's direct control. Low severity/likelihood while this is single-business test data; becomes a real risk the moment real client data is in the system.
- **Process improvement adopted**: as of the `pg_trgm`/placeholder-customer setup, the user switched to storing the Supabase personal access token in the project's `.env` file (`c:\Users\Jonas Mohlala\GBP\.env`, key `SUPABASE_ACCESS_TOKEN`) rather than pasting it directly in chat each time — Claude reads it from there instead. Better practice going forward for any credential, not just Supabase. This `.env` also now holds `RESEND_API_KEY` (added 2026-08-20) alongside unrelated live secrets (Anthropic, LinkedIn, Gemini, Google API keys) from other projects. **`.gitignore` addressed 2026-08-20** — see "Deployment & rebrand" section — `.env` is correctly excluded from the repo now that it's on GitHub.
- **Still outstanding, unchanged from earlier sessions**: rotate the Supabase secret/service-role key, Gemini API key, Pabbly Chatflow API key, and Postgres database password — all were at some point visible in a chat transcript or n8n export. Was "low urgency while only test data exists"; **now higher priority**, since the app has a real name (Always Reviews), a real domain plan, and a live public deployment as of 2026-08-20.

## Useful links

- Table editor: https://supabase.com/dashboard/project/xbmoomufmxicwymwbovg/editor
- SQL editor: https://supabase.com/dashboard/project/xbmoomufmxicwymwbovg/sql/new
- API keys: https://supabase.com/dashboard/project/xbmoomufmxicwymwbovg/settings/api-keys
- Database connection settings: https://supabase.com/dashboard/project/xbmoomufmxicwymwbovg/settings/database
- Personal access tokens (for CLI/Management API use): https://supabase.com/dashboard/account/tokens

## n8n Postgres connection (for reference)

Had to use the **Session pooler** (not direct connection) due to an IPv6 `ENETUNREACH` error on the direct host — the direct connection host resolves IPv6-only and the local network couldn't route to it.

- Host: `aws-1-eu-west-1.pooler.supabase.com`
- Port: `5432` (session pooler)
- Database: `postgres`
- User: `postgres.xbmoomufmxicwymwbovg` (note the dotted project-ref suffix — required for pooler auth, plain `postgres` fails against the pooler host)
- Password: the project's database password (was pasted in chat once during troubleshooting — same rotation caveat as above applies if this becomes a production concern)

## Next steps (pick up here)

Updated 2026-08-20 (second pass, same day). Done since the last update: audited and fixed real bugs in all three n8n workflows (not just workflow #3) — see each workflow's section for specifics; also fixed the `rate_limit_email_sent` gotcha (custom SMTP does NOT auto-lift Supabase's cap) and added `do_not_call = true` to the "Unmatched Reviewer" placeholder. Remaining open items, roughly in priority order:

1. **Verify `alwaysreviews.com` on Resend** (once purchased) and switch the SMTP from-address from `onboarding@resend.dev` to a real address on that domain (e.g. `noreply@alwaysreviews.com`) — hard blocker before onboarding any real business, since test mode only delivers to the Resend account's own verified email today. Confirmed NOT a paid-plan issue — domain verification is free-tier.
2. **Connect a custom domain** once purchased: add it in Vercel, point DNS, then update Supabase's `site_url`/`uri_allow_list` to match (currently `https://alwaysreviews.vercel.app`).
3. **Re-import ALL THREE n8n workflows** — every workflow had real bugs fixed this session and none have been re-imported/re-tested since:
   - `inbound-gbp-review-capture.json`: `.first()`/error-handling/SQL-injection fixes (all live-tested successfully before the fixes were made — re-test recommended, especially the new "Already Replied on Google?" branch, which wasn't exercised live).
   - `send-review-request.json`: **the WhatsApp/email IF-branch swap is a real functional bug fix that needs to go live** — currently `active: false`, so it's not silently misrouting customers right now, but don't activate it before re-importing this fix.
   - `customer-intake-form.json`: **has never been live-tested at all** in its webhook form, and the original test would very likely have hit the comma-splitting SQL bug on the first submission with any name/service-type containing a comma — now fixed, worth testing for real this time (with and without a photo, and a name/service-type containing a comma specifically, to confirm the fix).
4. **Connect GitHub auto-deploy in Vercel** — currently deploys are manual (`vercel deploy --cwd web --yes --prod`); `vercel link`'s attempt to auto-connect the GitHub repo failed and likely needs the Vercel-for-GitHub App authorized via the dashboard first.
5. **Rotate exposed credentials before onboarding real client data** — Supabase secret/service-role key, Gemini API key, Pabbly Chatflow API key, and the Postgres database password were all at some point visible in a chat transcript or n8n export. This is now higher priority than before (real name, real domain plan, live public deployment).
6. **Fix the remaining raw-SQL-interpolation node**: "Log Reply on Activity" in `inbound-gbp-review-capture.json` still builds its query via string interpolation (lower risk than the ones already fixed, since it only touches `activity_id`, a UUID from our own database — not public review text — but same pattern class).
7. **Write and submit real WhatsApp template content for attempts 2-4** (`review_request_v2/3/4`) for Meta approval — currently just placeholder names in the database with no real message content. Only attempt 1 (`review_request_v1`) actually sends via WhatsApp today; attempts 2-4 will silently fail or send nothing meaningful until this is done. Email attempts 2-4 already work.
8. **Live-test `web/customers.html` and `web/settings.html`** — sign in, confirm the customer list loads and the status dropdown correctly updates `opt_out`/`do_not_call`, and confirm Settings loads/saves `businesses` contact fields + status correctly. Still not confirmed as of this session.
9. Formalize the ad-hoc `ALTER TABLE` changes (`review_request_link`, `project_image_url`) into tracked migration files if full reproducibility from `supabase/migrations/` matters later.
10. **Visual design pass on the web app** (colors, layout, etc.) — user has explicitly deferred this; functionality is prioritized first.
11. Optional: build a self-service "invite staff" flow on `settings.html` so linking additional users to a business doesn't require a manual SQL insert into `business_members` (see "Unassigned users, linking to a business" section above).
12. **`gemini-2.5-flash-image` (used in `customer-intake-form.json`'s "Personalize Image with Gemini") is currently active/not deprecated** per Google's own docs, checked 2026-08-20 — but one unverified third-party source claimed an October 2026 shutdown date. Not acted on since unconfirmed against official docs, but worth a quick re-check of `ai.google.dev/gemini-api/docs/models/gemini-2.5-flash-image` before relying on it long-term.
