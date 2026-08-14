# SLE-ID 本机设备与工程盘点

盘点时间：2026-08-14（Asia/Shanghai）  
范围：附件要求的 PHASE 0，只读盘点；本轮没有修改业务代码、没有烧录设备、没有删除数据库或配置。

## 1. 工程与 Git 状态

| 组成 | 当前使用路径 | Git 状态 | 构建/启动入口 | 主要入口与配置 |
|---|---|---|---|---|
| 硬件端工作目录 | `C:\Users\20741\Documents\Codex\2026-08-02\ni-x-n` | 目录本身不是 Git 仓库 | 主机测试：`powershell -File .\tests\run_tests.ps1`；安装到 SDK：`tools\install_into_sdk.ps1 -SdkRoot D:\hispark\sdk\fbb_ws63\src` | A/B：`firmware\h3863\sle_ab\h3863_sle_ab.c`；Card：`firmware\h3863\sle_card\h3863_sle_card.c`；Kconfig/CMake：`firmware\h3863` |
| 硬件端上传工作树 | `...\ni-x-n\github-upload\ws63` | 分支 `ws63`，工作树干净；本地提交 `939d81e`，比 `origin/ws63` 领先 1；尚未推送 | 与硬件端工作目录相同 | 仅用于 Git 上传，不作为 SDK 构建源目录 |
| 管理端工作目录 | `D:\naiwa1\SLE-ID-Admin-Backend\SLE-ID-Admin-Backend` | 目录本身不是 Git 仓库 | 后端：`cd server; npm run dev` 或 `npm run build; npm start`；前端：`cd StarFollow-Admin; npm run dev/build` | 后端入口：`server\src\index.ts`；API：`server\src\routes\api.ts`；前端入口：`StarFollow-Admin\src\main.ts`；服务配置：环境变量 `STARFOLLOW_*` |
| 管理端上传工作树 | `...\ni-x-n\github-upload\Admin-Backend` | 分支 `Admin-Backend`，工作树干净；本地提交 `e6434e8`，比 `origin/Admin-Backend` 领先 1；尚未推送 | 与管理端工作目录相同 | 仅用于 Git 上传；`node_modules`、`dist`、SQLite 数据未纳入提交 |
| 权威移动端工程 | `D:\naiwa2\SLE-ID-App-OH` | 不是 Git 仓库；含本机 `.idea`、`.hvigor`、`oh_modules` | DevEco Studio 6.1 / Hvigor 6.23.6；命令行入口：`D:\DevEco Studio\tools\hvigor\bin\hvigorw.bat --no-daemon --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap` | **后续审计、修复和真机测试均以此目录为准**。ArkUI 入口：`entry\src\main\ets\entryability\EntryAbility.ets`；页面入口：`pages\Index.ets` |
| 移动端参考快照（非最新版） | `C:\Users\20741\Downloads\SLE-ID-App-OH (1).zip\SLE-ID-App-OH` | ZIP 不含 `.git`；只读审计副本位于 `...\work\integration-audit-20260814\SLE-ID-App-OH` | 不作为后续构建入口 | 业务源码与 `D:\naiwa2` 当前版本相同，但根 `build-profile.json5` 和两个 lock 文件不同；仅用于差异核对，不得覆盖权威工程 |

保护说明：没有执行 `git reset --hard`、`git clean`、强制 checkout 或数据库删除。ZIP 只解压到审计临时目录，未覆盖 `D:\naiwa2` 权威工程。

### 1.1 平板端自动签名现状

- `D:\naiwa2\SLE-ID-App-OH\build-profile.json5` 已存在名为 `default` 的 HarmonyOS `signingConfigs`，证书（`.cer`）、Profile（`.p7b`）与密钥库（`.p12`）文件均存在；本报告不记录其密码或具体材料路径。
- `app.products` 中的 `default` 产品没有 `"signingConfig": "default"`，因此已生成的签名方案没有绑定到实际构建产品。华为官方 `build-profile.json5` 规范将 `products[].signingConfig` 定义为产品所使用的签名方案名称；这是当前可静态确认的首要配置缺口。
- 当前只完成只读诊断，尚未修改签名配置、重新申请 Profile 或重新构建。后续应先补齐产品关联，再由 DevEco 验证 Profile 的包名、证书和当前平板设备是否匹配。

## 2. 当前连接设备

### 2.1 Windows 串口

| 角色 | 当前端口 | USB/PNP 信息 | 当前被动观察 | 确认状态 |
|---|---|---|---|---|
| WS63-B | `COM8` | `USB-SERIAL CH340`；`USB\VID_1A86&PID_7523\6&1EFA3ABE&0&3` | 115200 被动读取到以 `SL` 开头的 Protocol V2 二进制心跳/上报及 `LED toggle.`；符合 B 的单 USB 网关行为 | **已确认** |
| WS63 Card | `COM7`（历史映射） | `USB-SERIAL CH340`；`USB\VID_1A86&PID_7523\6&1EFA3ABE&0&2` | 当前打开失败：`Access to the port 'COM7' is denied`。历史三板联调使用 `CardPort COM7` 并得到 Card HMAC 响应，但本轮不能读取当前启动日志 | **本轮未重新确认**；需先释放端口后读取 Card 启动行 |
| WS63-A | `COM9`（候选） | `USB-SERIAL CH340`；`USB\VID_1A86&PID_7523\5&19E527CA&0&9` | 被动读取只有 `LED toggle.`，没有 `[A] boot`、sourceId 或 dual-client 状态。历史映射为 `COM10`，重新插拔后端口号可能变化 | **未确认**；禁止仅凭端口号认定 |

系统另有蓝牙虚拟串口 `COM3`、`COM4`，不属于三块板。

COM7 占用者没有通过进程命令行可靠定位。当前同时运行 VS Code 与 DevEco Studio；释放端口时应先关闭相应串口监视器，不应强杀未知进程。

### 2.2 HarmonyOS 平板

| 项目 | 观察值 |
|---|---|
| HDC 目标 | `5TVUN25B20G01816` |
| USB | `VID_12D1&PID_1101`，HDC Interface 正常 |
| 型号 | HUAWEI MatePad 11.5 S (`SLG-W10`) |
| 系统 | `SLG-W30 6.1.0.135(SP9C00E125R6P5)` |
| 设备类型 | `tablet` |
| 应用 | `com.slekey.app` 已安装，版本 `1.0.0`，debug 包，目标 API 6.1.0(23) |
| 权限声明 | `ohos.permission.INTERNET`、`ohos.permission.ACCESS_NEARLINK`；系统包信息显示 NearLink 权限已声明，但本轮未进行运行时授权/扫描测试 |
| 确认状态 | **平板及应用已确认** |

HDC 路径：`D:\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`。

## 3. 当前运行状态与网络

- 本轮检查时 `127.0.0.1:8080` 没有监听进程，管理后端未运行。
- 后端默认绑定 `127.0.0.1:8080`；真实平板不能使用自身的 `localhost` 访问电脑。
- 当前 WLAN IPv4 为 `10.253.50.121`，默认网关 `10.253.50.202`。
- 另有 Radmin VPN 地址 `26.101.87.133`，不应自动当作同 WLAN 平板的开发地址。
- 本轮没有修改 Windows 防火墙规则。

## 4. 进入下一阶段前必须补齐的设备确认

1. 关闭占用 COM7 的串口监视器，只读取一次 Card 启动日志，确认出现 `[C] boot card=...` 与 SLE Card 服务信息。
2. 对 COM9 读取一次包含启动行的日志，确认 `[A] boot`、sourceId 和 dual SLE client 状态；若不是 A，再重新映射，不能猜。
3. 确认角色后再记录固定标签（板上贴纸建议写 `Card/COM7`、`A/COM9`、`B/COM8`）；端口号仍需每次重连后重新枚举。
4. 在任何烧录动作前，单独列出端口、USB InstanceId、工程角色和 build target；本轮未授权也未执行烧录。
