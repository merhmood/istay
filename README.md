# iStay

A localized Airbnb-style short-let marketplace for the Nigerian market: a Flutter app backed by a FastAPI + PostgreSQL service.

See [`.claude` plan notes / PRD context] for the full product spec. This repo contains a real, runnable slice of the MVP (Phase 1): listing creation, search/discovery, booking, payments (Flutterwave), and messaging — plus host tooling and reviews.

## Repository layout

- `backend/` — FastAPI service (auth, listings, bookings, payments, messaging, reviews)
- `mobile/` — Flutter app (guest + host experience in one app)
- `docker-compose.yml` — Postgres + backend, one command to run the backend locally

## Running the backend

```bash
cp backend/.env.example backend/.env   # then edit FLUTTERWAVE_SECRET_KEY / FLUTTERWAVE_PUBLIC_KEY with your test keys
docker compose up -d --build
docker compose exec api python seed.py   # demo host/guest + 3 listings
```

API docs: http://localhost:8000/docs
Demo logins (after seeding): `guest@staynaija.demo` / `host@staynaija.demo`, password `password123`.

If Postgres port 5432 is already taken on your machine, the compose file publishes it on `5433` instead — only relevant if you connect to Postgres directly from the host.

## Running the mobile app

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

- On an Android emulator, `localhost` refers to the emulator itself, not your host machine — use `http://10.0.2.2:8000` instead.
- On a physical device, use your machine's LAN IP (e.g. `http://192.168.1.20:8000`).
- Web (`flutter run -d chrome`) can use `http://localhost:8000` directly.

## What's real vs. stubbed

This build wires up real infrastructure (Postgres, JWT auth, Flutterwave's actual API, a live WebSocket chat) but deliberately leaves a few pieces as clearly-marked seams because they need third-party accounts nobody has set up yet:

- **SMS OTP**: OTP codes are real (generated, hashed, expiring) but delivery is stubbed — in dev mode the code comes back in the API response instead of being texted. Wire a provider (Termii, Africa's Talking, Twilio) into `backend/app/services/otp.py::send_sms`.
- **ID/selfie verification**: uploads are stored and marked `pending`; there's no KYC vendor integration or admin UI to approve them yet — approve manually via `PATCH /api/v1/users/{id}/verification-status`.
- **Maps**: uses OpenStreetMap tiles via `flutter_map` (no Google Maps API key needed).
- **Push notifications**: in-app/WebSocket only; no Firebase Cloud Messaging project is wired up.
- **Admin dashboard, AI pricing, smart locks, insurance, promoted listings**: out of scope for this build (later-phase per the product roadmap).

## Payments

Payments go through Flutterwave's real Transactions API in test mode. Get test keys from your Flutterwave dashboard and put them in `backend/.env`:

```
FLUTTERWAVE_SECRET_KEY=FLWSECK_TEST-...
FLUTTERWAVE_PUBLIC_KEY=FLWPUBK_TEST-...
```

Use [Flutterwave's published test cards](https://developer.flutterwave.com/docs/integration-guides/testing-helpers) to complete a checkout end-to-end in the app.
