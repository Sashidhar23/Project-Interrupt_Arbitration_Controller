`timescale 1ns/1ps
module tb_sensor_oled_text;
    reg clk=0, rst=1, av=0, hv=0;
    always #5 clk=~clk;
    reg signed [15:0] x=0,y=0,z=0;
    reg [15:0] t=0,h=0;
    reg [1:0] initialized=0,fault=0;
    wire [671:0] text_frame;
    sensor_oled_text dut(.clk(clk),.rst(rst),.acl_valid(av),.hygro_valid(hv),
        .x(x),.y(y),.z(z),.temperature_raw(t),.humidity_raw(h),
        .initialized(initialized),.fault(fault),.frame_text(text_frame));
    task check_rows(input [167:0] a,b,c,d);
        begin
            // Allow a complete snapshot/conversion even if valid arrived mid-pass.
            repeat(40) @(negedge clk); #1;
            if (text_frame !== {a,b,c,d}) begin
                $display("Got: [%s] [%s] [%s] [%s]",text_frame[671:504],text_frame[503:336],text_frame[335:168],text_frame[167:0]);
                $fatal(1,"OLED text mismatch");
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst=0;
        check_rows("X=------ Y=------    ","Z=------ A:WAIT      ","T=------C H:WAIT     ","RH=-----%            ");
        @(negedge clk); initialized=3; av=1; hv=1;
        x=-123; y=456; z=2047; t=16'h6680; h=16'h8000;
        @(negedge clk); av=0; hv=0;
        check_rows("X=-00123 Y=+00456    ","Z=+02047 A:OK        ","T=+026.0C H:OK       ","RH=050.0%            ");
        // Bus values without a valid strobe must not replace the cached record.
        x=999; t=0; h=0;
        repeat(3) @(negedge clk);
        check_rows("X=-00123 Y=+00456    ","Z=+02047 A:OK        ","T=+026.0C H:OK       ","RH=050.0%            ");
        hv=1; @(negedge clk); hv=0;
        check_rows("X=-00123 Y=+00456    ","Z=+02047 A:OK        ","T=-040.0C H:OK       ","RH=000.0%            ");
        av=1; hv=1; x=-32768; y=32767; z=0; t=16'hffff; h=16'hffff;
        @(negedge clk); av=0; hv=0; fault=3;
        check_rows("X=-32768 Y=+32767    ","Z=+00000 A:ERR       ","T=+124.9C H:ERR      ","RH=099.9%            ");
        rst=1; @(negedge clk); rst=0; fault=0;
        check_rows("X=------ Y=------    ","Z=------ A:WAIT      ","T=------C H:WAIT     ","RH=-----%            ");
        $display("PASS OLED text: valid capture, independent updates, signs, limits, WAIT, ERR and reset");
        $finish;
    end
    initial begin #10000; $fatal(1,"text watchdog"); end
endmodule
