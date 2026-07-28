/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 9 (SUPPLEMENT) — DATABASE SECURITY IMPLEMENTATION (v3)

   FIX IN THIS VERSION: instead of a hardcoded "PEARLS_APP" placeholder
   that must be manually replaced everywhere (easy to miss), this version
   uses a substitution variable &&schema_name. When you run this script,
   APEX SQL Scripts will prompt you ONCE for a value, and it is reused
   automatically for every reference below.

   BEFORE RUNNING, find out your real schema name by running this
   separately first:
       SELECT USER FROM DUAL;
   Whatever that returns, enter it exactly (same case) when prompted.

   STILL REQUIRES DBA-level privileges (ADMIN on Autonomous Database, or
   a DBA/SYSTEM account on XE) for the CREATE PROFILE / CREATE ROLE /
   CREATE AUDIT POLICY statements — a normal app schema user cannot run
   those regardless of how the schema name is supplied.
   ===================================================================== */

SET DEFINE ON;
SET SERVEROUTPUT ON;

-- ---------- 0. CONFIRM THE SCHEMA EXISTS BEFORE DOING ANYTHING ELSE ----------
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM all_users WHERE username = UPPER('&&schema_name');
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: no schema named &&schema_name found. Check spelling/case before continuing.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Schema &&schema_name confirmed to exist.');
    END IF;

    SELECT COUNT(*) INTO v_count FROM all_tables
     WHERE owner = UPPER('&&schema_name') AND table_name = 'RESIDENT';
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: table RESIDENT not found in schema &&schema_name. ' ||
                              'Did Phase5_01_Sequences_and_Tables.sql actually run successfully in THIS schema?');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Table &&schema_name..RESIDENT confirmed to exist — proceeding.');
    END IF;
END;
/

-- ---------- 1. PASSWORD POLICY (PROFILE) ----------
BEGIN
    EXECUTE IMMEDIATE '
        CREATE PROFILE pearls_profile LIMIT
            FAILED_LOGIN_ATTEMPTS   5
            PASSWORD_LOCK_TIME      1
            PASSWORD_LIFE_TIME      90
            PASSWORD_GRACE_TIME     7
            PASSWORD_REUSE_TIME     365
            PASSWORD_REUSE_MAX      5';
    DBMS_OUTPUT.PUT_LINE('Profile pearls_profile created.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -2379 THEN
            DBMS_OUTPUT.PUT_LINE('Profile pearls_profile already exists — skipped.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Could not create profile (likely a privileges issue): ' || SQLERRM);
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER PROFILE pearls_profile LIMIT PASSWORD_VERIFY_FUNCTION ora12c_verify_function';
    DBMS_OUTPUT.PUT_LINE('Password verify function attached.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Skipped password verify function (not available here): ' || SQLERRM);
END;
/

BEGIN
    EXECUTE IMMEDIATE 'ALTER USER &&schema_name PROFILE pearls_profile';
    DBMS_OUTPUT.PUT_LINE('Profile applied to &&schema_name.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not alter user profile: ' || SQLERRM);
END;
/

-- ---------- 2. DATABASE ROLES ----------
DECLARE
    PROCEDURE create_role_safe(p_role_name IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE 'CREATE ROLE ' || p_role_name;
        DBMS_OUTPUT.PUT_LINE('Role created: ' || p_role_name);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -1921 THEN
                DBMS_OUTPUT.PUT_LINE('Role already exists, skipped: ' || p_role_name);
            ELSE
                DBMS_OUTPUT.PUT_LINE('ERROR creating role ' || p_role_name || ' (privileges issue?): ' || SQLERRM);
            END IF;
    END;
BEGIN
    create_role_safe('role_pearls_readonly');
    create_role_safe('role_pearls_registry_writer');
    create_role_safe('role_pearls_finance_writer');
    create_role_safe('role_pearls_court_writer');
    create_role_safe('role_pearls_infra_writer');
    create_role_safe('role_pearls_admin');
END;
/

-- Confirm all 6 roles actually exist before attempting any grants
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM dba_roles WHERE role LIKE 'ROLE_PEARLS%';
    DBMS_OUTPUT.PUT_LINE(v_count || ' of 6 expected roles found. If this is less than 6, the GRANTs below will fail — check the privilege errors above first.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not query dba_roles (you may lack DBA view access): ' || SQLERRM);
END;
/

-- ---------- 3. GRANTS (each wrapped so one failure doesn't hide the rest) ----------
DECLARE
    PROCEDURE grant_safe(p_stmt IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_stmt;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('FAILED: ' || p_stmt || '  -->  ' || SQLERRM);
    END;
BEGIN
    -- Read-only role: SELECT on views
    grant_safe('GRANT SELECT ON &&schema_name..vw_resident_directory            TO role_pearls_readonly');
    grant_safe('GRANT SELECT ON &&schema_name..vw_active_announcements          TO role_pearls_readonly');
    grant_safe('GRANT SELECT ON &&schema_name..vw_case_summary                  TO role_pearls_readonly');
    grant_safe('GRANT SELECT ON &&schema_name..vw_payment_summary_by_type       TO role_pearls_readonly');
    grant_safe('GRANT SELECT ON &&schema_name..vw_infrastructure_report_status  TO role_pearls_readonly');
    grant_safe('GRANT SELECT ON &&schema_name..vw_population_by_village         TO role_pearls_readonly');
    grant_safe('GRANT SELECT ON &&schema_name..vw_letter_verification           TO role_pearls_readonly');

    -- Registry writer
    grant_safe('GRANT role_pearls_readonly TO role_pearls_registry_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..resident              TO role_pearls_registry_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..household             TO role_pearls_registry_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..emergency_contact     TO role_pearls_registry_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..resident_relationship TO role_pearls_registry_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..letter_request        TO role_pearls_registry_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..letter_issued         TO role_pearls_registry_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..announcement          TO role_pearls_registry_writer');
    grant_safe('GRANT EXECUTE ON &&schema_name..pkg_resident     TO role_pearls_registry_writer');
    grant_safe('GRANT EXECUTE ON &&schema_name..pkg_letter       TO role_pearls_registry_writer');
    grant_safe('GRANT EXECUTE ON &&schema_name..pkg_announcement TO role_pearls_registry_writer');

    -- Finance writer (BR10 defense-in-depth) — no DELETE grant on payment, ever
    grant_safe('GRANT role_pearls_readonly TO role_pearls_finance_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..payment TO role_pearls_finance_writer');
    grant_safe('GRANT SELECT, INSERT        ON &&schema_name..receipt  TO role_pearls_finance_writer');
    grant_safe('GRANT EXECUTE ON &&schema_name..pkg_payment TO role_pearls_finance_writer');

    -- Court writer
    grant_safe('GRANT role_pearls_readonly TO role_pearls_court_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..court_case       TO role_pearls_court_writer');
    grant_safe('GRANT SELECT, INSERT         ON &&schema_name..case_party       TO role_pearls_court_writer');
    grant_safe('GRANT SELECT, INSERT         ON &&schema_name..evidence         TO role_pearls_court_writer');
    grant_safe('GRANT SELECT, INSERT         ON &&schema_name..witness_statement TO role_pearls_court_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..hearing          TO role_pearls_court_writer');
    grant_safe('GRANT SELECT, INSERT         ON &&schema_name..mediation_note   TO role_pearls_court_writer');
    grant_safe('GRANT SELECT, INSERT         ON &&schema_name..case_judgment    TO role_pearls_court_writer');
    grant_safe('GRANT EXECUTE ON &&schema_name..pkg_court TO role_pearls_court_writer');

    -- Infrastructure writer
    grant_safe('GRANT role_pearls_readonly TO role_pearls_infra_writer');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..infrastructure_report TO role_pearls_infra_writer');
    grant_safe('GRANT SELECT, INSERT         ON &&schema_name..report_photo          TO role_pearls_infra_writer');
    grant_safe('GRANT SELECT, INSERT         ON &&schema_name..report_progress_update TO role_pearls_infra_writer');
    grant_safe('GRANT EXECUTE ON &&schema_name..pkg_infra TO role_pearls_infra_writer');

    -- Admin: everything
    grant_safe('GRANT role_pearls_registry_writer TO role_pearls_admin');
    grant_safe('GRANT role_pearls_finance_writer  TO role_pearls_admin');
    grant_safe('GRANT role_pearls_court_writer    TO role_pearls_admin');
    grant_safe('GRANT role_pearls_infra_writer    TO role_pearls_admin');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..app_user   TO role_pearls_admin');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..user_role  TO role_pearls_admin');
    grant_safe('GRANT SELECT ON &&schema_name..audit_log                  TO role_pearls_admin');
    grant_safe('GRANT SELECT ON &&schema_name..activity_log               TO role_pearls_admin');
    grant_safe('GRANT SELECT, INSERT, UPDATE ON &&schema_name..system_setting TO role_pearls_admin');

    DBMS_OUTPUT.PUT_LINE('Grant section complete — scroll up for any FAILED lines.');
END;
/

-- ---------- 4. UNIFIED AUDITING ----------
BEGIN
    EXECUTE IMMEDIATE '
        CREATE AUDIT POLICY pearls_sensitive_access
            ACTIONS SELECT ON &&schema_name..payment,
                    SELECT ON &&schema_name..app_user,
                    SELECT ON &&schema_name..letter_issued,
                    INSERT ON &&schema_name..payment,
                    UPDATE ON &&schema_name..payment,
                    DELETE ON &&schema_name..payment';
    DBMS_OUTPUT.PUT_LINE('Audit policy created.');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -46358 THEN
            DBMS_OUTPUT.PUT_LINE('Audit policy already exists — skipped.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Could not create audit policy (Unified Auditing may be unavailable): ' || SQLERRM);
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'AUDIT POLICY pearls_sensitive_access';
    DBMS_OUTPUT.PUT_LINE('Audit policy enabled.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not enable audit policy: ' || SQLERRM);
END;
/

-- Review captured events later with:
-- SELECT event_timestamp, dbusername, action_name, object_name
--   FROM unified_audit_trail
--  WHERE object_name IN ('PAYMENT','APP_USER','LETTER_ISSUED')
--  ORDER BY event_timestamp DESC;

COMMIT;
