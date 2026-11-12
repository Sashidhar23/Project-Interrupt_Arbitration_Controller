#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2012 -s tb_hygro_service -o build/tb_hygro rtl/common/sync_input.sv rtl/control/arbiter.v rtl/bus/i2c_master.sv rtl/sensors/hygro_service.sv sim/models/hdc1080_model.sv sim/tb_hygro_service.sv
vvp build/tb_hygro
