/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 6 — PL/SQL
   FILE 3 OF 4: TRIGGERS

   Run AFTER Phase6_01 and Phase6_02 (triggers call PKG_AUDIT).
   ===================================================================== */

/* ---------------------------------------------------------------------
   1. RESIDENT status/household change history (supports BR1, FR1.14)
   --------------------------------------------------------------------- */
CREATE OR REPLACE TRIGGER trg_resident_status_history
AFTER UPDATE OF status, household_id ON resident
FOR EACH ROW
WHEN (NVL(OLD.status,'x') <> NVL(NEW.status,'x') OR NVL(OLD.household_id,-1) <> NVL(NEW.household_id,-1))
DECLARE
    v_user NUMBER;
BEGIN
    v_user := pkg_audit.get_current_user;
    INSERT INTO resident_status_history
        (resident_id, previous_status, new_status, previous_household_id, new_household_id, changed_by_user_id)
    VALUES
        (:NEW.resident_id, :OLD.status, :NEW.status, :OLD.household_id, :NEW.household_id,
         NVL(v_user, :NEW.resident_id)); -- fallback avoids a hard NOT NULL failure if no session user was set
END;
/

/* ---------------------------------------------------------------------
   2. COURT_CASE status change history (supports BR4, FR2.9)
   --------------------------------------------------------------------- */
CREATE OR REPLACE TRIGGER trg_case_status_history
AFTER UPDATE OF case_status ON court_case
FOR EACH ROW
WHEN (OLD.case_status <> NEW.case_status)
DECLARE
    v_user NUMBER;
BEGIN
    v_user := pkg_audit.get_current_user;
    INSERT INTO case_status_history
        (case_id, previous_status, new_status, changed_by_user_id)
    VALUES
        (:NEW.case_id, :OLD.case_status, :NEW.case_status, v_user);
END;
/

/* ---------------------------------------------------------------------
   3. CASE_PARTY: a complainant cannot also be listed as a respondent (BR3)
   --------------------------------------------------------------------- */
CREATE OR REPLACE TRIGGER trg_case_party_bi
BEFORE INSERT ON case_party
FOR EACH ROW
DECLARE
    v_complainant court_case.complainant_resident_id%TYPE;
BEGIN
    IF :NEW.party_role = 'RESPONDENT' THEN
        SELECT complainant_resident_id INTO v_complainant
          FROM court_case WHERE case_id = :NEW.case_id;

        IF v_complainant = :NEW.resident_id THEN
            RAISE_APPLICATION_ERROR(-20003,
                'BR3 violation: resident ' || :NEW.resident_id ||
                ' is the complainant on case ' || :NEW.case_id || ' and cannot also be a respondent.');
        END IF;
    END IF;
END;
/

/* ---------------------------------------------------------------------
   4. LOCAL_LEADER: auto-deactivate a leader once their term has ended
   --------------------------------------------------------------------- */
CREATE OR REPLACE TRIGGER trg_local_leader_biu
BEFORE INSERT OR UPDATE ON local_leader
FOR EACH ROW
BEGIN
    IF :NEW.term_end_date IS NOT NULL AND :NEW.term_end_date <= SYSDATE THEN
        :NEW.is_active := 'N';
    END IF;
END;
/

/* ---------------------------------------------------------------------
   5. HEARING: block scheduling a hearing directly against a closed case
      even for callers who bypass PKG_COURT (defense in depth for BR5)
   --------------------------------------------------------------------- */
CREATE OR REPLACE TRIGGER trg_hearing_bi
BEFORE INSERT ON hearing
FOR EACH ROW
DECLARE
    v_status court_case.case_status%TYPE;
BEGIN
    SELECT case_status INTO v_status FROM court_case WHERE case_id = :NEW.case_id;
    IF v_status IN ('CLOSED','RESOLVED','REJECTED') THEN
        RAISE_APPLICATION_ERROR(-20002,
            'BR5 violation: cannot schedule a hearing for case ' || :NEW.case_id ||
            ' because it is already ' || v_status || '.');
    END IF;
END;
/

/* ---------------------------------------------------------------------
   6-9. AUDIT LOGGING TRIGGERS on the four most sensitive tables
   (NFR7: every INSERT/UPDATE/DELETE on cases, payments, letters, users)
   --------------------------------------------------------------------- */
CREATE OR REPLACE TRIGGER trg_audit_court_case
AFTER INSERT OR UPDATE OR DELETE ON court_case
FOR EACH ROW
DECLARE
    v_op VARCHAR2(10);
BEGIN
    IF INSERTING THEN v_op := 'INSERT';
    ELSIF UPDATING THEN v_op := 'UPDATE';
    ELSE v_op := 'DELETE';
    END IF;

    pkg_audit.log_change(
        p_table_name => 'COURT_CASE',
        p_operation  => v_op,
        p_record_id  => NVL(:NEW.case_id, :OLD.case_id),
        p_old_value  => CASE WHEN :OLD.case_id IS NOT NULL THEN 'STATUS=' || :OLD.case_status END,
        p_new_value  => CASE WHEN :NEW.case_id IS NOT NULL THEN 'STATUS=' || :NEW.case_status END
    );
END;
/

CREATE OR REPLACE TRIGGER trg_audit_payment
AFTER INSERT OR UPDATE OR DELETE ON payment
FOR EACH ROW
DECLARE
    v_op VARCHAR2(10);
BEGIN
    IF INSERTING THEN v_op := 'INSERT';
    ELSIF UPDATING THEN v_op := 'UPDATE';
    ELSE v_op := 'DELETE';
    END IF;

    pkg_audit.log_change(
        p_table_name => 'PAYMENT',
        p_operation  => v_op,
        p_record_id  => NVL(:NEW.payment_id, :OLD.payment_id),
        p_old_value  => CASE WHEN :OLD.payment_id IS NOT NULL
                              THEN 'AMOUNT=' || :OLD.amount || ' STATUS=' || :OLD.payment_status END,
        p_new_value  => CASE WHEN :NEW.payment_id IS NOT NULL
                              THEN 'AMOUNT=' || :NEW.amount || ' STATUS=' || :NEW.payment_status END
    );
END;
/

CREATE OR REPLACE TRIGGER trg_audit_letter_issued
AFTER INSERT OR UPDATE OR DELETE ON letter_issued
FOR EACH ROW
DECLARE
    v_op VARCHAR2(10);
BEGIN
    IF INSERTING THEN v_op := 'INSERT';
    ELSIF UPDATING THEN v_op := 'UPDATE';
    ELSE v_op := 'DELETE';
    END IF;

    pkg_audit.log_change(
        p_table_name => 'LETTER_ISSUED',
        p_operation  => v_op,
        p_record_id  => NVL(:NEW.letter_id, :OLD.letter_id),
        p_old_value  => CASE WHEN :OLD.letter_id IS NOT NULL THEN 'SERIAL=' || :OLD.serial_number END,
        p_new_value  => CASE WHEN :NEW.letter_id IS NOT NULL THEN 'SERIAL=' || :NEW.serial_number END
    );
END;
/

CREATE OR REPLACE TRIGGER trg_audit_app_user
AFTER INSERT OR UPDATE OR DELETE ON app_user
FOR EACH ROW
DECLARE
    v_op VARCHAR2(10);
BEGIN
    IF INSERTING THEN v_op := 'INSERT';
    ELSIF UPDATING THEN v_op := 'UPDATE';
    ELSE v_op := 'DELETE';
    END IF;

    pkg_audit.log_change(
        p_table_name => 'APP_USER',
        p_operation  => v_op,
        p_record_id  => NVL(:NEW.user_id, :OLD.user_id),
        p_old_value  => CASE WHEN :OLD.user_id IS NOT NULL THEN 'STATUS=' || :OLD.account_status END,
        p_new_value  => CASE WHEN :NEW.user_id IS NOT NULL THEN 'STATUS=' || :NEW.account_status END
    );
END;
/
