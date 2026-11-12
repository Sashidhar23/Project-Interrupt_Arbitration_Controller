# RC-Project---Interrupt-Arbitration-Controller

ZedBoard FPGA project using the PMOD ACL2, HYGRO and OLED. The repository contains the priority arbiter, common RTL, SPI master, ACL2 controller and simulation sources. The HYGRO/I2C path and combined sensor hub are included; OLED/UART and board-level integration remain.

- [Standalone HYGRO: simulation, JB wiring and LED outputs](docs/HYGRO_STANDALONE.md)
- [How ACL2/HYGRO connect to UART and OLED](docs/SYSTEM_DATA_FLOW.md)
- [Project structure and implementation status](PROJECT_STRUCTURE.md)
- [HYGRO controller, interfaces and hardware handoff](docs/HYGRO.md)
- [ACL2 controller and simulation instructions](docs/ACL2.md)
- [Two-person workflow](docs/ZedBoard_Two_Person_Workflow.pdf)
- [Arbiter simulation report](docs/Arbiter_Simulation_Report.pdf)

Run the ACL2 test from this directory with `vivado -mode batch -source scripts/run_xsim.tcl` or `sh scripts/run_iverilog.sh`. Hardware validation is pending. The original scope document predates the correction that the HYGRO uses timer-triggered acquisition.

Run the complete simulation suite with `sh scripts/run_regression.sh`. GitHub Actions also runs this suite and retains logs and waveforms. See [HYGRO instructions](docs/HYGRO.md) for the new files, timing assumptions and two-person handoff.

Test HYGRO independently with `vivado -mode batch -source scripts/run_hygro_xsim.tcl`. To create its hardware/simulation project in the Vivado Tcl Console, run `source scripts/create_hygro_project.tcl` from the repository root. This adds only the required sources; do not recursively add all RTL because `rtl/ACL2/` also contains standalone copies of several modules.
