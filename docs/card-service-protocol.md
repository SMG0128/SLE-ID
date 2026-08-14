# Card C 写卡服务协议

版本：1  
传输：Protocol V2 二进制帧，所有多字节整数均为小端序

## 1. 服务边界

Card C 的业务核心已经实现以下正式消息：

| 消息 | 类型 | 方向 | 作用 |
|---|---:|---|---|
| `CARD_INFO` | `0x40` | 工具/A ↔ Card | 查询协议、容量、固件与存储 generation |
| `CREDENTIAL_BEGIN` | `0x41` | 工具/A → Card | 建立一次分片写卡事务 |
| `CREDENTIAL_CHUNK` | `0x42` | 工具/A → Card | 按顺序写入凭证分片 |
| `CREDENTIAL_COMMIT` | `0x43` | 工具/A → Card | 校验 CRC32 并原子提交 |
| `CREDENTIAL_RESULT` | `0x44` | Card → 工具/A | 返回命令结果和提交 generation |
| `CREDENTIAL_LIST` | `0x45` | 工具/A ↔ Card | 返回不含密钥的凭证摘要 |
| `CARD_STATE_SET` | `0x46` | 工具/A → Card | 冻结、挂失、恢复或撤销凭证 |

与传输无关的 Card 业务层由 `card_service.c` 实现。WS63 平台层已经注册 INFO、COMMAND、
RESPONSE、STATUS 四个特征：COMMAND 回调只复制数据到队列，Card 任务再调用
`card_service_handle_command()`，避免在 SLE 服务线程中执行 NV 写入；业务响应通过
RESPONSE 通知发出。

当前联调固件只允许本机串口 `proto` 入口以 `Host` 角色执行写卡、列表和状态命令；远端 SLE COMMAND 不具备管理授权，平台层会拒绝。SLE 侧只接受 Detector A 角色发送的 `AUTH_CHALLENGE`，INFO/STATUS 特征仍可只读。以后若需要手机或远端写卡，必须先定义带签名、权限和防重放的管理员协议，不能直接放开现有 COMMAND。

`CARD_INFO` 响应固定 16 字节：

| 偏移 | 长度 | 字段 |
|---:|---:|---|
| 0 | 1 | 写卡服务协议版本 |
| 1 | 1 | 最大凭证数 |
| 2 | 1 | 当前凭证数 |
| 3 | 1 | 能力位：bit0=持久化存储，bit1=本地串口写卡，bit2=认证次数原子提交 |
| 4 | 4 | `cardId` |
| 8 | 4 | 固件版本 |
| 12 | 4 | 存储 `generation` |

## 2. 凭证写入事务

一份凭证的固定编码长度为 78 字节。密钥只允许出现在加密配对后的 COMMAND 写入中，
不会出现在 `CARD_INFO` 或 `CREDENTIAL_LIST` 响应里。

### CREDENTIAL_BEGIN

| 偏移 | 长度 | 字段 |
|---:|---:|---|
| 0 | 4 | `requestId`，必须非零 |
| 4 | 2 | `totalLength`，当前必须为 78 |
| 6 | 4 | 完整 78 字节凭证的 CRC32 |

### CREDENTIAL_CHUNK

| 偏移 | 长度 | 字段 |
|---:|---:|---|
| 0 | 4 | `requestId` |
| 4 | 2 | `offset` |
| 6 | 1 | `chunkLength`，范围 1～48 |
| 7 | N | 分片数据 |

分片必须按 offset 顺序到达。相同 offset、长度和内容的重复分片会幂等接受；内容不同的
重复分片返回 `OFFSET_MISMATCH`。

### CREDENTIAL_COMMIT

负载只有 4 字节 `requestId`。Card 先检查长度和 CRC32，再解码并验证字段，最后调用双槽
存储提交。提交成功后才更新活动 slot 与 generation。

## 3. 状态修改与读取

`CARD_STATE_SET` 负载：

```text
requestId:u32 | permissionId:u32 | state:u8
```

`CREDENTIAL_LIST` 请求负载为 `requestId:u32`。每项响应固定 48 字节，包含许可范围、
有效期、次数、版本和状态，但不包含 32 字节密钥。全部条目发送完后追加一条
`CREDENTIAL_RESULT` 作为结束标记。

## 4. 结果与幂等

`CREDENTIAL_RESULT` 固定为 18 字节：

```text
requestId:u32 | commandType:u8 | status:u8 | permissionId:u32 |
credentialVersion:u32 | generation:u32
```

Card 缓存最近 8 个最终写操作结果。重复 `COMMIT` 或 `STATE_SET` 只重发原结果，不会再次
写 Flash、递增版本或切换 generation。缓存同时绑定完整凭证 CRC32 或状态命令指纹；同一
`requestId` 换用不同凭证或不同状态会返回 `REQUEST_MISMATCH`。设备重启后缓存会清空，
因此上层仍必须使用读回和版本号确认最终状态。

同一 `requestId` 若被换成不同命令类型会返回 `REQUEST_MISMATCH`。更新已有许可时，`credentialVersion`、`keyVersion` 和 `usageCount` 均不得回退；密钥变化必须伴随 `keyVersion` 递增。相同凭证版本只允许内容完全一致的幂等重放。

## 5. 当前限制

- 手机写卡工具（本地串口写卡工具已完成，见 `docs/CARD_SERIAL_TOOL_GUIDE.md`）；
- B 侧挑战/结果和 A 转发业务核心已完成；A↔Card 第二条真实 SLE 连接及三板验收仍待完成；
- Card 侧 HMAC-SHA-256 挑战响应已完成，协议见 `docs/card-auth-protocol.md`；持久化计数窗口仍待 NV key 预留。
- 四特征固件已通过官方 SDK 编译，但尚未在第三块实体板上完成服务发现和写卡验收；
- 当前交付固件使用安全的 RAM 存储配置，复位会清空凭证；正式 NV key 预留后才能生成持久化固件。

这些分别属于 P2 真板写卡收尾和 P3 真实认证阶段，不能用当前主机测试冒充。
