#!/bin/bash
rm $1
nasm -f elf64 -gdwarf $1.asm 
gcc -o $1 $1.o -lX11 -no-pie
./$1
