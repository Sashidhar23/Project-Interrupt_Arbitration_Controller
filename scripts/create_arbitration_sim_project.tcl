# Same source folder, separate simulation project: existing ILA project is preserved.
set root [file normalize [file join [file dirname [info script]] ..]]
create_project -force arbitration_sim [file join $root build arbitration_sim] -part xc7z020clg484-1
foreach f {rtl/control/arbiter.v rtl/debug/arbiter_metrics.sv rtl/debug/arbiter_stress_demo.sv} {
 add_files -norecurse [list [file join $root $f]]
}
add_files -fileset sim_1 -norecurse [list [file join $root sim tb_arbitration_demo.sv]]
set_property top tb_arbitration_demo [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Run Behavioral Simulation, then source scripts/arbitration_wave_setup.tcl using its full path."
