-- Review automation schema: businesses -> customers -> activities
-- No auth/RLS yet (service-role/n8n access only). See plan notes for future
-- business_members + RLS addition when client logins are needed.

create table businesses (
  id uuid primary key default gen_random_uuid(),
  business_name text not null,
  gbp_account_id text,
  location_id text,
  whatsapp_sender_number text,
  template_name text,
  contact_person text,
  contact_email text,
  contact_phone text,
  status text not null default 'Active' check (status in ('Active', 'Paused')),
  onboarded_date date default now(),
  notes text,
  created_at timestamptz not null default now()
);

create table customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  first_name text,
  full_name text,
  phone text not null,
  email text,
  service_type text,
  job_completion_date date,
  consent_optin boolean not null default false,
  opt_out boolean not null default false,
  do_not_call boolean not null default false,
  date_added timestamptz not null default now(),
  source text,
  notes text
);

create index idx_customers_business_id on customers(business_id);

create table activities (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  activity_type text not null check (
    activity_type in ('Request Sent', 'Follow-up', 'Reply Sent', 'Failed', 'Opt-Out')
  ),
  review_received boolean not null default false,
  activity_status text check (
    activity_status in ('Pending', 'Sent', 'Delivered', 'Read', 'Failed', 'Completed')
  ),
  channel text check (channel in ('WhatsApp', 'SMS', 'Email')),
  template_name text,
  personalized_image_url text,
  "timestamp" timestamptz not null default now(),
  message_id text,
  review_id text,
  star_rating text,
  star_number smallint check (star_number between 1 and 5),
  review_comment text,
  review_link text,
  reply_text text,
  attempts smallint,
  notes text
);

create index idx_activities_business_id on activities(business_id);
create index idx_activities_customer_id on activities(customer_id);
create index idx_activities_activity_type on activities(activity_type);
