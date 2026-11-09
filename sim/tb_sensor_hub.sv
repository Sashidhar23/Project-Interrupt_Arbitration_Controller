`timescale 1ns/1ps
module tb_sensor_hub;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    wire cs_n,sclk,mosi,miso,irq;
    tri1 scl,sda;
    wire [1:0] req,grant,done,initialized,fault;
    wire acl_valid,hygro_valid,converting;
    wire signed [15:0] x,y,z;
    wire [15:0] temp,rh;
    wire [2:0] error_code;
    wire [31:0] retries;
    integer acl_samples=0,hy_samples=0;
    reg [1:0] previous_grant=0,previous_done=0;
    sensor_hub #(.ACL_SPI_DIV(5),.ACL_STARTUP_CYCLES(10),.I2C_HALF_PERIOD(5),
        .I2C_TIMEOUT_CYCLES(5000),.HYGRO_STARTUP_CYCLES(10),
        .HYGRO_CONVERSION_CYCLES(5000),.HYGRO_SAMPLE_GAP_CYCLES(1000),
        .HYGRO_RETRY_CYCLES(500)) dut(.clk(clk),.rst(rst),.aging_en(1'b1),
        .age_thresh(16'd20),.acl_priority(4'd7),.hygro_priority(4'd1),
        .acl_int1(irq),.acl_miso(miso),.acl_cs_n(cs_n),.acl_sclk(sclk),.acl_mosi(mosi),
        .hygro_scl(scl),.hygro_sda(sda),.req(req),.grant(grant),.done(done),
        .initialized(initialized),.fault(fault),.acl_valid(acl_valid),.hygro_valid(hygro_valid),
        .hygro_converting(converting),.x(x),.y(y),.z(z),.temperature_raw(temp),
        .humidity_raw(rh),.hygro_error(error_code),.hygro_retries(retries));
    adxl362_model acl_model(.rst(rst),.cs_n(cs_n),.sclk(sclk),.mosi(mosi),.miso(miso),.int1(irq));
    hdc1080_model hy_model(.rst(rst),.present(1'b1),.bad_id(1'b0),.scl(scl),.sda(sda));
    always @(posedge clk) begin
        if(!rst) begin
            if(grant==3 || |fault) $fatal(1,"grant overlap or sensor fault");
            if((done & ~grant)!=0) $fatal(1,"completion without ownership");
            if((previous_grant & ~previous_done & ~grant)!=0) $fatal(1,"preempted transaction");
            if(converting && (req[1] || grant[1])) $fatal(1,"HYGRO blocked ACL2 during conversion");
            if(acl_valid) acl_samples++;
            if(hygro_valid) hy_samples++;
        end
        previous_grant=grant; previous_done=done;
    end
    initial begin
        $dumpfile("build/sensor_hub.vcd"); $dumpvars(0,tb_sensor_hub);
        repeat(5) @(negedge clk); rst=0;
        wait(initialized==3); wait(converting); @(negedge clk);
        acl_model.inject(-16'sd123,16'sd456,16'sd2047);
        wait(acl_valid); @(negedge clk);
        if(!converting || hy_samples!=0 || x!==-16'sd123 || y!==16'sd456 || z!==16'sd2047)
            $fatal(1,"ACL2 did not complete within conversion window");
        wait(hygro_valid); @(negedge clk);
        if(temp!==16'h6680 || rh!==16'h8000 || acl_samples!=1) $fatal(1,"combined records");
        wait(!converting); wait(converting); @(negedge clk);
        acl_model.inject(16'sd1,-16'sd2,16'sd3);
        wait(acl_valid); @(negedge clk);
        if(!converting) $fatal(1,"second ACL2 missed conversion window");
        wait(hy_samples==2); @(negedge clk);
        if(acl_samples!=2 || retries!=0) $fatal(1,"combined sample accounting");
        $display("PASS sensor hub: two ACL2 reads completed during HYGRO conversion, two HYGRO samples");
        $finish;
    end
    initial begin #1000000; $fatal(1,"sensor hub watchdog timeout"); end
endmodule
