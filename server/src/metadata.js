/**
 * TABLE METADATA — this file is the single source of truth that turns the
 * Phase 5 Oracle schema into live, clickable app features instead of a
 * static diagram. Add/edit a table here and it automatically gets:
 *   - a sidebar entry
 *   - a list view (with search + pagination)
 *   - a create form
 *   - an edit form
 *   - delete (if allowed)
 *   - dropdowns for every foreign key, populated live from the DB
 *
 * field.type one of: text, textarea, number, decimal, date, select, fk, bool
 */

const MODULES = [
  { key: 'geography', label: 'Geography', icon: 'map' },
  { key: 'people', label: 'People & Households', icon: 'users' },
  { key: 'leadership', label: 'Leadership & Accounts', icon: 'shield' },
  { key: 'court', label: 'LC Court', icon: 'gavel' },
  { key: 'infrastructure', label: 'Infrastructure Reports', icon: 'tool' },
  { key: 'notices', label: 'Notice Board', icon: 'megaphone' },
  { key: 'letters', label: 'Letters & Certificates', icon: 'file-text' },
  { key: 'payments', label: 'Payments', icon: 'credit-card' },
  { key: 'communication', label: 'Notifications', icon: 'bell' },
  { key: 'system', label: 'Administration & Logs', icon: 'settings' },
];

// Roles allowed to manage users/roles/system settings + view every log
const ADMIN_ROLES = ['SUPER_ADMINISTRATOR', 'LC3_ADMINISTRATOR'];

const TABLES = {

  /* ---------------------------- GEOGRAPHY ---------------------------- */
  parish: {
    label: 'Parishes', module: 'geography', pk: 'parish_id',
    displayCols: ['parish_name'],
    columns: [
      { name: 'parish_name', label: 'Parish Name', type: 'text', required: true },
      { name: 'district_name', label: 'District', type: 'text', required: true },
      { name: 'date_created', label: 'Date Created', type: 'date', readOnly: true },
    ],
  },
  zone: {
    label: 'Zones', module: 'geography', pk: 'zone_id',
    displayCols: ['zone_name'],
    columns: [
      { name: 'parish_id', label: 'Parish', type: 'fk', ref: 'parish', required: true },
      { name: 'zone_name', label: 'Zone Name', type: 'text', required: true },
    ],
  },
  village: {
    label: 'Villages', module: 'geography', pk: 'village_id',
    displayCols: ['village_name'],
    columns: [
      { name: 'zone_id', label: 'Zone', type: 'fk', ref: 'zone', required: true },
      { name: 'village_name', label: 'Village Name', type: 'text', required: true },
    ],
  },

  /* ------------------------ PEOPLE & HOUSEHOLDS ----------------------- */
  household: {
    label: 'Households', module: 'people', pk: 'household_id',
    displayCols: ['house_number'],
    columns: [
      { name: 'village_id', label: 'Village', type: 'fk', ref: 'village', required: true },
      { name: 'head_resident_id', label: 'Head of Household', type: 'fk', ref: 'resident' },
      { name: 'house_number', label: 'House Number', type: 'text' },
      { name: 'address_description', label: 'Address', type: 'textarea' },
    ],
  },
  resident: {
    label: 'Residents', module: 'people', pk: 'resident_id',
    displayCols: ['first_name', 'last_name'],
    columns: [
      { name: 'household_id', label: 'Household', type: 'fk', ref: 'household', required: true },
      { name: 'first_name', label: 'First Name', type: 'text', required: true },
      { name: 'last_name', label: 'Last Name', type: 'text', required: true },
      { name: 'date_of_birth', label: 'Date of Birth', type: 'date', required: true },
      { name: 'sex', label: 'Sex', type: 'select', options: ['M', 'F'], required: true },
      { name: 'nin_number', label: 'National ID (NIN)', type: 'text' },
      { name: 'phone_number', label: 'Phone Number', type: 'text' },
      { name: 'photo_ref', label: 'Photo URL', type: 'text' },
      { name: 'status', label: 'Status', type: 'select',
        options: ['ACTIVE', 'MOVED_OUT', 'DECEASED', 'DEREGISTERED'], default: 'ACTIVE' },
      { name: 'date_registered', label: 'Date Registered', type: 'date', readOnly: true },
    ],
  },
  resident_relationship: {
    label: 'Family Relationships', module: 'people', pk: 'relationship_id',
    displayCols: ['relationship_type'],
    columns: [
      { name: 'resident_id', label: 'Resident', type: 'fk', ref: 'resident', required: true },
      { name: 'related_resident_id', label: 'Related Resident', type: 'fk', ref: 'resident', required: true },
      { name: 'relationship_type', label: 'Relationship', type: 'select',
        options: ['SPOUSE', 'CHILD', 'PARENT', 'SIBLING'], required: true },
    ],
  },
  emergency_contact: {
    label: 'Emergency Contacts', module: 'people', pk: 'contact_id',
    displayCols: ['contact_name'],
    columns: [
      { name: 'resident_id', label: 'Resident', type: 'fk', ref: 'resident', required: true },
      { name: 'contact_name', label: 'Contact Name', type: 'text', required: true },
      { name: 'contact_phone', label: 'Contact Phone', type: 'text', required: true },
      { name: 'relationship', label: 'Relationship', type: 'text' },
    ],
  },
  landlord_tenant: {
    label: 'Landlord / Tenant', module: 'people', pk: 'll_tenant_id',
    displayCols: ['ll_tenant_id'],
    columns: [
      { name: 'landlord_resident_id', label: 'Landlord', type: 'fk', ref: 'resident', required: true },
      { name: 'tenant_resident_id', label: 'Tenant', type: 'fk', ref: 'resident', required: true },
      { name: 'household_id', label: 'Household', type: 'fk', ref: 'household', required: true },
      { name: 'lease_start_date', label: 'Lease Start', type: 'date', required: true },
      { name: 'lease_end_date', label: 'Lease End', type: 'date' },
    ],
  },
  business: {
    label: 'Businesses', module: 'people', pk: 'business_id',
    displayCols: ['business_name'],
    columns: [
      { name: 'owner_resident_id', label: 'Owner', type: 'fk', ref: 'resident', required: true },
      { name: 'village_id', label: 'Village', type: 'fk', ref: 'village', required: true },
      { name: 'business_name', label: 'Business Name', type: 'text', required: true },
      { name: 'business_type', label: 'Business Type', type: 'text', required: true },
      { name: 'license_number', label: 'License Number', type: 'text' },
      { name: 'registration_date', label: 'Registration Date', type: 'date', readOnly: true },
    ],
  },
  resident_status_history: {
    label: 'Resident Status History', module: 'people', pk: 'history_id', readOnly: true,
    displayCols: ['new_status'],
    columns: [
      { name: 'resident_id', label: 'Resident', type: 'fk', ref: 'resident' },
      { name: 'previous_status', label: 'Previous Status', type: 'text' },
      { name: 'new_status', label: 'New Status', type: 'text' },
      { name: 'effective_date', label: 'Effective Date', type: 'date' },
      { name: 'changed_by_user_id', label: 'Changed By', type: 'fk', ref: 'app_user' },
    ],
  },

  /* ------------------------ LEADERSHIP & ACCOUNTS ---------------------- */
  leader_position: {
    label: 'Leader Positions', module: 'leadership', pk: 'position_id',
    displayCols: ['position_name'],
    columns: [
      { name: 'position_name', label: 'Position Name', type: 'text', required: true },
      { name: 'jurisdiction_level', label: 'Jurisdiction Level', type: 'select',
        options: ['VILLAGE', 'ZONE', 'PARISH'], required: true },
    ],
  },
  local_leader: {
    label: 'Local Leaders', module: 'leadership', pk: 'leader_id',
    displayCols: ['leader_id'],
    columns: [
      { name: 'resident_id', label: 'Resident', type: 'fk', ref: 'resident', required: true },
      { name: 'position_id', label: 'Position', type: 'fk', ref: 'leader_position', required: true },
      { name: 'village_id', label: 'Village', type: 'fk', ref: 'village' },
      { name: 'zone_id', label: 'Zone', type: 'fk', ref: 'zone' },
      { name: 'parish_id', label: 'Parish', type: 'fk', ref: 'parish' },
      { name: 'term_start_date', label: 'Term Start', type: 'date', required: true },
      { name: 'term_end_date', label: 'Term End', type: 'date' },
      { name: 'signature_image_ref', label: 'Signature Image URL', type: 'text' },
      { name: 'is_active', label: 'Active?', type: 'select', options: ['Y', 'N'], default: 'Y' },
    ],
  },
  app_role: {
    label: 'Roles', module: 'leadership', pk: 'role_id', adminOnly: true,
    displayCols: ['role_name'],
    columns: [
      { name: 'role_name', label: 'Role Name', type: 'text', required: true },
      { name: 'description', label: 'Description', type: 'textarea' },
    ],
  },
  app_user: {
    label: 'User Accounts', module: 'leadership', pk: 'user_id', adminOnly: true,
    displayCols: ['username'],
    columns: [
      { name: 'resident_id', label: 'Linked Resident', type: 'fk', ref: 'resident' },
      { name: 'username', label: 'Username', type: 'text', required: true },
      { name: 'email', label: 'Email', type: 'text' },
      { name: 'display_name', label: 'Display Name', type: 'text' },
      { name: 'account_status', label: 'Account Status', type: 'select',
        options: ['ACTIVE', 'LOCKED', 'DISABLED'], default: 'ACTIVE' },
      { name: 'last_login_date', label: 'Last Login', type: 'date', readOnly: true },
      { name: 'date_created', label: 'Date Created', type: 'date', readOnly: true },
    ],
    // password_hash intentionally excluded from generic form — never editable via generic CRUD
  },
  user_role: {
    label: 'User ↔ Role Assignments', module: 'leadership', pk: 'user_role_id', adminOnly: true,
    displayCols: ['user_role_id'],
    columns: [
      { name: 'user_id', label: 'User', type: 'fk', ref: 'app_user', required: true },
      { name: 'role_id', label: 'Role', type: 'fk', ref: 'app_role', required: true },
      { name: 'village_id', label: 'Village Scope', type: 'fk', ref: 'village' },
      { name: 'zone_id', label: 'Zone Scope', type: 'fk', ref: 'zone' },
      { name: 'parish_id', label: 'Parish Scope', type: 'fk', ref: 'parish' },
    ],
  },

  /* ------------------------------ LC COURT ----------------------------- */
  court_case: {
    label: 'Court Cases', module: 'court', pk: 'case_id',
    displayCols: ['case_reference_no'],
    columns: [
      { name: 'case_reference_no', label: 'Case Reference No.', type: 'text', required: true },
      { name: 'complainant_resident_id', label: 'Complainant', type: 'fk', ref: 'resident', required: true },
      { name: 'case_type', label: 'Case Type', type: 'select',
        options: ['BOUNDARY', 'DOMESTIC', 'COMMUNITY', 'LAND'], required: true },
      { name: 'case_status', label: 'Status', type: 'select',
        options: ['PENDING', 'UNDER_REVIEW', 'SCHEDULED', 'RESOLVED', 'CLOSED', 'REJECTED'], default: 'PENDING' },
      { name: 'filed_at_village_id', label: 'Filed At Village', type: 'fk', ref: 'village', required: true },
      { name: 'date_filed', label: 'Date Filed', type: 'date', readOnly: true },
    ],
  },
  case_party: {
    label: 'Case Parties', module: 'court', pk: 'case_party_id',
    displayCols: ['party_role'],
    columns: [
      { name: 'case_id', label: 'Case', type: 'fk', ref: 'court_case', required: true },
      { name: 'resident_id', label: 'Resident', type: 'fk', ref: 'resident', required: true },
      { name: 'party_role', label: 'Role', type: 'select', options: ['COMPLAINANT', 'RESPONDENT'], required: true },
    ],
  },
  evidence: {
    label: 'Evidence', module: 'court', pk: 'evidence_id',
    displayCols: ['evidence_type'],
    columns: [
      { name: 'case_id', label: 'Case', type: 'fk', ref: 'court_case', required: true },
      { name: 'evidence_type', label: 'Type', type: 'select', options: ['DOCUMENT', 'PHOTO'], required: true },
      { name: 'file_ref', label: 'File URL', type: 'text', required: true },
      { name: 'uploaded_by_resident_id', label: 'Uploaded By', type: 'fk', ref: 'resident', required: true },
      { name: 'upload_date', label: 'Upload Date', type: 'date', readOnly: true },
    ],
  },
  witness_statement: {
    label: 'Witness Statements', module: 'court', pk: 'statement_id',
    displayCols: ['statement_id'],
    columns: [
      { name: 'case_id', label: 'Case', type: 'fk', ref: 'court_case', required: true },
      { name: 'witness_resident_id', label: 'Witness', type: 'fk', ref: 'resident', required: true },
      { name: 'statement_text', label: 'Statement', type: 'textarea', required: true },
      { name: 'statement_date', label: 'Date', type: 'date', readOnly: true },
    ],
  },
  hearing: {
    label: 'Hearings', module: 'court', pk: 'hearing_id',
    displayCols: ['hearing_date'],
    columns: [
      { name: 'case_id', label: 'Case', type: 'fk', ref: 'court_case', required: true },
      { name: 'hearing_date', label: 'Hearing Date', type: 'date', required: true },
      { name: 'hearing_time', label: 'Hearing Time', type: 'text', required: true },
      { name: 'venue', label: 'Venue', type: 'text', required: true },
      { name: 'presiding_leader_id', label: 'Presiding Leader', type: 'fk', ref: 'local_leader', required: true },
    ],
  },
  mediation_note: {
    label: 'Mediation Notes', module: 'court', pk: 'note_id',
    displayCols: ['note_id'],
    columns: [
      { name: 'hearing_id', label: 'Hearing', type: 'fk', ref: 'hearing', required: true },
      { name: 'note_text', label: 'Notes', type: 'textarea', required: true },
      { name: 'recorded_by_user_id', label: 'Recorded By', type: 'fk', ref: 'app_user', required: true },
      { name: 'recorded_date', label: 'Recorded Date', type: 'date', readOnly: true },
    ],
  },
  case_judgment: {
    label: 'Case Judgments', module: 'court', pk: 'judgment_id',
    displayCols: ['judgment_id'],
    columns: [
      { name: 'case_id', label: 'Case', type: 'fk', ref: 'court_case', required: true },
      { name: 'judgment_text', label: 'Judgment', type: 'textarea', required: true },
      { name: 'agreement_terms', label: 'Agreement Terms', type: 'textarea' },
      { name: 'debt_amount', label: 'Debt Amount (UGX)', type: 'decimal' },
      { name: 'judgment_date', label: 'Judgment Date', type: 'date', readOnly: true },
      { name: 'recorded_by_leader_id', label: 'Recorded By Leader', type: 'fk', ref: 'local_leader', required: true },
    ],
  },
  case_status_history: {
    label: 'Case Status History', module: 'court', pk: 'status_history_id', readOnly: true,
    displayCols: ['new_status'],
    columns: [
      { name: 'case_id', label: 'Case', type: 'fk', ref: 'court_case' },
      { name: 'previous_status', label: 'Previous Status', type: 'text' },
      { name: 'new_status', label: 'New Status', type: 'text' },
      { name: 'change_date', label: 'Change Date', type: 'date' },
      { name: 'changed_by_user_id', label: 'Changed By', type: 'fk', ref: 'app_user' },
    ],
  },

  /* ------------------------ INFRASTRUCTURE REPORTS ---------------------- */
  infrastructure_report: {
    label: 'Infrastructure Reports', module: 'infrastructure', pk: 'report_id',
    displayCols: ['category'],
    columns: [
      { name: 'reported_by_resident_id', label: 'Reported By', type: 'fk', ref: 'resident', required: true },
      { name: 'village_id', label: 'Village', type: 'fk', ref: 'village', required: true },
      { name: 'category', label: 'Category', type: 'select', options: [
        'ROAD', 'BRIDGE', 'GARBAGE', 'WATER', 'ELECTRICITY', 'HEALTH_HAZARD',
        'ILLEGAL_DUMPING', 'FLOODING', 'STREET_LIGHT'], required: true },
      { name: 'gps_latitude', label: 'GPS Latitude', type: 'decimal' },
      { name: 'gps_longitude', label: 'GPS Longitude', type: 'decimal' },
      { name: 'priority', label: 'Priority', type: 'select', options: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'], required: true },
      { name: 'report_status', label: 'Status', type: 'select',
        options: ['REPORTED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED'], default: 'REPORTED' },
      { name: 'assigned_officer_user_id', label: 'Assigned Officer', type: 'fk', ref: 'app_user' },
      { name: 'date_reported', label: 'Date Reported', type: 'date', readOnly: true },
    ],
  },
  report_photo: {
    label: 'Report Photos', module: 'infrastructure', pk: 'photo_id',
    displayCols: ['photo_type'],
    columns: [
      { name: 'report_id', label: 'Report', type: 'fk', ref: 'infrastructure_report', required: true },
      { name: 'photo_type', label: 'Photo Type', type: 'select', options: ['INITIAL', 'COMPLETION'], required: true },
      { name: 'file_ref', label: 'Photo URL', type: 'text', required: true },
    ],
  },
  report_progress_update: {
    label: 'Report Progress Updates', module: 'infrastructure', pk: 'progress_id',
    displayCols: ['new_status'],
    columns: [
      { name: 'report_id', label: 'Report', type: 'fk', ref: 'infrastructure_report', required: true },
      { name: 'update_text', label: 'Update', type: 'textarea', required: true },
      { name: 'new_status', label: 'New Status', type: 'select',
        options: ['REPORTED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED'], required: true },
      { name: 'updated_by_user_id', label: 'Updated By', type: 'fk', ref: 'app_user', required: true },
      { name: 'update_date', label: 'Update Date', type: 'date', readOnly: true },
    ],
  },

  /* ------------------------------ NOTICE BOARD -------------------------- */
  announcement: {
    label: 'Announcements', module: 'notices', pk: 'announcement_id',
    displayCols: ['title'],
    columns: [
      { name: 'title', label: 'Title', type: 'text', required: true },
      { name: 'category', label: 'Category', type: 'select', options: [
        'MEETING', 'GOV_PROGRAM', 'PDM', 'COMMUNITY_WORK', 'HEALTH_CAMPAIGN',
        'SECURITY_ALERT', 'LOST_AND_FOUND', 'PUBLIC_NOTICE'], required: true },
      { name: 'body_text', label: 'Body', type: 'textarea', required: true },
      { name: 'posted_by_leader_id', label: 'Posted By', type: 'fk', ref: 'local_leader', required: true },
      { name: 'target_village_id', label: 'Target Village', type: 'fk', ref: 'village' },
      { name: 'target_zone_id', label: 'Target Zone', type: 'fk', ref: 'zone' },
      { name: 'target_parish_id', label: 'Target Parish', type: 'fk', ref: 'parish' },
      { name: 'publish_date', label: 'Publish Date', type: 'date', readOnly: true },
      { name: 'expiry_date', label: 'Expiry Date', type: 'date' },
    ],
  },
  announcement_acknowledgement: {
    label: 'Announcement Acknowledgements', module: 'notices', pk: 'ack_id',
    displayCols: ['ack_id'],
    columns: [
      { name: 'announcement_id', label: 'Announcement', type: 'fk', ref: 'announcement', required: true },
      { name: 'resident_id', label: 'Resident', type: 'fk', ref: 'resident', required: true },
      { name: 'ack_date', label: 'Acknowledged On', type: 'date', readOnly: true },
    ],
  },

  /* ------------------------- LETTERS & CERTIFICATES ---------------------- */
  letter_type: {
    label: 'Letter Types', module: 'letters', pk: 'letter_type_id',
    displayCols: ['letter_type_name'],
    columns: [
      { name: 'letter_type_name', label: 'Letter Type', type: 'select', options: [
        'INTRODUCTION', 'RESIDENCE_VERIFICATION', 'GOOD_CONDUCT',
        'BUSINESS_RECOMMENDATION', 'RECOMMENDATION', 'MOVEMENT'], required: true },
      { name: 'default_fee_amount', label: 'Default Fee (UGX)', type: 'decimal', required: true },
    ],
  },
  letter_request: {
    label: 'Letter Requests', module: 'letters', pk: 'request_id',
    displayCols: ['purpose'],
    columns: [
      { name: 'resident_id', label: 'Resident', type: 'fk', ref: 'resident', required: true },
      { name: 'letter_type_id', label: 'Letter Type', type: 'fk', ref: 'letter_type', required: true },
      { name: 'purpose', label: 'Purpose', type: 'textarea', required: true },
      { name: 'request_status', label: 'Status', type: 'select',
        options: ['PENDING', 'APPROVED', 'ISSUED', 'REJECTED'], default: 'PENDING' },
      { name: 'request_date', label: 'Request Date', type: 'date', readOnly: true },
    ],
  },
  letter_issued: {
    label: 'Letters Issued', module: 'letters', pk: 'letter_id',
    displayCols: ['serial_number'],
    columns: [
      { name: 'request_id', label: 'Letter Request', type: 'fk', ref: 'letter_request', required: true },
      { name: 'serial_number', label: 'Serial Number', type: 'text', required: true },
      { name: 'qr_code_ref', label: 'QR Code Ref', type: 'text', required: true },
      { name: 'issued_by_leader_id', label: 'Issued By', type: 'fk', ref: 'local_leader', required: true },
      { name: 'date_issued', label: 'Date Issued', type: 'date', readOnly: true },
    ],
  },

  /* -------------------------------- PAYMENTS ----------------------------- */
  payment_type: {
    label: 'Payment Types', module: 'payments', pk: 'payment_type_id',
    displayCols: ['type_name'],
    columns: [
      { name: 'type_name', label: 'Type Name', type: 'select', options: [
        'APPLICATION_FEE', 'LETTER_FEE', 'COURT_FEE', 'COMMUNITY_CONTRIBUTION', 'DONATION'], required: true },
    ],
  },
  payment: {
    label: 'Payments', module: 'payments', pk: 'payment_id',
    displayCols: ['payment_id'],
    columns: [
      { name: 'payment_type_id', label: 'Payment Type', type: 'fk', ref: 'payment_type', required: true },
      { name: 'payer_resident_id', label: 'Payer', type: 'fk', ref: 'resident', required: true },
      { name: 'related_case_id', label: 'Related Case', type: 'fk', ref: 'court_case' },
      { name: 'related_letter_request_id', label: 'Related Letter Request', type: 'fk', ref: 'letter_request' },
      { name: 'amount', label: 'Amount (UGX)', type: 'decimal', required: true },
      { name: 'payment_method', label: 'Method', type: 'select', options: ['CASH', 'MOBILE_MONEY'], required: true },
      { name: 'payment_status', label: 'Status', type: 'select', options: ['PAID', 'REVERSED'], default: 'PAID' },
      { name: 'recorded_by_user_id', label: 'Recorded By', type: 'fk', ref: 'app_user', required: true },
      { name: 'payment_date', label: 'Payment Date', type: 'date', readOnly: true },
    ],
  },
  receipt: {
    label: 'Receipts', module: 'payments', pk: 'receipt_id',
    displayCols: ['receipt_number'],
    columns: [
      { name: 'payment_id', label: 'Payment', type: 'fk', ref: 'payment', required: true },
      { name: 'receipt_number', label: 'Receipt Number', type: 'text', required: true },
      { name: 'issue_date', label: 'Issue Date', type: 'date', readOnly: true },
    ],
  },

  /* ------------------------------ COMMUNICATION --------------------------- */
  notification_log: {
    label: 'Notifications', module: 'communication', pk: 'notification_id',
    displayCols: ['notification_type'],
    columns: [
      { name: 'recipient_resident_id', label: 'Recipient', type: 'fk', ref: 'resident', required: true },
      { name: 'channel', label: 'Channel', type: 'select', options: ['SMS', 'EMAIL'], required: true },
      { name: 'notification_type', label: 'Type', type: 'select',
        options: ['REMINDER_HEARING', 'REMINDER_MEETING', 'ANNOUNCEMENT_ALERT'], required: true },
      { name: 'related_entity_type', label: 'Related Entity Type', type: 'text' },
      { name: 'related_entity_id', label: 'Related Entity ID', type: 'number' },
      { name: 'delivery_status', label: 'Delivery Status', type: 'select',
        options: ['QUEUED', 'SENT', 'FAILED'], default: 'QUEUED' },
      { name: 'created_date', label: 'Created', type: 'date', readOnly: true },
    ],
  },

  /* ------------------------- ADMINISTRATION & LOGS ------------------------- */
  system_setting: {
    label: 'System Settings', module: 'system', pk: 'setting_id', adminOnly: true,
    displayCols: ['setting_key'],
    columns: [
      { name: 'setting_key', label: 'Key', type: 'text', required: true },
      { name: 'setting_value', label: 'Value', type: 'text', required: true },
      { name: 'description', label: 'Description', type: 'textarea' },
    ],
  },
  audit_log: {
    label: 'Audit Log', module: 'system', pk: 'audit_id', readOnly: true, adminOnly: true,
    displayCols: ['table_name'],
    columns: [
      { name: 'table_name', label: 'Table', type: 'text' },
      { name: 'operation', label: 'Operation', type: 'text' },
      { name: 'record_id', label: 'Record ID', type: 'number' },
      { name: 'changed_by_user_id', label: 'Changed By', type: 'fk', ref: 'app_user' },
      { name: 'change_timestamp', label: 'When', type: 'date' },
      { name: 'old_value_summary', label: 'Old Value', type: 'textarea' },
      { name: 'new_value_summary', label: 'New Value', type: 'textarea' },
    ],
  },
  activity_log: {
    label: 'Activity Log', module: 'system', pk: 'activity_id', readOnly: true, adminOnly: true,
    displayCols: ['activity_type'],
    columns: [
      { name: 'user_id', label: 'User', type: 'fk', ref: 'app_user' },
      { name: 'activity_type', label: 'Activity', type: 'text' },
      { name: 'activity_timestamp', label: 'When', type: 'date' },
      { name: 'ip_address', label: 'IP Address', type: 'text' },
    ],
  },
};

// Fill in defaults so route code never has to null-check
for (const [key, t] of Object.entries(TABLES)) {
  t.table = key;
  t.readOnly = !!t.readOnly;
  t.adminOnly = !!t.adminOnly;
  t.label = t.label || key;
  t.displayCols = t.displayCols || [t.pk];
}

module.exports = { MODULES, TABLES, ADMIN_ROLES };
