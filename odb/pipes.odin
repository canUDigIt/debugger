package odb

import "core:fmt"
import "core:slice"
import "core:sys/posix"

pipe :: [2]posix.FD
read_fd :: 0
write_fd :: 1

pipe_create :: proc(p: ^pipe, close_on_exec: bool) {
  if posix.pipe(p) == .FAIL {
    fmt.eprintln("Failed to create pipe: ", posix.strerror(posix.errno()))
  }

  if close_on_exec {
    flags := posix.fcntl(p[read_fd], .GETFD)
    flags |= posix.FD_CLOEXEC
    posix.fcntl(p[read_fd], .SETFD, flags)

    flags = posix.fcntl(p[write_fd], .GETFD)
    flags |= posix.FD_CLOEXEC
    posix.fcntl(p[write_fd], .SETFD, flags)
  }
}

pipe_destroy :: proc(p: ^pipe) {
  pipe_close_read(p)
  pipe_close_write(p)
}

pipe_close_read :: proc(p: ^pipe) {
  if p[read_fd] != -1 {
    posix.close(p[read_fd])
    p[read_fd] = -1
  }
}

pipe_close_write :: proc(p: ^pipe) {
  if p[write_fd] != -1 {
    posix.close(p[write_fd])
    p[write_fd] = -1
  }
}

pipe_release_read :: proc(p: ^pipe) -> posix.FD {
  tmp := p[read_fd]
  p[read_fd] = -1
  return tmp
}

pipe_release_write :: proc(p: ^pipe) -> posix.FD {
  tmp := p[write_fd]
  p[write_fd] = -1
  return tmp
}

pipe_read :: proc(p: pipe) -> []u8 {
  buf_size :: 1024
  buf: [buf_size]u8
  chars_read: int
  if chars_read = posix.read(p[read_fd], raw_data(buf[:]), buf_size); chars_read < 0 {
    panic("Could not read from pipe")
  }
  return slice.clone(buf[:chars_read])
}

pipe_write :: proc(p: pipe, data: []u8) {
  if posix.write(p[write_fd], raw_data(data), len(data)) < 0 {
    panic("Could not write to pipe")
  }
}
