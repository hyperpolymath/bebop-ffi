# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
#
# config.ncl - Nickel configuration for bebop-v-ffi
# https://nickel-lang.org

{
  project = {
    name = "bebop-v-ffi",
    version = "0.0.1",
    description = "FFI bindings between Bebop binary serialization and V language",
    license = "AGPL-3.0-or-later",
    repository = "https://github.com/hyperpolymath/bebop-v-ffi",
  },

  build = {
    implementation = "zig",
    output = {
      shared_lib = "libbebop_v_ffi.so",
      static_lib = "libbebop_v_ffi.a",
      header = "bebop_v_ffi.h",
    },
    targets = ["x86_64-linux", "aarch64-linux"],
  },

  abi = {
    version = 1,
    stability = "unstable",  # will be "stable" at 1.0.0
    header = "include/bebop_v_ffi.h",
    types = ["BebopCtx", "VBytes", "VSensorReading"],
    functions = [
      "bebop_ctx_new",
      "bebop_ctx_free",
      "bebop_ctx_reset",
      "bebop_decode_sensor_reading",
      "bebop_free_sensor_reading",
      "bebop_encode_batch_readings",
    ],
  },

  schemas = {
    path = "schemas/",
    files = ["sensors.bop"],
    generator = "bebopc --lang c",
  },

  implementations = {
    zig = {
      path = "implementations/zig/",
      status = "stub",
      build_cmd = "zig build",
    },
    rust = {
      path = "implementations/rust/",
      status = "help-wanted",
      build_cmd = "cargo build --release",
    },
  },

  quality = {
    required_coverage = 0,  # TODO: increase as we implement
    run_fuzz = false,
    require_golden_vectors = true,
  },

  ecosystem = {
    parent = "kaldor-iiot",
    related = ["bunsenite"],
    language_bindings = ["v"],
  },
}
