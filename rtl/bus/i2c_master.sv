`timescale 1ns/1ps
// Single-master, bounded I2C transaction engine. clk is the only internal clock.
// Payload byte zero is bits [7:0]. tx_count/rx_count are each in 0..4.
// Both nonzero performs a repeated START between write and read.
module i2c_master #(
    parameter integer HALF_PERIOD = 500,
    parameter integer TIMEOUT_CYCLES = 1000000
)(
    input wire clk, rst, start,
    input wire [6:0] address,
    input wire [2:0] tx_count, rx_count,
    input wire [31:0] tx_data,
    output reg [31:0] rx_data,
    output wire busy,
    output reg done,
    output reg [2:0] error, // 0 success, 1 NACK, 2 timeout, 3 invalid length
    inout wire scl, sda
);
    localparam IDLE=0, FREE=1, START_HOLD=2, BIT_LOW=3, BIT_RISE=4,
        BIT_HIGH=5, BIT_FALL=6, ACK_LOW=7, ACK_RISE=8, ACK_HIGH=9,
        ACK_FALL=10, RESTART_LOW=11, RESTART_RISE=12, RESTART_HIGH=13,
        STOP_LOW=14, STOP_RISE=15, STOP_HIGH=16, STOP_FREE=17;
    reg [4:0] state;
    reg [31:0] timer, watchdog;
    reg [6:0] slave_address;
    reg [2:0] nw, nr, byte_index, bit_index;
    reg [31:0] write_payload;
    reg [7:0] shift_tx, shift_rx;
    reg reading, address_phase, nack;
    reg scl_low, sda_low;
    wire scl_sync, sda_sync;
    sync_input #(.RESET_VALUE(1'b1)) scl_input(.clk(clk),.rst(rst),.async_in(scl),.sync_out(scl_sync));
    sync_input #(.RESET_VALUE(1'b1)) sda_input(.clk(clk),.rst(rst),.async_in(sda),.sync_out(sda_sync));
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    assign busy = state != IDLE;
    wire receive_byte = reading && !address_phase;
    wire last_read = byte_index == nr-1'b1;
    wire half_elapsed = timer >= HALF_PERIOD-1;

    always @* begin
        scl_low=0; sda_low=0;
        case(state)
            START_HOLD: sda_low=1;
            BIT_LOW, BIT_RISE, BIT_HIGH, BIT_FALL: begin
                scl_low=(state==BIT_LOW || state==BIT_FALL);
                sda_low=!receive_byte && !shift_tx[bit_index];
            end
            ACK_LOW, ACK_RISE, ACK_HIGH, ACK_FALL: begin
                scl_low=(state==ACK_LOW || state==ACK_FALL);
                sda_low=receive_byte && !last_read;
            end
            RESTART_LOW: scl_low=1;
            STOP_LOW: begin scl_low=1; sda_low=1; end
            STOP_RISE, STOP_HIGH: sda_low=1;
            default: begin end
        endcase
        if (rst) begin scl_low=0; sda_low=0; end
    end

    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE; timer<=0; watchdog<=0; done<=0; error<=0;
            rx_data<=0; slave_address<=0; nw<=0; nr<=0; byte_index<=0;
            bit_index<=7; write_payload<=0; shift_tx<=0; shift_rx<=0;
            reading<=0; address_phase<=1; nack<=0;
        end else begin
            done<=0;
            if(state!=IDLE && watchdog>=TIMEOUT_CYCLES-1) begin
                // Release lines even if an external device holds SCL/SDA low.
                state<=IDLE; error<=2; done<=1; timer<=0;
            end else begin
                if(state!=IDLE) begin watchdog<=watchdog+1'b1; timer<=timer+1'b1; end
                case(state)
                    IDLE: if(start) begin
                        error<=0; rx_data<=0; watchdog<=0; timer<=0; nack<=0;
                        if(tx_count>4 || rx_count>4 || (tx_count==0 && rx_count==0)) begin
                            error<=3; done<=1;
                        end else begin
                            slave_address<=address; nw<=tx_count; nr<=rx_count;
                            write_payload<=tx_data; byte_index<=0; bit_index<=7;
                            reading<=(tx_count==0); address_phase<=1;
                            shift_tx<={address,(tx_count==0)}; state<=FREE;
                        end
                    end
                    FREE: begin
                        if(!scl_sync || !sda_sync) timer<=0;
                        else if(half_elapsed) begin timer<=0; state<=START_HOLD; end
                    end
                    START_HOLD: if(half_elapsed) begin timer<=0; state<=BIT_LOW; end
                    BIT_LOW: if(half_elapsed) begin timer<=0; state<=BIT_RISE; end
                    BIT_RISE: begin timer<=0; if(scl_sync) state<=BIT_HIGH; end
                    BIT_HIGH: if(half_elapsed) begin
                        if(receive_byte) shift_rx<={shift_rx[6:0],sda_sync};
                        timer<=0; state<=BIT_FALL;
                    end
                    BIT_FALL: begin
                        timer<=0;
                        if(bit_index==0) state<=ACK_LOW;
                        else begin bit_index<=bit_index-1'b1; state<=BIT_LOW; end
                    end
                    ACK_LOW: if(half_elapsed) begin timer<=0; state<=ACK_RISE; end
                    ACK_RISE: begin timer<=0; if(scl_sync) state<=ACK_HIGH; end
                    ACK_HIGH: if(half_elapsed) begin
                        if(!receive_byte && sda_sync) begin nack<=1; error<=1; end
                        if(receive_byte) rx_data[byte_index*8 +: 8]<=shift_rx;
                        timer<=0; state<=ACK_FALL;
                    end
                    ACK_FALL: begin
                        timer<=0; bit_index<=7;
                        if(nack) state<=STOP_LOW;
                        else if(address_phase) begin
                            address_phase<=0; byte_index<=0; shift_rx<=0;
                            shift_tx<=write_payload[7:0]; state<=BIT_LOW;
                        end else if(reading) begin
                            if(last_read) state<=STOP_LOW;
                            else begin byte_index<=byte_index+1'b1; shift_rx<=0; state<=BIT_LOW; end
                        end else if(byte_index+1'b1<nw) begin
                            byte_index<=byte_index+1'b1;
                            shift_tx<=write_payload[(byte_index+1)*8 +: 8]; state<=BIT_LOW;
                        end else if(nr!=0) begin
                            reading<=1; address_phase<=1; byte_index<=0;
                            shift_tx<={slave_address,1'b1}; state<=RESTART_LOW;
                        end else state<=STOP_LOW;
                    end
                    RESTART_LOW: if(half_elapsed) begin timer<=0; state<=RESTART_RISE; end
                    RESTART_RISE: begin timer<=0; if(scl_sync) state<=RESTART_HIGH; end
                    RESTART_HIGH: if(half_elapsed) begin timer<=0; state<=START_HOLD; end
                    STOP_LOW: if(half_elapsed) begin timer<=0; state<=STOP_RISE; end
                    STOP_RISE: begin timer<=0; if(scl_sync) state<=STOP_HIGH; end
                    STOP_HIGH: if(half_elapsed) begin timer<=0; state<=STOP_FREE; end
                    STOP_FREE: begin
                        if(!scl_sync || !sda_sync) timer<=0;
                        else if(half_elapsed) begin state<=IDLE; timer<=0; done<=1; end
                    end
                    default: begin state<=IDLE; error<=3; done<=1; end
                endcase
            end
        end
    end
    // synthesis translate_off
    initial begin
        if(HALF_PERIOD<4 || TIMEOUT_CYCLES<1) $fatal(1,"invalid I2C timing parameters");
    end
    // synthesis translate_on
endmodule
