-- =====================================================================
-- PEARLS E-LOCAL COUNCIL PLATFORM — POSTGRESQL SCHEMA
-- Converted from the original Oracle design (Phase 5) for use with
-- Railway's PostgreSQL database add-on. Column names/tables match
-- server/src/metadata.js exactly — the app's generic CRUD engine needs
-- no changes to work against this schema.
-- =====================================================================

-- ---------------------------- GEOGRAPHY ----------------------------
CREATE TABLE parish (
  parish_id     SERIAL PRIMARY KEY,
  parish_name   VARCHAR(150) NOT NULL,
  district_name VARCHAR(150) NOT NULL,
  date_created  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE zone (
  zone_id   SERIAL PRIMARY KEY,
  parish_id INTEGER NOT NULL REFERENCES parish(parish_id),
  zone_name VARCHAR(150) NOT NULL
);

CREATE TABLE village (
  village_id   SERIAL PRIMARY KEY,
  zone_id      INTEGER NOT NULL REFERENCES zone(zone_id),
  village_name VARCHAR(150) NOT NULL
);

-- ------------------------ PEOPLE & HOUSEHOLDS ------------------------
CREATE TABLE household (
  household_id        SERIAL PRIMARY KEY,
  village_id           INTEGER NOT NULL REFERENCES village(village_id),
  head_resident_id      INTEGER,  -- FK to resident added after resident table exists
  house_number          VARCHAR(50),
  address_description    TEXT
);

CREATE TABLE resident (
  resident_id     SERIAL PRIMARY KEY,
  household_id    INTEGER NOT NULL REFERENCES household(household_id),
  first_name      VARCHAR(100) NOT NULL,
  last_name       VARCHAR(100) NOT NULL,
  date_of_birth   DATE NOT NULL,
  sex             VARCHAR(1) NOT NULL CHECK (sex IN ('M','F')),
  nin_number      VARCHAR(50),
  phone_number    VARCHAR(30),
  photo_ref       VARCHAR(300),
  status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                    CHECK (status IN ('ACTIVE','MOVED_OUT','DECEASED','DEREGISTERED')),
  date_registered TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE household ADD CONSTRAINT fk_household_head
  FOREIGN KEY (head_resident_id) REFERENCES resident(resident_id);

CREATE TABLE resident_relationship (
  relationship_id     SERIAL PRIMARY KEY,
  resident_id         INTEGER NOT NULL REFERENCES resident(resident_id),
  related_resident_id INTEGER NOT NULL REFERENCES resident(resident_id),
  relationship_type   VARCHAR(20) NOT NULL
                        CHECK (relationship_type IN ('SPOUSE','CHILD','PARENT','SIBLING'))
);

CREATE TABLE emergency_contact (
  contact_id     SERIAL PRIMARY KEY,
  resident_id    INTEGER NOT NULL REFERENCES resident(resident_id),
  contact_name   VARCHAR(150) NOT NULL,
  contact_phone  VARCHAR(30) NOT NULL,
  relationship   VARCHAR(50)
);

CREATE TABLE landlord_tenant (
  ll_tenant_id          SERIAL PRIMARY KEY,
  landlord_resident_id  INTEGER NOT NULL REFERENCES resident(resident_id),
  tenant_resident_id    INTEGER NOT NULL REFERENCES resident(resident_id),
  household_id          INTEGER NOT NULL REFERENCES household(household_id),
  lease_start_date      DATE NOT NULL,
  lease_end_date        DATE
);

CREATE TABLE business (
  business_id        SERIAL PRIMARY KEY,
  owner_resident_id  INTEGER NOT NULL REFERENCES resident(resident_id),
  village_id         INTEGER NOT NULL REFERENCES village(village_id),
  business_name      VARCHAR(200) NOT NULL,
  business_type      VARCHAR(100) NOT NULL,
  license_number     VARCHAR(50),
  registration_date  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE resident_status_history (
  history_id           SERIAL PRIMARY KEY,
  resident_id          INTEGER REFERENCES resident(resident_id),
  previous_status      VARCHAR(20),
  new_status           VARCHAR(20),
  previous_household_id INTEGER,
  new_household_id      INTEGER,
  effective_date       DATE,
  changed_by_user_id   INTEGER  -- FK to app_user added after that table exists
);

-- ------------------------ LEADERSHIP & ACCOUNTS ------------------------
CREATE TABLE leader_position (
  position_id        SERIAL PRIMARY KEY,
  position_name      VARCHAR(100) NOT NULL,
  jurisdiction_level VARCHAR(20) NOT NULL
                        CHECK (jurisdiction_level IN ('VILLAGE','ZONE','PARISH'))
);

CREATE TABLE local_leader (
  leader_id             SERIAL PRIMARY KEY,
  resident_id           INTEGER NOT NULL REFERENCES resident(resident_id),
  position_id           INTEGER NOT NULL REFERENCES leader_position(position_id),
  village_id            INTEGER REFERENCES village(village_id),
  zone_id               INTEGER REFERENCES zone(zone_id),
  parish_id             INTEGER REFERENCES parish(parish_id),
  term_start_date       DATE NOT NULL,
  term_end_date         DATE,
  signature_image_ref   VARCHAR(300),
  is_active             VARCHAR(1) NOT NULL DEFAULT 'Y' CHECK (is_active IN ('Y','N'))
);

CREATE TABLE app_role (
  role_id     SERIAL PRIMARY KEY,
  role_name   VARCHAR(50) NOT NULL UNIQUE,
  description TEXT
);

CREATE TABLE app_user (
  user_id         SERIAL PRIMARY KEY,
  resident_id     INTEGER REFERENCES resident(resident_id),
  username        VARCHAR(80) NOT NULL UNIQUE,
  email           VARCHAR(150),
  display_name    VARCHAR(150),
  password_hash   VARCHAR(200),
  account_status  VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                    CHECK (account_status IN ('ACTIVE','LOCKED','DISABLED')),
  last_login_date TIMESTAMP,
  date_created    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE resident_status_history ADD CONSTRAINT fk_rsh_changed_by
  FOREIGN KEY (changed_by_user_id) REFERENCES app_user(user_id);

CREATE TABLE user_role (
  user_role_id SERIAL PRIMARY KEY,
  user_id      INTEGER NOT NULL REFERENCES app_user(user_id),
  role_id      INTEGER NOT NULL REFERENCES app_role(role_id),
  village_id   INTEGER REFERENCES village(village_id),
  zone_id      INTEGER REFERENCES zone(zone_id),
  parish_id    INTEGER REFERENCES parish(parish_id)
);

-- ------------------------------ LC COURT ------------------------------
CREATE TABLE court_case (
  case_id             SERIAL PRIMARY KEY,
  case_reference_no   VARCHAR(50) NOT NULL UNIQUE,
  complainant_resident_id INTEGER NOT NULL REFERENCES resident(resident_id),
  case_type           VARCHAR(20) NOT NULL
                        CHECK (case_type IN ('BOUNDARY','DOMESTIC','COMMUNITY','LAND')),
  case_status         VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (case_status IN ('PENDING','UNDER_REVIEW','SCHEDULED','RESOLVED','CLOSED','REJECTED')),
  filed_at_village_id INTEGER NOT NULL REFERENCES village(village_id),
  date_filed          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE case_party (
  case_party_id SERIAL PRIMARY KEY,
  case_id       INTEGER NOT NULL REFERENCES court_case(case_id),
  resident_id   INTEGER NOT NULL REFERENCES resident(resident_id),
  party_role    VARCHAR(20) NOT NULL CHECK (party_role IN ('COMPLAINANT','RESPONDENT'))
);

CREATE TABLE evidence (
  evidence_id            SERIAL PRIMARY KEY,
  case_id                INTEGER NOT NULL REFERENCES court_case(case_id),
  evidence_type          VARCHAR(20) NOT NULL CHECK (evidence_type IN ('DOCUMENT','PHOTO')),
  file_ref               VARCHAR(300) NOT NULL,
  uploaded_by_resident_id INTEGER NOT NULL REFERENCES resident(resident_id),
  upload_date            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE witness_statement (
  statement_id        SERIAL PRIMARY KEY,
  case_id             INTEGER NOT NULL REFERENCES court_case(case_id),
  witness_resident_id INTEGER NOT NULL REFERENCES resident(resident_id),
  statement_text      TEXT NOT NULL,
  statement_date      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE hearing (
  hearing_id          SERIAL PRIMARY KEY,
  case_id             INTEGER NOT NULL REFERENCES court_case(case_id),
  hearing_date        DATE NOT NULL,
  hearing_time        VARCHAR(20) NOT NULL,
  venue               VARCHAR(200) NOT NULL,
  presiding_leader_id INTEGER NOT NULL REFERENCES local_leader(leader_id)
);

CREATE TABLE mediation_note (
  note_id            SERIAL PRIMARY KEY,
  hearing_id         INTEGER NOT NULL REFERENCES hearing(hearing_id),
  note_text          TEXT NOT NULL,
  recorded_by_user_id INTEGER NOT NULL REFERENCES app_user(user_id),
  recorded_date      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE case_judgment (
  judgment_id           SERIAL PRIMARY KEY,
  case_id               INTEGER NOT NULL REFERENCES court_case(case_id),
  judgment_text         TEXT NOT NULL,
  agreement_terms       TEXT,
  debt_amount           NUMERIC(14,2),
  judgment_date         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  recorded_by_leader_id INTEGER NOT NULL REFERENCES local_leader(leader_id)
);

CREATE TABLE case_status_history (
  status_history_id  SERIAL PRIMARY KEY,
  case_id            INTEGER REFERENCES court_case(case_id),
  previous_status    VARCHAR(20),
  new_status         VARCHAR(20),
  change_date        TIMESTAMP,
  changed_by_user_id INTEGER REFERENCES app_user(user_id)
);

-- ------------------------ INFRASTRUCTURE REPORTS ------------------------
CREATE TABLE infrastructure_report (
  report_id               SERIAL PRIMARY KEY,
  reported_by_resident_id INTEGER NOT NULL REFERENCES resident(resident_id),
  village_id              INTEGER NOT NULL REFERENCES village(village_id),
  category                VARCHAR(30) NOT NULL CHECK (category IN
                            ('ROAD','BRIDGE','GARBAGE','WATER','ELECTRICITY',
                             'HEALTH_HAZARD','ILLEGAL_DUMPING','FLOODING','STREET_LIGHT')),
  gps_latitude            NUMERIC(10,6),
  gps_longitude           NUMERIC(10,6),
  priority                VARCHAR(10) NOT NULL CHECK (priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  report_status           VARCHAR(20) NOT NULL DEFAULT 'REPORTED'
                            CHECK (report_status IN ('REPORTED','ASSIGNED','IN_PROGRESS','COMPLETED','REJECTED')),
  assigned_officer_user_id INTEGER REFERENCES app_user(user_id),
  date_reported           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE report_photo (
  photo_id   SERIAL PRIMARY KEY,
  report_id  INTEGER NOT NULL REFERENCES infrastructure_report(report_id),
  photo_type VARCHAR(20) NOT NULL CHECK (photo_type IN ('INITIAL','COMPLETION')),
  file_ref   VARCHAR(300) NOT NULL
);

CREATE TABLE report_progress_update (
  progress_id       SERIAL PRIMARY KEY,
  report_id         INTEGER NOT NULL REFERENCES infrastructure_report(report_id),
  update_text       TEXT NOT NULL,
  new_status        VARCHAR(20) NOT NULL
                      CHECK (new_status IN ('REPORTED','ASSIGNED','IN_PROGRESS','COMPLETED','REJECTED')),
  updated_by_user_id INTEGER NOT NULL REFERENCES app_user(user_id),
  update_date       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------ NOTICE BOARD ------------------------------
CREATE TABLE announcement (
  announcement_id     SERIAL PRIMARY KEY,
  title               VARCHAR(200) NOT NULL,
  category            VARCHAR(30) NOT NULL CHECK (category IN
                        ('MEETING','GOV_PROGRAM','PDM','COMMUNITY_WORK','HEALTH_CAMPAIGN',
                         'SECURITY_ALERT','LOST_AND_FOUND','PUBLIC_NOTICE')),
  body_text           TEXT NOT NULL,
  posted_by_leader_id INTEGER NOT NULL REFERENCES local_leader(leader_id),
  target_village_id   INTEGER REFERENCES village(village_id),
  target_zone_id      INTEGER REFERENCES zone(zone_id),
  target_parish_id    INTEGER REFERENCES parish(parish_id),
  publish_date        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expiry_date         DATE
);

CREATE TABLE announcement_acknowledgement (
  ack_id          SERIAL PRIMARY KEY,
  announcement_id INTEGER NOT NULL REFERENCES announcement(announcement_id),
  resident_id     INTEGER NOT NULL REFERENCES resident(resident_id),
  ack_date        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------- LETTERS & CERTIFICATES -------------------------
CREATE TABLE letter_type (
  letter_type_id     SERIAL PRIMARY KEY,
  letter_type_name   VARCHAR(50) NOT NULL CHECK (letter_type_name IN
                        ('INTRODUCTION','RESIDENCE_VERIFICATION','GOOD_CONDUCT',
                         'BUSINESS_RECOMMENDATION','RECOMMENDATION','MOVEMENT')),
  default_fee_amount NUMERIC(12,2) NOT NULL
);

CREATE TABLE letter_request (
  request_id      SERIAL PRIMARY KEY,
  resident_id     INTEGER NOT NULL REFERENCES resident(resident_id),
  letter_type_id  INTEGER NOT NULL REFERENCES letter_type(letter_type_id),
  purpose         TEXT NOT NULL,
  request_status  VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (request_status IN ('PENDING','APPROVED','ISSUED','REJECTED')),
  request_date    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE letter_issued (
  letter_id          SERIAL PRIMARY KEY,
  request_id         INTEGER NOT NULL REFERENCES letter_request(request_id),
  serial_number      VARCHAR(50) NOT NULL UNIQUE,
  qr_code_ref        VARCHAR(300) NOT NULL,
  issued_by_leader_id INTEGER NOT NULL REFERENCES local_leader(leader_id),
  date_issued        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------- PAYMENTS --------------------------------
CREATE TABLE payment_type (
  payment_type_id SERIAL PRIMARY KEY,
  type_name       VARCHAR(50) NOT NULL CHECK (type_name IN
                    ('APPLICATION_FEE','LETTER_FEE','COURT_FEE','COMMUNITY_CONTRIBUTION','DONATION'))
);

CREATE TABLE payment (
  payment_id               SERIAL PRIMARY KEY,
  payment_type_id          INTEGER NOT NULL REFERENCES payment_type(payment_type_id),
  payer_resident_id        INTEGER NOT NULL REFERENCES resident(resident_id),
  related_case_id          INTEGER REFERENCES court_case(case_id),
  related_letter_request_id INTEGER REFERENCES letter_request(request_id),
  amount                   NUMERIC(14,2) NOT NULL,
  payment_method           VARCHAR(20) NOT NULL CHECK (payment_method IN ('CASH','MOBILE_MONEY')),
  payment_status           VARCHAR(20) NOT NULL DEFAULT 'PAID' CHECK (payment_status IN ('PAID','REVERSED')),
  recorded_by_user_id      INTEGER NOT NULL REFERENCES app_user(user_id),
  payment_date             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE receipt (
  receipt_id     SERIAL PRIMARY KEY,
  payment_id     INTEGER NOT NULL REFERENCES payment(payment_id),
  receipt_number VARCHAR(50) NOT NULL UNIQUE,
  issue_date     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------ COMMUNICATION ------------------------------
CREATE TABLE notification_log (
  notification_id       SERIAL PRIMARY KEY,
  recipient_resident_id INTEGER NOT NULL REFERENCES resident(resident_id),
  channel               VARCHAR(10) NOT NULL CHECK (channel IN ('SMS','EMAIL')),
  notification_type     VARCHAR(30) NOT NULL CHECK (notification_type IN
                          ('REMINDER_HEARING','REMINDER_MEETING','ANNOUNCEMENT_ALERT')),
  related_entity_type   VARCHAR(50),
  related_entity_id     INTEGER,
  delivery_status       VARCHAR(20) NOT NULL DEFAULT 'QUEUED' CHECK (delivery_status IN ('QUEUED','SENT','FAILED')),
  created_date          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------- ADMINISTRATION & LOGS -------------------------
CREATE TABLE system_setting (
  setting_id    SERIAL PRIMARY KEY,
  setting_key   VARCHAR(100) NOT NULL UNIQUE,
  setting_value VARCHAR(500) NOT NULL,
  description   TEXT
);

CREATE TABLE audit_log (
  audit_id           SERIAL PRIMARY KEY,
  table_name         VARCHAR(50),
  operation          VARCHAR(20),
  record_id          INTEGER,
  changed_by_user_id INTEGER REFERENCES app_user(user_id),
  change_timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  old_value_summary  TEXT,
  new_value_summary  TEXT
);

CREATE TABLE activity_log (
  activity_id       SERIAL PRIMARY KEY,
  user_id           INTEGER REFERENCES app_user(user_id),
  activity_type     VARCHAR(50),
  activity_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ip_address        VARCHAR(50)
);
