# A/B 与 Card C 组件隔离修复记录

日期：2026-08-13

## 问题现象

Detector B 启动日志同时出现 `[B]` 和 `[C]`，Card C 初始化返回错误：

```text
[B] boot: SLE server, ...
[C] boot card=... service_init=-2147459068
```

A/B 固件不应启动独立 Card C 应用。两个 SLE 服务同时初始化会争用协议栈资源，可能导致服务注册失败、连接不稳定或后续行为不可预测。

## 根因与修复

- A、B 的 SDK 配置曾同时启用 `CONFIG_SAMPLE_SUPPORT_SLE_AB` 和 `CONFIG_SAMPLE_SUPPORT_SLE_CARD`。
- A、B 配置现已明确设置 `# CONFIG_SAMPLE_SUPPORT_SLE_CARD is not set`。
- 发布重编译脚本会强制关闭 Card C，并在构建后扫描链接产物；发现 `sle_card_entry` 或 `h3863_sle_card` 即中止发布。

## 验证结果

- A/B/Card 主机自动化测试全部通过。
- A、B 均已使用官方 SDK 完成清理、编译、签名和打包。
- 最终 A/B 配置均确认 Card C 未启用。
- 最终 A/B 链接产物未发现 Card C 入口符号。

## 新固件

```text
5D4B54D56A06E5117154A446EEDB216C36DF4AD8524D170EF32BEFF59341F949  detector_a_h3863_all.fwpkg
2C49CB51DBAC604295CF4FAB75DDE4A7858EC330A25A7F86A17D5F1275E0B3E3  detector_b_h3863_all.fwpkg
```

旧 A/B 包应停止使用，两块板均需重新烧录。修复后的 A、B 启动日志都不应出现任何 `[C]` 行。
