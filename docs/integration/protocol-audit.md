# SLE-ID 三端协议静态审计

审计时间：2026-08-14  
范围：附件要求的 PHASE 1。只做静态分析与冲突记录；未修改业务代码、未调整协议、未烧录设备。

## 1. 审计基线

移动端权威源码固定为 `D:\naiwa2\SLE-ID-App-OH`。`Downloads` 中的 ZIP 是非最新版参考快照，不作为实现、构建或修复入口。两者当前业务源码相同，因此下述协议结论不变；签名及 lock 文件差异以 `D:\naiwa2` 为准。

为避免破坏已经工作的链路，后续兼容优先级固定为：

1. 硬件 A/B/Card 的 Protocol V2、B↔PC USB 和既有 HMAC 认证；
2. 管理端现有 `/api/*`、`/ws/events`、SQLite 与 B 串口网关；
3. 移动端通过兼容层接入，不直接重构前两项。

当前实际实现：

- 硬件：`SL` magic、Protocol V2、CRC16、小端序、最大 64 字节 payload；Card 写卡业务使用 78 字节凭证、CRC32 分片事务和双槽 NV。
- 管理端：Express + SQLite + WebSocket，B 串口网关已与硬件 Protocol V2 对齐。
- 移动端：生产模式默认开启，但真实后端 API、真实 Card C 适配器均未落地；现有 NearLink 代码是一套独立的诊断协议，不是当前 Card 固件协议。

## 2. 三端入口

### 管理端

- REST：`server/src/routes/api.ts`，挂载于 `/api`。
- WebSocket：`/ws/events`，消息为 `{version, seq, topic, sentAt, data}`。
- 串口：`server/src/ws63/gateway.ts`，115200/8N1。
- Protocol V2：`server/src/ws63/protocol.ts`。
- EVENT/ALERT/CONFIRM/POLICY：`server/src/services/hardware.ts`。
- SQLite：`server/src/db.ts`，表包括 `events`、`alarms`、`confirmations`、`licenses`、`cards`、`invites`、`invite_bindings`、`hardware_frames`、`device_commands`。
- 默认监听：`127.0.0.1:8080`；非回环监听强制要求 `STARFOLLOW_API_TOKEN`。

### 移动端

- 运行时：`entry/src/main/ets/runtime/MobileRuntime.ets`。
- 默认模式：`PRODUCTION`。
- 后端地址：`BackendConfigService.ets`，当前默认 `http://localhost:3000`。
- HTTP：`HarmonyHttpTransport.ets` + `MobileApiClient.ets`。
- WebSocket：目标 `/ws/mobile`，消息按 `type + subjectId` 路由。
- 邀请码/Permission：`MobileApiClient.ets`、`Invitation.ets`、`Authorization.ets`。
- 二次确认：`ConfirmationStore.ets`、`ConfirmationRequest.ets`。
- Card 写入协调器：`CardProvisioningService.ets`，具备 begin/chunk/commit/readback/receipt 的正确事务框架。
- Card 真实适配边界：`CardSleClient.ets` 只有接口，无实现；生产运行时注入 `UnavailableCardCService`，明确失败关闭。
- 现有 NearLink：`NearLinkConnectionService.ets` + `NearLinkProtocol.ets`，只实现 HELLO/PING/DEVICE_INFO 诊断链路。

### 硬件端

- 通用帧：`common/include/ab_protocol.h`。
- 状态与事件：`common/include/hw_types.h`、`detector_a/src/passage_fsm.c`。
- A↔B 与 A↔Card 双客户端：`firmware/h3863/sle_ab/sle_ab_dual_client.c`。
- B 策略/确认/执行与 USB：`detector_b/*`、`firmware/h3863/sle_ab/h3863_sle_ab.c`。
- Card 服务/存储/认证：`card_ws63/*`、`firmware/h3863/sle_card/h3863_sle_card.c`。
- Card SLE：设备名 `sle_card`；16 位服务/特征 `0x2C00`～`0x2C04`。

## 3. 标识字段对照

| 字段 | 硬件 | 管理端 | 移动端 | 结论 |
|---|---|---|---|---|
| `organizationId` | `uint32`；Card 凭证、认证挑战和策略同步均使用 | 部署策略时临时传入，默认 100；当前 `licenses` 表未持久化该字段 | 类型为 `string`，Permission/凭证模型必填 | **冲突**：后端缺少许可级持久化，类型也不一致 |
| `detectorId` | B 认证结构中为 `uint32 detector_id`，实际与设备 sourceId 相关 | 核心使用 `sourceId`，API 展示为 `DEV-XXXXXXXX`；没有统一 `detectorId` 字段 | `string` | **命名/类型冲突**；需由后端建立显示 ID 与 wire u32 映射 |
| `nodeId` | 无正式字段 | 无正式字段，仅有设备节点数量 | 无正式业务使用 | **未定义**；不要擅自引入，除非明确其与 sourceId/detectorId 的关系 |
| `cardAnonId` | wire 为 `uint32 card_id/card_anon_id` | 数据库为整数，API 常格式化为 `CARD-XXXXXXXX` | `string` | 概念一致、序列化不一致；API 层应统一使用 `CARD-XXXXXXXX`，写卡包另带 wire u32 |
| `permissionId` | `uint32`，贯穿凭证、认证、事件 | 同时存在公开字符串 `licenses.id=LC-...` 与 `hardwarePermissionId:uint32` | 只有一个字符串 `permissionId` | **关键冲突**：移动端不能把 `LC-...` 直接写入 78 字节凭证；必须同时获得公开 ID 与 `hardwarePermissionId` |
| `eventId` | 每次启动内 `uint32`；唯一键必须是 `sourceId+bootId+eventId` | 保存 raw `eventId`，对外还有 `eventKey=EV-source-boot-event` | `string` | 移动端应使用不可碰撞的 `eventKey` 作为公开事件 ID；确认协议内部保留 raw u32 |
| `requestId` | 状态变更命令/确认使用 `uint32`，结合 source/boot 判定会话 | 确认数据库公开主键为 `CF-source-boot-request`，同时保存 raw requestId | `string` 并直接作为确认 API 路径 | **冲突**：移动端应使用 confirmation `id`；不能仅用 raw requestId |
| `policyVersion` | `uint32`，拒绝回滚 | 后端/SQLite 为 number，全局单调递增 | `string` | 类型冲突；移动 API 应序列化为 number，或显式区分显示文本与 wire 数值 |

建议的最小 ID 规则：后端作为唯一映射权威；API 使用稳定字符串 ID，同时返回明确命名的 `hardwarePermissionId:number`、`cardAnonU32:number`、`rawEventId:number`，禁止一个字段承担两种含义。

## 4. 状态对照

| 状态域 | 硬件 | 管理端 | 移动端 | 兼容结论 |
|---|---|---|---|---|
| Card | ACTIVE/FROZEN/LOST/EXPIRED/REVOKED (0～4) | 正常/已冻结/已挂失/已撤销，另有 `pending_sync` | active/frozen/lost/expired/revoked/deregistered/pending_sync 等 | 基础五态可映射；额外状态必须保留为管理/同步态，不能下发为硬件枚举 |
| Permission | 许可摘要 + Card credential state；硬件只接受 u32、版本、有效期等 | 有效/即将过期/已过期/已撤销；当前字段不足以生成完整 78 字节凭证 | draft/invited/bound/active/expired/revoked/usageExhausted | 需要移动 API DTO；现有管理端 license 不是完整 Card credential |
| Event | IDLE/APPROACHING/IN_ZONE/COMPLETED/CANCELLED/COOLDOWN | USB 仅持久化 B 上报的联合事件/决定；保存 raw state | 没有与硬件状态直接对齐的实时事件模型 | 第一闭环只需要最终 COMPLETED/决定；中间态不要伪造为后端事件 |
| Authentication | UNKNOWN/AUTHORIZED/UNAUTHORIZED/KEY_FAILED/REPLAY_SUSPECTED | 保存 raw number，转换报警与结果 | 无对应认证结果枚举 | 移动确认 DTO 可只读展示；不得让移动端自行宣布授权 |
| Confirm | NOT_REQUIRED/PENDING/APPROVED/REJECTED/TIMEOUT/OFFLINE | raw number + DB pending/sending/resolved/failed | notRequired/pending/approved/rejected/timeout/offline | 语义基本一致；需建立 DTO，并以复合 confirmation id 防止旧响应放行新事件 |
| Execution | NOT_REQUESTED/PENDING/SUCCESS/FAILED | raw number并转换中文状态/报警 | 无对应硬件执行状态 | 后端可作为只读字段推送，移动端不应本地推断成功 |
| Alert | 由稳定 reason code/执行失败产生 | 8 类报警、3 级严重度 | 只有授权的 alertPolicy/alertLevel，无实际报警事件模型 | 策略概念不等于报警实例；若移动端需要显示必须由后端推送实际 alarm DTO |

## 5. HTTP 与 WebSocket 冲突

| 项目 | 管理端实际实现 | 移动端当前期待 | 影响 |
|---|---|---|---|
| 基础地址 | `http://127.0.0.1:8080` | `http://localhost:3000` | 真平板必然访问错误主机和端口 |
| REST 响应 | `{code, message, data}` | 直接把 body 解析为业务 DTO | 即使路径存在也会解析失败 |
| 配对 | 无 `/api/mobile/pair`；只有可选全局 API token | `/api/mobile/pair` 返回 subject session/token | 生产运行时无法建立 SessionStore |
| 钱包 | `/api/licenses`、`/api/cards` 是管理 DTO | `/api/mobile/cards` 返回 cards + authorizations + revision | 路径与模型均不存在 |
| 邀请预览 | 无 preview 路由 | `/api/mobile/invites/preview` | 404 |
| 邀请兑换 | `/api/invites/redeem`，需要 `{code, subject}` | `/api/mobile/invites/redeem`，只发 `{code}`，且期待 Permission/Card/回执 | 路径、请求、响应均冲突 |
| 邀请码格式 | 后端生成 8 字符 base64url 风格代码 | 客户端强制 `SLE-XXXX-XXXX` | 客户端会在请求前拒绝后端生成的码 |
| 二次确认 | `/api/confirmations/pending`；decision body `{decision:'approve'|'reject'}`，路径参数是 confirmation id | `/api/mobile/confirmations/...`；body `{status:'approved'|'rejected'}`，路径参数叫 requestId | 路径、枚举、ID 含义均冲突 |
| WebSocket | `/ws/events?access_token=...`，`topic/data` | `/ws/mobile`，Bearer header，`type/subjectId` | 连接和消息路由均不兼容 |

最小方案不是改掉现有管理 API，而是在同一后端新增 `/api/mobile/*` 和 `/ws/mobile` 兼容层，内部复用现有数据库、HardwareService 和 WsHub 事件源。

## 6. 平板 ↔ Card SLE 冲突

| 项目 | Card 固件实际值 | 移动端当前值 | 结论 |
|---|---|---|---|
| 广播名 | `sle_card` | `SLEKEY-A` | 不会按名称发现同一设备 |
| Service | 16 位 `0x2C00` | 128 位 `7A7B0001-...` | 完全不同 |
| Characteristics | INFO `2C01`、COMMAND `2C02`、RESPONSE `2C03`、STATUS `2C04` | CONTROL/STATUS/DEVICE_INFO 为另一套 128 位 UUID | 完全不同 |
| 帧 magic/version | `53 4C` (`SL`)，version 2，20 字节头，最大 payload 64 | `53 4B` (`SK`)，version 1，8 字节头，最大 payload 256 | 完全不同 |
| 写卡消息 | `0x41/0x42/0x43`，78 字节凭证，48 字节最大 chunk，结果 `0x44` | 真实命令未实现；只有 HELLO/PING/DEVICE_INFO | 不能写卡 |
| 生产注入 | Card SLE 服务存在，但远程 COMMAND 当前只允许 A 的 AUTH_CHALLENGE；管理写卡被拒绝 | `UnavailableCardCService`，失败关闭 | 两端均明确不支持“平板直接写卡”现状 |

移动端 `CardProvisioningCoordinator` 的事务顺序与硬件 BEGIN/CHUNK/COMMIT/读回思想一致，可以保留；应替换的是底层 `CardSleClient` 适配器，而不是重新设计协调器。

安全阻塞：Card 固件文档明确禁止未经授权的远程管理写卡。不能为了联调直接放开 COMMAND。最小后续设计应是：后端签发短期、绑定 Card/permission/request/nonce/expiry 的不透明写卡授权；Card 验证授权、防重放和配对身份后才接受该事务。正式密钥不得进入移动端源码或 Git。

## 7. 已实现能力与真实缺口

### 已实现且应保护

- A↔B SLE、A↔Card 双连接代码与三板 HMAC 认证核心。
- B↔PC Protocol V2、心跳、事件/报警/确认、ACK 重试与 SQLite 幂等持久化。
- Card 78 字节凭证、分片 CRC32、双槽原子提交、状态/版本/计数防回滚。
- 管理端确认 requestId/eventId 绑定和迟到结果拒绝。
- 移动端本地安全模型、确认终态保护、写卡事务协调器与持久化回执框架。

### 阻塞真实闭环

1. 移动端没有可调用的后端 mobile API，默认地址也不适用于真平板。
2. 后端 license/invite 当前不能生成移动端所需的完整 Permission/CardWritePackage，且 organizationId 未持久化到许可。
3. 移动端没有硬件 Card SLE 适配器；现有 NearLink 诊断协议与 Card 固件完全不兼容。
4. Card 固件安全策略拒绝移动端管理写入；缺少签名写卡授权协议。
5. 真实 Channel Sounding 尚未接入。A 的通行状态机存在，但 `demo enter/reverse/timeout` 仍是主要观测输入；不能把模拟经过当作最终真机 CS 验收。
6. 本轮设备映射中 Card/A 尚未同时通过当前启动日志确认。

## 8. 最小改进顺序（供 PHASE 2 以后审阅）

1. **不动硬件链路**：保留所有现有 `/api/*`、`/ws/events` 和 Protocol V2 行为，并加入回归测试。
2. **后端移动兼容层**：新增 mobile pairing/session、wallet、invite preview/redeem、confirmation DTO 与 `/ws/mobile` 适配；内部复用现有表和硬件服务。
3. **补齐许可数据**：许可持久化 organizationId、有效期、次数、scope、policy flags、hardwarePermissionId、credential/key version；密钥仅安全存储，不返回普通管理 API。
4. **运行配置**：开发模式允许显式 `STARFOLLOW_HOST=0.0.0.0` + 强 token；平板把可编辑地址设置为 PC 当前 LAN IP 和 8080，不永久硬编码个人 IP；不自动改防火墙。
5. **Card 写卡授权**：先敲定签名/防重放票据，再实现固件受控远程写入和 ArkUI `CardSleClient`；复用 `0x2C00`～`0x2C04` 与 Protocol V2。
6. **先走第一闭环**：邀请码领取 → 真写卡/读回 → A/B 真认证 → B USB → 管理事件；成功后才接二次确认。
7. **最后接真实 CS**：把 Channel Sounding 观测接入现有 passage FSM，保留 demo 命令作为可配置测试模式，禁止混作真实事件。

## 9. PHASE 1 结论

管理端与硬件端当前协议是同一条已工作基线；移动端并非“只差一个地址”，而是同时缺少 mobile 后端路由、DTO 映射、会话模型和 Card 固件适配。后续应以兼容层和一个真实 `CardSleClient` 为主，不应重构已有 B USB 或 A/B 协议。

在进入 PHASE 2 前，应先完成 COM7/COM9 的当前角色确认，并由用户确认后端 mobile API 与安全写卡票据的最小设计。
