`timescale 1ns/1ps
// Async-assert, sync-deassert reset. arst and rst are active high.
module reset_sync #(parameter int STAGES = 2) (
    input  wire clk,
    input  wire arst,
    output wire rst
);
    (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] s = '1;
    always_ff @(posedge clk or posedge arst)
        if (arst) s <= '1;
        else      s <= {s[STAGES-2:0], 1'b0};
    assign rst = s[STAGES-1];
endmodule
