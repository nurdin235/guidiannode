# GuardianNode Production Deployment

GuardianNode consists of a Flutter client, a Node/Express API, and Supabase. Authentication uses inbound WhatsApp messages; Twilio is not required.

## Backend

Deploy `server/` to Render, Railway, or a Node 20+ VPS. The process must remain available to receive Meta webhooks.

```bash
npm ci --omit=dev
npm run check:env:prod
npm start
```

Use `server/.env.production.example` as the environment-variable template. Required production values include:

```env
NODE_ENV=production
PORT=3000
APP_BASE_URL=https://app.yourdomain.com
CORS_ORIGIN=https://app.yourdomain.com
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=replace_in_host_secret_store
GOOGLE_MAPS_SERVER_API_KEY=replace_in_host_secret_store
JWT_SECRET=replace_with_at_least_32_random_characters
META_APP_ID=replace_with_meta_app_id
META_BUSINESS_ID=replace_with_meta_business_id
WHATSAPP_API_VERSION=v22.0
WHATSAPP_TARGET_NUMBER=237657262038
WHATSAPP_PHONE_NUMBER_ID=replace_with_phone_number_id
WHATSAPP_BUSINESS_ACCOUNT_ID=replace_with_waba_id
WHATSAPP_VERIFY_TOKEN=replace_with_a_private_random_verify_token
WHATSAPP_APP_SECRET=replace_with_meta_app_secret
WEBHOOK_URL=https://guidiannode-production.up.railway.app/webhook
DEBUG_AUTH_MODE=false
```

`DATABASE_URL` and `SESSION_SECRET` are supported in the environment templates. This application currently accesses the database through Supabase; `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are therefore required. `SESSION_SECRET` can be used instead of `JWT_SECRET`. `WHATSAPP_ACCESS_TOKEN` is optional for this inbound-only flow.

Health checks:

```text
GET https://guidiannode-production.up.railway.app/health
GET https://guidiannode-production.up.railway.app/ready
```

Public Meta app publishing pages:

```text
https://guidiannode-production.up.railway.app/privacy-policy
https://guidiannode-production.up.railway.app/data-deletion
```

Docker deployment definitions are available at `Dockerfile` for repository-root
deployments and `server/Dockerfile` for backend-root deployments.
`render.yaml` is a Render starting point.

The repository root now contains `Dockerfile`, `.dockerignore`, and
`railway.json`, so Railway can deploy the backend correctly even when the
service Root Directory remains `/`.

Both Railway configurations watch `server/**`; backend changes therefore
trigger deployments whether the service uses the repository-root or
backend-root layout.

The root `package.json` also declares `server` as an npm workspace. This gives
Railpack a Node entry point if the Railway service is configured to use
automatic framework detection instead of the root Dockerfile.

Recommended Railway configuration:

```text
Root Directory: /
Config File Path: /railway.json
Healthcheck Path: /health
```

Alternatively, the older `/server` deployment layout remains supported with
Root Directory `/server` and Config File Path `/server/railway.json`.

Paste `server/railway.variables.example.json` into Railway's Variables Raw
Editor, then replace every placeholder before deploying.

## Database

Apply these scripts in Supabase SQL Editor before directing production traffic:

```text
server/sql/create_otp_sessions.sql
server/sql/add_enum_value.sql
server/sql/add_whatsapp_verification_columns.sql
server/sql/add_whatsapp_verification_index.sql
server/sql/reload_schema_cache.sql
```

The migrations preserve old OTP columns and add nullable WhatsApp fields plus `users.phone_verified`.

## Meta Webhook

Configure the WhatsApp product webhook callback as:

```text
https://guidiannode-production.up.railway.app/webhook
```

Use the exact production value of `WHATSAPP_VERIFY_TOKEN`. Subscribe to the `messages` field. Production POST requests require a valid `X-Hub-Signature-256` generated with `WHATSAPP_APP_SECRET`.

Do not use ngrok for production. Tunnel domains are temporary development endpoints.

## Flutter Web

Create `config/flutter.production.json` from `config/flutter.production.example.json`, then build:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=config/flutter.production.json
```

Deploy `build/web` to Firebase Hosting, Netlify, or Vercel with SPA rewrites to `index.html`. `firebase.json` contains a Firebase Hosting configuration.

Flutter compile-time values use `API_BASE_URL` and `WHATSAPP_TARGET_NUMBER`. The equivalent `VITE_API_BASE_URL` and `VITE_WHATSAPP_TARGET_NUMBER` aliases are also accepted for deployment compatibility.

## Android

Create an upload keystore and `android/key.properties` before building:

```powershell
keytool -genkeypair -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
Copy-Item android/key.properties.example android/key.properties
flutter build appbundle --release --dart-define-from-file=config/flutter.production.json
```

Keep the keystore, passwords, and `key.properties` outside source control. The expected bundle is `build/app/outputs/bundle/release/app-release.aab`.

## Credential Safety

Never commit `.env`, access tokens, service-role keys, app secrets, or keystores. If a credential has ever been committed or pasted into a shared channel, rotate it before deployment and remove it from Git history where appropriate.
