# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.5.2 |
| **Release Date** | 2026-03（4.5.2 maintenance；4.5 分支最后一个补丁，现 partial support） |
| **Project Pinned** | 2026-06-30（**re-pinned from 4.6.3** — 见下方 Re-pin Note） |
| **Last Docs Verified** | 2026-06-30 |
| **LLM Knowledge Cutoff** | May 2025 |

## Re-pin Note — 4.6.3 → 4.5.2（2026-06-30）

项目原 pin Godot 4.6.3，经 Sprint 0 导出 spike 实证后 **re-pin 到 Godot 4.5.2**。两条独立实证理由：

1. **抖音官方 Godot 适配器仅支持 4.5**：官方 Godot 集成指南（developer.open-douyin.com）明确「仅支持特定版本 Godot、不支持自定义」，支持列表只列 `Godot 4.5（推荐）`，未列 4.6/4.6.3。适配器插件 `ttsdk 1.0.3` 的 `compatibility_minimum=4.5`。
2. **GDUnit4 v6.0.0 在 4.6.3 编译失败**：内部 `get_as_text()` 参数不符 + `current_dir` 不存在 → 测试框架整链无法运行（ADR-0004 预设的"安装时验证"步骤 FAIL）。

4.5.2 是 4.5 分支最新稳定补丁。降级风险低：4.6 的主要变更（Jolt 默认物理、glow 改写、D3D12 默认、Dual-focus）针对 Forward+/3D/桌面路径，**不影响本项目 2D + Compatibility/WebGL2 路径**。spike 已证 4.6.3 出包/体积可行；切 4.5.2 后须用 4.5 兼容的 GDUnit4 重跑测试 + 重导出验证 Douyin IDE（之前卡在 dummy AppID + 框架，非 4.5 本身）。

## Knowledge Gap Warning

LLM 训练数据约覆盖到 Godot ~4.3。**4.4、4.5 是 post-cutoff（模型不了解），必须查本目录再建议 API。** 4.5 是本项目的**版本上限**——4.6 特有 API/变更**不适用**（见下表）。

## Post-Cutoff Version Timeline

| Version | Release | 对本项目 | Key Theme |
|---------|---------|---------|-----------|
| 4.4 | ~Mid 2025 | 适用（≤ pin） | Jolt physics option, FileAccess 返回类型, shader texture 类型变更 |
| 4.5 | ~Late 2025 | ✅ **PINNED 上限** | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA, Recursive Control, duplicate_deep |
| 4.6 | Jan 2026 | ❌ **NOT USED**（超出 pin） | Jolt 默认 / glow 改写 / D3D12 默认 / Dual-focus / IK restored —— **本项目不使用，引用 4.6 特性的 ADR 须复审** |

> ⚠️ **ADR 复审提示**：原 ADR 在 4.6.3 下撰写，部分正文引用 4.6 特有行为（如 ADR-0008 的「4.6 Dual-focus」、ADR-0007 的「D3D12 默认/glow 改写」）。re-pin 4.5 后这些 4.6 特性不再适用——须在下一次 `/architecture-review`（全新会话）中逐条复审、剔除或改写。9 个 ADR 的 `Engine:` 字段已随 re-pin 更新为 4.5.2。

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.5.2 maintenance release: https://godotengine.org/article/maintenance-release-godot-4-5-2/
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md

---

## Douyin Mini-Game Platform Notes

| Item | Status |
|------|--------|
| **Adapter Baseline** | Godot 4.5（官方 ByteDance 适配器；ttsdk 1.0.3，compatibility_minimum=4.5）—— **现与项目 pin 对齐** ✅ |
| **官方支持版本** | 仅 Godot 4.5（「不支持自定义版本」，未列 4.6+） |
| **WASM Size Limit** | ~50 MB；spike 实测空包 ~7.2 MB（引擎 godot.wasm.br 6.5M），2D 像素余量大 |
| **Memory Constraint** | 低端设备严格；纹理须压缩（ETC2/ASTC）；避免复杂着色器 |
| **Personal Dev Quota** | 须在 developer.open-douyin.com 注册 + 创建小游戏取 AppID（导出必填）+ 核实激励广告资格 |
| **测试框架** | GDUnit4 须用 **4.5 兼容版本**（v6.0.0 在 4.6.3 编译失败；4.5 下须验证可用版本，ADR-0004） |
| **Last Verified** | 2026-06-30 |

### Action Items（Sprint 0 / before Vertical Slice）
1. 安装 **Godot 4.5.2** + 4.5 兼容的 GDUnit4 → 在主项目跑通 TuningFormulas 8 个测试（逻辑已用独立脚本验证 8/8）
2. developer.open-douyin.com 注册 + 创建小游戏取真 AppID → 用 ttsdk 重导出 → Douyin IDE 跑通（验 spike P2/P5/P3-6 + 坐标 QQ-ADR8-01）
3. 修 `tests/gdunit4_runner.gd`（v6 入口为 `bin/GdUnitCmdTool.gd`，目录 `addons/gdUnit4` 大写 U；现脚本引用不存在的 `GdUnitRunner.gd`）
4. 下一次 `/architecture-review`（全新会话）复审 ADR 正文的 4.6 特性引用（Dual-focus / D3D12 / glow 等）
