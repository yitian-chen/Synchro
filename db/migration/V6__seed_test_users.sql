-- V5__seed_test_users.sql
-- 生成 20 个测试用户（10男10女），所有用户状态为 ACTIVE，已开通匹配
-- 测试登录密码均为：password123
-- BCrypt hash: $2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy

-- ========== 清理已有数据（按外键依赖顺序） ==========
DELETE FROM messages;
DELETE FROM conversations;
DELETE FROM matches;
DELETE FROM user_traits;
DELETE FROM profiles;
DELETE FROM refresh_tokens;
DELETE FROM users;

-- ========== 重置自增ID ==========
ALTER TABLE users AUTO_INCREMENT = 1;
ALTER TABLE profiles AUTO_INCREMENT = 1;
ALTER TABLE user_traits AUTO_INCREMENT = 1;
ALTER TABLE matches AUTO_INCREMENT = 1;
ALTER TABLE conversations AUTO_INCREMENT = 1;
ALTER TABLE messages AUTO_INCREMENT = 1;
ALTER TABLE refresh_tokens AUTO_INCREMENT = 1;

-- ========== 插入 20 个测试用户 ==========
INSERT INTO users (id, email, password_hash, nickname, avatar_url, status, onboarding_completed, matching_opt_in, created_at, updated_at) VALUES
-- 男性用户 (1-10)
(1,  'test1@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '张明远', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(2,  'test2@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '李浩然', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(3,  'test3@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '王子涵', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(4,  'test4@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '刘思远', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(5,  'test5@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '陈天宇', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(6,  'test6@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '赵俊杰', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(7,  'test7@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '孙浩宇', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(8,  'test8@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '周文博', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(9,  'test9@synchro.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '吴子轩', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(10, 'test10@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '郑凯文', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
-- 女性用户 (11-20)
(11, 'test11@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '李晓萱', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(12, 'test12@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '王语嫣', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(13, 'test13@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '张雨桐', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(14, 'test14@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '刘诗涵', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(15, 'test15@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '陈静怡', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(16, 'test16@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '赵梦婷', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(17, 'test17@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '孙悦然', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(18, 'test18@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '周　蕾', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(19, 'test19@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '吴欣怡', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW()),
(20, 'test20@synchro.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '郑　媛', NULL, 'ACTIVE', TRUE, TRUE, NOW(), NOW());

-- ========== 插入 20 个用户资料 ==========
INSERT INTO profiles (user_id, bio, age, gender, location, preferences, matching_preference, ideal_partner_description) VALUES

-- 男 1: 张明远 (28, 北京, 程序员, 户外运动/摄影)
(1,
 '在一家互联网公司做后端开发，代码写累了就背着相机去京郊爬山。周末喜欢约朋友打羽毛球，偶尔在家研究咖啡拉花。养了一只橘猫，叫"火锅"。',
 28, 'MALE', '北京',
 '{"occupation":"后端开发工程师","education":"本科","interests":["摄影","爬山","羽毛球","咖啡","养猫"]}',
 'BALANCED',
 '希望对方性格开朗，有自己热爱的事情。不需要跟我有完全相同的爱好，但愿意一起尝试新事物。坐标北京，不接受异地。'),

-- 男 2: 李浩然 (30, 上海, 金融产品经理)
(2,
 '在陆家嘴做金融产品，工作日西装革履，周末最爱穿T恤逛菜市场。喜欢做饭，拿手菜是红烧肉和糖醋排骨。每周坚持健身三次，最近在学油画。',
 30, 'MALE', '上海',
 '{"occupation":"金融产品经理","education":"硕士","interests":["做饭","健身","油画","美食探店","阅读"]}',
 'SIMILAR',
 '希望对方有相似的职业背景和生活节奏，本科以上学历。喜欢有主见、有追求的女生，能一起在上海奋斗也能一起享受生活。'),

-- 男 3: 王子涵 (26, 深圳, UI设计师)
(3,
 '在科技公司做UI设计，对美有执念。平时喜欢逛展览、看独立电影，也喜欢自己画插画。性格偏内向但熟了之后话很多，属于慢热型。不烟少酒，生活作息规律。',
 26, 'MALE', '深圳',
 '{"occupation":"UI/UX设计师","education":"本科","interests":["插画","看展","独立电影","摄影","手账"]}',
 'COMPLEMENTARY',
 '希望对方性格比我外向一些，能互补。喜欢有分享欲的女生，可以跟我聊日常琐事也可以聊人生理想。对艺术有一定兴趣更好。'),

-- 男 4: 刘思远 (32, 杭州, 创业者)
(4,
 '在杭州创业做跨境电商，公司已经B轮了。工作很忙但很注重生活品质，每天早上六点跑步，晚上再忙也会抽时间读书。喜欢滑雪和潜水，每年至少一次长途旅行。',
 32, 'MALE', '杭州',
 '{"occupation":"创业者/跨境电商","education":"硕士","interests":["跑步","滑雪","潜水","旅行","商业阅读"]}',
 'BALANCED',
 '希望对方情绪稳定、有独立人格。理解创业的忙碌但也能安排好自己的生活。不接受过于黏人的关系，相信"各自优秀，互相成就"。'),

-- 男 5: 陈天宇 (27, 成都, 独立摄影师)
(5,
 '自由摄影师，主要拍人像和城市风光。工作时间自由，收入不稳定但够花。性格随和乐天派，觉得人生最重要的是体验。会弹吉他，偶尔在街头路演。养了一只边境牧羊犬。',
 27, 'MALE', '成都',
 '{"occupation":"独立摄影师","education":"本科","interests":["摄影","吉他","旅行","徒步","宠物"]}',
 'COMPLEMENTARY',
 '希望对方也有对生活的热情，不一定要爱冒险但不接受宅到发霉。性格随和、不较真，对物质要求不太高的女生。喜欢小动物加分。'),

-- 男 6: 赵俊杰 (29, 广州, 数据分析师)
(6,
 '在大厂做数据相关的工作，工作中喜欢用数据说话，生活中反而很感性。煲汤手艺一流，喜欢研究广式茶点。性格耐心温和，朋友评价是"情绪稳定的成年人"。',
 29, 'MALE', '广州',
 '{"occupation":"数据分析师","education":"本科","interests":["煲汤","茶点","阅读","跑步","桌游"]}',
 'SIMILAR',
 '希望对方也在广深地区，性格温和好沟通。不喜欢冷战，有问题愿意坐下来聊。有自己的事业和生活圈就好。'),

-- 男 7: 孙浩宇 (25, 南京, 中学教师)
(7,
 '在南京一所高中教语文，享受跟学生在一起的感觉。业余时间喜欢写写文章，给几个公众号供稿。典型的老南京人，对这座城市的大街小巷了如指掌。',
 25, 'MALE', '南京',
 '{"occupation":"高中语文教师","education":"硕士","interests":["写作","阅读","逛博物馆","跑步","喝茶"]}',
 'BALANCED',
 '希望对方善良真诚，对生活有感恩之心。不需要多漂亮但要有书卷气，能一起逛书店、泡图书馆的那种。'),

-- 男 8: 周文博 (31, 武汉, 医生)
(8,
 '武汉同济的骨科医生，工作时间长但不影响我对生活的热爱。喜欢在阳台上种花养草，休班时就骑车去东湖边发呆。为人正直可靠，朋友说跟我在一起很有安全感。',
 31, 'MALE', '武汉',
 '{"occupation":"骨科医生","education":"博士","interests":["园艺","骑行","阅读","烹饪","围棋"]}',
 'SIMILAR',
 '希望对方有稳定工作，能理解医生的工作节奏（值班、加班是常态）。性格温柔体贴，有耐心。体制内工作加分。'),

-- 男 9: 吴子轩 (24, 西安, 研究生)
(9,
 '在西交大读计算机研二，明年毕业。喜欢打篮球和玩主机游戏，属于那种爱学习也会玩的类型。性格幽默开朗，朋友评价是"行走的快乐源泉"。',
 24, 'MALE', '西安',
 '{"occupation":"计算机硕士研究生","education":"硕士在读","interests":["篮球","主机游戏","看电影","桌游","健身"]}',
 'COMPLEMENTARY',
 '希望对方年龄相仿，性格活泼开朗。能一起打游戏最好，不打也行。对学历没有硬性要求，聊得来最重要。'),

-- 男 10: 郑凯文 (33, 重庆, 律师)
(10,
 '在重庆做执业律师，主要做民商事诉讼。工作压力大但很会解压——吃火锅、爬山、钓鱼。性格直爽，重庆人嘛，有啥说啥。不烟，应酬时少量饮酒。',
 33, 'MALE', '重庆',
 '{"occupation":"执业律师","education":"硕士","interests":["火锅","爬山","钓鱼","健身","看电影"]}',
 'BALANCED',
 '希望对方性格直爽好相处，不喜欢拐弯抹角。年龄25-33之间，在重庆生活。有自己的事业或追求。'),

-- 女 11: 李晓萱 (26, 北京, 市场经理)
(11,
 '在望京一家外企做市场，工作节奏快但乐在其中。周末喜欢去胡同里探店、逛咖啡馆。性格开朗独立，一个人也能把生活过得精彩。喜欢看话剧和脱口秀。',
 26, 'FEMALE', '北京',
 '{"occupation":"市场经理","education":"本科","interests":["探店","咖啡","话剧","脱口秀","瑜伽"]}',
 'BALANCED',
 '希望对方在北京，175以上，有上进心和责任心。成熟但不沉闷，有自己的爱好和社交圈。不爱大男子主义。'),

-- 女 12: 王语嫣 (28, 上海, 时尚设计师)
(12,
 '在一家独立设计师品牌工作，每天跟布料和色彩打交道。喜欢看展、逛买手店，也喜欢自己做手工皮具。独立理性，对生活品质有要求。养了一只布偶猫。',
 28, 'FEMALE', '上海',
 '{"occupation":"时尚设计师","education":"本科","interests":["看展","手工皮具","时尚","烘焙","旅行"]}',
 'COMPLEMENTARY',
 '希望对方有审美有品位，穿搭得体。成熟稳重、情绪稳定。最好也喜欢小动物。年龄在30-35之间。'),

-- 女 13: 张雨桐 (24, 深圳, 新媒体编辑)
(13,
 '在科技媒体做编辑，日常追热点写稿。性格活泼话多，社交牛杂症——在熟人面前是话痨，在陌生人面前很文静。喜欢拍照记录生活，业余经营一个美食探店账号。',
 24, 'FEMALE', '深圳',
 '{"occupation":"新媒体编辑","education":"本科","interests":["摄影","美食探店","写作","跳舞","看展"]}',
 'SIMILAR',
 '希望对方也爱美食，能一起探店的那种。性格开朗幽默，三观正。年龄上下5岁以内，不接受异地。颜值过关很重要。'),

-- 女 14: 刘诗涵 (30, 杭州, 钢琴教师)
(14,
 '从小弹钢琴，现在是音乐学院的一名钢琴老师。性格安静温柔，喜欢读书和练字。周末有时会在西湖边的茶室弹琴，算是一个小小的雅集活动。',
 30, 'FEMALE', '杭州',
 '{"occupation":"钢琴教师","education":"硕士","interests":["钢琴","阅读","书法","茶道","园艺"]}',
 'BALANCED',
 '希望对方有绅士风度，有文化素养。不需要懂音乐，但愿意尊重和支持我的工作。成熟稳重，情绪稳定。不接受暴躁易怒的人。'),

-- 女 15: 陈静怡 (27, 成都, 咖啡馆店主)
(15,
 '在锦里附近开了一家小小的独立咖啡馆，自己烘豆子、做甜品。生活节奏慢但充实。性格温暖随和，喜欢跟客人聊天交朋友。闲暇时喜欢徒步和露营。',
 27, 'FEMALE', '成都',
 '{"occupation":"咖啡馆店主","education":"本科","interests":["咖啡","甜品","徒步","露营","阅读"]}',
 'COMPLEMENTARY',
 '希望对方性格阳光、热爱生活。不要求多有钱但要愿意享受生活。能接受我偶尔的文艺矫情。喜欢户外活动加分。'),

-- 女 16: 赵梦婷 (29, 广州, 护士)
(16,
 '在广州三甲医院做护士，工作辛苦但很有成就感。性格细心体贴但也很能吃苦。休息时喜欢逛公园、做手工、看综艺放松。',
 29, 'FEMALE', '广州',
 '{"occupation":"护士","education":"本科","interests":["手工","逛公园","看综艺","烘焙","养多肉"]}',
 'SIMILAR',
 '希望对方在广州工作，有稳定收入。性格踏实靠谱、有责任心。能偶尔浪漫但不能太飘。不接受抽烟和沉迷游戏的。'),

-- 女 17: 孙悦然 (25, 南京, 文学研究生)
(17,
 '在南京大学读比较文学研三，准备继续读博。日常就是看书、写论文、逛先锋书店。偶尔写写诗，在文学杂志上发表过几篇短篇小说。性格安静、爱思考。',
 25, 'FEMALE', '南京',
 '{"occupation":"比较文学研究生","education":"硕士在读","interests":["阅读","写作","逛书店","看电影","逛博物馆"]}',
 'BALANCED',
 '希望对方有学识有思想，能跟我聊文学聊电影。不要求是文艺青年，但不能是毫无精神追求的人。温柔善良比帅更重要。'),

-- 女 18: 周蕾 (31, 武汉, 注册会计师)
(18,
 '在武汉一家会计师事务所做审计，CPA持证。工作中严谨细致，生活中反而有些大大咧咧。喜欢旅行和美食，人生信条是"认真工作，尽情享受"。',
 31, 'FEMALE', '武汉',
 '{"occupation":"注册会计师","education":"本科","interests":["旅行","美食","瑜伽","看书","看电影"]}',
 'COMPLEMENTARY',
 '希望对方经济独立、思想成熟。对生活有规划但不会死板。年龄30-38之间，在武汉或愿意来武汉发展。'),

-- 女 19: 吴欣怡 (23, 西安, 前端开发)
(19,
 '在西安一家互联网公司做前端，日常写React和TypeScript。性格活泼开朗，喜欢二次元和cosplay，周末经常去漫展。也会玩滑板，虽然技术一般但很快乐。',
 23, 'FEMALE', '西安',
 '{"occupation":"前端开发工程师","education":"本科","interests":["二次元","cosplay","滑板","游戏","看番"]}',
 'SIMILAR',
 '希望对方也喜欢二次元文化，能一起逛漫展、追番。性格有趣不无聊。年龄24-30之间，最好也在西安。颜值阳光干净。'),

-- 女 20: 郑媛 (35, 重庆, 合伙律师)
(20,
 '重庆一家律所的合伙人，主攻商事诉讼。事业型女性但不想被标签化——我也爱做饭、爱逛街、爱追剧。性格大气豁达，见过世面所以对很多事都很包容。',
 35, 'FEMALE', '重庆',
 '{"occupation":"律所合伙人","education":"硕士","interests":["做饭","逛街","追剧","健身","自驾游"]}',
 'BALANCED',
 '希望对方成熟稳重，有事业心和格局。年龄32-42之间，经济独立。思想上能同频沟通，不介意对方比我强或比我弱，重要的是互相尊重。');
