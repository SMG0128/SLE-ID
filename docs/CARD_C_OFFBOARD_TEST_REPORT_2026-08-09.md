# Card C 无第三块板测试报告

测试日期：2026-08-09  
SDK：`D:\hispark\sdk\fbb_ws63\src`  
目标：`ws63-liteos-app`

## 结论

在没有第三块实体板的条件下，已完成 Card C 的主机自动化、NV 配置核查和官方 SDK 三配置真实构建。源码可编译、可链接、可签名、可封装；RAM 联调、NV 个性化和 NV 生产锁定固件均已生成。

本轮发现生产锁定配置中的一个真实缺陷：关闭 `SLE_CARD_SERIAL_PROVISIONING` 后，`hex_decode()` 不再被调用，但仍参与编译，导致 SDK 的 `-Werror=unused-function` 中止构建。现已将十六进制解析函数放入相同条件编译块，修复后主机回归和锁定版全量构建均通过。

## 已执行测试

- A/B Protocol V2 与业务核心测试：通过。
- Card 凭证双槽存储、故障注入和服务命令测试：通过。
- HMAC-SHA-256、认证幂等、防重放和使用次数提交测试：通过。
- B↔Card 密码学互操作及 A 认证中继测试：通过。
- B 单 USB 管理端网关及 DTO 映射测试：通过。
- Card 串口写卡工具 DryRun：通过。
- NV 核查：`0x5C10/0x5C11` 位于 SDK 用户普通区、无精确冲突，768 字节槽长低于 4060 字节单项上限。

## SDK 构建结果

三次构建均出现：

```text
Build target:ws63_liteos_app success
packet success!
```

产物及 SHA256：

```text
1ED0AED1CBF0F45468FA28D03C82B951031F1E20DE10C4C1048E71B942830B89  card_c_h3863_ram_all.fwpkg
9153D8374837ACEBAC9EA9DB79315583B16007F33672C3C2F02CA21408FFBE1F  card_c_ws63_nv_provisioning_all.fwpkg
5421DAD234AF71293C3EBCCDBA5A2D8F5950B671081E15181551D83C95286113  card_c_ws63_nv_locked_load_only.fwpkg
```

NV 两种配置均编入 `ws63_card_nv_port.c` 并成功生成 NV 镜像。个性化包开启本地串口写卡并包含 NV 分区；锁定包关闭该入口，只交付不覆盖 NV 分区的 `load_only` 包。

锁定版最终内存占用：ITCM 79.30%，DTCM 91.04%，SRAM 34.98%，PROGRAM 58.10%，均未超出链接区域。

## 无实体板无法替代的测试

- 广播名、服务发现、配对、四特征 UUID、CCCD 通知和真实 SLE 收发。
- NV 首次写卡后的复位/断电保持、双槽掉电回退和长期写入寿命。
- 先烧录个性化全量包、再烧录锁定 `load_only` 包后凭证不被覆盖。
- A 同时维持 B 与 Card 两条真实 SLE 连接的三端整链路。

因此当前状态为“离板验证通过、固件可交付测试”，不能标记为“第三块板实机验收通过”。
