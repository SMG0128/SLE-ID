# MilkWa-Admin · 奶蛙管理端

> 基于**星闪（NearLink）主动感知系统**的检测管理控制中心 Web 前端原型。  
> HarmonyOS ArkUI 主应用 → Ark Web 容器 → Vue3 管理端 → 本地后端 (SQLite + WS63)

---

## 总体架构

```
                 星随 HarmonyOS 应用
        ┌─────────────────────────────┐
        │       ArkUI 主应用           │
        │  · 用户身份管理               │
        │  · 数字卡片管理               │
        │  · 系统设置                   │
        └─────────────┬───────────────┘
                      │
                Ark Web 容器
                      │
        ┌─────────────▼───────────────┐
        │   Vue3 管理端 Web 应用 ★     │  ← 当前仓库
        │  · Dashboard 数据看板         │
        │  · 实时事件监控               │
        │  · 事件日志查询               │
        │  · 报警中心                   │
        │  · 检测端管理 (WS63)          │
        │  · 许可管理 (策略引擎)         │
        └─────────────┬───────────────┘
                      │
                   API 接口层
                      │
        ┌─────────────▼───────────────┐
        │  本地后端服务                 │
        │  · SQLite 数据库              │
        │  · WS63 通信模块              │
        └─────────────────────────────┘
```

## 技术栈

| 类别 | 技术 | 用途 |
|------|------|------|
| 框架 | Vue 3 + TypeScript | 页面组件开发 |
| 构建 | Vite 5 | 工程构建与 HMR |
| UI | Element Plus 2.7 | 后台管理 UI 组件 |
| 路由 | Vue Router 4 | 页面路由 (Hash 模式) |
| 状态 | Pinia 2 | 全局状态管理 |
| 图表 | ECharts 5 | 数据可视化 |
| HTTP | Axios | 接口请求封装 |
| 模拟 | 内置 Mock 引擎 | 开发阶段本地数据 |

## 项目结构

```
StarFollow-Admin/
├── index.html                     # 入口 HTML
├── package.json                   # 依赖与脚本
├── vite.config.ts                 # Vite 配置
├── tsconfig.json                  # TypeScript 配置
└── src/
    ├── main.ts                    # 应用入口
    ├── App.vue                    # 根组件
    ├── api/                       # 接口封装层（page → api → mock）
    │   ├── request.ts             # Axios 实例 + Mock 延迟辅助
    │   ├── event.ts               # 事件接口（日志 + 实时引擎）
    │   ├── alarm.ts               # 报警接口
    │   ├── device.ts              # 设备接口
    │   ├── permission.ts          # 许可接口
    │   └── websocket.ts           # WebSocket 预留（暂不连接）
    ├── types/                     # TypeScript 类型定义
    │   ├── event.ts               # 事件/实时事件类型 + 状态流转常量
    │   ├── alarm.ts               # 报警类型 + 7 种报警/3 级严重度/处理方案表
    │   ├── device.ts              # WS63 设备类型
    │   └── license.ts             # 许可类型 + 4 项策略定义
    ├── mock/                      # 模拟数据层
    │   ├── event.ts               # 事件日志 Mock + 实时生命周期引擎
    │   ├── alarm.ts               # 报警 Mock（内含筛选逻辑）
    │   ├── device.ts              # 设备 Mock + WS63 状态
    │   └── license.ts             # 许可 Mock（内存 CRUD）
    ├── router/
    │   └── index.ts               # 路由表（AdminLayout + 7 条子路由）
    ├── stores/
    │   └── system.ts              # 系统状态（侧栏折叠 / WS63 连接）
    ├── layouts/
    │   └── AdminLayout.vue        # 管理端框架（侧栏 + 顶栏 + 内容区）
    └── views/                     # 业务页面
        ├── Home.vue               # 首页 Dashboard（ECharts 趋势图 + 饼图）
        ├── EventMonitor.vue       # 实时事件监控（5s 生命周期模拟引擎）
        ├── EventLog.vue           # 事件日志（筛选 + 分页）
        ├── AlarmCenter.vue        # 报警中心（7 种类型 × 3 级 + 确认/处理）
        ├── DeviceManage.vue       # 检测端管理（WS63 信息表）
        ├── PermissionManage.vue   # 许可管理（创建 + 策略开关 + 吊销）
        └── InviteManage.vue       # 邀请码管理
```

## 接口层架构

所有页面**禁止直接访问 Mock**，统一走三层链路：

```
Page.vue  →  api/*.ts  →  mock/*.ts
 (视图)      (异步接口)    (数据生成)
```

- `api/*.ts` 导出 async 函数，内部通过 `mockDelay()` 模拟网络延迟
- 接入真实后端时，仅需将 api 层改为 `request.get/post(...)`，页面零改动
- WebSocket 接口：`connectEventSocket()` / `closeSocket()` / `onEventMessage()` 已预留，后端就绪后取消防注释即用

## 功能模块

| 页面 | 路由 | 核心能力 |
|------|------|----------|
| **首页看板** | `/home` | 星闪检测系统状态 + 数据卡片 + ECharts 趋势图/异常饼图 + 最近事件 |
| **实时事件** | `/realtime-events` | 5 状态生命周期模拟引擎 (IDLE→APPROACHING→IN_ZONE→COMPLETED→COOLDOWN)，每 5 秒自动刷新 |
| **事件日志** | `/event-log` | 81 条历史记录，按时间/检测端/结果筛选分页 |
| **报警中心** | `/alarm-center` | 未知设备/未授权/许可过期/密钥失败/确认失败/执行失败/疑似重放 7 种报警，严重/高/普通 3 级 |
| **检测端管理** | `/device-manage` | WS63 通信模块状态 + 设备表（ID/名称/位置/固件/心跳/USB/策略版本） |
| **许可管理** | `/permission-manage` | 许可 CRUD + 4 项可配置策略（记录事件/允许执行/二次确认/异常报警） ⭐ 项目创新点 |
| **邀请码** | `/invite-code` | 生成/撤销/复制邀请码 |

## 快速开始

```bash
# 安装依赖
npm install

# 开发模式
npm run dev        # 启动 Vite 开发服务器 → http://localhost:3000

# 生产构建
npm run build      # 输出至 dist/
npm run preview    # 预览生产构建 → http://localhost:4173
```

## 分支说明

| 分支 | 内容 |
|------|------|
| **Admin-Backend** ★ | Vue3 管理前端（当前分支） |
| App-UI | HarmonyOS ArkUI 应用端 |
| App-OH | OpenHarmony 适配 |

---

*StarFollow — 基于星闪的主动感知系统 · 广东技术师范大学*
