> Current demo uses the replacement ACL2 at +/-2 g with raw XYZ and no
> old-module Z-offset correction. See ../DEMO_START_HERE.md for ILA/VIO.

# Live ACL2 + HYGRO OLED integration

## What this adds

`rtl/sensor_oled_top.sv` connects the existing `sensor_hub` to a single OLED writer.
ACL2 and HYGRO retain their existing priority-with-aging req/grant/done interface.
A latest-value cache captures each sensor only on its sample-valid pulse. The OLED
uses a 19-clock shift/add-3 decimal converter (no long division chain), then
snapshots all four text rows at the start of a frame, so a new sample cannot mix
old and new values within that transmitted frame. Acquisition continues while the
OLED writes its dedicated SPI bus. There is no second arbiter inside the display:
one writer owns it, and both sensors have reserved fields in every frame.

This is a latest-reading display, not a lossless sample logger. Intermediate
samples may be replaced before the next display refresh. The two sensor records
are independently sampled, not measurements of the same instant. The panel itself
updates page by page; the snapshot guarantees coherent transmitted data, not an
instantaneous screen-wide swap.

Example (21 characters per row):

```text
X=-00123 Y=+00456
Z=+02047 A:OK
T=+026.0C H:OK
RH=050.0%
```

XYZ are signed raw accelerometer counts. Temperature is degrees C; humidity is
percent RH, both shown to one decimal. HDC1080 conversions use T=raw*165/65536-40
and RH=raw*100/65536, truncated to tenths (temperature scaled term rounded down
before offset subtraction). `WAIT` and dashes mean no sample yet; `ERR` reports
the controller fault. After a fault, displayed numbers are the last valid sample.
An absent ACL2 interrupt alone does not assert a fault: stale-data detection is
not implemented. `OK` means initialized and at least one valid sample received.

## Files

| File | Purpose |
|---|---|
| rtl/sensor_oled_top.sv | Complete PL sensor + display board top; aging enabled |
| rtl/OLED/srces/sensor_oled_text.sv | Valid-driven caches, numeric conversion, status and four text rows |
| rtl/OLED/srces/oled_acl2_view.sv | Reused renderer/SPI; optional external text input, frame snapshot, additional glyphs, clear-before-power sequence |
| rtl/OLED/srces/bin2bcd12.sv | Existing converter retained for legacy display mode |
| constraints/sensor_oled_zedboard.xdc | Combined, nonoverlapping JA/JB/JC pins |
| scripts/oled_sources.tcl | Canonical synthesis source manifest |
| scripts/create_sensor_oled_project.tcl | Creates Vivado hardware/simulation project |
| scripts/run_oled_xsim.py / .tcl | Direct XSim regression runner (Python 3 standard library) |
| scripts/check_sensor_oled_synth.tcl | Synthesis, utilization, timing and DRC reports |
| scripts/check_sensor_oled_route.tcl | Place-and-route check from the synthesized checkpoint |
| sim/tb_sensor_oled_text.sv | Formatting, limits, valid gating, independent updates, reset and faults |
| sim/tb_sensor_oled.sv | Actual sensor models through hub to decoded OLED SPI frames |

The standalone `oled_test_top` and `oled_dbg_top` still support fixed-pattern
bring-up. The new renderer port is tied off there; EXTERNAL_TEXT defaults to 0.
Use the source manifest; do not recursively add RTL folders containing duplicate
module names, especially the extra reset_sync files.

## Wiring

Use the external **Pmod OLED**, not the ZedBoard onboard OLED, for this XDC.
Power off before connecting the modules; align pin 1 and both power/ground rows.

| Module | Header | Signal connections |
|---|---|---|
| ACL2 | JA | 1 CS, 2 MOSI, 3 MISO, 4 SCLK, 8 INT1 |
| HYGRO | JB | 3 SCL, 4 SDA; enable the module pull-up links |
| OLED | JC | 1 CS, 2 SDIN, 4 SCLK, 7 DC, 8 RES, 9 VBATC, 10 VDDC |

OLED package pins respectively: AB7, AB6, AA4, R6, T6, T4, U4.
The JC signal labels in the master XDC use differential-pair names; here they
are individual LVCMOS33 signals in physical connector order.
Pmod power is 3.3 V. Set `VADJ_IOSTANDARD` in the combined XDC to match the actual
board jumper for BTNC (default file value LVCMOS18). Load **only** the combined
XDC for this top; existing standalone OLED JA/JB constraints conflict with sensors.

Pin/reference sources:
- [Digilent ZedBoard master constraints](https://github.com/Digilent/digilent-xdc/blob/master/Zedboard-Master.xdc)
- [Digilent PmodOLED manual](https://digilent.com/reference/_media/pmod:pmod:pmodoled_rm.pdf)
- [TI HDC1080 datasheet](https://www.ti.com/lit/ds/symlink/hdc1080.pdf)

## Build and run

In Vivado's Tcl Console, from the repository root:

```tcl
source scripts/create_sensor_oled_project.tcl
```

The hardware top is `sensor_oled_top`. The script uses ZedBoard part
`xc7z020clg484-1`, a 100 MHz clock, canonical modules and the combined XDC.
Run Synthesis, Implementation, review timing/DRC, then Generate Bitstream and
program using Hardware Manager. No PS application is required for OLED output.
No bitstream is included as a substitute for checking your board's VADJ setting.

Simulation from a Vivado command shell (Python 3 required for this batch runner):

```text
vivado -mode batch -source scripts/run_oled_xsim.tcl
```

You can also run `python scripts/run_oled_xsim.py` in that shell, or pass `--vivado-bin "path/to/Vivado/bin"`.
Use `run all` if launching simulation interactively. The default simulation top
is `tb_sensor_oled`; select `tb_sensor_oled_text` for the formatter unit test.
The complete portable regression is `sh scripts/run_regression.sh`.
For synthesis-only reports:

```text
vivado -mode batch -source scripts/check_sensor_oled_synth.tcl
```

For an implementation check after synthesis, run `vivado -mode batch -source scripts/check_sensor_oled_route.tcl`. This produces routed reports/checkpoint without programming hardware.

Peripheral outputs have a 20 ns register-to-pin propagation budget, well below
the default bus phase lengths. They are not modeled as external 100 MHz receivers. The async input
exceptions follow the existing synchronized slow-bus architecture; they are not
a proof of peripheral setup/hold timing. Review implementation timing and verify
SPI/I2C edges on hardware before treating the system as board-validated.

## LEDs and reset

| LED | Meaning |
|---|---|
| 0 | OLED initialization commands completed (write-only panel; not an acknowledgement) |
| 1 | A sensor currently owns the acquisition grant |
| 2 / 3 | ACL2 / HYGRO initialized |
| 4 / 5 | ACL2 / HYGRO fault |
| 6 / 7 | Toggle on each valid ACL2 / HYGRO sample |

BTNC holds acquisition/cache reset until about 10 ms after release. It does not
cycle OLED power; the display keeps refreshing and shows WAIT until new samples.
The pre-existing ACL2 controller does not issue a sensor soft reset; use a cold
board start for initial bring-up, and verify warm-restart behavior separately.
At startup, the renderer resets/configures the OLED, clears 512 RAM bytes, enables
panel power, waits 100 ms and turns the display on. Hardware timings are shortened
only through explicit parameter overrides in the testbench.

## What is still outside this change

UART integration, lossless output logging, hardware metrics and physical-board
validation remain. No remote repository push or board programming is performed.
See OLED_VALIDATION.md for the checks actually completed.

## Optional arbitration demonstration

Use `scripts/create_ila_project.tcl` for real-signal ILA observation plus a separate
synthetic OFF/ON benchmark. See [ILA_DEMO.md](ILA_DEMO.md). The normal project keeps
aging enabled and includes no debug IP.
