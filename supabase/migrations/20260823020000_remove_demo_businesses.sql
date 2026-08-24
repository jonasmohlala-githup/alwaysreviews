-- Removes the two demo businesses seeded in 20260823010000_demo_businesses.sql
-- (Kimberley Auto Care, Bright Smile Dental) now that the business-switcher
-- has been verified working end-to-end. Deleting businesses cascades to their
-- customers, activities, business_members rows, and auto-created "Unmatched
-- Reviewer" placeholder customer — nothing orphaned. Print Express and the
-- admin's membership on it are untouched.

delete from businesses
where id in (
  'a1b2c3d4-0001-4000-8000-000000000001', -- Kimberley Auto Care
  'a1b2c3d4-0002-4000-8000-000000000002'  -- Bright Smile Dental
);
