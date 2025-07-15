package odb

import "core:mem"

register_write_by_id :: proc(p: ^process, id: reg, value: $T) {
  register_write(p, register_info_by_id(id), value)
}

register_write :: proc(p: ^process, info: reg_info, value: $T, commit: bool = true) {
  if info.type == .fpr {
    if commit {
      // Differentiate between XMM registers and x87 FPU registers
      if info.format == .vector && info.id == .xmm0 {
        // XMM registers - use existing write_fprs function
        write_fprs(p, cast(f64)value)
      } else if info.format == .long_double || info.format == .uint {
        // ST registers and FPU control registers - use new write_fpu_regs function
        write_fpu_regs(p, info, value)
      } else {
        panic("Unsupported FPU register format")
      }
    }
  } else {
    bytes := mem.byte_slice(rawptr(&p.data), size_of(user))
    data_ptr: [^]byte = &bytes[0]

    if size_of(value) <= info.size {
      wide := u128(value)
      val_bytes := mem.any_to_bytes(wide)
      val_ptr: [^]byte = &val_bytes[0]
      mem.copy(&data_ptr[info.offset], val_ptr, int(info.size))
    } else {
      panic("register_write called with mismatched register and value sizes")
    }

    if commit {
      aligned_offset := info.offset &~ 0b111
      write_user_area(p, aligned_offset, mem.reinterpret_copy(uint, &data_ptr[aligned_offset]))
    }
  }
}
