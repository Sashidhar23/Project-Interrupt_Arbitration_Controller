## =============================================================================
## acl2_test.xdc : constraints for acl2_test_top on a ZedBoard (xc7z020clg484-1)
##
## Pins cross-checked against published ZedBoard material:
##   - Clock Y9 and PMOD JA1..JA10 = Y11 AA11 Y10 AA9 AB11 AB10 AB9 AA8 (bank 13)
##   - LEDs (bank 33), BTNC P16 (bank 34), SW0 F22 / SW1 G22 (bank 35)
## Still compare the rest (LD1-LD4, SW2, SW3) with the Digilent/Avnet master XDC.
##
## Bank voltages on the ZedBoard:
##   bank 13 (clock + PMOD JA..JD) : fixed 3.3 V        -> LVCMOS33
##   bank 33 (LEDs)                : fixed 3.3 V        -> LVCMOS33
##   bank 34 (buttons), 35 (switches): VADJ, default 1.8 V -> LVCMOS18
## Leave the VADJ jumper at its default. If you ever change VADJ, change the
## button and switch standards below to match it.
## =============================================================================

## 100 MHz system clock
set_property PACKAGE_PIN Y9 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## Push button BTNC -> btn_rst (bank 34, VADJ)
set_property PACKAGE_PIN P16 [get_ports btn_rst]
set_property IOSTANDARD LVCMOS18 [get_ports btn_rst]

## Switches SW0..SW3 (bank 35, VADJ)
set_property PACKAGE_PIN F22 [get_ports {sw[0]}]
set_property PACKAGE_PIN G22 [get_ports {sw[1]}]
set_property PACKAGE_PIN H22 [get_ports {sw[2]}]
set_property PACKAGE_PIN F21 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw[*]}]

## LEDs LD0..LD7 (bank 33, fixed 3.3 V)
set_property PACKAGE_PIN T22 [get_ports {led[0]}]
set_property PACKAGE_PIN T21 [get_ports {led[1]}]
set_property PACKAGE_PIN U22 [get_ports {led[2]}]
set_property PACKAGE_PIN U21 [get_ports {led[3]}]
set_property PACKAGE_PIN V22 [get_ports {led[4]}]
set_property PACKAGE_PIN W22 [get_ports {led[5]}]
set_property PACKAGE_PIN U19 [get_ports {led[6]}]
set_property PACKAGE_PIN U14 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## PMOD ACL2 on header JA, top row (bank 13, 3.3 V).
## ACL2 J1: 1 ~CS, 2 MOSI, 3 MISO, 4 SCLK, 5 GND, 6 VCC, 7 INT2, 8 INT1
set_property PACKAGE_PIN Y11  [get_ports acl2_cs_n]   ;# JA1
set_property PACKAGE_PIN AA11 [get_ports acl2_mosi]   ;# JA2
set_property PACKAGE_PIN Y10  [get_ports acl2_miso]   ;# JA3
set_property PACKAGE_PIN AA9  [get_ports acl2_sclk]   ;# JA4
set_property PACKAGE_PIN AB10 [get_ports acl2_int1]   ;# JA8  (INT1; INT2 would be JA7 = AB11)
set_property IOSTANDARD LVCMOS33 [get_ports {acl2_cs_n acl2_mosi acl2_miso acl2_sclk acl2_int1}]

## Asynchronous / slow inputs and display-only outputs are not timed
set_false_path -from [get_ports {btn_rst sw[*] acl2_int1 acl2_miso}]
set_false_path -to   [get_ports {led[*]}]
