`timescale 1ns/1ps
// Asynchronous assertion, synchronous deassertion. One instance per clock.
// arst must be a clean reset source, not an undebounced pushbutton.
module reset_sync #(
    parameter int unsigned STAGES = 2
) (
    input  logic clk,
    input  logic arst,
    output wire  rst
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    logic [STAGES-1:0] reset_pipe;

    always_ff @(posedge clk or posedge arst) begin
        if (arst)
            reset_pipe <= '1;
        else begin
            reset_pipe[0] <= 1'b0;
            for (int unsigned i = 1; i < STAGES; i++)
                reset_pipe[i] <= reset_pipe[i-1];
        end
    end
    assign rst = reset_pipe[STAGES-1];

    // synthesis translate_off
    initial begin
        if (STAGES < 2) $fatal(1, "reset_sync: STAGES must be >= 2");
    end
    // synthesis translate_on
endmodule
