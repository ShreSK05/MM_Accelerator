
`timescale 1ns/1ps

module systolic_array_4x4 #(
    parameter DATA_WIDTH  = 16,
    parameter ACCUM_WIDTH = 32
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       enable,
    input  wire                       load_data,
    input  wire                       clear_accum,
    input  wire [DATA_WIDTH*16-1:0]   a_in_flat,  // A[i][j] at [(i*4+j)*DW +: DW]
    input  wire [DATA_WIDTH*16-1:0]   b_in_flat,  // B[i][j] at [(i*4+j)*DW +: DW]
    output wire [ACCUM_WIDTH*16-1:0]  result_flat, // C[i][j] at [(i*4+j)*AW +: AW]
    output wire                       overflow_any
);

    // Unpack A and B into 2D arrays
    wire [DATA_WIDTH-1:0] A [0:3][0:3];  // A[row][col]
    wire [DATA_WIDTH-1:0] B [0:3][0:3];  // B[row][col]

    genvar gi, gj;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : ua_i
            for (gj = 0; gj < 4; gj = gj + 1) begin : ua_j
                assign A[gi][gj] = a_in_flat[(gi*4 + gj)*DATA_WIDTH +: DATA_WIDTH];
                assign B[gi][gj] = b_in_flat[(gi*4 + gj)*DATA_WIDTH +: DATA_WIDTH];
            end
        end
    endgenerate

    // k-counter: selects which column of A / row of B to feed each cycle
    // Counts 0,1,2,3 during the N=4 compute cycles
    reg [1:0] k_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            k_cnt <= 2'd0;
        else if (clear_accum)
            k_cnt <= 2'd0;
        else if (enable)
            k_cnt <= k_cnt + 2'd1;
    end

    // For MAC[i][j]: feed A[i][k_cnt] and B[k_cnt][j]
    // Wire the correct element based on k_cnt using a mux
    wire [DATA_WIDTH-1:0] a_sel [0:3][0:3];
    wire [DATA_WIDTH-1:0] b_sel [0:3][0:3];

    // 4-to-1 mux selecting the k-th column of A for row i
    // and k-th row of B for column j
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : sel_i
            for (gj = 0; gj < 4; gj = gj + 1) begin : sel_j
                // a_sel[i][j] = A[i][k]   (column k of row i)
                assign a_sel[gi][gj] = (k_cnt == 2'd0) ? A[gi][0] :
                                       (k_cnt == 2'd1) ? A[gi][1] :
                                       (k_cnt == 2'd2) ? A[gi][2] :
                                                         A[gi][3];
                // b_sel[i][j] = B[k][j]   (row k of column j)
                assign b_sel[gi][gj] = (k_cnt == 2'd0) ? B[0][gj] :
                                       (k_cnt == 2'd1) ? B[1][gj] :
                                       (k_cnt == 2'd2) ? B[2][gj] :
                                                         B[3][gj];
            end
        end
    endgenerate

    // MAC results and overflow
    wire [ACCUM_WIDTH-1:0] mac_res [0:3][0:3];
    wire                   ov      [0:3][0:3];

    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : mac_r
            for (gj = 0; gj < 4; gj = gj + 1) begin : mac_c
                mac_unit #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .ACCUM_WIDTH(ACCUM_WIDTH)
                ) u_mac (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .enable     (enable),
                    .clear_accum(clear_accum),
                    .a          (a_sel[gi][gj]),
                    .b          (b_sel[gi][gj]),
                    .result     (mac_res[gi][gj]),
                    .overflow   (ov[gi][gj])
                );

                assign result_flat[(gi*4+gj)*ACCUM_WIDTH +: ACCUM_WIDTH] = mac_res[gi][gj];
            end
        end
    endgenerate

    assign overflow_any = ov[0][0] | ov[0][1] | ov[0][2] | ov[0][3] |
                          ov[1][0] | ov[1][1] | ov[1][2] | ov[1][3] |
                          ov[2][0] | ov[2][1] | ov[2][2] | ov[2][3] |
                          ov[3][0] | ov[3][1] | ov[3][2] | ov[3][3];

endmodule
