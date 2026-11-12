`timescale 1ns/1ps
// 12-bit binary -> 4-digit BCD, shift-and-add-3, 12 clocks. Pulse start with bin valid.
module bin2bcd12 (
    input  wire         clk,
    input  wire         start,
    input  wire [11:0]  bin,
    output logic [15:0] bcd,
    output logic        done
);
    logic [11:0] sh;
    logic [15:0] acc, a3, nxt;
    logic [3:0]  n;
    logic        busy = 1'b0;

    always_comb begin
        a3 = acc;
        for (int i = 0; i < 4; i++)
            if (acc[4*i +: 4] >= 4'd5) a3[4*i +: 4] = acc[4*i +: 4] + 4'd3;
        nxt = {a3[14:0], sh[11]};
    end

    always_ff @(posedge clk) begin
        done <= 1'b0;
        if (start) begin
            sh <= bin; acc <= '0; n <= '0; busy <= 1'b1;
        end else if (busy) begin
            acc <= nxt;
            sh  <= {sh[10:0], 1'b0};
            n   <= n + 1'b1;
            if (n == 4'd11) begin busy <= 1'b0; done <= 1'b1; bcd <= nxt; end
        end
    end
endmodule
