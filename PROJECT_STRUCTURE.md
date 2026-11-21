# Repository structure and next handoff

The acquisition milestone now includes ACL2, HYGRO and their combined sensor hub.
One folder contains hardware sources, and another contains simulation-only
models and benches. Keep device models out of synthesis sources.

| Location | Current files | Remaining project files / purpose |
|---|---|---|
| rtl/common/ | config_pkg.sv, reset_sync.sv, sync_input.sv, sync_fifo.sv | Shared records, timing, reset, synchronization and buffering |
| rtl/control/ | arbiter.v | Keep its tested req/grant/done interface and additive aging policy. Add a dispatcher only if a new interface needs one. |
| rtl/bus/ | spi_master.v, i2c_master.sv | SPI byte transport and open-drain I2C transactions with timeouts |
| rtl/sensors/ | adxl362_ctrl.v, hygro_service.sv | Interrupt-driven ACL2 and scheduled HYGRO acquisition |
| rtl/OLED/srces/ | sensor_oled_text.sv, oled_acl2_view.sv, bin2bcd12.sv | Live four-row display; one writer snapshots both sensor caches. UART output remains. |
| Display font | Inline in oled_acl2_view.sv | No separate font memory file needed |
| rtl/debug/ | arbiter_metrics.sv, arbiter_stress_demo.sv, arbiter_debug.sv | Optional ILA/VIO observer, live counters and separate synthetic OFF/ON benchmark |
| rtl/axi/ and sw/ | Planned for onboard USB-UART | axi_regs.sv; main.c, pl_regs.h and pl_irq.c/.h for the PS UART1 bridge |
| rtl/ (top levels) | sensor_hub.sv, hygro_test_top.sv, ACL2/acl_top.sv | sensor_oled_top.sv adds combined sensor/OLED integration; UART remains |
| constraints/ | hygro_jb.xdc | sensor_oled_zedboard.xdc adds ACL2 JA, HYGRO JB and OLED JC |
| sim/arbiter/ | arb_system.v, synth_requester.v, tb_arbiter.v | Preserve the synthetic arbitration regression |
| sim/ and sim/models/ | tb_spi_master.v, tb_acl2_service.sv, adxl362_model.sv | Added: hdc1080_model.sv, tb_hygro_service.sv and tb_sensor_hub.sv. Remaining: tb_system_stress.sv |
| scripts/ | run_xsim.tcl, run_iverilog.sh, run_regression.sh | Later add full-project build and measurement scripts |
| docs/ and results/ | Planned | Wiring, interfaces, register map, test plan, raw logs, plots and configuration manifest |

## Two-person handoff

- Person A: run the new ACL2 test, capture an ID-read waveform, then verify the
  interrupt burst and signed XYZ on the ZedBoard. Use the existing SPI engine
  as the byte transport and the new controller as CS owner.
- Person B: run the HDC1080/I2C regression and bring up HYGRO on channel 1.
  First prove an ID read and trigger/wait/read sequence.
- Joint: start HYGRO conversion, release its grant, service ACL2 during that
  wait, then grant HYGRO's result read. Compare records and ownership signals
  with a scoreboard. Use sensor_oled_top for OLED integration; integrate UART separately.

For the original arbiter regression, compile rtl/control/arbiter.v plus all
three files in sim/arbiter/ and select tb_arbiter as top. For SPI loopback,
compile rtl/bus/spi_master.v and sim/tb_spi_master.v with tb_spi_master as top.

Standalone HYGRO setup is in scripts/create_hygro_project.tcl, scripts/run_hygro_xsim.tcl and scripts/run_hygro_iverilog.sh. See docs/HYGRO_STANDALONE.md and docs/SYSTEM_DATA_FLOW.md. The scripts select canonical RTL files explicitly to avoid duplicate module definitions in rtl/ACL2/.

For arbitration evidence, use scripts/create_ila_project.tcl and docs/ILA_DEMO.md.
