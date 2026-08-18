# SLE-ID 星随 · 端到端测试结果（2026-08-18 硬件段+平板端+管理端）

测试时间：2026-08-18 15:00-15:40（Asia/Shanghai）
测试方式：真实硬件 + 真机平板 + 真实后端，全链路实测
结果：**三端（硬件/平板/管理端）端到端测试全部通过**

## 1. 测试环境

| 组件 | 标识 | 状态 |
|---|---|---|
| Detector A | COM8，`detector_a_h3863_all.fwpkg`（SHA `E5E4C198...`） | `[A] boot source=a0000001 protocol=2`；B/Card 链路 ready |
| Detector B | COM6，`detector_b_h3863_all.fwpkg`（SHA `9FA16455...`） | 后端 `detectorBReady=True`；含 `auth key`/`auth start [time]` 命令 |
| Card C | COM14，`card_c_ws63_nv_provisioning_all.fwpkg`（SHA `536E51CA...`） | `count=1 generation=2`（写卡后 + 认证计数后），NV 持久化 |
| 平板 | HDC `5TVUN25B20G01816`，SleKey 4.12.0 | 配对/刷新正常，卡片显示"已写入" |
| 后端 | `0.0.0.0:8080`，SQLite | REST/WS/B 网关正常，管理前端 HTTP 200 |

## 2. 测试结果

### 2.1 硬件段：三端认证放行（✅）

真实日志（本次实测）：

```text
B: [B] auth provisioned credential installed=1 permission=1 org=100 card=c0000001 version=2 key_version=1
B: [B] auth start=1 sent=1 reason=0 time=1787066990
B: [B] auth verify=1 session=f09839cc card=c0000001 permission=1 auth=1 reason=0 counter=2
A: [A] decision event=5 action=2 confirm=0 exec=2 reason=0
C: [C] auth rx=4 ok=1 commits=1 generation=2
```

- 认证放行：`auth verify=1 → auth=1 → consume=1 → GPIO exec=2`
- 拒绝路径（此前验证）：测试密钥 vs 真实凭证 → `auth=2 deny=3`；模拟卡 `a9000001` → `reason=1`（均符合预期）

### 2.2 平板端（✅）

- 配对成功、钱包刷新完成、卡片 `credentialBindingStatus=written`、`physicalCardId=CARD-C0000001`
- 主页卡片显示 **"已写入"**（修复 `Admin 7bd0a00` 后）

### 2.3 管理端（✅）

- 事件落库：`EV-A0000001-EED49484-0000000005` CARD-C0000001 **成功/执行/执行成功 reason=0**（15:30:08 实时入库）
- 审计完整：`card.write.issued` → `card.write.verified`（generation=1）→ `policy.deploy` → `mobile.pair`
- 管理前端 `http://127.0.0.1:8080/` 正常服务

## 3. 完整闭环链路（本次测试跑通）

```text
管理端签发写卡包 → 平板写卡到 Card C（NV 持久化，断电保持）
→ Card C 持真实凭证 permission=1
→ B 安装同密钥（auth key）+ 真实时间认证（auth start <unix>）
→ A 触发通行（demo enter）
→ B auth verify=1 放行 → GPIO10 执行 → EVENT auth=1 exec=2
→ B USB 上报 → 后端事件落库 → 管理端可见
```

## 4. 本次相关代码提交

| 仓库 | 提交 | 内容 |
|---|---|---|
| ws63 | `dc7568d` | Card C：LIST 只读校验放行（COMMIT 后 readback 可用） |
| ws63 | `e2b01e5` | Detector B：`auth key <hex>` + `auth start [<unix秒>]`（真实凭据/时间认证） |
| Admin | `03ab592` | 移动端卡片偏好 PATCH 路由 |
| Admin | `7bd0a00` | 卡片绑定状态值与 App 枚举对齐（`written`） |
| codexworkspace | `63132a4` `30c11f7` `aaf22eb` `96098be` | 联调/认证/修复文档 |

## 5. 二次确认闭环（补测：18:30-18:41 本地时间，✅ 全链路打通）

任务书演示链路 C（无感接近 → 认证 → 二次确认 → 管理端/平板决策 → B 执行）补充验证。

### 5.1 关键修复验证：确认超时 60s（✅）

此前 B 板上报确认超时（reason=15）与确认请求**同秒**——疑似 10s 超时固件问题。重烧 B 板为 60s 版（`detector_b_h3863_all.fwpkg` SHA `FE351770...`，`DETECTOR_B_CONFIRM_TIMEOUT_MS=60000`）后实测：

| 事件 | 帧/时间 (UTC) | 说明 |
|---|---|---|
| 事件 ev=200 首次上报 | mid=250 type=98 @ 10:32:57.747 | auth=1 认证通过 |
| CONFIRM_REQUEST 入库 | mid=251 type=100 @ 10:32:57.776 | 确认请求 `CF-B0000001-A4D79613-1` pending |
| 窗口内新事件 | ev=201~205 @ 10:33:06~10:33:52 | B 回 `reason=20 BUSY`（确认 pending 期间的正常拒绝） |
| **事件 ev=200 二次上报（超时）** | mid=316 type=98 @ **10:33:57.763** | `confirm=4 reason=15`，**恰好在确认请求后 60.0s** |

→ **60s 版固件生效**：B 板精确等待 60s 才上报确认超时，不再同秒超时。旧问题已解决。

### 5.2 完整二次确认闭环（✅ 决策→执行成功）

实测链路（B 板 boot `2765592083`，A 板 boot `EEE3C188`）：

| 环节 | 时间 (UTC) | 结果 |
|---|---|---|
| 事件 ev=247 上报 | 10:40:08.680 | `auth=1`（真实凭证 permission=1，counter=15） |
| CONFIRM_REQUEST 入库 | 10:40:08.708 | `CF-B0000001-A4D79613-2` pending，exp 10:41:08.708（60s 窗口） |
| 决策 approve | 10:40:34.483 | API `POST /api/confirmations/:id/decision`（窗口内 26s） |
| 后端 sendCommand ConfirmResult | 10:40:34.507 | `device_commands`: type=101(ConfirmResult), **status=success, result_code=0** |
| B 板执行成功上报 | 10:40:34.547 | ev=247 更新：`action=2 confirm=2(已批准) execution=2(执行成功) reason=0 result=成功` |
| 确认请求 resolved | 10:40:34.543 | `state=resolved decision=approve` |

审计：`confirmation.decision.requested` → `confirmation.decision.completed`（op=admin，10:40:34）。

→ **决策命令 → B 板 GPIO 执行 → 后端事件更新** 整条链路打通。此次决策由自动监控脚本在 60s 窗口内发出（等效管理端/平板 approve 动作）；平板端 UI 决策路径此前已实现（滑动确认弹窗），可在演示时用平板实机操作复现同一链路。

### 5.3 平板端真实决策闭环（补测：23:17 本地时间，✅ 实机操作成功）

此前平板端确认推送一直不通，排查定位到两个后端缺陷并修复：

| 缺陷 | 现象 | 修复 |
|---|---|---|
| **mobile session 不持久化** | 后端每次重启清空内存 session，平板 token 失效 → WS 401 拒绝 → 确认推送永远到不了平板 | `MobileSessionStore` 增加 SQLite 持久化（`mobile_sessions` 表，V6 迁移），重启后恢复 |
| **double-claim bug** | 平板决策路由先 `claimConfirmation` 再调 `decideConfirmation`（内部又 claim 一次）→ 第二次失败 409 → 确认请求卡 `sending`、命令从未发送、平板"划到最右边没反应" | `mobile.ts` 去掉路由内重复 claim，直接调用 `hardware.decideConfirmation` |

**实机操作完整闭环**（真平板滑动确认，op=`mobile:5TVUN25B20G01816`）：

| 环节 | 时间 (UTC) | 结果 |
|---|---|---|
| 事件 ev=373 上报 | 15:17:15.746 | `auth=1` 认证通过（真实凭证 counter=21） |
| CONFIRM_REQUEST 入库 | 15:17:15.775 | `CF-B0000001-A4D79613-8` pending，60s 窗口 |
| **平板滑动确认 approve** | 15:17:34.173 | audit `confirmation.decision.requested` op=mobile |
| ConfirmResult 命令 | 15:17:34.175→208 | `device_commands` status=success result_code=0 |
| B 板执行成功上报 | 15:17:34.217 | ev=373 更新 `confirm=2(已批准) execution=2(执行成功) result=成功` |
| 确认请求结案 | 15:17:34.213 | `state=resolved decision=approve` |

→ **平板 App 推送 → 滑动确认 → 后端决策 → B 板 GPIO 执行 → 事件落库** 全链路实机打通，`confirmation.decision.completed` 审计由平板身份（op=mobile:5TVUN25B20G01816）产生。

### 5.4 requestId 响应格式修复与平板端显示成功（补测：23:24 本地时间，✅ 平板 UI 显示成功）

**遗留问题**：-8 后端执行成功但平板 App 显示失败。定位：`MobileApiClient.decideConfirmation` 校验
`response.result.request.requestId === 传入的完整确认ID`，而后端返回的是命令数字 requestId（`8` vs `CF-...-8`）→ 校验失败 → App 抛 "Confirmation decision lacks backend acknowledgement" → 前端显示失败。

**修复**：`mobile.ts` 决策响应 `request.requestId` 改为返回完整确认 ID（`confirmationId`）。

**修复后实机复测（确认请求 -9，平板 UI 显示成功 ✅）**：

| 环节 | 时间 (UTC) | 结果 |
|---|---|---|
| 事件 ev=423 上报 | 15:24:39.587 | `auth=1` 认证通过（counter=22） |
| CONFIRM_REQUEST 入库 | 15:24:39.615 | `CF-B0000001-A4D79613-9` pending，60s 窗口 |
| 平板滑动确认 approve | 15:24:55.162 | audit op=mobile:5TVUN25B20G01816 |
| ConfirmResult 命令 | 15:24:55.198 | `device_commands` status=success result_code=0 |
| B 板执行成功上报 | 15:24:55.200 | ev=423 更新 `confirm=2(已批准) execution=2(执行成功) result=成功` |
| 确认请求结案 | 15:24:55.199 | `state=resolved decision=approve`，**平板 UI 显示"后端已确认本次决定"** |

→ **平板端二次确认 UI 显示成功**，16 秒闭环。至此平板端二次确认链路（推送→弹窗→滑动→后端→B 板→落库→UI 反馈）全部实机验证通过。

## 6. 结论

项目已达到参赛演示级别：**真实写卡（NV 持久化）+ 真实认证放行 + 二次确认决策 + GPIO 执行 + 后端事件落库**，三端全链路真机验证通过。演示视频可直接按 `COMPETITION_DEMO_HANDOFF_2026-08-18.md` 与本节结果拍摄。
