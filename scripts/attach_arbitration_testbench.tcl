# Attach to the CURRENT open project; never creates or reopens a project.
set demo_root [file normalize [file join [file dirname [info script]] ..]]
if {[current_project -quiet] eq ""} {error "Open your existing ILA project first."}
set demo_tb [file join $demo_root sim tb_arbitration_demo.sv]
add_files -fileset sim_1 -norecurse [list $demo_tb]
set_property used_in_synthesis false [get_files -of_objects [get_filesets sim_1] [list $demo_tb]]
set_property used_in_implementation false [get_files -of_objects [get_filesets sim_1] [list $demo_tb]]
set_property top tb_arbitration_demo [get_filesets sim_1]
set_property top_auto_set 0 [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
puts "ATTACHED: tb_arbitration_demo is the simulation top in [current_project]. Hardware top remains [get_property top [get_filesets sources_1]]."

