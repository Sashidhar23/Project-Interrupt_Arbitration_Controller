`timescale 1ns/1ps
// OLED-only bring-up: fixed X/Y/Z so you know what the screen must show.
module oled_test_top (
    input  wire clk,          // 100 MHz
    input  wire btn_rst,      // BTNC
    output wire oled_cs_n, oled_sdin, oled_sclk, oled_dc,
    output wire oled_res_n, oled_vbatc_n, oled_vddc_n,
    output wire led0          // lit when the OLED is initialised and on
);
    logic [3:0] por = '0;
    wire por_busy = ~&por;
    always_ff @(posedge clk) if (por_busy) por <= por + 1'b1;
    wire rst;
    reset_sync #(.STAGES(2)) u_rst (.clk(clk), .arst(por_busy | btn_rst), .rst(rst));

    wire ready;
    oled_acl2_view #(.CLK_DIV(25), .T_1MS(100_000), .T_100MS(10_000_000),
                     .REFRESH_CYCLES(10_000_000), .FLIP(1'b0), .ALL_ON(1'b1)) u_oled (
        .clk(clk), .rst(rst),
        .x(-16'sd1075), .y(-16'sd275), .z(16'sd1000), .device_id(8'hAD),
        .id_ok(1'b1), .initialized(1'b1), .fault(1'b0),
        .oled_cs_n(oled_cs_n), .oled_dc(oled_dc), .oled_res_n(oled_res_n),
        .oled_vbatc_n(oled_vbatc_n), .oled_vddc_n(oled_vddc_n),
        .oled_sclk(oled_sclk), .oled_sdin(oled_sdin), .ready(ready));
    assign led0 = ready;
endmodule