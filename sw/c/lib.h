#pragma once
#include <stdint.h>
#define UART_TX (*(volatile uint32_t *)0x10000000)
#define MTIME   (*(volatile uint32_t *)0x10000008)
static inline void putc_(char c) { UART_TX = (uint32_t)c; }
static inline void puts_(const char *s) { while (*s) putc_(*s++); }
static inline void putu(uint32_t v) {           /* print unsigned decimal, no libc */
    char b[11]; int i = 10; b[i] = 0;
    do { b[--i] = '0' + v % 10; v /= 10; } while (v);
    puts_(&b[i]);
}
