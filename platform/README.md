# 平台适配层

在接入 WS63 SDK 时，只在这个目录实现适配：

- `sle_adapter`：扫描、广播、连接、GATT 服务和 A↔B 链路。
- `cs_adapter`：将 Channel Sounding SDK 回调转为距离/质量/时间特征。
- `storage_adapter`：Flash 原子写入、CRC、掉电恢复。
- `usb_adapter`：CDC/串口收发、帧边界和重连事件。
- `io_adapter`：GPIO、继电器、LED、蜂鸣器和外设动作回执。
- `clock_watchdog_adapter`：单调时钟、RTC、看门狗、低功耗唤醒。

不要在此层实现权限或场景判断；平台层只报告事实和执行底层动作。
