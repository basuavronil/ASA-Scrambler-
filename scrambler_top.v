module scrambler_top (
    input  wire         clk,
    input  wire         rst,
    
    input  wire         Tx_phy_block_valid,   
    input  wire         Data_stream_en,       
    input  wire         Upstream_Downstream,  
    
    input  wire [2:0]   Spg,                  
    input  wire [1:0]   link_id,              
    input  wire [7:0]   data_in,              
    
    output wire [7:0]   data_out_final,       
    
    output wire [7:0]   upstream_s0_debug,    
    output wire [183:0] upstream_state_debug, 
    output wire [183:0] dnstream_state_debug  
);

    wire        lfsr_en_up;
    wire        lfsr_en_dn;
    wire [7:0]  data_out_upstream;
    wire [7:0]  data_out_downstream;

    // Sub-Module Instance 1: Enable Control
    lfsr_enable_control u_enable_control (
        .Tx_phy_block_valid  (Tx_phy_block_valid),
        .Data_stream_en      (Data_stream_en),
        .Upstream_Downstream (Upstream_Downstream),
        .lfsr_en_up          (lfsr_en_up),
        .lfsr_en_dn          (lfsr_en_dn)
    );

    // Sub-Module Instance 2: Upstream Core
    lfsr_upstream_8p u_upstream_core (
        .clk        (clk),
        .rst        (rst),
        .lfsr_en_up (lfsr_en_up),
        .link_id    (link_id),
        .data_in    (data_in),
        .data_out   (data_out_upstream),
        .s0         (upstream_s0_debug),
        .state_out  (upstream_state_debug)
    );

    // Sub-Module Instance 3: Downstream Core
    lfsr_downstream_8p u_downstream_core (
        .clk       (clk),
        .rst       (rst),
        .Dnstr_en  (lfsr_en_dn),
        .Spg       (Spg),
        .link_id   (link_id),
        .data_in   (data_in),
        .data_out  (data_out_downstream),
        .state_out (dnstream_state_debug)
    );

    // Dynamic Top Level Output Stream Selection Multiplexer
    assign data_out_final = (Upstream_Downstream == 1'b1) ? 
                            data_out_upstream : 
                            data_out_downstream;

endmodule
