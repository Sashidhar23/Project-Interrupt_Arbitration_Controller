# Vivado Tcl Console: source C:/path/HYGRO_Standalone/scripts/create_hygro_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
create_project -force hygro_standalone [file join $root build vivado_hygro] -part xc7z020clg484-1
foreach f {rtl/common/reset_sync.sv rtl/common/sync_input.sv rtl/control/arbiter.v rtl/bus/i2c_master.sv rtl/sensors/hygro_service.sv rtl/hygro_test_top.sv} {
    add_files -norecurse [file join $root $f]
}
foreach f {sim/models/hdc1080_model.sv sim/tb_hygro_service.sv} {
    add_files -fileset sim_1 -norecurse [file join $root $f]
}
add_files -fileset constrs_1 -norecurse [file join $root constraints hygro_jb.xdc]
set_property top hygro_test_top [get_filesets sources_1]
set_property top tb_hygro_service [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Project ready. Simulation top: tb_hygro_service. Hardware top: hygro_test_top."
puts "Before hardware generation: match VADJ_IOSTANDARD in hygro_jb.xdc to your actual board jumper."
