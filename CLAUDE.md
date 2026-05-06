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
