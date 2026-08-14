# 后端高优先级修复日志（2026-08-13）

## 本轮范围

- 修复后端异常退出后人工确认停留在 `sending` 的恢复问题。
- 为 REST API 与 `/ws/events` 增加可配置共享令牌。
- 禁止未设置令牌时监听非回环地址，避免无鉴权接口误暴露到局域网。
- 补齐邀请码兑换、绑定记录、使用次数扣减和重复绑定保护。
- 保持默认 `127.0.0.1` 本地开发方式兼容。

## 行为说明

- 服务启动时：未过期的 `sending` 确认恢复为 `pending`；已过期的 `pending/sending` 确认更新为 `expired`。
- 设置 `STARFOLLOW_API_TOKEN` 后：REST 接受 Bearer 或 `X-API-Token`；WebSocket 接受相同请求头或 `access_token` 查询参数。
- 令牌模式下审计操作人使用服务端 `STARFOLLOW_ADMIN_OPERATOR`，忽略客户端伪造身份。
- `POST /api/invites/redeem` 在同一 SQLite 事务中写绑定、扣次数并更新状态。

## 验证结果

- `npm run check`：TypeScript 编译通过，13/13 后端测试通过。
- `tests/run_tests.ps1`：A/B Protocol V2、Card 存储/HMAC、防重放、B 权威互操作、A 中继、B 单 USB 网关、写卡 DryRun、安全脚本和映射自测全部通过。
- 本轮未执行实体板串口验证，未修改管理端前端源码和任何固件源码。

## 下一步

1. 将管理端前端从 mock API 切换到真实 REST。
2. 接入 `/ws/events`，实现待确认列表和允许/拒绝操作。
3. 使用 Card 模拟器完成 B→后端→前端→确认→B 的完整闭环联调。
