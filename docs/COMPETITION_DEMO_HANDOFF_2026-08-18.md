# SLE-ID 星随 · 参赛演示版交接说明

更新时间：2026-08-18（Asia/Shanghai）  
用途：本项目定位为**参赛作品**，与真实打卡/门禁场景存在差距；目标是**调试好三端（Detector A / Detector B / Card C）并拍摄可重复演示的视频**。后续开发思路不要求严谨贴近真实环境，以"可稳定、可展示、可讲解"为准。

---

## 1. 项目定位（用户明确要求）

- 本作品用于参赛，视频展示重点：三端真实 SLE 链路 + 卡片认证 + 通行事件 + GPIO 执行。
- **不追求**真实环境要素（真实 Channel Sounding 测距、门区传感器方向判定、生产级写卡授权协议等）作为验收门槛。
- 允许使用 `demo enter` 等模拟观测输入作为**正式演示路径**（区别于之前"demo 不得冒充真实验收"的严格要求）。
- 安全基线仍保留：不输出私钥/Token/签名材料；不把伪造结果写成真实通过；不放开 Card 写鉴权。

## 2. 当前已跑通的演示闭环（真机验证通过）

### 2.1 平板 ↔ Card C（INFO 读取修复）✅

平板真实日志：

```text
[SLEKEY][CARD-C] using live Card C advertisement
[SLEKEY][CARD-C] pairing completed
[SLEKEY][CARD-C] SSAP link connected
[SLEKEY][CARD-C] services discovered=1
[SLEKEY][CARD-C] INFO raw length=38 hex=534C02400201010000C0C3474AE501000000100001080007010000C0000101000000000022C8
[SLEKEY][CARD-C] INFO verified card=CARD-C0000001
```

根因：HarmonyOS `readProperty()` 不触发 SSAP 读请求，直接读服务发现缓存的注册属性值；固件此前把 INFO 注册成 1 字节 `00`。
修复：注册 INFO/STATUS 属性时预填完整 38 字节 Protocol V2 CARD_INFO 帧（静态值方案）。

### 2.2 三端认证 + 通行 + 执行闭环 ✅

真实日志（授权放行路径）：

```text
B: [B] auth verify=1 session=... card=c0000001 permission=7 auth=1 reason=0 counter=2
B: [B] auth consume=1 session=... card=c0000001 permission=7 counter=2
B: [B] actuator ON event=3 pin=10
B: [B] EVENT event=3 card=c0000001 auth=1 ... action=2 confirm=0 exec=2 reason=0
A: [A] auth result session=... card=c0000001 permission=7 auth=1 reason=0 counter=2
A: [A] decision event=3 action=2 confirm=0 exec=2 reason=0
```

关键顺序（演示脚本要点）：**同一流程内** `auth testkey` → `auth start` → 稍候 → `demo enter`，认证成功后的 15 秒一次性通行窗口内触发事件，否则 `auth consume=0`（超时属正常）。

拒绝路径同样验证过：未授权卡得到 `auth=2 exec=0`，GPIO 不动作（可作演示对比）。

## 3. 真实 Channel Sounding 结论（已回滚）

- 尝试：开启 `CONFIG_FEATURE_GLE_HADM`、编写 `a_cs_sampler` 采集 IQ/TOF。
- 结果：SDK 预编译库 `libbth_gle.a` **不含 HADM 实现**（链接报 `undefined reference to 'sle_hadm_register_callbacks'` 等），SDK 无 gle 源码可重编译。
- 处理：按用户选择**已回滚全部 CS 改动**，A/B 重建为基线固件。
- 后续：参赛演示**不接入真实 CS**；需要时用 `demo enter/reverse/timeout` 模拟观测输入驱动状态机。

## 4. 当前固件清单（可用基线）

| 板 | 固件文件 | SHA-256 |
|---|---|---|
| Detector A | `D:\SLEID\ws63\outputs\detector_a_h3863_all.fwpkg` | `E5E4C1989C70184D58D72A9FCD89275732F539F74CE43E006D73DCB2EC0702C5` |
| Detector B | `D:\SLEID\ws63\outputs\detector_b_h3863_all.fwpkg` | `E95DCD7729EB5CAF28341BCCBFAADFF40B8F266B9ECCD3FBF9D89B955D53753B` |
| Card C | `D:\SLEID\ws63\outputs\card_c_ws63_nv_provisioning_all.fwpkg` | `28861C925AA4A4F9792411CDFE2CE4A1BD3A0B34865817411284493B7C718B13` |

- A/B 哈希与 `codexworkspace/docs/H3863_THREE_BOARD_DUAL_SLE_TEST.md` 记录一致。
- Card C 含 INFO 静态预填修复；板上凭证状态：`count=1 generation=4`（permission=7, org=100, credential_version=3, key_version=2, key=0x11×32）。
- 注意：Card C 是单连接设备，A 与平板不能同时占用；演示顺序要错开。

## 5. 演示脚本建议（可重复）

1. 三块板通电，A 自动连接 B 与 Card C；确认 A `status` 输出 `B ... ready=1` 且 `Card ... ready=1`。
2. B 串口发送 `auth testkey`（安装测试凭据，permission=7/org=100/key=TEST-ONLY-11x32）。
3. B 串口发送 `auth start`，随后**立即**（15 秒窗口内）给 A 发送 `demo enter`。
4. 预期日志：B `auth verify=1` → A `auth result ... auth=1` → B `auth consume=1` → B `actuator ON ... pin=10`（GPIO10 脉冲，排针第 34 脚，可用 LED 观察）→ B `EVENT ... auth=1 ... exec=2` → A `decision ... exec=2`。
5. （可选对比）不安装凭据直接 `auth start` + `demo enter`，展示 `auth=2 exec=0` 拒绝路径。
6. 平板演示：拔掉 A 或让 A 断开 Card C，App 内「实体卡 → 发现并绑定」，展示 `INFO verified card=CARD-C0000001`。

串口参数：115200 / 8N1 / 无流控。

## 6. 代码与仓库状态

- 权威工作区：`D:\SLEID`（ws63 / Admin / SLE-ID-App-OH / codexworkspace）。
- 本轮固件改动集中在 `ws63`：`card_ws63/platform/ws63/ws63_card_sle_server.c`（INFO/STATUS 静态预填 + read_by_uuid 回调 + 诊断日志）、`firmware/h3863/sle_card/h3863_sle_card.c`（read_property 兼容 UUID 值）、`tools/install_into_sdk.ps1` 等。
- 已移除误杀 A↔Card 的"配对 30 秒无活动即断开"看门狗。
- git 未在 PATH，提交需手动处理（如需要）。

## 7. 收工注意事项

- 板上 Card C 已有测试凭证（count=1）；如需重置到干净状态，用 `card_serial_tool.ps1` 或重烧。
- 端口号每次重插可能变化（历史：A=COM8、B=COM7、Card=COM14），演示前重新枚举。
- 视频拍摄建议：三个串口终端并行滚动 + GPIO LED 动作 + 平板 App 绑定界面，一次拍完认证→通行→执行→平板四段。
