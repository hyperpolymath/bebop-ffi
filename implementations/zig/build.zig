// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
// (MPL-2.0 is the automatic legal fallback until PMPL is formally recognised)
//
// build.zig — Zig 0.15.2 build script for bebop-ffi.
//
// Outputs:
//   zig-out/lib/libbebop_v_ffi.so   (shared library)
//   zig-out/lib/libbebop_v_ffi.a    (static library)
//   zig-out/include/bebop_v_ffi.h   (installed header)
//
// NOTE: The library name `bebop_v_ffi` retains the historical `_v_` for C ABI
// stability — V is no longer involved (moved to v-ecosystem/v-api-interfaces/
// v-bebop/). The repo was renamed bebop-v-ffi → bebop-ffi on 2026-04-17.
//
// Usage:
//   zig build              # debug shared + static libs
//   zig build -Doptimize=ReleaseFast
//   zig build test         # unit tests (no external deps)
//   zig build install      # install to zig-out/

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target   = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ------------------------------------------------------------------
    // Root module — single source of truth for both lib targets
    // ------------------------------------------------------------------

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/bridge.zig"),
        .target           = target,
        .optimize         = optimize,
    });

    // ------------------------------------------------------------------
    // Shared library: libbebop_v_ffi.so / .dylib / .dll
    // ------------------------------------------------------------------

    const lib_shared = b.addLibrary(.{
        .name        = "bebop_v_ffi",
        .root_module = root_mod,
        .linkage     = .dynamic,
        .version     = .{ .major = 0, .minor = 1, .patch = 0 },
    });
    b.installArtifact(lib_shared);

    // ------------------------------------------------------------------
    // Static library: libbebop_v_ffi.a
    // ------------------------------------------------------------------

    const static_mod = b.createModule(.{
        .root_source_file = b.path("src/bridge.zig"),
        .target           = target,
        .optimize         = optimize,
    });

    const lib_static = b.addLibrary(.{
        .name        = "bebop_v_ffi",
        .root_module = static_mod,
        .linkage     = .static,
    });
    b.installArtifact(lib_static);

    // ------------------------------------------------------------------
    // Install the C header so consumers can include it directly from
    // the zig-out tree.
    // ------------------------------------------------------------------

    b.installFile("../../include/bebop_v_ffi.h", "include/bebop_v_ffi.h");

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/bridge.zig"),
        .target           = target,
        .optimize         = optimize,
    });

    const unit_tests = b.addTest(.{ .root_module = test_mod });
    const run_tests  = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
