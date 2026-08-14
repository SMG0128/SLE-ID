# WS63 Card C 工程

当前已建立 Card C 的前两层可测试核心：最多 8 项匿名许可、稳定字段模型、CRC32 完整性校验、A/B 双槽原子更新，以及正式的分片写卡事务。写入时只改非活动槽，回读校验成功后才切换活动 generation；写失败、校验失败或中途掉电时，重启仍选择上一份有效记录。

`card_service.c` 已实现 `CARD_INFO`、`CREDENTIAL_BEGIN/CHUNK/COMMIT/RESULT/LIST` 和 `CARD_STATE_SET`。最近 8 个最终写请求按 `requestId` 和内容指纹缓存；完全重复的提交只重发原结果，不重复写 NV 或递增凭证版本，同 ID 不同内容则拒绝。列表响应不包含 32 字节密钥。详细负载见 `docs/card-service-protocol.md`。

`platform/ws63/ws63_card_sle_server.c` 已实现独立 Card SLE 服务，UUID 为 `0x2C00`，四个特征分别为 INFO `0x2C01`、COMMAND `0x2C02`、RESPONSE `0x2C03`、STATUS `0x2C04`。COMMAND 要求加密和认证连接，写回调只入队，不在 SLE 服务线程中执行 Flash 操作。`firmware/h3863/sle_card` 已使用官方 SDK 完成编译和打包。

`platform/ws63/ws63_card_nv_port.c` 已适配官方 `uapi_nv_read/uapi_nv_write`。经当前 SDK 核查，WS63 普通 NV 单项上限为 4060 字节，Card 每个双槽镜像为 768 字节；SDK 将 `0x5000-0xFFFE` 划为用户普通区，工程进一步保留 `0x5C00-0x5CFF` 作为 Card 命名空间，并使用 `0x5C10/0x5C11`。适配层会拒绝命名空间外或相同的双槽 key，编译期也会检查镜像不超过 SDK 上限。

当前 `outputs/card_c_h3863_ram_all.fwpkg` 是安全的 RAM 联调固件，复位会清空凭证。已提供 `tools/card_serial_tool.ps1` 和开发态本地 UART 协议入口，可执行 INFO、LIST、分片写卡与 STATE_SET；详细步骤见 `docs/CARD_SERIAL_TOOL_GUIDE.md`。`tools/rebuild_card_nv_release.ps1` 可生成默认保留串口写卡入口的 NV 个性化固件；加 `-ProductionLockdown` 会关闭该入口并只交付不覆盖 NV 分区的 `load_only` 部署包。两种持久化固件均尚未在本轮构建或真板验证。

`card_auth.c` 已实现 Card 侧 `AUTH_CHALLENGE -> AUTH_RESPONSE`：双向 HMAC-SHA-256 证明、16 字节截断标签、常量时间比较、许可状态/有效期/版本检查、最近 4 个会话幂等和同 session 篡改拒绝。每次成功认证会先通过凭证双槽存储原子提交新的 `usage_count`，提交或回读校验失败只返回 `INTERNAL`，不会签发成功证明；完全重复的 challenge 在凭证仍为 ACTIVE 且版本未变化时只重发缓存响应，不重复扣次数，凭证状态或密钥变化后旧成功证明立即失效。协议见 `docs/card-auth-protocol.md`。B 侧认证权威和 A 转发核心已经完成，仍待第三块真板双 SLE 全链路验收。当前交付固件使用 RAM 存储，所以复位仍会清空凭证和次数；启用正式 NV 双槽后计数提交才具备掉电持久性。
