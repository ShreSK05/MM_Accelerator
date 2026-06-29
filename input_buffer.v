// ============================================================
// FILE: input_buffer.v
// Input Buffer with Dual-Port RAM-like Interface
// Fixed for Xilinx Vivado (Verilog-2001 compatible)
// - Removed integer loop inside always reset block
// ============================================================
`timescale 1ns/1ps

module input_buffer #(
    parameter DATA_WIDTH = 16,
    parameter N          = 4,
    parameter ADDR_WIDTH = 4
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    write_enable,
    input  wire [ADDR_WIDTH-1:0]   write_addr,
    input  wire [DATA_WIDTH-1:0]   write_data,
    input  wire                    read_enable,
    input  wire [ADDR_WIDTH-1:0]   read_addr,
    output reg  [DATA_WIDTH-1:0]   read_data
);

    reg [DATA_WIDTH-1:0] mem [0:N*N-1];

    integer k;

    // Write port (synchronous reset via explicit word clears)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Vivado supports integer loop in initial/always only in simulation;
            // for synthesis use a generate-based reset or rely on BRAM init.
            // Here we explicitly clear all 16 locations (N=4 fixed):
            mem[0]  <= {DATA_WIDTH{1'b0}};
            mem[1]  <= {DATA_WIDTH{1'b0}};
            mem[2]  <= {DATA_WIDTH{1'b0}};
            mem[3]  <= {DATA_WIDTH{1'b0}};
            mem[4]  <= {DATA_WIDTH{1'b0}};
            mem[5]  <= {DATA_WIDTH{1'b0}};
            mem[6]  <= {DATA_WIDTH{1'b0}};
            mem[7]  <= {DATA_WIDTH{1'b0}};
            mem[8]  <= {DATA_WIDTH{1'b0}};
            mem[9]  <= {DATA_WIDTH{1'b0}};
            mem[10] <= {DATA_WIDTH{1'b0}};
            mem[11] <= {DATA_WIDTH{1'b0}};
            mem[12] <= {DATA_WIDTH{1'b0}};
            mem[13] <= {DATA_WIDTH{1'b0}};
            mem[14] <= {DATA_WIDTH{1'b0}};
            mem[15] <= {DATA_WIDTH{1'b0}};
        end else if (write_enable) begin
            mem[write_addr] <= write_data;
        end
    end

    // Read port (registered)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_data <= {DATA_WIDTH{1'b0}};
        else if (read_enable)
            read_data <= mem[read_addr];
    end

endmodule