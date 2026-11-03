`timescale 1ns/1ps
// =============================================================================
// arb_system.v : arbiter + two synthetic requesters + latency trackers + checkers
// One self-contained "experiment". The testbench instantiates several with
// different parameters and runs them side by side.
// =============================================================================

// ---- measures request->grant latency of one channel ----
// latency = number of cycles the request was visible but not yet granted
module lat_tracker (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] cyc,
    input  wire        req,
    input  wire        grant,
    output reg  [31:0] n_grants,
    output reg  [31:0] lat_min,
    output reg  [31:0] lat_max,
    output reg  [63:0] lat_sum,
    output reg  [31:0] wcnt,            // current (still running) wait
    output reg  [31:0] first_grant_cyc
);
    reg grant_d;
    always @(posedge clk) begin
        if (rst) begin
            n_grants <= 0; lat_min <= 32'hFFFFFFFF; lat_max <= 0; lat_sum <= 0;
            wcnt <= 0; first_grant_cyc <= 32'hFFFFFFFF; grant_d <= 0;
        end else begin
            grant_d <= grant;
            if (grant && !grant_d) begin
                n_grants <= n_grants + 1;
                lat_sum  <= lat_sum + wcnt;
                if (wcnt > lat_max) lat_max <= wcnt;
                if (wcnt < lat_min) lat_min <= wcnt;
                if (n_grants == 0)  first_grant_cyc <= cyc;
                wcnt <= 0;
            end else if (req && !grant)
                wcnt <= wcnt + 1;
        end
    end
endmodule

module arb_system #(
    parameter         AGING_EN   = 1,
    parameter integer AGE_THRESH = 64,
    parameter [3:0]   PRIO0      = 4'd7,
    parameter [3:0]   PRIO1      = 4'd1,
    // requester 0
    parameter integer MODE0 = 2, parameter integer PERIOD0 = 1000, parameter integer PROB0 = 1000,
    parameter integer SERV0 = 8, parameter integer DELAY0  = 0,     parameter [15:0] SEED0 = 16'hACE1,
    // requester 1
    parameter integer MODE1 = 0, parameter integer PERIOD1 = 2000, parameter integer PROB1 = 1000,
    parameter integer SERV1 = 40, parameter integer DELAY1  = 0,    parameter [15:0] SEED1 = 16'h1D2B
)(
    input wire clk,
    input wire rst
);
    wire [1:0] req, done, grant;
    wire       repend0, repend1;
    wire [31:0] irq0, srv0, coal0, irq1, srv1, coal1;
    wire [8:0]  eff0, eff1;

    reg [31:0] cyc;
    always @(posedge clk) cyc <= rst ? 32'd0 : cyc + 1;

    arbiter dut (
        .clk(clk), .rst(rst), .req(req), .done(done), .grant(grant),
        .aging_en(AGING_EN[0]), .age_thresh(AGE_THRESH[15:0]),
        .base_prio0(PRIO0), .base_prio1(PRIO1),
        .eff_prio0(eff0), .eff_prio1(eff1)
    );

    synth_requester #(.MODE(MODE0), .PERIOD(PERIOD0), .PROB(PROB0),
                      .SERVICE_CYCLES(SERV0), .START_DELAY(DELAY0), .SEED(SEED0)) src0 (
        .clk(clk), .rst(rst), .grant(grant[0]), .req(req[0]), .done(done[0]), .repend(repend0),
        .irq_count(irq0), .served_count(srv0), .coalesced_count(coal0));

    synth_requester #(.MODE(MODE1), .PERIOD(PERIOD1), .PROB(PROB1),
                      .SERVICE_CYCLES(SERV1), .START_DELAY(DELAY1), .SEED(SEED1)) src1 (
        .clk(clk), .rst(rst), .grant(grant[1]), .req(req[1]), .done(done[1]), .repend(repend1),
        .irq_count(irq1), .served_count(srv1), .coalesced_count(coal1));

    wire [31:0] n0, mn0, mx0, w0, fg0, n1, mn1, mx1, w1, fg1;
    wire [63:0] sum0, sum1;
    lat_tracker lat0 (.clk(clk), .rst(rst), .cyc(cyc), .req(req[0]), .grant(grant[0]),
        .n_grants(n0), .lat_min(mn0), .lat_max(mx0), .lat_sum(sum0), .wcnt(w0), .first_grant_cyc(fg0));
    lat_tracker lat1 (.clk(clk), .rst(rst), .cyc(cyc), .req(req[1]), .grant(grant[1]),
        .n_grants(n1), .lat_min(mn1), .lat_max(mx1), .lat_sum(sum1), .wcnt(w1), .first_grant_cyc(fg1));

    // ---------------- always-on protocol checkers ----------------
    reg [31:0] err_mutex, err_spurious, err_preempt, err_event;
    reg [1:0]  gd, dd;
    always @(posedge clk) begin
        if (rst) begin
            err_mutex <= 0; err_spurious <= 0; err_preempt <= 0; err_event <= 0;
            gd <= 0; dd <= 0;
        end else begin
            gd <= grant; dd <= done;
            // never both granted
            if (grant == 2'b11) err_mutex <= err_mutex + 1;
            // a new grant must coincide with a live request
            if ((grant[0] && !gd[0] && !req[0]) || (grant[1] && !gd[1] && !req[1]))
                err_spurious <= err_spurious + 1;
            // grant may only fall one cycle after that channel's done pulse
            if ((gd[0] && !grant[0] && !dd[0]) || (gd[1] && !grant[1] && !dd[1]))
                err_preempt <= err_preempt + 1;
            // no interrupt event may vanish
            if (irq0 !== (srv0 + coal0 + req[0] + repend0) ||
                irq1 !== (srv1 + coal1 + req[1] + repend1))
                err_event <= err_event + 1;
        end
    end
endmodule
