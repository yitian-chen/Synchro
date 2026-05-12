-- ============================================================
-- Synchro 数据库初始化脚本（建表 + 测试数据）
-- ============================================================
-- 使用方法: mysql -u root -p synchro < db/init.sql
-- 或         docker compose exec -T mysql mysql -usynchro -psynchro_password synchro < db/init.sql
-- ============================================================

-- ========== 1. 核心表结构 ==========

-- Users
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(50) NOT NULL,
    avatar_url VARCHAR(500),
    status ENUM('PENDING_ONBOARDING', 'ACTIVE', 'SUSPENDED') DEFAULT 'PENDING_ONBOARDING',
    onboarding_completed BOOLEAN DEFAULT FALSE,
    matching_opt_in BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_status (status),
    INDEX idx_matching_opt_in (matching_opt_in)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Profiles（不含已废弃的 preferences / compatibility_score）
CREATE TABLE profiles (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL UNIQUE,
    bio TEXT,
    age INT,
    gender ENUM('MALE', 'FEMALE', 'OTHER'),
    location VARCHAR(255),
    city_id BIGINT,
    traits_summary JSON,
    ideal_partner_description TEXT,
    matching_preference VARCHAR(20) DEFAULT 'BALANCED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- User traits
CREATE TABLE user_traits (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    profile_id BIGINT NOT NULL,
    trait_name VARCHAR(100) NOT NULL,
    trait_value DECIMAL(5,4) NOT NULL,
    confidence DECIMAL(5,4) DEFAULT 1.0,
    source_message_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
    INDEX idx_profile_id (profile_id),
    INDEX idx_trait_name (trait_name),
    UNIQUE KEY uk_profile_trait (profile_id, trait_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Matches
CREATE TABLE matches (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user1_id BIGINT NOT NULL,
    user2_id BIGINT NOT NULL,
    match_week DATE NOT NULL,
    compatibility_score DECIMAL(5,4),
    match_reason JSON,
    status ENUM('PENDING', 'ACTIVE', 'EXPIRED', 'REMATCHED') DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user1_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (user2_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uk_weekly_match (user1_id, match_week),
    UNIQUE KEY uk_weekly_match_user2 (user2_id, match_week),
    INDEX idx_match_week (match_week),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Conversations
CREATE TABLE conversations (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    conversation_type ENUM('ONBOARDING', 'MATCH') NOT NULL,
    participant_id BIGINT,
    match_id BIGINT,
    title VARCHAR(255),
    status ENUM('ACTIVE', 'COMPLETED', 'ARCHIVED') DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (participant_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_type (conversation_type),
    INDEX idx_match_id (match_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Messages
CREATE TABLE messages (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    conversation_id BIGINT NOT NULL,
    sender_id BIGINT NOT NULL,
    sender_type ENUM('USER', 'AI') NOT NULL,
    content TEXT NOT NULL,
    metadata JSON,
    is_ai_processed BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    INDEX idx_conversation_id (conversation_id),
    INDEX idx_sender_id (sender_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- user_traits 外键（引用 messages）
ALTER TABLE user_traits
    ADD CONSTRAINT fk_trait_source_message
    FOREIGN KEY (source_message_id) REFERENCES messages(id) ON DELETE SET NULL;

-- Refresh tokens
CREATE TABLE refresh_tokens (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_token_hash (token_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ========== 2. 省市数据 ==========

CREATE TABLE provinces (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cities (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    province_id BIGINT NOT NULL,
    name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (province_id) REFERENCES provinces(id) ON DELETE CASCADE,
    INDEX idx_province_id (province_id),
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- profiles city_id 外键
ALTER TABLE profiles
    ADD FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE SET NULL;

-- 省份
INSERT INTO provinces (id, name) VALUES
(1, '北京市'), (2, '天津市'), (3, '上海市'), (4, '重庆市'),
(5, '河北省'), (6, '山西省'), (7, '辽宁省'), (8, '吉林省'), (9, '黑龙江省'),
(10, '江苏省'), (11, '浙江省'), (12, '安徽省'), (13, '福建省'), (14, '江西省'),
(15, '山东省'), (16, '河南省'), (17, '湖北省'), (18, '湖南省'), (19, '广东省'),
(20, '海南省'), (21, '四川省'), (22, '贵州省'), (23, '云南省'), (24, '陕西省'),
(25, '甘肃省'), (26, '青海省'), (27, '台湾省'), (28, '内蒙古自治区'),
(29, '广西壮族自治区'), (30, '西藏自治区'), (31, '宁夏回族自治区'),
(32, '新疆维吾尔自治区'), (33, '香港特别行政区'), (34, '澳门特别行政区');

-- 城市
INSERT INTO cities (province_id, name) VALUES
(1, '北京市'), (2, '天津市'), (3, '上海市'), (4, '重庆市'),
(5, '石家庄市'), (5, '唐山市'), (5, '秦皇岛市'), (5, '邯郸市'), (5, '邢台市'), (5, '保定市'), (5, '张家口市'), (5, '承德市'), (5, '沧州市'), (5, '廊坊市'), (5, '衡水市'),
(6, '太原市'), (6, '大同市'), (6, '阳泉市'), (6, '长治市'), (6, '晋城市'), (6, '朔州市'), (6, '晋中市'), (6, '运城市'), (6, '忻州市'), (6, '临汾市'), (6, '吕梁市'),
(7, '沈阳市'), (7, '大连市'), (7, '鞍山市'), (7, '抚顺市'), (7, '本溪市'), (7, '丹东市'), (7, '锦州市'), (7, '营口市'), (7, '阜新市'), (7, '辽阳市'), (7, '盘锦市'), (7, '铁岭市'), (7, '朝阳市'), (7, '葫芦岛市'),
(8, '长春市'), (8, '吉林市'), (8, '四平市'), (8, '辽源市'), (8, '通化市'), (8, '白山市'), (8, '松原市'), (8, '白城市'), (8, '延边朝鲜族自治州'),
(9, '哈尔滨市'), (9, '齐齐哈尔市'), (9, '鸡西市'), (9, '鹤岗市'), (9, '双鸭山市'), (9, '大庆市'), (9, '伊春市'), (9, '佳木斯市'), (9, '七台河市'), (9, '牡丹江市'), (9, '黑河市'), (9, '绥化市'), (9, '大兴安岭地区'),
(10, '南京市'), (10, '无锡市'), (10, '徐州市'), (10, '常州市'), (10, '苏州市'), (10, '南通市'), (10, '连云港市'), (10, '淮安市'), (10, '盐城市'), (10, '扬州市'), (10, '镇江市'), (10, '泰州市'), (10, '宿迁市'),
(11, '杭州市'), (11, '宁波市'), (11, '温州市'), (11, '嘉兴市'), (11, '湖州市'), (11, '绍兴市'), (11, '金华市'), (11, '舟山市'), (11, '台州市'), (11, '丽水市'),
(12, '合肥市'), (12, '芜湖市'), (12, '蚌埠市'), (12, '淮南市'), (12, '马鞍山市'), (12, '淮北市'), (12, '铜陵市'), (12, '安庆市'), (12, '黄山市'), (12, '滁州市'), (12, '阜阳市'), (12, '宿州市'), (12, '六安市'), (12, '亳州市'), (12, '池州市'), (12, '宣城市'),
(13, '福州市'), (13, '厦门市'), (13, '莆田市'), (13, '三明市'), (13, '泉州市'), (13, '漳州市'), (13, '南平市'), (13, '龙岩市'), (13, '宁德市'),
(14, '南昌市'), (14, '景德镇市'), (14, '萍乡市'), (14, '九江市'), (14, '新余市'), (14, '鹰潭市'), (14, '赣州市'), (14, '吉安市'), (14, '宜春市'), (14, '抚州市'), (14, '上饶市'),
(15, '济南市'), (15, '青岛市'), (15, '淄博市'), (15, '枣庄市'), (15, '东营市'), (15, '烟台市'), (15, '潍坊市'), (15, '济宁市'), (15, '泰安市'), (15, '威海市'), (15, '日照市'), (15, '临沂市'), (15, '德州市'), (15, '聊城市'), (15, '滨州市'), (15, '菏泽市'),
(16, '郑州市'), (16, '开封市'), (16, '洛阳市'), (16, '平顶山市'), (16, '安阳市'), (16, '鹤壁市'), (16, '新乡市'), (16, '焦作市'), (16, '濮阳市'), (16, '许昌市'), (16, '漯河市'), (16, '三门峡市'), (16, '南阳市'), (16, '商丘市'), (16, '信阳市'), (16, '周口市'), (16, '驻马店市'), (16, '济源市'),
(17, '武汉市'), (17, '黄石市'), (17, '十堰市'), (17, '宜昌市'), (17, '襄阳市'), (17, '鄂州市'), (17, '荆门市'), (17, '孝感市'), (17, '荆州市'), (17, '黄冈市'), (17, '咸宁市'), (17, '随州市'), (17, '恩施土家族苗族自治州'), (17, '仙桃市'), (17, '潜江市'), (17, '天门市'), (17, '神农架林区'),
(18, '长沙市'), (18, '株洲市'), (18, '湘潭市'), (18, '衡阳市'), (18, '邵阳市'), (18, '岳阳市'), (18, '常德市'), (18, '张家界市'), (18, '益阳市'), (18, '郴州市'), (18, '永州市'), (18, '怀化市'), (18, '娄底市'), (18, '湘西土家族苗族自治州'),
(19, '广州市'), (19, '韶关市'), (19, '深圳市'), (19, '珠海市'), (19, '汕头市'), (19, '佛山市'), (19, '江门市'), (19, '湛江市'), (19, '茂名市'), (19, '肇庆市'), (19, '惠州市'), (19, '梅州市'), (19, '汕尾市'), (19, '河源市'), (19, '阳江市'), (19, '清远市'), (19, '东莞市'), (19, '中山市'), (19, '潮州市'), (19, '揭阳市'), (19, '云浮市'),
(20, '海口市'), (20, '三亚市'), (20, '三沙市'), (20, '儋州市'),
(21, '成都市'), (21, '自贡市'), (21, '攀枝花市'), (21, '泸州市'), (21, '德阳市'), (21, '绵阳市'), (21, '广元市'), (21, '遂宁市'), (21, '内江市'), (21, '乐山市'), (21, '南充市'), (21, '眉山市'), (21, '宜宾市'), (21, '广安市'), (21, '达州市'), (21, '雅安市'), (21, '巴中市'), (21, '资阳市'), (21, '阿坝藏族羌族自治州'), (21, '甘孜藏族自治州'), (21, '凉山彝族自治州'),
(22, '贵阳市'), (22, '六盘水市'), (22, '遵义市'), (22, '安顺市'), (22, '毕节市'), (22, '铜仁市'), (22, '黔西南布依族苗族自治州'), (22, '黔东南苗族侗族自治州'), (22, '黔南布依族苗族自治州'),
(23, '昆明市'), (23, '曲靖市'), (23, '玉溪市'), (23, '保山市'), (23, '昭通市'), (23, '丽江市'), (23, '普洱市'), (23, '临沧市'), (23, '楚雄彝族自治州'), (23, '红河哈尼族彝族自治州'), (23, '文山壮族苗族自治州'), (23, '西双版纳傣族自治州'), (23, '大理白族自治州'), (23, '德宏傣族景颇族自治州'), (23, '怒江傈僳族自治州'), (23, '迪庆藏族自治州'),
(24, '西安市'), (24, '铜川市'), (24, '宝鸡市'), (24, '咸阳市'), (24, '渭南市'), (24, '延安市'), (24, '汉中市'), (24, '榆林市'), (24, '安康市'), (24, '商洛市'),
(25, '兰州市'), (25, '嘉峪关市'), (25, '金昌市'), (25, '白银市'), (25, '天水市'), (25, '武威市'), (25, '张掖市'), (25, '平凉市'), (25, '酒泉市'), (25, '庆阳市'), (25, '定西市'), (25, '陇南市'), (25, '临夏回族自治州'), (25, '甘南藏族自治州'),
(26, '西宁市'), (26, '海东市'), (26, '海北藏族自治州'), (26, '黄南藏族自治州'), (26, '海南藏族自治州'), (26, '果洛藏族自治州'), (26, '玉树藏族自治州'), (26, '海西蒙古族藏族自治州'),
(27, '台北市'), (27, '高雄市'), (27, '新北市'), (27, '台中市'), (27, '台南市'), (27, '桃园市'), (27, '基隆市'), (27, '新竹市'), (27, '嘉义市'),
(28, '呼和浩特市'), (28, '包头市'), (28, '乌海市'), (28, '赤峰市'), (28, '通辽市'), (28, '鄂尔多斯市'), (28, '呼伦贝尔市'), (28, '巴彦淖尔市'), (28, '乌兰察布市'), (28, '兴安盟'), (28, '锡林郭勒盟'), (28, '阿拉善盟'),
(29, '南宁市'), (29, '柳州市'), (29, '桂林市'), (29, '梧州市'), (29, '北海市'), (29, '防城港市'), (29, '钦州市'), (29, '贵港市'), (29, '玉林市'), (29, '百色市'), (29, '贺州市'), (29, '河池市'), (29, '来宾市'), (29, '崇左市'),
(30, '拉萨市'), (30, '日喀则市'), (30, '昌都市'), (30, '林芝市'), (30, '山南市'), (30, '那曲市'), (30, '阿里地区'),
(31, '银川市'), (31, '石嘴山市'), (31, '吴忠市'), (31, '固原市'), (31, '中卫市'),
(32, '乌鲁木齐市'), (32, '克拉玛依市'), (32, '吐鲁番市'), (32, '哈密市'), (32, '昌吉回族自治州'), (32, '博尔塔拉蒙古自治州'), (32, '巴音郭楞蒙古自治州'), (32, '阿克苏地区'), (32, '克孜勒苏柯尔克孜自治州'), (32, '喀什地区'), (32, '和田地区'), (32, '伊犁哈萨克自治州'), (32, '塔城地区'), (32, '阿勒泰地区'), (32, '石河子市'), (32, '阿拉尔市'), (32, '图木舒克市'), (32, '五家渠市'),
(33, '香港特别行政区'), (34, '澳门特别行政区');

-- ========== 3. 20 个测试用户 ==========
-- 测试登录密码均为: password123
-- BCrypt hash: $2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu

INSERT INTO users (id, email, password_hash, nickname, avatar_url, status, onboarding_completed, matching_opt_in, created_at, updated_at) VALUES
(1,  'test1@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '张明远', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(2,  'test2@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '李浩然', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(3,  'test3@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '王子涵', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(4,  'test4@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '刘思远', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(5,  'test5@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '陈天宇', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(6,  'test6@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '赵俊杰', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(7,  'test7@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '孙浩宇', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(8,  'test8@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '周文博', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(9,  'test9@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '吴子轩', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(10, 'test10@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '郑凯文', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(11, 'test11@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '李晓萱', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(12, 'test12@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '王语嫣', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(13, 'test13@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '张雨桐', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(14, 'test14@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '刘诗涵', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(15, 'test15@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '陈静怡', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(16, 'test16@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '赵梦婷', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(17, 'test17@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '孙悦然', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(18, 'test18@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '周蕾',   NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(19, 'test19@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '吴欣怡', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(20, 'test20@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '郑媛',   NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW());

-- ========== 4. 20 个用户资料 ==========

INSERT INTO profiles (user_id, bio, age, gender, location, city_id, traits_summary, ideal_partner_description, matching_preference, created_at, updated_at) VALUES

-- 男 1: 张明远 (28, 北京, 后端开发)
(1, '在一家互联网公司做后端开发，代码写累了就背着相机去京郊爬山。周末喜欢约朋友打羽毛球，偶尔在家研究咖啡拉花。养了一只橘猫，叫"火锅"。',
 28, 'MALE', '北京市 北京市', 1,
 '[{"name":"extroversion","value":0.6,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.8},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.8,"confidence":0.9},{"name":"socialness","value":0.6,"confidence":0.8},{"name":"activity_level","value":0.7,"confidence":0.8},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.6,"confidence":0.6},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.6,"confidence":0.7},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.8},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.9},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.2,"confidence":0.9},{"name":"long_term_goal","value":0.7,"confidence":0.8}]',
 '希望对方性格开朗，有自己热爱的事情。坐标北京，不接受异地。', 'BALANCED', NOW(), NOW()),

-- 男 2: 李浩然 (30, 上海, 金融产品经理)
(2, '在陆家嘴做金融产品，工作日西装革履，周末最爱穿T恤逛菜市场。喜欢做饭，拿手菜是红烧肉和糖醋排骨。每周坚持健身三次。',
 30, 'MALE', '上海市 上海市', 3,
 '[{"name":"extroversion","value":0.6,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.5,"confidence":0.6},{"name":"socialness","value":0.6,"confidence":0.7},{"name":"activity_level","value":0.8,"confidence":0.8},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.8,"confidence":0.9},{"name":"creative","value":0.6,"confidence":0.7},{"name":"intellectual","value":0.6,"confidence":0.7},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.7,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.8},{"name":"long_term_goal","value":0.8,"confidence":0.9}]',
 '希望对方有相似的职业背景和生活节奏，本科以上学历。', 'SIMILAR', NOW(), NOW()),

-- 男 3: 王子涵 (26, 深圳, UI设计师)
(3, '在科技公司做UI设计，对美有执念。性格偏内向但熟了之后话很多。',
 26, 'MALE', '广东省 深圳市', 189,
 '[{"name":"extroversion","value":0.4,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.9},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.5,"confidence":0.6},{"name":"socialness","value":0.4,"confidence":0.8},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.7,"confidence":0.8},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.6,"confidence":0.7},{"name":"emotional_expressiveness","value":0.4,"confidence":0.7},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.7,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.8},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.7,"confidence":0.8},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.6,"confidence":0.7}]',
 '希望对方性格比我外向一些，能互补。对艺术有一定兴趣更好。', 'COMPLEMENTARY', NOW(), NOW()),

-- 男 4: 刘思远 (32, 杭州, 创业者)
(4, '在杭州创业做跨境电商，公司已经B轮了。每天早上六点跑步，喜欢滑雪和潜水。',
 32, 'MALE', '浙江省 杭州市', 76,
 '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.9,"confidence":0.9},{"name":"agreeableness","value":0.6,"confidence":0.6},{"name":"adventurousness","value":0.9,"confidence":0.9},{"name":"socialness","value":0.6,"confidence":0.7},{"name":"activity_level","value":0.9,"confidence":0.9},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.9,"confidence":0.9},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.4,"confidence":0.6},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.9,"confidence":0.9},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.6,"confidence":0.6},{"name":"openness_to_distance","value":0.6,"confidence":0.7},{"name":"long_term_goal","value":0.7,"confidence":0.8}]',
 '希望对方情绪稳定、有独立人格，理解创业的忙碌。', 'BALANCED', NOW(), NOW()),

-- 男 5: 陈天宇 (27, 成都, 独立摄影师)
(5, '自由摄影师，主要拍人像和城市风光。性格随和乐天派，会弹吉他，养了一只边境牧羊犬。',
 27, 'MALE', '四川省 成都市', 208,
 '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.8,"confidence":0.8},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.4,"confidence":0.6},{"name":"career_oriented","value":0.4,"confidence":0.6},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.5,"confidence":0.6},{"name":"long_term_goal","value":0.5,"confidence":0.6}]',
 '希望对方也有对生活的热情，不一定要爱冒险但不接受宅。', 'COMPLEMENTARY', NOW(), NOW()),

-- 男 6: 赵俊杰 (29, 广州, 数据分析师)
(6, '在大厂做数据分析，煲汤手艺一流，喜欢研究广式茶点。性格耐心温和。',
 29, 'MALE', '广东省 广州市', 187,
 '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.4,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.7},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.7,"confidence":0.8},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.4,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.9}]',
 '希望对方在广深地区，性格温和好沟通，有自己的事业和生活圈。', 'SIMILAR', NOW(), NOW()),

-- 男 7: 孙浩宇 (25, 南京, 中学教师)
(7, '在南京一所高中教语文，业余喜欢写文章给公众号供稿。',
 25, 'MALE', '江苏省 南京市', 63,
 '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.7},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.7,"confidence":0.8},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.7,"confidence":0.8},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.3,"confidence":0.7},{"name":"importance_values","value":0.9,"confidence":0.9},{"name":"importance_intelligence","value":0.8,"confidence":0.8},{"name":"openness_to_distance","value":0.2,"confidence":0.8},{"name":"long_term_goal","value":0.8,"confidence":0.9}]',
 '希望对方善良真诚，有书卷气，能一起逛书店。', 'BALANCED', NOW(), NOW()),

-- 男 8: 周文博 (31, 武汉, 医生)
(8, '武汉同济的骨科医生，喜欢种花养草，为人正直可靠。',
 31, 'MALE', '湖北省 武汉市', 156,
 '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.5,"confidence":0.6},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.4,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.6},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.8,"confidence":0.8},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.4,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.4,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.9,"confidence":0.9}]',
 '希望对方有稳定工作，能理解医生的工作节奏。', 'SIMILAR', NOW(), NOW()),

-- 男 9: 吴子轩 (24, 西安, 研究生)
(9, '在西交大读计算机研二，喜欢打篮球和玩主机游戏，性格幽默开朗。',
 24, 'MALE', '陕西省 西安市', 259,
 '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.8,"confidence":0.8},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.4,"confidence":0.6},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.4,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.7,"confidence":0.7},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.6,"confidence":0.6},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.6},{"name":"long_term_goal","value":0.4,"confidence":0.6}]',
 '希望对方年龄相仿，性格活泼开朗，聊得来最重要。', 'COMPLEMENTARY', NOW(), NOW()),

-- 男 10: 郑凯文 (33, 重庆, 律师)
(10, '在重庆做执业律师，性格直爽，不烟，应酬时少量饮酒。',
 33, 'MALE', '重庆市 重庆市', 4,
 '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.4,"confidence":0.6},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.3,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.8,"confidence":0.8},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.8}]',
 '希望对方性格直爽好相处，在重庆生活。', 'BALANCED', NOW(), NOW()),

-- 女 11: 李晓萱 (26, 北京, 市场经理)
(11, '在望京一家外企做市场，周末喜欢去胡同探店、逛咖啡馆。性格开朗独立。',
 26, 'FEMALE', '北京市 北京市', 1,
 '[{"name":"extroversion","value":0.8,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.7,"confidence":0.7},{"name":"socialness","value":0.8,"confidence":0.8},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.6,"confidence":0.7},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.6,"confidence":0.7}]',
 '希望对方在北京，175以上，有上进心和责任心。', 'BALANCED', NOW(), NOW()),

-- 女 12: 王语嫣 (28, 上海, 时尚设计师)
(12, '在一家独立设计师品牌工作，喜欢看展和手工皮具，养了一只布偶猫。',
 28, 'FEMALE', '上海市 上海市', 3,
 '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.6,"confidence":0.6},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.5,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.7,"confidence":0.7},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.7,"confidence":0.7},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.6,"confidence":0.7}]',
 '希望对方有审美有品位，成熟稳重，喜欢小动物加分。', 'COMPLEMENTARY', NOW(), NOW()),

-- 女 13: 张雨桐 (24, 深圳, 新媒体编辑)
(13, '在科技媒体做编辑，性格活泼话多，业余经营一个美食探店账号。',
 24, 'FEMALE', '广东省 深圳市', 189,
 '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.7,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.6,"confidence":0.6},{"name":"family_oriented","value":0.4,"confidence":0.6},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.7,"confidence":0.7},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.8,"confidence":0.8},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.7,"confidence":0.7},{"name":"importance_appearance","value":0.7,"confidence":0.7},{"name":"importance_values","value":0.6,"confidence":0.6},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.2,"confidence":0.8},{"name":"long_term_goal","value":0.5,"confidence":0.6}]',
 '希望对方也爱美食，性格开朗幽默，不接受异地。', 'SIMILAR', NOW(), NOW()),

-- 女 14: 刘诗涵 (30, 杭州, 钢琴教师)
(14, '音乐学院钢琴老师，性格安静温柔，喜欢读书和练字。',
 30, 'FEMALE', '浙江省 杭州市', 76,
 '[{"name":"extroversion","value":0.4,"confidence":0.7},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.4,"confidence":0.7},{"name":"activity_level","value":0.4,"confidence":0.6},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.4,"confidence":0.6},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.5,"confidence":0.6},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.9,"confidence":0.9},{"name":"importance_intelligence","value":0.7,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.8}]',
 '希望对方有绅士风度，有文化素养，成熟稳重。', 'BALANCED', NOW(), NOW()),

-- 女 15: 陈静怡 (27, 成都, 咖啡馆店主)
(15, '在锦里附近开了一家独立咖啡馆，自己烘豆子、做甜品。性格温暖随和。',
 27, 'FEMALE', '四川省 成都市', 208,
 '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.7,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.5,"confidence":0.6},{"name":"creative","value":0.8,"confidence":0.8},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.3,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.4,"confidence":0.6},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.5,"confidence":0.6}]',
 '希望对方性格阳光、热爱生活，喜欢户外活动加分。', 'COMPLEMENTARY', NOW(), NOW()),

-- 女 16: 赵梦婷 (29, 广州, 护士)
(16, '在广州三甲医院做护士，性格细心体贴，休息时喜欢做手工。',
 29, 'FEMALE', '广东省 广州市', 187,
 '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.4,"confidence":0.6},{"name":"agreeableness","value":0.9,"confidence":0.8},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.6},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.8,"confidence":0.8},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.4,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.5,"confidence":0.6},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.9}]',
 '希望对方在广州工作，有稳定收入，踏实靠谱。', 'SIMILAR', NOW(), NOW()),

-- 女 17: 孙悦然 (25, 南京, 文学研究生)
(17, '在南京大学读比较文学研三，准备继续读博。喜欢看书、写诗。',
 25, 'FEMALE', '江苏省 南京市', 63,
 '[{"name":"extroversion","value":0.3,"confidence":0.7},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.3,"confidence":0.7},{"name":"activity_level","value":0.3,"confidence":0.6},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.8,"confidence":0.8},{"name":"intellectual","value":0.9,"confidence":0.9},{"name":"emotional_expressiveness","value":0.4,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.4,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.4,"confidence":0.6},{"name":"importance_appearance","value":0.3,"confidence":0.6},{"name":"importance_values","value":0.9,"confidence":0.9},{"name":"importance_intelligence","value":0.9,"confidence":0.9},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.7,"confidence":0.8}]',
 '希望对方有学识有思想，能聊文学聊电影。', 'BALANCED', NOW(), NOW()),

-- 女 18: 周蕾 (31, 武汉, 注册会计师)
(18, '在武汉做审计，CPA持证。生活中大大咧咧，喜欢旅行和美食。',
 31, 'FEMALE', '湖北省 武汉市', 156,
 '[{"name":"extroversion","value":0.6,"confidence":0.7},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.6,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.5,"confidence":0.6},{"name":"long_term_goal","value":0.8,"confidence":0.8}]',
 '希望对方经济独立、思想成熟，在武汉或愿意来武汉。', 'COMPLEMENTARY', NOW(), NOW()),

-- 女 19: 吴欣怡 (23, 西安, 前端开发)
(19, '在西安做前端开发，喜欢二次元和cosplay，周末经常去漫展。',
 23, 'FEMALE', '陕西省 西安市', 259,
 '[{"name":"extroversion","value":0.8,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.6,"confidence":0.6},{"name":"family_oriented","value":0.3,"confidence":0.6},{"name":"career_oriented","value":0.5,"confidence":0.6},{"name":"creative","value":0.8,"confidence":0.8},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.8,"confidence":0.8},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.7,"confidence":0.7},{"name":"importance_appearance","value":0.6,"confidence":0.7},{"name":"importance_values","value":0.5,"confidence":0.6},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.3,"confidence":0.6}]',
 '希望对方也喜欢二次元，性格有趣，年龄24-30之间。', 'SIMILAR', NOW(), NOW()),

-- 女 20: 郑媛 (35, 重庆, 合伙律师)
(20, '重庆律所合伙人，主攻商事诉讼。事业型女性，也爱做饭和追剧。',
 35, 'FEMALE', '重庆市 重庆市', 4,
 '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.5,"confidence":0.6},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.4,"confidence":0.6},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.9,"confidence":0.9},{"name":"creative","value":0.4,"confidence":0.6},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.6,"confidence":0.7},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.9,"confidence":0.9},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.4,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.3,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.7,"confidence":0.7},{"name":"openness_to_distance","value":0.6,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.8}]',
 '希望对方成熟稳重，有事业心和格局，互相尊重。', 'BALANCED', NOW(), NOW());

-- ========== 5. 从 traits_summary 解析生成 user_traits ==========

INSERT INTO user_traits (profile_id, trait_name, trait_value, confidence, source_message_id)
SELECT
    p.id,
    JSON_UNQUOTE(JSON_EXTRACT(t.value, '$.name')),
    CAST(JSON_EXTRACT(t.value, '$.value') AS DECIMAL(5,4)),
    CAST(JSON_EXTRACT(t.value, '$.confidence') AS DECIMAL(5,4)),
    NULL
FROM profiles p
CROSS JOIN JSON_TABLE(p.traits_summary, '$[*]' COLUMNS (
    value JSON PATH '$'
)) t
WHERE p.id BETWEEN 1 AND 20;
