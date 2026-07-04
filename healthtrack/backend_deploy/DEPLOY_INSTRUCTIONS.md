# Backend Deployment Instructions — Vaccine Tracking Feature

Follow these steps **in order** to deploy the vaccine tracking feature to your
live Render + Aiven stack. Nothing below touches data that already exists.

---

## Step 1 — Run the SQL Migration Against Aiven

Connect to your Aiven PostgreSQL instance with any PostgreSQL client
(psql, DBeaver, TablePlus, etc.) and run:

```
backend_deploy/migrations/001_vaccine_tables.sql
```

The script is fully idempotent — `CREATE TABLE IF NOT EXISTS`,
`CREATE UNIQUE INDEX IF NOT EXISTS`, and `ON CONFLICT DO NOTHING` mean it is
safe to run multiple times without duplicating data.

**What it creates:**
- `vaccine_schedules` — master schedule with 14 Philippine EPI doses (seeded)
- `child_vaccine_records` — per-child completion records (starts empty)

---

## Step 2 — Add the Route File to Your Render Backend

Copy `backend_deploy/routes/vaccines.js` into your Render backend's
`routes/` directory (alongside your existing `appointments.js`, `patients.js`,
etc.).

---

## Step 3 — Mount the Route in Your Express App

In your main `app.js` (or `index.js` / `server.js`), add **two lines**:

```js
// near the top, with your other requires:
const vaccineRoutes = require('./routes/vaccines');

// with your other app.use() route mounts (after authenticateToken is defined):
app.use('/vaccines', authenticateToken, vaccineRoutes);
```

The route file expects:
- `req.app.get('pool')` — your existing `pg.Pool` instance.
  If your app stores it differently (e.g. `req.db`), adjust the two
  `const pool = req.app.get('pool')` lines at the top of each handler.
- `req.app.get('io')` — your Socket.IO server instance.
  If stored differently (e.g. `global.io`), replace those lines similarly.

---

## Step 4 — Verify Socket.IO Room Name Convention

The vaccine route emits to `user_<patient_id>`.  Make sure your Socket.IO
server already handles `joinUserRoom` by placing the socket in a room named
`user_<userId>`.  The existing Flutter code already calls
`joinUserRoom(patientId)`, so this should already be in place.

If the room name uses a different pattern, update the `io.to(...)` calls in
`vaccines.js` to match.

---

## Step 5 — Deploy to Render

Commit the new route file and your `app.js` changes, then push/deploy to
Render as normal.  The Aiven migration must be run **before** the new backend
code is live (Step 1 must precede Step 5).

---

## Step 6 — Test the Endpoints

After deployment, verify with curl or Postman.  Replace `<JWT>` and `<PID>`
with a real token and patient ID from your system.

```bash
# Dashboard summary
curl -H "Authorization: Bearer <JWT>" \
  https://healthtrack-vvbu.onrender.com/vaccines/dashboard/<PID>

# Full vaccine card
curl -H "Authorization: Bearer <JWT>" \
  https://healthtrack-vvbu.onrender.com/vaccines/card/<PID>

# Mark a dose as given (admin — schedule ID 1 = BCG)
curl -X POST \
  -H "Authorization: Bearer <JWT>" \
  -H "Content-Type: application/json" \
  -d '{"patient_id":<PID>,"vaccine_schedule_id":1,"given_by":"Dr. Available"}' \
  https://healthtrack-vvbu.onrender.com/vaccines/record
```

---

## New Endpoints Summary

| Method | Path | Description |
|--------|------|-------------|
| GET | `/vaccines/dashboard/:patientId` | Today counts + last completed + next due |
| GET | `/vaccines/card/:patientId` | Full dose-by-dose vaccine card |
| POST | `/vaccines/record` | Admin marks a dose as given |
| DELETE | `/vaccines/record/:recordId` | Admin un-marks a dose |

All four endpoints require the existing `authenticateToken` middleware.
