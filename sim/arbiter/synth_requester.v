`timescale 1ns/1ps
// =============================================================================
// synth_requester.v : SYNTHETIC INTERRUPT GENERATOR + fake sensor service model
// (simulation only; not meant for synthesis)
//
// Behaves like a real sensor controller as seen by the arbiter:
//   raw irq event -> sticky pending (req) -> wait for grant -> "service" for
//   SERVICE_CYCLES -> done pulse -> req drops (or stays high if a new event
//   arrived during the service, so nothing is lost).
//
// MODE
//   0 periodic : one event every PERIOD cycles
//   1 random   : each cycle an event with probability ~PROB/65536 (16-bit LFSR)
//   2 saturate : request is ALWAYS pending (re-requests the moment it finishes)
//   3 one-shot : a single event at START_DELAY
//
// Event accounting (checked by the testbench every cycle):
//   irq_count == served_count + coalesced_count + req + repend
//   coalesced = event arrived while one was already pending (merged, like a
//   sticky interrupt flag); repend = event arrived during service (kept).
// Grant-to-done time = SERVICE_CYCLES + 1 cycles.
// =============================================================================
module synth_requester #(
    parameter integer MODE           = 0,
    parameter integer PERIOD         = 1000,
    parameter integer PROB           = 656,
    parameter integer SERVICE_CYCLES = 8,
    parameter integer START_DELAY    = 0,
    parameter [15:0]  SEED           = 16'hACE1
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        grant,
    output reg         req,
    output reg         done,
    output reg         repend,
    output reg [31:0]  irq_count,
    output reg [31:0]  served_count,
    output reg [31:0]  coalesced_count
);
    reg [31:0] start_cnt, tmr, svc_cnt;
    reg [15:0] lfsr;
    reg        irq, serving, fired;

    wire active    = (start_cnt >= START_DELAY);
    wire finishing = serving && (svc_cnt >= SERVICE_CYCLES);

    always @(posedge clk) begin
        if (rst) begin
            start_cnt <= 0; tmr <= PERIOD-1; svc_cnt <= 0; lfsr <= SEED;
            irq <= 0; serving <= 0; fired <= 0;
            req <= 0; done <= 0; repend <= 0;
            irq_count <= 0; served_count <= 0; coalesced_count <= 0;
        end else begin
            done <= 1'b0;
            irq  <= 1'b0;
            lfsr <= (lfsr >> 1) ^ ({16{lfsr[0]}} & 16'hB400);
            if (start_cnt < START_DELAY) start_cnt <= start_cnt + 1;

            // ---------- raw interrupt source ----------
            case (MODE)
                0: if (active) begin
                       if (tmr >= PERIOD-1) begin tmr <= 0; irq <= 1'b1; end
                       else                       tmr <= tmr + 1;
                   end
                1: if (active && (lfsr < PROB)) irq <= 1'b1;
                default: if (active && !fired) begin irq <= 1'b1; fired <= 1'b1; end
            endcase

            // ---------- service completes ----------
            if (finishing) begin
                done         <= 1'b1;
                serving      <= 1'b0;
                served_count <= served_count + 1;
                if (MODE == 2) begin                 // saturating: instantly pending again
                    req       <= 1'b1;
                    repend    <= 1'b0;
                    irq_count <= irq_count + 1;
                end else begin
                    req    <= repend | irq;
                    repend <= 1'b0;
                    if (irq) begin
                        irq_count <= irq_count + 1;
                        if (repend) coalesced_count <= coalesced_count + 1;
                    end
                end
            end
            // ---------- ordinary interrupt arrival ----------
            else if (irq) begin
                irq_count <= irq_count + 1;
                if (serving) begin
                    if (repend) coalesced_count <= coalesced_count + 1;
                    else        repend <= 1'b1;
                end else if (req) coalesced_count <= coalesced_count + 1;
                else              req <= 1'b1;
            end

            // ---------- service start / progress ----------
            if (!serving && grant && req && !done) begin
                serving <= 1'b1;
                svc_cnt <= 1;
            end else if (serving && !finishing)
                svc_cnt <= svc_cnt + 1;
        end
    end
endmodule
