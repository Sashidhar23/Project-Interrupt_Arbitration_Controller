`timescale 1ns/1ps
// OLED bring-up with debug LEDs (no multimeter needed). All-pixels-on test.
//  LD0 ready | LD1 VDDC on (lit = on) | LD2 VBATC on (lit = on) | LD3 RES high
//  LD4 CS active (stretched) | LD5 SCLK activity (stretched) | LD6 SDIN activity | LD7 D/C=data seen
module oled_dbg_top (
    input  wire clk, btn_rst,
    output wire oled_cs_n, oled_sdin, oled_sclk, oled_dc,
    output wire oled_res_n, oled_vbatc_n, oled_vddc_n,
    output wire [7:0] led
);
    logic [3:0] por = '0;
    wire por_busy = ~&por;
    always_ff @(posedge clk) if (por_busy) por <= por + 1'b1;
    wire rst;
    reset_sync #(.STAGES(2)) u_rst (.clk(clk), .arst(por_busy | btn_rst), .rst(rst));

    wire ready;
    oled_acl2_view #(.CLK_DIV(25), .T_1MS(100_000), .T_100MS(10_000_000),
                     .REFRESH_CYCLES(10_000_000), .FLIP(1'b0), .ALL_ON(1'b0)) u_oled (
        .clk(clk), .rst(rst),
        .x(-16'sd1075), .y(-16'sd275), .z(16'sd1000), .device_id(8'hAD),
        .id_ok(1'b1), .initialized(1'b1), .fault(1'b0),
        .oled_cs_n(oled_cs_n), .oled_dc(oled_dc), .oled_res_n(oled_res_n),
        .oled_vbatc_n(oled_vbatc_n), .oled_vddc_n(oled_vddc_n),
        .oled_sclk(oled_sclk), .oled_sdin(oled_sdin), .ready(ready));

    // stretch short events so the eye can see them (~84 ms)
    logic [23:0] s_cs = '0, s_clk = '0, s_din = '0, s_dc = '0;
    always_ff @(posedge clk) begin
        s_cs  <= (!oled_cs_n) ? '1 : (s_cs  != 0) ? s_cs  - 1'b1 : 24'd0;
        s_clk <= (oled_sclk)  ? '1 : (s_clk != 0) ? s_clk - 1'b1 : 24'd0;
        s_din <= (oled_sdin)  ? '1 : (s_din != 0) ? s_din - 1'b1 : 24'd0;
        s_dc  <= (oled_dc)    ? '1 : (s_dc  != 0) ? s_dc  - 1'b1 : 24'd0;
    end
    assign led = {s_dc != 0, s_din != 0, s_clk != 0, s_cs != 0,
                  oled_res_n, ~oled_vbatc_n, ~oled_vddc_n, ready};
endmodule