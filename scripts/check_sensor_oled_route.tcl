# Optional place-and-route check after check_sensor_oled_synth.tcl.
set root [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint [file join $root build oled_synth sensor_oled_synth.dcp]
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file [file join $root build oled_synth timing_routed.rpt]
report_drc -file [file join $root build oled_synth drc_routed.rpt]
report_utilization -file [file join $root build oled_synth utilization_routed.rpt]
write_checkpoint -force [file join $root build oled_synth sensor_oled_routed.dcp]
set paths [get_timing_paths -delay_type max -max_paths 1]
if {[llength $paths] && [get_property SLACK [lindex $paths 0]] < 0} {
    error "Routed setup timing failed; inspect timing_routed.rpt before hardware use."
}
