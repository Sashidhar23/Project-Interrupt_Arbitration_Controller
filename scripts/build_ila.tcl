source [file join [file dirname [info script]] create_ila_project.tcl]
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "ILA synthesis failed"}
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "ILA implementation failed"}
open_run impl_1
if {[llength [get_clocks sys_clk]] != 1} {error "Missing 100 MHz board clock constraint"}
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] eq "DEFAULT"} {
        error "Missing board pin/IOSTANDARD constraint on $port"
    }
}
set result [file join $root build ila_results]
file mkdir $result
report_timing_summary -file [file join $result timing.rpt]
report_utilization -file [file join $result utilization.rpt]
report_drc -file [file join $result drc.rpt]
write_debug_probes -force [file join $result arbiter_ila.ltx]
foreach delay {max min} {
    set p [get_timing_paths -delay_type $delay -max_paths 1]
    if {![llength $p]} {error "No $delay timing paths found"}
    if {[get_property SLACK [lindex $p 0]]<0} {error "ILA $delay timing failed"}
}
puts "ILA implementation checked. Generate bitstream after confirming board VADJ."
