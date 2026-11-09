`timescale 1ns/1ps
// Standalone HYGRO bring-up, using arbiter channel 1 and existing reset module.
module hygro_test_top(input wire clk, btn_rst, input wire [2:0] sw,
    output reg [7:0] led, inout wire hygro_scl, hygro_sda);
    reg [3:0] por_count=0;
    wire por_busy=~&por_count;
    always @(posedge clk) if(por_busy) por_count<=por_count+1'b1;
    wire rst;
    reset_sync resetter(.clk(clk),.arst(por_busy|btn_rst),.rst(rst));
    wire req,done,initialized,fault,valid,converting;
    wire [1:0] grant;
    wire [2:0] error_code;
    wire [15:0] mid,did,temp,humidity;
    wire [31:0] retries;
    reg heartbeat;
    always @(posedge clk) if(rst) heartbeat<=0; else if(valid) heartbeat<=~heartbeat;
    arbiter arb(.clk(clk),.rst(rst),.req({req,1'b0}),.done({done,1'b0}),.grant(grant),
        .aging_en(1'b0),.age_thresh(16'd1),.base_prio0(4'd0),.base_prio1(4'd1),
        .eff_prio0(),.eff_prio1());
    hygro_service sensor(.clk(clk),.rst(rst),.req(req),.grant(grant[1]),.done(done),
        .scl(hygro_scl),.sda(hygro_sda),.initialized(initialized),.fault(fault),
        .sample_valid(valid),.error_code(error_code),.manufacturer_id(mid),.device_id(did),
        .temperature_raw(temp),.humidity_raw(humidity),.retry_count(retries),.converting(converting));
    always @* case(sw)
        0:led={error_code,converting,grant[1],heartbeat,fault,initialized};
        1:led=mid[15:8]; 2:led=mid[7:0]; 3:led=did[15:8];
        4:led=temp[15:8]; 5:led=temp[7:0];
        6:led=humidity[15:8]; default:led=humidity[7:0];
    endcase
endmodule
