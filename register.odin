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
    // Get the user data as a byte slice
    user_bytes := mem.byte_slice(rawptr(&p.data), size_of(user))

    if size_of(value) <= info.size {
      // Convert value to bytes, expanding to u128 to handle all register sizes
      wide := u128(value)
      val_bytes := mem.any_to_bytes(wide)

      // Get the target slice for the register
      target_slice := user_bytes[info.offset:][:info.size]

      // Copy the value bytes to the target register location
      copy(target_slice, val_bytes[:info.size])
    } else {
      panic("register_write called with mismatched register and value sizes")
    }

    if commit {
      // Write the modified data back to the process
      aligned_offset := info.offset &~ 0b111
      aligned_slice := user_bytes[aligned_offset:][:8]  // 8 bytes for uint alignment
      aligned_value := mem.reinterpret_copy(uint, raw_data(aligned_slice))
      write_user_area(p, aligned_offset, aligned_value)
    }
  }
}
