`timescale 1ns/1ps
// =============================================================================
// tb_arbiter.v : self-checking testbench for the priority+aging arbiter
// Eight independent experiments run side by side on the same clock.
//   S1  priority order        : ch0 high prio, both fire same cycle   -> ch0 first
//   S2  priority order swapped: ch1 high prio                         -> ch1 first
//   S3  tie-break             : equal prio, both fire same cycle      -> ch0 first
//   S4  tie fairness          : equal prio, both saturating           -> alternate
//   S5  STARVATION, aging OFF : ch0 saturating, ch1 low-prio periodic -> ch1 starves
//   S6  same load, aging ON   : ch1 is served, wait bounded           -> no starvation
//   S7  random overload, aging OFF  \ same random streams, compare
//   S8  random overload, aging ON   /
// =============================================================================
module tb_arbiter;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;                       // 100 MHz

    localparam integer RUN_CYCLES = 60000;
    localparam integer THR  = 64;               // aging threshold used in S6/S8
    localparam integer PA   = 7, PB = 1;        // base priorities in S5..S8
    localparam integer SA   = 8, SB = 40;       // service cycles of ch0 / ch1 in S5/S6

    // ---------------- experiments ----------------
    arb_system #(.AGING_EN(0), .PRIO0(7), .PRIO1(1), .MODE0(3), .DELAY0(20), .SERV0(8), .MODE1(3), .DELAY1(20), .SERV1(8)) s1 (clk, rst);
    arb_system #(.AGING_EN(0), .PRIO0(1), .PRIO1(7), .MODE0(3), .DELAY0(20), .SERV0(8), .MODE1(3), .DELAY1(20), .SERV1(8)) s2 (clk, rst);
    arb_system #(.AGING_EN(0), .PRIO0(4), .PRIO1(4), .MODE0(3), .DELAY0(20), .SERV0(8), .MODE1(3), .DELAY1(20), .SERV1(8)) s3 (clk, rst);
    arb_system #(.AGING_EN(0), .PRIO0(4), .PRIO1(4), .MODE0(2), .SERV0(8), .MODE1(2), .SERV1(8)) s4 (clk, rst);

    arb_system #(.AGING_EN(0), .AGE_THRESH(THR), .PRIO0(PA), .PRIO1(PB),
                 .MODE0(2), .SERV0(SA), .MODE1(0), .PERIOD1(2000), .SERV1(SB), .DELAY1(100)) s5 (clk, rst);
    arb_system #(.AGING_EN(1), .AGE_THRESH(THR), .PRIO0(PA), .PRIO1(PB),
                 .MODE0(2), .SERV0(SA), .MODE1(0), .PERIOD1(2000), .SERV1(SB), .DELAY1(100)) s6 (clk, rst);

    arb_system #(.AGING_EN(0), .AGE_THRESH(THR), .PRIO0(PA), .PRIO1(PB),
                 .MODE0(1), .PROB0(30000), .SERV0(10), .SEED0(16'hACE1),
                 .MODE1(1), .PROB1(6000), .SERV1(30), .SEED1(16'h1D2B)) s7 (clk, rst);
    arb_system #(.AGING_EN(1), .AGE_THRESH(THR), .PRIO0(PA), .PRIO1(PB),
                 .MODE0(1), .PROB0(30000), .SERV0(10), .SEED0(16'hACE1),
                 .MODE1(1), .PROB1(6000), .SERV1(30), .SEED1(16'h1D2B)) s8 (clk, rst);

    // ---------------- check helpers ----------------
    integer fails = 0, checks = 0;
    task check(input cond, input [8*96-1:0] msg);
        begin
            checks = checks + 1;
            if (cond) $display("  PASS: %0s", msg);
            else begin $display("  FAIL: %0s", msg); fails = fails + 1; end
        end
    endtask

    function real jain(input integer a, input integer b);
        real x, y;
        begin
            x = a; y = b;
            if (a + b == 0) jain = 1.0;
            else            jain = ((x + y) * (x + y)) / (2.0 * (x * x + y * y));
        end
    endfunction

    // print a stats table for one system
    task report(input [8*24-1:0] name,
                input integer n0, input integer mn0, input integer mx0, input real avg0,
                input integer n1, input integer mn1, input integer mx1, input real avg1);
        begin
            $display("  %0s", name);
            $display("    ch0: grants=%6d  latency min/avg/max = %0d / %0.1f / %0d", n0, mn0, avg0, mx0);
            $display("    ch1: grants=%6d  latency min/avg/max = %0d / %0.1f / %0d", n1, mn1, avg1, mx1);
            $display("    Jain index (grant counts) = %0.3f", jain(n0, n1));
        end
    endtask

    // generic protocol/integrity check on one system
    task protocol_ok(input [8*8-1:0] tag, input integer em, input integer es, input integer ep, input integer ee);
        begin
            check(em == 0, {tag, ": never both grants at once"});
            check(es == 0, {tag, ": no grant without a request"});
            check(ep == 0, {tag, ": no preemption (grant held until done)"});
            check(ee == 0, {tag, ": no interrupt event lost"});
        end
    endtask

    integer bound, wB_max;
    real avg;

    initial begin
        $dumpfile("tb_arbiter.vcd");
        $dumpvars(2, tb_arbiter.s5);
        $dumpvars(2, tb_arbiter.s6);

        repeat (5) @(posedge clk);
        rst = 0;
        repeat (RUN_CYCLES) @(posedge clk);
        @(negedge clk);

        // ------------------------------------------------------------------
        $display("\n=== S1: higher priority (ch0=7 > ch1=1) wins a simultaneous request ===");
        check(s1.fg0 < s1.fg1, "ch0 served before ch1");
        check(s1.n0 == 1 && s1.n1 == 1, "both eventually served exactly once");
        protocol_ok("S1", s1.err_mutex, s1.err_spurious, s1.err_preempt, s1.err_event);

        $display("\n=== S2: swapped priorities (ch0=1 < ch1=7) ===");
        check(s2.fg1 < s2.fg0, "ch1 served before ch0");
        protocol_ok("S2", s2.err_mutex, s2.err_spurious, s2.err_preempt, s2.err_event);

        $display("\n=== S3: equal priority tie -> least-recently-served (ch0 after reset) ===");
        check(s3.fg0 < s3.fg1, "ch0 wins the first tie");
        protocol_ok("S3", s3.err_mutex, s3.err_spurious, s3.err_preempt, s3.err_event);

        $display("\n=== S4: equal priority, both saturating -> grants alternate ===");
        $display("  grants ch0=%0d ch1=%0d", s4.n0, s4.n1);
        check((s4.n0 > s4.n1 ? s4.n0 - s4.n1 : s4.n1 - s4.n0) <= 1, "grant counts differ by at most 1");
        check(s4.n0 > 100, "arbiter kept running (>100 grants)");
        protocol_ok("S4", s4.err_mutex, s4.err_spurious, s4.err_preempt, s4.err_event);

        // ------------------------------------------------------------------
        $display("\n=== S5: ch0 saturating (prio 7), ch1 periodic (prio 1), AGING OFF ===");
        wB_max = (s5.w1 > s5.mx1) ? s5.w1 : s5.mx1;     // include a wait that is still running
        avg = (s5.n0 > 0) ? $itor(s5.sum0) / s5.n0 : 0.0;
        report("fixed priority", s5.n0, s5.mn0, s5.mx0, avg, s5.n1, 0, wB_max, 0.0);
        $display("    ch1 is STILL WAITING after %0d cycles (current wait = %0d)", RUN_CYCLES, s5.w1);
        check(s5.n1 == 0, "ch1 starved: never granted while ch0 saturates");
        check(s5.w1 > RUN_CYCLES - 1000, "ch1 wait grows with the whole run (unbounded)");
        protocol_ok("S5", s5.err_mutex, s5.err_spurious, s5.err_preempt, s5.err_event);

        $display("\n=== S6: identical load, AGING ON (threshold %0d cycles/step) ===", THR);
        bound = (PA - PB) * THR + 2 * (SA + 3) + 8;
        avg = $itor(s6.sum0) / s6.n0;
        report("priority + aging", s6.n0, s6.mn0, s6.mx0, avg, s6.n1, s6.mn1, s6.mx1, $itor(s6.sum1) / ((s6.n1 > 0) ? s6.n1 : 1));
        $display("    analytic bound for ch1 wait = (%0d-%0d)*%0d + 2*(%0d+3) + 8 = %0d cycles", PA, PB, THR, SA, bound);
        check(s6.n1 > 10, "ch1 is now served repeatedly (no starvation)");
        check(s6.mx1 <= bound, "ch1 worst-case wait is within the analytic bound");
        check(s6.mn1 >= (PA - PB) * THR, "ch1 never wins before its aging bonus has closed the priority gap");
        check(s6.n0 > 10 * s6.n1, "high-priority ch0 still gets the vast majority of grants");
        check(s6.mx0 <= SB + 8, "ch0 worst-case latency is just one ch1 service");
        check(s6.mx1 < wB_max, "aging cuts ch1 worst-case wait versus S5");
        protocol_ok("S6", s6.err_mutex, s6.err_spurious, s6.err_preempt, s6.err_event);

        // ------------------------------------------------------------------
        $display("\n=== S7 vs S8: random overload, same event streams, aging OFF vs ON ===");
        report("S7 aging OFF", s7.n0, s7.mn0, s7.mx0, $itor(s7.sum0) / s7.n0,
                               s7.n1, s7.mn1, s7.mx1, $itor(s7.sum1) / ((s7.n1 > 0) ? s7.n1 : 1));
        report("S8 aging ON ", s8.n0, s8.mn0, s8.mx0, $itor(s8.sum0) / s8.n0,
                               s8.n1, s8.mn1, s8.mx1, $itor(s8.sum1) / ((s8.n1 > 0) ? s8.n1 : 1));
        $display("    events  S7: ch0 irq=%0d coalesced=%0d | ch1 irq=%0d coalesced=%0d",
                 s7.irq0, s7.coal0, s7.irq1, s7.coal1);
        $display("    events  S8: ch0 irq=%0d coalesced=%0d | ch1 irq=%0d coalesced=%0d",
                 s8.irq0, s8.coal0, s8.irq1, s8.coal1);
        check(s8.mx1 < s7.mx1, "aging reduces ch1 worst-case wait");
        check(s8.n1 >= s7.n1, "aging does not reduce ch1 service count");
        check(s8.mx0 >= s7.mx0, "cost of aging: ch0 worst-case latency does not improve");
        check(jain(s8.n0, s8.n1) >= jain(s7.n0, s7.n1), "aging does not worsen Jain fairness index");
        protocol_ok("S7", s7.err_mutex, s7.err_spurious, s7.err_preempt, s7.err_event);
        protocol_ok("S8", s8.err_mutex, s8.err_spurious, s8.err_preempt, s8.err_event);

        $display("\n==============================================");
        if (fails == 0) $display("ALL %0d CHECKS PASSED", checks);
        else            $display("%0d OF %0d CHECKS FAILED", fails, checks);
        $display("==============================================");
        $finish;
    end

    // watchdog
    initial begin
        #(10 * (RUN_CYCLES + 1000) * 2);
        $display("TIMEOUT"); $finish;
    end
endmodule
