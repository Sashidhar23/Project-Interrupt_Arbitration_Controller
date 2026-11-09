`timescale 1ns/1ps
module tb_hygro_service;
    reg clk=0,rst=1,present=1,bad_id=0,hold_scl=0;
    always #5 clk=~clk;
    tri1 scl,sda;
    assign scl=hold_scl ? 1'b0 : 1'bz;
    wire req,done,initialized,fault,valid,converting;
    wire [1:0] grant;
    wire [2:0] error_code;
    wire [15:0] mid,did,temp,rh;
    wire [31:0] retries;
    integer samples=0;
    reg previous_done=0;
    arbiter arb(.clk(clk),.rst(rst),.req({req,1'b0}),.done({done,1'b0}),.grant(grant),
        .aging_en(1'b1),.age_thresh(16'd20),.base_prio0(4'd1),.base_prio1(4'd2),
        .eff_prio0(),.eff_prio1());
    hygro_service #(.I2C_HALF_PERIOD(5),.BUS_TIMEOUT_CYCLES(5000),
        .STARTUP_CYCLES(10),.CONVERSION_CYCLES(2500),.SAMPLE_GAP_CYCLES(500),
        .RETRY_CYCLES(500)) dut(.clk(clk),.rst(rst),.req(req),.grant(grant[1]),.done(done),
        .scl(scl),.sda(sda),.initialized(initialized),.fault(fault),.sample_valid(valid),
        .error_code(error_code),.manufacturer_id(mid),.device_id(did),
        .temperature_raw(temp),.humidity_raw(rh),.retry_count(retries),.converting(converting));
    hdc1080_model model(.rst(rst),.present(present),.bad_id(bad_id),.scl(scl),.sda(sda));
    always @(posedge clk) begin
        if(!rst) begin
            if(done && (!req || !grant[1])) $fatal(1,"unowned done");
            if(done && previous_done) $fatal(1,"done must pulse once");
            if(converting && (req || grant[1])) $fatal(1,"conversion holds grant");
            if(valid) begin
                samples++;
                if(temp!==16'h6680 || rh!==16'h8000) $fatal(1,"incorrect result byte order");
            end
        end
        previous_done=done;
    end
    task reset_dut;
        @(negedge clk); rst=1;
        repeat(4) @(negedge clk); rst=0;
    endtask
    task check_released;
        repeat(6) @(negedge clk);
        if(req || grant[1] || initialized || valid) $fatal(1,"fault did not release ownership");
        if(sda!==1'b1) $fatal(1,"SDA not released");
    endtask
    initial begin
        reset_dut();
        wait(initialized); @(negedge clk);
        if(mid!==16'h5449 || did!==16'h1050 || model.configuration!==16'h1000)
            $fatal(1,"identity/configuration");
        wait(converting); model.forced_nacks=1;
        wait(valid); @(negedge clk);
        if(retries!=1 || fault || model.triggers!=1) $fatal(1,"retry retriggered measurement");
        wait(samples==2); @(negedge clk);
        $display("PASS HYGRO identities, config, retry without retrigger, periodic samples");
        present=0; reset_dut(); wait(fault); check_released();
        if(error_code!=1) $fatal(1,"missing-device error");
        $display("PASS HYGRO absent device");
        present=1; bad_id=1; reset_dut(); wait(fault); check_released();
        if(error_code!=4) $fatal(1,"wrong-ID error");
        $display("PASS HYGRO wrong identity");
        bad_id=0; reset_dut(); wait(converting); model.forced_nacks=100;
        wait(fault); check_released();
        if(error_code!=1 || retries!=3 || model.triggers!=1) $fatal(1,"retry bound");
        $display("PASS HYGRO bounded not-ready retries");
        hold_scl=1; reset_dut(); wait(fault); check_released();
        if(error_code!=2) $fatal(1,"stuck bus timeout");
        hold_scl=0;
        $display("PASS HYGRO stuck SCL releases requester");
        reset_dut(); wait(scl===1'b0); reset_dut(); wait(valid);
        $display("PASS HYGRO reset during transaction and recovery");
        $finish;
    end
    initial begin #2000000; $fatal(1,"HYGRO watchdog timeout"); end
endmodule
