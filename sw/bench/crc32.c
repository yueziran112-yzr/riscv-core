/* crc32: bitwise CRC-32 over 512 bytes - shifts, xor and data-dependent branches */
#include "../c/lib.h"
static uint8_t buf[512];
int main(void) {
    for (int i = 0; i < 512; i++) buf[i] = (uint8_t)(i * 7 + (i >> 3));
    uint32_t crc = 0xFFFFFFFFu;
    for (int i = 0; i < 512; i++) {
        crc ^= buf[i];
        for (int b = 0; b < 8; b++) crc = (crc & 1) ? (crc >> 1) ^ 0xEDB88320u : crc >> 1;
    }
    crc = ~crc;
    puts_("crc32 = "); putu(crc); puts_("\n");
    return crc == EXPECTED ? 0 : 1;
}
