# Repository structure and next handoff

The controller in rtl/sensors/adxl362_ctrl.v is the next implementation step.
One folder contains hardware sources, and another contains simulation-only
models and benches. Keep device models out of synthesis sources.

| Location | Included in this ZIP | Remaining project files / purpose |
|---|---|---|
| rtl/common/ | config_pkg.sv, reset_sync.sv, sync_input.sv, sync_fifo.sv | Shared records, timing, reset, synchronization and buffering |
| rtl/control/ | arbiter.v | Keep its tested req/grant/done interface and additive aging policy. Add a dispatcher only if a new interface needs one. |
| rtl/bus/ | spi_master.v | Add i2c_master.sv for open-drain transfers, ACK/NACK and timeouts |
| rtl/sensors/ | adxl362_ctrl.v | Add hygro_service.sv for trigger, timed conversion wait and result read |
| rtl/output/ | Planned | record_fanout.sv, uart_record_mux.sv, oled_update_mux.sv, value_format.sv, oled_driver.sv, font_rom.sv |
| assets/ | Planned | font8x8.mem for display glyphs |
| rtl/metrics/ | Planned | metrics.sv and traffic_gen.sv for board counters and controlled stress traffic |
| rtl/axi/ and sw/ | Planned for onboard USB-UART | axi_regs.sv; main.c, pl_regs.h and pl_irq.c/.h for the PS UART1 bridge |
| rtl/ (top levels) | Planned | sensor_hub.sv for portable integration; zedboard_top.sv for board wiring |
| constraints/ | Planned | zedboard_pmods.xdc with verified package pins, I/O standards and clocks |
| sim/arbiter/ | arb_system.v, synth_requester.v, tb_arbiter.v | Preserve the synthetic arbitration regression |
| sim/ and sim/models/ | tb_spi_master.v, tb_acl2_service.sv, adxl362_model.sv | Next: hdc1080_model.sv, tb_hygro_service.sv, tb_sensor_hub.sv and tb_system_stress.sv |
| scripts/ | run_xsim.tcl, run_iverilog.sh | Later add full-project build and measurement scripts |
| docs/ and results/ | Planned | Wiring, interfaces, register map, test plan, raw logs, plots and configuration manifest |

## Two-person handoff

- Person A: run the new ACL2 test, capture an ID-read waveform, then verify the
  interrupt burst and signed XYZ on the ZedBoard. Use the existing SPI engine
  as the byte transport and the new controller as CS owner.
- Person B: model the HDC1080 and implement I2C plus hygro_service on channel 1.
  First prove an ID read and trigger/wait/read sequence.
- Joint: start HYGRO conversion, release its grant, service ACL2 during that
  wait, then grant HYGRO's result read. Compare records and ownership signals
  with a scoreboard. Integrate UART/OLED once this test passes.

For the original arbiter regression, compile rtl/control/arbiter.v plus all
three files in sim/arbiter/ and select tb_arbiter as top. For SPI loopback,
compile rtl/bus/spi_master.v and sim/tb_spi_master.v with tb_spi_master as top.
