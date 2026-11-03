# ZedBoard sensor arbitration project

## What to run first

Compile the ACL2 service test with the real spi_master and arbiter. The ZIP
includes the exact supplied SPI and arbiter source files alongside the new
controller, device model and integration testbench. Proposed future files in
PROJECT_STRUCTURE.md describe the remaining work.

In a Vivado-configured terminal, change to the extracted project directory:

    vivado -mode batch -source scripts/run_xsim.tcl

For a Linux/WSL installation with Icarus Verilog and vvp:

    sh scripts/run_iverilog.sh

In the Vivado GUI, add the four design files named by the Tcl script, add
sim/models/adxl362_model.sv and sim/tb_acl2_service.sv as Simulation Sources,
set tb_acl2_service as the simulation top, and run behavioral simulation using
Run All. The other simulation files are separate regression tops.

Expected success message:

    PASS: ID/config, contention, two signed bursts, delayed IRQ clear and bad ID

The new testbench was prepared and its source dependencies were checked. An HDL
simulator was unavailable in the authoring environment. Run this test locally
before marking the controller verified. Board timing, wiring, synthesis and
hardware behavior also require local validation.

## Integration

Use adxl362_ctrl for the file called acl2_service.sv in the earlier plan.
The Verilog module internally instantiates the provided SPI byte engine and
the common SystemVerilog sync_input module. The latter is compiled as SV.
Supply a single system clock and synchronous active-high reset.

| Controller signal | Connect to |
|---|---|
| req, grant, done | arbiter channel 0, respectively req[0], grant[0], done[0] |
| int1_async | ACL2 INT1 pin, configured active high |
| cs_n, sclk, mosi, miso | ACL2 chip select, clock, FPGA-to-sensor data, sensor-to-FPGA data |
| id_ok, device_id, initialized, fault | LED or ILA status indicators |
| sample_valid, x, y, z | Record builder/FIFO push on the one-cycle sample_valid indication |

Reserve channel 1 for the HYGRO service FSM. Give it separate grants for the
conversion trigger and the result read, releasing the slot during conversion.
Each controller must start once per grant. Only the owner's done releases it.

## What happens after reset

1. Wait POWERUP_CYCLES. At the default 100 MHz, the proposed wait is 100 ms.
2. Request one transaction to read register 0x00. Require ID 0xAD.
3. Request separate transactions to write FILTER_CTL (0x2C) = 0x13,
   INTMAP1 (0x2A) = 0x01, and POWER_CTL (0x2D) = 0x02. This selects +/-2 g,
   100 Hz, half bandwidth, active-high data-ready on INT1 and measurement mode.
4. Synchronize INT1. On a new assertion, latch a pending request. Once granted,
   lower CS and send 0x0B, 0x0E and six dummy bytes under one assertion of CS.
   The final six MISO bytes are X low/high, Y low/high, Z low/high.
5. Present signed 16-bit, sign-extended XYZ and pulse sample_valid. The previous
   XYZ values remain visible between valid pulses. done covers exactly one
   complete transaction including configuration. done is separate from the
   SPI engine's internal byte_done.
6. A wrong ID or a byte engine timeout latches fault, completes the owned
   transaction once and requires reset for retry. SPI has no per-byte slave
   acknowledgement. A wiring or disconnect issue after initialization need not
   produce an engine timeout.

Use CLK_DIV >= 4, POWERUP_CYCLES >= 1 and BYTE_TIMEOUT_CYCLES longer than one
complete byte (16 * CLK_DIV plus control overhead). Keep default hardware
delays in the bitstream. Testbenches may shorten them. Assert system reset at
startup. This baseline assumes the ACL2 begins at power-on defaults; for a
warm reboot from an arbitrary configuration, power-cycle the sensor or add
the documented soft-reset sequence and recovery delay.

The interrupt detector rearms after a synchronized low and latches one pending
assertion. Multiple notifications can coalesce, and a level that stays high
does not count individual sensor samples. At the nominal 100 Hz, validate
rearm timing and service latency on the board. If every intermediate sample
is required, extend the design to use the ADXL362 FIFO and overrun reporting.
The record consumer must capture each sample_valid or explicitly count drops.

## Acceptance tests

Watch req, grant, done, cs_n, sclk, mosi, miso, int1_async, sample_valid,
device_id, x, y and z. Check that no physical operation starts before grant,
CS stays low for each whole frame, a held IRQ does not trigger a duplicate,
and the arbiter releases a failing requester. The model is a focused SPI
protocol fixture, not a cycle-accurate device or a timing sign-off.

First board milestone: read ID 0xAD, inspect one XYZ interrupt burst in ILA,
then tilt the PMOD and watch signed readings change. Verify PMOD pin mappings
for your board before making an XDC. The archive has no guessed pin assignments.

Device source:
https://www.analog.com/media/en/technical-documentation/data-sheets/adxl362.pdf
