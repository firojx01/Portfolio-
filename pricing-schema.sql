-- ============================================================
-- FX STUDIO — PRICING SCHEMA (standalone, safe to re-run)
-- Only touches pricing tables. Does NOT touch site_settings,
-- portfolio_items, services, or reviews — those are untouched.
--
-- Why the previous script failed: your database already had a
-- pricing_plans table from the OLD flat pricing system (tier,
-- price_old, price_new, delivery, badge, is_popular — no
-- group_id column). "create table if not exists" saw that table
-- already existed and skipped creating the new one, so the next
-- statement tried to index a group_id column that was never
-- there. This version drops any old pricing_plans / pricing_groups
-- / pricing_categories tables first — regardless of their shape —
-- then rebuilds them clean, every time you run it.
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- clean slate for pricing only ----------
drop table if exists pricing_plans cascade;
drop table if exists pricing_groups cascade;
drop table if exists pricing_categories cascade;

-- ============================================================
-- PRICING — CATEGORY -> GROUP -> PLAN
-- ============================================================
create table pricing_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  services text[] default '{}',   -- chip list, e.g. {"UGC Ads","Product Video Ads"}
  order_index int default 0,
  is_active boolean default true
);

create table pricing_groups (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references pricing_categories(id) on delete cascade,
  name text not null,             -- "Packages", "Monthly Plans", "Monthly Management", "Maintenance"
  is_monthly boolean default false,
  is_enabled boolean default true,  -- lets admin hide a whole group (e.g. disable Monthly Plans)
  order_index int default 0
);
create index idx_pricing_groups_category on pricing_groups(category_id);

create table pricing_plans (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references pricing_groups(id) on delete cascade,
  tier text not null,             -- "Starter", "20 Ads / Month", etc.
  price_old numeric,
  price_new numeric,
  offer_enabled boolean default true,
  currency text default '₹',
  period text default '',         -- e.g. "/mo" appended after price on monthly groups
  features text[] default '{}',
  delivery text default '',
  revisions text default '',
  is_best_seller boolean default false,
  is_recommended boolean default false,
  show_custom_quote boolean default false,
  custom_quote_note text default 'Need something different? Get a custom quote.',
  order_index int default 0
);
create index idx_pricing_plans_group on pricing_plans(group_id);

-- ============================================================
-- RLS — public can read, only logged-in admin can write
-- ============================================================
alter table pricing_categories enable row level security;
alter table pricing_groups     enable row level security;
alter table pricing_plans      enable row level security;

drop policy if exists "public read pricing_categories" on pricing_categories;
create policy "public read pricing_categories" on pricing_categories for select using (true);
drop policy if exists "admin write pricing_categories" on pricing_categories;
create policy "admin write pricing_categories" on pricing_categories for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "public read pricing_groups" on pricing_groups;
create policy "public read pricing_groups" on pricing_groups for select using (true);
drop policy if exists "admin write pricing_groups" on pricing_groups;
create policy "admin write pricing_groups" on pricing_groups for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "public read pricing_plans" on pricing_plans;
create policy "public read pricing_plans" on pricing_plans for select using (true);
drop policy if exists "admin write pricing_plans" on pricing_plans;
create policy "admin write pricing_plans" on pricing_plans for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ============================================================
-- SEED DATA — matches the taxonomy from the brief.
-- Categories, groups, and starter plans for all four categories
-- so the live site and admin panel both have real rows to show
-- immediately (edit/replace any of it from Admin → Pricing).
-- ============================================================

insert into pricing_categories (name, slug, services, order_index) values
  ('Creative Ads', 'creative-ads', array['UGC Ads','Product Video Ads'], 1),
  ('Meta Advertising', 'meta-advertising', array['Facebook Ads Management','Instagram Ads Management'], 2),
  ('Creative Design', 'creative-design', array['Logo Design','Banner Design','Poster Design'], 3),
  ('Website Development', 'website-development', array['Landing Page','Business Website','Restaurant Website','Gym Website','Clothing Website','Portfolio Website','E-commerce Website'], 4);

-- ---------- groups ----------
insert into pricing_groups (category_id, name, is_monthly, order_index)
select id, 'Packages', false, 1 from pricing_categories where slug = 'creative-ads';
insert into pricing_groups (category_id, name, is_monthly, order_index)
select id, 'Monthly Plans', true, 2 from pricing_categories where slug = 'creative-ads';

insert into pricing_groups (category_id, name, is_monthly, order_index)
select id, 'Packages', false, 1 from pricing_categories where slug = 'meta-advertising';
insert into pricing_groups (category_id, name, is_monthly, order_index)
select id, 'Monthly Management', true, 2 from pricing_categories where slug = 'meta-advertising';

insert into pricing_groups (category_id, name, is_monthly, order_index)
select id, 'Packages', false, 1 from pricing_categories where slug = 'creative-design';

insert into pricing_groups (category_id, name, is_monthly, order_index)
select id, 'Packages', false, 1 from pricing_categories where slug = 'website-development';
insert into pricing_groups (category_id, name, is_monthly, order_index)
select id, 'Website Maintenance', true, 2 from pricing_categories where slug = 'website-development';

-- ---------- Creative Ads / Packages ----------
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, is_recommended, order_index)
select g.id, 'Starter', 6999, 4999, array['10 UGC/Product video ads','Basic script + hook','Raw footage editing'], '5-7 days', '2 rounds', false, 1
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-ads' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, is_best_seller, order_index)
select g.id, 'Professional', 12999, 8999, array['20 UGC/Product video ads','Scripting + hook testing','Captions + on-brand editing','1 revision call'], '7-10 days', '3 rounds', true, 2
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-ads' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, show_custom_quote, order_index)
select g.id, 'Premium', 21999, 15999, array['35+ UGC/Product video ads','Full creative strategy','Priority editing queue','Unlimited minor revisions'], '10-14 days', 'Unlimited minor', true, 3
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-ads' and g.name = 'Packages';

-- ---------- Creative Ads / Monthly Plans ----------
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, order_index)
select g.id, '20 Ads / Month', 14999, 11999, '/mo', array['20 ads delivered monthly','Consistent posting cadence','Monthly performance notes'], 'Rolling', '2 rounds/ad', 1
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-ads' and g.name = 'Monthly Plans';
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, is_best_seller, order_index)
select g.id, '30 Ads / Month', 21999, 17999, '/mo', array['30 ads delivered monthly','Priority queue','Monthly performance notes'], 'Rolling', '2 rounds/ad', true, 2
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-ads' and g.name = 'Monthly Plans';
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, show_custom_quote, order_index)
select g.id, '50 Ads / Month', 34999, 27999, '/mo', array['50 ads delivered monthly','Dedicated editor','Weekly check-ins'], 'Rolling', 'Unlimited minor', true, 3
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-ads' and g.name = 'Monthly Plans';

-- ---------- Meta Advertising / Packages ----------
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, is_recommended, order_index)
select g.id, 'Starter', 5999, 3999, array['Ad account setup','1 campaign, 2 ad sets','Basic pixel/event setup'], '3-5 days', '1 round', false, 1
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'meta-advertising' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, is_best_seller, order_index)
select g.id, 'Professional', 9999, 6999, array['Full account structure','3 campaigns, A/B creative testing','Conversion tracking setup'], '5-7 days', '2 rounds', true, 2
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'meta-advertising' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, show_custom_quote, order_index)
select g.id, 'Premium', 17999, 12999, array['Full-funnel campaign build','Advanced audience + retargeting setup','CAPI/server-side tracking'], '7-10 days', 'Unlimited minor', true, 3
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'meta-advertising' and g.name = 'Packages';

-- ---------- Meta Advertising / Monthly Management ----------
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, order_index)
select g.id, 'Basic', 12999, 9999, '/mo', array['Up to ₹50k ad spend managed','Weekly optimization','Monthly report'], 'Rolling', '—', 1
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'meta-advertising' and g.name = 'Monthly Management';
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, is_best_seller, order_index)
select g.id, 'Growth', 21999, 16999, '/mo', array['Up to ₹1.5L ad spend managed','2x weekly optimization','Creative refresh included'], 'Rolling', '—', true, 2
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'meta-advertising' and g.name = 'Monthly Management';
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, show_custom_quote, order_index)
select g.id, 'Scale', 34999, 27999, '/mo', array['₹1.5L+ ad spend managed','Daily monitoring','Dedicated account manager'], 'Rolling', '—', true, 3
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'meta-advertising' and g.name = 'Monthly Management';

-- ---------- Creative Design / Packages ----------
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, order_index)
select g.id, 'Starter', 2999, 1999, array['1 logo concept','2 banner designs','Source files'], '3-4 days', '2 rounds', 1
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-design' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, is_best_seller, order_index)
select g.id, 'Professional', 5999, 3999, array['3 logo concepts','5 banners + 2 posters','Brand color/style guide'], '5-7 days', '3 rounds', true, 2
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-design' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, show_custom_quote, order_index)
select g.id, 'Premium', 9999, 6999, array['Full brand identity','Unlimited banners/posters (scope-based)','Priority turnaround'], '7-10 days', 'Unlimited minor', true, 3
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'creative-design' and g.name = 'Packages';

-- ---------- Website Development / Packages ----------
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, order_index)
select g.id, 'Starter', 9999, 7999, array['1-page landing site','Mobile responsive','Contact form'], '5-7 days', '2 rounds', 1
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'website-development' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, is_best_seller, order_index)
select g.id, 'Business', 19999, 14999, array['Up to 6 pages','SEO-ready structure','CMS/admin panel'], '10-14 days', '3 rounds', true, 2
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'website-development' and g.name = 'Packages';
insert into pricing_plans (group_id, tier, price_old, price_new, features, delivery, revisions, show_custom_quote, order_index)
select g.id, 'Enterprise', 0, 0, array['Fully custom design + animation','E-commerce / booking systems','Custom backend + integrations'], 'Scoped', 'Scoped', true, 3
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'website-development' and g.name = 'Packages';

-- ---------- Website Development / Website Maintenance ----------
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, order_index)
select g.id, 'Basic', 1999, 1499, '/mo', array['Uptime monitoring','Monthly backups','Minor content edits'], 'Rolling', '1/mo', 1
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'website-development' and g.name = 'Website Maintenance';
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, is_best_seller, order_index)
select g.id, 'Standard', 3999, 2999, '/mo', array['Everything in Basic','Weekly backups','Priority bug fixes'], 'Rolling', '3/mo', true, 2
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'website-development' and g.name = 'Website Maintenance';
insert into pricing_plans (group_id, tier, price_old, price_new, period, features, delivery, revisions, show_custom_quote, order_index)
select g.id, 'Premium', 6999, 4999, '/mo', array['Everything in Standard','Daily backups','New feature additions each month'], 'Rolling', 'Unlimited minor', true, 3
from pricing_groups g join pricing_categories c on c.id = g.category_id where c.slug = 'website-development' and g.name = 'Website Maintenance';
￼Enter=========================================================
-- FX STUDIO — PRICING SCHEMA (standalone, safe to re-run)
-- Only touches pricing tables. Does NOT touch site_settings,
-- portfolio_items, services, or reviews — those are untouched.
--
-- Why the previous script failed: your database already had a
-- pricing_plans table from the OLD flat pricing system (tier,
-- price_old, price_new, delivery, badge, is_popular — no
-- group_id column). "create table if not exists" saw that table
-- already existed and skipped creating the new one, so the next
-- statement tried to index a group_id column that was never
-- there. This version drops any old pricing_plans / pricing_groups
-- / pricing_categories tables first — regardless of their shape —
-- then rebuilds them clean, every time you run it.
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- clean slate for pricing only ----------
drop table if exists pricing_plans cascade;
drop table if exists pricing_groups cascade;
drop table if exists pricing_categories cascade;

-- ============================================================
-- PRICING — CATEGORY -> GROUP -> PLAN
-- ============================================================
create table pricing_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  services text[] default '{}',   -- chip list, e.g. {"UGC Ads","Product Video Ads"}
  order_index int default 0,
  is_active boolean default true
);

create table pricing_groups (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references pricing_categories(id) on delete cascade,
  name text not null,             -- "Packages", "Monthly Plans", "Monthly Management", "Maintenance"
  is_monthly boolean default false,
  is_enabled boolean default true,  -- lets admin hide a whole group (e.g. disable Monthly Plans)
  order_index int default 0
);
create index idx_pricing_groups_category on pricing_groups(category_id);

create table pricing_plans (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references pricing_groups(id) on delete cascade,
  tier text not null,             -- "Starter", "20 Ads / Month", etc.
  price_old numeric,
  price_new numeric,
  offer_enabled boolean default true,
  currency text default '₹',
  period text default '',         -- e.g. "/mo" appended after price on monthly groups
  features text[] default '{}',
  delivery text default '',
  revisions text default '',
  is_best_seller boolean default false,
  is_recommended boolean default false,
  show_custom_quote boolean default false,
  custom_quote_note text default 'Need something different? Get a custom quote.',
  order_index int default 0
);
create index idx_pricing_plans_group on pricing_plans(group_id);

-- ============================================================
-- RLS — public can read, only logged-in admin can write
-- ============================================================
alter table pricing_categories enable row level security;
alter table pricing_groups     enable row level security;
alter table pricing_plans      enable row level security;

drop policy if exists "public read pricing_categories" on pricing_categories;
create policy "public read pricing_categories" on pricing_categories for select using (true);
drop policy if exists "admin write pricing_categories" on pricing_categories;
create policy "admin write pricing_categories" on pricing_categories for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "public read pricing_groups" on pricing_groups;
create policy "public read pricing_groups" on pricing_groups for select using (true);
drop policy if exists "admin write pricing_groups" on pricing_groups;
create policy "admin write pricing_groups" on pricing_groups for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "public read pricing_plans" on pricing_plans;
create policy "public read pricing_plans" on pricing_plans for select using (true);
drop policy if exists "admin write pricing_plans" on pricing_plans;
create policy "admin write pricing_plans" on pricing_plans for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ============================================================
-- SEED DATA — matches the taxonomy from the brief.
-- Categories, groups, and starter plans for all four categories
-- so the live site and admin panel both have real rows to show
