global main
extern printf
extern fflush

section .data
hex_format: db "%#x", 0
float_format: db "%.2f", 0
long_float_format: db "%.2Lf", 0
my_float: dd 42.24

section .text
%macro trap 0
  mov rax, 62
  mov rdi, r12
  mov rsi, 5
  syscall
%endmacro

main:
  push  rbp
  mov rbp, rsp

  ; Get PID
  mov eax, 39
  syscall
  mov r12, rax

  trap

  ; Print the contents of rsi
  lea rdi, [rel hex_format]
  mov rax, 0
  call printf wrt ..plt
  mov rdi, 0
  call fflush wrt ..plt

  trap

  ; Print the contents of xmm0
  lea rdi, [rel float_format]
  mov rax, 1
  call printf wrt ..plt
  mov rdi, 0
  call fflush wrt ..plt

  trap

  ; Print the contents of st0
  sub rsp, 16
  fstp tword [rsp]
  lea rdi, [rel long_float_format]
  mov rax, 0
  call printf wrt ..plt
  mov rdi, 0
  call fflush wrt ..plt
  add rsp, 16

  trap

  pop rbp
  mov rax, 0
  ret
