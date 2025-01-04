package odb

import "core:fmt"
import "core:sys/posix"
import "core:testing"

@(test)
process_launch_success :: proc(t: ^testing.T) {
  p := launch("/home/tracyb/workspaces/debugger/test")
  defer stop_process(p)
  testing.expect(t, process_exists(p.id))
}

process_exists :: proc(pid: posix.pid_t) -> bool {
  ret := posix.kill(pid, .NONE)
  return ret == .OK
}

@(test)
process_launch_no_such_program :: proc(t: ^testing.T) {
  // p := launch("you_do_not_have_to_be_good")
}
