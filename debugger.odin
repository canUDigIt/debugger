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
    defer linenoiseFree(buf)

    if strings.has_prefix(string(line), "quit") {
      break
    }

    debugger_handle_command(d,line)
    linenoiseHistoryAdd(line)
  }
}

debugger_handle_command :: proc(d: ^debug_context, line: cstring) {
  args := strings.fields(string(line))
  command := args[0]

  switch {
  case strings.has_prefix(command, "continue"):
    debugger_continue_execution(d)
  case strings.has_prefix(command, "break"):
    if len(args) < 2 {
      fmt.println("break command needs an address")
      return
    }
    if addr, ok := strconv.parse_uint(args[1]); ok { 
      debugger_set_breakpoint_at_address(d, uintptr(addr))
    } else {
      fmt.printfln("Failed to parse %s got 0x%x", args[1], addr)
    }

  case strings.has_prefix(command, "register"):
    if len(args) < 2 {
      fmt.println("register command needs an either dump, read, or write sub-command")
      return
    }

    switch {
    case strings.has_prefix(args[1], "dump"):
      debugger_dump_registers(d)

    case strings.has_prefix(args[1], "read"):
      if len(args) < 3 {
        fmt.println("register read command needs a register name to read")
        return
      }
      reg, err := register_get_register_from_name(args[2])
      if err == nil {
        fmt.println(register_get_register_value(d.pid, reg))
      } else {
        fmt.printfln("%s is not a register name", args[2])
      }

    case strings.has_prefix(args[1], "write"):
      if len(args) < 4 {
        fmt.println("register write command needs a register name and value to write")
        return
      }
      val, ok := strconv.parse_uint(args[3])
      if ok {
        reg, err := register_get_register_from_name(args[2])
        if err == nil {
          register_set_register_value(d.pid, reg, val)
        } else {
          fmt.println("%s is not a register name", args[2])
        }
      } else {
        fmt.printfln("write command requires a hexidecimal address.")
      }
    }

  case strings.has_prefix(command, "memory"):
    if len(args) < 2 {
      fmt.println("memory command needs sub commands read or write")
      return
    }
    switch {
    case strings.has_prefix(args[1], "read"):
      if len(args) < 3 {
        fmt.println("memory read command needs a memory address to read")
        return
      }
      addy, ok := strconv.parse_uint(args[2])
      if !ok {
        fmt.println("Failed to parse memory address")
        return
      }
      val, errno := debugger_read_memory(d, cast(u64)addy)
      fmt.printfln("%x", val)

    case strings.has_prefix(args[1], "write"):
      if len(args) < 4 {
        fmt.println("memory write needs a memory address and a value to write")
        return
      }
      addy, addy_ok := strconv.parse_uint(args[2])
      if !addy_ok {
        fmt.println("Failed to parse memory address")
        return
      }
      val, val_ok := strconv.parse_uint(args[3])
      if val_ok {
        debugger_write_memory(d, cast(u64)addy, cast(u64)val)
      } else {
        fmt.printfln("Failed to parse value to write to %x", addy)
      }
    }

  case:
    fmt.printf("Unknown command\n")
  }
}

debugger_continue_execution :: proc(d: ^debug_context) {
  debugger_step_over_breakpoint(d)
  linux.ptrace_cont(.CONT, d.pid, nil)
  debugger_wait_for_signal(d)
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

debugger_read_memory :: proc(d: ^debug_context, address: u64) -> (u64, linux.Errno) {
  val, errno := linux.ptrace_peek(.PEEKDATA, d.pid, cast(uintptr)address)
  return cast(u64)val, errno
}

debugger_write_memory :: proc(d: ^debug_context, address, value: u64) -> (linux.Errno) {
  errno := linux.ptrace_poke(.POKEDATA, d.pid, cast(uintptr)address, cast(uint)value)
  return errno
}

debugger_get_pc :: proc(d: ^debug_context) -> u64 {
  return cast(u64)register_get_register_value(d.pid, .rip)
}

debugger_set_pc :: proc(d: ^debug_context, pc: u64) {
  register_set_register_value(d.pid, .rip, cast(uint)pc)
}

debugger_wait_for_signal :: proc(d: ^debug_context) {
  wait_status: u32
  rusage: linux.RUsage
  linux.waitpid(d.pid, &wait_status, nil, &rusage)
}

debugger_step_over_breakpoint :: proc(d: ^debug_context) {
  possible_breakpoint: uintptr = uintptr(debugger_get_pc(d) - 1)

  if possible_breakpoint in d.breakpoints {
    bp := d.breakpoints[possible_breakpoint]
    if bp.enabled {
      previous_instruction_address := possible_breakpoint

      debugger_set_pc(d, cast(u64)previous_instruction_address)

      breakpoint_disable(&bp)
      linux.ptrace_singlestep(.SINGLESTEP, d.pid, nil)
      debugger_wait_for_signal(d)
      breakpoint_enable(&bp)
    }
  }
}
