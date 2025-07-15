#!/bin/bash

nasm -f elf64 reg_write.s -o reg_write.o
gcc reg_write.o -o reg_write
