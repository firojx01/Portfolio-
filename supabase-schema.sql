-- ============================================================
-- FX STUDIO -- SUPABASE SCHEMA (production-ready, re-runnable)
-- Run this whole file in Supabase Dashboard -> SQL Editor.
-- Safe to run more than once: every statement is idempotent.
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- TABLES
-- ============================================================

-- ---------- SITE SETTINGS (singleton row: branding + contact) ----------
create table if not exists site_settings (
  id int primary key default 1,
  logo_url text,
  hero_image_url text,
  about_photo_url text,
  showreel_url text,
  headline text default 'We Create Creative Designs That Grow Your Business.',
  subheadline text default 'FX Studio helps businesses grow with Premium UGC Ads, Product Video Ads, Logo Design, Banner Design, Posters, Facebook Ads, Branding, and Professional Business Websites.',
  tagline text default 'Creative Designs. Powerful Ads. Real Results.',
  whatsapp text default '+91 9064234366',
  email text default 'rahamanfiroj54@gmail.com',
  instagram_url text default 'https://instagram.com/firojx.live',
  instagram_handle text default '@firojx.live',
  updated_at timestamptz default now(),
  constraint singleton check (id = 1)
);
insert into site_settings (id) values (1) on conflict (id) do nothing;

-- ---------- SERVICES ----------
create table if not exists services (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  order_index int default 0,
  created_at timestamptz default now()
);

-- ---------- PRICING PLANS ----------
create table if not exists pricing_plans (
  id uuid primary key default gen_random_uuid(),
  tier text not null unique,        -- Starter / Professional / Premium
  price_old text,
  price_new text,
  features jsonb default '[]',      -- array of strings
  delivery text,
  badge text,
  is_popular boolean default false,
  order_index int default 0
);

-- ---------- REVIEWS ----------
create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  company text,
  stars int default 5 check (stars between 1 and 5),
  message text not null,
  approved boolean default false,
  created_at timestamptz default now()
);

-- ---------- PORTFOLIO ITEMS ----------
create table if not exists portfolio_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,           -- ads / branding / websites / logos / banners / posters
  media_type text not null check (media_type in ('image','video')),
  media_url text not null,
  thumbnail_url text,               -- required for video, optional for image
  order_index int default 0,
  created_at timestamptz default now()
);

-- ============================================================
-- INDEXES
-- ============================================================
create index if not exists idx_portfolio_category on portfolio_items (category);
create index if not exists idx_portfolio_media_type on portfolio_items (media_type);
create index if not exists idx_portfolio_created_at on portfolio_items (created_at desc);
create index if not exists idx_reviews_approved on reviews (approved);
create index if not exists idx_services_order on services (order_index);
create index if not exists idx_pricing_order on pricing_plans (order_index);

-- ============================================================
-- TRIGGER: auto-update site_settings.updated_at on every UPDATE
-- ============================================================
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_site_settings_updated_at on site_settings;
create trigger trg_site_settings_updated_at
  before update on site_settings
  for each row
  execute function set_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- Public (anon) can READ everything. Only logged-in admins can WRITE.
-- ============================================================
alter table site_settings enable row level security;
alter table services enable row level security;
alter table pricing_plans enable row level security;
alter table reviews enable row level security;
alter table portfolio_items enable row level security;

-- Public read policies
drop policy if exists "public read site_settings" on site_settings;
create policy "public read site_settings" on site_settings for select using (true);

drop policy if exists "public read services" on services;
create policy "public read services" on services for select using (true);

drop policy if exists "public read pricing_plans" on pricing_plans;
create policy "public read pricing_plans" on pricing_plans for select using (true);

drop policy if exists "public read approved reviews" on reviews;
create policy "public read approved reviews" on reviews for select using (approved = true);

drop policy if exists "public read portfolio_items" on portfolio_items;
create policy "public read portfolio_items" on portfolio_items for select using (true);

-- Authenticated (admin) full access
drop policy if exists "admin write site_settings" on site_settings;
create policy "admin write site_settings" on site_settings for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "admin write services" on services;
create policy "admin write services" on services for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "admin write pricing_plans" on pricing_plans;
create policy "admin write pricing_plans" on pricing_plans for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "admin write reviews" on reviews;
create policy "admin write reviews" on reviews for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "admin write portfolio_items" on portfolio_items;
create policy "admin write portfolio_items" on portfolio_items for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "admin read all reviews" on reviews;
create policy "admin read all reviews" on reviews for select
  using (auth.role() = 'authenticated');

-- ============================================================
-- STORAGE BUCKET
-- One public bucket, folders: logo/ hero/ about/ showreel/ portfolio/ thumbnails/
-- ============================================================
insert into storage.buckets (id, name, public)
values ('fx-media', 'fx-media', true)
on conflict (id) do nothing;

drop policy if exists "public read fx-media" on storage.objects;
create policy "public read fx-media" on storage.objects
  for select using (bucket_id = 'fx-media');

drop policy if exists "admin upload fx-media" on storage.objects;
create policy "admin upload fx-media" on storage.objects
  for insert with check (bucket_id = 'fx-media' and auth.role() = 'authenticated');

drop policy if exists "admin update fx-media" on storage.objects;
create policy "admin update fx-media" on storage.objects
  for update using (bucket_id = 'fx-media' and auth.role() = 'authenticated');

drop policy if exists "admin delete fx-media" on storage.objects;
create policy "admin delete fx-media" on storage.objects
  for delete using (bucket_id = 'fx-media' and auth.role() = 'authenticated');

-- ============================================================
-- SEED starter pricing rows
-- (matches current live site -- edit anytime from the dashboard;
--  "on conflict (tier) do nothing" means re-running this file will
--  never overwrite prices you've already changed in the dashboard)
-- ============================================================
insert into pricing_plans (tier, price_old, price_new, features, delivery, badge, is_popular, order_index)
values
  (
    'Starter',
    '₹4,999',
    '₹3,999',
    '["2 UGC Ads","2 Product Video Ads","Professional Logo","Premium Banner","HD Export","2 Revisions"]'::jsonb,
    '7 Days',
    null,
    false,
    1
  ),
  (
    'Professional',
    '₹6,999',
    '₹5,499',
    '["Everything in Starter","Facebook Ads Setup (2 Campaigns)","Priority Support","3 Revisions"]'::jsonb,
    '10 Days',
    'Most Popular',
    true,
    2
  ),
  (
    'Premium',
    '₹14,999',
    '₹9,999',
    '["Everything in Professional","Facebook Ads Management (7 Days)","Campaign Optimization","Performance Report","Unlimited Minor Revisions","Priority Support"]'::jsonb,
    '14 Days',
    'Best Value',
    false,
    3
  )
on conflict (tier) do nothing;
