// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
// (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
//
// bridge.zig — Zig implementation of the Bebop-FFI C ABI.
//
// NOTE: The symbol prefix `bebop_v_` and the header name `bebop_v_ffi.h` retain
// the historical `_v_` for C ABI stability — V is no longer involved. The repo
// was renamed bebop-v-ffi → bebop-ffi on 2026-04-17; the ABI is unchanged.
//
// Wire format implemented here follows the Bebop specification:
//   https://bebop.sh/reference/
//
//   message type:  4-byte LE total-length, then repeated (u8 field-index, data),
//                  terminated by a 0x00 sentinel byte.
//   string:        4-byte LE character count (not byte count), then UTF-8 bytes.
//   map<K,V>:      4-byte LE entry count, then repeated (key, value) pairs.
//   uint64/float64: 8 bytes LE.
//   uint16:         2 bytes LE.
//
// SensorReading field indices (from sensors.bop, 1-based per Bebop message spec):
//   1 → timestamp   (uint64)
//   2 → sensorId    (string)
//   3 → sensorType  (uint16 enum)
//   4 → value       (float64)
//   5 → unit        (string)
//   6 → location    (string)
//   7 → metadata    (map<string,string>)

const std = @import("std");
const Allocator = std.mem.Allocator;

// =============================================================================
// Public types — must match bebop_v_ffi.h exactly
// =============================================================================

/// Byte slice passed across the FFI boundary. `ptr` is NOT NUL-terminated.
/// An empty slice is represented as `{ .ptr = null, .len = 0 }`.
pub const VBytes = extern struct {
    ptr: ?[*]const u8,
    len: usize,

    /// Construct a VBytes view over a Zig slice. No allocation.
    pub fn fromSlice(s: []const u8) VBytes {
        return .{
            .ptr = if (s.len > 0) s.ptr else null,
            .len = s.len,
        };
    }

    /// Null/empty sentinel.
    pub fn empty() VBytes {
        return .{ .ptr = null, .len = 0 };
    }

    /// Borrow back as a Zig slice. Safe only while the owning context is live.
    pub fn toSlice(self: VBytes) []const u8 {
        if (self.ptr == null or self.len == 0) return &[_]u8{};
        return self.ptr.?[0..self.len];
    }
};

/// Flat, FFI-friendly representation of SensorReading (schema-defined).
/// Layout must exactly match the C struct in bebop_v_ffi.h.
pub const VSensorReading = extern struct {
    timestamp: u64,
    sensor_id: VBytes,
    sensor_type: u16,
    value: f64,
    unit: VBytes,
    location: VBytes,

    metadata_count: usize,
    metadata_keys: ?[*]VBytes,
    metadata_values: ?[*]VBytes,

    error_code: i32,
    /// NUL-terminated; owned by the context (valid until ctx reset/free).
    error_message: ?[*:0]const u8,

    pub fn zeroed() VSensorReading {
        return .{
            .timestamp = 0,
            .sensor_id = VBytes.empty(),
            .sensor_type = 0,
            .value = 0.0,
            .unit = VBytes.empty(),
            .location = VBytes.empty(),
            .metadata_count = 0,
            .metadata_keys = null,
            .metadata_values = null,
            .error_code = 0,
            .error_message = null,
        };
    }
};

// =============================================================================
// Error codes (must match bebop_v_ffi.h)
// =============================================================================

pub const ERR_OK: i32 = 0;
pub const ERR_NULL_CTX: i32 = -1;
pub const ERR_NULL_DATA: i32 = -2;
pub const ERR_INVALID_LENGTH: i32 = -3;
pub const ERR_DECODE_FAILED: i32 = -4;
pub const ERR_ENCODE_OVERFLOW: i32 = -5;
pub const ERR_OOM: i32 = -6;

// =============================================================================
// Internal decode errors
// =============================================================================

const DecodeError = error{
    UnexpectedEof,
    InvalidUtf8,
    OutOfMemory,
    BufferTooSmall,
};

// =============================================================================
// BebopCtx — arena-based context
// =============================================================================

/// Opaque context; caller receives and passes this as `*BebopCtx`.
/// All decode output slices are arena-owned and valid until reset/free.
pub const BebopCtx = struct {
    arena: std.heap.ArenaAllocator,
    /// Fixed buffer for the most recent NUL-terminated error string.
    error_buf: [512]u8,
    error_msg_ptr: ?[*:0]const u8,

    pub fn init(backing: Allocator) !*BebopCtx {
        const self = try backing.create(BebopCtx);
        self.* = .{
            .arena = std.heap.ArenaAllocator.init(backing),
            .error_buf = undefined,
            .error_msg_ptr = null,
        };
        return self;
    }

    pub fn deinit(self: *BebopCtx, backing: Allocator) void {
        self.arena.deinit();
        backing.destroy(self);
    }

    pub fn reset(self: *BebopCtx) void {
        _ = self.arena.reset(.retain_capacity);
        self.error_msg_ptr = null;
    }

    pub fn allocator(self: *BebopCtx) Allocator {
        return self.arena.allocator();
    }

    /// Store an error string; returns a pointer stable until next reset/free.
    pub fn setError(self: *BebopCtx, code: i32, msg: []const u8) i32 {
        const n = @min(msg.len, self.error_buf.len - 1);
        @memcpy(self.error_buf[0..n], msg[0..n]);
        self.error_buf[n] = 0;
        self.error_msg_ptr = @ptrCast(&self.error_buf);
        return code;
    }
};

// =============================================================================
// Exported C ABI functions
// =============================================================================

/// Create a new context backed by the page allocator.
/// Returns null on allocation failure.
export fn bebop_ctx_new() ?*BebopCtx {
    return BebopCtx.init(std.heap.page_allocator) catch null;
}

/// Free context and all its arena allocations.
export fn bebop_ctx_free(ctx: ?*BebopCtx) void {
    const c = ctx orelse return;
    c.deinit(std.heap.page_allocator);
}

/// Reset arena for reuse (high-throughput decode pattern).
export fn bebop_ctx_reset(ctx: ?*BebopCtx) void {
    const c = ctx orelse return;
    c.reset();
}

/// Decode a Bebop-encoded SensorReading from `data[0..len]`.
/// Returns 0 on success; negative ERR_ code on failure.
/// On success, `out.*` is valid until ctx is reset or freed.
export fn bebop_decode_sensor_reading(
    ctx: ?*BebopCtx,
    data: ?[*]const u8,
    len: usize,
    out: ?*VSensorReading,
) i32 {
    const c = ctx orelse return ERR_NULL_CTX;
    const output = out orelse return ERR_NULL_DATA;
    const raw = data orelse return ERR_NULL_DATA;
    if (len == 0) return ERR_INVALID_LENGTH;

    output.* = VSensorReading.zeroed();

    const bytes = raw[0..len];
    decodeSensorReading(c, bytes, output) catch |err| {
        const msg: []const u8 = switch (err) {
            error.UnexpectedEof => "unexpected end of input",
            error.InvalidUtf8 => "invalid UTF-8 in string field",
            error.OutOfMemory => "out of memory during decode",
            error.BufferTooSmall => "buffer too small",
        };
        output.error_code = ERR_DECODE_FAILED;
        return c.setError(ERR_DECODE_FAILED, msg);
    };
    return ERR_OK;
}

/// Free per-reading allocations. With arena allocation this is a no-op —
/// memory reclaims on ctx reset/free. Resets the struct to zeroed state.
export fn bebop_free_sensor_reading(ctx: ?*BebopCtx, reading: ?*VSensorReading) void {
    _ = ctx; // arena owns everything
    if (reading) |r| r.* = VSensorReading.zeroed();
}

/// Encode `count` SensorReadings into `out_buf[0..out_len]`.
/// Returns bytes written, or 0 on failure.
export fn bebop_encode_batch_readings(
    ctx: ?*BebopCtx,
    readings: ?[*]const VSensorReading,
    count: usize,
    out_buf: ?[*]u8,
    out_len: usize,
) usize {
    const c = ctx orelse return 0;
    const rptr = readings orelse return 0;
    const buf_ptr = out_buf orelse return 0;
    if (count == 0 or out_len == 0) return 0;

    const buf = buf_ptr[0..out_len];
    const written = encodeBatchReadings(c, rptr[0..count], buf) catch |err| {
        const msg: []const u8 = switch (err) {
            error.BufferTooSmall => "output buffer too small for batch",
        };
        _ = c.setError(ERR_ENCODE_OVERFLOW, msg);
        return 0;
    };
    return written;
}

// =============================================================================
// Bebop wire-format helpers
// =============================================================================

/// Reader cursor over an immutable byte slice.
const Reader = struct {
    data: []const u8,
    pos: usize,

    fn init(data: []const u8) Reader {
        return .{ .data = data, .pos = 0 };
    }

    fn remaining(self: Reader) usize {
        return self.data.len - self.pos;
    }

    fn readU8(self: *Reader) DecodeError!u8 {
        if (self.pos >= self.data.len) return error.UnexpectedEof;
        const v = self.data[self.pos];
        self.pos += 1;
        return v;
    }

    fn readU16Le(self: *Reader) DecodeError!u16 {
        if (self.remaining() < 2) return error.UnexpectedEof;
        const lo: u16 = self.data[self.pos];
        const hi: u16 = self.data[self.pos + 1];
        self.pos += 2;
        return lo | (hi << 8);
    }

    fn readU32Le(self: *Reader) DecodeError!u32 {
        if (self.remaining() < 4) return error.UnexpectedEof;
        const b = self.data[self.pos .. self.pos + 4];
        self.pos += 4;
        return std.mem.readInt(u32, b[0..4], .little);
    }

    fn readU64Le(self: *Reader) DecodeError!u64 {
        if (self.remaining() < 8) return error.UnexpectedEof;
        const b = self.data[self.pos .. self.pos + 8];
        self.pos += 8;
        return std.mem.readInt(u64, b[0..8], .little);
    }

    fn readF64Le(self: *Reader) DecodeError!f64 {
        const bits = try self.readU64Le();
        return @bitCast(bits);
    }

    /// Read a Bebop string: 4-byte LE char count, then UTF-8 bytes.
    /// Returns a slice pointing into `self.data` (zero-copy view).
    fn readStringView(self: *Reader) DecodeError![]const u8 {
        const char_count = try self.readU32Le();
        if (self.remaining() < char_count) return error.UnexpectedEof;
        const s = self.data[self.pos .. self.pos + char_count];
        self.pos += char_count;
        if (!std.unicode.utf8ValidateSlice(s)) return error.InvalidUtf8;
        return s;
    }

    /// Read a Bebop string and arena-copy it, yielding an owned slice.
    fn readStringCopy(self: *Reader, alloc: Allocator) DecodeError![]const u8 {
        const view = try self.readStringView();
        const copy = try alloc.dupe(u8, view);
        return copy;
    }
};

/// Writer cursor with bounds checking.
const Writer = struct {
    buf: []u8,
    pos: usize,

    fn init(buf: []u8) Writer {
        return .{ .buf = buf, .pos = 0 };
    }

    fn written(self: Writer) usize {
        return self.pos;
    }

    fn writeU8(self: *Writer, v: u8) error{BufferTooSmall}!void {
        if (self.pos >= self.buf.len) return error.BufferTooSmall;
        self.buf[self.pos] = v;
        self.pos += 1;
    }

    fn writeU16Le(self: *Writer, v: u16) error{BufferTooSmall}!void {
        if (self.pos + 2 > self.buf.len) return error.BufferTooSmall;
        std.mem.writeInt(u16, self.buf[self.pos..][0..2], v, .little);
        self.pos += 2;
    }

    fn writeU32Le(self: *Writer, v: u32) error{BufferTooSmall}!void {
        if (self.pos + 4 > self.buf.len) return error.BufferTooSmall;
        std.mem.writeInt(u32, self.buf[self.pos..][0..4], v, .little);
        self.pos += 4;
    }

    fn writeU64Le(self: *Writer, v: u64) error{BufferTooSmall}!void {
        if (self.pos + 8 > self.buf.len) return error.BufferTooSmall;
        std.mem.writeInt(u64, self.buf[self.pos..][0..8], v, .little);
        self.pos += 8;
    }

    fn writeF64Le(self: *Writer, v: f64) error{BufferTooSmall}!void {
        try self.writeU64Le(@bitCast(v));
    }

    /// Write a Bebop string: 4-byte LE char count, then UTF-8 bytes.
    fn writeString(self: *Writer, s: []const u8) error{BufferTooSmall}!void {
        try self.writeU32Le(@intCast(s.len));
        if (self.pos + s.len > self.buf.len) return error.BufferTooSmall;
        @memcpy(self.buf[self.pos .. self.pos + s.len], s);
        self.pos += s.len;
    }

    /// Write a Bebop string from VBytes.
    fn writeVBytes(self: *Writer, vb: VBytes) error{BufferTooSmall}!void {
        try self.writeString(vb.toSlice());
    }

    /// Patch a previously-reserved u32 slot with the actual value.
    fn patchU32Le(self: *Writer, slot: usize, v: u32) void {
        std.mem.writeInt(u32, self.buf[slot..][0..4], v, .little);
    }
};

// =============================================================================
// SensorReading decode
// =============================================================================

/// Decode a single Bebop-encoded SensorReading `message` into `out`.
/// All string/slice fields point into arena-owned copies.
fn decodeSensorReading(c: *BebopCtx, bytes: []const u8, out: *VSensorReading) DecodeError!void {
    var r = Reader.init(bytes);
    const alloc = c.allocator();

    // Bebop `message` format: 4-byte LE total byte length of remaining data,
    // then repeated (field_index: u8, field_data), terminated by 0x00.
    const msg_len = try r.readU32Le();
    if (msg_len > r.remaining()) return error.UnexpectedEof;
    // Constrain reader to declared message body.
    const body_end = r.pos + msg_len;

    // Temporary metadata storage (arena-backed ArrayLists for dynamic count).
    var meta_keys = std.ArrayListUnmanaged(VBytes){};
    var meta_vals = std.ArrayListUnmanaged(VBytes){};

    while (r.pos < body_end) {
        const field_index = try r.readU8();
        if (field_index == 0) break; // Bebop sentinel

        switch (field_index) {
            1 => { // timestamp: uint64
                out.timestamp = try r.readU64Le();
            },
            2 => { // sensorId: string
                const s = try r.readStringCopy(alloc);
                out.sensor_id = VBytes.fromSlice(s);
            },
            3 => { // sensorType: uint16 (enum)
                out.sensor_type = try r.readU16Le();
            },
            4 => { // value: float64
                out.value = try r.readF64Le();
            },
            5 => { // unit: string
                const s = try r.readStringCopy(alloc);
                out.unit = VBytes.fromSlice(s);
            },
            6 => { // location: string
                const s = try r.readStringCopy(alloc);
                out.location = VBytes.fromSlice(s);
            },
            7 => { // metadata: map<string,string>
                const entry_count = try r.readU32Le();
                try meta_keys.ensureTotalCapacity(alloc, entry_count);
                try meta_vals.ensureTotalCapacity(alloc, entry_count);
                var i: u32 = 0;
                while (i < entry_count) : (i += 1) {
                    const k = try r.readStringCopy(alloc);
                    const v = try r.readStringCopy(alloc);
                    meta_keys.appendAssumeCapacity(VBytes.fromSlice(k));
                    meta_vals.appendAssumeCapacity(VBytes.fromSlice(v));
                }
            },
            else => {
                // Unknown field: skip. Bebop forward-compat requires this.
                // We cannot skip cleanly without knowing field size; treat as
                // an opaque error (schema version mismatch).
                return error.UnexpectedEof;
            },
        }
    }

    // Move metadata arrays into arena-stable slices.
    const meta_count = meta_keys.items.len;
    if (meta_count > 0) {
        const keys_slice = try alloc.dupe(VBytes, meta_keys.items);
        const vals_slice = try alloc.dupe(VBytes, meta_vals.items);
        out.metadata_count = meta_count;
        out.metadata_keys = keys_slice.ptr;
        out.metadata_values = vals_slice.ptr;
    } else {
        out.metadata_count = 0;
        out.metadata_keys = null;
        out.metadata_values = null;
    }
}

// =============================================================================
// SensorReading encode
// =============================================================================

/// Encode one SensorReading into `buf`.
/// Returns bytes written.
fn encodeSensorReading(r: *const VSensorReading, buf: []u8) error{BufferTooSmall}!usize {
    var w = Writer.init(buf);

    // Reserve 4-byte length prefix slot; patch after body is written.
    const len_slot = w.pos;
    try w.writeU32Le(0); // placeholder

    const body_start = w.pos;

    // Field 1: timestamp
    try w.writeU8(1);
    try w.writeU64Le(r.timestamp);

    // Field 2: sensorId
    if (r.sensor_id.len > 0) {
        try w.writeU8(2);
        try w.writeVBytes(r.sensor_id);
    }

    // Field 3: sensorType
    try w.writeU8(3);
    try w.writeU16Le(r.sensor_type);

    // Field 4: value
    try w.writeU8(4);
    try w.writeF64Le(r.value);

    // Field 5: unit
    if (r.unit.len > 0) {
        try w.writeU8(5);
        try w.writeVBytes(r.unit);
    }

    // Field 6: location
    if (r.location.len > 0) {
        try w.writeU8(6);
        try w.writeVBytes(r.location);
    }

    // Field 7: metadata
    if (r.metadata_count > 0) {
        try w.writeU8(7);
        try w.writeU32Le(@intCast(r.metadata_count));
        const keys = r.metadata_keys.?[0..r.metadata_count];
        const vals = r.metadata_values.?[0..r.metadata_count];
        for (keys, vals) |k, v| {
            try w.writeVBytes(k);
            try w.writeVBytes(v);
        }
    }

    // Bebop message terminator
    try w.writeU8(0);

    // Patch length: body byte count (everything after the 4-byte prefix).
    const body_len: u32 = @intCast(w.pos - body_start);
    w.patchU32Le(len_slot, body_len);

    return w.written();
}

/// Encode a batch of SensorReadings into `buf`.
/// The batch is a sequence of individually-framed messages (not a Bebop `BatchReadings`
/// struct) — callers can wrap them in their own framing as needed.
/// Returns total bytes written, or bubbles error{BufferTooSmall} if buf is too small.
fn encodeBatchReadings(
    c: *BebopCtx,
    readings: []const VSensorReading,
    buf: []u8,
) error{BufferTooSmall}!usize {
    _ = c; // no context allocation needed for encode
    var total: usize = 0;
    for (readings) |*r| {
        const n = try encodeSensorReading(r, buf[total..]);
        total += n;
    }
    return total;
}

// =============================================================================
// Tests
// =============================================================================

test "context lifecycle — new / reset / free" {
    const ctx = bebop_ctx_new();
    try std.testing.expect(ctx != null);
    bebop_ctx_reset(ctx);
    bebop_ctx_free(ctx);
}

test "VBytes roundtrip" {
    const s = "hello-world";
    const vb = VBytes.fromSlice(s);
    try std.testing.expectEqual(@as(usize, 11), vb.len);
    try std.testing.expectEqualSlices(u8, s, vb.toSlice());

    const empty = VBytes.empty();
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    try std.testing.expect(empty.ptr == null);
}

test "decode/encode SensorReading roundtrip" {
    // Build a Bebop-encoded SensorReading, decode it, re-encode, then
    // re-decode and verify field values match.  We do NOT compare raw bytes
    // byte-for-byte because the encoder canonicalises (omits empty optional
    // fields) while a hand-crafted wire may include them explicitly.
    //
    // Fields encoded here:
    //   1: timestamp   = 1_735_000_000_000
    //   2: sensor_id   = "s1"
    //   3: sensor_type = 1
    //   4: value       = 23.5
    //   5: unit        = "c"
    //   6: location    = "a"

    var reading_in = VSensorReading.zeroed();
    reading_in.timestamp   = 1_735_000_000_000;
    const id_lit  = "s1";
    const unit_lit = "c";
    const loc_lit  = "a";
    reading_in.sensor_id   = VBytes.fromSlice(id_lit);
    reading_in.sensor_type = 1;
    reading_in.value       = 23.5;
    reading_in.unit        = VBytes.fromSlice(unit_lit);
    reading_in.location    = VBytes.fromSlice(loc_lit);

    // Encode
    var enc_buf: [256]u8 = undefined;
    const n = try encodeSensorReading(&reading_in, &enc_buf);
    try std.testing.expect(n > 4); // at least length prefix + sentinel

    // Decode what we just encoded
    const ctx = bebop_ctx_new();
    defer bebop_ctx_free(ctx);

    var reading_out = VSensorReading.zeroed();
    const rc = bebop_decode_sensor_reading(ctx, enc_buf[0..].ptr, n, &reading_out);
    try std.testing.expectEqual(ERR_OK, rc);
    try std.testing.expectEqual(reading_in.timestamp,   reading_out.timestamp);
    try std.testing.expectEqualSlices(u8, "s1", reading_out.sensor_id.toSlice());
    try std.testing.expectEqual(reading_in.sensor_type, reading_out.sensor_type);
    try std.testing.expectApproxEqAbs(reading_in.value, reading_out.value, 1e-9);
    try std.testing.expectEqualSlices(u8, "c", reading_out.unit.toSlice());
    try std.testing.expectEqualSlices(u8, "a", reading_out.location.toSlice());
    try std.testing.expectEqual(@as(usize, 0), reading_out.metadata_count);

    // Re-encode and verify idempotence (encoder is deterministic).
    var enc_buf2: [256]u8 = undefined;
    const n2 = try encodeSensorReading(&reading_out, &enc_buf2);
    try std.testing.expectEqual(n, n2);
    try std.testing.expectEqualSlices(u8, enc_buf[0..n], enc_buf2[0..n2]);
}

test "decode SensorReading with metadata" {
    var w_buf: [512]u8 = undefined;
    var w = Writer.init(&w_buf);
    try w.writeU32Le(0); // placeholder

    // field 1: timestamp
    try w.writeU8(1);
    try w.writeU64Le(42);
    // field 7: metadata = { "fw" => "1.0" }
    try w.writeU8(7);
    try w.writeU32Le(1);
    try w.writeString("fw");
    try w.writeString("1.0");
    // sentinel
    try w.writeU8(0);

    w.patchU32Le(0, @intCast(w.pos - 4));

    const ctx = bebop_ctx_new();
    defer bebop_ctx_free(ctx);

    var reading = VSensorReading.zeroed();
    const rc = bebop_decode_sensor_reading(ctx, w_buf[0..].ptr, w.pos, &reading);
    try std.testing.expectEqual(ERR_OK, rc);
    try std.testing.expectEqual(@as(u64, 42), reading.timestamp);
    try std.testing.expectEqual(@as(usize, 1), reading.metadata_count);
    try std.testing.expectEqualSlices(u8, "fw", reading.metadata_keys.?[0].toSlice());
    try std.testing.expectEqualSlices(u8, "1.0", reading.metadata_values.?[0].toSlice());
}

test "decode rejects empty input" {
    const ctx = bebop_ctx_new();
    defer bebop_ctx_free(ctx);
    var reading = VSensorReading.zeroed();
    const rc = bebop_decode_sensor_reading(ctx, null, 0, &reading);
    try std.testing.expectEqual(ERR_NULL_DATA, rc);
}

test "decode rejects null ctx" {
    var reading = VSensorReading.zeroed();
    const bytes = [_]u8{0x00};
    const rc = bebop_decode_sensor_reading(null, &bytes, bytes.len, &reading);
    try std.testing.expectEqual(ERR_NULL_CTX, rc);
}

test "decode rejects truncated data" {
    const ctx = bebop_ctx_new();
    defer bebop_ctx_free(ctx);
    // Only 2 bytes — not enough for even the 4-byte length prefix.
    var reading = VSensorReading.zeroed();
    const bytes = [_]u8{ 0x01, 0x00 };
    const rc = bebop_decode_sensor_reading(ctx, &bytes, bytes.len, &reading);
    try std.testing.expectEqual(ERR_DECODE_FAILED, rc);
}

test "encode batch of zero returns 0" {
    const ctx = bebop_ctx_new();
    defer bebop_ctx_free(ctx);
    var buf: [64]u8 = undefined;
    const n = bebop_encode_batch_readings(ctx, null, 0, &buf, buf.len);
    try std.testing.expectEqual(@as(usize, 0), n);
}

test "bebop_free_sensor_reading clears struct" {
    const ctx = bebop_ctx_new();
    defer bebop_ctx_free(ctx);
    var r = VSensorReading.zeroed();
    r.timestamp = 999;
    bebop_free_sensor_reading(ctx, &r);
    try std.testing.expectEqual(@as(u64, 0), r.timestamp);
}
