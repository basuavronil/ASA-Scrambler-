module lfsr_downstream_8p (
    input  wire         clk,
    input  wire         rst,
    input  wire         Dnstr_en,        // Downstream master enable
    input  wire [2:0]   Spg,             // Stage selection control signal
    input  wire [1:0]   link_id,
    input  wire [7:0]   data_in,         // 8-bit parallel raw data in
    output wire [7:0]   data_out,        // 8-bit parallel scrambled data out
    output wire [183:0] state_out        // flat-packed states [LFSR7:LFSR0], 23 bits each
);

    // -------------------------------------------------------------------------
    // Base Seed Lookup
    // -------------------------------------------------------------------------
    reg [22:0] base_seed;
    always @(*) begin
        case (link_id)
            2'd0 : base_seed = 23'h000001;
            2'd1 : base_seed = 23'h000003;
            2'd2 : base_seed = 23'h000005;
            2'd3 : base_seed = 23'h000007;
            default: base_seed = 23'h000001;
        endcase
    end

    // -------------------------------------------------------------------------
    // Compute All 8 Seeds (1-bit circular right shifts)
    // -------------------------------------------------------------------------
    wire [22:0] seed [0:7];
    assign seed[0] = base_seed;
    assign seed[1] = {seed[0][0], seed[0][22:1]};
    assign seed[2] = {seed[1][0], seed[1][22:1]};
    assign seed[3] = {seed[2][0], seed[2][22:1]};
    assign seed[4] = {seed[3][0], seed[3][22:1]};
    assign seed[5] = {seed[4][0], seed[4][22:1]};
    assign seed[6] = {seed[5][0], seed[5][22:1]};
    assign seed[7] = {seed[6][0], seed[6][22:1]};

    // -------------------------------------------------------------------------
    // Gating Logic For The Last 4 LFSRs (Group B: LFSR 4 to 7)
    // -------------------------------------------------------------------------
    reg spg_gate;
    always @(*) begin
        case (Spg)
            3'd1, 3'd2:       spg_gate = 1'b1; // Group B active
            3'd3, 3'd4, 3'd5: spg_gate = 1'b0; // Group B frozen
            default:          spg_gate = 1'b1;
        endcase
    end

    wire en_group_a = Dnstr_en;
    wire en_group_b = Dnstr_en && spg_gate;

    // -------------------------------------------------------------------------
    // 8 Registers (23-bit) for Downstream Scrambler Polynomial: x^23 + x^5 + 1
    // -------------------------------------------------------------------------
    reg [22:0] lfsr [0:7];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) begin
                lfsr[i] <= (seed[i] == 23'd0) ? 23'd1 : seed[i];
            end
        end else begin
            // Group A: LFSRs 0 to 3 
            if (en_group_a) begin
                lfsr[0] <= {lfsr[0][21:0], lfsr[0][22] ^ lfsr[0][4]};
                lfsr[1] <= {lfsr[1][21:0], lfsr[1][22] ^ lfsr[1][4]};
                lfsr[2] <= {lfsr[2][21:0], lfsr[2][22] ^ lfsr[2][4]};
                lfsr[3] <= {lfsr[3][21:0], lfsr[3][22] ^ lfsr[3][4]};
            end
            
            // Group B: LFSRs 4 to 7
            if (en_group_b) begin
                lfsr[4] <= {lfsr[4][21:0], lfsr[4][22] ^ lfsr[4][4]};
                lfsr[5] <= {lfsr[5][21:0], lfsr[5][22] ^ lfsr[5][4]};
                lfsr[6] <= {lfsr[6][21:0], lfsr[6][22] ^ lfsr[6][4]};
                lfsr[7] <= {lfsr[7][21:0], lfsr[7][22] ^ lfsr[7][4]};
            end
        end
    end

    // -------------------------------------------------------------------------
    // Extract Raw Tap Bits from the LFSR Array
    // -------------------------------------------------------------------------
    wire [7:0] s0; // Current bit (bit 22) for LFSR 0 to 7
    wire [3:0] s1; // Next bit lookahead for LFSR 0 to 3

    generate
        genvar g;
        for (g = 0; g < 8; g = g + 1) begin: extract_taps
            assign s0[g] = lfsr[g][22];
            if (g < 4) begin: extract_s1
                assign s1[g] = lfsr[g][21] ^ lfsr[g][3];
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Intermediate XOR Processing Lanes (Purple Gates)
    // FIXED: Aligned indices sequentially to match structural MUX assumptions
    // -------------------------------------------------------------------------
wire [7:0] data_xor_s0;
   assign data_xor_s0[0] = data_in[7] ^ s0[0]; // 0 ^ 0 = 0 -> data_out[7]
assign data_xor_s0[1] = data_in[6] ^ s0[1]; // 1 ^ 0 = 1 -> data_out[6]
assign data_xor_s0[2] = data_in[5] ^ s0[2]; // 0 ^ 1 = 1 -> data_out[5]
assign data_xor_s0[3] = data_in[4] ^ s0[3]; // 1 ^ 0 = 1 -> data_out[4]
assign data_xor_s0[4] = data_in[3] ^ s0[4]; // 0 ^ 0 = 0 -> data_out[3]
assign data_xor_s0[5] = data_in[2] ^ s0[5]; // 1 ^ 0 = 1 -> data_out[2]
assign data_xor_s0[6] = data_in[1] ^ s0[6]; // 0 ^ 0 = 0 -> data_out[1]
assign data_xor_s0[7] = data_in[0] ^ s0[7]; // 1 ^ 0 = 1 -> data_out[0]

    // -------------------------------------------------------------------------
    // Interleaved Lanes (Orange Gates)
    // FIXED: Straight-mapped indexes to let interleaving execute over lower blocks
    // -------------------------------------------------------------------------
    wire [3:0] data_xor_interleaved;
  assign data_xor_interleaved[0] = data_in[1] ^ s1[3]; 
  assign data_xor_interleaved[1] = data_in[3] ^ s1[2]; 
  assign data_xor_interleaved[2] = data_in[5] ^ s1[1]; 
  assign data_xor_interleaved[3] = data_in[7] ^ s1[0]; 

    // -------------------------------------------------------------------------
    // MUX Selection Logic Network
    // -------------------------------------------------------------------------
    reg mux_sel;
    always @(*) begin
        case (Spg)
            3'd1, 3'd2:       mux_sel = 1'b0; 
            3'd3, 3'd4, 3'd5: mux_sel = 1'b1; 
            default:          mux_sel = 1'b0;
        endcase
    end

    // =========================================================================
    // UNTOUCHED MANAGER'S DESIGN BLOCK
    // =========================================================================
    // MUX 1
    assign data_out[7] = (mux_sel) ? data_xor_interleaved[0] : data_xor_s0[0]; 
    // MUX 2
    assign data_out[6] = (mux_sel) ? data_xor_s0[0]  : data_xor_s0[1];
    // MUX 3
    assign data_out[5] = (mux_sel) ? data_xor_interleaved[1] : data_xor_s0[2]; 
    // MUX4
    assign data_out[4] = (mux_sel) ?  data_xor_s0[1] : data_xor_s0[3]; 
    // MUX 5
    assign data_out[3] = (mux_sel) ? data_xor_interleaved[2] : data_xor_s0[4];
    // MUX 6
    assign data_out[2] = (mux_sel) ?  data_xor_s0[2] : data_xor_s0[5];
    // MUX 7
    assign data_out[1] = (mux_sel) ? data_xor_interleaved[3]  : data_xor_s0[6]; 
    // MUX 8
    assign data_out[0] = (mux_sel) ?  data_xor_s0[3] : data_xor_s0[7]; 

    // -------------------------------------------------------------------------
    // Debug Flat-Pack Interface Output
    // -------------------------------------------------------------------------
    generate
        genvar s;
        for (s = 0; s < 8; s = s + 1) begin: pack_states
            assign state_out[s*23 +: 23] = lfsr[s];
        end
    endgenerate

endmodule
