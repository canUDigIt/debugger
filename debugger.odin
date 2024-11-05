package debugger

import "core:os"
import "core:fmt"
import "core:sys/linux"
import "core:strings"
import "core:strconv"

debug_context :: struct {
  prog: cstring,
  pid: linux.Pid,
  breakpoints: map[uintptr]breakpoint,
}

debugger_run :: proc(d: ^debug_context) {
  wait_status: u32
  rusage: linux.RUsage
  linux.waitpid(d.pid, &wait_status, nil, &rusage)
  
  for {
    buf := linenoise("minigdb> ")
    if buf == nil {
      break
    }

    line := cstring(buf)
    debugger_handle_command(d,line)
    linenoiseHistoryAdd(line)
    linenoiseFree(buf)
  }
}

debugger_handle_command :: proc(d: ^debug_context, line: cstring) {
  args := strings.split(string(line), " ")
  command := args[0]

  switch {
  case strings.has_prefix(command, "continue"):
    debugger_continue_execution(d)
  case strings.has_prefix(command, "break"):
    // TODO(tracy): What if someone just types break? Handle that case
    if len(args) < 2 {
      fmt.println("break command needs an address")
      return
    }

    if addr, ok := strconv.parse_uint(args[1], 16); ok { 
      debugger_set_breakpoint_at_address(d, uintptr(addr))
    } else {
      fmt.printfln("Failed to parse %s got 0x%x", args[1], addr)
    }
  case:
    fmt.printf("Unknown command\n")
  }
}

debugger_continue_execution :: proc(d: ^debug_context) {
  linux.ptrace_cont(.CONT, d.pid, .SIGCONT)

  wait_status: u32
  rusage: linux.RUsage
  linux.waitpid(d.pid, &wait_status, nil, &rusage)
}

debugger_set_breakpoint_at_address :: proc(d: ^debug_context, addr: uintptr) {
  fmt.printf("Set breakpoint at address 0x%x\n", addr)
  bp: breakpoint = {d.pid, addr, false, 0}
  breakpoint_enable(&bp)
  d.breakpoints[addr] = bp
}

debugger_dump_registers :: proc(d: ^debug_context) {
  for reg in Reg {
    desc := g_register_descriptors[reg]
    fmt.printfln("%s 0x%x", desc.name, register_get_register_value(d.pid, reg))
  }
}
