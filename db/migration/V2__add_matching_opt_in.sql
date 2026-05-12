ALTER TABLE users
    ADD COLUMN matching_opt_in BOOLEAN DEFAULT TRUE AFTER onboarding_completed,
    ADD INDEX idx_matching_opt_in (matching_opt_in);
