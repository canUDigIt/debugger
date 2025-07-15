package odb

import "core:c/libc"
import "core:encoding/endian"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"

process :: struct {
  id: posix.pid_t,
  state: process_state,
  term_on_end: bool,
  attached: bool,
  data: user,
}

process_state :: enum {
  stopped,
  running,
  exited,
  terminated,
}

process_error :: enum {
  None,
  Fork_Failed,
  Child_Failed,
  Zero_Pid,
  Attach_Failed,
  Resume_Failed,
}

exit_with_error :: proc(p: ^pipe, prefix: string) {
  message := fmt.aprintf("%s: %s", prefix, libc.strerror(libc.errno()^))
  pipe_write(p^, transmute([]u8)message)
  delete(message)
  posix.exit(libc.EXIT_FAILURE)
}

launch :: proc(path: string, debug: bool = true, stdout_replacement: Maybe(posix.FD) = nil) -> (process, process_error) {
  channel: pipe
  pipe_create(&channel, true)
  defer pipe_destroy(&channel)

  pid := posix.fork()
  switch pid {
  case -1: 
    return {}, .Fork_Failed
  case 0:
    // child process
    pipe_close_read(&channel)

    if stdout_replacement != nil {
      stdout_fd := stdout_replacement.(posix.FD)
      if posix.dup2(stdout_fd, posix.STDOUT_FILENO) < 0 {
        exit_with_error(&channel, "stdout replacement failed")
      }
      posix.close(stdout_fd)
    }

    if debug && linux.ptrace_traceme(.TRACEME) != .NONE {
      exit_with_error(&channel, "Tracing failed")
    }

    defer pipe_close_write(&channel)

    cpath := strings.unsafe_string_to_cstring(path)
    if posix.execlp(cpath, cpath, cstring(nil)) < 0 {
      exit_with_error(&channel, "exec failed")
    }
  case:
    // parent process
    pipe_close_write(&channel)
    data := pipe_read(channel)
    defer delete(data)
    pipe_close_read(&channel)

    if len(data) > 0 {
      posix.waitpid(pid, nil, nil)
      fmt.eprintln(string(data))
      return {}, .Child_Failed
    }
  }

  p := process {
    id = pid,
    term_on_end = true,
    attached = debug,
  }

  if debug {
    wait_on_signal(&p)
  }

  return p, .None
}

attach :: proc(pid: posix.pid_t) -> (process, process_error) {
  if pid == 0 {
    return {}, .Zero_Pid
  }

  if err := linux.ptrace_attach(.ATTACH, linux.Pid(pid)); err != .NONE {
    fmt.eprintln("Couldn't attach", err)
    return {}, .Attach_Failed
  }

  p := process {
    id = pid,
    term_on_end = false,
    attached = true,
  }
  wait_on_signal(&p)

  return p, .None
}

stop_process :: proc(p: process) {
  if p.id != 0 {
    status: i32
    if p.attached {
      if p.state == .running {
        posix.kill(p.id, .SIGSTOP)
        posix.waitpid(p.id, &status, nil)
      }

      linux.ptrace_detach(.DETACH, linux.Pid(p.id), .SIGCONT)
      posix.kill(p.id, .SIGCONT)
    }

    if p.term_on_end {
      posix.kill(p.id, .SIGKILL)
      posix.waitpid(p.id, &status, nil)
    }
  }
}

resume :: proc(p: ^process) -> process_error {
  if err := linux.ptrace_cont(.CONT, linux.Pid(p.id), .SIGCONT); err != nil {
    fmt.eprintln("Couldn't resume", err)
    return .Resume_Failed
  }
  p.state = .running

  return .None
}

wait_on_signal :: proc(p: ^process) -> stop_reason {
  status: i32
  if posix.waitpid(p.id, &status, nil) == -1 {
    fmt.eprintln("waitpid failed")
    return {}
  }

  reason := interpret_wait_status(status)
  p.state = reason.reason

  return reason
}

stop_reason :: struct {
  reason: process_state,
  info: i32
}

interpret_wait_status :: proc(wait_status: i32) -> stop_reason {
  r: stop_reason

  switch {
  case posix.WIFEXITED(wait_status):
    r.reason = .exited
    r.info = posix.WEXITSTATUS(wait_status)
  case posix.WIFSIGNALED(wait_status):
    r.reason = .terminated
    r.info = i32(posix.WTERMSIG(wait_status))
  case posix.WIFSTOPPED(wait_status):
    r.reason = .stopped
    r.info = i32(posix.WSTOPSIG(wait_status))
  }

  return r
}

write_user_area :: proc(p: ^process, offset: uintptr, data: uint) {
  err := linux.ptrace_poke(.POKEUSER, linux.Pid(p.id), offset, data)
  if err != .NONE {
    buf: [1024]u8
    msg := fmt.bprintfln(buf[:], "Couldn't write to user area: %v", err)
    panic(msg)
  }
}

write_fprs :: proc(p: ^process, float_val: f64) {
  // Size of the XSAVE area (contains extended state including XMM registers)
  XSAVE_AREA_SIZE :: 4096
  // Offset of XMM0 register within the XSAVE area
  XMM0_OFFSET :: 160
  // Size of XMM register in bytes
  XMM_SIZE :: 16
  // Buffer to hold the XSAVE area data
  xsave_area: [XSAVE_AREA_SIZE]u8
  // I/O vector structure for ptrace system calls
  iov := linux.IO_Vec {
    base = &xsave_area,
    len = XSAVE_AREA_SIZE,
  }

  // Read the current extended state (including XMM registers) from the process
  trace_err := linux.ptrace_getregset(.GETREGSET, linux.Pid(p.id), .NT_X86_XSTATE, &iov)
  if trace_err != .NONE {
    fmt.panicf("Couldn't get floating point registers: %v", trace_err)
  }

  // Get a slice pointing to the XMM0 register
  xmm0_slice := xsave_area[XMM0_OFFSET:][:XMM_SIZE]
  // Clear the XMM0 register data
  mem.zero_slice(xmm0_slice)
  // Copy our float value into the XMM0 register location
  // TODO(tracy): Is 32bit needed because of how I wrote the assembly...converting from 32bit to 64bit?
  if ok := endian.put_f64(xmm0_slice, .Little, float_val); !ok {
    panic("failed to write to floating point register")
  }

  // Write the modified extended state back to the process
  trace_err = linux.ptrace_setregset(.SETREGSET, linux.Pid(p.id), .NT_X86_XSTATE, &iov)
  if trace_err != .NONE {
    fmt.panicf("Couldn't write floating point registers: %v", trace_err)
  }
}

write_fpu_regs :: proc(p: ^process, info: reg_info, value: $T) {
  // Get the current FPU register set using traditional ptrace calls
  fpu_regs: linux.User_FP_Regs
  
  // Read the current FPU state
  trace_err := linux.ptrace_getfpregs(.GETFPREGS, linux.Pid(p.id), &fpu_regs)
  if trace_err != .NONE {
    fmt.panicf("Couldn't get FPU registers: %v", trace_err)
  }

  // Handle different register types
  if info.format == .long_double {
    // ST registers - convert value to 80-bit extended precision format
    fpu_bytes := mem.any_to_bytes(fpu_regs)
    reg_offset := info.offset - offset_of(user, i387)
    
    // Clear the target register space (16 bytes)
    reg_slice := fpu_bytes[reg_offset:][:16]
    mem.zero_slice(reg_slice)
    
    // Convert f64 to 80-bit extended precision IEEE 754 format
    float_val := f64(value)
    
    // Handle special cases
    if float_val == 0.0 {
      // Zero is represented as all zeros
      return
    }
    
    // Extract sign, exponent, and mantissa from f64
    f64_bits := transmute(u64)float_val
    f64_sign := (f64_bits >> 63) & 1
    f64_exp := (f64_bits >> 52) & 0x7FF
    f64_mantissa := f64_bits & 0xFFFFFFFFFFFFF
    
    // Handle special f64 values
    if f64_exp == 0x7FF {
      // Infinity or NaN
      if f64_mantissa == 0 {
        // Infinity: set exp to 0x7FFF, mantissa to 0x8000000000000000
        exp_sign := u16((u16(f64_sign) << 15) | 0x7FFF)
        endian.put_u64(reg_slice[0:8], .Little, 0x8000000000000000)
        endian.put_u16(reg_slice[8:10], .Little, exp_sign)
      } else {
        // NaN: set exp to 0x7FFF, mantissa with bit 63 set + original mantissa
        exp_sign := u16((u16(f64_sign) << 15) | 0x7FFF)
        extended_mantissa := 0x8000000000000000 | (f64_mantissa << 11)
        endian.put_u64(reg_slice[0:8], .Little, extended_mantissa)
        endian.put_u16(reg_slice[8:10], .Little, exp_sign)
      }
      return
    }
    
    // Normal and denormal numbers
    if f64_exp == 0 {
      // f64 denormal - convert to extended precision denormal
      // Find the leading 1 bit in the mantissa
      if f64_mantissa == 0 {
        return // Already handled zero case above
      }
      
      // Normalize the denormal number
      shift := 0
      temp_mantissa := f64_mantissa
      for (temp_mantissa & 0x10000000000000) == 0 {
        temp_mantissa <<= 1
        shift += 1
      }
      
      // Calculate the extended precision exponent
      // f64 denormal exponent is -1022, adjusted for the normalization shift
      extended_exp := 16383 - 1022 - shift
      
      if extended_exp <= 0 {
        // Result would be denormal in extended precision too
        // For simplicity, we'll set it to zero
        return
      }
      
      // Set the mantissa (remove the implicit leading 1, then shift to 64-bit)
      extended_mantissa := (temp_mantissa & 0xFFFFFFFFFFFFF) << 11
      extended_mantissa |= 0x8000000000000000 // Set the explicit leading 1 bit
      
      exp_sign := u16((u16(f64_sign) << 15) | u16(extended_exp))
      endian.put_u64(reg_slice[0:8], .Little, extended_mantissa)
      endian.put_u16(reg_slice[8:10], .Little, exp_sign)
    } else {
      // f64 normal number
      // Convert exponent: f64 bias is 1023, extended precision bias is 16383
      extended_exp := int(f64_exp) - 1023 + 16383
      
      // Check for overflow/underflow
      if extended_exp >= 32767 {
        // Overflow to infinity
        exp_sign := u16((u16(f64_sign) << 15) | 0x7FFF)
        endian.put_u64(reg_slice[0:8], .Little, 0x8000000000000000)
        endian.put_u16(reg_slice[8:10], .Little, exp_sign)
        return
      }
      
      if extended_exp <= 0 {
        // Underflow to zero or denormal
        return
      }
      
      // Convert mantissa: f64 has 52 bits, extended has 64 bits (with explicit leading 1)
      // Shift f64 mantissa left by 11 bits and set the explicit leading 1 bit
      extended_mantissa := (f64_mantissa << 11) | 0x8000000000000000
      
      exp_sign := u16((u16(f64_sign) << 15) | u16(extended_exp))
      endian.put_u64(reg_slice[0:8], .Little, extended_mantissa)
      endian.put_u16(reg_slice[8:10], .Little, exp_sign)
    }
  } else if info.format == .uint {
    // FPU control registers (fcw, fsw, ftw, etc.)
    fpu_bytes := mem.any_to_bytes(fpu_regs)
    reg_offset := info.offset - offset_of(user, i387)
    
    // Write the value to the appropriate offset
    if size_of(value) <= info.size {
      val_bytes := mem.any_to_bytes(value)
      reg_slice := fpu_bytes[reg_offset:][:info.size]
      copy(reg_slice, val_bytes[:info.size])
    } else {
      panic("register_write called with mismatched register and value sizes")
    }
  }

  // Write the modified FPU state back to the process
  trace_err = linux.ptrace_setfpregs(.SETFPREGS, linux.Pid(p.id), &fpu_regs)
  if trace_err != .NONE {
    fmt.panicf("Couldn't write FPU registers: %v", trace_err)
  }
}

write_gprs :: proc(p: ^process, gprs: ^linux.User_Regs) {
  err := linux.ptrace_setregs(.SETREGS, linux.Pid(p.id), gprs)
  if err != .NONE {
    buf: [1024]u8
    msg := fmt.bprintfln(buf[:], "Couldn't write to general registers: %v", err)
    panic(msg)
  }
}
