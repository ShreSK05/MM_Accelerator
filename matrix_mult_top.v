
`timescale 1ns/1ps

module matrix_mult_top #(
    parameter DATA_WIDTH  = 16,
    parameter ACCUM_WIDTH = 32,
    parameter N           = 4
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,
    input  wire [DATA_WIDTH*16-1:0]  a_in_flat,   // A[i][j] at [(i*4+j)*DW +: DW]
    input  wire [DATA_WIDTH*16-1:0]  b_in_flat,
    output wire [ACCUM_WIDTH*16-1:0] c_out_flat,
    output wire                      done,
    output wire                      overflow_flag
);

    wire       load_data;
    wire       compute_enable;
    wire       clear_accum;
    wire [3:0] cycle_count;

    fsm_controller #(.N(N)) u_fsm (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .load_data     (load_data),
        .compute_enable(compute_enable),
        .clear_accum   (clear_accum),
        .done          (done),
        .cycle_count   (cycle_count)
    );

    wire [ACCUM_WIDTH*16-1:0] systolic_result_flat;
    wire                      systolic_overflow;

    systolic_array_4x4 #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) u_systolic (
        .clk         (clk),
        .rst_n       (rst_n),
        .enable      (compute_enable),
        .load_data   (load_data),
        .clear_accum (clear_accum),
        .a_in_flat   (a_in_flat),
        .b_in_flat   (b_in_flat),
        .result_flat (systolic_result_flat),
        .overflow_any(systolic_overflow)
    );

    // Latch result when done pulses
    reg [ACCUM_WIDTH*16-1:0] c_out_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            c_out_reg <= {(ACCUM_WIDTH*16){1'b0}};
        else if (done)
            c_out_reg <= systolic_result_flat;
    end

    assign c_out_flat    = c_out_reg;
    assign overflow_flag = systolic_overflow;

endmodule
