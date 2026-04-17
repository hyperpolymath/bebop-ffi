;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; PLAYBOOK.scm - Operational runbooks and procedures

(playbook
 (version 2)
 (project "bebop-ffi")
 (note "Repo renamed bebop-v-ffi → bebop-ffi on 2026-04-17. Zig canonical.")

 (runbooks
  ((id "build-library")
   (description "Build libbebop_v_ffi.{so,a}")
   (steps
    "cd implementations/zig && zig build"
    "Artifacts: implementations/zig/zig-out/lib/libbebop_v_ffi.{so,a}"
    "Or: just build (from repo root)"
    "Release: just build-release"))

  ((id "run-tests")
   (description "Run unit tests")
   (steps
    "cd implementations/zig && zig build test"
    "Or: just test (from repo root)"
    "9 tests should pass; no external deps required"))

  ((id "consumer-integration")
   (description "Wire a consumer (e.g. volumod) to libbebop_v_ffi")
   (steps
    "1. Build bebop-ffi first: cd implementations/zig && zig build"
    "2. In consumer build.zig, pass -Dbebop-include and -Dbebop-lib"
    "   Example: zig build test-ffi -Dbebop-include=../../developer-ecosystem/bebop-ffi/include -Dbebop-lib=../../developer-ecosystem/bebop-ffi/implementations/zig/zig-out/lib/libbebop_v_ffi.a"
    "3. Header is installed at: implementations/zig/zig-out/include/bebop_v_ffi.h"))

  ((id "add-new-message-type")
   (description "Add a new Bebop message type to the FFI")
   (steps
    "1. Add message to schemas/*.bop"
    "2. Add corresponding struct to include/bebop_v_ffi.h (human review required)"
    "3. Add decode/encode functions to header (human review required)"
    "4. Implement in implementations/zig/src/bridge.zig"
    "5. Add tests"
    "6. Add golden test vectors"
    "7. Update docs"))

  ((id "add-implementation")
   (description "Add a plug-compatible implementation (e.g. Rust)")
   (steps
    "1. Create implementations/<lang>/ directory"
    "2. Implement all 6 functions from bebop_v_ffi.h"
    "3. Use VBytes (ptr+len) for all byte slices"
    "4. Implement context-based arena allocation"
    "5. Pass all golden vector tests"
    "6. Document build process in implementations/<lang>/README.adoc"
    "7. Add to CI matrix"))

  ((id "rename-github-remote")
   (description "Complete the bebop-v-ffi → bebop-ffi rename on GitHub")
   (steps
    "1. On GitHub: Settings → General → Repository name → bebop-ffi"
    "2. git remote set-url origin https://github.com/hyperpolymath/bebop-ffi.git"
    "3. Update any cross-repo references (kaldor-iiot, volumod, etc.)"
    "(This is a USER action — NOT done by AI)"))

  ((id "release-checklist")
   (description "Steps before tagging a release")
   (steps
    "1. All unit tests pass (just test)"
    "2. volumod test-ffi passes"
    "3. ABI header unchanged or version bumped with ADR"
    "4. STATE.scm updated"
    "5. Docs reflect current state"
    "6. CI green on all platforms"
    "7. Tag with semantic version"))

  ((id "debug-decode-failure")
   (description "Troubleshoot decode failures")
   (steps
    "1. Check wire bytes against golden vectors"
    "2. Verify Bebop message format: 4-byte LE body-length prefix"
    "3. Check field indices (1-based; SensorReading: 1=ts, 2=id, 3=type, 4=val, 5=unit, 6=loc, 7=meta)"
    "4. Check endianness (little-endian throughout)"
    "5. Check schema version match"
    "6. Check context not already freed")))

 (emergency-procedures
  ((id "revert-bad-release")
   (steps
    "1. git revert to last known good"
    "2. Tag new patch release"
    "3. Notify consumers (especially volumod)"
    "4. Post-mortem in docs/incidents/"))))
