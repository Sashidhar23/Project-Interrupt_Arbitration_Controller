# Run the arbitration testbench from this ILA folder

The presentation testbench is now included at sim/tb_arbitration_demo.sv.
It reuses this project's arbiter and benchmark modules; no duplicate RTL copies.
Hardware/ILA sources and the existing bitstream do not need changes.

New projects created by scripts/create_ila_project.tcl automatically include this
bench under Simulation Sources. Simulation top is tb_arbitration_demo; hardware
top remains sensor_oled_top.

For an existing ILA project, from the repository root in Vivado Tcl Console run:
`source scripts/attach_arbitration_testbench.tcl`
This updates the CURRENT open project; it does not create or reopen a project.

1. Select Run Simulation > Run Behavioral Simulation.
2. Source scripts/arbitration_wave_setup.tcl using its full path, for example:
   `source {C:/ArbDemo/scripts/arbitration_wave_setup.tcl}`
3. Look for PASS in the console. Zoom Fit for the full run, or 0.05-1.5 us for
   the initial grant decisions. No synthesis or new bitstream is required.

For a simulation-only project without ILA IP, the optional
scripts/create_arbitration_sim_project.tcl creates a separate project.

Both modes receive simultaneous, persistent synthetic requests. OFF is fixed
priority; ON enables aging. Grants: 00=idle, 01=channel 0, 10=channel 1; never 11.
Show priority1_on rising, then grant_on=10. An active transaction is not preempted.

Expected simulation results:

| Aging | Grants 0 | Grants 1 | Max wait 1 (cycles) |
|---|---:|---:|---:|
| OFF | 241 | 0 | 8192, unserved |
| ON | 181 | 60 | 103 |

Results are synthetic, not physical sensor traffic. The OFF run shows an unserved
request over a finite window, not an infinite-time proof. These parameters match
the hardware benchmark; the real sensor path has a different aging threshold.
The simulator writes arbitration_demo.vcd, arbitration_events.csv and
arbitration_results.csv into its working directory. For the full project
regression with Icarus on PATH, run `python scripts/run_regression.py`.

The copied bench previously passed Icarus and Vivado XSim; its integration here
is additionally checked with the shared RTL. See results/ila/tb_arbitration_demo.txt.
