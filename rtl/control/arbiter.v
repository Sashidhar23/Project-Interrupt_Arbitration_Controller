`timescale 1ns/1ps
// =============================================================================
// arbiter.v : 2-requester, non-preemptive, priority arbiter with aging
//
// Policy
//   effective_priority(i) = base_prio(i) + bonus(i)
//   bonus(i) grows by 1 every AGE_THRESH cycles that request i has been
//   waiting (req=1, not granted), saturating at 2^BONUS_W-1.
//   bonus is cleared when i is granted or drops its request.
//   Highest effective priority wins. TIE -> the requester that was NOT
//   served last (least-recently-served). After reset, channel 0 wins ties.
//   aging_en=0  -> bonus stays 0 -> plain fixed-priority arbiter (baseline).
//
// Handshake (same for every requester, so real sensor controllers drop in)
//   req[i]   : held high by requester i from "data pending" until it finishes
//   grant[i] : registered, one-hot; held until done[owner] pulses
//   done[i]  : 1-cycle pulse from requester i when its service is complete
//
// Non-preemptive: once granted, a requester keeps the grant until its done,
// no matter what the priorities do meanwhile (SPI/I2C frames can't be aborted).
// Decision latency: req seen in IDLE -> grant visible the next cycle.
// Between two services the arbiter spends 1 IDLE cycle (grant low).
//
// Synthesizable Verilog-2001. Synchronous active-high reset.
// =============================================================================
module arbiter #(
    parameter PRIO_W  = 4,                       // base priority width
    parameter BONUS_W = 8,                       // aging bonus width
    parameter THR_W   = 16,                      // aging threshold width
    parameter EFF_W   = ((BONUS_W > PRIO_W) ? BONUS_W : PRIO_W) + 1  // do not override
)(
    input  wire                clk,
    input  wire                rst,
    input  wire [1:0]          req,
    input  wire [1:0]          done,
    output reg  [1:0]          grant,
    // run-time configuration
    input  wire                aging_en,
    input  wire [THR_W-1:0]    age_thresh,       // cycles of waiting per +1 bonus (>=1)
    input  wire [PRIO_W-1:0]   base_prio0,
    input  wire [PRIO_W-1:0]   base_prio1,
    // visibility for debug / waveforms
    output wire [EFF_W-1:0]    eff_prio0,
    output wire [EFF_W-1:0]    eff_prio1
);
    localparam S_IDLE = 1'b0;
    localparam S_BUSY = 1'b1;
    localparam [BONUS_W-1:0] BONUS_MAX = {BONUS_W{1'b1}};

    reg                state;
    reg                owner;          // channel currently holding the grant
    reg                last_served;    // channel granted most recently
    reg [THR_W-1:0]    wait0, wait1;   // cycles since last bonus step
    reg [BONUS_W-1:0]  bonus0, bonus1; // aging bonus

    assign eff_prio0 = {{(EFF_W-PRIO_W){1'b0}},  base_prio0} + {{(EFF_W-BONUS_W){1'b0}}, bonus0};
    assign eff_prio1 = {{(EFF_W-PRIO_W){1'b0}},  base_prio1} + {{(EFF_W-BONUS_W){1'b0}}, bonus1};

    // ---------------- combinational winner selection ----------------
    reg win;          // which channel would win right now
    reg win_valid;    // at least one request pending
    always @* begin
        win_valid = |req;
        win       = 1'b0;
        case (req)
            2'b01:   win = 1'b0;
            2'b10:   win = 1'b1;
            2'b11:   begin
                if      (eff_prio0 > eff_prio1) win = 1'b0;
                else if (eff_prio1 > eff_prio0) win = 1'b1;
                else                            win = ~last_served;   // tie-break
            end
            default: win = 1'b0;
        endcase
    end

    // ---------------- state, grant and aging ----------------
    always @(posedge clk) begin
        if (rst) begin
            state       <= S_IDLE;
            owner       <= 1'b0;
            last_served <= 1'b1;        // so channel 0 wins the very first tie
            grant       <= 2'b00;
            wait0 <= {THR_W{1'b0}};  wait1 <= {THR_W{1'b0}};
            bonus0 <= {BONUS_W{1'b0}}; bonus1 <= {BONUS_W{1'b0}};
        end else begin
            // ---- aging counters: only while waiting (req && !grant) ----
            if (!req[0] || grant[0] || !aging_en) begin
                wait0 <= {THR_W{1'b0}}; bonus0 <= {BONUS_W{1'b0}};
            end else if (({1'b0, wait0} + 1) >= {1'b0, age_thresh}) begin
                wait0 <= {THR_W{1'b0}};
                if (bonus0 != BONUS_MAX) bonus0 <= bonus0 + 1'b1;
            end else
                wait0 <= wait0 + 1'b1;

            if (!req[1] || grant[1] || !aging_en) begin
                wait1 <= {THR_W{1'b0}}; bonus1 <= {BONUS_W{1'b0}};
            end else if (({1'b0, wait1} + 1) >= {1'b0, age_thresh}) begin
                wait1 <= {THR_W{1'b0}};
                if (bonus1 != BONUS_MAX) bonus1 <= bonus1 + 1'b1;
            end else
                wait1 <= wait1 + 1'b1;

            // ---- grant FSM (later assignments override the aging ones) ----
            case (state)
                S_IDLE: begin
                    if (win_valid) begin
                        grant       <= win ? 2'b10 : 2'b01;
                        owner       <= win;
                        last_served <= win;
                        state       <= S_BUSY;
                        if (win) begin wait1 <= {THR_W{1'b0}}; bonus1 <= {BONUS_W{1'b0}}; end
                        else     begin wait0 <= {THR_W{1'b0}}; bonus0 <= {BONUS_W{1'b0}}; end
                    end
                end
                S_BUSY: begin
                    if (done[owner]) begin      // only the owner can release
                        grant <= 2'b00;
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
