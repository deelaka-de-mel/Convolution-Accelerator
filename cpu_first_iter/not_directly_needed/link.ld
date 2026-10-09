MEMORY { RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K }
_stack_top = ORIGIN(RAM) + LENGTH(RAM);
SECTIONS {
  .text : { *(.text.start) *(.text*) *(.rodata*) . = ALIGN(4); } > RAM
  .data : { *(.data*) *(.sdata*) . = ALIGN(4); } > RAM
  .bss  : { . = ALIGN(4); _sbss = .; *(.bss*) *(.sbss*) *(COMMON) . = ALIGN(4); _ebss = .; } > RAM
}
