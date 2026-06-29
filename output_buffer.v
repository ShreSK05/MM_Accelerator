// ============================================================
// FILE: output_buffer.v
// Output Buffer with Result Storage and Overflow Flags
// Fixed for Xilinx Vivado (Verilog-2001 compatible)
// ============================================================
`timescale 1ns/1ps

module output_buffer #(
    parameter DATA_WIDTH  = 16,
    parameter ACCUM_WIDTH = 32,
    parameter N           = 4,
    parameter ADDR_WIDTH  = 4
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    write_enable,
    input  wire [ADDR_WIDTH-1:0]   write_addr,
    input  wire [ACCUM_WIDTH-1:0]  write_data,
    input  wire                    read_enable,
    input  wire [ADDR_WIDTH-1:0]   read_addr,
    output reg  [ACCUM_WIDTH-1:0]  read_data,
    output wire                    overflow_flag
);

    reg [ACCUM_WIDTH-1:0] mem [0:N*N-1];
    reg overflow_detected;

    wire sat_max = (write_data == {1'b0, {(ACCUM_WIDTH-1){1'b1}}});
    wire sat_min = (write_data == {1'b1, {(ACCUM_WIDTH-1){1'b0}}});

    // Write port
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem[0]  <= {ACCUM_WIDTH{1'b0}};
            mem[1]  <= {ACCUM_WIDTH{1'b0}};
            mem[2]  <= {ACCUM_WIDTH{1'b0}};
            mem[3]  <= {ACCUM_WIDTH{1'b0}};
            mem[4]  <= {ACCUM_WIDTH{1'b0}};
            mem[5]  <= {ACCUM_WIDTH{1'b0}};
            mem[6]  <= {ACCUM_WIDTH{1'b0}};
            mem[7]  <= {ACCUM_WIDTH{1'b0}};
            mem[8]  <= {ACCUM_WIDTH{1'b0}};
            mem[9]  <= {ACCUM_WIDTH{1'b0}};
            mem[10] <= {ACCUM_WIDTH{1'b0}};
            mem[11] <= {ACCUM_WIDTH{1'b0}};
            mem[12] <= {ACCUM_WIDTH{1'b0}};
            mem[13] <= {ACCUM_WIDTH{1'b0}};
            mem[14] <= {ACCUM_WIDTH{1'b0}};
            mem[15] <= {ACCUM_WIDTH{1'b0}};
            overflow_detected <= 1'b0;
        end else begin
            if (write_enable) begin
                mem[write_addr]   <= write_data;
                overflow_detected <= (sat_max || sat_min) ? 1'b1 : overflow_detected;
            end
            if (read_enable)
                overflow_detected <= 1'b0;
        end
    end

    // Read port
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_data <= {ACCUM_WIDTH{1'b0}};
        else if (read_enable)
            read_data <= mem[read_addr];
    end

    assign overflow_flag = overflow_detected;

endmodule