`timescale 1ns/1ps
// Compile this package before any module that imports it.
package config_pkg;
    // Baseline hardware settings. Override module parameters for simulation.
    parameter int unsigned CLK_HZ             = 100_000_000;
    parameter int unsigned ACL2_SPI_HZ        = 1_000_000;
    parameter int unsigned OLED_SPI_HZ        = 1_000_000;
    parameter int unsigned I2C_HZ             = 100_000;
    parameter int unsigned UART_BAUD          = 115_200; // PS UART setting
    parameter int unsigned HYGRO_PERIOD_CYCLES = 110_000_000;
    parameter int unsigned HYGRO_STARTUP_CYCLES = 1_500_000;
    parameter int unsigned HYGRO_WAIT_CYCLES    = 2_000_000;
    parameter int unsigned OLED_FRAME_CYCLES   = 20_000_000;
    parameter int unsigned AGE_LIMIT_CYCLES    = 100_000;
    parameter int unsigned BUS_TIMEOUT_CYCLES  = 1_000_000;
    parameter int unsigned RECORD_FIFO_DEPTH   = 16;
    parameter int unsigned PS_FIFO_DEPTH       = 32;
    parameter int unsigned MAX_SENSOR_BYTES    = 8;

    localparam int unsigned NUM_SOURCES = 2;
    localparam int unsigned RECORD_WORDS = 8;
    localparam int unsigned RECORD_BITS = 256;
    localparam int unsigned PAYLOAD_BITS = 8 * MAX_SENSOR_BYTES;

    // Round up for clock-enable dividers: generated rate never exceeds target.
    localparam int unsigned ACL2_SPI_HALF_CYCLES =
        (CLK_HZ + 2*ACL2_SPI_HZ - 1) / (2*ACL2_SPI_HZ);
    localparam int unsigned OLED_SPI_HALF_CYCLES =
        (CLK_HZ + 2*OLED_SPI_HZ - 1) / (2*OLED_SPI_HZ);
    localparam int unsigned I2C_QUARTER_CYCLES =
        (CLK_HZ + 4*I2C_HZ - 1) / (4*I2C_HZ);

    typedef enum logic { SRC_ACL2 = 1'b0, SRC_HYGRO = 1'b1 } source_t;
    typedef enum logic { BUS_SPI  = 1'b0, BUS_I2C   = 1'b1 } bus_t;
    typedef enum logic { OP_WRITE = 1'b0, OP_READ   = 1'b1 } operation_t;
    typedef enum logic [3:0] {
        ERR_NONE = 4'd0, ERR_NACK = 4'd1, ERR_TIMEOUT = 4'd2,
        ERR_ID = 4'd3, ERR_CONFIG = 4'd4, ERR_PROTOCOL = 4'd5
    } error_t;

    // Sensor-service command, not the low-level SPI/OLED byte interface.
    // Byte zero is bits [7:0], byte one [15:8], etc. byte_count is 1..8.
    // ACL2: SPI opcode is derived from operation; reg_addr follows the opcode.
    // HYGRO: trigger is a pointer-only write (byte_count=0); raw result read
    // uses reg_addr_valid=0, avoiding an accidental conversion restart.
    typedef struct packed {
        source_t source;
        bus_t bus;
        operation_t operation;
        logic reg_addr_valid;
        logic [7:0] reg_addr;
        logic [3:0] byte_count;
        logic [PAYLOAD_BITS-1:0] write_data;
    } sensor_cmd_t;

    typedef struct packed {
        source_t source;
        error_t error;
        logic [3:0] byte_count;
        logic [PAYLOAD_BITS-1:0] read_data;
    } sensor_rsp_t;

    // Packed layout: word 0 is record[31:0], word 7 is record[255:224].
    // XYZ are sign-extended 16-bit values. T/RH are unsigned raw words.
    // Zero payload fields not belonging to this source.
    typedef struct packed {
        logic [31:0] arbitration_wait_cycles; // W7
        logic [15:0] humidity_raw;            // W6[31:16]
        logic [15:0] temperature_raw;         // W6[15:0]
        logic [15:0] reserved_w5;             // W5[31:16], zero
        logic signed [15:0] z;               // W5[15:0]
        logic signed [15:0] y;               // W4[31:16]
        logic signed [15:0] x;               // W4[15:0]
        logic [31:0] completion_timestamp;    // W3
        logic [31:0] event_timestamp;         // W2
        logic [31:0] sequence_number;         // W1
        logic [15:0] reserved_w0;             // W0[31:16], zero
        logic [7:0] status;                   // W0[15:8]
        logic [7:0] source_id;                // W0[7:0], 0 ACL2 / 1 HYGRO
    } sensor_record_t;

    localparam int unsigned STATUS_SYNTHETIC_BIT = 0;
    localparam int unsigned STATUS_COALESCED_BIT = 1;
    localparam logic [6:0] HYGRO_I2C_ADDRESS = 7'h40;
    localparam logic [7:0] ACL2_CMD_WRITE = 8'h0A;
    localparam logic [7:0] ACL2_CMD_READ  = 8'h0B;
    localparam logic [7:0] ACL2_CMD_FIFO  = 8'h0D;

    // Proposed project AXI offsets; not sensor register addresses.
    localparam logic [7:0] REG_CONTROL       = 8'h00;
    localparam logic [7:0] REG_PRIORITY      = 8'h04;
    localparam logic [7:0] REG_AGE_LIMIT     = 8'h08;
    localparam logic [7:0] REG_HYGRO_PERIOD  = 8'h0C;
    localparam logic [7:0] REG_STATUS        = 8'h10;
    localparam logic [7:0] REG_IRQ_ENABLE    = 8'h14;
    localparam logic [7:0] REG_IRQ_STATUS    = 8'h18;
    localparam logic [7:0] REG_ERROR_ACK     = 8'h1C;
    localparam logic [7:0] REG_FIFO_LEVEL    = 8'h20;
    localparam logic [7:0] REG_FIFO_POP      = 8'h24;
    localparam logic [7:0] REG_METRICS_CMD   = 8'h28;
    localparam logic [7:0] REG_RECORD_BASE   = 8'h40;
    localparam logic [7:0] REG_METRICS_BASE  = 8'h80;
endpackage
