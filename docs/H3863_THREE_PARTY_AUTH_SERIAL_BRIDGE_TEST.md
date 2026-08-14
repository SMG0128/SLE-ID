# H3863 三端 HMAC 串口桥联调指南

本指南用于第三块板到位后的阶段性认证验收：B 与 A 之间使用真实 SLE；A 与 Card 之间暂时由电脑
自动转发完整 Protocol V2 帧。它能验证 B 权威端、A 中继、Card HMAC、计数器和结果回传，
但不能替代 A 同时连接 B/Card 的双 SLE 真机验收。

## 1. 准备

- A 烧录 `outputs/detector_a_h3863_all.fwpkg`；
- B 烧录 `outputs/detector_b_h3863_all.fwpkg`；
- Card 烧录 `outputs/card_c_h3863_ram_all.fwpkg`；
- 三块板各有一个可收发的 115200 UART COM 口；
- A 与 B 已出现 `connected` 和 `bridge ready`；
- 关闭 VS Code 串口监视器，避免 COM 口被占用。

Card 是 RAM 联调固件，每次复位后都要重新写入测试许可。下面假设 Card 为 `COM7`：

```powershell
$key = '11' * 32
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\card_serial_tool.ps1 `
  -Action Provision -Port COM7 `
  -PermissionId 7 -OrganizationId 100 `
  -Scope Checkpoint -ScopeId 9 `
  -ValidFrom 0 -ValidTo 0 -UsageLimit 100 `
  -CredentialVersion 3 -KeyVersion 2 -KeyHex $key
```

该固定密钥仅在 `CONFIG_SLE_AB_TEST_MODE` 中由 B 的 `auth testkey` 命令安装，禁止用于正式部署。

## 2. 自动桥接测试

按实际端口替换 A/B/Card 三个 COM 号：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\three_party_auth_serial_bridge.ps1 `
  -APort COM5 -BPort COM6 -CardPort COM7
```

脚本会自动完成：

1. 给 B 发送 `auth testkey` 和 `auth start`；
2. 从 A 的 `[A][CARD-TX]` 取得挑战帧并送入 Card；
3. 从 Card 的 `[C][PROTO]` 取得响应帧并送回 A；
4. 等待 B 验签和 A 收到最终 `AUTH_RESULT`；
5. 自动向 A 发送 `demo enter`，验证 B 精确消费该授权并执行 GPIO。

成功标志：

```text
[B] auth verify=1 ... auth=1 reason=0 counter=1
[A] auth result ... auth=1 reason=0 counter=1
[B] EVENT ... auth=1 action=2 confirm=0 exec=2 reason=0
PASS: HMAC authentication was bound to one passage and B executed it.
```

测试结束后在 B 输入 `status`，`consumed` 应增加 1。相同认证结果不能再次授权另一条事件。

再次运行时 counter 应递增。Card 复位后凭证和 RAM counter 清空，必须重新写卡；B 复位后测试许可
和已接受最高 counter 也会清空。当前行为符合 RAM 联调版边界，不属于最终掉电防重放实现。

## 3. 失败检查

- `reason=1`：Card 没有匹配许可，或 Card 已复位清空；
- `reason=10`：测试密钥、凭证版本或响应标签不匹配；
- `reason=11`：计数器/会话疑似重放；
- `reason=20`：B 或 A 的认证会话槽已满；
- 超时：先确认三个 COM 未被其他程序占用，以及 A/B 真实 SLE 仍连接。

更改 Card 许可为 Frozen/Lost/Revoked、改用错误密钥或重复注入旧响应，可继续验证拒绝分支。
