/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 5 — PHYSICAL DESIGN (ORACLE XE)
   FILE 3 OF 3: VIEWS

   These views sit on top of the 3NF base tables from Phase5_01 and never
   duplicate stored data — they only project/join/filter it. This is the
   correct way to get denormalized-looking, fast-to-query results (e.g.
   for the Analytics Dashboard and APEX Interactive Reports) without
   breaking 3NF at the base-table level. Run after Phase5_01 and 02.
   ===================================================================== */

-- 1. Full resident directory with geographic hierarchy resolved
CREATE OR REPLACE VIEW vw_resident_directory AS
SELECT
    r.resident_id,
    r.first_name || ' ' || r.last_name          AS full_name,
    r.date_of_birth,
    TRUNC(MONTHS_BETWEEN(SYSDATE, r.date_of_birth) / 12) AS age,
    r.sex,
    r.nin_number,
    r.phone_number,
    r.status,
    h.household_id,
    v.village_id,
    v.village_name,
    z.zone_id,
    z.zone_name,
    p.parish_id,
    p.parish_name
FROM resident r
JOIN household h ON h.household_id = r.household_id
JOIN village   v ON v.village_id   = h.village_id
JOIN zone      z ON z.zone_id      = v.zone_id
JOIN parish    p ON p.parish_id    = z.parish_id;

-- 2. Announcements currently active (not expired), per BR13
CREATE OR REPLACE VIEW vw_active_announcements AS
SELECT a.*
FROM announcement a
WHERE a.expiry_date IS NULL OR a.expiry_date >= TRUNC(SYSDATE);

-- 3. Court case summary with complainant name and hearing/judgment counts
CREATE OR REPLACE VIEW vw_case_summary AS
SELECT
    cc.case_id,
    cc.case_reference_no,
    cc.case_type,
    cc.case_status,
    cc.date_filed,
    r.first_name || ' ' || r.last_name AS complainant_name,
    v.village_name,
    (SELECT COUNT(*) FROM hearing h WHERE h.case_id = cc.case_id)        AS hearing_count,
    (SELECT COUNT(*) FROM case_judgment j WHERE j.case_id = cc.case_id)  AS has_judgment
FROM court_case cc
JOIN resident r ON r.resident_id = cc.complainant_resident_id
JOIN village   v ON v.village_id = cc.filed_at_village_id;

-- 4. Payment/revenue summary by type and month
CREATE OR REPLACE VIEW vw_payment_summary_by_type AS
SELECT
    pt.type_name,
    TRUNC(p.payment_date, 'MM')  AS payment_month,
    COUNT(*)                     AS transaction_count,
    SUM(CASE WHEN p.payment_status = 'PAID' THEN p.amount ELSE 0 END)     AS total_paid,
    SUM(CASE WHEN p.payment_status = 'REVERSED' THEN p.amount ELSE 0 END) AS total_reversed
FROM payment p
JOIN payment_type pt ON pt.payment_type_id = p.payment_type_id
GROUP BY pt.type_name, TRUNC(p.payment_date, 'MM');

-- 5. Infrastructure report status dashboard feed
CREATE OR REPLACE VIEW vw_infrastructure_report_status AS
SELECT
    ir.report_id,
    ir.category,
    ir.priority,
    ir.report_status,
    v.village_name,
    ir.date_reported,
    au.username AS assigned_officer,
    (SELECT COUNT(*) FROM report_photo rp
       WHERE rp.report_id = ir.report_id AND rp.photo_type = 'COMPLETION') AS completion_photo_count
FROM infrastructure_report ir
JOIN village v  ON v.village_id = ir.village_id
LEFT JOIN app_user au ON au.user_id = ir.assigned_officer_user_id;

-- 6. Population statistics per village (feeds Analytics Dashboard Module 7)
CREATE OR REPLACE VIEW vw_population_by_village AS
SELECT
    v.village_id,
    v.village_name,
    z.zone_name,
    p.parish_name,
    COUNT(r.resident_id)                                   AS total_residents,
    SUM(CASE WHEN r.sex = 'M' THEN 1 ELSE 0 END)           AS male_count,
    SUM(CASE WHEN r.sex = 'F' THEN 1 ELSE 0 END)           AS female_count,
    SUM(CASE WHEN r.status = 'ACTIVE' THEN 1 ELSE 0 END)   AS active_residents
FROM village v
JOIN zone   z ON z.zone_id   = v.zone_id
JOIN parish p ON p.parish_id = z.parish_id
LEFT JOIN household h ON h.village_id = v.village_id
LEFT JOIN resident  r ON r.household_id = h.household_id
GROUP BY v.village_id, v.village_name, z.zone_name, p.parish_name;

-- 7. Verifiable letters (for public/serial-number verification lookups)
CREATE OR REPLACE VIEW vw_letter_verification AS
SELECT
    li.letter_id,
    li.serial_number,
    lt.letter_type_name,
    r.first_name || ' ' || r.last_name AS issued_to,
    li.date_issued,
    ll.leader_id AS issued_by_leader_id
FROM letter_issued li
JOIN letter_request lr ON lr.request_id = li.request_id
JOIN letter_type lt    ON lt.letter_type_id = lr.letter_type_id
JOIN resident r        ON r.resident_id = lr.resident_id
JOIN local_leader ll   ON ll.leader_id = li.issued_by_leader_id;

COMMIT;
