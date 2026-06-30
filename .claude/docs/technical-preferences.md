# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.5.2（2026-06-30 re-pinned from 4.6.3 — 抖音适配器仅支持 4.5 + GDUnit4 v6 不兼容 4.6.3）
- **Language**: GDScript
- **Rendering**: Godot 2D Renderer (Compatibility backend — most efficient for 2D-only)
- **Physics**: Godot Physics 2D (built-in, sufficient for arcade-style 2D)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: 抖音小游戏 (Douyin Mini-Game)
- **Input Methods**: Touch
- **Primary Input**: Touch (single-finger tap/swipe)
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: 抖音小游戏官方 Godot 适配器(ttsdk 1.0.3，字节小游戏引擎团队维护)。官方仅支持 **Godot 4.5**(项目已 re-pin 4.5.2 对齐，2026-06-30)。spike 实测：4.5/4.6.3 均能导出，但 Douyin IDE 真跑 + 测试框架须 4.5。WASM 体积实测空包 ~7.2MB(远低于 50MB 上限)。低端手机内存/GPU 严格受限:纹理必须压缩(ETC2/ASTC)、着色器复杂度需控制。导出必填 AppID(须在 developer.open-douyin.com 创建小游戏)；个人开发者资质及激励广告 SDK 接入资格待核实。导出时使用 Compatibility 渲染后端(最适合 2D + 低端设备)。

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerDash`)
- **Variables/Functions**: snake_case (e.g., `dash_charges`, `perform_dash()`)
- **Signals/Events**: snake_case past tense (e.g., `enemy_killed`, `charge_depleted`)
- **Files**: snake_case matching class (e.g., `player_dash.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerDash.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_DASH_CHARGES`)

## Performance Budgets

- **Target Framerate**: 30 fps (mini-game standard; 60 fps feasible but battery-intensive)
- **Frame Budget**: 33.3ms
- **Draw Calls**: < 50 (mobile / mini-game budget)
- **Memory Ceiling**: 256 MB (mini-game runtime constraint)
- **WASM Bundle Target**: < 50 MB (抖音小游戏上限;超出需自定义 JS 加载方案)

## Testing

- **Framework**: GDUnit4（`addons/gdunit4/`）— ADR-0004 正式选定，替代 GUT
- **Minimum Coverage**: Core gameplay systems (grid movement, deterministic combat, key/door logic, stat growth curve)
- **Required Tests**: Balance formulas (stat growth curve validation), deterministic combat results, floor progression pacing

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design, visual feedback shaders, and pixel-art rendering effects. Invoke GDExtension specialist only when native extensions are involved (e.g., Douyin SDK bindings).

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
