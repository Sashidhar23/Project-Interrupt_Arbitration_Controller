`timescale 1ns/1ps
// ZedBoard: ACL2 on JA, HYGRO on JB, external PmodOLED on JC.
// Acquisition and the display use the same 100 MHz clock. No PS software needed.
module sensor_oled_top #(
    parameter integer ENABLE_DEBUG=0,
    parameter integer ACL_SPI_DIV=50, ACL_STARTUP_CYCLES=10000000,
    parameter integer I2C_HALF_PERIOD=500, I2C_TIMEOUT_CYCLES=1000000,
    parameter integer HYGRO_STARTUP_CYCLES=2000000, HYGRO_CONVERSION_CYCLES=2000000,
    parameter integer HYGRO_SAMPLE_GAP_CYCLES=100000000, HYGRO_RETRY_CYCLES=1000000,
    parameter integer RESET_HOLD_CYCLES=1000000,
    parameter integer OLED_CLK_DIV=25, OLED_T_1MS=100000, OLED_T_100MS=10000000,
    parameter integer OLED_REFRESH_CYCLES=10000000,
    parameter [15:0] AGE_THRESH=16'd1000,
    parameter [3:0] ACL_PRIORITY=4'd7, HYGRO_PRIORITY=4'd1
)(
    input wire clk, btn_rst,
    input wire acl2_int1, acl2_miso,
    output wire acl2_cs_n, acl2_sclk, acl2_mosi,
    inout wire hygro_scl, hygro_sda,
    output wire oled_cs_n, oled_sdin, oled_sclk, oled_dc,
    output wire oled_res_n, oled_vbatc_n, oled_vddc_n,
    output wire [7:0] led
);
    reg [3:0] por=0;
    wire por_busy=~&por;
    always @(posedge clk) if (por_busy) por <= por+1'b1;
    wire rst, display_rst;
    // Hold acquisition reset after the last button bounce for about 10 ms.
    reg [31:0] reset_hold=0;
    wire button_sync;
    sync_input u_btn(.clk(clk),.rst(por_busy),.async_in(btn_rst),.sync_out(button_sync));
    always @(posedge clk) begin
        if (por_busy || button_sync) reset_hold <= RESET_HOLD_CYCLES;
        else if (reset_hold != 0) reset_hold <= reset_hold-1'b1;
    end
    reset_sync u_rst(.clk(clk),.arst(por_busy || (reset_hold != 0)),.rst(rst));
    // Button reset clears sensor/cache state, but leaves the powered OLED running.
    // This avoids abruptly cycling the panel supplies on every button press.
    reset_sync u_display_rst(.clk(clk),.arst(por_busy),.rst(display_rst));
    wire [1:0] req,grant,done,initialized,fault;
    wire acl_valid,hygro_valid,converting,oled_ready;
    wire signed [15:0] x,y,z;
    wire [15:0] temperature_raw,humidity_raw;
    wire [671:0] text_frame;
    wire [8:0] debug_eff0,debug_eff1;
    wire live_aging_enable;
    generate if(ENABLE_DEBUG) begin : debug_build
        arbiter_debug debug_unit(.clk(clk),.rst(rst),.live_req(req),.live_grant(grant),
            .live_done(done),.initialized(initialized),.fault(fault),
            .live_eff0(debug_eff0),.live_eff1(debug_eff1),.live_aging_enable(live_aging_enable));
    end else begin : normal_build
        assign live_aging_enable=1'b1;
    end endgenerate
    sensor_hub #(.ACL_FILTER_CTL(8'h13),.ACL_SPI_DIV(ACL_SPI_DIV),.ACL_STARTUP_CYCLES(ACL_STARTUP_CYCLES),
        .I2C_HALF_PERIOD(I2C_HALF_PERIOD),.I2C_TIMEOUT_CYCLES(I2C_TIMEOUT_CYCLES),
        .HYGRO_STARTUP_CYCLES(HYGRO_STARTUP_CYCLES),.HYGRO_CONVERSION_CYCLES(HYGRO_CONVERSION_CYCLES),
        .HYGRO_SAMPLE_GAP_CYCLES(HYGRO_SAMPLE_GAP_CYCLES),.HYGRO_RETRY_CYCLES(HYGRO_RETRY_CYCLES)) hub (
        .clk(clk),.rst(rst),.aging_en(live_aging_enable),.age_thresh(AGE_THRESH),
        .acl_priority(ACL_PRIORITY),.hygro_priority(HYGRO_PRIORITY),
        .acl_int1(acl2_int1),.acl_miso(acl2_miso),.acl_cs_n(acl2_cs_n),.acl_sclk(acl2_sclk),.acl_mosi(acl2_mosi),
        .hygro_scl(hygro_scl),.hygro_sda(hygro_sda),.req(req),.grant(grant),.done(done),
        .initialized(initialized),.fault(fault),.acl_valid(acl_valid),.hygro_valid(hygro_valid),
        .hygro_converting(converting),.x(x),.y(y),.z(z),.temperature_raw(temperature_raw),
        .humidity_raw(humidity_raw),.debug_eff0(debug_eff0),.debug_eff1(debug_eff1),.hygro_error(),.hygro_retries());
    sensor_oled_text text_cache(.clk(clk),.rst(rst),.acl_valid(acl_valid),.hygro_valid(hygro_valid),
        .x(x),.y(y),.z(z),.temperature_raw(temperature_raw),.humidity_raw(humidity_raw),
        .initialized(initialized),.fault(fault),.frame_text(text_frame));
    oled_acl2_view #(.EXTERNAL_TEXT(1'b1),.CLK_DIV(OLED_CLK_DIV),.T_1MS(OLED_T_1MS),
        .T_100MS(OLED_T_100MS),.REFRESH_CYCLES(OLED_REFRESH_CYCLES)) display (
        .clk(clk),.rst(display_rst),.frame_text(text_frame),.x(16'sd0),.y(16'sd0),.z(16'sd0),
        .device_id(8'd0),.id_ok(1'b0),.initialized(1'b0),.fault(1'b0),.com_pins(8'h20),.flip_sw(1'b0),
        .oled_cs_n(oled_cs_n),.oled_sdin(oled_sdin),.oled_sclk(oled_sclk),.oled_dc(oled_dc),
        .oled_res_n(oled_res_n),.oled_vbatc_n(oled_vbatc_n),.oled_vddc_n(oled_vddc_n),.ready(oled_ready));
    reg [1:0] sample_toggle;
    always @(posedge clk) begin
        if (rst) sample_toggle <= 0;
        else begin
            if (acl_valid) sample_toggle[0] <= ~sample_toggle[0];
            if (hygro_valid) sample_toggle[1] <= ~sample_toggle[1];
        end
    end
    assign led = {sample_toggle, fault, initialized, |grant, oled_ready};
endmodule

