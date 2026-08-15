# 三端真实联调阶段收尾报告（2026-08-15）

## 1. 本轮结论

本轮已完成真实 Permission 领取、Card C 新固件烧录、HarmonyOS 对 Card C 的真实发现与系统配对验证，并修复了 Card C 广播格式、移动端异步连接竞态和已配对设备重连入口。

当前尚未完成“平板写入 Card C”闭环。阻塞不是虚拟数据或 UI：Card C 在首次系统配对后仍报告 `connected=1`，平板能够从系统已配对设备中找到 `sle_card`，但新的 SSAP Client 会话在 5 秒内没有收到连接完成回调。因此尚未执行 WRITE_BEGIN / WRITE_PERMISSION / WRITE_COMMIT，也没有把写卡标记为成功。

## 2. 已验证事实

### 管理端与平板

- 真实测试许可已由管理端创建并由真实平板领取。
- `permissionId=1`
- `organizationId=100`
- `policyVersion=2`
- 后端数据库存在真实数字卡记录，平板卡包从 0 张变为 1 张。
- 平板显示 `Tablet Card C Ordinary Access`，状态仍为“未写卡”。
- 未使用 Mock 或硬编码卡片。

### Card C 固件

- 当前固件：`D:\SLEID\ws63\outputs\card_c_ws63_nv_provisioning_all.fwpkg`
- SHA-256：`C3AF3CFFE93944BAA07F4B8860A70C1A20EAD368EB5F05AE142C90F50AD207B4`
- 已由用户烧录。
- 串口启动与 NV 存储初始化正常。
- 当前卡片状态：`count=0 generation=0`，证明没有伪造写卡成功。
- Card C 广播名 `sle_card` 已被真实 HarmonyOS 扫描回调识别。
- 系统配对已完成，移动端读到配对状态 `3`（PAIRED）。
- 移动端可通过 `manager.getPairedDevices()` 找回 Card C，不再只依赖广播扫描。

### 移动端构建

- 最新调试 HAP：`D:\SLEID\SLE-ID-App-OH\entry\build\default\outputs\default\entry-default-signed.hap`
- SHA-256：`0CB4C0D98A14603113A2FFE3412FB99D868C371236F0894FDDBAEBBB0FC8F00F`
- Hvigor：BUILD SUCCESSFUL。
- 已真实安装到平板。
- 调试签名与正式 AssetStore 限制维持原方案，本轮未修改证书或正式安全存储体系。

## 3. 本轮代码修改

### 硬件仓库 `D:\SLEID\ws63`

- `17f4d0e`：远程写卡必须先经本地 `write unlock`，60 秒窗口，断连或提交后清除。
- `a2d7990`：在主广播中加入 Card C 名称，兼容 HarmonyOS 扫描。
- `3499959`：按 HarmonyOS SLE 广播要求改为 Type-Length-Value 编码。

### 移动端仓库 `D:\SLEID\SLE-ID-App-OH`

修改文件：`entry/src/main/ets/services/CardCSleAdapter.ets`

- 等待真实 `STATE_CONNECTED` 回调后才发现 SSAP 服务，修复 `connect()` 返回过早的竞态。
- 增加 5 秒连接超时及失败清理，避免挂起 Promise。
- 增加真实 NearLink 配对；人工确认窗口由 8 秒延长到 30 秒。
- 优先复用系统已配对、名称为 `sle_card` 的设备，解决 App 重启后卡片不再广播导致扫描超时的问题。
- 失败后关闭 Client、清空失效地址，并记录不含密钥的阶段日志。
- 只有服务、通知和 CARD_INFO 全部验证后才上报实体卡发现成功。

`build-profile.json5` 是本机调试签名配置，未纳入提交。

## 4. 当前阻塞现场

平板真实日志：

```text
[SLEKEY][CARD-C] using paired Card C
[SLEKEY][CARD-C] pairing check started
[SLEKEY][CARD-C] initial pairing state=3
[SLEKEY][CARD-C] pairing check passed
[SLEKEY][CARD-C] discovery failed: Card C connection timeout
```

Card C 串口真实状态：

```text
[C] card=c0000001 count=0 generation=0 caps=07 connected=1 commands=0 bad=0 dup=0 send_fail=0 crc=0 format=0
```

判断：首次系统配对建立的底层连接尚未释放，Card C 不再发可连接广播，新建 SSAP Client 会话未获得连接完成事件。当前不能据此宣称写卡成功。

## 5. 当前阶段状态矩阵

| 链路 | 状态 | 依据 |
|---|---|---|
| 管理端 → 平板 | PASS | 真实许可领取，卡包 0→1，数据库存在记录 |
| 平板 → Card C | FAIL（阻塞） | 已发现并配对，但 SSAP 重连超时；未写入 |
| Card C → A | 既往 PASS，本轮未回归 | 三板 HMAC 通行测试已有真实日志 |
| A → B | 既往 PASS，本轮未回归 | 双 SLE 与认证消费已有真实日志 |
| B → Backend | 既往 PASS，本轮未回归 | USB 网关与事件中心已有真实日志 |
| Backend → 管理端 | 既往 PASS，本轮未回归 | 事件中心真实展示通过 |
| Backend → Tablet CONFIRM | NOT TESTED | 必须等待普通授权写卡闭环稳定 |
| Tablet → B APPROVE | NOT TESTED | 必须等待 CONFIRM 映射实现和真实待确认事件 |

## 6. 下一阶段执行方案

严格继续以下顺序：

1. 释放 Card C 首次配对残留连接：优先按一次 C 板 Reset；若仍 `connected=1`，拔插 C 板 USB 后复查 `status`。
2. 不解除系统配对，打开 App 的“发现并绑定”。验证依次出现：
   - `using paired Card C`
   - `connection state=STATE_CONNECTED`
   - `services discovered`
   - `response notification enabled`
   - `INFO verified card=CARD-C0000001`
3. 若复位后仍无法建立 SSAP，会保留平板与 Card C 双侧日志，检查 Card C 在 `pair complete` 后是否需要主动释放配对连接；只做最小硬件修复，不降低 INFO/COMMAND/RESPONSE 的加密或认证权限。
4. 真实读卡成功后，在 COM11 执行 `write unlock`，再从平板发起许可写入。
5. 写卡成功必须同时满足：Card C COMMIT ACK、平板 Read Back 匹配、后端写卡同步成功、Card C `count=1 generation>0`。
6. 重启 Card C 后再次读回，确认 NV 持久化；否则判定 FAIL。
7. 接回 A 板，执行普通授权闭环：Card C → A → B → USB → Backend → 管理端。
8. 普通授权稳定后再创建 `requireConfirm` 许可，完成 Backend → Tablet ConfirmRequest → APPROVE/REJECT → B 的 requestId 绑定、过期、重复、错误 ID、掉线和 TIMEOUT 测试。

## 7. 已知风险

- `startPairing()` 的编译提示说明该 API 自 5.1.0(18) 起支持，而项目兼容基线仍为 5.0.1(13)。当前真实平板已能弹出并完成系统配对；暂不修改正式兼容基线。
- 当前调试签名无法使用正式 AssetStore，仍安全回退到内存会话；这是已接受的调试环境限制。
- CONFIRM 业务映射与 B 端 requestId 严格匹配尚未完成，不得提前宣称确认闭环通过。
- 后续日志不得输出真实许可密钥、写卡票据或 HMAC 密钥。
