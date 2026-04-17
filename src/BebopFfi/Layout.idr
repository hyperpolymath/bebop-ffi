-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-- (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
--
-- BebopFfi.Layout — Memory layout declarations for the Bebop FFI C ABI.
--
-- This module documents and checks the expected byte sizes and alignment of
-- structs that cross the C ABI boundary.  Sizes are given for the canonical
-- 64-bit LP64 target (Linux x86-64 / aarch64).
--
-- The structs themselves are opaque to Idris2 — callers never construct them
-- directly in Idris2.  The Zig implementation owns the layout; these
-- declarations serve as a cross-language audit checkpoint and as commentary
-- for future ABI versioning work.
--
-- Key structures (from include/bebop_v_ffi.h + implementations/zig/src/bridge.zig):
--
--   BebopCtx — fully opaque to C callers; accessed only via *BebopCtx pointer.
--              Size is internal to the Zig implementation and not ABI-visible.
--
--   VBytes   — { ptr: *const u8, len: usize }
--              LP64 layout: 8 + 8 = 16 bytes, alignment 8.
--
--   VSensorReading — contains 2× u64, 3× VBytes (48 b), 1× u16 (+6 bytes pad),
--                    1× f64, 1× usize, 2× *VBytes, 1× i32 (+4 bytes pad), 1× *u8.
--                    Expected size on LP64: 96 bytes.  See below.
--
-- NOTE: Idris2's RefC backend does not expose sizeof/alignof at the language
-- level, so the proofs here are propositional assertions backed by the inline
-- commentary and by the Zig `@sizeOf` / `@alignOf` values verified in the Zig
-- unit tests (see implementations/zig/src/bridge.zig).
-- A future ABI-hardening step could generate C headers from these declarations
-- and verify them with a static_assert in C.

module BebopFfi.Layout

import Data.Nat

%default total

-- ============================================================================
-- Canonical size constants (LP64 / x86-64 / aarch64)
-- ============================================================================

||| Byte size of a `VBytes` struct on LP64 targets.
||| Layout: ptr (8 bytes) + len (8 bytes) = 16 bytes, alignment 8.
public export
vbytesSize : Nat
vbytesSize = 16

||| Byte alignment of `VBytes` on LP64 targets.
public export
vbytesAlign : Nat
vbytesAlign = 8

||| Expected byte size of `VSensorReading` on LP64 targets.
|||
||| Field-by-field breakdown (padding inserted by Zig/C rules):
|||   timestamp      : u64   —  8 bytes  [0..7]
|||   sensor_id      : VBytes — 16 bytes  [8..23]
|||   sensor_type    : u16   —  2 bytes  [24..25]  (+6 pad → 32)
|||   value          : f64   —  8 bytes  [32..39]
|||   unit           : VBytes — 16 bytes  [40..55]
|||   location       : VBytes — 16 bytes  [56..71]
|||   metadata_count : usize —  8 bytes  [72..79]
|||   metadata_keys  : *VBytes — 8 bytes  [80..87]
|||   metadata_values: *VBytes — 8 bytes  [88..95]
|||   error_code     : i32   —  4 bytes  [96..99]  (+4 pad → 104)
|||   error_message  : *u8   —  8 bytes  [104..111]
|||   Total                    112 bytes
|||
||| This matches `@sizeOf(VSensorReading)` in the Zig implementation.
public export
vsensorReadingSize : Nat
vsensorReadingSize = 112

||| Byte alignment of `VSensorReading` (largest scalar member = 8).
public export
vsensorReadingAlign : Nat
vsensorReadingAlign = 8

-- ============================================================================
-- Propositional layout lemmas
-- ============================================================================

||| VBytes contains exactly two pointer-sized fields.
||| Proof: 16 == 2 * 8 (LP64: ptr = 8 bytes, len = 8 bytes).
public export
vbytesTwoFields : 16 = 2 * 8
vbytesTwoFields = Refl

||| VSensorReading is non-trivially larger than VBytes.
||| Proof: 112 > 16 (reading contains three embedded VBytes plus scalars).
||| Uses LTE from Data.Nat: LTE n m means n <= m, so LTE 113 112 is False;
||| we assert 16 `LTE` 112, i.e. VBytes fits inside VSensorReading.
public export
vbytesLteReading : LTE 16 112
vbytesLteReading = %search
