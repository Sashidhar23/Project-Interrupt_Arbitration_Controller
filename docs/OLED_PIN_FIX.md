# OLED connector correction - 19 November 2026

The earlier sensor_oled_zedboard.xdc incorrectly interpreted the master XDC's
N/P net listing order as physical connector pin order. This can leave the external
OLED blank even when LD0 is on. LD0 confirms completion of the transmitted startup
sequence, not acknowledgement from the OLED. SPI has no acknowledgement here.

Correct assignments:

| Signal | Physical JC pin | FPGA pin |
|---|---|---|
| CS | 1 | AB7 |
| SDIN | 2 | AB6 |
| SCLK | 4 | AA4 |
| DC | 7 | R6 |
| RES | 8 | T6 |
| VBATC | 9 | T4 |
| VDDC | 10 | U4 |

Verified using ZedBoard schematic sheet 3 (Pmod connector numbering) and
Digilent Zedboard-Master.xdc (net-to-package mapping):
https://digilent.com/reference/_media/zedboard%3Azedboard_sch.pdf
https://github.com/Digilent/digilent-xdc/blob/master/Zedboard-Master.xdc

For an existing project, replace its old combined XDC with this package's
constraints/sensor_oled_zedboard.xdc. Ensure only one combined XDC is enabled.
Preserve the VADJ_IOSTANDARD setting matching your actual board jumper.
Reset synthesis and rerun synthesis, implementation and Generate Bitstream.
Program the new bitstream. Existing .bit files do not acquire source-file fixes.
Keep ACL2 on JA, HYGRO on JB and external Pmod OLED on JC.
If power cycling, reprogram afterward when using volatile JTAG configuration.

Expected output is four lines of XYZ, temperature and humidity, with sensor
status. WAIT/ERR text should still be visible if acquisition fails; a completely
blank screen needs further display debugging. This correction is source-verified;
visible output on the user's board is still to be confirmed.

User-reported LEDs: LD7, LD6, LD3, LD2, LD0 on; LD4/LD5 off.
LD2/3 indicate sensor initialization, LD4/5 faults, and LD6/7 toggle on samples.
A still observation of LD6/7 alone does not establish the sample rate.
