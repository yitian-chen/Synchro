-- V5__add_message_read_flag.sql
-- 添加已读标记字段

ALTER TABLE messages
    ADD COLUMN is_read BOOLEAN DEFAULT FALSE AFTER is_ai_processed;

-- 将已有消息全部标记为已读（兼容旧数据）
UPDATE messages SET is_read = TRUE WHERE is_read IS NULL;
