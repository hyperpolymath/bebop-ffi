# Bebop-FFI

> Stable C ABI for Bebop binary serialization — Zig is the canonical implementation.

Repo renamed from `bebop-v-ffi` → `bebop-ffi` on 2026-04-17.
V-lang was banned estate-wide on 2026-04-10; the V binding was moved to
`developer-ecosystem/v-ecosystem/v-api-interfaces/v-bebop/` for donation to
the V community.  GitHub remote rename (bebop-v-ffi → bebop-ffi) is pending
(user action).

## Project Context

This library exposes a stable C ABI (`include/bebop_v_ffi.h`) for the
[Bebop](https://bebop.sh) binary serialization format.  It is part of the
[Kaldor IIoT](https://github.com/hyperpolymath/kaldor-iiot) ecosystem.

The `_v_` in `bebop_v_ffi.h` and in all symbol names is **retained for C ABI
stability** — renaming would cascade breakage into consumers (volumod, etc.).
It is historical, not current.

## Tech Stack

- **Zig** — Canonical implementation language (`implementations/zig/`)
- **Bebop** — Schema definition and wire format (`schemas/`, `test-vectors/`)
- **C header** — Stable ABI contract (`include/bebop_v_ffi.h`)

## Key Commands

```bash
# Build shared + static library
just build
# or: cd implementations/zig && zig build

# Run tests
just test
# or: cd implementations/zig && zig build test

# Release build
just build-release
```

## Architecture

```
Any Consumer → C FFI (bebop_v_ffi.h) → Zig Implementation → Bebop Wire Format
```

## Related Projects

- [kaldor-iiot](https://github.com/hyperpolymath/kaldor-iiot) - Parent IIoT platform
- [volumod](https://github.com/hyperpolymath/volumod) - Concrete consumer (declares extern against bebop_v_ffi.h)
- [v-bebop](developer-ecosystem/v-ecosystem/v-api-interfaces/v-bebop/) - Former V binding, donated upstream

## Coding Standards

- Use descriptive variable names
- All public functions must have doc comments
- No `@panic` as error handling; use `error.X` unions internally
- No stubs, no TODOs, no `unreachable` in reachable code
- C ABI boundary returns int codes / opaque pointers

## File Annotations

All source files must include:
```
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (C) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
```

## RSR Compliance

- **Tier**: Bronze
- **Prohibited**: Python, TypeScript/JavaScript (use ReScript), V-lang, Go
- **Required**: justfile, .well-known/, comprehensive docs
