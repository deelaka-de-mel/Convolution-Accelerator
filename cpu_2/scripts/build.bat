@echo off
set P=riscv-none-elf-
%P%gcc -march=rv32i -mabi=ilp32 -O2 -ffreestanding -nostdlib -nostartfiles -mno-relax -T link.ld -o firmware.elf crt0.S main.c
if errorlevel 1 exit /b 1
%P%objcopy -O binary firmware.elf firmware.bin
if errorlevel 1 exit /b 1
python makehex.py firmware.bin firmware.hex
if errorlevel 1 exit /b 1
%P%size firmware.elf
echo.
echo Done. Copy firmware.hex into the Quartus project folder.
