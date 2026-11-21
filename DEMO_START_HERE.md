# Arbitration and aging demonstration

Use this package for the REPLACEMENT ACL2: +/-2 g, raw XYZ, NO 1635 offset.
The previous calibrated package was for the faulty original module. Do not use
its bitstream with this replacement. ACL2=JA, HYGRO=JB, external PmodOLED=JC.

## What you can demonstrate

1. Real sensors produce XYZ, Celsius and humidity on the OLED.
2. Real ILA signals show requests, grants, effective priorities and completion.
3. A controlled, SYNTHETIC two-requester test using the same arbiter RTL forces
   persistent contention. Compare aging OFF/ON with identical offered workload.

The synthetic requester channels are not physical ACL2/HYGRO transactions.
They never drive the real sensor buses. OLED output always remains real sensor
values. Do not describe the benchmark counts as physical sensor throughput.

## Build once

Extract to a short folder on Windows (for example C:/ArbDemo, if writable).
Open Vivado and in its Tcl Console change to the extracted project folder.
Run: `source scripts/create_ila_project.tcl`
The script creates build/i/ila.xpr, top sensor_oled_top, ENABLE_DEBUG=1,
and generates ILA/VIO IP automatically. Do NOT use Set Up Debug to add another ILA.
Check VADJ_IOSTANDARD in constraints/sensor_oled_zedboard.xdc against your board.
Run Synthesis > Implementation > Generate Bitstream. Open the implemented design
and export probes: `write_debug_probes -force arbiter_ila.ltx`
Program Hardware Manager with:
- build/i/ila.runs/impl_1/sensor_oled_top.bit
- arbiter_ila.ltx from THAT SAME build
The programming/JTAG USB connection is sufficient. No UART or extra modules.

For automated checking through routing: `source scripts/build_ila.tcl` creates
reports and build/ila_results/arbiter_ila.ltx, but does not generate the bitstream.
Do not source build_ila.tcl after starting manual runs: it recreates the project.

## Demonstration: real acquisition

Open VIO and ILA dashboards. Use probe numbers if Vivado shows hierarchy names.
VIO outputs: out0=start, out1=test aging, out2=source, out3=real aging.
Set out2=0 and out3=1. Keep other defaults.
The OLED should show real changing sensor data. All XYZ are raw +/-2 g counts.
In ILA, probe1=requests, probe2=grants, probe3=completion, probe4/5=priorities.
Trigger on probe2 == binary 10 (HYGRO grant), capture all samples.
Capture another run on 01 (ACL2 grant). Neither grant should overlap the other.
A trigger on req=11 can show real contention, but may wait if the sensors do not
happen to overlap. Real transactions can exceed the finite 163.84 us capture;
use captures near grant/completion edges to show the relevant events.

## Demonstration: persistent contention

Set ILA data depth 16384, trigger position 2048, capture ALL samples (no qualifier).
Trigger on probe9 == 1. Probe9 is the accepted benchmark start.
Commit VIO edits (typing a value without committing may not drive it).

First run, aging OFF:
1. VIO out2=1, out0=0, out1=0. Keep out3=1.
2. Arm ILA with Run Trigger.
3. Set out0=1 and commit. Wait for ILA capture; refresh VIO inputs.
4. Save the waveform and counters. VIO in1=1 means the test finished.

Second run, aging ON:
1. Commit out0=0, then out1=1. Leave out2=1, out3=1.
2. Re-arm ILA; set out0=1 and commit.
3. Save the second waveform and counters. Do not press board reset between runs.

VIO inputs: in0=test active, in1=test finished, in2/3=grant counts ch0/ch1,
in4/5=max waiting cycles ch0/ch1. Use unsigned decimal for counters/priorities;
use binary for requests/grants/done. One cycle = 10 ns.

Expected SIMULATION results, to compare with your actual hardware measurements:

| Aging | Grants ch0 | Grants ch1 | Max wait ch0 | Max wait ch1 |
|---|---:|---:|---:|---:|
| OFF | 241 | 0 | 1 | 8192 (unserved) |
| ON | 181 | 60 | 35 | 103 |

The test holds both requests for 8192 clocks, then drains the active transaction.
The high-priority requester still receives more service. Fairness here means
avoiding starvation, not equal service counts. In OFF mode the low-priority
requester's wait is censored by the test ending; it is not a completed latency.
Actual board results have not been collected by this package's validation.

## What to point at in the waveform

- Both requests are 11. First grant is 01: base priority 7 beats 1.
- With aging OFF, channel 1 remains waiting throughout the observation window.
- With aging ON, probe5 increases while channel 1 waits; a later grant is 10.
- Grant is never 11; an owner retains its grant until done.
- Priority bonus clears on grant: inspect the priority BEFORE the grant edge.
  Ties use least-recently-served selection, so priority need not strictly exceed 7.

Benchmark aging threshold is 16 clocks to fit a full test in ILA. Real sensor
aging threshold stays 1000 clocks. Service durations also differ. Do not report
benchmark waiting time as measured real-sensor latency. The simulation bench
checks counters independently, repeated starts, priority-first, exclusive grants
and non-preemption. A finite demo is evidence for the specified workload, not a
universal proof for unbounded transactions or every possible parameter setting.

## Files added and why

- rtl/debug/arbiter_metrics.sv: passive grant counts and current/maximum wait.
- rtl/debug/arbiter_stress_demo.sv: repeatable simultaneous, persistent requests.
- rtl/debug/arbiter_debug.sv: source selection and generated ILA/VIO connections.
- sensor_hub effective-priority outputs: expose real arbitration decisions.
- sensor_oled_top ENABLE_DEBUG: select debug hardware; normal operation defaults
  to aging enabled. Replacement sensor has no old-module offset correction.
- scripts/create_ila_project.tcl and build_ila.tcl: reproducible debug build.
- sim/tb_arbiter_stress_demo.sv: independent arbitration/metrics scoreboard.
- sim/tb_arbiter_debug.sv: simulation-only IP stand-ins check control/mux wiring.
  Never add this testbench to synthesis sources.
- docs/ILA_DEMO.md: complete probe map and detailed capture instructions.

## Save evidence

Fill docs/DEMO_RESULTS.csv with hardware measurements. Save OFF/ON waveform
screenshots or ILA exports, one real-sensor waveform, and an OLED photo.
Use docs/ILA_VALIDATION.md for software/build verification status.
Return VIO out2=0, out3=1 for real-sensor observation after the demonstration.

## Simulation-only presentation

The same folder now includes sim/tb_arbitration_demo.sv. Follow
docs/ARBITRATION_SIMULATION.md; no board or new bitstream is needed.
