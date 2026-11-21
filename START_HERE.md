# Start with DEMO_START_HERE.md for the arbitration demonstration.

Replacement ACL2: +/-2 g with no old-module Z-offset correction.

# Final sensor/OLED project with optional ILA demonstration

IMPORTANT (19 November): Earlier distributed OLED constraints had incorrect JC
pin ordering. Use the corrected combined XDC in this package and rebuild the
bitstream. Do not reuse an old .bit. See docs/OLED_PIN_FIX.md.

Use the external Pmod OLED: ACL2 on JA, HYGRO on JB, OLED on JC.
Check the board VADJ setting before generating a bitstream.

In Vivado's Tcl Console, change directory to this project folder, then choose ONE:

- Normal sensor + OLED build: `source scripts/create_sensor_oled_project.tcl`
- ILA/VIO demonstration build: `source scripts/create_ila_project.tcl`

Both use top `sensor_oled_top`; the debug project sets ENABLE_DEBUG=1 automatically.
Run Synthesis > Implementation > Generate Bitstream, then program using Hardware
Manager. The ILA build also needs the matching .ltx debug-probes file.

Read docs/OLED_INTEGRATION.md for wiring and expected sensor values.
Read docs/ILA_DEMO.md for the OFF/ON demonstration and every control/probe.
Read docs/ILA_VALIDATION.md for verification status.

UART is not needed. No additional sensor, external analyzer or ARM C program is
needed. ILA uses the programming USB connection. The separate synthetic benchmark
uses the same arbiter RTL but is not physical sensor traffic. OLED data stays real.
