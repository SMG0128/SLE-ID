# 硬件端与 MilkWa/StarFollow 管理端兼容说明

版本：2026-08-09  
硬件工程：`ni-x-n`  
管理端快照：`D:\naiwa1\SLE-ID-Admin-Backend\SLE-ID-Admin-Backend`

## 1. 结论

管理端后端第一版已完成：`server/` 具备 REST、WebSocket、SQLite 和 USB Protocol V2 串口驱动。
自动化协议与服务测试已通过，尚待连接真实 Detector B 完成串口端到端验收。Vue 3 前端仍调用
mock API，下一阶段需要把 `src/api/*.ts` 切换到真实 Axios/WS 接口。

本轮新增管理端 `server/` 后端源码，但没有修改 Vue 前端源码；前端目录中的 `node_modules/` 和 `dist/` 为测试生成物。

## 2. 已兼容的链路

| 管理端需求 | 硬件消息 | 状态 | 后端映射 |
|---|---|---|---|
| 设备在线、固件、策略版本、运行时长 | `HEARTBEAT 0x30` | 已完成 | 映射为 `Device` 和 `SerialStatus` |
| 事件日志 | `EVENT_REPORT 0x62` | 已完成 | 生成复合事件 ID，映射结果、动作和原因 |
| 报警中心 | `ALERT_REPORT 0x63` | 已完成 | 原因码映射为 8 类 `AlarmType` |
| 强制确认 | `CONFIRM_REQUEST/RESULT 0x64/0x65` | 硬件与后端完成 | 前端确认页面尚未实现 |
| 策略下发与版本回执 | `POLICY_SYNC/RESULT 0x60/0x61` | 基础策略完成 | 支持执行、两类确认、离线、拒绝报警 |
| 命令幂等 | `requestId` + `COMMAND_RESULT 0x66` | 已完成 | 重复请求返回原结果 |
| 离线补传 | RAM 可靠队列 + ACK | 阶段完成 | 32 条，断 USB 不丢；重启会丢 |

## 3. 字段映射

### 3.1 HEARTBEAT 到 Device

```text
sourceId              -> Device.id / sourceId
bootId                -> 设备本次启动标识
firmwareVersion       -> firmware，例如 0x00010002 -> v1.0.2
policyVersion         -> policyVersion，例如 2 -> POL-2
uptimeMs              -> uptimeSeconds
queueDepth            -> 待上传数量
queueOverflows        -> 丢弃计数
framesSent            -> frameCount
接收时间与 1 秒周期    -> status / heartbeat / usbConnected
```

设备名称和位置不应该固化在固件中，由 SQLite 使用 `sourceId` 关联管理端配置。

### 3.2 EVENT_REPORT 到 EventLogItem

管理端不能只使用递增 `eventId`。兼容工具生成：

```text
EV-{sourceId}-{bootId}-{eventId}
```

这样 A 重启后 `eventId` 从 1 重新开始也不会覆盖历史事件。`cardAnonId` 映射为匿名
`CARD-XXXXXXXX`；持有人姓名只能由管理端数据库关联，硬件不会上传姓名。

硬件时间戳当前是启动后的毫秒数，后端必须同时记录主机接收时间。没有可信 UTC 前，禁止把
设备单调时间直接解释为日历时间。

### 3.3 ALERT_REPORT 到 AlarmType

| 硬件原因 | 管理端类型 |
|---|---|
| `NO_PERMISSION/OUT_OF_SCOPE` | `unauthorized` |
| `EXPIRED` | `license_expired` |
| `LOST` | `lost_report` |
| `KEY_FAILED` | `key_failed` |
| `REPLAY_SUSPECTED` | `suspected_replay` |
| `CONFIRM_REJECTED/TIMEOUT/OFFLINE` | `confirm_rejected` |
| `EXECUTION_FAILED` | `execute_failed` |

`unknown_device` 需要后端在收到未登记的 `sourceId` 时产生，不应由 B 猜测。

## 4. 策略兼容边界

管理端定义 10 项组合策略，当前 B 网关可以直接执行其中 4 类：

- `allowExecute`；
- `forceConfirm` 与用户确认开关；
- `offlineAllowed`；
- `unauthorizedAction=alarm` 对应拒绝报警。

以下字段不能静默声称已下发成功：

- `recordEvent=false`：B 当前为安全审计始终上报事件；
- `scope`：Card 存储已有范围字段，但 B 的网关策略摘要尚未下发/执行完整范围；
- `timeLimit`：认证核心支持起止时间，但尚无可信 UTC 和 USB 凭证同步；
- `usageLimit`：认证核心支持次数上限，但计数窗口尚未持久化；
- `direction`：事件携带方向，但 B 尚未按策略拒绝方向；
- `huaweiFallback`：属于 App/后端临时凭证流程，不属于 B 本地布尔策略。

本地后端在这些字段未落地前必须返回“部分支持/不支持”，不能只显示“策略更新成功”。

## 5. 兼容工具

`tools/admin_gateway_compat.ps1` 是后端实现前的参考驱动与测试工具。它能解析混有文本日志的
Protocol V2 字节流、校验 CRC、自动 ACK、维持主机心跳，并输出与管理端类型接近的 NDJSON。

离线映射自测：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\admin_gateway_compat.ps1 `
  -Action SelfTest
```

监听 B 串口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\admin_gateway_compat.ps1 `
  -Action Listen -Port COM6
```

下发基础策略：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\admin_gateway_compat.ps1 `
  -Action Policy -Port COM6 -PermissionId 7 -OrganizationId 100 `
  -PolicyVersion 2 -AllowExecute -OfflineAllowed -AlertOnDenial
```

确认请求必须复用 B 上报的 `requestId` 和 `eventId`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\admin_gateway_compat.ps1 `
  -Action Confirm -Port COM6 -RequestId 77 -EventId 9 -ConfirmResult Approve
```

## 6. 管理端后端最小实现清单（第一版已完成）

1. `serialport` 打开 115200/8N1，按魔数 `53 4C` 流式重同步；不得按文本行读取。
2. 每秒发送一次 Host `HEARTBEAT`，对带 `ACK_REQUIRED` 的消息立即回复 ACK。
3. 将事件、报警和设备心跳写入 SQLite，再通过 WebSocket 推送。
4. REST API 返回统一 `{ code, message, data }`，匹配现有 Axios 拦截器。
5. 策略发布使用单调 `policyVersion` 和唯一 `requestId`，收到 `POLICY_RESULT` 后才标记成功。
6. 确认结果必须携带原 `requestId + eventId`；超时结果不得重试为批准。
7. 保存事件唯一键 `sourceId + bootId + eventId`，数据库加唯一索引。

## 7. 尚未完成的整机能力

- 管理端前端真实 API/WS 切换与确认操作页面；
- Flash 256 条离线日志与设备重启后补传；
- 10 项策略的完整下发和执行；
- 手机端确认入口与安全身份认证；
- 真实 Channel Sounding、方向判定和实时中间状态上报；
- 执行器反馈输入与成功/失败闭环；
- 第三块 Card 的真实双 SLE 联调。
