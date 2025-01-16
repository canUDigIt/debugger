package debugger

import "core:sys/linux"
import c "core:c/libc"
import "core:reflect"

user_regs_union :: struct #raw_union {
    ar0 : ^linux.User_Regs,
    ar0_word : c.ulonglong,
}

user_fpregs_union :: struct #raw_union {
    fpstate : ^linux.User_FP_Regs,
    fpstate_word : c.ulonglong,
}

user :: struct {
  regs: linux.User_Regs,
  fpvalid: c.int,
  i387: linux.User_FP_Regs,
  tsize: c.ulonglong,
  dsize: c.ulonglong,
  ssize: c.ulonglong,
  start_code: c.ulonglong,
  start_stack: c.ulonglong,
  signal: c.longlong,
  reserved: c.int,
  using regs_union: user_regs_union,
  using fpregs_union: user_fpregs_union,
  magic: c.ulonglong,
  comm: [32]c.char,
  u_debugreg: [8]c.ulonglong,
}

reg :: enum {
  // 64bit registers
  rax, rbx, rcx, rdx,
  rdi, rsi, rbp, rsp,
  r8,  r9,  r10, r11,
  r12, r13, r14, r15,
  rip, eflags, cs,
  orig_rax,
  // fs_base,
  // gs_base,
  fs, gs, ss, ds, es,

  // 32bit registers
  eax, edx,
  ecx, ebx,
  esi, edi,
  ebp, esp,
  r8d, r9d,
  r10d, r11d,
  r12d, r13d,
  r14d, r15d,

  // 16bit registers
  ax, dx,
  cx, bx,
  si, di,
  bp, sp,
  r8w, r9w,
  r10w, r11w,
  r12w, r13w,
  r14w, r15w,

  // 8bit registers
  ah, dh,
  ch, bh,

  al, dl,
  cl, bl,
  sil, dil,
  bpl, spl,
  r8b, r9b,
  r10b, r11b,
  r12b, r13b,
  r14b, r15b,

  // Floating point registers
  fcw,
  fsw,
  ftw,
  fop,
  frip,
  frdp,
  mxcsr,
  mxcsr_mask,

  st0,
  st1,
  st2,
  st3,
  st4,
  st5,
  st6,
  st7,

  mm0,
  mm1,
  mm2,
  mm3,
  mm4,
  mm5,
  mm6,
  mm7,

  xmm0,
  xmm1,
  xmm2,
  xmm3,
  xmm4,
  xmm5,
  xmm6,
  xmm7,
  xmm8,
  xmm9,
  xmm10,
  xmm11,
  xmm12,
  xmm13,
  xmm14,
  xmm15,
}

reg_type :: enum {
  gpr,
  sub_gpr,
  fpr,
  dr,
}

reg_format :: enum {
  uint,
  double_float,
  long_double,
  vector,
}

reg_info :: struct {
  id: reg,
  name: string,
  dwarf_r: int,
  size: uint,
  offset: uintptr,
  type: reg_type,
  format: reg_format,
}

g_register_info := []reg_info {
  {.rax, "rax", 0, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rax), .gpr, .uint},
  {.rdx, "rdx", 1, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rdx), .gpr, .uint},
  {.rcx, "rcx", 2, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rcx), .gpr, .uint},
  {.rbx, "rbx", 3, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rbx), .gpr, .uint},
  {.rsi, "rsi", 4, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rsi), .gpr, .uint},
  {.rdi, "rdi", 5, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rdi), .gpr, .uint},
  {.rbp, "rbp", 6, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rbp), .gpr, .uint},
  {.rsp, "rsp", 7, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rsp), .gpr, .uint},
  {.r8, "r8", 8, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r8), .gpr, .uint},
  {.r9, "r9", 9, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r9), .gpr, .uint},
  {.r10, "r10", 10, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r10), .gpr, .uint},
  {.r11, "r11", 11, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r11), .gpr, .uint},
  {.r12, "r12", 12, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r12), .gpr, .uint},
  {.r13, "r13", 13, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r13), .gpr, .uint},
  {.r14, "r14", 14, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r14), .gpr, .uint},
  {.r15, "r15", 15, 8, offset_of(user, regs) + offset_of(linux.User_Regs, r15), .gpr, .uint},
  {.rip, "rip", 16, 8, offset_of(user, regs) + offset_of(linux.User_Regs, rip), .gpr, .uint},
  {.eflags, "eflags", 49, 8, offset_of(user, regs) + offset_of(linux.User_Regs, eflags), .gpr, .uint},
  {.es, "es", 50, 8, offset_of(user, regs) + offset_of(linux.User_Regs, es), .gpr, .uint},
  {.cs, "cs", 51, 8, offset_of(user, regs) + offset_of(linux.User_Regs, cs), .gpr, .uint},
  {.ss, "ss", 52, 8, offset_of(user, regs) + offset_of(linux.User_Regs, ss), .gpr, .uint},
  {.ds, "ds", 53, 8, offset_of(user, regs) + offset_of(linux.User_Regs, ds), .gpr, .uint},
  {.fs, "fs", 54, 8, offset_of(user, regs) + offset_of(linux.User_Regs, fs), .gpr, .uint},
  {.gs, "gs", 55, 8, offset_of(user, regs) + offset_of(linux.User_Regs, gs), .gpr, .uint},
  {.orig_rax, "orig_rax", -1, 8, offset_of(user, regs) + offset_of(linux.User_Regs, orig_rax), .gpr, .uint},
  // .fs_base = {"fs_base", 58, 8, offset_of(user, regs) + offset_of(linux.User_Regs, fs_base), .gpr, .uint},
  // .gs_base = {"gs_base", 59, 8, offset_of(user, regs) + offset_of(linux.User_Regs, gs_base), .gpr, .uint},

  // 32bit registers
  {.eax,  "eax", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rax), .sub_gpr, .uint},
  {.edx,  "edx", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rdx), .sub_gpr, .uint},
  {.ecx,  "ecx", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rcx), .sub_gpr, .uint},
  {.ebx,  "ebx", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rbx), .sub_gpr, .uint},
  {.esi,  "esi", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rsi), .sub_gpr, .uint},
  {.edi,  "edi", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rdi), .sub_gpr, .uint},
  {.ebp,  "ebp", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rbp), .sub_gpr, .uint},
  {.esp,  "esp", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, rsp), .sub_gpr, .uint},
  {.r8d,  "r8d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r8), .sub_gpr, .uint},
  {.r9d,  "r9d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r9), .sub_gpr, .uint},
  {.r10d,  "r10d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r10), .sub_gpr, .uint},
  {.r11d,  "r11d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r11), .sub_gpr, .uint},
  {.r12d,  "r12d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r12), .sub_gpr, .uint},
  {.r13d,  "r13d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r13), .sub_gpr, .uint},
  {.r14d,  "r14d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r14), .sub_gpr, .uint},
  {.r15d,  "r15d", -1, 4, offset_of(user, regs) + offset_of(linux.User_Regs, r15), .sub_gpr, .uint},

  // 16bit registers
  {.ax,  "ax", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rax), .sub_gpr, .uint},
  {.dx,  "dx", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rdx), .sub_gpr, .uint},
  {.cx,  "cx", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rcx), .sub_gpr, .uint},
  {.bx,  "bx", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rbx), .sub_gpr, .uint},
  {.si,  "si", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rsi), .sub_gpr, .uint},
  {.di,  "di", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rdi), .sub_gpr, .uint},
  {.bp,  "bp", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rbp), .sub_gpr, .uint},
  {.sp,  "sp", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, rsp), .sub_gpr, .uint},
  {.r8w,  "r8w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r8), .sub_gpr, .uint},
  {.r9w,  "r9w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r9), .sub_gpr, .uint},
  {.r10w,  "r10w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r10), .sub_gpr, .uint},
  {.r11w,  "r11w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r11), .sub_gpr, .uint},
  {.r12w,  "r12w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r12), .sub_gpr, .uint},
  {.r13w,  "r13w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r13), .sub_gpr, .uint},
  {.r14w,  "r14w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r14), .sub_gpr, .uint},
  {.r15w,  "r15w", -1, 2, offset_of(user, regs) + offset_of(linux.User_Regs, r15), .sub_gpr, .uint},

  // 8bit registers
  {.ah,  "ah", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rax), .sub_gpr, .uint},
  {.dh,  "dh", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rdx), .sub_gpr, .uint},
  {.ch,  "ch", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rcx), .sub_gpr, .uint},
  {.bh,  "bh", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rbx), .sub_gpr, .uint},

  {.al,  "al", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rax), .sub_gpr, .uint},
  {.dl,  "dl", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rdx), .sub_gpr, .uint},
  {.cl,  "cl", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rcx), .sub_gpr, .uint},
  {.bl,  "bl", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rbx), .sub_gpr, .uint},
  {.sil,  "sil", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rsi), .sub_gpr, .uint},
  {.dil,  "dil", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rdi), .sub_gpr, .uint},
  {.bpl,  "bpl", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rbp), .sub_gpr, .uint},
  {.spl,  "spl", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, rsp), .sub_gpr, .uint},
  {.r8b,  "r8b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r8), .sub_gpr, .uint},
  {.r9b,  "r9b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r9), .sub_gpr, .uint},
  {.r10b,  "r10b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r10), .sub_gpr, .uint},
  {.r11b,  "r11b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r11), .sub_gpr, .uint},
  {.r12b,  "r12b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r12), .sub_gpr, .uint},
  {.r13b,  "r13b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r13), .sub_gpr, .uint},
  {.r14b,  "r14b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r14), .sub_gpr, .uint},
  {.r15b,  "r15b", -1, 1, offset_of(user, regs) + offset_of(linux.User_Regs, r15), .sub_gpr, .uint},

  // Floating point registers
  {.fcw,  "fcw", 65, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "cwd").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, cwd), .fpr, .uint },
  {.fsw,  "fsw", 66, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "swd").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, swd), .fpr, .uint },
  {.ftw,  "ftw", -1, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "twd").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, twd), .fpr, .uint },
  {.fop,  "fop", -1, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "fop").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, fop), .fpr, .uint },
  {.frip,  "frip", -1, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "rip").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, rip), .fpr, .uint },
  {.frdp,  "frdp", -1, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "rdp").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, rdp), .fpr, .uint },
  {.mxcsr,  "mxcsr", 64, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "mxcsr").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, mxcsr), .fpr, .uint },
  {.mxcsr_mask,  "mxcsr_mask", -1, size_of(reflect.struct_field_by_name(linux.User_FP_Regs, "mxcsr_mask").type), offset_of(user, i387) + offset_of(linux.User_FP_Regs, mxcsr_mask), .fpr, .uint },

  //use these to replace st registers
  // .st\1 = { "st\1", (33 + \1), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + \1*16, .fpr, .long_double },
  {.st0,  "st0", (33 + 0), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 0*16, .fpr, .long_double },
  {.st1,  "st1", (33 + 1), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 1*16, .fpr, .long_double },
  {.st2,  "st2", (33 + 2), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 2*16, .fpr, .long_double },
  {.st3,  "st3", (33 + 3), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 3*16, .fpr, .long_double },

  {.st4,  "st4", (33 + 4), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 4*16, .fpr, .long_double },
  {.st5,  "st5", (33 + 5), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 5*16, .fpr, .long_double },
  {.st6,  "st6", (33 + 6), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 6*16, .fpr, .long_double },
  {.st7,  "st7", (33 + 7), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 7*16, .fpr, .long_double },

  //use these to replace mm registers
  // .mm\1 = { "mm\1", (41 + \1), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + \1*16, .fpr, .vector },
  {.mm0,  "mm0", (41 + 0), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 0*16, .fpr, .vector },
  {.mm1,  "mm1", (41 + 1), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 1*16, .fpr, .vector },
  {.mm2,  "mm2", (41 + 2), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 2*16, .fpr, .vector },
  {.mm3,  "mm3", (41 + 3), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 3*16, .fpr, .vector },

  {.mm4,  "mm4", (41 + 4), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 4*16, .fpr, .vector },
  {.mm5,  "mm5", (41 + 5), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 5*16, .fpr, .vector },
  {.mm6,  "mm6", (41 + 6), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 6*16, .fpr, .vector },
  {.mm7,  "mm7", (41 + 7), 8, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, st_space)) + 7*16, .fpr, .vector },

  //use these to replace xmm registers
  // .xmm\1 = { "xmm\1", (17 + \1), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + \1*16, .fpr, .vector },
  {.xmm0,  "xmm0", (17 + 0), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 0*16, .fpr, .vector },
  {.xmm1,  "xmm1", (17 + 1), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 1*16, .fpr, .vector },
  {.xmm2,  "xmm2", (17 + 2), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 2*16, .fpr, .vector },
  {.xmm3,  "xmm3", (17 + 3), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 3*16, .fpr, .vector },

  {.xmm4,  "xmm4", (17 + 4), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 4*16, .fpr, .vector },
  {.xmm5,  "xmm5", (17 + 5), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 5*16, .fpr, .vector },
  {.xmm6,  "xmm6", (17 + 6), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 6*16, .fpr, .vector },
  {.xmm7,  "xmm7", (17 + 7), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 7*16, .fpr, .vector },

  {.xmm8,  "xmm8", (17 + 8), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 8*16, .fpr, .vector },
  {.xmm9,  "xmm9", (17 + 9), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 9*16, .fpr, .vector },
  {.xmm10,  "xmm10", (17 + 10), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 10*16, .fpr, .vector },
  {.xmm11,  "xmm11", (17 + 11), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 11*16, .fpr, .vector },

  {.xmm12,  "xmm12", (17 + 12), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 12*16, .fpr, .vector },
  {.xmm13,  "xmm13", (17 + 13), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 13*16, .fpr, .vector },
  {.xmm14,  "xmm14", (17 + 14), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 14*16, .fpr, .vector },
  {.xmm15,  "xmm15", (17 + 15), 16, (offset_of(user, i387) + offset_of(linux.User_FP_Regs, xmm_space)) + 15*16, .fpr, .vector },
}

register_info_by_id :: proc(id: reg) -> reg_info {
  val: reg_info
  for r in g_register_info {
    if r.id == id {
      val = r
    }
  }
  return val
}

register_info_by_name :: proc(name: string) -> reg_info {
  val: reg_info
  for r in g_register_info {
    if r.name == name {
      val = r
    }
  }
  return val
}

register_info_by_dwarf :: proc(dwarf_id: int) -> reg_info {
  val: reg_info
  for r in g_register_info {
    if r.dwarf_r == dwarf_id {
      val = r
    }
  }
  return val
}
