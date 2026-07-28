/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 5 — PHYSICAL DESIGN (ORACLE XE)
   FILE 1 OF 3: SEQUENCES + TABLES + CONSTRAINTS

   HOW TO RUN:
   Run this entire file in SQL*Plus, SQLcl, Oracle SQL Developer, or the
   APEX SQL Workshop > SQL Commands, connected as the schema owner
   (e.g., PEARLS_APP). Run top to bottom — order respects FK dependencies.
   ===================================================================== */

SET DEFINE OFF;

/* =====================================================================
   SECTION A: SEQUENCES (one per table with a surrogate PK)
   ===================================================================== */
CREATE SEQUENCE seq_parish                 START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_zone                   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_village                START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_leader_position        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_local_leader           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_household              START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_resident               START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_resident_relationship  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_emergency_contact      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_resident_status_hist   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_landlord_tenant        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_business               START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_court_case             START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_case_party             START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_evidence               START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_witness_statement      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_hearing                START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_mediation_note         START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_case_judgment          START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_case_status_hist       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_infra_report           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_report_photo           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_report_progress        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_announcement           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_announcement_ack       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_letter_type            START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_letter_request         START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_letter_issued          START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_payment_type           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_payment                START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_receipt                START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_notification_log       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_app_role               START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_app_user               START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_user_role              START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_audit_log              START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_activity_log           START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_system_setting         START WITH 1 INCREMENT BY 1 NOCACHE;

-- Business-facing document serials (kept separate from internal surrogate PKs)
CREATE SEQUENCE seq_case_ref_no            START WITH 1000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_letter_serial          START WITH 1000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_receipt_no             START WITH 1000 INCREMENT BY 1 NOCACHE;

/* =====================================================================
   SECTION B: GEOGRAPHIC HIERARCHY
   ===================================================================== */
CREATE TABLE parish (
    parish_id       NUMBER(6)     DEFAULT seq_parish.NEXTVAL PRIMARY KEY,
    parish_name     VARCHAR2(100) NOT NULL,
    district_name   VARCHAR2(100) NOT NULL,
    date_created    DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT uq_parish_name UNIQUE (parish_name)
);

CREATE TABLE zone (
    zone_id         NUMBER(6)     DEFAULT seq_zone.NEXTVAL PRIMARY KEY,
    parish_id       NUMBER(6)     NOT NULL,
    zone_name       VARCHAR2(100) NOT NULL,
    CONSTRAINT fk_zone_parish FOREIGN KEY (parish_id) REFERENCES parish(parish_id),
    CONSTRAINT uq_zone_name_per_parish UNIQUE (parish_id, zone_name)
);

CREATE TABLE village (
    village_id      NUMBER(6)     DEFAULT seq_village.NEXTVAL PRIMARY KEY,
    zone_id         NUMBER(6)     NOT NULL,
    village_name    VARCHAR2(100) NOT NULL,
    CONSTRAINT fk_village_zone FOREIGN KEY (zone_id) REFERENCES zone(zone_id),
    CONSTRAINT uq_village_name_per_zone UNIQUE (zone_id, village_name)
);

/* =====================================================================
   SECTION C: HOUSEHOLD + RESIDENT (circular FK handled via ALTER TABLE)
   ===================================================================== */
CREATE TABLE household (
    household_id        NUMBER(10)   DEFAULT seq_household.NEXTVAL PRIMARY KEY,
    village_id           NUMBER(6)    NOT NULL,
    head_resident_id     NUMBER(10),  -- FK added later, after RESIDENT exists
    house_number          VARCHAR2(30),
    address_description   VARCHAR2(300),
    CONSTRAINT fk_household_village FOREIGN KEY (village_id) REFERENCES village(village_id)
);

CREATE TABLE resident (
    resident_id      NUMBER(10)    DEFAULT seq_resident.NEXTVAL PRIMARY KEY,
    household_id     NUMBER(10)    NOT NULL,
    first_name       VARCHAR2(60)  NOT NULL,
    last_name        VARCHAR2(60)  NOT NULL,
    date_of_birth    DATE          NOT NULL,
    sex              CHAR(1)       NOT NULL,
    nin_number       VARCHAR2(20),
    phone_number     VARCHAR2(20),
    photo_ref        VARCHAR2(400),
    qr_code_ref      VARCHAR2(400),
    status           VARCHAR2(20)  DEFAULT 'ACTIVE' NOT NULL,
    date_registered  DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_resident_household FOREIGN KEY (household_id) REFERENCES household(household_id),
    CONSTRAINT ck_resident_sex CHECK (sex IN ('M','F')),
    CONSTRAINT ck_resident_status CHECK (status IN ('ACTIVE','MOVED_OUT','DECEASED','DEREGISTERED')),
    CONSTRAINT uq_resident_nin UNIQUE (nin_number)
);

-- Now that RESIDENT exists, complete the circular reference
ALTER TABLE household
    ADD CONSTRAINT fk_household_head FOREIGN KEY (head_resident_id) REFERENCES resident(resident_id);

/* =====================================================================
   SECTION D: SECURITY / ADMINISTRATION CORE (needed by many later FKs)
   ===================================================================== */
CREATE TABLE app_role (
    role_id       NUMBER(6)     DEFAULT seq_app_role.NEXTVAL PRIMARY KEY,
    role_name     VARCHAR2(40)  NOT NULL,
    description   VARCHAR2(200),
    CONSTRAINT uq_app_role_name UNIQUE (role_name)
);

CREATE TABLE app_user (
    user_id          NUMBER(10)    DEFAULT seq_app_user.NEXTVAL PRIMARY KEY,
    resident_id      NUMBER(10),
    username         VARCHAR2(40)  NOT NULL,
    email            VARCHAR2(150),
    account_status   VARCHAR2(10)  DEFAULT 'ACTIVE' NOT NULL,
    last_login_date  DATE,
    date_created     DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_app_user_resident FOREIGN KEY (resident_id) REFERENCES resident(resident_id),
    CONSTRAINT uq_app_user_username UNIQUE (username),
    CONSTRAINT uq_app_user_email UNIQUE (email),
    CONSTRAINT ck_app_user_status CHECK (account_status IN ('ACTIVE','LOCKED','DISABLED'))
);

CREATE TABLE user_role (
    user_role_id  NUMBER(10)  DEFAULT seq_user_role.NEXTVAL PRIMARY KEY,
    user_id       NUMBER(10)  NOT NULL,
    role_id       NUMBER(6)   NOT NULL,
    village_id    NUMBER(6),
    zone_id       NUMBER(6),
    parish_id     NUMBER(6),
    CONSTRAINT fk_user_role_user   FOREIGN KEY (user_id)    REFERENCES app_user(user_id),
    CONSTRAINT fk_user_role_role   FOREIGN KEY (role_id)    REFERENCES app_role(role_id),
    CONSTRAINT fk_user_role_village FOREIGN KEY (village_id) REFERENCES village(village_id),
    CONSTRAINT fk_user_role_zone   FOREIGN KEY (zone_id)    REFERENCES zone(zone_id),
    CONSTRAINT fk_user_role_parish FOREIGN KEY (parish_id)  REFERENCES parish(parish_id),
    CONSTRAINT uq_user_role_scope UNIQUE (user_id, role_id, village_id, zone_id, parish_id)
);

/* =====================================================================
   SECTION E: LEADERSHIP
   ===================================================================== */
CREATE TABLE leader_position (
    position_id          NUMBER(6)    DEFAULT seq_leader_position.NEXTVAL PRIMARY KEY,
    position_name        VARCHAR2(100) NOT NULL,
    jurisdiction_level   VARCHAR2(10)  NOT NULL,
    CONSTRAINT uq_leader_position_name UNIQUE (position_name),
    CONSTRAINT ck_position_jurisdiction CHECK (jurisdiction_level IN ('VILLAGE','ZONE','PARISH'))
);

CREATE TABLE local_leader (
    leader_id             NUMBER(10)  DEFAULT seq_local_leader.NEXTVAL PRIMARY KEY,
    resident_id           NUMBER(10)  NOT NULL,
    position_id           NUMBER(6)   NOT NULL,
    village_id            NUMBER(6),
    zone_id               NUMBER(6),
    parish_id             NUMBER(6),
    term_start_date       DATE        NOT NULL,
    term_end_date         DATE,
    signature_image_ref   VARCHAR2(400),
    is_active             CHAR(1)     DEFAULT 'Y' NOT NULL,
    CONSTRAINT fk_leader_resident FOREIGN KEY (resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_leader_position FOREIGN KEY (position_id) REFERENCES leader_position(position_id),
    CONSTRAINT fk_leader_village  FOREIGN KEY (village_id)  REFERENCES village(village_id),
    CONSTRAINT fk_leader_zone     FOREIGN KEY (zone_id)     REFERENCES zone(zone_id),
    CONSTRAINT fk_leader_parish   FOREIGN KEY (parish_id)   REFERENCES parish(parish_id),
    CONSTRAINT ck_leader_active CHECK (is_active IN ('Y','N'))
);

-- BR14: no two concurrently-active holders of the same position in the same jurisdiction
CREATE UNIQUE INDEX uq_leader_active_position
    ON local_leader (position_id,
                      NVL(village_id,-1), NVL(zone_id,-1), NVL(parish_id,-1),
                      CASE WHEN is_active = 'Y' THEN 'Y' END);

/* =====================================================================
   SECTION F: RESIDENT REGISTRY DETAIL
   ===================================================================== */
CREATE TABLE resident_relationship (
    relationship_id      NUMBER(10)  DEFAULT seq_resident_relationship.NEXTVAL PRIMARY KEY,
    resident_id          NUMBER(10)  NOT NULL,
    related_resident_id  NUMBER(10)  NOT NULL,
    relationship_type    VARCHAR2(20) NOT NULL,
    CONSTRAINT fk_relationship_resident FOREIGN KEY (resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_relationship_related  FOREIGN KEY (related_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT ck_relationship_not_self CHECK (resident_id <> related_resident_id),
    CONSTRAINT ck_relationship_type CHECK (relationship_type IN ('SPOUSE','CHILD','PARENT','SIBLING')),
    CONSTRAINT uq_relationship UNIQUE (resident_id, related_resident_id, relationship_type)
);

CREATE TABLE emergency_contact (
    contact_id       NUMBER(10)   DEFAULT seq_emergency_contact.NEXTVAL PRIMARY KEY,
    resident_id      NUMBER(10)   NOT NULL,
    contact_name     VARCHAR2(120) NOT NULL,
    contact_phone    VARCHAR2(20)  NOT NULL,
    relationship     VARCHAR2(40),
    CONSTRAINT fk_contact_resident FOREIGN KEY (resident_id) REFERENCES resident(resident_id)
);

CREATE TABLE resident_status_history (
    history_id             NUMBER(10)  DEFAULT seq_resident_status_hist.NEXTVAL PRIMARY KEY,
    resident_id            NUMBER(10)  NOT NULL,
    previous_status        VARCHAR2(20),
    new_status             VARCHAR2(20) NOT NULL,
    previous_household_id  NUMBER(10),
    new_household_id       NUMBER(10),
    effective_date         DATE        DEFAULT SYSDATE NOT NULL,
    changed_by_user_id     NUMBER(10)  NOT NULL,
    CONSTRAINT fk_rsh_resident   FOREIGN KEY (resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_rsh_prev_hh    FOREIGN KEY (previous_household_id) REFERENCES household(household_id),
    CONSTRAINT fk_rsh_new_hh     FOREIGN KEY (new_household_id) REFERENCES household(household_id),
    CONSTRAINT fk_rsh_user       FOREIGN KEY (changed_by_user_id) REFERENCES app_user(user_id)
);

CREATE TABLE landlord_tenant (
    ll_tenant_id           NUMBER(10)  DEFAULT seq_landlord_tenant.NEXTVAL PRIMARY KEY,
    landlord_resident_id   NUMBER(10)  NOT NULL,
    tenant_resident_id     NUMBER(10)  NOT NULL,
    household_id           NUMBER(10)  NOT NULL,
    lease_start_date       DATE        NOT NULL,
    lease_end_date         DATE,
    CONSTRAINT fk_lt_landlord FOREIGN KEY (landlord_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_lt_tenant   FOREIGN KEY (tenant_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_lt_household FOREIGN KEY (household_id) REFERENCES household(household_id),
    CONSTRAINT ck_lt_not_self CHECK (landlord_resident_id <> tenant_resident_id)
);

CREATE TABLE business (
    business_id          NUMBER(10)   DEFAULT seq_business.NEXTVAL PRIMARY KEY,
    owner_resident_id    NUMBER(10)   NOT NULL,
    village_id           NUMBER(6)    NOT NULL,
    business_name        VARCHAR2(150) NOT NULL,
    business_type        VARCHAR2(60)  NOT NULL,
    license_number       VARCHAR2(40),
    registration_date    DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_business_owner   FOREIGN KEY (owner_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_business_village FOREIGN KEY (village_id) REFERENCES village(village_id),
    CONSTRAINT uq_business_license UNIQUE (license_number)
);

/* =====================================================================
   SECTION G: LC COURT MANAGEMENT
   ===================================================================== */
CREATE TABLE court_case (
    case_id                    NUMBER(10)  DEFAULT seq_court_case.NEXTVAL PRIMARY KEY,
    case_reference_no          VARCHAR2(30) NOT NULL,
    complainant_resident_id    NUMBER(10)  NOT NULL,
    case_type                  VARCHAR2(20) NOT NULL,
    case_status                VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    filed_at_village_id        NUMBER(6)   NOT NULL,
    date_filed                 DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_case_complainant FOREIGN KEY (complainant_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_case_village     FOREIGN KEY (filed_at_village_id) REFERENCES village(village_id),
    CONSTRAINT uq_case_reference UNIQUE (case_reference_no),
    CONSTRAINT ck_case_type CHECK (case_type IN ('BOUNDARY','DOMESTIC','COMMUNITY','LAND')),
    CONSTRAINT ck_case_status CHECK (case_status IN ('PENDING','UNDER_REVIEW','SCHEDULED','RESOLVED','CLOSED','REJECTED'))
);

CREATE TABLE case_party (
    case_party_id  NUMBER(10)  DEFAULT seq_case_party.NEXTVAL PRIMARY KEY,
    case_id        NUMBER(10)  NOT NULL,
    resident_id    NUMBER(10)  NOT NULL,
    party_role     VARCHAR2(20) NOT NULL,
    CONSTRAINT fk_party_case     FOREIGN KEY (case_id) REFERENCES court_case(case_id),
    CONSTRAINT fk_party_resident FOREIGN KEY (resident_id) REFERENCES resident(resident_id),
    CONSTRAINT ck_party_role CHECK (party_role IN ('COMPLAINANT','RESPONDENT')),
    CONSTRAINT uq_case_party UNIQUE (case_id, resident_id, party_role)
);

CREATE TABLE evidence (
    evidence_id              NUMBER(10)  DEFAULT seq_evidence.NEXTVAL PRIMARY KEY,
    case_id                  NUMBER(10)  NOT NULL,
    evidence_type            VARCHAR2(20) NOT NULL,
    file_ref                 VARCHAR2(400) NOT NULL,
    uploaded_by_resident_id  NUMBER(10)  NOT NULL,
    upload_date              DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_evidence_case     FOREIGN KEY (case_id) REFERENCES court_case(case_id),
    CONSTRAINT fk_evidence_resident FOREIGN KEY (uploaded_by_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT ck_evidence_type CHECK (evidence_type IN ('DOCUMENT','PHOTO'))
);

CREATE TABLE witness_statement (
    statement_id         NUMBER(10)  DEFAULT seq_witness_statement.NEXTVAL PRIMARY KEY,
    case_id              NUMBER(10)  NOT NULL,
    witness_resident_id  NUMBER(10)  NOT NULL,
    statement_text       CLOB        NOT NULL,
    statement_date       DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_witness_case     FOREIGN KEY (case_id) REFERENCES court_case(case_id),
    CONSTRAINT fk_witness_resident FOREIGN KEY (witness_resident_id) REFERENCES resident(resident_id)
);

CREATE TABLE hearing (
    hearing_id            NUMBER(10)  DEFAULT seq_hearing.NEXTVAL PRIMARY KEY,
    case_id               NUMBER(10)  NOT NULL,
    hearing_date          DATE        NOT NULL,
    hearing_time          VARCHAR2(10) NOT NULL,
    venue                 VARCHAR2(150) NOT NULL,
    presiding_leader_id   NUMBER(10)  NOT NULL,
    CONSTRAINT fk_hearing_case   FOREIGN KEY (case_id) REFERENCES court_case(case_id),
    CONSTRAINT fk_hearing_leader FOREIGN KEY (presiding_leader_id) REFERENCES local_leader(leader_id)
);

CREATE TABLE mediation_note (
    note_id              NUMBER(10)  DEFAULT seq_mediation_note.NEXTVAL PRIMARY KEY,
    hearing_id           NUMBER(10)  NOT NULL,
    note_text            CLOB        NOT NULL,
    recorded_by_user_id  NUMBER(10)  NOT NULL,
    recorded_date         DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_note_hearing FOREIGN KEY (hearing_id) REFERENCES hearing(hearing_id),
    CONSTRAINT fk_note_user    FOREIGN KEY (recorded_by_user_id) REFERENCES app_user(user_id)
);

CREATE TABLE case_judgment (
    judgment_id              NUMBER(10)  DEFAULT seq_case_judgment.NEXTVAL PRIMARY KEY,
    case_id                  NUMBER(10)  NOT NULL,
    judgment_text            CLOB        NOT NULL,
    agreement_terms          CLOB,
    debt_amount              NUMBER(12,2),
    judgment_date            DATE        DEFAULT SYSDATE NOT NULL,
    recorded_by_leader_id    NUMBER(10)  NOT NULL,
    CONSTRAINT fk_judgment_case   FOREIGN KEY (case_id) REFERENCES court_case(case_id),
    CONSTRAINT fk_judgment_leader FOREIGN KEY (recorded_by_leader_id) REFERENCES local_leader(leader_id),
    CONSTRAINT uq_judgment_case UNIQUE (case_id)
);

CREATE TABLE case_status_history (
    status_history_id    NUMBER(10)  DEFAULT seq_case_status_hist.NEXTVAL PRIMARY KEY,
    case_id               NUMBER(10)  NOT NULL,
    previous_status       VARCHAR2(20),
    new_status            VARCHAR2(20) NOT NULL,
    change_date           DATE        DEFAULT SYSDATE NOT NULL,
    changed_by_user_id    NUMBER(10)  NOT NULL,
    CONSTRAINT fk_csh_case FOREIGN KEY (case_id) REFERENCES court_case(case_id),
    CONSTRAINT fk_csh_user FOREIGN KEY (changed_by_user_id) REFERENCES app_user(user_id)
);

/* =====================================================================
   SECTION H: INFRASTRUCTURE REPORTING
   ===================================================================== */
CREATE TABLE infrastructure_report (
    report_id                  NUMBER(10)  DEFAULT seq_infra_report.NEXTVAL PRIMARY KEY,
    reported_by_resident_id    NUMBER(10)  NOT NULL,
    village_id                 NUMBER(6)   NOT NULL,
    category                   VARCHAR2(20) NOT NULL,
    gps_latitude               NUMBER(9,6),
    gps_longitude              NUMBER(9,6),
    priority                   VARCHAR2(10) NOT NULL,
    report_status              VARCHAR2(15) DEFAULT 'REPORTED' NOT NULL,
    assigned_officer_user_id   NUMBER(10),
    date_reported              DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_report_resident FOREIGN KEY (reported_by_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_report_village  FOREIGN KEY (village_id) REFERENCES village(village_id),
    CONSTRAINT fk_report_officer  FOREIGN KEY (assigned_officer_user_id) REFERENCES app_user(user_id),
    CONSTRAINT ck_report_category CHECK (category IN
        ('ROAD','BRIDGE','GARBAGE','WATER','ELECTRICITY','HEALTH_HAZARD','ILLEGAL_DUMPING','FLOODING','STREET_LIGHT')),
    CONSTRAINT ck_report_priority CHECK (priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    CONSTRAINT ck_report_status CHECK (report_status IN ('REPORTED','ASSIGNED','IN_PROGRESS','COMPLETED','REJECTED'))
);

CREATE TABLE report_photo (
    photo_id     NUMBER(10)  DEFAULT seq_report_photo.NEXTVAL PRIMARY KEY,
    report_id    NUMBER(10)  NOT NULL,
    photo_type   VARCHAR2(12) NOT NULL,
    file_ref     VARCHAR2(400) NOT NULL,
    CONSTRAINT fk_photo_report FOREIGN KEY (report_id) REFERENCES infrastructure_report(report_id),
    CONSTRAINT ck_photo_type CHECK (photo_type IN ('INITIAL','COMPLETION'))
);

CREATE TABLE report_progress_update (
    progress_id       NUMBER(10)  DEFAULT seq_report_progress.NEXTVAL PRIMARY KEY,
    report_id         NUMBER(10)  NOT NULL,
    update_text       VARCHAR2(500) NOT NULL,
    new_status        VARCHAR2(15) NOT NULL,
    update_date       DATE        DEFAULT SYSDATE NOT NULL,
    updated_by_user_id NUMBER(10) NOT NULL,
    CONSTRAINT fk_progress_report FOREIGN KEY (report_id) REFERENCES infrastructure_report(report_id),
    CONSTRAINT fk_progress_user   FOREIGN KEY (updated_by_user_id) REFERENCES app_user(user_id)
);

/* =====================================================================
   SECTION I: COMMUNITY NOTICE BOARD
   ===================================================================== */
CREATE TABLE announcement (
    announcement_id      NUMBER(10)  DEFAULT seq_announcement.NEXTVAL PRIMARY KEY,
    title                VARCHAR2(150) NOT NULL,
    category             VARCHAR2(20)  NOT NULL,
    body_text            CLOB          NOT NULL,
    posted_by_leader_id  NUMBER(10)    NOT NULL,
    target_village_id    NUMBER(6),
    target_zone_id       NUMBER(6),
    target_parish_id     NUMBER(6),
    publish_date         DATE          DEFAULT SYSDATE NOT NULL,
    expiry_date          DATE,
    CONSTRAINT fk_announcement_leader  FOREIGN KEY (posted_by_leader_id) REFERENCES local_leader(leader_id),
    CONSTRAINT fk_announcement_village FOREIGN KEY (target_village_id) REFERENCES village(village_id),
    CONSTRAINT fk_announcement_zone    FOREIGN KEY (target_zone_id) REFERENCES zone(zone_id),
    CONSTRAINT fk_announcement_parish  FOREIGN KEY (target_parish_id) REFERENCES parish(parish_id),
    CONSTRAINT ck_announcement_category CHECK (category IN
        ('MEETING','GOV_PROGRAM','PDM','COMMUNITY_WORK','HEALTH_CAMPAIGN','SECURITY_ALERT','LOST_AND_FOUND','PUBLIC_NOTICE'))
);

CREATE TABLE announcement_acknowledgement (
    ack_id           NUMBER(10)  DEFAULT seq_announcement_ack.NEXTVAL PRIMARY KEY,
    announcement_id  NUMBER(10)  NOT NULL,
    resident_id      NUMBER(10)  NOT NULL,
    ack_date         DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_ack_announcement FOREIGN KEY (announcement_id) REFERENCES announcement(announcement_id),
    CONSTRAINT fk_ack_resident     FOREIGN KEY (resident_id) REFERENCES resident(resident_id),
    CONSTRAINT uq_ack UNIQUE (announcement_id, resident_id)
);

/* =====================================================================
   SECTION J: LETTERS & CERTIFICATES
   ===================================================================== */
CREATE TABLE letter_type (
    letter_type_id      NUMBER(6)    DEFAULT seq_letter_type.NEXTVAL PRIMARY KEY,
    letter_type_name    VARCHAR2(40) NOT NULL,
    default_fee_amount  NUMBER(12,2) NOT NULL,
    CONSTRAINT uq_letter_type_name UNIQUE (letter_type_name),
    CONSTRAINT ck_letter_type_name CHECK (letter_type_name IN
        ('INTRODUCTION','RESIDENCE_VERIFICATION','GOOD_CONDUCT','BUSINESS_RECOMMENDATION','RECOMMENDATION','MOVEMENT'))
);

CREATE TABLE letter_request (
    request_id       NUMBER(10)  DEFAULT seq_letter_request.NEXTVAL PRIMARY KEY,
    resident_id      NUMBER(10)  NOT NULL,
    letter_type_id   NUMBER(6)   NOT NULL,
    purpose          VARCHAR2(300) NOT NULL,
    request_status   VARCHAR2(15) DEFAULT 'PENDING' NOT NULL,
    request_date     DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_request_resident FOREIGN KEY (resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_request_type     FOREIGN KEY (letter_type_id) REFERENCES letter_type(letter_type_id),
    CONSTRAINT ck_request_status CHECK (request_status IN ('PENDING','APPROVED','ISSUED','REJECTED'))
);

CREATE TABLE letter_issued (
    letter_id             NUMBER(10)  DEFAULT seq_letter_issued.NEXTVAL PRIMARY KEY,
    request_id            NUMBER(10)  NOT NULL,
    serial_number         VARCHAR2(30) NOT NULL,
    qr_code_ref           VARCHAR2(400) NOT NULL,
    issued_by_leader_id   NUMBER(10)  NOT NULL,
    date_issued           DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_issued_request FOREIGN KEY (request_id) REFERENCES letter_request(request_id),
    CONSTRAINT fk_issued_leader  FOREIGN KEY (issued_by_leader_id) REFERENCES local_leader(leader_id),
    CONSTRAINT uq_issued_request UNIQUE (request_id),
    CONSTRAINT uq_issued_serial UNIQUE (serial_number)
);

/* =====================================================================
   SECTION K: PAYMENTS
   ===================================================================== */
CREATE TABLE payment_type (
    payment_type_id  NUMBER(6)    DEFAULT seq_payment_type.NEXTVAL PRIMARY KEY,
    type_name        VARCHAR2(30) NOT NULL,
    CONSTRAINT uq_payment_type_name UNIQUE (type_name),
    CONSTRAINT ck_payment_type_name CHECK (type_name IN
        ('APPLICATION_FEE','LETTER_FEE','COURT_FEE','COMMUNITY_CONTRIBUTION','DONATION'))
);

CREATE TABLE payment (
    payment_id                  NUMBER(10)  DEFAULT seq_payment.NEXTVAL PRIMARY KEY,
    payment_type_id             NUMBER(6)   NOT NULL,
    payer_resident_id           NUMBER(10)  NOT NULL,
    related_case_id             NUMBER(10),
    related_letter_request_id   NUMBER(10),
    amount                      NUMBER(12,2) NOT NULL,
    payment_method              VARCHAR2(15) NOT NULL,
    payment_status              VARCHAR2(10) DEFAULT 'PAID' NOT NULL,
    recorded_by_user_id         NUMBER(10)  NOT NULL,
    payment_date                DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_payment_type    FOREIGN KEY (payment_type_id) REFERENCES payment_type(payment_type_id),
    CONSTRAINT fk_payment_payer   FOREIGN KEY (payer_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT fk_payment_case    FOREIGN KEY (related_case_id) REFERENCES court_case(case_id),
    CONSTRAINT fk_payment_request FOREIGN KEY (related_letter_request_id) REFERENCES letter_request(request_id),
    CONSTRAINT fk_payment_user    FOREIGN KEY (recorded_by_user_id) REFERENCES app_user(user_id),
    CONSTRAINT ck_payment_amount CHECK (amount > 0),
    CONSTRAINT ck_payment_method CHECK (payment_method IN ('CASH','MOBILE_MONEY')),
    CONSTRAINT ck_payment_status CHECK (payment_status IN ('PAID','REVERSED'))
);

CREATE TABLE receipt (
    receipt_id      NUMBER(10)  DEFAULT seq_receipt.NEXTVAL PRIMARY KEY,
    payment_id      NUMBER(10)  NOT NULL,
    receipt_number  VARCHAR2(30) NOT NULL,
    issue_date      DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_receipt_payment FOREIGN KEY (payment_id) REFERENCES payment(payment_id),
    CONSTRAINT uq_receipt_payment UNIQUE (payment_id),
    CONSTRAINT uq_receipt_number UNIQUE (receipt_number)
);

/* =====================================================================
   SECTION L: COMMUNICATION
   ===================================================================== */
CREATE TABLE notification_log (
    notification_id          NUMBER(10)  DEFAULT seq_notification_log.NEXTVAL PRIMARY KEY,
    recipient_resident_id    NUMBER(10)  NOT NULL,
    channel                  VARCHAR2(10) NOT NULL,
    notification_type        VARCHAR2(25) NOT NULL,
    related_entity_type      VARCHAR2(30),
    related_entity_id        NUMBER(10),
    delivery_status          VARCHAR2(10) DEFAULT 'QUEUED' NOT NULL,
    created_date             DATE        DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_notification_resident FOREIGN KEY (recipient_resident_id) REFERENCES resident(resident_id),
    CONSTRAINT ck_notification_channel CHECK (channel IN ('SMS','EMAIL')),
    CONSTRAINT ck_notification_type CHECK (notification_type IN
        ('REMINDER_HEARING','REMINDER_MEETING','ANNOUNCEMENT_ALERT')),
    CONSTRAINT ck_notification_status CHECK (delivery_status IN ('QUEUED','SENT','FAILED'))
);

/* =====================================================================
   SECTION M: AUDIT, ACTIVITY, SETTINGS
   ===================================================================== */
CREATE TABLE audit_log (
    audit_id              NUMBER(12)  DEFAULT seq_audit_log.NEXTVAL PRIMARY KEY,
    table_name            VARCHAR2(30) NOT NULL,
    operation              VARCHAR2(10) NOT NULL,
    record_id             NUMBER(12)   NOT NULL,
    changed_by_user_id    NUMBER(10),
    change_timestamp      TIMESTAMP   DEFAULT SYSTIMESTAMP NOT NULL,
    old_value_summary     VARCHAR2(4000),
    new_value_summary     VARCHAR2(4000),
    CONSTRAINT fk_audit_user FOREIGN KEY (changed_by_user_id) REFERENCES app_user(user_id),
    CONSTRAINT ck_audit_operation CHECK (operation IN ('INSERT','UPDATE','DELETE'))
);

CREATE TABLE activity_log (
    activity_id           NUMBER(12)  DEFAULT seq_activity_log.NEXTVAL PRIMARY KEY,
    user_id               NUMBER(10)  NOT NULL,
    activity_type         VARCHAR2(15) NOT NULL,
    activity_timestamp    TIMESTAMP   DEFAULT SYSTIMESTAMP NOT NULL,
    ip_address            VARCHAR2(45),
    CONSTRAINT fk_activity_user FOREIGN KEY (user_id) REFERENCES app_user(user_id),
    CONSTRAINT ck_activity_type CHECK (activity_type IN ('LOGIN','LOGOUT','PAGE_ACCESS'))
);

CREATE TABLE system_setting (
    setting_id     NUMBER(6)    DEFAULT seq_system_setting.NEXTVAL PRIMARY KEY,
    setting_key    VARCHAR2(60) NOT NULL,
    setting_value  VARCHAR2(400) NOT NULL,
    description    VARCHAR2(200),
    CONSTRAINT uq_setting_key UNIQUE (setting_key)
);

COMMIT;
