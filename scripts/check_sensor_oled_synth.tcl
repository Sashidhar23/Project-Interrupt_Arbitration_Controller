# Reproducible synthesis + I/O checks; does not program the board.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts oled_sources.tcl]
file mkdir [file join $root build oled_synth]
foreach f $oled_sources {read_verilog -sv [list [file join $root $f]]}
read_xdc [list [file join $root constraints sensor_oled_zedboard.xdc]]
synth_design -top sensor_oled_top -part xc7z020clg484-1
report_utilization -file [file join $root build oled_synth utilization.rpt]
report_timing_summary -file [file join $root build oled_synth timing_synth.rpt]
report_drc -file [file join $root build oled_synth drc.rpt]
write_checkpoint -force [file join $root build oled_synth sensor_oled_synth.dcp]
