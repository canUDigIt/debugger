package odb

import "core:c/libc"
import "core:fmt"
import "core:strings"
import "core:sys/posix"
import "core:testing"

@(test)
process_launch_success :: proc(t: ^testing.T) {
  p, err := launch("./test")
  defer stop_process(p)

  testing.expect(t, err == .None)
  testing.expect(t, process_exists(p.id))
}

process_exists :: proc(pid: posix.pid_t) -> bool {
  ret := posix.kill(pid, .NONE)
  return ret == .OK
}

@(test)
process_launch_no_such_program :: proc(t: ^testing.T) {
  p, err := launch("you_do_not_have_to_be_good")
  testing.expect(t, err == .Child_Failed)
}

get_process_status :: proc(pid: posix.pid_t) -> u8 {
  buf: [128]u8
  filename := fmt.bprint(buf[:], "/proc", pid, "stat", sep = "/")
  file := libc.fopen(strings.unsafe_string_to_cstring(filename), "r")

  line: cstring
  length: uint
  read := posix.getline(&line, &length, file)
  index_of_last_parenthesis := strings.index(string(line), ")")
  index_of_status_indicator := index_of_last_parenthesis + 2
  return (transmute([^]u8)line)[index_of_status_indicator]
}

@(test)
process_attach_sucess :: proc(t: ^testing.T) {
  p, err := launch("./run_endlessly", false)
  defer stop_process(p)
  _, err = attach(p.id)
  testing.expect(t, get_process_status(p.id) == 't')
}

@(test)
process_attach_invalid_pid :: proc(t: ^testing.T) {
  p, err := attach(0)

  testing.expect(t, err == .Zero_Pid)
}

@(test)
process_resume_success :: proc(t: ^testing.T) {
  {
    p, err := launch("./run_endlessly")
    defer stop_process(p)

    resume(&p)

    status := get_process_status(p.id)
    success := status == 'R' || status == 'S'
    testing.expect(t, success)
  }

  {
    target, err := launch("./run_endlessly", false)
    defer stop_process(target)
    p, err_attach := attach(target.id)

    resume(&p)

    status := get_process_status(p.id)
    success := status == 'R' || status == 'S'
    testing.expect(t, success)
  }
}

@(test)
process_resume_alread_terminated :: proc(t: ^testing.T) {
  p, err := launch("./end_immediately")
  defer stop_process(p)

  resume(&p)
  wait_on_signal(&p)

  err_resume := resume(&p)
  testing.expect(t, err_resume == .Resume_Failed)
}
