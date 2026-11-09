`timescale 1ns/1ps
// HDC1080 at address 0x40. Trigger and read each acquire/release the arbiter.
module hygro_service #(
    parameter integer I2C_HALF_PERIOD=500,
    parameter integer BUS_TIMEOUT_CYCLES=1000000,
    parameter integer STARTUP_CYCLES=2000000,
    parameter integer CONVERSION_CYCLES=2000000,
    parameter integer SAMPLE_GAP_CYCLES=100000000,
    parameter integer RETRY_CYCLES=1000000,
    parameter integer MAX_READ_RETRIES=3
)(
    input wire clk, rst,
    output wire req,
    input wire grant,
    output wire done,
    inout wire scl, sda,
    output reg initialized, fault, sample_valid,
    output reg [2:0] error_code, // engine errors or 4 = wrong identity
    output reg [15:0] manufacturer_id, device_id, temperature_raw, humidity_raw,
    output reg [31:0] retry_count,
    output wire converting
);
    localparam BOOT=0, REQUEST=1, LAUNCH=2, WAIT_BUS=3, COMPLETE=4,
        RELEASE=5, CONVERT=6, PERIOD=7, FAILED=8;
    localparam MFG=0, DEVICE=1, CONFIGURE=2, TRIGGER=3, READ_SAMPLE=4;
    reg [3:0] state;
    reg [2:0] job;
    reg [31:0] timer, retries;
    reg retry_pending;
    reg [2:0] tx_count, rx_count;
    reg [31:0] tx_data;
    wire [31:0] rx_data;
    wire bus_busy,bus_done;
    wire [2:0] bus_error;
    assign req=state==REQUEST || state==LAUNCH || state==WAIT_BUS || state==COMPLETE;
    assign done=state==COMPLETE;
    assign converting=state==CONVERT;
    always @* begin
        tx_count=1; rx_count=2; tx_data=0;
        case(job)
            MFG: tx_data=32'h000000FE;
            DEVICE: tx_data=32'h000000FF;
            CONFIGURE: begin tx_count=3; rx_count=0; tx_data=32'h00001002; end
            TRIGGER: begin tx_count=1; rx_count=0; tx_data=0; end
            READ_SAMPLE: begin tx_count=0; rx_count=4; end
            default: begin end
        endcase
    end
    i2c_master #(.HALF_PERIOD(I2C_HALF_PERIOD),.TIMEOUT_CYCLES(BUS_TIMEOUT_CYCLES)) bus(
        .clk(clk),.rst(rst),.start(state==LAUNCH),.address(7'h40),
        .tx_count(tx_count),.rx_count(rx_count),.tx_data(tx_data),.rx_data(rx_data),
        .busy(bus_busy),.done(bus_done),.error(bus_error),.scl(scl),.sda(sda));
    always @(posedge clk) begin
        if(rst) begin
            state<=BOOT; job<=MFG; timer<=0; retries<=0; retry_pending<=0;
            initialized<=0; fault<=0; sample_valid<=0; error_code<=0;
            manufacturer_id<=0; device_id<=0; temperature_raw<=0; humidity_raw<=0;
            retry_count<=0;
        end else begin
            sample_valid<=0;
            case(state)
                BOOT: if(timer>=STARTUP_CYCLES-1) begin timer<=0; state<=REQUEST; end
                      else timer<=timer+1'b1;
                REQUEST: if(grant) state<=LAUNCH;
                LAUNCH: state<=WAIT_BUS;
                WAIT_BUS: if(bus_done) begin
                    retry_pending<=0; state<=COMPLETE;
                    if(bus_error!=0) begin
                        error_code<=bus_error;
                        if(job==READ_SAMPLE && bus_error==1 && retries<MAX_READ_RETRIES) begin
                            retries<=retries+1'b1; retry_count<=retry_count+1'b1; retry_pending<=1;
                        end else begin fault<=1; initialized<=0; end
                    end else begin
                        error_code<=0;
                        case(job)
                            MFG: begin
                                manufacturer_id<={rx_data[7:0],rx_data[15:8]};
                                if(rx_data[15:0]!=16'h4954) begin fault<=1; error_code<=4; end
                            end
                            DEVICE: begin
                                device_id<={rx_data[7:0],rx_data[15:8]};
                                if(rx_data[15:0]!=16'h5010) begin fault<=1; error_code<=4; end
                            end
                            CONFIGURE: initialized<=1;
                            TRIGGER: retries<=0;
                            READ_SAMPLE: begin
                                temperature_raw<={rx_data[7:0],rx_data[15:8]};
                                humidity_raw<={rx_data[23:16],rx_data[31:24]};
                                sample_valid<=1;
                            end
                            default: begin end
                        endcase
                    end
                end
                COMPLETE: state<=RELEASE;
                RELEASE: if(!grant) begin
                    timer<=0;
                    if(fault) state<=FAILED;
                    else if(job==TRIGGER || retry_pending) begin job<=READ_SAMPLE; state<=CONVERT; end
                    else if(job==READ_SAMPLE) begin job<=TRIGGER; state<=PERIOD; end
                    else begin job<=job+1'b1; state<=REQUEST; end
                end
                CONVERT: if(timer >= (retry_pending ? RETRY_CYCLES : CONVERSION_CYCLES)-1) begin
                    timer<=0; state<=REQUEST;
                end else timer<=timer+1'b1;
                PERIOD: if(timer>=SAMPLE_GAP_CYCLES-1) begin timer<=0; state<=REQUEST; end
                        else timer<=timer+1'b1;
                FAILED: state<=FAILED;
                default: begin fault<=1; initialized<=0; error_code<=3; state<=FAILED; end
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if(STARTUP_CYCLES<1 || CONVERSION_CYCLES<1 || SAMPLE_GAP_CYCLES<1 || RETRY_CYCLES<1 || MAX_READ_RETRIES<0)
            $fatal(1,"invalid HYGRO timing parameters");
    end
    // synthesis translate_on
endmodule
