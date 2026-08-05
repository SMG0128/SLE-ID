# StarFollow 本地后端服务

> 电脑本地后端：API + WebSocket 事件推送 + USB 串口读写（WS63-B）+ SQLite 数据库

## 目录结构

```
server/
├── src/
│   ├── index.js              # 入口：REST + WebSocket
│   ├── db.js                 # SQLite 初始化 + 建表（待开发）
│   ├── routes/               # API 路由（与前端 api/*.ts 一一对应）
│   │   ├── events.js         # 事件日志/实时事件
│   │   ├── alarms.js         # 报警
│   │   ├── devices.js        # 检测端 + 串口状态
│   │   ├── licenses.js       # 许可发布
│   │   ├── invites.js        # 邀请码
│   │   ├── cards.js          # 卡片/许可管理
│   │   ├── system.js         # 系统设置
│   │   └── auth.js           # 登录认证
│   ├── services/             # 核心业务逻辑
│   │   ├── policy.js         # 10 项组合策略计算（文档 4.3）
│   │   ├── invite.js         # 邀请码一次性机制（文档 4.7）
│   │   └── alarm.js          # 报警规则判定（文档 4.5）
│   ├── ws63/                 # USB 串口适配层（W3）
│   │   └── driver.js         # 帧解析/心跳/自动重连/命令应答
│   └── ws/                   # WebSocket 事件推送（W4）
│       └── index.js
└── data/
    └── starfollow.db         # SQLite 数据库文件（运行时生成）
```

## 技术栈

- Node.js + Express（REST API）
- better-sqlite3（本地数据库）
- ws（WebSocket 事件推送）
- serialport（USB 串口，W3 阶段）

## 端口约定

- 后端监听 `8080`
- 前端开发服务器代理 `/api` → `http://localhost:8080`（已在 vite.config.ts 配置）

## 状态

- [ ] W0 数据建模（表结构）
- [ ] W2 本地后端与数据库
- [ ] W3 单 USB 通信（WS63-B）
- [ ] W4 实时事件（WebSocket）
- [ ] W5 权限同步
