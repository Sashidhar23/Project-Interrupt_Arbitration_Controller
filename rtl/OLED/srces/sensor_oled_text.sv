`timescale 1ns/1ps
// Latest-value cache. Only sample_valid commits a complete sensor record.
// Four rows of 21 ASCII bytes; row 0 column 0 occupies bits [671:664].
module sensor_oled_text #(parameter CALIBRATED_8G=0) (
    input wire clk, rst,
    input wire acl_valid, hygro_valid,
    input wire signed [15:0] x, y, z,
    input wire [15:0] temperature_raw, humidity_raw,
    input wire [1:0] initialized, fault,
    output reg [671:0] frame_text
);
    reg signed [15:0] cx, cy, cz;
    reg [15:0] ct, ch;
    reg acl_seen, hygro_seen;
    always @(posedge clk) begin
        if (rst) begin
            cx <= 0; cy <= 0; cz <= 0; ct <= 0; ch <= 0;
            acl_seen <= 0; hygro_seen <= 0;
        end else begin
            if (acl_valid) begin cx <= x; cy <= y; cz <= z; acl_seen <= 1; end
            if (hygro_valid) begin ct <= temperature_raw; ch <= humidity_raw; hygro_seen <= 1; end
        end
    end

    // Convert snapshots in 19 clocks, with five parallel shift/add-3 engines.
    // No division/modulo combinational chain is placed on the 100 MHz path.
    reg [1:0] state;
    reg [3:0] bit_count;
    reg [15:0] shx,shy,shz,sht,shh;
    reg [19:0] bx,by_,bz,bt,bh;
    reg nx,ny,nz,nt,have_acl,have_hygro;
    reg [1:0] init_l,fault_l;
    reg [26:0] temp_product;
    reg [25:0] rh_product;
    wire signed [12:0] temp10 = $signed({2'b00,temp_product[26:16]}) - 13'sd400;
    wire [12:0] temp_magnitude = temp10[12] ? -temp10 : temp10;

    function automatic [15:0] magnitude(input reg signed [15:0] value);
        magnitude = value[15] ? -value : value;
    endfunction
    function automatic [19:0] bcd_step(input [19:0] bcd, input next_bit);
        reg [19:0] corrected;
        integer i;
        begin
            corrected=bcd;
            for(i=0;i<5;i=i+1)
                if(bcd[i*4+:4]>=5) corrected[i*4+:4]=bcd[i*4+:4]+4'd3;
            bcd_step={corrected[18:0],next_bit};
        end
    endfunction
    function automatic [7:0] digit(input [3:0] nibble);
        digit = 8'd48 + {4'b0,nibble};
    endfunction
    function automatic [47:0] signed_axis(input negative, input [19:0] bcd);
        signed_axis = {negative ? 8'h2d : 8'h2b,
            digit(bcd[19:16]),digit(bcd[15:12]),digit(bcd[11:8]),digit(bcd[7:4]),digit(bcd[3:0])};
    endfunction
    function automatic [31:0] status(input reg init_ok, seen, failed);
        if (failed) status = "ERR ";
        else if (!init_ok || !seen) status = "WAIT";
        else status = "OK  ";
    endfunction
    reg [167:0] row0,row1,row2,row3;
    always @* begin
        row0={"X=",signed_axis(nx,bx)," Y=",signed_axis(ny,by_),"    "};
        row1={"Z=",signed_axis(nz,bz)," A:",status(init_l[0],have_acl,fault_l[0]),"      "};
        if(CALIBRATED_8G) row1={"ZC=",signed_axis(nz,bz)," A:",status(init_l[0],have_acl,fault_l[0]),"8G   "};
        row2={"T=",nt ? 8'h2d : 8'h2b,digit(bt[15:12]),digit(bt[11:8]),digit(bt[7:4]),
            ".",digit(bt[3:0]),"C H:",status(init_l[1],have_hygro,fault_l[1]),"     "};
        row3={"RH=",digit(bh[15:12]),digit(bh[11:8]),digit(bh[7:4]),".",digit(bh[3:0]),"%            "};
        if(!have_acl) begin
            row0="X=------ Y=------    ";
            row1={"Z=------ A:",status(init_l[0],have_acl,fault_l[0]),"      "};
        end
        if(CALIBRATED_8G && !have_acl) row1={"ZC=------ A:",status(init_l[0],have_acl,fault_l[0]),"8G   "};
        if(!have_hygro) begin
            row2={"T=------C H:",status(init_l[1],have_hygro,fault_l[1]),"     "};
            row3="RH=-----%            ";
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            state<=0; bit_count<=0;
            shx<=0; shy<=0; shz<=0; sht<=0; shh<=0;
            bx<=0; by_<=0; bz<=0; bt<=0; bh<=0;
            nx<=0; ny<=0; nz<=0; nt<=0;
            have_acl<=0; have_hygro<=0; init_l<=0; fault_l<=0;
            temp_product<=0; rh_product<=0;
            frame_text<={"X=------ Y=------    ","Z=------ A:WAIT      ",
                        "T=------C H:WAIT     ","RH=-----%            "};
        end else case(state)
            0: begin
                // Snapshot both latest records and status; cache remains writable.
                shx<=magnitude(cx); shy<=magnitude(cy); shz<=magnitude(cz);
                nx<=cx[15]; ny<=cy[15]; nz<=cz[15];
                have_acl<=acl_seen; have_hygro<=hygro_seen;
                init_l<=initialized; fault_l<=fault;
                // HDC1080 T=raw*165/65536-40; RH=raw*100/65536.
                temp_product<=ct*27'd1650; rh_product<=ch*26'd1000;
                bx<=0; by_<=0; bz<=0; bt<=0; bh<=0;
                state<=1;
            end
            1: begin
                // Scale to tenths; floor the scaled term before T offset removal.
                sht<={3'd0,temp_magnitude}; shh<={6'd0,rh_product[25:16]};
                nt<=temp10[12]; bit_count<=0; state<=2;
            end
            2: begin
                bx<=bcd_step(bx,shx[15]); by_<=bcd_step(by_,shy[15]); bz<=bcd_step(bz,shz[15]);
                bt<=bcd_step(bt,sht[15]); bh<=bcd_step(bh,shh[15]);
                shx<={shx[14:0],1'b0}; shy<={shy[14:0],1'b0}; shz<={shz[14:0],1'b0};
                sht<={sht[14:0],1'b0}; shh<={shh[14:0],1'b0};
                if(bit_count==15) state<=3;
                else bit_count<=bit_count+1'b1;
            end
            3: begin frame_text<={row0,row1,row2,row3}; state<=0; end
            default: state<=0;
        endcase
    end
endmodule
