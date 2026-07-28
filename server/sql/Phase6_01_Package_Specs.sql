/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 6 — PL/SQL
   FILE 1 OF 4: PACKAGE SPECIFICATIONS

   Organization: one package per module (NFR8 — maintainability by module).
   Custom exceptions use RAISE_APPLICATION_ERROR codes in the -20000 to
   -20099 range, consistent across all packages so error codes never clash.
   Run this file, then Phase6_02 (bodies), then Phase6_03 (triggers),
   then Phase6_04 (standalone objects).
   ===================================================================== */

/* ---------------------------------------------------------------------
   PKG_AUDIT — tracks which application user is performing the current
   action, so triggers can attribute AUDIT_LOG / history rows correctly
   even though APEX/DB sessions are shared/pooled.
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_audit AS
    PROCEDURE set_current_user(p_user_id IN NUMBER);
    FUNCTION  get_current_user RETURN NUMBER;
    PROCEDURE log_change(
        p_table_name  IN VARCHAR2,
        p_operation   IN VARCHAR2,
        p_record_id   IN NUMBER,
        p_old_value   IN VARCHAR2 DEFAULT NULL,
        p_new_value   IN VARCHAR2 DEFAULT NULL
    );
END pkg_audit;
/

/* ---------------------------------------------------------------------
   PKG_RESIDENT — Module 1: Digital Resident Registry
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_resident AS

    e_household_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_household_not_found, -20010);
    e_invalid_resident_status EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_resident_status, -20011);

    FUNCTION register_resident(
        p_household_id  IN resident.household_id%TYPE,
        p_first_name    IN resident.first_name%TYPE,
        p_last_name     IN resident.last_name%TYPE,
        p_dob           IN resident.date_of_birth%TYPE,
        p_sex           IN resident.sex%TYPE,
        p_nin           IN resident.nin_number%TYPE DEFAULT NULL,
        p_phone         IN resident.phone_number%TYPE DEFAULT NULL
    ) RETURN resident.resident_id%TYPE;

    PROCEDURE change_status(
        p_resident_id     IN resident.resident_id%TYPE,
        p_new_status      IN resident.status%TYPE,
        p_new_household_id IN resident.household_id%TYPE DEFAULT NULL,
        p_changed_by_user IN NUMBER
    );

    FUNCTION get_age(p_resident_id IN resident.resident_id%TYPE) RETURN NUMBER;

    PROCEDURE generate_qr_code(p_resident_id IN resident.resident_id%TYPE);

    -- Returns a ref cursor so APEX Interactive Reports / any client can consume it directly
    PROCEDURE search_residents(
        p_search_term IN VARCHAR2,
        p_cursor      OUT SYS_REFCURSOR
    );

END pkg_resident;
/

/* ---------------------------------------------------------------------
   PKG_COURT — Module 2: LC Court Management
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_court AS

    TYPE t_id_list IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

    e_invalid_transition EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_transition, -20001);
    e_case_closed EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_case_closed, -20002);
    e_case_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_case_not_found, -20090);

    FUNCTION file_case(
        p_complainant_id IN resident.resident_id%TYPE,
        p_case_type      IN court_case.case_type%TYPE,
        p_village_id     IN village.village_id%TYPE,
        p_respondents    IN t_id_list
    ) RETURN court_case.case_id%TYPE;

    PROCEDURE schedule_hearing(
        p_case_id      IN court_case.case_id%TYPE,
        p_hearing_date IN hearing.hearing_date%TYPE,
        p_hearing_time IN hearing.hearing_time%TYPE,
        p_venue        IN hearing.venue%TYPE,
        p_leader_id    IN local_leader.leader_id%TYPE
    );

    PROCEDURE record_judgment(
        p_case_id           IN court_case.case_id%TYPE,
        p_judgment_text     IN CLOB,
        p_agreement_terms   IN CLOB DEFAULT NULL,
        p_debt_amount       IN NUMBER DEFAULT NULL,
        p_leader_id         IN local_leader.leader_id%TYPE
    );

    PROCEDURE update_case_status(
        p_case_id         IN court_case.case_id%TYPE,
        p_new_status      IN court_case.case_status%TYPE,
        p_changed_by_user IN NUMBER
    );

END pkg_court;
/

/* ---------------------------------------------------------------------
   PKG_INFRA — Module 3: Infrastructure Reporting
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_infra AS

    e_report_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_report_not_found, -20091);
    e_completion_requirements EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_completion_requirements, -20020);

    FUNCTION report_issue(
        p_resident_id IN resident.resident_id%TYPE,
        p_village_id  IN village.village_id%TYPE,
        p_category    IN infrastructure_report.category%TYPE,
        p_latitude    IN NUMBER DEFAULT NULL,
        p_longitude   IN NUMBER DEFAULT NULL,
        p_priority    IN infrastructure_report.priority%TYPE DEFAULT 'MEDIUM'
    ) RETURN infrastructure_report.report_id%TYPE;

    PROCEDURE assign_officer(
        p_report_id IN infrastructure_report.report_id%TYPE,
        p_user_id   IN app_user.user_id%TYPE
    );

    PROCEDURE add_progress_update(
        p_report_id  IN infrastructure_report.report_id%TYPE,
        p_text       IN VARCHAR2,
        p_new_status IN infrastructure_report.report_status%TYPE,
        p_user_id    IN app_user.user_id%TYPE
    );

    -- Enforces BR9: cannot complete without an assigned officer + completion photo
    PROCEDURE mark_completed(
        p_report_id IN infrastructure_report.report_id%TYPE,
        p_user_id   IN app_user.user_id%TYPE
    );

END pkg_infra;
/

/* ---------------------------------------------------------------------
   PKG_LETTER — Module 5: Letters & Certificates
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_letter AS

    e_fee_unpaid EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_fee_unpaid, -20030);
    e_request_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_request_not_found, -20092);

    FUNCTION request_letter(
        p_resident_id    IN resident.resident_id%TYPE,
        p_letter_type_id IN letter_type.letter_type_id%TYPE,
        p_purpose        IN VARCHAR2
    ) RETURN letter_request.request_id%TYPE;

    PROCEDURE approve_request(p_request_id IN letter_request.request_id%TYPE);

    -- Enforces BR7: fee must be PAID before issuance (unless fee amount is 0)
    FUNCTION issue_letter(
        p_request_id      IN letter_request.request_id%TYPE,
        p_issued_by_leader IN local_leader.leader_id%TYPE
    ) RETURN letter_issued.serial_number%TYPE;

    FUNCTION verify_letter(p_serial_number IN VARCHAR2) RETURN VARCHAR2;

END pkg_letter;
/

/* ---------------------------------------------------------------------
   PKG_PAYMENT — Module 6: Payments
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_payment AS

    e_unauthorized_role EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_unauthorized_role, -20040);
    e_already_reversed EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_already_reversed, -20041);

    -- Enforces BR10: only TREASURER or SUPER_ADMINISTRATOR may record/reverse payments
    FUNCTION record_payment(
        p_payment_type_id IN payment_type.payment_type_id%TYPE,
        p_payer_id        IN resident.resident_id%TYPE,
        p_amount          IN NUMBER,
        p_method          IN payment.payment_method%TYPE,
        p_recorded_by     IN app_user.user_id%TYPE,
        p_related_case_id IN court_case.case_id%TYPE DEFAULT NULL,
        p_related_request_id IN letter_request.request_id%TYPE DEFAULT NULL
    ) RETURN payment.payment_id%TYPE;

    -- Enforces BR8: no physical delete, only a reversal marker
    PROCEDURE reverse_payment(
        p_payment_id  IN payment.payment_id%TYPE,
        p_reversed_by IN app_user.user_id%TYPE
    );

    FUNCTION get_total_revenue(
        p_from_date IN DATE DEFAULT NULL,
        p_to_date   IN DATE DEFAULT NULL
    ) RETURN NUMBER;

END pkg_payment;
/

/* ---------------------------------------------------------------------
   PKG_ANNOUNCEMENT — Module 4: Community Notice Board
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_announcement AS

    FUNCTION post_announcement(
        p_title       IN announcement.title%TYPE,
        p_category    IN announcement.category%TYPE,
        p_body_text   IN CLOB,
        p_leader_id   IN local_leader.leader_id%TYPE,
        p_village_id  IN village.village_id%TYPE DEFAULT NULL,
        p_zone_id     IN zone.zone_id%TYPE DEFAULT NULL,
        p_parish_id   IN parish.parish_id%TYPE DEFAULT NULL,
        p_expiry_date IN DATE DEFAULT NULL
    ) RETURN announcement.announcement_id%TYPE;

    PROCEDURE acknowledge(
        p_announcement_id IN announcement.announcement_id%TYPE,
        p_resident_id     IN resident.resident_id%TYPE
    );

    FUNCTION get_ack_stats(p_announcement_id IN announcement.announcement_id%TYPE)
        RETURN VARCHAR2;

END pkg_announcement;
/

/* ---------------------------------------------------------------------
   PKG_NOTIFICATION — Module 8: Communication (simulated per Assumption A4)
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE pkg_notification AS

    PROCEDURE queue_notification(
        p_resident_id  IN resident.resident_id%TYPE,
        p_channel      IN notification_log.channel%TYPE,
        p_type         IN notification_log.notification_type%TYPE,
        p_entity_type  IN VARCHAR2 DEFAULT NULL,
        p_entity_id    IN NUMBER DEFAULT NULL
    );

    -- Demonstrates an explicit cursor FOR loop over hearings happening tomorrow
    PROCEDURE send_hearing_reminders;

    PROCEDURE mark_sent(p_notification_id IN notification_log.notification_id%TYPE);
    PROCEDURE mark_failed(p_notification_id IN notification_log.notification_id%TYPE);

END pkg_notification;
/
