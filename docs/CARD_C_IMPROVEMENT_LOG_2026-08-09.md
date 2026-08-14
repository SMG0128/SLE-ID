# Card C 完善日志（2026-08-09）

## 本轮完成

- 认证成功前先原子提交 `usageCount`，存储写入或回读校验失败时返回 `INTERNAL`，不签发成功证明。
- 完全相同的认证挑战命中会话缓存时只重发原响应，不重复扣次数。
- 缓存响应重放前重新核对凭证当前状态、凭证版本和密钥版本；冻结、挂失、撤销或换钥后，旧的成功证明立即失效。
- 新增次数跨重启恢复、写失败回退和次数耗尽的测试用例源码。
- 写卡结果缓存新增请求内容指纹；相同 `requestId` 携带不同凭证或不同状态时返回 `REQUEST_MISMATCH`，不再误重放旧成功结果。
- CARD_INFO 新增能力位，串口 `status` 增加 `caps`、认证次数提交数、存储失败数和认证响应发送失败数。
- Card 固件版本已提升为 `0x00010100`，RAM、NV 个性化和 NV 锁定三种配置均已按该版本完成官方 SDK 构建。
- WS63 平台组件补齐 `card_crypto.c` 与 `card_auth.c`，避免单独复用平台 CMake 时漏编认证核心。
- Card SLE 读写、配对完成和断开回调现在校验当前 `connId`，旧连接的延迟回调不会把新连接误标为已配对或清除其状态；CCCD 写入会得到明确响应，失败配对不再打印 `service ready`，空读值也不会被误报为成功。

## WS63 NV 结论

当前官方 SDK 文件 `middleware/chips/ws63/nv/include/nv_config.h` 定义普通 NV 单项最大 4060 字节，Card 双槽单槽为 768 字节，容量满足要求。`key_id.h` 将 `0x5000-0xFFFE` 定义为用户普通区，SDK 示例也直接在该区使用运行时 key。

项目保留 `0x5C00-0x5CFF` 作为 Card C 命名空间，默认双槽为：

```text
slot A = 0x5C10
slot B = 0x5C11
```

适配层会拒绝范围外 key、相同 key 和非 768 字节读写，并在编译期检查槽尺寸不超过 SDK 限制。当前 SDK 源码中未发现 `0x5C10/0x5C11` 的既有使用；如果以后更换 SDK 版本，仍需重新执行冲突核查。

新增的 `tools/check_card_nv_keys.ps1` 会在持久化构建前检查 SDK 容量宏、用户区起点以及两个 key 在非 Card 源码中的精确冲突；发现变化时构建会直接停止，要求人工重新分配。

## 固件构建流程

`tools/rebuild_card_nv_release.ps1` 已完成实现并在官方 SDK 中实际执行：

```powershell
# 首次个性化：包含 NV 分区，保留本地串口写卡
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\rebuild_card_nv_release.ps1 `
  -SdkRoot D:\hispark\sdk\fbb_ws63\src

# 个性化完成后的部署锁定：关闭串口写卡，仅打包 loader + app，不覆盖 NV 分区
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\rebuild_card_nv_release.ps1 `
  -SdkRoot D:\hispark\sdk\fbb_ws63\src -ProductionLockdown
```

首次个性化包使用 SDK 的 `all.fwpkg`；部署锁定包使用 `load_only.fwpkg`，这是为了避免第二次烧录时由全量包重写 NV 区。锁定包只适用于已经完成个性化、且板上已有有效基础固件的设备。

构建过程中发现锁定配置关闭串口个性化后，十六进制解析函数会成为未使用函数并被 SDK 的 `-Werror` 拒绝。现已将解析函数纳入相同条件编译范围，主机回归通过，锁定版重新全量构建成功。

## 已完成验证

- 全套主机测试通过：A/B Protocol V2、Card 存储与服务、HMAC、防重放、B↔Card 互操作、A 中继、B 单 USB 网关、串口 DryRun 和管理端映射。
- NV 分配核查通过：用户区、单项容量、`0x5C10/0x5C11` 冲突和 768 字节槽长均符合当前 SDK。
- RAM、NV 个性化和 NV 锁定配置均已同步到官方 SDK，并完成编译、链接、签名与打包。
- NV 个性化包：`outputs/card_c_ws63_nv_provisioning_all.fwpkg`，SHA256 `9153D8374837ACEBAC9EA9DB79315583B16007F33672C3C2F02CA21408FFBE1F`。
- NV 锁定包：`outputs/card_c_ws63_nv_locked_load_only.fwpkg`，SHA256 `5421DAD234AF71293C3EBCCDBA5A2D8F5950B671081E15181551D83C95286113`。
- RAM 联调包：`outputs/card_c_h3863_ram_all.fwpkg`，SHA256 `1ED0AED1CBF0F45468FA28D03C82B951031F1E20DE10C4C1048E71B942830B89`。

## 仍需实体板验证

- 未在第三块 WS63/H3863 板上验证 NV 跨复位恢复、掉电故障注入和写入寿命。
- 未在第三块板上验证 Card 广播、服务发现、配对、CCCD 通知以及真实分片写卡/读回。
- 未完成 A 同时维持 B/Card 两条真实 SLE 连接的整链路替换；当前三端认证仍可先用串口桥阶段验证。
