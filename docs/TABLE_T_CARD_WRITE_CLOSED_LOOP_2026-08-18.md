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

1. ~~**三端认证回归**~~ ✅ **已完成并通过**（见下节）

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

## 7. 三端认证放行回归（2026-08-18 完成 ✅）在写卡闭环完成后，为让 B 与 Card C（permission=1 真实凭证）配对认证，给 Detector B 固件新增两条命令（ws63 提交 `e2b01e5`）：

- `auth key <64位hex>`：从本地串口安装与 Card C 写卡载荷完全一致的凭据（permission=1, org=100, card=c0000001, credential_version=2, key_version=1, 真实密钥），密钥不写入代码/Git；
- `auth start [<unix-seconds>]`：认证挑战携带真实 Unix 时间（Card C 凭证有 2026-08-15..2026-12-31 有效窗口；B 无 RTC，由调用方传入）。

真机回归结果（与 8/18 文档演示脚本一致）：

```text
B: [B] auth verify=1 session=5b188ea4 card=c0000001 permission=1 auth=1 reason=0 counter=1
B: [B] auth challenge=1 success=1 consumed=1
A: [A] decision event=4 action=2 confirm=0 exec=2 reason=0
C: [C] auth rx=4 ok=1 commits=1 generation=2
B: 后端事件 EV-A0000001-EED49484-0000000004  card=CARD-C0000001  成功  执行/无需确认/执行成功 reason=0
```

要点：
- 认证**放行**路径真实跑通：Card C 真实验证 → A 转发 → B 用真实密钥放行 → GPIO10 执行 → 事件落库；
- 拒绝路径同样真实验证（测试密钥 vs 真实凭证 → `auth=2 deny=3`；模拟卡 a9000001 → reason=1），与 8/17 文档一致；
- Card C `generation 1→2` 为使用计数提交（auth commits=1），凭证本体未变；
- 唯一事件键 `EV-A0000001-EED49484-0000000004`（sourceId+bootId+eventId），符合唯一性要求。

## 8. 平板绑定状态显示修复（2026-08-18 ✅）

端到端测试发现平板主页卡片显示"未写卡"，但后端 `sync_status=synced`、Card C 已真实写入。

- 根因：后端 mobile API 返回 `credentialBindingStatus: 'active'`，而 App 的 `CredentialBindingStatus` 枚举仅含 `'notWritten' | 'writing' | 'verifying' | 'written' | 'writeFailed'`——`'active'` 不匹配任何枚举，UI 判定失败走"未写卡"分支。
- 修复：Admin `7bd0a00`，后端 `mobile.ts` 改为 `cardWritten ? 'written' : 'notWritten'`，与 App 枚举对齐。
- 验证：API 返回 `written`；平板 UI 主页卡片显示 **"已写入"**。
