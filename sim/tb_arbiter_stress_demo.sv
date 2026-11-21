`timescale 1ns/1ps
module tb_arbiter_stress_demo;
    reg clk=0,rst=1,start=0,aging=0;
    always #5 clk=~clk;
    wire [1:0] req,grant,done;
    wire [8:0] e0,e1;
    wire active,finished,event_start,latched;
    wire [31:0] timestamp,w0,w1,m0,m1,g0,g1;
    arbiter_stress_demo dut(.clk(clk),.rst(rst),.start(start),.aging_enable(aging),
        .req(req),.grant(grant),.done(done),.eff0(e0),.eff1(e1),.active(active),
        .finished(finished),.start_event(event_start),.aging_latched(latched),
        .timestamp(timestamp),.wait0(w0),.wait1(w1),.max_wait0(m0),.max_wait1(m1),.grants0(g0),.grants1(g1));
    reg [1:0] prev_grant=0,prev_done=0;
    integer count0=0,count1=0,waiting0=0,waiting1=0,maximum0=0,maximum1=0;
    always @(posedge clk) begin
        if(rst || event_start) begin
            prev_grant=0; prev_done=0; count0=0; count1=0;
            waiting0=0; waiting1=0; maximum0=0; maximum1=0;
        end else begin
            if(grant==3) $fatal(1,"overlapping grants");
            if((done & ~grant)!=0) $fatal(1,"done without ownership");
            if((prev_grant & ~prev_done & ~grant)!=0) $fatal(1,"transaction preempted");
            if(grant[0]&&!prev_grant[0]) count0=count0+1;
            if(grant[1]&&!prev_grant[1]) count1=count1+1;
            waiting0=(req[0]&&!grant[0])?waiting0+1:0;
            waiting1=(req[1]&&!grant[1])?waiting1+1:0;
            if(waiting0>maximum0) maximum0=waiting0;
            if(waiting1>maximum1) maximum1=waiting1;
            prev_grant=grant; prev_done=done;
        end
    end
    task run_case(input mode);
        begin
            @(negedge clk); aging=mode; start=1;
            @(negedge clk); start=0;
            wait(grant!=0);
            if(grant!=1 || e0!=7) $fatal(1,"base priority did not win first grant");
            // Mid-run VIO changes must not change the latched test configuration.
            @(negedge clk); aging=~mode;
            wait(finished); repeat(3) @(negedge clk);
            if(latched!=mode || grant!=0 || req!=0) $fatal(1,"run latch/drain failure");
            if(g0!=count0 || g1!=count1 || m0!=maximum0 || m1!=maximum1)
                $fatal(1,"metric scoreboard mismatch");
            if(g0==0 || (!mode && g1!=0) || (mode && (g1<10 || m1>200)))
                $fatal(1,"priority/fairness failure");
            $display("PASS benchmark aging=%0d grants0=%0d grants1=%0d maxwait0=%0d maxwait1=%0d",mode,g0,g1,m0,m1);
        end
    endtask
    initial begin
        $dumpfile("build/arbiter_stress_demo.vcd"); $dumpvars(0,tb_arbiter_stress_demo);
        repeat(5) @(negedge clk); rst=0;
        run_case(0); run_case(1); run_case(0);
        $display("PASS stress demo: repeatable reset, priority first, aging service, no preemption, independent metric scoreboard");
        $finish;
    end
    initial begin #1000000; $fatal(1,"benchmark watchdog"); end
endmodule
