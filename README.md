# DIV Giveaway

A professional, mobile-first giveaway website for upcoming DIV apps.

## Included now
- `index.html` — public giveaway landing page and registration form
- `admin.html` — admin login/dashboard interface
- `styles.css` — responsive DIV visual design
- `app.js` — public registration logic and secure-backend integration point
- `admin.js` — admin dashboard interaction scaffold
- `supabase-config.example.js` — safe public-key configuration template
- `.gitignore` — prevents local secrets/config from being committed

## Important security rule
The frontend is intentionally **not** storing participant records in GitHub. Connect the form and admin dashboard to Supabase (or another secure backend) before launch. Never place a Supabase service-role key, admin password, gift-card inventory, or private API secret in browser code or this repository.

## Supabase setup planned
Create a `participants` table with fields such as:
- `id`
- `full_name`
- `email`
- `phone`
- `country`
- `app_interest`
- `social_handle`
- `consent`
- `created_at`
- `status`
- `gift_card_status`
- `gift_card_code`
- `admin_notes`

Use Row Level Security (RLS). Public users should only be able to submit an allowed registration payload. Only authenticated admin users should be able to read/update participant records or gift-card information.

## Run locally
Open `index.html` in a browser for the public interface. The repository can also be published with GitHub Pages once the backend connection is configured.

## Next step
Connect Supabase authentication + database + RLS, then wire the public form to create entries and the admin dashboard to securely list/search/select participants and record gift-card delivery.