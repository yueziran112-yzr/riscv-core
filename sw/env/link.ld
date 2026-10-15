OUTPUT_ARCH( "riscv" )
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x40);
  .tohost    : { *(.tohost) }
  . = ALIGN(0x40);
  .text      : { *(.text) }
  . = ALIGN(0x40);
  .data      : { *(.data) }
  .bss       : { *(.bss) }
  _end = .;
}
