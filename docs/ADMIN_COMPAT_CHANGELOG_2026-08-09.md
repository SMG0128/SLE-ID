# 管理端兼容改动日志（2026-08-09）

## 管理端检查

- 检查路径：`D:\naiwa1\SLE-ID-Admin-Backend\SLE-ID-Admin-Backend`。
- 确认 `server/` 只有 README，没有可运行的本地后端源码。
- 使用 npm 官方源安装 107 个包；首次安装受本机清华镜像配置影响，`zrender` 下载 404，
  使用 `--registry=https://registry.npmjs.org --replace-registry-host=never` 后成功。
- `npm run build` 通过 TypeScript 检查和 Vite 生产构建。
- 构建存在大于 500 kB 的 chunk 警告；npm 报告 6 项依赖漏洞（2 moderate、4 high），本轮未执行
  可能造成破坏性升级的 `npm audit fix --force`。
- 没有修改管理端源码；测试生成了 `node_modules/` 和 `dist/`。

## 硬件端新增

- 新增 B 单 USB Protocol V2 网关：心跳、策略同步、事件、报警、确认、命令结果。
- 新增 32 条 RAM 可靠队列、ACK、同 messageId 重试、断线恢复与溢出计数。
- 新增 UART0 二进制帧/文本命令分流，解析工作移到任务线程。
- 新增 `tools/admin_gateway_compat.ps1`，输出管理端 Device/Event/Alarm/Confirm 映射。
- 心跳周期由 2 秒调整为需求约定的 1 秒。

## 修复缺陷

- 修复 Host 策略 requestId 与 B 生成的确认 requestId 数字相同时被错误判为冲突。
- 修复确认超时/结束后，旧 `CONFIRM_REQUEST` 仍留在可靠队列继续发送。
- 修复确认请求因队列已满未入队时，仍错误标记为 active 的状态不一致。
- 最终确认报告现在会取消同事件尚未 ACK 的旧确认请求。

## 测试

- 管理端 `vue-tsc --noEmit && vite build`：通过。
- 硬件协议、A/B 核心、Card、三端认证、A 中继、B 网关测试：通过。
- 管理端字段映射 SelfTest：通过（设备、事件、报警、确认）。
- 新增 requestId 命名空间碰撞、超时确认清理、满队列确认测试：通过。
- A、B 角色均使用 `D:\hispark\sdk` 官方 SDK 完成全量编译、签名和打包。

## 本次发布产物

- Detector A：`detector_a_h3863_all.fwpkg`，SHA256 `0C80BFC5F86842624DA666EDE70204EEA486601F6FC8A6F0134350C553966291`。
- Detector B：`detector_b_h3863_all.fwpkg`，SHA256 `DF58FA33A8F1DF826428F6A92508E84555E6C428D32BB89AD1FFF316C654F5F9`。
- Card C RAM 联调版：`card_c_h3863_ram_all.fwpkg`，SHA256 `4F5D6364ED4B7C206D7BAA45098143724FA004775B65F3DA9CB4B0094451BB56`。
- 硬件源码归档：`SLE_AB_H3863_source.zip`，SHA256 `859C414A94EF32203F9F2A52453E88335360AC1E97A0DA465E60A690F0FF5C69`。

## 未解决

- 管理端真实本地后端不存在，不能进行 REST/WebSocket/SQLite 端到端测试。
- B 离线队列尚未写入 Flash，设备复位会丢待上传记录。
- 管理端 10 项策略只有基础子集能映射到 B；范围、时间、次数、方向仍需协议 V2 扩展。
- 串口正式发布版仍应关闭或封装文本调试日志，避免与二进制帧共享 UART 带来的带宽和交错风险。
