/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 6 — PL/SQL
   FILE 4 OF 4: STANDALONE FUNCTIONS & PROCEDURES

   Most business logic lives inside packages (NFR8), but a few
   general-purpose, cross-module utilities are implemented as standalone
   schema-level objects, callable directly from SQL (e.g., in APEX
   Interactive Report column expressions) without a package prefix.
   ===================================================================== */

-- Standalone FUNCTION: full display name for any resident, usable directly in SQL
CREATE OR REPLACE FUNCTION fn_get_resident_full_name(p_resident_id IN NUMBER)
RETURN VARCHAR2
IS
    v_name VARCHAR2(150);
BEGIN
    SELECT first_name || ' ' || last_name INTO v_name
      FROM resident WHERE resident_id = p_resident_id;
    RETURN v_name;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END fn_get_resident_full_name;
/

-- Standalone FUNCTION: resolves a resident's full geographic path, e.g.
-- "Kanyanya Village, Kawempe Zone, Ttula Parish" — handy for letter headers
CREATE OR REPLACE FUNCTION fn_get_resident_location(p_resident_id IN NUMBER)
RETURN VARCHAR2
IS
    v_location VARCHAR2(300);
BEGIN
    SELECT village_name || ' Village, ' || zone_name || ' Zone, ' || parish_name || ' Parish'
      INTO v_location
      FROM vw_resident_directory
     WHERE resident_id = p_resident_id;
    RETURN v_location;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END fn_get_resident_location;
/

-- Standalone PROCEDURE: monthly summary report across the whole system,
-- used by the Analytics Dashboard and by administrators for a quick health check.
CREATE OR REPLACE PROCEDURE prc_generate_monthly_summary(
    p_year        IN NUMBER,
    p_month       IN NUMBER,
    p_new_residents  OUT NUMBER,
    p_new_cases      OUT NUMBER,
    p_cases_resolved OUT NUMBER,
    p_new_reports    OUT NUMBER,
    p_reports_completed OUT NUMBER,
    p_total_revenue  OUT NUMBER
)
IS
    v_from DATE := TO_DATE(p_year || '-' || LPAD(p_month,2,'0') || '-01', 'YYYY-MM-DD');
    v_to   DATE := ADD_MONTHS(v_from, 1);
BEGIN
    SELECT COUNT(*) INTO p_new_residents
      FROM resident WHERE date_registered >= v_from AND date_registered < v_to;

    SELECT COUNT(*) INTO p_new_cases
      FROM court_case WHERE date_filed >= v_from AND date_filed < v_to;

    SELECT COUNT(*) INTO p_cases_resolved
      FROM case_status_history
     WHERE new_status IN ('RESOLVED','CLOSED') AND change_date >= v_from AND change_date < v_to;

    SELECT COUNT(*) INTO p_new_reports
      FROM infrastructure_report WHERE date_reported >= v_from AND date_reported < v_to;

    SELECT COUNT(*) INTO p_reports_completed
      FROM report_progress_update
     WHERE new_status = 'COMPLETED' AND update_date >= v_from AND update_date < v_to;

    p_total_revenue := pkg_payment.get_total_revenue(v_from, v_to - 1/86400);
END prc_generate_monthly_summary;
/

-- Standalone PROCEDURE: simple maintenance utility to purge old ACTIVITY_LOG
-- rows beyond a retention window, runnable manually or via an Oracle Scheduler job
CREATE OR REPLACE PROCEDURE prc_purge_old_activity_logs(p_retention_days IN NUMBER DEFAULT 365)
IS
    v_deleted NUMBER;
BEGIN
    DELETE FROM activity_log
     WHERE activity_timestamp < SYSTIMESTAMP - p_retention_days;
    v_deleted := SQL%ROWCOUNT;
    DBMS_OUTPUT.PUT_LINE(v_deleted || ' activity_log rows older than ' || p_retention_days || ' days purged.');
    COMMIT;
END prc_purge_old_activity_logs;
/
