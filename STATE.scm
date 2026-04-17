;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; STATE.scm - Current project state and progress tracking
;;
;; NOTE: This file uses .scm extension for historical reasons. The estate-wide
;; migration to .a2ml is ongoing; this file will be migrated in a future pass.

(state
 (metadata
  (version 1)
  (schema-version "0.0.2")
  (created "2025-12-24")
  (updated "2026-04-17")
  (project "bebop-ffi")
  (repo "github.com/hyperpolymath/bebop-ffi")
  (note "Repo renamed from bebop-v-ffi on 2026-04-17. GitHub remote rename pending (user action)."))

 (project-context
  (name "Bebop-FFI")
  (tagline "Stable C ABI for Bebop binary serialization — Zig canonical implementation")
  (tech-stack Zig C Bebop)
  (note "V-lang banned estate-wide 2026-04-10. V binding moved to v-ecosystem/v-api-interfaces/v-bebop/ for donation to V community."))

 (current-position
  (phase "zig-canonical")
  (overall-completion 60)
  (version "0.1.0")
  (components
   ((name "ABI header")
    (status complete)
    (file "include/bebop_v_ffi.h"))
   ((name "Zig build system")
    (status complete)
    (file "implementations/zig/build.zig")
    (note "Zig 0.15.2 idioms; addLibrary API"))
   ((name "Zig implementation")
    (status complete)
    (file "implementations/zig/src/bridge.zig")
    (note "Full Bebop message-format decode + encode. Arena allocator. 9 tests pass."))
   ((name "V binding (moved)")
    (status removed)
    (note "Moved to developer-ecosystem/v-ecosystem/v-api-interfaces/v-bebop/ on 2026-04-17"))
   ((name "Rust implementation")
    (status help-wanted)
    (file "implementations/rust/"))
   ((name "Schema")
    (status complete)
    (file "schemas/sensors.bop"))
   ((name "Documentation")
    (status updated-2026-04-17)
    (files "docs/*.adoc" "README.adoc" "ROADMAP.adoc")
    (note "Docs still reference V in narrative; _v_ in symbol names retained for ABI stability"))
   ((name "Golden vectors")
    (status placeholder)
    (file "test-vectors/sensor_reading_001.json")
    (note "wire_bytes_hex still TODO — need bebopc to generate canonical bytes"))))

 (working-features
  "ABI contract (bebop_v_ffi.h)"
  "Context lifecycle (new/reset/free)"
  "bebop_decode_sensor_reading — full Bebop message wire format"
  "bebop_encode_batch_readings — Bebop message wire format"
  "Arena-based allocator (zero per-field allocations after context creation)"
  "All 9 unit tests pass")

 (route-to-mvp
  ((milestone "M0: Scaffold — COMPLETE")
   (status complete))
  ((milestone "M1: Working Decode — COMPLETE 2026-04-17")
   (status complete)
   (items
    "Implement bebop_decode_sensor_reading in Zig"
    "All tests pass"))
  ((milestone "M2: Working Encode — COMPLETE 2026-04-17")
   (status complete)
   (items
    "Implement bebop_encode_batch_readings"
    "Round-trip test (encode → decode → values match)"))
  ((milestone "M3: Consumer Integration — COMPLETE 2026-04-17")
   (status complete)
   (items
    "volumod test-ffi passes with libbebop_v_ffi.a"))
  ((milestone "M4: Golden Vectors")
   (status pending)
   (items
    "Generate real wire bytes with bebopc"
    "Wire golden vectors into tests"))
  ((milestone "M5: CI Matrix")
   (status pending)
   (items
    "Linux / macOS builds"
    "Multiple Zig versions")))

 (blockers-and-issues
  (critical)
  (high
   "GitHub remote not yet renamed (bebop-v-ffi → bebop-ffi) — user action required")
  (medium
   "Golden vectors still have placeholder wire bytes (need bebopc)"
   "README.adoc still describes V; narrative docs not fully updated"
   "No CI pipeline yet")
  (low
   "Rust implementation help wanted"))

 (critical-next-actions
  (immediate
   "User: rename GitHub remote bebop-v-ffi → bebop-ffi")
  (this-week
   "Generate wire bytes with bebopc to fill test-vectors"
   "Update README.adoc narrative to reflect Zig-canonical status")
  (this-month
   "Set up CI (Linux/macOS, Zig matrix)"
   "Explore Rust plug-compatible implementation")))
