# Spike Runbook — ADR-0007 QQ-01 (WASM / Douyin export)

> Human-executed. Claude Code cannot run Godot, the Douyin IDE, a device, or the
> developer portal. Follow these steps, record results, then update ADR-0007.

## 0. Prerequisites (one-time)

- [ ] Install **Godot 4.6.3** (standard, not .NET — project is GDScript). Match the
      version in `docs/engine-reference/godot/VERSION.md` exactly.
- [ ] Install the **Web export templates** for 4.6.3 (Editor → Manage Export Templates).
- [ ] Install **Douyin 小游戏开发者工具（独立版本）** — download page:
      https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/dev-tools/developer-instrument-update-and-download
      （通用版后续不再维护小游戏功能，认准"小游戏独立版本"；Mac/Windows 选对应版）。
- [ ] Obtain the official **「Godot 开发者插件」(adapter)** + 《抖音 Godot 小游戏 SDK 使用说明》 via
      developer.open-douyin.com — integration guide:
      https://developer.open-douyin.com/docs/resource/zh-CN/mini-game/develop/guide/game-engine/godot/godot-engine-integration-guide
      Record its version.
      > 🔴 **官方文档（核于 2026-06-29）：适配器仅支持 `Godot 4.5（推荐）`，「不支持自定义」版本——未列 4.6/4.6.3。**
      > 本 spike 用 4.6.3 跑是**经验性兼容测试**：若适配器集成步骤（§4 P2）失败/拒绝 4.6.3，即为官方"仅 4.5"的实证确认 → 触发引擎 re-pin 到 4.5（ADR-0007 Risks 已预案；4.5 风险更低，2D Compatibility 路径不受 4.6 变更影响）。导出前可同时准备一份 Godot 4.5 以便对照。

## 1. Open the spike project & confirm it loads

1. Godot → Import → select `prototypes/wasm-export-spike/project.godot`.
2. **Confirm no script/scene parse errors.** If any appear (post-cutoff syntax surprises
   are possible — see README honesty note), fix them and record the fix in §5 "Notes".
3. Press **F5** (Play) in the editor. The window should show the P3 checklist with
   PASS/FAIL. Click/tap the window to satisfy **P3-6**.
4. **Record the editor (desktop) result** of each P3 line below — this is the baseline
   before WASM. P3-4a/P3-4b especially: does `RefCounted` have `duplicate`/`duplicate_deep`?

   > If P3-4a/P3-4b FAIL in the editor already, **stop and escalate**: this is an ADR-0001
   > Foundation defect (see README). It does not need the Douyin IDE to confirm — fix
   > ADR-0001 first. The rest of the export spike can still proceed in parallel.

## 2. Confirm renderer = Compatibility (ADR-0007 决策 1)

- [ ] Project Settings → Rendering → Renderer: `rendering_method = gl_compatibility`
      (already set in `project.godot`; confirm it didn't get overridden).
- [ ] Forbidden: Forward+ / Mobile (`forward_plus_renderer_in_wasm_project`).

## 3. Export to Web (WASM) & measure bundle size (P1, P4)

1. Project → Export → Add… → **Web**. (Let Godot generate the preset — do not hand-edit.)
2. Options to confirm:
   - **Export With Debug = OFF** (Release template — saves ~5-10MB, ADR-0007 decision 2).
   - **VRAM Texture Compression: For Mobile = ON** (ETC2/ASTC).
   - Runnable = ON.
3. Export to `prototypes/wasm-export-spike/build/web/index.html`.
4. **Measure** (run from this dir): `ls -lh build/web/*.wasm build/web/*.pck`
   - Record `.wasm` + `.pck` total. Apply the ADR-0007 three-tier rule:
     - ≤ 50MB → ✅ PASS
     - 51–70MB → ⚠️ apply standard optimization list (ADR-0007 决策 2) and re-measure
     - > 70MB or still > 50MB after optimization → ❌ custom JS chunked loader needed
   - (Empty spike will be tiny; this measurement is a *pipeline rehearsal* — the real
     bundle is measured again once game content exists.)

## 4. Load in Douyin IDE & verify on-platform (P2, P3, P5)

1. Integrate the ByteDance adapter per its docs; load the exported build in the Douyin IDE.
2. **P2** — reaches the spike screen without adapter/console errors; Autoload init chain
   shows no assertion failures.
3. **P3** — read the on-screen PASS/FAIL (and console `[SPIKE]` lines). Tap to satisfy P3-6.
4. **P5** — record first-frame time (< 10s target) and note any shader-compile hitch.
5. **E-3 (godot-specialist add-on)** — the empty spike can't measure a real floor-switch
   frame. Record this as a **deferred** P5 item: once #6 GridMovement exists, measure the
   floor-switch frame (256 `duplicate_deep` CellEntry + 256 `set_cell`) on the Douyin IDE /
   low-end device to confirm the <2ms budget (ADR-0009). Do NOT mark the <2ms budget
   verified from this spike.

## 5. Record results

Fill this table, then copy the verdict into **ADR-0007 § Validation Criteria** (tick the
boxes there + add spike run date + measured bundle size; flip Status → Accepted only if
all P1–P5 pass or a documented CONDITIONAL PASS).

| Item | Editor (desktop) | Douyin IDE / device | Notes |
|------|------------------|---------------------|-------|
| Project loads, no parse errors | | | |
| P3-1 Autoload order | | | |
| P3-2 FileAccess res:// JSON | | | |
| P3-3 JSON parse + int() cast | | | |
| **P3-4a RefCounted.duplicate()** | | | ← ADR-0001 |
| **P3-4b RefCounted.duplicate_deep()** | | | ← ADR-0001 |
| P3-4c deep-copy independence | | | |
| P3-5 signal emit + connect | | | |
| P3-6 touch input | | | |
| P1 export succeeds | n/a | | |
| P4 bundle size | n/a | | _____ MB |
| P5 first frame < 10s | n/a | | _____ s |
| E-3 floor-switch frame | DEFERRED — needs #6 | DEFERRED | measure post-#6 |

**Adapter version**: __________  **Douyin IDE version**: __________  **Test device**: __________
**Spike run date**: __________  **Overall**: PASS / CONDITIONAL PASS / FAIL

## 5a-bis. Douyin SDK 安装 — 2026-06-29 (Claude Code 解压放置)

- 已将 `douyin_godot_sdk_1.0.3_517fd34.zip` 解压到 `addons/`：`addons/ttsdk/` + `addons/ttsdk.editor/`。
- `ttsdk.editor` 是**原生 GDExtension**（`ttsdkeditor.gdextension`，含 macOS/Win/Linux 二进制）。
- **`compatibility_minimum = "4.5"`，无 `compatibility_maximum`** → GDExtension 向上兼容，预计可在 4.6.3 加载（4.6.3 ≥ 4.5）。官方只**支持** 4.5；4.6.3 即便加载亦属脱离官方支持区。
- SDK **自带 Web 导出模板**（`addons/ttsdk.editor/templates/web_release.zip` / `web_debug.zip`）——抖音导出走其自带模板，可能无需单独安装 Godot 官方 Web 模板。
- **macOS Apple Silicon 加载坑（2026-06-29 实遇 + 修复）**：启用插件报
  `library load disallowed by system policy` + `code signature not valid for use in process`，
  且连带 `Identifier "Brotli" not declared`（Brotli 是该扩展注册的类，dylib 没加载→类缺失→脚本 parse 错）。
  根因：dylib 原签名为 `adhoc,linker-signed`（flags 0x20002），arm64 加载策略拒绝。
  修复两步：(1) `xattr -dr com.apple.quarantine addons/ttsdk.editor`；
  (2) `codesign --force --sign - addons/ttsdk.editor/bin/libttsdkeditor.macos.editor.dylib`
  （重签为正常 adhoc flags 0x2 → `codesign --verify` 通过）。**重签后必须完全重启 Godot** 才会重新 dlopen。
- 下一步（人工）：重启 Godot → 确认 Output 无 dylib/Brotli 报错 → Project → Export 出现抖音平台 → 导出。决定性测试已从"能否启用"后移到"导出+Douyin 运行时是否工作于 4.6.3"。

## 5b. Headless desktop baseline — RUN 2026-06-29 (Claude Code, Godot 4.6.3.stable)

Ran `Godot --headless --path . --quit-after 30`. Harness parsed & ran with **zero
script errors** in 4.6.3. Results:

| Item | Headless desktop | Still pending |
|------|------------------|---------------|
| Project loads, no parse errors | ✅ PASS | — |
| P3-1 Autoload order | ✅ PASS | — |
| P3-2 FileAccess res:// JSON | ✅ PASS (379 bytes) | — |
| P3-3 / P3-3b JSON parse + int() cast | ✅ PASS (→20) | — |
| **P3-4a RefCounted.duplicate()** | 🔴 **FAIL** | — (verified, see below) |
| **P3-4b RefCounted.duplicate_deep()** | 🔴 **FAIL** | — (verified, see below) |
| P3-4c deep-copy independence | ⏭ skipped (4b false) | — |
| P3-5 signal emit + connect | ✅ PASS | — |
| P3-6 touch | n/a headless | needs device/IDE tap |
| P1 export / P4 bundle | — | **Web export templates not installed** → install via editor, then export |
| P2 / P5 Douyin IDE + first-frame | — | needs Douyin IDE + adapter |
| E-3 floor-switch frame | DEFERRED | needs #6 GridMovement |

### 🔴 P3-4 finding (ADR-0001 defect — VERIFIED)

Cross-checked with `verify_dup.gd` on 4.6.3:
```
RefCounted.duplicate = false   RefCounted.duplicate_deep = false
Resource.duplicate   = true    Resource.duplicate_deep   = true  (deep-copy independence ✅)
```
ADR-0001 chose `RefCounted` carriers and returns `.duplicate()/.duplicate_deep()` copies —
**neither method exists on RefCounted in 4.6.3.** Fix: switch the 8 data-type carriers to
`extends Resource` (constructed via `.new()`/`from_dict()` from JSON — no `.tres`, no
ResourceLoader cache, so ADR-0001's original Resource-rejection reason does not apply).
Ripple: ADR-0001 decision + Key Interfaces + Alternatives; ADR-0005 `from_dict` return types;
ADR-0009 `get_floor` duplicate_deep contract; `architecture.yaml` api_decisions
`cross_module_data_types` + `readonly_data_source_access`. Revise via `/architecture-decision`,
then re-run `/architecture-review`.

## 6. Feedback loop

- **P3-4 FAIL** → open `/architecture-decision` to revise ADR-0001 (carrier or copy strategy);
  ripple to ADR-0005/0009. Re-run `/architecture-review`.
- **Bundle > 50MB** → schedule custom JS chunked loader (ADR-0007 决策 2) in Pre-Production.
- **Adapter incompatible with 4.6.3** → evaluate downgrade to Godot 4.5.x (ADR-0007 Risks;
  re-check ADR-0001 `duplicate_deep` 4.5 availability).
- **All pass** → flip ADR-0007 → Accepted; unblocks content production.
