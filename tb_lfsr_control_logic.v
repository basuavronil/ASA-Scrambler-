`timescale 1ns / 1ps

module tb_lfsr_enable_control;

    // Inputs
    reg Tx_phy_block_valid;
    reg Data_stream_en;
    reg Upstream_Downstream;

    // Outputs
    wire lfsr_en_up;
    wire lfsr_en_dn;

    // Instantiate the Unit Under Test (UUT)
    lfsr_enable_control uut (
        .Tx_phy_block_valid(Tx_phy_block_valid),
        .Data_stream_en(Data_stream_en),
        .Upstream_Downstream(Upstream_Downstream),
        .lfsr_en_up(lfsr_en_up),
        .lfsr_en_dn(lfsr_en_dn)
    );

    initial begin
        // Initialize Inputs
        Tx_phy_block_valid  = 0;
        Data_stream_en     = 0;
        Upstream_Downstream = 0;

        // Wait 20 ns for global reset/initialization
        #20;
        
        $display("Starting Testbench Verification...");
        $monitor("Time=%0t ns | Valid=%b | Data_en=%b | Up_Dn_Sel=%b || Enable_Up=%b | Enable_Dn=%b", 
                 $time, Tx_phy_block_valid, Data_stream_en, Upstream_Downstream, lfsr_en_up, lfsr_en_dn);

        // ==========================================
        // TEST CASE 1: All inputs low
        // ==========================================
        #10;
        if (lfsr_en_up !== 0 || lfsr_en_dn !== 0) 
            $display("ERROR: TC1 Failed. Outputs should be 0.");

        // ==========================================
        // TEST CASE 2: Select UPSTREAM (1), Enable active, Valid low
        // ==========================================
        Upstream_Downstream = 1;
        Data_stream_en     = 1;
        Tx_phy_block_valid  = 0;
        #10;
        if (lfsr_en_up !== 0 || lfsr_en_dn !== 0)
            $display("ERROR: TC2 Failed. Valid is low, outputs must be 0.");

        // ==========================================
        // TEST CASE 3: UPSTREAM active with valid high
        // ==========================================
        Tx_phy_block_valid  = 1;
        #10;
        if (lfsr_en_up !== 1 || lfsr_en_dn !== 0)
            $display("ERROR: TC3 Failed. Upstream enable should be 1, Downstream 0.");

        // ==========================================
        // TEST CASE 4: Keep UPSTREAM active, toggle data stream enable
        // ==========================================
        Data_stream_en     = 0;
        #10;
        if (lfsr_en_up !== 0 || lfsr_en_dn !== 0)
            $display("ERROR: TC4 Failed. Data stream enable dropped, outputs must be 0.");

        // ==========================================
        // TEST CASE 5: Select DOWNSTREAM (0), Enable active, Valid high
        // ==========================================
        Upstream_Downstream = 0;
        Data_stream_en     = 1;
        Tx_phy_block_valid  = 1;
        #10;
        if (lfsr_en_up !== 0 || lfsr_en_dn !== 1)
            $display("ERROR: TC5 Failed. Downstream enable should be 1, Upstream 0.");

        // ==========================================
        // TEST CASE 6: DOWNSTREAM active, toggle Valid low
        // ==========================================
        Tx_phy_block_valid  = 0;
        #10;
        if (lfsr_en_up !== 0 || lfsr_en_dn !== 0)
            $display("ERROR: TC6 Failed. Valid dropped, outputs must be 0.");

        // Finish simulation
        #20;
        $display("Verification Complete.");
        $finish;
    end
      
endmodule
