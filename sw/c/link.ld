OUTPUT_ARCH("riscv")
ENTRY(_start)
MEMORY { RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64K }
SECTIONS
{
  .text   : { *(.text.init) *(.text .text.*) } > RAM
  .tohost : { . = ALIGN(64); *(.tohost) } > RAM
  .rodata : { . = ALIGN(4); *(.rodata .rodata.* .srodata .srodata.*) } > RAM
  .data   : { . = ALIGN(4); *(.data .data.*)
              __global_pointer$ = . + 0x800;
              *(.sdata .sdata.*) } > RAM
  .bss    : { . = ALIGN(4); _bss_start = .; *(.sbss .sbss.*) *(.bss .bss.*) *(COMMON); . = ALIGN(4); _bss_end = .; } > RAM
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
