> Historical normal OLED build report. For the current arbitration demonstration
> build, use ILA_VALIDATION.md and results/ila/.

# OLED integration validation — 19 November 2026

Base repository commit: `94f269ec443491583eb1e8607a08933d2d6317b3`.
These results describe the local OLED integration changes, not an upstream commit.

The physical JC OLED pin-order error in the earlier package was corrected on
19 November. Normal design routing was repeated with the corrected pins; the
reported timing below remains +0.982 ns setup / +0.106 ns hold. See OLED_PIN_FIX.md.

## Completed

- Icarus: **8/8 self-checking testbenches passed**: common, SPI, arbiter, ACL2,
  HYGRO, combined sensor hub, OLED text and complete sensor/OLED integration.
- Icarus: **5/5 hardware/demo tops elaborated**: hygro_test_top, acl2_test_top,
  sensor_oled_top, oled_test_top, oled_dbg_top.
- Vivado XSim 2025.2.1: **both new OLED benches passed** using the supplied
  `scripts/run_oled_xsim.py` direct runner.
- Vivado project creation: the supplied source/constraint project script completed.
  The project-based simulation launcher stalled locally; it was stopped and the
  supplied batch simulation entry point now uses the verified direct runner.
- Vivado synthesis and full place-and-route completed for `xc7z020clg484-1`.
- Routed timing at 100 MHz: **setup WNS +0.982 ns**, **hold WHS +0.106 ns**,
  zero failing setup/hold endpoints. Pulse-width slack +4.500 ns.
- Routed resources: **1,163 LUTs (2.19%)**, **1,021 registers (0.96%)**, **2 DSPs**.
- Routed default DRC: **no errors**; 3 warnings remain (two DSP pipelining
  recommendations and the PS7 warning for this PL-only design). See the report.

## What the new tests establish

The formatter test checks valid-only capture, independent sensor updates, signed
axis limits including -32768, temperature/RH endpoints, WAIT/ERR states and reset.
The integration test connects pin-level ADXL362 and HDC1080 models to the actual
hub/top. It decodes OLED SPI, verifies 512 zero bytes before panel enable, checks
all 512 pixel bytes of each of two subsequent frames, injects an ACL2 update
mid-frame and confirms it appears only in the following complete frame. It also
checks that HYGRO keeps producing samples while OLED refresh is active.

## Limits

Timing results apply to the checked-in constraints: 100 MHz internal clock,
20 ns peripheral output propagation budget, and documented asynchronous-input /
LED exceptions. They do not prove the external sensor/panel electrical timing.
No board was programmed or physically tested, no bitstream was delivered, and no
GitHub push was performed. Confirm module orientation, actual VADJ setting,
HYGRO pull-ups, visible OLED output and live sensor changes on your ZedBoard.
UART is outside this change. The OLED shows latest records, not every sample.

The local compilers required execution outside the restricted tool environment;
that limitation was resolved for the successful checks above.

## Evidence

Full timing, DRC, utilization and test outputs are in [results/oled](results/oled/).
Build/wiring instructions are in [OLED_INTEGRATION.md](OLED_INTEGRATION.md).
