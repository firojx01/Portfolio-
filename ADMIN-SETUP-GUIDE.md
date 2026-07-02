# FX Studio Admin Dashboard — Setup Guide

This connects the admin dashboard to your own Supabase project. Takes about 10 minutes, one time only.

## 1. Create a Supabase project
1. Go to https://supabase.com → New Project.
2. Pick any name/region, set a database password (save it somewhere safe).
3. Wait ~2 minutes for the project to spin up.

## 2. Run the schema
1. In your Supabase project, open **SQL Editor**.
2. Open `supabase-schema.sql` (included alongside this guide), copy the whole file, paste it into a new query, and click **Run**.
3. This creates all 5 tables, the storage bucket (`fx-media`), and the security rules that let the public read your content but only you edit it.

## 3. Create your admin login
1. Go to **Authentication → Users → Add User**.
2. Enter your email (e.g. `rahamanfiroj54@gmail.com`) and a strong password.
3. Toggle **Auto Confirm User** on, then create.
4. This is the only account that can log into the dashboard — there's no public sign-up screen, by design.

## 4. Get your API keys
1. Go to **Project Settings → API**.
2. Copy the **Project URL** and the **`anon` public key**.

## 5. Connect the dashboard
1. Open `admin-dashboard.html` in a text editor.
2. Near the top of the `<script>` block, find:
   ```js
   const SUPABASE_URL = "YOUR_SUPABASE_URL";
   const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
   ```
3. Paste in your values from step 4. Save.

## 6. Use it
- Open `admin-dashboard.html` in any browser (or host it privately — see note below).
- Log in with the email/password from step 3.
- Upload your logo, hero image, about photo, showreel, and portfolio items; edit pricing, services, contact info; approve or delete reviews.

## Where should this file live?
`admin-dashboard.html` has no secrets in it (the anon key is safe to expose — that's what Row Level Security is for), but it's still an admin tool, so don't link to it from your public nav. Host it at a private/unlisted URL (e.g. `yourdomain.com/fx-admin-9k2x/`) or keep it local and open it as a file when you need it.

## Important: this dashboard alone does not change your live site — yet
Right now your public FX Studio site is static HTML with hardcoded text and images. This dashboard writes to your new Supabase database and storage bucket correctly, but the public site isn't reading from it yet. That's a separate, smaller wiring job (swap the hardcoded hero text, portfolio grid, pricing cards, etc. for live Supabase fetches). Ask me for that next and I'll wire the two together so dashboard edits show up live.
