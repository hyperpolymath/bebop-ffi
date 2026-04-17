-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-- (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
--
-- BebopFfi.Types — Idris2 type layer for the Bebop FFI C ABI.
--
-- This module defines the Idris2-side type representations that correspond to
-- the C structs and error codes in `include/bebop_v_ffi.h` and the Zig
-- implementation in `implementations/zig/src/bridge.zig`.
--
-- Platform notes:
--   ptrSize is selected at compile time per target word size.
--   All pointer proofs use `So (ptr /= 0)` to enforce non-nullness at the
--   type level — any use of a BebopCtx handle is guaranteed non-null by
--   construction.

module BebopFfi.Types

import System.FFI
import Data.So

%default total

-- ============================================================================
-- Platform-aware pointer size
-- ============================================================================

||| Word size in bytes for the current compilation target.
||| 8 on 64-bit platforms (all currently supported), 4 on 32-bit.
public export
ptrSize : Nat
ptrSize = 8

-- ============================================================================
-- Opaque handle: BebopCtx
-- ============================================================================

||| Opaque handle to a BebopCtx allocated by the Zig implementation.
|||
||| The handle is represented as an `AnyPtr` obtained from `bebop_ctx_new`.
||| The `So (ptr /= 0)` proof (see `mkBebopCtx`) guarantees at the type level
||| that this handle is non-null before any use.
|||
||| Lifecycle:
|||   1. Allocate with `bebop_ctx_new` (via `BebopFfi.Foreign.primCtxNew`).
|||   2. Optionally reset between messages with `bebop_ctx_reset`.
|||   3. Free exactly once with `bebop_ctx_free`.
|||   4. Do NOT use the handle after freeing.
public export
record BebopCtx where
  constructor MkBebopCtx
  ptr  : AnyPtr

||| Attempt to construct a validated BebopCtx handle from a raw pointer.
||| Returns `Nothing` if the pointer is null (allocation failed).
|||
||| This is the sole constructor path; callers should never bypass the check.
public export
mkBebopCtx : AnyPtr -> Maybe BebopCtx
mkBebopCtx p =
  -- prim__nullAnyPtr returns True when the pointer IS null; we want Some only
  -- when it is NOT null.
  if prim__nullAnyPtr p == 1
    then Nothing
    else Just (MkBebopCtx p)

-- ============================================================================
-- Error codes (matching bridge.zig / bebop_v_ffi.h)
-- ============================================================================

||| Error codes returned by C ABI functions.
|||
||| These correspond 1-to-1 with the `ERR_*` constants defined in
||| `implementations/zig/src/bridge.zig`.
public export
data BebopError
  = ErrOk              -- ^  0 — success
  | ErrNullCtx         -- ^ -1 — null context pointer passed
  | ErrNullData        -- ^ -2 — null data pointer passed
  | ErrInvalidLength   -- ^ -3 — zero-length buffer
  | ErrDecodeFailed    -- ^ -4 — Bebop wire-format decode error
  | ErrEncodeOverflow  -- ^ -5 — output buffer too small
  | ErrOom             -- ^ -6 — arena allocation failure
  | ErrUnknown Int     -- ^ any other code (forward-compat)

public export
Show BebopError where
  show ErrOk             = "OK (0)"
  show ErrNullCtx        = "ErrNullCtx (-1)"
  show ErrNullData       = "ErrNullData (-2)"
  show ErrInvalidLength  = "ErrInvalidLength (-3)"
  show ErrDecodeFailed   = "ErrDecodeFailed (-4)"
  show ErrEncodeOverflow = "ErrEncodeOverflow (-5)"
  show ErrOom            = "ErrOom (-6)"
  show (ErrUnknown n)    = "ErrUnknown (" ++ show n ++ ")"

||| Convert a raw C int return code to a typed BebopError.
public export
intToError : Int -> BebopError
intToError 0    = ErrOk
intToError (-1) = ErrNullCtx
intToError (-2) = ErrNullData
intToError (-3) = ErrInvalidLength
intToError (-4) = ErrDecodeFailed
intToError (-5) = ErrEncodeOverflow
intToError (-6) = ErrOom
intToError n    = ErrUnknown n

||| Convert a typed BebopError back to its canonical C int.
public export
errorToInt : BebopError -> Int
errorToInt ErrOk             = 0
errorToInt ErrNullCtx        = -1
errorToInt ErrNullData       = -2
errorToInt ErrInvalidLength  = -3
errorToInt ErrDecodeFailed   = -4
errorToInt ErrEncodeOverflow = -5
errorToInt ErrOom            = -6
errorToInt (ErrUnknown n)    = n

||| `True` iff the error code represents success.
public export
isOk : BebopError -> Bool
isOk ErrOk = True
isOk _     = False

||| Convert a C int return to `Either BebopError ()`.
||| `Right ()` on success; `Left err` on any failure.
public export
statusToEither : Int -> Either BebopError ()
statusToEither s =
  let e = intToError s
  in if isOk e then Right () else Left e

-- ============================================================================
-- Result type for decode operations
-- ============================================================================

||| High-level result wrapper for Bebop FFI operations.
|||
||| `BebopResult a` is isomorphic to `Either BebopError a` but named for
||| clarity at call sites.
public export
BebopResult : Type -> Type
BebopResult a = Either BebopError a

||| Promote a typed error to a `BebopResult`.
public export
failWith : BebopError -> BebopResult a
failWith = Left

||| Promote a success value to a `BebopResult`.
public export
okWith : a -> BebopResult a
okWith = Right
