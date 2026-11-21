# Show priority and aging on ZedBoard

This delivery targets the replacement ACL2: +/-2 g, raw XYZ, no old sensor's
1635-count correction. Start with ../DEMO_START_HERE.md for the walkthrough.

## Two things to demonstrate

1. **Real operation:** actual ACL2/HYGRO requests, priorities and grants, with live
   sensor values on the external Pmod OLED.
2. **Controlled benchmark:** a separate synthetic instance of the SAME `arbiter.v`
   receives identical saturated requests with aging disabled and enabled.

The benchmark is NOT physical sensor traffic. It runs beside the real acquisition
path and never drives sensor requests or bus pins. The OLED always shows real
sensor values. This distinction must be stated in the project demonstration.

## What was added and why

| Addition | Purpose |
|---|---|
| sensor_hub debug_eff0/debug_eff1 outputs | Make actual effective priorities observable |
| sensor_oled_top ENABLE_DEBUG parameter | Keep original normal build; enable debug hardware only in the debug project |
| rtl/debug/arbiter_debug.sv | Connect real/benchmark observations to ILA and VIO |
| rtl/debug/arbiter_metrics.sv | Count grant starts and current/maximum waiting cycles without altering arbitration |
| rtl/debug/arbiter_stress_demo.sv | Repeatable, synthesizable two-requester benchmark using the existing arbiter |
| ILA IP | Store clock-by-clock waveform samples and transfer them through JTAG |
| VIO IP | Change controls and view summary counts from Vivado, with no switches or UART |
| scripts/create_ila_project.tcl | Generate both IP cores and create a separate debug project |
| scripts/build_ila.tcl | Build through routing, export .ltx probes and check timing |
| sim/tb_arbiter_stress_demo.sv | Independently check priority, aging, non-preemption, counters and repeated runs |

ILA records; VIO controls/reads. No new external hardware is required beyond the
programming USB cable already used with the ZedBoard. Keep existing JA/JB/JC
wiring and the same combined XDC. UART is not required.

## Build the debug version

Open Vivado and change its Tcl Console directory to the extracted project root.

```tcl
source scripts/create_ila_project.tcl
```

This creates `build/i/ila.xpr`, top `sensor_oled_top`, with
`ENABLE_DEBUG=1`. It automatically generates ILA 6.2 and VIO 3.0 from Vivado's IP
catalog. Do not create a second ILA using Set Up Debug; one is already instantiated.
Keep the extracted project path short on Windows: Vivado debug-core temporary
paths have a stricter length limit than ordinary source files. The generated
project deliberately uses the short `build/i` directory.
Normal `create_sensor_oled_project.tcl` leaves ENABLE_DEBUG=0 and aging enabled.

Check VADJ_IOSTANDARD against the actual board jumper. Run Synthesis, Implementation
and review timing/DRC; then Generate Bitstream. For batch build through routing:

```text
vivado -mode batch -source scripts/build_ila.tcl
```

This writes reports and `build/ila_results/arbiter_ila.ltx`; it does not program
hardware or generate a bitstream. After Generate Bitstream, the bit file is normally
`build/i/ila.runs/impl_1/sensor_oled_top.bit`.
If building manually, open the implemented design and export probes with:

```tcl
write_debug_probes -force arbiter_ila.ltx
```

Always use a .bit and .ltx from the SAME build. Do not use the previous non-debug
bitstream: it has no ILA/VIO cores. Debug IP consumes additional FPGA memory and
logic, so the normal-build timing report does not validate this version.

## Connect in Hardware Manager

1. Power the board and connect the programming/JTAG cable (not the UART port).
2. Open Hardware Manager > Open Target > Auto Connect.
3. Program the FPGA with the debug .bit and associate its matching .ltx probes.
4. Open the ILA and VIO dashboards. Probe names may contain hierarchy prefixes;
   use the port-number tables below to identify them.
5. Set numeric counters/priority signals to unsigned decimal and req/grant/done
   to binary. At 100 MHz, one sample is 10 ns.

## VIO controls (output probes)

Commit each change in the VIO dashboard; editing a value alone may not drive it.

| Port | Signal | Default | Meaning |
|---|---|---|---|
| probe_out0 | test_start | 0 | Rising 0-to-1 transition starts a fresh benchmark |
| probe_out1 | test_aging | 1 | Benchmark aging setting; latched at start |
| probe_out2 | select_test | 0 | 0=observe real sensors; 1=observe synthetic benchmark |
| probe_out3 | live_aging_enable | 1 | Aging setting of the real sensor arbiter |

Keep live_aging_enable=1 for the normal project demonstration. Changing test_aging
has no effect on the real sensors. Changing it during a running benchmark has no
effect until the next run. A start while busy is ignored; lower test_start to 0
before starting again. Do not change select_test during an ILA capture.

## VIO readings (input probes)

| Port | Meaning |
|---|---|
| probe_in0 | Synthetic benchmark active (including final transaction drain) |
| probe_in1 | Synthetic benchmark finished |
| probe_in2 | Channel 0 grant count for the selected source |
| probe_in3 | Channel 1 grant count for the selected source |
| probe_in4 | Channel 0 maximum observed pending wait, clock cycles |
| probe_in5 | Channel 1 maximum observed pending wait, clock cycles |

With select_test=0, channels 0/1 are real ACL2/HYGRO. With select_test=1 they are
synthetic high/low-priority requesters. Refresh VIO input values after a run if
automatic refresh is disabled. Grant counts count ownership starts, not samples.
Maximum wait includes requests that were NEVER served within the test window.
Counters saturate at 2^32-1. Real counters reset with the top reset; benchmark
counters reset on each accepted start. The timestamp alone wraps after 42.95 s.

## ILA waveform probes

| Port | Width | Meaning |
|---|---:|---|
| probe0 | 8 | Context flags, decoded below |
| probe1 | 2 | req: bit 0 channel 0, bit 1 channel 1 |
| probe2 | 2 | grant: 01 channel 0, 10 channel 1, 00 idle; never 11 |
| probe3 | 2 | done pulses |
| probe4 | 9 | Channel 0 effective priority |
| probe5 | 9 | Channel 1 effective priority |
| probe6 | 32 | Selected source timestamp in 100 MHz cycles |
| probe7 | 32 | Channel 0 current pending wait |
| probe8 | 32 | Channel 1 current pending wait |
| probe9 | 1 | Accepted benchmark start (trigger signal) |

probe0 bits: [0] select_test, [1] selected aging mode, [2] benchmark active,
[3] benchmark finished, [5:4] real sensor fault, [7:6] real sensor initialized.
During the start trigger, the latched mode changes on the following cycle; inspect
it while benchmark-active is high. Fault/init bits always describe real sensors.

All probes use one shared input pipeline stage, so their relative alignment is
preserved. State, grants and observer counters update on clock edges; counters
can appear one cycle behind a displayed grant edge. The recorder has 16,384
samples = 163.84 microseconds at 100 MHz. It is a finite capture, not a continuous
serial logger. For real transactions longer than this window, trigger close to
the grant or take additional captures; do not assume the whole wait fits.

## Repeatable OFF / ON demonstration

The benchmark continuously requests both channels for 8,192 clocks (81.92 us).
Base priorities: channel 0=7, channel 1=1. Aging step: 16 waiting clocks (160 ns).
Both service engines use the same 32-clock service parameter. The active owner
finishes before the test stops. These accelerated parameters are for the synthetic
benchmark only; the real sensor top retains its 1,000-clock aging step.

### Capture A: fixed priority

1. VIO: select_test=1, test_start=0, test_aging=0. Leave live_aging_enable=1.
2. ILA: full 16,384-sample window; capture all samples; trigger on probe9==1.
   Put the trigger at sample 2,048 to retain pre-trigger context and the full run.
3. Click Run Trigger to arm ILA, then commit test_start=1 in VIO.
4. Wait for capture completion; refresh VIO readings. Save waveform and counts.
5. Expected: both requests high, first grant 01, no channel 1 grants.

### Capture B: aging enabled

1. Commit test_start=0, then test_aging=1. Keep select_test=1.
2. Arm the same ILA trigger, then commit test_start=1.
3. Save waveform and counts. Channel 1 effective priority increases while waiting.
4. It eventually receives grant 10. Channel 0's active transaction is not
   interrupted: the change of owner follows done and the idle decision interval.
5. At equal effective priorities, the least-recently-served channel wins the tie;
   channel 1 need not exceed priority 7 before being served. Aging bonuses clear
   after grant or request removal, so inspect effective priority immediately
   before selection rather than only after it resets.

Expected results from the independently checked simulation of this exact benchmark:

| Mode | Channel 0 grants | Channel 1 grants | Max wait ch0 | Max wait ch1 |
|---|---:|---:|---:|---:|
| OFF | 241 | 0 | 1 cycle | 8192 cycles (unserved) |
| ON | 181 | 60 | 35 cycles | 103 cycles |

Fairness here means avoiding starvation, not equal grant counts: the higher-priority requester still receives more service.

These are simulation predictions for the default hardware benchmark, NOT measured
board results. Record actual VIO/ILA results after programming. The OFF row is a
finite stress window, not a proof about infinite-time behavior. Latency/fairness
bounds depend on priorities, aging threshold and bounded service durations.

## Observe the actual sensors

Set select_test=0 and live_aging_enable=1. Trigger on probe1==binary 11 to see
contention, or on probe2==binary 10 to observe HYGRO ownership. Keep capture-all
selected. If both requests rarely overlap, the contention trigger may keep waiting;
use a grant trigger instead. Tilting ACL2 changes data, not necessarily its configured
interrupt rate. Real sensor operation is not guaranteed to produce starvation.

The OLED continues to show real XYZ, temperature and humidity throughout both
modes. It is not a display of the synthetic benchmark. Use the benchmark to create
repeatable contention and real-mode waveforms to establish actual integration.

## Evidence to show your evaluator

- Real OLED readings changing with sensor input.
- One real ILA capture identifying ACL2/HYGRO requests and grants.
- OFF/ON benchmark captures and VIO count table, labelled SYNTHETIC BENCHMARK.
- A zoom showing priority increase, final done, and the waiting requester's grant.
- Show grants never overlap and the current owner keeps its grant until done.

See ILA_VALIDATION.md for completed checks and remaining board checks.

References: [AMD ILA/VIO RTL integration](https://docs.amd.com/r/2024.1-English/ug1393-vitis-application-acceleration/Adding-Debug-IP-to-RTL-Kernels),
[AMD VIO controls](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Interacting-with-VIO-Core-Output-Probes),
[AMD ILA capture](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Viewing-Trigger-and-Capture-Status).

## Run the benchmark without hardware

The full regression includes the new test. With Icarus on PATH, from the repository
root (create the build directory first if needed):

```text
iverilog -g2012 -s tb_arbiter_stress_demo -o build/tb_arbiter_stress_demo rtl/control/arbiter.v rtl/debug/arbiter_metrics.sv rtl/debug/arbiter_stress_demo.sv sim/tb_arbiter_stress_demo.sv
vvp build/tb_arbiter_stress_demo
```

This produces PASS lines and build/arbiter_stress_demo.vcd for waveform inspection.
It does not simulate the proprietary ILA/VIO cores; Vivado generates those for the
hardware build. Repeated VIO starts reset only the benchmark: do not press BTNC
between OFF/ON runs, since that also restarts actual sensor acquisition.

Windows regression: install Icarus on PATH, then run `python scripts/run_regression.py`.
The simulation-only IP stand-ins in tb_arbiter_debug.sv are not hardware sources.
