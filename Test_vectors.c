#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

// Structure mimicking the internal register configurations and wires
typedef struct {
    uint32_t lfsr[8];     // 23-bit internal state arrays (using lower 23 bits)
    uint8_t data_out;     // 8-bit output 
} lfsr_downstream_t;

// Helper function to extract bit values safely
static inline uint8_t get_bit(uint32_t val, uint8_t bit_pos) {
    return (val >> bit_pos) & 1;
}

// Function executing initialization and computing circular shifts
void lfsr_reset(lfsr_downstream_t *dut, uint8_t link_id) {
    uint32_t base_seed = 0;
    
    // Base Seed Lookup
    switch (link_id) {
        case 0:  base_seed = 0x000001; break;
        case 1:  base_seed = 0x000003; break;
        case 2:  base_seed = 0x000005; break;
        case 3:  base_seed = 0x000007; break;
        default: base_seed = 0x000001; break;
    }

    // Compute all 8 seeds (1-bit circular right shifts over a 23-bit space)
    uint32_t seed[8];
    seed[0] = base_seed;
    for (int i = 1; i < 8; i++) {
        uint8_t bit_0 = get_bit(seed[i-1], 0);
        seed[i] = (bit_0 << 22) | (seed[i-1] >> 1);
    }

    // Load states while guarding against dead zeroes
    for (int i = 0; i < 8; i++) {
        dut->lfsr[i] = (seed[i] == 0) ? 1 : (seed[i] & 0x7FFFFF);
    }
    dut->data_out = 0;
}

// Main logic routine running sequential state steps and combinations
void lfsr_step(lfsr_downstream_t *dut, bool Dnstr_en, uint8_t Spg, uint8_t data_in) {
    
    // -------------------------------------------------------------------------
    // 1. COMBINATIONAL STAGE: Extract Taps and Process Masks
    // -------------------------------------------------------------------------
    uint8_t s0[8];
    uint8_t s1[4];

    for (int g = 0; g < 8; g++) {
        s0[g] = get_bit(dut->lfsr[g], 22); // Bit 22 extraction
        if (g < 4) {
            // Next bit lookahead: s1[g] = bit 21 ^ bit 3
            s1[g] = get_bit(dut->lfsr[g], 21) ^ get_bit(dut->lfsr[g], 3);
        }
    }

    // Intermediate XOR Lanes (Purple Gates)
    uint8_t data_xor_s0[8];
    data_xor_s0[0] = get_bit(data_in, 7) ^ s0[0];
    data_xor_s0[1] = get_bit(data_in, 6) ^ s0[1];
    data_xor_s0[2] = get_bit(data_in, 5) ^ s0[2];
    data_xor_s0[3] = get_bit(data_in, 4) ^ s0[3];
    data_xor_s0[4] = get_bit(data_in, 3) ^ s0[4];
    data_xor_s0[5] = get_bit(data_in, 2) ^ s0[5];
    data_xor_s0[6] = get_bit(data_in, 1) ^ s0[6];
    data_xor_s0[7] = get_bit(data_in, 0) ^ s0[7];

    // Interleaved Lanes (Orange Gates)
    uint8_t data_xor_interleaved[4];
    data_xor_interleaved[0] = get_bit(data_in, 1) ^ s1[3];
    data_xor_interleaved[1] = get_bit(data_in, 3) ^ s1[2];
    data_xor_interleaved[2] = get_bit(data_in, 5) ^ s1[1];
    data_xor_interleaved[3] = get_bit(data_in, 7) ^ s1[0];

    // MUX Selection Mapping logic
    bool mux_sel = false;
    if (Spg >= 3 && Spg <= 5) {
        mux_sel = true;
    }

    // UNTOUCHED MANAGER'S DESIGN BLOCK
    uint8_t out_bits[8];
    out_bits[7] = mux_sel ? data_xor_interleaved[0] : data_xor_s0[0];
    out_bits[6] = mux_sel ? data_xor_s0[0]          : data_xor_s0[1];
    out_bits[5] = mux_sel ? data_xor_interleaved[1] : data_xor_s0[2];
    out_bits[4] = mux_sel ? data_xor_s0[1]          : data_xor_s0[3];
    out_bits[3] = mux_sel ? data_xor_interleaved[2] : data_xor_s0[4];
    out_bits[2] = mux_sel ? data_xor_s0[2]          : data_xor_s0[5];
    out_bits[1] = mux_sel ? data_xor_interleaved[3] : data_xor_s0[6];
    out_bits[0] = mux_sel ? data_xor_s0[3]          : data_xor_s0[7];

    // Reconstruct output register byte array
    dut->data_out = 0;
    for (int b = 0; b < 8; b++) {
        dut->data_out |= (out_bits[b] << b);
    }

    // -------------------------------------------------------------------------
    // 2. SEQUENTIAL STAGE: Register State Shift Updates (Clock Edge)
    // -------------------------------------------------------------------------
    bool en_group_a = Dnstr_en;
    bool en_group_b = Dnstr_en && (Spg == 1 || Spg == 2); // Frozen for 3,4,5

    uint32_t next_lfsr[8];
    for (int j = 0; j < 8; j++) {
        next_lfsr[j] = dut->lfsr[j]; // Keep current state default
    }

    // Group A updates: Registers 0 to 3
    if (en_group_a) {
        for (int j = 0; j < 4; j++) {
            uint8_t feedback = get_bit(dut->lfsr[j], 22) ^ get_bit(dut->lfsr[j], 4);
            next_lfsr[j] = ((dut->lfsr[j] & 0x3FFFFF) << 1) | feedback;
        }
    }

    // Group B updates: Registers 4 to 7
    if (en_group_b) {
        for (int j = 4; j < 8; j++) {
            uint8_t feedback = get_bit(dut->lfsr[j], 22) ^ get_bit(dut->lfsr[j], 4);
            next_lfsr[j] = ((dut->lfsr[j] & 0x3FFFFF) << 1) | feedback;
        }
    }

    // Commit calculated state matrices back to structure blocks
    for (int j = 0; j < 8; j++) {
        dut->lfsr[j] = next_lfsr[j] & 0x7FFFFF;
    }
}

// Utility formatting template wrapper to print register rows matching hardware format
void debug_print_state(const lfsr_downstream_t *dut) {
    printf("    LFSR S0 Taps (S01..S04): %d_%d_%d_%d\n", 
           get_bit(dut->lfsr[0], 22), get_bit(dut->lfsr[1], 22), 
           get_bit(dut->lfsr[2], 22), get_bit(dut->lfsr[3], 22));
    printf("    LFSR S0 Taps (S05..S08): %d_%d_%d_%d\n", 
           get_bit(dut->lfsr[4], 22), get_bit(dut->lfsr[5], 22), 
           get_bit(dut->lfsr[6], 22), get_bit(dut->lfsr[7], 22));
}

// -------------------------------------------------------------------------
// Execution Loop
// -------------------------------------------------------------------------
int main() {
    lfsr_downstream_t my_dut;
    uint8_t input_vector = 0x55;

    printf("==========================================================================\n");
    printf("              C-BASED LFSR VECTOR GENERATION TESTBENCH                    \n");
    printf("==========================================================================\n");

    // Test Run 1: Link ID 0, Speed Grade 2 (Lower Rate Parallel Mode)
    printf("\n>>> PART 1: LOWER SPEED GRADE PROCESSING (Spg = 2) <<<\n");
    lfsr_reset(&my_dut, 0);
    
    for (int cycle = 1; cycle <= 3; cycle++) {
        // Step execution before print mimicking dynamic wave evaluations
        lfsr_step(&my_dut, true, 2, input_vector);
        printf("  [Cycle %d] In: 0x%02X -> Scrambled Out: 0x%02X\n", cycle, input_vector, my_dut.data_out);
        debug_print_state(&my_dut);
    }

    // Test Run 2: Transition to Speed Grade 3 (Interleaved Lane Mode) without reset
    printf("\n>>> PART 2: INTERLEAVED HIGHER SPEED SWITCH OVER (Spg = 3) <<<\n");
    for (int cycle = 4; cycle <= 6; cycle++) {
        lfsr_step(&my_dut, true, 3, input_vector);
        printf("  [Cycle %d] In: 0x%02X -> Scrambled Out: 0x%02X\n", cycle, input_vector, my_dut.data_out);
        debug_print_state(&my_dut);
    }

    return 0;
}
