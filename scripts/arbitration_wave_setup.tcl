# Run in Vivado's Tcl Console AFTER opening behavioral simulation, BEFORE Run All.
add_wave -radix unsigned /tb_arbitration_demo/phase
foreach n {clk reset start request_off grant_off done_off request_on grant_on done_on} {
 add_wave -radix bin /tb_arbitration_demo/$n
}
foreach n {priority0_off priority1_off priority0_on priority1_on wait1_off wait1_on grants0_off grants1_off grants0_on grants1_on max_wait1_off max_wait1_on} {
 add_wave -radix unsigned /tb_arbitration_demo/$n
}
run all

