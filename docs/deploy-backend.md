# Deploying the backend to Bunny.net Magic Containers

One-time manual setup (needs your Bunny account and GitHub repo access - not
something that can be scripted from here), then every push to `backend/**`
on `main` rolls out automatically via `.github/workflows/deploy-backend.yml`.

## Database: Neon, not a sibling container

Magic Containers has no managed Postgres yet (Bunny Database, their new
managed-SQL product, is libSQL-only in preview) - the original version of
this doc ran Postgres as a second container in the same app for that reason.
Since the database is Neon instead, only the `api` container runs on Magic
Containers at all; Neon is reached over the public internet like any other
external service.

One thing this needs that a same-pod Postgres wouldn't: Neon's connection
string comes with `sslmode=require&channel_binding=require`, which are
libpq-style params asyncpg doesn't understand - passed straight through as
unrecognised connect kwargs, asyncpg rejects the connection outright. Both
`app/db/session.py` and `alembic/env.py` now strip those and translate them
to the `ssl` connect kwarg asyncpg actually wants
(`prepare_database_url()`), so the same `DATABASE_URL` works whether it's
Neon's or the plain local one - nothing further to configure for this part.

## 1. Get an initial image into GHCR

The Bunny dashboard can only pick an image that already exists, so the very
first build has to happen before the app exists on Bunny's side:

1. Push any change under `backend/` to `main` (or re-run the workflow
   manually from the Actions tab). The build-and-push step will succeed and
   publish `ghcr.io/stay-naijaa/staynaija-backend:<sha>`; the final
   "Roll out on Magic Containers" step will fail - expected, since there's no
   app to roll out yet. Ignore that failure for now.
2. GitHub Container Registry packages are private by default. Either make
   `staynaija-backend` public (package Settings → Change visibility), or note
   the package so you can connect it as a private registry in step 2 - you'll
   need a GitHub PAT with `read:packages` scope either way if you keep it
   private.

## 2. Create a Neon project

In Neon, create a project/database and grab its connection string from the
dashboard - it looks like:

```
postgresql://neondb_owner:<password>@ep-xxxx-xxxx.<region>.aws.neon.tech/neondb?sslmode=require&channel_binding=require
```

Two edits before it's usable as `DATABASE_URL` here:

1. Change the scheme from `postgresql://` to `postgresql+asyncpg://` - this
   codebase's SQLAlchemy setup needs the driver named explicitly.
2. Leave the `sslmode`/`channel_binding` params in place - `prepare_database_url()`
   strips and translates them at startup, so the connection string doesn't
   need hand-editing beyond the scheme change.

Run `alembic upgrade head` against it once yourself before the first deploy
(`DATABASE_URL=<neon url> alembic upgrade head` from `backend/`, with your
local venv/deps), or just let the container do it - the Dockerfile's `CMD`
runs migrations on every start regardless.

## 3. Create the app on Magic Containers

In the Bunny dashboard, Magic Containers → New App, add **one container**:

### `api` (this backend)

| Setting | Value |
|---|---|
| Image | the GHCR image from step 1 |
| Port | `8000`, endpoint type CDN (this is a normal HTTP API) |
| Volume | mount path `/app/uploads` - without this, every rolling update wipes listing photos and verification documents (container disk is ephemeral) |

Environment variables for `api` (see `backend/.env.example` for the full
list) - the ones that matter most to get right:

| Variable | Value |
|---|---|
| `DATABASE_URL` | your Neon connection string from step 2, with `+asyncpg` added to the scheme |
| `JWT_SECRET` | a real long random value - never the `change-me-...` placeholder |
| `PAYSTACK_SECRET_KEY` / `PAYSTACK_PUBLIC_KEY` | your real test or live Paystack keys |
| `ENV` | `production` |
| `PUBLIC_BASE_URL` | fill in *after* deploying once you know the app's Bunny-assigned URL (or your custom domain) - this is what makes uploaded-photo URLs resolve correctly, see `_save_upload` in `app/api/v1/users.py` |
| `CORS_ORIGINS` | your real app origins once known, instead of `*` |

Deploy the app. Note the **App ID** Bunny assigns it (shown in the app's
dashboard URL/settings) and the container name you gave the API container
(the workflow assumes `api` - rename the step's `container:` input to match
if you called it something else).

## 4. Wire up GitHub Actions

In the GitHub repo (`Stay-Naijaa/staynaija`) → Settings → Secrets and
variables → Actions:

- **Secret** `BUNNY_API_KEY` - your Bunny account API key (Account Settings →
  API, master account only).
- **Variable** `BUNNY_APP_ID` - the App ID from step 3.

Push to `backend/**` again (or re-run the failed workflow run from step 1) -
this time the rollout step will find the app and update it.

## 5. Point the mobile apps at it

Both apps default to `http://localhost:8000` (`ApiConfig.baseUrl` in
`staynaija_shared/lib/core/api/api_config.dart`), which only works during
local device testing via `adb reverse`. Release builds need:

```
flutter build apk --dart-define=API_BASE_URL=https://<your-production-url>
```

(or the equivalent for `flutter build ipa`), once `PUBLIC_BASE_URL` in step 2
is filled in to match.
