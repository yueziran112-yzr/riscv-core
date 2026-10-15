# Build the C benchmarks (self-checking: exit code 0 = correct result).
CROSS  ?= riscv-none-elf-
BUILD  ?= build
CFLAGS  = -march=rv32im -mabi=ilp32 -O2 -nostdlib -nostartfiles -ffreestanding \
          -T ../c/link.ld -Wl,--no-warn-rwx-segments

# expected checksums (computed with the same C code on a PC)
EXP_matmul = 4057788162u
EXP_sort   = 3460930206u
EXP_crc32  = 3813639939u
EXP_fib    = 2584u
BENCHES    = matmul sort crc32 fib

.SECONDARY:
all: $(addprefix $(BUILD)/,$(addsuffix .hex,$(BENCHES)))

$(BUILD)/%.elf: %.c ../c/crt0.S ../c/lib.h ../c/link.ld
	@mkdir -p $(BUILD)
	$(CROSS)gcc $(CFLAGS) -DEXPECTED=$(EXP_$*) ../c/crt0.S $< -o $@ -lgcc
$(BUILD)/%.hex: $(BUILD)/%.elf
	$(CROSS)objcopy -O binary $< $(BUILD)/$*.bin
	python3 ../../scripts/bin2hex.py $(BUILD)/$*.bin $@
	$(CROSS)nm $< | awk '$$3=="tohost"{print $$1}' > $(BUILD)/$*.tohost
	$(CROSS)objdump -d $< > $(BUILD)/$*.dump
clean:
	rm -rf $(BUILD)
