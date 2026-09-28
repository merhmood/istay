# Deploying the backend to Bunny.net Magic Containers

One-time manual setup (needs your Bunny account and GitHub repo access - not
something that can be scripted from here), then every push to `backend/**`
on `main` rolls out automatically via `.github/workflows/deploy-backend.yml`.

## Why two containers

Magic Containers has no managed Postgres yet (Bunny Database, their new
managed-SQL product, is libSQL-only in preview). Instead you run Postgres as
a second container in the same app - same pattern as `docker-compose.yml`
locally, just both containers live in one Bunny "app" (pod) and talk over
`127.0.0.1` instead of a compose network.

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

## 2. Create the app on Magic Containers

In the Bunny dashboard, Magic Containers → New App, add **two containers**:

### `db` (Postgres)

| Setting | Value |
|---|---|
| Image | `postgres:16-alpine` (matches local dev) |
| Port | `5432` |
| Env `POSTGRES_USER` | `staynaija` |
| Env `POSTGRES_PASSWORD` | a real generated password - **not** `staynaija` |
| Env `POSTGRES_DB` | `staynaija` |
| Env `PGDATA` | `/var/lib/postgresql/data/pgdata` |
| Volume | name `postgres-data`, mount path `/var/lib/postgresql/data` |
| Region | single region, single instance - Postgres here has no replication |

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
| `DATABASE_URL` | `postgresql+asyncpg://staynaija:<the db password>@127.0.0.1:5432/staynaija` - note the `+asyncpg` driver suffix; Bunny's generic Postgres example omits it, but this codebase's SQLAlchemy setup requires it |
| `JWT_SECRET` | a real long random value - never the `change-me-...` placeholder |
| `PAYSTACK_SECRET_KEY` / `PAYSTACK_PUBLIC_KEY` | your real test or live Paystack keys |
| `ENV` | `production` |
| `PUBLIC_BASE_URL` | fill in *after* deploying once you know the app's Bunny-assigned URL (or your custom domain) - this is what makes uploaded-photo URLs resolve correctly, see `_save_upload` in `app/api/v1/users.py` |
| `CORS_ORIGINS` | your real app origins once known, instead of `*` |

Deploy the app. Note the **App ID** Bunny assigns it (shown in the app's
dashboard URL/settings) and the container name you gave the API container
(the workflow assumes `api` - rename the step's `container:` input to match
if you called it something else).

## 3. Wire up GitHub Actions

In the GitHub repo (`Stay-Naijaa/staynaija`) → Settings → Secrets and
variables → Actions:

- **Secret** `BUNNY_API_KEY` - your Bunny account API key (Account Settings →
  API, master account only).
- **Variable** `BUNNY_APP_ID` - the App ID from step 2.

Push to `backend/**` again (or re-run the failed workflow run from step 1) -
this time the rollout step will find the app and update it.

## 4. Point the mobile apps at it

Both apps default to `http://localhost:8000` (`ApiConfig.baseUrl` in
`staynaija_shared/lib/core/api/api_config.dart`), which only works during
local device testing via `adb reverse`. Release builds need:

```
flutter build apk --dart-define=API_BASE_URL=https://<your-production-url>
```

(or the equivalent for `flutter build ipa`), once `PUBLIC_BASE_URL` in step 2
is filled in to match.
