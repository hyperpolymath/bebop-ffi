;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; ECOSYSTEM.scm - Project relationships and ecosystem positioning
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
 (version 2)
 (name "bebop-ffi")
 (former-name "bebop-v-ffi")
 (renamed "2026-04-17")
 (type "library")
 (purpose "Stable C ABI for Bebop binary serialization — Zig canonical implementation")

 (position-in-ecosystem
  (layer "infrastructure")
  (domain "serialization")
  (target "iiot-edge"))

 (language "Zig")
 (note "V-lang banned estate-wide 2026-04-10. V binding donated to V community at developer-ecosystem/v-ecosystem/v-api-interfaces/v-bebop/.")

 (related-projects
  ((name "kaldor-iiot")
   (relationship parent)
   (description "Parent IIoT platform — primary consumer"))

  ((name "volumod")
   (relationship consumer)
   (description "Concrete downstream consumer; declares extern against bebop_v_ffi.h"))

  ((name "bunsenite")
   (relationship sibling-standard)
   (description "Similar FFI architecture for Nickel parser"))

  ((name "bebop")
   (relationship upstream-dependency)
   (url "https://bebop.sh")
   (description "Binary serialization format — wire format spec"))

  ((name "v-bebop")
   (relationship former-binding-donated)
   (path "developer-ecosystem/v-ecosystem/v-api-interfaces/v-bebop/")
   (description "Former V binding; moved 2026-04-17 for donation to V community")))

 (what-this-is
  "A stable C ABI contract (bebop_v_ffi.h) for Bebop serialization"
  "Zig implementation producing libbebop_v_ffi.{so,a}"
  "Zero-copy arena-based decode/encode for IIoT edge devices")

 (what-this-is-not
  "A reimplementation of Bebop wire format from scratch (this implements it)"
  "A general-purpose serialization library"
  "A networking library"
  "A V-language project (V moved out 2026-04-17)"))
