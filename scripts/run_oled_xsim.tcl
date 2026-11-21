# vivado -mode batch -source scripts/run_oled_xsim.tcl
# Requires Python 3. Direct simulator runner avoids project-launcher issues.
set root [file normalize [file join [file dirname [info script]] ..]]
set python [auto_execok python]
if {![llength $python]} {error "Python 3 not found on PATH; use the Vivado GUI simulation project instead."}
set bin_dir [file join $::env(XILINX_VIVADO) bin]
puts [exec {*}$python [file join $root scripts run_oled_xsim.py] --vivado-bin $bin_dir 2>@1]
