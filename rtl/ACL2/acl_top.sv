`timescale 1ns/1ps
// =============================================================================
// acl2_test_top.sv : stand-alone bring-up of the PMOD ACL2 (ADXL362) on a ZedBoard
//
// Uses your existing blocks unchanged: reset_sync, sync_input, spi_master,
// adxl362_ctrl and arbiter. Channel 1 of the arbiter is tied idle, so the
// ACL2 requester runs through exactly the req/grant/done path it will use in
// the final system.
//
// LED display (sw[3] selects the page)
//   sw[3]=0  STATUS : led0 id_ok   led1 initialized   led2 fault
//                     led3 heartbeat (toggles every HEARTBEAT_SAMPLES samples)
//                     led4 grant    led5 INT1 (synchronized)   led6 CS active
//   sw[3]=1  DATA   : sw[1:0] = 0 X, 1 Y, 2 Z, 3 DEVID_AD (expect 0xAD)
//                     sw[2]   = 0 low byte, 1 high byte of the selected value
// Debug: x, y, z, sample_valid and the SPI pins are marked for the ILA.
// =============================================================================
module acl2_test_top #(
    parameter int unsigned CLK_DIV           = 50,          // 100 MHz -> 1 MHz SPI
    parameter int unsigned POWERUP_CYCLES    = 10_000_000,  // 100 ms
    parameter int unsigned HEARTBEAT_SAMPLES = 50           // ~0.5 s at 100 Hz
) (
    input  logic       clk,        // 100 MHz
    input  logic       btn_rst,    // push button, resets the test
    input  logic [3:0] sw,
    output logic [7:0] led,
    // PMOD ACL2
    output wire        acl2_cs_n,
    output wire        acl2_sclk,
    output wire        acl2_mosi,
    input  wire        acl2_miso,
    input  wire        acl2_int1
);
    // ---------------- reset: power-on pulse OR button ----------------
    logic [3:0] por_cnt = '0;
    wire        por_busy = ~&por_cnt;
    always_ff @(posedge clk) if (por_busy) por_cnt <= por_cnt + 1'b1;

    wire rst;
    reset_sync #(.STAGES(2)) u_rst (.clk(clk), .arst(por_busy | btn_rst), .rst(rst));

    // ---------------- ACL2 requester + arbiter (ch1 idle) ----------------
    wire        acl2_req, acl2_done;
    wire [1:0]  grant;
    wire        id_ok, initialized, fault, sample_valid;
    wire [7:0]  device_id;
    (* MARK_DEBUG = "TRUE" *) wire signed [15:0] x, y, z;

    adxl362_ctrl #(.CLK_DIV(CLK_DIV), .POWERUP_CYCLES(POWERUP_CYCLES)) u_acl2 (
        .clk(clk), .rst(rst),
        .req(acl2_req), .grant(grant[0]), .done(acl2_done),
        .int1_async(acl2_int1),
        .cs_n(acl2_cs_n), .sclk(acl2_sclk), .mosi(acl2_mosi), .miso(acl2_miso),
        .id_ok(id_ok), .initialized(initialized), .fault(fault),
        .device_id(device_id), .sample_valid(sample_valid),
        .x(x), .y(y), .z(z)
    );

    wire [8:0] eff0_unused, eff1_unused;
    arbiter u_arb (
        .clk(clk), .rst(rst),
        .req({1'b0, acl2_req}), .done({1'b0, acl2_done}), .grant(grant),
        .aging_en(1'b0), .age_thresh(16'd1),
        .base_prio0(4'd1), .base_prio1(4'd0),
        .eff_prio0(eff0_unused), .eff_prio1(eff1_unused)
    );

    // ---------------- LED display ----------------
    wire int1_sync;
    sync_input u_int1_led (.clk(clk), .rst(rst), .async_in(acl2_int1), .sync_out(int1_sync));

    logic [$clog2(HEARTBEAT_SAMPLES+1)-1:0] sample_cnt;
    logic heartbeat;
    always_ff @(posedge clk) begin
        if (rst) begin
            sample_cnt <= '0;
            heartbeat  <= 1'b0;
        end else if (sample_valid) begin
            if (sample_cnt == HEARTBEAT_SAMPLES-1) begin
                sample_cnt <= '0;
                heartbeat  <= ~heartbeat;
            end else
                sample_cnt <= sample_cnt + 1'b1;
        end
    end

    logic [15:0] selected;
    always_comb begin
        case (sw[1:0])
            2'd0:    selected = x;
            2'd1:    selected = y;
            2'd2:    selected = z;
            default: selected = {8'h00, device_id};
        endcase
    end

    always_comb begin
        if (sw[3]) led = sw[2] ? selected[15:8] : selected[7:0];
        else       led = {1'b0, ~acl2_cs_n, int1_sync, grant[0], heartbeat, fault, initialized, id_ok};
    end
endmodule
