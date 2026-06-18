// =============================================================================
// Upstream Scrambler — 8 Parallel LFSRs
// Polynomial : g_Up(x) = x^23 + x^18 + 1
// 
// 8 LFSRs run in parallel each clock cycle, producing 8 scrambler bits
// simultaneously as s0[7:0].
//
// Seed rules (spec section 3.2.19):
//   LinkID=0 -> base_seed = 23'h000001
//   LinkID=1 -> base_seed = 23'h000003
//   LinkID=2 -> base_seed = 23'h000005
//   LinkID=3 -> base_seed = 23'h000007
//
// Seed chain across 8 LFSRs:
//   LFSR[0] seed = base_seed
//   LFSR[1] seed = circ_right_shift( LFSR[0] seed )
//   LFSR[2] seed = circ_right_shift( LFSR[1] seed )
//   ...
//   LFSR[7] seed = circ_right_shift( LFSR[6] seed )
//
// Ports:
//   clk       - clock
//   rst       - synchronous active-high reset (loads seeds)
//   en        - enable / clock gate
//   link_id   - 2-bit LinkID (selects base seed)
//   s0        - 8-bit parallel scrambler output (1 bit per LFSR per cycle)
//   state     - 8x23 = 184-bit flat-packed internal states (debug)
// =============================================================================

module lfsr_upstream_8p (
    input  wire       clk,
    input  wire       rst,
    input  wire       lfsr_en,
    input  wire [1:0] link_id,
    output wire [7:0] s0,           // 8-bit parallel output, 1 bit per LFSR
    output wire [183:0] state_out   // flat-packed states [LFSR7:LFSR0], 23 bits each
);

    // -------------------------------------------------------------------------
    // Base seed lookup
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
    // Compute all 8 seeds at elaboration time (combinational)
    // seed[0] = base_seed
    // seed[n] = {seed[n-1][0], seed[n-1][22:1]}  (1-bit circular right shift)
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
    // 8 LFSR registers
    // -------------------------------------------------------------------------
    reg [22:0] lfsr [0:7];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            // Load seeds, guard against all-zero
            lfsr[0] <= (seed[0] == 23'd0) ? 23'd1 : seed[0];
            lfsr[1] <= (seed[1] == 23'd0) ? 23'd1 : seed[1];
            lfsr[2] <= (seed[2] == 23'd0) ? 23'd1 : seed[2];
            lfsr[3] <= (seed[3] == 23'd0) ? 23'd1 : seed[3];
            lfsr[4] <= (seed[4] == 23'd0) ? 23'd1 : seed[4];
            lfsr[5] <= (seed[5] == 23'd0) ? 23'd1 : seed[5];
            lfsr[6] <= (seed[6] == 23'd0) ? 23'd1 : seed[6];
            lfsr[7] <= (seed[7] == 23'd0) ? 23'd1 : seed[7];
        end else if (lfsr_en) begin
            // Each LFSR shifts left independently, same polynomial
          lfsr[0] <= {lfsr[0][22] ^ lfsr[0][17], lfsr[0][21:1]};
          lfsr[1] <= {lfsr[1][22] ^ lfsr[1][17], lfsr[1][21:1]};
          lfsr[2] <= {lfsr[2][22] ^ lfsr[2][17], lfsr[2][21:1]};
          lfsr[3] <= {lfsr[3][22] ^ lfsr[3][17], lfsr[3][21:1]};
          lfsr[4] <= {lfsr[4][22] ^ lfsr[4][17], lfsr[4][21:1]};
          lfsr[5] <= {lfsr[5][22] ^ lfsr[5][17], lfsr[5][21:1]};
          lfsr[6] <= {lfsr[6][22] ^ lfsr[6][17], lfsr[6][21:1]};
          lfsr[7] <= {lfsr[7][22] ^ lfsr[7][17], lfsr[7][21:1]};
        end
    end

    // -------------------------------------------------------------------------
    // Output: s0[n] = MSB of LFSR[n]
    // -------------------------------------------------------------------------
  assign s0[0] = lfsr[0][0];
  assign s0[1] = lfsr[1][0];
  assign s0[2] = lfsr[2][0];
  assign s0[3] = lfsr[3][0];
  assign s0[4] = lfsr[4][0];
  assign s0[5] = lfsr[5][0];
  assign s0[6] = lfsr[6][0];
  assign s0[7] = lfsr[7][0];

    // Flat-pack states for debug: state_out[22:0]=LFSR0, [45:23]=LFSR1, ...
    assign state_out[22:0]    = lfsr[0];
    assign state_out[45:23]   = lfsr[1];
    assign state_out[68:46]   = lfsr[2];
    assign state_out[91:69]   = lfsr[3];
    assign state_out[114:92]  = lfsr[4];
    assign state_out[137:115] = lfsr[5];
    assign state_out[160:138] = lfsr[6];
    assign state_out[183:161] = lfsr[7];

endmodule
