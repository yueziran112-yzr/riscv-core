/* fib: recursive Fibonacci - call/return heavy (jal / jalr) */
#include "../c/lib.h"
__attribute__((noinline)) static uint32_t fib(uint32_t n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
int main(void) {
    uint32_t r = fib(18);
    puts_("fib(18) = "); putu(r); puts_("\n");
    return r == EXPECTED ? 0 : 1;
}
