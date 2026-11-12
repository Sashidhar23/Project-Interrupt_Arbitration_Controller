`timescale 1ns/1ps
// =============================================================================
// oled_acl2_view : PMOD OLED (SSD1306, 128x32, 4 pages) text view of ACL2 data.
//   line0  ACL2 ID=hh OK        (BAD if !id_ok)
//   line1  X=+1075   line2  Y=-0275   line3  Z=+1000
// Power-up order (Digilent PmodOLED): VDD on, 1 ms, DISPLAY OFF, RES pulse,
// charge pump + precharge, VBAT on, 100 ms, contrast/remap/COM, DISPLAY ON.
// SPI mode 0, MSB first, CS framed per byte, D/C valid for the whole byte.
// =============================================================================
module oled_spi_tx #(parameter int unsigned CLK_DIV = 25) (   // half SCLK period in clks
    input  wire       clk, rst,
    input  wire       start,
    input  wire [7:0] byte_in,
    input  wire       dc_in,
    output logic      cs_n, sclk, sdin, dc,
    output logic      done
);
    typedef enum logic [1:0] {T_IDLE, T_LO, T_HI, T_TAIL} t_t;
    t_t st = T_IDLE;
    logic [7:0]  sh;
    logic [2:0]  bc;
    logic [15:0] cnt;
    wire tick = (cnt == CLK_DIV-1);

    always_ff @(posedge clk) begin
        done <= 1'b0;
        if (rst) begin
            st <= T_IDLE; cs_n <= 1'b1; sclk <= 1'b0; sdin <= 1'b0; dc <= 1'b0; cnt <= '0;
        end else case (st)
            T_IDLE: if (start) begin
                sh <= byte_in; dc <= dc_in; cs_n <= 1'b0; sclk <= 1'b0;
                cnt <= '0; bc <= '0; st <= T_LO;
            end
            T_LO: begin                       // present data, then rising edge
                sdin <= sh[7];
                if (tick) begin cnt <= '0; sclk <= 1'b1; st <= T_HI; end
                else cnt <= cnt + 1'b1;
            end
            T_HI: begin
                if (tick) begin
                    cnt <= '0; sclk <= 1'b0; sh <= {sh[6:0], 1'b0};
                    if (bc == 3'd7) st <= T_TAIL;
                    else begin bc <= bc + 1'b1; st <= T_LO; end
                end else cnt <= cnt + 1'b1;
            end
            T_TAIL: begin
                if (tick) begin cnt <= '0; cs_n <= 1'b1; done <= 1'b1; st <= T_IDLE; end
                else cnt <= cnt + 1'b1;
            end
        endcase
    end
endmodule

module oled_acl2_view #(
    parameter int unsigned CLK_DIV        = 25,          // OLED SPI = 100MHz/(2*CLK_DIV) = 2 MHz
    parameter int unsigned T_1MS          = 100_000,
    parameter int unsigned T_100MS        = 10_000_000,
    parameter int unsigned REFRESH_CYCLES = 10_000_000,  // 10 updates/s
    parameter bit          FLIP           = 1'b0,        // rotate 180 deg if upside down
    parameter bit          ALL_ON         = 1'b0,        // 1 = send 0xA5 (all pixels on) as a wiring test
    parameter logic [7:0]  CONTRAST       = 8'hCF        // 0x00..0xFF panel brightness
) (
    input  wire               clk, rst,
    input  wire signed [15:0] x, y, z,
    input  wire        [7:0]  device_id,
    input  wire               id_ok,
    input  wire               initialized,   // unused here (kept for interface)
    input  wire               fault,         // unused here (kept for interface)
    output wire               oled_cs_n,
    output wire               oled_dc,
    output logic              oled_res_n,
    output logic              oled_vbatc_n,
    output logic              oled_vddc_n,
    output wire               oled_sclk,
    output wire               oled_sdin,
    output logic              ready
);
    // ---------------- SPI byte engine ----------------
    logic       tx_start;
    logic [7:0] tx_byte;
    logic       tx_dc;
    wire        tx_done;
    oled_spi_tx #(.CLK_DIV(CLK_DIV)) u_tx (
        .clk(clk), .rst(rst), .start(tx_start), .byte_in(tx_byte), .dc_in(tx_dc),
        .cs_n(oled_cs_n), .sclk(oled_sclk), .sdin(oled_sdin), .dc(oled_dc), .done(tx_done));

    // ---------------- init command ROM ----------------
    function automatic logic [7:0] init_byte(input logic [4:0] i);
        case (i)
            5'd0:  init_byte = 8'hAE;                       // display off
            5'd1:  init_byte = 8'h8D;  5'd2: init_byte = 8'h14;   // charge pump on
            5'd3:  init_byte = 8'hD9;  5'd4: init_byte = 8'hF1;   // pre-charge
            5'd5:  init_byte = 8'h81;  5'd6: init_byte = CONTRAST;   // contrast
            5'd7:  init_byte = FLIP ? 8'hA0 : 8'hA1;        // segment remap
            5'd8:  init_byte = FLIP ? 8'hC0 : 8'hC8;        // COM scan direction
            5'd9:  init_byte = 8'hDA;  5'd10: init_byte = 8'h00;  // COM pins
            5'd11: init_byte = 8'hA4;                       // show RAM contents (cancel all-on)
            5'd12: init_byte = 8'hA6;                       // normal (non-inverted) display
            5'd13: init_byte = 8'h20;  5'd14: init_byte = 8'h02;  // page addressing mode
            5'd15: init_byte = 8'hAF;                       // display on
            default: init_byte = 8'hA5;                     // entire display ON (test only)
        endcase
    endfunction

    // ---------------- 5x7 font (column bytes, LSB = top row) ----------------
    function automatic logic [39:0] font5(input logic [7:0] ch);
        case (ch)
            "0": font5 = 40'h3E5149453E;  "1": font5 = 40'h00427F4000;  "2": font5 = 40'h4261514946;
            "3": font5 = 40'h2141454B31;  "4": font5 = 40'h1814127F10;  "5": font5 = 40'h2745454539;
            "6": font5 = 40'h3C4A494930;  "7": font5 = 40'h0171090503;  "8": font5 = 40'h3649494936;
            "9": font5 = 40'h064949291E;
            "A": font5 = 40'h7E1111117E;  "B": font5 = 40'h7F49494936;  "C": font5 = 40'h3E41414122;
            "D": font5 = 40'h7F4141221C;  "E": font5 = 40'h7F49494941;  "F": font5 = 40'h7F09090901;
            "I": font5 = 40'h00417F4100;  "K": font5 = 40'h7F08142241;  "L": font5 = 40'h7F40404040;
            "O": font5 = 40'h3E4141413E;  "X": font5 = 40'h6314081463;  "Y": font5 = 40'h0708700807;
            "Z": font5 = 40'h6151494543;
            "+": font5 = 40'h08083E0808;  "-": font5 = 40'h0808080808;  "=": font5 = 40'h1414141414;
            default: font5 = 40'h0;
        endcase
    endfunction

    // ---------------- latched frame data + BCD ----------------
    logic [7:0]  id_l;
    logic        ok_l, negx, negy, negz;
    logic [11:0] magx, magy, magz;
    logic        bcd_start;
    wire  [15:0] bx, by_, bz;
    wire         dx, dy, dz;
    bin2bcd12 u_bx (.clk(clk), .start(bcd_start), .bin(magx), .bcd(bx),  .done(dx));
    bin2bcd12 u_by (.clk(clk), .start(bcd_start), .bin(magy), .bcd(by_), .done(dy));
    bin2bcd12 u_bz (.clk(clk), .start(bcd_start), .bin(magz), .bcd(bz),  .done(dz));

    function automatic logic [7:0] hexc(input logic [3:0] n);
        hexc = (n < 4'd10) ? (8'h30 + {4'h0, n}) : (8'h41 + {4'h0, n} - 8'd10);
    endfunction

    function automatic logic [7:0] char_at(input logic [1:0] ln, input logic [4:0] ci);
        logic [7:0]  c;
        logic [15:0] b;
        logic        neg;
        c = 8'h20;
        if (ln == 2'd0) begin
            case (ci)
                5'd0: c = "A";  5'd1: c = "C";  5'd2: c = "L";  5'd3: c = "2";
                5'd5: c = "I";  5'd6: c = "D";  5'd7: c = "=";
                5'd8: c = hexc(id_l[7:4]);  5'd9: c = hexc(id_l[3:0]);
                5'd11: c = ok_l ? "O" : "B";
                5'd12: c = ok_l ? "K" : "A";
                5'd13: c = ok_l ? 8'h20 : "D";
                default: c = 8'h20;
            endcase
        end else begin
            b   = (ln == 2'd1) ? bx : (ln == 2'd2) ? by_ : bz;
            neg = (ln == 2'd1) ? negx : (ln == 2'd2) ? negy : negz;
            case (ci)
                5'd0: c = (ln == 2'd1) ? "X" : (ln == 2'd2) ? "Y" : "Z";
                5'd1: c = "=";
                5'd2: c = neg ? "-" : "+";
                5'd3: c = 8'h30 + {4'h0, b[15:12]};
                5'd4: c = 8'h30 + {4'h0, b[11:8]};
                5'd5: c = 8'h30 + {4'h0, b[7:4]};
                5'd6: c = 8'h30 + {4'h0, b[3:0]};
                default: c = 8'h20;
            endcase
        end
        return c;
    endfunction

    // ---------------- main FSM ----------------
    typedef enum logic [4:0] {S_BOOT, S_TMR, S_C0, S_RES, S_RES2, S_C1, S_VB, S_C2,
                              S_SEND, S_SENDW, S_LATCH, S_CONV, S_PG0, S_PB, S_PBW} st_t;
    st_t         st, nxt;
    logic [31:0] tmr;
    logic [4:0]  idx, last;
    logic [1:0]  ph;
    logic [1:0]  page;
    logic [7:0]  bi;
    logic [4:0]  ci;
    logic [2:0]  si;
    logic [39:0] g;
    logic [7:0]  pbyte;

    always_comb begin
        g = font5(char_at(page, ci));
        if (bi < 8'd3) begin
            case (bi[1:0])
                2'd0: pbyte = {6'b101100, 2'b00} | {6'd0, page};   // 0xB0 | page
                2'd1: pbyte = 8'h00;
                default: pbyte = 8'h10;
            endcase
        end else if (si == 3'd5 || ci > 5'd20) pbyte = 8'h00;
        else pbyte = g[39 - 8*si -: 8];
    end

    always_ff @(posedge clk) begin
        tx_start  <= 1'b0;
        bcd_start <= 1'b0;
        if (rst) begin
            st <= S_BOOT; oled_res_n <= 1'b1; oled_vbatc_n <= 1'b1; oled_vddc_n <= 1'b1;
            ready <= 1'b0; tmr <= '0; tx_dc <= 1'b0; tx_byte <= '0;
        end else case (st)
            S_BOOT:  begin oled_vddc_n <= 1'b0; tmr <= T_1MS; nxt <= S_C0; st <= S_TMR; end
            S_TMR:   if (tmr == 0) st <= nxt; else tmr <= tmr - 1'b1;

            S_C0:    begin idx <= 5'd0; last <= 5'd0;  ph <= 2'd0; st <= S_SEND; end   // DISPLAY OFF
            S_RES:   begin oled_res_n <= 1'b0; tmr <= T_1MS; nxt <= S_RES2; st <= S_TMR; end
            S_RES2:  begin oled_res_n <= 1'b1; tmr <= T_1MS; nxt <= S_C1;  st <= S_TMR; end
            S_C1:    begin idx <= 5'd1; last <= 5'd4;  ph <= 2'd1; st <= S_SEND; end   // charge pump, precharge
            S_VB:    begin oled_vbatc_n <= 1'b0; tmr <= T_100MS; nxt <= S_C2; st <= S_TMR; end
            S_C2:    begin idx <= 5'd5; last <= ALL_ON ? 5'd16 : 5'd15; ph <= 2'd2; st <= S_SEND; end   // contrast..DISPLAY ON

            S_SEND:  begin tx_byte <= init_byte(idx); tx_dc <= 1'b0; tx_start <= 1'b1; st <= S_SENDW; end
            S_SENDW: if (tx_done) begin
                if (idx == last) begin
                    case (ph)
                        2'd0:    st <= S_RES;
                        2'd1:    st <= S_VB;
                        default: begin ready <= 1'b1; st <= S_LATCH; end
                    endcase
                end else begin idx <= idx + 1'b1; st <= S_SEND; end
            end

            S_LATCH: begin
                id_l <= device_id; ok_l <= id_ok;
                negx <= x[15]; negy <= y[15]; negz <= z[15];
                magx <= x[15] ? 12'(-x) : x[11:0];
                magy <= y[15] ? 12'(-y) : y[11:0];
                magz <= z[15] ? 12'(-z) : z[11:0];
                st <= S_CONV;
            end
            S_CONV:  begin bcd_start <= 1'b1; tmr <= 32'd20; nxt <= S_PG0; st <= S_TMR; end

            S_PG0:   begin page <= 2'd0; bi <= 8'd0; ci <= 5'd0; si <= 3'd0; st <= S_PB; end
            S_PB:    begin tx_byte <= pbyte; tx_dc <= (bi >= 8'd3); tx_start <= 1'b1; st <= S_PBW; end
            S_PBW:   if (tx_done) begin
                if (bi == 8'd130) begin
                    if (page == 2'd3) begin tmr <= REFRESH_CYCLES; nxt <= S_LATCH; st <= S_TMR; end
                    else begin page <= page + 1'b1; bi <= 8'd0; ci <= 5'd0; si <= 3'd0; st <= S_PB; end
                end else begin
                    bi <= bi + 1'b1;
                    if (bi >= 8'd3) begin
                        if (si == 3'd5) begin si <= 3'd0; ci <= ci + 1'b1; end
                        else si <= si + 1'b1;
                    end
                    st <= S_PB;
                end
            end
            default: st <= S_BOOT;
        endcase
    end
endmodule