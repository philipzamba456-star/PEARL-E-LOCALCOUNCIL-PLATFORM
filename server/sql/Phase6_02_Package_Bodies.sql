/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 6 — PL/SQL
   FILE 2 OF 4: PACKAGE BODIES

   Run AFTER Phase6_01_Package_Specs.sql.
   ===================================================================== */

/* ---------------------------------------------------------------------
   PKG_AUDIT BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_audit AS

    g_current_user_id NUMBER;

    PROCEDURE set_current_user(p_user_id IN NUMBER) IS
    BEGIN
        g_current_user_id := p_user_id;
    END set_current_user;

    FUNCTION get_current_user RETURN NUMBER IS
    BEGIN
        RETURN g_current_user_id;
    END get_current_user;

    PROCEDURE log_change(
        p_table_name  IN VARCHAR2,
        p_operation   IN VARCHAR2,
        p_record_id   IN NUMBER,
        p_old_value   IN VARCHAR2 DEFAULT NULL,
        p_new_value   IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION; -- audit row must survive even if caller later rolls back
    BEGIN
        INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id,
                                old_value_summary, new_value_summary)
        VALUES (p_table_name, p_operation, p_record_id, g_current_user_id,
                p_old_value, p_new_value);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Auditing must never block the main transaction; log and swallow.
            NULL;
    END log_change;

END pkg_audit;
/

/* ---------------------------------------------------------------------
   PKG_RESIDENT BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_resident AS

    FUNCTION register_resident(
        p_household_id  IN resident.household_id%TYPE,
        p_first_name    IN resident.first_name%TYPE,
        p_last_name     IN resident.last_name%TYPE,
        p_dob           IN resident.date_of_birth%TYPE,
        p_sex           IN resident.sex%TYPE,
        p_nin           IN resident.nin_number%TYPE DEFAULT NULL,
        p_phone         IN resident.phone_number%TYPE DEFAULT NULL
    ) RETURN resident.resident_id%TYPE
    IS
        v_resident_id resident.resident_id%TYPE;
        v_dummy        household.household_id%TYPE;
    BEGIN
        -- Validate the household exists (gives a clean custom error instead of ORA-02291)
        SELECT household_id INTO v_dummy FROM household WHERE household_id = p_household_id;

        INSERT INTO resident (household_id, first_name, last_name, date_of_birth, sex, nin_number, phone_number)
        VALUES (p_household_id, p_first_name, p_last_name, p_dob, p_sex, p_nin, p_phone)
        RETURNING resident_id INTO v_resident_id;

        generate_qr_code(v_resident_id);

        RETURN v_resident_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'Household ID ' || p_household_id || ' does not exist.');
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20012, 'A resident with NIN ' || p_nin || ' is already registered.');
    END register_resident;

    PROCEDURE change_status(
        p_resident_id      IN resident.resident_id%TYPE,
        p_new_status       IN resident.status%TYPE,
        p_new_household_id IN resident.household_id%TYPE DEFAULT NULL,
        p_changed_by_user  IN NUMBER
    ) IS
        v_valid_statuses SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('ACTIVE','MOVED_OUT','DECEASED','DEREGISTERED');
        v_is_valid       BOOLEAN := FALSE;
    BEGIN
        FOR i IN 1 .. v_valid_statuses.COUNT LOOP
            IF v_valid_statuses(i) = p_new_status THEN
                v_is_valid := TRUE;
            END IF;
        END LOOP;

        IF NOT v_is_valid THEN
            RAISE e_invalid_resident_status;
        END IF;

        pkg_audit.set_current_user(p_changed_by_user);

        -- The AFTER UPDATE trigger TRG_RESIDENT_AU compares :OLD/:NEW and writes
        -- RESIDENT_STATUS_HISTORY automatically (see Phase6_03_Triggers.sql).
        IF p_new_household_id IS NOT NULL THEN
            UPDATE resident
               SET status = p_new_status, household_id = p_new_household_id
             WHERE resident_id = p_resident_id;
        ELSE
            UPDATE resident
               SET status = p_new_status
             WHERE resident_id = p_resident_id;
        END IF;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Resident ID ' || p_resident_id || ' not found.');
        END IF;
    EXCEPTION
        WHEN e_invalid_resident_status THEN
            RAISE_APPLICATION_ERROR(-20011, 'Invalid resident status: ' || p_new_status);
    END change_status;

    FUNCTION get_age(p_resident_id IN resident.resident_id%TYPE) RETURN NUMBER IS
        v_dob resident.date_of_birth%TYPE;
    BEGIN
        SELECT date_of_birth INTO v_dob FROM resident WHERE resident_id = p_resident_id;
        RETURN TRUNC(MONTHS_BETWEEN(SYSDATE, v_dob) / 12);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_age;

    PROCEDURE generate_qr_code(p_resident_id IN resident.resident_id%TYPE) IS
        v_qr VARCHAR2(400);
    BEGIN
        -- QR payload is a stable, verifiable reference string; the actual QR
        -- image is rendered by the APEX page from this text (BR12: immutable once set).
        v_qr := 'PEARLS-RESIDENT-' || TO_CHAR(p_resident_id) || '-' ||
                TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');

        UPDATE resident
           SET qr_code_ref = v_qr
         WHERE resident_id = p_resident_id
           AND qr_code_ref IS NULL; -- never overwrite an existing code (BR12)
    END generate_qr_code;

    PROCEDURE search_residents(
        p_search_term IN VARCHAR2,
        p_cursor      OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT resident_id, first_name, last_name, nin_number, phone_number,
                   status, village_name, zone_name, parish_name
            FROM   vw_resident_directory
            WHERE  UPPER(full_name)  LIKE '%' || UPPER(p_search_term) || '%'
               OR  UPPER(nin_number) LIKE '%' || UPPER(p_search_term) || '%'
               OR  phone_number      LIKE '%' || p_search_term || '%'
               OR  UPPER(village_name) LIKE '%' || UPPER(p_search_term) || '%'
            ORDER BY full_name;
    END search_residents;

END pkg_resident;
/

/* ---------------------------------------------------------------------
   PKG_COURT BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_court AS

    FUNCTION file_case(
        p_complainant_id IN resident.resident_id%TYPE,
        p_case_type      IN court_case.case_type%TYPE,
        p_village_id     IN village.village_id%TYPE,
        p_respondents    IN t_id_list
    ) RETURN court_case.case_id%TYPE
    IS
        v_case_id  court_case.case_id%TYPE;
        v_ref_no   court_case.case_reference_no%TYPE;
        idx        PLS_INTEGER;
    BEGIN
        v_ref_no := 'CASE-' || TO_CHAR(SYSDATE, 'YYYY') || '-' ||
                    LPAD(TO_CHAR(seq_case_ref_no.NEXTVAL), 6, '0');

        INSERT INTO court_case (case_reference_no, complainant_resident_id, case_type, filed_at_village_id)
        VALUES (v_ref_no, p_complainant_id, p_case_type, p_village_id)
        RETURNING case_id INTO v_case_id;

        INSERT INTO case_party (case_id, resident_id, party_role)
        VALUES (v_case_id, p_complainant_id, 'COMPLAINANT');

        -- Explicit collection loop over the respondent list (associative array)
        idx := p_respondents.FIRST;
        WHILE idx IS NOT NULL LOOP
            INSERT INTO case_party (case_id, resident_id, party_role)
            VALUES (v_case_id, p_respondents(idx), 'RESPONDENT');
            idx := p_respondents.NEXT(idx);
        END LOOP;

        RETURN v_case_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20099, 'Error filing case: ' || SQLERRM);
    END file_case;

    PROCEDURE schedule_hearing(
        p_case_id      IN court_case.case_id%TYPE,
        p_hearing_date IN hearing.hearing_date%TYPE,
        p_hearing_time IN hearing.hearing_time%TYPE,
        p_venue        IN hearing.venue%TYPE,
        p_leader_id    IN local_leader.leader_id%TYPE
    ) IS
        v_status court_case.case_status%TYPE;
    BEGIN
        SELECT case_status INTO v_status
          FROM court_case
         WHERE case_id = p_case_id
         FOR UPDATE; -- lock the case row for the duration of this business transaction

        IF v_status IN ('CLOSED', 'RESOLVED', 'REJECTED') THEN
            RAISE e_case_closed;
        END IF;

        INSERT INTO hearing (case_id, hearing_date, hearing_time, venue, presiding_leader_id)
        VALUES (p_case_id, p_hearing_date, p_hearing_time, p_venue, p_leader_id);

        IF v_status IN ('PENDING', 'UNDER_REVIEW') THEN
            update_case_status(p_case_id, 'SCHEDULED', pkg_audit.get_current_user);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20090, 'Case ID ' || p_case_id || ' not found.');
        WHEN e_case_closed THEN
            RAISE_APPLICATION_ERROR(-20002, 'Cannot schedule a hearing: case ' || p_case_id ||
                                             ' is already ' || v_status || '.');
    END schedule_hearing;

    PROCEDURE record_judgment(
        p_case_id           IN court_case.case_id%TYPE,
        p_judgment_text     IN CLOB,
        p_agreement_terms   IN CLOB DEFAULT NULL,
        p_debt_amount       IN NUMBER DEFAULT NULL,
        p_leader_id         IN local_leader.leader_id%TYPE
    ) IS
    BEGIN
        INSERT INTO case_judgment (case_id, judgment_text, agreement_terms, debt_amount, recorded_by_leader_id)
        VALUES (p_case_id, p_judgment_text, p_agreement_terms, p_debt_amount, p_leader_id);

        update_case_status(p_case_id, 'RESOLVED', pkg_audit.get_current_user);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20021, 'Case ' || p_case_id || ' already has a recorded judgment.');
    END record_judgment;

    PROCEDURE update_case_status(
        p_case_id         IN court_case.case_id%TYPE,
        p_new_status      IN court_case.case_status%TYPE,
        p_changed_by_user IN NUMBER
    ) IS
        v_current court_case.case_status%TYPE;
        v_ok      BOOLEAN := FALSE;
    BEGIN
        SELECT case_status INTO v_current FROM court_case WHERE case_id = p_case_id;

        -- BR4: forward-only transition matrix
        IF    v_current = 'PENDING'       AND p_new_status IN ('UNDER_REVIEW','SCHEDULED','REJECTED') THEN v_ok := TRUE;
        ELSIF v_current = 'UNDER_REVIEW'  AND p_new_status IN ('SCHEDULED','REJECTED')                  THEN v_ok := TRUE;
        ELSIF v_current = 'SCHEDULED'     AND p_new_status IN ('RESOLVED','CLOSED','REJECTED')          THEN v_ok := TRUE;
        ELSIF v_current = 'RESOLVED'      AND p_new_status = 'CLOSED'                                   THEN v_ok := TRUE;
        END IF;

        IF NOT v_ok THEN
            RAISE e_invalid_transition;
        END IF;

        pkg_audit.set_current_user(p_changed_by_user);

        -- TRG_COURT_CASE_AU writes CASE_STATUS_HISTORY automatically from :OLD/:NEW
        UPDATE court_case SET case_status = p_new_status WHERE case_id = p_case_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20090, 'Case ID ' || p_case_id || ' not found.');
        WHEN e_invalid_transition THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid case status transition from ' ||
                                             v_current || ' to ' || p_new_status || '.');
    END update_case_status;

END pkg_court;
/

/* ---------------------------------------------------------------------
   PKG_INFRA BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_infra AS

    FUNCTION report_issue(
        p_resident_id IN resident.resident_id%TYPE,
        p_village_id  IN village.village_id%TYPE,
        p_category    IN infrastructure_report.category%TYPE,
        p_latitude    IN NUMBER DEFAULT NULL,
        p_longitude   IN NUMBER DEFAULT NULL,
        p_priority    IN infrastructure_report.priority%TYPE DEFAULT 'MEDIUM'
    ) RETURN infrastructure_report.report_id%TYPE
    IS
        v_report_id infrastructure_report.report_id%TYPE;
    BEGIN
        INSERT INTO infrastructure_report
            (reported_by_resident_id, village_id, category, gps_latitude, gps_longitude, priority)
        VALUES
            (p_resident_id, p_village_id, p_category, p_latitude, p_longitude, p_priority)
        RETURNING report_id INTO v_report_id;

        RETURN v_report_id;
    END report_issue;

    PROCEDURE assign_officer(
        p_report_id IN infrastructure_report.report_id%TYPE,
        p_user_id   IN app_user.user_id%TYPE
    ) IS
    BEGIN
        UPDATE infrastructure_report
           SET assigned_officer_user_id = p_user_id,
               report_status = 'ASSIGNED'
         WHERE report_id = p_report_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE e_report_not_found;
        END IF;
    EXCEPTION
        WHEN e_report_not_found THEN
            RAISE_APPLICATION_ERROR(-20091, 'Report ID ' || p_report_id || ' not found.');
    END assign_officer;

    PROCEDURE add_progress_update(
        p_report_id  IN infrastructure_report.report_id%TYPE,
        p_text       IN VARCHAR2,
        p_new_status IN infrastructure_report.report_status%TYPE,
        p_user_id    IN app_user.user_id%TYPE
    ) IS
    BEGIN
        INSERT INTO report_progress_update (report_id, update_text, new_status, updated_by_user_id)
        VALUES (p_report_id, p_text, p_new_status, p_user_id);

        UPDATE infrastructure_report
           SET report_status = p_new_status
         WHERE report_id = p_report_id;
    END add_progress_update;

    PROCEDURE mark_completed(
        p_report_id IN infrastructure_report.report_id%TYPE,
        p_user_id   IN app_user.user_id%TYPE
    ) IS
        v_officer      infrastructure_report.assigned_officer_user_id%TYPE;
        v_photo_count  NUMBER;
    BEGIN
        SELECT assigned_officer_user_id INTO v_officer
          FROM infrastructure_report WHERE report_id = p_report_id;

        SELECT COUNT(*) INTO v_photo_count
          FROM report_photo
         WHERE report_id = p_report_id AND photo_type = 'COMPLETION';

        -- BR9: cannot complete without an assigned officer AND a completion photo
        IF v_officer IS NULL OR v_photo_count = 0 THEN
            RAISE e_completion_requirements;
        END IF;

        UPDATE infrastructure_report
           SET report_status = 'COMPLETED'
         WHERE report_id = p_report_id;

        INSERT INTO report_progress_update (report_id, update_text, new_status, updated_by_user_id)
        VALUES (p_report_id, 'Marked as completed.', 'COMPLETED', p_user_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20091, 'Report ID ' || p_report_id || ' not found.');
        WHEN e_completion_requirements THEN
            RAISE_APPLICATION_ERROR(-20020,
                'Report ' || p_report_id || ' needs an assigned officer AND at least one completion photo before it can be marked Completed.');
    END mark_completed;

END pkg_infra;
/

/* ---------------------------------------------------------------------
   PKG_LETTER BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_letter AS

    FUNCTION request_letter(
        p_resident_id    IN resident.resident_id%TYPE,
        p_letter_type_id IN letter_type.letter_type_id%TYPE,
        p_purpose        IN VARCHAR2
    ) RETURN letter_request.request_id%TYPE
    IS
        v_request_id letter_request.request_id%TYPE;
    BEGIN
        INSERT INTO letter_request (resident_id, letter_type_id, purpose)
        VALUES (p_resident_id, p_letter_type_id, p_purpose)
        RETURNING request_id INTO v_request_id;

        RETURN v_request_id;
    END request_letter;

    PROCEDURE approve_request(p_request_id IN letter_request.request_id%TYPE) IS
    BEGIN
        UPDATE letter_request SET request_status = 'APPROVED' WHERE request_id = p_request_id;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE e_request_not_found;
        END IF;
    EXCEPTION
        WHEN e_request_not_found THEN
            RAISE_APPLICATION_ERROR(-20092, 'Letter request ' || p_request_id || ' not found.');
    END approve_request;

    FUNCTION issue_letter(
        p_request_id       IN letter_request.request_id%TYPE,
        p_issued_by_leader IN local_leader.leader_id%TYPE
    ) RETURN letter_issued.serial_number%TYPE
    IS
        v_fee_amount    letter_type.default_fee_amount%TYPE;
        v_paid_count    NUMBER;
        v_serial        letter_issued.serial_number%TYPE;
        v_letter_id     letter_issued.letter_id%TYPE;
    BEGIN
        SELECT lt.default_fee_amount
          INTO v_fee_amount
          FROM letter_request lr
          JOIN letter_type lt ON lt.letter_type_id = lr.letter_type_id
         WHERE lr.request_id = p_request_id;

        IF v_fee_amount > 0 THEN
            SELECT COUNT(*) INTO v_paid_count
              FROM payment
             WHERE related_letter_request_id = p_request_id
               AND payment_status = 'PAID';

            -- BR7: fee must be settled before issuance (unless the letter type is free)
            IF v_paid_count = 0 THEN
                RAISE e_fee_unpaid;
            END IF;
        END IF;

        v_serial := 'LTR-' || TO_CHAR(SYSDATE, 'YYYY') || '-' ||
                    LPAD(TO_CHAR(seq_letter_serial.NEXTVAL), 6, '0');

        INSERT INTO letter_issued (request_id, serial_number, qr_code_ref, issued_by_leader_id)
        VALUES (p_request_id, v_serial, 'VERIFY-' || v_serial, p_issued_by_leader)
        RETURNING letter_id INTO v_letter_id;

        UPDATE letter_request SET request_status = 'ISSUED' WHERE request_id = p_request_id;

        RETURN v_serial;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20092, 'Letter request ' || p_request_id || ' not found.');
        WHEN e_fee_unpaid THEN
            RAISE_APPLICATION_ERROR(-20030,
                'Letter request ' || p_request_id || ' cannot be issued: the letter fee has not been paid.');
    END issue_letter;

    FUNCTION verify_letter(p_serial_number IN VARCHAR2) RETURN VARCHAR2 IS
        v_result VARCHAR2(500);
    BEGIN
        SELECT 'VALID: ' || letter_type_name || ' issued to ' || issued_to ||
               ' on ' || TO_CHAR(date_issued, 'DD-MON-YYYY')
          INTO v_result
          FROM vw_letter_verification
         WHERE serial_number = p_serial_number;

        RETURN v_result;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'INVALID: No letter found with serial number ' || p_serial_number || '.';
    END verify_letter;

END pkg_letter;
/

/* ---------------------------------------------------------------------
   PKG_PAYMENT BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_payment AS

    -- Internal helper: confirms the user holds TREASURER or SUPER_ADMINISTRATOR role (BR10)
    FUNCTION is_authorized(p_user_id IN app_user.user_id%TYPE) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
          FROM user_role ur
          JOIN app_role ar ON ar.role_id = ur.role_id
         WHERE ur.user_id = p_user_id
           AND ar.role_name IN ('TREASURER', 'SUPER_ADMINISTRATOR');
        RETURN v_count > 0;
    END is_authorized;

    FUNCTION record_payment(
        p_payment_type_id IN payment_type.payment_type_id%TYPE,
        p_payer_id        IN resident.resident_id%TYPE,
        p_amount          IN NUMBER,
        p_method          IN payment.payment_method%TYPE,
        p_recorded_by     IN app_user.user_id%TYPE,
        p_related_case_id IN court_case.case_id%TYPE DEFAULT NULL,
        p_related_request_id IN letter_request.request_id%TYPE DEFAULT NULL
    ) RETURN payment.payment_id%TYPE
    IS
        v_payment_id payment.payment_id%TYPE;
        v_receipt_no receipt.receipt_number%TYPE;
    BEGIN
        IF NOT is_authorized(p_recorded_by) THEN
            RAISE e_unauthorized_role;
        END IF;

        INSERT INTO payment (payment_type_id, payer_resident_id, amount, payment_method,
                              recorded_by_user_id, related_case_id, related_letter_request_id)
        VALUES (p_payment_type_id, p_payer_id, p_amount, p_method,
                p_recorded_by, p_related_case_id, p_related_request_id)
        RETURNING payment_id INTO v_payment_id;

        v_receipt_no := 'RCT-' || TO_CHAR(SYSDATE, 'YYYY') || '-' ||
                         LPAD(TO_CHAR(seq_receipt_no.NEXTVAL), 6, '0');

        INSERT INTO receipt (payment_id, receipt_number)
        VALUES (v_payment_id, v_receipt_no);

        RETURN v_payment_id;
    EXCEPTION
        WHEN e_unauthorized_role THEN
            RAISE_APPLICATION_ERROR(-20040,
                'User ' || p_recorded_by || ' is not authorized to record payments (requires TREASURER or SUPER_ADMINISTRATOR role).');
    END record_payment;

    PROCEDURE reverse_payment(
        p_payment_id  IN payment.payment_id%TYPE,
        p_reversed_by IN app_user.user_id%TYPE
    ) IS
        v_status payment.payment_status%TYPE;
    BEGIN
        IF NOT is_authorized(p_reversed_by) THEN
            RAISE e_unauthorized_role;
        END IF;

        SELECT payment_status INTO v_status FROM payment WHERE payment_id = p_payment_id;

        IF v_status = 'REVERSED' THEN
            RAISE e_already_reversed;
        END IF;

        -- BR8: never DELETE a payment row — only mark it reversed
        UPDATE payment SET payment_status = 'REVERSED' WHERE payment_id = p_payment_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20093, 'Payment ID ' || p_payment_id || ' not found.');
        WHEN e_unauthorized_role THEN
            RAISE_APPLICATION_ERROR(-20040,
                'User ' || p_reversed_by || ' is not authorized to reverse payments.');
        WHEN e_already_reversed THEN
            RAISE_APPLICATION_ERROR(-20041, 'Payment ' || p_payment_id || ' is already reversed.');
    END reverse_payment;

    FUNCTION get_total_revenue(
        p_from_date IN DATE DEFAULT NULL,
        p_to_date   IN DATE DEFAULT NULL
    ) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(amount), 0)
          INTO v_total
          FROM payment
         WHERE payment_status = 'PAID'
           AND payment_date >= NVL(p_from_date, payment_date)
           AND payment_date <= NVL(p_to_date, payment_date);
        RETURN v_total;
    END get_total_revenue;

END pkg_payment;
/

/* ---------------------------------------------------------------------
   PKG_ANNOUNCEMENT BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_announcement AS

    FUNCTION post_announcement(
        p_title       IN announcement.title%TYPE,
        p_category    IN announcement.category%TYPE,
        p_body_text   IN CLOB,
        p_leader_id   IN local_leader.leader_id%TYPE,
        p_village_id  IN village.village_id%TYPE DEFAULT NULL,
        p_zone_id     IN zone.zone_id%TYPE DEFAULT NULL,
        p_parish_id   IN parish.parish_id%TYPE DEFAULT NULL,
        p_expiry_date IN DATE DEFAULT NULL
    ) RETURN announcement.announcement_id%TYPE
    IS
        v_id announcement.announcement_id%TYPE;
    BEGIN
        INSERT INTO announcement
            (title, category, body_text, posted_by_leader_id, target_village_id,
             target_zone_id, target_parish_id, expiry_date)
        VALUES
            (p_title, p_category, p_body_text, p_leader_id, p_village_id,
             p_zone_id, p_parish_id, p_expiry_date)
        RETURNING announcement_id INTO v_id;

        RETURN v_id;
    END post_announcement;

    PROCEDURE acknowledge(
        p_announcement_id IN announcement.announcement_id%TYPE,
        p_resident_id     IN resident.resident_id%TYPE
    ) IS
    BEGIN
        INSERT INTO announcement_acknowledgement (announcement_id, resident_id)
        VALUES (p_announcement_id, p_resident_id);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL; -- already acknowledged; not an error, just a no-op
    END acknowledge;

    FUNCTION get_ack_stats(p_announcement_id IN announcement.announcement_id%TYPE) RETURN VARCHAR2 IS
        v_ack_count   NUMBER;
        v_target_count NUMBER;
        v_village_id  announcement.target_village_id%TYPE;
    BEGIN
        SELECT target_village_id INTO v_village_id FROM announcement WHERE announcement_id = p_announcement_id;

        SELECT COUNT(*) INTO v_ack_count
          FROM announcement_acknowledgement WHERE announcement_id = p_announcement_id;

        IF v_village_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_target_count
              FROM resident r JOIN household h ON h.household_id = r.household_id
             WHERE h.village_id = v_village_id AND r.status = 'ACTIVE';
        ELSE
            SELECT COUNT(*) INTO v_target_count FROM resident WHERE status = 'ACTIVE';
        END IF;

        RETURN v_ack_count || ' of ' || v_target_count || ' residents acknowledged';
    END get_ack_stats;

END pkg_announcement;
/

/* ---------------------------------------------------------------------
   PKG_NOTIFICATION BODY
   --------------------------------------------------------------------- */
CREATE OR REPLACE PACKAGE BODY pkg_notification AS

    PROCEDURE queue_notification(
        p_resident_id  IN resident.resident_id%TYPE,
        p_channel      IN notification_log.channel%TYPE,
        p_type         IN notification_log.notification_type%TYPE,
        p_entity_type  IN VARCHAR2 DEFAULT NULL,
        p_entity_id    IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        INSERT INTO notification_log
            (recipient_resident_id, channel, notification_type, related_entity_type, related_entity_id)
        VALUES
            (p_resident_id, p_channel, p_type, p_entity_type, p_entity_id);
    END queue_notification;

    PROCEDURE send_hearing_reminders IS
        -- Explicit cursor: every hearing scheduled for tomorrow, joined to the
        -- complainant so we know who to notify.
        CURSOR c_tomorrow_hearings IS
            SELECT h.hearing_id, cc.complainant_resident_id, h.case_id
              FROM hearing h
              JOIN court_case cc ON cc.case_id = h.case_id
             WHERE h.hearing_date = TRUNC(SYSDATE) + 1;
    BEGIN
        FOR rec IN c_tomorrow_hearings LOOP
            queue_notification(
                p_resident_id => rec.complainant_resident_id,
                p_channel     => 'SMS',
                p_type        => 'REMINDER_HEARING',
                p_entity_type => 'HEARING',
                p_entity_id   => rec.hearing_id
            );
        END LOOP;
    END send_hearing_reminders;

    PROCEDURE mark_sent(p_notification_id IN notification_log.notification_id%TYPE) IS
    BEGIN
        UPDATE notification_log SET delivery_status = 'SENT' WHERE notification_id = p_notification_id;
    END mark_sent;

    PROCEDURE mark_failed(p_notification_id IN notification_log.notification_id%TYPE) IS
    BEGIN
        UPDATE notification_log SET delivery_status = 'FAILED' WHERE notification_id = p_notification_id;
    END mark_failed;

END pkg_notification;
/
