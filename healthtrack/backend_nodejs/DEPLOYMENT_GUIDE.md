# HealthTrack Backend — Render Deployment Guide

## Quick Summary
- **Backend hosting**: Render (Starter plan, $7/mo)
- **Database**: Railway MySQL (free tier)
- **Push notifications**: Firebase Cloud Messaging
- **Build command**: `npm install`
- **Start command**: `npm start`
- **Root directory** (in Render): `backend_nodejs`
- **Health check path**: `/health`

---

## STEP 1 — Set Up Railway MySQL Database

1. Go to [railway.app](https://railway.app) → **New Project** → **Add a Service** → **MySQL**
2. Once provisioned, click the MySQL service → **Variables** tab
3. Copy these four values for use in Step 3:
   - `MYSQL_HOST` → your `DB_HOST`
   - `MYSQL_USER` → your `DB_USER`
   - `MYSQL_PASSWORD` → your `DB_PASS`
   - `MYSQL_DATABASE` → your `DB_NAME` (Railway sets this to `railway`)
   - `MYSQL_PORT` → your `DB_PORT` (usually `3306`)
4. Click **Connect** → **MySQL Client** (or use a tool like TablePlus / DBeaver)
5. Run the schema:
   ```
   database/railway_schema.sql
   ```
6. Verify by running: `SHOW TABLES;` — you should see ~15 tables

> **Default admin credentials after schema import:**
> - Username: `admin`
> - Password: `HealthTrack@2025`
> - **Change this immediately after first login**

---

## STEP 2 — Generate Firebase Credentials

The original Firebase JSON key was deleted. You need a new one:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → **Project Settings** → **Service Accounts**
3. Find the old key with ID `4ada6cfc53f1` → click ⋮ → **Revoke** (if not already done)
4. Click **Generate new private key** → download JSON
5. From the downloaded JSON, copy:
   - `project_id` → `FIREBASE_PROJECT_ID`
   - `private_key` → `FIREBASE_PRIVATE_KEY` (the entire `-----BEGIN...-----END-----\n` block)
   - `client_email` → `FIREBASE_CLIENT_EMAIL`

---

## STEP 3 — Generate JWT Secret

Run this in any terminal:
```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```
Copy the output → `JWT_SECRET`

---

## STEP 4 — Deploy to Render

1. Push your code to GitHub:
   ```bash
   git add .
   git commit -m "Production ready: bcrypt, JWT, auth guards, Railway DB"
   git push origin main
   ```

2. Go to [render.com](https://render.com) → **New** → **Web Service**

3. Connect your GitHub repository

4. Set these fields:
   | Field | Value |
   |---|---|
   | **Root Directory** | `backend_nodejs` |
   | **Environment** | `Node` |
   | **Build Command** | `npm install` |
   | **Start Command** | `npm start` |
   | **Plan** | Starter ($7/mo) |

5. Click **Advanced** → **Add Environment Variables** — add every variable from the table below

6. Click **Create Web Service** → wait for the green deploy ✅

---

## STEP 5 — Environment Variables (Render Dashboard)

| Variable | Value | Notes |
|---|---|---|
| `NODE_ENV` | `production` | |
| `PORT` | `10000` | Render injects this automatically |
| `DB_HOST` | `<from Railway>` | e.g. `containers-us-west-xxx.railway.app` |
| `DB_USER` | `<from Railway>` | usually `root` |
| `DB_PASS` | `<from Railway>` | strong password |
| `DB_NAME` | `railway` | Railway's default DB name |
| `DB_PORT` | `3306` | |
| `JWT_SECRET` | `<64-char hex>` | generated in Step 3 |
| `JWT_EXPIRES_IN` | `24h` | |
| `ALLOWED_ORIGINS` | `https://your-flutter-app.vercel.app` | your Flutter web URL |
| `FIREBASE_PROJECT_ID` | `healthtrack-d20c2` | from new key JSON |
| `FIREBASE_PRIVATE_KEY` | `-----BEGIN PRIVATE KEY-----\n...` | entire key with `\n` literals |
| `FIREBASE_CLIENT_EMAIL` | `firebase-adminsdk-...` | from new key JSON |
| `NOTIFICATION_TIMEZONE` | `Asia/Manila` | |
| `TEST_MODE` | `false` | |

> **FIREBASE_PRIVATE_KEY tip**: In Render's dashboard, paste the key exactly as it appears
> in the JSON file. The `\n` characters should be **literal backslash-n** in the env var value,
> not real newlines. The code handles the conversion automatically.

---

## STEP 6 — Verify Deployment

After deploy completes, test these URLs in your browser or Postman:

```
GET  https://your-service.onrender.com/
     → { "success": true, "message": "HealthTrack API is running" }

GET  https://your-service.onrender.com/health
     → { "success": true, "message": "Server is healthy" }

POST https://your-service.onrender.com/admin/login
     Body: { "username": "admin", "password": "HealthTrack@2025" }
     → { "success": true, "access_token": "..." }
```

---

## STEP 7 — Update Flutter App

In `lib/env_config.dart`, ensure:
```dart
static const String currentEnvironment = production;
static const String _renderUrl = 'https://your-actual-service.onrender.com';
```

Replace `healthtrack-api.onrender.com` with your actual Render service URL.

---

## Git Commands Before First Push

```bash
# Ensure no secrets are staged
git status

# Remove any accidentally tracked .env files
git rm --cached backend_nodejs/.env 2>/dev/null || true
git rm --cached "backend_nodejs/*.json" 2>/dev/null || true
git rm -r --cached backend_nodejs/node_modules 2>/dev/null || true

# Stage all your source changes
git add backend_nodejs/src/
git add backend_nodejs/package.json
git add backend_nodejs/render.yaml
git add backend_nodejs/.env.example
git add database/railway_schema.sql
git add lib/env_config.dart
git add .gitignore

git commit -m "Production ready: bcrypt passwords, JWT auth, route guards, Railway DB schema"
git push origin main
```

---

## Production Checklist

- [ ] Railway MySQL database provisioned
- [ ] `railway_schema.sql` imported successfully (`SHOW TABLES` shows 15+ tables)
- [ ] Default admin password changed from `HealthTrack@2025`
- [ ] Old Firebase key revoked in Firebase Console
- [ ] New Firebase private key generated and copied
- [ ] JWT_SECRET generated (64-char random hex)
- [ ] Git repo has no `.env` files or `*.json` key files tracked
- [ ] `node_modules/` not in git
- [ ] Render Web Service created with `Root Directory = backend_nodejs`
- [ ] All 15 environment variables set in Render Dashboard
- [ ] Render deploy succeeds (green checkmark)
- [ ] `GET /health` returns `200 OK`
- [ ] `POST /admin/login` returns `access_token`
- [ ] Flutter `env_config.dart` updated to `production` with real Render URL
- [ ] Flutter app connects and users can register/login
- [ ] Push notifications working (test via Flutter app)
