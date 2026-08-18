# 三端真实联调交接报告（2026-08-17）

## 1. 交接结论

本轮已经解决 2026-08-15 报告中的“Card C 连接超时”主阻塞：HarmonyOS 平板现在可以扫描到 Card C 本次启动的实时地址，完成配对、建立 SSAP 链路、发现服务并启用 RESPONSE 通知。

当前尚未完成写卡闭环。最新阻塞已推进到 INFO 属性读取：平板读到的内容是服务注册时的一字节初始值 `00`，不是 Card C 生成的 38 字节 Protocol V2 CARD_INFO 帧，因此 App 拒绝绑定实体卡。Card C 仍为 `count=0 generation=0`，未伪造成功状态。

停止时间：`2026-08-17 17:43 +08:00`。

## 2. 现场设备与环境

- Card A：`COM8`。为避免 A 占用 Card C 的唯一 SLE 连接，当前已拔下，测试期间应继续保持断开。
- Detector B：`COM7`。
- Card C：`COM14`，115200 baud。
- HarmonyOS 平板 HDC ID：`5TVUN25B20G01816`。
- HDC：`D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`。
- DevEco Studio 已打开权威项目：`D:\SLEID\SLE-ID-App-OH`。不要误用另一个旧窗口 `D:\naiwa2\SLE-ID-App-OH`。

## 3. 仓库与工作区状态

### Card C 固件仓库

- 路径：`D:\SLEID\ws63`
- HEAD：`3499959`
- 本轮没有修改固件源码，工作区干净。

### HarmonyOS App 仓库

- 路径：`D:\SLEID\SLE-ID-App-OH`
- HEAD：`259d9c7`
- 未提交修改：
  - `build-profile.json5`：用户原有的本机签名修改，必须保留，禁止覆盖或泄露其中内容。
  - `entry/src/main/ets/services/CardCSleAdapter.ets`：本轮修复与诊断代码，必须保留。
- 最新构建 HAP：`D:\SLEID\SLE-ID-App-OH\entry\build\default\outputs\default\entry-default-signed.hap`
- 最新 HAP SHA-256：`3EBAE4F58DF4FA34B1AC369C213EE6C0789FB6042E32CF517D6ECA369768594E`
- DevEco 构建、安装、启动均成功；该 HAP 已安装到真实平板。

本轮未创建 Git 提交。

## 4. 已完成修复

修改文件：`D:\SLEID\SLE-ID-App-OH\entry\src\main\ets\services\CardCSleAdapter.ets`

### 4.1 修复重启后地址失效

Card C 固件每次启动都会随机生成本地 SLE 地址。旧 App 优先使用系统已配对地址，Card C 重启后这个地址可能已经失效，导致连接超时。

现在 App 的选择顺序为：

1. 优先实时扫描名称为 `sle_card` 的广播并使用本次启动地址。
2. 只有扫描不可用时才回退到系统已配对设备。

真实日志已经证明修复生效：

```text
[SLEKEY][CARD-C] using live Card C advertisement
[SLEKEY][CARD-C] pairing check started
[SLEKEY][CARD-C] pairing completed
[SLEKEY][CARD-C] pairing check passed
[SLEKEY][CARD-C] connection state=1
[SLEKEY][CARD-C] SSAP link connected
[SLEKEY][CARD-C] services discovered=1
```

### 4.2 修复通知启用时序竞争

配对完成后立即调用 `setPropertyNotification()`，首次调用稳定出现：

```text
code=1009700099 message=Operation failed.
```

增加最多 3 次、间隔 250ms 的短重试后，第二次调用成功：

```text
[SLEKEY][CARD-C] response notification attempt=1 failed code=1009700099 message=Operation failed.
[SLEKEY][CARD-C] response notification enabled attempt=2
```

服务发现得到的属性元数据也已确认正确：

```text
2C01 operation=1 descriptors=0
2C02 operation=4 descriptors=0
2C03 operation=9 descriptors=1
2C04 operation=9 descriptors=1
```

即 INFO 可读、COMMAND 支持带响应写入、RESPONSE/STATUS 均具备 Read+Notify 和客户端配置描述符。

### 4.3 增加无敏感信息的诊断日志

已记录服务属性 operation、descriptor 数量、通知失败错误码和 INFO 原始字节，不包含许可密钥或签名配置。

## 5. 当前精确阻塞

最新真实日志：

```text
[SLEKEY][CARD-C] response notification enabled attempt=2
[SLEKEY][CARD-C] INFO raw length=1 hex=00
[SLEKEY][CARD-C] discovery failed: Card C returned an invalid Protocol V2 frame
```

预期 INFO 应为 38 字节：20 字节 Protocol V2 header + 16 字节 payload + 2 字节 CRC。Card C 固件的 `build_info_value()` 已按该格式生成数据，但 HarmonyOS `readProperty()` 实际只拿到属性注册时的初始值 `00`。

相关固件位置：

- `D:\SLEID\ws63\card_ws63\platform\ws63\ws63_card_sle_server.c`
  - `add_property()` 把所有属性的初始值注册为一字节 `00`。
  - `read_request_callback()` 计划通过 `g_callbacks.read()` 动态生成 INFO/STATUS 并调用 `ssaps_send_response()`。
- `D:\SLEID\ws63\firmware\h3863\sle_card\h3863_sle_card.c`
  - `build_info_value()` 正确构造 Protocol V2 CARD_INFO。
  - `read_property()` 根据 `ws63_card_sle_info_handle()` 返回该帧。

当前判断：HarmonyOS 读请求没有走到预期的动态 read response，或 `request->handle` 与保存的 property handle 语义不一致；客户端因此读取了注册时的静态初始值。需要先用服务端日志证实具体分支，不能直接宣称是 App 解码错误。

Card C 停止时状态：

```text
[C] card=c0000001 count=0 generation=0 caps=07 connected=0 commands=0 bad=0 dup=0 send_fail=0 crc=0 format=0
[C] auth rx=0 ok=0 deny=0 dup=0 replay=0 commits=0 store_fail=0 send_fail=0
```

## 6. 下一位接手者的执行方案

### 阶段 A：确认 SSAP 读回调行为

1. 保持 A/COM8 断开，避免占用 C 的唯一连接。
2. 在 `read_request_callback()` 临时打印以下非敏感字段：`status`、`conn_id`、`request->handle`、`request->type`、`request->need_rsp`，同时打印 `g_info_handle` 与 `g_status_handle`。
3. 检查 SDK 头文件：`D:\hispark\sdk\fbb_ws63\src\include\middleware\services\bts\sle\sle_ssap_server.h`，确认 `ssaps_req_read_cb_t` 的 handle/type 定义以及动态读取所需的回调/operate 配置。
4. 重新构建并烧录 Card C，只做一次“发现并绑定”测试，通过 COM14 收集回调日志。

### 阶段 B：按证据修复 INFO 返回

优先采用 SDK 语义正确的修复：纠正 handle 比较或 SSAP 属性/回调配置，使 `ssaps_send_response()` 返回动态 38 字节 INFO 帧。

如果该 HarmonyOS/WS63 组合只读取注册值，则采用可验证的静态值方案：在注册 INFO 属性时写入完整 CARD_INFO 初始帧，并确保属性值缓冲区生命周期符合 SDK 要求。STATUS 仍需动态性，不能不加验证地一并静态化。

不要在 App 中把单字节 `00` 当作成功，也不要硬编码 `CARD-C0000001` 绕过协议校验。

### 阶段 C：重新验证发现闭环

成功标准：

```text
INFO raw length=38 hex=534C02...
INFO verified card=CARD-C0000001
```

同时 App UI 应显示真实实体卡已绑定，C 串口应在连接期间显示 `connected=1`；失败清理后可回到 `connected=0`。

### 阶段 D：执行真实写卡闭环

INFO 成功前不要执行此阶段。

1. COM14 输入 `write unlock`，开启固件定义的 60 秒本地授权窗口。
2. 在平板选择现有真实数字许可并发起写卡。
3. 验证 WRITE_BEGIN / WRITE_PERMISSION / WRITE_COMMIT 的通知响应与 App 状态更新。
4. COM14 输入 `status`，必须看到 `count` 从 0 变为 1、`generation` 增加、`commands` 增加且 `bad/crc/format/send_fail` 仍为 0。
5. 断电重启 C，再次 `status`，确认 NV 持久化后 `count=1` 仍存在。
6. 最后再接回 A/COM8，执行 A-B-C 三端认证链路测试。

## 7. 快速复现命令

读取 C 状态（PowerShell）：

```powershell
$port = [System.IO.Ports.SerialPort]::new('COM14',115200,'None',8,'One')
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = 500
$port.Open()
$port.WriteLine('status')
Start-Sleep -Milliseconds 800
$port.ReadExisting()
$port.Close()
```

筛选 App 日志：

```powershell
$hdc = 'D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc -t 5TVUN25B20G01816 shell hilog -x |
  Select-String -SimpleMatch '[SLEKEY][CARD-C]'
```

## 8. 安全与交接注意事项

- 不要输出或提交 `build-profile.json5` 中的签名路径、口令散列或证书信息。
- 不要覆盖用户已有签名配置。
- 不要把“已连接/已发现服务”等同于“已写卡”；最终证据必须包括 C 的 `count/generation` 和断电重启后的 NV 状态。
- App 当前修复尚未提交，接手后先查看 diff，不要 reset 或 checkout 掉工作区。
- 当前诊断日志中的 INFO 原始值不含密钥；后续写卡阶段不要打印 Credential 正文、密钥或认证材料。
