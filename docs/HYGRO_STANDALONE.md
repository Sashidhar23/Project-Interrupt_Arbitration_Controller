# Standalone HYGRO test within the main project

You can complete and test this part without ACL2, OLED, UART, ARM software,
or your teammate's hardware. The arbiter is included as a dependency: channel
0 is tied idle and HYGRO uses channel 1. This preserves the interface needed
for later integration. Do not tie grant permanently high: this service waits
for grant to fall after done.

## Files to use

| File | Role | Vivado category |
|---|---|---|
| rtl/common/reset_sync.sv | Reset release synchronization | Design |
| rtl/common/sync_input.sv | Synchronize SCL/SDA inputs | Design |
| rtl/control/arbiter.v | Request/grant/done handshake | Design |
| rtl/bus/i2c_master.sv | Open-drain I2C transfers, repeated START, ACK/NACK and timeout | Design |
| rtl/sensors/hygro_service.sv | HDC1080 identity, configuration, trigger/wait/read and retries | Design |
| rtl/hygro_test_top.sv | Board wrapper with switches and LEDs | Design; hardware top |
| sim/models/hdc1080_model.sv | Fake HDC1080 responding at physical I2C pins | Simulation only |
| sim/tb_hygro_service.sv | Automated stimulus and assertions | Simulation only; simulation top |
| constraints/hygro_jb.xdc | Clock, buttons, switches, LEDs and JB pins | Constraints |
| scripts/create_hygro_project.tcl | Creates a correctly separated Vivado project | Setup script |
| scripts/run_hygro_xsim.tcl | Runs only the HYGRO simulation | Simulation script |
| scripts/run_hygro_iverilog.sh | Alternative simulation without Vivado | Simulation script |

Keep .sv extensions and SystemVerilog file types. Do not add every file from
the larger repository: duplicate copies of modules can cause compilation errors.
The portable service is the module you later give to your teammate; the board
wrapper is only for standalone testing.

## What the controller does

HYGRO uses HDC1080 at seven-bit I2C address 0x40. There is no data-ready
interrupt connection. This requester runs a timed state machine:

1. Wait 20 ms after reset at the default 100 MHz clock.
2. Read manufacturer register FE: expected 5449 hex.
3. Read device register FF: expected 1050 hex.
4. Write register 02 with 1000 hex: combined 14-bit temperature/humidity.
5. Write pointer 00 to trigger temperature followed by humidity conversion.
6. Release the grant and wait 20 ms.
7. Reacquire the grant and read four bytes, without rewriting the pointer.
8. Publish temperature_raw, humidity_raw and a one-cycle sample_valid pulse.
9. Wait one second before the next trigger.

Default I2C clock is approximately 100 kHz. A sample arrives about every
1.02 seconds plus transaction overhead. The first sample arrives after startup,
initialization and conversion, rather than waiting a full extra second.
Three not-ready read retries are allowed, each after a 10 ms wait. A persistent
error latches fault until reset. The bus transaction timeout is 10 ms.

## Inputs and outputs

At the board level you provide only power, the sensor, clock and reset.
SW2:SW0 select what the LEDs show; they do not enter temperature or humidity.
Acquisition starts automatically. No terminal input or UART command is required.

| Service signal | Direction | Meaning |
|---|---|---|
| clk | Input | 100 MHz, 10 ns period |
| rst | Input | Synchronous active-high reset |
| grant | Input | Arbiter ownership permission |
| scl, sda | Bidirectional | Open-drain physical I2C wires; pull-ups required |
| req | Output | Request held through completion |
| done | Output | One-clock transaction completion while grant is held |
| initialized | Output | Identity/configuration successful |
| fault | Output | Latched unrecoverable error |
| sample_valid | Output | One 10 ns pulse when a new T/RH pair is valid |
| temperature_raw, humidity_raw | Output | Unsigned 16-bit values held until next sample |
| manufacturer_id, device_id | Output | 5449 and 1050 hex after successful reads |
| error_code | Output | 0 OK, 1 NACK, 2 timeout, 3 invalid transaction/internal state, 4 wrong ID |
| retry_count | Output | Cumulative result-read retries since reset |
| converting | Output | Conversion/retry wait; request and grant are released |

## Simulation: easiest route on Windows with Vivado

1. Clone or download this repository to a short path, for example C:/FPGA/Project-Interrupt_Arbitration_Controller.
2. Open Vivado. In the Tcl Console run:

   `source C:/FPGA/Project-Interrupt_Arbitration_Controller/scripts/create_hygro_project.tcl`

   The script creates build/vivado_hygro. Re-running it recreates this generated
   project, so keep source changes in rtl/, sim/ and constraints/.
3. Check Design Sources top = hygro_test_top and Simulation Sources top =
   tb_hygro_service. No board or PMOD is needed for simulation.
4. Click Run Simulation > Run Behavioral Simulation.
5. In the simulation Tcl Console execute these commands one per line:

   `log_wave -r /*`

   `add_wave /tb_hygro_service/*`

   `run all`

   The top-level wave names are temp, rh, mid, did, valid, initialized, fault,
   error_code, req, grant, done, converting, scl and sda. Set vector radix to hex.
6. Simulation ends after about 281.615 microseconds with the supplied accelerated
   timing. Do not stop at Vivado's usual 1000 ns window. There is a 2 ms watchdog.

Batch alternative: in the Vivado command prompt, change to the repository root:

`vivado -mode batch -source scripts/run_hygro_xsim.tcl`

Icarus alternative (Icarus Verilog 12 used for previous validation):

`sh scripts/run_hygro_iverilog.sh`

The testbench supplies all inputs: 100 MHz clock, reset, a model that responds
with known values, one forced read NACK, missing-device and wrong-ID cases,
retry exhaustion, a stuck-low SCL, and reset during a transaction. Do not force
SDA/SCL from Vivado; the model and controller already drive them.

Expected console lines:

```
PASS HYGRO identities, config, retry without retrigger, periodic samples
PASS HYGRO absent device
PASS HYGRO wrong identity
PASS HYGRO bounded not-ready retries
PASS HYGRO stuck SCL releases requester
PASS HYGRO reset during transaction and recovery
```

During a successful measurement, mid=5449, did=1050, temp=6680, rh=8000
(all hex), valid pulses, and fault is zero. The first test deliberately causes
one transient NACK, so retries=1 before it completes. Later fault=1 is expected
because the bench intentionally tests error paths; judge the complete run by
all six PASS lines and no FATAL, not by its final waveform values alone.
The simulation timings are deliberately shortened, including a much faster
I2C clock; never copy those testbench parameter overrides to the board top.

## Hardware wiring: HYGRO on JB

Turn board power off before connecting. Connect HYGRO's J1 pins to the matching
JB pin numbers. Use the row identified by pins 1 through 6 on the connector;
do not infer the row from the board's orientation in a photo.

| HYGRO J1 pin | Signal | ZedBoard connection | FPGA package pin |
|---|---|---|---|
| 1 | NC | JB1 if plugged directly; unused | No RTL port |
| 2 | NC | JB2 if plugged directly; unused | No RTL port |
| 3 | SCL | JB3 | V10 |
| 4 | SDA | JB4 | W8 |
| 5 | GND | JB5 / GND | Power pin |
| 6 | VCC | JB6 / 3.3 V | Power pin |

Enable both HYGRO JP1 pull-up links (onboard 2.2 kohm resistors).
Use 3.3 V power and pull-ups, not 5 V with the ZedBoard I/O.
This assignment keeps JA available for your teammate's ACL2.

Before generating the bitstream, inspect the board's VADJ jumper. The XDC
starts with VADJ_IOSTANDARD=LVCMOS18. This must match the actual switch/button
bank supply: for 1.8 V use LVCMOS18; for 2.5 V change that variable to LVCMOS25.
Do not assume the board's shipped or current setting. Clock, JB and LEDs remain
LVCMOS33. Compare board revision/connector markings with the source pin map.

## Program and observe

1. Use the project created by create_hygro_project.tcl. Confirm hardware top
   hygro_test_top; simulation model and bench must stay in Simulation Sources.
2. Verify wiring and the VADJ choice above. Only hygro_jb.xdc is needed here;
   do not add the separate ACL2 project's XDC.
3. Run Synthesis, Open Synthesized Design, and inspect errors/warnings.
4. Run Implementation. Check timing and DRC results. These have not been run
   in this project's preparation; simulation success is not a hardware timing proof.
5. Generate Bitstream. The expected path is:
   build/vivado_hygro/hygro_standalone.runs/impl_1/hygro_test_top.bit
6. Connect the ZedBoard's USB-JTAG/PROG port to the laptop and power the board.
   Use Hardware Manager > Open Target > Auto Connect > Program Device and
   select the generated .bit file. No Vitis, SDK, PS block design or ARM program
   is required for this standalone PL design.
7. Set SW2:SW0=000. Press and release the centre user button BTNC (not PS reset).
   The wrapper also supplies a short power-on reset after FPGA configuration.
   Button bounce can restart initialization; wait until the button is released.
8. After initialization, LD0 should be on and LD1 off. LD2 toggles on each
   completed sample, approximately once per 1.02 seconds; a full blink cycle
   therefore takes roughly two seconds. LD3/LD4 activity can be too brief to
   see reliably. LD7:LD5 should normally be zero.
9. Select the other switch modes to read ID and measurement bytes.

| SW2 SW1 SW0 | LEDs LD7..LD0 show | Expected |
|---|---|---|
| 000 | Status | See mapping below |
| 001 | Manufacturer ID high byte | 54 hex = 01010100 |
| 010 | Manufacturer ID low byte | 49 hex = 01001001 |
| 011 | Device ID high byte | 10 hex = 00010000 |
| 100 | Temperature high byte | Depends on room temperature |
| 101 | Temperature low byte | Depends on room temperature |
| 110 | Humidity high byte | Depends on room humidity |
| 111 | Humidity low byte | Depends on room humidity |

Mode 000 mapping: LD0 initialized; LD1 fault; LD2 sample heartbeat; LD3 grant;
LD4 converting; LD7:LD5 error_code. A lit LED represents 1. Identify LEDs by
printed LD numbers rather than their left-to-right position. The standalone
wrapper exposes only the high byte of device ID; the full 1050 is checked
internally and visible in simulation or ILA.

Combine raw = 256 * high_byte + low_byte. Measurements can update while you
switch between bytes, so LED reconstruction is approximate. For an exact
single sample use Vivado ILA with trigger sensor.sample_valid=1, capturing
sensor.temperature_raw and sensor.humidity_raw together, clocked by clk.
ILA is optional and is not instantiated in this project.

Convert unsigned 16-bit values as follows (do not right shift away the two
zero LSBs before using these formulas):

Temperature C = raw * 165.0 / 65536.0 - 40.0
Humidity %RH = raw * 100.0 / 65536.0

The simulated 0x6680 and 0x8000 represent 26.064453125 C and 50% RH. Actual
hardware should show its environment, not necessarily these fixed numbers.

## If something fails

- Missing module or duplicate definition: use only the six listed design files,
  with one copy of each. Simulation also needs the two simulation files.
- Simulation remains at startup: run all; do not use hardware's long timers in
  a short run. The included bench overrides the timing automatically.
- fault=1, error=1: check JB3/JB4, sensor power, ground and enabled pull-ups.
- error=2: check for a stuck-low SCL/SDA, shorts or a reversed connector.
- error=4: identity mismatch; verify sensor type and I2C waveform/byte order.
- SDA/SCL show Z in simulation: use the supplied tri1 testbench/model.
- DRC unspecified pin/standard: ensure hardware top and XDC match exactly.
- Reset cannot recover after interruption: this engine has no nine-clock bus
  recovery sequence. Power-cycle the sensor/board with wiring unchanged, then
  retry; it cannot release a line held low by a physical slave.

## What to hand to your teammate

Keep hygro_service, i2c_master and sync_input. In the combined project connect
req/grant/done to channel 1 of the one shared arbiter and connect scl/sda to JB.
Capture both raw values whenever sample_valid is high. Share screenshots of
six PASS lines, the measurement waveform, manufacturer ID LEDs, sample
heartbeat, and one converted physical reading. OLED/UART formatting belongs
to the subsequent shared output stage.

## Validation and references

The included HYGRO RTL/model/bench match the versions tested on 9 November
2026 in GitHub Actions with Icarus Verilog 12. All six HYGRO checks passed and
the board top elaborated. The new Vivado scripts and XDC were prepared for
this standalone kit; Vivado synthesis, implementation and ZedBoard operation
have not been executed here.

Previous successful run:
https://github.com/Sashidhar23/Project-Interrupt_Arbitration_Controller/actions/runs/42621372712

Pin map:
https://github.com/Digilent/digilent-xdc/blob/master/Zedboard-Master.xdc

HYGRO wiring, timing and formulas:
https://digilent.com/reference/_media/reference/pmod/pmodhygro/pmod-hygro-rm.pdf

HDC1080 detailed register definitions:
https://www.ti.com/lit/ds/symlink/hdc1080.pdf
