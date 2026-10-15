/* matmul: 16x16 integer matrix multiply - multiply-heavy */
#include "../c/lib.h"
#define N 16
static int A[N][N], B[N][N], C[N][N];
int main(void) {
    uint32_t s = 1;
    for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) {
        s = s * 1664525u + 1013904223u; A[i][j] = (int)(s >> 20) - 2048;
        s = s * 1664525u + 1013904223u; B[i][j] = (int)(s >> 20) - 2048;
    }
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            int acc = 0;
            for (int k = 0; k < N; k++) acc += A[i][k] * B[k][j];
            C[i][j] = acc;
        }
    uint32_t chk = 0;
    for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) chk = chk * 31u + (uint32_t)C[i][j];
    puts_("matmul checksum = "); putu(chk); puts_("\n");
    return chk == EXPECTED ? 0 : 1;
}
