-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-- (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
--
-- BebopFfi.Foreign — %foreign "C" declarations for libbebop_v_ffi.
--
-- This module declares every C function exported by the Zig implementation
-- (`implementations/zig/src/bridge.zig`) using the Idris2 `%foreign` mechanism.
-- The linker library name is `libbebop_v_ffi` (built at
-- `implementations/zig/zig-out/lib/libbebop_v_ffi.so`).
--
-- NOTE on the `_v_` prefix: all exported symbols retain the historical
-- `bebop_v_` prefix for C ABI stability — the V-lang binding was removed in
-- 2026-04-17 but the symbol names are frozen.
--
-- Memory management contract:
--   BebopCtx lifetime:
--     Allocate  → prim__bebopCtxNew
--     Reset     → prim__bebopCtxReset   (reuse arena without re-allocating)
--     Free      → prim__bebopCtxFree    (call exactly once; handle invalid after)
--
--   VSensorReading lifetime:
--     The struct is caller-allocated (stack or heap) and passed by pointer.
--     Decode fills it; the arena inside the associated BebopCtx owns all
--     dynamic sub-fields (strings, metadata arrays).
--     prim__bebopFreeSensorReading zeroes the struct (arena memory is reclaimed
--     only on ctx reset/free — this matches the Zig implementation's design).
--
-- ABI note:
--   Idris2's RefC backend marshals `AnyPtr` as a C `void*`, `Int` as a C
--   `int32_t`, and `Int64` as a C `int64_t`.
--   The VSensorReading struct is passed as `AnyPtr` (pointer to caller-allocated
--   memory) because Idris2 cannot directly represent C `extern struct` fields.
--   The decode result is read back via the safe wrapper in BebopFfi.Safe (if
--   present) or by the caller inspecting the AnyPtr via C interop.

module BebopFfi.Foreign

import System.FFI
import BebopFfi.Types

%default total

-- ============================================================================
-- Context lifecycle (3 functions)
-- ============================================================================

||| Allocate a new BebopCtx backed by the page allocator.
||| Returns a null pointer on allocation failure.
||| Caller is responsible for freeing with `prim__bebopCtxFree`.
%foreign "C:bebop_ctx_new,libbebop_v_ffi"
export
prim__bebopCtxNew : PrimIO AnyPtr

||| Free a BebopCtx and all its arena allocations.
||| `ctx` must be a valid non-null pointer previously returned by
||| `prim__bebopCtxNew`.  Passing null is a no-op (Zig guards it).
%foreign "C:bebop_ctx_free,libbebop_v_ffi"
export
prim__bebopCtxFree : AnyPtr -> PrimIO ()

||| Reset the arena inside a BebopCtx for reuse without re-allocating.
||| All pointers obtained from previous decode operations become invalid
||| after this call.
%foreign "C:bebop_ctx_reset,libbebop_v_ffi"
export
prim__bebopCtxReset : AnyPtr -> PrimIO ()

-- ============================================================================
-- Decode (1 function)
-- ============================================================================

||| Decode a Bebop-encoded SensorReading from `data[0..len]`.
|||
||| Parameters:
|||   ctx   — non-null BebopCtx pointer (arena owner)
|||   data  — pointer to the raw Bebop wire bytes
|||   len   — byte count of `data`
|||   out   — pointer to a caller-allocated VSensorReading struct to fill
|||
||| Returns 0 (`ERR_OK`) on success; a negative `ERR_*` code on failure.
||| On success, all string/slice fields inside `out` point into the ctx arena.
||| On failure, `out.error_code` and `out.error_message` are set.
|||
||| C signature:
|||   int32_t bebop_decode_sensor_reading(
|||       BebopCtx* ctx, const uint8_t* data, size_t len, VSensorReading* out);
%foreign "C:bebop_decode_sensor_reading,libbebop_v_ffi"
export
prim__bebopDecodeSensorReading : AnyPtr -> AnyPtr -> Int -> AnyPtr -> PrimIO Int

-- ============================================================================
-- Free sensor reading (1 function)
-- ============================================================================

||| Zero a VSensorReading struct.
||| With arena allocation this is a logical clear — actual memory is reclaimed
||| only on ctx reset/free.  Safe to call multiple times.
|||
||| C signature:
|||   void bebop_free_sensor_reading(BebopCtx* ctx, VSensorReading* reading);
%foreign "C:bebop_free_sensor_reading,libbebop_v_ffi"
export
prim__bebopFreeSensorReading : AnyPtr -> AnyPtr -> PrimIO ()

-- ============================================================================
-- Encode (1 function)
-- ============================================================================

||| Encode `count` SensorReadings into `out_buf[0..out_len]`.
||| Returns total bytes written, or 0 on failure (buffer too small, null args).
|||
||| The batch format is a sequence of individually-framed Bebop messages —
||| not a Bebop `BatchReadings` struct.  Callers may add their own outer
||| framing as needed.
|||
||| C signature:
|||   size_t bebop_encode_batch_readings(
|||       BebopCtx* ctx,
|||       const VSensorReading* readings,
|||       size_t count,
|||       uint8_t* out_buf,
|||       size_t out_len);
%foreign "C:bebop_encode_batch_readings,libbebop_v_ffi"
export
prim__bebopEncodeBatchReadings : AnyPtr -> AnyPtr -> Int -> AnyPtr -> Int -> PrimIO Int

-- ============================================================================
-- Safe lifecycle wrappers using BebopFfi.Types
-- ============================================================================

||| Allocate a new BebopCtx and validate the pointer.
||| Returns `Nothing` if allocation failed (OOM).
export
bebopCtxNew : IO (Maybe BebopCtx)
bebopCtxNew = do
  raw <- primIO prim__bebopCtxNew
  pure (mkBebopCtx raw)

||| Free a BebopCtx handle.
||| The handle must not be used after this call.
export
bebopCtxFree : BebopCtx -> IO ()
bebopCtxFree ctx = primIO (prim__bebopCtxFree ctx.ptr)

||| Reset a BebopCtx arena for reuse.
||| All decode output pointers derived from this ctx become invalid.
export
bebopCtxReset : BebopCtx -> IO ()
bebopCtxReset ctx = primIO (prim__bebopCtxReset ctx.ptr)

||| Decode a SensorReading from raw Bebop wire bytes.
|||
||| `out` must point to a valid caller-allocated VSensorReading struct.
||| Returns `Right ()` on success; `Left err` on failure.
||| On success the output fields are valid until `ctx` is reset or freed.
export
bebopDecodeSensorReading :
    BebopCtx
  -> AnyPtr   -- ^ data: raw wire bytes
  -> Int      -- ^ len:  byte count of data
  -> AnyPtr   -- ^ out:  pointer to caller-allocated VSensorReading
  -> IO (Either BebopError ())
bebopDecodeSensorReading ctx dataPtr len outPtr = do
  rc <- primIO (prim__bebopDecodeSensorReading ctx.ptr dataPtr len outPtr)
  pure (statusToEither rc)

||| Zero a VSensorReading struct.
export
bebopFreeSensorReading : BebopCtx -> AnyPtr -> IO ()
bebopFreeSensorReading ctx readingPtr =
  primIO (prim__bebopFreeSensorReading ctx.ptr readingPtr)

||| Encode a batch of SensorReadings.
|||
||| `readings` is a pointer to an array of `count` VSensorReading structs.
||| `outBuf` is a pointer to a caller-provided output buffer of `outLen` bytes.
||| Returns the number of bytes written (0 on failure).
export
bebopEncodeBatchReadings :
    BebopCtx
  -> AnyPtr   -- ^ readings: pointer to VSensorReading[]
  -> Int      -- ^ count:    number of readings
  -> AnyPtr   -- ^ outBuf:   pointer to output buffer
  -> Int      -- ^ outLen:   byte capacity of output buffer
  -> IO Int
bebopEncodeBatchReadings ctx readings count outBuf outLen =
  primIO (prim__bebopEncodeBatchReadings ctx.ptr readings count outBuf outLen)
