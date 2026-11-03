`timescale 1ns/1ps
module fifo_case #(parameter int DEPTH = 3) (output logic done);
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst = 1, wr_valid = 0, rd_ready = 0;
    logic [31:0] wr_data = 0;
    wire wr_ready, rd_valid, full, empty;
    wire [31:0] rd_data;
    wire [$clog2(DEPTH+1)-1:0] occupancy;
    sync_fifo #(.DATA_WIDTH(32), .DEPTH(DEPTH)) dut (.*);
    logic [31:0] reference_data [0:DEPTH-1];
    int count = 0;
    logic [31:0] rng = 32'hABCDEF01 ^ 32'(DEPTH);

    task automatic step(input bit reset_now, input bit w, input bit r,
                        input logic [31:0] data);
        bit push, pop;
        @(negedge clk);
        rst = reset_now; wr_valid = w; rd_ready = r; wr_data = data;
        @(posedge clk);
        if (rst) begin
            if (wr_ready || rd_valid) $fatal(1, "handshake during reset");
            count = 0;
        end else begin
            if (int'(occupancy) != count) $fatal(1, "old occupancy mismatch");
            if (rd_valid != (count != 0)) $fatal(1, "valid mismatch");
            if (full != (count == DEPTH) || empty != (count == 0))
                $fatal(1, "flag mismatch");
            if (rd_valid && rd_data !== reference_data[0])
                $fatal(1, "DEPTH=%0d ordering/data mismatch", DEPTH);
            pop = rd_valid && rd_ready;
            if (wr_ready != ((count < DEPTH) || pop))
                $fatal(1, "ready mismatch");
            push = wr_valid && wr_ready;
            if (pop) begin
                for (int i=0; i<count-1; i++)
                    reference_data[i] = reference_data[i+1];
                count--;
            end
            if (push) begin
                reference_data[count] = wr_data;
                count++;
            end
        end
        #1;
        if (int'(occupancy) != count) $fatal(1, "new occupancy mismatch");
    endtask

    initial begin
        done = 0;
        step(1,0,0,0);
        step(0,0,1,0); // empty read attempt
        for (int i=0; i<DEPTH; i++) step(0,1,0,32'(i));
        step(0,1,0,32'hBAD); // full/stalled: no acceptance
        step(0,1,1,32'h12345678); // full simultaneous replacement
        for (int i=0; i<DEPTH+1; i++) step(0,0,1,0);
        for (int i=0; i<2000; i++) begin
            rng = {rng[30:0], rng[31]^rng[21]^rng[1]^rng[0]};
            step((i == 777), rng[0], rng[3], rng);
        end
        repeat (DEPTH+1) step(0,0,1,0);
        done = 1;
        $display("PASS FIFO DEPTH=%0d", DEPTH);
    end
endmodule

module tb_common;
    import config_pkg::*;
    wire d1,d3,d16;
    fifo_case #(.DEPTH(1)) f1(d1);
    fifo_case #(.DEPTH(3)) f3(d3);
    fifo_case #(.DEPTH(16)) f16(d16);
    logic clk = 0, arst = 0, async_in = 0;
    always #5 clk = ~clk;
    wire rst, sync_out;
    reset_sync #(.STAGES(2)) reset_dut(.*);
    sync_input #(.STAGES(2)) input_dut(.*);
    sensor_record_t record_value;
    logic [255:0] raw_record;
    logic sync_done = 0;

    initial begin
        if ($bits(sensor_record_t) != 256) $fatal(1,"record width");
        record_value = '0;
        record_value.source_id = 8'h01;
        record_value.status = 8'h02;
        record_value.x = -16'sd2;
        record_value.y = 16'sd3;
        record_value.z = -16'sd4;
        record_value.temperature_raw = 16'hABCD;
        record_value.humidity_raw = 16'h1234;
        record_value.arbitration_wait_cycles = 32'h11223344;
        raw_record = record_value;
        if (raw_record[31:0] !== 32'h00000201 ||
            raw_record[159:128] !== 32'h0003FFFE ||
            raw_record[191:160] !== 32'h0000FFFC ||
            raw_record[223:192] !== 32'h1234ABCD ||
            raw_record[255:224] !== 32'h11223344)
            $fatal(1,"record word layout");
        #2; arst = 1;
        #1; if (rst !== 1) $fatal(1,"async reset assertion");
        repeat (2) @(negedge clk);
        arst = 0;
        @(posedge clk); #1;
        if (rst !== 1) $fatal(1,"reset released early");
        @(posedge clk); #1;
        if (rst !== 0) $fatal(1,"reset release latency");
        @(negedge clk); async_in = 1;
        @(posedge clk); #1;
        if (sync_out !== 0) $fatal(1,"input synchronizer bypass");
        @(posedge clk); #1;
        if (sync_out !== 1) $fatal(1,"input synchronization latency");
        #1; arst = 1;
        #1; if (rst !== 1) $fatal(1,"second async assertion");
        @(posedge clk); #1;
        if (sync_out !== 0) $fatal(1,"input reset value");
        sync_done = 1;
        $display("PASS reset, synchronizer and record layout");
    end
    initial begin
        wait(d1 && d3 && d16 && sync_done);
        $display("ALL COMMON TESTS PASSED");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"test timeout");
    end
endmodule
