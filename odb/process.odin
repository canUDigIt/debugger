package odb

import "core:c/libc"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"

process :: struct {
  id: posix.pid_t,
  term_on_end: bool,
  state: process_state,
}

process_state :: enum {
  stopped,
  running,
  exited,
  terminated,
}

exit_with_error :: proc(p: ^pipe, prefix: string) {
  message := fmt.aprintf("%s: %s", prefix, libc.strerror(libc.errno()^))
  pipe_write(p^, transmute([]u8)message)
  posix.exit(libc.EXIT_FAILURE)
}

launch :: proc(path: string) -> process {
  channel: pipe
  pipe_create(&channel, true)

  pid := posix.fork()
  switch pid {
  case -1: 
    log.error("Fork failed.")
    posix.exit(libc.EXIT_FAILURE)
  case 0:
    // child process
    pipe_close_read(&channel)

    if err := linux.ptrace_traceme(.TRACEME); err != .NONE {
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
    pipe_close_read(&channel)

    if len(data) > 0 {
      posix.waitpid(pid, nil, nil)
      log.error(string(data))
      posix.exit(libc.EXIT_FAILURE)
    }
  }

  p := process {
    id = pid,
    term_on_end = true,
  }
  wait_on_signal(&p)

  return p
}

attach :: proc(pid: posix.pid_t) -> process {
  if pid == 0 {
    log.error("Zero is not a valid PID to attach to.")
    return {}
  }

  if err := linux.ptrace_attach(.ATTACH, linux.Pid(pid)); err != .NONE {
    log.error("Couldn't attach", err)
    return {}
  }

  p := process {
    id = pid,
    term_on_end = false,
  }
  wait_on_signal(&p)

  return p
}

stop_process :: proc(p: process) {
  if p.id != 0 {
    status: i32
    if p.state == .running {
      posix.kill(p.id, .SIGSTOP)
      posix.waitpid(p.id, &status, nil)
    }

    linux.ptrace_detach(.DETACH, linux.Pid(p.id), .SIGCONT)
    posix.kill(p.id, .SIGCONT)

    if p.term_on_end {
      posix.kill(p.id, .SIGKILL)
      posix.waitpid(p.id, &status, nil)
    }
  }
}

resume :: proc(p: ^process) {
  if err := linux.ptrace_cont(.CONT, linux.Pid(p.id), .SIGCONT); err != nil {
    log.error("Couldn't resume")
    return
  }
  p.state = .running
}

wait_on_signal :: proc(p: ^process) -> stop_reason {
  status: i32
  if posix.waitpid(p.id, &status, nil) == -1 {
    log.error("waitpid failed")
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
