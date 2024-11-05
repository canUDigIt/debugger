package debugger

import "core:sys/linux"

Reg :: enum {
  rax, rbx, rcx, rdx,
  rdi, rsi, rbp, rsp,
  r8,  r9,  r10, r11,
  r12, r13, r14, r15,
  rip, eflags, cs,
  orig_rax, fs_base,
  gs_base,
  fs, gs, ss, ds, es,
}

reg_descriptor :: struct {
  dwarf_r: int,
  name: string,
}

g_register_descriptors := [Reg] reg_descriptor {
  .rax = {0, "rax"},
  .rbx = {3, "rbx"},
  .rcx = {2, "rcx"},
  .rdx = {1, "rdx"},
  .rdi = {5, "rdi"},
  .rsi = {4, "rsi"},
  .rbp = {6, "rbp"},
  .rsp = {7, "rsp"},
  .r8 = {8, "r8"},
  .r9 = {9, "r9"},
  .r10 = {10, "r10"},
  .r11 = {11, "r11"},
  .r12 = {12, "r12"},
  .r13 = {13, "r13"},
  .r14 = {14, "r14"},
  .r15 = {15, "r15"},
  .rip = {-1, "rip"},
  .eflags = {49, "eflags"},
  .cs = {51, "cs"},
  .orig_rax = {-1, "orig_rax"},
  .fs_base = {58, "fs_base"},
  .gs_base = {59, "gs_base"},
  .fs = {54, "fs"},
  .gs = {55, "gs"},
  .ss = {52, "ss"},
  .ds = {53, "ds"},
  .es = {50, "es"},
}

register_get_register_value :: proc(pid: linux.Pid, r: Reg) -> uint {
  regs: linux.User_Regs
  linux.ptrace_getregs(.GETREGS, pid, &regs)

  val: uint
  switch r {
    case .rax:
      val = regs.rax
    case .rbx:
      val = regs.rbx
    case .rcx:
      val = regs.rcx
    case .rdx:
      val = regs.rdx
    case .rdi:
      val = regs.rdi
    case .rsi:
      val = regs.rsi
    case .rbp:
      val = regs.rbp
    case .rsp:
      val = regs.rsp
    case .r8:
      val = regs.r8
    case .r9:
      val = regs.r9
    case .r10:
      val = regs.r10
    case .r11:
      val = regs.r11
    case .r12:
      val = regs.r12
    case .r13:
      val = regs.r13
    case .r14:
      val = regs.r14
    case .r15:
      val = regs.r15
    case .rip:
      val = regs.rip
    case .eflags:
      val = regs.eflags
    case .cs:
      val = regs.cs
    case .orig_rax:
      val = regs.orig_rax
    case .fs_base:
      val = regs.fs_base
    case .gs_base:
      val = regs.gs_base
    case .fs:
      val = regs.fs
    case .gs:
      val = regs.gs
    case .ss:
      val = regs.ss
    case .ds:
      val = regs.ds
    case .es:
      val = regs.es
  }
  return val
}

register_set_register_value :: proc(pid: linux.Pid, r: Reg, val: uint) {
  regs: linux.User_Regs
  linux.ptrace_getregs(.GETREGS, pid, &regs)

  switch r {
    case .rax:
      regs.rax = val
    case .rbx:
      regs.rbx = val
    case .rcx:
      regs.rcx = val
    case .rdx:
      regs.rdx = val
    case .rdi:
      regs.rdi = val
    case .rsi:
      regs.rsi = val
    case .rbp:
      regs.rbp = val
    case .rsp:
      regs.rsp = val
    case .r8:
      regs.r8 = val
    case .r9:
      regs.r9 = val
    case .r10:
      regs.r10 = val
    case .r11:
      regs.r11 = val
    case .r12:
      regs.r12 = val
    case .r13:
      regs.r13 = val
    case .r14:
      regs.r14 = val
    case .r15:
      regs.r15 = val
    case .rip:
      regs.rip = val
    case .eflags:
      regs.eflags = val
    case .cs:
      regs.cs = val
    case .orig_rax:
      regs.orig_rax = val
    case .fs_base:
      regs.fs_base = val
    case .gs_base:
      regs.gs_base = val
    case .fs:
      regs.fs = val
    case .gs:
      regs.gs = val
    case .ss:
      regs.ss = val
    case .ds:
      regs.ds = val
    case .es:
      regs.es = val
  }

  linux.ptrace_setregs(.SETREGS, pid, &regs)
}

RegisterError :: enum { None, InvalidRegisterNumber, InvalidRegisterName }

register_get_register_value_from_dwarf_register :: proc(pid: linux.Pid, regnum: uint) -> (uint, RegisterError) {
  for reg in Reg {
    if g_register_descriptors[reg].dwarf_r == int(regnum ) {
      return register_get_register_value(pid, reg), .None
    }
  }
  return 0, .InvalidRegisterNumber
}

register_get_register_name :: proc(reg: Reg) -> string {
  return g_register_descriptors[reg].name
}

register_get_register_from_name :: proc(name: string) -> (Reg, RegisterError) {
  for reg in Reg {
    if g_register_descriptors[reg].name == name {
      return reg, .None
    }
  }
  return nil, .InvalidRegisterName
}
