package debugger

import "core:os"
import "core:fmt"
import "core:sys/linux"
import "core:strings"

foreign import liblinenoise "./liblinenoise.a"
foreign liblinenoise {
  linenoise :: proc(prompt: cstring) -> [^]u8 ---
  linenoiseHistoryAdd :: proc(line: cstring) -> i32 ---
  linenoiseFree :: proc(ptr: rawptr) ---
}

main :: proc() {
  if len(os.args) < 2 {
    fmt.printf("Program name not specified\n")
    linux.exit(1)
  }

  args := os.args[1:]

  cargs := make([]cstring, len(args))
  defer delete(cargs)

  for arg, i in args {
    cargs[i] = strings.unsafe_string_to_cstring(arg)
  }

  if pid, err := linux.fork(); err == .NONE {
    switch pid {
    case -1:
      linux.exit(1)
    case 0:
      linux.personality(linux.ADDR_NO_RANDOMIZE)
      linux.ptrace_traceme(.TRACEME)
      linux.execve(cargs[0], raw_data(cargs), nil)
    case:
      fmt.printf("Started debbuging process %d\n", pid)
      dbg := debug_context{cargs[0], pid, nil}
      debugger_run(&dbg)
    }
  } else {
    fmt.printfln("Fork failed with error: %s", err)
  }
}
