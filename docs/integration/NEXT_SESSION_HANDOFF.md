# 星随 / SLE-ID 后续完善与新对话交接方案

更新时间：2026-08-15（Asia/Shanghai）  
用途：把当前开发状态完整移交给新的 Codex 对话，使其从现有基线继续开发，而不是重新设计或重复已经通过的硬件联调。

## 0. 新对话必须先读

权威开发根目录：`D:\SLEID`

| 模块 | 权威目录 | Git 分支 | 当前提交 | 远程关系 |
|---|---|---|---|---|
| 硬件端 | `D:\SLEID\ws63` | `ws63` | `939d81e` | 比 `origin/ws63` 领先 1 |
| 管理端 | `D:\SLEID\Admin` | `Admin-Backend` | `e6434e8` | 比 `origin/Admin-Backend` 领先 1 |
| 平板端 | `D:\SLEID\APPOH` | `App-OH` | `71f72fc` | 比 `origin/App-OH` 领先 1 |
| 联调资料 | `D:\SLEID\codexworkspace` | `integration-workspace` | `a95ecd2` | 本地新分支，远程尚无同名分支 |

统一远程：`https://github.com/SMG0128/SLE-ID.git`

VS Code 入口：`D:\SLEID\SLE-ID.code-workspace`

不得再把以下旧目录当成权威修改入口：

- `C:\Users\20741\Documents\Codex\2026-08-02\ni-x-n`：迁移前工作区，只保留作备份。
- `D:\naiwa1\SLE-ID-Admin-Backend\SLE-ID-Admin-Backend`：迁移前管理端目录。
- `D:\naiwa2\SLE-ID-App-OH`：迁移前最新版平板端来源，关键业务源码已经校验迁入 `D:\SLEID\APPOH`。
- Downloads 中的移动端 ZIP：非最新版，只能参考，禁止覆盖 `D:\SLEID\APPOH`。

开始任何修改前，必须分别运行：

```powershell
git -C D:\SLEID\ws63 status --short --branch
git -C D:\SLEID\Admin status --short --branch
git -C D:\SLEID\APPOH status --short --branch
git -C D:\SLEID\codexworkspace status --short --branch
```

若发现未提交修改，先记录并保护；禁止使用 `git reset --hard`、`git clean` 或强制 checkout。

## 1. 已完成且不得破坏的基线

### 1.1 硬件端

- 三块 WS63 的目标角色已经确定：Card C、Detector A、Detector B。
- A 已能同时连接 B 和 Card，日志出现 B/Card `ready=1`。
- Card C 已实现 Protocol V2、持久 NV 双槽存储、串口配置、SLE 广播和 HMAC 挑战响应。
- B 已实现策略、一次执行、二次确认、离线处理、认证结果消费、GPIO10 执行和 USB 网关。
- 三板认证链路已真实跑通过，成功日志包含：
  - B `auth verify=1`
  - A `auth result ... auth=1`
  - B `auth consume=1`
  - B `EVENT ... auth=1 ... action=2 ... exec=2`
- 模拟卡 `a9000001` 会得到 `auth=2`，这是未授权的预期结果，不能把它当成 Card C 认证失败。
- B→PC USB Protocol V2 与管理后端已有链路已通过。

### 1.2 管理端

- Express、SQLite、WebSocket、B 串口网关和管理前端已存在。
- 后端入口：`D:\SLEID\Admin\server\src\index.ts`。
- 现有 REST 前缀：`/api/*`；现有 WebSocket：`/ws/events`。
- 后端默认 `127.0.0.1:8080`；真实平板不能访问电脑的 `localhost`。
- 管理端曾真实收到 B 上报的事件，硬件→管理端闭环不可因移动端接入而重构破坏。

### 1.3 平板端

- 权威源码已经从 `D:\naiwa2` 迁入 `D:\SLEID\APPOH`。
- 当前移动端有完整领域模型、Mock、邀请码/许可服务框架、二次确认状态框架、写卡事务协调器和本地持久化框架。
- 生产运行仍缺真实后端兼容接口和真实 Card C SLE 适配器。
- 当前 `NearLinkProtocol` 是另一套诊断协议，不兼容 Card 固件，不能直接用于正式写卡。
- 当前 Git HEAD 不包含证书、Profile、密钥库或签名密码。

## 2. 已完成审计文档

新对话必须先读取：

1. `D:\SLEID\codexworkspace\docs\integration\device-map.md`
2. `D:\SLEID\codexworkspace\docs\integration\protocol-audit.md`
3. `D:\SLEID\codexworkspace\docs\card-auth-protocol.md`
4. `D:\SLEID\codexworkspace\docs\card-service-protocol.md`
5. `D:\SLEID\codexworkspace\docs\message-contract.md`
6. `D:\SLEID\codexworkspace\docs\H3863_THREE_BOARD_DUAL_SLE_TEST.md`

协议审计的核心结论：管理端和硬件端已经处于同一条可工作基线；移动端不是只差服务器地址，而是缺少移动 API/DTO 兼容层、真实会话、真实 Card SLE 适配器和受控写卡授权协议。

## 3. 当前设备状态与重新发现规则

历史映射仅用于辅助定位：

- Card C 历史使用 `COM7`。
- B 历史使用 `COM8`。
- A 重插前使用过 `COM10`，之后出现过 `COM9`。
- 平板 HDC 序列号历史为 `5TVUN25B20G01816`。

2026-08-15 刷新时 HDC 返回 `[Empty]`；当前沙箱无法枚举 WMI 串口。新对话不得假设 COM 号仍然有效，必须重新执行设备发现，并通过启动日志确认角色：

- A：`[A] boot`、`[A][dual] ready B=1`、`ready Card=1`
- B：`[B] boot`、网关统计、SLE server
- Card：`[C] boot`、`[sle card] service=10 info=11 command=12 response=13 status=14`

一次只操作一块板；烧录前必须向用户报告目标端口、固件角色、工程和 build target。固件正确时优先不重刷。

## 4. 后续阶段与实施顺序

### 阶段 A：新目录构建基线与自动签名

目标：证明迁移后的三个工程能够独立构建，先解决平板真机安装。

1. 在 `D:\SLEID\codexworkspace` 运行硬件主机测试：

   ```powershell
   powershell -ExecutionPolicy Bypass -File D:\SLEID\codexworkspace\tests\run_tests.ps1
   ```

2. 在 `D:\SLEID\Admin\server` 安装依赖、测试、构建；在 `D:\SLEID\Admin\StarFollow-Admin` 构建前端。不得把 `node_modules`、`dist`、SQLite 运行库提交。
3. 在 DevEco 打开 `D:\SLEID\APPOH`，先同步工程。
4. 平板端 `build-profile.json5` 当前故意不含任何本机签名材料。通过 DevEco 的 Project Structure → Signing Configs 重新生成当前账号/设备的自动签名。
5. 自动签名成功必须同时满足：
   - 存在名为 `default` 的 `signingConfigs`；
   - `products.default` 关联 `"signingConfig": "default"`；
   - 生成的 HAP 不再命名为 `*-unsigned.hap`；
   - 能安装到当前平板并启动。
6. 自动签名生成的证书路径、加密密码和个人 Profile 不得提交。必要时只在本机执行：

   ```powershell
   git -C D:\SLEID\APPOH update-index --skip-worktree build-profile.json5
   ```

   若以后需要提交公共构建配置，先恢复：

   ```powershell
   git -C D:\SLEID\APPOH update-index --no-skip-worktree build-profile.json5
   ```

完成标准：三端在新目录构建成功，平板最新版 HAP 能安装启动；保存命令、版本和实际结果。

### 阶段 B：后端移动兼容层与 LAN 开发配置

目标：让平板真实访问本机后端，同时不改变已有管理端 `/api/*`、`/ws/events` 和 B USB 行为。

最小修改原则：优先在管理后端增加兼容层，不重构硬件协议。

需要实现或敲定：

- 开发环境允许显式绑定 PC LAN 地址或 `0.0.0.0`，非回环监听必须要求强 `STARFOLLOW_API_TOKEN`。
- 增加移动端 health/session/invite/permission/card/confirmation API，或提供明确 DTO 适配层。
- 保留现有管理 API；移动兼容接口建议使用 `/api/mobile/*`。
- WebSocket 可增加 `/ws/mobile` 适配入口，内部复用现有事件中心；不能复制两套事件事实源。
- API 统一响应当前存在 `{code,message,data}` 包装与移动端直接 DTO 的差异。
- 明确公开字符串 ID 与 wire 数值 ID：`permissionId` 不得混用 `LC-...` 和 `hardwarePermissionId:uint32`。
- 平板后端地址必须可编辑并持久化；默认不能是平板自己的 `localhost:3000`。
- 不自动修改 Windows 防火墙；若阻塞，只报告需要用户允许的端口。

完成标准：平板请求 health 成功，真实兑换邀请码并显示“待写入卡片”，后端日志能关联一次移动会话。

### 阶段 C：真实 Card C SLE 适配器

目标：替换生产模式下的 `UnavailableCardCService`，复用现有 `CardProvisioningCoordinator`。

硬件真实协议基线：

- 设备名：`sle_card`
- Service：`0x2C00`
- INFO：`0x2C01`
- COMMAND：`0x2C02`
- RESPONSE：`0x2C03`
- STATUS：`0x2C04`
- 帧 magic：`SL`
- 协议版本：2
- 最大 payload：64 字节
- 多字节字段：小端序
- 帧校验：CRC16；写卡对象还需要长度、CRC32/MAC 与事务读回

实现顺序：发现 → 连接/配对 → 服务发现 → 读取 INFO/STATUS → BEGIN → 分片 CHUNK → COMMIT → 读取回执/读回核验。

安全阻塞必须先解决：Card 固件当前有意拒绝未经授权的远程管理写入。禁止为了演示直接放开 COMMAND。先形成最小写卡授权票据：绑定 Card、permission、request、摘要、nonce/counter、expiry 和操作类型，并由 Card 验签/验 MAC、防重放后才进入事务。正式密钥不得写入 ArkUI 源码或 Git。

完成标准：平板发现真实 Card，写入一个后端签发的真实 Permission，Card 提交 NV 后读回一致；断连或校验失败不留下半个凭证。

### 阶段 D：第一条完整真实闭环

按固定顺序验证：

1. 管理端创建 Permission 和邀请码。
2. 平板真实领取，获得公开 ID 与明确命名的 wire 字段。
3. 平板通过 SLE 事务写入 Card 并读回。
4. A 同时 `ready B=1`、`ready Card=1`。
5. 触发一次完整通行事件；允许先用 `demo enter` 验证业务闭环，但必须明确标为模拟观测输入。
6. B 输出 `auth consume=1`，事件必须为 `auth=1`，策略允许时执行 GPIO。
7. B 通过 USB Protocol V2 上报。
8. 后端保存事件，管理端事件中心出现同一事件。

唯一事件键使用 `sourceId + bootId + eventId`，不能只用重启后可能归零的 `eventId`。

完成标准：保存从管理创建到管理事件落库的同一次真实关联日志，至少重复 3 次无重复执行。

### 阶段 E：二次确认闭环

目标链路：B 产生 CONFIRM → USB → 后端 → 平板 → APPROVED/REJECTED → 后端 → B → GPIO/结果回传。

重点：

- confirmation 对外 ID 使用复合 ID，内部保留 raw `requestId:uint32`。
- 请求终态后不允许迟到响应重新打开或放行。
- 后端/移动端重试必须幂等，B 只执行一次。
- 分别测试 approve、reject、timeout、offline、重复 ACK、重连恢复。

完成标准：批准只执行一次；拒绝、超时、离线均不执行；管理端和平板状态一致。

### 阶段 F：真实 Channel Sounding 与最终回归

当前 A 的状态机与事件闭环存在，但主要输入仍是 `demo enter/reverse/timeout`。最后阶段才接真实 Channel Sounding：

- 使用真实距离/方向/置信度驱动 APPROACHING、IN_ZONE、COMPLETED、CANCELLED、COOLDOWN。
- 保留 demo 命令作为诊断入口，不能把 demo 结果写成真 CS 验收。
- 测试往返、边界抖动、停留、反向、超时、快速重复经过。

最终回归同时覆盖硬件单元测试、管理端测试、ArkUI 测试、三板重连、USB 重连、平板断网恢复、重复帧和断电持久化。

## 5. 修改归属原则

| 问题 | 优先修改位置 |
|---|---|
| 移动 HTTP 路由/DTO 不匹配 | 管理端兼容层 + 移动 API client 最小映射 |
| 平板无法访问 PC | 后端开发监听配置 + 平板可编辑地址 |
| Card UUID/帧不匹配 | 平板真实 `CardSleClient`，复用硬件 Protocol V2 |
| 未授权远程写卡 | 先设计共同票据，再分别改后端、Card、平板 |
| B USB/现有管理事件 | 默认不改；必须有回归证据才能修改 |
| A/B/Card 已通过认证协议 | 默认不重构，只修有复现证据的问题 |

## 6. 安全与操作红线

- 不提交或输出正式私钥、主密钥、签名密码、Token、数据库密码和用户隐私。
- 不提交 `.cer`、`.p7b`、`.p12`、`.key`、`.pem`、HAP、数据库、依赖和构建缓存。
- 不为了联调关闭 Card 写入鉴权。
- 不自动开放防火墙、不终止未知进程、不删除用户数据库。
- 不盲刷三块板；一次只刷一块，烧录前报告精确目标。
- 不把历史日志中的 `bridge ready` 当成当前连接证据；重启后必须看当前会话日志。
- 每一阶段结束输出：Changed Files、Why、Build Result、Test Result、Remaining Problems。
- 修改形成小提交；未经用户要求不要 push、force-push 或改写远程历史。

## 7. 下一次对话的第一项实际工作

下一对话不要直接开发大功能，应从“阶段 A”开始：

1. 打开 `D:\SLEID\SLE-ID.code-workspace`。
2. 读取本文件及两份 integration 审计。
3. 确认四个仓库 status 没有未知修改。
4. 重新发现三块板和平板，不复用旧 COM 号。
5. 在新目录跑硬件、管理端和平板端构建基线。
6. 先解决 DevEco 自动签名并把最新版应用安装到平板。
7. 报告基线结果后，再进入阶段 B。

## 8. 可直接复制给新对话的启动指令

```text
继续“星随 / SLE-ID”三端真实联调项目。权威工作区已经迁移到 D:\SLEID，禁止再把旧的 ni-x-n、naiwa1、naiwa2 或 Downloads ZIP 当成修改入口。

首先完整读取：
1. D:\SLEID\codexworkspace\docs\integration\NEXT_SESSION_HANDOFF.md
2. D:\SLEID\codexworkspace\docs\integration\device-map.md
3. D:\SLEID\codexworkspace\docs\integration\protocol-audit.md

然后检查 D:\SLEID\ws63、Admin、APPOH、codexworkspace 四个 Git 工作区，保护现有本地提交和任何用户修改。不要 reset、clean、force checkout，不要推送。

从交接方案“阶段 A”继续：重新发现当前三块 WS63 与 HarmonyOS 平板，验证新目录三端构建基线，优先解决 APPOH 自动签名并安装最新版应用。完成后按 Changed Files / Why / Build Result / Test Result / Remaining Problems 汇报，再进入后端移动兼容层。不得破坏已通过的 A/B/Card 认证和 B→USB→管理端链路。
```

## 9. 最终完成定义

只有同时满足以下条件，整个项目才算完成：

- 管理端与原硬件链路无回归。
- 平板能真实访问 PC 后端并领取真实 Permission。
- 平板能通过 SLE 对真实 Card 事务写入并读回。
- A 能识别 Card 并形成完整事件。
- B 能认证、执行策略并经 USB 上报。
- 管理端出现同一真实事件。
- 二次确认 approve/reject/timeout/offline 至少各通过一次。
- 真实 Channel Sounding 已替代 demo 作为正式输入，或明确列为未完成而不伪造验收。
- 三端测试日志、构建方式、设备映射和剩余限制均已更新并提交到对应分支。
