package debugger

import c "core:c/libc"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/linux"

history_entry :: struct {
  line: cstring,
  data: rawptr
}
foreign import libedit "system:libedit.so"
foreign libedit {
  readline :: proc "c" (prompt: cstring) -> [^]u8 ---
  add_history :: proc "c" (line: cstring) -> c.int ---
  history_list :: proc "c" () -> [^]^history_entry ---
  history_length: c.int
}

attach :: proc(args: []string) -> linux.Pid {
  pid: linux.Pid = 0
  if len(args) == 3 && args[1] == "-p" {
    // Passed in PID
    id, ok := strconv.parse_int(args[2])
    if !ok {
      log.error("Invalid pid")
      return -1
    }
    pid = linux.Pid(id)

    if err := linux.ptrace_attach(.ATTACH, pid); err != .NONE {
      log.error("Couldn't attach", err)
      return -1
    }

  } else {
    // Passed in program name
    if id, err := linux.fork(); err == .NONE {
      switch id {
      case -1:
        log.error("Fork failed with error:", err)
        return -1
      case 0:
        // We're in the child process
        // Execute debuggee

        if err := linux.ptrace_traceme(.TRACEME); err != .NONE {
          log.error("Tracing failed", err)
          return -1
        }

        cargs := []cstring{strings.unsafe_string_to_cstring(args[1]), nil}
        if err := linux.execve(cargs[0], raw_data(cargs[1:]), nil); err != .NONE {
          log.error("Exec failed", err)
          return -1
        }
      case:
        pid = id
      }
    } else {
      log.error("Fork failed with error:", err)
    }
  }
  return pid
}

handle_command :: proc(pid: linux.Pid, line: string) {
  args := strings.split(line, " ")
  cmd := args[0]

  if strings.has_prefix(cmd, "continue") {
    resume(pid)
    wait_on_signal(pid)
  } else {
    log.error("Unknown command")
  }
}

resume :: proc(pid: linux.Pid) {
  if err := linux.ptrace_cont(.CONT, pid, .SIGCONT); err != .NONE {
    log.error("Couldn't continue")
    linux.exit(1)
  }
}
wait_on_signal :: proc(pid: linux.Pid) {
  wait_status: u32
  options: linux.Wait_Options
  rusage: linux.RUsage
  if _, err := linux.waitpid(pid, &wait_status, options, &rusage); err != .NONE {
    log.error("waitpid failed", err)
    linux.exit(1)
  }
}

main :: proc() {
  context.logger = log.create_console_logger()

  if len(os.args) < 2 {
    log.error("Pass in a program to debug.")
    linux.exit(1)
  }

  pid := attach(os.args[:])

  wait_status: u32
  options: linux.Wait_Options
  rusage: linux.RUsage
  if _, err := linux.waitpid(pid, &wait_status, options, &rusage); err != .NONE {
    log.error("waitpid failed", err)
  }
  
  for {
    line := readline("bdb> ")
    if line == nil {
      break
    }
    defer c.free(line)

    line_str := cstring(line)

    if line_str == "" {
      if history_length > 0 {
        line_str = cstring(history_list()[history_length - 1].line)
      }
    } else {
      add_history(line_str)
    }

    if line_str != "" {
      handle_command(pid, string(line_str))
    }
  }
}
