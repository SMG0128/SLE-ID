# StarFollow 本地后端

这是 SLE-ID 管理端配套的本地后端。它负责 SQLite 持久化、REST API、WebSocket 实时推送，以及通过 USB 串口与 Detector B 通信。

## 当前架构

```text
Vue3 管理端 / Ark Web
        │ REST + WebSocket
        ▼
Node.js 本地后端 ── SQLite
        │ USB 串口，115200 8N1，Protocol V2
        ▼
Detector B ── SLE ── Detector A / WS63 卡片
```

电脑只需要连接 Detector B 的管理串口。不要让 VS Code 串口监视器和本后端同时打开同一个 COM 口，否则 Windows 会报告端口被占用。

## 环境与启动

- Node.js 20 或更高版本
- 已烧录支持 Protocol V2 的 Detector A、Detector B 固件

```powershell
cd server
npm install
npm run dev
```

默认监听 `http://127.0.0.1:8080`，数据库保存到 `server/data/starfollow.db`。生产构建：

```powershell
npm run build
npm start
```

### 访问控制

默认只监听本机回环地址，便于本地 Ark Web / 浏览器开发。如果需要让局域网设备访问，必须同时设置共享访问令牌；后端会拒绝无令牌的非回环监听配置：

```powershell
$env:STARFOLLOW_HOST = '0.0.0.0'
$env:STARFOLLOW_API_TOKEN = '<请替换为足够长的随机值>'
$env:STARFOLLOW_ADMIN_OPERATOR = 'admin'
npm run dev
```

REST 使用 `Authorization: Bearer <token>` 或 `X-API-Token: <token>`。浏览器 WebSocket 使用
`/ws/events?access_token=<token>`。启用令牌后，审计操作人由服务端配置确定，不接受客户端伪造的 `X-Operator`。

## 第一次连接 Detector B

1. 关闭占用 B 板 COM 口的串口监视器。
2. 启动后端。
3. 查看可用串口：`GET http://127.0.0.1:8080/api/system/serial-ports`。
4. 设置 B 板端口，例如：

```powershell
$body = @{ port = 'COM6'; baudRate = 115200; autoReconnect = $true } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri http://127.0.0.1:8080/api/system/serial -ContentType application/json -Body $body
```

设置接口会等待 B 的 Protocol V2 心跳；如果选成 A 板、固件版本不对或端口被占用，配置不会保存。连接状态可从以下接口确认：

```powershell
Invoke-RestMethod http://127.0.0.1:8080/api/devices/serial-status
```

`connected=true` 只表示 COM 口已打开；`detectorBReady=true` 才表示已收到 B 的合法心跳，可以进行策略下发和确认。

## 主要接口

| 方法 | 地址 | 用途 |
|---|---|---|
| GET | `/api/health` | 服务与串口健康状态 |
| GET | `/api/capabilities` | 查询硬件已支持和未支持的能力 |
| GET | `/api/events` | 事件分页查询 |
| GET | `/api/alarms` | 报警分页查询与统计 |
| POST | `/api/alarms/:id/handle` | 处理报警 |
| GET | `/api/devices` | 设备列表 |
| PATCH | `/api/devices/:id` | 登记设备并修改名称、位置 |
| GET | `/api/devices/serial-status` | 串口与 B 网关状态 |
| GET | `/api/licenses` | 许可证列表 |
| POST | `/api/licenses` | 新建许可证 |
| POST | `/api/licenses/:id/deploy` | 向 B 下发当前硬件可表达的策略 |
| GET | `/api/confirmations/pending` | 待人工确认列表 |
| POST | `/api/confirmations/:id/decision` | 向 B 返回允许或拒绝 |
| GET | `/api/system/settings` | 系统设置 |
| GET | `/api/audit-logs` | 管理写操作审计记录 |
| POST | `/api/system/backup` | 生成 SQLite 一致性备份 |
| GET | `/api/system/serial-ports` | 枚举 COM 口 |
| PATCH | `/api/system/serial` | 选择并验证 B 板 COM 口 |
| POST | `/api/invites/redeem` | 原子兑换邀请码并绑定对象、扣减可用次数 |

统一响应格式为：

```json
{ "code": 0, "message": "ok", "data": {} }
```

WebSocket 地址是 `/ws/events`，消息格式为：

```json
{
  "version": 1,
  "seq": 1,
  "topic": "event.created",
  "sentAt": "2026-08-09T00:00:00.000Z",
  "data": {}
}
```

## 通信可靠性约束

- Protocol V2 使用帧头、长度和 CRC16-CCITT，解析器能跳过同一串口里的普通文本日志。
- 原始硬件帧以 `(sourceId, bootId, messageId)` 去重；B 重启后 `bootId` 改变，因此新的同号报文不会被误丢弃。
- 事件和原始帧在同一 SQLite 事务中持久化成功后才向 B 返回 ACK。
- 策略下发和确认结果使用相同请求号、相同载荷重试；命令历史使用数据库自增主键，兼容 B 重启后请求号重新计数。
- 命令发送期间 USB 瞬断时不会立即伪造失败；后端保留原请求并在剩余次数内等待串口重连，最终失败才更新同步状态。
- 策略版本由后端全局单调递增，符合 B 当前仅保存一份活动策略的实现。
- 心跳超过 3.5 秒未到达时，`detectorBReady` 自动变为 `false`。
- Host `sourceId` 首次运行随机生成并保存到 SQLite，后端重启后保持不变；`bootId` 每次进程启动更新。
- 已保存的 COM 口在启动时暂时不存在，也会按退避间隔自动重连。
- 后端启动时会把未过期但中断在 `sending` 的确认恢复为待处理，并把已超时记录标为过期。
- 邀请码兑换在 SQLite 事务中写入绑定记录并扣减次数，同一对象不能重复消费同一邀请码。
- 串口状态保留最后错误、错误时间和当前重连次数，便于区分端口占用、拔线和 B 心跳丢失。
- 设备可由管理端登记并维护名称、位置；策略、确认、串口设置等管理写操作写入审计日志。
- 数据库备份使用 SQLite 在线备份接口，保存到 `data/backups/`，不会直接复制仍在写入的 WAL 文件。服务每天自动生成一次并保留最近 7 份，也可通过 REST 手动备份。

## 当前能力边界

- 当前硬件协议没有“远程重启”消息，相关 API 明确返回 `501 / code=3002`，不会伪造成功。
- B 当前只保存一份活动策略；许可证中硬件无法表达的高级字段会保存在数据库，并返回 capability 状态，但不会假装已经下发。
- 卡片冻结、挂失等管理动作目前保存为 `pending_sync`；在 WS63 卡片写入链路完成前，不会声称实体卡已更新。
- 管理端前端目前仍使用 mock API，需要在下一阶段把各 `src/api/*.ts` 切换到已经存在的 Axios `request` 实例。

## 验证

```powershell
npm run build
npm test
```

自动化测试覆盖 CRC、协议帧编解码、混合文本流重同步、坏帧恢复、SQLite 幂等入库、先持久化后 ACK，以及无硬件启动时的 REST 行为。
