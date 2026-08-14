# H3863 A/B Protocol V2 实机测试报告

测试日期：2026-08-08  
测试设备：两块小熊派 H3863，分别运行 Detector A 与 Detector B  
测试链路：真实 SLE Client/Server + 双 USB 串口

> 历史基线说明：本报告绑定的是表中 2026-08-08 固件，仅证明当时版本的实机结果。当前安全版 A/B 固件哈希分别为 `4D7C53AF80C1DE6658366754DCB08546C962E42507EE79B2623AA57A9186EAFE` 和 `313465EA326CC9720DF17130EC1A1F6777F683DA8ADB58E41846C3EC5B6E1038`，事件负载已从 18 字节扩展到 30 字节，必须同时升级并重新做冒烟测试；在完成前不得把本报告视为新固件的真板验收记录。

## 固件

| 角色 | 文件 | SHA256 |
|---|---|---|
| Detector A | `detector_a_h3863_all.fwpkg` | `14E93EE5D80CCFAF2B3A51C1E14F053C748BFE8B45FCCED7A18CF02A5B9E9426` |
| Detector B | `detector_b_h3863_all.fwpkg` | `715023815E459EF7954834A687CAEC118BB9706FBAEC00691F988D5BCCEE6B6F` |

## 实机结果

| 测试项 | 关键证据 | 结果 |
|---|---|---|
| 正常事件、决策和执行 | A `sent=1 ack=1 pending=0`；B `rx=1 dup=0`；决策 `action=2 exec=2 reason=0` | 通过 |
| 协议健康状态 | B `bad=0 ack_fail=0 decision_fail=0 crc=0` | 通过 |
| A 重启后事件 ID 复用 | A 重启并重新出现 `bridge ready` 后，新的 `event=1` 被 B 作为新事件接收，未记为 duplicate | 通过 |
| 确认超时保护 | 等待超过 10 秒后返回 `reason=15`，迟到的 `confirm yes` 不执行 GPIO | 通过 |
| pending 防覆盖 | 新事件返回 `reason=20 (BUSY)`；B 累计 `busy=6`，旧 pending 未被覆盖 | 通过 |
| 断线重试上限 | B 断电期间 A 重试 3 次后进入 exhausted，不无限发送 | 通过 |
| 重连恢复 | B 恢复并出现 `bridge ready` 后，A 新事件重新获得 ACK，B 正常执行 | 通过 |

主机故障注入测试另外覆盖了 CRC 错误后的重新同步、错误版本帧、非连续重复事件、B 决策发送失败、Card 双槽写失败和损坏恢复。

## 判定

Detector A/B Protocol V2 双板实机验收通过。当前结果证明 A/B 通信、ACK、有限重试、复合事件键、确认保护和断线恢复有效；不代表 Card C、真实 HMAC 认证、Channel Sounding、USB 正式后端协议或执行器反馈闭环已经完成。
