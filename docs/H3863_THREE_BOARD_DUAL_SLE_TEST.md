# H3863 三板双 SLE 真机测试

更新时间：2026-08-14

## 1. 测试目标

验证 Detector A 同时维护两条真实 SLE 链路：

- A ↔ Detector B：通行事件、认证挑战、认证结果和执行决策；
- A ↔ Card C：认证挑战和 HMAC 响应。

本测试不再使用 `three_party_auth_serial_bridge.ps1`。PC 只负责查看三块板的串口日志和输入测试命令，不转发认证帧。

## 2. 固件

- A：`outputs/detector_a_h3863_all.fwpkg`
  - SHA256：`E5E4C1989C70184D58D72A9FCD89275732F539F74CE43E006D73DCB2EC0702C5`
- B：`outputs/detector_b_h3863_all.fwpkg`
  - SHA256：`E95DCD7729EB5CAF28341BCCBFAADFF40B8F266B9ECCD3FBF9D89B955D53753B`
- C：保留当前已经写入测试许可并验证 NV 持久化的 Card C 固件和数据，不要为了本项测试重新烧录 RAM 联调包。

## 3. 准备

1. 关闭管理端后端和所有占用 A、B、C 串口的软件；第一次双 SLE 认证测试期间，B 串口需要接收人工命令。
2. 给 A 烧录新 A 固件，给 B 烧录新 B 固件。
3. 先启动 B 和 C，再启动 A。
4. 分别打开三块板的串口监视器，参数为 115200、8N1、LF 或 CRLF。

## 4. 链路检查

A 应依次出现类似日志：

```text
[A][dual] found B, stopping seek
[A][dual] connected B ...
[A][dual] ready B=1 ...
[sle uart client] === bridge ready ===
[A][dual] seeking target=Card
[A][dual] found Card, stopping seek
[A][dual] connected Card ...
[A][dual] ready Card=1 ... command=... response=...
```

给 A 发送：

```text
status
```

通过条件：A 的双链路状态中 `B ... ready=1` 且 `Card ... ready=1`。

## 5. 无 PC 桥认证与通行

给 B 依次发送：

```text
auth testkey
auth start
```

通过条件：

- A 出现 `[A] card SLE tx bytes=...`，不能依赖 `[A][CARD-TX]`；
- C 收到挑战并产生认证响应；
- B 出现 `auth verify=1`；
- A 出现成功的 `auth result`。

认证握手限时 5 秒；B 验签成功后会单独开启 15 秒的一次性通行窗口。

随后给 A 发送：

```text
demo enter
```

最终通过条件：B 输出 `auth=1` 的事件并驱动一次执行器，A 收到允许执行的 decision。

## 6. 重连测试

1. 断开 C 的 USB 供电，确认 A 输出 Card disconnected；
2. 恢复 C 供电，确认 A 自动重新发现 Card，状态回到 `Card ... ready=1`；
3. 再执行一次 `auth start` 和 `demo enter`；
4. 对 B 重复一次断电、恢复和通行测试。

## 7. 故障定位

- B ready=1、Card ready=0：检查 C 是否输出 `advertising result=0`，并确认 C 使用的是独立 Card 服务固件。
- Card 已连接但 response handle 为 0：Card 服务发现或 UUID 映射失败，保留 A/C 完整启动日志。
- A 输出 `[A][CARD-TX]`：真实 Card SLE 链路尚未 ready，当前走的是测试模式串口回退路径。
- C 有响应但 B 没有 `auth verify=1`：保留 A 的 Card notification 日志、B 的认证日志和三块板 `status`。
- B 验签成功但不执行：先确认已经在认证成功后发送 `demo enter`，且 B 的策略允许 execute。

## 8. 尚未包含的功能

本项完成的是双 SLE 连接、HMAC 认证和一次性通行绑定。真实 Channel Sounding、全自动靠近触发、持久化防重放窗口、生产密钥注入及关闭本地串口写卡入口仍是后续工作。
