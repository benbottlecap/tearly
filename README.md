# Tearly

A cry journal: log a cry in three taps, watch your bottle fill, reflect on the patterns, and let friends send a hug.

It is a static web app (no build step) backed by Supabase for accounts, private entries and friends.
Without Supabase details in `config.js` it still works, saving entries on the device only, with Friends switched off.

## Set up the server (about 10 minutes)

1. Create a free project at supabase.com.
2. In the project, open **SQL Editor**, paste the contents of `supabase/schema.sql`, and run it.
3. Open **Project Settings → API** and copy the **Project URL** and the **anon public** key into `config.js`.
4. Under **Authentication → URL Configuration**, set **Site URL** to the address where Tearly is hosted.
5. Optional for testing: under **Authentication → Providers → Email**, turn off **Confirm email** so new accounts can sign in straight away.

## Host it

Any static host works (GitHub Pages, Netlify, Vercel, Cloudflare Pages). Publish this folder as it is.
On an iPhone, open the address in Safari and choose **Share → Add to Home Screen**.

## Not built yet

- Push or email notifications. Updates appear live while Tearly is open and on next open otherwise.
- The fuller "Reflect with me" reading. It needs a small server function holding an AI key; the built-in reflection works without it.
