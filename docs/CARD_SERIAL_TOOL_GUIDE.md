# Card C 串口写卡工具

`tools/card_serial_tool.ps1` 用于通过 Card C 的本地维护串口完成信息查询、许可列表、
分片写卡和许可状态修改。它生成正式的 Protocol V2 二进制帧，经 `proto <hex>` 送入固件，
固件仍调用与 SLE COMMAND 特征相同的 `card_service_handle_command()`，不是另一套简化存储逻辑。

## 1. 固件和接线

使用 `outputs/card_c_h3863_ram_all.fwpkg`。当前固件默认配置如下：

- UART0，115200、8N1；
- 板端 TX=GPIO17，RX=GPIO18；
- USB 转串口 RX 接 GPIO17，TX 接 GPIO18，并共地；
- 电平必须是 3.3 V；
- `CONFIG_SLE_CARD_SERIAL_PROVISIONING=y`；
- RAM 存储，复位会清空刚写入的许可。

如果板载 USB 已把 UART0 同时接到电脑，可直接使用它对应的 COM 口。运行工具前要关闭 VS Code
串口监视器，否则同一个 COM 口会被占用。

启动后应看到：

```text
[C] WARNING: volatile RAM credential store; reset clears credentials
[C] WARNING: local serial provisioning is enabled
```

## 2. 离线检查

不连接板子也可以验证参数和帧编码：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\card_serial_tool.ps1 `
  -Action Info -DryRun
```

默认只输出帧长度和 SHA-256，不显示可能包含密钥的原始帧。仅在确有需要时添加 `-ShowFrames`；
不要把该输出截图或提交到仓库。

## 3. 查询 Card

以下示例假设 Card 是 `COM7`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\card_serial_tool.ps1 `
  -Action Info -Port COM7

powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\card_serial_tool.ps1 `
  -Action List -Port COM7
```

`Info` 返回协议版本、容量、Card ID、固件版本和 generation。`List` 返回不含 32 字节密钥的
许可摘要；空卡只会正常结束，不输出许可项。

## 4. 写入许可

下面写入一项检查点许可。示例密钥只用于实验，真实密钥必须由安全随机源生成并另行保管：

```powershell
$key = '11' * 32
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\card_serial_tool.ps1 `
  -Action Provision -Port COM7 `
  -PermissionId 1 -OrganizationId 100 `
  -Scope Checkpoint -ScopeId 7 `
  -ValidFrom 0 -ValidTo 0 `
  -UsageLimit 100 -CredentialVersion 1 -KeyVersion 1 `
  -KeyHex $key
```

工具依次等待 BEGIN、两个 CHUNK 和 COMMIT 的业务回执；任何一步非零状态都会停止并报错。
成功后再运行 `List`，应看到 `PermissionId=1`、`CredentialVersion=1`、`State=Active`，且
generation 已增加。

## 5. 修改许可状态

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\card_serial_tool.ps1 `
  -Action State -Port COM7 -PermissionId 1 -State Frozen
```

状态可选 `Active`、`Frozen`、`Lost`、`Expired`、`Revoked`。状态修改成功后，凭证版本和
generation 都会增加。使用相同 requestId 的底层重复请求由 Card 幂等处理；工具每次启动会生成
新的 requestId。

## 6. 安全边界

串口写卡入口是实验室维护接口，不是远程管理接口。RAM 联调固件默认启用它；切换到持久化 NV
或生产固件时，Kconfig 默认关闭 `SLE_CARD_SERIAL_PROVISIONING`。若确需启用，必须同时控制设备
物理访问，不能把维护排针暴露给非授权人员。

当前工具验证的是 Card 本地串口和正式业务核心。第三块板到位后，仍需分别验证 SLE 服务发现、
安全配对、COMMAND/RESPONSE 特征、断线恢复和三节点闭环。
