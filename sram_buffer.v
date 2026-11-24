
module sram_buffer #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 2,   // 2 bits -> 4 locations (00,01,10,11)
    parameter DEPTH       = 4
)(
    input  wire                     clk,
    input  wire                     we,        // write enable
    input  wire [ADDR_WIDTH-1:0]    waddr,
    input  wire [DATA_WIDTH-1:0]    wdata,
    input  wire [ADDR_WIDTH-1:0]    raddr,
    output reg  [DATA_WIDTH-1:0]    rdata
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
    end

    // synchronous write
    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
    end

    // synchronous read
    always @(posedge clk) begin
        rdata <= mem[raddr];
    end

endmodule
