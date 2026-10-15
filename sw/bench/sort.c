/* sort: insertion sort of 200 integers - branch-heavy, no multiply in the kernel */
#include "../c/lib.h"
#define N 200
static int d[N];
int main(void) {
    uint32_t s = 7;
    for (int i = 0; i < N; i++) { s ^= s << 13; s ^= s >> 17; s ^= s << 5; d[i] = (int)(s & 0xFFFF) - 32768; }
    for (int i = 1; i < N; i++) {
        int k = d[i], j = i - 1;
        while (j >= 0 && d[j] > k) { d[j + 1] = d[j]; j--; }
        d[j + 1] = k;
    }
    uint32_t chk = 0;
    for (int i = 0; i < N; i++) { if (i && d[i - 1] > d[i]) return 2; chk = (chk << 1 | chk >> 31) ^ (uint32_t)d[i]; }
    puts_("sort checksum = "); putu(chk); puts_("\n");
    return chk == EXPECTED ? 0 : 1;
}
