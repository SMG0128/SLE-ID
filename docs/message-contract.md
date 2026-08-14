# 消息契约（Protocol V2）

## 通用二进制帧

所有多字节整数使用小端序。CRC16-CCITT 的输入从 `protocolVersion` 开始，到 payload 最后一个字节结束；不包含两个 magic 字节和 CRC 字段本身。

| 偏移 | 长度 | 字段 | 说明 |
|---:|---:|---|---|
| 0 | 2 | magic | 固定 `0x53 0x4C`（`SL`） |
| 2 | 1 | protocolVersion | 当前为 `2` |
| 3 | 1 | messageType | 消息类型 |
| 4 | 1 | flags | bit0 ACK_REQUIRED、bit1 RESPONSE、bit2 RETRY |
| 5 | 1 | sourceRole | Card=1、A=2、B=3、Host=4 |
| 6 | 4 | sourceId | 设备稳定标识 |
| 10 | 4 | bootId | 每次启动由 TRNG 生成 |
| 14 | 4 | messageId | 同一启动周期内单调递增 |
| 18 | 2 | payloadLength | 当前最大 64 字节 |
| 20 | N | payload | 类型相关负载 |
| 20+N | 2 | CRC16 | CCITT，初值 `0xFFFF` |

事件唯一键固定为 `sourceId + bootId + eventId`，不能只用 eventId。会改变状态的正式命令还必须在 payload 中携带 requestId，并以 requestId 保证幂等。

## 当前已实现消息

| 链路 | 类型 | 状态 |
|---|---|---|
| A → B | `PASSAGE_EVENT` (`0x10`) | 已实现；30 字节事件负载，要求 ACK；携带一次性认证授权绑定 |
| B → A | `DECISION` (`0x20`) | 已实现；认证、动作、确认、执行、原因相互独立 |
| 双向 | `ACK` (`0x7F`) | 已实现；被确认 messageId + ACCEPTED/DUPLICATE/BAD_MESSAGE/BUSY |
| B ↔ Host | `HEARTBEAT` (`0x30`) | B 已实现 1 秒设备心跳；Host 心跳用于在线判定 |
| 工具/A → Card | `CREDENTIAL_BEGIN/CHUNK/COMMIT` (`0x41`～`0x43`) | Card 业务核心已实现分片、CRC32、原子提交与重复请求幂等 |
| Card → 工具/A | `CARD_INFO/CREDENTIAL_RESULT/LIST` (`0x40`、`0x44`、`0x45`) | Card 业务核心与 SLE 四特征适配已实现并通过 SDK 编译；待真板验收 |
| 工具/A → Card | `CARD_STATE_SET` (`0x46`) | 已实现凭证状态原子更新核心 |
| B → A → Card | `AUTH_CHALLENGE` (`0x51`) | B 生成并签名、A 按会话转发、Card 验证 |
| Card → A → B | `AUTH_RESPONSE` (`0x52`) | Card 生成 HMAC 证据、A 转发、B 验签与 counter 防重放 |
| B → A | `AUTH_RESULT` (`0x53`) | 已实现 20 字节最终认证结果；A 仅以此建立一次性通行授权 |
| Host → B | `POLICY_SYNC` (`0x60`) | 已实现 requestId 幂等、版本防回滚和基础策略原子更新 |
| B → Host | `POLICY_RESULT` (`0x61`) | 已实现状态与当前策略版本回执 |
| B → Host | `EVENT_REPORT/ALERT_REPORT` (`0x62/0x63`) | 已实现 40 字节事件/决定联合上报与 ACK 重试 |
| B → Host | `CONFIRM_REQUEST` (`0x64`) | 已实现 requestId、eventId 绑定和超时撤销 |
| Host → B | `CONFIRM_RESULT` (`0x65`) | 已实现批准/拒绝、幂等和迟到确认拒绝 |
| B → Host | `COMMAND_RESULT` (`0x66`) | 已实现确认等命令的统一结果回执 |

`PASSAGE_EVENT` 的前 18 字节保持原字段顺序，后续增加 `authSessionId:u32 + permissionId:u32 + authCounter:u32`。B 只有在这三个字段与尚未消费、未超时的成功 HMAC 会话完全一致时才将事件视为已授权，并立即把该授权标记为已消费。

A 在 500 ms 内未收到完整 ACK/DECISION 闭环时使用相同 messageId 和事件键重发，最多重试 3 次。B 保存最近 32 个复合事件键和对应决定；重复帧返回 DUPLICATE ACK 并重发缓存的 DECISION，不会重复执行策略或 GPIO。认证中继也以 500 ms 间隔重发挑战或响应，最终仍受会话超时限制。

Card 写卡负载和结果格式见 `docs/card-service-protocol.md`。

## B 与本地后端

B 网关使用 UART0 115200/8N1 上的同一 Protocol V2 帧格式。可靠上报采用 32 条 RAM FIFO；
队首消息带 `ACK_REQUIRED`，500 ms 重试三次后进入 2 秒退避，Host 返回 ACCEPTED 或
DUPLICATE ACK 后释放。USB 断开期间队列保留，但 B 复位会清空。

完整负载和管理端映射见 `docs/ADMIN_BACKEND_COMPATIBILITY.md`。Flash 256 条日志、
`LOG_UPLOAD/ACK`、完整 10 项策略和正式 DEBUG/LOG 帧仍待实现，不能用 RAM 队列或文本日志冒充。

Card 认证业务核心已完成，负载见 `docs/card-auth-protocol.md`；A↔Card 的真实第二条 SLE
连接管理和三板真机验收待完成。

## 稳定原因码

已冻结的枚举顺序见 `common/include/ab_messages.h`，包括：`NO_PERMISSION`、`OUT_OF_SCOPE`、`NOT_YET_VALID`、`EXPIRED`、`USAGE_EXHAUSTED`、`FROZEN`、`LOST`、`REVOKED`、`KEY_VERSION_MISMATCH`、`KEY_FAILED`、`REPLAY_SUSPECTED`、`POLICY_STALE`、`BACKEND_OFFLINE`、`CONFIRM_REJECTED`、`CONFIRM_TIMEOUT`、`CONFIRM_OFFLINE`、`EXECUTION_FAILED`、`LINK_LOST`、`DUPLICATE_EVENT`、`BUSY`、`STALE_REQUEST`、`BAD_MESSAGE`。
