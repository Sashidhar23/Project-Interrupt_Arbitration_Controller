`timescale 1ns/1ps
// Simulation-only IP stand-ins. Hardware uses generated AMD IP, not these modules.
module vio_arb(input wire clk,input wire probe_in0,probe_in1,
 input wire [31:0] probe_in2,probe_in3,probe_in4,probe_in5,
 output reg probe_out0,probe_out1,probe_out2,probe_out3);
 initial begin probe_out0=0;probe_out1=1;probe_out2=0;probe_out3=1;end
endmodule
module ila_arb(input wire clk,input wire [7:0] probe0,
 input wire [1:0] probe1,probe2,probe3,input wire [8:0] probe4,probe5,
 input wire [31:0] probe6,probe7,probe8,input wire probe9);
endmodule
module tb_arbiter_debug;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [1:0] req=0,grant=0,done=0;wire aging;
 arbiter_debug dut(.clk(clk),.rst(rst),.live_req(req),.live_grant(grant),.live_done(done),
 .initialized(2'b11),.fault(2'b00),.live_eff0(9'd7),.live_eff1(9'd1),.live_aging_enable(aging));
 initial begin
  repeat(4) @(negedge clk);rst=0;
  if(aging!==1) $fatal(1,"live aging default");
  req=3;grant=1;repeat(4) @(negedge clk);
  if(dut.capture.probe1!==3 || dut.capture.probe2!==1 || dut.control.probe_in2!==1)
   $fatal(1,"real source mux/counter");
  grant=0;req=0;
  dut.control.probe_out2=1;dut.control.probe_out1=0;
  dut.control.probe_out0=1;@(negedge clk);dut.control.probe_out0=0;
  wait(dut.finished);repeat(3) @(negedge clk);
  if(dut.control.probe_in2!==241 || dut.control.probe_in3!==0 || dut.control.probe_in5!==8192)
   $fatal(1,"OFF summary wiring");
  if(aging!==1) $fatal(1,"benchmark changed real aging");
  dut.control.probe_out1=1;dut.control.probe_out0=1;
  @(negedge clk);dut.control.probe_out0=0;
  wait(dut.active);wait(dut.finished);repeat(3) @(negedge clk);
  if(dut.control.probe_in2!==181 || dut.control.probe_in3!==60 || dut.control.probe_in5!==103)
   $fatal(1,"ON summary wiring");
  dut.control.probe_out2=0;req=2;grant=2;repeat(4) @(negedge clk);
  if(dut.capture.probe1!==2 || dut.capture.probe2!==2 || dut.control.probe_in3!==1)
   $fatal(1,"return to live source");
  dut.control.probe_out3=0;@(negedge clk);if(aging!==0) $fatal(1,"live control wiring");
  $display("PASS debug wrapper: live/test mux, VIO controls, OFF/ON summaries, live isolation");$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
