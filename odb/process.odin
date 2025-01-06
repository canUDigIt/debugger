package odb

import "core:c/libc"
import "core:fmt"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"

process :: struct {
  id: posix.pid_t,
  state: process_state,
  term_on_end: bool,
  attached: bool,
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

launch :: proc(path: string, debug: bool = true) -> (process, process_error) {
  channel: pipe
  pipe_create(&channel, true)

  pid := posix.fork()
  switch pid {
  case -1: 
    return {}, .Fork_Failed
  case 0:
    // child process
    pipe_close_read(&channel)

    if debug && linux.ptrace_traceme(.TRACEME) != .NONE {
      exit_with_error(&channel, "Tracing failed")
    }

    cpath := strings.unsafe_string_to_cstring(path)
    if posix.execlp(cpath, cpath, cstring(nil)) < 0 {
      exit_with_error(&channel, "exec failed")
    }

    pipe_close_write(&channel)
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
    fmt.eprintln("Couldn't resume")
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
    r.reason = .exited
    r.info = i32(posix.WTERMSIG(wait_status))
  case posix.WIFSTOPPED(wait_status):
    r.reason = .exited
    r.info = i32(posix.WSTOPSIG(wait_status))
  }

  return r
}
