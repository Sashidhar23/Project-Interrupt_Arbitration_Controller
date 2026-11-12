# From a Vivado command prompt:
# vivado -mode batch -source scripts/run_hygro_xsim.tcl
source [file join [file dirname [info script]] create_hygro_project.tcl]
launch_simulation
log_wave -r /*
run all
close_sim
close_project
