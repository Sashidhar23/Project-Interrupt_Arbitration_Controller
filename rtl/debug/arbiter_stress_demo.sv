`timescale 1ns/1ps
// SYNTHETIC benchmark, separate from physical sensor controllers. Same arbiter RTL.
// Two permanently pending requesters for RUN_CYCLES; drain the final service.
// A rising start launches a fresh run, latching aging_enable for that whole run.
module arbiter_stress_demo #(
    parameter integer RUN_CYCLES=8192, SERVICE_CYCLES=32,
    parameter [15:0] AGE_THRESH=16'd16
)(input wire clk,rst,start,aging_enable,
    output wire [1:0] req,grant, output reg [1:0] done,
    output wire [8:0] eff0,eff1,
    output wire active,finished,start_event, output reg aging_latched,
    output wire [31:0] timestamp,wait0,wait1,max_wait0,max_wait1,grants0,grants1);
    localparam IDLE=0,RUN=1,DRAIN=2,FINISHED=3;
    reg [1:0] state;
    reg start_previous;
    reg [31:0] elapsed,service0,service1;
    assign active=(state==RUN)||(state==DRAIN);
    assign finished=(state==FINISHED);
    assign start_event=start&&!start_previous&&!active&&!rst;
    wire clear=rst||start_event;
    assign req=(state==RUN)?2'b11:(state==DRAIN)?grant:2'b00;
    arbiter arb(.clk(clk),.rst(clear),.req(req),.grant(grant),.done(done),
        .aging_en(aging_latched),.age_thresh(AGE_THRESH),.base_prio0(4'd7),
        .base_prio1(4'd1),.eff_prio0(eff0),.eff_prio1(eff1));
    arbiter_metrics metrics(.clk(clk),.rst(clear),.req(req),.grant(grant),
        .timestamp(timestamp),.wait0(wait0),.wait1(wait1),.max_wait0(max_wait0),
        .max_wait1(max_wait1),.grants0(grants0),.grants1(grants1));
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE; start_previous<=0; elapsed<=0; aging_latched<=0;
            service0<=0; service1<=0; done<=0;
        end else begin
            start_previous<=start; done<=0;
            if(start_event) begin
                state<=RUN; elapsed<=0; aging_latched<=aging_enable;
                service0<=0; service1<=0;
            end else begin
                if(state==RUN) begin
                    if(elapsed==RUN_CYCLES-1) state<=DRAIN;
                    else elapsed<=elapsed+1'b1;
                end else if(state==DRAIN && grant==0) state<=FINISHED;
                if(!grant[0] || done[0]) service0<=0;
                else if(service0==SERVICE_CYCLES-1) begin done[0]<=1; service0<=0; end
                else service0<=service0+1'b1;
                if(!grant[1] || done[1]) service1<=0;
                else if(service1==SERVICE_CYCLES-1) begin done[1]<=1; service1<=0; end
                else service1<=service1+1'b1;
            end
        end
    end
endmodule
