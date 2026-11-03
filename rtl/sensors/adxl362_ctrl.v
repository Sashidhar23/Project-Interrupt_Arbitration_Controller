`timescale 1ns/1ps
// ZedBoard ACL2 requester. rst is synchronous active high, in the clk domain.
// req spans a WHOLE transaction, including its one-cycle done indication.
module adxl362_ctrl #(
    parameter integer CLK_DIV = 50,                 // 100 MHz -> 1 MHz SPI
    parameter integer POWERUP_CYCLES = 10000000,    // 100 ms @ 100 MHz
    parameter integer BYTE_TIMEOUT_CYCLES = 32*CLK_DIV + 32
)(
    input wire clk, rst,
    output wire req,
    input wire grant,
    output wire done,
    input wire int1_async,
    output wire cs_n, sclk, mosi,
    input wire miso,
    output reg id_ok, initialized, fault,
    output reg [7:0] device_id,
    output reg sample_valid,
    output reg signed [15:0] x, y, z
);
    localparam BOOT=0, REQUEST=1, START_BYTE=2, WAIT_BYTE=3,
               COMPLETE=4, RELEASE=5, WAIT_IRQ=6, FAULTED=7;
    localparam ID=0, FILTER=1, MAP_IRQ=2, MEASURE=3, XYZ=4;
    reg [2:0] state, job, index;
    reg [31:0] timer;
    reg [7:0] address, value, tx;
    reg [47:0] payload;
    wire [7:0] rx;
    wire byte_done, byte_busy, irq;
    reg irq_previous, pending;
    wire irq_rise = initialized && irq && !irq_previous;
    wire take_event = state == REQUEST && grant && job == XYZ;

    sync_input irq_sync(.clk(clk), .rst(rst), .async_in(int1_async), .sync_out(irq));
    always @(posedge clk) begin
        if (rst) begin
            irq_previous <= 0;
            pending <= 0;
        end else begin
            irq_previous <= initialized && irq;
            if (irq_rise) pending <= 1;
            else if (take_event) pending <= 0;
        end
    end

    always @* begin
        case (job)
            ID:      begin address=8'h00; value=0; end
            FILTER:  begin address=8'h2C; value=8'h13; end // +/-2 g, half BW, 100 Hz
            MAP_IRQ: begin address=8'h2A; value=8'h01; end // active-high DATA_READY -> INT1
            MEASURE: begin address=8'h2D; value=8'h02; end // measurement mode
            default: begin address=8'h0E; value=0; end     // XDATA_L
        endcase
        case (index)
            0: tx = (job==ID || job==XYZ) ? 8'h0B : 8'h0A;
            1: tx = address;
            default: tx = value;
        endcase
    end

    assign req = state==REQUEST || state==START_BYTE || state==WAIT_BYTE || state==COMPLETE;
    assign done = state==COMPLETE;
    assign cs_n = !(state==START_BYTE || state==WAIT_BYTE);
    spi_master #(.CLK_DIV(CLK_DIV)) spi (
        .clk(clk), .rst(rst || state==FAULTED || fault),
        .start(state==START_BYTE && !byte_busy), .tx_data(tx), .rx_data(rx),
        .busy(byte_busy), .done(byte_done), .sclk(sclk), .mosi(mosi), .miso(miso)
    );

    always @(posedge clk) begin
        if (rst) begin
            state<=BOOT; job<=ID; index<=0; timer<=0; payload<=0;
            id_ok<=0; initialized<=0; fault<=0; device_id<=0;
            sample_valid<=0; x<=0; y<=0; z<=0;
        end else begin
            sample_valid<=0;
            case (state)
                BOOT: begin
                    if (timer >= POWERUP_CYCLES-1) begin timer<=0; state<=REQUEST; end
                    else timer<=timer+1'b1;
                end
                REQUEST: if (grant) begin index<=0; timer<=0; state<=START_BYTE; end
                START_BYTE: begin // previous byte has finished before this state is entered
                    timer<=0;
                    state<=WAIT_BYTE;
                end
                WAIT_BYTE: begin
                    if (byte_done) begin
                        if (job==XYZ && index>=2)
                            payload[(index-2)*8 +: 8] <= rx;
                        if (index == (job==XYZ ? 7 : 2)) begin
                            if (job==ID) begin
                                device_id<=rx;
                                id_ok<=(rx==8'hAD);
                                if (rx!=8'hAD) fault<=1;
                            end
                            if (job==MEASURE) initialized<=1;
                            if (job==XYZ) begin
                                // Each signed 12-bit axis is little-endian.
                                x <= {{4{payload[11]}},payload[11:0]};
                                y <= {{4{payload[27]}},payload[27:16]};
                                z <= {{4{rx[3]}},rx[3:0],payload[39:32]};
                                sample_valid<=1;
                            end
                            state<=COMPLETE;
                        end else begin index<=index+1'b1; state<=START_BYTE; end
                    end else if (timer >= BYTE_TIMEOUT_CYCLES-1) begin
                        fault<=1; initialized<=0; state<=COMPLETE;
                    end else timer<=timer+1'b1;
                end
                COMPLETE: state<=RELEASE;
                RELEASE: if (!grant) begin
                    if (fault) state<=FAULTED;
                    else if (job==MEASURE || job==XYZ) begin job<=XYZ; state<=WAIT_IRQ; end
                    else begin job<=job+1'b1; state<=REQUEST; end
                end
                WAIT_IRQ: if (pending) state<=REQUEST;
                FAULTED: state<=FAULTED; // reset to retry initialization
                default: begin fault<=1; state<=FAULTED; end
            endcase
        end
    end
endmodule
