package debugger

import "core:sys/linux"

breakpoint :: struct {
  pid: linux.Pid,
  addr: uintptr,
  enabled: bool, 
  saved_data: u8,
}

breakpoint_enable :: proc(b: ^breakpoint) {
  data, peek_err := linux.ptrace_peek(.PEEKDATA, b.pid, b.addr)
  b.saved_data = u8(data & 0xff)
  int3: uint = 0xcc
  data_with_int3 := ((data & ~uint(0xff)) | int3)
  linux.ptrace_poke(.POKEDATA, b.pid, b.addr, data_with_int3)
  b.enabled = true
}

breakpoint_disable :: proc(b: ^breakpoint) {
  data, peek_err := linux.ptrace_peek(.PEEKDATA, b.pid, b.addr)
  restored_data := ((data & ~uint(0xff)) | uint(b.saved_data))
  linux.ptrace_poke(.POKEDATA, b.pid, b.addr, restored_data)
  b.enabled = false
}
