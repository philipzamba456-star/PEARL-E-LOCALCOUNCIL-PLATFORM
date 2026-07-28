/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 11 — WEB APP ENABLEMENT (run AFTER Phase 5, 6 and 9 scripts)

   Your original design (Phase 5) never stored a password anywhere on
   purpose (Phase 7 assumed Oracle APEX's own account system would do
   authentication). Since this app is a standalone Node/Express + Oracle
   backend instead of APEX, APP_USER needs somewhere to keep a securely
   hashed password, and a couple of small conveniences for self-signup.

   Safe to re-run: every statement checks for existence first.
   ===================================================================== */

SET SERVEROUTPUT ON;

-- 1. Password hash column (bcrypt hash, never a plaintext password)
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM user_tab_columns
   WHERE table_name = 'APP_USER' AND column_name = 'PASSWORD_HASH';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE app_user ADD password_hash VARCHAR2(200)';
  END IF;
END;
/

-- 2. Full name convenience column for accounts that self-register without
--    an existing RESIDENT record (e.g. before they are attached to a
--    household by an admin).
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM user_tab_columns
   WHERE table_name = 'APP_USER' AND column_name = 'DISPLAY_NAME';
  IF v_count = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE app_user ADD display_name VARCHAR2(150)';
  END IF;
END;
/

-- 3. Make resident_id truly optional at the DB-constraint level for
--    self-signup accounts (it already allows NULL by default — this just
--    documents/confirms it; no change needed if the Phase 5 script ran
--    as-is).

-- 4. Ensure the RESIDENT and GUEST lookup roles exist (idempotent — the
--    Phase 5 seed script already inserts these, this just guards against
--    running this file on a schema that skipped seeding).
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM app_role WHERE role_name = 'RESIDENT';
  IF v_count = 0 THEN
    INSERT INTO app_role (role_name, description) VALUES ('RESIDENT', 'Registered resident, self-service access');
  END IF;

  SELECT COUNT(*) INTO v_count FROM app_role WHERE role_name = 'GUEST';
  IF v_count = 0 THEN
    INSERT INTO app_role (role_name, description) VALUES ('GUEST', 'Public read-only access');
  END IF;
  COMMIT;
END;
/

-- 5. Seed a default admin login so you can sign in immediately after
--    deploying (username: admin / password set via the app's
--    scripts/set-admin-password.js helper — see README). This only
--    inserts if an 'admin' app_user does not already exist.
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM app_user WHERE username = 'admin';
  IF v_count = 0 THEN
    INSERT INTO app_user (username, email, display_name, account_status)
    VALUES ('admin', 'admin@pearls.local', 'System Administrator', 'ACTIVE');
  END IF;
  COMMIT;
END;
/

COMMIT;
