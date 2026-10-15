# Build riscv-tests (rv32ui + rv32um) with our minimal environment.
RISCV_TESTS ?= $(HOME)/riscv-tests
CROSS       ?= riscv-none-elf-
ARCH        ?= rv32im
BUILD       ?= build

CFLAGS  = -march=$(ARCH) -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden \
          -nostdlib -nostartfiles -Wl,--no-warn-rwx-segments -I env -I $(RISCV_TESTS)/isa/macros/scalar -T env/link.ld

# fence_i and ma_data need self-modifying code / misaligned access support
UI_TESTS = $(filter-out fence_i ma_data,$(basename $(notdir $(wildcard $(RISCV_TESTS)/isa/rv32ui/*.S))))
UM_TESTS = $(basename $(notdir $(wildcard $(RISCV_TESTS)/isa/rv32um/*.S)))
ALL      = $(addprefix rv32ui-,$(UI_TESTS)) $(addprefix rv32um-,$(UM_TESTS))

.SECONDARY:
all: $(addprefix $(BUILD)/,$(addsuffix .hex,$(ALL)))

$(BUILD)/rv32ui-%.elf: $(RISCV_TESTS)/isa/rv32ui/%.S env/riscv_test.h env/link.ld
	@mkdir -p $(BUILD)
	$(CROSS)gcc $(CFLAGS) $< -o $@
$(BUILD)/rv32um-%.elf: $(RISCV_TESTS)/isa/rv32um/%.S env/riscv_test.h env/link.ld
	@mkdir -p $(BUILD)
	$(CROSS)gcc $(CFLAGS) $< -o $@
$(BUILD)/%.hex: $(BUILD)/%.elf
	$(CROSS)objcopy -O binary $< $(BUILD)/$*.bin
	python3 ../scripts/bin2hex.py $(BUILD)/$*.bin $@
	$(CROSS)nm $< | awk '$$3=="tohost"{print $$1}' > $(BUILD)/$*.tohost
	$(CROSS)objdump -d $< > $(BUILD)/$*.dump
clean:
	rm -rf $(BUILD)
