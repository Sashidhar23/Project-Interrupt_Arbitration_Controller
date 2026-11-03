#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2012 -s tb_acl2_service -o build/acl2 rtl/common/sync_input.sv rtl/control/arbiter.v rtl/bus/spi_master.v rtl/sensors/adxl362_ctrl.v sim/models/adxl362_model.sv sim/tb_acl2_service.sv
vvp build/acl2
