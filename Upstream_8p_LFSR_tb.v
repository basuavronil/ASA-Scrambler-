// =============================================================================
// Testbench : lfsr_upstream_8p
// Tests:
//   1. All 4 LinkIDs — correct seeds loaded across all 8 LFSRs
//   2. s0[7:0] all bits toggle (non-zero output after warmup)
//   3. Enable gate — all states freeze when en=0
//   4. Re-reset with different LinkID changes seeds correctly
// =============================================================================
`timescale 1ns/1ps

module lfsr_upstream_tb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg        clk;
    reg        rst;
    reg        lfsr_en_up;
    reg  [1:0] link_id;
  
    wire [7:0]   s0;
    wire [183:0] state_out;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    lfsr_upstream_8p dut (
        .clk       (clk),
        .rst       (rst),
        .lfsr_en_up  (lfsr_en_up),
        .link_id   (link_id),
        .s0        (s0),
        .state_out (state_out)
    );

    // -------------------------------------------------------------------------
    // Helper: extract 23-bit state of LFSR[idx]
    // -------------------------------------------------------------------------
    function [22:0] get_state;
        input [183:0] bus;
        input integer idx;
        begin
            get_state = bus[idx*23 +: 23];
        end
    endfunction

    // -------------------------------------------------------------------------
    // Expected seed for LFSR[n] given a base seed (purely combinational check)
    // -------------------------------------------------------------------------
    function [22:0] exp_seed;
        input [22:0] base;
        input integer n;
        integer k;
        reg [22:0] s;
        begin
            s = base;
            for (k = 0; k < n; k = k + 1)
                s = {s[0], s[22:1]};   // circular right shift
            exp_seed = s;
        end
    endfunction

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Task: reset with given link_id
    // -------------------------------------------------------------------------
    task do_reset;
        input [1:0] lid;
        begin
            link_id = lid;
            rst     = 1;
            lfsr_en_up = 0;
            repeat(3) @(posedge clk); #1;
            rst = 0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: verify all 8 LFSR seeds after reset
    // -------------------------------------------------------------------------
    task verify_seeds;
        input [1:0]  lid;
        reg [22:0] base;
        reg [22:0] expected;
        reg [22:0] actual;
        integer j;
        begin
            case (lid)
                2'd0: base = 23'h000001;
                2'd1: base = 23'h000003;
                2'd2: base = 23'h000005;
                2'd3: base = 23'h000007;
                default: base = 23'h000001;
            endcase
            $display("  [SEED CHECK] LinkID=%0d  base=0x%06h", lid, base);
            for (j = 0; j < 8; j = j + 1) begin
                expected = exp_seed(base, j);
                actual   = get_state(state_out, j);
                $display("    LFSR[%0d] state=0x%06h  expected=0x%06h  %s",
                         j, actual, expected,
                         (actual === expected) ? "PASS" : "FAIL");
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: run N cycles, print s0 and all 8 states
    // -------------------------------------------------------------------------
    task run_cycles;
        input integer n;
        integer k;
        begin
            lfsr_en_up = 1;
            for (k = 0; k < n; k = k + 1) begin
                @(posedge clk); #1;
                $display("  cyc=%3d | s0=0x%02h (%08b) | st0=0x%06h st1=0x%06h st2=0x%06h st3=0x%06h",
                         k, s0, s0,
                         get_state(state_out,0), get_state(state_out,1),
                         get_state(state_out,2), get_state(state_out,3));
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------------
    reg [183:0] frozen_state;
    integer i;

    initial begin
        $dumpfile("lfsr_upstream.vcd");
        $dumpvars(0, lfsr_upstream_tb);

        rst     = 1;
        lfsr_en_up      = 0;
        link_id = 0;

        // ============================================================
        // TEST 1 : LinkID=0 — seed check + 30 cycles (warmup needed)
        // ============================================================
        $display("\n============================================================");
        $display(" TEST 1 : LinkID=0  (base seed = 0x000001)");
        $display("============================================================");
        do_reset(2'd0);
        verify_seeds(2'd0);
        $display("  -- 30 cycles (s0 starts toggling after ~22 cycles) --");
        run_cycles(30);

        // ============================================================
        // TEST 2 : LinkID=1
        // ============================================================
        $display("\n============================================================");
        $display(" TEST 2 : LinkID=1  (base seed = 0x000003)");
        $display("============================================================");
        do_reset(2'd1);
        verify_seeds(2'd1);
        run_cycles(30);

        // ============================================================
        // TEST 3 : LinkID=2
        // ============================================================
        $display("\n============================================================");
        $display(" TEST 3 : LinkID=2  (base seed = 0x000005)");
        $display("============================================================");
        do_reset(2'd2);
        verify_seeds(2'd2);
        run_cycles(30);

        // ============================================================
        // TEST 4 : LinkID=3
        // ============================================================
        $display("\n============================================================");
        $display(" TEST 4 : LinkID=3  (base seed = 0x000007)");
        $display("============================================================");
        do_reset(2'd3);
        verify_seeds(2'd3);
        run_cycles(30);

        // ============================================================
        // TEST 5 : Enable gate
        // ============================================================
        $display("\n============================================================");
        $display(" TEST 5 : Enable gate  (LinkID=0, run 25 cycles first)");
        $display("============================================================");
        do_reset(2'd0);
        lfsr_en_up = 1;
        repeat(25) @(posedge clk); #1;
        frozen_state = state_out;
        $display("  State frozen: st0=0x%06h  s0=0x%02h", get_state(state_out,0), s0);
        lfsr_en_up = 0;
        repeat(4) @(posedge clk); #1;
        if (state_out === frozen_state)
            $display("  Enable gate PASS — all states held");
        else
            $display("  Enable gate FAIL");
        $display("  -- Resume --");
        run_cycles(5);

        $display("\n============================================================");
        $display(" ALL TESTS COMPLETE");
        $display("============================================================\n");
        $finish;
    end

endmodule
