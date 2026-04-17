;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; META.scm - Governance and design principles for bebop-ffi
;; Media-Type: application/meta+scheme

(meta
 (version 2)
 (note "Repo renamed bebop-v-ffi → bebop-ffi on 2026-04-17. Zig is canonical.")

 (architecture-decisions
  ((id zig-canonical)
   (status accepted)
   (date "2026-04-17")
   (statement "Zig replaces V as the canonical binding language")
   (rationale "V-lang banned estate-wide 2026-04-10 in favour of Zig. Zig produces C-compatible shared/static libraries natively, matches the ABI/FFI standard (Idris2 ABI + Zig FFI).")
   (consequences "V binding moved to v-ecosystem for donation; `_v_` in symbol/header names retained for ABI stability."))

  ((id abi-name-stability)
   (status accepted)
   (date "2026-04-17")
   (statement "Symbol names (bebop_ctx_new, etc.) and header name (bebop_v_ffi.h) are frozen")
   (rationale "Renaming would cascade breakage into volumod and any other consumer that already links against these symbols.")
   (consequences "`_v_` in names is historical, not current. New consumers should accept this."))

  ((id arena-allocator)
   (status accepted)
   (statement "All decode outputs are arena-owned; per-field frees are no-ops")
   (rationale "Eliminates bookkeeping overhead; simplifies V/Zig consumer code; matches IIoT high-throughput pattern."))

  ((id no-external-bebop-dep)
   (status accepted)
   (date "2026-04-17")
   (statement "Wire format is implemented directly in Zig; no external bebop C library required")
   (rationale "bebopc generates code but does not ship a C runtime library. The Bebop message wire format is simple enough to implement directly: 4-byte LE length prefix, repeated (field_index, data) pairs, 0x00 sentinel.")))

 (principles
  ((id no-stubs)
   (statement "No stubs, no TODOs in reachable code, no @panic as error handling"))
  ((id explicit-allocators)
   (statement "No hidden allocations in hot paths; all allocators passed explicitly"))
  ((id wire-everything)
   (statement "Consumers must link and run; undefined-reference build failures are blockers")))

 (allowed
  propose_architecture
  draft_docs
  suggest_api_shapes
  generate_examples
  explain_existing_code
  implement_zig_code)

 (forbidden
  direct_commits_without_review
  renaming_abi_symbols
  breaking_c_abi
  language_migration_back_to_V)

 (requires_human_review
  ffi_boundaries
  abi_headers
  build_scripts
  serialization_logic
  schema_changes
  security_sensitive_code))
