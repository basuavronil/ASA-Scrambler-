module lfsr_enable_control (
    input  wire Tx_phy_block_valid,       // Valid signal from RS-FEC encoder
    input  wire Data_stream_en,          // Data stream enable input
    input  wire Upstream_Downstream,     // Select signal (High = Upstream, Low = Downstream)
    
    output wire lfsr_en_up,          // Top lfsr_enable output (Upstream)
    output wire lfsr_en_dn           // Bottom lfsr_enable output (Downstream)
);

    // Internal wires for the Demultiplexor outputs
    wire Upstr_en;
    wire Dnstr_en;

    // 1-to-2 Demultiplexer Logic
    // Assumes Upstream / Downstream select line is HIGH (1) for Upstream, LOW (0) for Downstream
    assign Upstr_en = (Upstream_Downstream == 1'b1) ? Data_stream_en : 1'b0;
    assign Dnstr_en = (Upstream_Downstream == 1'b0) ? Data_stream_en : 1'b0;

    // AND Gate Logic
    assign lfsr_en_up = Tx_phy_block_valid && Upstr_en;
    assign lfsr_en_dn = Tx_phy_block_valid && Dnstr_en;

endmodule
