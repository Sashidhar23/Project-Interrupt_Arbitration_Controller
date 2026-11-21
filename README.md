# Interrupt-driven arbitration controller for ZedBoard

ACL2 acceleration over SPI and HYGRO temperature/humidity over I2C are serviced
by a non-preemptive priority arbiter with aging. Latest readings appear together
on an external Pmod OLED. ACL2 uses its data-ready interrupt; HYGRO acquisition is
timer-triggered because this module has no data-ready interrupt output.

## Start here

- [Hardware and ILA/VIO demonstration](DEMO_START_HERE.md)
- [Arbitration testbench in the same ILA project](docs/ARBITRATION_SIMULATION.md)
- [Complete ILA probe/control map](docs/ILA_DEMO.md)
- [Build and simulation validation](docs/ILA_VALIDATION.md)
- [OLED wiring and normal operation](docs/OLED_INTEGRATION.md)

Connect ACL2 to JA, HYGRO to JB, and external Pmod OLED to JC. Check the actual
board VADJ setting against constraints/sensor_oled_zedboard.xdc. The JC pin-order
correction is included. The replacement ACL2 uses raw +/-2 g readings; no offset
from the earlier faulty module is applied. UART is not required or implemented.

## Existing ILA project

From this repository root in the already-open Vivado project:

```tcl
source scripts/attach_arbitration_testbench.tcl
```

Then Run Simulation > Run Behavioral Simulation. Source
scripts/arbitration_wave_setup.tcl using its full path to add waves and run the
self-checking OFF/ON test. Hardware top remains sensor_oled_top; only the
simulation top becomes tb_arbitration_demo. No new bitstream is needed for this.

## Create a project from source

From the repository root in Vivado's Tcl Console, choose one:

```tcl
source scripts/create_ila_project.tcl
```

This creates build/i/ila.xpr, generates ILA/VIO IP and includes the testbench.
For just normal sensor/OLED operation instead:

```tcl
source scripts/create_sensor_oled_project.tcl
```

Run synthesis, implementation and Generate Bitstream. The debug build requires
matching .bit and .ltx files from the same implementation. Full instructions are
in DEMO_START_HERE.md. Use a short extracted folder path on Windows. Generated
projects, IP, bitstreams and build caches are regenerated locally, not committed.
Do not recursively add all RTL: legacy standalone examples contain duplicate
modules. The scripts choose the canonical source files.

## Verify arbitration

With Icarus on PATH:

```text
python scripts/run_regression.py
```

Alternatively run `sh scripts/run_regression.sh`; GitHub Actions runs this suite.
The presentation bench uses the SAME arbiter RTL in parallel OFF/ON instances,
with identical persistent synthetic requests. Default simulation results:

| Aging | Channel 0 grants | Channel 1 grants | Maximum channel 1 pending wait |
|---|---:|---:|---:|
| OFF | 241 | 0 | 8192 cycles, unserved |
| ON | 181 | 60 | 103 cycles |

Synthetic stress results are not physical sensor throughput or latency. Real
sensor ILA captures establish integration; the controlled workload demonstrates
priority, exclusivity, non-preemption and service of the aging requester. A finite
test is not a universal liveness proof. OLED refresh shows cached sensor readings,
not simultaneous grants. The SPI and I2C buses are physically separate; this
arbiter serializes service rather than arbitrating an electrically shared bus.

The user has reported working sensor/OLED output and supplied OFF/ON ILA captures.
Automated simulation/build results are documented separately; exact hardware
counter measurements should be recorded in docs/DEMO_RESULTS.csv.
