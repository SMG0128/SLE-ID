# H3863 Card C SDK 构建报告

构建日期：2026-08-09  
SDK：`D:\hispark\sdk\fbb_ws63\src`  
目标：`ws63-liteos-app`  
配置：RAM 联调、NV 个性化、NV 生产锁定

## 结果

官方 SDK 已完成编译、签名和打包，最终日志包含：

```text
Build target:ws63_liteos_app success
packet success!
```

交付固件：

- `outputs/card_c_h3863_ram_all.fwpkg`：`1ED0AED1CBF0F45468FA28D03C82B951031F1E20DE10C4C1048E71B942830B89`
- `outputs/card_c_ws63_nv_provisioning_all.fwpkg`：`9153D8374837ACEBAC9EA9DB79315583B16007F33672C3C2F02CA21408FFBE1F`
- `outputs/card_c_ws63_nv_locked_load_only.fwpkg`：`5421DAD234AF71293C3EBCCDBA5A2D8F5950B671081E15181551D83C95286113`

三种配置均使用固件版本 `0x00010100`。NV 双槽为 768 字节，key 为 `0x5C10/0x5C11`；个性化版开启本地串口写卡，锁定版关闭该入口且只交付不覆盖 NV 区的 `load_only` 包。

## 已编入能力

- 独立 Card C 应用入口，不与 Detector A/B 共用角色宏；
- SLE Card 服务 UUID `0x2C00`；
- INFO `0x2C01`、COMMAND `0x2C02`、RESPONSE `0x2C03`、STATUS `0x2C04`；
- Protocol V2 流式解析和 CRC16；
- 分片写卡、CRC32、双槽存储接口、状态修改、摘要列表和 requestId 幂等；
- INFO、COMMAND、RESPONSE、STATUS 在配对完成后才允许业务读写或通知；
- 每次启动生成新的随机广播地址，不在广播中暴露固定 Card ID；
- SLE 写回调入队，NV/业务处理在 Card 任务中执行；
- 断线时终止未完成事务并重新广播。
- 本地 UART0（GPIO17/18，115200）Protocol V2 维护入口；RAM 联调配置启用，NV/生产配置默认关闭；
- 配套 `tools/card_serial_tool.ps1` 支持查询、列表、分片写卡和许可状态修改。
- Card 侧 `AUTH_CHALLENGE/RESPONSE` HMAC-SHA-256 核心、许可校验、会话幂等与 RAM 防重放。
- 凭证版本、密钥版本和使用计数防回滚；相同版本只允许完全一致的幂等写入；
- 同一 requestId 换用不同命令类型时拒绝；
- 管理命令仅允许本机串口 Host，远端 SLE 只接受 Detector A 的认证挑战及只读特征。

## 安全说明

RAM 固件用于无持久化的服务发现、协议和写卡联调，复位会清空凭证。正式部署使用 NV 个性化包完成首次写卡，随后使用锁定 `load_only` 包更新应用，避免覆盖已写入的 NV 区。

## 尚待真板验证

- 第三块板广播名 `sle_card` 可被发现；
- 配对后四个特征和 UUID 正确；
- 分片写入、读回、重复提交及错误 CRC 行为；
- 断线/复位后的 RAM 清空行为；
- 正式 NV key 预留后的双槽掉电恢复。
