# NearLink build and real-device test

## App build

The repository intentionally uses the Hvigor bundled with DevEco Studio and does not check in a custom wrapper or Hvigor JAR. From the repository root, run:

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --no-daemon --mode module -p product=default -p module=entry@default `
  -p buildMode=debug assembleHap
```

The repository build is unsigned. Configure local signing in DevEco Studio when installing on a device, and do not commit the generated signing configuration or certificate material. Do not use an emulator as final NearLink verification; use a Huawei phone or tablet that supports NearLink.

## Firmware build and flash

From `D:\bearpi-pico_h3863A` run:

```powershell
$env:PATH = 'C:\Program Files\HiSpark Studio\tools\Windows\cc_riscv32_musl_fp_win\bin;' + $env:PATH
python build.py ws63-liteos-app
```

The temporary `PATH` prefix supplies `libssp-0.dll`, which is absent from the repository's RISC-V toolchain `bin` directories.

Flash `output\ws63\fwpkg\ws63-liteos-app\ws63-liteos-app_all.fwpkg` using the BearPi/HiSpark serial flashing flow. Open the 115200 baud serial console and confirm:

```text
[SLEKEY][INIT] SLE initialized
[SLEKEY][SERVER] SSAP service registered
[SLEKEY][ADV] advertising started
```

## Acceptance sequence

1. Enable NearLink manually in system settings.
2. Open the App's “临时连接” page and tap Scan.
3. Confirm `SLEKEY-A`, its address, and RSSI appear.
4. Tap Connect; confirm the firmware logs `client connected`.
5. Confirm the App progresses `CONNECTING -> CONNECTED -> HANDSHAKING -> READY`.
6. Confirm firmware RX `type=0x01` and TX `type=0x81` use the same sequence.
7. Tap “测试通信”; confirm RX `0x02` and TX `0x82` use the same next sequence.
8. Tap Disconnect and verify both sides report disconnected.
9. Scan and connect again to verify listeners, timers, and the old client were released.

Only after all nine steps pass on real hardware may the result be described as an end-to-end in-app NearLink connection loop.
