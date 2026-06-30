# ADR-0007: WASM 导出管线与 Douyin 适配器验证

## Status
Proposed

> **⚠️ 出口门控 ADR（Spike-Gated）**：本 ADR 的架构决策（渲染器选择、体积策略）可在导出 spike 前确立；但 **Status 须保持 Proposed，直到导出 spike QQ-01 通过**。Spike 通过后将本 ADR 状态更新为 Accepted，并在 "## Validation Criteria" 节附注 spike 运行日期与实测 bundle size。

## Date
2026-06-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3 — 适配器仅支持 4.5；本 ADR 正文 4.6 渲染变更引用须复审） |
| **Domain** | Platform / Build（WASM 导出，Douyin 小游戏适配器） |
| **Knowledge Risk** | HIGH — Douyin 适配器基线 ~Godot 4.5；4.6.3 兼容性待实测；LLM 训练截止 4.3，所有相关变更均在截止后 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`（Douyin 节）、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `FileAccess.store_*` 在 4.4+ 返回 bool 而非 void（本项目只读，不调用 store_*，无影响但须在 spike 中确认）；`RefCounted.duplicate_deep()` 为 4.5+ API，适配器基线 ~4.5，须在 spike 中验证 WASM 行为 |
| **Verification Required** | 运行导出 spike QQ-01（本 ADR 核心闸口）：所有 Validation Criteria 通过后将 Status 改为 Accepted |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（duplicate_deep() 用于 FloorDB — 须在 spike 中验证 WASM 行为）；ADR-0002（Autoload 启动顺序 — 须在 WASM 中验证 _ready() 顺序）；ADR-0005（FileAccess + manifest.json 方案 — 须在 WASM VFS 中验证） |
| **Enables** | MVP 所有实现 epic（#1–#13）的「WASM 兼容」验证前置 |
| **Blocks** | 生产内容制作（sprites、关卡 JSON、音频资产）不应在本 ADR Accepted 之前大规模投入，否则存在平台不可用风险 |
| **Ordering Note** | 可与 ADR-0001~0006 并行设计，但 spike 执行须在内容生产开始前完成；spike 不需要等待所有 MVP 实现 epic——可以在开始实现任意系统后立即执行 |

## Context

### Problem Statement

ADR-0001 至 ADR-0006 均将「Verification Required」指向 WASM/Douyin 导出验证（QQ-01），但无任何 ADR 正式确立：

1. **Compatibility 渲染后端**的选择依据（已写入 technical-preferences.md，但从未作为架构决策记录——其他开发者无法得知为何不用 Forward+/Mobile，也不知道在哪个 ADR 中决定的）。
2. **WASM 体积 > 50MB** 时的分级应对策略（VERSION.md 仅记录风险，无决策）。
3. **Douyin 适配器 4.6.3 兼容性验证程序**：什么情况构成「通过」，什么情况构成「阻断器」。
4. **内容生产开始的闸门**：以什么客观标准宣布平台可行、允许 MVP 生产内容投入。

没有这些决策，团队在「游戏技术可行但导出不可行」的情况下无法做出有依据的优先级判断。

### Constraints
- **50MB 上限**：Douyin 小游戏 WASM bundle 限制（VERSION.md）；超出须自定义 JS 分块加载方案
- **WebGL 2.0**：Douyin 小游戏 WebView 支持 WebGL 2.0，不支持 Vulkan/Metal/D3D12
- **低端设备**：目标包含 2GB RAM Android 设备；<256MB 运行时内存预算
- **Douyin 适配器**：官方 ByteDance 小游戏引擎团队维护，基线 ~Godot 4.5，4.6.3 兼容性待字节开发者文档或实测确认
- **Shader Baker 不适用**：Shader Baker（4.5+）仅支持 Vulkan 渲染器，本项目 Compatibility 渲染器下不可用（不影响正确性，但意味着首次着色器编译可能有轻微卡顿）

### Requirements
- Compatibility 渲染后端须有正式架构依据，不可在后续 sprint 中被误更换
- 导出 spike 须在生产内容投入前执行（本 ADR 作为闸门）
- WASM 体积须有明确的三级应对策略（每级有明确的行动标准）
- spike 须覆盖所有下游 ADR 标记的「Verification Required」项

## Decision

### 决策 1 — 渲染后端：Compatibility（唯一可行 WASM 选择）

**正式确立 Compatibility 渲染后端（OpenGL ES 3.0 / WebGL 2.0）为本项目唯一使用的渲染后端。**

Forward+ 和 Mobile 渲染器均依赖 Vulkan/D3D12/Metal，这些图形 API 在 WASM/WebGL 环境下不可用。Compatibility 是 Godot 4.x 中唯一支持 WebGL 2.0 的渲染后端。

在 Godot 4.4、4.5、4.6 的 breaking changes 中，所有主要渲染变更（Jolt 默认物理、光晕改写、D3D12 默认、SMAA、Shader Baker）均针对 Forward+ 或 Metal/D3D12 渲染器，Compatibility / WebGL 2.0 路径未发生改变。引擎专家确认：**Compatibility 渲染面在 4.4-4.6 中对 2D 像素艺术项目保持稳定。**

禁止在 Project Settings 中将渲染后端切换为 Forward+ 或 Mobile，即便在开发机（macOS/Windows）上对开发调试更方便。始终使用 Compatibility 以保证本地与 WASM 行为一致。

### 决策 2 — WASM bundle 体积三级策略

| 实测体积 | 状态 | 行动 |
|---------|------|------|
| ≤ 50MB（优化前） | ✅ PASS | 无需额外工作，直接进入生产 |
| 51–70MB（标准优化后 ≤ 50MB） | ⚠️ 需优化 | 应用标准优化清单（见下）后重测；若 ≤ 50MB 则 PASS |
| > 70MB，或标准优化后仍 > 50MB | ❌ 阻断器 | 实施自定义 JS 分块加载方案（见下）；spike 标注为 CONDITIONAL PASS |

**标准优化清单**（应用顺序）：
1. 使用 **Release 导出模板**（非 Debug）→ 节省约 5-10MB
2. 导出设置中**禁用 3D 模块**：3D 物理（Jolt/Godot Physics 3D）、NavigationServer3D、XR、Movie Maker、Mesh 相关类
3. 所有纹理使用 **ETC2 或 ASTC 压缩**（移动 WebGL 2.0 支持）
4. 启用 **GDScript 调试符号剥离**（release build 自动）
5. 若项目有 C# bindings（本项目无），移除

**自定义 JS 分块加载方案**（仅在体积 > 50MB 且标准优化后仍超限时）：
- Douyin 小游戏支持自定义 JS 加载器，可将 `.wasm` 分块按需加载
- 方案来源：VERSION.md「WASM Size Limit」条目的缓解措施
- 实现时序：spike 阶段仅证明体积是否需要分块加载；具体 JS 分块加载实现在 pre-production 阶段完成（届时出 ADR-0007 修订版或独立 ADR）

### 决策 3 — 导出 spike QQ-01 通过标准

以下**所有**检查项通过，spike 才构成「PASS」，本 ADR 方可更新为 Accepted：

**P1 — 基础导出**
- [ ] Godot 4.6.3 WASM 导出成功（无构建错误）
- [ ] `index.html` + `.wasm` + `.pck` 文件完整生成
- [ ] 实测 bundle size 已记录（`.wasm` + `.pck` 合计）

**P2 — Douyin 适配器加载**
- [ ] 适配器脚本集成无报错
- [ ] 小游戏包在 Douyin 开发者工具 (IDE) 中启动，到达 GameBootstrap 完成帧
- [ ] Autoload 初始化顺序正确（控制台无 assertion failed 信息）

**P3 — 关键 API 验证**（覆盖下游 ADR 的 Verification Required）
- [ ] `FileAccess.get_file_as_string("res://data/entities.json")` 返回非空字符串（ADR-0005）
- [ ] `manifest.json` 正确枚举楼层文件列表（ADR-0005 manifest 方案）
- [ ] `RefCounted.new()` + 字段赋值 + 读取正常（ADR-0001）
- [ ] `FloorEntry.duplicate_deep()` 复制嵌套 grid 正确、修改副本不影响原始（ADR-0001）
- [ ] 触控输入 `InputEventScreenTouch` 在真机/模拟器触发正常（technical-preferences.md）
- [ ] 信号发出与接收正常（Autoload signal → Scene Node 连接模式，ADR-0003）

**P4 — 体积合规**
- [ ] bundle size ≤ 50MB（优化前或标准优化后），或自定义 JS 分块加载方案可行性确认（CONDITIONAL PASS）

**P5 — 性能基线**
- [ ] 启动时间（首帧渲染）< 10s（低端 Android 设备或 Douyin IDE 模拟器）
- [ ] 实体数据库加载（3 JSON 文件）无明显卡顿（< 500ms）

**非阻断（记录但不阻断 PASS）**：
- 着色器首次编译卡顿（<1s 可接受）
- `push_error()` 日志是否在 Douyin 控制台可见

### Architecture Diagram

```
本地 Godot 4.6.3 Editor
    │
    ├── Export → WASM (Compatibility renderer)
    │       ├── index.html
    │       ├── [game].wasm
    │       └── [game].pck   (含 res://data/*.json + GDScript .gdc)
    │
    │   [Spike QQ-01: 体积测量、API验证]
    │
Douyin 开发者工具 (IDE)
    │
    ├── 适配器脚本注入 (ByteDance ~4.5 baseline)
    │       └── WebGL 2.0 Canvas
    │
    ├── WASM 运行时
    │       ├── Autoload 初始化链（ADR-0002）
    │       ├── JSON FileAccess + manifest（ADR-0005）
    │       └── 游戏主循环
    │
    └── 上传小游戏包 → Douyin 审核 → 上线
```

### Key Interfaces

本 ADR 为平台/流程决策，无 GDScript 接口。关键配置：

```
# Godot Project Settings — Export → Web
renderer/rendering_method = "gl_compatibility"      # 决策 1：必须是此值
renderer/rendering_method.mobile = "gl_compatibility"

# Export Template
debug/export_console_commands = false               # release build
binary_format/embed_pck = true                      # 单文件 WASM
html/export_icon = true
```

```
# 体积测量命令（spike 执行时运行）
ls -lh build/web/*.wasm build/web/*.pck  # 记录实测大小
```

## Alternatives Considered

### Alternative 1: Forward+ 渲染器（编辑器中使用，导出时切换）
- **Description**: 本地开发用 Forward+ 享受 Vulkan 功能，导出时自动切换到 Compatibility。
- **Pros**: 本地开发可使用更好的光照和 PBR 调试工具。
- **Cons**: 本地行为与 WASM 行为不一致（着色器、CanvasItem material 参数在两者间可能不同）；开发者可能在 Forward+ 下调试像素艺术而未意识到 Compatibility 下颜色/滤镜不同；切换成本在每次导出时都需要确认。
- **Rejection Reason**: 像素艺术项目在 Compatibility 下已有完整开发能力，两后端一致性比 Forward+ 额外功能更重要；本机和 WASM 必须视觉一致。

### Alternative 2: 推迟 spike 至 MVP 首个系统实现后
- **Description**: 先完成 #1–#5 的代码实现，再验证 WASM 导出。
- **Pros**: 可以更接近真实游戏环境验证（而非空项目 hello-world spike）。
- **Cons**: 若 Douyin 4.6.3 适配器存在根本性不兼容，在 5 个系统实现后才发现，等同于废弃所有工作；早期 spike 的代价是 1-2 天工程时间，远低于被迫回滚的成本。
- **Rejection Reason**: 平台可用性是最高风险项，「验证后再投入」是标准风险管理实践。

### Alternative 3: 无体积策略，超过就再想办法
- **Description**: 不预先决定体积应对策略，超过 50MB 时再临时应对。
- **Pros**: 现在无需决策。
- **Cons**: 临时应对可能在 Pre-Production 关键节点消耗大量时间；自定义 JS 分块加载器有工程复杂度，需提前预留时间；Douyin 适配器文档可能需要时间研究。
- **Rejection Reason**: 提前定义三级策略的成本极低，可在 spike 时即获得决策基础，避免后续临时决策。

## Consequences

### Positive
- Compatibility 渲染器选择正式有依据，防止未来误更换导致导出失败
- spike QQ-01 通过标准明确，消除「应该测什么才够」的歧义
- 三级体积策略提供清晰的阶段性预期，生产决策有据可依
- 本 ADR Proposed 状态显式传递「平台可行性未经验证」的风险信号

### Negative
- spike 是一个阻断器——在 spike 运行前，不应大规模投入关卡内容制作（但代码实现可以并行进行）
- 若 Douyin 4.6.3 适配器与 4.6 存在不兼容（目前 UNKNOWN），可能需要回退到 Godot 4.5.x，涉及引擎降级成本

### Risks
- **风险（HIGH → 部分实证升级，2026-06-29）**：Douyin 适配器 ~4.5 baseline 与 Godot 4.6.3 存在 API 不兼容。**官方 Godot 集成指南（developer.open-douyin.com，核于 2026-06-29）明确：适配器仅支持 `Godot 4.5（推荐）`、「不支持自定义」版本——未列 4.6/4.6.3。** 即项目当前 pin 的 4.6.3 大概率不被官方适配器接受。
  - **缓解**：spike 优先执行；用户决定先用 4.6.3 跑作经验性兼容测试（§4 P2 适配器集成步骤即判定点）；若集成失败/拒绝 4.6.3 → 实证确认"仅 4.5"，**触发引擎 re-pin 到 Godot 4.5**（迁移方案见 Migration Plan；4.5 风险方向与 ADR-0001 duplicate_deep 一致，且 4.6 的 HIGH 风险变更 [Jolt/glow/D3D12] 均不影响 2D Compatibility 路径，降级风险低）。re-pin 涉及 VERSION.md + CLAUDE.md + 全 ADR「Engine」字段 + technical-preferences，由用户拍板后执行。
- **风险（MEDIUM）**：bundle size 超过 50MB 且自定义 JS 分块加载实现延误 Pre-Production 进度。
  - **缓解**：spike 阶段即测量体积；若体积在 51-70MB 区间，提前安排标准优化；若 > 70MB，在 Pre-Production 计划中提前分配 JS 分块加载实现时间（ADR-0007 CONDITIONAL PASS）。
- **风险（ENGINE ES-7）**：Shader Baker（4.5+）不支持 Compatibility 渲染器，无法预热着色器缓存。
  - **缓解**：2D 像素艺术项目使用的着色器变体极少（扁平颜色 + 简单纹理采样），首次编译卡顿应 < 500ms；spike P5 确认实际值。若超出可接受范围，改用 ShaderMaterial 内联着色器（无变体分叉）。
- **风险（ENGINE ES-7）**：`FileAccess.store_*` 方法在 4.4+ 返回 bool（原 void），本项目不调用 store_*，但未来新增写入逻辑时须注意。
  - **缓解**：本项目 MVP 为只读架构（EntityDB/FloorDB/TuningConfig 全只读），无 store_* 调用；如引入存档功能则需单独 ADR。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| （所有 GDD） | 依托平台：抖音小游戏，WASM 导出 | 本 ADR 正式确立 Compatibility 渲染器选择，spike QQ-01 验证 WASM 可行性 |
| combat-system.md | C7：逻辑/动画解耦，逻辑同步结算，无 await | spike P3 验证信号在 WASM 中正常 dispatch（CONNECT_DEFERRED 行为） |
| floor-layout-data.md | AC-FL-13：duplicate_deep 返回独立副本 | spike P3 验证 `duplicate_deep()` 在 Douyin WASM 中行为正确 |
| entity-database.md / floor-layout-data.md | JSON FileAccess 读取 res:// | spike P3 验证 FileAccess 在 WASM VFS 中正常读取 JSON |

## Performance Implications
- **CPU**: Compatibility 渲染器 2D draw call 消耗约等于 Forward+（没有显著差异）；WASM 单线程，所有游戏逻辑和渲染在主线程执行
- **Memory**: 256MB 上限；bundle 加载后 WASM 实例约占 60-80MB（引擎核心 + 代码），剩余 ≥ 176MB 给游戏状态和资产
- **Load Time**: spike P5 基线（目标 < 10s 首帧；JSON 加载 < 500ms）
- **Network**: WASM 文件须从 Douyin CDN 分发；bundle size 直接影响加载时间（50MB @ 10Mbps = 40s；分块加载可优化首屏时间）

## Migration Plan
无现有导出管线。spike 是首次建立 WASM 导出流程；若发现 Godot 4.6.3 与适配器不兼容，迁移方案为引擎降级（4.5.x，须评估 ADR-0001~0006 兼容性）。

## Validation Criteria
（spike QQ-01 执行后逐项勾选，全部通过后将 Status 改为 Accepted）

**P1 基础导出**
- [ ] WASM 导出成功，bundle 文件生成
- [ ] 实测 bundle size：_______ MB（记录实际值）

**P2 Douyin 适配器加载**
- [ ] 在 Douyin 开发者 IDE 中启动并到达 GameBootstrap 完成帧
- [ ] Autoload 初始化链无 assertion failed

**P3 关键 API**
- [ ] FileAccess.get_file_as_string(res://data/entities.json) 返回有效 JSON
- [ ] manifest.json 楼层发现正常
- [ ] RefCounted new() + 字段赋值正常
- [ ] FloorEntry.duplicate_deep() 嵌套复制正确（修改副本不影响原始）
- [ ] InputEventScreenTouch 在触控/模拟器中触发
- [ ] 信号 emit + connect 正常（Autoload → Scene Node）

**P4 体积**
- [ ] bundle size ≤ 50MB，或分块加载方案可行性确认

**P5 性能基线**
- [ ] 首帧 < 10s；JSON 加载 < 500ms

**Spike 运行日期**：2026-06-29（部分 — 桌面导出阶段）
**执行环境**：Godot 4.6.3.stable + Douyin Godot SDK 1.0.3（ttsdk/ttsdk.editor）/ macOS Apple Silicon

### Spike 部分结果（2026-06-29，dummy app_id 占位）

| 项 | 结果 |
|----|------|
| 插件加载（ttsdkeditor GDExtension on 4.6.3） | ✅ 过（compatibility_minimum=4.5，无上限；macOS 需 codesign ad-hoc 重签 + 去 quarantine，见 RUNBOOK §5a-bis） |
| 抖音导出平台注册 | ✅ 出现于 Project→Export |
| **P1 导出成功** | ✅ 产出 game.js/godot.launcher.js/game.json + godot/{godot.wasm.br, godot.js, main.pck} |
| **P4 bundle size** | ✅ **≈ 7.2MB**（godot.wasm.br 6.5M + js 354K + main.pck 136K[空spike] + wrapper 68K）≪ 50MB，余量极大 |
| 导出警告 | 无害：`未找到 wasm32 库对应 ttsdkeditor.gdextension`——editor 插件仅 desktop 库，本不进 web 运行时（runtime SDK 为纯 GDScript ttsdk，无原生库） |
| **P2 Douyin IDE 加载** | 🟡 部分过：4.6.3 导出包被 IDE 接受、抖音运行时**启动**（iPhone 15 Pro 模拟器显示 SDK「正在初始化」绿条）——证明 4.6.3 出包能进 Douyin 运行时，非格式不认 |
| **P5 首帧 / 内容渲染** | ⏳ 未过：**卡在「正在初始化」、屏幕空白**，Godot 场景未渲染。最可能因 dummy app_id 致 SDK init 不通过（非 4.6.3 兼容问题）。须真 AppID 越过 init 后再验 P5 + P3-6 + QQ-ADR8-01 |
| P3-6 触控 / QQ-ADR8-01 坐标 | ⏳ 待 IDE/真机 |

**4.6.3 兼容性初步结论**：官方文档称"仅 4.5"，但 **4.6.3 下插件加载 + 导出管线 + 出包全部通过**，无真实不兼容。最终判定待 P2/P5（IDE/真机运行）—— 若 IDE 运行亦正常，则 4.6.3 可继续用、无需 re-pin 4.5。**Status 维持 Proposed 直至 P2/P5 通过。**

## Related Decisions
- ADR-0001（数据类型）— duplicate_deep() 在 WASM 验证是本 ADR spike 的覆盖项
- ADR-0002（Autoload 启动顺序）— Autoload _ready() 在 WASM 中的时序验证
- ADR-0005（数据文件组织）— FileAccess + manifest WASM VFS 验证
- docs/engine-reference/godot/VERSION.md Douyin 节 — 本 ADR 的风险来源文档
