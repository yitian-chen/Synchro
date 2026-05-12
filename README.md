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

- **个人资料设置**: 首次登录收集年龄、性别、地区、简介等基本信息
- **AI性格访谈**: 用户与AI聊天机器人对话，AI分析并提取用户的性格、爱好、交友偏好（限定8轮对话）
- **匹配参与开关**: 用户可自主选择是否参与每周匹配
- **智能匹配**: 每周五自动运行匹配算法，基于兼容度为每位用户匹配一位对象
- **实时通讯**: 与匹配对象进行实时聊天
- **个人主页**: 展示用户资料、头像和AI提取的兴趣标签

## 技术栈

### 后端
- **框架**: Spring Boot 3.5 + Java 17
- **数据库**: MySQL 8 + Redis 7
- **实时通讯**: WebSocket (STOMP协议), SockJS
- **AI集成**: LangChain4j (DeepSeek Chat + OpenAI Embedding 双模型)
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
├── docker-compose.yml         # MySQL + Redis + MinIO
└── README.md
```

## 快速开始

### 前置要求

- JDK 17+
- Maven 3.9+ (项目内置 Maven Wrapper)
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

首次启动后，创建 MinIO 的 bucket（只需执行一次）：

```bash
# 安装 mc 客户端
docker exec -it synchro-minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker exec -it synchro-minio mc mb local/synchro-avatars
```

> 或打开 http://localhost:9001（账号密码: minioadmin/minioadmin），手动创建 `synchro-avatars` bucket。

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
| users | 用户账户（含 matchingOptIn 开关） |
| profiles | 用户资料、traits_summary、理想伴侣描述、匹配偏好 |
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

### 特质提取（AI驱动的22个特征）

用户完成8轮AI访谈后，TraitExtractionService调用AI从对话中提取：

**人格特质（14个）**: extroversion, openness, agreeableness, adventurousness, socialness, activity_level, romantic, family_oriented, career_oriented, creative, intellectual, emotional_expressiveness, conflict_avoidant, independence

**择偶偏好（8个）**: partner_extroversion_pref, partner_adventurous_pref, partner_social_pref, importance_appearance, importance_values, importance_intelligence, openness_to_distance, long_term_goal

### 匹配数据流

```
1. 用户完成AI访谈 → TraitExtractionService提取22个特质值
   → 存入 user_trait 表
   → 同时写入 profile.traitsSummary (JSON)
2. 用户bio + 理想伴侣描述 → LangChain4j生成1536维embedding
   → 存入Redis: user:vectors:{userId}
3. 周五定时任务筛选eligible用户（ACTIVE + matchingOptIn=true）
4. 逐对计算兼容分（特质相似度 + 语义相似度 + 偏好匹配 + 互补性 + 意向匹配）
5. 根据用户MatchingPreference个性化调整权重
6. 贪心算法（按平均兼容分排序后配对）
7. 创建Match记录
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
| Primary | #FF6B6B (珊瑚红) |
| Secondary | #4ECDC4 (青绿色) |
| Accent | #FFE66D (明黄色) |
| 渐变 | Linear(#FF6B6B → #4ECDC4) |

字体：Poppins（标题）+ Inter（正文）

## License

MIT License
