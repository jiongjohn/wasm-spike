# WASM / Douyin Export Spike (THROWAWAY)

> **Status**: Spike harness prepared 2026-06-29 — NOT YET RUN (needs human + external tools)
> **Gates**: ADR-0007 (Status: Proposed until this spike passes QQ-01)
> **Throwaway**: delete after the verdict is recorded back into ADR-0007.

## What this is

A minimal Godot 4.6.3 project whose **only** purpose is to validate that the
Godot → WASM → Douyin mini-game pipeline works on the real platform, and that the
platform-sensitive APIs the architecture depends on behave as assumed. It is **not**
game code — no game systems are implemented here. Per `directory-structure.md`,
throwaway spikes live in `prototypes/`.

## Why a separate minimal project

The real game project (`project.godot`) does not exist yet — the project is currently
all docs + ADRs. ADR-0007 **Alternative 2** explicitly chose an *early* spike (before
content) over waiting for MVP code: platform viability is the highest project risk, and
"verify before investing" is standard risk management. This minimal harness is that early
spike.

## What it validates (ADR-0007 P3 + linked ADRs)

| Check | Validates | Source ADR |
|-------|-----------|------------|
| P3-1 | Autoload `_ready()` order (A before B) holds in WASM | ADR-0002 |
| P3-2 | `FileAccess.get_file_as_string("res://…")` reads PCK JSON in WASM VFS | ADR-0005 |
| P3-3 | `JSON.parse_string` + `int()` cast of JSON numbers | ADR-0005 |
| P3-4 | **RefCounted `duplicate()` / `duplicate_deep()` exist + deep-copy independence** | ADR-0001 |
| P3-5 | signal emit + Callable `connect` (Autoload → Node) | ADR-0003 |
| P3-6 | `InputEventScreenTouch` fires (tap the screen) | technical-preferences |

### ⚠️ P3-4 is a deliberate probe of a possible ADR-0001 defect

ADR-0001 (Accepted) chose `class_name + RefCounted` as the carrier for all 8 data
types AND calls `.duplicate()` / `.duplicate_deep()` on them to return read-only copies
(the `return_internal_reference_from_readonly_source` forbidden_pattern depends on this).

But per `docs/engine-reference/godot/breaking-changes.md`, `duplicate_deep()` was added
to **`Resource`** in 4.5 — and `duplicate()` is a **`Resource`/`Node`** method. **Plain
`RefCounted` may have neither.** The harness probes this with `has_method()` (so it never
crashes) and reports the truth on-screen.

- **If P3-4a/P3-4b FAIL** → ADR-0001's carrier or copy strategy is broken at the Foundation
  layer. Options: (a) switch the carrier to `Resource` subclasses, or (b) keep `RefCounted`
  but implement explicit hand-written deep-copy methods. Either way ADR-0001 (and ADR-0005/0009
  which inherit the copy contract) must be revised **before** any Foundation system is coded.
- This must be verified independently of the spike too — check Godot 4.6 docs (`Resource` vs
  `RefCounted` API) or ask the godot-specialist. The spike confirms it on-platform.

## Files

```
prototypes/wasm-export-spike/
├── project.godot          # Godot 4.6.3, gl_compatibility, 2 spike autoloads, emulate touch
├── SpikeMain.tscn         # one Control + script (main scene)
├── spike_main.gd          # the P3 harness — renders PASS/FAIL on screen + console
├── spike_config_a.gd      # Autoload A (ADR-0002 order probe)
├── spike_config_b.gd      # Autoload B (asserts A ready first)
├── data/spike_data.json   # FileAccess + JSON + nested grid fixture
├── RUNBOOK.md             # ← human execution steps + result recording
└── README.md              # this file
```

## Honesty note

This harness was authored by Claude Code against Godot ~4.3 training knowledge + the
project's pinned engine reference. It has **not** been opened in a Godot 4.6.3 editor or
run. Post-cutoff syntax/API surprises are possible (that is partly what the spike is for).
If the editor reports script/scene errors on first open, fix them and note the fix in the
RUNBOOK — do not assume the harness is authoritative over the editor.
