# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Synchro 是一款AI驱动的智能匹配交友平台，核心流程：用户与AI对话完成性格访谈 → 每周五自动匹配 → 实时聊天。

## 开发命令

### 后端 (Spring Boot)
```bash
cd backend
./mvnw spring-boot:run          # 启动
./mvnw test                     # 运行测试
./mvnw flyway:migrate            # 数据库迁移
```

### 前端 (React)
```bash
cd frontend
npm install                     # 安装依赖
npm run dev                      # 开发服务器 (http://localhost:5173)
npm run build                   # 生产构建
```

### 基础设施
```bash
docker-compose up -d            # 启动 MySQL + Redis
```

## 技术架构

### 后端包结构
```
io.github.yitianchen.synchro/
├── config/       # SecurityConfig, RedisConfig, WebSocketConfig, OpenAIConfig
├── controller/   # REST API (Auth, User, Onboarding, Match, Chat)
├── service/      # 业务逻辑
├── repository/   # Spring Data JPA
├── model/        # JPA实体
├── dto/          # 请求/响应DTO
├── security/     # JWT认证 (JwtTokenProvider, JwtAuthenticationFilter)
├── websocket/    # STOMP WebSocket处理
├── scheduler/    # 定时任务 (MatchingScheduler每周五18:00 UTC)
└── exception/    # 全局异常处理
```

### 核心数据模型
- **User** → **Profile** → **UserTrait** (特质标签)
- **Conversation** (类型: ONBOARDING/MATCH) → **Message**
- **Match** (每周匹配关系)

### 匹配算法
```
得分 = 0.3×特质相似度 + 0.25×语义相似度 + 0.25×偏好匹配度 + 0.2×互补性
```
- 语义相似度基于Redis Vector Search (用户自我介绍embedding)
- AI集成使用LangChain4j

### 用户状态流转
```
PENDING_ONBOARDING → (完成AI访谈) → ACTIVE → (周五匹配) → 可聊天
```

## API约定

- REST API base: `/api`
- WebSocket: `/ws/chat`
- 认证: JWT Bearer Token (Access 15min, Refresh 7 days)
- 响应格式: `{ data, message, code }`

## 数据库

- MySQL: 用户、匹配、消息等结构化数据
- Redis: 会话、向量索引、实时消息缓存、WebSocket pub/sub

## UI风格

- 活力多彩: Primary #FF6B6B, Secondary #4ECDC4, Accent #FFE66D
- 字体: Poppins (标题) + Inter (正文)

## 代码守则
- **异常处理**: 禁止吞掉异常。所有外部 API 调用（特别是 AI/Redis/MySQL）必须有超时处理、重试机制 (Resilience4j) 和优雅的错误提示。
- **架构模式**：采用 Controller -> Service 的结构，禁止在 Controller 中编写业务逻辑。

## AI Agent 开发约束
- **流式响应**: 所有涉及 AI 生成内容的 API，必须实现 SSE (Server-Sent Events) 支持，禁止一次性等待全文返回。
- **Prompt 可观测性**: 在 `infrastructure` 层调用 LLM 时，必须打印输入 Prompt 和输出结果（脱敏后），以便排查 AI 决策逻辑。
- **向量检索优化**: 匹配算法中的 `特质相似度` 和 `语义相似度` 必须能够动态调整权重（存放在配置文件中），禁止写死。
- **Token 节省**: 在进行 Embedding 转换或长文本分析时，务必先进行清理（去除停用词、精简 Prompt），减少 Token 消耗。

## 协作约定
- 在进行大规模的 API 重构或数据库 Schema 修改前，必须先询问我。
- 在编写涉及匹配算法逻辑的 Service 时，请优先编写对应的 JUnit 测试用例，确保算法逻辑可验证。
- 依赖库选型需考虑 Apple Silicon (ARM64) 兼容性，避免使用陈旧的、依赖 x86 本地库的 Java 组件。
- 不要生成冗长的注释，除非逻辑非常复杂。
- 在修改任何现有 API 接口前，请先询问我。