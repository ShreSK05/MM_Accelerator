
`timescale 1ns/1ps

module mac_unit #(
    parameter DATA_WIDTH  = 16,
    parameter ACCUM_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    enable,
    input  wire                    clear_accum,
    input  wire [DATA_WIDTH-1:0]   a,
    input  wire [DATA_WIDTH-1:0]   b,
    output reg  [ACCUM_WIDTH-1:0]  result,
    output wire                    overflow
);

    // Stage 1: register the product
    reg [ACCUM_WIDTH-1:0] product_r;
    wire [ACCUM_WIDTH-1:0] product_w = {{(ACCUM_WIDTH-2*DATA_WIDTH){1'b0}}, a * b};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            product_r <= {ACCUM_WIDTH{1'b0}};
        else if (clear_accum)
            product_r <= {ACCUM_WIDTH{1'b0}};
        else if (enable)
            product_r <= product_w;
    end

    // Stage 2: accumulate into result directly (no extra output register)
    wire [ACCUM_WIDTH:0] sum_ext = {1'b0, result} + {1'b0, product_r};
    wire of_int = sum_ext[ACCUM_WIDTH];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result <= {ACCUM_WIDTH{1'b0}};
        else if (clear_accum)
            result <= {ACCUM_WIDTH{1'b0}};
        else if (enable) begin
            if (of_int)
                result <= {ACCUM_WIDTH{1'b1}};   // saturate
            else
                result <= sum_ext[ACCUM_WIDTH-1:0];
        end
    end

    assign overflow = of_int & enable;

endmodule
