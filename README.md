# SLE 无感项目：H3863 Detector A/B + WS63 Card C

这是面向两块小熊派 H3863 的硬件端第一版工程。

- Detector A：模拟卡片认证和通行区域观测，通过状态机生成完整通行事件，作为 SLE Client 发送给 B。
- Detector B：作为 SLE Server 接收事件，执行策略、管理员确认和 GPIO 动作，并将决定返回 A。
- A/B 之间使用真实 SLE 链路；卡片和 Channel Sounding 输入目前由 A 端串口命令模拟。

## 当前完成状态

- Protocol V2 帧头、CRC16、流式解析、ACK 与 A 端超时重试
- B 端按 `sourceId + bootId + eventId` 保存最近 32 个事件键，避免重复执行
- A 端通行状态机：正向通过、反向取消、超时取消、冷却去重
- B 端：记录、直接执行、确认后执行、拒绝、密钥失败和重放告警
- B 端 GPIO10 高电平动作脉冲（500 ms，排针物理第 34 脚）
- H3863 官方 SDK SLE UART Client/Server 适配
- 主机单元测试
- Detector A 和 Detector B 两份可烧录全量固件
- Card C 凭证与写卡核心：8 项许可、CRC32、双 NV 槽原子提交、分片事务、requestId 幂等和掉电恢复测试
- Card C 认证核心：HMAC-SHA-256 签名挑战/响应、许可检查、会话幂等和 RAM 防重放
- Detector B 认证权威核心：TRNG 会话/nonce、签名挑战、Card 响应验签、计数器/版本/状态/有效期校验
- Detector A 认证中继核心：按会话转发挑战、响应和最终结果，拒绝篡改、超时及冲突重复帧
- HMAC 成功结果与下一条通行事件一次性绑定，由 B 精确匹配并消费；A 本地模拟命令不能绕过
- 认证挑战/响应和通行决定支持丢包重传，重复事件不会重复驱动执行器
- B 单 USB Protocol V2 网关：1 秒心跳、策略同步、事件/报警/确认上报、ACK 重试和 32 条 RAM 队列
- 管理端兼容映射与串口参考工具：`tools/admin_gateway_compat.ps1`
- Card 凭证版本/密钥版本/计数防回滚，同一 requestId 跨命令冲突拒绝
- Card 管理命令当前仅开放给本机串口 Host；远端 SLE 只接受 A 的认证挑战和只读特征
- Card C 独立 SLE 四特征固件已通过官方 SDK 编译；当前交付为复位清空凭证的 RAM 安全联调版
- A/B/Card 密码学核心的端到端主机互操作测试；另提供 A↔Card 串口桥三板阶段联调工具

## 目录

- `common/`：消息协议、类型和公共逻辑
- `detector_a/`：A 端状态机与业务核心
- `detector_b/`：B 端策略、确认与执行核心
- `card_ws63/`：Card C 数据模型、凭证双槽存储和 WS63 NV 适配
- `firmware/h3863/`：H3863 SDK 接入、Kconfig 和 CMake 文件
- `tools/install_into_sdk.ps1`：安装到官方 SDK 的脚本
- `tools/card_serial_tool.ps1`：Card C 本地串口写卡、查询和状态维护工具
- `tools/ab_security_smoke.ps1`：双串口自动识别 A/B，验证未绑定授权拒绝和 GPIO 不动作
- `tools/admin_gateway_compat.ps1`：B USB 二进制网关监听、策略/确认命令和管理端字段映射
- `tests/`：PC 端单元测试
- `docs/`：架构、消息契约和双板测试说明
- `outputs/`：最终固件和交付包

## 快速开始

直接使用已经编译好的固件：

- `outputs/detector_a_h3863_all.fwpkg`
- `outputs/detector_b_h3863_all.fwpkg`
- `outputs/card_c_h3863_ram_all.fwpkg`（第三块板联调用，复位清空凭证）

完整烧录、接线和测试步骤见 `docs/H3863_A_B_双板测试指南.md`。
第三块板的阶段认证验收见 `docs/H3863_THREE_PARTY_AUTH_SERIAL_BRIDGE_TEST.md`。

## 重新安装到 SDK

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install_into_sdk.ps1 `
  -SdkRoot D:\hispark\sdk\fbb_ws63\src
```

安装位置：

```text
D:\hispark\sdk\fbb_ws63\src\application\samples\custom\sle_ab
```

## 主机测试

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_tests.ps1
```

通过标志：

```text
All SLE A/B protocol V2 and core tests passed.
All WS63 Card credential store and service tests passed.
All Card HMAC-SHA256 authentication and replay tests passed.
All B authority and Card authentication interoperability tests passed.
All Detector A authentication relay tests passed.
All Detector B single-USB gateway tests passed.
All Card serial provisioning tool dry-run tests passed.
Admin gateway compatibility mapping self-test passed.
```

## 硬件结论

两块 H3863 已足够继续验证 Detector A/B 和真实 SLE 通信。Card、B 权威端和 A 中继端的认证核心均已实现并通过互操作测试，三份固件也已通过官方 SDK 构建。第三块板到位后可先按 `docs/H3863_THREE_PARTY_AUTH_SERIAL_BRIDGE_TEST.md` 验证三端 HMAC；真正的 A↔B 与 A↔Card 双 SLE 并发连接、持久化 NV、Channel Sounding 和功耗仍需继续开发及真板验收。
