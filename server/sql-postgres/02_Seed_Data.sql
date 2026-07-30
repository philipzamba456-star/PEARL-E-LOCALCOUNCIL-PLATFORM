-- =====================================================================
-- PEARLS E-LOCAL COUNCIL PLATFORM — POSTGRESQL SEED DATA
-- Run after 01_Schema.sql. Fresh DB assumed (SERIAL columns start at 1),
-- so foreign keys below are hardcoded to match insertion order.
-- =====================================================================

INSERT INTO parish (parish_name, district_name) VALUES ('Ttula', 'Kampala');                 -- parish_id 1

INSERT INTO zone (parish_id, zone_name) VALUES
  (1, 'Kanyanya'),   -- zone_id 1
  (1, 'Kyebando');   -- zone_id 2

INSERT INTO village (zone_id, village_name) VALUES
  (1, 'Kanyanya A'),        -- village_id 1
  (1, 'Kanyanya B'),        -- village_id 2
  (2, 'Kyebando Central');  -- village_id 3

INSERT INTO household (village_id, house_number, address_description) VALUES
  (1, 'H-001', 'Plot 12, Kanyanya A Road'),               -- household_id 1
  (2, 'H-014', 'Plot 3, Kanyanya B Trading Centre');      -- household_id 2

INSERT INTO resident (household_id, first_name, last_name, date_of_birth, sex, phone_number, status) VALUES
  (1, 'Joseph', 'Ssemakula', '1975-03-12', 'M', '0772000001', 'ACTIVE'),  -- resident_id 1
  (1, 'Grace',  'Nakato',    '1988-07-04', 'F', '0772000002', 'ACTIVE'),  -- resident_id 2
  (2, 'Peter',  'Okello',    '1980-11-20', 'M', '0772000003', 'ACTIVE'),  -- resident_id 3
  (2, 'Sarah',  'Namuli',    '1990-01-15', 'F', '0772000004', 'ACTIVE'),  -- resident_id 4
  (1, 'Daniel', 'Ssemakula', '2010-05-02', 'M', NULL,          'ACTIVE'); -- resident_id 5

UPDATE household SET head_resident_id = 1 WHERE household_id = 1;
UPDATE household SET head_resident_id = 3 WHERE household_id = 2;

INSERT INTO business (owner_resident_id, village_id, business_name, business_type, license_number) VALUES
  (3, 2, 'Okello''s Hardware', 'Retail', 'BL-2291');

INSERT INTO leader_position (position_name, jurisdiction_level) VALUES
  ('LC1 Chairperson', 'VILLAGE'),  -- position_id 1
  ('Secretary',       'VILLAGE'),  -- position_id 2
  ('Treasurer',       'VILLAGE'); -- position_id 3

INSERT INTO local_leader (resident_id, position_id, village_id, term_start_date, is_active) VALUES
  (1, 1, 1, '2021-01-01', 'Y'),  -- leader_id 1 (Ssemakula, Chairperson)
  (2, 2, 1, '2021-01-01', 'Y'),  -- leader_id 2 (Nakato, Secretary)
  (3, 3, 2, '2021-01-01', 'Y'); -- leader_id 3 (Okello, Treasurer)

INSERT INTO app_role (role_name, description) VALUES
  ('SUPER_ADMINISTRATOR', 'Full system access'),
  ('LC3_ADMINISTRATOR',   'Parish-level administrator'),
  ('LC1_CHAIRPERSON',     'Village chairperson'),
  ('SECRETARY',           'Village secretary'),
  ('TREASURER',           'Village treasurer'),
  ('RESIDENT',            'Registered resident, self-service access'),
  ('GUEST',               'Public read-only access');

-- admin app_user created with NO password_hash on purpose — set one with
-- `npm run set-admin-password admin <yourpassword>` after deploying.
INSERT INTO app_user (username, email, display_name, account_status) VALUES
  ('admin', 'admin@pearls.local', 'System Administrator', 'ACTIVE'); -- user_id 1

INSERT INTO user_role (user_id, role_id) VALUES (1, 1); -- admin -> SUPER_ADMINISTRATOR

INSERT INTO court_case (case_reference_no, complainant_resident_id, case_type, case_status, filed_at_village_id) VALUES
  ('CASE-1001', 3, 'BOUNDARY', 'SCHEDULED', 2),  -- case_id 1
  ('CASE-1002', 4, 'DOMESTIC', 'PENDING', 2);   -- case_id 2

INSERT INTO hearing (case_id, hearing_date, hearing_time, venue, presiding_leader_id) VALUES
  (1, '2026-08-10', '10:00 AM', 'Kanyanya B LC1 Office', 1);

INSERT INTO infrastructure_report (reported_by_resident_id, village_id, category, priority, report_status) VALUES
  (2, 1, 'ROAD',    'HIGH',     'IN_PROGRESS'),
  (3, 2, 'GARBAGE', 'MEDIUM',   'REPORTED'),
  (4, 2, 'WATER',   'CRITICAL', 'ASSIGNED');

INSERT INTO announcement (title, category, body_text, posted_by_leader_id) VALUES
  ('Monthly Village Meeting', 'MEETING',     'All residents invited to the monthly meeting on the 5th.', 1),
  ('PDM Registration Open',   'GOV_PROGRAM', 'PDM registration is now open at the parish office.', 1);

INSERT INTO letter_type (letter_type_name, default_fee_amount) VALUES
  ('INTRODUCTION',  5000),   -- letter_type_id 1
  ('GOOD_CONDUCT', 10000);  -- letter_type_id 2

INSERT INTO letter_request (resident_id, letter_type_id, purpose, request_status) VALUES
  (4, 1, 'Opening a bank account', 'PENDING');

INSERT INTO payment_type (type_name) VALUES
  ('LETTER_FEE'),  -- payment_type_id 1
  ('COURT_FEE');  -- payment_type_id 2

INSERT INTO payment (payment_type_id, payer_resident_id, amount, payment_method, payment_status, recorded_by_user_id) VALUES
  (1, 4, 5000,  'MOBILE_MONEY', 'PAID', 1),
  (2, 3, 10000, 'CASH',         'PAID', 1);

INSERT INTO audit_log (table_name, operation, changed_by_user_id) VALUES
  ('COURT_CASE', 'INSERT', 1),
  ('PAYMENT',    'INSERT', 1);
