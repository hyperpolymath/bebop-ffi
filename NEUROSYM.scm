;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; NEUROSYM.scm - Neural-symbolic integration patterns for this repository

(neurosym
 (version 2)
 (project "bebop-ffi")
 (note "Repo renamed bebop-v-ffi → bebop-ffi on 2026-04-17. Zig canonical.")

 (reasoning-domains
  ((domain "abi-design")
   (type symbolic)
   (constraints
    "Struct layouts must match C ABI exactly (extern struct in Zig)"
    "Alignment rules are deterministic"
    "Ownership semantics are explicit: context owns all decode outputs")
   (tools "static-analysis" "zig-comptime-checks"))

  ((domain "wire-format")
   (type symbolic)
   (constraints
    "Bebop spec is authoritative (https://bebop.sh/reference/)"
    "message type: 4-byte LE body-length, repeated (u8 field-index, data), 0x00 sentinel"
    "string: 4-byte LE character count, then UTF-8 bytes"
    "map<K,V>: 4-byte LE entry count, then repeated (key, value) pairs"
    "Little-endian encoding throughout"
    "Field indices 1-based per Bebop message spec")
   (tools "golden-vectors" "round-trip-tests"))

  ((domain "implementation-patterns")
   (type hybrid)
   (neural-assists
    "Zig 0.15.2 idioms: ArrayListUnmanaged, std.mem.Allocator explicit passing"
    "Arena allocator patterns for high-throughput decode"
    "Error union handling at C ABI boundary")
   (symbolic-constraints
    "Must satisfy ABI contract (bebop_v_ffi.h)"
    "No callconv(.C) on export fn (Zig 0.15 uses export which implies C ABI)"
    "addLibrary API in Zig 0.15 build.zig (not addSharedLibrary)")))

 (verification-strategy
  (primary "unit-tests-in-bridge.zig")
  (secondary "volumod-test-ffi-integration")
  (aspirational "golden-vectors-with-bebopc"))

 (knowledge-sources
  ((source "bebop-spec")
   (type authoritative)
   (url "https://bebop.sh/reference/"))
  ((source "zig-0.15-stdlib")
   (type authoritative)
   (url "https://ziglang.org/documentation/0.15.2/"))
  ((source "zig-c-interop")
   (type authoritative)
   (url "https://ziglang.org/documentation/0.15.2/#C-Type-Primitives")))

 (invariants
  "VBytes uses ptr+len, never NUL-terminated"
  "Context owns all allocations from decode"
  "Decode outputs valid until ctx reset or free"
  "Encode returns bytes written or 0 on failure (never partial write)"
  "symbol names bebop_ctx_new/free/reset/etc. are frozen for ABI stability"))
