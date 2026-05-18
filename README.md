# Synchro - AI智能匹配交友平台

<div align="center">
  <img src="https://img.shields.io/badge/Java-17-blue.svg" alt="Java 17">
  <img src="https://img.shields.io/badge/Spring%20Boot-3.5-green.svg" alt="Spring Boot 3.5">
  <img src="https://img.shields.io/badge/React-18-blue.svg" alt="React 18">
  <img src="https://img.shields.io/badge/TypeScript-5-black.svg" alt="TypeScript">
  <img src="https://img.shields.io/badge/Vite-5-purple.svg" alt="Vite">
  <img src="https://img.shields.io/badge/Tailwind%20CSS-3-cyan.svg" alt="Tailwind CSS">
  <img src="https://img.shields.io/badge/MinIO-Object%20Storage-blue.svg" alt="MinIO">
  <img src="https://img.shields.io/badge/MySQL-8-orange.svg" alt="MySQL 8">
  <img src="https://img.shields.io/badge/Redis-7-red.svg" alt="Redis 7">
  <img src="https://img.shields.io/badge/LangChain4j-AI-purple.svg" alt="LangChain4j">
  <img src="https://img.shields.io/badge/Flyway-DB%20Migration-yellow.svg" alt="Flyway">
</div>

## 项目简介

Synchro 是一款AI驱动的智能匹配交友平台。用户通过与AI对话完成性格测试，平台基于AI提取的用户特质进行智能匹配，每周为用户配对一位有高兼容性的对象。

### 核心特性

- **个人资料设置**: 首次登录收集年龄、性别、所在城市、个人简介与期望交友对象等基本信息
- **AI性格访谈**: 用户与AI聊天机器人对话（限定8轮）。AI通过 prompt-based tool calling 实时提取用户性格特质、自动填充个人资料、跳过已覆盖话题
- **匹配参与开关**: 用户可自主选择是否参与每周匹配
- **智能匹配**: 每周五自动运行匹配算法，基于兼容度评分为每位用户匹配一位对象
- **实时通讯**: 与匹配对象进行实时聊天
- **个人主页**: 展示用户资料、头像和AI提取的兴趣标签

## 技术栈

### 后端
- **框架**: Spring Boot 3.5 + Java 17
- **数据库**: MySQL 8 + Redis 7
- **实时通讯**: WebSocket (STOMP协议), SockJS
- **AI集成**: LangChain4j (DeepSeek Chat + Prompt-based Tool Calling + Embedding 双模型)
- **向量检索**: Redis Hash 存储 1536 维 embedding，余弦相似度计算
- **安全**: Spring Security + JWT (Access 8h + Refresh 7d)
- **对象存储**: MinIO (用户头像)
- **容错**: Resilience4j (重试 + 熔断)
- **迁移**: Flyway (数据库版本管理)
- **构建**: Maven Wrapper

### 前端
- **框架**: React 18 + TypeScript 5
- **构建**: Vite 5
- **样式**: Tailwind CSS 3
- **路由**: React Router v6
- **状态管理**: React Context + Hooks
- **HTTP**: Axios
- **WebSocket**: STOMP.js + SockJS
- **Markdown渲染**: react-markdown

## 项目结构

```
Synchro/
├── backend/                  # Spring Boot 后端
│   ├── src/main/java/io/github/yitianchen/synchro/
│   │   ├── config/           # 配置类
│   │   ├── controller/       # REST API控制器
│   │   ├── service/          # 业务逻辑（含 OnboardingTools 工具调度）
│   │   ├── repository/       # 数据访问层
│   │   ├── model/            # 实体类
│   │   ├── dto/              # 数据传输对象
│   │   ├── security/         # JWT安全
│   │   ├── websocket/        # WebSocket处理
│   │   ├── scheduler/        # 定时任务
│   │   └── exception/        # 异常处理
│   └── src/main/resources/
│       ├── application.yml
│       └── db/migration/     # Flyway迁移脚本
│
├── frontend/                 # React 前端
│   ├── src/
│   │   ├── api/              # API客户端
│   │   ├── components/       # UI组件
│   │   ├── pages/            # 页面（含 PostOnboardingPage 访谈后资料完善）
│   │   ├── hooks/            # 自定义Hooks
│   │   ├── context/          # React Context
│   │   ├── types/            # TypeScript类型
│   │   └── utils/            # 工具函数
│   └── ...
│
├── docker-compose.yml        # MySQL + Redis + MinIO
└── README.md
```

## 快速开始

### 前置要求

- JDK 17+
- Maven 3.9+ 
- Node.js 18+
- Docker Desktop

---

### 1. 配置环境变量

后端通过环境变量读取 API Key 等敏感信息。复制以下内容到 `~/.zshrc` 或 `.env` 文件：

```bash
# === AI 聊天（DeepSeek）===
export OPENAI_API_KEY=sk-your-deepseek-api-key
export OPENAI_API_MODEL=deepseek-v4-flash          # 可选，默认值
export OPENAI_BASE_URL=https://api.deepseek.com/v1  # 可选，默认值

# === AI 向量嵌入（阿里通义千问 Embedding）===
export EMBEDDING_API_KEY=sk-your-dashscope-api-key
export EMBEDDING_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
export EMBEDDING_MODEL=text-embedding-v4             # 可选，默认值

# === JWT 密钥（生产环境必改）===
export JWT_SECRET=your-256-bit-secret-key-here-change-in-production
```

> **获取 API Key:**
> - DeepSeek: https://platform.deepseek.com/api_keys
> - 阿里云 DashScope (通义千问): https://dashscope.aliyun.com/  → API Keys 管理

---

### 2. 启动基础设施（MySQL + Redis + MinIO）

```bash
docker-compose up -d
```

包含三个服务：
| 服务 | 端口 | 用途 |
|------|------|------|
| MySQL 8 | 3307 | 业务数据 |
| Redis Stack 7 | 6379 | 缓存、向量存储、会话 |
| MinIO | 9000 / 9001 | 用户头像存储 |

> MinIO bucket 会在后端首次启动时自动创建并设置为公开读，无需手动操作。

---

### 3. 初始化数据库

```bash
# 方式一：使用整合脚本（推荐，包含建表 + 测试数据）
docker compose exec -T mysql mysql -usynchro -psynchro_password synchro < db/init.sql

# 方式二：使用 Flyway（仅建表，不包含测试数据）
cd backend && ./mvnw flyway:migrate
```

> `db/init.sql` 包含完整的表结构、34 省市区数据、以及 20 个测试用户（密码: `password123`）。
> 如果不使用测试数据，直接启动后端后 Flyway 会自动执行 `db/migration/` 下的迁移脚本。

---

### 4. 启动后端

```bash
cd backend
./mvnw spring-boot:run
```

后端地址: http://localhost:8080

验证启动成功：访问 http://localhost:8080/api/auth/login 应返回 401（说明 Spring Security 正常工作）。

---

### 5. 启动前端

```bash
cd frontend
npm install
npm run dev
```

前端地址: http://localhost:5173

---

### 6. 测试登录

使用预置测试用户登录：

| 邮箱 | 密码 | 角色 |
|------|------|------|
| test1@synchro.com | password123 | 男，28岁，北京，后端开发 |
| test2@synchro.com | password123 | 男，30岁，上海，金融产品经理 |
| test11@synchro.com | password123 | 女，26岁，北京，市场经理 |
| test12@synchro.com | password123 | 女，28岁，上海，时尚设计师 |

所有测试用户均为 ACTIVE 状态，已开通匹配，可直接触发匹配算法：`POST /api/matches/trigger`

---

### 环境变量一览

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `OPENAI_API_KEY` | — | **必填** DeepSeek 聊天 API Key |
| `OPENAI_API_MODEL` | `deepseek-v4-flash` | DeepSeek 模型名 |
| `OPENAI_BASE_URL` | `https://api.deepseek.com/v1` | DeepSeek API 地址 |
| `EMBEDDING_API_KEY` | 同 OPENAI_API_KEY | 向量模型 API Key（阿里 DashScope） |
| `EMBEDDING_BASE_URL` | `https://api.openai.com/v1` | 向量模型 API 地址（DashScope 用 `https://dashscope.aliyuncs.com/compatible-mode/v1`） |
| `EMBEDDING_MODEL` | `text-embedding-v4` | 向量模型名（阿里 Qwen） |
| `JWT_SECRET` | `your-256-bit-secret-key-here-change-in-production` | JWT 签名密钥（生产环境必须修改） |

## 功能流程

### 1. 用户注册/登录
- 用户注册账号，设置昵称和密码
- 登录后跳转到`/profile-setup`填写基础信息

### 2. 基础资料设置（访谈前）
- 收集必填信息：年龄、性别、所在地（省市选择器）
- 这三项信息在后续 AI 访谈中为锁定状态，AI 不可修改
- 完成后直接进入 AI 性格访谈

### 3. AI性格访谈（核心流程）
- 用户与AI聊天机器人对话（限定8轮）
- AI覆盖6大话题维度：兴趣爱好、性格情感、社交交友、择偶偏好、价值观、情感需求
- **Prompt-based Tool Calling**: AI通过输出 `<|tool_call|>` 代码块实时调用后端工具：
  - `savePersonalityTrait` / `savePartnerPreference` — 实时保存特质（confidence < 0.5 自动过滤）
  - `setProfileBio` / `setIdealPartnerDescription` — 自动生成个人简介和理想伴侣描述
  - `markTopicCovered` — 标记话题已覆盖（Redis 记录，动态提示词反映已覆盖状态）
- 第8轮后自动结束，底部输入框变为"完成访谈"按钮
- 访谈完成后用户状态变为`ACTIVE`

### 4. 资料完善（访谈后）
- 跳转到`/post-onboarding`页面
- 显示 AI 生成的自我介绍和理想伴侣描述（可编辑）
- 选择匹配偏好：更相似 / 更互补 / 平衡
- 提交后进入主页

### 5. 匹配参与控制
- Dashboard提供开关按钮，控制是否参与每周匹配
- 默认开启，关闭后将不会被纳入当周匹配池

### 6. 每周匹配
- 每周五18:00 UTC运行匹配算法
- 仅匹配状态为ACTIVE且matchingOptIn=true的用户
- 每位用户匹配一位兼容度最高的对象
- 匹配结果创建对话，用户可开始聊天

### 7. 实时聊天
- 与匹配对象进行实时消息传递
- WebSocket维持长连接
- 消息持久化存储

## 数据库设计

### 核心表结构

| 表名 | 说明 |
|------|------|
| users | 用户账户（含 matchingOptIn 开关） |
| profiles | 用户资料、traits_summary、理想伴侣描述、匹配偏好、post_onboarding_completed |
| user_traits | 22个AI提取特征值（14人格 + 8择偶偏好） |
| conversations | 对话（ONBOARDING / MATCH） |
| messages | 消息记录（含 is_read 已读标记） |
| matches | 周匹配记录 |
| provinces / cities | 中国省市行政区域数据 |
| refresh_tokens | JWT刷新令牌 |

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
| POST | /api/onboarding/message | 发送消息（含 tool_call 解析与执行） |
| GET | /api/onboarding/messages | 获取访谈消息 |
| POST | /api/onboarding/complete | 手动完成访谈 |
| POST | /api/onboarding/reset | 重置访谈 |

> 访谈完成后 `redirectUrl` 返回 `/post-onboarding`，前端跳转到访谈后资料完善页面。

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
基础分 = 0.3 × 特质相似度 + 0.25 × 语义相似度 + 0.25 × 偏好匹配度 + 0.2 × 互补性
个性化基础 = (用户A加权分 + 用户B加权分) / 2
最终分 = 个性化基础 × 0.8 + 双向意向匹配度 × 0.2
```

- **特质相似度**: 基于Cosine Similarity计算用户22个特质向量的相似程度
- **语义相似度**: 基于Redis存储的用户自我介绍1536维embedding做余弦相似度
- **偏好匹配度**: 年龄差、地理位置的匹配程度
- **互补性**: 性格互补（如外向+内向）可获得额外加分，基于特质配对映射
- **个性化权重**: 用户可选 SIMILAR / COMPLEMENTARY / BALANCED，动态调整特质相似度和互补性的权重
- **双向意向匹配**: A的理想伴侣描述embedding vs B的自我介绍embedding + 反向，双向取平均

### 特质提取

特质通过两种方式收集，后端硬门槛过滤 confidence < 0.5 的数据：

**实时提取（Tool Calling）**: 访谈中 AI 发现用户特质后，通过 `savePersonalityTrait` / `savePartnerPreference` 工具实时保存到 `user_traits` 表。已保存的特质会在下一轮动态提示词中显示，防止重复提取。

**批量兜底（TraitExtractionService）**: 访谈结束时，若已保存的特质少于 15 个（共 22 个），触发全量 AI 提取补充遗漏。若已保存 ≥15 个，则仅更新 `profile.traitsSummary`。

**人格特质（14个）**: extroversion, openness, agreeableness, adventurousness, socialness, activity_level, romantic, family_oriented, career_oriented, creative, intellectual, emotional_expressiveness, conflict_avoidant, independence

**择偶偏好（8个）**: partner_extroversion_pref, partner_adventurous_pref, partner_social_pref, importance_appearance, importance_values, importance_intelligence, openness_to_distance, long_term_goal

### 匹配数据流

```
1. AI访谈中 Tool Calling 实时提取特质 → 存入 user_trait 表
2. 访谈结束时 TraitExtractionService 兜底提取（若 < 15 个特质）
   → 写入 profile.traitsSummary (JSON)
3. 用户 bio + 理想伴侣描述 → LangChain4j 生成 1536 维 embedding
   → 存入 Redis: user:vectors:{userId}
4. 周五定时任务筛选 eligible 用户（ACTIVE + matchingOptIn=true）
5. 逐对计算兼容分（特质相似度 + 语义相似度 + 偏好匹配 + 互补性 + 意向匹配）
6. 根据用户 MatchingPreference 个性化调整权重
7. 贪心算法（按平均兼容分排序后配对）
8. 创建 Match 记录
```

### Redis向量存储格式

```
user:vectors:{user_id} = {
  "bio_embedding": "0.12,-0.34,0.78,...",           # 1536维embedding（逗号分隔）
  "bio_summary": "喜欢户外运动、阅读哲学...",
  "ideal_partner_embedding": "0.23,-0.45,...",       # 理想伴侣描述embedding
  "ideal_partner_summary": "希望对方阳光开朗...",
  "updated_at": "2026-05-06T10:00:00Z"
}
```

### Embedding模型配置

聊天和向量使用独立模型配置（见 application.yml）：
- **聊天**: `ai.openai.*` — DeepSeek Chat (deepseek-v4-flash)
- **向量**: `ai.embedding.*` — 阿里通义千问 Embedding (text-embedding-v4)，可独立设置 API Key 和 Base URL

## UI设计

采用活力多彩的设计风格：

| 用途 | 色值 |
|------|------|
| Primary | #5BC0BE (青绿色) |
| Secondary | #96D2CF (浅青绿) |
| Accent | #D1EDEA (淡青) |
| 渐变 | Linear(#5BC0BE → #7AC8C5) |

字体：Poppins（标题）+ Inter（正文）

## License

MIT License
