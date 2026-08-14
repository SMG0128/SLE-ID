# SLE A/B 硬件端状态

更新时间：2026-08-09

> 2026-08-13 后端高优先级修复完成：启动时可恢复中断在 `sending` 的人工确认；REST 与 WebSocket 支持共享令牌，并禁止无令牌监听非回环地址；邀请码具备原子兑换、绑定记录、次数扣减和重复绑定保护。TypeScript 编译、13 项后端测试及全部 A/B/Card 主机回归均通过。本轮未改管理端前端和 A/B/Card 固件。

> 2026-08-13 管理端真实链路接入完成：全部业务 API 已由 Mock 切换为真实 REST，接入带指数退避重连的 `/ws/events`，新增“待确认”页面和允许/拒绝闭环；首页统计、趋势、报警、设备与串口状态改为真实数据。队友仓库 `D:\naiwa1` 的前后端已同步，前端生产构建、后端 13 项测试、前后端托管冒烟和全部 A/B/Card 主机回归通过。原前后端源码已分别保存到 `backups/`。

> 2026-08-09 已完成管理端兼容性检查和第一版真实本地后端：B 端具备单 USB Protocol V2 网关；后端具备 SQLite、REST、WebSocket、串口验证、事务后 ACK、幂等和命令重试。A/B 官方 SDK 全量重编译与主机回归测试通过；后端 9 项自动化测试通过，真实 B 板串口联调待执行。

## 已完成

- Detector A/B 公共协议、业务核心和 H3863 平台适配已完成。
- 官方 SDK 安装位置：`D:\hispark\sdk\fbb_ws63\src\application\samples\custom\sle_ab`。
- Detector A 和 Detector B 均已使用官方 SDK 成功编译、签名和打包。
- 两份全量固件已分别保存到 `outputs/`。
- 主机单元测试全部通过。
- A/B 公共协议已升级到 V2：设备/启动/消息 ID、ACK、A 端超时重试和 32 项复合键去重。
- 已修复后台离线原因、确认事件覆盖和过期确认仍可执行的问题。
- 已建立 Card C 凭证存储核心与 WS63 NV 适配，主机故障注入测试通过。
- 已完成 Card C 分片写卡事务核心：INFO、BEGIN、CHUNK、COMMIT、RESULT、LIST、STATE_SET，支持 CRC32、最近 8 个 requestId 幂等结果缓存和不含密钥的摘要读取。
- 已新增独立 `sle_card` SDK 工程和 INFO/COMMAND/RESPONSE/STATUS 四特征；COMMAND 使用加密/认证权限并通过队列移出 SLE 回调线程。
- 已新增 Card C 本地串口 Protocol V2 入口和 `tools/card_serial_tool.ps1`，支持 INFO、LIST、分片写卡、状态修改及无密钥泄露的 DryRun。
- 已实现 Card C HMAC-SHA-256 挑战响应核心：B 签名挑战验证、Card 响应证明、许可检查、会话幂等和 RAM 防重放；RFC 4231 与异常路径测试通过。
- Card C RAM 安全联调固件已按版本 `0x00010100` 通过官方 SDK 完整编译、签名和打包，SHA256 为 `1ED0AED1CBF0F45468FA28D03C82B951031F1E20DE10C4C1048E71B942830B89`。
- Card 认证成功现在会先经凭证双槽后端原子提交 `usageCount`，写入或回读失败不会签发成功响应；正式 NV 配置可跨复位恢复，当前 RAM 联调固件仍会随复位清空整个存储。
- 已核查当前 WS63 SDK 的用户普通 NV 范围和单项容量，项目保留 Card 命名空间 `0x5C00-0x5CFF`，默认双槽为 `0x5C10/0x5C11`；适配层增加范围、重复 key、固定槽长和 SDK 容量保护。
- 已实际执行 NV 个性化/部署锁定构建：首次个性化全量包 SHA256 为 `9153D8374837ACEBAC9EA9DB79315583B16007F33672C3C2F02CA21408FFBE1F`；不覆盖 NV 区的锁定 `load_only` 包 SHA256 为 `5421DAD234AF71293C3EBCCDBA5A2D8F5950B671081E15181551D83C95286113`。
- 已修复生产锁定配置关闭串口个性化后 `hex_decode` 未使用导致 `-Werror` 构建失败的问题，修复后全套主机测试和官方 SDK 全量构建均通过。
- Card 最终命令缓存已绑定请求内容指纹，同一 `requestId` 换用不同凭证或状态会拒绝，不再误重放旧成功结果。
- 已实现 B 侧认证权威核心：TRNG challenge、HMAC 响应校验、4 会话超时/幂等、许可原因和最高 counter 防重放。
- 已实现 A 侧认证中继核心：B/Card 双解析器、4 会话路由、冲突重复与超时拒绝，并只接受 B 的 `AUTH_RESULT` 作为最终认证结果。
- 已通过 B↔Card 密码学互操作和 A 中继主机测试；A/B 新固件均通过官方 SDK 构建。
- 已提供 `tools/three_party_auth_serial_bridge.ps1`，可用真实 A↔B SLE 加 A↔Card 串口桥完成三端阶段验收。
- 已修复 A 本地模拟认证可被 B 信任的问题：成功 HMAC 结果现在以 `sessionId + cardId + permissionId + counter` 绑定下一条通行事件，并由 B 精确匹配、限时且只消费一次。
- 已修复 ACK 已到但 DECISION 丢失时无法恢复的问题：A 保留待决事件并重发，B 对重复事件重发缓存决定且不重复执行 GPIO。
- 已增加认证挑战/响应 500 ms 重传、畸形响应安全初始化、凭证版本/密钥/计数回滚保护和跨命令 requestId 冲突拒绝。
- Card 管理命令当前限制为本机串口 Host，远端 SLE 仅接受 Detector A 的认证挑战与只读特征。
- 三端串口桥工具已升级为认证后自动触发一次通行，并以 B 实际执行作为通过条件。
- 已新增 `tools/ab_security_smoke.ps1`，可自动识别双串口 A/B，并验证未绑定本地授权必须被拒绝且 GPIO 不动作。
- 当前认证版 A 固件 SHA256：`4D7C53AF80C1DE6658366754DCB08546C962E42507EE79B2623AA57A9186EAFE`。
- 当前认证版 B 固件 SHA256：`313465EA326CC9720DF17130EC1A1F6777F683DA8ADB58E41846C3EC5B6E1038`。
- 已增加可重复的 SDK 配置、A/B 清理构建、产物收集和哈希脚本。
- Protocol V2 已在两块实体 H3863 上完成 ACK、A 重启事件键、确认超时、BUSY 防覆盖、断线重试和重连恢复验收；详见 `docs/H3863_PROTOCOL_V2_TEST_REPORT.md`。
- 双板烧录、串口命令和验收步骤见 `docs/H3863_A_B_双板测试指南.md`。
- 已完成 B→管理端的心跳、事件、告警、确认、策略与命令结果协议，心跳周期调整为 1 秒。
- 已提供 `tools/admin_gateway_compat.ps1` 作为后端串口驱动参考，可解析混合文本/二进制流、自动 ACK、维持主机心跳并输出管理端 DTO 风格 NDJSON。
- 已修复 Host 策略 requestId 与 B 本地确认 requestId 数字碰撞、过期确认残留队列、满队列却误标 active 三个缺陷。
- 管理端 `vue-tsc --noEmit && vite build` 通过；`server/` 已完成可运行的 TypeScript 后端。本轮没有改动管理端前端源码，其 `src/api/*.ts` 仍使用 mock。
- 当前 A 固件 SHA256：`5D4B54D56A06E5117154A446EEDB216C36DF4AD8524D170EF32BEFF59341F949`。
- 当前 B 固件 SHA256：`2C49CB51DBAC604295CF4FAB75DDE4A7858EC330A25A7F86A17D5F1275E0B3E3`。
- 当前源码归档 SHA256 记录在 `outputs/SHA256SUMS.txt`；每次 Card NV 构建会自动刷新源码包及全部固件校验值。

## 下一阶段

- 在第三块实体板上验证 Card 服务发现、配对、分片写卡、读回和重复提交；
- 实现 A 同时维持 B/Card 的双 SLE 连接管理，替换当前 A↔Card 串口桥；
- 在正式 NV 双槽上验证认证次数跨复位恢复、掉电回退和写入寿命；必要时再升级为分块计数预留；
- 第三块板可用后，先烧录 NV 个性化全量包并完成首次写卡，再烧录 `load_only` 锁定包，确认凭证未被覆盖且串口写卡入口已关闭；
- 将 A 端串口模拟观测替换为真实 Channel Sounding/传感器输入；
- 需要独立卡片节点时，再添加第三块支持 SLE 的板卡和 Card 固件。
- 关闭 B 板串口监视器，启动 `server/`，选择并验证 B 板 COM 口，执行真实 B 串口端到端验收。
- 后续把管理端 `src/api/*.ts` 切换为真实 REST，并启用 `/ws/events` 与确认操作页面。
- 将 B 的 32 条 RAM 补传队列升级为 Flash 持久化队列，并将管理端 10 项策略中的范围、时间、次数和方向扩展进正式协议。
