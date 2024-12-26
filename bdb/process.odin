package bdb

import "core:log"
import "core:strings"
import "core:sys/linux"

process :: struct {
  id: linux.Pid,
  term_on_end: bool,
  state: process_state,
}

process_state :: enum {
  stopped,
  running,
  exited,
  terminated,
}

launch :: proc(path: string) -> process {
  pid: linux.Pid
  err: linux.Errno
  if pid, err = linux.fork(); err != .NONE {
    log.error("Fork failed.", err)
  }

  if pid == 0 {
    if err = linux.ptrace_traceme(.TRACEME); err != .NONE {
      log.error("Tracing failed", err)
    }

    cargs := []cstring{strings.unsafe_string_to_cstring(path), nil}
    if err = linux.execve(cargs[0], raw_data(cargs[:]), nil); err != .NONE {
      log.error("Exec failed", err)
    }
  }

  p := process {
    id = pid,
    term_on_end = true,
  }
  wait_on_signal(&p)

  return p
}

attach :: proc(pid: linux.Pid) -> process {
  if pid == 0 {
    log.error("Zero is not a valid PID to attach to.")
  }

  if err := linux.ptrace_attach(.ATTACH, pid); err != .NONE {
    log.error("Couldn't attach", err)
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
    status: u32
    if p.state == .running {
      linux.kill(p.id, .SIGSTOP)
      linux.waitpid(p.id, &status, nil, nil)
    }

    linux.ptrace_detach(.DETACH, p.id, .SIGCONT)
    linux.kill(p.id, .SIGCONT)

    if p.term_on_end {
      linux.kill(p.id, .SIGKILL)
      linux.waitpid(p.id, &status, nil, nil)
    }
  }
}

resume :: proc(p: ^process) {
  if err := linux.ptrace_cont(.CONT, p.id, .SIGCONT); err != nil {
    log.error("Couldn't resume")
  }
  p.state = .running
}

wait_on_signal :: proc(p: ^process) -> stop_reason {
  status: u32
  if _, err := linux.waitpid(p.id, &status, nil, nil); err != nil {
    log.error("waitpid failed")
  }

  reason := interpret_wait_status(status)
  p.state = reason.reason
  return reason
}

stop_reason :: struct {
  reason: process_state,
  info: u32
}

interpret_wait_status :: proc(wait_status: u32) -> stop_reason {
  r: stop_reason

  switch {
  case linux.WIFEXITED(wait_status):
    r.reason = .exited
    r.info = linux.WEXITSTATUS(wait_status)
  case linux.WIFSIGNALED(wait_status):
    r.reason = .exited
    r.info = linux.WTERMSIG(wait_status)
  case linux.WIFSTOPPED(wait_status):
    r.reason = .exited
    r.info = linux.WSTOPSIG(wait_status)
  }

  return r
}
