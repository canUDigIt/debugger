package odb

import c "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"

history_entry :: struct {
  line: cstring,
  timestamp: cstring,
  data: rawptr
}
foreign import libedit "system:libedit.so"
foreign libedit {
  readline :: proc "c" (prompt: cstring) -> [^]u8 ---
  add_history :: proc "c" (line: cstring) -> c.int ---
  history_list :: proc "c" () -> [^]^history_entry ---
  history_length: c.int
}

main :: proc() {
  if len(os.args) < 2 {
    fmt.eprintln("Pass in a program to debug.")
    posix.exit(1)
  }

  p := handle_args(os.args[:])
  defer stop_process(p)

  main_loop(&p)
}

main_loop :: proc(p: ^process) {
  for {
    line := readline("odb> ")
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
      handle_command(p, string(line_str))
    }
  }
}

handle_args :: proc(args: []string) -> process {
  if len(args) == 3 && args[1] == "-p" {
    // Passed in PID
    id, ok := strconv.parse_int(args[2])
    if !ok {
      fmt.eprintln("Invalid pid")
      return {}
    }

    return attach(posix.pid_t(id)) or_else process{}
  } else {
    // Passed in program name
    process, err := launch(args[1])
    if err != .None {
      fmt.eprintln("Failed to launch ", args[1], err)
      return {}
    }
    return process
  }
}

handle_command :: proc(p: ^process, line: string) {
  args := strings.split(line, " ")
  cmd := args[0]

  if strings.has_prefix("continue", cmd) {
    resume(p)
    reason := wait_on_signal(p)
    print_stop_reason(p^, reason)
  } else {
    fmt.eprintln("Unknown command")
  }
}

print_stop_reason :: proc(p: process, r: stop_reason) {
  switch r.reason {
    case .exited:
      fmt.eprintfln("Process %v exited with status %v", p.id, r.info)
    case .terminated:
      fmt.eprintfln("Process %v terminated with signal %v", p.id, r.info)
    case .stopped:
      fmt.eprintfln("Process %v stopped with signal %v", p.id, r.info)
    case .running:
      fmt.eprintfln("Printing stop reason for running process %v", p.id)
  }
}
