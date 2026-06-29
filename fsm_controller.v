// ============================================================
// FILE: fsm_controller.v  - final correct version
// Compute window = N cycles (one per k-column)
// Plus 1 pipeline drain cycle (product_r stage)
// Total COMPUTE state cycles = N+1 = 5 for N=4
// ============================================================
`timescale 1ns/1ps

module fsm_controller #(
    parameter N = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    output wire       load_data,
    output wire       compute_enable,
    output wire       clear_accum,
    output wire       done,
    output wire [3:0] cycle_count
);

    localparam IDLE    = 3'b000;
    localparam LOAD    = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE_ST = 3'b011;

    // We need exactly N enable pulses to the MAC.
    // The MAC has one pipeline register (product_r), so after N enables
    // we need 1 more enable to flush the last product into the accumulator.
    // Total COMPUTE cycles = N+1 = 5 for N=4.
    localparam COMPUTE_CYCLES = N; // count 0..N, done at N (N+1 pulses)

    reg [2:0] state, next_state;
    reg [3:0] cycle_cnt;
    reg [4:0] load_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            cycle_cnt    <= 4'd0;
            load_counter <= 5'd0;
        end else begin
            state <= next_state;

            if (state == COMPUTE)
                cycle_cnt <= (cycle_cnt < COMPUTE_CYCLES) ? cycle_cnt + 4'd1 : 4'd0;
            else
                cycle_cnt <= 4'd0;

            if (state == LOAD)
                load_counter <= (load_counter < N*N-1) ? load_counter + 5'd1 : 5'd0;
            else
                load_counter <= 5'd0;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:    if (start)                          next_state = LOAD;
            LOAD:    if (load_counter == N*N-1)          next_state = COMPUTE;
            COMPUTE: if (cycle_cnt == COMPUTE_CYCLES)    next_state = DONE_ST;
            DONE_ST: if (!start)                         next_state = IDLE;
            default:                                     next_state = IDLE;
        endcase
    end

    assign load_data      = (state == LOAD);
    assign compute_enable = (state == COMPUTE);
    assign clear_accum    = (state == IDLE) || (state == LOAD);
    assign done           = (state == DONE_ST);
    assign cycle_count    = cycle_cnt;

endmodule