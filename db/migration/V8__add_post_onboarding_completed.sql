-- V8__add_post_onboarding_completed.sql
-- AI访谈完成后的额外步骤（如资料完善）完成标记

ALTER TABLE profiles
    ADD COLUMN post_onboarding_completed BOOLEAN DEFAULT FALSE AFTER matching_preference;
