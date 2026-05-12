ALTER TABLE profiles
    ADD COLUMN ideal_partner_description TEXT AFTER traits_summary,
    ADD COLUMN matching_preference VARCHAR(20) DEFAULT 'BALANCED' AFTER ideal_partner_description;