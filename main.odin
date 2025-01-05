package debugger

import c "core:c/libc"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/posix"
import "./odb"

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

main :: proc() {
  context.logger = log.create_console_logger()

  if len(os.args) < 2 {
    log.error("Pass in a program to debug.")
    posix.exit(1)
  }

  p := attach(os.args[:])
  defer odb.stop_process(p)

  main_loop(&p)
}

main_loop :: proc(p: ^odb.process) {
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

attach :: proc(args: []string) -> odb.process {
  if len(args) == 3 && args[1] == "-p" {
    // Passed in PID
    id, ok := strconv.parse_int(args[2])
    if !ok {
      log.error("Invalid pid")
      return {}
    }

    return odb.attach(posix.pid_t(id))
  } else {
    // Passed in program name
    process, err := odb.launch(args[1])
    if err != .None {
      log.error("Failed to launch ", args[1], err)
      return {}
    }
    return process
  }
}

handle_command :: proc(p: ^odb.process, line: string) {
  args := strings.split(line, " ")
  cmd := args[0]

  if strings.has_prefix(cmd, "continue") {
    odb.resume(p)
    reason := odb.wait_on_signal(p)
    print_stop_reason(p^, reason)
  } else {
    log.error("Unknown command")
  }
}

print_stop_reason :: proc(p: odb.process, r: odb.stop_reason) {
  switch r.reason {
    case .exited:
      log.infof("Process %v exited with status %v", p.id, r.info)
    case .terminated:
      log.infof("Process %v terminated with signal %v", p.id, r.info)
    case .stopped:
      log.infof("Process %v stopped with signal %v", p.id, r.info)
    case .running:
      log.errorf("Printing stop reason for running process %v", p.id)
  }
}
