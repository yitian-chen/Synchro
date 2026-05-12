# Synchro - AI智能匹配交友平台

<div align="center">
  <img src="https://img.shields.io/badge/Java-17-blue.svg" alt="Java 17">
  <img src="https://img.shields.io/badge/Spring%20Boot-3.x-green.svg" alt="Spring Boot 3">
  <img src="https://img.shields.io/badge/React-18-blue.svg" alt="React 18">
  <img src="https://img.shields.io/badge/TypeScript-5-black.svg" alt="TypeScript">
  <img src="https://img.shields.io/badge/Vite-5-purple.svg" alt="Vite">
  <img src="https://img.shields.io/badge/Tailwind%20CSS-3-cyan.svg" alt="Tailwind CSS">
</div>

## 项目简介

Synchro 是一款AI驱动的智能匹配交友平台。用户通过与AI对话完成性格测试，平台基于AI提取的用户特质进行智能匹配，每周为用户配对一位有高兼容性的对象。

### 核心特性

- **个人资料设置**: 首次登录收集年龄、性别、地区、简介等基本信息
- **AI性格访谈**: 用户与AI聊天机器人对话，AI分析并提取用户的性格、爱好、交友偏好（限定8轮对话）
- **匹配参与开关**: 用户可自主选择是否参与每周匹配
- **智能匹配**: 每周五自动运行匹配算法，基于兼容度为每位用户匹配一位对象
- **实时通讯**: 与匹配对象进行实时聊天
- **个人主页**: 展示用户资料、头像和AI提取的兴趣标签

## 技术栈

### 后端
- **框架**: Spring Boot 3.5 + Java 17
- **数据库**: MySQL 8 + Redis
- **实时通讯**: WebSocket (STOMP协议)
- **AI集成**: LangChain4j (支持多模型接入)
- **向量搜索**: Redis Vector Search (用户自我介绍语义匹配)
- **安全**: Spring Security + JWT
- **迁移**: Flyway

### 前端
- **框架**: React 18 + TypeScript
- **构建**: Vite 5
- **样式**: Tailwind CSS
- **路由**: React Router v6
- **状态管理**: React Context + Hooks
- **HTTP**: Axios
- **WebSocket**: STOMP.js

## 项目结构

```
Synchro/
├── backend/                    # Spring Boot 后端
│   ├── src/main/java/io/github/yitianchen/synchro/
│   │   ├── config/           # 配置类
│   │   ├── controller/       # REST API控制器
│   │   ├── service/          # 业务逻辑
│   │   ├── repository/       # 数据访问层
│   │   ├── model/            # 实体类
│   │   ├── dto/              # 数据传输对象
│   │   ├── security/         # JWT安全
│   │   ├── websocket/        # WebSocket处理
│   │   ├── scheduler/         # 定时任务
│   │   └── exception/        # 异常处理
│   └── src/main/resources/
│       ├── application.yml
│       └── db/migration/     # Flyway迁移脚本
│
├── frontend/                   # React 前端
│   ├── src/
│   │   ├── api/              # API客户端
│   │   ├── components/       # UI组件
│   │   ├── pages/            # 页面
│   │   ├── hooks/            # 自定义Hooks
│   │   ├── context/          # React Context
│   │   ├── types/            # TypeScript类型
│   │   └── utils/            # 工具函数
│   └── ...
│
├── docker-compose.yml         # MySQL + Redis
└── README.md
```

## 快速开始

### 前置要求

- JDK 17+
- Maven 3.9+
- Node.js 18+
- Docker Desktop

### 1. 启动基础设施（MySQL + Redis）

```bash
docker-compose up -d
```

### 2. 启动后端

```bash
cd backend
./mvnw spring-boot:run
```

后端地址: http://localhost:8080

### 3. 启动前端

```bash
cd frontend
npm install
npm run dev
```

前端地址: http://localhost:5173

## 功能流程

### 1. 用户注册/登录
- 用户注册账号，设置昵称和密码
- 登录后若未完成资料设置，跳转到`/profile-setup`

### 2. 个人资料设置
- 收集用户基本信息：昵称、年龄、性别、地区、个人简介
- 完成后方可进入AI性格访谈

### 3. AI性格访谈
- 用户与AI聊天机器人对话（限定8轮）
- AI覆盖6大话题维度：兴趣爱好、性格情感、社交交友、择偶偏好、价值观、情感需求
- AI从对话中提取22个特征值（14个人格特质 + 8个择偶偏好）
- 提取结果存入user_trait表，同时写入profile.traitsSummary（JSON）供Dashboard展示
- 访谈完成后用户状态变为`ACTIVE`

### 4. 匹配参与控制
- Dashboard提供开关按钮，控制是否参与每周匹配
- 默认开启，关闭后将不会被纳入当周匹配池

### 5. 每周匹配
- 每周五18:00 UTC运行匹配算法
- 仅匹配状态为ACTIVE且matchingOptIn=true的用户
- 每位用户匹配一位兼容度最高的对象
- 匹配结果创建对话，用户可开始聊天

### 4. 实时聊天
- 与匹配对象进行实时消息传递
- WebSocket维持长连接
- 消息持久化存储

## 数据库设计

### 核心表结构

| 表名 | 说明 |
|------|------|
| users | 用户账户信息 |
| profiles | 用户资料和AI提取的特质摘要 |
| user_traits | 用户特质详情（兴趣、性格等） |
| conversations | 对话（AI访谈对话/Match对话） |
| messages | 消息记录 |
| matches | 匹配记录 |

## API接口

### 认证接口
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/auth/register | 用户注册 |
| POST | /api/auth/login | 用户登录 |
| POST | /api/auth/logout | 登出 |
| POST | /api/auth/refresh | 刷新Token |

### 用户接口
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/users/me | 获取当前用户信息 |
| PUT | /api/users/me | 更新个人资料 |
| PUT | /api/users/me/avatar | 上传头像 |
| PUT | /api/users/me/matching-opt-in | 设置匹配参与开关 |

### AI访谈接口
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | /api/onboarding/start | 开始访谈 |
| POST | /api/onboarding/message | 发送消息 |
| GET | /api/onboarding/messages | 获取访谈消息 |

### 匹配接口
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/matches/current | 获取本周匹配 |
| GET | /api/matches/history | 获取匹配历史 |

### 聊天接口
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | /api/conversations | 获取对话列表 |
| GET | /api/conversations/{id}/messages | 获取消息历史 |
| WS | /ws/chat | WebSocket聊天端点 |

## 匹配算法

```
兼容度得分 = 0.3 × 特质相似度 + 0.25 × 语义相似度 + 0.25 × 偏好匹配度 + 0.2 × 互补性得分
```

- **特质相似度**: 基于Cosine Similarity计算用户22个特质向量的相似程度
- **语义相似度**: 基于Redis存储的用户自我介绍1536维embedding做余弦相似度
- **偏好匹配度**: 年龄差、地理位置的匹配程度
- **互补性**: 性格互补（如外向+内向）可获得额外加分，基于特质配对映射

### 特质提取（AI驱动的22个特征）

用户完成8轮AI访谈后，TraitExtractionService调用AI从对话中提取：

**人格特质（14个）**: extroversion, openness, agreeableness, adventurousness, socialness, activity_level, romantic, family_oriented, career_oriented, creative, intellectual, emotional_expressiveness, conflict_avoidant, independence

**择偶偏好（8个）**: partner_extroversion_pref, partner_adventurous_pref, partner_social_pref, importance_appearance, importance_values, importance_intelligence, openness_to_distance, long_term_goal

### 匹配数据流

```
1. 用户完成AI访谈 → TraitExtractionService提取22个特质值
   → 存入 user_trait 表
   → 同时写入 profile.traitsSummary (JSON)
2. 用户自我介绍(bio)通过LangChain4j生成1536维embedding
   → 存入Redis: user:vectors:{userId} (逗号分隔float字符串)
3. 周五定时任务筛选eligible用户（ACTIVE + matchingOptIn=true）
4. 逐对计算四维加权兼容分
5. 贪心算法（按平均兼容分排序后配对）
6. 创建Match记录
```

### Redis向量存储格式

```
user:vectors:{user_id} = {
  "bio_embedding": "0.12,-0.34,0.78,...",  # 1536维embedding（逗号分隔）
  "bio_summary": "喜欢户外运动、阅读哲学...",
  "updated_at": "2026-05-06T10:00:00Z"
}
```

## UI设计

采用活力多彩的设计风格：

| 用途 | 色值 |
|------|------|
| Primary | #FF6B6B (珊瑚红) |
| Secondary | #4ECDC4 (青绿色) |
| Accent | #FFE66D (明黄色) |
| 渐变 | Linear(#FF6B6B → #4ECDC4) |

字体：Poppins（标题）+ Inter（正文）

## License

MIT License
