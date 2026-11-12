# ZedBoard xc7z020clg484-1. HYGRO J1 pins 1..6 -> JB pins 1..6.
# Pin source: https://github.com/Digilent/digilent-xdc/blob/master/Zedboard-Master.xdc
# HYGRO SCL is pin 3; SDA is pin 4. Enable its two JP1 pull-up links.
# IMPORTANT: inspect actual VADJ jumper BEFORE programming.
# Use LVCMOS18 for 1.8 V, or LVCMOS25 for 2.5 V. Do not assume a default.
set VADJ_IOSTANDARD LVCMOS18
set_property PACKAGE_PIN Y9 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_property PACKAGE_PIN P16 [get_ports btn_rst]
set_property PACKAGE_PIN F22 [get_ports {sw[0]}]
set_property PACKAGE_PIN G22 [get_ports {sw[1]}]
set_property PACKAGE_PIN H22 [get_ports {sw[2]}]
set_property IOSTANDARD $VADJ_IOSTANDARD [get_ports {btn_rst sw[*]}]
set_property PACKAGE_PIN T22 [get_ports {led[0]}]
set_property PACKAGE_PIN T21 [get_ports {led[1]}]
set_property PACKAGE_PIN U22 [get_ports {led[2]}]
set_property PACKAGE_PIN U21 [get_ports {led[3]}]
set_property PACKAGE_PIN V22 [get_ports {led[4]}]
set_property PACKAGE_PIN W22 [get_ports {led[5]}]
set_property PACKAGE_PIN U19 [get_ports {led[6]}]
set_property PACKAGE_PIN U14 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
set_property PACKAGE_PIN V10 [get_ports hygro_scl]
set_property PACKAGE_PIN W8 [get_ports hygro_sda]
set_property IOSTANDARD LVCMOS33 [get_ports {hygro_scl hygro_sda}]
set_property SLEW SLOW [get_ports {hygro_scl hygro_sda}]
# Slow asynchronous inputs enter synchronizers; LEDs are human displays.
# These exceptions are for this bring-up top, not a general I2C timing proof.
set_false_path -from [get_ports {btn_rst sw[*] hygro_scl hygro_sda}]
set_false_path -to [get_ports {led[*]}]
