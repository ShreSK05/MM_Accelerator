
`timescale 1ns/1ps

module tb();

    parameter DATA_WIDTH  = 16;
    parameter ACCUM_WIDTH = 32;
    parameter N           = 4;
    parameter CLK_HALF    = 5;   // 10 ns period = 100 MHz

    // ----------------------------------------------------------------
    // DUT ports
    // ----------------------------------------------------------------
    reg                          clk, rst_n, start;
    reg  [DATA_WIDTH*16-1:0]     a_in_flat;
    reg  [DATA_WIDTH*16-1:0]     b_in_flat;
    wire [ACCUM_WIDTH*16-1:0]    c_out_flat;
    wire                         done;
    wire                         overflow_flag;

    matrix_mult_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH),
        .N          (N)
    ) u_dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .a_in_flat    (a_in_flat),
        .b_in_flat    (b_in_flat),
        .c_out_flat   (c_out_flat),
        .done         (done),
        .overflow_flag(overflow_flag)
    );

    // Clock
    initial clk = 1'b0;
    always  #CLK_HALF clk = ~clk;

    // ----------------------------------------------------------------
    // Storage for test matrices and expected results
    // ----------------------------------------------------------------
    reg [DATA_WIDTH-1:0]  mat_a    [0:3][0:3];
    reg [DATA_WIDTH-1:0]  mat_b    [0:3][0:3];
    reg [ACCUM_WIDTH-1:0] expected [0:3][0:3];

    integer pass_count, fail_count;
    integer pi, pj, pr, pc, pk;

    // Pack mat_a / mat_b into flat buses
    task pack_inputs;
        integer r, c;
        begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    a_in_flat[(r*4+c)*DATA_WIDTH +: DATA_WIDTH] = mat_a[r][c];
                    b_in_flat[(r*4+c)*DATA_WIDTH +: DATA_WIDTH] = mat_b[r][c];
                end
        end
    endtask

    // Compute reference result in software
    task compute_expected;
        integer r, c, k;
        begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    expected[r][c] = {ACCUM_WIDTH{1'b0}};
                    for (k = 0; k < 4; k = k + 1)
                        expected[r][c] = expected[r][c] + mat_a[r][k] * mat_b[k][c];
                end
        end
    endtask

    // Read one element from c_out_flat
    function [ACCUM_WIDTH-1:0] get_c;
        input integer row, col;
        begin
            get_c = c_out_flat[(row*4+col)*ACCUM_WIDTH +: ACCUM_WIDTH];
        end
    endfunction

    // ----------------------------------------------------------------
    // Run one test case
    // ----------------------------------------------------------------
    task run_test;
        input integer test_id;
        integer r, c;
        integer mismatch;
        integer timeout;
        begin
            $display("\n===== TEST %0d =====", test_id);
            compute_expected;
            pack_inputs;

            // Reset
            rst_n = 1'b0; start = 1'b0;
            repeat(3) @(posedge clk);
            #1 rst_n = 1'b1;
            @(posedge clk);

            // Pulse start for ONE cycle
            #1 start = 1'b1;
            @(posedge clk);
            #1 start = 1'b0;

            // Wait for done (with timeout)
            timeout = 0;
            while (!done && timeout < 300) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 300) begin
                $display("TIMEOUT in test %0d - done never asserted", test_id);
                fail_count = fail_count + 1;
            end else begin
                // done is high; wait two more clock edges so output register settles
                @(posedge clk); @(posedge clk);

                mismatch = 0;
                for (r = 0; r < 4; r = r + 1)
                    for (c = 0; c < 4; c = c + 1)
                        if (get_c(r,c) !== expected[r][c]) begin
                            $display("  FAIL C[%0d][%0d]: got=%0d  expected=%0d",
                                     r, c, get_c(r,c), expected[r][c]);
                            mismatch = 1;
                        end

                if (!mismatch) begin
                    $display("  PASS - C[0][0]=%0d  C[1][1]=%0d  C[2][2]=%0d  C[3][3]=%0d",
                             get_c(0,0), get_c(1,1), get_c(2,2), get_c(3,3));
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                end
            end

            // Let done clear (FSM returns to IDLE since start=0)
            repeat(5) @(posedge clk);
        end
    endtask

    // ----------------------------------------------------------------
    // Main stimulus
    // ----------------------------------------------------------------
    integer i, j;

    initial begin
       

        pass_count = 0;
        fail_count = 0;
        a_in_flat  = {(DATA_WIDTH*16){1'b0}};
        b_in_flat  = {(DATA_WIDTH*16){1'b0}};

        // --------------------------------------------------
        // TEST 1: Identity × Identity → Identity
        // --------------------------------------------------
        for (i=0;i<4;i=i+1) for (j=0;j<4;j=j+1) begin
            mat_a[i][j] = (i==j) ? 16'd1 : 16'd0;
            mat_b[i][j] = (i==j) ? 16'd1 : 16'd0;
        end
        run_test(1);

        // --------------------------------------------------
        // TEST 2: All-ones → C[i][j] = 4
        // --------------------------------------------------
        for (i=0;i<4;i=i+1) for (j=0;j<4;j=j+1) begin
            mat_a[i][j] = 16'd1; mat_b[i][j] = 16'd1;
        end
        run_test(2);

        // --------------------------------------------------
        // TEST 3: Ascending × Transpose
        //   A[i][j] = i*4+j+1,  B[i][j] = j*4+i+1
        // --------------------------------------------------
        for (i=0;i<4;i=i+1) for (j=0;j<4;j=j+1) begin
            mat_a[i][j] = i*4+j+1;
            mat_b[i][j] = j*4+i+1;
        end
        run_test(3);

        // --------------------------------------------------
        // TEST 4: Zero × anything = zero
        // --------------------------------------------------
        for (i=0;i<4;i=i+1) for (j=0;j<4;j=j+1) begin
            mat_a[i][j] = 16'd0;
            mat_b[i][j] = i*4+j+1;
        end
        run_test(4);

        // --------------------------------------------------
        // TEST 5: A=2, B=3 → C[i][j] = 4*6 = 24
        // --------------------------------------------------
        for (i=0;i<4;i=i+1) for (j=0;j<4;j=j+1) begin
            mat_a[i][j] = 16'd2; mat_b[i][j] = 16'd3;
        end
        run_test(5);

        // --------------------------------------------------
        // Summary
        // --------------------------------------------------
        $display("\n============================");
        $display("  PASSED : %0d / %0d", pass_count, pass_count+fail_count);
        $display("  FAILED : %0d / %0d", fail_count, pass_count+fail_count);
        $display("============================\n");

        $finish;
    end

    initial begin
        #200000;
        $display("GLOBAL TIMEOUT at 200us");
        $finish;
    end

endmodule
