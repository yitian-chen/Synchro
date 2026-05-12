-- V7__cleanup_profile_fields.sql
-- 删除 profiles 表中未使用的列

ALTER TABLE profiles
    DROP COLUMN preferences,
    DROP COLUMN compatibility_score;
