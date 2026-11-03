`timescale 1ns/1ps
// Focused SPI mode-0 behavioral model. Independent of controller states.
module adxl362_model(input logic rst, cs_n, sclk, mosi,
                     output logic miso, output logic int1);
    logic [7:0] regs [0:63];
    logic [7:0] opcode, addr, incoming;
    integer bytes, bits, frames, data_frames;
    initial begin
        foreach (regs[i]) regs[i]=0;
        regs[0]=8'hAD; int1=0; frames=0; data_frames=0; miso=0;
        bytes=0; bits=0;
    end
    task automatic inject(input logic signed [15:0] ax, ay, az);
        if (regs['h2a] != 1 || regs['h2d] != 2) $fatal(1,"sensor not configured");
        {regs['h0f],regs['h0e]} = ax;
        {regs['h11],regs['h10]} = ay;
        {regs['h13],regs['h12]} = az;
        int1=1;
    endtask
    always @(negedge cs_n) begin
        bytes=0; bits=0; incoming=0; opcode=0; addr=0; miso=0;
    end
    always @(posedge sclk) if (!cs_n) begin
        incoming={incoming[6:0],mosi};
        if (bits==7) begin
            if (bytes==0) opcode=incoming;
            else if (bytes==1) addr=incoming;
            else if (opcode==8'h0A) regs[addr+bytes-2]=incoming;
            bytes=bytes+1; bits=0;
        end else bits=bits+1;
    end
    always @(negedge sclk) if (!cs_n) begin
        if (bytes>=2 && opcode==8'h0B) miso=regs[addr+bytes-2][7-bits];
        else miso=0;
    end
    always @(posedge cs_n) if (!rst && bytes!=0) begin
        if (bits!=0) $fatal(1,"CS released inside a byte");
        if (opcode==8'h0B && addr==8'h0E) begin
            if (bytes!=8) $fatal(1,"XYZ burst must have eight SPI bytes");
            data_frames++;
            // Delay clear beyond transaction completion to stress IRQ re-arm.
            fork begin #800; int1=0; end join_none
        end else if (bytes!=3) $fatal(1,"ID/config frame length %0d",bytes);
        frames++;
    end
endmodule
