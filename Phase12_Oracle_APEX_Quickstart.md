# PHASE 12: RUNNING THIS ON ORACLE APEX — QUICKSTART

This is the practical "click this, then this" guide for actually building the
app in Oracle APEX, using your Phase 5/6/9 schema. It has two paths:

- **Path A (fast, ~30 min):** auto-generated CRUD pages for every table — gets
  you clicking around and entering data today.
- **Path B (your Phase 7 spec):** the fully custom, business-rule-aware build
  (dashboards, PL/SQL-package-driven forms, role-based buttons) — do this
  once Path A confirms everything's wired up correctly.

You can do Path A first, then upgrade individual pages toward Path B over
time — they use the same schema, so nothing is wasted.

---

## 0. Get an APEX environment (pick one)

| Option | Cost | Good for |
|---|---|---|
| **apex.oracle.com** free workspace | Free | Fastest to start, shared/limited DB, fine for building & testing |
| **Oracle Cloud Always Free Autonomous Database** | Free | Full control, your own DB, APEX pre-installed, production-capable |
| Your own Oracle DB + APEX install | Depends | If you already run Oracle on-prem/cloud |

For Always Free Autonomous DB: OCI Console → Autonomous Database → Create →
choose "Always Free" → once provisioned, click **Database Actions → APEX**
to open App Builder directly. No separate install step.

---

## 1. Load the schema

In **SQL Workshop → SQL Scripts** (or SQL Commands for smaller ones), run, **in order**,
against the schema/workspace you'll build the app in:

```
Phase5_01_Sequences_and_Tables.sql
Phase5_02_Indexes.sql
Phase5_03_Views.sql
Phase5_04_Seed_Data.sql
Phase6_01_Package_Specs.sql
Phase6_02_Package_Bodies.sql
Phase6_03_Triggers.sql
Phase6_04_Standalone_Procs_Functions.sql
Phase9_01_Database_Security_v3.sql
```

Skip `Phase11_App_Enhancements.sql` — that one's specific to the Node.js app's
password login and isn't needed here (APEX manages its own accounts). No harm
leaving it out or running it; it's independent of everything else.

---

## PATH A — Fast: auto-generated CRUD for every table

1. **App Builder → Create → New Application**
2. Name it `Pearls E-Local Council Platform`, Theme = Universal Theme, Navigation = Side Menu → **Create Application** (start with zero pages, or add your first one right in this wizard).
3. Now repeat this for each table you want as a feature (start with the ones people will use daily — Resident, Household, Court Case, Infrastructure Report, Announcement, Letter Request, Payment — then go back for the rest):
   - **App Builder → your app → Create Page (the green + button)**
   - Choose **Report and Form**
   - Data Source → **Existing Table** → pick the table (e.g. `RESIDENT`)
   - APEX auto-detects the primary key and foreign keys, and **automatically
     turns foreign key columns into select-list lookups** (e.g. Resident's
     `HOUSEHOLD_ID` becomes a dropdown of real households) — the same thing
     the Node app's metadata engine does, APEX just does it natively.
   - Click **Create Page** — you now have a live, clickable list + add/edit
     form for that table, in about 15 seconds.
4. Repeat step 3 for the rest of the 38 tables. It's mechanical but fast —
   budget about 10–15 minutes for all of them.
5. **Shared Components → Navigation → Navigation Menu**: drag the generated
   pages into groups so they read like features, not a table list. Use the
   same grouping your schema already implies (this matches Phase 7 §4 and
   the Node app's sidebar):
   - Geography (Parish, Zone, Village)
   - People & Households (Household, Resident, Business, relationships)
   - Leadership & Accounts (Leader Position, Local Leader, App User, App
     Role, User Role)
   - LC Court (Court Case, Hearing, Evidence, Witness Statement, Judgment)
   - Infrastructure Reports
   - Notice Board (Announcement)
   - Letters & Certificates
   - Payments
   - Administration (User Accounts, Roles, Audit Log, Activity Log, System
     Settings — restrict these, see §3 below)
6. Click **Run Application** (the ▶ icon). That's it — you have a live,
   multi-user, Oracle-backed app you can log into and use today.

For the four tables that should be **read-only** (`RESIDENT_STATUS_HISTORY`,
`CASE_STATUS_HISTORY`, `AUDIT_LOG`, `ACTIVITY_LOG` — your triggers populate
these automatically per Phase 6), generate a **Report only** page (not
Report and Form) so there's no accidental manual insert/edit path.

---

## 2. Authentication — get logins working

**Quickest option (to get moving today):** use APEX's built-in
**Application Express Accounts** authentication scheme (it's the default —
you don't have to do anything). Create accounts for your staff under
**Administration → Manage Users**. Good enough to fully test Path A.

**The integrated option (matches Phase 7 §3, ties logins to APP_USER):**
1. Shared Components → Authentication Schemes → Create → based on APEX
   Accounts, but add this **Post-Authentication Procedure**:
   ```sql
   BEGIN
       SELECT user_id INTO :APP_CURRENT_USER_ID
         FROM app_user WHERE username = :APP_USER;
       INSERT INTO activity_log (user_id, activity_type, ip_address)
       VALUES (:APP_CURRENT_USER_ID, 'LOGIN', OWA_UTIL.get_cgi_env('REMOTE_ADDR'));
       COMMIT;
   END;
   ```
2. This sets an application-level item `APP_CURRENT_USER_ID` you can use in
   every page's SQL/PL/SQL to filter "my data" and log activity — exactly
   as your Phase 7 doc specifies.

**Self-service resident signup (matches the "anyone can create their own
account" requirement):** APEX doesn't have this out of the box the way a
custom app does, so build one small **public page** (Page Access: "Public -
No Authentication Required"):
- Items: Username, Email, Display Name, Password (masked)
- A "Create Account" button with a page process (PL/SQL):
  ```sql
  DECLARE
    v_hash   VARCHAR2(200);
    v_uid    NUMBER;
    v_rid    NUMBER;
  BEGIN
    v_hash := STANDARD_HASH(:P_PASSWORD || :P_USERNAME, 'SHA256'); -- see note below
    INSERT INTO app_user (username, email, display_name, password_hash, account_status)
    VALUES (:P_USERNAME, :P_EMAIL, :P_DISPLAY_NAME, v_hash, 'ACTIVE')
    RETURNING user_id INTO v_uid;

    SELECT role_id INTO v_rid FROM app_role WHERE role_name = 'RESIDENT';
    INSERT INTO user_role (user_id, role_id) VALUES (v_uid, v_rid);
    COMMIT;
  END;
  ```
  > Note: `STANDARD_HASH` is a plain SHA-256, fine for a student/demo
  > project but weaker than the bcrypt hashing the Node app uses. For
  > anything beyond a class project, either keep authentication purely in
  > APEX Accounts (simplest — sidesteps storing passwords in your own table
  > at all) or call out to a proper hashing routine.

---

## 3. Authorization — restrict Administration pages

Shared Components → Authorization Schemes → Create one per role check, e.g.:

```sql
-- "Is Administrator"
SELECT COUNT(*) FROM user_role ur JOIN app_role ar ON ar.role_id = ur.role_id
 WHERE ur.user_id = :APP_CURRENT_USER_ID
   AND ar.role_name IN ('SUPER_ADMINISTRATOR','LC3_ADMINISTRATOR')
```

Attach this scheme to the User Accounts, Roles, Audit Log, Activity Log, and
System Settings pages (Page → Security → Authorization Scheme), and to their
menu entries (so non-admins don't even see the links) — this is the exact
same rule the Node app enforces server-side, just expressed as an APEX
Authorization Scheme instead.

---

## 4. Upgrading toward Path B (your full Phase 7 spec)

Once Path A is working end-to-end, you can replace individual auto-generated
pages with the richer versions described in `Phase7_APEX_Build_Specification.md`
— e.g. swap the plain Court Case form for one that calls
`pkg_court.file_case`, add the Dashboard charts against
`vw_population_by_village` / `vw_case_summary`, wire the "Issue Letter"
button to `pkg_letter.issue_letter` so its business-rule errors
(`RAISE_APPLICATION_ERROR`) surface inline. That document is already a
correct, page-by-page spec for your exact schema — follow it section by
section (§5.1 through §5.9) at your own pace.

---

## 5. Running both the Node app and APEX against the same database

Nothing stops you from doing this — they're just two different front ends
on the same Oracle schema. A common pattern: staff use the polished APEX
app internally, while the Node app (or a future public site) is what
residents use to self-register and submit things. Just be mindful that
`Phase11_App_Enhancements.sql`'s bcrypt-hashed `password_hash` values are
specific to the Node app's login check — if a resident signs up through
APEX using the `STANDARD_HASH` approach above instead, that account won't
be able to log into the Node app (and vice versa) unless you standardize on
one hashing method across both.
