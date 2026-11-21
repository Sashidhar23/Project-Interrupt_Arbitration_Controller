# Run from the repository root. Builds a separate project; normal build is preserved.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root scripts oled_sources.tcl]
create_project -force ila [file join $root build i] -part xc7z020clg484-1
foreach f [concat $oled_sources {rtl/debug/arbiter_metrics.sv rtl/debug/arbiter_stress_demo.sv rtl/debug/arbiter_debug.sv}] {
    add_files -norecurse [list [file join $root $f]]
}
add_files -fileset constrs_1 -norecurse [list [file join $root constraints sensor_oled_zedboard.xdc]]
set_property top sensor_oled_top [get_filesets sources_1]
set_property generic {ENABLE_DEBUG=1} [get_filesets sources_1]
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_arb
set cfg [list CONFIG.C_NUM_OF_PROBES 10 CONFIG.C_DATA_DEPTH 16384 CONFIG.C_INPUT_PIPE_STAGES 1]
set widths {8 2 2 2 9 9 32 32 32 1}
for {set i 0} {$i < 10} {incr i} {lappend cfg CONFIG.C_PROBE${i}_WIDTH [lindex $widths $i]}
set_property -dict $cfg [get_ips ila_arb]
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_arb
set cfg [list CONFIG.C_NUM_PROBE_IN 6 CONFIG.C_NUM_PROBE_OUT 4]
set widths {1 1 32 32 32 32}
for {set i 0} {$i < 6} {incr i} {lappend cfg CONFIG.C_PROBE_IN${i}_WIDTH [lindex $widths $i]}
foreach i {0 1 2 3} {lappend cfg CONFIG.C_PROBE_OUT${i}_WIDTH 1}
lappend cfg CONFIG.C_PROBE_OUT0_INIT_VAL 0x0 CONFIG.C_PROBE_OUT1_INIT_VAL 0x1
lappend cfg CONFIG.C_PROBE_OUT2_INIT_VAL 0x0 CONFIG.C_PROBE_OUT3_INIT_VAL 0x1
set_property -dict $cfg [get_ips vio_arb]
generate_target all [get_ips {ila_arb vio_arb}]
# Synthesize IP with the top, avoiding separate out-of-context jobs.
set_property GENERATE_SYNTH_CHECKPOINT false [get_files -all {*/ila_arb.xci */vio_arb.xci}]
update_compile_order -fileset sources_1
puts "ILA project ready. Same JA/JB/JC wiring. Read docs/ILA_DEMO.md before testing."

# The same ILA project also contains the presentation simulation top.
source [file join $root scripts attach_arbitration_testbench.tcl]
