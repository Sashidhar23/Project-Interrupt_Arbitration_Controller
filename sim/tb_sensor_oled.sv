`timescale 1ns/1ps
// Pin-level integration: real hub + sensor models + decoded OLED SPI bytes.
module tb_sensor_oled;
    reg clk=0, btn_rst=0;
    always #5 clk=~clk;
    wire acs,asck,amosi,amiso,irq;
    tri1 scl,sda;
    wire cs,sdin,sck,dc,res,vbat,vdd;
    wire [7:0] led;
    sensor_oled_top #(.ACL_SPI_DIV(5),.ACL_STARTUP_CYCLES(10),
        .I2C_HALF_PERIOD(5),.I2C_TIMEOUT_CYCLES(5000),.HYGRO_STARTUP_CYCLES(10),
        .HYGRO_CONVERSION_CYCLES(5000),.HYGRO_SAMPLE_GAP_CYCLES(1000),.HYGRO_RETRY_CYCLES(500),
        .RESET_HOLD_CYCLES(4),.OLED_CLK_DIV(2),.OLED_T_1MS(100),.OLED_T_100MS(200),
        .OLED_REFRESH_CYCLES(100),.AGE_THRESH(20)) dut (
        .clk(clk),.btn_rst(btn_rst),.acl2_int1(irq),.acl2_miso(amiso),
        .acl2_cs_n(acs),.acl2_sclk(asck),.acl2_mosi(amosi),.hygro_scl(scl),.hygro_sda(sda),
        .oled_cs_n(cs),.oled_sdin(sdin),.oled_sclk(sck),.oled_dc(dc),.oled_res_n(res),
        .oled_vbatc_n(vbat),.oled_vddc_n(vdd),.led(led));
    adxl362_model acl_model(.rst(dut.rst),.cs_n(acs),.sclk(asck),.mosi(amosi),.miso(amiso),.int1(irq));
    hdc1080_model hy_model(.rst(dut.rst),.present(1'b1),.bad_id(1'b0),.scl(scl),.sda(sda));
    integer av_count=0,hv_count=0;
    always @(posedge clk) if (!dut.rst) begin
        if (dut.grant==3 || |dut.fault) $fatal(1,"sensor grant/fault during OLED refresh");
        if (dut.acl_valid) av_count=av_count+1;
        if (dut.hygro_valid) hv_count=hv_count+1;
    end
    // Independent expected glyph table for the characters used in these frames.
    function automatic [39:0] glyph(input [7:0] c);
        case(c)
            "G":glyph=40'h3E41495132;
            "0":glyph=40'h3E5149453E; "1":glyph=40'h00427F4000;
            "2":glyph=40'h4261514946; "3":glyph=40'h2141454B31;
            "4":glyph=40'h1814127F10; "5":glyph=40'h2745454539;
            "6":glyph=40'h3C4A494930; "7":glyph=40'h0171090503;
            "8":glyph=40'h3649494936; "9":glyph=40'h064949291E;
            "X":glyph=40'h6314081463; "Y":glyph=40'h0708700807; "Z":glyph=40'h6151494543;
            "A":glyph=40'h7E1111117E; "C":glyph=40'h3E41414122;
            "H":glyph=40'h7F0808087F; "R":glyph=40'h7F09192946; "T":glyph=40'h01017F0101;
            "O":glyph=40'h3E4141413E; "K":glyph=40'h7F08142241;
            "=":glyph=40'h1414141414; "+":glyph=40'h08083E0808; "-":glyph=40'h0808080808;
            ":":glyph=40'h0036360000; ".":glyph=40'h0060600000; "%":glyph=40'h2313086462;
            default:glyph=0;
        endcase
    endfunction
    function automatic [7:0] expected_pixel(input integer frame_no,offset);
        reg [167:0] r0,r1,r2,r3,line_text;
        reg [39:0] g;
        integer col;
        begin
            r0=frame_no==0 ? "X=-00123 Y=+00456    " : "X=+00001 Y=-00002    ";
            r1=frame_no==0 ? "Z=+02047 A:OK        " : "Z=+00003 A:OK        ";
            r2="T=+026.0C H:OK       "; r3="RH=050.0%            ";
            case(offset/128) 0:line_text=r0; 1:line_text=r1; 2:line_text=r2; default:line_text=r3; endcase
            col=offset%128;
            if (col>=126 || col%6==5) expected_pixel=0;
            else begin
                g=glyph(line_text[167-(col/6)*8-:8]);
                expected_pixel=g[39-(col%6)*8-:8];
            end
        end
    endfunction
    integer bits=0,cleared=0,pixels=0,frames=0,commands=0;
    reg [7:0] shift=0;
    reg dc_byte=0,panel_on=0,started=0;
    time last_rise=0;
    always @(negedge cs) begin
        bits=0; shift=0; dc_byte=dc; started=1;
        if (sck!==0) $fatal(1,"OLED SPI must idle low");
    end
    always @(posedge sck) if (!cs) begin
        if (dc!==dc_byte) $fatal(1,"OLED D/C changed during byte");
        shift={shift[6:0],sdin}; bits=bits+1; last_rise=$time;
    end
    always @(posedge cs) if (started) begin
        if(bits!=8 || sck!==0 || dc!==dc_byte) $fatal(1,"invalid OLED byte framing");
        if (dc_byte) begin
            if (!panel_on) begin
                if (shift!==0 || vbat!==1) $fatal(1,"RAM not cleared before panel power");
                cleared=cleared+1;
            end else begin
                if (shift!==expected_pixel(frames,pixels))
                    $fatal(1,"frame %0d pixel %0d got %h expected %h",frames,pixels,shift,expected_pixel(frames,pixels));
                pixels=pixels+1;
                if (pixels==512) begin pixels=0; frames=frames+1; end
            end
        end else if (shift==8'hAF) begin
            if(cleared!=512 || vbat!==0 || vdd!==0 || res!==1) $fatal(1,"bad OLED power-up sequence");
            panel_on=1;
        end else if (panel_on) begin
            case(commands%3)
                0: if(shift!==(8'hB0 | ((commands/3)%4))) $fatal(1,"wrong OLED page");
                1: if(shift!==8'h00) $fatal(1,"wrong low column");
                2: if(shift!==8'h10) $fatal(1,"wrong high column");
            endcase
            commands=commands+1;
        end
    end
    initial begin
        wait(dut.rst===1); wait(dut.rst===0);
        wait(dut.initialized==3); wait(dut.converting); @(negedge clk);
        if(acl_model.regs['h2c]!==8'h13) $fatal(1,"2g not configured");
        acl_model.inject(-16'sd123,16'sd456,16'sd2047);
        wait(av_count==1 && hv_count>=1);
        // Update ACL2 during frame transmission: current frame must remain old,
        // next frame must contain the new complete XYZ record.
        wait(panel_on && pixels>=30); @(negedge clk);
        acl_model.inject(16'sd1,-16'sd2,16'sd3);
        wait(av_count==2); wait(frames==2); @(negedge clk);
        if(hv_count<2 || !led[0] || led[3:2]!=3 || commands!=24)
            $fatal(1,"acquisition/display did not progress together");
        $display("PASS OLED integration: sensor pin models, 512-byte clear, two exact SPI frames, coherent mid-frame update, concurrent HYGRO");
        $finish;
    end
    initial begin #5000000; $fatal(1,"OLED integration watchdog"); end
endmodule
