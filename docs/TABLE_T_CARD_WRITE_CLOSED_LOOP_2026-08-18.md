# SLE-ID 星随 · 平板真实写卡闭环联调记录（2026-08-18 续）

更新时间：2026-08-18（Asia/Shanghai）
本篇在 `COMPETITION_DEMO_HANDOFF_2026-08-18.md` 基础上，记录"平板真实写卡"闭环的联调进展、根因与修复。

## 1. 重大进展：平板真实写卡事务已真实执行并写入 NV ✅

通过 hdc 模拟点击平板 App（SleKey 4.12.0），完整走通写卡发现链路：

```text
[SLEKEY][CARD-C] using live Card C advertisement
[SLEKEY][CARD-C] pairing check started
[SLEKEY][CARD-C] pairing completed
[SLEKEY][CARD-C] pairing check passed
[SLEKEY][CARD-C] connection state=1
[SLEKEY][CARD-C] SSAP link connected
[SLEKEY][CARD-C] services discovered=1
[SLEKEY][CARD-C] property=...2C01 operation=1 descriptors=0
[SLEKEY][CARD-C] property=...2C02 operation=4 descriptors=0
[SLEKEY][CARD-C] property=...2C03 operation=9 descriptors=1
[SLEKEY][CARD-C] property=...2C04 operation=9 descriptors=1
[SLEKEY][CARD-C] response notification enabled attempt=2
[SLEKEY][CARD-C] INFO raw length=38 hex=534C02400201010000C05CFEC49901000000100001080107010000C0000101000400000015DD
[SLEKEY][CARD-C] INFO verified card=CARD-C0000001
```

**Card C 串口状态确认写卡已提交 NV：**

```text
[C] card=c0000001 count=2 generation=5   ← 写卡前 count=1 generation=4
```

即平板发起的 WRITE_BEGIN/CHUNK/COMMIT 事务**已真实执行**，新凭证（permission=1, policy_v2）已 upsert 进 Card C 的 NV 持久化存储，`count 1→2`、`generation 4→5`。

## 2. 遗留问题与根因：COMMIT 后 readback 校验失败

- 现象：App 显示"写后校验失败，可以重新尝试"；Card C `bad=3`（LIST 命令被拒）。
- 根因（固件 `firmware/h3863/sle_card/h3863_sle_card.c` 的 `frame_received()`）：
  - COMMIT 成功后立即执行 `g_remote_write_until_ms = 0U` **关闭写窗口**；
  - 平板随后为读回校验发送 `AB_MSG_CREDENTIAL_LIST`（只读），但窗口已关，命令被拒（`bad++`），App 拿不到 readback → 判定 READBACK_MISMATCH。
- 说明：**写卡本身成功**，只是校验命令被窗口门禁误伤。

## 3. 已完成的修复（均已本地提交）

| 仓库 | 提交 | 内容 |
|---|---|---|
| `ws63` | `dc7568d` | `frame_received()`：LIST（与 INFO）为只读校验命令，连接建立后**不受写窗口限制**，COMMIT 后仍可执行 readback |
| `Admin` | `03ab592` | 新增 `PATCH /api/mobile/cards/:id/preferences` 路由（App 有 `updateCardPreferences`，后端此前缺失导致历史 pendingMutations 重放 401 → 清会话 → App 离线） |

后端修复的完整影响：App 缓存中的 4 条历史 `preferences` pendingMutations（8/15~8/17 遗留）重放成功后即清除，App 恢复在线（UI 由"当前离线，正在显示本地缓存"恢复为"1 张已启用"）。

## 4. 烧录完成 → 写卡闭环重测通过 ✅

- 新固件已由用户烧录至 Card C（COM14）：`card_c_ws63_nv_provisioning_all.fwpkg`
  - SHA-256：`536E51CAE537C3CCDA027BE690DC97B406AD0732F4AF02D13FB4823940E1A580`
  - 烧录后 NV 清零，`count=0 generation=0`，干净起点。
- 平板写卡重测**完整通过**，UI 显示：

  ```text
  凭证写入并校验成功
  写入、校验与同步已完成
  ```

- Card C 串口最终状态：

  ```text
  [C] card=c0000001 count=1 generation=1 commands=5 bad=0 dup=0 send_fail=0 crc=0 format=0
  ```

  - `count 0→1`、`generation 0→1`：permission=1 凭证已 upsert 进 NV；
  - `commands=5`：BEGIN + CHUNK×2 + COMMIT + LIST 全部处理；
  - `bad=0 crc=0 format=0`：**readback LIST 校验成功**（对比修复前 `bad=3`）。
- 后端审计确认闭环落库：

  ```text
  card.write.issued    DC-33E83A56  06:13:44  （签发 request_id=10 写卡包）
  card.write.verified  DC-33E83A56  06:13:56  （回执确认，generation=1，receipt_at 记录）
  ```

  即完整链路：**后端签发 → 平板 SLE 事务写卡 → Card C 提交 NV → 平板 readback 校验 → 后端回执落库** 已真实闭环。

### 待办（仅剩一项验证）

1. **三端认证回归**：接回 A（COM8）后执行 A-B-C 认证链路（`auth verify=1 → auth=1 → consume=1`），确认新固件未破坏既有认证。

### 已确认：断电重启 NV 持久化 ✅

Card C 断电重启后 `status` 结果：

```text
[C] card=c0000001 count=1 generation=1 commands=0 bad=0 crc=0 format=0
```

- `count=1 generation=1` **保持**（NV 持久化成功，重启未丢失凭证）；
- `commands` 归零（确认确实重启过）；
- `bad/crc/format` 全 0。

符合 8/17 交接文档阶段 D 完成标准："断电重启 C，再次 status，确认 NV 持久化后 count=1 仍存在"。

## 5. 环境快照（联调现场）

- 后端：`0.0.0.0:8080`（STARFOLLOW_API_TOKEN 与配对码为一次性生成，未入库）
- Detector B：COM7，`connected=True detectorBReady=True`
- Card C：COM14，115200 8N1
- 平板：HDC `5TVUN25B20G01816`，SleKey 4.12.0，卡片 `DC-33E83A56`（permission=1）状态"已写入实体卡"
- 四个仓库本地提交均领先 origin（未推送，网络/凭据受限，见 BACKUP_2026-08-18）

## 6. 安全与红线（重申）

- 不提交/输出签名材料与密钥；`build-profile.json5` 保持 skip-worktree 保护。
- 烧录只动 COM14；写卡仍走 `write unlock` 60 秒本地授权窗口，未放开 Card 写鉴权。
- 断电重启验证是最终判据：必须看到 `count` 保持而非 RAM 清零。
