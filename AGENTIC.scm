;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; AGENTIC.scm - AI/Agent interaction policies for this repository

(agentic
 (version 2)
 (project "bebop-ffi")
 (note "Repo renamed bebop-v-ffi → bebop-ffi on 2026-04-17. Zig is canonical.")

 (agent-role
  (primary "zig-implementer")
  (description "AI implements, tests, and documents the Zig binding. ABI header changes require human review."))

 (boundaries
  (can-do
   "Implement and update Zig code in implementations/zig/"
   "Write and maintain tests"
   "Update internal docs (STATE.scm, META.scm, ECOSYSTEM.scm, CLAUDE.md)"
   "Propose API shapes and struct layouts"
   "Draft documentation"
   "Fix build system issues (build.zig)"
   "Update consumer build.zig paths (e.g. volumod)"))

  (cannot-do
   "Modify include/bebop_v_ffi.h without human review"
   "Rename ABI symbols"
   "Change Bebop wire format interpretation without spec reference"
   "Push commits directly"
   "Migrate the Zig implementation to another language"))

 (review-gates
  ((artifact "ABI header changes (bebop_v_ffi.h)")
   (requires human-sign-off)
   (reason "ABI stability is the core deliverable"))
  ((artifact "Serialization logic")
   (requires human-sign-off)
   (reason "Wire format correctness critical; mismatches are silent corruption"))
  ((artifact "Schema changes (schemas/*.bop)")
   (requires human-sign-off)
   (reason "Schema is the source of truth for field indices and types")))

 (interaction-style
  (verbosity concise)
  (code-generation full-implementation-no-stubs)
  (proactive-suggestions allowed)
  (explain-before-act required))

 (trust-escalation
  (default-level "implement-with-approval")
  (escalation-path
   "propose → implement → human-sign-off for ABI changes")))
