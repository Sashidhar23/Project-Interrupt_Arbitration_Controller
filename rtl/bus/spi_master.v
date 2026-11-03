// SPI master, mode 0 (CPOL=0, CPHA=0), MSB first, one byte per start.
// SCLK = clk / (2*CLK_DIV).  100 MHz, CLK_DIV=50 -> 1 MHz.
// MOSI changes on the FALLING edge of SCLK, MISO is sampled on the RISING edge.
// Keep CLK_DIV >= 4 (the 2-flop MISO synchronizer adds ~2 clocks of latency).
module spi_master #(
    parameter CLK_DIV = 50
)(
    input  wire       clk,
    input  wire       rst,        // synchronous, active high
    input  wire       start,      // 1-cycle pulse, ignored while busy
    input  wire [7:0] tx_data,
    output reg  [7:0] rx_data,    // valid when done pulses
    output reg        busy,
    output reg        done,       // 1-cycle pulse when the byte is complete
    output reg        sclk,       // idles low
    output reg        mosi,
    input  wire       miso
);

    // 2-flop synchronizer for MISO
    reg miso_s1, miso_s2;
    always @(posedge clk) begin
        miso_s1 <= miso;
        miso_s2 <= miso_s1;
    end

    reg [$clog2(CLK_DIV)-1:0] cnt;   // half-period counter
    reg [2:0] bitcnt;                // bits completed (0..7)
    reg [7:0] txr;                   // transmit shift register
    reg [7:0] rxr;                   // receive shift register

    always @(posedge clk) begin
        done <= 1'b0;                // default: pulse lasts one cycle

        if (rst) begin
            sclk    <= 1'b0;
            mosi    <= 1'b0;
            busy    <= 1'b0;
            cnt     <= 0;
            bitcnt  <= 3'd0;
            txr     <= 8'd0;
            rxr     <= 8'd0;
            rx_data <= 8'd0;
        end
        else if (!busy) begin
            sclk <= 1'b0;
            cnt  <= 0;
            if (start) begin
                txr    <= tx_data;
                mosi   <= tx_data[7];   // bit 7 is on MOSI BEFORE the first rising edge
                bitcnt <= 3'd0;
                busy   <= 1'b1;
            end
        end
        else begin
            if (cnt == CLK_DIV-1) begin
                cnt <= 0;
                if (!sclk) begin
                    // ---- RISING edge: sample MISO ----
                    sclk <= 1'b1;
                    rxr  <= {rxr[6:0], miso_s2};
                end
                else begin
                    // ---- FALLING edge: change MOSI / finish ----
                    sclk <= 1'b0;
                    if (bitcnt == 3'd7) begin
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        rx_data <= rxr;          // rxr already holds all 8 bits
                    end
                    else begin
                        bitcnt <= bitcnt + 3'd1;
                        mosi   <= txr[6];        // next bit
                        txr    <= {txr[6:0], 1'b0};
                    end
                end
            end
            else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule