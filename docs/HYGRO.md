# HYGRO acquisition and combined sensor hub

## Hardware behavior

The PMOD HYGRO uses an HDC1080 at I2C address 0x40. It has no data-ready
interrupt pin. This path therefore generates scheduled requests: trigger a
measurement, release the arbitration grant, wait for conversion, then request
a four-byte result read. ACL2 remains interrupt driven. The arbiter schedules
sensor services; it is not an electrical multi-master I2C arbiter.

At 100 MHz, defaults provide approximately 100 kHz I2C, a 20 ms startup wait,
a 20 ms combined conversion wait, and a one-second gap between completed
samples and the next trigger. The gap is not an exact one-Hz sample rate.
All timing parameters are clock cycles. SCL and SDA are open drain and need
external pull-ups to the correct 3.3 V rail. Verify the PMOD wiring and its
pull-ups before programming the board.

Initialization reads manufacturer ID 0x5449 and device ID 0x1050, then writes
configuration 0x1000 (combined temperature/humidity, 14-bit resolution).
Writing only pointer 0x00 triggers conversion. The result transaction is a
raw read without rewriting that pointer; rewriting it would retrigger.
The master ACKs the first three bytes and NACKs the fourth.

A not-ready result-address NACK allows three retries with 10 ms waits.
Each retry releases the grant. Missing-device initialization, wrong ID,
exhausted retries, or a bus timeout latches fault until reset. Timeout releases
the master's line drivers; it cannot force a physically stuck bus high.

## Files and interfaces

| File | Purpose |
|---|---|
| rtl/bus/i2c_master.sv | Bounded transactions, repeated START, ACK/NACK, clock stretching, open-drain pins and timeout |
| rtl/sensors/hygro_service.sv | Identity checks, configuration, scheduled conversion, result decoding and bounded retries |
| rtl/sensor_hub.sv | Real ACL2 and HYGRO requesters connected to the existing two-channel arbiter |
| rtl/hygro_test_top.sv | Standalone HYGRO board bring-up with switches and LEDs |
| sim/models/hdc1080_model.sv | Pin-level simulated HDC1080 with conversion delay and fault injection |
| sim/tb_hygro_service.sv | IDs, byte ordering, periodic acquisition, NACK retry, missing sensor, bad ID, stuck bus and reset recovery |
| sim/tb_sensor_hub.sv | Ownership assertions and ACL2 acquisition during HYGRO conversion |
| scripts/run_regression.sh | Runs common, SPI, arbiter, ACL2, HYGRO and hub tests, then elaborates both bring-up tops |
| .github/workflows/hdl.yml | Runs the regression in GitHub Actions and saves logs/waveforms |

The byte-engine payload uses byte zero in bits [7:0]. Sensor outputs use
normal 16-bit numeric order. sample_valid is a one-clock strobe; consumers
must capture the values on that cycle. Raw values remain latched afterward.
Temperature in Celsius = raw * 165 / 65536 - 40; relative humidity in percent
= raw * 100 / 65536. Formatting is a later output-stage task.

Requests remain asserted until completion. done is one cycle with the grant
still held. A requester waits for grant removal before issuing its next job.
The hub maps ACL2 to channel 0 and HYGRO to channel 1. Priority and aging
inputs retain the original arbiter policy.

## Run and bring-up

From the repository root, run `sh scripts/run_regression.sh` with Icarus
Verilog and GNU timeout installed. Logs and the hub waveform are under build/.
Simulation models and testbenches belong only in simulation sources.
For Vivado synthesis, add the RTL sources and select hygro_test_top for a
standalone test or sensor_hub for portable integration. sensor_hub requires
an externally supplied synchronous reset and is not a complete board top.

Do not reuse invented package pins. Add an XDC only after matching the exact
ZedBoard connector, clock, switches, LEDs and PMOD wiring to the board's master
constraints. The current repository does not supply verified HYGRO constraints.

HYGRO top switch modes: 0 status, 1/2 manufacturer ID high/low, 3 device ID
high, 4/5 temperature high/low, 6/7 humidity high/low. Status LEDs [7:5]
are error, [4] converting, [3] grant, [2] sample heartbeat, [1] fault,
[0] initialized. Confirm IDs first, then observe changing measurements.

## Two-person next handoff

- Person A: validate ACL2 SPI/interrupt wiring and signed XYZ on hardware;
  capture CS, clock, IRQ, grant, done and sample_valid with ILA.
- Person B: validate HYGRO IDs and raw values, then integrate a record fanout
  with separate UART and OLED queues so a slow display cannot block logging.
- Joint: integrate verified constraints and board top, measure request-to-grant
  latency and service counts under stress, then complete OLED/UART and the
  demonstration report before 20 November 2026.

This acquisition milestone does not yet implement output queues, OLED,
UART/PS bridge, hardware metrics, or the final stress measurement report.
Simulation success does not establish synthesis timing or electrical validity.

Reference: TI HDC1080 datasheet, https://www.ti.com/lit/ds/symlink/hdc1080.pdf
