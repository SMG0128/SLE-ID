# SLE-ID

基于星闪的无感识别应用，实现数字身份/交通/权限卡管理，支持写入物理 WS63 卡片。应用采用单页路由架构，通过 ArkUI 构建，提供中英文双语界面。目前完全基于模拟数据运行。

## 核心功能

- **数字卡片管理**：用户卡包中的数字身份/交通/权限卡
- **物理卡管理**：WS63 物理卡的发现、连接和凭证写入
- **邀请码系统**：SLE 格式邀请码的预览和兑换
- **二次验证**：外部应用触发的安全验证流程
- **设置中心**：语言、模拟参数等配置

## 技术架构

### 单页路由模式
采用单一路由入口（`pages/Index`），通过 `@State` 控制不同子页面的显示：

- `CardsPage` - 数字卡片列表（默认页面）
- `CardDetailPage` - 卡片详情
- `PhysicalCardManagerPage` - 物理卡管理
- `ProfilePage` - 用户资料
- `LanguagePage` - 语言设置
- `MockSettingsPage` - 模拟参数设置
- `ScanPage` - 卡片扫描

### 状态管理
使用单例模式的 `CardStore` 管理应用状态，包括数字卡片、授权信息、物理卡状态等。采用 `@Observed` 和 `@ObjectLink` 实现响应式数据流。

### 服务接口模式
所有业务逻辑通过接口定义实现：

- `DigitalCardService` - 数字卡片 CRUD
- `AuthorizationService` - 授权管理
- `PhysicalCardService` - 物理卡操作
- `CredentialService` - 凭证管理
- `ConfirmationService` - 二次验证
- `InvitationService` - 邀请码管理

### 模拟数据系统
完全基于模拟数据开发，使用 `MockDataSource` 模拟所有物理卡操作，包括延迟和失败模式。支持生产级持久化和测试级内存持久化两种实现。

## 项目结构

```
entry/src/main/ets/
├── pages/              # 单页组件 (路由管理)
│   ├── Index.ets      # 路由壳
│   ├── CardsPage.ets  # 卡片列表
│   ├── CardDetailPage.ets  # 卡片详情
│   └── ...            # 其他子页
├── components/         # 复用UI组件
├── common/             # 公共工具 (主题, 卡片模型)
├── models/             # 领域模型
├── services/           # 服务接口定义
├── mock/               # 模拟实现
├── stores/             # 状态管理
└── entryability/       # 入口能力
```

## 开发环境

### 构建工具

项目使用 **DevEco Studio 自带的 Hvigor**，不维护单独的自定义包装器或
Hvigor JAR。首次检出后先安装锁定依赖，再执行干净的调试构建：

```powershell
ohpm install

& '<DevEco Studio>\tools\hvigor\bin\hvigorw.bat' --no-daemon clean
& '<DevEco Studio>\tools\hvigor\bin\hvigorw.bat' --no-daemon `
  --mode module -p product=default -p module=entry@default `
  -p buildMode=debug assembleHap
```

### Domain contract tests

The Phase 0C host-side Hypium tests are under `entry/src/test` and require no
device or emulator:

```powershell
& '<DevEco Studio>\tools\hvigor\bin\hvigorw.bat' --no-daemon `
  --mode module -p product=default -p module=entry@default `
  -p buildMode=debug test
```

Generated local-test output is written under `entry/.test/` and is ignored by
Git.

仓库默认生成未签名 HAP，确保构建配置不依赖个人证书或密码。需要安装到真机时，
请在 DevEco Studio 中配置个人本地签名；不得提交 IDE 写入的签名配置或证书材料。

### 测试
目标框架：`@ohos/hypium` 1.0.19

`entry/src/test` 包含可在宿主机运行的领域契约测试。`entry/src/ohosTest`
仍为空，因为 Phase 0C 不需要设备测试运行器。

### 技术栈

- **开发语言**：ArkTS (.ets 后缀)
- **UI框架**：ArkUI
- **状态管理**：@Observed, @ObjectLink
- **双语支持**：内联 ternary 表达式
- **持久化**：AppStorage, PersistentStorage

## 使用说明

### 核心流程
1. **卡片兑换**：通过邀请码获取新数字卡片
2. **物理卡操作**：发现 -> 连接 -> 写入凭证
3. **二次验证**：外部应用触发的验证流程

### 邀请码格式
支持 `SLE-XXXX-XXXX` 格式的邀请码，包含预览和兑换功能。

### 物理卡操作
模拟 WS63 物理卡的完整操作流程，包括发现、连接、凭证写入和验证，包含各种失败模式和延迟模拟。

## 项目状态

- ✅ 核心功能开发完成
- ✅ 物理卡模拟实现
- ✅ 邀请码系统
- ✅ 二次验证流程
- ⏳ 测试覆盖
- ⏳ 生产级优化
