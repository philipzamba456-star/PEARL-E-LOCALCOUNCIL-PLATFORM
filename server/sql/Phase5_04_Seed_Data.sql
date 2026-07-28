/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 5 (SUPPLEMENT) — SEED / REFERENCE DATA

   Run this AFTER all Phase 5 and Phase 6 files. Without this data, every
   package call will fail on a foreign key (no roles, no letter types, no
   geography to attach a resident to). This script creates:
     - All 11 lookup roles, 7 leader positions, 6 letter types, 5 payment types
     - A few system settings
     - One sample parish -> 2 zones -> 4 villages
     - Sample households + residents (including one designated household head)
     - Local leader assignments + matching APP_USER/USER_ROLE records
   ===================================================================== */

SET SERVEROUTPUT ON;

-- ---------- 1. LOOKUP / REFERENCE DATA ----------
INSERT INTO app_role (role_name, description) VALUES ('SUPER_ADMINISTRATOR', 'Full system oversight');
INSERT INTO app_role (role_name, description) VALUES ('LC3_ADMINISTRATOR', 'Parish-level administrator');
INSERT INTO app_role (role_name, description) VALUES ('LC2_CHAIRPERSON', 'Zone-level chairperson');
INSERT INTO app_role (role_name, description) VALUES ('LC1_CHAIRPERSON', 'Village-level chairperson');
INSERT INTO app_role (role_name, description) VALUES ('SECRETARY', 'Records and letters');
INSERT INTO app_role (role_name, description) VALUES ('TREASURER', 'Payments and financial reports');
INSERT INTO app_role (role_name, description) VALUES ('COURT_CLERK', 'Case scheduling and hearing records');
INSERT INTO app_role (role_name, description) VALUES ('COMMUNITY_DEVELOPMENT_OFFICER', 'Infrastructure report handling');
INSERT INTO app_role (role_name, description) VALUES ('RESIDENT', 'Registered resident, self-service access');
INSERT INTO app_role (role_name, description) VALUES ('BUSINESS_OWNER', 'Registered business owner');
INSERT INTO app_role (role_name, description) VALUES ('GUEST', 'Public read-only access');

INSERT INTO leader_position (position_name, jurisdiction_level) VALUES ('LC3 Administrator', 'PARISH');
INSERT INTO leader_position (position_name, jurisdiction_level) VALUES ('LC2 Chairperson', 'ZONE');
INSERT INTO leader_position (position_name, jurisdiction_level) VALUES ('LC1 Chairperson', 'VILLAGE');
INSERT INTO leader_position (position_name, jurisdiction_level) VALUES ('Secretary', 'VILLAGE');
INSERT INTO leader_position (position_name, jurisdiction_level) VALUES ('Treasurer', 'VILLAGE');
INSERT INTO leader_position (position_name, jurisdiction_level) VALUES ('Court Clerk', 'VILLAGE');
INSERT INTO leader_position (position_name, jurisdiction_level) VALUES ('Community Development Officer', 'ZONE');

INSERT INTO letter_type (letter_type_name, default_fee_amount) VALUES ('INTRODUCTION', 5000);
INSERT INTO letter_type (letter_type_name, default_fee_amount) VALUES ('RESIDENCE_VERIFICATION', 5000);
INSERT INTO letter_type (letter_type_name, default_fee_amount) VALUES ('GOOD_CONDUCT', 10000);
INSERT INTO letter_type (letter_type_name, default_fee_amount) VALUES ('BUSINESS_RECOMMENDATION', 15000);
INSERT INTO letter_type (letter_type_name, default_fee_amount) VALUES ('RECOMMENDATION', 5000);
INSERT INTO letter_type (letter_type_name, default_fee_amount) VALUES ('MOVEMENT', 2000);

INSERT INTO payment_type (type_name) VALUES ('APPLICATION_FEE');
INSERT INTO payment_type (type_name) VALUES ('LETTER_FEE');
INSERT INTO payment_type (type_name) VALUES ('COURT_FEE');
INSERT INTO payment_type (type_name) VALUES ('COMMUNITY_CONTRIBUTION');
INSERT INTO payment_type (type_name) VALUES ('DONATION');

INSERT INTO system_setting (setting_key, setting_value, description)
VALUES ('CURRENCY_CODE', 'UGX', 'Default currency for all financial records');
INSERT INTO system_setting (setting_key, setting_value, description)
VALUES ('COURT_FEE_DEFAULT', '10000', 'Default court filing fee in UGX');
INSERT INTO system_setting (setting_key, setting_value, description)
VALUES ('SYSTEM_NAME', 'Pearls E-Local Council Platform', 'Display name used across the app');

COMMIT;

-- ---------- 2. SAMPLE GEOGRAPHY + PEOPLE (PL/SQL block to capture generated IDs) ----------
DECLARE
    v_parish_id   parish.parish_id%TYPE;
    v_zone1_id    zone.zone_id%TYPE;
    v_zone2_id    zone.zone_id%TYPE;
    v_village1_id village.village_id%TYPE;
    v_village2_id village.village_id%TYPE;
    v_village3_id village.village_id%TYPE;

    v_hh1_id      household.household_id%TYPE;
    v_hh2_id      household.household_id%TYPE;

    v_res_ssemakula  resident.resident_id%TYPE; -- LC1 Chairperson
    v_res_nakato     resident.resident_id%TYPE; -- Secretary
    v_res_okello     resident.resident_id%TYPE; -- Treasurer
    v_res_admin      resident.resident_id%TYPE; -- resident linked to super admin account
    v_res_family2    resident.resident_id%TYPE;

    v_pos_lc1        leader_position.position_id%TYPE;
    v_pos_secretary  leader_position.position_id%TYPE;
    v_pos_treasurer  leader_position.position_id%TYPE;

    v_leader_ssemakula local_leader.leader_id%TYPE;
    v_leader_nakato     local_leader.leader_id%TYPE;
    v_leader_okello      local_leader.leader_id%TYPE;

    v_user_admin      app_user.user_id%TYPE;
    v_user_ssemakula  app_user.user_id%TYPE;
    v_user_nakato     app_user.user_id%TYPE;
    v_user_okello     app_user.user_id%TYPE;

    v_role_super       app_role.role_id%TYPE;
    v_role_lc1          app_role.role_id%TYPE;
    v_role_secretary    app_role.role_id%TYPE;
    v_role_treasurer    app_role.role_id%TYPE;
BEGIN
    -- Geography: Ttula Parish -> Kanyanya Zone + Kyebando Zone
    INSERT INTO parish (parish_name, district_name) VALUES ('Ttula', 'Kampala')
        RETURNING parish_id INTO v_parish_id;

    INSERT INTO zone (parish_id, zone_name) VALUES (v_parish_id, 'Kanyanya')
        RETURNING zone_id INTO v_zone1_id;
    INSERT INTO zone (parish_id, zone_name) VALUES (v_parish_id, 'Kyebando')
        RETURNING zone_id INTO v_zone2_id;

    INSERT INTO village (zone_id, village_name) VALUES (v_zone1_id, 'Kanyanya A')
        RETURNING village_id INTO v_village1_id;
    INSERT INTO village (zone_id, village_name) VALUES (v_zone1_id, 'Kanyanya B')
        RETURNING village_id INTO v_village2_id;
    INSERT INTO village (zone_id, village_name) VALUES (v_zone2_id, 'Kyebando Central')
        RETURNING village_id INTO v_village3_id;

    -- Households (head_resident_id filled in after residents are created)
    INSERT INTO household (village_id, house_number, address_description)
        VALUES (v_village1_id, 'H-001', 'Plot 12, Kanyanya A Road')
        RETURNING household_id INTO v_hh1_id;
    INSERT INTO household (village_id, house_number, address_description)
        VALUES (v_village2_id, 'H-014', 'Plot 3, Kanyanya B Trading Centre')
        RETURNING household_id INTO v_hh2_id;

    -- Residents (using PKG_RESIDENT.register_resident so QR codes are generated automatically)
    v_res_ssemakula := pkg_resident.register_resident(v_hh1_id, 'Joseph', 'Ssemakula', DATE '1975-03-12', 'M', 'CM75031200001AA');
    v_res_nakato    := pkg_resident.register_resident(v_hh1_id, 'Grace', 'Nakato', DATE '1988-07-04', 'F', 'CF88070400002BB');
    v_res_okello    := pkg_resident.register_resident(v_hh2_id, 'Peter', 'Okello', DATE '1980-11-20', 'M', 'CM80112000003CC');
    v_res_admin     := pkg_resident.register_resident(v_hh2_id, 'Sarah', 'Namuli', DATE '1990-01-15', 'F', 'CF90011500004DD');
    v_res_family2   := pkg_resident.register_resident(v_hh1_id, 'Daniel', 'Ssemakula', DATE '2010-05-02', 'M', 'CM10050200005EE');

    -- Set household heads now that residents exist
    UPDATE household SET head_resident_id = v_res_ssemakula WHERE household_id = v_hh1_id;
    UPDATE household SET head_resident_id = v_res_okello    WHERE household_id = v_hh2_id;

    -- Family relationship: Daniel is Joseph's child
    INSERT INTO resident_relationship (resident_id, related_resident_id, relationship_type)
        VALUES (v_res_ssemakula, v_res_family2, 'CHILD');
    INSERT INTO resident_relationship (resident_id, related_resident_id, relationship_type)
        VALUES (v_res_family2, v_res_ssemakula, 'PARENT');

    -- Leadership positions
    SELECT position_id INTO v_pos_lc1 FROM leader_position WHERE position_name = 'LC1 Chairperson';
    SELECT position_id INTO v_pos_secretary FROM leader_position WHERE position_name = 'Secretary';
    SELECT position_id INTO v_pos_treasurer FROM leader_position WHERE position_name = 'Treasurer';

    INSERT INTO local_leader (resident_id, position_id, village_id, term_start_date)
        VALUES (v_res_ssemakula, v_pos_lc1, v_village1_id, DATE '2021-01-01')
        RETURNING leader_id INTO v_leader_ssemakula;
    INSERT INTO local_leader (resident_id, position_id, village_id, term_start_date)
        VALUES (v_res_nakato, v_pos_secretary, v_village1_id, DATE '2021-01-01')
        RETURNING leader_id INTO v_leader_nakato;
    INSERT INTO local_leader (resident_id, position_id, village_id, term_start_date)
        VALUES (v_res_okello, v_pos_treasurer, v_village2_id, DATE '2021-01-01')
        RETURNING leader_id INTO v_leader_okello;

    -- Application user accounts + role assignments
    SELECT role_id INTO v_role_super     FROM app_role WHERE role_name = 'SUPER_ADMINISTRATOR';
    SELECT role_id INTO v_role_lc1       FROM app_role WHERE role_name = 'LC1_CHAIRPERSON';
    SELECT role_id INTO v_role_secretary FROM app_role WHERE role_name = 'SECRETARY';
    SELECT role_id INTO v_role_treasurer FROM app_role WHERE role_name = 'TREASURER';

    INSERT INTO app_user (resident_id, username, email, account_status)
        VALUES (v_res_admin, 'admin', 'admin@pearls.ug', 'ACTIVE')
        RETURNING user_id INTO v_user_admin;
    INSERT INTO app_user (resident_id, username, email, account_status)
        VALUES (v_res_ssemakula, 'jssemakula', 'jssemakula@pearls.ug', 'ACTIVE')
        RETURNING user_id INTO v_user_ssemakula;
    INSERT INTO app_user (resident_id, username, email, account_status)
        VALUES (v_res_nakato, 'gnakato', 'gnakato@pearls.ug', 'ACTIVE')
        RETURNING user_id INTO v_user_nakato;
    INSERT INTO app_user (resident_id, username, email, account_status)
        VALUES (v_res_okello, 'pokello', 'pokello@pearls.ug', 'ACTIVE')
        RETURNING user_id INTO v_user_okello;

    INSERT INTO user_role (user_id, role_id) VALUES (v_user_admin, v_role_super);
    INSERT INTO user_role (user_id, role_id, village_id) VALUES (v_user_ssemakula, v_role_lc1, v_village1_id);
    INSERT INTO user_role (user_id, role_id, village_id) VALUES (v_user_nakato, v_role_secretary, v_village1_id);
    INSERT INTO user_role (user_id, role_id, village_id) VALUES (v_user_okello, v_role_treasurer, v_village2_id);

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Seed data loaded successfully.');
    DBMS_OUTPUT.PUT_LINE('Sample resident IDs -> Ssemakula: ' || v_res_ssemakula ||
                          ', Nakato: ' || v_res_nakato || ', Okello: ' || v_res_okello);
END;
/
