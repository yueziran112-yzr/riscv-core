#include "lib.h"
static int data[64];
static uint32_t seed = 12345;
static uint32_t rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }

int main(void) {
    puts_("Hello from my RISC-V core!\n");
    for (int i = 0; i < 64; i++) data[i] = (int)(rnd() % 1000) - 500;
    uint32_t t0 = MTIME;
    for (int i = 1; i < 64; i++) {                 /* insertion sort */
        int k = data[i], j = i - 1;
        while (j >= 0 && data[j] > k) { data[j + 1] = data[j]; j--; }
        data[j + 1] = k;
    }
    uint32_t t1 = MTIME;
    for (int i = 1; i < 64; i++) if (data[i - 1] > data[i]) { puts_("sort FAILED\n"); return 1; }
    int64_t acc = 0;                               /* exercise mul/div */
    for (int i = 0; i < 64; i++) acc += (int64_t)data[i] * (i + 3) / 7;
    puts_("sort OK, cycles = "); putu(t1 - t0);
    puts_(", checksum = "); putu((uint32_t)acc); puts_("\n");
    return 0;
}
