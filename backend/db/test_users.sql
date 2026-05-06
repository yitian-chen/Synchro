-- 生成20个随机用户用于测试匹配功能
-- 执行前请确保数据库已初始化

-- 插入20个用户
INSERT INTO users (email, password_hash, nickname, status, onboarding_completed, created_at, updated_at) VALUES
('user1@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Alice', 'ACTIVE', true, NOW(), NOW()),
('user2@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Bob', 'ACTIVE', true, NOW(), NOW()),
('user3@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Charlie', 'ACTIVE', true, NOW(), NOW()),
('user4@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Diana', 'ACTIVE', true, NOW(), NOW()),
('user5@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Edward', 'ACTIVE', true, NOW(), NOW()),
('user6@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Fiona', 'ACTIVE', true, NOW(), NOW()),
('user7@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'George', 'ACTIVE', true, NOW(), NOW()),
('user8@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Hannah', 'ACTIVE', true, NOW(), NOW()),
('user9@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Ivan', 'ACTIVE', true, NOW(), NOW()),
('user10@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Julia', 'ACTIVE', true, NOW(), NOW()),
('user11@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Kevin', 'ACTIVE', true, NOW(), NOW()),
('user12@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Laura', 'ACTIVE', true, NOW(), NOW()),
('user13@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Michael', 'ACTIVE', true, NOW(), NOW()),
('user14@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Nancy', 'ACTIVE', true, NOW(), NOW()),
('user15@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Oscar', 'ACTIVE', true, NOW(), NOW()),
('user16@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Patricia', 'ACTIVE', true, NOW(), NOW()),
('user17@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Quentin', 'ACTIVE', true, NOW(), NOW()),
('user18@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Rachel', 'ACTIVE', true, NOW(), NOW()),
('user19@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Steven', 'ACTIVE', true, NOW(), NOW()),
('user20@test.com', '$2a$10$N9qo8uLOickgx2ZMRZoMye7T3j7G3JZ2bM7z8xQ9X5Y6Z1A2B3C4D', 'Tina', 'ACTIVE', true, NOW(), NOW());

-- 插入20个profile (user_id 2-21, 因为 user_id=1 已经被注册)
INSERT INTO profiles (user_id, bio, age, gender, location, preferences, compatibility_score, traits_summary, created_at, updated_at) VALUES
(2, '热爱户外运动，喜欢登山和摄影', 28, 'MALE', '北京', '{"outdoor": 0.9, "indoor": 0.1}', 85.50, '{"traits": ["户外爱好者", "摄影", "登山"]}', NOW(), NOW()),
(3, '文艺青年，喜欢电影和音乐', 25, 'FEMALE', '上海', '{"outdoor": 0.2, "indoor": 0.9}', 78.30, '{"traits": ["文艺", "电影", "音乐"]}', NOW(), NOW()),
(4, '健身爱好者，注重健康生活', 30, 'MALE', '深圳', '{"fitness": 0.95, "party": 0.3}', 82.10, '{"traits": ["健身", "健康", "自律"]}', NOW(), NOW()),
(5, '喜欢旅行，足迹遍布全球', 27, 'FEMALE', '成都', '{"travel": 0.95, "homebody": 0.2}', 88.70, '{"traits": ["旅行", "冒险", "摄影"]}', NOW(), NOW()),
(6, '程序员，热爱技术', 26, 'MALE', '杭州', '{"tech": 0.9, "gaming": 0.7}', 75.20, '{"traits": ["技术宅", "游戏", "编程"]}', NOW(), NOW()),
(7, '美食爱好者，喜欢烹饪', 29, 'FEMALE', '广州', '{"food": 0.95, "cooking": 0.9}', 80.50, '{"traits": ["美食", "烹饪", "探索"]}', NOW(), NOW()),
(8, '喜欢阅读，安静的性格', 24, 'MALE', '南京', '{"reading": 0.9, "social": 0.3}', 72.80, '{"traits": ["书虫", "内敛", "思考"]}', NOW(), NOW()),
(9, '社交达人，喜欢派对', 26, 'FEMALE', '北京', '{"social": 0.95, "party": 0.9}', 79.30, '{"traits": ["社交", "活泼", "派対"]}', NOW(), NOW()),
(10, '艺术家，热爱创作', 28, 'MALE', '成都', '{"art": 0.95, "creative": 0.9}', 86.40, '{"traits": ["艺术", "创意", "感性"]}', NOW(), NOW()),
(11, '商务人士，忙碌但充实', 32, 'FEMALE', '上海', '{"career": 0.9, "ambitious": 0.85}', 77.60, '{"traits": ["事业心", "独立", "上进"]}', NOW(), NOW()),
(12, '喜欢动物，养了一只猫', 27, 'MALE', '深圳', '{"animals": 0.95, "nature": 0.8}', 83.90, '{"traits": ["爱动物", "温柔", "居家"]}', NOW(), NOW()),
(13, '音乐人，弹吉他', 25, 'FEMALE', '北京', '{"music": 0.95, "performance": 0.8}', 81.20, '{"traits": ["音乐", "表演", "浪漫"]}', NOW(), NOW()),
(14, '运动健将，跑步马拉松', 29, 'MALE', '杭州', '{"sports": 0.95, "running": 0.9}', 85.70, '{"traits": ["运动", "跑步", "坚持"]}', NOW(), NOW()),
(15, '喜欢电影，尤其是科幻', 26, 'FEMALE', '广州', '{"movies": 0.9, "scifi": 0.9}', 74.50, '{"traits": ["电影", "科幻", "宅"]}', NOW(), NOW()),
(16, '创业中，充满激情', 31, 'MALE', '上海', '{"entrepreneur": 0.9, "risk_taker": 0.8}', 82.30, '{"traits": ["创业", "激情", "领导"]}', NOW(), NOW()),
(17, '喜欢瑜伽，平和的心态', 27, 'FEMALE', '成都', '{"yoga": 0.95, "meditation": 0.9}', 87.80, '{"traits": ["瑜伽", "冥想", "平衡"]}', NOW(), NOW()),
(18, '喜欢摄影，记录生活', 28, 'MALE', '深圳', '{"photography": 0.95, "travel": 0.8}', 84.60, '{"traits": ["摄影", "旅行", "观察"]}', NOW(), NOW()),
(19, '游戏玩家，也喜欢运动', 24, 'FEMALE', '北京', '{"gaming": 0.9, "sports": 0.6}', 76.40, '{"traits": ["游戏", "活力", "多元"]}', NOW(), NOW()),
(20, '喜欢品酒，享受生活', 30, 'MALE', '杭州', '{"wine": 0.9, "gourmet": 0.85}', 80.90, '{"traits": ["品酒", "美食", "享受"]}', NOW(), NOW()),
(21, '学生，热爱学习', 22, 'FEMALE', '南京', '{"study": 0.95, "curious": 0.9}', 73.20, '{"traits": ["学生", "好学", "好奇"]}', NOW(), NOW());

-- 为每个profile插入一些traits
INSERT INTO user_traits (profile_id, trait_name, trait_value, confidence, created_at) VALUES
-- User 1 (id=1) traits
(1, 'outdoor', 0.8, 0.9, NOW()),
(1, 'social', 0.7, 0.85, NOW()),
(1, 'adventurous', 0.85, 0.9, NOW()),
-- User 2 traits
(2, 'indoor', 0.9, 0.9, NOW()),
(2, 'music', 0.85, 0.85, NOW()),
(2, 'creative', 0.8, 0.8, NOW()),
-- User 3 traits
(3, 'fitness', 0.95, 0.9, NOW()),
(3, 'disciplined', 0.9, 0.85, NOW()),
(3, 'health_conscious', 0.9, 0.85, NOW()),
-- User 4 traits
(4, 'travel', 0.95, 0.9, NOW()),
(4, 'adventurous', 0.9, 0.85, NOW()),
(4, 'photography', 0.85, 0.8, NOW()),
-- User 5 traits
(5, 'tech', 0.9, 0.9, NOW()),
(5, 'gaming', 0.85, 0.85, NOW()),
(5, 'logical', 0.85, 0.8, NOW()),
-- User 6 traits
(6, 'food', 0.95, 0.9, NOW()),
(6, 'cooking', 0.9, 0.85, NOW()),
(6, 'social', 0.8, 0.8, NOW()),
-- User 7 traits
(7, 'reading', 0.9, 0.9, NOW()),
(7, 'introvert', 0.85, 0.85, NOW()),
(7, 'thoughtful', 0.85, 0.8, NOW()),
-- User 8 traits
(8, 'social', 0.95, 0.9, NOW()),
(8, 'party', 0.9, 0.85, NOW()),
(8, 'outgoing', 0.9, 0.85, NOW()),
-- User 9 traits
(9, 'art', 0.95, 0.9, NOW()),
(9, 'creative', 0.9, 0.85, NOW()),
(9, 'sensitive', 0.85, 0.8, NOW()),
-- User 10 traits
(10, 'career', 0.9, 0.85, NOW()),
(10, 'ambitious', 0.85, 0.8, NOW()),
(10, 'independent', 0.85, 0.8, NOW()),
-- User 11 traits
(11, 'animals', 0.95, 0.9, NOW()),
(11, 'nurturing', 0.9, 0.85, NOW()),
(11, 'homebody', 0.85, 0.8, NOW()),
-- User 12 traits
(12, 'music', 0.95, 0.9, NOW()),
(12, 'performance', 0.85, 0.85, NOW()),
(12, 'romantic', 0.85, 0.8, NOW()),
-- User 13 traits
(13, 'sports', 0.95, 0.9, NOW()),
(13, 'running', 0.9, 0.85, NOW()),
(13, 'disciplined', 0.9, 0.85, NOW()),
-- User 14 traits
(14, 'movies', 0.9, 0.85, NOW()),
(14, 'scifi', 0.9, 0.85, NOW()),
(14, 'homebody', 0.8, 0.8, NOW()),
-- User 15 traits
(15, 'entrepreneur', 0.9, 0.85, NOW()),
(15, 'risk_taker', 0.85, 0.8, NOW()),
(15, 'leadership', 0.85, 0.8, NOW()),
-- User 16 traits
(16, 'yoga', 0.95, 0.9, NOW()),
(16, 'meditation', 0.9, 0.85, NOW()),
(16, 'balanced', 0.9, 0.85, NOW()),
-- User 17 traits
(17, 'photography', 0.95, 0.9, NOW()),
(17, 'travel', 0.85, 0.85, NOW()),
(17, 'observant', 0.85, 0.8, NOW()),
-- User 18 traits
(18, 'gaming', 0.9, 0.85, NOW()),
(18, 'sports', 0.75, 0.8, NOW()),
(18, 'versatile', 0.85, 0.8, NOW()),
-- User 19 traits
(19, 'wine', 0.9, 0.85, NOW()),
(19, 'gourmet', 0.9, 0.85, NOW()),
(19, 'sophisticated', 0.85, 0.8, NOW()),
-- User 20 traits
(20, 'study', 0.95, 0.9, NOW()),
(20, 'curious', 0.9, 0.85, NOW()),
(20, 'open_minded', 0.85, 0.8, NOW());