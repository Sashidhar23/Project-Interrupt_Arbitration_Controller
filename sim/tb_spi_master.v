`timescale 1ns/1ps
module tb_spi_master;
    reg clk = 0, rst = 1, start = 0;
    reg [7:0] tx_data = 0;
    wire [7:0] rx_data;
    wire busy, done, sclk, mosi;

    always #5 clk = ~clk;   // 100 MHz

    // loopback: MISO = MOSI
    spi_master #(.CLK_DIV(5)) dut (
        .clk(clk), .rst(rst), .start(start), .tx_data(tx_data),
        .rx_data(rx_data), .busy(busy), .done(done),
        .sclk(sclk), .mosi(mosi), .miso(mosi)
    );

    integer i, errors = 0, sclk_edges;
    reg [7:0] test_bytes [0:4];

    // count rising SCLK edges in a transfer
    always @(posedge sclk) sclk_edges = sclk_edges + 1;

    task send_byte(input [7:0] b);
        begin
            sclk_edges = 0;
            @(posedge clk); tx_data <= b; start <= 1;
            @(posedge clk); start <= 0;
            @(posedge done);
            @(posedge clk);
            if (rx_data !== b) begin
                $display("FAIL: sent %h got %h", b, rx_data);
                errors = errors + 1;
            end else
                $display("PASS: sent %h got %h", b, rx_data);
            if (sclk_edges !== 8) begin
                $display("FAIL: %0d SCLK pulses (expected 8)", sclk_edges);
                errors = errors + 1;
            end
            if (sclk !== 1'b0) begin
                $display("FAIL: SCLK not idle low");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);
        test_bytes[0] = 8'hA5; test_bytes[1] = 8'h5A; test_bytes[2] = 8'hFF;
        test_bytes[3] = 8'h00; test_bytes[4] = 8'h0B;
        repeat (4) @(posedge clk);
        rst = 0;
        repeat (4) @(posedge clk);
        for (i = 0; i < 5; i = i + 1) begin
            send_byte(test_bytes[i]);
            repeat (3) @(posedge clk);
        end
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d ERRORS", errors);
        $finish;
    end
endmodule