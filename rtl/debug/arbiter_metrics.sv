`timescale 1ns/1ps
// Passive observer. Wait counts include currently unserved requests; counters
// saturate at 2^32-1. Timestamp wraps every 42.94967296 seconds at 100 MHz.
module arbiter_metrics(input wire clk,rst, input wire [1:0] req,grant,
    output reg [31:0] timestamp,wait0,wait1,max_wait0,max_wait1,grants0,grants1);
    reg [1:0] previous_grant;
    function automatic [31:0] inc(input [31:0] v);
        inc=(&v)?v:v+1'b1;
    endfunction
    always @(posedge clk) begin
        if(rst) begin
            timestamp<=0; wait0<=0; wait1<=0; max_wait0<=0; max_wait1<=0;
            grants0<=0; grants1<=0; previous_grant<=0;
        end else begin
            timestamp<=timestamp+1'b1; previous_grant<=grant;
            if(req[0] && !grant[0]) begin
                wait0<=inc(wait0);
                if(inc(wait0)>max_wait0) max_wait0<=inc(wait0);
            end else wait0<=0;
            if(req[1] && !grant[1]) begin
                wait1<=inc(wait1);
                if(inc(wait1)>max_wait1) max_wait1<=inc(wait1);
            end else wait1<=0;
            if(grant[0]&&!previous_grant[0]) grants0<=inc(grants0);
            if(grant[1]&&!previous_grant[1]) grants1<=inc(grants1);
        end
    end
endmodule
