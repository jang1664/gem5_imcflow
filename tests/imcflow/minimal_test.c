#include <stdio.h>
#include <stdint.h>

#define IMCFLOW_BASE    0x80000000UL

int main() {
    printf("Minimal ImcFlow test starting...\n");

    // Try to access the ImcFlow device
    volatile uint32_t *imcflow = (volatile uint32_t*)IMCFLOW_BASE;

    printf("Reading state register...\n");
    uint32_t state = imcflow[0];  // Register 0 (state)
    printf("State register value: %u\n", state);

    printf("Writing to PC register...\n");
    imcflow[2] = 0x1234;  // Register 2 (PC0)

    printf("Reading back PC register...\n");
    uint32_t pc = imcflow[2];
    printf("PC register value: 0x%08x\n", pc);

    printf("Test completed successfully!\n");
    return 0;
}
