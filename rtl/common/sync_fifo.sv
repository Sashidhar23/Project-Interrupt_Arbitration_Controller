`timescale 1ns/1ps
// Single-clock, first-word-fall-through FIFO with ready/valid interfaces.
// Registered storage with combinational read: intended for small FIFOs,
// not a guaranteed block-RAM inference template.
module sync_fifo #(
    parameter int unsigned DATA_WIDTH = 256,
    parameter int unsigned DEPTH = 16,
    parameter int unsigned COUNT_WIDTH = $clog2(DEPTH + 1)
) (
    input  logic clk,
    input  logic rst, // synchronous active high; empties queue
    input  logic wr_valid,
    output wire  wr_ready,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output wire  rd_valid,
    input  logic rd_ready,
    output wire  [DATA_WIDTH-1:0] rd_data,
    output wire  full,
    output wire  empty,
    output wire  [COUNT_WIDTH-1:0] occupancy
);
    localparam int unsigned PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [COUNT_WIDTH-1:0] count;
    wire push, pop;

    assign empty = (count == 0);
    assign full = (count == COUNT_WIDTH'(DEPTH));
    assign occupancy = count;
    assign rd_valid = !rst && !empty;
    assign pop = rd_valid && rd_ready;
    // A full queue may accept a replacement when its head is consumed.
    assign wr_ready = !rst && (!full || pop);
    assign push = wr_valid && wr_ready;
    // No combinational bypass on empty. Data is meaningful only if rd_valid.
    assign rd_data = rd_valid ? mem[rd_ptr] : '0;

    function automatic logic [PTR_WIDTH-1:0] next_ptr(
        input logic [PTR_WIDTH-1:0] ptr
    );
        if (ptr == PTR_WIDTH'(DEPTH - 1)) next_ptr = '0;
        else next_ptr = ptr + 1'b1;
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count <= '0;
        end else begin
            if (push) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= next_ptr(wr_ptr);
            end
            if (pop) rd_ptr <= next_ptr(rd_ptr);
            case ({push, pop})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
    // Memory is deliberately not reset: validity is determined by count.
    // synthesis translate_off
    initial begin
        if (DATA_WIDTH < 1 || DEPTH < 1)
            $fatal(1, "sync_fifo: DATA_WIDTH and DEPTH must be >= 1");
        if (COUNT_WIDTH < $clog2(DEPTH + 1))
            $fatal(1, "sync_fifo: COUNT_WIDTH too small");
    end
    // synthesis translate_on
endmodule
