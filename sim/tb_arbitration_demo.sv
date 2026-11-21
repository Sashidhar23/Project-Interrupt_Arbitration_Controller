`timescale 1ns/1ps
// Two copies of the SAME project arbiter, identical persistent synthetic workload.
// This is an arbiter test, not a physical SPI/I2C sensor model.
module tb_arbitration_demo;
 reg clk=0,reset=1,start=0;
 always #5 clk=~clk; // 100 MHz
 reg [1:0] phase=0; // 0 reset, 1 contention, 2 completed
 wire [1:0] request_off,grant_off,done_off,request_on,grant_on,done_on;
 wire [8:0] priority0_off,priority1_off,priority0_on,priority1_on;
 wire active_off,finished_off,active_on,finished_on;
 wire [31:0] grants0_off,grants1_off,max_wait0_off,max_wait1_off,wait0_off,wait1_off;
 wire [31:0] grants0_on,grants1_on,max_wait0_on,max_wait1_on,wait0_on,wait1_on;
 arbiter_stress_demo fixed_priority(.clk(clk),.rst(reset),.start(start),.aging_enable(1'b0),
 .req(request_off),.grant(grant_off),.done(done_off),.eff0(priority0_off),.eff1(priority1_off),
 .active(active_off),.finished(finished_off),.start_event(),.aging_latched(),.timestamp(),
 .wait0(wait0_off),.wait1(wait1_off),.max_wait0(max_wait0_off),.max_wait1(max_wait1_off),
 .grants0(grants0_off),.grants1(grants1_off));
 arbiter_stress_demo aging_priority(.clk(clk),.rst(reset),.start(start),.aging_enable(1'b1),
 .req(request_on),.grant(grant_on),.done(done_on),.eff0(priority0_on),.eff1(priority1_on),
 .active(active_on),.finished(finished_on),.start_event(),.aging_latched(),.timestamp(),
 .wait0(wait0_on),.wait1(wait1_on),.max_wait0(max_wait0_on),.max_wait1(max_wait1_on),
 .grants0(grants0_on),.grants1(grants1_on));
 reg [1:0] prev_off=0,prev_on=0,prev_done_off=0,prev_done_on=0;
 integer count00=0,count01=0,count10=0,count11=0;
 integer cycle=0,events,summary;
 reg first_off=0,first_on=0,saw_aging=0,saw_both=0;
 // Scoreboard samples at clock edges, just like the passive hardware counters.
 always @(posedge clk) begin
  if(reset || start) begin
   prev_off=0;prev_on=0;prev_done_off=0;prev_done_on=0;
   count00=0;count01=0;count10=0;count11=0;cycle=0;
   first_off=0;first_on=0;saw_aging=0;saw_both=0;
  end else begin
   cycle=cycle+1;
   if((^grant_off===1'bx) || (^grant_on===1'bx)) $fatal(1,"unknown grant");
   if(grant_off==3 || grant_on==3) $fatal(1,"mutual exclusion violated");
   if((done_off & ~grant_off)!=0 || (done_on & ~grant_on)!=0) $fatal(1,"completion without ownership");
   if((prev_off & ~prev_done_off & ~grant_off)!=0 || (prev_on & ~prev_done_on & ~grant_on)!=0)
    $fatal(1,"active transaction was preempted");
   if(!first_off && grant_off!=0) begin
    first_off=1;if(grant_off!=1) $fatal(1,"OFF first grant violates base priority");
   end
   if(!first_on && grant_on!=0) begin
    first_on=1;if(grant_on!=1) $fatal(1,"ON first grant violates base priority");
   end
   if(request_off==3 && request_on==3) saw_both=1;
   if(active_off && active_on && request_off!=request_on) $fatal(1,"offered workloads differ");
   if(priority0_off!=7 || priority1_off!=1) $fatal(1,"fixed priorities changed");
   if(request_on[1] && !grant_on[1] && priority1_on>1) saw_aging=1;
   if(grant_off[0]&&!prev_off[0]) count00=count00+1;
   if(grant_off[1]&&!prev_off[1]) count01=count01+1;
   if(grant_on[0]&&!prev_on[0]) count10=count10+1;
   if(grant_on[1]&&!prev_on[1]) count11=count11+1;
   if(grant_off!=prev_off || grant_on!=prev_on)
    $fdisplay(events,"%0d,%0t,%b,%b,%b,%b,%0d,%0d,%0d,%0d",cycle,$time,
      request_off,grant_off,request_on,grant_on,priority0_on,priority1_on,wait1_off,wait1_on);
   prev_off=grant_off;prev_on=grant_on;prev_done_off=done_off;prev_done_on=done_on;
  end
 end
 initial begin
  $dumpfile("arbitration_demo.vcd");$dumpvars(0,tb_arbitration_demo);
  events=$fopen("arbitration_events.csv","w");summary=$fopen("arbitration_results.csv","w");
  if(!events || !summary) $fatal(1,"cannot open results");
  $fdisplay(events,"cycle,time_ps,req_off,grant_off,req_on,grant_on,priority0_on,priority1_on,wait1_off,wait1_on");
  repeat(5) @(negedge clk);reset=0;
  @(negedge clk);start=1;phase=1;@(negedge clk);start=0;
  wait(finished_off && finished_on);repeat(3) @(negedge clk);phase=2;
  if(!first_off || !first_on || !saw_both || !saw_aging) $fatal(1,"required demonstration event missing");
  if(grants0_off!=count00 || grants1_off!=count01 || grants0_on!=count10 || grants1_on!=count11)
    $fatal(1,"independent grant scoreboard mismatch");
  if(grants1_off!=0 || max_wait1_off!=8192) $fatal(1,"OFF starvation window not demonstrated");
  if(grants0_on==0 || grants1_on<10 || max_wait1_on>200) $fatal(1,"ON bounded-wait check failed");
  if(grant_on!=0 || grant_off!=0 || request_on!=0 || request_off!=0) $fatal(1,"test did not drain");
  $fdisplay(summary,"mode,grants0,grants1,max_wait0_cycles,max_wait1_cycles");
  $fdisplay(summary,"OFF,%0d,%0d,%0d,%0d",grants0_off,grants1_off,max_wait0_off,max_wait1_off);
  $fdisplay(summary,"ON,%0d,%0d,%0d,%0d",grants0_on,grants1_on,max_wait0_on,max_wait1_on);
  $display("MODE  GRANTS0 GRANTS1 MAX_WAIT0 MAX_WAIT1 (cycles)");
  $display("OFF   %0d %0d %0d %0d",grants0_off,grants1_off,max_wait0_off,max_wait1_off);
  $display("ON    %0d %0d %0d %0d",grants0_on,grants1_on,max_wait0_on,max_wait1_on);
  $display("PASS: simultaneous contention, priority first, exclusive grants, no preemption, aging growth, OFF unserved wait, ON service and bounded observed wait");
  $fclose(events);$fclose(summary);#100;$finish;
 end
 initial begin #1000000;$fatal(1,"simulation watchdog");end
endmodule
