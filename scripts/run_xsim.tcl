# vivado -mode batch -source scripts/run_xsim.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
create_project -force acl2_test [file join $root build vivado] -part xc7z020clg484-1
foreach f {rtl/common/sync_input.sv rtl/control/arbiter.v rtl/bus/spi_master.v rtl/sensors/adxl362_ctrl.v} {
    add_files -norecurse [file join $root $f]
}
foreach f {sim/models/adxl362_model.sv sim/tb_acl2_service.sv} {
    add_files -fileset sim_1 -norecurse [file join $root $f]
}
set_property top tb_acl2_service [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
close_project
