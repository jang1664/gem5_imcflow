#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>

// ImcFlow device base address (should match gem5 config)
#define IMCFLOW_BASE    0x80000000UL
#define IMCFLOW_SIZE    0x493E0UL // 300000, must match --imc-size default

// Register offsets (based on params.py)
#define REG_STATE       0x00    // REG_STATE_ID = 0
#define REG_CMD         0x04    // REG_CMD_ID_BASE = 1
#define REG_INODE_PC0   0x08    // REG_INODE_PC_ID_BASE = 2
#define REG_INODE_PC1   0x0C
#define REG_INODE_PC2   0x10
#define REG_INODE_PC3   0x14

// Memory regions (based on address map)
#define INODE_0_IMEM_BASE_ADDR 128
#define INODE_0_POLICY_BASE_ADDR 1152
#define IMCE_0_POLICY_BASE_ADDR 1280
#define IMCE_1_POLICY_BASE_ADDR 1408
#define IMCE_2_POLICY_BASE_ADDR 1504
#define IMCE_3_POLICY_BASE_ADDR 1568
#define IMCE_0_IMEM_BASE_ADDR 1600
#define IMCE_1_IMEM_BASE_ADDR 1632
#define IMCE_2_IMEM_BASE_ADDR 1664
#define IMCE_3_IMEM_BASE_ADDR 1696
#define INODE_1_IMEM_BASE_ADDR 66688
#define INODE_1_POLICY_BASE_ADDR 67712
#define IMCE_4_POLICY_BASE_ADDR 67840
#define IMCE_5_POLICY_BASE_ADDR 67968
#define IMCE_6_POLICY_BASE_ADDR 68064
#define IMCE_7_POLICY_BASE_ADDR 68128
#define IMCE_4_IMEM_BASE_ADDR 68160
#define IMCE_5_IMEM_BASE_ADDR 68192
#define IMCE_6_IMEM_BASE_ADDR 68224
#define IMCE_7_IMEM_BASE_ADDR 68256
#define INODE_2_IMEM_BASE_ADDR 133248
#define INODE_2_POLICY_BASE_ADDR 134272
#define IMCE_8_POLICY_BASE_ADDR 134400
#define IMCE_9_POLICY_BASE_ADDR 134528
#define IMCE_10_POLICY_BASE_ADDR 134624
#define IMCE_11_POLICY_BASE_ADDR 134688
#define IMCE_8_IMEM_BASE_ADDR 134720
#define IMCE_9_IMEM_BASE_ADDR 134752
#define IMCE_10_IMEM_BASE_ADDR 134784
#define IMCE_11_IMEM_BASE_ADDR 134816
#define INODE_3_IMEM_BASE_ADDR 199808
#define INODE_3_POLICY_BASE_ADDR 205440
#define IMCE_12_POLICY_BASE_ADDR 205632
#define IMCE_13_POLICY_BASE_ADDR 205824
#define IMCE_14_POLICY_BASE_ADDR 205984
#define IMCE_15_POLICY_BASE_ADDR 206112
#define IMCE_12_IMEM_BASE_ADDR 206208
#define IMCE_13_IMEM_BASE_ADDR 206240
#define IMCE_14_IMEM_BASE_ADDR 206272
#define IMCE_15_IMEM_BASE_ADDR 206304
#define INPUT_DATA_BASE_ADDR 200832
#define OUTPUT_DATA_BASE_ADDR 203136

// .o to .bin has error

// State values
#define STATE_IDLE      0
#define STATE_RUN       1
#define STATE_PROGRAM   2

// PC control flags (top 2 bits of PC register)
#define PC_FLAG_START_P0        (2U << 30) // 0b00...
#define PC_FLAG_START_P1        (0U << 30) // 0b01...
#define PC_FLAG_START_EXTERN    (1U << 30) // 0b10...
#define PC_VAL_MASK             (0x3FFFFFFF)

volatile uint32_t *imcflow_regs;
volatile uint32_t *imcflow_mem;

int map_imcflow_device() {
    printf("Mapping ImcFlow device at 0x%lx (size: 0x%lx)\n", IMCFLOW_BASE, IMCFLOW_SIZE);

    // In real hardware, we'd open /dev/mem
    // For gem5 simulation, we use direct memory access
    imcflow_regs = (volatile uint32_t*)IMCFLOW_BASE;
    imcflow_mem = (volatile uint32_t*)IMCFLOW_BASE;

    return 0;
}

void inode_slv_imem_write(volatile uint32_t *inode_slv_imem) {
    // policy update instruction
    inode_slv_imem[0] = 0x0000001b;
    inode_slv_imem[1] = 0x00001051;
    inode_slv_imem[2] = 0x0100005b;
    inode_slv_imem[3] = 0x00002091;
    inode_slv_imem[4] = 0x0200009b;
    inode_slv_imem[5] = 0x000030d1;
    inode_slv_imem[6] = 0x030000db;
    inode_slv_imem[7] = 0x00080111;
    inode_slv_imem[8] = 0x0004101b;
    inode_slv_imem[9] = 0x0104105b;
    inode_slv_imem[10] = 0x0204109b;
    inode_slv_imem[11] = 0x030410db;
    inode_slv_imem[12] = 0x001000d1;
    inode_slv_imem[13] = 0x0003201b;
    inode_slv_imem[14] = 0x0103205b;
    inode_slv_imem[15] = 0x0203209b;
    inode_slv_imem[16] = 0x00160091;
    inode_slv_imem[17] = 0x0002301b;
    inode_slv_imem[18] = 0x0102305b;
    inode_slv_imem[19] = 0x001a0091;
    inode_slv_imem[20] = 0x0002401b;
    inode_slv_imem[21] = 0x00002003;
    inode_slv_imem[22] = 0x00000022;
    inode_slv_imem[23] = 0x00000014;
    inode_slv_imem[24] = 0x001c0091;
    inode_slv_imem[25] = 0x00000095;
    inode_slv_imem[26] = 0x00000014;
    inode_slv_imem[27] = 0x001e0091;
    inode_slv_imem[28] = 0x00400095;
    inode_slv_imem[29] = 0x00000014;
    inode_slv_imem[30] = 0x00200091;
    inode_slv_imem[31] = 0x00800095;
    inode_slv_imem[32] = 0x00220091;
    inode_slv_imem[33] = 0x00000014;
    inode_slv_imem[34] = 0x00c00095;
    inode_slv_imem[35] = 0x00002003;
    inode_slv_imem[36] = 0x00000022;
    inode_slv_imem[37] = 0x00000022;
    inode_slv_imem[38] = 0x00000000;
    inode_slv_imem[39] = 0x00000000;
}

void inode_mst_imem_write(volatile uint32_t *inode_mst_imem) {
    // policy update instruction
    inode_mst_imem[0] = 0x01200151;
    inode_mst_imem[1] = 0x0005001b;
    inode_mst_imem[2] = 0x00001051;
    inode_mst_imem[3] = 0x0105005b;
    inode_mst_imem[4] = 0x00002091;
    inode_mst_imem[5] = 0x0205009b;
    inode_mst_imem[6] = 0x000030d1;
    inode_mst_imem[7] = 0x030500db;
    inode_mst_imem[8] = 0x00004111;
    inode_mst_imem[9] = 0x0405011b;
    inode_mst_imem[10] = 0x00005191;
    inode_mst_imem[11] = 0x0505019b;
    inode_mst_imem[12] = 0x012c0151;
    inode_mst_imem[13] = 0x0005101b;
    inode_mst_imem[14] = 0x0105105b;
    inode_mst_imem[15] = 0x0205109b;
    inode_mst_imem[16] = 0x030510db;
    inode_mst_imem[17] = 0x0405111b;
    inode_mst_imem[18] = 0x0505119b;
    inode_mst_imem[19] = 0x01380151;
    inode_mst_imem[20] = 0x0005201b;
    inode_mst_imem[21] = 0x0105205b;
    inode_mst_imem[22] = 0x0205209b;
    inode_mst_imem[23] = 0x030520db;
    inode_mst_imem[24] = 0x0405211b;
    inode_mst_imem[25] = 0x01420111;
    inode_mst_imem[26] = 0x0004301b;
    inode_mst_imem[27] = 0x0104305b;
    inode_mst_imem[28] = 0x0204309b;
    inode_mst_imem[29] = 0x030430db;
    inode_mst_imem[30] = 0x014a00d1;
    inode_mst_imem[31] = 0x0003401b;
    inode_mst_imem[32] = 0x0103405b;
    inode_mst_imem[33] = 0x0203409b;
    inode_mst_imem[34] = 0x00002004;
    inode_mst_imem[35] = 0x00002144;
    inode_mst_imem[36] = 0x00002284;
    inode_mst_imem[37] = 0x00000021;
    inode_mst_imem[38] = 0x0000001c;
    inode_mst_imem[39] = 0x00000022;
    inode_mst_imem[40] = 0x00000014;
    inode_mst_imem[41] = 0x01500051;
    inode_mst_imem[42] = 0x00800055;
    inode_mst_imem[43] = 0x00000014;
    inode_mst_imem[44] = 0x01520051;
    inode_mst_imem[45] = 0x00c00055;
    inode_mst_imem[46] = 0x00000014;
    inode_mst_imem[47] = 0x01540051;
    inode_mst_imem[48] = 0x01000055;
    inode_mst_imem[49] = 0x00000014;
    inode_mst_imem[50] = 0x00001051;
    inode_mst_imem[51] = 0x00000091;
    inode_mst_imem[52] = 0x00000d4e;
    inode_mst_imem[53] = 0x000204d2;
    inode_mst_imem[54] = 0x015606d1;
    inode_mst_imem[55] = 0x014000d5;
    inode_mst_imem[56] = 0x00001491;
    inode_mst_imem[57] = 0xfe000c4b;
    inode_mst_imem[58] = 0x00000ece;
    inode_mst_imem[59] = 0x00400020;
    inode_mst_imem[60] = 0x00001051;
    inode_mst_imem[61] = 0x00000091;
    inode_mst_imem[62] = 0x00000fce;
    inode_mst_imem[63] = 0x000204d2;
    inode_mst_imem[64] = 0x204000c1;
    inode_mst_imem[65] = 0x00001491;
    inode_mst_imem[66] = 0xfe80904b;
    inode_mst_imem[67] = 0x0000110e;
    inode_mst_imem[68] = 0x00001051;
    inode_mst_imem[69] = 0x00000091;
    inode_mst_imem[70] = 0x000011ce;
    inode_mst_imem[71] = 0x000204d2;
    inode_mst_imem[72] = 0x009006d1;
    inode_mst_imem[73] = 0x200000c2;
    inode_mst_imem[74] = 0x00001491;
    inode_mst_imem[75] = 0xfe00904b;
    inode_mst_imem[76] = 0x0000134e;
    inode_mst_imem[77] = 0x00001051;
    inode_mst_imem[78] = 0x00002004;
    inode_mst_imem[79] = 0x00002144;
    inode_mst_imem[80] = 0x00002284;
    inode_mst_imem[81] = 0x00000021;
    inode_mst_imem[82] = 0x0000001c;
    inode_mst_imem[83] = 0x00000022;
    inode_mst_imem[84] = 0x00000022;
    inode_mst_imem[85] = 0x00000000;
    inode_mst_imem[86] = 0x00000000;
    inode_mst_imem[87] = 0x00000000;
}

void imce_nop_imem_write(volatile uint32_t *imce_imem) {
    imce_imem[0] = 0x0000003f;
    imce_imem[1] = 0x00000000;
    imce_imem[2] = 0x00000000;
    imce_imem[3] = 0x00000000;
    imce_imem[4] = 0x00000000;
    imce_imem[5] = 0x00000000;
    imce_imem[6] = 0x00000000;
    imce_imem[7] = 0x00000000;
}

void imce_relu_imem_write(volatile uint32_t *imce_imem) {
    imce_imem[0] = 0x00080073;
    imce_imem[1] = 0x00000000;
    imce_imem[2] = 0x00000000;
    imce_imem[3] = 0x00000000;
    imce_imem[4] = 0x00000000;
    imce_imem[5] = 0x00000000;
    imce_imem[6] = 0x00000000;
    imce_imem[7] = 0x00000000;
    imce_imem[8] = 0x00001068;
    imce_imem[9] = 0x00000000;
    imce_imem[10] = 0x00000000;
    imce_imem[11] = 0x00000000;
    imce_imem[12] = 0x00000000;
    imce_imem[13] = 0x00000000;
    imce_imem[14] = 0x00000000;
    imce_imem[15] = 0x00000000;
    imce_imem[16] = 0x00081032;
    imce_imem[17] = 0x00000000;
    imce_imem[18] = 0x00000000;
    imce_imem[19] = 0x00000000;
    imce_imem[20] = 0x00000000;
    imce_imem[21] = 0x00000000;
    imce_imem[22] = 0x00000000;
    imce_imem[23] = 0x00000000;
    imce_imem[24] = 0x01230f78;
    imce_imem[25] = 0x00000000;
    imce_imem[26] = 0x00000000;
    imce_imem[27] = 0x00000000;
    imce_imem[28] = 0x00000000;
    imce_imem[29] = 0x00000000;
    imce_imem[30] = 0x00000000;
    imce_imem[31] = 0x00000000;
    imce_imem[32] = 0x0000017c;
    imce_imem[33] = 0x00000000;
    imce_imem[34] = 0x00000000;
    imce_imem[35] = 0x00000000;
    imce_imem[36] = 0x00000000;
    imce_imem[37] = 0x00000000;
    imce_imem[38] = 0x00000000;
    imce_imem[39] = 0x00000000;
    imce_imem[40] = 0x0000003f;
    imce_imem[41] = 0x00000000;
    imce_imem[42] = 0x00000000;
    imce_imem[43] = 0x00000000;
    imce_imem[44] = 0x00000000;
    imce_imem[45] = 0x00000000;
    imce_imem[46] = 0x00000000;
    imce_imem[47] = 0x00000000;
}

void inode_slv_policy_table_write(volatile uint32_t *inode_policy) {
    inode_policy[0] = 0x00100000;
    inode_policy[1] = 0x00000000;
    inode_policy[2] = 0x00000000;
    inode_policy[3] = 0x00000000;
    inode_policy[4] = 0x00000000;
    inode_policy[5] = 0x00000000;
    inode_policy[6] = 0x00000000;
    inode_policy[7] = 0x00000000;
    inode_policy[8] = 0x00104000;
    inode_policy[9] = 0x00000000;
    inode_policy[10] = 0x00000000;
    inode_policy[11] = 0x00000000;
    inode_policy[12] = 0x00000000;
    inode_policy[13] = 0x00000000;
    inode_policy[14] = 0x00000000;
    inode_policy[15] = 0x00000000;
    inode_policy[16] = 0x00108000;
    inode_policy[17] = 0x00000000;
    inode_policy[18] = 0x00000000;
    inode_policy[19] = 0x00000000;
    inode_policy[20] = 0x00000000;
    inode_policy[21] = 0x00000000;
    inode_policy[22] = 0x00000000;
    inode_policy[23] = 0x00000000;
    inode_policy[24] = 0x0010c000;
    inode_policy[25] = 0x00000000;
    inode_policy[26] = 0x00000000;
    inode_policy[27] = 0x00000000;
    inode_policy[28] = 0x00000000;
    inode_policy[29] = 0x00000000;
    inode_policy[30] = 0x00000000;
    inode_policy[31] = 0x00000000;
}

void inode_mst_policy_table_write(volatile uint32_t *inode_policy) {
    inode_policy[0] = 0x00000000;
    inode_policy[1] = 0x00000800;
    inode_policy[2] = 0x00000000;
    inode_policy[3] = 0x00000000;
    inode_policy[4] = 0x00000000;
    inode_policy[5] = 0x00000000;
    inode_policy[6] = 0x00000000;
    inode_policy[7] = 0x00000000;
    inode_policy[8] = 0x00104000;
    inode_policy[9] = 0x00000000;
    inode_policy[10] = 0x00000000;
    inode_policy[11] = 0x00000000;
    inode_policy[12] = 0x00000000;
    inode_policy[13] = 0x00000000;
    inode_policy[14] = 0x00000000;
    inode_policy[15] = 0x00000000;
    inode_policy[16] = 0x00108000;
    inode_policy[17] = 0x00000000;
    inode_policy[18] = 0x00000000;
    inode_policy[19] = 0x00000000;
    inode_policy[20] = 0x00000000;
    inode_policy[21] = 0x00000000;
    inode_policy[22] = 0x00000000;
    inode_policy[23] = 0x00000000;
    inode_policy[24] = 0x0010c000;
    inode_policy[25] = 0x00000000;
    inode_policy[26] = 0x00000000;
    inode_policy[27] = 0x00000000;
    inode_policy[28] = 0x00000000;
    inode_policy[29] = 0x00000000;
    inode_policy[30] = 0x00000000;
    inode_policy[31] = 0x00000000;
    inode_policy[32] = 0x00110000;
    inode_policy[33] = 0x00000000;
    inode_policy[34] = 0x00000000;
    inode_policy[35] = 0x00000000;
    inode_policy[36] = 0x00000000;
    inode_policy[37] = 0x00000000;
    inode_policy[38] = 0x00000000;
    inode_policy[39] = 0x00000000;
    inode_policy[40] = 0x00114000;
    inode_policy[41] = 0x00000000;
    inode_policy[42] = 0x00000000;
    inode_policy[43] = 0x00000000;
    inode_policy[44] = 0x00000000;
    inode_policy[45] = 0x00000000;
    inode_policy[46] = 0x00000000;
    inode_policy[47] = 0x00000000;
}

void imce_slv_policy_table_write(volatile uint32_t *imce_policy, int w_id) {
  if (w_id < 4) {
    imce_policy[0] = 0x00000000;
    imce_policy[1] = 0x00000800;
    imce_policy[2] = 0x00000000;
    imce_policy[3] = 0x00000000;
    imce_policy[4] = 0x00000000;
    imce_policy[5] = 0x00000000;
    imce_policy[6] = 0x00000000;
    imce_policy[7] = 0x00000000;
    if (w_id < 3) {
      imce_policy[8] = 0x00100000;
      imce_policy[9] = 0x00000000;
      imce_policy[10] = 0x00000000;
      imce_policy[11] = 0x00000000;
      imce_policy[12] = 0x00000000;
      imce_policy[13] = 0x00000000;
      imce_policy[14] = 0x00000000;
      imce_policy[15] = 0x00000000;
      if (w_id < 2) {
        imce_policy[16] = 0x00104000;
        imce_policy[17] = 0x00000000;
        imce_policy[18] = 0x00000000;
        imce_policy[19] = 0x00000000;
        imce_policy[20] = 0x00000000;
        imce_policy[21] = 0x00000000;
        imce_policy[22] = 0x00000000;
        imce_policy[23] = 0x00000000;
        if (w_id < 1) {
          imce_policy[24] = 0x00108000;
          imce_policy[25] = 0x00000000;
          imce_policy[26] = 0x00000000;
          imce_policy[27] = 0x00000000;
          imce_policy[28] = 0x00000000;
          imce_policy[29] = 0x00000000;
          imce_policy[30] = 0x00000000;
          imce_policy[31] = 0x00000000;
        }
      }
    }
  }
}

void imce_mst_policy_table_write_0(volatile uint32_t *imce_policy, int w_id) {
  if (w_id < 4) {
    imce_policy[0] = 0x00000040;
    imce_policy[1] = 0x00000000;
    imce_policy[2] = 0x00000000;
    imce_policy[3] = 0x00000000;
    imce_policy[4] = 0x00000000;
    imce_policy[5] = 0x00000000;
    imce_policy[6] = 0x00000000;
    imce_policy[7] = 0x00000000;
    imce_policy[8] = 0x00104000;
    imce_policy[9] = 0x00000000;
    imce_policy[10] = 0x00000000;
    imce_policy[11] = 0x00000000;
    imce_policy[12] = 0x00000000;
    imce_policy[13] = 0x00000000;
    imce_policy[14] = 0x00000000;
    imce_policy[15] = 0x00000000;
    imce_policy[16] = 0x00000000;
    imce_policy[17] = 0x00000800;
    imce_policy[18] = 0x00000000;
    imce_policy[19] = 0x00000000;
    imce_policy[20] = 0x00000000;
    imce_policy[21] = 0x00000000;
    imce_policy[22] = 0x00000000;
    imce_policy[23] = 0x00000000;
    if (w_id < 3) {
      imce_policy[24] = 0x00108000;
      imce_policy[25] = 0x00000000;
      imce_policy[26] = 0x00000000;
      imce_policy[27] = 0x00000000;
      imce_policy[28] = 0x00000000;
      imce_policy[29] = 0x00000000;
      imce_policy[30] = 0x00000000;
      imce_policy[31] = 0x00000000;
      if (w_id < 2) {
        imce_policy[32] = 0x0010c000;
        imce_policy[33] = 0x00000000;
        imce_policy[34] = 0x00000000;
        imce_policy[35] = 0x00000000;
        imce_policy[36] = 0x00000000;
        imce_policy[37] = 0x00000000;
        imce_policy[38] = 0x00000000;
        imce_policy[39] = 0x00000000;
        if (w_id < 1) {
          imce_policy[40] = 0x00110000;
          imce_policy[41] = 0x00000000;
          imce_policy[42] = 0x00000000;
          imce_policy[43] = 0x00000000;
          imce_policy[44] = 0x00000000;
          imce_policy[45] = 0x00000000;
          imce_policy[46] = 0x00000000;
          imce_policy[47] = 0x00000000;
        }
      }
    }
  }
}

void imce_mst_policy_table_write_1(volatile uint32_t *imce_policy, int w_id) {
    imce_policy[0] = 0x00000040;
    imce_policy[1] = 0x00000000;
    imce_policy[2] = 0x00000000;
    imce_policy[3] = 0x00000000;
    imce_policy[4] = 0x00000000;
    imce_policy[5] = 0x00000000;
    imce_policy[6] = 0x00000000;
    imce_policy[7] = 0x00000000;
    imce_policy[8] = 0x00000000;
    imce_policy[9] = 0x00000800;
    imce_policy[10] = 0x00000000;
    imce_policy[11] = 0x00000000;
    imce_policy[12] = 0x00000000;
    imce_policy[13] = 0x00000000;
    imce_policy[14] = 0x00000000;
    imce_policy[15] = 0x00000000;
    imce_policy[16] = 0x00000000;
    imce_policy[17] = 0x00000800;
    imce_policy[18] = 0x00000000;
    imce_policy[19] = 0x00000000;
    imce_policy[20] = 0x00000000;
    imce_policy[21] = 0x00000000;
    imce_policy[22] = 0x00000000;
    imce_policy[23] = 0x00000000;
}

void input_data_write(volatile uint32_t *input_data) {
    for (int i = 0; i < 1; i++) {
      for (int j = 0; j < 14; j++) {
        for (int k = 0; k < 6; k++) {
          for (int l = 0; l < 6; l++) {
            input_data[i*14*6*6 + j*6*6 + k*6 + l] = (l % 2 == 0) ? 1 : -1;
          }
        }
      }
    }
}

void test_relu() {
    printf("\n=== Testing Interrupt Handling ===\n");
//
    // This is a placeholder as actual interrupt handling would require
    // integration with the gem5 simulation environment.
    printf("Simulating interrupt handling is not implemented in this test.\n");
    // Setting memory for all nodes
    printf("Setting memory for all nodes...\n");
    volatile uint32_t *inode_0_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_0_IMEM_BASE_ADDR);
    volatile uint32_t *inode_0_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_0_POLICY_BASE_ADDR);
    volatile uint32_t *imce_0_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_0_IMEM_BASE_ADDR);
    volatile uint32_t *imce_0_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_0_POLICY_BASE_ADDR);
    volatile uint32_t *imce_1_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_1_IMEM_BASE_ADDR);
    volatile uint32_t *imce_1_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_1_POLICY_BASE_ADDR);
    volatile uint32_t *imce_2_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_2_IMEM_BASE_ADDR);
    volatile uint32_t *imce_2_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_2_POLICY_BASE_ADDR);
    volatile uint32_t *imce_3_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_3_IMEM_BASE_ADDR);
    volatile uint32_t *imce_3_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_3_POLICY_BASE_ADDR);
    volatile uint32_t *inode_1_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_1_IMEM_BASE_ADDR);
    volatile uint32_t *inode_1_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_1_POLICY_BASE_ADDR);
    volatile uint32_t *imce_4_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_4_IMEM_BASE_ADDR);
    volatile uint32_t *imce_4_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_4_POLICY_BASE_ADDR);
    volatile uint32_t *imce_5_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_5_IMEM_BASE_ADDR);
    volatile uint32_t *imce_5_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_5_POLICY_BASE_ADDR);
    volatile uint32_t *imce_6_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_6_IMEM_BASE_ADDR);
    volatile uint32_t *imce_6_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_6_POLICY_BASE_ADDR);
    volatile uint32_t *imce_7_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_7_IMEM_BASE_ADDR);
    volatile uint32_t *imce_7_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_7_POLICY_BASE_ADDR);
    volatile uint32_t *inode_2_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_2_IMEM_BASE_ADDR);
    volatile uint32_t *inode_2_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_2_POLICY_BASE_ADDR);
    volatile uint32_t *imce_8_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_8_IMEM_BASE_ADDR);
    volatile uint32_t *imce_8_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_8_POLICY_BASE_ADDR);
    volatile uint32_t *imce_9_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_9_IMEM_BASE_ADDR);
    volatile uint32_t *imce_9_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_9_POLICY_BASE_ADDR);
    volatile uint32_t *imce_10_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_10_IMEM_BASE_ADDR);
    volatile uint32_t *imce_10_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_10_POLICY_BASE_ADDR);
    volatile uint32_t *imce_11_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_11_IMEM_BASE_ADDR);
    volatile uint32_t *imce_11_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_11_POLICY_BASE_ADDR);
    volatile uint32_t *inode_3_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_3_IMEM_BASE_ADDR);
    volatile uint32_t *inode_3_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + INODE_3_POLICY_BASE_ADDR);
    volatile uint32_t *imce_12_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_12_IMEM_BASE_ADDR);
    volatile uint32_t *imce_12_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_12_POLICY_BASE_ADDR);
    volatile uint32_t *imce_13_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_13_IMEM_BASE_ADDR);
    volatile uint32_t *imce_13_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_13_POLICY_BASE_ADDR);
    volatile uint32_t *imce_14_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_14_IMEM_BASE_ADDR);
    volatile uint32_t *imce_14_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_14_POLICY_BASE_ADDR);
    volatile uint32_t *imce_15_imem = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_15_IMEM_BASE_ADDR);
    volatile uint32_t *imce_15_policy = (volatile uint32_t*)((uint8_t*)imcflow_mem + IMCE_15_POLICY_BASE_ADDR);

    // Setting input & output data region
    printf("Setting memory for all in/out data...\n");
    volatile uint32_t *input_data_region = (volatile uint32_t*)((uint8_t*)imcflow_mem + INPUT_DATA_BASE_ADDR);
    volatile uint32_t *output_data_region = (volatile uint32_t*)((uint8_t*)imcflow_mem + OUTPUT_DATA_BASE_ADDR);

    // Writing simple program to inode & imce instruction memory
    inode_slv_imem_write(inode_0_imem);
    inode_slv_imem_write(inode_1_imem);
    inode_slv_imem_write(inode_2_imem);

    inode_mst_imem_write(inode_3_imem);

    imce_nop_imem_write(imce_0_imem);
    imce_nop_imem_write(imce_1_imem);
    imce_nop_imem_write(imce_2_imem);
    imce_nop_imem_write(imce_3_imem);
    imce_nop_imem_write(imce_4_imem);
    imce_nop_imem_write(imce_5_imem);
    imce_nop_imem_write(imce_6_imem);
    imce_nop_imem_write(imce_7_imem);
    imce_nop_imem_write(imce_8_imem);
    imce_nop_imem_write(imce_9_imem);
    imce_nop_imem_write(imce_10_imem);
    imce_nop_imem_write(imce_11_imem);
    imce_nop_imem_write(imce_12_imem);
    imce_nop_imem_write(imce_13_imem);
    imce_nop_imem_write(imce_14_imem);

    imce_relu_imem_write(imce_15_imem);

    // Writing Policy Tables to inode data memory
    inode_slv_policy_table_write(inode_0_policy);
    inode_slv_policy_table_write(inode_1_policy);
    inode_slv_policy_table_write(inode_2_policy);

    inode_mst_policy_table_write(inode_3_policy);

    imce_slv_policy_table_write(imce_0_policy, 0);
    imce_slv_policy_table_write(imce_1_policy, 1);
    imce_slv_policy_table_write(imce_2_policy, 2);
    imce_slv_policy_table_write(imce_3_policy, 3);

    imce_slv_policy_table_write(imce_4_policy, 0);
    imce_slv_policy_table_write(imce_5_policy, 1);
    imce_slv_policy_table_write(imce_6_policy, 2);
    imce_slv_policy_table_write(imce_7_policy, 3);

    imce_slv_policy_table_write(imce_8_policy, 0);
    imce_slv_policy_table_write(imce_9_policy, 1);
    imce_slv_policy_table_write(imce_10_policy, 2);
    imce_slv_policy_table_write(imce_11_policy, 3);

    imce_mst_policy_table_write_0(imce_12_policy, 0);
    imce_mst_policy_table_write_0(imce_13_policy, 1);
    imce_mst_policy_table_write_0(imce_14_policy, 2);
    imce_mst_policy_table_write_1(imce_15_policy, 3);

    // Writing input data to inode data memory
    input_data_write(input_data_region);

    // Setting PC registers to start execution
    printf("\n=== Register Access ===\n");
    // Read initial state
    uint32_t state = imcflow_regs[REG_STATE/4];
    printf("Initial state: %u (expected: %u)\n", state, STATE_IDLE);

    printf("Current state: %u\n", state);
    // Set a valid PC value before running
    printf("Setting PC for inode0 to start at 0x0 with external flag\n");
    imcflow_regs[REG_INODE_PC0/4] = PC_FLAG_START_EXTERN | 0x0;
    imcflow_regs[REG_INODE_PC1/4] = PC_FLAG_START_EXTERN | 0x0;
    imcflow_regs[REG_INODE_PC2/4] = PC_FLAG_START_EXTERN | 0x0;
    imcflow_regs[REG_INODE_PC3/4] = PC_FLAG_START_EXTERN | 0x0;
    // Set Program state
    printf("Writing PROGRAM command to trigger simulation...\n");
    imcflow_regs[REG_CMD/4] = STATE_PROGRAM;
    // Wait interrupt

    // Running programmed instructions
    imcflow_regs[REG_INODE_PC0/4] = PC_FLAG_START_P1 | 0x0;
    imcflow_regs[REG_INODE_PC1/4] = PC_FLAG_START_P1 | 0x0;
    imcflow_regs[REG_INODE_PC2/4] = PC_FLAG_START_P1 | 0x0;
    imcflow_regs[REG_INODE_PC3/4] = PC_FLAG_START_P1 | 0x0;
    // Set Run state
    printf("Writing RUN command to trigger simulation...\n");
    imcflow_regs[REG_CMD/4] = STATE_RUN;
    //Wait interrupt

    // Check output data
    printf("\n=== Checking Output Data ===\n");
    uint32_t num_errors = 0;
    for (int i = 0; i < 1; i++) {
      for (int j = 0; j < 14; j++) {
        for (int k = 0; k < 6; k++) {
          for (int l = 0; l < 6; l++) {
            uint32_t val = output_data_region[i*14*6*6 + j*6*6 + k*6 + l];
            uint32_t expected = (l % 2 == 0) ? 1 : 0;
            if (val != expected) {
              printf("Mismatch at output_data[%d][%d][%d][%d]: got %u, expected %u\n",
                     i, j, k, l, val, expected);
              num_errors++;
            }
          }
        }
      }
    }

    if (num_errors == 0) {
      printf("All output data matches expected values.\n");
    } else {
      printf("Total mismatches: %u\n", num_errors);
    }

}

int main() {
    printf("ImcFlow Device Test Program\n");
    printf("===========================\n");

    if (map_imcflow_device() != 0) {
        printf("Failed to map ImcFlow device\n");
        return 1;
    }

    printf("Successfully mapped ImcFlow device\n");

    test_relu();

    printf("\n=== Test Summary ===\n");
    printf("ImcFlow device testing completed.\n");
    printf("Check output above for individual test results.\n");

    return 0;
}
