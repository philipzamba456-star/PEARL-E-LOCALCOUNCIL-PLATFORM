# Pearls E-Local Council Platform — Live Web App

This turns your Phase 5/6/9 Oracle schema into a **real, working web application**:
every table in your design is a clickable feature in the sidebar — not a diagram.
Click a feature, see the live data, click **Add**, fill a form, and it's saved
straight into your Oracle database. People can also **create their own login
accounts** right from the app (self-signup, with the `RESIDENT` role).

It is a standard **Node.js + Express** backend talking to **Oracle** (via the
official `node-oracledb` driver, in THIN mode — no separate Oracle Instant
Client install needed) with a small, dependency-free HTML/JS frontend.

```
build/
├── server/                 ← Node.js backend (API + serves the frontend)
│   ├── sql/                ← your original schema scripts + one small addition
│   ├── scripts/            ← admin password helper
│   ├── src/
│   │   ├── metadata.js     ← *** every table/feature is defined here ***
│   │   ├── db.js           ← Oracle connection pool
│   │   ├── auth.js         ← JWT auth middleware
│   │   ├── server.js       ← Express app entry point
│   │   └── routes/         ← auth.js (signup/login) + api.js (generic CRUD)
│   ├── package.json
│   └── .env.example
└── public/                 ← frontend (no build step — just static files)
    ├── index.html
    ├── css/style.css
    └── js/app.js
```

---

## 1. Get an Oracle database to point it at

Pick **one**:

### Option A — Oracle Database XE, free, local (Docker — fastest to test with)
```bash
docker run -d --name oracle-xe -p 1521:1521 -e ORACLE_PASSWORD=YourSysPass123 gvenzl/oracle-xe:21-slim
# Wait ~1-2 minutes for it to finish initializing, then check:
docker logs -f oracle-xe   # look for "DATABASE IS READY TO USE!"
```
Default connect string will be `localhost:1521/XEPDB1`.

### Option B — Oracle Autonomous Database (Always Free) on Oracle Cloud
1. Create an **Always Free Autonomous Database** in your OCI account.
2. Download the **Wallet** (DB Connection → Download Wallet) — or, simpler with
   node-oracledb's THIN driver, just use the connection string shown under
   **DB Connection → Connection Strings** (e.g. `..._high`) with your DB's
   public/mTLS access enabled, or use **1-way TLS** connection strings which
   don't need a wallet file at all — copy that string into `ORACLE_CONNECT_STRING`.

### Option C — Your existing Oracle server (on-prem / another cloud)
Just get host, port, service name (or full connect string), and credentials
for the schema owner you ran Phases 5/6/9 against (e.g. `PEARLS_APP`).

**Create an application schema/user** if you haven't already (as SYSDBA / admin):
```sql
CREATE USER pearls_app IDENTIFIED BY "ChooseAStrongPassword1";
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SEQUENCE, CREATE TRIGGER, CREATE PROCEDURE TO pearls_app;
ALTER USER pearls_app QUOTA UNLIMITED ON USERS;
```

---

## 2. Run the SQL scripts, in order, connected as that schema owner

Using SQL*Plus, SQLcl, or SQL Developer:

```
sql pearls_app/YourPassword@localhost:1521/XEPDB1

@server/sql/Phase5_01_Sequences_and_Tables.sql
@server/sql/Phase5_02_Indexes.sql
@server/sql/Phase5_03_Views.sql
@server/sql/Phase5_04_Seed_Data.sql
@server/sql/Phase6_01_Package_Specs.sql
@server/sql/Phase6_02_Package_Bodies.sql
@server/sql/Phase6_03_Triggers.sql
@server/sql/Phase6_04_Standalone_Procs_Functions.sql
@server/sql/Phase9_01_Database_Security_v3.sql
@server/sql/Phase11_App_Enhancements.sql
```

`Phase11_App_Enhancements.sql` is the **one new file** — your original design
(correctly, per Phase 7's plan for Oracle APEX) never stored a password
anywhere. Since this app authenticates itself instead of relying on APEX
accounts, that script adds a `password_hash` column to `APP_USER` and a
`display_name` convenience column, and makes sure an `admin` account row and
the `RESIDENT`/`GUEST` roles exist. It's safe to re-run.

---

## 3. Configure and run the app

```bash
cd server
cp .env.example .env
# edit .env with your real ORACLE_USER / ORACLE_PASSWORD / connect info

npm install
npm run set-admin-password admin YourChosenAdminPassword123   # first login
npm start
```

Open **http://localhost:3000** — log in as `admin` / the password you just set.
Anyone else can click **Create Account** on that same screen to self-register
(they land in the `RESIDENT` role automatically).

---

## 4. What you get, out of the box

- **Every table from Phase 5 is a feature** in the sidebar, grouped exactly
  like the modules in your Phase 7 plan (People & Households, LC Court,
  Infrastructure Reports, Notice Board, Letters & Certificates, Payments,
  Administration, etc.) — click one, see a searchable, paginated list of the
  live rows, with **Add / Edit / Delete** if that data is meant to be
  user-entered.
- Foreign keys render as proper dropdowns (e.g. picking a Resident's
  Household shows real household addresses, not raw IDs).
- Tables that your own trigger design (Phase 6) populates automatically —
  `RESIDENT_STATUS_HISTORY`, `CASE_STATUS_HISTORY`, `AUDIT_LOG`,
  `ACTIVITY_LOG` — are shown **read-only**, matching Phase 7's spec ("Audit
  Log Viewer... read-only").
- **Self-service account creation**: anyone can sign up from the login
  screen; passwords are hashed with bcrypt and never stored in plain text.
  New accounts get the `RESIDENT` role. To promote someone to
  Secretary/Treasurer/Chairperson/Admin, an admin edits their row under
  **Administration → User ↔ Role Assignments**.
- Tables marked `adminOnly` in the metadata (Roles, User Accounts, User↔Role
  Assignments, System Settings, Audit/Activity Logs) are hidden from the
  sidebar and blocked at the API for anyone without the
  `SUPER_ADMINISTRATOR` or `LC3_ADMINISTRATOR` role — mirroring your Phase 7
  authorization scheme plan.
- A **Dashboard** landing page with live counts (active residents,
  households, revenue) and status breakdowns for cases, infrastructure
  reports, and letters — pulled straight from the data, same idea as your
  Phase 7 Analytics Dashboard (Module 7).

---

## 5. Extending it

Everything is driven by **one file**: `server/src/metadata.js`. To change what
shows up as a feature, add a field, rename a label, or mark something
read-only/admin-only, edit the object for that table there — the sidebar,
list view, and forms (including dropdowns for any new foreign keys) update
automatically. No other file needs to change for a new column or a new
table that follows the same pattern as the existing ones.

If you'd rather call your existing `PKG_RESIDENT`, `PKG_COURT`,
`PKG_LETTER`, `PKG_PAYMENT` etc. PL/SQL packages (Phase 6) instead of raw
`INSERT`/`UPDATE` for specific actions (e.g. so `pkg_resident.register_resident`
also auto-generates the QR code, or `pkg_letter.issue_letter` enforces the
fee-paid business rule), add a small dedicated route in
`server/src/routes/api.js` that calls
`conn.execute('BEGIN :out := pkg_resident.register_resident(...); END;', {...})`
for that specific action, and call it from a custom button in the frontend —
the generic CRUD engine stays as the fallback for everything else.

---

## 6. Security notes

- Passwords: bcrypt-hashed, 10 rounds, never logged or returned by the API.
- Sessions: JWT (12h expiry by default), sent as both an `Authorization:
  Bearer` header and an `httpOnly` cookie.
- **Change `JWT_SECRET` in `.env`** to a long random value before any real
  deployment.
- Run behind HTTPS (a reverse proxy like nginx/Caddy, or your cloud
  provider's load balancer) in production — cookies and bearer tokens are
  not encrypted in transit over plain HTTP.
- `adminOnly` tables are enforced **server-side** in `api.js`, not just
  hidden in the UI, so it isn't just security-by-obscurity.

---

## 7. Deploying so others can reach it (not just localhost)

Any Node host works since the app is just Express + a database connection:
a small VM (OCI free tier, DigitalOcean, etc.), Railway, Render, Fly.io, or
a container platform. The only two things it needs at runtime are:
1. Network access to your Oracle server/port (1521, or your Autonomous DB's
   TLS port) from wherever the app runs.
2. The environment variables from `.env` set on that host.

Point your domain at it, put it behind HTTPS, and it's a live multi-user
app — accounts, edits, and everything typed in are saved straight to your
Oracle server as they happen.
