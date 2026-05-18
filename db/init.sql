-- ============================================================
-- Synchro 数据库初始化脚本（建表 + 完整测试数据）
-- ============================================================
-- 使用方法: docker compose exec -T mysql mysql -usynchro -psynchro_password synchro < db/init.sql
-- ============================================================
-- 测试数据包含:
--   - 20 个用户（10男10女），状态 ACTIVE，已开通匹配
--   - 20 份完整资料（含 bio/理想伴侣/traits_summary/匹配偏好/postOnboardingCompleted）
--   - 20 个 AI 访谈对话，每人 8 轮完整对话记录（共 ~340 条消息）
--   - 220 条 user_traits，带 source_message_id 指向访谈消息
--   - 1 条示例匹配记录（含 match_reason JSON 子分数）
--   - 34 省市区数据
--   - 测试登录密码: password123
-- ============================================================

-- ========== 0. 清理旧表 ==========

DROP TABLE IF EXISTS user_traits;
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS conversations;
DROP TABLE IF EXISTS matches;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS profiles;
DROP TABLE IF EXISTS cities;
DROP TABLE IF EXISTS provinces;
DROP TABLE IF EXISTS users;

-- ========== 1. 核心表结构 ==========

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
    post_onboarding_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

ALTER TABLE user_traits
    ADD CONSTRAINT fk_trait_source_message
    FOREIGN KEY (source_message_id) REFERENCES messages(id) ON DELETE SET NULL;

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

ALTER TABLE profiles
    ADD FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE SET NULL;

INSERT INTO provinces (id, name) VALUES
(1, '北京市'), (2, '天津市'), (3, '上海市'), (4, '重庆市'),
(5, '河北省'), (6, '山西省'), (7, '辽宁省'), (8, '吉林省'), (9, '黑龙江省'),
(10, '江苏省'), (11, '浙江省'), (12, '安徽省'), (13, '福建省'), (14, '江西省'),
(15, '山东省'), (16, '河南省'), (17, '湖北省'), (18, '湖南省'), (19, '广东省'),
(20, '海南省'), (21, '四川省'), (22, '贵州省'), (23, '云南省'), (24, '陕西省'),
(25, '甘肃省'), (26, '青海省'), (27, '台湾省'), (28, '内蒙古自治区'),
(29, '广西壮族自治区'), (30, '西藏自治区'), (31, '宁夏回族自治区'),
(32, '新疆维吾尔自治区'), (33, '香港特别行政区'), (34, '澳门特别行政区');

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
-- 密码均为: password123
-- BCrypt: $2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu

INSERT INTO users (id, email, password_hash, nickname, avatar_url, status, onboarding_completed, matching_opt_in, created_at, updated_at) VALUES
(1,  'test1@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '张明远', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-01 10:00:00', '2026-05-01 10:30:00'),
(2,  'test2@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '李浩然', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-01 11:00:00', '2026-05-01 11:30:00'),
(3,  'test3@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '王子涵', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-01 12:00:00', '2026-05-01 12:30:00'),
(4,  'test4@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '刘思远', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-02 09:00:00', '2026-05-02 09:30:00'),
(5,  'test5@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '陈天宇', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-02 10:00:00', '2026-05-02 10:30:00'),
(6,  'test6@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '赵俊杰', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-02 11:00:00', '2026-05-02 11:30:00'),
(7,  'test7@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '孙浩宇', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-02 12:00:00', '2026-05-02 12:30:00'),
(8,  'test8@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '周文博', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-03 09:00:00', '2026-05-03 09:30:00'),
(9,  'test9@synchro.com',  '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '吴子轩', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-03 10:00:00', '2026-05-03 10:30:00'),
(10, 'test10@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '郑凯文', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-03 11:00:00', '2026-05-03 11:30:00'),
(11, 'test11@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '李晓萱', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-04 09:00:00', '2026-05-04 09:30:00'),
(12, 'test12@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '王语嫣', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-04 10:00:00', '2026-05-04 10:30:00'),
(13, 'test13@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '张雨桐', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-04 11:00:00', '2026-05-04 11:30:00'),
(14, 'test14@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '刘诗涵', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-04 12:00:00', '2026-05-04 12:30:00'),
(15, 'test15@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '陈静怡', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-05 09:00:00', '2026-05-05 09:30:00'),
(16, 'test16@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '赵梦婷', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-05 10:00:00', '2026-05-05 10:30:00'),
(17, 'test17@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '孙悦然', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-05 11:00:00', '2026-05-05 11:30:00'),
(18, 'test18@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '周蕾',   NULL, 'ACTIVE', TRUE, TRUE, '2026-05-05 12:00:00', '2026-05-05 12:30:00'),
(19, 'test19@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '吴欣怡', NULL, 'ACTIVE', TRUE, TRUE, '2026-05-06 09:00:00', '2026-05-06 09:30:00'),
(20, 'test20@synchro.com', '$2a$10$JfBzYCQ.2EdBEc1vsrJGkO3XTnV4tSkLTLqFddAVhhcKIQrmrjvDu', '郑媛',   NULL, 'ACTIVE', TRUE, TRUE, '2026-05-06 10:00:00', '2026-05-06 10:30:00');

-- ========== 4. 20 个用户资料 ==========

INSERT INTO profiles (id, user_id, bio, age, gender, location, city_id, traits_summary, ideal_partner_description, matching_preference, post_onboarding_completed, created_at, updated_at) VALUES
(1,  1,  '在一家互联网公司做后端开发，代码写累了就背着相机去京郊爬山。周末喜欢约朋友打羽毛球，偶尔在家研究咖啡拉花。养了一只橘猫叫火锅。', 28, 'MALE', '北京市 北京市', 1, '[{"name":"extroversion","value":0.6,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.8},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.8,"confidence":0.9},{"name":"socialness","value":0.6,"confidence":0.8},{"name":"activity_level","value":0.7,"confidence":0.8},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.6,"confidence":0.6},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.6,"confidence":0.7},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.8},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.9},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.2,"confidence":0.9},{"name":"long_term_goal","value":0.7,"confidence":0.8}]', '希望对方性格开朗，有自己热爱的事情。坐标北京，不接受异地。', 'BALANCED', TRUE, '2026-05-01 10:30:00', '2026-05-01 10:30:00'),
(2,  2,  '在陆家嘴做金融产品，工作日西装革履，周末最爱穿T恤逛菜市场。喜欢做饭，拿手菜是红烧肉和糖醋排骨。每周坚持健身三次。', 30, 'MALE', '上海市 上海市', 3, '[{"name":"extroversion","value":0.6,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.5,"confidence":0.6},{"name":"socialness","value":0.6,"confidence":0.7},{"name":"activity_level","value":0.8,"confidence":0.8},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.8,"confidence":0.9},{"name":"creative","value":0.6,"confidence":0.7},{"name":"intellectual","value":0.6,"confidence":0.7},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.7,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.8},{"name":"long_term_goal","value":0.8,"confidence":0.9}]', '希望对方有相似的职业背景和生活节奏，本科以上学历。', 'SIMILAR', TRUE, '2026-05-01 11:30:00', '2026-05-01 11:30:00'),
(3,  3,  '在科技公司做UI设计，对美有执念。性格偏内向但熟了之后话很多。喜欢逛美术馆和独立书店，最近在学陶艺。', 26, 'MALE', '广东省 深圳市', 189, '[{"name":"extroversion","value":0.4,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.9},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.5,"confidence":0.6},{"name":"socialness","value":0.4,"confidence":0.8},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.7,"confidence":0.8},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.6,"confidence":0.7},{"name":"emotional_expressiveness","value":0.4,"confidence":0.7},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.7,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.8},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.7,"confidence":0.8},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.6,"confidence":0.7}]', '希望对方性格比我外向一些，能互补。对艺术有一定兴趣更好。', 'COMPLEMENTARY', TRUE, '2026-05-01 12:30:00', '2026-05-01 12:30:00'),
(4,  4,  '在杭州创业做跨境电商，公司已经B轮了。每天早上六点跑步，喜欢滑雪和潜水。一年至少去两个没去过的国家。', 32, 'MALE', '浙江省 杭州市', 76, '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.9,"confidence":0.9},{"name":"agreeableness","value":0.6,"confidence":0.6},{"name":"adventurousness","value":0.9,"confidence":0.9},{"name":"socialness","value":0.6,"confidence":0.7},{"name":"activity_level","value":0.9,"confidence":0.9},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.9,"confidence":0.9},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.4,"confidence":0.6},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.9,"confidence":0.9},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.6,"confidence":0.6},{"name":"openness_to_distance","value":0.6,"confidence":0.7},{"name":"long_term_goal","value":0.7,"confidence":0.8}]', '希望对方情绪稳定、有独立人格，理解创业的忙碌。', 'BALANCED', TRUE, '2026-05-02 09:30:00', '2026-05-02 09:30:00'),
(5,  5,  '自由摄影师，主要拍人像和城市风光。性格随和乐天派，会弹吉他，养了一只边境牧羊犬叫小七。', 27, 'MALE', '四川省 成都市', 208, '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.8,"confidence":0.8},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.4,"confidence":0.6},{"name":"career_oriented","value":0.4,"confidence":0.6},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.5,"confidence":0.6},{"name":"long_term_goal","value":0.5,"confidence":0.6}]', '希望对方也有对生活的热情，不一定要爱冒险但不接受宅。', 'COMPLEMENTARY', TRUE, '2026-05-02 10:30:00', '2026-05-02 10:30:00'),
(6,  6,  '在大厂做数据分析，煲汤手艺一流，喜欢研究广式茶点。性格耐心温和，周末喜欢去东山口逛市集。', 29, 'MALE', '广东省 广州市', 187, '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.4,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.7},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.7,"confidence":0.8},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.4,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.9}]', '希望对方在广深地区，性格温和好沟通，有自己的事业和生活圈。', 'SIMILAR', TRUE, '2026-05-02 11:30:00', '2026-05-02 11:30:00'),
(7,  7,  '在南京一所高中教语文，业余喜欢写文章给公众号供稿。性格温和有耐心，喜欢有书卷气的周末。', 25, 'MALE', '江苏省 南京市', 63, '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.7},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.7,"confidence":0.8},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.7,"confidence":0.8},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.3,"confidence":0.7},{"name":"importance_values","value":0.9,"confidence":0.9},{"name":"importance_intelligence","value":0.8,"confidence":0.8},{"name":"openness_to_distance","value":0.2,"confidence":0.8},{"name":"long_term_goal","value":0.8,"confidence":0.9}]', '希望对方善良真诚，有书卷气，能一起逛书店看展。', 'BALANCED', TRUE, '2026-05-02 12:30:00', '2026-05-02 12:30:00'),
(8,  8,  '武汉同济的骨科医生，喜欢种花养草，阳台上养了二十多盆多肉。为人正直可靠，对待病人有耐心。', 31, 'MALE', '湖北省 武汉市', 156, '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.5,"confidence":0.6},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.4,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.6},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.8,"confidence":0.8},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.4,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.4,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.9,"confidence":0.9}]', '希望对方有稳定工作，能理解医生的工作节奏。在武汉生活。', 'SIMILAR', TRUE, '2026-05-03 09:30:00', '2026-05-03 09:30:00'),
(9,  9,  '在西交大读计算机研二，喜欢打篮球和玩主机游戏，性格幽默开朗，实验室的开心果。', 24, 'MALE', '陕西省 西安市', 259, '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.8,"confidence":0.8},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.4,"confidence":0.6},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.4,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.7,"confidence":0.7},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.6,"confidence":0.6},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.6},{"name":"long_term_goal","value":0.4,"confidence":0.6}]', '希望对方年龄相仿，性格活泼开朗，聊得来最重要。', 'COMPLEMENTARY', TRUE, '2026-05-03 10:30:00', '2026-05-03 10:30:00'),
(10, 10, '在重庆做执业律师，主攻民商事诉讼。性格直爽，做事雷厉风行，不烟，应酬时少量饮酒。', 33, 'MALE', '重庆市 重庆市', 4, '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.4,"confidence":0.6},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.3,"confidence":0.6},{"name":"intellectual","value":0.7,"confidence":0.7},{"name":"emotional_expressiveness","value":0.8,"confidence":0.8},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.5,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.8}]', '希望对方性格直爽好相处，在重庆生活。互相尊重各自的事业。', 'BALANCED', TRUE, '2026-05-03 11:30:00', '2026-05-03 11:30:00'),
(11, 11, '在望京一家外企做市场，周末喜欢去胡同探店、逛咖啡馆。性格开朗独立，喜欢旅行和看展。', 26, 'FEMALE', '北京市 北京市', 1, '[{"name":"extroversion","value":0.8,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.7,"confidence":0.7},{"name":"socialness","value":0.8,"confidence":0.8},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.6,"confidence":0.7},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.6,"confidence":0.7}]', '希望对方在北京，175以上，有上进心和责任心。幽默加分。', 'BALANCED', TRUE, '2026-05-04 09:30:00', '2026-05-04 09:30:00'),
(12, 12, '在一家独立设计师品牌工作，喜欢看展和手工皮具，养了一只布偶猫叫云朵。对色彩和质感很敏感。', 28, 'FEMALE', '上海市 上海市', 3, '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.6,"confidence":0.6},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.5,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.7,"confidence":0.7},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.8,"confidence":0.8},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.7,"confidence":0.7},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.6,"confidence":0.7}]', '希望对方有审美有品位，成熟稳重，喜欢小动物加分。', 'COMPLEMENTARY', TRUE, '2026-05-04 10:30:00', '2026-05-04 10:30:00'),
(13, 13, '在科技媒体做编辑，性格活泼话多，业余经营一个美食探店账号。喜欢尝试各种新餐厅。', 24, 'FEMALE', '广东省 深圳市', 189, '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.7,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.6,"confidence":0.6},{"name":"family_oriented","value":0.4,"confidence":0.6},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.7,"confidence":0.7},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.8,"confidence":0.8},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.7,"confidence":0.7},{"name":"importance_appearance","value":0.7,"confidence":0.7},{"name":"importance_values","value":0.6,"confidence":0.6},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.2,"confidence":0.8},{"name":"long_term_goal","value":0.5,"confidence":0.6}]', '希望对方也爱美食，性格开朗幽默，不接受异地，在深圳优先。', 'SIMILAR', TRUE, '2026-05-04 11:30:00', '2026-05-04 11:30:00'),
(14, 14, '音乐学院钢琴老师，性格安静温柔，喜欢读书和练字。周末会去听音乐会或在家烤面包。', 30, 'FEMALE', '浙江省 杭州市', 76, '[{"name":"extroversion","value":0.4,"confidence":0.7},{"name":"openness","value":0.6,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.4,"confidence":0.7},{"name":"activity_level","value":0.4,"confidence":0.6},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.6,"confidence":0.7},{"name":"creative","value":0.9,"confidence":0.9},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.4,"confidence":0.6},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.5,"confidence":0.6},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.9,"confidence":0.9},{"name":"importance_intelligence","value":0.7,"confidence":0.7},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.8}]', '希望对方有绅士风度，有文化素养，成熟稳重。在杭州生活。', 'BALANCED', TRUE, '2026-05-04 12:30:00', '2026-05-04 12:30:00'),
(15, 15, '在锦里附近开了一家独立咖啡馆，自己烘豆子、做甜品。性格温暖随和，喜欢听民谣。', 27, 'FEMALE', '四川省 成都市', 208, '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.8,"confidence":0.8},{"name":"adventurousness","value":0.7,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.5,"confidence":0.6},{"name":"creative","value":0.8,"confidence":0.8},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.7,"confidence":0.7},{"name":"conflict_avoidant","value":0.6,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.6,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.7,"confidence":0.7},{"name":"partner_social_pref","value":0.6,"confidence":0.7},{"name":"importance_appearance","value":0.3,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.4,"confidence":0.6},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.5,"confidence":0.6}]', '希望对方性格阳光、热爱生活，喜欢户外活动加分。成都一起喝咖啡！', 'COMPLEMENTARY', TRUE, '2026-05-05 09:30:00', '2026-05-05 09:30:00'),
(16, 16, '在广州三甲医院做护士，性格细心体贴，休息时喜欢做手工和织毛线。养了两只虎斑猫。', 29, 'FEMALE', '广东省 广州市', 187, '[{"name":"extroversion","value":0.5,"confidence":0.7},{"name":"openness","value":0.4,"confidence":0.6},{"name":"agreeableness","value":0.9,"confidence":0.8},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.5,"confidence":0.6},{"name":"activity_level","value":0.5,"confidence":0.6},{"name":"romantic","value":0.6,"confidence":0.7},{"name":"family_oriented","value":0.8,"confidence":0.8},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.4,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.7,"confidence":0.7},{"name":"independence","value":0.5,"confidence":0.6},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.9}]', '希望对方在广州工作，有稳定收入，踏实靠谱。不烟不酒加分。', 'SIMILAR', TRUE, '2026-05-05 10:30:00', '2026-05-05 10:30:00'),
(17, 17, '在南京大学读比较文学研三，准备继续读博。喜欢看书、写诗、逛旧书店。偏内向但思想很丰富。', 25, 'FEMALE', '江苏省 南京市', 63, '[{"name":"extroversion","value":0.3,"confidence":0.7},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.3,"confidence":0.6},{"name":"socialness","value":0.3,"confidence":0.7},{"name":"activity_level","value":0.3,"confidence":0.6},{"name":"romantic","value":0.8,"confidence":0.8},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.7,"confidence":0.7},{"name":"creative","value":0.8,"confidence":0.8},{"name":"intellectual","value":0.9,"confidence":0.9},{"name":"emotional_expressiveness","value":0.4,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.4,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.3,"confidence":0.6},{"name":"partner_social_pref","value":0.4,"confidence":0.6},{"name":"importance_appearance","value":0.3,"confidence":0.6},{"name":"importance_values","value":0.9,"confidence":0.9},{"name":"importance_intelligence","value":0.9,"confidence":0.9},{"name":"openness_to_distance","value":0.3,"confidence":0.7},{"name":"long_term_goal","value":0.7,"confidence":0.8}]', '希望对方有学识有思想，能聊文学聊电影。可以一起逛书店。', 'BALANCED', TRUE, '2026-05-05 11:30:00', '2026-05-05 11:30:00'),
(18, 18, '在武汉做审计，CPA持证。生活中大大咧咧，喜欢旅行和美食，每年至少两次长途旅行。', 31, 'FEMALE', '湖北省 武汉市', 156, '[{"name":"extroversion","value":0.6,"confidence":0.7},{"name":"openness","value":0.7,"confidence":0.7},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.6,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.5,"confidence":0.6},{"name":"family_oriented","value":0.6,"confidence":0.7},{"name":"career_oriented","value":0.8,"confidence":0.8},{"name":"creative","value":0.5,"confidence":0.6},{"name":"intellectual","value":0.6,"confidence":0.6},{"name":"emotional_expressiveness","value":0.5,"confidence":0.6},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.7,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.5,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.4,"confidence":0.6},{"name":"importance_values","value":0.7,"confidence":0.7},{"name":"importance_intelligence","value":0.6,"confidence":0.7},{"name":"openness_to_distance","value":0.5,"confidence":0.6},{"name":"long_term_goal","value":0.8,"confidence":0.8}]', '希望对方经济独立、思想成熟，在武汉或愿意来武汉。最好也喜欢旅行。', 'COMPLEMENTARY', TRUE, '2026-05-05 12:30:00', '2026-05-05 12:30:00'),
(19, 19, '在西安做前端开发，喜欢二次元和cosplay，周末经常去漫展。性格活泼可爱，笑点很低。', 23, 'FEMALE', '陕西省 西安市', 259, '[{"name":"extroversion","value":0.8,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.6,"confidence":0.7},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.7,"confidence":0.7},{"name":"romantic","value":0.6,"confidence":0.6},{"name":"family_oriented","value":0.3,"confidence":0.6},{"name":"career_oriented","value":0.5,"confidence":0.6},{"name":"creative","value":0.8,"confidence":0.8},{"name":"intellectual","value":0.5,"confidence":0.6},{"name":"emotional_expressiveness","value":0.8,"confidence":0.8},{"name":"conflict_avoidant","value":0.4,"confidence":0.6},{"name":"independence","value":0.6,"confidence":0.7},{"name":"partner_extroversion_pref","value":0.7,"confidence":0.7},{"name":"partner_adventurous_pref","value":0.6,"confidence":0.7},{"name":"partner_social_pref","value":0.7,"confidence":0.7},{"name":"importance_appearance","value":0.6,"confidence":0.7},{"name":"importance_values","value":0.5,"confidence":0.6},{"name":"importance_intelligence","value":0.5,"confidence":0.6},{"name":"openness_to_distance","value":0.4,"confidence":0.6},{"name":"long_term_goal","value":0.3,"confidence":0.6}]', '希望对方也喜欢二次元，性格有趣，年龄24-30之间。打游戏加分！', 'SIMILAR', TRUE, '2026-05-06 09:30:00', '2026-05-06 09:30:00'),
(20, 20, '重庆律所合伙人，主攻商事诉讼。事业型女性，同时也爱做饭和追剧。每年必去看一场话剧。', 35, 'FEMALE', '重庆市 重庆市', 4, '[{"name":"extroversion","value":0.7,"confidence":0.8},{"name":"openness","value":0.8,"confidence":0.8},{"name":"agreeableness","value":0.7,"confidence":0.7},{"name":"adventurousness","value":0.5,"confidence":0.6},{"name":"socialness","value":0.7,"confidence":0.7},{"name":"activity_level","value":0.6,"confidence":0.7},{"name":"romantic","value":0.4,"confidence":0.6},{"name":"family_oriented","value":0.5,"confidence":0.6},{"name":"career_oriented","value":0.9,"confidence":0.9},{"name":"creative","value":0.4,"confidence":0.6},{"name":"intellectual","value":0.8,"confidence":0.8},{"name":"emotional_expressiveness","value":0.6,"confidence":0.7},{"name":"conflict_avoidant","value":0.5,"confidence":0.6},{"name":"independence","value":0.9,"confidence":0.9},{"name":"partner_extroversion_pref","value":0.5,"confidence":0.6},{"name":"partner_adventurous_pref","value":0.4,"confidence":0.6},{"name":"partner_social_pref","value":0.5,"confidence":0.6},{"name":"importance_appearance","value":0.3,"confidence":0.6},{"name":"importance_values","value":0.8,"confidence":0.8},{"name":"importance_intelligence","value":0.7,"confidence":0.7},{"name":"openness_to_distance","value":0.6,"confidence":0.7},{"name":"long_term_goal","value":0.8,"confidence":0.8}]', '希望对方成熟稳重，有事业心和格局，互相尊重。在重庆优先。', 'BALANCED', TRUE, '2026-05-06 10:30:00', '2026-05-06 10:30:00');

-- ========== 5. AI 访谈对话记录 ==========
-- 每人一个 ONBOARDING 对话，状态 COMPLETED，共 8 轮交流
-- 消息 ID 为连续自增，后续 user_traits 的 source_message_id 指向 AI 消息

INSERT INTO conversations (id, user_id, conversation_type, participant_id, match_id, title, status, created_at, updated_at) VALUES
(1,  1,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-01 10:00:00', '2026-05-01 10:25:00'),
(2,  2,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-01 11:00:00', '2026-05-01 11:25:00'),
(3,  3,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-01 12:00:00', '2026-05-01 12:25:00'),
(4,  4,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-02 09:00:00', '2026-05-02 09:25:00'),
(5,  5,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-02 10:00:00', '2026-05-02 10:25:00'),
(6,  6,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-02 11:00:00', '2026-05-02 11:25:00'),
(7,  7,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-02 12:00:00', '2026-05-02 12:25:00'),
(8,  8,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-03 09:00:00', '2026-05-03 09:25:00'),
(9,  9,  'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-03 10:00:00', '2026-05-03 10:25:00'),
(10, 10, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-03 11:00:00', '2026-05-03 11:25:00'),
(11, 11, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-04 09:00:00', '2026-05-04 09:25:00'),
(12, 12, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-04 10:00:00', '2026-05-04 10:25:00'),
(13, 13, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-04 11:00:00', '2026-05-04 11:25:00'),
(14, 14, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-04 12:00:00', '2026-05-04 12:25:00'),
(15, 15, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-05 09:00:00', '2026-05-05 09:25:00'),
(16, 16, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-05 10:00:00', '2026-05-05 10:25:00'),
(17, 17, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-05 11:00:00', '2026-05-05 11:25:00'),
(18, 18, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-05 12:00:00', '2026-05-05 12:25:00'),
(19, 19, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-06 09:00:00', '2026-05-06 09:25:00'),
(20, 20, 'ONBOARDING', NULL, NULL, 'AI 性格访谈', 'COMPLETED', '2026-05-06 10:00:00', '2026-05-06 10:25:00');

-- ========== 6. AI 访谈消息（每人 17 条，共 340 条） ==========
-- 消息 ID 显式指定，便于 user_traits 引用
-- 格式: id, conversation_id, sender_id, sender_type, content, metadata, is_ai_processed, is_read, created_at

INSERT INTO messages (id, conversation_id, sender_id, sender_type, content, metadata, is_ai_processed, is_read, created_at) VALUES

-- ======== 用户 1: 张明远 (28, 北京, 后端开发) ========
(1,   1, 1, 'AI', '嗨张明远！我是你的交友助手~ 很高兴认识你！😊 想先了解一下，你平时工作之余最喜欢做什么？周末一般怎么过？', NULL, FALSE, FALSE, '2026-05-01 10:00:30'),
(2,   1, 1, 'USER', '平时下班后会去健身房或者约朋友打羽毛球，周末最喜欢背着相机去京郊爬山，北京的秋天山色特别美。家里还养了一只橘猫叫火锅，每天回家撸猫是最治愈的时刻。', NULL, FALSE, FALSE, '2026-05-01 10:01:30'),
(3,   1, 1, 'AI', '爬山、摄影、撸猫、打羽毛球……你的生活好丰富啊！感觉你是个热爱生活也享受独处时光的人。那你觉得自己性格是怎样的？朋友一般怎么形容你？', '{"extractedTraits":["adventurousness","activity_level","independence"]}', FALSE, FALSE, '2026-05-01 10:02:00'),
(4,   1, 1, 'USER', '朋友们说我挺随和的，不过熟了之后话比较多。我算是外向但也不是特别社交型，跟兴趣相投的人在一起比较放得开。平时做事有自己的主意，不太喜欢被人安排。', NULL, FALSE, FALSE, '2026-05-01 10:04:30'),
(5,   1, 1, 'AI', '了解~ 随和但有主见，这种性格很吸引人呢。那在社交方面呢？你是喜欢热闹的聚会还是偏向小圈子的深度交流？朋友在你生活中扮演什么角色？', '{"extractedTraits":["extroversion","agreeableness","openness"]}', FALSE, FALSE, '2026-05-01 10:05:00'),
(6,   1, 1, 'USER', '我更喜欢小圈子的深度交流，不是那种大聚会的类型。有几个认识了十几年的铁哥们，我们会一起出去旅行。朋友对我来说是生活中很重要的一部分，可以分享快乐也能一起消化烦恼。', NULL, FALSE, FALSE, '2026-05-01 10:07:30'),
(7,   1, 1, 'AI', '有几个铁哥们是很幸福的事！那聊聊恋爱观吧~ 你理想中的另一半是什么样的？有哪些特质是必须的，有没有什么雷区？', '{"extractedTraits":["socialness","family_oriented"]}', FALSE, FALSE, '2026-05-01 10:08:00'),
(8,   1, 1, 'USER', '我希望她性格开朗，有自己热爱的事情很重要，不管是工作还是爱好。必须在北京，异地太难坚持了。比较看重三观一致，长相身材倒没那么高的要求。不太能接受太情绪化的，遇到事情能理性沟通。', NULL, FALSE, FALSE, '2026-05-01 10:10:30'),
(9,   1, 1, 'AI', '三观一致确实比外表更重要！那再聊聊你对未来的规划吧~ 人生中最重要的是什么？对婚姻和长期关系有什么看法？', '{"extractedTraits":["partner_extroversion_pref","partner_adventurous_pref","importance_values","openness_to_distance","importance_appearance"]}', FALSE, FALSE, '2026-05-01 10:11:00'),
(10,  1, 1, 'USER', '我觉得人生最重要的还是过得开心有意义吧，家庭和事业都要兼顾。对婚姻我是认真的态度，希望能在两年内找到合适的伴侣稳定下来。事业上我也还在持续学习提升。', NULL, FALSE, FALSE, '2026-05-01 10:13:30'),
(11,  1, 1, 'AI', '兼顾家庭和事业、对未来有清晰规划，这种稳重的态度很加分！那聊聊情感方面~ 谈恋爱时你需要什么样的情感支持？喜欢每天聊天还是保持一定的独立空间？', '{"extractedTraits":["career_oriented","romantic","long_term_goal"]}', FALSE, FALSE, '2026-05-01 10:14:00'),
(12,  1, 1, 'USER', '我希望对方是能互相支持共同成长的关系。平时工作忙的时候不用每天腻在一起，但重要的时刻一定要在。沟通很重要，有什么问题直接说出来而不是让人猜。', NULL, FALSE, FALSE, '2026-05-01 10:16:30'),
(13,  1, 1, 'AI', '真诚直接的沟通太重要了！那再聊一个有趣的话题~ 你有过什么印象很深的旅行或冒险经历吗？', '{"extractedTraits":["emotional_expressiveness","conflict_avoidant","intellectual"]}', FALSE, FALSE, '2026-05-01 10:17:00'),
(14,  1, 1, 'USER', '去年国庆自驾去了川西，一个人开了两千多公里。在稻城亚丁看到雪山的那个瞬间，真的觉得所有的疲惫都值得了。平时也喜欢研究咖啡，从选豆到拉花都自己来，算是生活里的小仪式感吧。', NULL, FALSE, FALSE, '2026-05-01 10:19:30'),
(15,  1, 1, 'AI', '一个人自驾川西！这份独立和冒险精神真的让人佩服。咖啡拉花也是需要耐心的手艺活。那你对未来的生活方式有什么想象？理想中的生活是什么样？', '{"extractedTraits":["creative","partner_social_pref","importance_intelligence"]}', FALSE, FALSE, '2026-05-01 10:20:00'),
(16,  1, 1, 'USER', '理想的生活就是两个人一起做喜欢的事吧。周末一起去爬山拍照，然后回家一起做饭，晚上窝在沙发上看电影。不用多么轰轰烈烈，能够在平凡的日子里互相陪伴。', NULL, FALSE, FALSE, '2026-05-01 10:22:30'),
(17,  1, 1, 'AI', '感谢你的分享，我真的很享受这次交流！🌿 让我给你整理一下我的印象：你是一个热爱户外、独立自主但又不失温和的人，喜欢深度交流胜过热闹社交，对伴侣看重价值观和真诚沟通，希望找一个开朗独立、在北京一起认真生活的她。带着一只叫火锅的橘猫~ 我会把这些信息整理好，祝你早日遇到最合适的那个人！', NULL, FALSE, FALSE, '2026-05-01 10:23:00'),

-- ======== 用户 2: 李浩然 (30, 上海, 金融产品经理) ========
(18,  2, 2, 'AI', '嗨李浩然！我是你的交友助手~ 很高兴认识你！😊 想先了解一下，你平时工作之余最喜欢做什么？', NULL, FALSE, FALSE, '2026-05-01 11:00:30'),
(19,  2, 2, 'USER', '工作日比较忙，但周末我一定要自己做饭。红烧肉和糖醋排骨是我的拿手菜，每次做完发朋友圈都会被赞爆。每周坚持健身三次，已经坚持两年多了。', NULL, FALSE, FALSE, '2026-05-01 11:01:30'),
(20,  2, 2, 'AI', '会做饭还坚持健身，这个自控力真的强！在陆家嘴那种快节奏下还能保持生活品质不容易。那你觉得自己性格是什么样的？', '{"extractedTraits":["activity_level","independence","career_oriented"]}', FALSE, FALSE, '2026-05-01 11:02:00'),
(21,  2, 2, 'USER', '我觉得自己算是目标明确、执行力比较强。工作上要处理复杂的产品需求，习惯了一步一步拆解问题。但生活中我也挺随性的，周末穿T恤逛菜市场比穿西装舒服多了。', NULL, FALSE, FALSE, '2026-05-01 11:04:30'),
(22,  2, 2, 'AI', '工作和生活能切换自如，这种平衡感很棒。那社交方面呢？你觉得社交对你意味着什么？', '{"extractedTraits":["extroversion","openness","agreeableness"]}', FALSE, FALSE, '2026-05-01 11:05:00'),
(23,  2, 2, 'USER', '我社交不算多也不算少，更喜欢有质量的交流。平时工作应酬不少，但真正的好朋友也就那么几个。我算是能聊但不会主动组织的那种人。', NULL, FALSE, FALSE, '2026-05-01 11:07:30'),
(24,  2, 2, 'AI', '理解~ 那聊聊你对另一半的期待吧！你理想中的伴侣是什么样的？', '{"extractedTraits":["socialness","romantic"]}', FALSE, FALSE, '2026-05-01 11:08:00'),
(25,  2, 2, 'USER', '我希望她有相似的教育背景，本科以上吧，这样沟通在一个频道上。职业上比较欣赏有自己的事业规划的女生，最好是上海本地的或者在周边。性格上不要太作，能够独立的。', NULL, FALSE, FALSE, '2026-05-01 11:10:30'),
(26,  2, 2, 'AI', '门当户对这个观念在上海确实挺重要的。那你对未来的人生有什么规划？三五年内最想实现什么？', '{"extractedTraits":["partner_extroversion_pref","importance_intelligence","openness_to_distance","importance_values"]}', FALSE, FALSE, '2026-05-01 11:11:00'),
(27,  2, 2, 'USER', '三年内希望能升到VP吧，职业上一直在往这个方向努力。感情上希望遇到一个合适的人，一起在上海扎根。我觉得事业和感情是相辅相成的，有了稳定的家庭才能更有动力去拼事业。', NULL, FALSE, FALSE, '2026-05-01 11:13:30'),
(28,  2, 2, 'AI', '事业和家庭互相成就，这个理念很成熟！那在感情中你比较看重什么？外表、性格、才华、还是其他？', '{"extractedTraits":["family_oriented","long_term_goal"]}', FALSE, FALSE, '2026-05-01 11:14:00'),
(29,  2, 2, 'USER', '说实话外表会有一定要求，但更重要的是性格和价值观。两个人能不能聊到一起去，遇到问题能不能理性解决，比长得好不好看重要多了。当然有才华也很加分。', NULL, FALSE, FALSE, '2026-05-01 11:16:30'),
(30,  2, 2, 'AI', '理性务实又懂得欣赏，这种成熟的态度很好。那你喜欢什么样的相处模式？每天联系还是保持独立空间？', '{"extractedTraits":["importance_appearance","partner_adventurous_pref","importance_intelligence"]}', FALSE, FALSE, '2026-05-01 11:17:00'),
(31,  2, 2, 'USER', '平时工作忙的时候各自忙，但晚上睡前聊一聊这一天的经历就很好。周末能一起做饭、看剧，偶尔去旅行。我觉得最好的关系就是两个人都在变好。', NULL, FALSE, FALSE, '2026-05-01 11:19:30'),
(32,  2, 2, 'AI', '那做饭这件事会是你展示心意的一种方式吗？比如说会给喜欢的人做拿手菜？', '{"extractedTraits":["emotional_expressiveness","creative","adventurousness"]}', FALSE, FALSE, '2026-05-01 11:20:00'),
(33,  2, 2, 'USER', '哈哈会的！我觉得做饭给喜欢的人吃是一件很有成就感的事。上次朋友聚会我做了红烧肉，他们都说是上海最好吃的家常版哈哈。如果以后另一半也喜欢做饭，那我们可以在厨房里一起折腾。', NULL, FALSE, FALSE, '2026-05-01 11:22:30'),
(34,  2, 2, 'AI', '感谢你分享这么多！🌿 让我梳理一下对你的印象：你是一个目标感强、生活有品质感的金融人，能自律也能放松，喜欢做事而非空谈。你期待一位学历背景相当、独立有事业心、能一起在上海认真生活的她。而且你会做红烧肉——这可是一个超强加分项！祝你在寻爱的路上遇到懂你的人。', NULL, FALSE, FALSE, '2026-05-01 11:23:00'),

-- ======== 用户 3: 王子涵 (26, 深圳, UI设计师) ========
(35,  3, 3, 'AI', '嗨王子涵！我是你的交友助手~ 很高兴认识你！😊 先从兴趣爱好开始吧——作为设计师，平时除了工作还喜欢做什么？', NULL, FALSE, FALSE, '2026-05-01 12:00:30'),
(36,  3, 3, 'USER', '我经常去逛美术馆和独立书店，深圳的华侨城那边有很多不错的展览。最近在学陶艺，周末会去工作室捏泥巴。一个人待着做自己喜欢的事其实挺享受的。', NULL, FALSE, FALSE, '2026-05-01 12:01:30'),
(37,  3, 3, 'AI', '逛美术馆、学陶艺……你的生活有种安静的文艺感。那你觉得自己是什么性格？会是比较内向的类型吗？', '{"extractedTraits":["creative","openness","adventurousness"]}', FALSE, FALSE, '2026-05-01 12:02:00'),
(38,  3, 3, 'USER', '对，我是偏内向的，不太擅长也不太喜欢大场合的社交。但是熟了之后话其实挺多的，只是需要时间。很多人第一眼见我觉得我很高冷，其实熟了就知道我挺随和的。', NULL, FALSE, FALSE, '2026-05-01 12:04:30'),
(39,  3, 3, 'AI', '慢热但随和，这种性格其实很有魅力！那在关系中，你是哪种依恋风格呢？比如安全感强还是容易焦虑？', '{"extractedTraits":["extroversion","socialness","agreeableness"]}', FALSE, FALSE, '2026-05-01 12:05:00'),
(40,  3, 3, 'USER', '我觉得自己还算安全型吧，不会太粘人也不会太疏离。但我需要一个能让我信任的人，如果对方忽冷忽热我就比较容易退缩。发生矛盾的话我不太喜欢吵架，更愿意冷静下来再聊。', NULL, FALSE, FALSE, '2026-05-01 12:07:30'),
(41,  3, 3, 'AI', '温和的处理方式，跟我猜的差不多。那聊聊你的择偶想法吧！你理想中的另一半是什么样的？', '{"extractedTraits":["romantic","conflict_avoidant","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-01 12:08:00'),
(42,  3, 3, 'USER', '我希望对方性格比我外向一些，可以互补。因为我自己比较闷，需要有个开朗的人带带。对外表会有要求，毕竟是做设计的，对审美比较敏感。最好对艺术有一定兴趣，至少能一起看展。', NULL, FALSE, FALSE, '2026-05-01 12:10:30'),
(43,  3, 3, 'AI', '外向一点互补、有审美共鸣——这个描述很清晰！那你对未来的生活方式有什么期待？想在深圳定居吗？', '{"extractedTraits":["partner_extroversion_pref","importance_appearance","partner_social_pref"]}', FALSE, FALSE, '2026-05-01 12:11:00'),
(44,  3, 3, 'USER', '深圳挺好的，但也不排斥去别的城市。工作方面我挺享受现在的设计方向，希望未来能做更多有影响力的作品。对婚姻我不着急，觉得遇到对的人比时间更重要。', NULL, FALSE, FALSE, '2026-05-01 12:13:30'),
(45,  3, 3, 'AI', '遇到对的人比时间更重要——很赞同。那你更看重伴侣的哪些方面？性格、才华、价值观？', '{"extractedTraits":["career_oriented","openness_to_distance","long_term_goal"]}', FALSE, FALSE, '2026-05-01 12:14:00'),
(46,  3, 3, 'USER', '才华和价值观都重要，但如果非要排序的话，价值观排第一。两个人对生活的理解方向一致才能走得远。聪明有趣的灵魂比好看的脸更让人心动，当然好看也加分。', NULL, FALSE, FALSE, '2026-05-01 12:16:30'),
(47,  3, 3, 'AI', '价值观先行，果然是深度思考型的人。那在感情中，你表达爱意的方式是什么样的？', '{"extractedTraits":["importance_values","importance_intelligence","intellectual"]}', FALSE, FALSE, '2026-05-01 12:17:00'),
(48,  3, 3, 'USER', '我可能不是那种天天说"我爱你"的人，但我会用心做很多小事。比如记住对方喜欢的咖啡口味，在她累的时候默默准备好一切。行动比语言更能表达我自己。', NULL, FALSE, FALSE, '2026-05-01 12:19:30'),
(49,  3, 3, 'AI', '那就剩最后几个问题了~ 你觉得自己是事业型还是家庭型？', '{"extractedTraits":["partner_adventurous_pref","activity_level","family_oriented"]}', FALSE, FALSE, '2026-05-01 12:20:00'),
(50,  3, 3, 'USER', '一半一半吧。我很喜欢我的工作，但也不会为了事业放弃生活。理想的状态是两个人都能在各自的事业里成长，回到家又有温暖的陪伴。', NULL, FALSE, FALSE, '2026-05-01 12:22:30'),
(51,  3, 3, 'AI', '感谢你的真诚分享！✨ 这次聊天让我认识了一个内心丰富、温和细腻的你。你喜欢安静但有品味的生活，性格慢热但值得等待，期待一个开朗有审美、价值观契合的她。我想你需要的不是一场短暂的浪漫，而是一个能读懂你沉默的人。祝你好运！', NULL, FALSE, FALSE, '2026-05-01 12:23:00'),

-- ======== 用户 4: 刘思远 (32, 杭州, 创业者) ========
(52,  4, 4, 'AI', '嗨刘思远！我是你的交友助手~ 创业一定很忙吧？想先了解一下，在工作之外你有什么爱好？', NULL, FALSE, FALSE, '2026-05-02 09:00:30'),
(53,  4, 4, 'USER', '虽然忙但我坚持每天早上六点跑步，这已经是多年的习惯了。冬天会去滑雪，夏天找地方潜水。每年至少去两个没去过的国家，去年的目标是看了极光。', NULL, FALSE, FALSE, '2026-05-02 09:01:30'),
(54,  4, 4, 'AI', '极光、滑雪、潜水……你的生活就是一部探险纪录片啊！那你觉得自己是什么性格？创业这些年有没有改变你？', '{"extractedTraits":["adventurousness","activity_level","openness"]}', FALSE, FALSE, '2026-05-02 09:02:00'),
(55,  4, 4, 'USER', '我觉得自己是个目标导向很强的人，创业让我变得更加果断和独立。不太喜欢拖泥带水，做事喜欢快速决策快速执行。但有时候太理性了，别人会觉得不够温情吧。', NULL, FALSE, FALSE, '2026-05-02 09:04:30'),
(56,  4, 4, 'AI', '果断理性是创业者的标配，理解。那社交方面呢？创业圈子的社交你应该不少吧？', '{"extractedTraits":["extroversion","independence","career_oriented"]}', FALSE, FALSE, '2026-05-02 09:05:00'),
(57,  4, 4, 'USER', '对，商业社交是我的日常，但说实话大部分是功能性社交。真正能放松的社交反而不多。我更喜欢一对一的深度对话，或者一起运动之类不用太多话的活动。', NULL, FALSE, FALSE, '2026-05-02 09:07:30'),
(58,  4, 4, 'AI', '明白。那在这样的生活节奏下，你理想中另一半应该具备什么特质？', '{"extractedTraits":["socialness","agreeableness"]}', FALSE, FALSE, '2026-05-02 09:08:00'),
(59,  4, 4, 'USER', '第一点肯定是情绪稳定。创业本身压力很大，我希望家里是能放松的地方而不是另一个战场。她要有自己独立的事业和朋友圈，不依赖别人。能理解我有时候忙到飞起，不会因为没及时回消息就生气。', NULL, FALSE, FALSE, '2026-05-02 09:10:30'),
(60,  4, 4, 'AI', '需要独立、理解、情绪稳定——这对创业者的伴侣要求其实挺高的。那对未来呢？结婚生子在计划中吗？', '{"extractedTraits":["partner_extroversion_pref","importance_values","partner_adventurous_pref","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-02 09:11:00'),
(61,  4, 4, 'USER', '公司稳定下来之后再考虑吧，现在B轮刚结束还有很多事情要忙。我觉得不一定要按传统的时间线来，一切顺其自然。但确实希望能遇到一个志同道合的人，一起分享生活的冒险。', NULL, FALSE, FALSE, '2026-05-02 09:13:30'),
(62,  4, 4, 'AI', '顺其自然、不设限，这个心态很好。那在外表和内涵之间你怎么看？', '{"extractedTraits":["long_term_goal","family_oriented","romantic"]}', FALSE, FALSE, '2026-05-02 09:14:00'),
(63,  4, 4, 'USER', '外表过得去就行，不要太在意外在。我更看重内在，一个有智慧和阅历的人比漂亮的人有意思多了。当然如果也喜欢运动就更好了，可以一起跑步。', NULL, FALSE, FALSE, '2026-05-02 09:16:30'),
(64,  4, 4, 'AI', '那你觉得自己需要什么样的情感支持？创业低谷时一般怎么恢复？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-02 09:17:00'),
(65,  4, 4, 'USER', '低谷的时候其实不太需要别人给我建议，有人能静静陪着就够了。或者说一句"我相信你"就很有力量。我这个人不太容易表达困难，但其实内心是很需要理解和支持的。', NULL, FALSE, FALSE, '2026-05-02 09:19:30'),
(66,  4, 4, 'AI', '了解。最后几个问题——你对异地怎么看？还有哪些是不能接受的？', '{"extractedTraits":["conflict_avoidant","creative"]}', FALSE, FALSE, '2026-05-02 09:20:00'),
(67,  4, 4, 'USER', '异地我不排斥，因为我的时间本来就比较灵活。但我不能接受的是不诚实，还有就是完全没有自己生活的人。对了，喜欢动物是加分项，我打算养一只金毛。', NULL, FALSE, FALSE, '2026-05-02 09:22:30'),
(68,  4, 4, 'AI', '感谢你的开放和坦诚！🏔️ 这次聊天让我认识了一位有着探索者灵魂的你。你是那种不断突破舒适区的人，需要的是一个情绪稳定、独立自信、能和你并肩看世界的伴侣——不一定天天腻在一起，但重要时刻一定在。正如你追逐极光一样，祝你也找到属于你的那道光。', NULL, FALSE, FALSE, '2026-05-02 09:23:00'),

-- ======== 用户 5: 陈天宇 (27, 成都, 摄影师) ========
(69,  5, 5, 'AI', '嗨陈天宇！我是你的交友助手~ 自由摄影师听起来太酷了！先聊聊你平时除了拍照还喜欢做什么？', NULL, FALSE, FALSE, '2026-05-02 10:00:30'),
(70,  5, 5, 'USER', '哈哈谢谢！除了拍照我还会弹吉他，民谣和指弹都会一点。养了一只边境牧羊犬叫小七，每天带它跑步是我最开心的事。成都的生活节奏慢，正好适合我这种随性的人~', NULL, FALSE, FALSE, '2026-05-02 10:01:30'),
(71,  5, 5, 'AI', '弹吉他、遛边牧、拍照……成都文艺青年的标配啊！那你描述一下自己的性格？朋友们会怎么形容你？', '{"extractedTraits":["creative","adventurousness","openness"]}', FALSE, FALSE, '2026-05-02 10:02:00'),
(72,  5, 5, 'USER', '朋友都说我是乐天派，天塌下来也能笑着面对那种。我比较感性，看到好的光影会站在路边拍半天。很随和，不太会计较小事，跟谁都能聊得来。但有时候朋友说我太浪漫主义了，现实感不够。', NULL, FALSE, FALSE, '2026-05-02 10:04:30'),
(73,  5, 5, 'AI', '浪漫主义多好啊，成都就是适合浪漫的城市！那社交方面呢？平时喜欢和朋友一起做什么？', '{"extractedTraits":["extroversion","agreeableness","romantic"]}', FALSE, FALSE, '2026-05-02 10:05:00'),
(74,  5, 5, 'USER', '我挺喜欢社交的，朋友很多。周末经常呼朋唤友去拍照、野餐、或者找新的馆子钻。一个人的时候也会和狗狗去山里走走。我觉得人和人之间的连接是生活最有意思的部分。', NULL, FALSE, FALSE, '2026-05-02 10:07:30'),
(75,  5, 5, 'AI', '生活充满热情，太好了。那你的择偶观呢？你理想中的女朋友是什么样的？', '{"extractedTraits":["socialness","activity_level","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-02 10:08:00'),
(76,  5, 5, 'USER', '最重要的是有对生活的热爱。我不介意她是活泼的还是安静的，但不能接受太宅的或者每天只想躺平的。最好也对文艺有点兴趣，能一起去看展、听livehouse、或者一起旅行拍照。', NULL, FALSE, FALSE, '2026-05-02 10:10:30'),
(77,  5, 5, 'AI', '能一起旅行拍照——这个要求很摄影师哈哈！那你对婚姻和未来的生活有什么期待？', '{"extractedTraits":["partner_adventurous_pref","importance_values","partner_extroversion_pref"]}', FALSE, FALSE, '2026-05-02 10:11:00'),
(78,  5, 5, 'USER', '我不着急结婚，但希望能有一段认真的长期关系。未来想找一个愿意和我一起探索世界的女生。生活不需要赚很多钱，够用就行，但要有足够的自由和美好。', NULL, FALSE, FALSE, '2026-05-02 10:13:30'),
(79,  5, 5, 'AI', '你对物质的看法很淡然呢。那在感情关系中，你最看重对方的什么特质？', '{"extractedTraits":["long_term_goal","family_oriented","career_oriented"]}', FALSE, FALSE, '2026-05-02 10:14:00'),
(80,  5, 5, 'USER', '真诚，最重要的就是真诚。还有就是有趣——不是那种刻意搞笑的有趣，而是对世界有好奇心，能让平淡的日子变得有意思。外表的话过得去就行，我觉得人的魅力来自性格。', NULL, FALSE, FALSE, '2026-05-02 10:16:30'),
(81,  5, 5, 'AI', '好奇心和真诚，很纯粹的追求。那你对于每天相处的时间有什么期待吗？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-02 10:17:00'),
(82,  5, 5, 'USER', '哈哈我反正是希望每天都能见到的，但也不强求。如果对方需要个人空间我也理解。我觉得好的感情就是两个人自然地想在一起，不用刻意安排。', NULL, FALSE, FALSE, '2026-05-02 10:19:30'),
(83,  5, 5, 'AI', '最后几个小问题~ 你有什么不能接受的雷区吗？还有对异地怎么看？', '{"extractedTraits":["independence","conflict_avoidant","intellectual"]}', FALSE, FALSE, '2026-05-02 10:20:00'),
(84,  5, 5, 'USER', '雷区就是太算计的人，还有沉迷手机的——两个人在一起各自刷手机那还不如一个人。异地的话看情况吧，如果感情好的话异地也不是问题，但最终还是要在一起的。', NULL, FALSE, FALSE, '2026-05-02 10:22:30'),
(85,  5, 5, 'AI', '感谢这次温暖的交流！🎸 你就像成都的阳光一样，温暖、随性、充满创造力。你期待一段真诚而有趣的感情，和一个同样热爱生活的她一起看世界。带着相机和边牧小七，你的生活本身就是一幅画，现在就差画里的女主角了。祝你在寻爱路上遇到那个能一起拍日落的她。', NULL, FALSE, FALSE, '2026-05-02 10:23:00'),

-- ======== 用户 6: 赵俊杰 (29, 广州, 数据分析师) ========
(86,  6, 6, 'AI', '嗨赵俊杰！我是你的交友助手~ 数据分析师听起来很酷，先聊聊你工作之外的生活吧！', NULL, FALSE, FALSE, '2026-05-02 11:00:30'),
(87,  6, 6, 'USER', '我最大的爱好是煲汤和做广式茶点。作为一个广州人，对吃是有执念的哈哈。周末喜欢去东山口逛创意市集，或者研究新的食谱。生活嘛要细水长流~', NULL, FALSE, FALSE, '2026-05-02 11:01:30'),
(88,  6, 6, 'AI', '煲汤和茶点，太有广式生活气息了！那你描述一下自己的性格？', '{"extractedTraits":["creative","openness","agreeableness"]}', FALSE, FALSE, '2026-05-02 11:02:00'),
(89,  6, 6, 'USER', '我属于比较温和耐心的性格，数据分析做久了，遇到事情也比较冷静。不太容易生气，朋友们都说我是好好先生。但也有缺点，就是有时候不太会表达自己的情绪，比较能忍。', NULL, FALSE, FALSE, '2026-05-02 11:04:30'),
(90,  6, 6, 'AI', '温和有耐心的好好先生~ 那社交方面呢？你更喜欢什么样的社交方式？', '{"extractedTraits":["extroversion","emotional_expressiveness","conflict_avoidant"]}', FALSE, FALSE, '2026-05-02 11:05:00'),
(91,  6, 6, 'USER', '我的社交圈不大，主要就是同事和几个老同学。周末喜欢和家人聚餐，我觉得家庭很重要。不是那种喜欢出去嗨的人，更多是居家型的生活。', NULL, FALSE, FALSE, '2026-05-02 11:07:30'),
(92,  6, 6, 'AI', '居家型生活，温馨。那感情方面，你理想中的伴侣是什么样的？', '{"extractedTraits":["socialness","family_oriented","independence"]}', FALSE, FALSE, '2026-05-02 11:08:00'),
(93,  6, 6, 'USER', '我希望对方在广深地区，性格温和好沟通。有自己的事业和生活圈，不要太依赖。学历和工作都无所谓，重要的是人好、聊得来。不要太情绪化，遇到问题能好好商量。', NULL, FALSE, FALSE, '2026-05-02 11:10:30'),
(94,  6, 6, 'AI', '温和、独立、好沟通，很清晰。那对于未来的规划呢？', '{"extractedTraits":["partner_extroversion_pref","importance_values","openness_to_distance","partner_adventurous_pref"]}', FALSE, FALSE, '2026-05-02 11:11:00'),
(95,  6, 6, 'USER', '希望两年内可以考虑结婚的事吧。事业上稳步发展就行，不想太卷。理想的生活就是有个温暖的家，周末给家人煲汤做饭，平淡但有滋有味。', NULL, FALSE, FALSE, '2026-05-02 11:13:30'),
(96,  6, 6, 'AI', '平淡但有滋有味，这就是广州style。那你对外表、年龄这些怎么看？', '{"extractedTraits":["long_term_goal","romantic","career_oriented"]}', FALSE, FALSE, '2026-05-02 11:14:00'),
(97,  6, 6, 'USER', '外表中等就好，不要过度在意外在。年龄大一点小一点都可以接受。我觉得两个人在一起舒服最重要，彼此相处不需要端着。还有就是比较看重对方的家庭观念，因为我自己挺喜欢家庭氛围的。', NULL, FALSE, FALSE, '2026-05-02 11:16:30'),
(98,  6, 6, 'AI', '家庭观念很重要这点特别赞同。那你需要什么样的情感支持？', '{"extractedTraits":["importance_appearance","importance_values","partner_social_pref"]}', FALSE, FALSE, '2026-05-02 11:17:00'),
(99,  6, 6, 'USER', '我可能更需要那种被理解的安心感。不用天天聊，但聊的时候能真的听我说话。有时候工作遇到问题可能会闷在心里，如果能被关心和包容就很好。', NULL, FALSE, FALSE, '2026-05-02 11:19:30'),
(100, 6, 6, 'AI', '最后的小问题~ 有什么雷区吗？', '{"extractedTraits":["intellectual","importance_intelligence","activity_level"]}', FALSE, FALSE, '2026-05-02 11:20:00'),
(101, 6, 6, 'USER', '不能接受欺骗和玩弄感情。还有就是太过强势控制欲强的也不太能接受，我希望双方是平等的。', NULL, FALSE, FALSE, '2026-05-02 11:22:30'),
(102, 6, 6, 'AI', '赵俊杰，很高兴认识你！🍲 你是一个像广式老火靓汤一样的人——需要时间，但用心熬出来的都是精华。温和可靠、家庭为重，期待一段互相理解、平淡真挚的感情。你带着煲汤的食谱和一颗细水长流的心，只等一个懂得品味生活的人。祝你在寻爱的路上遇到温暖的人。', NULL, FALSE, FALSE, '2026-05-02 11:23:00'),

-- ======== 用户 7: 孙浩宇 (25, 南京, 中学教师) ========
(103, 7, 7, 'AI', '嗨孙浩宇！我是你的交友助手~ 教师是个很有意义的职业。先聊聊你的业余生活吧！', NULL, FALSE, FALSE, '2026-05-02 12:00:30'),
(104, 7, 7, 'USER', '我业余喜欢写文章，给一个文化类公众号供稿，主要写书评和影评。周末喜欢逛书店，南京先锋书店是我常去的地方。也喜欢早起去中山陵附近走走，安静的时候思维最清晰。', NULL, FALSE, FALSE, '2026-05-02 12:01:30'),
(105, 7, 7, 'AI', '写文章、逛书店、中山陵散步……好有书卷气的生活。那你形容一下自己的性格？', '{"extractedTraits":["creative","intellectual","openness"]}', FALSE, FALSE, '2026-05-02 12:02:00'),
(106, 7, 7, 'USER', '我觉得自己算是温和安静型的，在教室里比较自信，但社交场合其实偏内向。比较有耐心，毕竟是当老师的，忍耐力是基本素养哈哈。做事比较深思熟虑，不太喜欢冲动。', NULL, FALSE, FALSE, '2026-05-02 12:04:30'),
(107, 7, 7, 'AI', '耐心确实是老师最重要的品质。那社交方面你觉得怎样？', '{"extractedTraits":["extroversion","agreeableness","socialness"]}', FALSE, FALSE, '2026-05-02 12:05:00'),
(108, 7, 7, 'USER', '实话说不擅长社交，人多的场合会有些紧张。但我喜欢和聊得来的人深入交流，一两个朋友坐下来聊一下午文学哲学那种。我可能不是社交型，但一旦建立了连接就会很认真。', NULL, FALSE, FALSE, '2026-05-02 12:07:30'),
(109, 7, 7, 'AI', '深度的交流比表面的社交更有意义。那恋爱观呢？你期待怎样的另一半？', '{"extractedTraits":["romantic","conflict_avoidant","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-02 12:08:00'),
(110, 7, 7, 'USER', '我希望她善良真诚，有书卷气。最好也喜欢阅读，能一起逛书店、看完同一本书然后交流。年龄不是问题，重要的是精神世界的契合。不需要多漂亮，但一定要有内涵。', NULL, FALSE, FALSE, '2026-05-02 12:10:30'),
(111, 7, 7, 'AI', '精神世界的契合……很美好的向往。那聊聊人生目标？', '{"extractedTraits":["partner_extroversion_pref","importance_values","importance_intelligence","importance_appearance"]}', FALSE, FALSE, '2026-05-02 12:11:00'),
(112, 7, 7, 'USER', '职业上会继续在教育领域深耕，希望能成为那种能影响学生的好老师。感情上希望遇到一个能互相理解的人，一起建立温馨的小家。我觉得好的感情像一本好书，需要慢慢读。', NULL, FALSE, FALSE, '2026-05-02 12:13:30'),
(113, 7, 7, 'AI', '像好书一样慢慢读……这个比喻真好。那对婚姻你是怎么看的？', '{"extractedTraits":["career_oriented","family_oriented","long_term_goal"]}', FALSE, FALSE, '2026-05-02 12:14:00'),
(114, 7, 7, 'USER', '我希望三年左右能结婚吧。婚姻对我来说是一个承诺，不只是形式。希望对方也是以长期关系为目标的人，认真对待感情。', NULL, FALSE, FALSE, '2026-05-02 12:16:30'),
(115, 7, 7, 'AI', '那你喜欢什么样的相处节奏？对方需要给你很多空间吗？', '{"extractedTraits":["independence","activity_level"]}', FALSE, FALSE, '2026-05-02 12:17:00'),
(116, 7, 7, 'USER', '我觉得适度的空间是必要的。但我也希望有固定的交流时间，比如睡前聊聊今天的感受。那种不用刻意找话题也能安静待在一起的状态是我最向往的。', NULL, FALSE, FALSE, '2026-05-02 12:19:30'),
(117, 7, 7, 'AI', '好温柔的回答。最后问一下，你对于异地和年龄怎么看？', '{"extractedTraits":["partner_social_pref","adventurousness","openness_to_distance"]}', FALSE, FALSE, '2026-05-02 12:20:00'),
(118, 7, 7, 'USER', '异地的话不太能接受，我希望和另一半能在一个城市。年龄的话25-35都OK，主要是精神层面的匹配。比我大一点也挺好，成熟稳重。', NULL, FALSE, FALSE, '2026-05-02 12:22:30'),
(119, 7, 7, 'AI', '孙浩宇，感谢你的真诚和温柔。📚 这次聊天让我认识了一位有着深厚内心世界的你。你像一本安静的好书，不喧嚣但值得细品。你期待的是一段基于精神契合的感情——能在先锋书店的书架间不期而遇，也能在中山陵的梧桐树下并肩漫步。祝你在最好的南京，遇见最好的她。', NULL, FALSE, FALSE, '2026-05-02 12:23:00'),

-- ======== 用户 8: 周文博 (31, 武汉, 医生) ========
(120, 8, 8, 'AI', '嗨周文博！我是你的交友助手~ 医生是个了不起的职业。忙完手术之后你是怎么放松的？', NULL, FALSE, FALSE, '2026-05-03 09:00:30'),
(121, 8, 8, 'USER', '我喜欢种花养草，阳台上养了二十多盆多肉和几盆兰花。每天给它们浇水修剪是我最减压的事。也喜欢做点家常菜，虽然不如专业厨师但自己吃很满足。', NULL, FALSE, FALSE, '2026-05-03 09:01:30'),
(122, 8, 8, 'AI', '养花和做菜，很有耐心的人才喜欢这些。那你形容一下自己的性格？', '{"extractedTraits":["agreeableness","creative","independence"]}', FALSE, FALSE, '2026-05-03 09:02:00'),
(123, 8, 8, 'USER', '我算是比较稳重的性格。做医生这么久了，习惯了遇事不慌、先想清楚再处理。为人比较正直可靠，不喜欢虚假那一套。但有时候可能不太会表达温柔，这点需要努力。', NULL, FALSE, FALSE, '2026-05-03 09:04:30'),
(124, 8, 8, 'AI', '稳重可靠是非常难得的品质。那社交方面呢？你喜欢什么样的社交方式？', '{"extractedTraits":["extroversion","emotional_expressiveness","openness"]}', FALSE, FALSE, '2026-05-03 09:05:00'),
(125, 8, 8, 'USER', '工作已经够累了，业余时间我其实更喜欢独处或者和家人待在一起。社交对我来说是能耗比较高的活动，但医院同事之间的相处我还是挺好的。', NULL, FALSE, FALSE, '2026-05-03 09:07:30'),
(126, 8, 8, 'AI', '医生的工作本身就需要大量社交和共情。那你对另一半有什么期待呢？', '{"extractedTraits":["socialness","activity_level","family_oriented"]}', FALSE, FALSE, '2026-05-03 09:08:00'),
(127, 8, 8, 'USER', '我希望对方有稳定的工作，不需要赚很多但有自己的小事业。最好在武汉生活，或者愿意来。要能理解医生的工作节奏——有时候急诊一来计划全泡汤。性格上温和一点，不要动不动就闹情绪。', NULL, FALSE, FALSE, '2026-05-03 09:10:30'),
(128, 8, 8, 'AI', '理解医生节奏这点确实很重要。那对未来的生活有什么规划？', '{"extractedTraits":["partner_extroversion_pref","importance_values","openness_to_distance","partner_adventurous_pref"]}', FALSE, FALSE, '2026-05-03 09:11:00'),
(129, 8, 8, 'USER', '事业上希望再过几年晋升到副主任医生。家庭方面希望能尽早遇到对的人，我其实挺期待有孩子的。理想的生活就是下班回家有热饭和温暖的人在等你。', NULL, FALSE, FALSE, '2026-05-03 09:13:30'),
(130, 8, 8, 'AI', '很实在的期盼。那外表和内涵之间你觉得哪个更重要？', '{"extractedTraits":["career_oriented","long_term_goal","romantic"]}', FALSE, FALSE, '2026-05-03 09:14:00'),
(131, 8, 8, 'USER', '内涵和性格显然更重要，外表会变但人品不会。当然也不是完全不在意，正常范围内就好。我觉得一个人愿不愿意为别人着想，比脸好不好看重要多了。', NULL, FALSE, FALSE, '2026-05-03 09:16:30'),
(132, 8, 8, 'AI', '那在关系中你一般是主动表达还是需要对方更多主动？', '{"extractedTraits":["importance_appearance","importance_values","importance_intelligence"]}', FALSE, FALSE, '2026-05-03 09:17:00'),
(133, 8, 8, 'USER', '我可能在表达感情方面比较被动。但如果对方给我足够的安全感，我也会慢慢打开自己。希望对方能比我更愿意表达一些，互补嘛。', NULL, FALSE, FALSE, '2026-05-03 09:19:30'),
(134, 8, 8, 'AI', '最后问一下，你有不能接受的雷区吗？', '{"extractedTraits":["conflict_avoidant","intellectual","partner_social_pref"]}', FALSE, FALSE, '2026-05-03 09:20:00'),
(135, 8, 8, 'USER', '不能接受不诚实的人，还有就是过于自私的。关系是两个人都要付出和维护的。', NULL, FALSE, FALSE, '2026-05-03 09:22:30'),
(136, 8, 8, 'AI', '周文博，很高兴认识你。🌱 你是一个稳重踏实、外冷内暖的人。像你阳台上那些多肉一样，你的感情需要耐心和时间去培育，但一旦扎根就会长久。你希望遇到一个能理解你工作节奏、温柔可靠的她，在武汉共筑一个温暖的小家。祝你能遇到那个愿意等你下手术台的她。', NULL, FALSE, FALSE, '2026-05-03 09:23:00'),

-- ======== 用户 9: 吴子轩 (24, 西安, 研究生) ========
(137, 9, 9, 'AI', '嗨吴子轩！我是你的交友助手~ 研二应该很忙吧？写论文之外还有什么爱好？', NULL, FALSE, FALSE, '2026-05-03 10:00:30'),
(138, 9, 9, 'USER', '打篮球和打主机游戏！每周至少去两次球场，实验室干活累了就和同学开黑。我是实验室的开心果，大家都说我段子讲得好哈哈。', NULL, FALSE, FALSE, '2026-05-03 10:01:30'),
(139, 9, 9, 'AI', '哈哈篮球+游戏+段子，感觉很活泼啊！那形容一下你的性格？', '{"extractedTraits":["activity_level","socialness","adventurousness"]}', FALSE, FALSE, '2026-05-03 10:02:00'),
(140, 9, 9, 'USER', '我算是外向开朗型的，喜欢热闹，跟谁都能聊。比较幽默，不开心的时候也能把人逗笑。但是朋友也说我有时候太大大咧咧了，不够成熟。', NULL, FALSE, FALSE, '2026-05-03 10:04:30'),
(141, 9, 9, 'AI', '开朗幽默很讨女生喜欢呢！那你在感情中一般是什么样的？', '{"extractedTraits":["extroversion","agreeableness","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-03 10:05:00'),
(142, 9, 9, 'USER', '我觉得我挺会照顾人的，虽然看起来大大咧咧但其实挺细心。比如会记住对方喜欢喝什么奶茶、生日是哪天之类的。吵架不会冷战，更倾向于直接沟通。', NULL, FALSE, FALSE, '2026-05-03 10:07:30'),
(143, 9, 9, 'AI', '不小气不冷战，这个态度很好。那说说你的择偶想法吧！', '{"extractedTraits":["romantic","conflict_avoidant","family_oriented"]}', FALSE, FALSE, '2026-05-03 10:08:00'),
(144, 9, 9, 'USER', '我希望对方年龄跟我差不多，24-30都可以。性格活泼开朗最好了，能跟我一起疯一起笑。当然也不用一模一样，互补也挺有趣的。最重要的是聊得来，我话比较多需要有人接得住哈哈。', NULL, FALSE, FALSE, '2026-05-03 10:10:30'),
(145, 9, 9, 'AI', '活泼能接得住段子，这个要求很清楚！那对未来呢？毕业后的打算？', '{"extractedTraits":["partner_extroversion_pref","partner_adventurous_pref","openness_to_distance"]}', FALSE, FALSE, '2026-05-03 10:11:00'),
(146, 9, 9, 'USER', '毕业先找一份不错的开发工作吧，可能去大厂或者创业。感情方面暂时不会特别着急结婚，但希望能有一段认真的长期关系。觉得两个人开心地在一起比什么都重要。', NULL, FALSE, FALSE, '2026-05-03 10:13:30'),
(147, 9, 9, 'AI', '那你更看重对方哪些方面？外貌、性格、兴趣爱好？', '{"extractedTraits":["career_oriented","long_term_goal","intellectual"]}', FALSE, FALSE, '2026-05-03 10:14:00'),
(148, 9, 9, 'USER', '性格排第一，其次是兴趣爱好相投。外表有要求但不是重点，看着舒服就行了。希望她也有自己的爱好和生活，不要太依赖我。三观的话只要不是很奇葩都能聊。', NULL, FALSE, FALSE, '2026-05-03 10:16:30'),
(149, 9, 9, 'AI', '那关于相处模式，你喜欢什么样的节奏？', '{"extractedTraits":["importance_appearance","importance_values","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-03 10:17:00'),
(150, 9, 9, 'USER', '喜欢轻松自然的相处模式。不用太拘谨也不用太粘人。两个人在一起像最好的朋友一样，可以一起玩游戏看剧，也可以一起打球跑步。', NULL, FALSE, FALSE, '2026-05-03 10:19:30'),
(151, 9, 9, 'AI', '最后聊聊雷区吧！有什么是你完全不能接受的？', '{"extractedTraits":["openness","creative","independence"]}', FALSE, FALSE, '2026-05-03 10:20:00'),
(152, 9, 9, 'USER', '不能接受太势利的，还有就是那种什么都管着的。我需要个人空间。还有就是希望对方有基本的上进心，不用学霸但不能摆烂。', NULL, FALSE, FALSE, '2026-05-03 10:22:30'),
(153, 9, 9, 'AI', '吴子轩，和你聊天真的很开心！🏀 你是一个阳光开朗、笑点低的大男孩，给周围人带来了很多欢乐。你期待一段轻松自然、像好朋友一样的恋爱，和一个活泼有趣、能接住你段子的她。带着篮球和Switch，你的青春才刚开始，祝你在西安遇见那个刚好对的她。', NULL, FALSE, FALSE, '2026-05-03 10:23:00'),

-- ======== 用户 10: 郑凯文 (33, 重庆, 律师) ========
(154, 10, 10, 'AI', '嗨郑凯文！我是你的交友助手~ 做了这么多年律师，一定积累了很多故事。先聊聊工作之外的生活？', NULL, FALSE, FALSE, '2026-05-03 11:00:30'),
(155, 10, 10, 'USER', '工作之外我喜欢研究一些法律之外的东西，看点历史书。也经常去健身房，保持精力很重要。和朋友聚会的时候我一般比较能控场，可能也是职业习惯吧。', NULL, FALSE, FALSE, '2026-05-03 11:01:30'),
(156, 10, 10, 'AI', '看书健身、能控场，律师的日常果然很高效。那你觉得自己是什么样的性格？', '{"extractedTraits":["activity_level","intellectual","openness"]}', FALSE, FALSE, '2026-05-03 11:02:00'),
(157, 10, 10, 'USER', '我性格比较直爽，不喜欢拐弯抹角。法庭上习惯了直来直去，生活中也是这样。情绪表达比较丰富，开心生气都写在脸上。做事雷厉风行，最讨厌拖泥带水。', NULL, FALSE, FALSE, '2026-05-03 11:04:30'),
(158, 10, 10, 'AI', '直爽的重庆人，太符合了！那社交方面你是不是也很有号召力？', '{"extractedTraits":["extroversion","emotional_expressiveness","agreeableness"]}', FALSE, FALSE, '2026-05-03 11:05:00'),
(159, 10, 10, 'USER', '对，在朋友圈里我一般是组织者的角色。我觉得社交是给自己充电，和有趣的人在一起聊聊天喝点小酒，是生活的一大乐趣。但也不是什么圈子都融，我更偏向有质量的社交。', NULL, FALSE, FALSE, '2026-05-03 11:07:30'),
(160, 10, 10, 'AI', '有质量的社交——这个标准很好。那感情方面呢？你理想中另一半是什么样的？', '{"extractedTraits":["socialness","independence"]}', FALSE, FALSE, '2026-05-03 11:08:00'),
(161, 10, 10, 'USER', '我希望她性格直爽好相处，不要搞那些弯弯绕。在重庆生活或者愿意来重庆。有自己的事业最好，两个人互相尊重各自的工作。年龄28-40都可以，但必须成熟懂事。', NULL, FALSE, FALSE, '2026-05-03 11:10:30'),
(162, 10, 10, 'AI', '成熟直爽、互相尊重——律师的标准很清晰。那对未来呢，家庭和事业怎么平衡？', '{"extractedTraits":["partner_extroversion_pref","importance_values","openness_to_distance","long_term_goal"]}', FALSE, FALSE, '2026-05-03 11:11:00'),
(163, 10, 10, 'USER', '事业对我来说一直很重要，但不代表会放弃家庭。我觉得好的伴侣是合作伙伴，两个人一起把家庭经营好。不需要每天腻在一起，但重要的决策要一起商量。', NULL, FALSE, FALSE, '2026-05-03 11:13:30'),
(164, 10, 10, 'AI', '家庭也需要经营，这个比喻很好。对外表这些你怎么看？', '{"extractedTraits":["career_oriented","family_oriented","romantic"]}', FALSE, FALSE, '2026-05-03 11:14:00'),
(165, 10, 10, 'USER', '外表嘛基本顺眼就行，我对外貌没太高要求。但气质很重要——一个人走路的姿态、说话的节奏，比脸更能说明问题。', NULL, FALSE, FALSE, '2026-05-03 11:16:30'),
(166, 10, 10, 'AI', '气质比脸重要，这个观点很律师。那谈恋爱时你是什么样的？浪漫吗？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_adventurous_pref"]}', FALSE, FALSE, '2026-05-03 11:17:00'),
(167, 10, 10, 'USER', '哈哈可能不是传统意义上的浪漫。我会记住对方的需求然后用实际行动解决。比如她说最近累了我就会安排好一切让她休息。我表达爱的方式更多是行动而不是语言。', NULL, FALSE, FALSE, '2026-05-03 11:19:30'),
(168, 10, 10, 'AI', '那最后聊聊雷区？什么事是你完全不能接受的？', '{"extractedTraits":["conflict_avoidant","creative","partner_social_pref"]}', FALSE, FALSE, '2026-05-03 11:20:00'),
(169, 10, 10, 'USER', '最不能接受的就是欺骗和虚伪。还有那种特别黏人的，需要有人24小时在线的那种。工作的时候我很专注，不希望被频繁打扰。', NULL, FALSE, FALSE, '2026-05-03 11:22:30'),
(170, 10, 10, 'AI', '郑凯文，很荣幸和你交流。⚖️ 你是一个直爽果敢、做事有章法的人，有着重庆人的率真和律师的理性。你期待的是一段平等成熟的关系——两个人在各自领域发光，回到家能坦诚相对。你的爱情观就像你处理的案件一样：不需要花哨，但需要真诚。祝在重庆的雾中，遇到那个让你甘心放慢脚步的她。', NULL, FALSE, FALSE, '2026-05-03 11:23:00'),

-- ======== 用户 11: 李晓萱 (26, 北京, 市场经理) ========
(171, 11, 11, 'AI', '嗨李晓萱！我是你的交友助手~ 做市场的人生活一般都很精彩！先聊聊你的业余生活？', NULL, FALSE, FALSE, '2026-05-04 09:00:30'),
(172, 11, 11, 'USER', '周末最喜欢去胡同里探店和咖啡馆打卡。北京的胡同有种特别的烟火气，每次走进去都会有新发现。我也喜欢旅行和看展，公司有年假的时候会去国外游。', NULL, FALSE, FALSE, '2026-05-04 09:01:30'),
(173, 11, 11, 'AI', '探店、旅行、看展——你是个生活家啊！那形容一下自己的性格？', '{"extractedTraits":["adventurousness","openness","activity_level"]}', FALSE, FALSE, '2026-05-04 09:02:00'),
(174, 11, 11, 'USER', '开朗独立是朋友们给我的标签。我很喜欢和人打交道，一个人也能把事情处理得很好。乐观自信，遇到困难不会轻易退缩。', NULL, FALSE, FALSE, '2026-05-04 09:04:30'),
(175, 11, 11, 'AI', '独立又开朗，很有魅力。那社交对你来说是什么？', '{"extractedTraits":["extroversion","independence","agreeableness"]}', FALSE, FALSE, '2026-05-04 09:05:00'),
(176, 11, 11, 'USER', '社交对我来说是生活的必需品！我喜欢和朋友在一起的感觉。无论是工作上的应酬还是私下的聚会我都很享受。我觉得社交不仅是为了结识人脉，也是生活的乐趣所在。', NULL, FALSE, FALSE, '2026-05-04 09:07:30'),
(177, 11, 11, 'AI', '社交达人！那感情方面呢？你期待怎样的另一半？', '{"extractedTraits":["socialness","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-04 09:08:00'),
(178, 11, 11, 'USER', '希望对方在北京，175以上，有上进心和责任心。幽默很重要！一个能让我笑出来的男生很加分。最好也是做技术或者管理类的，能和我互相理解工作节奏。年纪不要差太多。', NULL, FALSE, FALSE, '2026-05-04 09:10:30'),
(179, 11, 11, 'AI', '幽默和上进，很好的期待。聊聊人生目标？', '{"extractedTraits":["partner_extroversion_pref","partner_adventurous_pref","importance_values","openness_to_distance"]}', FALSE, FALSE, '2026-05-04 09:11:00'),
(180, 11, 11, 'USER', '职业上我想在两三年内升到市场总监。人生目标就是事业有成、家庭美满。觉得自己能做的比现在更多，一直在追求进步。', NULL, FALSE, FALSE, '2026-05-04 09:13:30'),
(181, 11, 11, 'AI', '那你在感情中最需要什么样的支持？', '{"extractedTraits":["career_oriented","long_term_goal","family_oriented"]}', FALSE, FALSE, '2026-05-04 09:14:00'),
(182, 11, 11, 'USER', '需要被认可和被鼓励吧。其实内心也有脆弱的一面，需要一个能让我卸下防备的人。在外面我可能很强大，但回到家希望有人能给我一个拥抱。', NULL, FALSE, FALSE, '2026-05-04 09:16:30'),
(183, 11, 11, 'AI', '再坚强的人也需要温柔。外表这方面你怎么看？', '{"extractedTraits":["romantic","intellectual"]}', FALSE, FALSE, '2026-05-04 09:17:00'),
(184, 11, 11, 'USER', '说实话我对身高有要求的，毕竟我自己也不矮。长相的话顺眼就行，关键是气质和衣品。一个穿着得体、干净整洁的男生很有吸引力。', NULL, FALSE, FALSE, '2026-05-04 09:19:30'),
(185, 11, 11, 'AI', '了解。那你觉得两个人在一起最重要的是什么？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-04 09:20:00'),
(186, 11, 11, 'USER', '信任和沟通吧。没有信任的爱情是没有基础的。还有就是两个人要能一起成长，而不是一个人拉着另一个人。希望是相互成就的关系。', NULL, FALSE, FALSE, '2026-05-04 09:22:30'),
(187, 11, 11, 'AI', '李晓萱，很高兴认识你！✨ 你像北京的天空一样明亮而独立，有能力有想法也有深情。你期待的是一个有上进心、能让你开怀大笑、一起在北京奋斗的他。相信你一定会遇到那个让你愿意卸下铠甲、展现柔软的特别的人。祝你的爱情像你探索的胡同一样，充满惊喜。', NULL, FALSE, FALSE, '2026-05-04 09:23:00'),

-- ======== 用户 12: 王语嫣 (28, 上海, 时尚设计师) ========
(188, 12, 12, 'AI', '嗨王语嫣！我是你的交友助手~ 作为设计师，你的日常一定很有美感吧？', NULL, FALSE, FALSE, '2026-05-04 10:00:30'),
(189, 12, 12, 'USER', '是的，我做的每件事都会有些设计考量。工作之余喜欢去看各种展览，尤其是装置艺术和面料展。自己也会做手工皮具，从设计到打版缝制全程自己来。养了一只布偶猫叫云朵，它是我最好的模特。', NULL, FALSE, FALSE, '2026-05-04 10:01:30'),
(190, 12, 12, 'AI', '手工皮具、布偶猫、艺术展……你真的活在美学里。那你是怎样的性格呢？', '{"extractedTraits":["creative","openness","adventurousness"]}', FALSE, FALSE, '2026-05-04 10:02:00'),
(191, 12, 12, 'USER', '我觉得自己不算外向，但也绝对不内向。和了解我的人在一起我会很放松，陌生的场合会比较拘谨。比较独立，自己能搞定很多事。对工作很认真，但生活里有点小任性。', NULL, FALSE, FALSE, '2026-05-04 10:04:30'),
(192, 12, 12, 'AI', '独立又有点小任性，很有个性的组合。那社交方面呢？', '{"extractedTraits":["extroversion","independence","agreeableness"]}', FALSE, FALSE, '2026-05-04 10:05:00'),
(193, 12, 12, 'USER', '我有几个关系很好的朋友就够了，不追求社交圈的大小。更多时候喜欢自己待着做手工、看书、撸猫。当然遇到聊得来的也会聊很久。我是一个慢热的人。', NULL, FALSE, FALSE, '2026-05-04 10:07:30'),
(194, 12, 12, 'AI', '慢热但值得等待。那你的择偶观呢？你希望和一个什么样的人在一起？', '{"extractedTraits":["socialness","activity_level","romantic"]}', FALSE, FALSE, '2026-05-04 10:08:00'),
(195, 12, 12, 'USER', '我希望他有审美有品位，不一定是做设计的但要有基本的审美意识。成熟稳重一些，能包容我的小脾气。喜欢小动物加分，因为我的猫是我生活的一部分。年龄方面30左右最合适。', NULL, FALSE, FALSE, '2026-05-04 10:10:30'),
(196, 12, 12, 'AI', '审美、品位、成熟——设计师的标准不低呢。那价值观方面呢？你觉得人生什么最重要？', '{"extractedTraits":["partner_extroversion_pref","importance_appearance","importance_values"]}', FALSE, FALSE, '2026-05-04 10:11:00'),
(197, 12, 12, 'USER', '我觉得最重要的是做自己喜欢的事，过自己想要的生活。不需要活给别人看。对婚姻我希望是自然而然发生的，不强求但也不排斥。最好是两个人在各自的领域都闪闪发光。', NULL, FALSE, FALSE, '2026-05-04 10:13:30'),
(198, 12, 12, 'AI', '在各自领域发光——这种关系很美。那感情中你怎么表达爱？', '{"extractedTraits":["career_oriented","long_term_goal","family_oriented"]}', FALSE, FALSE, '2026-05-04 10:14:00'),
(199, 12, 12, 'USER', '我可能比较含蓄吧，但我相信行动胜过语言。比如给对方设计一个专属的皮具，或者做一顿特别的晚餐。希望对方能读懂这些无声的温柔。', NULL, FALSE, FALSE, '2026-05-04 10:16:30'),
(200, 12, 12, 'AI', '用作品表达爱意真的很设计师。那关于异地，你怎么看？', '{"extractedTraits":["emotional_expressiveness","creative","conflict_avoidant"]}', FALSE, FALSE, '2026-05-04 10:17:00'),
(201, 12, 12, 'USER', '异地的话看缘分吧，如果真的很合适可以尝试，但我还是更希望能在上海。这座城市有我想要的一切，也希望能在这里找到那个人。', NULL, FALSE, FALSE, '2026-05-04 10:19:30'),
(202, 12, 12, 'AI', '最后问一个：你有什么恋爱中的雷区？', '{"extractedTraits":["openness_to_distance","partner_social_pref","importance_intelligence"]}', FALSE, FALSE, '2026-05-04 10:20:00'),
(203, 12, 12, 'USER', '不能接受邋遢不修边幅的人，还有就是不尊重别人时间的。守时对我来说很重要。还有就是不要太快节奏，我喜欢慢慢了解慢慢走近。', NULL, FALSE, FALSE, '2026-05-04 10:22:30'),
(204, 12, 12, 'AI', '王语嫣，谢谢你让我认识了一个如此懂得美的人。🎨 你用设计理解世界，用行动表达爱意。你期待的是一个成熟有品位、能读懂你安静语言的他。和你的布偶猫云朵一样，你值得被温柔地对待。祝你在上海这座精致的城市里，遇到一样精致的人。', NULL, FALSE, FALSE, '2026-05-04 10:23:00'),

-- ======== 用户 13: 张雨桐 (24, 深圳, 新媒体编辑) ========
(205, 13, 13, 'AI', '嗨张雨桐！我是你的交友助手~ 新媒体编辑还运营美食号，生活一定很精彩！', NULL, FALSE, FALSE, '2026-05-04 11:00:30'),
(206, 13, 13, 'USER', '哈哈是的！我性格比较活泼话多，美食探店号是业余做的但是粉丝已经上万了。喜欢吃也喜欢分享，每次发现新开的店第一个冲过去打卡。', NULL, FALSE, FALSE, '2026-05-04 11:01:30'),
(207, 13, 13, 'AI', '美食博主！那你觉得自己的性格是怎样的？', '{"extractedTraits":["adventurousness","activity_level","socialness"]}', FALSE, FALSE, '2026-05-04 11:02:00'),
(208, 13, 13, 'USER', '外向活泼，情绪来的快去得也快。表达欲很强，开心不开心都写在脸上。喜欢新鲜感，不能忍受无聊。朋友们都说我像小太阳一样，气氛组担当。', NULL, FALSE, FALSE, '2026-05-04 11:04:30'),
(209, 13, 13, 'AI', '小太阳！那你对人是不是也特别热情？社交对你来说重要吗？', '{"extractedTraits":["extroversion","emotional_expressiveness","openness"]}', FALSE, FALSE, '2026-05-04 11:05:00'),
(210, 13, 13, 'USER', '非常重要！我喜欢和人分享一切好玩的东西。朋友很多，经常组局吃饭。我觉得人生最大的乐趣就是和有趣的人一起吃好吃的东西。', NULL, FALSE, FALSE, '2026-05-04 11:07:30'),
(211, 13, 13, 'AI', '那这么有活力的你，遇到感情会是什么样？你期待什么样的男生？', '{"extractedTraits":["agreeableness","romantic"]}', FALSE, FALSE, '2026-05-04 11:08:00'),
(212, 13, 13, 'USER', '我也喜欢开朗幽默的男生，能陪我一起到处探店。对外表比较在意，喜欢会穿搭的。不接受异地，在深圳最好了。年龄的话和我差不多就好，相差不要超过8岁。', NULL, FALSE, FALSE, '2026-05-04 11:10:30'),
(213, 13, 13, 'AI', '在深圳、懂穿搭、爱美食——标准很具体。那聊聊你的三观？对未来有什么规划？', '{"extractedTraits":["partner_extroversion_pref","importance_appearance","partner_adventurous_pref","openness_to_distance"]}', FALSE, FALSE, '2026-05-04 11:11:00'),
(214, 13, 13, 'USER', '我比较活在当下，不太喜欢做太长远的规划。但希望自己的美食号能越做越大，变成全职的美食博主。感情方面不想太快，先享受恋爱的过程。', NULL, FALSE, FALSE, '2026-05-04 11:13:30'),
(215, 13, 13, 'AI', '享受当下，活在美食里——这样的生活态度很好。那在关系中，你比较看重对方的什么？', '{"extractedTraits":["career_oriented","long_term_goal","family_oriented"]}', FALSE, FALSE, '2026-05-04 11:14:00'),
(216, 13, 13, 'USER', '最重要的是能不能玩得到一起去。如果我喜欢探店他喜欢宅在家那肯定不合适。也希望对方有内涵，不能只会吃喝玩乐。还有就是要有包容心，我有时候会很粘人。', NULL, FALSE, FALSE, '2026-05-04 11:16:30'),
(217, 13, 13, 'AI', '玩得到一起去——这真的是很多人的心声。那你对异地有没有什么想法？', '{"extractedTraits":["importance_values","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-04 11:17:00'),
(218, 13, 13, 'USER', '异地真的不太行！我需要见面需要一起吃东西，视频聊天怎么能代替面对面呢。如果对方不在深圳，至少要愿意来深圳。', NULL, FALSE, FALSE, '2026-05-04 11:20:30'),
(219, 13, 13, 'AI', '最后问一个：你的雷区或者底线是什么？', '{"extractedTraits":["independence","conflict_avoidant"]}', FALSE, FALSE, '2026-05-04 11:21:00'),
(220, 13, 13, 'USER', '骗人绝对不可以，有小秘密可以但不能是大的。还有就是不要太过严肃和无聊的人，生活需要一点仪式感和趣味。', NULL, FALSE, FALSE, '2026-05-04 11:22:30'),
(221, 13, 13, 'AI', '哈哈张雨桐，你太可爱了！🍜 你是一个像火锅一样热烈而丰富的女孩，有你在的地方就不会冷场。你期待的是一个能陪你一起吃遍深圳每一条小巷的他——开朗、爱美食、懂得打扮。带着你的美食号和小太阳能量，你一定会遇到那个愿意陪你把深圳吃遍的人。', NULL, FALSE, FALSE, '2026-05-04 11:23:00'),

-- ======== 用户 14: 刘诗涵 (30, 杭州, 钢琴教师) ========
(222, 14, 14, 'AI', '嗨刘诗涵！我是你的交友助手~ 钢琴老师听起来就很优雅，先聊聊你的生活吧。', NULL, FALSE, FALSE, '2026-05-04 12:00:30'),
(223, 14, 14, 'USER', '我是一个比较安静的人。除了教琴之外，最喜欢做的事情就是读书和练字。周末会去听音乐会或者在家烤面包。杭州的四季都很美，每个季节都有不同的风景。', NULL, FALSE, FALSE, '2026-05-04 12:01:30'),
(224, 14, 14, 'AI', '练字、音乐会、烤面包……画面感好强。形容一下你的性格吧。', '{"extractedTraits":["creative","openness","agreeableness"]}', FALSE, FALSE, '2026-05-04 12:02:00'),
(225, 14, 14, 'USER', '我是安静温柔型，内心很丰富但不一定会表达出来。教琴需要耐心，这么多年下来我变得特别能等待。性格上有点内向，不太主动，但一旦熟悉了会展现很多面。', NULL, FALSE, FALSE, '2026-05-04 12:04:30'),
(226, 14, 14, 'AI', '安静而丰富，这种感觉很美。那在社交场合你会是什么样的？', '{"extractedTraits":["extroversion","emotional_expressiveness","independence"]}', FALSE, FALSE, '2026-05-04 12:05:00'),
(227, 14, 14, 'USER', '实话说不擅长社交，人多的场合会不自在。更喜欢一对一的深入交流。朋友不多但都很珍惜，每个都是经过了时间沉淀的。', NULL, FALSE, FALSE, '2026-05-04 12:07:30'),
(228, 14, 14, 'AI', '小圈子深交流，确实是很多内向型人的特点。那感情上呢，期待什么样的他？', '{"extractedTraits":["socialness","activity_level","romantic"]}', FALSE, FALSE, '2026-05-04 12:08:00'),
(229, 14, 14, 'USER', '希望他有绅士风度，有文化素养，成熟稳重。在杭州生活，最好也是从事教育或者文化相关的工作。不需要多富有，但要有精神追求。外表不必多出众，但要有气质。', NULL, FALSE, FALSE, '2026-05-04 12:10:30'),
(230, 14, 14, 'AI', '精神追求>物质条件，这个排序很吸引人。聊聊你对人生和婚姻的看法？', '{"extractedTraits":["partner_extroversion_pref","importance_values","importance_intelligence","importance_appearance"]}', FALSE, FALSE, '2026-05-04 12:11:00'),
(231, 14, 14, 'USER', '我觉得人生最重要的就是找到内心的平静。婚姻更像是两个灵魂的相伴，不是将就。如果遇到不合适的人，我宁愿一个人弹琴。希望对方也是以长期关系为目标的。', NULL, FALSE, FALSE, '2026-05-04 12:13:30'),
(232, 14, 14, 'AI', '两个灵魂的相伴——好优美的形容。那你是怎样表达爱意的？', '{"extractedTraits":["long_term_goal","family_oriented","creative"]}', FALSE, FALSE, '2026-05-04 12:14:00'),
(233, 14, 14, 'USER', '我可能比较含蓄，但希望用特别的、安静的方式。比如为对方弹一首曲子、做一顿健康美味的饭、写一封没有发送的信。希望对方能理解这种安静的深情。', NULL, FALSE, FALSE, '2026-05-04 12:16:30'),
(234, 14, 14, 'AI', '用音乐和食物表达爱，这很刘诗涵。你对于每天相处的频率怎么看？', '{"extractedTraits":["emotional_expressiveness","adventurousness"]}', FALSE, FALSE, '2026-05-04 12:17:00'),
(235, 14, 14, 'USER', '我觉得不需要每天腻在一起。各自有各自的生活，然后在精神的层面上相遇。当然如果已经在一个家里了，每天见面也是正常的。关键是质量而不是数量。', NULL, FALSE, FALSE, '2026-05-04 12:19:30'),
(236, 14, 14, 'AI', '最后问一下：有什么是感情中绝对不能碰的雷区？', '{"extractedTraits":["conflict_avoidant","intellectual","partner_social_pref"]}', FALSE, FALSE, '2026-05-04 12:20:00'),
(237, 14, 14, 'USER', '不尊重。还有就是太功利地看待感情，把婚姻当交易的人我完全不能接受。还有就是太大男子主义的，我希望双方是平等的。', NULL, FALSE, FALSE, '2026-05-04 12:22:30'),
(238, 14, 14, 'AI', '刘诗涵，和你聊天就像听一首安静的钢琴曲。🎹 你是一个内心丰富而优雅的女性，在喧嚣的世界里保有一方静谧。你期待的是一个有文化涵养、温和稳重的他，在杭州的西湖边一起走过四季。你的温柔值得被懂得的人珍视。祝你遇到那个能在你弹琴时安静聆听的人。', NULL, FALSE, FALSE, '2026-05-04 12:23:00'),

-- ======== 用户 15: 陈静怡 (27, 成都, 咖啡馆店主) ========
(239, 15, 15, 'AI', '嗨陈静怡！我是你的交友助手~ 开咖啡馆的人一定有很多温暖的故事吧？', NULL, FALSE, FALSE, '2026-05-05 09:00:30'),
(240, 15, 15, 'USER', '是啊！我咖啡馆开了三年了，自己烘豆子做甜品，每天早上闻着咖啡香醒来是最大的幸福。喜欢和客人聊天，有些熟客变成了好朋友。也喜欢听民谣，店里经常放着赵雷的歌~', NULL, FALSE, FALSE, '2026-05-05 09:01:30'),
(241, 15, 15, 'AI', '咖啡馆+民谣+成都，这组合太治愈了。形容一下自己的性格吧？', '{"extractedTraits":["creative","openness","agreeableness"]}', FALSE, FALSE, '2026-05-05 09:02:00'),
(242, 15, 15, 'USER', '朋友们都说我温暖随和，像一杯热巧克力一样让人舒服。我很享受照顾人的感觉，看到客人喝了我做的咖啡露出满足的表情就会很开心。性格比较乐天派，不太会计较。', NULL, FALSE, FALSE, '2026-05-05 09:04:30'),
(243, 15, 15, 'AI', '温暖随和热巧克力，这个比喻好可爱。社交呢？开店应该很考验社交能力吧。', '{"extractedTraits":["extroversion","emotional_expressiveness","socialness"]}', FALSE, FALSE, '2026-05-05 09:05:00'),
(244, 15, 15, 'USER', '对啊所以开店三年我的社交能力指数级增长哈哈。我很喜欢和人打交道，但也不是每时每刻都要social，偶尔也需要自己待着充充电。最喜欢的状态是在店里当"隐形人"，默默观察大家享受咖啡的样子。', NULL, FALSE, FALSE, '2026-05-05 09:07:30'),
(245, 15, 15, 'AI', '那这么温暖的你，理想中的男友应该是什么样？', '{"extractedTraits":["romantic","activity_level"]}', FALSE, FALSE, '2026-05-05 09:08:00'),
(246, 15, 15, 'USER', '希望他性格阳光、热爱生活。喜欢户外活动就更好了，可以带我一起出去玩！我自己是偏室内的，需要一个人拉我出去哈哈。在成都一起生活，周末可以来店里帮忙或者一起露营。', NULL, FALSE, FALSE, '2026-05-05 09:10:30'),
(247, 15, 15, 'AI', '互补型很甜蜜啊。那对人生你有哪些期待？', '{"extractedTraits":["partner_extroversion_pref","partner_adventurous_pref","importance_values","openness_to_distance"]}', FALSE, FALSE, '2026-05-05 09:11:00'),
(248, 15, 15, 'USER', '咖啡馆能越做越好，可能开个分店。不追求大富大贵，能做自己喜欢的事已经很幸福了。感情上希望能遇到一段不那么紧张的关系——轻轻松松在一起，互相支持各自的梦想。', NULL, FALSE, FALSE, '2026-05-05 09:13:30'),
(249, 15, 15, 'AI', '那你更喜欢什么样的人——相似的还是互补的？', '{"extractedTraits":["career_oriented","long_term_goal","family_oriented"]}', FALSE, FALSE, '2026-05-05 09:14:00'),
(250, 15, 15, 'USER', '互补的吧。我比较柔和，希望对方能更有行动力一些。但如果刚好遇到一个也爱咖啡爱民谣的人，那相似的也不错。不设限。', NULL, FALSE, FALSE, '2026-05-05 09:16:30'),
(251, 15, 15, 'AI', '那你对外表有什么要求吗？还有哪些是特别看重的？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-05 09:17:00'),
(252, 15, 15, 'USER', '外表顺眼就好，不是必须很帅。但是笑容很重要——一个笑起来好看的人会让人想多看几眼。还有就是内在，能和我聊得来、对世界保持好奇。', NULL, FALSE, FALSE, '2026-05-05 09:19:30'),
(253, 15, 15, 'AI', '那对于每天在一起的时间你有什么想法吗？', '{"extractedTraits":["independence","conflict_avoidant"]}', FALSE, FALSE, '2026-05-05 09:20:00'),
(254, 15, 15, 'USER', '每天能见到当然最好，但也要尊重彼此的节奏。我觉得最好的距离就是两个人在一起但各自有空间。给对方泡一杯咖啡然后各做各的事，那种舒适感很幸福。', NULL, FALSE, FALSE, '2026-05-05 09:22:30'),
(255, 15, 15, 'AI', '陈静怡，你的温暖透过屏幕都能感受到。☕ 你就像你泡的咖啡一样，温暖、有层次、带着一点点甜。你期待的是一个阳光开朗、能带你走出咖啡馆去探索世界的人。在成都这座温暖的城市里，你经营着一间温暖的小店，相信不久也会有一个人来点亮你的吧台。', NULL, FALSE, FALSE, '2026-05-05 09:23:00'),

-- ======== 用户 16: 赵梦婷 (29, 广州, 护士) ========
(256, 16, 16, 'AI', '嗨赵梦婷！我是你的交友助手~ 做护士一定很辛苦吧？你怎么放松自己？', NULL, FALSE, FALSE, '2026-05-05 10:00:30'),
(257, 16, 16, 'USER', '下班之后我最喜欢做手工，织毛线、戳羊毛毡、做布艺小摆件。养了两只虎斑猫，是捡回来的流浪猫现在被我养得胖胖的。会做饭，家常菜还行。', NULL, FALSE, FALSE, '2026-05-05 10:01:30'),
(258, 16, 16, 'AI', '手工+猫咪+做饭，好治愈的组合。那你觉得自己的性格是怎样的？', '{"extractedTraits":["creative","agreeableness","independence"]}', FALSE, FALSE, '2026-05-05 10:02:00'),
(259, 16, 16, 'USER', '细心体贴是职业素养，也是我的性格特点。对人对事都比较认真，比较能照顾别人的感受。不过有时候太能忍了，遇到不舒服的事也不会说出来。', NULL, FALSE, FALSE, '2026-05-05 10:04:30'),
(260, 16, 16, 'AI', '护士的细心和体贴真的很值得尊重。那社交方面呢？你是内向还是外向多一点？', '{"extractedTraits":["extroversion","emotional_expressiveness","conflict_avoidant"]}', FALSE, FALSE, '2026-05-05 10:05:00'),
(261, 16, 16, 'USER', '一半一半吧。工作上要一直和人打交道，所以私人时间会想安静一些。有几个关系特别好的闺蜜，周末一起吃饭聊天就很满足。', NULL, FALSE, FALSE, '2026-05-05 10:07:30'),
(262, 16, 16, 'AI', '那说说你对另一半的期待？', '{"extractedTraits":["socialness","activity_level","family_oriented"]}', FALSE, FALSE, '2026-05-05 10:08:00'),
(263, 16, 16, 'USER', '我希望对方在广州工作，有稳定的收入和职业。踏实靠谱是最重要的。不烟不酒加分，会做饭加分。年龄比我大一些或者差不多都可以，关键是人要好。', NULL, FALSE, FALSE, '2026-05-05 10:10:30'),
(264, 16, 16, 'AI', '踏实靠谱、人好——很务实的标准。对未来有什么规划吗？', '{"extractedTraits":["partner_extroversion_pref","importance_values","openness_to_distance","partner_adventurous_pref"]}', FALSE, FALSE, '2026-05-05 10:11:00'),
(265, 16, 16, 'USER', '希望在两年内能结婚吧，比较看重家庭。工作上继续做好护理工作，做一名优秀的护士长。觉得家庭和事业同样重要，希望对方也是认真对待生活的人。', NULL, FALSE, FALSE, '2026-05-05 10:13:30'),
(266, 16, 16, 'AI', '很踏实的规划。那你对外表和年龄这些外在条件怎么看？', '{"extractedTraits":["long_term_goal","romantic","career_oriented"]}', FALSE, FALSE, '2026-05-05 10:14:00'),
(267, 16, 16, 'USER', '外表的话舒服干净就好，不需要多帅。年龄大一点像30多岁的也可以，成熟稳重的更靠谱。身高和长相在我看来不是很重要，内心的踏实才是硬道理。', NULL, FALSE, FALSE, '2026-05-05 10:16:30'),
(268, 16, 16, 'AI', '那在关系中你一般是什么样的呢？会主动表达吗？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-05 10:17:00'),
(269, 16, 16, 'USER', '我觉得我是付出型的，会用自己的方式照顾对方。但不太擅长用言语表达，更多是通过行动——比如做一顿好饭给他吃。但也希望对方能看得到并回应。', NULL, FALSE, FALSE, '2026-05-05 10:19:30'),
(270, 16, 16, 'AI', '最后聊聊底线——有什么是绝对不能接受的？', '{"extractedTraits":["romantic","adventurousness","intellectual"]}', FALSE, FALSE, '2026-05-05 10:20:00'),
(271, 16, 16, 'USER', '不能接受欺骗和不诚实。还有就是游手好闲没有上进心的，两个人在一起要一起努力。还有就是家庭暴力绝对不行。', NULL, FALSE, FALSE, '2026-05-05 10:22:30'),
(272, 16, 16, 'AI', '赵梦婷，很高兴了解你。🌿 你是一个细心温柔、脚踏实地的好姑娘，像你养的那些猫猫一样真实可爱。你期待的是一份踏实稳定的感情，和一个同样认真生活的他一起组建温暖的小家。这份真诚一定会被值得的人看见。祝你的毛线球里也绕进爱情的线。', NULL, FALSE, FALSE, '2026-05-05 10:23:00'),

-- ======== 用户 17: 孙悦然 (25, 南京, 文学研究生) ========
(273, 17, 17, 'AI', '嗨孙悦然！我是你的交友助手~ 读比较文学的研究生，你的世界一定很精彩吧？', NULL, FALSE, FALSE, '2026-05-05 11:00:30'),
(274, 17, 17, 'USER', '我的世界在书里哈哈。研三了，准备继续读博，方向是比较文学。最喜欢的诗人是辛波斯卡，最近在研究她作品里的沉默主题。喜欢逛旧书店，南大附近那家旧书店是我最喜欢的地方。', NULL, FALSE, FALSE, '2026-05-05 11:01:30'),
(275, 17, 17, 'AI', '辛波斯卡和旧书店，好有深度的爱好。那你形容一下自己的性格吧。', '{"extractedTraits":["intellectual","openness","creative"]}', FALSE, FALSE, '2026-05-05 11:02:00'),
(276, 17, 17, 'USER', '我是一个很内向的人，偏安静。比较敏感，能从文字和画面里捕捉到很多情绪。不太擅长社交，但如果是谈文学和哲学我可以聊很久。有自己的小世界。', NULL, FALSE, FALSE, '2026-05-05 11:04:30'),
(277, 17, 17, 'AI', '内向但有丰富的内在世界。那社交对你来说意味着什么？', '{"extractedTraits":["extroversion","emotional_expressiveness","socialness"]}', FALSE, FALSE, '2026-05-05 11:05:00'),
(278, 17, 17, 'USER', '社交是有限的——对我来说是需要能量而不是给予能量。但我珍惜深度关系，喜欢和人有一对一的思想交流。朋友很少，但每一个都能聊到很深的程度。', NULL, FALSE, FALSE, '2026-05-05 11:07:30'),
(279, 17, 17, 'AI', '深度的思想交流，这正是最珍贵的。那你对另一半有什么期待？', '{"extractedTraits":["agreeableness","romantic","activity_level"]}', FALSE, FALSE, '2026-05-05 11:08:00'),
(280, 17, 17, 'USER', '我希望他有学识有思想，能和我聊文学聊电影聊哲学。不太在乎外表，更看重智商和情商。希望他也能有自己热爱的事情，最好在南京。年龄不要太小，比我大一点成熟一点好。', NULL, FALSE, FALSE, '2026-05-05 11:10:30'),
(281, 17, 17, 'AI', '学识思想、智商情商——确实是灵魂伴侣的标准。那对生活你有什么向往？', '{"extractedTraits":["partner_extroversion_pref","importance_intelligence","importance_values","importance_appearance"]}', FALSE, FALSE, '2026-05-05 11:11:00'),
(282, 17, 17, 'USER', '我希望毕业之后能在高校工作，继续做研究。生活不需要大富大贵，能安静读书写字就够了。感情方面期待一个真正理解我的人，不需要改变我，而是和我一起在书的海洋里航行。', NULL, FALSE, FALSE, '2026-05-05 11:13:30'),
(283, 17, 17, 'AI', '在书的海洋里航行——你果然是个诗人。那你觉得好的感情应该是什么样？', '{"extractedTraits":["career_oriented","long_term_goal","family_oriented"]}', FALSE, FALSE, '2026-05-05 11:14:00'),
(284, 17, 17, 'USER', '好的感情就是两个人在各自的轨道上运行，但互相照亮。不需要时时刻刻粘在一起，但当你在深夜看书感到孤独的时候，知道有一个人在也在某个地方为你亮着灯。', NULL, FALSE, FALSE, '2026-05-05 11:16:30'),
(285, 17, 17, 'AI', '互相照亮——这才是诗一样的爱情观。那你有不能接受的雷区吗？', '{"extractedTraits":["conflict_avoidant","independence","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-05 11:17:00'),
(286, 17, 17, 'USER', '不能接受肤浅的人。也不能接受试图改变我的人。还有就是对知识没有敬畏心的人。如果一个人对世界的态度是傲慢和封闭的，那完全谈不来。', NULL, FALSE, FALSE, '2026-05-05 11:19:30'),
(287, 17, 17, 'AI', '对于异地和年龄你有什么特别的偏好吗？', '{"extractedTraits":["openness_to_distance","partner_adventurous_pref","partner_social_pref"]}', FALSE, FALSE, '2026-05-05 11:20:00'),
(288, 17, 17, 'USER', '异地的话短期可以，长期还是要在一个城市。我希望两人的交流是面对面的那种有质感。年龄的话28-40都可以，关键是思想的成熟度。', NULL, FALSE, FALSE, '2026-05-05 11:22:30'),
(289, 17, 17, 'AI', '孙悦然，很感谢你让我看到了一个如此深邃的灵魂。📖 你是那种在安静的表面下藏着星河的人。你期待的是一段智识和精神上的共鸣，和一个同样热爱思考、懂得欣赏沉默的他。正如辛波斯卡的诗所说的——"我偏爱没有星星的夜晚"。祝愿你遇见那个为你点亮灯的人。', NULL, FALSE, FALSE, '2026-05-05 11:23:00'),

-- ======== 用户 18: 周蕾 (31, 武汉, 注册会计师) ========
(290, 18, 18, 'AI', '嗨周蕾！我是你的交友助手~ 做审计还拿下了CPA，了不起！平时怎么放松？', NULL, FALSE, FALSE, '2026-05-05 12:00:30'),
(291, 18, 18, 'USER', '我生活中和工作中差别还挺大的。工作的时候专业严谨，生活里就比较大大咧咧。最喜欢旅行和美食，每年至少两次长途旅行，已经去过十几个国家了。平时也喜欢做饭，拿手菜是啤酒鸭。', NULL, FALSE, FALSE, '2026-05-05 12:01:30'),
(292, 18, 18, 'AI', '旅行美食啤酒鸭——生活中的你很有趣！形容一下你的性格？', '{"extractedTraits":["adventurousness","openness","activity_level"]}', FALSE, FALSE, '2026-05-05 12:02:00'),
(293, 18, 18, 'USER', '我的性格就是简单直接，不喜欢绕弯子。工作上很细致但生活里大大咧咧，有时候会丢三落四的。比较乐观，遇到困难也会尽快调整。善于快速做决定，行动派。', NULL, FALSE, FALSE, '2026-05-05 12:04:30'),
(294, 18, 18, 'AI', '行动派+乐观主义，很有魅力。社交方面呢？', '{"extractedTraits":["extroversion","agreeableness","emotional_expressiveness"]}', FALSE, FALSE, '2026-05-05 12:05:00'),
(295, 18, 18, 'USER', '我还挺喜欢社交的，朋友聚会吃喝玩乐我一般都在。但也需要独处的时间来充电。比较能交朋友，旅行中也总能认识当地人和驴友。', NULL, FALSE, FALSE, '2026-05-05 12:07:30'),
(296, 18, 18, 'AI', '那你在感情中比较看重什么？理想中他是什么样？', '{"extractedTraits":["socialness","independence"]}', FALSE, FALSE, '2026-05-05 12:08:00'),
(297, 18, 18, 'USER', '我希望他经济独立、思想成熟。最好在武汉或愿意来武汉。也喜欢旅行就更好了，可以一起探索世界。年龄大一点小一点都可以，但要成熟能沟通。不喜欢太矫情的男生。', NULL, FALSE, FALSE, '2026-05-05 12:10:30'),
(298, 18, 18, 'AI', '经济独立、思想成熟——很清晰。那人生目标呢？', '{"extractedTraits":["partner_extroversion_pref","importance_values","openness_to_distance","partner_adventurous_pref"]}', FALSE, FALSE, '2026-05-05 12:11:00'),
(299, 18, 18, 'USER', '职业上继续做好审计，可能将来去企业做财务总监。也希望有一个稳定温暖的家庭。我觉得事业和家庭完全可以兼顾，关键是找对人。', NULL, FALSE, FALSE, '2026-05-05 12:13:30'),
(300, 18, 18, 'AI', '兼顾家庭和事业——很有抱负。那外貌年龄这些外在条件你怎么看？', '{"extractedTraits":["career_oriented","long_term_goal","family_oriented"]}', FALSE, FALSE, '2026-05-05 12:14:00'),
(301, 18, 18, 'USER', '外表的话顺眼就行，但身高不能太矮。年龄的话30-45都可以接受。我更看重的是对方的阅历和见识——一个人走过多少路比长什么样重要太多。', NULL, FALSE, FALSE, '2026-05-05 12:16:30'),
(302, 18, 18, 'AI', '那你觉得自己在感情中是更偏向需要还是被需要？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-05 12:17:00'),
(303, 18, 18, 'USER', '两者都需要。但我不依赖别人提供情绪价值，自己也能过得很好。只是如果有个人能在你累了一天之后给你做晚饭或者陪你聊天，那生活会更有意思。', NULL, FALSE, FALSE, '2026-05-05 12:19:30'),
(304, 18, 18, 'AI', '最后聊一下你的雷区吧！', '{"extractedTraits":["romantic","conflict_avoidant","creative"]}', FALSE, FALSE, '2026-05-05 12:20:00'),
(305, 18, 18, 'USER', '不能接受小气和记仇的人。还有就是太黏人的，我需要个人空间。还有就是对你花心的人，忠诚是最基本的。', NULL, FALSE, FALSE, '2026-05-05 12:22:30'),
(306, 18, 18, 'AI', '周蕾，很高兴认识到你的另一面。✈️ 你是一个独立又爱笑的人，工作上严谨专业，生活中大大咧咧。你期待的是一段相互尊重也相互独立的关系，和一个成熟有见识的他一起走遍地图上的每个角落。你已经去过了十几个国家，相信你的爱情地图上很快就会多一个目的地。', NULL, FALSE, FALSE, '2026-05-05 12:23:00'),

-- ======== 用户 19: 吴欣怡 (23, 西安, 前端开发) ========
(307, 19, 19, 'AI', '嗨吴欣怡！我是你的交友助手~ 做前端开发还喜欢二次元，感觉你是个有趣的人！', NULL, FALSE, FALSE, '2026-05-06 09:00:30'),
(308, 19, 19, 'USER', '哈哈谢谢！我超喜欢二次元和cosplay，平时也会去漫展。周末不是在写代码就是在刷番追漫画。性格比较活泼，笑点很低，随便一个表情包都能笑半天。', NULL, FALSE, FALSE, '2026-05-06 09:01:30'),
(309, 19, 19, 'AI', '笑点低是个可爱的特质！你形容一下自己的性格？', '{"extractedTraits":["extroversion","emotional_expressiveness","openness"]}', FALSE, FALSE, '2026-05-06 09:02:00'),
(310, 19, 19, 'USER', '我算是外向活泼的类型，在团队里比较活跃。比较乐观，遇到烦心的事也能很快调整。但是不太适合严肃的场合，一正式就不自在了。喜欢轻松自由的生活方式。', NULL, FALSE, FALSE, '2026-05-06 09:04:30'),
(311, 19, 19, 'AI', '轻松自由——这才是年轻人的生活态度。那社交方面你是什么样的？', '{"extractedTraits":["agreeableness","activity_level"]}', FALSE, FALSE, '2026-05-06 09:05:00'),
(312, 19, 19, 'USER', '社交还可以！在漫展上认识了特别多好朋友。线上交流没什么障碍，现实中也挺能聊的。但不喜欢那种特别正式的社交场合，喜欢轻松随意的方式。', NULL, FALSE, FALSE, '2026-05-06 09:07:30'),
(313, 19, 19, 'AI', '那说说你的择偶观吧！你理想中的男友是什么样的？', '{"extractedTraits":["socialness","independence","romantic"]}', FALSE, FALSE, '2026-05-06 09:08:00'),
(314, 19, 19, 'USER', '希望他也喜欢二次元或者至少不排斥！性格有趣很重要，能一起打游戏刷番看漫展简直是理想状态。年龄24-30之间，在西安或者在周边城市。打游戏加一百分！', NULL, FALSE, FALSE, '2026-05-06 09:10:30'),
(315, 19, 19, 'AI', '二次元+游戏，这个男友画像很具体。那对未来你有什么打算？', '{"extractedTraits":["partner_extroversion_pref","partner_adventurous_pref","importance_values","openness_to_distance"]}', FALSE, FALSE, '2026-05-06 09:11:00'),
(316, 19, 19, 'USER', '职业上先在前端方向上积累经验，可能以后做全栈。感情上不急，先谈着开心就好。我觉得年轻的时候应该多体验，但也希望能找到志同道合的人。', NULL, FALSE, FALSE, '2026-05-06 09:13:30'),
(317, 19, 19, 'AI', '多体验再决定，很成熟。那你比较看重对方的哪些特质？', '{"extractedTraits":["career_oriented","long_term_goal","family_oriented"]}', FALSE, FALSE, '2026-05-06 09:14:00'),
(318, 19, 19, 'USER', '最重要的是有趣！还有就是要尊重我的爱好，不能说cosplay是幼稚的东西。外表嘛会穿搭就好，不要穿得像程序员——哦等等我自己就是程序员哈哈！', NULL, FALSE, FALSE, '2026-05-06 09:16:30'),
(319, 19, 19, 'AI', '哈哈哈程序员穿搭被精准吐槽了！那在相处中你有什么特别的需求吗？', '{"extractedTraits":["importance_appearance","importance_intelligence","partner_social_pref"]}', FALSE, FALSE, '2026-05-06 09:17:00'),
(320, 19, 19, 'USER', '我需要被理解和被包容，毕竟有时候会突然冒出来一些二次元梗。希望对方能接得住或者至少配合一下。还有就是要有一些共同的娱乐活动，不然各玩各的就没什么意思了。', NULL, FALSE, FALSE, '2026-05-06 09:19:30'),
(321, 19, 19, 'AI', '最后说说你的雷区！', '{"extractedTraits":["creative","adventurousness","conflict_avoidant"]}', FALSE, FALSE, '2026-05-06 09:20:00'),
(322, 19, 19, 'USER', '不能接受太严肃整天板着脸的人。还有就是不能接受嘲笑别人爱好的，尊重是底线。还有就是太负能量的人，我需要阳光一点的氛围。', NULL, FALSE, FALSE, '2026-05-06 09:22:30'),
(323, 19, 19, 'AI', '吴欣怡，和你聊天太快乐了！🎮 你就像一个从二次元里走出来的活力少女，活泼可爱不设防。你期待的是一个能和你一起打游戏刷番逛漫展的他——有趣是第一标准，尊重是硬性底线。带着你的电脑、你的cos服和你的小太阳性格，在西安一定会遇到那个懂你梗的人。', NULL, FALSE, FALSE, '2026-05-06 09:23:00'),

-- ======== 用户 20: 郑媛 (35, 重庆, 合伙律师) ========
(324, 20, 20, 'AI', '嗨郑媛！我是你的交友助手~ 律所合伙人，这个头衔很有分量。工作这么忙，你怎么平衡生活的？', NULL, FALSE, FALSE, '2026-05-06 10:00:30'),
(325, 20, 20, 'USER', '说不忙是假的，但我一直坚持每周至少做两次饭，追一两部剧。每年必看一场话剧，这是我和自己的约定。生活再忙也不该被掏空，你需要有输入也有输出。', NULL, FALSE, FALSE, '2026-05-06 10:01:30'),
(326, 20, 20, 'AI', '做饭、追剧、话剧——你的生活很有质感。形容一下自己的性格？', '{"extractedTraits":["independence","openness","activity_level"]}', FALSE, FALSE, '2026-05-06 10:02:00'),
(327, 20, 20, 'USER', '我是目标感和执行力都很强的人。做律师这一行，需要果断、需要魄力，也需要情商。过去十年都在拼事业，现在觉得自己各方面都挺成熟的。性格比较直爽，也愿意倾听。', NULL, FALSE, FALSE, '2026-05-06 10:04:30'),
(328, 20, 20, 'AI', '那社交场合里你一般是什么样的？', '{"extractedTraits":["extroversion","agreeableness","career_oriented"]}', FALSE, FALSE, '2026-05-06 10:05:00'),
(329, 20, 20, 'USER', '工作上社交很多，商务场合对我来说是主场。但私人生活中我喜欢比较小范围的聚会。朋友不需要太多，但要真心的。现在这个年纪，能说真心话的朋友是最大的财富。', NULL, FALSE, FALSE, '2026-05-06 10:07:30'),
(330, 20, 20, 'AI', '那说说你的择偶标准吧。什么样的人配得上一个合伙律师？', '{"extractedTraits":["socialness","emotional_expressiveness","romantic"]}', FALSE, FALSE, '2026-05-06 10:08:00'),
(331, 20, 20, 'USER', '他一定要成熟稳重——思想上的成熟，不是年龄。有事业心和格局，能理解一个事业型女性。在重庆生活最好，但也不强求。希望他也是一个有追求的人，互相尊重互相成就。', NULL, FALSE, FALSE, '2026-05-06 10:10:30'),
(332, 20, 20, 'AI', '相互成就——这个标准很高也很有深度。那你对未来的人生有什么规划？', '{"extractedTraits":["partner_extroversion_pref","importance_values","long_term_goal","openness_to_distance"]}', FALSE, FALSE, '2026-05-06 10:11:00'),
(333, 20, 20, 'USER', '事业上继续把律所带好。家庭方面我一直都想要，只是以前没有时间为它创造机会。现在觉得自己准备好了，想要一个能在人生后半程并肩的战友。', NULL, FALSE, FALSE, '2026-05-06 10:13:30'),
(334, 20, 20, 'AI', '那在爱情中你比较看重什么？外表、性格还是其他？', '{"extractedTraits":["family_oriented","importance_intelligence"]}', FALSE, FALSE, '2026-05-06 10:14:00'),
(335, 20, 20, 'USER', '格局和品格最重要。一个男人有没有胸襟，遇到事情怎么处理，比外表重要千万倍。外表的话保持干净得体就好了。我希望两个人能互相欣赏而不是互相将就。', NULL, FALSE, FALSE, '2026-05-06 10:16:30'),
(336, 20, 20, 'AI', '你觉得在感情中你是怎么表达爱意的？', '{"extractedTraits":["importance_appearance","creative","partner_adventurous_pref"]}', FALSE, FALSE, '2026-05-06 10:17:00'),
(337, 20, 20, 'USER', '我可能不太会说甜言蜜语，但我会用自己的方式照顾对方。比如帮他处理一些实际问题，或者在他忙的时候把家里的事都安排好。成熟的感情不需要太多的花言巧语。', NULL, FALSE, FALSE, '2026-05-06 10:19:30'),
(338, 20, 20, 'AI', '最后说一下你有什么雷区？', '{"extractedTraits":["conflict_avoidant","intellectual","partner_social_pref"]}', FALSE, FALSE, '2026-05-06 10:20:00'),
(339, 20, 20, 'USER', '不能接受小心眼的男人。还有就是没有上进心的，我不需要一个整天躺着的儿子。还有就是对你的职业指手画脚的人——我不需要别人来定义我该不该做什么。', NULL, FALSE, FALSE, '2026-05-06 10:22:30'),
(340, 20, 20, 'AI', '郑媛，非常尊重你这样的女性。⚖️ 你用自己的能力证明了女性的力量——独立、睿智、不将就。你期待的是一个成熟有格局、能与你并肩作战的他。走过了拼事业的十年，现在的生活需要一个新的维度。相信在重庆的江边，会有一个人懂得欣赏你的高度。', NULL, FALSE, FALSE, '2026-05-06 10:23:00');

-- ========== 7. user_traits（从 traits_summary 解析，source_message_id 指向对应 AI 轮次消息） ==========

INSERT INTO user_traits (profile_id, trait_name, trait_value, confidence, source_message_id)
SELECT
    p.id,
    JSON_UNQUOTE(JSON_EXTRACT(jt.val, '$.name')),
    CAST(JSON_EXTRACT(jt.val, '$.value') AS DECIMAL(5,4)),
    CAST(JSON_EXTRACT(jt.val, '$.confidence') AS DECIMAL(5,4)),
    (p.id - 1) * 17 + 3 + ((jt.rn - 1) % 7) * 2
FROM profiles p
CROSS JOIN JSON_TABLE(
    p.traits_summary,
    '$[*]' COLUMNS (
        val JSON PATH '$',
        rn FOR ORDINALITY
    )
) jt
WHERE p.id BETWEEN 1 AND 20;

-- ========== 8. 示例匹配记录（含 match_reason JSON） ==========
-- 手动创建一对匹配：user 1（张明远）和 user 11（李晓萱），模拟本周五匹配

INSERT INTO matches (id, user1_id, user2_id, match_week, compatibility_score, match_reason, status, created_at) VALUES
(1, 1, 11, '2026-05-22', 0.7842,
 '{"traitSimilarity":0.7621,"semanticSimilarity":0.7134,"preferenceMatch":0.8500,"complementarity":0.6230,"idealPartnerMatch":0.7456,"totalScore":0.7842}',
 'ACTIVE', '2026-05-16 18:00:00');

-- ========== 9. 匹对对话 ==========
INSERT INTO conversations (id, user_id, conversation_type, participant_id, match_id, title, status, created_at, updated_at) VALUES
(21, 1,  'MATCH', 11, 1, '李晓萱', 'ACTIVE', '2026-05-16 18:05:00', '2026-05-16 18:05:00'),
(22, 11, 'MATCH', 1,  1, '张明远', 'ACTIVE', '2026-05-16 18:05:00', '2026-05-16 18:05:00');
