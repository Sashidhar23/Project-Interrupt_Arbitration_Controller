`timescale 1ns/1ps
// Portable acquisition integration. rst is synchronous active high.
module sensor_hub #(
    parameter integer ACL_SPI_DIV=50,
    parameter integer ACL_STARTUP_CYCLES=10000000,
    parameter integer I2C_HALF_PERIOD=500,
    parameter integer I2C_TIMEOUT_CYCLES=1000000,
    parameter integer HYGRO_STARTUP_CYCLES=2000000,
    parameter integer HYGRO_CONVERSION_CYCLES=2000000,
    parameter integer HYGRO_SAMPLE_GAP_CYCLES=100000000,
    parameter integer HYGRO_RETRY_CYCLES=1000000
)(
    input wire clk, rst, aging_en,
    input wire [15:0] age_thresh,
    input wire [3:0] acl_priority, hygro_priority,
    input wire acl_int1, acl_miso,
    output wire acl_cs_n, acl_sclk, acl_mosi,
    inout wire hygro_scl, hygro_sda,
    output wire [1:0] req, grant, done, initialized, fault,
    output wire acl_valid, hygro_valid, hygro_converting,
    output wire signed [15:0] x,y,z,
    output wire [15:0] temperature_raw, humidity_raw,
    output wire [2:0] hygro_error,
    output wire [31:0] hygro_retries
);
    arbiter arb(.clk(clk),.rst(rst),.req(req),.grant(grant),.done(done),
        .aging_en(aging_en),.age_thresh(age_thresh),.base_prio0(acl_priority),
        .base_prio1(hygro_priority),.eff_prio0(),.eff_prio1());
    adxl362_ctrl #(.CLK_DIV(ACL_SPI_DIV),.POWERUP_CYCLES(ACL_STARTUP_CYCLES)) acl(
        .clk(clk),.rst(rst),.req(req[0]),.grant(grant[0]),.done(done[0]),
        .int1_async(acl_int1),.cs_n(acl_cs_n),.sclk(acl_sclk),.mosi(acl_mosi),
        .miso(acl_miso),.id_ok(),.initialized(initialized[0]),.fault(fault[0]),
        .device_id(),.sample_valid(acl_valid),.x(x),.y(y),.z(z));
    hygro_service #(.I2C_HALF_PERIOD(I2C_HALF_PERIOD),.BUS_TIMEOUT_CYCLES(I2C_TIMEOUT_CYCLES),
        .STARTUP_CYCLES(HYGRO_STARTUP_CYCLES),.CONVERSION_CYCLES(HYGRO_CONVERSION_CYCLES),
        .SAMPLE_GAP_CYCLES(HYGRO_SAMPLE_GAP_CYCLES),.RETRY_CYCLES(HYGRO_RETRY_CYCLES)) hygro(
        .clk(clk),.rst(rst),.req(req[1]),.grant(grant[1]),.done(done[1]),
        .scl(hygro_scl),.sda(hygro_sda),.initialized(initialized[1]),.fault(fault[1]),
        .sample_valid(hygro_valid),.error_code(hygro_error),.manufacturer_id(),.device_id(),
        .temperature_raw(temperature_raw),.humidity_raw(humidity_raw),
        .retry_count(hygro_retries),.converting(hygro_converting));
endmodule
