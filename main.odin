package debugger

import c "core:c/libc"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/linux"
import "./bdb"

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
    linux.exit(1)
  }

  p := attach(os.args[:])
  main_loop(&p)
}

main_loop :: proc(p: ^bdb.process) {
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
      handle_command(p, string(line_str))
    }
  }
}

attach :: proc(args: []string) -> bdb.process {
  pid: linux.Pid = 0
  if len(args) == 3 && args[1] == "-p" {
    // Passed in PID
    id, ok := strconv.parse_int(args[2])
    if !ok {
      log.error("Invalid pid")
      return {}
    }
    pid = linux.Pid(id)

    return bdb.attach(pid)
  } else {
    // Passed in program name
    return bdb.launch(args[1])
  }
}

handle_command :: proc(p: ^bdb.process, line: string) {
  args := strings.split(line, " ")
  cmd := args[0]

  if strings.has_prefix(cmd, "continue") {
    bdb.resume(p)
    reason := bdb.wait_on_signal(p)
    print_stop_reason(p^, reason)
  } else {
    log.error("Unknown command")
  }
}

print_stop_reason :: proc(p: bdb.process, r: bdb.stop_reason) {
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
