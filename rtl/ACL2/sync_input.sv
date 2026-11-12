`timescale 1ns/1ps
// Synchronizes ONE asynchronous single-bit level. Not a pulse catcher,
// debouncer, multi-bit CDC bridge or event counter.
module sync_input #(
    parameter int unsigned STAGES = 2,
    parameter bit RESET_VALUE = 1'b0
) (
    input  logic clk,
    input  logic rst, // synchronous, active high; connect reset_sync.rst
    input  logic async_in,
    output wire  sync_out
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    logic [STAGES-1:0] sync_pipe;

    always_ff @(posedge clk) begin
        if (rst)
            sync_pipe <= {STAGES{RESET_VALUE}};
        else begin
            sync_pipe[0] <= async_in;
            for (int unsigned i = 1; i < STAGES; i++)
                sync_pipe[i] <= sync_pipe[i-1];
        end
    end
    assign sync_out = sync_pipe[STAGES-1];

    // synthesis translate_off
    initial begin
        if (STAGES < 2) $fatal(1, "sync_input: STAGES must be >= 2");
    end
    // synthesis translate_on
endmodule