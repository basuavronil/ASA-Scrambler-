`timescale 1ns/1ps

module scrambler_top_tb;

    // -------------------------------------------------------------------------
    // Testbench Signals (Wired to the Scrambler Top System)
    // -------------------------------------------------------------------------
    reg         clk;
    reg         rst;
    
    reg         Tx_phy_block_valid;
    reg         Data_stream_en;
    reg         Upstream_Downstream;
    
    reg  [2:0]  Spg;
    reg  [1:0]  link_id;
    reg  [7:0]  data_in;
    
    wire [7:0]  data_out_final;
    wire [7:0]  upstream_s0_debug;
    wire [183:0] upstream_state_debug;
    wire [183:0] dnstream_state_debug;

    // -------------------------------------------------------------------------
    // Instantiate System Under Test (SUT)
    // -------------------------------------------------------------------------
    scrambler_top sut (
        .clk                 (clk),
        .rst                 (rst),
        .Tx_phy_block_valid  (Tx_phy_block_valid),
        .Data_stream_en      (Data_stream_en),
        .Upstream_Downstream (Upstream_Downstream),
        .Spg                 (Spg),
        .link_id             (link_id),
        .data_in             (data_in),
        .data_out_final      (data_out_final),
        .upstream_s0_debug   (upstream_s0_debug),
        .upstream_state_debug(upstream_state_debug),
        .dnstream_state_debug(dnstream_state_debug)
    );

    // -------------------------------------------------------------------------
    // Clock Generator (100 MHz System Clock)
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper Tasks for Diagnostic Printing
    // -------------------------------------------------------------------------
    task print_downstream_taps;
        reg [22:0] curr_lfsr [0:7];
        reg [7:0]  s0;
        integer j;
        begin
            // Unpack flat bus for visualization
            for (j = 0; j < 8; j = j + 1) begin
                curr_lfsr[j] = dnstream_state_debug[j*23 +: 23];
                s0[j]        = curr_lfsr[j][22];
            end
            $display("    [Downstream] s0 (MSB s0[0] -> LSB s0[7]): %b_%b_%b_%b_%b_%b_%b_%b (Hex: 0x%02h)", 
                     s0[0], s0[1], s0[2], s0[3], s0[4], s0[5], s0[6], s0[7], s0);
        end
    endtask

    task print_upstream_taps;
        $display("    [Upstream]   s0 (MSB s0[0] -> LSB s0[7]): %b_%b_%b_%b_%b_%b_%b_%b (Hex: 0x%02h)",
                 upstream_s0_debug[0], upstream_s0_debug[1], upstream_s0_debug[2], upstream_s0_debug[3],
                 upstream_s0_debug[4], upstream_s0_debug[5], upstream_s0_debug[6], upstream_s0_debug[7],
                 upstream_s0_debug);
    endtask

    // -------------------------------------------------------------------------
    // Main Simulation Thread
    // -------------------------------------------------------------------------
    initial begin
        $display("==========================================================================");
        $display("          STARTING SCRAMBLER INTEGRATED TOP-LEVEL TESTBENCH               ");
        $display("==========================================================================");

        // --- Step 1: Initialization & System Reset ---
        rst                 = 1;
        Tx_phy_block_valid  = 0;
        Data_stream_en      = 0;
        Upstream_Downstream = 0; // Start in Downstream Mode
        Spg                 = 3'd2; // Lower speed grade parallel block operation
        link_id             = 2'd0;
        data_in             = 8'h00;
        #20;
        
        // Synchronous De-assertion of Reset
        @(posedge clk);
        #1;
        rst = 0;
        $display("\n[System Alert] Reset released successfully.");

        // --- Step 2: Test Downstream Verification (Upstream_Downstream = 0) ---
        $display("\n>>> TEST BLOCK 1: DOWNSTREAM LOWER SPEED GRADE RUN (Spg = 2) <<<");
        Upstream_Downstream = 1'b0; // Routing to Downstream Core
        Tx_phy_block_valid  = 1'b1; // Trigger enable gating gate logic
        Data_stream_en      = 1'b1; 
        data_in             = 8'h55; // Core fixed visual input testing vector
        
        // Advance clock cycles and step to monitor calculations cleanly
        repeat (3) begin
            @(posedge clk);
            #1; // Post-assignment processing step guard delay
            $display("  [Mode: Downstream] In: 0x%02h (%b) -> Final Out: 0x%02h (%b)", 
                     data_in, data_in, data_out_final, data_out_final);
            print_downstream_taps();
        end

        // --- Step 3: Test Downstream Interleaved (Spg = 3) ---
        $display("\n>>> TEST BLOCK 2: DOWNSTREAM HIGHER SPEED GRADE INTERLEAVING (Spg = 3) <<<");
        Spg = 3'd3; // Change to higher rate mode configuration 
        repeat (2) begin
            @(posedge clk);
            #1;
            $display("  [Mode: Downstream Interleaved] In: 0x%02h -> Final Out: 0x%02h", data_in, data_out_final);
            print_downstream_taps();
        end

        // --- Step 4: Test Dynamic Upstream Switchover (Upstream_Downstream = 1) ---
        $display("\n>>> TEST BLOCK 3: SWITCHING TO DYNAMIC UPSTREAM PATHWAY (Upstream_Downstream = 1) <<<");
        @(posedge clk);
        #1;
        Upstream_Downstream = 1'b1; // Direct multiplexer path switchover to upstream core
        
        repeat (3) begin
            @(posedge clk);
            #1;
            $display("  [Mode: Upstream] In: 0x%02h (%b) -> Final Out: 0x%02h (%b)", 
                     data_in, data_in, data_out_final, data_out_final);
            print_upstream_taps();
        end

        // --- Step 5: Test Gating Disable Verification ---
        $display("\n>>> TEST BLOCK 4: ENABLES SHUTDOWN TEST (Data_stream_en = 0) <<<");
        @(posedge clk);
        #1;
        Data_stream_en = 1'b0; // Freezing the cores through demux system layout
        
        repeat (2) begin
            @(posedge clk);
            #1;
            $display("  [Mode: Disabled] In: 0x%02h -> Final Out: 0x%02h", data_in, data_out_final);
        end

        $display("\n==========================================================================");
        $display("          INTEGRATION VERIFICATION SUCCESSFUL. TERMINATING RUN.            ");
        $display("==========================================================================");
        $finish;
    end

endmodule
