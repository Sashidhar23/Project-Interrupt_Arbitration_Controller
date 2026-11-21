# Arbitration demo validation - 19 November 2026

## Software checks

The delivered scripts/run_regression.py passed all 10 self-checking benches:
common, SPI master, arbiter, ACL2 service, HYGRO service, sensor hub, OLED text,
sensor/OLED pin-level integration, synthetic stress demo and debug-wrapper wiring.
Five normal/legacy top-level elaboration checks passed as well.

The stress bench independently scores grant counts and pending waits, asserts
exclusive grants, non-preemption and ownership of completion, checks first-grant
priority, and runs OFF/ON/OFF to verify repeatability. The wrapper bench checks
VIO controls, live/test multiplexing, output counts and isolation of test aging
from real-sensor aging. Its IP stand-ins are simulation-only, not substitutes
for hardware validation of AMD ILA/VIO.

| Aging | Grants ch0 | Grants ch1 | Max wait ch0 | Max wait ch1 |
|---|---:|---:|---:|---:|
| OFF | 241 | 0 | 1 | 8192 (never served in window) |
| ON | 181 | 60 | 35 | 103 |

These are simulation observations with RUN_CYCLES=8192, SERVICE_CYCLES=32,
AGE_THRESH=16 and base priorities 7/1. They are not board measurements and not
real-sensor throughput/latency. Fairness means eventual service rather than equal
counts. The OFF window terminates an unserved wait, not a completed latency.

## Hardware build

Vivado 2025.2.1 completed scripts/build_ila.tcl for xc7z020clg484-1,
including generated ILA 6.2, VIO 3.0, synthesis and routing. The source project
uses ENABLE_DEBUG=1 and the corrected combined board constraints.

- Clock: 100 MHz; setup WNS +0.454 ns, hold WHS +0.037 ns.
- No failing setup/hold endpoints. Pulse-width slack +3.750 ns.
- 3817 LUTs, 5394 registers, 58 block RAM tiles, 2 DSPs.
- DRC: no errors or critical warnings. Seven warnings remain: two DSP pipeline
  recommendations, three LUT-term checks and one unroutable-load warning in debug
  infrastructure, plus the PS7 warning for a PL-only Zynq design. See full report.
- Build script verifies all package pins/IO standards and checks setup and hold
  paths before reporting success. Matching debug probes were exported.
- Project script uses short build/i paths to avoid Windows debug-core path limits.
  Extracting the delivered source to a short path is still recommended.

## Scope and remaining checks

- Replacement ACL2 uses +/-2 g with raw XYZ, without the faulty sensor's offset.
- OLED stays connected to real sensors; benchmark traffic stays internal.
- Board measurements and screenshots are still required. No FPGA was programmed
  by this verification and no bitstream is bundled. Generate the .bit and matching
  .ltx together after confirming the actual board VADJ setting.
- Run the guide's OFF/ON sequence and record actual counters in DEMO_RESULTS.csv.
- Capture real grants/completion as integration evidence. Synthetic benchmark
  captures must be labelled synthetic, even though the same arbiter RTL is used.
- Timing uses the combined 100 MHz constraints and documented asynchronous input
  exceptions/output propagation budget; it is not an external sensor timing proof.
- Live counters count service grants (including initialization), not fresh samples.
- A finite test does not prove liveness for arbitrary unbounded service durations.
- Build reports describe local verification; remote CI status is tracked separately.

Detailed verification outputs are in results/ila/. Build instructions and probe
mapping are in ILA_DEMO.md; the short presentation workflow is ../DEMO_START_HERE.md.

## 21 November simulation addition

Added tb_arbitration_demo to this folder and regression entry points. Its new
shared-RTL integration passed Icarus independently with OFF 241/0 and ON 181/60.
Production RTL is unchanged, so no FPGA rebuild is needed for this addition.
