/* =====================================================================
   PEARLS E-LOCAL COUNCIL PLATFORM
   PHASE 5 — PHYSICAL DESIGN (ORACLE XE)
   FILE 2 OF 3: INDEXES ON FOREIGN KEY COLUMNS

   Oracle does NOT automatically index foreign key columns (unlike primary
   keys / unique constraints, which get an index automatically). Un-indexed
   FKs cause full table scans on joins and can cause locking issues on
   parent tables during child deletes. Run this after Phase5_01.
   ===================================================================== */

CREATE INDEX idx_zone_parish              ON zone(parish_id);
CREATE INDEX idx_village_zone             ON village(zone_id);

CREATE INDEX idx_household_village        ON household(village_id);
CREATE INDEX idx_household_head           ON household(head_resident_id);
CREATE INDEX idx_resident_household       ON resident(household_id);

CREATE INDEX idx_app_user_resident        ON app_user(resident_id);
CREATE INDEX idx_user_role_user           ON user_role(user_id);
CREATE INDEX idx_user_role_role           ON user_role(role_id);
CREATE INDEX idx_user_role_village        ON user_role(village_id);
CREATE INDEX idx_user_role_zone           ON user_role(zone_id);
CREATE INDEX idx_user_role_parish         ON user_role(parish_id);

CREATE INDEX idx_leader_resident          ON local_leader(resident_id);
CREATE INDEX idx_leader_position          ON local_leader(position_id);
CREATE INDEX idx_leader_village           ON local_leader(village_id);
CREATE INDEX idx_leader_zone              ON local_leader(zone_id);
CREATE INDEX idx_leader_parish            ON local_leader(parish_id);

CREATE INDEX idx_relationship_resident    ON resident_relationship(resident_id);
CREATE INDEX idx_relationship_related     ON resident_relationship(related_resident_id);
CREATE INDEX idx_contact_resident         ON emergency_contact(resident_id);
CREATE INDEX idx_rsh_resident             ON resident_status_history(resident_id);
CREATE INDEX idx_rsh_user                 ON resident_status_history(changed_by_user_id);
CREATE INDEX idx_lt_landlord              ON landlord_tenant(landlord_resident_id);
CREATE INDEX idx_lt_tenant                ON landlord_tenant(tenant_resident_id);
CREATE INDEX idx_lt_household             ON landlord_tenant(household_id);
CREATE INDEX idx_business_owner           ON business(owner_resident_id);
CREATE INDEX idx_business_village         ON business(village_id);

CREATE INDEX idx_case_complainant         ON court_case(complainant_resident_id);
CREATE INDEX idx_case_village             ON court_case(filed_at_village_id);
CREATE INDEX idx_case_status              ON court_case(case_status);
CREATE INDEX idx_party_case               ON case_party(case_id);
CREATE INDEX idx_party_resident           ON case_party(resident_id);
CREATE INDEX idx_evidence_case            ON evidence(case_id);
CREATE INDEX idx_evidence_resident        ON evidence(uploaded_by_resident_id);
CREATE INDEX idx_witness_case             ON witness_statement(case_id);
CREATE INDEX idx_witness_resident         ON witness_statement(witness_resident_id);
CREATE INDEX idx_hearing_case             ON hearing(case_id);
CREATE INDEX idx_hearing_leader           ON hearing(presiding_leader_id);
CREATE INDEX idx_note_hearing             ON mediation_note(hearing_id);
CREATE INDEX idx_note_user                ON mediation_note(recorded_by_user_id);
CREATE INDEX idx_judgment_leader          ON case_judgment(recorded_by_leader_id);
CREATE INDEX idx_csh_case                 ON case_status_history(case_id);
CREATE INDEX idx_csh_user                 ON case_status_history(changed_by_user_id);

CREATE INDEX idx_report_resident          ON infrastructure_report(reported_by_resident_id);
CREATE INDEX idx_report_village           ON infrastructure_report(village_id);
CREATE INDEX idx_report_officer           ON infrastructure_report(assigned_officer_user_id);
CREATE INDEX idx_report_status            ON infrastructure_report(report_status);
CREATE INDEX idx_photo_report             ON report_photo(report_id);
CREATE INDEX idx_progress_report          ON report_progress_update(report_id);
CREATE INDEX idx_progress_user            ON report_progress_update(updated_by_user_id);

CREATE INDEX idx_announcement_leader      ON announcement(posted_by_leader_id);
CREATE INDEX idx_announcement_village     ON announcement(target_village_id);
CREATE INDEX idx_announcement_zone        ON announcement(target_zone_id);
CREATE INDEX idx_announcement_parish      ON announcement(target_parish_id);
CREATE INDEX idx_ack_announcement         ON announcement_acknowledgement(announcement_id);
CREATE INDEX idx_ack_resident             ON announcement_acknowledgement(resident_id);

CREATE INDEX idx_request_resident         ON letter_request(resident_id);
CREATE INDEX idx_request_type             ON letter_request(letter_type_id);
CREATE INDEX idx_issued_leader            ON letter_issued(issued_by_leader_id);

CREATE INDEX idx_payment_type             ON payment(payment_type_id);
CREATE INDEX idx_payment_payer            ON payment(payer_resident_id);
CREATE INDEX idx_payment_case             ON payment(related_case_id);
CREATE INDEX idx_payment_request          ON payment(related_letter_request_id);
CREATE INDEX idx_payment_user             ON payment(recorded_by_user_id);
CREATE INDEX idx_payment_date             ON payment(payment_date);

CREATE INDEX idx_notification_resident    ON notification_log(recipient_resident_id);
CREATE INDEX idx_notification_status      ON notification_log(delivery_status);

CREATE INDEX idx_audit_user               ON audit_log(changed_by_user_id);
CREATE INDEX idx_audit_table_record        ON audit_log(table_name, record_id);
CREATE INDEX idx_activity_user            ON activity_log(user_id);

COMMIT;
