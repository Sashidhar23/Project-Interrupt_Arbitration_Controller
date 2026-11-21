# Run from the Vivado Tcl console; only this combined XDC is loaded.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts oled_sources.tcl]
create_project -force sensor_oled [file join $root build vivado_sensor_oled] -part xc7z020clg484-1
foreach f $oled_sources {add_files -norecurse [list [file join $root $f]]}
foreach f {sim/models/adxl362_model.sv sim/models/hdc1080_model.sv sim/tb_sensor_oled.sv sim/tb_sensor_oled_text.sv} {
    add_files -fileset sim_1 -norecurse [list [file join $root $f]]
}
add_files -fileset constrs_1 -norecurse [list [file join $root constraints sensor_oled_zedboard.xdc]]
set_property top sensor_oled_top [get_filesets sources_1]
set_property top tb_sensor_oled [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Ready: ACL2=JA, HYGRO=JB, external PmodOLED=JC. Check VADJ_IOSTANDARD before generating a bitstream."
