#! /bin/bash

rm -f *.o *.bin *.elf dump.txt decdump.txt

riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -ffreestanding -nostdlib -c backtoshell.S write_handler.S read_handler.S sys_sd_read.S sys_sd_write.S

riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -ffreestanding -nostdlib -Os -c crt0.S boot.c sysopen.c sysclose.c sysdispatch.c trap_entry.S syswrite.c sysread.c backtoshell.S Globals.c shell.c sysexecve.c sysexit.c

riscv64-unknown-elf-ld -m elf32lriscv -T link.ld crt0.o boot.o sysdispatch.o trap_entry.o backtoshell.o write_handler.o read_handler.o sys_sd_read.o sys_sd_write.o Globals.o shell.o sysexecve.o sysexit.o sysread.o syswrite.o sysopen.o sysclose.o -o kernel.elf

riscv64-unknown-elf-objcopy -O binary kernel.elf kernel.bin

riscv64-unknown-elf-objdump -d -t kernel.elf > dump.txt
python addr2pc4.py dump.txt > decdump.txt

python bin2verilog.py kernel.bin
