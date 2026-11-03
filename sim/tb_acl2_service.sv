`timescale 1ns/1ps
module tb_acl2_service;
    logic clk=0, rst=1, rival_req=0, rival_done=0, bad_id=0;
    always #5 clk=~clk;
    wire req,done,cs_n,sclk,mosi,miso,irq,id_ok,initialized,fault,valid;
    wire [7:0] device_id;
    wire signed [15:0] x,y,z;
    wire [1:0] grant;
    integer samples=0, completions=0;
    reg previous_done=0;
    arbiter arb(.clk(clk),.rst(rst),.req({rival_req,req}),
        .done({rival_done,done}),.grant(grant),.aging_en(1'b1),
        .age_thresh(16'd20),.base_prio0(4'd7),.base_prio1(4'd1),
        .eff_prio0(),.eff_prio1());
    adxl362_ctrl #(.CLK_DIV(5),.POWERUP_CYCLES(8)) dut(
        .clk(clk),.rst(rst),.req(req),.grant(grant[0]),.done(done),
        .int1_async(irq),.cs_n(cs_n),.sclk(sclk),.mosi(mosi),
        .miso(bad_id ? 1'b0 : miso),.id_ok(id_ok),.device_id(device_id),
        .initialized(initialized),.fault(fault),.sample_valid(valid),.x(x),.y(y),.z(z));
    adxl362_model sensor(.rst(rst),.cs_n(cs_n),.sclk(sclk),.mosi(mosi),
                         .miso(miso),.int1(irq));
    always @(posedge clk) begin
        if (!rst) begin
            if ((!cs_n || done) && (!req || !grant[0])) $fatal(1,"unowned transaction");
            if (done && previous_done) $fatal(1,"done held across cycles");
            if (grant==2'b11) $fatal(1,"double grant");
            if (valid) samples++;
            if (done) completions++;
        end
        previous_done=done;
    end
    initial begin
        repeat (4) @(negedge clk); rst=0;
        wait(initialized); @(negedge clk);
        if (!id_ok || device_id!==8'hAD || sensor.regs['h2c]!==8'h13 ||
            sensor.regs['h2a]!==1 || sensor.regs['h2d]!==2)
            $fatal(1,"initialization mismatch");
        // Other owner holds the slot when the real requester raises req.
        rival_req=1; wait(grant[1]); @(negedge clk);
        sensor.inject(-16'sd2048,16'sd2047,-16'sd1);
        wait(req); repeat(12) begin @(negedge clk);
            if (!cs_n || valid) $fatal(1,"service started before grant");
        end
        rival_done=1; @(negedge clk); rival_done=0; rival_req=0;
        wait(valid); @(negedge clk);
        if(x!==-16'sd2048 || y!==16'sd2047 || z!==-16'sd1) $fatal(1,"XYZ mismatch");
        repeat(140) @(negedge clk);
        if(samples!=1 || sensor.data_frames!=1 || req || !cs_n)
            $fatal(1,"duplicate or stuck first sample");
        sensor.inject(16'sd123,-16'sd456,16'sd0);
        wait(valid); @(negedge clk);
        if(x!==16'sd123 || y!==-16'sd456 || z!==0) $fatal(1,"second XYZ mismatch");
        repeat(140) @(negedge clk);
        if(samples!=2 || completions!=6) $fatal(1,"transaction count");
        rst=1; bad_id=1; repeat(4) @(negedge clk); rst=0;
        wait(fault); repeat(6) @(negedge clk);
        if(initialized || id_ok || req || grant[0] || !cs_n || samples!=2)
            $fatal(1,"ID failure did not release bus");
        $display("PASS: ID/config, contention, two signed bursts, delayed IRQ clear and bad ID");
        $finish;
    end
    initial begin #200000; $fatal(1,"simulation timeout"); end
endmodule
