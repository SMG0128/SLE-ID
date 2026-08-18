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

## 5. 结论

项目已达到参赛演示级别：**真实写卡（NV 持久化）+ 真实认证放行 + GPIO 执行 + 后端事件落库**，三端全链路真机验证通过。演示视频可直接按 `COMPETITION_DEMO_HANDOFF_2026-08-18.md` 与本节结果拍摄。
