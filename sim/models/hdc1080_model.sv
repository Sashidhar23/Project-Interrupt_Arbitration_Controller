`timescale 1ns/1ps
// Pin-level test fixture. Open-drain drive, ID/config registers, conversion delay.
module hdc1080_model #(parameter integer CONVERSION_NS=20000)(
    input wire rst, present, bad_id,
    inout wire scl, sda
);
    localparam RX=0, SLAVE_ACK=1, TX=2, MASTER_ACK=3, IGNORE=4;
    integer state, next_state, bit_count, write_count, read_index;
    integer starts, stops, triggers, reads, forced_nacks;
    reg drive_low, expect_address, read_direction, ack_value, ack_active, ack_sampled;
    reg master_acked, valid_write;
    reg [7:0] shift, pointer;
    reg [15:0] configuration;
    time ready_at;
    assign sda=drive_low ? 1'b0 : 1'bz;
    function automatic [7:0] read_byte(input integer index);
        case(pointer)
            8'hFE: read_byte=bad_id ? 8'h00 : (index==0 ? 8'h54 : 8'h49);
            8'hFF: read_byte=index==0 ? 8'h10 : 8'h50;
            8'h02: read_byte=index==0 ? configuration[15:8] : configuration[7:0];
            8'h00: case(index)
                0: read_byte=8'h66; 1: read_byte=8'h80; // T raw 0x6680
                2: read_byte=8'h80; 3: read_byte=8'h00; // RH raw 0x8000
                default: read_byte=0;
            endcase
            default: read_byte=0;
        endcase
    endfunction
    task reset_model;
        state=IGNORE; drive_low=0; starts=0; stops=0; triggers=0; reads=0;
        forced_nacks=0; pointer=0; configuration=16'h1000; ready_at=0;
        bit_count=0; write_count=0; read_index=0; shift=0;
        expect_address=1; read_direction=0; ack_value=0; ack_active=0;
        ack_sampled=0; master_acked=0; valid_write=0; next_state=RX;
    endtask
    initial reset_model();
    always @(posedge rst) reset_model();
    always @(negedge sda) if(scl===1'b1 && !rst) begin
        starts++; state=RX; expect_address=1; bit_count=0; shift=0;
        write_count=0; read_index=0; valid_write=0; drive_low=0;
    end
    always @(posedge sda) if(scl===1'b1 && !rst) begin
        stops++;
        if(valid_write && pointer==0 && write_count==1) begin
            triggers++; ready_at=$time+CONVERSION_NS;
        end
        state=IGNORE; drive_low=0;
    end
    always @(posedge scl) if(!rst) begin
        case(state)
            RX: begin
                shift={shift[6:0],sda};
                if(bit_count==7) begin
                    bit_count=0; ack_value=1; next_state=RX;
                    if(expect_address) begin
                        expect_address=0; read_direction=shift[0];
                        ack_value=present && shift[7:1]==7'h40;
                        if(read_direction && pointer==0) begin
                            if($time<ready_at) ack_value=0;
                            if(forced_nacks>0) begin ack_value=0; forced_nacks--; end
                        end
                        if(ack_value && read_direction) begin next_state=TX; reads++; end
                        valid_write=ack_value && !read_direction;
                    end else begin
                        if(write_count==0) pointer=shift;
                        else if(pointer==2 && write_count==1) configuration[15:8]=shift;
                        else if(pointer==2 && write_count==2) configuration[7:0]=shift;
                        write_count++;
                    end
                    if(!ack_value) next_state=IGNORE;
                    ack_active=0; ack_sampled=0; state=SLAVE_ACK;
                end else bit_count++;
            end
            SLAVE_ACK: if(ack_active) ack_sampled=1;
            TX: begin
                if(bit_count==7) begin state=MASTER_ACK; ack_active=0; ack_sampled=0; end
                else bit_count++;
            end
            MASTER_ACK: if(ack_active) begin
                master_acked=(sda===1'b0); ack_sampled=1;
                if(pointer==0) begin
                    if(read_index<3 && !master_acked) $fatal(1,"early master NACK");
                    if(read_index==3 && master_acked) $fatal(1,"final byte must be NACKed");
                end
            end
            default: begin end
        endcase
    end
    reg [7:0] outgoing;
    always @(negedge scl) if(!rst) begin
        case(state)
            SLAVE_ACK: begin
                if(!ack_active) begin drive_low=ack_value; ack_active=1; end
                else if(ack_sampled) begin
                    state=next_state; bit_count=0;
                    outgoing=read_byte(read_index);
                    drive_low=(next_state==TX) && !outgoing[7];
                end
            end
            TX: begin outgoing=read_byte(read_index); drive_low=!outgoing[7-bit_count]; end
            MASTER_ACK: begin
                if(!ack_active) begin drive_low=0; ack_active=1; end
                else if(ack_sampled) begin
                    if(master_acked) begin
                        read_index++; bit_count=0; state=TX;
                        outgoing=read_byte(read_index); drive_low=!outgoing[7];
                    end else begin drive_low=0; state=IGNORE; end
                end
            end
            default: drive_low=0;
        endcase
    end
endmodule
