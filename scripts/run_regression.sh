#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
common='rtl/common/config_pkg.sv rtl/common/reset_sync.sv rtl/common/sync_input.sv rtl/common/sync_fifo.sv'
rtl="$common rtl/control/arbiter.v rtl/bus/spi_master.v rtl/bus/i2c_master.sv rtl/sensors/adxl362_ctrl.v rtl/sensors/hygro_service.sv rtl/sensor_hub.sv"
run_test() {
    top=$1
    shift
    iverilog -g2012 -s "$top" -o "build/$top" $rtl "$@"
    timeout 30s vvp "build/$top" > "build/$top.log" 2>&1
    cat "build/$top.log"
    if grep -Eq 'FAIL|ERROR|TIMEOUT|FATAL' "build/$top.log"; then exit 1; fi
    grep -Eq 'PASS' "build/$top.log"
}
run_test tb_common sim/tb_common.sv
run_test tb_spi_master sim/tb_spi_master.v
run_test tb_arbiter sim/arbiter/arb_system.v sim/arbiter/synth_requester.v sim/arbiter/tb_arbiter.v
run_test tb_acl2_service sim/models/adxl362_model.sv sim/tb_acl2_service.sv
run_test tb_hygro_service sim/models/hdc1080_model.sv sim/tb_hygro_service.sv
run_test tb_sensor_hub sim/models/adxl362_model.sv sim/models/hdc1080_model.sv sim/tb_sensor_hub.sv
# Elaborate both independent board tops using default hardware parameter values.
iverilog -g2012 -s hygro_test_top -o build/hygro_top $rtl rtl/hygro_test_top.sv
iverilog -g2012 -s acl2_test_top -o build/acl_top $rtl rtl/ACL2/acl_top.sv
printf 'ALL REGRESSIONS PASSED\n'
