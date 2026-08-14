# Card C HMAC 挑战响应协议

版本：1（承载于 Protocol V2）

认证权威是 Detector B。A 负责发现 Card、转发 B 的挑战和 Card 的响应，不自行宣布认证成功。
B 和 Card 按许可共享 32 字节密钥；A 不需要持有该密钥。

## 1. 消息流程

```text
B -> A       AUTH_START / 本地会话请求
B -> A -> C  AUTH_CHALLENGE (0x51)
C -> A -> B  AUTH_RESPONSE  (0x52)
B -> A       AUTH_RESULT    (0x53)
```

Card 已实现 `AUTH_CHALLENGE -> AUTH_RESPONSE`，B 已实现挑战生成、响应校验和最终结果，A 已实现
按会话转发核心。当前 A↔Card 通过串口桥可完成阶段联调；A 同时维持 B/Card 两条 SLE 连接的驱动仍待实现。

## 2. AUTH_CHALLENGE

负载固定 64 字节，所有整数为小端序：

| 偏移 | 长度 | 字段 |
|---:|---:|---|
| 0 | 4 | `sessionId`，非零 |
| 4 | 12 | `nonce`，由 B 的安全随机源生成且不能全零 |
| 16 | 4 | `detectorId` |
| 20 | 4 | `organizationId` |
| 24 | 4 | `permissionId` |
| 28 | 4 | `credentialVersion` |
| 32 | 4 | `keyVersion` |
| 36 | 4 | `minimumCounter`，B 已接受的最高计数值 |
| 40 | 4 | `unixTime`，用于许可有效期检查 |
| 44 | 4 | `policyDigest`，B 当前策略摘要 |
| 48 | 16 | `challengeTag` |

挑战标签：

```text
HMAC-SHA-256(key,
  "SLE-AUTH-CHAL-V1" || protocolVersion:u8 || challenge[0..47])[:16]
```

Card 先检查许可组织、状态、有效期、使用上限、凭证版本和密钥版本，再使用常量时间比较验证标签。
失败统一返回 `DENIED`，不向中间节点泄露具体许可状态。

## 3. AUTH_RESPONSE

负载固定 48 字节：

| 偏移 | 长度 | 字段 |
|---:|---:|---|
| 0 | 4 | `sessionId` |
| 4 | 4 | `permissionId` |
| 8 | 1 | `status` |
| 9 | 3 | 保留，置零 |
| 12 | 4 | `cardId` |
| 16 | 4 | `counter` |
| 20 | 4 | `credentialVersion` |
| 24 | 4 | `keyVersion` |
| 28 | 4 | `cardBootId` |
| 32 | 16 | `responseTag` |

成功响应标签绑定完整挑战和响应正文：

```text
HMAC-SHA-256(key,
  "SLE-AUTH-RESP-V1" || protocolVersion:u8 ||
  challenge[0..47] || response[0..31])[:16]
```

状态值：`0=OK`、`1=DENIED`、`2=BAD_CHALLENGE`、`3=REPLAY`、`4=INTERNAL`。
非成功响应的标签为全零，B 不得把它解释为认证证据。

## 4. AUTH_RESULT

B 验证完成后向 A 返回固定 20 字节负载：

| 偏移 | 长度 | 字段 |
|---:|---:|---|
| 0 | 4 | `sessionId` |
| 4 | 4 | `cardId` |
| 8 | 4 | `permissionId` |
| 12 | 1 | `auth`：UNKNOWN/AUTHORIZED/UNAUTHORIZED/KEY_FAILED/REPLAY_SUSPECTED |
| 13 | 1 | `reason`，使用公共稳定原因码 |
| 14 | 2 | 保留，置零 |
| 16 | 4 | B 已接受的 `counter` |

A 只有收到 B 的 `AUTH_RESULT` 后才建立一次性通行授权；Card 的成功响应本身不能让 A 宣布授权。A 将 `sessionId + cardId + permissionId + counter` 绑定到下一条完整 `PASSAGE_EVENT`，随后立即清除本地授权。B 必须在自己的成功会话表中精确匹配并原子消费该授权；重复消费、字段篡改和会话超时全部拒绝。A 串口的 `auth ok` 不能构造这组绑定字段，因此不能绕过 B 的认证权威。

## 5. 幂等与防重放边界

- Card 缓存最近 4 个会话；完全相同的挑战只重发原响应，不重复增加计数器；
- 重发缓存成功响应前，Card 会重新核对凭证仍为 ACTIVE，且凭证版本和密钥版本未变化；冻结、挂失、撤销或换钥会立即使旧缓存失效；
- 相同 `sessionId` 携带不同内容会返回 `REPLAY`；
- B 必须保证 `sessionId + nonce` 唯一，并拒绝已经完成或超时的会话；
- B 对完全重复的成功响应返回同一结果且不重复推进 counter；同 session 的冲突响应按重放拒绝；
- A 缓存最近 4 个认证会话，完全重复帧可重发，冲突内容和超时响应不转发；
- A 以 500 ms 间隔重发尚未得到 Card 响应的挑战，或尚未得到 B 最终结果的 Card 响应，最多各 3 次；
- 每个 B 成功认证会话最多授权一条通行事件；通行事件重传只触发缓存决定重发，不重复消费授权或执行 GPIO；
- Card 返回 `cardBootId`，B 可识别 Card 重启；
- Card 的最近 4 个会话响应缓存位于 RAM，重启后清空；
- 成功认证先把新计数通过凭证存储的 A/B 双槽原子提交，再生成并发送成功响应；写入或回读校验失败返回 `INTERNAL`，不会发出成功证明；
- 完全重复的 challenge 命中会话缓存，只重发首次响应，不再次提交 `usageCount`；
- 使用正式 NV 双槽后，已提交的 `usageCount` 可跨重启恢复；当前 RAM 联调固件的整个凭证存储都会在复位时清空，因此不能用它验证掉电持久性。

因此核心实现已经能抵抗重复/篡改挑战，并在持久化后才签发成功响应。正式版本仍需先在 SDK NV 数据库中预留无冲突的双槽 key、构建 NV 固件并完成掉电故障注入与写入寿命评估；B 同时保存每项许可已接受的最高计数器，作为 Card 回滚时的第二道防线。若写入寿命不足，再把逐次双槽提交升级为分块计数预留方案。

## 6. 已完成验证

- RFC 4231 HMAC-SHA-256 标准向量；
- 正常挑战和截断 16 字节标签；
- 完全重复挑战幂等；
- 相同会话内容变化拒绝；
- 错误挑战 MAC 拒绝；
- 许可过期拒绝；
- B 与 Card 正常互操作、错误响应标签、会话超时、冻结、次数耗尽和版本回滚；
- 畸形认证响应安全初始化、成功授权精确匹配、单次消费和重复消费拒绝；
- A 挑战/响应/结果路由、重复幂等、冲突消息和会话超时；
- 挑战/响应丢包重传，以及 `AUTH_RESULT` 与下一条通行事件的一次性绑定；
- A、B、Card 三份固件均通过官方 H3863/WS63 SDK 编译、链接、签名和打包。

尚未完成第三块实体板上的双 SLE `B→A→Card→A→B` 全链路认证验收。串口桥阶段测试见
`docs/H3863_THREE_PARTY_AUTH_SERIAL_BRIDGE_TEST.md`。
