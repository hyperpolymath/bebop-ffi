// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
// (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
//
// bebop_v_ffi.h - Stable C ABI contract for Bebop serialization bindings.
//
// NOTE: The `_v_` in the name is retained for C ABI stability — the V-lang
// binding was moved to v-ecosystem/v-api-interfaces/v-bebop/ on 2026-04-17.
// Zig is now the canonical implementation (implementations/zig/).
//
// This header defines the FFI boundary. Implementations (Zig, Rust, etc.)
// must conform to these signatures exactly.

#ifndef BEBOP_V_FFI_H
#define BEBOP_V_FFI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque context for allocations and state. Prefer one context per connection/thread. */
typedef struct BebopCtx BebopCtx;

/* Byte slice passed across FFI. Data is not NUL-terminated. */
typedef struct VBytes {
    const uint8_t* ptr;
    size_t len;
} VBytes;

/* Flat, FFI-friendly representation of SensorReading (schema-defined). */
typedef struct VSensorReading {
    uint64_t timestamp;
    VBytes sensor_id;
    uint16_t sensor_type;
    double value;
    VBytes unit;
    VBytes location;

    size_t metadata_count;
    VBytes* metadata_keys;
    VBytes* metadata_values;

    int32_t error_code;
    const char* error_message; /* NUL-terminated; owned by implementation (ctx). */
} VSensorReading;

/* Context lifecycle */
BebopCtx* bebop_ctx_new(void);
void bebop_ctx_free(BebopCtx* ctx);
void bebop_ctx_reset(BebopCtx* ctx);

/* Decode/encode */
int32_t bebop_decode_sensor_reading(
    BebopCtx* ctx,
    const uint8_t* data,
    size_t len,
    VSensorReading* out
);

/* Frees any per-reading allocations (if needed). Safe to call multiple times. */
void bebop_free_sensor_reading(BebopCtx* ctx, VSensorReading* reading);

/* Encode a batch of readings into out_buf. Returns bytes written (0 on failure). */
size_t bebop_encode_batch_readings(
    BebopCtx* ctx,
    const VSensorReading* readings,
    size_t count,
    uint8_t* out_buf,
    size_t out_len
);

#ifdef __cplusplus
}
#endif

#endif /* BEBOP_V_FFI_H */
